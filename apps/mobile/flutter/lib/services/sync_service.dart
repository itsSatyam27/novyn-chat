import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'hybrid_db_service.dart';
import 'local_db_service.dart';

typedef PendingMessageSender = Future<void> Function(PendingMessage message);
typedef PendingMessageFailureHandler = void Function(
  PendingMessage message,
  String reason,
);

/// A server rejection is permanent for this queued payload. Transport errors,
/// timeouts and missing peer keys remain retryable and stay in the outbox.
class PendingMessageRejectedException implements Exception {
  const PendingMessageRejectedException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Background sync and account-scoped durable outbox for offline messages.
class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  Timer? _syncTimer;
  bool _isSyncing = false;
  bool _isOnline = true;
  bool _outboxLoaded = false;
  DateTime? _lastSyncTime;
  String? _activeAccount;
  int _accountActivationRevision = 0;
  Future<void> _storageWriteQueue = Future<void>.value();
  Future<void>? _flushFuture;

  final List<PendingMessage> _pendingMessages = [];

  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;
  DateTime? get lastSyncTime => _lastSyncTime;
  List<PendingMessage> get pendingMessages =>
      List.unmodifiable(_pendingMessages);

  /// Load one account's outbox after its account-scoped Hive boxes are active.
  Future<void> activateAccount(String username) async {
    final account = username.trim().toLowerCase();
    if (account.isEmpty) return;
    if (_activeAccount == account && _outboxLoaded) return;

    final activationRevision = ++_accountActivationRevision;
    await _storageWriteQueue.catchError((Object _) {});
    if (activationRevision != _accountActivationRevision) return;
    _activeAccount = account;
    _outboxLoaded = false;
    _pendingMessages.clear();
    notifyListeners();

    final raw = await LocalDbService.getPendingMessages(account);
    if (activationRevision != _accountActivationRevision ||
        _activeAccount != account) {
      return;
    }

    for (final entry in raw) {
      try {
        final message = PendingMessage.fromJson(entry);
        if (message.accountId == account &&
            message.tempId.isNotEmpty &&
            !_pendingMessages.any((item) => item.tempId == message.tempId)) {
          _pendingMessages.add(message);
        }
      } catch (error) {
        debugPrint('[NovynOutbox] Skipped malformed queue item: $error');
      }
    }
    _pendingMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _outboxLoaded = true;
    notifyListeners();
  }

  Future<void> loadPendingMessages() async {
    final account = _activeAccount;
    if (account == null) return;
    _outboxLoaded = false;
    await activateAccount(account);
  }

  /// Clear only the in-memory account context on logout. Durable records stay
  /// in that account's isolated Hive namespace and are restored on next login.
  Future<void> deactivateAccount() async {
    final activationRevision = ++_accountActivationRevision;
    await _storageWriteQueue.catchError((Object _) {});
    if (activationRevision != _accountActivationRevision) return;
    _activeAccount = null;
    _outboxLoaded = false;
    _pendingMessages.clear();
    notifyListeners();
  }

  Future<void> _ensureOutboxLoaded() async {
    final account = _activeAccount;
    if (account == null) {
      throw StateError('Activate the signed-in account before queuing messages.');
    }
    if (!_outboxLoaded) await activateAccount(account);
  }

  void startPeriodicSync({Duration interval = const Duration(seconds: 30)}) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) {
      if (_isOnline && !_isSyncing) syncAll();
    });
  }

  void stopPeriodicSync() {
    _syncTimer?.cancel();
  }

  void setOnlineStatus(bool online) {
    if (_isOnline == online) return;
    _isOnline = online;
    notifyListeners();
    if (online) syncAll();
  }

  Future<void> syncAll({String? myUid}) async {
    if (_isSyncing || !_isOnline) return;
    _isSyncing = true;
    notifyListeners();
    try {
      await HybridDbService.getGlobalLastSync();
      if (myUid != null) await ApiService.getChats(myUid);
      _lastSyncTime = DateTime.now();
      await HybridDbService.setGlobalLastSync(_lastSyncTime!);
    } catch (error) {
      debugPrint('[NovynSync] Sync error: $error');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> syncChat(String chatId, String myUid) async {
    if (!_isOnline) return;
    try {
      await HybridDbService.getLastSync(chatId);
      final messages = await ApiService.getMessages(chatId, myUid: myUid);
      await HybridDbService.saveMessages(messages);
      await HybridDbService.setLastSync(chatId, DateTime.now());
    } catch (error) {
      debugPrint('[NovynSync] Chat sync error: $error');
    }
  }

  Future<void> addPendingMessage(PendingMessage message) async {
    await _ensureOutboxLoaded();
    if (message.accountId != _activeAccount) {
      throw StateError('The pending message belongs to a different account.');
    }
    final existing = _pendingMessages.indexWhere(
      (item) => item.tempId == message.tempId,
    );
    if (existing >= 0) {
      _pendingMessages[existing] = message;
    } else {
      if (_pendingMessages.length >= 1000) {
        throw StateError('The pending message queue is full.');
      }
      _pendingMessages.add(message);
    }
    _pendingMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    await _persistOutbox();
    notifyListeners();
  }

  Future<void> removePendingMessage(String tempId) async {
    await _ensureOutboxLoaded();
    final before = _pendingMessages.length;
    _pendingMessages.removeWhere((item) => item.tempId == tempId);
    if (_pendingMessages.length == before) return;
    await _persistOutbox();
    notifyListeners();
  }

  Future<void> _replacePendingMessage(PendingMessage updated) async {
    final index = _pendingMessages.indexWhere(
      (item) => item.tempId == updated.tempId,
    );
    if (index < 0) return;
    _pendingMessages[index] = updated;
    await _persistOutbox();
    notifyListeners();
  }

  Future<void> _persistOutbox() {
    final account = _activeAccount;
    if (account == null) {
      return Future<void>.error(
        StateError('No account is active for the pending message outbox.'),
      );
    }
    final snapshot = _pendingMessages.map((item) => item.toJson()).toList();
    final write = _storageWriteQueue
        .catchError((Object _) {})
        .then((_) async {
          if (_activeAccount != account) return;
          await LocalDbService.savePendingMessages(account, snapshot);
        });
    _storageWriteQueue = write;
    return write;
  }

  /// Send queued messages FIFO. Only a positive server acknowledgement removes
  /// an item. Permanent server rejections are removed and surfaced to the UI;
  /// transient errors stay queued and stop this pass.
  Future<void> flushPendingMessages(
    PendingMessageSender sender, {
    PendingMessageFailureHandler? onRejected,
  }) async {
    if (_flushFuture != null) return _flushFuture!;
    final task = _flushOutbox(sender, onRejected: onRejected);
    _flushFuture = task;
    try {
      await task;
    } finally {
      if (identical(_flushFuture, task)) _flushFuture = null;
    }
  }

  Future<void> _flushOutbox(
    PendingMessageSender sender, {
    PendingMessageFailureHandler? onRejected,
  }) async {
    await _ensureOutboxLoaded();
    final account = _activeAccount;
    if (!_isOnline || account == null || _pendingMessages.isEmpty) return;

    final snapshot = List<PendingMessage>.from(_pendingMessages)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final pending in snapshot) {
      if (!_isOnline || _activeAccount != account) break;
      if (pending.accountId != account ||
          !_pendingMessages.any((item) => item.tempId == pending.tempId)) {
        continue;
      }
      try {
        await sender(pending);
        if (_activeAccount != account) break;
        await removePendingMessage(pending.tempId);
      } on PendingMessageRejectedException catch (error) {
        if (_activeAccount != account) break;
        await removePendingMessage(pending.tempId);
        onRejected?.call(pending, error.message);
      } catch (error) {
        if (_activeAccount != account) break;
        await _replacePendingMessage(
          pending.copyWith(
            attemptCount: pending.attemptCount + 1,
            lastError: error.toString(),
          ),
        );
        debugPrint('[NovynOutbox] Will retry ' + pending.tempId + ': ' + error.toString());
break;
      }
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}

/// Plain-text local outbox record. Encryption is performed only immediately
/// before a direct message is sent over an authenticated socket.
class PendingMessage {
  final String accountId;
  final String tempId;
  final String text;
  final String receiverId;
  final String chatId;
  final DateTime createdAt;
  final String? replyToId;
  final String? replyToText;
  final String? replyToSender;
  final bool isGroup;
  final Map<String, dynamic>? attachment;
  final int attemptCount;
  final String? lastError;

  PendingMessage({
    required this.accountId,
    required this.tempId,
    required this.text,
    required this.receiverId,
    required this.chatId,
    required this.createdAt,
    this.replyToId,
    this.replyToText,
    this.replyToSender,
    this.isGroup = false,
    this.attachment,
    this.attemptCount = 0,
    this.lastError,
  });

  PendingMessage copyWith({int? attemptCount, String? lastError}) =>
      PendingMessage(
        accountId: accountId,
        tempId: tempId,
        text: text,
        receiverId: receiverId,
        chatId: chatId,
        createdAt: createdAt,
        replyToId: replyToId,
        replyToText: replyToText,
        replyToSender: replyToSender,
        isGroup: isGroup,
        attachment: attachment,
        attemptCount: attemptCount ?? this.attemptCount,
        lastError: lastError ?? this.lastError,
      );

  Map<String, dynamic> toJson() => {
    'accountId': accountId,
    'tempId': tempId,
    'text': text,
    'receiverId': receiverId,
    'chatId': chatId,
    'createdAt': createdAt.toIso8601String(),
    'replyToId': replyToId,
    'replyToText': replyToText,
    'replyToSender': replyToSender,
    'isGroup': isGroup,
    'attachment': attachment,
    'attemptCount': attemptCount,
    'lastError': lastError,
  };

  factory PendingMessage.fromJson(Map<String, dynamic> json) {
    final accountId = json['accountId']?.toString().trim().toLowerCase() ?? '';
    final tempId = json['tempId']?.toString() ?? '';
    final text = json['text']?.toString() ?? '';
    final receiverId = json['receiverId']?.toString() ?? '';
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    if (accountId.isEmpty || tempId.isEmpty ||
        receiverId.isEmpty || createdAt == null) {
      throw const FormatException('Invalid pending message record.');
    }
    final rawAttachment = json['attachment'];
    return PendingMessage(
      accountId: accountId,
      tempId: tempId,
      text: text,
      receiverId: receiverId,
      chatId: json['chatId']?.toString() ?? receiverId,
      createdAt: createdAt,
      replyToId: json['replyToId']?.toString(),
      replyToText: json['replyToText']?.toString(),
      replyToSender: json['replyToSender']?.toString(),
      isGroup: json['isGroup'] == true,
      attachment: rawAttachment is Map
          ? Map<String, dynamic>.from(rawAttachment)
          : null,
      attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
      lastError: json['lastError']?.toString(),
    );
  }
}
