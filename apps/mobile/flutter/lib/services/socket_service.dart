import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:collection';
import '../models/chat_models.dart';
import '../models/chat_preview.dart';
import '../models/user_model.dart';
import 'hybrid_db_service.dart';
import 'api_service.dart';
import 'media_storage_service.dart';
import 'backend_contacts.dart';
import 'message_encryption_service.dart';
import '../utils/message_pagination.dart';
import 'security_service.dart';
import 'sync_service.dart';
import 'settings_service.dart';

/// Socket service for the shared novyn-chat backend (server.js).
///
/// Event vocabulary (novyn-chat):
///   EMIT  resume_session           — authenticate socket after connect
///   EMIT  set_active_chat          — { to, kind }
///   EMIT  get_history              — { to, kind }
///   EMIT  private_message          — { to, toType, text, attachment?, replyTo?, clientTempId, ciphertext?, iv?, isEncrypted? }
///   EMIT  typing                   — { to, isTyping, toType }
///   EMIT  voice_activity           — { to, isSpeaking, toType }
///   EMIT  edit_message             — { messageId, text, to }
///   EMIT  unsend_message           — { messageId, to }
///   EMIT  add_reaction             — { messageId, emoji, to, toType }
///   EMIT  remove_reaction          — { messageId, to, toType }
///   EMIT  add_friend               — username string
///   EMIT  accept_friend            — username string
///   EMIT  reject_friend            — username string
///   EMIT  call_invite              — { to, isVideo }
///   EMIT  call_accept              — { to }
///   EMIT  call_start                — { to, isVideo, callId }
///   EMIT  call_accept               — { to, callId }
///   EMIT  call_end                  — { to, callId, reason? }
///   EMIT  webrtc_signal            — { to, signal }
///
///   ON    init                     — { friends, requests }
///   ON    friend_list / friend_list_updated
///   ON    requests_updated
///   ON    history                  — { with, messages[], wallpaper? }
///   ON    private_message          — incoming message
///   ON    message_status           — { id, deliveredAt?, seenAt? }
///   ON    message_unsent           — { messageId }
///   ON    message_edited           — { messageId, text }
///   ON    reaction_updated         — { messageId, reactions }
///   ON    typing                   — { from, isTyping }
///   ON    voice_activity           — { from, isSpeaking, toType, to? }
///   ON    user_status              — { username, online, presence, lastSeenAt }
///   ON    call_incoming            — { from, fromDisplayName, isVideo }
///   ON    call_accepted
///   ON    call_rejected
///   ON    call_ended
///   ON    webrtc_signal            — { from, signal }
///   ON    profile_updated
///   ON    friend_request_received  — { from }
///   ON    friend_request_accepted  — { by }
///   ON    friend_removed           — { username }
///   ON    error_message            — { message }

typedef IncomingMessageCallback = void Function(
  String sender,
  String body,
  bool isGroup,
  bool mentionOrReply,
);

class SocketService extends ChangeNotifier {
  SocketService({bool initialStealthModeEnabled = false})
      : _stealthModePreference = initialStealthModeEnabled;

  bool _stealthModePreference;
  bool _stealthPreferenceSynced = false;
  // Uses the same ECDH P-256 + AES-GCM-256 wire format as the web client.
  final encryption = MessageEncryptionService();
  Future<void>? _identityRegistration;
  Future<void>? _outboxActivation;
  String? _registeredIdentityAccount;
  Future<bool> Function()? restoreSessionForRecovery;
  bool _isAuthenticated = false;
  bool _hasLoadedConversations = false;
  Completer<void>? _authenticationReady;
  Completer<bool>? _olderHistoryCompleter;
  String? _olderHistoryTarget;
  Completer<List<Message>>? _chatHistoryCompleter;
  String? _chatHistoryTarget;
  VoidCallback? onAuthenticated;
  final Map<String, String> _peerKeys = {};
  final Map<String, Future<String>> _inFlightMessageDecryptions = {};
  final BackendContacts contacts = BackendContacts();
  io.Socket? _socket;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _manualDisconnect = false;
  bool _refreshingSocketSession = false;
  String? _socketSessionCookie;
  Timer? _socketAuthRetryTimer;
  int _socketAuthRetryAttempt = 0;
  bool _appForeground = true;
  String? _myUsername; // novyn-chat username (not Firebase UID)
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Map<String, String> _messageStatuses = {};
  int _messageStatusRevision = 0;
  final Map<String, DateTime> _messageDeliveredAt = {};
  final Map<String, DateTime> _messageSeenAt = {};
  final Set<String> _recentOwnMessageEchoIds = <String>{};
  int get messageStatusRevision => _messageStatusRevision;
  String messageStatusFor(String messageId) =>
      _messageStatuses[messageId] ?? 'sent';
  DateTime? messageDeliveredAtFor(String messageId) =>
      _messageDeliveredAt[messageId];
  DateTime? messageSeenAtFor(String messageId) => _messageSeenAt[messageId];

  String? messageFailureReasonFor(String messageId) {
    for (final pending in SyncService().pendingMessages) {
      if (pending.tempId == messageId && pending.isFailed) {
        return pending.lastError;
      }
    }
    return null;
  }

  Future<void> _restorePersistedMessageStatuses(String chatId) async {
    final saved = await HybridDbService.getMessageStatuses(chatId);
    if (_currentChatWith?.toLowerCase() != chatId.toLowerCase()) return;
    var changed = false;
    const rank = {'sent': 1, 'delivered': 2, 'seen': 3};
    for (final entry in saved.entries) {
      final savedStatus = entry.value['status']?.toString();
      if (!rank.containsKey(savedStatus)) continue;
      final current = _messageStatuses[entry.key];
      if (current == 'failed' || current == 'sending') continue;
      if ((rank[savedStatus] ?? 0) > (rank[current] ?? 0)) {
        _messageStatuses[entry.key] = savedStatus!;
        final delivered = DateTime.tryParse(
          entry.value['deliveredAt']?.toString() ?? '',
        );
        final seen = DateTime.tryParse(
          entry.value['seenAt']?.toString() ?? '',
        );
        if (delivered != null) _messageDeliveredAt[entry.key] = delivered;
        if (seen != null) _messageSeenAt[entry.key] = seen;
        changed = true;
      }
    }
    if (changed) {
      _messageStatusRevision++;
      notifyListeners();
    }
  }

  Future<void> _persistMessageStatus(String messageId) async {
    final message = await HybridDbService.getMessageById(messageId);
    if (message == null || !message.isFromMe || message.chatId.isEmpty) return;
    await HybridDbService.saveMessageStatuses(message.chatId, {
      messageId: {
        'status': _messageStatuses[messageId] ?? 'sent',
        'deliveredAt': _messageDeliveredAt[messageId]?.toIso8601String(),
        'seenAt': _messageSeenAt[messageId]?.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      },
    });
  }

  void _captureMessageStatusTimes(String id, Map data) {
    final delivered = DateTime.tryParse(data['deliveredAt']?.toString() ?? '');
    final seen = DateTime.tryParse(data['seenAt']?.toString() ?? '');
    if (delivered != null) _messageDeliveredAt[id] = delivered.toLocal();
    if (seen != null) _messageSeenAt[id] = seen.toLocal();
  }

  Future<Message> _decryptMessageOnce(
    Message message,
    String account,
    String? peerPublicKey,
  ) async {
    if (!encryption.needsDecryption(message)) return message;

    final key = [
      account.trim().toLowerCase(),
      message.chatId.trim().toLowerCase(),
      message.id,
      message.iv ?? '',
      message.ciphertext ?? '',
      peerPublicKey ?? '',
    ].join('\u0000');
    // Share only the plaintext result. Each caller keeps its own Message
    // object and therefore preserves its own latest reactions/attachments
    // and other metadata from the corresponding history/live event.
    final pending = _inFlightMessageDecryptions.putIfAbsent(
      key,
      () => encryption
          .decrypt(message, account, peerPublicKey)
          .then((decrypted) => decrypted.text),
    );

    try {
      final clearText = await pending;
      return clearText == message.text
          ? message
          : message.copyWith(text: clearText);
    } finally {
      if (identical(_inFlightMessageDecryptions[key], pending)) {
        _inFlightMessageDecryptions.remove(key);
      }
    }
  }

  // Reconnection state
  String? _serverUrl;
  Timer? _reconnectTimer;
  int _transportReconnectAttempt = 0;
  Timer? _pendingOutboxRetryTimer;

  // Messages for the currently open chat (immutable list — replaced on update)
  List<Message> _messages = [];
  List<Message>? _messagesViewSource;
  UnmodifiableListView<Message>? _messagesView;
  String? _currentChatWith; // username for DMs or group ID for group chats
  bool _currentChatIsGroup = false;
  bool _activeChatCaptureProtected = false;
  String _chatWallpaper = '';
  String get chatWallpaper => _chatWallpaper;

  // Typing
  bool _peerIsTyping = false;
  bool _peerIsRecordingVoice = false;
  final Map<String, Set<String>> _voiceUsersInChats = {};
  String? _voiceActivityTargetKey;
  String? _voiceActivityTargetUsername;
  bool _voiceActivityTargetIsGroup = false;
  Timer? _typingStopTimer;
  String? _typingTargetKey;
  String? _typingTargetUsername;
  bool _typingTargetIsGroup = false;

  // Typing across other chats: peerUsername → true
  final Map<String, bool> _typingInChats = {};
  final Map<String, Map<String, String>> _typingUsersInChats = {};
  Map<String, bool> get typingInChats => Map.unmodifiable(_typingInChats);

  String typingUsersSignature(String conversationKey) {
    final users = _typingUsersInChats[conversationKey.toLowerCase()];
    if (users == null || users.isEmpty) return '';
    final names = users.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names.join('\u0000');
  }

  // Conversations list (mirrors novyn-chat's friend_list)
  List<ChatPreview> _conversations = [];
  List<ChatPreview> get conversations => List.unmodifiable(_conversations);
  Map<String, dynamic>? _latestGroupInfo;
  Map<String, dynamic>? get latestGroupInfo => _latestGroupInfo == null
      ? null
      : Map<String, dynamic>.from(_latestGroupInfo!);
  List<String> _blockedUsers = [];
  final Set<String> _hiddenChatUsernames = <String>{};
  List<String> get blockedUsers => List.unmodifiable(_blockedUsers);
  Set<String> get hiddenChatUsernames => Set.unmodifiable(_hiddenChatUsernames);

  // Call event callbacks
  Function(Map)? onRandomMatchFound;
  Function(Map)? onRandomMatchTimeout;
  Function(Map)? onRandomGameUpdated;
  Function(Map)? onGameInviteAccepted;
  Function(Map)? onGameInviteTimeout;
  Function(Map)? onRajaMantriMatchFound;
  Function(Map)? onRajaMantriMatchProgress;
  Function(Map)? onRajaMantriMatchTimeout;
  Function(Map)? onRajaMantriGameUpdated;
  Function(Map)? onRajaMantriRoomStarted;
  Function(Map)? onRajaMantriGameAbandoned;
  final Map<String, Map<String, dynamic>> _rajaMantriGames = <String, Map<String, dynamic>>{};
  final Map<String, String> _rajaMantriInviteSessions = <String, String>{};
  final Set<String> _rajaMantriExpiredInvites = <String>{};
  final Map<String, Map<String, dynamic>> _randomGames = <String, Map<String, dynamic>>{};
  // Game moves can arrive before the corresponding chat history page.
  final Map<String, Map<String, dynamic>> _pendingGameUpdates =
      <String, Map<String, dynamic>>{};
  Function(Map)? onCallInviteCallback;
  Function(Map)? onCallAcceptedCallback;
  Function()? onCallRejectedCallback;
  Function(Map)? onCallEndedCallback;
  Function(Map)? onCallMediaUpgradeRequestCallback;
  Function(Map)? onCallMediaUpgradeResponseCallback;
  Function(Map)? onCallScreenShareChangedCallback;
  Function(Map)? onWebRTCSignalCallback;

  // Status and foreground message callbacks
  Function(String username, bool isOnline)? onUserStatusChanged;
  IncomingMessageCallback? onIncomingMessage;
  VoidCallback? onConnected;

  // Cache the read-only view while the immutable backing list is unchanged.
  // List.unmodifiable(_messages) copied the entire history on every read,
  // which became expensive as conversations grew.
  List<Message> get messages {
    if (!identical(_messagesViewSource, _messages)) {
      _messagesViewSource = _messages;
      _messagesView = UnmodifiableListView<Message>(_messages);
    }
    return _messagesView!;
  }

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  bool get isAuthenticated => _isAuthenticated;
  bool get hasLoadedConversations => _hasLoadedConversations;
  bool get peerIsTyping => _peerIsTyping;
  bool get peerIsRecordingVoice => _peerIsRecordingVoice;
  String? get currentChatWith => _currentChatWith;
  bool get activeChatCaptureProtected => _activeChatCaptureProtected;
  String? get myUsername => _myUsername;

  Map<String, dynamic>? randomGameFor(String sessionId) {
    final game = _randomGames[sessionId];
    return game == null ? null : Map<String, dynamic>.from(game);
  }

  // ── Connect ───────────────────────────────────────────────────────────────
  /// Rebuild the socket handshake after the REST session cookie rotates.
  /// The server binds each socket to the session ID used at connect time.
  Future<void> reconnectWithCurrentSession() async {
    final username = _myUsername;
    final serverUrl = _serverUrl;
    final currentCookie = ApiService.sessionCookie;
    if (username == null ||
        username.isEmpty ||
        serverUrl == null ||
        serverUrl.isEmpty) {
      return;
    }
    // Auth refresh and connectivity recovery can both request a reconnect.
    // Avoid replacing a socket that is already handshaking/authenticated with
    // the same session cookie.
    if ((_isConnecting || (_isConnected && _isAuthenticated)) &&
        _socketSessionCookie == currentCookie) {
      return;
    }
    // Refresh only the transport. Keep the in-memory chat, contacts and
    // active-conversation state intact while the session cookie is rotated.
    _socketAuthRetryTimer?.cancel();
    _socketAuthRetryTimer = null;
    _socketAuthRetryAttempt = 0;
    _reconnectTimer?.cancel();
    _isConnected = false;
    _isConnecting = false;
    _isAuthenticated = false;
    _authenticationReady = null;
    _registeredIdentityAccount = null;
    notifyListeners();
    _doConnect();
  }

  Duration _nextSocketAuthRetryDelay() {
    const delays = <Duration>[
      Duration(seconds: 3),
      Duration(seconds: 8),
      Duration(seconds: 20),
      Duration(seconds: 45),
    ];
    final index = _socketAuthRetryAttempt < delays.length
        ? _socketAuthRetryAttempt
        : delays.length - 1;
    if (_socketAuthRetryAttempt < delays.length - 1) {
      _socketAuthRetryAttempt++;
    }
    return delays[index];
  }

  void _scheduleSocketAuthRecovery({Duration delay = Duration.zero}) {
    if (_manualDisconnect || _isAuthenticated || _refreshingSocketSession)
      return;
    if (_socketAuthRetryTimer?.isActive == true) return;
    _socketAuthRetryTimer = Timer(delay, () {
      _socketAuthRetryTimer = null;
      unawaited(_refreshAfterSocketAuthFailure());
    });
  }

  Future<void> _refreshAfterSocketAuthFailure() async {
    if (_refreshingSocketSession || _manualDisconnect || _isAuthenticated)
      return;
    _refreshingSocketSession = true;
    var retryAfterTransientFailure = false;
    try {
      final restore = restoreSessionForRecovery;
      if (restore != null) {
        final restored = await restore()
            .timeout(const Duration(seconds: 32), onTimeout: () => false);
        if (_manualDisconnect || _isAuthenticated) return;
        if (restored && ApiService.hasAccessSessionCookie) {
          await reconnectWithCurrentSession();
          return;
        }
        // AuthService owns definitive expiry decisions. A failed restore can
        // also mean offline/timeout, so keep the local account and retry.
        retryAfterTransientFailure = true;
      } else {
        final status = await ApiService.refreshSessionStatus()
            .timeout(const Duration(seconds: 12), onTimeout: () => null);
        if (_manualDisconnect || _isAuthenticated) return;
        if (status == 200) {
          await reconnectWithCurrentSession();
          return;
        }

        // A rejected refresh token is a definitive sign-in requirement. Network,
        // rate-limit and server failures are not: keep the local account and
        // retry with bounded backoff rather than leaving a connected dead socket.
        retryAfterTransientFailure = status == null ||
            status == 401 ||
            status == 403 ||
            status == 429 ||
            (status != null && status >= 500);
      }
    } catch (error) {
      debugPrint(
          '[NovynSocket] Session refresh after auth failure failed: $error');
      retryAfterTransientFailure = true;
    } finally {
      _refreshingSocketSession = false;
    }

    if (retryAfterTransientFailure && !_manualDisconnect && !_isAuthenticated) {
      _scheduleSocketAuthRecovery(delay: _nextSocketAuthRetryDelay());
    }
  }

  void connect(String serverUrl, String username) {
    _manualDisconnect = false;
    if (_socket != null &&
        _myUsername != null &&
        _myUsername!.toLowerCase() != username.toLowerCase()) {
      disconnect();
    }
    _serverUrl = serverUrl;
    _myUsername = username;
    _outboxActivation = _activatePendingMessageOutbox(username);
    unawaited(_outboxActivation!.catchError((error) {
      debugPrint('[NovynOutbox] Could not restore pending messages: $error');
    }));
    if ((_socket != null && _socket!.connected && _isConnected) ||
        _isConnecting) return;
    _doConnect();
  }

  Future<void> _activatePendingMessageOutbox(String username) async {
    await SyncService().activateAccount(username);
    if (_myUsername?.toLowerCase() != username.trim().toLowerCase()) return;
    for (final pending in SyncService().pendingMessages) {
      _messageStatuses[pending.tempId] =
          pending.isFailed ? 'failed' : 'sending';
    }
    _restorePendingMessagesForOpenChat();
    notifyListeners();
  }

  /// Rebuild optimistic bubbles from the durable queue after process restart.
  void _restorePendingMessagesForOpenChat() {
    final peer = _currentChatWith;
    if (peer == null) return;

    final existingIds = _messages.map((message) => message.id).toSet();
    final restored = SyncService()
        .pendingMessages
        .where((pending) =>
            pending.isGroup == _currentChatIsGroup &&
            pending.chatId.toLowerCase() == peer.toLowerCase() &&
            !existingIds.contains(pending.tempId))
        .map((pending) {
      _messageStatuses[pending.tempId] =
          pending.isFailed ? 'failed' : 'sending';
      return pending.toLocalMessage();
    }).toList(growable: false);
    if (restored.isEmpty) return;

    _messages = [..._messages, ...restored]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    unawaited(HybridDbService.saveMessages(restored));
    notifyListeners();
  }

  Future<void> _flushPendingMessageOutbox() async {
    final account = _myUsername;
    if (account == null || !_isConnected || !_isAuthenticated) return;
    try {
      await (_outboxActivation ?? SyncService().activateAccount(account));
      if (_myUsername != account || !_isConnected || !_isAuthenticated) return;
      await SyncService().flushPendingMessages(
        _sendPendingMessage,
        onRejected: (pending, reason) {
          _messageStatuses[pending.tempId] = 'failed';
          _messageStatusRevision++;
          debugPrint(
              '[NovynOutbox] Message ${pending.tempId} rejected: $reason');
          notifyListeners();
        },
      );
    } catch (error) {
      debugPrint('[NovynOutbox] Flush deferred: $error');
    }
  }

  void _startPendingOutboxRetry() {
    _pendingOutboxRetryTimer?.cancel();
    _pendingOutboxRetryTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) {
        if (!_isConnected ||
            !_isAuthenticated ||
            !SyncService().pendingMessages.any((message) => !message.isFailed)) {
          return;
        }
        unawaited(_flushPendingMessageOutbox());
      },
    );
  }

  void _stopPendingOutboxRetry() {
    _pendingOutboxRetryTimer?.cancel();
    _pendingOutboxRetryTimer = null;
  }

  Future<void> _sendPendingMessage(PendingMessage pending) async {
    final account = _myUsername;
    if (account == null || pending.accountId != account.trim().toLowerCase()) {
      throw const PendingMessageRejectedException(
        'The signed-in account changed before this message could be sent.',
      );
    }

    await _waitForSocketAuthentication();
    _requireConnection();
    final connection = _socket;
    if (connection == null || !_isConnected || !_isAuthenticated) {
      throw StateError('Novyn is reconnecting. The message remains queued.');
    }

    final payload = <String, dynamic>{
      'to': pending.receiverId,
      'toType': pending.isGroup ? 'group' : 'friend',
      'text': pending.text,
      'attachment': pending.attachment,
      'replyTo': pending.replyToId == null
          ? null
          : {
              'id': pending.replyToId,
              'text': pending.replyToText ?? '',
              'from': pending.replyToSender ?? '',
            },
      'clientTempId': pending.tempId,
    };

    if (!pending.isGroup) {
      if (pending.attachment != null && pending.attachment?['encrypted'] != true) {
        throw const PendingMessageRejectedException(
          'This attachment is not end-to-end encrypted. Please select it again and retry.',
        );
      }

      await _registerEncryptionIdentity();
      if (_registeredIdentityAccount != account.toLowerCase()) {
        throw StateError('Secure identity registration is pending.');
      }

      // A contact may have re-created their E2EE identity while this
      // device was offline. The in-memory peer-key cache can then point to
      // the old public key, producing ciphertext the recipient can no longer
      // decrypt. Resolve the authoritative key for every send; never fall
      // back to a stale cached key when the server has no current key.
      final keyReply = Completer<Map<String, dynamic>>();
      connection.emitWithAck(
        'get_public_key',
        {'username': pending.receiverId},
        ack: (dynamic result) {
          if (!keyReply.isCompleted) {
            keyReply.complete(result is Map
                ? Map<String, dynamic>.from(result)
                : <String, dynamic>{});
          }
        },
      );
      final keyResult = await keyReply.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () => <String, dynamic>{},
      );
      final peerPublicKey = keyResult['publicKey']?.toString() ?? '';
      if (peerPublicKey.isNotEmpty) {
        _peerKeys[pending.receiverId.toLowerCase()] = peerPublicKey;
      } else {
        _peerKeys.remove(pending.receiverId.toLowerCase());
      }
      if (peerPublicKey.isEmpty) {
        throw const PendingMessageDeferredException(
          'The contact encryption key is not available yet.',
        );
      }
      if (pending.attachment != null &&
          pending.attachment?['peerPublicKey'] != peerPublicKey) {
        throw const PendingMessageRejectedException(
          'The contact encryption key changed during upload. Please select the attachment again.',
        );
      }

      final encrypted = await encryption.encrypt(
        pending.text,
        account,
        pending.receiverId,
        peerPublicKey,
      );
      if (encrypted == null || encrypted['isEncrypted'] != true) {
        throw const PendingMessageDeferredException(
          'Message encryption could not complete with the current contact key.',
        );
      }
      if (pending.attachment != null &&
          pending.attachment?['senderPublicKey'] != encrypted['senderPublicKey']) {
        throw const PendingMessageRejectedException(
          'Your secure identity changed during upload. Please select the attachment again.',
        );
      }
      payload
        ..['text'] = '🔒 Encrypted message'
        ..['isEncrypted'] = true
        ..['ciphertext'] = encrypted['ciphertext']
        ..['iv'] = encrypted['iv']
        ..['senderPublicKey'] = encrypted['senderPublicKey'];
      if (payload['replyTo'] is Map) {
        (payload['replyTo'] as Map)['text'] = '🔒 Encrypted message';
      }
    }

    final acknowledgement = Completer<Map<String, dynamic>>();
    connection.emitWithAck('private_message', payload, ack: (dynamic result) {
      if (acknowledgement.isCompleted) return;
      acknowledgement.complete(
        result is Map
            ? Map<String, dynamic>.from(result)
            : <String, dynamic>{
                'ok': false,
                'message': 'Unexpected server response.'
              },
      );
    });

    final result = await acknowledgement.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException(
        'Delivery was not confirmed. Message remains queued for a safe retry.',
      ),
    );
    if (result['ok'] != true) {
      final rejection =
          result['message']?.toString() ?? 'The server rejected this message.';
      final normalizedRejection = rejection.toLowerCase();
      // Rate limits and expired sessions are temporary server conditions.
      // Keep these records queued rather than losing user text.
      if (normalizedRejection.contains('rate limit') ||
          normalizedRejection.contains('sign in again') ||
          normalizedRejection.contains('try again') ||
          normalizedRejection.contains('temporarily unavailable')) {
        throw StateError(rejection);
      }
      throw PendingMessageRejectedException(rejection);
    }

    final messageId = result['id']?.toString() ?? '';
    if (messageId.isEmpty) {
      throw StateError(
        'The server acknowledged the send without a message ID. Retrying safely.',
      );
    }
    if (_myUsername != account || _socket != connection) {
      throw StateError(
          'The account or connection changed after send acknowledgement.');
    }

    final acknowledged = Message(
      id: messageId,
      chatId: pending.chatId,
      text: pending.text,
      senderId: account,
      isFromMe: true,
      createdAt: pending.createdAt,
      replyToId: pending.replyToId,
      replyToText: pending.replyToText,
      replyToSender: pending.replyToSender,
      attachment: pending.attachment,
      isEncrypted: !pending.isGroup,
      ciphertext: payload['ciphertext']?.toString(),
      iv: payload['iv']?.toString(),
      senderPublicKey: payload['senderPublicKey']?.toString(),
    );
    final echoAlreadyReceived = _recentOwnMessageEchoIds.remove(messageId);
    if (!echoAlreadyReceived) {
      final optimisticIndex = _messages.indexWhere(
        (message) => message.id == pending.tempId,
      );
      if (optimisticIndex >= 0) {
        final updated = List<Message>.from(_messages);
        updated[optimisticIndex] = acknowledged;
        _messages = updated;
      }
      await HybridDbService.deleteMessage(pending.tempId);
      await HybridDbService.saveMessage(acknowledged);
      unawaited(_persistMessageStatus(messageId));
    }
    _messageStatuses.remove(pending.tempId);
    _messageStatuses.putIfAbsent(messageId, () => 'sent');
    _messageStatusRevision++;
    notifyListeners();
  }

  void _doConnect() {
    if (_manualDisconnect || _serverUrl == null || _myUsername == null) return;
    if (_isConnecting && _socket != null) return;

    // Dispose the previous transport before creating another one. Socket.IO
    // can invoke disconnect callbacks during disposal, so suppress reconnect
    // scheduling until the old listeners have been removed.
    final previousSocket = _socket;
    _socket = null;
    if (previousSocket != null) {
      final wasManualDisconnect = _manualDisconnect;
      _manualDisconnect = true;
      previousSocket.dispose();
      _manualDisconnect = wasManualDisconnect;
    }
    _isConnected = false;
    _isAuthenticated = false;
    _hasLoadedConversations = false;
    _authenticationReady = null;
    _registeredIdentityAccount = null;
    _reconnectTimer?.cancel();

    // novyn-chat authenticates via cookie on the HTTP handshake,
    // not via a query param. We pass the cookie in extraHeaders.
    final headers = <String, dynamic>{};
    if (ApiService.sessionCookie != null) {
      headers['Cookie'] = ApiService.sessionCookie!;
    }

    _socket = io.io(_serverUrl!, <String, dynamic>{
      'transports': ['websocket'],
      // A fresh Manager ensures rotated session cookies are used on resume.
      'forceNew': true,
      'autoConnect': false,
      'extraHeaders': headers,
      'reconnection': false, // manual reconnection
    });
    _socketSessionCookie = ApiService.sessionCookie;

    _socket!.onConnect((_) {
      _isConnecting = false;
      _isConnected = true;
      // A live WebSocket transport is not an authenticated Novyn session.
      // Mark this device online only after resume_session is accepted.
      SyncService().setOnlineStatus(false);
      _isAuthenticated = false;
      _stealthPreferenceSynced = false;
      _authenticationReady = Completer<void>();
      _registeredIdentityAccount = null;
      _reconnectTimer?.cancel();

      // novyn-chat requires resume_session after connect to authenticate
      // the socket and receive the initial friend_list + requests.
      _socket!.emit('resume_session');
      _socket!.emit('app_visibility', {'foreground': _appForeground});
      // Some backend restarts leave the transport open without returning
      // init/register_success or auth_failed. Bound that handshake and run
      // the same refresh/reconnect recovery used for explicit auth failures.
      _scheduleSocketAuthRecovery(delay: const Duration(seconds: 12));

      MediaStorageService.watchConnectivity();
      onConnected?.call();
      notifyListeners();
    });

    _socket!.onDisconnect((_) {
      _socketAuthRetryTimer?.cancel();
      _socketAuthRetryTimer = null;
      _stopPendingOutboxRetry();
      _isConnecting = false;
      _isConnected = false;
      _hasLoadedConversations = false;
      _voiceUsersInChats.clear();
      _peerIsRecordingVoice = false;
      SyncService().setOnlineStatus(false);
      _isAuthenticated = false;
      // A completed future from an old socket must never authenticate a new one.
      _authenticationReady = null;
      _registeredIdentityAccount = null;
      notifyListeners();
      if (!_manualDisconnect) _scheduleReconnect();
    });

    _socket!.onConnectError((_) {
      _socketAuthRetryTimer?.cancel();
      _socketAuthRetryTimer = null;
      _stopPendingOutboxRetry();
      _isConnecting = false;
      _isConnected = false;
      _voiceUsersInChats.clear();
      _peerIsRecordingVoice = false;
      SyncService().setOnlineStatus(false);
      _isAuthenticated = false;
      _authenticationReady = null;
      _registeredIdentityAccount = null;
      notifyListeners();
      if (!_manualDisconnect) _scheduleReconnect();
    });

    _registerEventHandlers();
    _socket!.on('auth_failed', (data) {
      _stopPendingOutboxRetry();
      _isAuthenticated = false;
      SyncService().setOnlineStatus(false);
      notifyListeners();
      // Socket.IO may stay transport-connected after resume_session fails.
      // Recover the HTTP session, then replace that unauthenticated transport.
      // Never clear the local account for a socket-only authentication failure.
      // The server explicitly rejected this socket session, so replace the
      // startup handshake watchdog with immediate REST refresh/re-auth.
      _socketAuthRetryTimer?.cancel();
      _socketAuthRetryTimer = null;
      _scheduleSocketAuthRecovery();
    });
    _isConnecting = true;
    notifyListeners();
    _socket!.connect();
  }

  void setAppForeground(bool foreground) {
    final changed = _appForeground != foreground;
    _appForeground = foreground;

    if (!foreground) {
      if (changed && _isConnected) {
        _socket?.emit('app_visibility', {'foreground': false});
      }
      return;
    }

    if (_manualDisconnect) return;

    // Android can suspend the app while the socket transport is being dropped.
    // Re-check the transport itself on every resume instead of trusting a
    // possibly stale local connection flag.
    if (_socket == null || (!_socket!.connected && !_isConnecting)) {
      _reconnectTimer?.cancel();
      _doConnect();
      return;
    }

    // A transport can be connected while resume_session is still rejected.
    // Do not treat that as healthy or emit account actions on it.
    if (_isConnected && !_isAuthenticated) {
      _scheduleSocketAuthRecovery();
      return;
    }

    if (changed && _isConnected && _isAuthenticated) {
      _socket?.emit('app_visibility', {'foreground': true});
    }
    if (_isConnected && _isAuthenticated) {
      _requestActiveChatRefresh();
      unawaited(_flushPendingMessageOutbox());
    }
  }

  void _requestActiveChatRefresh() {
    final peer = _currentChatWith;
    final connection = _socket;
    if (peer == null ||
        peer.isEmpty ||
        connection == null ||
        !_isConnected ||
        !_isAuthenticated) return;
    final kind = _currentChatIsGroup ? 'group' : 'friend';
    connection.emit('set_active_chat', {'to': peer, 'kind': kind});
    if (!_currentChatIsGroup) {
      connection.emit('get_chat_protection', {'to': peer});
    }
    connection.emit('get_history', {'to': peer, 'kind': kind, 'limit': 100});
    connection.emit('get_chat_wallpaper', {'to': peer, 'toType': kind});
  }

  Duration _nextTransportReconnectDelay() {
    const delays = <Duration>[
      Duration(seconds: 3),
      Duration(seconds: 5),
      Duration(seconds: 8),
      Duration(seconds: 13),
      Duration(seconds: 21),
      Duration(seconds: 30),
    ];
    final index = _transportReconnectAttempt < delays.length
        ? _transportReconnectAttempt
        : delays.length - 1;
    if (_transportReconnectAttempt < delays.length - 1) {
      _transportReconnectAttempt++;
    }
    return delays[index];
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_nextTransportReconnectDelay(), () {
      if (!_manualDisconnect && (_socket == null || !_socket!.connected)) {
        _doConnect();
      }
    });
  }

  // ── Register all incoming event handlers ─────────────────────────────────
  void _registerEventHandlers() {
    for (final event in [
      'register_success',
      'init',
      'friend_list',
      'friend_list_updated',
      'requests_updated',
      'discover_online',
      'friend_request_sent',
      'friend_request_cancelled',
      'user_status'
    ]) {
      _socket!.on(event, (data) => contacts.applyEvent(event, data));
    }
    _socket!.on('register_success', (data) {
      // Mark the accepted session first so a hiddenChats snapshot can be
      // applied by ChatsScreen immediately, before preview decryption awaits.
      _markSocketAuthenticated();
      if (data is Map) _handleFriendList(data);
      unawaited(_registerEncryptionIdentity()
          .then((_) => _flushPendingMessageOutbox()));
    });
    // ── Initial data + friend list ────────────────────────────────────────
    _socket!.on('init', (data) {
      _markSocketAuthenticated();
      if (data is Map && data['friends'] != null) {
        _handleFriendList(data);
      }
      unawaited(
        _registerEncryptionIdentity().then((_) => _flushPendingMessageOutbox()),
      );
    });

    _socket!.on('friend_list', (data) => _handleFriendList(data));
    _socket!.on('friend_list_updated', (data) => _handleFriendList(data));
    _socket!.on('hidden_chats_updated', (data) {
      if (data is! Map || data['hiddenChats'] is! List) return;
      _hiddenChatUsernames
        ..clear()
        ..addAll((data['hiddenChats'] as List)
            .map((value) => value.toString().trim().toLowerCase())
            .where((value) => value.isNotEmpty));
      notifyListeners();
    });
    _socket!.on('group_info', (data) {
      if (data is! Map || data['group'] is! Map) return;
      _latestGroupInfo = Map<String, dynamic>.from(data['group'] as Map);
      notifyListeners();
    });

    _socket!.on('safety_state_updated', (data) {
      if (data is! Map) return;
      final blocked = data['blocked'];
      if (blocked is List) {
        _blockedUsers = blocked
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList();
        notifyListeners();
      }
    });
    _socket!.on('chat_protection_updated', (data) {
      if (data is! Map || _currentChatWith == null) return;
      final username = data['username']?.toString() ?? '';
      if (username.toLowerCase() != _currentChatWith!.toLowerCase()) return;
      final protected = data['protected'] == true;
      _activeChatCaptureProtected = protected;
      unawaited(SecurityService.setSafeMode(protected));
    });
    _socket!.on('block_updated', (data) {
      if (data is! Map) return;
      final username = data['username']?.toString().trim() ?? '';
      if (username.isEmpty) return;
      final key = username.toLowerCase();
      _blockedUsers.removeWhere((value) => value.toLowerCase() == key);
      if (data['blocked'] == true) _blockedUsers.add(username);
      notifyListeners();
    });

    _socket!.on('peer_public_key_updated', (data) {
      if (data is Map) {
        final username = data['username']?.toString() ?? '';
        _peerKeys[username.toLowerCase()] = data['publicKey']?.toString() ?? '';
        if (_currentChatWith?.toLowerCase() == username.toLowerCase()) {
          unawaited(decryptCurrentMessages());
        }
        unawaited(_flushPendingMessageOutbox());
      }
    });

    // ── Chat history ──────────────────────────────────────────────────────
    _socket!.on('history', (data) async {
      if (data is! Map) return;
      final withUser = data['with']?.toString() ??
          data['withUser']?.toString() ??
          data['to']?.toString() ??
          '';
      final historyList = data['messages'];
      if (historyList is! List) return;

      if (_currentChatWith != null &&
          _currentChatWith!.toLowerCase() == withUser.toLowerCase()) {
        final parsed = historyList.map<Message>((m) {
          final sender = m['from']?.toString() ??
              m['sender']?.toString() ??
              m['fromKey']?.toString() ??
              '';
          return Message(
            id: m['id']?.toString() ??
                m['messageId']?.toString() ??
                DateTime.now().millisecondsSinceEpoch.toString(),
            chatId: withUser,
            text: m['text']?.toString() ?? '',
            isEncrypted: m['isEncrypted'] == true,
            ciphertext: m['ciphertext']?.toString(),
            iv: m['iv']?.toString(),
            senderPublicKey: m['senderPublicKey']?.toString(),
            senderId: sender,
            isFromMe: sender.toLowerCase() == _myUsername?.toLowerCase(),
            createdAt: DateTime.tryParse(m['timestamp']?.toString() ?? '') ??
                DateTime.now(),
            reactions: Message.parseReactions(m['reactions']),
            replyToId: m['replyTo']?['id']?.toString(),
            replyToText: m['replyTo']?['text']?.toString(),
            replyToSender: m['replyTo']?['from']?.toString(),
            edited: m['edited'] == true,
            attachment: m['attachment'] is Map
                ? Map<String, dynamic>.from(m['attachment'])
                : null,
            poll:
                m['poll'] is Map ? Map<String, dynamic>.from(m['poll']) : null,
            pinnedAt: m['pinnedAt']?.toString(),
            pinnedBy: m['pinnedBy']?.toString(),
            riddle: m['riddle'] is Map
                ? Map<String, dynamic>.from(m['riddle'])
                : null,
            game:
                m['game'] is Map ? Map<String, dynamic>.from(m['game']) : null,
          );
        }).toList();

        final account = _myUsername;
        if (account == null) return;
        final statusSnapshot = <String, Map<String, dynamic>>{};
        for (final raw in historyList) {
          if (raw is! Map) continue;
          final id =
              raw['id']?.toString() ?? raw['messageId']?.toString() ?? '';
          if (id.isEmpty) continue;
          _captureMessageStatusTimes(id, raw);
          final explicit = raw['status']?.toString().toLowerCase();
          final serverStatus = raw['seenAt'] != null || explicit == 'seen'
              ? 'seen'
              : raw['deliveredAt'] != null || explicit == 'delivered'
                  ? 'delivered'
                  : 'sent';
          const statusRank = {'sent': 1, 'delivered': 2, 'seen': 3};
          final currentStatus = _messageStatuses[id];
          final status = currentStatus == 'failed' ||
                  currentStatus == 'sending' ||
                  (statusRank[currentStatus] ?? 0) >
                      (statusRank[serverStatus] ?? 0)
              ? currentStatus!
              : serverStatus;
          _messageStatuses[id] = status;
          statusSnapshot[id] = {
            'status': status,
            'deliveredAt': raw['deliveredAt']?.toString(),
            'seenAt': raw['seenAt']?.toString(),
            'updatedAt': DateTime.now().toIso8601String(),
          };
        }
        if (statusSnapshot.isNotEmpty) {
          unawaited(HybridDbService.saveMessageStatuses(
            withUser,
            statusSnapshot,
          ));
        }
        _messageStatusRevision++;
        final decrypted = await Future.wait(parsed.map((message) {
          final peerKey = message.isFromMe
              ? _peerKeys[withUser.toLowerCase()]
              : (message.senderPublicKey?.isNotEmpty == true
                  ? message.senderPublicKey
                  : _peerKeys[withUser.toLowerCase()]);
          return _decryptMessageOnce(message, account, peerKey);
        }));
        if (_myUsername != account ||
            _currentChatWith?.toLowerCase() != withUser.toLowerCase()) {
          return;
        }
        final messageIdsBeforePage =
            _messages.map((message) => message.id).toSet();
        // Merge by message ID instead of replacing the local timeline with
        // only the server's latest page. This preserves older cached messages
        // and messages received while history was being decrypted.
        final merged = <String, Message>{
          for (final message in _messages)
            if (message.id.isNotEmpty) message.id: message,
        };
        for (final message in decrypted) {
          if (message.id.isNotEmpty) merged[message.id] = message;
        }
        // Apply any move events that arrived before this history response.
        for (final entry in _pendingGameUpdates.entries.toList()) {
          final existing = merged[entry.key];
          if (existing == null) continue;
          merged[entry.key] = existing.copyWith(game: entry.value);
          _pendingGameUpdates.remove(entry.key);
        }
        final timeline = merged.values.toList()
          ..sort(compareMessagesChronologically);
        _messages = _resolveReplyPreviews(timeline);
        HybridDbService.saveMessages(_messages);
        final olderRequest = _olderHistoryCompleter;
        if (olderRequest != null &&
            !olderRequest.isCompleted &&
            _olderHistoryTarget == withUser.trim().toLowerCase()) {
          final pageMadeProgress = parsed.any(
            (message) =>
                message.id.isNotEmpty &&
                !messageIdsBeforePage.contains(message.id),
          );
          olderRequest.complete(data['hasMore'] == true && pageMadeProgress);
        }
        notifyListeners();
        final pendingHistory = _chatHistoryCompleter;
        if (pendingHistory != null &&
            !pendingHistory.isCompleted &&
            _chatHistoryTarget == withUser.trim().toLowerCase()) {
          pendingHistory.complete(List<Message>.unmodifiable(_messages));
        }
      }
    });

    // ── Incoming / outgoing message ───────────────────────────────────────
    // novyn-chat uses 'private_message' for BOTH sending confirmation
    // and receiving from the other party.
    _socket!.on('private_message', (data) async {
      if (data is! Map) return;
      final sender =
          data['from']?.toString() ?? data['sender']?.toString() ?? '';
      final receiver =
          data['to']?.toString() ?? data['receiver']?.toString() ?? '';
      final clientTempId = data['clientTempId']?.toString();
      final msgId = data['id']?.toString() ??
          data['messageId']?.toString() ??
          clientTempId ??
          DateTime.now().millisecondsSinceEpoch.toString();

      final isOwn = sender.toLowerCase() == _myUsername?.toLowerCase();
      final isGroupMessage = data['toType']?.toString() == 'group';
      final chatPartner = isGroupMessage
          ? (data['groupId']?.toString() ??
              data['toKey']?.toString() ??
              receiver)
          : (isOwn ? receiver : sender);

      var msg = Message(
        id: msgId,
        chatId: chatPartner,
        text: data['text']?.toString() ?? '',
        isEncrypted: data['isEncrypted'] == true,
        ciphertext: data['ciphertext']?.toString(),
        iv: data['iv']?.toString(),
        senderPublicKey: data['senderPublicKey']?.toString(),
        senderId: sender,
        isFromMe: isOwn,
        createdAt: DateTime.tryParse(data['timestamp']?.toString() ?? '') ??
            DateTime.now(),
        reactions: {},
        replyToId: data['replyTo']?['id']?.toString(),
        replyToText: data['replyTo']?['text']?.toString(),
        replyToSender: data['replyTo']?['from']?.toString(),
        attachment: data['attachment'] is Map
            ? Map<String, dynamic>.from(data['attachment'])
            : null,
        poll: data['poll'] is Map
            ? Map<String, dynamic>.from(data['poll'])
            : null,
        pinnedAt: data['pinnedAt']?.toString(),
        pinnedBy: data['pinnedBy']?.toString(),
        riddle: data['riddle'] is Map
            ? Map<String, dynamic>.from(data['riddle'])
            : null,
        game: data['game'] is Map
            ? Map<String, dynamic>.from(data['game'])
            : null,
      );

      final account = _myUsername;
      if (account == null) return;
      if (!isGroupMessage) {
        final peerKey = isOwn
            ? _peerKeys[chatPartner.toLowerCase()]
            : (msg.senderPublicKey?.isNotEmpty == true
                ? msg.senderPublicKey
                : _peerKeys[chatPartner.toLowerCase()]);
        msg = await _decryptMessageOnce(msg, account, peerKey);
      }
      if (isOwn) {
        _recentOwnMessageEchoIds.add(msgId);
        if (_recentOwnMessageEchoIds.length > 200) {
          _recentOwnMessageEchoIds.remove(_recentOwnMessageEchoIds.first);
        }
        _captureMessageStatusTimes(msgId, data);
        final explicit = data['status']?.toString().toLowerCase();
        final receivedStatus = data['seenAt'] != null || explicit == 'seen'
            ? 'seen'
            : data['deliveredAt'] != null || explicit == 'delivered'
                ? 'delivered'
                : 'sent';
        const statusRank = {'sent': 1, 'delivered': 2, 'seen': 3};
        final currentStatus = _messageStatuses[msgId];
        _messageStatuses[msgId] = currentStatus == 'failed' ||
                currentStatus == 'sending' ||
                (statusRank[currentStatus] ?? 0) >
                    (statusRank[receivedStatus] ?? 0)
            ? currentStatus!
            : receivedStatus;
        _messageStatusRevision++;
      }
      if (_myUsername != account) return;

      // Reconcile the durable local outbox with the server echo. The same
      // clientTempId makes a late echo safe after an acknowledged retry.
      if (isOwn && clientTempId != null && clientTempId.isNotEmpty) {
        try {
          await SyncService().removePendingMessage(clientTempId);
        } catch (error) {
          // Keep local history rendering even if persisting the outbox removal
          // fails. The stable clientTempId makes a later retry idempotent.
          debugPrint('[NovynOutbox] Could not persist queue removal: $error');
        }
        await HybridDbService.deleteMessage(clientTempId);
      }
      // Save to local DB
      await HybridDbService.saveMessage(msg);
      if (isOwn) unawaited(_persistMessageStatus(msgId));
      if (!isOwn && msg.attachment != null) {
        unawaited(MediaStorageService.handleIncomingAttachment(
            msg.attachment, msg.id));
      }

      // Update the open chat message list
      if (_currentChatWith != null &&
          _currentChatWith!.toLowerCase() == chatPartner.toLowerCase()) {
        // Replace optimistic temp message if present
        final idx = clientTempId != null
            ? _messages.indexWhere((m) => m.id == clientTempId)
            : -1;
        if (idx != -1) {
          final updated = List<Message>.from(_messages);
          updated[idx] = msg;
          _messages = updated;
        } else {
          // Avoid duplicates
          if (!_messages.any((m) => m.id == msgId)) {
            _messages = [..._messages, msg];
          }
        }
      } else if (!isOwn) {
        final ownUsername = (_myUsername ?? '').trim().toLowerCase();
        final mentionOrReply = data['replyTo'] != null ||
            (ownUsername.isNotEmpty &&
                msg.text.toLowerCase().contains('@' + ownUsername));
        onIncomingMessage?.call(
          chatPartner,
          msg.text,
          isGroupMessage,
          mentionOrReply,
        );
        // Sound and vibration remain independent user preferences.
        if (!(notificationsMuted?.call(chatPartner) ?? false)) {
          unawaited(_playIncomingMessageSound());
        }
        final vibrate = notificationsVibrate;
        if (vibrate != null) unawaited(vibrate(chatPartner));
      }

      // Resolve encrypted reply metadata against locally decrypted originals.
      if (_currentChatWith?.toLowerCase() == chatPartner.toLowerCase()) {
        _messages = _resolveReplyPreviews(_messages);
        HybridDbService.saveMessages(_messages);
      }

      // Update conversations list preview
      _updateConversationPreview(
        chatPartner,
        msg.text,
        sender,
        msg.createdAt,
        isCurrentChat:
            _currentChatWith?.toLowerCase() == chatPartner.toLowerCase(),
      );

      notifyListeners();
    });

    _socket!.on('game_move_updated', (data) {
      if (data is! Map) return;
      final messageId = data['messageId']?.toString() ?? '';
      final rawGame = data['game'];
      if (messageId.isEmpty || rawGame is! Map) return;
      final index = _messages.indexWhere((message) => message.id == messageId);
      if (index == -1) {
        _pendingGameUpdates[messageId] = Map<String, dynamic>.from(rawGame);
        return;
      }
      final updated = List<Message>.from(_messages);
      updated[index] =
          updated[index].copyWith(game: Map<String, dynamic>.from(rawGame));
      _messages = updated;
      HybridDbService.saveMessage(updated[index]);
      notifyListeners();
    });

    _socket!.on('riddle_updated', (data) {
      if (data is! Map) return;
      final messageId =
          data['id']?.toString() ?? data['messageId']?.toString() ?? '';
      final rawRiddle = data['riddle'];
      if (messageId.isEmpty || rawRiddle is! Map) return;
      final index = _messages.indexWhere((message) => message.id == messageId);
      if (index == -1) return;
      final updated = List<Message>.from(_messages);
      updated[index] =
          updated[index].copyWith(riddle: Map<String, dynamic>.from(rawRiddle));
      _messages = updated;
      HybridDbService.saveMessage(updated[index]);
      notifyListeners();
    });

    _socket!.on('message_pinned', (data) {
      if (data is! Map) return;
      final id = data['messageId']?.toString() ?? '';
      final index = _messages.indexWhere((message) => message.id == id);
      if (index == -1) return;
      final updated = List<Message>.from(_messages);
      updated[index] = updated[index].copyWith(
        pinnedAt:
            data['pinnedAt']?.toString() ?? DateTime.now().toIso8601String(),
        pinnedBy: data['pinnedBy']?.toString() ?? '',
      );
      _messages = updated;
      HybridDbService.saveMessage(updated[index]);
      notifyListeners();
    });

    _socket!.on('message_unpinned', (data) {
      if (data is! Map) return;
      final id = data['messageId']?.toString() ?? '';
      final index = _messages.indexWhere((message) => message.id == id);
      if (index == -1) return;
      final updated = List<Message>.from(_messages);
      updated[index] = updated[index].copyWith(pinnedAt: '', pinnedBy: '');
      _messages = updated;
      HybridDbService.saveMessage(updated[index]);
      notifyListeners();
    });

    _socket!.on('chat_wallpaper_updated', (data) {
      if (data is! Map) return;
      final from = data['from']?.toString().toLowerCase() ?? '';
      final to = data['to']?.toString().toLowerCase() ?? '';
      final current = _currentChatWith?.toLowerCase();
      if (current != null && (current == from || current == to)) {
        _chatWallpaper = data['wallpaper']?.toString() ?? '';
        notifyListeners();
      }
    });

    _socket!.on('poll_updated', (data) {
      if (data is! Map) return;
      final messageId = data['messageId']?.toString() ?? '';
      final rawPoll = data['poll'];
      if (messageId.isEmpty || rawPoll is! Map) return;
      final index = _messages.indexWhere((message) => message.id == messageId);
      if (index == -1) return;
      final updated = List<Message>.from(_messages);
      updated[index] = updated[index].copyWith(
        poll: Map<String, dynamic>.from(rawPoll),
      );
      _messages = updated;
      HybridDbService.saveMessage(updated[index]);
      notifyListeners();
    });

    // ── Message status (delivered / seen) ──────────────────────────────────
    _socket!.on('message_status', (data) {
      if (data is! Map) return;
      final msgId =
          data['id']?.toString() ?? data['messageId']?.toString() ?? '';
      if (msgId.isEmpty) return;
      _captureMessageStatusTimes(msgId, data);
      final explicit = data['status']?.toString().toLowerCase();
      final next =
          data['seenAt'] != null || explicit == 'seen' || explicit == 'read'
              ? 'seen'
              : data['deliveredAt'] != null || explicit == 'delivered'
                  ? 'delivered'
                  : null;
      if (next == null) return;
      final current = _messageStatuses[msgId] ?? 'sent';
      if (current == 'seen' || (current == 'delivered' && next == 'delivered'))
        return;
      _messageStatuses[msgId] = next;
      _messageStatusRevision++;
      unawaited(_persistMessageStatus(msgId));
      notifyListeners();
    });

    // ── Edit / Unsend ─────────────────────────────────────────────────────
    _socket!.on('message_edited', (data) {
      if (data is! Map) return;
      final msgId = data['messageId']?.toString() ?? '';
      final newText = data['text']?.toString() ?? '';
      final idx = _messages.indexWhere((m) => m.id == msgId);
      if (idx != -1) {
        final updated = List<Message>.from(_messages);
        updated[idx] = updated[idx].copyWith(text: newText, edited: true);
        _messages = updated;
        HybridDbService.updateMessage(msgId, updated[idx]);
        notifyListeners();
      }
    });

    _socket!.on('message_unsent', (data) {
      if (data is! Map) return;
      final msgId = data['messageId']?.toString() ?? '';
      _messages = _messages.where((m) => m.id != msgId).toList();
      HybridDbService.deleteMessage(msgId);
      notifyListeners();
    });

    // ── Reactions ─────────────────────────────────────────────────────────
    _socket!.on('reaction_updated', (data) {
      if (data is! Map) return;
      final msgId = data['messageId']?.toString() ?? '';
      final reactions = data['reactions'];
      final idx = _messages.indexWhere((m) => m.id == msgId);
      if (idx != -1) {
        final updatedReactions = Message.parseReactions(reactions);
        final updated = List<Message>.from(_messages);
        updated[idx] = updated[idx].copyWith(reactions: updatedReactions);
        _messages = updated;
        HybridDbService.saveMessage(updated[idx]);
        notifyListeners();
      }
    });

    // ── Typing ────────────────────────────────────────────────────────────
    // novyn-chat: { from, isTyping }
    _socket!.on('typing', (data) {
      if (data is! Map) return;
      final from = data['from']?.toString() ?? '';
      final isTyping = data['isTyping'] == true;
      final isGroupTyping = data['toType']?.toString() == 'group';
      final conversationKey =
          isGroupTyping ? (data['to']?.toString() ?? '') : from;
      if (conversationKey.isEmpty) return;
      final normalizedKey = conversationKey.toLowerCase();
      final usernameKey = from.trim().toLowerCase();
      final typingUsers = _typingUsersInChats.putIfAbsent(
        normalizedKey,
        () => <String, String>{},
      );
      if (usernameKey.isNotEmpty) {
        if (isTyping) {
          typingUsers[usernameKey] = from.trim();
        } else {
          typingUsers.remove(usernameKey);
        }
      }
      if (typingUsers.isEmpty) _typingUsersInChats.remove(normalizedKey);

      if (_currentChatWith != null &&
          conversationKey.toLowerCase() == _currentChatWith!.toLowerCase()) {
        _peerIsTyping = isTyping;
      }
      _typingInChats[normalizedKey] =
          isGroupTyping ? typingUsers.isNotEmpty : isTyping;
      notifyListeners();
    });

    _socket!.on('voice_activity', (data) {
      if (data is! Map) return;
      final from = data['from']?.toString().trim() ?? '';
      final isSpeaking = data['isSpeaking'] == true;
      final isGroupActivity = data['toType']?.toString() == 'group';
      final conversationKey =
          isGroupActivity ? (data['to']?.toString() ?? '') : from;
      if (conversationKey.isEmpty || from.isEmpty) return;

      final normalizedKey = conversationKey.toLowerCase();
      final userKey = from.toLowerCase();
      final activeUsers = _voiceUsersInChats.putIfAbsent(
        normalizedKey,
        () => <String>{},
      );
      if (isSpeaking) {
        activeUsers.add(userKey);
      } else {
        activeUsers.remove(userKey);
      }
      if (activeUsers.isEmpty) _voiceUsersInChats.remove(normalizedKey);

      if (_currentChatWith?.toLowerCase() == normalizedKey) {
        _peerIsRecordingVoice = activeUsers.isNotEmpty;
      }
      notifyListeners();
    });

    // ── User presence ─────────────────────────────────────────────────────
    _socket!.on('user_status', (data) {
      if (data is! Map) return;
      final username = data['username']?.toString().trim() ?? '';
      if (username.isEmpty) return;

      final online = data['online'] == true;
      final presence = data['presence']?.toString();
      final hasLastSeenAt = data.containsKey('lastSeenAt');
      final lastSeenAt =
          DateTime.tryParse(data['lastSeenAt']?.toString() ?? '');
      final normalized = username.toLowerCase();

      // Keep every Flutter surface in sync: contacts, cached chat previews,
      // and the active chat header all consume the same live presence event.
      contacts.updateStatus(
        username,
        online,
        presence: presence,
        lastSeenAt: lastSeenAt,
        clearLastSeen: hasLastSeenAt && lastSeenAt == null,
      );
      _conversations = _conversations.map((chat) {
        if (chat.isGroup || chat.peerUid.toLowerCase() != normalized) {
          return chat;
        }
        final updatedPeer = chat.peer.copyWith(
          isOnline: online,
          status: presence ?? (online ? 'online' : 'offline'),
          lastSeen: lastSeenAt,
          clearLastSeen: hasLastSeenAt && lastSeenAt == null,
        );
        return chat.copyWith(peer: updatedPeer);
      }).toList();

      onUserStatusChanged?.call(username, online);
      notifyListeners();
    });

    // ── Friend events ─────────────────────────────────────────────────────
    _socket!.on('friend_request_received', (data) {
      // UI layer handles this — just refresh
      _socket!.emit('resume_session');
    });

    _socket!.on('friend_request_accepted', (_) {
      _socket!.emit('resume_session');
    });

    _socket!.on('friend_removed', (data) {
      if (data is! Map) return;
      final username = data['username']?.toString() ?? '';
      _conversations = _conversations
          .where((c) => c.peerUid.toLowerCase() != username.toLowerCase())
          .toList();
      notifyListeners();
    });

    // ── Profile update ────────────────────────────────────────────────────
    _socket!.on('profile_updated', (data) {
      if (data is Map) onProfileData?.call(Map<String, dynamic>.from(data));
      // Notify AuthService to refresh — wired via callback below
      onProfileUpdated?.call();
    });

    _socket!.on('user_profile_updated', (data) {
      if (data is! Map) return;
      final profile = Map<String, dynamic>.from(data);
      final username = profile['username']?.toString().trim() ?? '';
      if (username.isEmpty) return;
      contacts.updateProfile(profile);
      _conversations = _conversations.map((chat) {
        if (chat.isGroup ||
            chat.peerUid.toLowerCase() != username.toLowerCase()) return chat;
        final updatedPeer = chat.peer.copyWith(
          name: profile['displayName']?.toString(),
          bio: profile['bio']?.toString(),
          photoUrl: profile['avatarId']?.toString(),
        );
        return chat.copyWith(peer: updatedPeer);
      }).toList();
      unawaited(HybridDbService.saveChats(_conversations));
      notifyListeners();
    });

    // ── Call signaling ────────────────────────────────────────────────────
    _socket!.on('call_incoming', (data) {
      onCallInviteCallback?.call(Map<String, dynamic>.from(data));
    });

    _socket!.on('call_accepted', (data) {
      onCallAcceptedCallback
          ?.call(data is Map ? Map<String, dynamic>.from(data) : {});
    });

    _socket!.on('call_rejected', (_) {
      onCallRejectedCallback?.call();
    });

    _socket!.on('call_ended', (data) {
      onCallEndedCallback
          ?.call(data is Map ? Map<String, dynamic>.from(data) : {});
    });

    _socket!.on('call_media_upgrade_request', (data) {
      onCallMediaUpgradeRequestCallback
          ?.call(data is Map ? Map<String, dynamic>.from(data) : {});
    });
    _socket!.on('call_media_upgrade_response', (data) {
      onCallMediaUpgradeResponseCallback
          ?.call(data is Map ? Map<String, dynamic>.from(data) : {});
    });
    _socket!.on('call_screen_share_changed', (data) {
      onCallScreenShareChangedCallback
          ?.call(data is Map ? Map<String, dynamic>.from(data) : {});
    });

    // ── WebRTC signaling ──────────────────────────────────────────────────
    _socket!.on('webrtc_signal', (data) {
      if (data is Map) {
        final signal = data['signal'];
        if (signal is Map) {
          final type = signal['type']?.toString() ?? '';
          if (type == 'offer') {
            onWebRTCOffer?.call(Map<String, dynamic>.from(signal));
          } else if (type == 'answer') {
            onWebRTCAnswer?.call(Map<String, dynamic>.from(signal));
          } else if (type == 'candidate') {
            onWebRTCIceCandidate?.call(Map<String, dynamic>.from(signal));
          }
        }
        onWebRTCSignalCallback?.call(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('random_match_found', (data) {
      if (data is! Map) return;
      final packet = Map<String, dynamic>.from(data);
      final sessionId = packet['sessionId']?.toString() ?? '';
      final game = packet['game'];
      if (sessionId.isNotEmpty && game is Map) {
        _randomGames[sessionId] = Map<String, dynamic>.from(game);
        notifyListeners();
      }
      onRandomMatchFound?.call(packet);
    });
    _socket!.on('random_game_updated', (data) {
      if (data is! Map) return;
      final packet = Map<String, dynamic>.from(data);
      final sessionId = packet['sessionId']?.toString() ?? '';
      final game = packet['game'];
      if (sessionId.isEmpty || game is! Map) return;
      _randomGames[sessionId] = Map<String, dynamic>.from(game);
      notifyListeners();
      onRandomGameUpdated?.call(packet);
    });
    _socket!.on('random_match_timeout', (data) {
      if (data is Map) onRandomMatchTimeout?.call(Map<String, dynamic>.from(data));
    });
    _socket!.on('game_invite_accepted', (data) {
      if (data is Map) onGameInviteAccepted?.call(Map<String, dynamic>.from(data));
    });
    _socket!.on('game_invite_timeout', (data) {
      if (data is Map) {
        final packet = Map<String, dynamic>.from(data);
        final gameType = packet['gameType']?.toString().toLowerCase();
        final messageId = packet['messageId']?.toString() ?? '';
        if (gameType == 'rajamantri' && messageId.isNotEmpty) {
          _rajaMantriExpiredInvites.add(messageId);
          _rajaMantriInviteSessions.remove(messageId);
          notifyListeners();
        }
        onGameInviteTimeout?.call(packet);
      }
    });

    _socket!.on('rajamantri_match_progress', (data) {
      if (data is Map) onRajaMantriMatchProgress?.call(Map<String, dynamic>.from(data));
    });
    _socket!.on('rajamantri_match_found', (data) {
      if (data is Map) onRajaMantriMatchFound?.call(Map<String, dynamic>.from(data));
    });
    _socket!.on('rajamantri_match_timeout', (data) {
      if (data is Map) onRajaMantriMatchTimeout?.call(Map<String, dynamic>.from(data));
    });

    _socket!.on('rajamantri_game_abandoned', (data) {
      if (data is Map) {
        onRajaMantriGameAbandoned?.call(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('rajamantri_game_updated', (data) {
      if (data is! Map) return;
      final packet = Map<String, dynamic>.from(data);
      final sessionId = packet['sessionId']?.toString() ?? '';
      final game = packet['game'];
      if (sessionId.isEmpty || game is! Map) return;
      _rajaMantriGames[sessionId] = Map<String, dynamic>.from(game);
      notifyListeners();
      onRajaMantriGameUpdated?.call(packet);
    });

    _socket!.on('rajamantri_room_started', (data) {
      if (data is! Map) return;
      final packet = Map<String, dynamic>.from(data);
      final sessionId = packet['sessionId']?.toString() ?? '';
      if (sessionId.isEmpty) return;
      final inviteIds = packet['inviteMessageIds'];
      if (inviteIds is List) {
        for (final value in inviteIds) {
          final id = value?.toString() ?? '';
          if (id.isNotEmpty) {
            _rajaMantriExpiredInvites.remove(id);
            _rajaMantriInviteSessions[id] = sessionId;
          }
        }
      }
      final messageId = packet['messageId']?.toString() ?? '';
      if (messageId.isNotEmpty) {
        _rajaMantriExpiredInvites.remove(messageId);
        _rajaMantriInviteSessions[messageId] = sessionId;
      }
      notifyListeners();
      onRajaMantriRoomStarted?.call(packet);
    });

    // ── Server error messages ─────────────────────────────────────────────
    _socket!.on('error_message', (data) {
      final message = data is Map ? data['message'] : data;
      debugPrint('[NovynSocket] Server error: $message');
    });
  }

  void _markSocketAuthenticated() {
    if (!_isConnected) return;
    _socketAuthRetryTimer?.cancel();
    _socketAuthRetryTimer = null;
    _socketAuthRetryAttempt = 0;
    _transportReconnectAttempt = 0;
    _isAuthenticated = true;
    SyncService().setOnlineStatus(true);
    _startPendingOutboxRetry();
    if (!_stealthPreferenceSynced) {
      _stealthPreferenceSynced = true;
      unawaited(_syncStealthModePreference());
    }
    // Discover requests made before authentication are intentionally not sent.
    // Fetch the online directory only after the server has accepted this session.
    requestDiscover();
    // A chat can be opened while the app is resuming and the socket is still
    // unauthenticated. Re-request its state only after session authentication.
    _requestActiveChatRefresh();
    if (_voiceActivityTargetUsername != null) {
      _emitVoiceActivity(true);
    }
    final ready = _authenticationReady;
    if (ready != null && !ready.isCompleted) ready.complete();
    onAuthenticated?.call();
  }

  Future<void> _waitForSocketAuthentication() async {
    if (_isConnected && _isAuthenticated) return;
    if (!ApiService.hasAccessSessionCookie) {
      throw StateError(
        'Your Novyn session is being restored. Please reconnect once verification finishes.',
      );
    }

    // Poll the live transport/auth state rather than awaiting a completer that
    // can become detached when a socket disconnects and is replaced.
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (!_isConnected || !_isAuthenticated) {
      if (_manualDisconnect) {
        throw StateError(
            'Reconnect to Novyn before changing account settings.');
      }

      // Recover a dropped transport instead of waiting passively for a
      // reconnect that may never be scheduled (for example after process
      // resume). A connected-but-unauthenticated socket is handled by the
      // handshake watchdog above.
      if (!_isConnected && !_isConnecting && _serverUrl != null &&
          _myUsername != null) {
        _doConnect();
      } else if (_isConnected &&
          !_isAuthenticated &&
          _socketAuthRetryTimer == null) {
        _scheduleSocketAuthRecovery();
      }

      if (DateTime.now().isAfter(deadline)) {
        throw StateError(
          _isConnected
              ? 'Novyn is still verifying your session. Please wait and try again.'
              : 'Novyn could not reconnect. Check your connection and try again.',
        );
      }
      await Future<void>.delayed(
        Duration(milliseconds: _isConnected ? 120 : 250),
      );
    }
  }

  Future<void> _requireAuthenticatedConnection() async {
    await _waitForSocketAuthentication();
    if (_socket == null || !_isConnected || !_isAuthenticated) {
      throw StateError(
          'Novyn is reconnecting securely. Please try again in a moment.');
    }
  }

  Future<void> _registerEncryptionIdentity() async {
    final account = _myUsername;
    final connection = _socket;
    if (account == null ||
        connection == null ||
        !_isConnected ||
        !_isAuthenticated) return;
    if (_registeredIdentityAccount == account.toLowerCase()) return;
    final active = _identityRegistration;
    if (active != null) return active;

    final task = () async {
      try {
        // After reinstall or Clear Storage, do not silently generate and
        // publish a replacement identity when this account already has a
        // recoverable key. That would strand new messages on the temporary
        // identity before the user has a chance to restore the original.
        if (!await encryption.hasLocalIdentity(account)) {
          final recoveryReply = Completer<Map<String, dynamic>>();
          connection.emitWithAck(
            'get_e2ee_identity_backup',
            const <String, dynamic>{},
            ack: (dynamic result) {
              if (!recoveryReply.isCompleted) {
                recoveryReply.complete(result is Map
                    ? Map<String, dynamic>.from(result)
                    : <String, dynamic>{'ok': false});
              }
            },
          );
          final recoveryState = await recoveryReply.future.timeout(
            const Duration(seconds: 8),
            onTimeout: () => <String, dynamic>{'ok': false},
          );
          if (recoveryState['ok'] != true) {
            throw StateError(
                'Could not verify this account’s E2EE recovery state. Reconnect and try again.');
          }
          if (recoveryState['backup'] is Map) {
            throw StateError(
                'This account has an E2EE recovery backup. Restore it from Settings → Chat Settings before sending messages.');
          }
        }
        final publicKey = await encryption.initializeIdentity(account);
        if (publicKey.isEmpty ||
            _myUsername != account ||
            _socket != connection ||
            !_isConnected) return;
        final completer = Completer<Map<String, dynamic>>();
        connection.emitWithAck('register_public_key', {'publicKey': publicKey},
            ack: (dynamic result) {
          if (!completer.isCompleted) {
            completer.complete(result is Map
                ? Map<String, dynamic>.from(result)
                : <String, dynamic>{'ok': false});
          }
        });
        final result = await completer.future.timeout(
          const Duration(seconds: 12),
          onTimeout: () => <String, dynamic>{'ok': false},
        );
        if (result['ok'] == true &&
            _myUsername == account &&
            _socket == connection) {
          _registeredIdentityAccount = account.toLowerCase();
          unawaited(decryptCurrentMessages());
        } else {
          debugPrint(
              '[NovynE2EE] Device identity registration was not confirmed.');
        }
      } catch (error) {
        debugPrint('[NovynE2EE] Identity setup failed: $error');
        if (error is StateError &&
            error.message.toString().contains('E2EE recovery backup')) {
          rethrow;
        }
      }
    }();

    _identityRegistration = task;
    try {
      await task;
    } finally {
      if (identical(_identityRegistration, task)) _identityRegistration = null;
    }
  }

  Future<void> saveE2eeIdentityBackup(String recoveryPassword) async {
    await _waitForSocketAuthentication();
    final account = _myUsername;
    final connection = _socket;
    if (account == null || connection == null) {
      throw StateError(
          'Sign in to Novyn before backing up your encryption key.');
    }
    await _registerEncryptionIdentity();
    if (_registeredIdentityAccount != account.toLowerCase()) {
      throw StateError(
          'Novyn could not verify the active encryption identity.');
    }
    final publicKey = await encryption.initializeIdentity(account);
    final backup = await encryption.exportIdentityRecoveryBackup(
      account,
      recoveryPassword,
    );
    final completer = Completer<Map<String, dynamic>>();
    connection.emitWithAck(
      'save_e2ee_identity_backup',
      {'publicKey': publicKey, 'backup': backup},
      ack: (dynamic result) {
        if (!completer.isCompleted) {
          completer.complete(result is Map
              ? Map<String, dynamic>.from(result)
              : <String, dynamic>{'ok': false});
        }
      },
    );
    final result = await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => <String, dynamic>{'ok': false},
    );
    if (result['ok'] != true) {
      throw StateError(
        result['message']?.toString() ??
            'The encrypted recovery backup could not be saved.',
      );
    }
  }

  Future<void> restoreE2eeIdentityBackup(String recoveryPassword) async {
    await _waitForSocketAuthentication();
    final account = _myUsername;
    final connection = _socket;
    if (account == null || connection == null) {
      throw StateError(
          'Sign in to Novyn before restoring your encryption key.');
    }
    final completer = Completer<Map<String, dynamic>>();
    connection.emitWithAck(
      'get_e2ee_identity_backup',
      const <String, dynamic>{},
      ack: (dynamic result) {
        if (!completer.isCompleted) {
          completer.complete(result is Map
              ? Map<String, dynamic>.from(result)
              : <String, dynamic>{'ok': false});
        }
      },
    );
    final result = await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => <String, dynamic>{'ok': false},
    );
    if (result['ok'] != true || result['backup'] is! Map) {
      throw StateError(
        result['message']?.toString() ??
            'No E2EE recovery backup exists for this account yet.',
      );
    }
    final backup = Map<String, dynamic>.from(result['backup'] as Map);
    final restoredPublicKey = await encryption.restoreIdentityRecoveryBackup(
      backup,
      account,
      recoveryPassword,
    );
    final serverPublicKey = result['publicKey']?.toString() ?? '';
    if (!MessageEncryptionService.samePublicKey(
        restoredPublicKey, serverPublicKey)) {
      throw StateError(
          'The account recovery backup does not match its registered identity.');
    }

    // Re-publish the recovered identity and discard peer keys cached against
    // the temporary identity created on this device before restore.
    _registeredIdentityAccount = null;
    _peerKeys.clear();
    await _registerEncryptionIdentity();
    if (_registeredIdentityAccount != account.toLowerCase()) {
      throw StateError(
          'The recovered encryption identity could not be registered.');
    }
    if (_currentChatWith != null) {
      connection.emit('get_history', {
        'to': _currentChatWith,
        'kind': _currentChatIsGroup ? 'group' : 'friend',
      });
      unawaited(decryptCurrentMessages());
    }
  }

  // ── Parse friend_list payload into ChatPreview list ───────────────────────
  void _handleFriendList(dynamic data) {
    // Socket.IO callbacks do not await async handlers. Keep failures contained
    // so one malformed friend record cannot escape as an unhandled async error.
    unawaited(_applyFriendList(data));
  }

  Future<void> _applyFriendList(dynamic data) async {
    if (data is Map && data['hiddenChats'] is List) {
      final nextHidden = (data['hiddenChats'] as List)
          .map((value) => value.toString().trim().toLowerCase())
          .where((value) => value.isNotEmpty)
          .toSet();
      final hiddenChanged =
          nextHidden.length != _hiddenChatUsernames.length ||
          !nextHidden.containsAll(_hiddenChatUsernames);
      if (hiddenChanged) {
        _hiddenChatUsernames
          ..clear()
          ..addAll(nextHidden);
        // Notify before awaiting encrypted preview decryption. The chat list
        // can remove server-hidden rows immediately, without waiting for every
        // latest-message preview to decrypt.
        notifyListeners();
      }
    }
    final rawList =
        data is List ? data : (data is Map ? data['friends'] : null);
    if (rawList is! List) return;
    final account = _myUsername;
    if (account == null || account.isEmpty) return;

    try {
      final list = rawList
          .whereType<Map>()
          .map((item) {
            try {
              return Map<String, dynamic>.from(item);
            } catch (_) {
              return null;
            }
          })
          .whereType<Map<String, dynamic>>()
          .toList();

      final peers = <UserModel>[];
      final previews = <ChatPreview>[];
      for (final item in list) {
        final directUsername = item['username']?.toString().trim() ?? '';
        final groupId = item['groupId']?.toString().trim() ?? '';
        // groupId can be present as auxiliary metadata on some direct-chat
        // snapshots; only treat it as a group when the server explicitly marks
        // the conversation kind or there is no direct username.
        final isGroupConversation =
            item['kind']?.toString().toLowerCase() == 'group' ||
                (directUsername.isEmpty && groupId.isNotEmpty);
        final username = directUsername.isNotEmpty ? directUsername : groupId;
        if (username.isEmpty) continue;

        final displayName = item['displayName']?.toString() ??
            item['name']?.toString() ??
            username;
        // The relay keeps the encrypted envelope in lastMessageData. The
        // legacy lastMessage field may not contain the ciphertext/IV.
        final lastMsg = item['lastMessageData'] ?? item['lastMessage'];
        final hasConversationActivity =
            (item['lastTimestamp']?.toString().trim().isNotEmpty ?? false) ||
                (lastMsg is Map && lastMsg.isNotEmpty) ||
                (lastMsg != null && lastMsg.toString().trim().isNotEmpty);
        // The server friend list also contains accepted contacts. Keep those
        // in Contacts/Discover, but do not create a Chats row until a first
        // message has actually started the conversation.
        if (!hasConversationActivity) continue;

        if (item['publicKey'] != null) {
          _peerKeys[username.toLowerCase()] = item['publicKey'].toString();
        }

        final peerModel = UserModel(
          uid: username,
          name: displayName,
          username: username,
          email: '',
          bio: '',
          createdAt: DateTime.now(),
          isOnline: item['online'] == true,
          status: item['presence']?.toString() ?? 'Online',
          lastSeen: DateTime.tryParse(item['lastSeenAt']?.toString() ?? ''),
          photoUrl: item['avatarId']?.toString() ?? '',
        );
        peers.add(peerModel);

        previews.add(ChatPreview(
          chatId: username.toLowerCase(),
          peerUid: username,
          peer: peerModel,
          isGroup: isGroupConversation,
          lastMessage: lastMsg is Map
              ? (lastMsg['isEncrypted'] == true
                  ? '🔒 Encrypted message'
                  : lastMsg['text']?.toString() ?? '')
              : lastMsg?.toString() ?? '',
          // Conversations without a message have no activity time.
          // Keep a stable old sentinel for sorting; the UI hides this value.
          lastTime:
              DateTime.tryParse(item['lastTimestamp']?.toString() ?? '') ??
                  DateTime(2000),
          unreadCount: (item['unreadCount'] as num?)?.toInt() ?? 0,
        ));
      }

      // Decrypt the latest encrypted previews before publishing the snapshot.
      // Publishing the placeholder first caused the Chats list to flash
      // "Encrypted message" while each preview was decrypted asynchronously.
      for (final item in list) {
        try {
          final raw = item['lastMessageData'] ?? item['lastMessage'];
          if (raw is! Map || raw['isEncrypted'] != true) continue;
          final peer = item['username']?.toString() ?? '';
          if (peer.isEmpty) continue;

          final previewIndex = previews.indexWhere(
            (chat) => chat.peerUid.toLowerCase() == peer.toLowerCase(),
          );
          if (previewIndex < 0) continue;

          final previousIndex = _conversations.indexWhere(
            (chat) => chat.peerUid.toLowerCase() == peer.toLowerCase(),
          );
          final incomingTime = previews[previewIndex].lastTime;
          // Keep an already-decrypted preview visible for the same activity
          // while refreshing the snapshot; never flash the placeholder again.
          if (previousIndex >= 0 &&
              _conversations[previousIndex]
                  .lastTime
                  .isAtSameMomentAs(incomingTime) &&
              _conversations[previousIndex].lastMessage.isNotEmpty &&
              _conversations[previousIndex].lastMessage !=
                  '🔒 Encrypted message') {
            previews[previewIndex] = previews[previewIndex].copyWith(
              lastMessage: _conversations[previousIndex].lastMessage,
            );
          }

          final decrypted = await encryption.decrypt(
            Message(
              id: raw['id']?.toString() ?? '',
              chatId: peer,
              text: raw['text']?.toString() ?? '🔒 Encrypted message',
              isFromMe: raw['from']?.toString().toLowerCase() ==
                  account.toLowerCase(),
              isEncrypted: true,
              ciphertext: raw['ciphertext']?.toString(),
              iv: raw['iv']?.toString(),
              senderPublicKey: raw['senderPublicKey']?.toString(),
            ),
            account,
            raw['from']?.toString().toLowerCase() == account.toLowerCase()
                ? _peerKeys[peer.toLowerCase()]
                : (raw['senderPublicKey']?.toString().isNotEmpty == true
                    ? raw['senderPublicKey']?.toString()
                    : _peerKeys[peer.toLowerCase()]),
          );
          if (_myUsername != account) return;
          if (!decrypted.needsMessageKey) {
            previews[previewIndex] = previews[previewIndex].copyWith(
              lastMessage: decrypted.text,
            );
          }
        } catch (error) {
          debugPrint('[NovynSocket] Could not decrypt chat preview: $error');
        }
      }

      if (_myUsername != account) return;

      // Publish one stable snapshot only after preview decryption has settled.
      // Local persistence remains asynchronous and does not block first render.
      _conversations = previews;
      _hasLoadedConversations = true;
      notifyListeners();

      unawaited(() async {
        await Future.wait([
          HybridDbService.saveUsers(peers),
          HybridDbService.saveChats(previews),
        ]);
      }());
    } catch (error, stackTrace) {
      debugPrint('[NovynSocket] Friend list refresh failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      // Keep the last good snapshot visible; a later server event can retry.
      notifyListeners();
    }
  }

  /// Persist a chat's hidden/deleted state on the authenticated account.
  /// Local UI state remains responsive; the caller can retry when offline.
  Future<bool> setChatHidden(String username, bool hidden) async {
    final connection = _socket;
    final peer = username.trim().toLowerCase();
    if (peer.isEmpty || peer == _myUsername?.toLowerCase() ||
        connection == null || !_isAuthenticated || !_isConnected) {
      return false;
    }

    final reply = Completer<Map<String, dynamic>>();
    connection.emitWithAck(
      'set_chat_hidden',
      {'username': peer, 'hidden': hidden},
      ack: (dynamic result) {
        if (reply.isCompleted) return;
        reply.complete(result is Map
            ? Map<String, dynamic>.from(result)
            : <String, dynamic>{});
      },
    );
    final result = await reply.future.timeout(
      const Duration(seconds: 6),
      onTimeout: () => <String, dynamic>{},
    );
    if (result['ok'] != true) return false;

    final rawHidden = result['hiddenChats'];
    if (rawHidden is List) {
      _hiddenChatUsernames
        ..clear()
        ..addAll(rawHidden
            .map((value) => value.toString().trim().toLowerCase())
            .where((value) => value.isNotEmpty));
      notifyListeners();
    }
    return true;
  }

  // ── Open a chat ────────────────────────────────────────────────────────────
  /// Opens the conversation and completes when the authenticated server has
  /// returned its history (including a legitimate empty-history response).
  /// This avoids treating a delayed socket response as an empty conversation.
  Future<List<Message>> openChat(
    String peerUsername,
    List<Message> cachedHistory, {
    bool isGroup = false,
  }) {
    final olderRequest = _olderHistoryCompleter;
    if (olderRequest != null && !olderRequest.isCompleted) {
      olderRequest.complete(false);
    }
    _olderHistoryCompleter = null;
    _olderHistoryTarget = null;
    final previousRequest = _chatHistoryCompleter;
    if (previousRequest != null && !previousRequest.isCompleted) {
      previousRequest.complete(const <Message>[]);
    }

    final historyRequest = Completer<List<Message>>();
    _chatHistoryCompleter = historyRequest;
    _chatHistoryTarget = peerUsername.trim().toLowerCase();

    if (_typingTargetKey != null) _stopActiveTyping();
    _currentChatWith = peerUsername;
    _currentChatIsGroup = isGroup;
    _chatWallpaper = '';
    _messages = List<Message>.from(cachedHistory);
    _peerIsTyping = false;
    _peerIsRecordingVoice =
        _voiceUsersInChats[peerUsername.toLowerCase()]?.isNotEmpty == true;
    _restorePendingMessagesForOpenChat();
    unawaited(_restorePersistedMessageStatuses(peerUsername));
    notifyListeners();

    unawaited(decryptCurrentMessages());

    // Ask the server whether this chat partner has enabled account-level
    // screenshot protection. Only their preference protects this conversation.
    _activeChatCaptureProtected = false;
    unawaited(SecurityService.setSafeMode(false));
    final connection = _socket;
    connection?.emit('set_active_chat',
        {'to': peerUsername, 'kind': isGroup ? 'group' : 'friend'});
    if (connection != null && !isGroup) {
      connection.emitWithAck('get_chat_protection', {'to': peerUsername},
          ack: (dynamic result) {
        if (_socket != connection ||
            _currentChatWith?.toLowerCase() != peerUsername.toLowerCase())
          return;
        final protected = result is Map &&
            result['ok'] == true &&
            result['protected'] == true;
        _activeChatCaptureProtected = protected;
        unawaited(SecurityService.setSafeMode(protected));
      });
    }
    connection?.emit('get_history',
        {'to': peerUsername, 'kind': isGroup ? 'group' : 'friend'});
    connection?.emit('get_chat_wallpaper',
        {'to': peerUsername, 'toType': isGroup ? 'group' : 'friend'});

    return historyRequest.future
        .timeout(
      const Duration(seconds: 12),
      onTimeout: () => List<Message>.unmodifiable(_messages),
    )
        .whenComplete(() {
      if (identical(_chatHistoryCompleter, historyRequest)) {
        _chatHistoryCompleter = null;
        _chatHistoryTarget = null;
      }
    });
  }

  Future<void> _syncStealthModePreference() async {
    try {
      await updateStealthMode(_stealthModePreference);
    } catch (error) {
      _stealthPreferenceSynced = false;
      debugPrint(
          '[NovynSecurity] Could not sync saved Stealth Mode preference: $error');
    }
  }

  Future<void> updateStealthMode(bool enabled) async {
    // Use the shared account-settings acknowledgement path so Stealth Mode
    // and Smart Presence report connection loss and server rejection
    // consistently.
    final result = await updateAccountSettings({'stealthModeEnabled': enabled});
    if (result['ok'] != true) {
      throw StateError(
        result['message']?.toString() ??
            'Could not sync Stealth Mode with your account. Please reconnect and try again.',
      );
    }
    _stealthModePreference = enabled;
  }

  void closeChat({bool notify = true}) {
    if (_typingTargetKey != null) _stopActiveTyping();
    stopVoiceActivity();
    final olderHistory = _olderHistoryCompleter;
    if (olderHistory != null && !olderHistory.isCompleted) {
      olderHistory.complete(false);
    }
    _olderHistoryCompleter = null;
    _olderHistoryTarget = null;
    final pendingHistory = _chatHistoryCompleter;
    if (pendingHistory != null && !pendingHistory.isCompleted) {
      pendingHistory.complete(const <Message>[]);
    }
    _chatHistoryCompleter = null;
    _chatHistoryTarget = null;
    _currentChatWith = null;
    _currentChatIsGroup = false;
    _activeChatCaptureProtected = false;
    unawaited(SecurityService.setSafeMode(false));
    _messages = [];
    _peerIsTyping = false;
    _peerIsRecordingVoice = false;

    // ChatDetailScreen calls closeChat while its own Provider subscription is
    // being disposed. Notifying listeners during that unmount pass causes an
    // unnecessary rebuild of the route that is already leaving.
    if (notify) notifyListeners();
  }

  Future<bool> loadOlderHistory(String peerUsername, String beforeMessageId,
      {bool isGroup = false}) async {
    if (beforeMessageId.isEmpty || !_isConnected || !_isAuthenticated)
      return false;
    _olderHistoryCompleter?.complete(false);
    final completer = Completer<bool>();
    _olderHistoryCompleter = completer;
    _olderHistoryTarget = peerUsername.trim().toLowerCase();
    _socket?.emit('get_history', {
      'to': peerUsername,
      'kind': isGroup ? 'group' : 'friend',
      'limit': 30,
      'before': beforeMessageId,
    });
    try {
      return await completer.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () => false,
      );
    } finally {
      if (identical(_olderHistoryCompleter, completer)) {
        _olderHistoryCompleter = null;
        _olderHistoryTarget = null;
      }
    }
  }

  /// Merge server history with the locally cached timeline without dropping
  /// older cached messages that are outside the server's latest-page window.
  void mergeChatHistory(List<Message> incoming) {
    final merged = <String, Message>{};
    for (final message in _messages) {
      if (message.id.isNotEmpty) merged[message.id] = message;
    }
    for (final message in incoming) {
      if (message.id.isNotEmpty) merged[message.id] = message;
    }
    final timeline = merged.values.toList()
      ..sort(compareMessagesChronologically);
    _messages = _resolveReplyPreviews(timeline);
    notifyListeners();
  }

  void prependOlderMessages(List<Message> older) {
    final merged = <String, Message>{};
    for (final message in [...older, ..._messages]) {
      if (message.id.isNotEmpty) merged[message.id] = message;
    }
    final timeline = merged.values.toList()
      ..sort(compareMessagesChronologically);
    _messages = _resolveReplyPreviews(timeline);
    notifyListeners();
  }

  // ── Send a message ─────────────────────────────────────────────────────────
  /// Encrypts a selected attachment for a direct chat before it reaches storage.
  /// Group media continues to use the existing group-media flow.
  Future<Map<String, dynamic>> prepareEncryptedAttachment(
    Uint8List bytes,
    String peerUsername,
  ) async {
    final account = _myUsername;
    if (account == null || account.isEmpty) {
      throw StateError('Sign in before sending attachments.');
    }
    if (bytes.isEmpty) throw StateError('The selected attachment is empty.');
    if (bytes.length + 16 > 15 * 1024 * 1024) {
      throw StateError('Direct-chat attachments must be smaller than 15 MB.');
    }
    await _waitForSocketAuthentication();
    _requireConnection();
    await _registerEncryptionIdentity();
    if (_registeredIdentityAccount != account.toLowerCase()) {
      throw StateError('Secure identity registration is pending.');
    }

    final connection = _socket;
    if (connection == null || !_isAuthenticated) {
      throw StateError('Novyn is reconnecting. Please try again.');
    }
    final keyReply = Completer<Map<String, dynamic>>();
    connection.emitWithAck('get_public_key', {'username': peerUsername},
        ack: (dynamic result) {
      if (!keyReply.isCompleted) {
        keyReply.complete(result is Map
            ? Map<String, dynamic>.from(result)
            : <String, dynamic>{});
      }
    });
    final keyResult = await keyReply.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => <String, dynamic>{},
    );
    final peerPublicKey = keyResult['publicKey']?.toString() ?? '';
    if (peerPublicKey.isEmpty) {
      throw StateError('The contact encryption key is not available yet.');
    }
    _peerKeys[peerUsername.toLowerCase()] = peerPublicKey;
    final encrypted = await encryption.encryptAttachmentBytes(
      bytes, account, peerPublicKey,
    );
    return {
      'bytes': encrypted['ciphertext'] as Uint8List,
      'metadata': {
        'encrypted': true,
        'encryptionVersion': 1,
        'iv': encrypted['iv'],
        'senderPublicKey': encrypted['senderPublicKey'],
        // The sender uses this public key to decrypt their own uploaded copy.
        'peerPublicKey': peerPublicKey,
      },
    };
  }

  Future<void> sendMessage(
    String text,
    String toPeerUsername, {
    String? replyToId,
    String? replyToText,
    String? replyToSender,
    Map<String, dynamic>? attachment,
    bool isGroup = false,
  }) async {
    final account = _myUsername;
    if (account == null) throw StateError('Sign in before sending messages.');
    final trimmedText = text.trim();
    if (trimmedText.isEmpty && attachment == null) {
      throw StateError('Write a message or attach a file first.');
    }
    final clientTempId = 'tmp_${DateTime.now().microsecondsSinceEpoch}';
    final rawText = trimmedText.isNotEmpty
        ? trimmedText
        : (attachment?['kind'] == 'image' ? '[Image]' : '[File]');
    final createdAt = DateTime.now();
    final tempMsg = Message(
      id: clientTempId,
      chatId: toPeerUsername,
      text: rawText,
      senderId: account,
      isFromMe: true,
      createdAt: createdAt,
      replyToId: replyToId,
      replyToText: replyToText,
      replyToSender: replyToSender,
      attachment: attachment,
      isEncrypted: false,
    );

    _messageStatuses[clientTempId] = 'sending';
    _messageStatusRevision++;
    _messages = [..._messages, tempMsg];
    notifyListeners();

    try {
      await (_outboxActivation ?? SyncService().activateAccount(account));
      if (_myUsername != account) {
        throw StateError(
            'Your account changed before this message was queued.');
      }
      // Persist the retry record before mirroring the optimistic bubble. If the
      // process stops immediately after queueing, openChat rebuilds the bubble.
      await SyncService().addPendingMessage(PendingMessage(
        accountId: account.trim().toLowerCase(),
        tempId: clientTempId,
        text: rawText,
        receiverId: toPeerUsername,
        chatId: toPeerUsername,
        createdAt: createdAt,
        replyToId: replyToId,
        replyToText: replyToText,
        replyToSender: replyToSender,
        isGroup: isGroup,
        attachment: attachment,
      ));
      await HybridDbService.saveMessage(tempMsg);

      // Offline sends are accepted into the durable outbox immediately.
      // Authenticated reconnect and key registration trigger the actual send.
      if (_isConnected && _isAuthenticated) {
        if (!isGroup) await _registerEncryptionIdentity();
        await _flushPendingMessageOutbox();
      }
    } catch (error) {
      _messageStatuses[clientTempId] = 'failed';
      _messageStatusRevision++;
      notifyListeners();
      rethrow;
    }
  }

  /// Requeues a message that the server explicitly rejected. Reusing its
  /// clientTempId lets the server return the original message if it had already
  /// stored it before a response was lost.
  Future<void> retryPendingMessage(
    String tempId, {
    required bool isGroup,
  }) async {
    final account = _myUsername;
    if (account == null) throw StateError('Sign in before retrying messages.');
    Message? message;
    for (final candidate in _messages) {
      if (candidate.id == tempId) {
        message = candidate;
        break;
      }
    }
    if (message == null) throw StateError('This message is no longer available.');

    await (_outboxActivation ?? SyncService().activateAccount(account));
    if (_myUsername != account) {
      throw StateError('Your account changed before retrying this message.');
    }

    PendingMessage? pending;
    for (final queued in SyncService().pendingMessages) {
      if (queued.tempId == tempId &&
          queued.accountId == account.trim().toLowerCase()) {
        pending = queued.copyWith(isFailed: false, lastError: '');
        break;
      }
    }
    pending ??= PendingMessage(
      accountId: account.trim().toLowerCase(),
      tempId: tempId,
      text: message.text,
      receiverId: message.chatId,
      chatId: message.chatId,
      createdAt: message.createdAt,
      replyToId: message.replyToId,
      replyToText: message.replyToText,
      replyToSender: message.replyToSender,
      isGroup: isGroup,
      attachment: message.attachment,
    );

    _messageStatuses[tempId] = 'sending';
    _messageStatusRevision++;
    notifyListeners();
    try {
      await SyncService().addPendingMessage(pending);
      if (_isConnected && _isAuthenticated) {
        await _flushPendingMessageOutbox();
      }
    } catch (error) {
      _messageStatuses[tempId] = 'failed';
      _messageStatusRevision++;
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> joinRandomGame(
    String gameType, {
    int? playerLevel,
  }) async {
    await _waitForSocketAuthentication();
    final socket = _socket;
    if (socket == null || !_isConnected || !_isAuthenticated) {
      throw StateError('Connect to Novyn before starting a random game.');
    }
    final completer = Completer<Map<String, dynamic>>();
    socket.emitWithAck('join_random_game', {
      'gameType': gameType,
      if (playerLevel != null) 'playerLevel': playerLevel,
    }, ack: (dynamic result) {
      if (completer.isCompleted) return;
      completer.complete(result is Map
          ? Map<String, dynamic>.from(result)
          : <String, dynamic>{'ok': false, 'message': 'Could not join matchmaking.'});
    });
    final result = await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => <String, dynamic>{'ok': false, 'message': 'Matchmaking request timed out.'},
    );
    if (result['ok'] != true) {
      throw StateError(result['message']?.toString() ?? 'Could not join matchmaking.');
    }
    return result;
  }

  Future<Map<String, dynamic>> joinRajaMantriMatchmaking(int playerCount) async {
    await _waitForSocketAuthentication();
    final socket = _socket;
    if (socket == null || !_isConnected || !_isAuthenticated) {
      throw StateError('Connect to Novyn before searching for players.');
    }
    if (playerCount != 3 && playerCount != 4) {
      throw ArgumentError.value(playerCount, 'playerCount', 'Only 3 or 4 players are supported.');
    }
    final completer = Completer<Map<String, dynamic>>();
    socket.emitWithAck(
      'join_rajamantri_matchmaking',
      {'playerCount': playerCount},
      ack: (dynamic result) {
        if (completer.isCompleted) return;
        completer.complete(result is Map
            ? Map<String, dynamic>.from(result)
            : <String, dynamic>{'ok': false, 'message': 'Could not join Raja Mantri matchmaking.'});
      },
    );
    final result = await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => <String, dynamic>{
        'ok': false,
        'message': 'Player search request timed out. Please try again.',
      },
    );
    if (result['ok'] != true) {
      throw StateError(result['message']?.toString() ?? 'Could not find players.');
    }
    return result;
  }

  Future<void> cancelRajaMantriMatchmaking() async {
    await _waitForSocketAuthentication();
    final socket = _socket;
    if (socket == null || !_isConnected || !_isAuthenticated) {
      throw StateError('Reconnect before cancelling player search.');
    }
    final completer = Completer<Map<String, dynamic>>();
    socket.emitWithAck('cancel_rajamantri_matchmaking', {}, ack: (dynamic result) {
      if (completer.isCompleted) return;
      completer.complete(result is Map
          ? Map<String, dynamic>.from(result)
          : <String, dynamic>{'ok': false});
    });
    final result = await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => <String, dynamic>{'ok': false, 'message': 'Could not cancel player search.'},
    );
    if (result['ok'] != true) {
      throw StateError(result['message']?.toString() ?? 'Could not cancel player search.');
    }
  }

  String? rajaMantriSessionForInvite(String messageId) =>
      _rajaMantriInviteSessions[messageId];

  bool isRajaMantriInviteExpired(String messageId) =>
      _rajaMantriExpiredInvites.contains(messageId);

  Future<void> leaveRajaMantriInvite(String messageId) async {
    await _waitForSocketAuthentication();
    final socket = _socket;
    if (socket == null || !_isConnected || !_isAuthenticated) {
      throw StateError('Reconnect before leaving this room.');
    }
    final completer = Completer<Map<String, dynamic>>();
    socket.emitWithAck(
      'leave_rajamantri_invite',
      {'messageId': messageId},
      ack: (dynamic result) {
        if (completer.isCompleted) return;
        completer.complete(result is Map
            ? Map<String, dynamic>.from(result)
            : <String, dynamic>{'ok': false});
      },
    );
    final result = await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => <String, dynamic>{'ok': false, 'message': 'Could not leave this room.'},
    );
    if (result['ok'] != true) {
      throw StateError(result['message']?.toString() ?? 'This room invitation is no longer active.');
    }
  }

  Future<Map<String, dynamic>> startRajaMantriFriendRoom({
    required int playerCount,
    required List<String> inviteMessageIds,
    required int botCount,
  }) async {
    await _waitForSocketAuthentication();
    final socket = _socket;
    if (socket == null || !_isConnected || !_isAuthenticated) {
      throw StateError('Reconnect to Novyn before starting this room.');
    }
    final completer = Completer<Map<String, dynamic>>();
    socket.emitWithAck(
      'start_rajamantri_friend_room',
      {
        'playerCount': playerCount,
        'inviteMessageIds': inviteMessageIds,
        'botCount': botCount,
      },
      ack: (dynamic result) {
        if (completer.isCompleted) return;
        completer.complete(result is Map
            ? Map<String, dynamic>.from(result)
            : <String, dynamic>{'ok': false, 'message': 'Could not start this room.'});
      },
    );
    final result = await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => <String, dynamic>{
        'ok': false,
        'message': 'Starting the room timed out. Please try again.',
      },
    );
    if (result['ok'] != true) {
      throw StateError(result['message']?.toString() ?? 'Could not start this room.');
    }
    return result;
  }

  Map<String, dynamic>? rajaMantriGameFor(String sessionId) {
    final game = _rajaMantriGames[sessionId];
    return game == null ? null : Map<String, dynamic>.from(game);
  }

  Future<Map<String, dynamic>> _rajaMantriGameAction(
    String event,
    Map<String, dynamic> payload, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    await _waitForSocketAuthentication();
    final socket = _socket;
    if (socket == null || !_isConnected || !_isAuthenticated) {
      throw StateError('Reconnect to Novyn before updating this match.');
    }
    final completer = Completer<Map<String, dynamic>>();
    socket.emitWithAck(event, payload, ack: (dynamic result) {
      if (completer.isCompleted) return;
      completer.complete(result is Map
          ? Map<String, dynamic>.from(result)
          : <String, dynamic>{'ok': false, 'message': 'Unexpected match response.'});
    });
    final result = await completer.future.timeout(
      timeout,
      onTimeout: () => <String, dynamic>{'ok': false, 'message': 'The match update timed out. Please retry.'},
    );
    if (result['ok'] != true) {
      throw StateError(result['message']?.toString() ?? 'Could not update this match.');
    }
    final game = result['game'];
    if (game is Map && payload['sessionId'] != null) {
      final sessionId = payload['sessionId'].toString();
      _rajaMantriGames[sessionId] = Map<String, dynamic>.from(game);
      notifyListeners();
    }
    return result;
  }

  Future<void> leaveRajaMantriGame(String sessionId) async {
    await _waitForSocketAuthentication();
    final socket = _socket;
    if (socket == null || !_isConnected || !_isAuthenticated) {
      throw StateError('Reconnect before leaving this match.');
    }
    final completer = Completer<Map<String, dynamic>>();
    socket.emitWithAck('leave_rajamantri_game', {'sessionId': sessionId},
        ack: (dynamic result) {
      if (completer.isCompleted) return;
      completer.complete(result is Map
          ? Map<String, dynamic>.from(result)
          : <String, dynamic>{'ok': false});
    });
    final result = await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => <String, dynamic>{'ok': false, 'message': 'Could not leave the match.'},
    );
    if (result['ok'] != true) {
      throw StateError(result['message']?.toString() ?? 'Could not leave the match.');
    }
  }

  Future<Map<String, dynamic>> getRajaMantriGame(String sessionId) {
    return _rajaMantriGameAction('get_rajamantri_game', {'sessionId': sessionId});
  }

  Future<Map<String, dynamic>> pickRajaMantriChit(String sessionId) {
    return _rajaMantriGameAction('pick_rajamantri_chit', {'sessionId': sessionId});
  }

  Future<Map<String, dynamic>> guessRajaMantriChor(
    String sessionId,
    String suspectUsername,
  ) {
    return _rajaMantriGameAction('guess_rajamantri_chor', {
      'sessionId': sessionId,
      'suspectUsername': suspectUsername,
    });
  }

  Future<Map<String, dynamic>> advanceRajaMantriRound(String sessionId) {
    return _rajaMantriGameAction('advance_rajamantri_round', {'sessionId': sessionId});
  }

  Future<Map<String, dynamic>> moveRandomGame(
    String sessionId,
    Map<String, dynamic> moveData,
  ) async {
    await _waitForSocketAuthentication();
    final socket = _socket;
    if (socket == null || !_isConnected || !_isAuthenticated) {
      throw StateError('Reconnect to Novyn before sending your move.');
    }
    final completer = Completer<Map<String, dynamic>>();
    socket.emitWithAck('random_game_move', {
      'sessionId': sessionId,
      'moveData': moveData,
    }, ack: (dynamic result) {
      if (completer.isCompleted) return;
      completer.complete(result is Map
          ? Map<String, dynamic>.from(result)
          : <String, dynamic>{'ok': false, 'message': 'Could not update the game.'});
    });
    final result = await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => <String, dynamic>{'ok': false, 'message': 'Game move timed out. Please retry.'},
    );
    if (result['ok'] != true) {
      throw StateError(result['message']?.toString() ?? 'Game move failed.');
    }
    final game = result['game'];
    if (game is Map) {
      _randomGames[sessionId] = Map<String, dynamic>.from(game);
      notifyListeners();
    }
    return result;
  }

  Future<void> cancelRandomGame() async {
    final socket = _socket;
    if (socket == null || !_isConnected || !_isAuthenticated) {
      throw StateError('Reconnect before cancelling matchmaking.');
    }
    final completer = Completer<Map<String, dynamic>>();
    socket.emitWithAck('cancel_random_game', {}, ack: (dynamic result) {
      if (completer.isCompleted) return;
      completer.complete(
        result is Map
            ? Map<String, dynamic>.from(result)
            : <String, dynamic>{'ok': false},
      );
    });
    final result = await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw StateError('Matchmaking cancellation timed out. Please try again.'),
    );
    if (result['ok'] != true || result['cancelled'] != true) {
      throw StateError(
        result['message']?.toString() ??
            'Matchmaking is no longer waiting. Please refresh the Games screen.',
      );
    }
  }

  Future<void> acceptGameInvite(String messageId) async {
    await _waitForSocketAuthentication();
    final socket = _socket;
    if (socket == null || !_isConnected || !_isAuthenticated) {
      throw StateError('Reconnect before joining this game.');
    }
    final completer = Completer<Map<String, dynamic>>();
    socket.emitWithAck('accept_game_invite', {'messageId': messageId},
        ack: (dynamic result) {
      if (completer.isCompleted) return;
      completer.complete(result is Map
          ? Map<String, dynamic>.from(result)
          : <String, dynamic>{'ok': false});
    });
    final result = await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw StateError('Could not join the invite in time.'),
    );
    if (result['ok'] != true) {
      throw StateError(result['message']?.toString() ?? 'This game invite has expired.');
    }
  }

  Future<void> cancelGameInvite(String messageId) async {
    await _waitForSocketAuthentication();
    final socket = _socket;
    if (socket == null || !_isConnected || !_isAuthenticated) {
      throw StateError('Reconnect before cancelling this invite.');
    }
    final completer = Completer<Map<String, dynamic>>();
    socket.emitWithAck('cancel_game_invite', {'messageId': messageId},
        ack: (dynamic result) {
      if (completer.isCompleted) return;
      completer.complete(result is Map
          ? Map<String, dynamic>.from(result)
          : <String, dynamic>{'ok': false});
    });
    final result = await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw StateError('Invite cancellation timed out.'),
    );
    if (result['ok'] != true) {
      throw StateError(result['message']?.toString() ?? 'The invite is no longer active.');
    }
  }

  Future<String> sendGameChallenge(String gameType, String peerUsername,
      {bool isGroup = false}) async {
    // A socket transport can be connected while resume_session is still
    // being verified. Wait for the authenticated session before sending a
    // game challenge instead of failing immediately with a stale UI state.
    await _waitForSocketAuthentication();
    _requireConnection();
    final connection = _socket;
    if (connection == null) {
      throw StateError('Novyn disconnected. Reconnect and try the game again.');
    }
    final timestamp = DateTime.now().microsecondsSinceEpoch.toString();
    final response = Completer<Map<String, dynamic>>();

    connection.emitWithAck(
      'private_message',
      {
        'to': peerUsername,
        'toType': isGroup ? 'group' : 'friend',
        'text': '🎮 Started a game of ' + _gameTitle(gameType) + '!',
        'clientTempId': 'tmp_game_' + timestamp,
        'game': {
          'id': 'game_' + timestamp,
          'gameType': gameType,
        },
      },
      ack: (dynamic result) {
        if (response.isCompleted) return;
        response.complete(
          result is Map
              ? Map<String, dynamic>.from(result)
              : <String, dynamic>{
                  'ok': false,
                  'message': 'Could not send the game invitation.',
                },
        );
      },
    );

    final result = await response.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => <String, dynamic>{
        'ok': false,
        'message': 'Game invitation timed out. Please retry.',
      },
    );
    if (result['ok'] != true) {
      throw StateError(
        result['message']?.toString() ?? 'Could not send the game invitation.',
      );
    }
    final messageId = result['id']?.toString() ?? '';
    if (messageId.isEmpty) {
      throw StateError('The game invitation was sent, but its game ID was missing.');
    }
    return messageId;
  }

  String _gameTitle(String type) {
    const titles = {
      'tictactoe': 'Tic-Tac-Toe',
      'rps': 'Rock • Paper • Scissors',
      'rajamantri': 'Raja Mantri Chor Sipahi',
    };
    return titles[type] ?? 'Game';
  }

  Future<Map<String, dynamic>> makeGameMove(
    String messageId,
    String peerUsername,
    Map<String, dynamic> moveData, {
    bool isGroup = false,
  }) async {
    _requireConnection();
    final completer = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck('game_move', {
      'messageId': messageId,
      'to': peerUsername,
      'toType': isGroup ? 'group' : 'friend',
      'moveData': moveData,
    }, ack: (dynamic result) {
      completer.complete(result is Map
          ? Map<String, dynamic>.from(result)
          : {'ok': false, 'message': 'Could not update the game.'});
    });
    final result = await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () =>
          {'ok': false, 'message': 'Game move timed out. Please retry.'},
    );
    if (result['ok'] != true) {
      throw StateError(result['message']?.toString() ?? 'Game move failed.');
    }
    return result;
  }

  Future<Map<String, dynamic>> sendRiddle({
    required String peerUsername,
    required String secret,
    required String question,
    required String answer,
    String? hint,
    int maxTries = 3,
    bool isGroup = false,
  }) async {
    _requireConnection();
    final completer = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck('riddle_message', {
      'to': peerUsername,
      'toType': isGroup ? 'group' : 'friend',
      'secret': secret,
      'question': question,
      'answer': answer,
      'hint': hint,
      'maxTries': maxTries == 5 ? 5 : 3,
      'clientTempId': 'riddle_${DateTime.now().millisecondsSinceEpoch}',
    }, ack: (dynamic result) {
      completer.complete(result is Map
          ? Map<String, dynamic>.from(result)
          : {'ok': false, 'message': 'Could not send riddle.'});
    });
    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => {'ok': false, 'message': 'Riddle send timed out.'},
    );
  }

  Future<Map<String, dynamic>> unlockRiddle({
    required String messageId,
    required String fromUsername,
    required String answer,
    bool isGroup = false,
  }) async {
    _requireConnection();
    final completer = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck('unlock_riddle', {
      'messageId': messageId,
      'from': fromUsername,
      'to': fromUsername,
      'toType': isGroup ? 'group' : 'friend',
      'answer': answer,
    }, ack: (dynamic result) {
      completer.complete(result is Map
          ? Map<String, dynamic>.from(result)
          : {'ok': false, 'message': 'Could not unlock riddle.'});
    });
    final result = await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => {'ok': false, 'message': 'Unlock timed out.'},
    );
    if (result['riddle'] is Map) {
      final index = _messages.indexWhere((message) => message.id == messageId);
      if (index != -1) {
        final updated = List<Message>.from(_messages);
        updated[index] = updated[index].copyWith(
          riddle: Map<String, dynamic>.from(result['riddle']),
        );
        _messages = updated;
        await HybridDbService.saveMessage(updated[index]);
        notifyListeners();
      }
    }
    return result;
  }

  void setChatWallpaper(String wallpaper, String peerUsername,
      {bool isGroup = false}) {
    _requireConnection();
    _socket!.emit('set_chat_wallpaper', {
      'to': peerUsername,
      'toType': isGroup ? 'group' : 'friend',
      'wallpaper': wallpaper,
    });
  }

  void pinMessage(String messageId, String peerUsername,
      {bool isGroup = false}) {
    _requireConnection();
    _socket!.emit('pin_message', {
      'messageId': messageId,
      'to': peerUsername,
      'toType': isGroup ? 'group' : 'friend',
    });
  }

  void unpinMessage(String messageId, String peerUsername,
      {bool isGroup = false}) {
    _requireConnection();
    _socket!.emit('unpin_message', {
      'messageId': messageId,
      'to': peerUsername,
      'toType': isGroup ? 'group' : 'friend',
    });
  }

  void createPoll(String question, List<String> options, String peerUsername,
      {bool isGroup = false}) {
    _requireConnection();
    _socket!.emit('create_poll', {
      'to': peerUsername,
      'toType': isGroup ? 'group' : 'friend',
      'question': question,
      'options': options,
      'clientTempId': 'tmp_poll_${DateTime.now().millisecondsSinceEpoch}',
    });
  }

  void votePoll(String messageId, String optionId, String peerUsername,
      {bool isGroup = false}) {
    _requireConnection();
    _socket!.emit('poll_vote', {
      'messageId': messageId,
      'optionId': optionId,
      'to': peerUsername,
      'toType': isGroup ? 'group' : 'friend',
    });
  }

  void forwardMessage(Message message, String targetUsername,
      {bool isGroup = false}) {
    _requireConnection();
    _socket!.emit('private_message', {
      'to': targetUsername,
      'toType': isGroup ? 'group' : 'friend',
      'text': message.text,
      'attachment': message.attachment,
      'clientTempId': 'tmp_forward_${DateTime.now().millisecondsSinceEpoch}',
    });
  }

  Future<void> decryptCurrentMessages() async {
    final account = _myUsername;
    final peer = _currentChatWith;
    if (account == null || peer == null) return;

    // Cached messages already decrypted on a previous open keep their
    // ciphertext envelope, but only placeholder messages need crypto work.
    final pending = _messages
        .where(encryption.needsDecryption)
        .toList(growable: false);
    var changed = false;
    if (pending.isNotEmpty) {
      final decrypted = await Future.wait(pending.map((message) {
        final peerKey = message.isFromMe
            ? _peerKeys[peer.toLowerCase()]
            : (message.senderPublicKey?.isNotEmpty == true
                ? message.senderPublicKey
                : _peerKeys[peer.toLowerCase()]);
        return _decryptMessageOnce(message, account, peerKey);
      }));
      if (_myUsername != account || _currentChatWith != peer) return;

      final byId = {for (final message in decrypted) message.id: message};
      final updated = _messages.map((message) {
        final clear = byId[message.id];
        if (clear == null ||
            clear.ciphertext != message.ciphertext ||
            clear.text == message.text) {
          return message;
        }
        changed = true;
        // Preserve any reactions/status-adjacent fields updated while crypto
        // was in flight; only replace the plaintext body.
        return message.copyWith(text: clear.text);
      }).toList();

      if (changed) {
        _messages = _resolveReplyPreviews(updated);
        await HybridDbService.saveMessages(_messages);
      }
    }

    if (_myUsername != account || _currentChatWith != peer) return;

    // Keep the conversation-list preview in sync even when the cached chat
    // messages were already decrypted before this open.
    if (_messages.isNotEmpty) {
      final latest = _messages.reduce(
        (a, b) => a.createdAt.isAfter(b.createdAt) ? a : b,
      );
      if (latest.text.isNotEmpty &&
          latest.text != '🔒 Encrypted message' &&
          !latest.needsMessageKey) {
        final previewIndex = _conversations.indexWhere(
          (chat) => chat.peerUid.toLowerCase() == peer.toLowerCase(),
        );
        if (previewIndex >= 0) {
          final existing = _conversations[previewIndex];
          if (existing.lastMessage != latest.text ||
              existing.lastTime != latest.createdAt) {
            final updated = List<ChatPreview>.from(_conversations);
            updated[previewIndex] = existing.copyWith(
              lastMessage: latest.text,
              lastTime: latest.createdAt,
            );
            _conversations = updated;
            await HybridDbService.saveChat(updated[previewIndex]);
            changed = true;
          }
        }
      }
    }
    if (changed) notifyListeners();
  }

  List<Message> _resolveReplyPreviews(List<Message> messages) {
    final originals = <String, Message>{
      for (final message in messages) message.id: message,
    };
    return messages.map((message) {
      final replyId = message.replyToId;
      if (replyId == null || replyId.isEmpty) return message;
      final original = originals[replyId];
      if (original == null ||
          original.text.isEmpty ||
          original.text == '🔒 Encrypted message') {
        return message;
      }
      return message.copyWith(
        replyToText: original.text,
        replyToSender: message.replyToSender?.isNotEmpty == true
            ? message.replyToSender
            : (original.isFromMe ? 'You' : original.senderId),
      );
    }).toList();
  }

  Future<int> importMessageKeys(String file, String password) async {
    final account = _myUsername;
    if (account == null) {
      throw StateError('Sign in before importing message keys.');
    }
    final count = await encryption.importKeys(file, password, account);
    if (_myUsername != account) {
      throw StateError('Your account changed. Reopen this chat.');
    }
    await decryptCurrentMessages();
    _socket?.emit('resume_session');
    if (_currentChatWith != null) {
      _socket?.emit('get_history', {'to': _currentChatWith, 'kind': 'friend'});
    }
    return count;
  }

  // ── Typing indicators ──────────────────────────────────────────────────────
  // Emit once on transition to typing, then emit a stop after the user pauses.
  // Per-keystroke events can hit the server's socket rate limit.
  void startTyping(String peerUsername, {bool isGroup = false}) {
    final key = '${isGroup ? 'group' : 'friend'}:${peerUsername.toLowerCase()}';
    if (_typingTargetKey != null && _typingTargetKey != key) {
      _stopActiveTyping();
    }
    if (_typingTargetKey != key) {
      _typingTargetKey = key;
      _typingTargetUsername = peerUsername;
      _typingTargetIsGroup = isGroup;
      _socket?.emit('typing', {
        'to': peerUsername,
        'isTyping': true,
        'toType': isGroup ? 'group' : 'friend',
      });
    }
    _typingStopTimer?.cancel();
    _typingStopTimer = Timer(const Duration(milliseconds: 2200), () {
      stopTyping(peerUsername, isGroup: isGroup);
    });
  }

  void stopTyping(String peerUsername, {bool isGroup = false}) {
    final key = '${isGroup ? 'group' : 'friend'}:${peerUsername.toLowerCase()}';
    if (_typingTargetKey != key) return;
    _stopActiveTyping();
  }

  void _stopActiveTyping() {
    final username = _typingTargetUsername;
    if (username == null) return;
    _typingStopTimer?.cancel();
    _socket?.emit('typing', {
      'to': username,
      'isTyping': false,
      'toType': _typingTargetIsGroup ? 'group' : 'friend',
    });
    _typingTargetKey = null;
    _typingTargetUsername = null;
    _typingTargetIsGroup = false;
  }

  void startVoiceActivity(String peerUsername, {bool isGroup = false}) {
    final username = peerUsername.trim();
    if (username.isEmpty) return;
    final key = '${isGroup ? 'group' : 'friend'}:${username.toLowerCase()}';
    if (_voiceActivityTargetKey == key) return;
    stopVoiceActivity();
    _voiceActivityTargetKey = key;
    _voiceActivityTargetUsername = username;
    _voiceActivityTargetIsGroup = isGroup;
    _emitVoiceActivity(true);
  }

  void stopVoiceActivity() {
    final username = _voiceActivityTargetUsername;
    if (username == null) return;
    _emitVoiceActivity(false);
    _voiceActivityTargetKey = null;
    _voiceActivityTargetUsername = null;
    _voiceActivityTargetIsGroup = false;
  }

  void _emitVoiceActivity(bool isSpeaking) {
    final username = _voiceActivityTargetUsername;
    final connection = _socket;
    if (username == null ||
        connection == null ||
        !_isConnected ||
        !_isAuthenticated) {
      return;
    }
    connection.emit('voice_activity', {
      'to': username,
      'isSpeaking': isSpeaking,
      'toType': _voiceActivityTargetIsGroup ? 'group' : 'friend',
    });
  }

  // ── Edit / Unsend ─────────────────────────────────────────────────────────
  void editMessage(String messageId, String newText, String peerUsername) {
    _socket?.emit('edit_message', {
      'messageId': messageId,
      'text': newText,
      'to': peerUsername,
    });
    // Optimistic update
    final idx = _messages.indexWhere((m) => m.id == messageId);
    if (idx != -1) {
      final updated = List<Message>.from(_messages);
      updated[idx] = updated[idx].copyWith(text: newText, edited: true);
      _messages = updated;
      notifyListeners();
    }
  }

  void unsendMessage(String messageId, String peerUsername) {
    _socket?.emit('unsend_message', {
      'messageId': messageId,
      'to': peerUsername,
    });
    _messages = _messages.where((m) => m.id != messageId).toList();
    notifyListeners();
  }

  // ── Reactions ─────────────────────────────────────────────────────────────
  void addReaction(String messageId, String emoji, String peerUsername,
      {bool isGroup = false}) {
    _socket?.emit('add_reaction', {
      'messageId': messageId,
      'emoji': emoji,
      'to': peerUsername,
      'toType': isGroup ? 'group' : 'friend',
    });
  }

  void removeReaction(String messageId, String peerUsername,
      {bool isGroup = false}) {
    _socket?.emit('remove_reaction', {
      'messageId': messageId,
      'to': peerUsername,
      'toType': isGroup ? 'group' : 'friend',
    });
  }

  // ── Friend management ─────────────────────────────────────────────────────
  Future<void> sendFriendRequest(String username) async {
    _requireConnection();
    final result = Completer<void>();
    _socket!.emitWithAck('add_friend', username, ack: (dynamic data) {
      if (result.isCompleted) return;
      if (data is Map && data['ok'] == true) {
        contacts.applyEvent(
            'friend_request_sent', {'to': data['username'] ?? username});
        result.complete();
      } else {
        result.completeError(StateError(data is Map
            ? data['message']?.toString() ?? 'Friend request failed.'
            : 'Friend request failed.'));
      }
    });
    await result.future.timeout(const Duration(seconds: 15));
  }

  Future<void> cancelFriendRequest(String username) async {
    _requireConnection();
    final completer = Completer<void>();
    _socket!.emitWithAck('cancel_friend_request', username,
        ack: (dynamic data) {
      if (data is Map && data['ok'] == true) {
        contacts.applyEvent('friend_request_cancelled', {'to': username});
        if (!completer.isCompleted) completer.complete();
      } else if (!completer.isCompleted) {
        completer.completeError(StateError(
          data is Map
              ? data['message']?.toString() ?? 'Could not cancel request.'
              : 'Could not cancel request.',
        ));
      }
    });
    await completer.future.timeout(const Duration(seconds: 12));
  }

  Future<void> acceptFriendRequest(String fromUsername) async {
    _requireConnection();
    final completer = Completer<void>();
    _socket!.emitWithAck('accept_friend', fromUsername, ack: (dynamic data) {
      if (completer.isCompleted) return;
      if (data is Map && data['ok'] == true) {
        completer.complete();
      } else {
        completer.completeError(StateError(
          data is Map
              ? data['message']?.toString() ?? 'Could not accept request.'
              : 'Could not accept request.',
        ));
      }
    });
    await completer.future.timeout(const Duration(seconds: 12));
  }

  Future<void> rejectFriendRequest(String fromUsername) async {
    _requireConnection();
    final completer = Completer<void>();
    _socket!.emitWithAck('reject_friend', fromUsername, ack: (dynamic data) {
      if (completer.isCompleted) return;
      if (data is Map && data['ok'] == true) {
        completer.complete();
      } else {
        completer.completeError(StateError(
          data is Map
              ? data['message']?.toString() ?? 'Could not decline request.'
              : 'Could not decline request.',
        ));
      }
    });
    await completer.future.timeout(const Duration(seconds: 12));
  }

  void removeFriend(String username) {
    _requireConnection();
    _socket!.emit('remove_friend', username);
  }

  Future<Map<String, dynamic>> setMute(
    String username, {
    required bool muted,
    bool isGroup = false,
  }) async {
    await _requireAuthenticatedConnection();
    final completer = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck('set_mute', {
      'username': username,
      'muted': muted,
      'kind': isGroup ? 'group' : 'friend',
      if (isGroup) 'groupId': username,
    }, ack: (dynamic result) {
      if (completer.isCompleted) return;
      completer.complete(result is Map
          ? Map<String, dynamic>.from(result)
          : <String, dynamic>{
              'ok': false,
              'message': 'The server did not confirm the mute update.',
            });
    });
    return completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => <String, dynamic>{
        'ok': false,
        'message': 'Updating muted chats timed out. Try again.',
      },
    );
  }

  void clearChat(String username) {
    _requireConnection();
    _socket!.emit('clear_chat', {'to': username, 'kind': 'friend'});
    _messages = [];
    notifyListeners();
  }

  Future<Map<String, dynamic>> markConversationAsRead(
    String username, {
    bool isGroup = false,
  }) async {
    await _requireAuthenticatedConnection();
    final completer = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck('mark_chat_read', {
      'to': username,
      'kind': isGroup ? 'group' : 'friend',
    }, ack: (dynamic result) {
      if (completer.isCompleted) return;
      completer.complete(result is Map
          ? Map<String, dynamic>.from(result)
          : <String, dynamic>{
              'ok': false,
              'message': 'The server did not confirm the read update.',
            });
    });
    return completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => <String, dynamic>{
        'ok': false,
        'message': 'Marking this chat as read timed out.',
      },
    );
  }

  Future<Map<String, dynamic>> markAllConversationsAsRead() async {
    await _requireAuthenticatedConnection();
    final completer = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck('mark_all_read', <String, dynamic>{},
        ack: (dynamic result) {
      if (completer.isCompleted) return;
      completer.complete(result is Map
          ? Map<String, dynamic>.from(result)
          : <String, dynamic>{
              'ok': false,
              'message': 'The server did not confirm the read update.',
            });
    });
    return completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => <String, dynamic>{
        'ok': false,
        'message': 'Marking chats as read timed out. Try again.',
      },
    );
  }

  void requestDiscover() {
    if (_isConnected && _isAuthenticated && _socket != null) {
      _socket!.emit('discover_online');
    }
  }

  void _requireConnection() {
    if (!_isConnected || _socket == null) {
      throw StateError(
          'Connect to Novyn before sending messages or changing contacts.');
    }
    if (!_isAuthenticated) {
      throw StateError(
          'Novyn is verifying your session. Please wait and try again.');
    }
  }

  // ── Call signaling ────────────────────────────────────────────────────────
  String sendCallInvite(String toUsername, {bool isVideo = false}) {
    final callId = DateTime.now().microsecondsSinceEpoch.toString();
    _socket?.emit('call_start', {
      'to': toUsername,
      'isVideo': isVideo,
      'callId': callId,
    });
    return callId;
  }

  void acceptCall(String fromUsername, String callId) {
    _socket?.emit('call_accept', {'to': fromUsername, 'callId': callId});
  }

  Future<String?> checkCallStatus(String peerUsername, String callId) async {
    final socket = _socket;
    if (socket == null || !_isConnected || !_isAuthenticated) return null;
    final response = Completer<String?>();
    socket.emitWithAck(
      'call_check',
      {'to': peerUsername, 'callId': callId},
      ack: (dynamic data) {
        if (response.isCompleted) return;
        if (data is Map && data['callId']?.toString() == callId) {
          response.complete(data['status']?.toString());
        } else {
          response.complete(null);
        }
      },
    );
    return response.future.timeout(
      const Duration(seconds: 4),
      onTimeout: () => null,
    );
  }

  void rejectCall(String fromUsername, String callId) {
    endCall(fromUsername, callId: callId, reason: 'Call declined');
  }

  void endCall(String peerUsername, {required String callId, String? reason}) {
    _socket?.emit('call_end', {
      'to': peerUsername,
      'callId': callId,
      if (reason != null) 'reason': reason,
    });
  }

  // ── WebRTC signaling ──────────────────────────────────────────────────────
  void sendWebRTCSignal(String toUsername, String callId, dynamic signal) {
    _socket?.emit('webrtc_signal', {
      'to': toUsername,
      'callId': callId,
      'signal': signal,
    });
  }

  void updateCallScreenShare(
      String toUsername, String callId, String? streamId) {
    _socket?.emit('call_screen_share_state', {
      'to': toUsername,
      'callId': callId,
      'streamId': streamId,
    });
  }

  void requestCallMediaUpgrade(String toUsername, String callId) {
    _socket?.emit(
        'call_media_upgrade_request', {'to': toUsername, 'callId': callId});
  }

  void respondCallMediaUpgrade(String toUsername, String callId,
      {required bool accepted}) {
    _socket?.emit('call_media_upgrade_response', {
      'to': toUsername,
      'callId': callId,
      'accepted': accepted,
    });
  }

  // ── Callback registrations ────────────────────────────────────────────────
  VoidCallback? onProfileUpdated;
  bool Function([String? sender])? notificationsMuted;
  Future<void> Function([String? sender])? notificationsVibrate;
  String Function()? notificationTone;
  double Function()? messageSoundVolume;
  void Function(Map<String, dynamic>)? onProfileData;

  Future<void> _playIncomingMessageSound() async {
    final tone = notificationTone?.call() ?? 'Drift';
    final asset = SettingsService.messageToneAsset(tone);
    final volume =
        (messageSoundVolume?.call() ?? 0.8).clamp(0.0, 1.0).toDouble();
    try {
      await _audioPlayer.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          audioFocus: AndroidAudioFocus.none,
          usageType: AndroidUsageType.notification,
          contentType: AndroidContentType.sonification,
        ),
      ));
      await _audioPlayer.setVolume(volume);
      if (volume > 0) await _audioPlayer.play(AssetSource(asset));
    } catch (_) {
      // A missing sound asset must not interrupt message delivery.
    }
  }

  bool _changingPassword = false;

  Future<Map<String, dynamic>> requestEmailChangeCode(String email) async {
    _requireConnection();
    final completer = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck('request_email_change_code', {'email': email.trim()},
        ack: (dynamic data) {
      if (!completer.isCompleted) {
        completer.complete(data is Map
            ? Map<String, dynamic>.from(data)
            : {'ok': false, 'message': 'Unexpected server response.'});
      }
    });
    return completer.future.timeout(const Duration(seconds: 20),
        onTimeout: () =>
            {'ok': false, 'message': 'Email request timed out. Try again.'});
  }

  Future<Map<String, dynamic>> verifyEmailChangeCode({
    required String email,
    required String code,
  }) async {
    _requireConnection();
    final completer = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck('verify_email_change_code', {
      'email': email.trim(),
      'code': code.trim(),
    }, ack: (dynamic data) {
      if (!completer.isCompleted) {
        completer.complete(data is Map
            ? Map<String, dynamic>.from(data)
            : {'ok': false, 'message': 'Unexpected server response.'});
      }
    });
    return completer.future.timeout(const Duration(seconds: 20),
        onTimeout: () =>
            {'ok': false, 'message': 'Verification timed out. Try again.'});
  }

  Future<void> changeUsername({
    required String newUsername,
    String currentPassword = '',
  }) async {
    _requireConnection();
    final connection = _socket!;
    final completer = Completer<void>();
    void succeeded(dynamic data) {
      if (!completer.isCompleted) completer.complete();
    }

    void failed(dynamic data) {
      if (!completer.isCompleted) {
        final message = data is Map ? data['message']?.toString() : null;
        completer
            .completeError(StateError(message ?? 'Could not change username.'));
      }
    }

    void disconnected(dynamic _) {
      if (!completer.isCompleted) {
        completer.completeError(StateError(
            'Connection lost before the username change was confirmed.'));
      }
    }

    connection.on('username_changed', succeeded);
    connection.on('username_change_failed', failed);
    connection.on('disconnect', disconnected);
    try {
      connection.emit('change_username', {
        'newUsername': newUsername.trim().toLowerCase(),
        'currentPassword': currentPassword,
      });
      await completer.future.timeout(const Duration(seconds: 20),
          onTimeout: () => throw StateError(
              'Username change timed out. Check your connection and try again.'));
    } finally {
      connection.off('username_changed', succeeded);
      connection.off('username_change_failed', failed);
      connection.off('disconnect', disconnected);
    }
  }

  Future<void> changePassword(
      String currentPassword, String newPassword) async {
    _requireConnection();
    if (_changingPassword) {
      throw StateError('A password change is already in progress.');
    }
    _changingPassword = true;
    final connection = _socket!;
    final confirmed = Completer<void>();
    void succeeded(dynamic _) {
      if (!confirmed.isCompleted) confirmed.complete();
    }

    void failed(dynamic data) {
      if (!confirmed.isCompleted) {
        final message = data is Map ? data['message']?.toString() : null;
        confirmed.completeError(
            StateError(message ?? 'Could not change your password.'));
      }
    }

    void disconnected(dynamic _) {
      if (!confirmed.isCompleted) {
        confirmed.completeError(StateError(
            'Connection lost before the password change was confirmed. Please sign in again.'));
      }
    }

    connection.on('password_changed', succeeded);
    connection.on('password_change_failed', failed);
    connection.on('disconnect', disconnected);
    try {
      connection.emit('change_password', {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
      await confirmed.future.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw StateError(
          'Could not confirm the password change. Check your connection and try signing in again.');
    } finally {
      connection.off('password_changed', succeeded);
      connection.off('password_change_failed', failed);
      connection.off('disconnect', disconnected);
      _changingPassword = false;
    }
  }

  Future<void> deleteAccount({
    required String confirmationText,
    String currentPassword = '',
  }) async {
    _requireConnection();
    final connection = _socket!;
    final completer = Completer<void>();
    void deleted(dynamic _) {
      if (!completer.isCompleted) completer.complete();
    }

    void failed(dynamic data) {
      if (!completer.isCompleted) {
        final message = data is Map ? data['message']?.toString() : null;
        completer.completeError(StateError(
          message ??
              'Account deletion was rejected. Check your confirmation and password.',
        ));
      }
    }

    void disconnected(dynamic _) {
      if (!completer.isCompleted) {
        completer.completeError(StateError(
          'Connection closed before the server confirmed account deletion.',
        ));
      }
    }

    connection.on('account_deleted', deleted);
    connection.on('account_deletion_failed', failed);
    connection.on('disconnect', disconnected);
    try {
      connection.emit('delete_account', {
        'currentPassword': currentPassword,
        'confirmationText': confirmationText,
        'confirmed': true,
      });
      await completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw StateError(
          'The server did not confirm account deletion. Please check your connection.',
        ),
      );
    } finally {
      connection.off('account_deleted', deleted);
      connection.off('account_deletion_failed', failed);
      connection.off('disconnect', disconnected);
    }
  }

  Future<Map<String, dynamic>> registerFcmToken(String token) async {
    _requireConnection();
    final completer = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck('register_fcm_token', {'token': token},
        ack: (dynamic result) {
      completer.complete(result is Map
          ? Map<String, dynamic>.from(result)
          : {
              'ok': false,
              'message': 'The server did not confirm this device.'
            });
    });
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () =>
          {'ok': false, 'message': 'Device registration timed out.'},
    );
  }

  Future<Map<String, dynamic>> clearFcmToken() async {
    if (!_isConnected || _socket == null) {
      return {'ok': false, 'message': 'Device is offline.'};
    }
    final completer = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck('clear_fcm_token', {}, ack: (dynamic result) {
      completer.complete(result is Map
          ? Map<String, dynamic>.from(result)
          : {
              'ok': false,
              'message': 'The server did not confirm device removal.'
            });
    });
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => {'ok': false, 'message': 'Device removal timed out.'},
    );
  }

  Future<Map<String, dynamic>> approveWebDevicePairing({
    required String id,
    required String secret,
    required String browserPublicKey,
  }) async {
    await _requireAuthenticatedConnection();
    final account = _myUsername;
    if (account == null)
      return {'ok': false, 'message': 'Sign in on this phone first.'};
    final encryptedIdentity = await encryption.exportIdentityForPairing(
      account,
      browserPublicKey,
    );
    final completer = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck('approve_device_pairing', {
      'id': id,
      'secret': secret,
      'browserPublicKey': browserPublicKey,
      'encryptedIdentity': encryptedIdentity,
    }, ack: (dynamic result) {
      if (!completer.isCompleted) {
        completer.complete(result is Map
            ? Map<String, dynamic>.from(result)
            : {
                'ok': false,
                'message': 'The server did not confirm device pairing.'
              });
      }
    });
    return completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () =>
          {'ok': false, 'message': 'Device pairing timed out. Try again.'},
    );
  }

  Future<Map<String, dynamic>> setBlockedUser(
    String username, {
    required bool blocked,
  }) async {
    _requireConnection();
    final value = username.trim().replaceFirst(RegExp(r'^@+'), '');
    if (value.isEmpty) {
      return {'ok': false, 'message': 'Enter a valid username.'};
    }
    final completer = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck('set_block', {
      'username': value,
      'blocked': blocked,
    }, ack: (dynamic result) {
      completer.complete(result is Map
          ? Map<String, dynamic>.from(result)
          : {
              'ok': false,
              'message': 'The server did not confirm this change.'
            });
    });
    final result = await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => {'ok': false, 'message': 'Block update timed out.'},
    );
    if (result['ok'] == true) {
      final key = value.toLowerCase();
      _blockedUsers.removeWhere((entry) => entry.toLowerCase() == key);
      if (blocked) _blockedUsers.add(value);
      notifyListeners();
    }
    return result;
  }

  Future<Map<String, dynamic>> fetchAccountSettings() async {
    await _requireAuthenticatedConnection();
    final completer = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck('get_account_settings', <String, dynamic>{},
        ack: (dynamic result) {
      completer.complete(result is Map
          ? Map<String, dynamic>.from(result)
          : {
              'ok': false,
              'message': 'The server did not return account settings.'
            });
    });
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () =>
          {'ok': false, 'message': 'Loading account settings timed out.'},
    );
  }

  Future<Map<String, dynamic>> updateAccountSettings(
      Map<String, dynamic> changes) async {
    await _requireAuthenticatedConnection();
    final connection = _socket!;
    final completer = Completer<Map<String, dynamic>>();

    void disconnected(dynamic _) {
      if (!completer.isCompleted) {
        completer.complete({
          'ok': false,
          'message': 'Connection was lost before Novyn confirmed the change. Reconnect and try again.',
        });
      }
    }

    connection.on('disconnect', disconnected);
    try {
      connection.emitWithAck('update_profile', changes, ack: (dynamic result) {
        if (completer.isCompleted) return;
        completer.complete(result is Map
            ? Map<String, dynamic>.from(result)
            : {
                'ok': false,
                'message': 'The server did not confirm this setting.'
              });
      });
      return await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => {
          'ok': false,
          'message': 'Novyn did not confirm the settings update in time. Check your connection and try again.',
        },
      );
    } finally {
      connection.off('disconnect', disconnected);
    }
  }

  Future<void> updatePresence(String mode) async {
    final result = await updateAccountSettings({'presenceMode': mode});
    if (result['ok'] != true) {
      throw StateError(
        result['message']?.toString() ??
            'The server did not confirm the status update. Please reconnect and try again.',
      );
    }
  }

  // messagesReadByPeer — used by chat_detail_screen for read tick color
  bool get messagesReadByPeer =>
      false; // novyn-chat tracks this via message_status events

  void onCallInvite(Function(Map) cb) => onCallInviteCallback = cb;
  void onCallAccepted(Function(Map) cb) => onCallAcceptedCallback = cb;
  void onCallRejected(VoidCallback cb) => onCallRejectedCallback = cb;
  void onCallEnded(Function(Map) cb) => onCallEndedCallback = cb;
  void onWebRTCSignal(Function(Map) cb) => onWebRTCSignalCallback = cb;

  // WebRTC setters used by call_screen.dart (old API used separate offer/answer/ice)
  // novyn-chat uses a single 'webrtc_signal' event; we map them here.
  Function(Map)? onWebRTCOffer;
  Function(Map)? onWebRTCAnswer;
  Function(Map)? onWebRTCIceCandidate;

  // sendOffer / sendAnswer / sendIceCandidate — old webrtc_service.dart API
  void sendOffer(String receiverId, String callId, dynamic offer) {
    sendWebRTCSignal(receiverId, callId, {
      'type': 'offer',
      if (offer is Map) ...Map<String, dynamic>.from(offer),
    });
  }

  void sendAnswer(String callerId, String callId, dynamic answer) {
    sendWebRTCSignal(callerId, callId, {
      'type': 'answer',
      if (answer is Map) ...Map<String, dynamic>.from(answer),
    });
  }

  void sendIceCandidate(String receiverId, String callId, dynamic candidate) {
    sendWebRTCSignal(receiverId, callId, {
      'type': 'candidate',
      if (candidate is Map) ...Map<String, dynamic>.from(candidate),
    });
  }

  // createGroup — emits create_group socket event
  Future<Map<String, dynamic>> getGroupInfo(String groupId) async {
    await _waitForSocketAuthentication();
    final connection = _socket;
    if (connection == null || !_isConnected || !_isAuthenticated) {
      throw StateError('Connect to Novyn to load group information.');
    }
    final acknowledgement = Completer<Map<String, dynamic>>();
    connection.emitWithAck('get_group_info', {'groupId': groupId},
        ack: (dynamic result) {
      if (acknowledgement.isCompleted) return;
      acknowledgement.complete(result is Map
          ? Map<String, dynamic>.from(result)
          : <String, dynamic>{
              'ok': false,
              'message': 'Unexpected server response.'
            });
    });
    final result = await acknowledgement.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => <String, dynamic>{
        'ok': false,
        'message': 'Loading group information timed out.'
      },
    );
    if (result['ok'] != true || result['group'] is! Map) {
      throw StateError(
          result['message']?.toString() ?? 'Could not load group information.');
    }
    _latestGroupInfo = Map<String, dynamic>.from(result['group'] as Map);
    notifyListeners();
    return Map<String, dynamic>.from(result['group'] as Map);
  }

  Future<Map<String, dynamic>> _groupAction(
    String event,
    Map<String, dynamic> payload,
  ) async {
    await _waitForSocketAuthentication();
    _requireConnection();
    final completer = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck(event, payload, ack: (dynamic response) {
      if (completer.isCompleted) return;
      completer.complete(response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{
              'ok': false,
              'message': 'The server did not confirm this group update.'
            });
    });
    final result = await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => <String, dynamic>{
        'ok': false,
        'message': 'Group update timed out. Please retry.'
      },
    );
    final group = result['group'];
    if (group is Map) {
      _latestGroupInfo = Map<String, dynamic>.from(group);
      notifyListeners();
    }
    return result;
  }

  Future<Map<String, dynamic>> addGroupMembers(
    String groupId,
    List<String> usernames,
  ) =>
      _groupAction('add_group_members', {
        'groupId': groupId,
        'members': usernames,
      });

  Future<Map<String, dynamic>> removeGroupMember(
    String groupId,
    String username,
  ) =>
      _groupAction('remove_group_member', {
        'groupId': groupId,
        'username': username,
      });

  Future<Map<String, dynamic>> setGroupMemberRole(
    String groupId,
    String username, {
    required String role,
  }) =>
      _groupAction('set_group_member_role', {
        'groupId': groupId,
        'username': username,
        'role': role,
      });

  Future<Map<String, dynamic>> leaveGroup(String groupId) =>
      _groupAction('leave_group', {'groupId': groupId});

  Future<String> createGroup({
    required String name,
    required List<String> memberIds,
  }) async {
    await _waitForSocketAuthentication();
    final connection = _socket;
    if (connection == null || !_isConnected || !_isAuthenticated) {
      throw StateError('Connect to Novyn before creating a group.');
    }
    final members = memberIds
        .map((value) => value.trim().replaceFirst(RegExp(r'^@+'), ''))
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    if (members.isEmpty) {
      throw StateError('Select at least one friend.');
    }
    final acknowledgement = Completer<Map<String, dynamic>>();
    connection.emitWithAck('create_group', {
      'name': name.trim(),
      // The API authorizes members by Novyn username, not Firebase UID.
      'members': members,
    }, ack: (dynamic result) {
      if (acknowledgement.isCompleted) return;
      acknowledgement.complete(result is Map
          ? Map<String, dynamic>.from(result)
          : <String, dynamic>{
              'ok': false,
              'message': 'Unexpected server response.'
            });
    });
    final result = await acknowledgement.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => <String, dynamic>{
        'ok': false,
        'message': 'Group creation timed out. Please try again.'
      },
    );
    if (result['ok'] != true) {
      throw StateError(
          result['message']?.toString() ?? 'Could not create group.');
    }
    final group = result['group'];
    final id =
        group is Map ? group['id']?.toString() : result['groupId']?.toString();
    if (id == null || id.isEmpty) {
      throw StateError(
          'The server created no group ID. Refresh your chats and try again.');
    }
    return id;
  }

  // deleteMessage — alias for unsendMessage with forEveryone flag
  void deleteMessage(String messageId, String peerUsername,
      {bool forEveryone = false}) {
    if (forEveryone) {
      unsendMessage(messageId, peerUsername);
    } else {
      // Delete for me only — remove locally
      _messages = _messages.where((m) => m.id != messageId).toList();
      notifyListeners();
    }
  }

  // prependMessages — used by chat_detail_screen for pagination
  void prependMessages(List<Message> older) {
    _messages = [...older, ..._messages];
    notifyListeners();
    unawaited(decryptCurrentMessages());
  }

  // ── Update conversations preview in memory ────────────────────────────────
  void _updateConversationPreview(
    String peerUsername,
    String text,
    String senderUsername,
    DateTime time, {
    bool isCurrentChat = false,
  }) {
    final idx = _conversations.indexWhere(
        (c) => c.peerUid.toLowerCase() == peerUsername.toLowerCase());

    if (idx != -1) {
      final old = _conversations[idx];
      final updated = old.copyWith(
        lastMessage: text,
        lastTime: time,
        unreadCount: isCurrentChat
            ? 0
            : senderUsername.toLowerCase() != _myUsername?.toLowerCase()
                ? old.unreadCount + 1
                : old.unreadCount,
      );
      final list = List<ChatPreview>.from(_conversations);
      list[idx] = updated;
      list.sort((a, b) => b.lastTime.compareTo(a.lastTime));
      _conversations = list;
    }
  }

  // ── Disconnect ────────────────────────────────────────────────────────────
  void disconnect() {
    _stopPendingOutboxRetry();
    _socketAuthRetryTimer?.cancel();
    _socketAuthRetryTimer = null;
    _socketAuthRetryAttempt = 0;
    _manualDisconnect = true;
    SyncService().setOnlineStatus(false);
    unawaited(SyncService().deactivateAccount());
    _myUsername = null;
    _outboxActivation = null;
    _isAuthenticated = false;
    _hasLoadedConversations = false;
    _registeredIdentityAccount = null;
    _identityRegistration = null;
    _authenticationReady = null;
    onAuthenticated = null;
    _peerKeys.clear();
    _messageStatuses.clear();
    _messageStatusRevision++;
    _blockedUsers.clear();
    _conversations = [];
    _latestGroupInfo = null;
    _messages = [];
    _currentChatWith = null;
    _currentChatIsGroup = false;
    _chatWallpaper = '';
    _peerIsTyping = false;
    _peerIsRecordingVoice = false;
    _typingInChats.clear();
    _typingUsersInChats.clear();
    _voiceUsersInChats.clear();
    contacts.clear();
    _reconnectTimer?.cancel();
    _stopActiveTyping();
    stopVoiceActivity();
    _socket?.dispose();
    _reconnectTimer?.cancel();
    _socket = null;
    _socketSessionCookie = null;
    _isConnected = false;
    _isConnecting = false;
    _transportReconnectAttempt = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _audioPlayer.dispose();
    contacts.dispose();
    super.dispose();
  }
}
