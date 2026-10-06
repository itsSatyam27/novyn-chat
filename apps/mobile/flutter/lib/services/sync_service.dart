import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'hybrid_db_service.dart';

/// Background sync service for fetching new messages and syncing data
class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  Timer? _syncTimer;
  bool _isSyncing = false;
  bool _isOnline = true;
  DateTime? _lastSyncTime;

  // Pending messages queue (to send when back online)
  final List<PendingMessage> _pendingMessages = [];

  bool get isSyncing => _isSyncing;
  bool get isOnline => _isOnline;
  DateTime? get lastSyncTime => _lastSyncTime;
  List<PendingMessage> get pendingMessages => List.unmodifiable(_pendingMessages);

  /// Start periodic background sync (every 30 seconds)
  void startPeriodicSync({Duration interval = const Duration(seconds: 30)}) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(interval, (_) {
      if (_isOnline && !_isSyncing) {
        syncAll();
      }
    });
  }

  /// Stop periodic sync
  void stopPeriodicSync() {
    _syncTimer?.cancel();
  }

  /// Set online/offline status
  void setOnlineStatus(bool online) {
    if (_isOnline != online) {
      _isOnline = online;
      notifyListeners();
      
      // If back online, sync immediately and send pending messages
      if (online) {
        syncAll();
        _sendPendingMessages();
      }
    }
  }

  /// Sync all chats and messages (incremental)
  Future<void> syncAll({String? myUid}) async {
    if (_isSyncing || !_isOnline) return;

    _isSyncing = true;
    notifyListeners();

    try {
      // Get last global sync time
      final _ = await HybridDbService.getGlobalLastSync();
      
      // Fetch chats (always fetch to get unread counts)
      if (myUid != null) {
        final _ = await ApiService.getChats(myUid);
        // Process and save chats...
        // (This would be more complex in production)
      }

      _lastSyncTime = DateTime.now();
      await HybridDbService.setGlobalLastSync(_lastSyncTime!);
    } catch (e) {
      print('Sync error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Sync a specific chat (incremental)
  Future<void> syncChat(String chatId, String myUid) async {
    if (!_isOnline) return;

    try {
      // Get last sync time for this chat
      final _ = await HybridDbService.getLastSync(chatId);
      
      // Fetch only new messages (after lastSync)
      final messages = await ApiService.getMessages(
        chatId,
        myUid: myUid,
        // In production, you'd add a 'after' parameter to API
      );

      // Save to local database
      await HybridDbService.saveMessages(messages);
      await HybridDbService.setLastSync(chatId, DateTime.now());
    } catch (e) {
      print('Chat sync error: $e');
    }
  }

  /// Add message to pending queue (for offline sending)
  void addPendingMessage(PendingMessage message) {
    _pendingMessages.add(message);
    _savePendingMessages();
    notifyListeners();
  }

  /// Remove message from pending queue
  void removePendingMessage(String tempId) {
    _pendingMessages.removeWhere((m) => m.tempId == tempId);
    _savePendingMessages();
    notifyListeners();
  }

  /// Send all pending messages
  Future<void> _sendPendingMessages() async {
    if (_pendingMessages.isEmpty || !_isOnline) return;

    final toSend = List<PendingMessage>.from(_pendingMessages);
    
    for (final pending in toSend) {
      try {
        // Send via socket service
        // (In production, you'd inject SocketService)
        // socket.sendMessage(pending.text, pending.receiverId, ...);
        
        // Remove from queue on success
        removePendingMessage(pending.tempId);
      } catch (e) {
        print('Failed to send pending message: $e');
        // Keep in queue, will retry next time
      }
    }
  }

  /// Save pending messages to local storage
  Future<void> _savePendingMessages() async {
    // Save to Hive metadata box
    final _ = _pendingMessages.map((m) => m.toJson()).toList();
    // await LocalDbService.savePendingMessages(data);
  }

  /// Load pending messages from local storage
  Future<void> loadPendingMessages() async {
    // Load from Hive metadata box
    // final data = await LocalDbService.getPendingMessages();
    // _pendingMessages.addAll(data.map((d) => PendingMessage.fromJson(d)));
    notifyListeners();
  }

  /// Dispose
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }
}

/// Pending message model (for offline queue)
class PendingMessage {
  final String tempId;
  final String text;
  final String receiverId;
  final String chatId;
  final DateTime createdAt;
  final String? replyToId;
  final String? replyToText;
  final String? replyToSender;

  PendingMessage({
    required this.tempId,
    required this.text,
    required this.receiverId,
    required this.chatId,
    required this.createdAt,
    this.replyToId,
    this.replyToText,
    this.replyToSender,
  });

  Map<String, dynamic> toJson() => {
    'tempId': tempId,
    'text': text,
    'receiverId': receiverId,
    'chatId': chatId,
    'createdAt': createdAt.toIso8601String(),
    'replyToId': replyToId,
    'replyToText': replyToText,
    'replyToSender': replyToSender,
  };

  factory PendingMessage.fromJson(Map<String, dynamic> json) => PendingMessage(
    tempId: json['tempId'],
    text: json['text'],
    receiverId: json['receiverId'],
    chatId: json['chatId'],
    createdAt: DateTime.parse(json['createdAt']),
    replyToId: json['replyToId'],
    replyToText: json['replyToText'],
    replyToSender: json['replyToSender'],
  );
}
