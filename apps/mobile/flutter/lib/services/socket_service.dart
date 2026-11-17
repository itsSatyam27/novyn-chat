import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:collection';
import '../models/chat_models.dart';
import '../models/chat_preview.dart';
import '../models/user_model.dart';
import 'hybrid_db_service.dart';
import 'api_service.dart';
import 'media_storage_service.dart';
import 'backend_contacts.dart';
import '../utils/message_pagination.dart';
import 'security_service.dart';
import 'sync_service.dart';

/// Socket service for the shared novyn-chat backend (server.js).
///
/// Event vocabulary (novyn-chat):
///   EMIT  resume_session           — authenticate socket after connect
///   EMIT  set_active_chat          — { to, kind }
///   EMIT  get_history              — { to, kind }
///   EMIT  private_message          — { to, toType, text, attachment?, replyTo?, clientTempId }
///   EMIT  typing                   — { to, isTyping, toType }
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

class SocketService extends ChangeNotifier {
  SocketService({bool initialStealthModeEnabled = false})
      : _stealthModePreference = initialStealthModeEnabled;

  bool _stealthModePreference;
  bool _stealthPreferenceSynced = false;
  Future<void>? _outboxActivation;
  bool _isAuthenticated = false;
  bool _hasLoadedConversations = false;
  Completer<void>? _authenticationReady;
  Completer<bool>? _olderHistoryCompleter;
  Completer<List<Message>>? _chatHistoryCompleter;
  String? _chatHistoryTarget;
  VoidCallback? onAuthenticated;
  final BackendContacts contacts = BackendContacts();
  io.Socket? _socket;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _manualDisconnect = false;
  bool _refreshingSocketSession = false;
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
  String messageStatusFor(String messageId) => _messageStatuses[messageId] ?? 'sent';
  DateTime? messageDeliveredAtFor(String messageId) => _messageDeliveredAt[messageId];
  DateTime? messageSeenAtFor(String messageId) => _messageSeenAt[messageId];

  void _captureMessageStatusTimes(String id, Map data) {
    final delivered = DateTime.tryParse(data['deliveredAt']?.toString() ?? '');
    final seen = DateTime.tryParse(data['seenAt']?.toString() ?? '');
    if (delivered != null) _messageDeliveredAt[id] = delivered.toLocal();
    if (seen != null) _messageSeenAt[id] = seen.toLocal();
  }

  // Reconnection state
  String? _serverUrl;
  Timer? _reconnectTimer;
  Timer? _pendingOutboxRetryTimer;
  Timer? _connectionHealthTimer;
  int _connectionHealthMisses = 0;
  bool _healthProbeInFlight = false;
  bool _connectionDegraded = false;

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
  Timer? _typingStopTimer;
  String? _typingTargetKey;
  String? _typingTargetUsername;
  bool _typingTargetIsGroup = false;

  // Typing across other chats: peerUsername → true
  final Map<String, bool> _typingInChats = {};
  Map<String, bool> get typingInChats => Map.unmodifiable(_typingInChats);

  // Conversations list (mirrors novyn-chat's friend_list)
  List<ChatPreview> _conversations = [];
  List<ChatPreview> get conversations => List.unmodifiable(_conversations);
  Map<String, dynamic>? _latestGroupInfo;
  Map<String, dynamic>? get latestGroupInfo =>
      _latestGroupInfo == null ? null : Map<String, dynamic>.from(_latestGroupInfo!);
  List<String> _blockedUsers = [];
  List<String> get blockedUsers => List.unmodifiable(_blockedUsers);

  // Call event callbacks
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
  Function(String sender, String body)? onIncomingMessage;
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
  bool get isAuthenticated => _isAuthenticated;
  bool get hasLoadedConversations => _hasLoadedConversations;
  bool get peerIsTyping => _peerIsTyping;
  String? get currentChatWith => _currentChatWith;
  bool get activeChatCaptureProtected => _activeChatCaptureProtected;
  String? get myUsername => _myUsername;

  // ── Connect ───────────────────────────────────────────────────────────────
  /// Rebuild the socket handshake after the REST session cookie rotates.
  /// The server binds each socket to the session ID used at connect time.
  Future<void> reconnectWithCurrentSession() async {
    final username = _myUsername;
    final serverUrl = _serverUrl;
    if (username == null || username.isEmpty ||
        serverUrl == null || serverUrl.isEmpty) {
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
    if (_manualDisconnect || _isAuthenticated || _refreshingSocketSession) return;
    if (_socketAuthRetryTimer?.isActive == true) return;
    _socketAuthRetryTimer = Timer(delay, () {
      _socketAuthRetryTimer = null;
      unawaited(_refreshAfterSocketAuthFailure());
    });
  }

  Future<void> _refreshAfterSocketAuthFailure() async {
    if (_refreshingSocketSession || _manualDisconnect || _isAuthenticated) return;
    _refreshingSocketSession = true;
    var retryAfterTransientFailure = false;
    try {
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
      retryAfterTransientFailure =
          status == null || status == 429 || (status != null && status >= 500);
    } catch (error) {
      debugPrint('[NovynSocket] Session refresh after auth failure failed: $error');
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
    if (_socket != null && _myUsername != null &&
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
      _messageStatuses[pending.tempId] = _isConnected && _isAuthenticated ? 'sending' : 'queued';
    }
    _restorePendingMessagesForOpenChat();
    notifyListeners();
  }

  /// Rebuild optimistic bubbles from the durable queue after process restart.
  void _restorePendingMessagesForOpenChat() {
    final peer = _currentChatWith;
    if (peer == null) return;

    final existingIds = _messages.map((message) => message.id).toSet();
    final restored = SyncService().pendingMessages
        .where((pending) =>
            pending.isGroup == _currentChatIsGroup &&
            pending.chatId.toLowerCase() == peer.toLowerCase() &&
            !existingIds.contains(pending.tempId))
        .map((pending) {
          _messageStatuses[pending.tempId] = 'sending';
          return pending.toLocalMessage();
        })
        .toList(growable: false);
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
          debugPrint('[NovynOutbox] Message ${pending.tempId} rejected: $reason');
          notifyListeners();
        },
        onDeferred: (pending) {
          _messageStatuses[pending.tempId] = 'queued';
          _messageStatusRevision++;
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
      const Duration(seconds: 5),
      (_) {
        if (!_isConnected ||
            !_isAuthenticated ||
            SyncService().pendingMessages.isEmpty) {
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
    if (account == null ||
        pending.accountId != account.trim().toLowerCase()) {
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

    _messageStatuses[pending.tempId] = 'sending';
    _messageStatusRevision++;
    notifyListeners();

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

    final acknowledgement = Completer<Map<String, dynamic>>();
    connection.emitWithAck('private_message', payload, ack: (dynamic result) {
      if (acknowledgement.isCompleted) return;
      acknowledgement.complete(
        result is Map
            ? Map<String, dynamic>.from(result)
            : <String, dynamic>{'ok': false, 'message': 'Unexpected server response.'},
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
      throw StateError('The account or connection changed after send acknowledgement.');
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
    _authenticationReady = null;
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

    _socket!.onConnect((_) {
      _isConnecting = false;
      _isConnected = true;
      SyncService().setOnlineStatus(true);
      _isAuthenticated = false;
      _stealthPreferenceSynced = false;
      _authenticationReady = Completer<void>();
      _reconnectTimer?.cancel();

      // novyn-chat requires resume_session after connect to authenticate
      // the socket and receive the initial friend_list + requests.
      _socket!.emit('resume_session');
      _socket!.emit('app_visibility', {'foreground': _appForeground});

      MediaStorageService.watchConnectivity();
      onConnected?.call();
      notifyListeners();
    });

    _socket!.onDisconnect((_) {
      _stopConnectionHealthMonitor();
      _stopPendingOutboxRetry();
      _isConnecting = false;
      _isConnected = false;
      SyncService().setOnlineStatus(false);
      _isAuthenticated = false;
      // A completed future from an old socket must never authenticate a new one.
      _authenticationReady = null;
      notifyListeners();
      if (!_manualDisconnect) _scheduleReconnect(3);
    });

    _socket!.onConnectError((_) {
      _stopConnectionHealthMonitor();
      _stopPendingOutboxRetry();
      _isConnecting = false;
      _isConnected = false;
      SyncService().setOnlineStatus(false);
      _isAuthenticated = false;
      _authenticationReady = null;
      notifyListeners();
      if (!_manualDisconnect) _scheduleReconnect(5);
    });

    _registerEventHandlers();
    _socket!.on('auth_failed', (data) {
      _stopConnectionHealthMonitor();
      _stopPendingOutboxRetry();
      _isAuthenticated = false;
      SyncService().setOnlineStatus(false);
      notifyListeners();
      // Socket.IO may stay transport-connected after resume_session fails.
      // Recover the HTTP session, then replace that unauthenticated transport.
      // Never clear the local account for a socket-only authentication failure.
      _scheduleSocketAuthRecovery();
    });
    _isConnecting = true;
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
    if (peer == null || peer.isEmpty || connection == null ||
        !_isConnected || !_isAuthenticated) return;
    final kind = _currentChatIsGroup ? 'group' : 'friend';
    connection.emit('set_active_chat', {'to': peer, 'kind': kind});
    if (!_currentChatIsGroup) {
      connection.emit('get_chat_protection', {'to': peer});
    }
    connection.emit('get_history', {'to': peer, 'kind': kind, 'limit': 100});
    connection.emit('get_chat_wallpaper', {'to': peer, 'toType': kind});
  }

  void _scheduleReconnect(int seconds) {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
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
      if (data is Map) _handleFriendList(data['friends']);
      _markSocketAuthenticated();
      unawaited(_flushPendingMessageOutbox());
    });
    // ── Initial data + friend list ────────────────────────────────────────
    _socket!.on('init', (data) {
      if (data is Map && data['friends'] != null) {
        _handleFriendList(data['friends']);
      }
      _markSocketAuthenticated();
      unawaited(
        _flushPendingMessageOutbox(),
      );
    });

    _socket!.on('friend_list', (data) => _handleFriendList(data));
    _socket!.on('friend_list_updated', (data) => _handleFriendList(data));
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
            attachment: m['attachment'] is Map ? Map<String, dynamic>.from(m['attachment']) : null,
            poll: m['poll'] is Map ? Map<String, dynamic>.from(m['poll']) : null,
            pinnedAt: m['pinnedAt']?.toString(),
            pinnedBy: m['pinnedBy']?.toString(),
            riddle: m['riddle'] is Map ? Map<String, dynamic>.from(m['riddle']) : null,
            game: m['game'] is Map ? Map<String, dynamic>.from(m['game']) : null,
          );
        }).toList();

        final account = _myUsername;
        if (account == null) return;
        for (final raw in historyList) {
          if (raw is! Map) continue;
          final id = raw['id']?.toString() ?? raw['messageId']?.toString() ?? '';
          if (id.isEmpty) continue;
          _captureMessageStatusTimes(id, raw);
          final explicit = raw['status']?.toString().toLowerCase();
          _messageStatuses[id] = raw['seenAt'] != null || explicit == 'seen'
              ? 'seen'
              : raw['deliveredAt'] != null || explicit == 'delivered'
                  ? 'delivered'
                  : 'sent';
        }
        _messageStatusRevision++;
        if (_myUsername != account ||
            _currentChatWith?.toLowerCase() != withUser.toLowerCase()) {
          return;
        }
        // Merge by message ID instead of replacing the local timeline with
        // only the server's latest page. This preserves older cached messages
        // and messages received while history was being refreshed.
        final merged = <String, Message>{
          for (final message in _messages)
            if (message.id.isNotEmpty) message.id: message,
        };
        for (final message in parsed) {
          if (message.id.isNotEmpty) merged[message.id] = message;
        }
        final timeline = merged.values.toList()
          ..sort(compareMessagesChronologically);
        _messages = _resolveReplyPreviews(timeline);
        HybridDbService.saveMessages(_messages);
        final olderRequest = _olderHistoryCompleter;
        if (olderRequest != null && !olderRequest.isCompleted) {
          olderRequest.complete(data['hasMore'] == true);
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
          ? (data['groupId']?.toString() ?? data['toKey']?.toString() ?? receiver)
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
        attachment: data['attachment'] is Map ? Map<String, dynamic>.from(data['attachment']) : null,
        poll: data['poll'] is Map ? Map<String, dynamic>.from(data['poll']) : null,
        pinnedAt: data['pinnedAt']?.toString(),
        pinnedBy: data['pinnedBy']?.toString(),
        riddle: data['riddle'] is Map ? Map<String, dynamic>.from(data['riddle']) : null,
        game: data['game'] is Map ? Map<String, dynamic>.from(data['game']) : null,
      );

      final account = _myUsername;
      if (account == null) return;
      if (isOwn) {
        _recentOwnMessageEchoIds.add(msgId);
        if (_recentOwnMessageEchoIds.length > 200) {
          _recentOwnMessageEchoIds.remove(_recentOwnMessageEchoIds.first);
        }
        _captureMessageStatusTimes(msgId, data);
        final explicit = data['status']?.toString().toLowerCase();
        _messageStatuses[msgId] = data['seenAt'] != null || explicit == 'seen'
            ? 'seen'
            : data['deliveredAt'] != null || explicit == 'delivered'
                ? 'delivered'
                : 'sent';
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
        // While the app is active, Socket.IO owns the in-app alert. In the
        // background, let the high-priority FCM handler own the system alert;
        // emitting both paths can create duplicate notifications when Android
        // keeps the socket process alive for a short time after backgrounding.
        if (!isGroupMessage && _appForeground) {
          onIncomingMessage?.call(chatPartner, msg.text);
        }
        // Background notification sound/vibration comes from the OS channel.
        // Suppress the in-process alert path when relying on FCM.
        final suppressChatAlert = !_appForeground ||
            (notificationsMuted?.call(chatPartner) ?? false);
        if (!suppressChatAlert) {
          unawaited(_playIncomingMessageSound());
          final vibrate = notificationsVibrate;
          if (vibrate != null) unawaited(vibrate(chatPartner));
        }
      }

      // Resolve reply metadata against locally cached originals.
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
      if (index == -1) return;
      final updated = List<Message>.from(_messages);
      updated[index] = updated[index].copyWith(game: Map<String, dynamic>.from(rawGame));
      _messages = updated;
      HybridDbService.saveMessage(updated[index]);
      notifyListeners();
    });

    _socket!.on('riddle_updated', (data) {
      if (data is! Map) return;
      final messageId = data['id']?.toString() ?? data['messageId']?.toString() ?? '';
      final rawRiddle = data['riddle'];
      if (messageId.isEmpty || rawRiddle is! Map) return;
      final index = _messages.indexWhere((message) => message.id == messageId);
      if (index == -1) return;
      final updated = List<Message>.from(_messages);
      updated[index] = updated[index].copyWith(riddle: Map<String, dynamic>.from(rawRiddle));
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
        pinnedAt: data['pinnedAt']?.toString() ?? DateTime.now().toIso8601String(),
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
      final msgId = data['id']?.toString() ?? data['messageId']?.toString() ?? '';
      if (msgId.isEmpty) return;
      _captureMessageStatusTimes(msgId, data);
      final explicit = data['status']?.toString().toLowerCase();
      final next = data['seenAt'] != null || explicit == 'seen' || explicit == 'read'
          ? 'seen'
          : data['deliveredAt'] != null || explicit == 'delivered'
              ? 'delivered'
              : null;
      if (next == null) return;
      final deliveredAt = DateTime.tryParse(data['deliveredAt']?.toString() ?? '');
      final seenAt = DateTime.tryParse(data['seenAt']?.toString() ?? '');
      var previewChanged = false;
      _conversations = _conversations.map((chat) {
        if (chat.lastMessageId != msgId) return chat;
        previewChanged = true;
        return chat.copyWith(
          lastMessageDeliveredAt: deliveredAt ?? chat.lastMessageDeliveredAt,
          lastMessageSeenAt: seenAt ?? chat.lastMessageSeenAt,
        );
      }).toList();
      if (previewChanged) {
        unawaited(HybridDbService.saveChats(_conversations));
      }

      final current = _messageStatuses[msgId] ?? 'sent';
      if (current == 'seen' || (current == 'delivered' && next == 'delivered')) {
        if (previewChanged) notifyListeners();
        return;
      }
      _messageStatuses[msgId] = next;
      _messageStatusRevision++;
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
      final conversationKey = isGroupTyping
          ? (data['to']?.toString() ?? '')
          : from;
      if (conversationKey.isEmpty) return;

      if (_currentChatWith != null &&
          conversationKey.toLowerCase() == _currentChatWith!.toLowerCase()) {
        _peerIsTyping = isTyping;
      }
      _typingInChats[conversationKey.toLowerCase()] = isTyping;
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
      final lastSeenAt = DateTime.tryParse(data['lastSeenAt']?.toString() ?? '');
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
        if (chat.isGroup || chat.peerUid.toLowerCase() != username.toLowerCase()) return chat;
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
      onCallEndedCallback?.call(data is Map ? Map<String, dynamic>.from(data) : {});
    });

    _socket!.on('call_media_upgrade_request', (data) {
      onCallMediaUpgradeRequestCallback?.call(data is Map ? Map<String, dynamic>.from(data) : {});
    });
    _socket!.on('call_media_upgrade_response', (data) {
      onCallMediaUpgradeResponseCallback?.call(data is Map ? Map<String, dynamic>.from(data) : {});
    });
    _socket!.on('call_screen_share_changed', (data) {
      onCallScreenShareChangedCallback?.call(data is Map ? Map<String, dynamic>.from(data) : {});
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

    // ── Server error messages ─────────────────────────────────────────────
    _socket!.on('error_message', (data) {
      final message = data is Map ? data['message'] : data;
      debugPrint('[NovynSocket] Server error: $message');
    });
  }

  bool get isConnectionDegraded => _connectionDegraded;

  void _stopConnectionHealthMonitor() {
    _connectionHealthTimer?.cancel();
    _connectionHealthTimer = null;
    _connectionHealthMisses = 0;
    _healthProbeInFlight = false;
    if (_connectionDegraded) {
      _connectionDegraded = false;
      notifyListeners();
    }
  }

  void _startConnectionHealthMonitor() {
    _connectionHealthTimer?.cancel();
    _connectionHealthMisses = 0;
    _healthProbeInFlight = false;
    _connectionDegraded = false;
    _connectionHealthTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(_probeConnectionHealth()),
    );
    unawaited(_probeConnectionHealth());
  }

  Future<void> _probeConnectionHealth() async {
    final connection = _socket;
    if (!_appForeground ||
        connection == null ||
        !_isConnected ||
        !_isAuthenticated ||
        _healthProbeInFlight) {
      return;
    }

    _healthProbeInFlight = true;
    final acknowledgement = Completer<bool>();
    connection.emitWithAck(
      'client_health_check',
      {'clientTime': DateTime.now().millisecondsSinceEpoch},
      ack: (dynamic result) {
        if (acknowledgement.isCompleted) return;
        acknowledgement.complete(
          result is Map &&
              result['ok'] == true &&
              result['authenticated'] == true,
        );
      },
    );

    final healthy = await acknowledgement.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => false,
    );
    _healthProbeInFlight = false;
    if (!identical(_socket, connection)) return;

    if (healthy) {
      _connectionHealthMisses = 0;
      if (_connectionDegraded) {
        _connectionDegraded = false;
        notifyListeners();
      }
      return;
    }

    _connectionHealthMisses++;
    if (!_connectionDegraded) {
      _connectionDegraded = true;
      notifyListeners();
    }
    debugPrint(
      '[NovynSocket] Application health acknowledgement missed '
      '($_connectionHealthMisses/2).',
    );

    // Two missed authenticated ACKs indicate a half-open/stalled transport.
    // Replace it instead of leaving the UI falsely marked as connected.
    if (_connectionHealthMisses >= 2) {
      _stopConnectionHealthMonitor();
      _isConnected = false;
      _isAuthenticated = false;
      _isConnecting = false;
      SyncService().setOnlineStatus(false);
      _socket = null;
      connection.dispose();
      notifyListeners();
      if (!_manualDisconnect) _scheduleReconnect(1);
    }
  }

  /// A push is a durable hint that a message exists. Refresh server history
  /// even if the socket transport claims to be connected.
  void syncMessageFromPush(String peer, {bool isGroup = false}) {
    final target = peer.trim();
    if (target.isEmpty) return;
    final connection = _socket;
    if (connection == null || !_isConnected || !_isAuthenticated) {
      setAppForeground(true);
      return;
    }
    connection.emit('get_history', {
      'to': target,
      'kind': isGroup ? 'group' : 'friend',
      'limit': 100,
    });
    // Refresh chat previews/unread counts independently of the active timeline.
    connection.emit('resume_session');
  }

  void _markSocketAuthenticated() {
    if (!_isConnected) return;
    _socketAuthRetryTimer?.cancel();
    _socketAuthRetryTimer = null;
    _socketAuthRetryAttempt = 0;
    _isAuthenticated = true;
    _startConnectionHealthMonitor();
    // Consumers such as Privacy settings must be notified after resume_session
    // is accepted, not only when the raw transport connects.
    notifyListeners();
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
    final ready = _authenticationReady;
    if (ready != null && !ready.isCompleted) ready.complete();
    onAuthenticated?.call();
  }

  Future<void> _waitForSocketAuthentication() async {
    if (_isConnected && _isAuthenticated) return;

    // Poll the live transport/auth state rather than awaiting a completer that
    // can become detached when a socket disconnects and is replaced.
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (!_isConnected || !_isAuthenticated) {
      if (_manualDisconnect) {
        throw StateError('Reconnect to Novyn before changing account settings.');
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
      throw StateError('Novyn is reconnecting securely. Please try again in a moment.');
    }
  }

  // ── Parse friend_list payload into ChatPreview list ───────────────────────
  void _handleFriendList(dynamic data) {
    // Socket.IO callbacks do not await async handlers. Keep failures contained
    // so one malformed friend record cannot escape as an unhandled async error.
    unawaited(_applyFriendList(data));
  }

  Future<void> _applyFriendList(dynamic data) async {
    final rawList = data is List ? data : (data is Map ? data['friends'] : null);
    if (rawList is! List) return;
    final account = _myUsername;
    if (account == null || account.isEmpty) return;

    try {
      final list = rawList.whereType<Map>().map((item) {
        try {
          return Map<String, dynamic>.from(item);
        } catch (_) {
          return null;
        }
      }).whereType<Map<String, dynamic>>().toList();

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
        // Legacy encrypted history may no longer contain a readable message body.
        final lastMsg = item['lastMessageData'] ?? item['lastMessage'];
        final lastMessageData = lastMsg is Map
            ? Map<String, dynamic>.from(lastMsg)
            : const <String, dynamic>{};
        final hasConversationActivity =
            (item['lastTimestamp']?.toString().trim().isNotEmpty ?? false) ||
            (lastMsg is Map && lastMsg.isNotEmpty) ||
            (lastMsg != null && lastMsg.toString().trim().isNotEmpty);
        // The server friend list also contains accepted contacts. Keep those
        // in Contacts/Discover, but do not create a Chats row until a first
        // message has actually started the conversation.
        if (!hasConversationActivity) continue;

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
              ? (lastMessageData['isEncrypted'] == true
                  ? 'Previous encrypted message unavailable'
                  : lastMessageData['text']?.toString() ?? '')
              : lastMsg?.toString() ?? '',
          lastMessageId: lastMessageData['id']?.toString() ?? '',
          lastMessageFrom: lastMessageData['from']?.toString() ??
              item['lastFrom']?.toString() ?? '',
          lastMessageDeliveredAt: DateTime.tryParse(
            lastMessageData['deliveredAt']?.toString() ?? '',
          ),
          lastMessageSeenAt: DateTime.tryParse(
            lastMessageData['seenAt']?.toString() ?? '',
          ),
          // Conversations without a message have no activity time.
          // Keep a stable old sentinel for sorting; the UI hides this value.
          lastTime:
              DateTime.tryParse(item['lastTimestamp']?.toString() ?? '') ??
                  DateTime(2000),
          unreadCount: (item['unreadCount'] as num?)?.toInt() ?? 0,
        ));
      }

      if (_myUsername != account) return;

      // Publish the refreshed conversation list.
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

  // ── Open a chat ────────────────────────────────────────────────────────────
  /// Opens the conversation and completes when the authenticated server has
  /// returned its history (including a legitimate empty-history response).
  /// This avoids treating a delayed socket response as an empty conversation.
  Future<List<Message>> openChat(
    String peerUsername,
    List<Message> cachedHistory, {
    bool isGroup = false,
  }) {
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
    _restorePendingMessagesForOpenChat();
    notifyListeners();
    // Ask the server whether this chat partner has enabled account-level
    // screenshot protection. Only their preference protects this conversation.
    _activeChatCaptureProtected = false;
    unawaited(SecurityService.setSafeMode(false));
    final connection = _socket;
    connection?.emit('set_active_chat', {'to': peerUsername, 'kind': isGroup ? 'group' : 'friend'});
    if (connection != null && !isGroup) {
      connection.emitWithAck('get_chat_protection', {'to': peerUsername},
        ack: (dynamic result) {
          if (_socket != connection ||
              _currentChatWith?.toLowerCase() != peerUsername.toLowerCase()) return;
          final protected = result is Map && result['ok'] == true &&
              result['protected'] == true;
          _activeChatCaptureProtected = protected;
          unawaited(SecurityService.setSafeMode(protected));
        });
    }
    connection?.emit('get_history', {'to': peerUsername, 'kind': isGroup ? 'group' : 'friend'});
    connection?.emit('get_chat_wallpaper', {'to': peerUsername, 'toType': isGroup ? 'group' : 'friend'});

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
      debugPrint('[NovynSecurity] Could not sync saved Stealth Mode preference: $error');
    }
  }

  Future<void> updateStealthMode(bool enabled) async {
    await _waitForSocketAuthentication();
    final connection = _socket;
    if (connection == null || !_isConnected) {
      throw StateError('Connect to Novyn before changing Stealth Mode.');
    }
    final completer = Completer<Map<String, dynamic>>();
    connection.emitWithAck('update_profile', {'stealthModeEnabled': enabled},
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
    if (result['ok'] != true) {
      throw StateError(result['message']?.toString() ??
          'Could not sync Stealth Mode with your account.');
    }
    _stealthModePreference = enabled;
  }

  void closeChat({bool notify = true}) {
    if (_typingTargetKey != null) _stopActiveTyping();
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

    // ChatDetailScreen calls closeChat while its own Provider subscription is
    // being disposed. Notifying listeners during that unmount pass causes an
    // unnecessary rebuild of the route that is already leaving.
    if (notify) notifyListeners();
  }

  Future<bool> loadOlderHistory(String peerUsername, String beforeMessageId, {bool isGroup = false}) async {
    if (beforeMessageId.isEmpty || !_isConnected || !_isAuthenticated) return false;
    _olderHistoryCompleter?.complete(false);
    final completer = Completer<bool>();
    _olderHistoryCompleter = completer;
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
    if (!isGroup && attachment != null) {
      throw StateError(
        'Secure media sharing is being prepared. Please send text-only messages for now.',
      );
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

    _messageStatuses[clientTempId] = 'queued';
    _messageStatusRevision++;
    _messages = [..._messages, tempMsg];
    notifyListeners();

    try {
      await (_outboxActivation ?? SyncService().activateAccount(account));
      if (_myUsername != account) {
        throw StateError('Your account changed before this message was queued.');
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

      // The durable outbox is the source of truth. Never make the composer
      // wait for a slow/weak network acknowledgement; flush in the background.
      if (_isConnected && _isAuthenticated) {
        unawaited(_flushPendingMessageOutbox());
      }
    } catch (error) {
      _messageStatuses[clientTempId] = SyncService().pendingMessages.any((item) => item.tempId == clientTempId) ? 'queued' : 'failed';
      _messageStatusRevision++;
      notifyListeners();
      rethrow;
    }
  }

  void sendGameChallenge(String gameType, String peerUsername, {bool isGroup = false}) {
    _requireConnection();
    _socket!.emit('private_message', {
      'to': peerUsername,
      'toType': isGroup ? 'group' : 'friend',
      'text': '🎮 Started a game of ${_gameTitle(gameType)}!',
      'clientTempId': 'tmp_game_${DateTime.now().millisecondsSinceEpoch}',
      'game': {
        'id': 'game_${DateTime.now().millisecondsSinceEpoch}',
        'gameType': gameType,
      },
    });
  }

  String _gameTitle(String type) {
    const titles = {
      'tictactoe': 'Tic-Tac-Toe',
      'rps': 'Rock • Paper • Scissors',
      'connect4': 'Connect 4',
      'doodle': 'Doodle Duel',
      'numberclash': 'Number Clash',
      'updown': 'Up or Down',
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
      onTimeout: () => {'ok': false, 'message': 'Game move timed out. Please retry.'},
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

  void setChatWallpaper(String wallpaper, String peerUsername, {bool isGroup = false}) {
    _requireConnection();
    _socket!.emit('set_chat_wallpaper', {
      'to': peerUsername,
      'toType': isGroup ? 'group' : 'friend',
      'wallpaper': wallpaper,
    });
  }

  void pinMessage(String messageId, String peerUsername, {bool isGroup = false}) {
    _requireConnection();
    _socket!.emit('pin_message', {
      'messageId': messageId,
      'to': peerUsername,
      'toType': isGroup ? 'group' : 'friend',
    });
  }

  void unpinMessage(String messageId, String peerUsername, {bool isGroup = false}) {
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

  void forwardMessage(Message message, String targetUsername, {bool isGroup = false}) {
    _requireConnection();
    _socket!.emit('private_message', {
      'to': targetUsername,
      'toType': isGroup ? 'group' : 'friend',
      'text': message.text,
      'attachment': message.attachment,
      'clientTempId': 'tmp_forward_${DateTime.now().millisecondsSinceEpoch}',
    });
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
          original.text == 'Previous encrypted message unavailable') {
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
    _socket!.emitWithAck('cancel_friend_request', username, ack: (dynamic data) {
      if (data is Map && data['ok'] == true) {
        contacts.applyEvent('friend_request_cancelled', {'to': username});
        if (!completer.isCompleted) completer.complete();
      } else if (!completer.isCompleted) {
        completer.completeError(StateError(
          data is Map ? data['message']?.toString() ?? 'Could not cancel request.' : 'Could not cancel request.',
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
          data is Map ? data['message']?.toString() ?? 'Could not accept request.' : 'Could not accept request.',
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
          data is Map ? data['message']?.toString() ?? 'Could not decline request.' : 'Could not decline request.',
        ));
      }
    });
    await completer.future.timeout(const Duration(seconds: 12));
  }

  void removeFriend(String username) {
    _requireConnection();
    _socket!.emit('remove_friend', username);
  }

  void setMute(String username, {required bool muted}) {
    _requireConnection();
    _socket!.emit('set_mute', {'username': username, 'muted': muted});
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
    _socket!.emitWithAck('mark_all_read', <String, dynamic>{}, ack: (dynamic result) {
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
      throw StateError('Connect to Novyn before sending messages or changing contacts.');
    }
    if (!_isAuthenticated) {
      throw StateError('Novyn is verifying your session. Please wait and try again.');
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

  void updateCallScreenShare(String toUsername, String callId, String? streamId) {
    _socket?.emit('call_screen_share_state', {
      'to': toUsername, 'callId': callId, 'streamId': streamId,
    });
  }

  void requestCallMediaUpgrade(String toUsername, String callId) {
    _socket?.emit('call_media_upgrade_request', {'to': toUsername, 'callId': callId});
  }

  void respondCallMediaUpgrade(String toUsername, String callId, {required bool accepted}) {
    _socket?.emit('call_media_upgrade_response', {
      'to': toUsername, 'callId': callId, 'accepted': accepted,
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
    final asset = switch (tone) {
      'Pulse' => 'audio/message_sent.mp3',
      'Glass' => 'audio/ringtone.mp3',
      'Echo' => 'audio/call_ring.mp3',
      _ => 'audio/notification.mp3',
    };
    final volume = (messageSoundVolume?.call() ?? 0.8)
        .clamp(0.0, 1.0)
        .toDouble();
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
      onTimeout: () => {'ok': false, 'message': 'Email request timed out. Try again.'});
  }

  Future<Map<String, dynamic>> verifyEmailChangeCode({
    required String email,
    required String code,
  }) async {
    _requireConnection();
    final completer = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck('verify_email_change_code', {
      'email': email.trim(), 'code': code.trim(),
    }, ack: (dynamic data) {
      if (!completer.isCompleted) {
        completer.complete(data is Map
          ? Map<String, dynamic>.from(data)
          : {'ok': false, 'message': 'Unexpected server response.'});
      }
    });
    return completer.future.timeout(const Duration(seconds: 20),
      onTimeout: () => {'ok': false, 'message': 'Verification timed out. Try again.'});
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
        completer.completeError(StateError(message ?? 'Could not change username.'));
      }
    }
    void disconnected(dynamic _) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Connection lost before the username change was confirmed.'));
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
        onTimeout: () => throw StateError('Username change timed out. Check your connection and try again.'));
    } finally {
      connection.off('username_changed', succeeded);
      connection.off('username_change_failed', failed);
      connection.off('disconnect', disconnected);
    }
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
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
        confirmed.completeError(StateError(message ?? 'Could not change your password.'));
      }
    }

    void disconnected(dynamic _) {
      if (!confirmed.isCompleted) {
        confirmed.completeError(StateError('Connection lost before the password change was confirmed. Please sign in again.'));
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
      throw StateError('Could not confirm the password change. Check your connection and try signing in again.');
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
          message ?? 'Account deletion was rejected. Check your confirmation and password.',
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

  Future<Map<String, dynamic>> registerFcmToken(
    String token, {
    int appBuild = 0,
    String platform = 'android',
  }) async {
    _requireConnection();
    final completer = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck('register_fcm_token', {
      'token': token,
      'appBuild': appBuild,
      'platform': platform,
    }, ack: (dynamic result) {
      completer.complete(result is Map
          ? Map<String, dynamic>.from(result)
          : {'ok': false, 'message': 'The server did not confirm this device.'});
    });
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => {'ok': false, 'message': 'Device registration timed out.'},
    );
  }

  Future<Map<String, dynamic>> clearFcmToken([String? token]) async {
    if (!_isConnected || _socket == null) {
      return {'ok': false, 'message': 'Device is offline.'};
    }
    final completer = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck('clear_fcm_token', {
      if (token != null && token.isNotEmpty) 'token': token,
    }, ack: (dynamic result) {
      completer.complete(result is Map
          ? Map<String, dynamic>.from(result)
          : {'ok': false, 'message': 'The server did not confirm device removal.'});
    });
    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => {'ok': false, 'message': 'Device removal timed out.'},
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
          : {'ok': false, 'message': 'The server did not confirm this change.'});
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
    _socket!.emitWithAck('get_account_settings', <String, dynamic>{}, ack: (dynamic result) {
      completer.complete(result is Map
          ? Map<String, dynamic>.from(result)
          : {'ok': false, 'message': 'The server did not return account settings.'});
    });
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => {'ok': false, 'message': 'Loading account settings timed out.'},
    );
  }

  Future<Map<String, dynamic>> updateAccountSettings(Map<String, dynamic> changes) async {
    await _requireAuthenticatedConnection();
    final completer = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck('update_profile', changes, ack: (dynamic result) {
      completer.complete(result is Map
          ? Map<String, dynamic>.from(result)
          : {'ok': false, 'message': 'The server did not confirm this setting.'});
    });
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => {'ok': false, 'message': 'Settings update timed out.'},
    );
  }

  Future<void> updatePresence(String mode) async {
    await _requireAuthenticatedConnection();
    final confirmed = Completer<void>();
    _socket!.emitWithAck(
      'update_profile',
      {'presenceMode': mode},
      ack: (dynamic result) {
        if (confirmed.isCompleted) return;
        if (result is Map && result['ok'] == true) {
          confirmed.complete();
        } else {
          final message = result is Map
              ? result['message']?.toString()
              : null;
          confirmed.completeError(StateError(
            message?.isNotEmpty == true
                ? message!
                : 'The server did not confirm the status update.',
          ));
        }
      },
    );
    await confirmed.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException(
        'Status update timed out. Check your connection and try again.',
      ),
    );
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
    connection.emitWithAck('get_group_info', {'groupId': groupId}, ack: (dynamic result) {
      if (acknowledgement.isCompleted) return;
      acknowledgement.complete(result is Map
          ? Map<String, dynamic>.from(result)
          : <String, dynamic>{'ok': false, 'message': 'Unexpected server response.'});
    });
    final result = await acknowledgement.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => <String, dynamic>{'ok': false, 'message': 'Loading group information timed out.'},
    );
    if (result['ok'] != true || result['group'] is! Map) {
      throw StateError(result['message']?.toString() ?? 'Could not load group information.');
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
          : <String, dynamic>{'ok': false, 'message': 'The server did not confirm this group update.'});
    });
    final result = await completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => <String, dynamic>{'ok': false, 'message': 'Group update timed out. Please retry.'},
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
  ) => _groupAction('add_group_members', {
    'groupId': groupId,
    'members': usernames,
  });

  Future<Map<String, dynamic>> removeGroupMember(
    String groupId,
    String username,
  ) => _groupAction('remove_group_member', {
    'groupId': groupId,
    'username': username,
  });

  Future<Map<String, dynamic>> setGroupMemberRole(
    String groupId,
    String username, {
    required String role,
  }) => _groupAction('set_group_member_role', {
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
          : <String, dynamic>{'ok': false, 'message': 'Unexpected server response.'});
    });
    final result = await acknowledgement.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => <String, dynamic>{'ok': false, 'message': 'Group creation timed out. Please try again.'},
    );
    if (result['ok'] != true) {
      throw StateError(result['message']?.toString() ?? 'Could not create group.');
    }
    final group = result['group'];
    final id = group is Map ? group['id']?.toString() : result['groupId']?.toString();
    if (id == null || id.isEmpty) {
      throw StateError('The server created no group ID. Refresh your chats and try again.');
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
    _stopConnectionHealthMonitor();
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
    _authenticationReady = null;
    onAuthenticated = null;
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
    _typingInChats.clear();
    contacts.clear();
    _reconnectTimer?.cancel();
    _stopActiveTyping();
    _socket?.dispose();
    _reconnectTimer?.cancel();
    _socket = null;
    _isConnected = false;
    _isConnecting = false;
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
