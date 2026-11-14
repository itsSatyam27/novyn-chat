import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import '../models/chat_models.dart';
import '../models/chat_preview.dart';
import '../models/user_model.dart';
import 'hybrid_db_service.dart';
import 'api_service.dart';
import 'media_storage_service.dart';
import 'backend_contacts.dart';
import 'message_encryption_service.dart';
import 'security_service.dart';

/// Socket service for the shared novyn-chat backend (server.js).
///
/// Event vocabulary (novyn-chat):
///   EMIT  resume_session           — authenticate socket after connect
///   EMIT  set_active_chat          — { to, kind }
///   EMIT  get_history              — { to, kind }
///   EMIT  private_message          — { to, toType, text, attachment?, replyTo?, clientTempId, ciphertext?, iv?, isEncrypted? }
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
  // Uses the same ECDH P-256 + AES-GCM-256 wire format as the web client.
  final encryption = MessageEncryptionService();
  Future<void>? _identityRegistration;
  String? _registeredIdentityAccount;
  bool _isAuthenticated = false;
  bool _hasLoadedConversations = false;
  Completer<void>? _authenticationReady;
  Completer<bool>? _olderHistoryCompleter;
  VoidCallback? onAuthenticated;
  final Map<String, String> _peerKeys = {};
  final BackendContacts contacts = BackendContacts();
  io.Socket? _socket;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _manualDisconnect = false;
  bool _refreshingSocketSession = false;
  bool _appForeground = true;
  String? _myUsername; // novyn-chat username (not Firebase UID)
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Map<String, String> _messageStatuses = {};
  int _messageStatusRevision = 0;
  final Map<String, DateTime> _messageDeliveredAt = {};
  final Map<String, DateTime> _messageSeenAt = {};
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

  // Messages for the currently open chat (immutable list — replaced on update)
  List<Message> _messages = [];
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
  Function(Map)? onWebRTCSignalCallback;

  // Status and foreground message callbacks
  Function(String username, bool isOnline)? onUserStatusChanged;
  Function(String sender, String body)? onIncomingMessage;
  VoidCallback? onConnected;

  List<Message> get messages => List.unmodifiable(_messages);
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
    _reconnectTimer?.cancel();
    _isConnected = false;
    _isConnecting = false;
    _isAuthenticated = false;
    _authenticationReady = null;
    _registeredIdentityAccount = null;
    notifyListeners();
    _doConnect();
  }

  Future<void> _refreshAfterSocketAuthFailure() async {
    if (_refreshingSocketSession) return;
    _refreshingSocketSession = true;
    try {
      final status = await ApiService.refreshSessionStatus()
          .timeout(const Duration(seconds: 12), onTimeout: () => null);
      if (status == 200 && !_manualDisconnect) {
        await reconnectWithCurrentSession();
      }
    } catch (error) {
      debugPrint('[NovynSocket] Session refresh after auth failure failed: $error');
    } finally {
      _refreshingSocketSession = false;
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
    if ((_socket != null && _socket!.connected && _isConnected) ||
        _isConnecting) return;
    _doConnect();
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

    _socket!.onConnect((_) {
      _isConnecting = false;
      _isConnected = true;
      _isAuthenticated = false;
      _stealthPreferenceSynced = false;
      _authenticationReady = Completer<void>();
      _registeredIdentityAccount = null;
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
      _isConnecting = false;
      _isConnected = false;
      _isAuthenticated = false;
      // A completed future from an old socket must never authenticate a new one.
      _authenticationReady = null;
      _registeredIdentityAccount = null;
      notifyListeners();
      if (!_manualDisconnect) _scheduleReconnect(3);
    });

    _socket!.onConnectError((_) {
      _isConnecting = false;
      _isConnected = false;
      _isAuthenticated = false;
      _authenticationReady = null;
      _registeredIdentityAccount = null;
      notifyListeners();
      if (!_manualDisconnect) _scheduleReconnect(5);
    });

    _registerEventHandlers();
    _socket!.on('auth_failed', (data) {
      _isAuthenticated = false;
      notifyListeners();
      // A stale access cookie can leave a newly connected socket without a
      // userKey. Refresh the HTTP session once, then rebuild the socket
      // handshake with the rotated cookie. Never clear the local account here.
      if (!_refreshingSocketSession && !_manualDisconnect) {
        unawaited(_refreshAfterSocketAuthFailure());
      }
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

    if (changed && _isConnected) {
      _socket?.emit('app_visibility', {'foreground': true});
    }
    if (_isConnected && _isAuthenticated) {
      _requestActiveChatRefresh();
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
      unawaited(_registerEncryptionIdentity());
    });
    // ── Initial data + friend list ────────────────────────────────────────
    _socket!.on('init', (data) {
      if (data is Map && data['friends'] != null) {
        _handleFriendList(data['friends']);
      }
      _markSocketAuthenticated();
      unawaited(_registerEncryptionIdentity());
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

    _socket!.on('peer_public_key_updated', (data) {
      if (data is Map) {
        final username = data['username']?.toString() ?? '';
        _peerKeys[username.toLowerCase()] =
            data['publicKey']?.toString() ?? '';
        if (_currentChatWith?.toLowerCase() == username.toLowerCase()) {
          unawaited(decryptCurrentMessages());
        }
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
        final decrypted = await Future.wait(
            parsed.map((message) => encryption.decrypt(message, account, _peerKeys[withUser.toLowerCase()])));
        if (_myUsername != account ||
            _currentChatWith?.toLowerCase() != withUser.toLowerCase()) {
          return;
        }
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
        final timeline = merged.values.toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _messages = _resolveReplyPreviews(timeline);
        HybridDbService.saveMessages(_messages);
        final olderRequest = _olderHistoryCompleter;
        if (olderRequest != null && !olderRequest.isCompleted) {
          olderRequest.complete(data['hasMore'] == true);
        }
        notifyListeners();
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
      if (!isGroupMessage) {
        msg = await encryption.decrypt(msg, account, _peerKeys[chatPartner.toLowerCase()]);
      }
      if (isOwn) {
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

      // Save to local DB
      HybridDbService.saveMessage(msg);
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
        if (!isGroupMessage) {
          onIncomingMessage?.call(chatPartner, msg.text);
        }
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
      final current = _messageStatuses[msgId] ?? 'sent';
      if (current == 'seen' || (current == 'delivered' && next == 'delivered')) return;
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
      final normalized = username.toLowerCase();

      // Keep every Flutter surface in sync: contacts, cached chat previews,
      // and the active chat header all consume the same live presence event.
      contacts.updateStatus(username, online, presence: presence);
      _conversations = _conversations.map((chat) {
        if (chat.isGroup || chat.peerUid.toLowerCase() != normalized) {
          return chat;
        }
        final updatedPeer = chat.peer.copyWith(
          isOnline: online,
          status: presence ?? (online ? 'online' : 'offline'),
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

  void _markSocketAuthenticated() {
    if (!_isConnected) return;
    _isAuthenticated = true;
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

  Future<void> _registerEncryptionIdentity() async {
    final account = _myUsername;
    final connection = _socket;
    if (account == null || connection == null || !_isConnected || !_isAuthenticated) return;
    if (_registeredIdentityAccount == account.toLowerCase()) return;
    final active = _identityRegistration;
    if (active != null) return active;

    final task = () async {
      try {
        final publicKey = await encryption.initializeIdentity(account);
        if (publicKey.isEmpty || _myUsername != account ||
            _socket != connection || !_isConnected) return;
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
        if (result['ok'] == true && _myUsername == account && _socket == connection) {
          _registeredIdentityAccount = account.toLowerCase();
        } else {
          debugPrint('[NovynE2EE] Device identity registration was not confirmed.');
        }
      } catch (error) {
        debugPrint('[NovynE2EE] Identity setup failed: $error');
      }
    }();

    _identityRegistration = task;
    try {
      await task;
    } finally {
      if (identical(_identityRegistration, task)) _identityRegistration = null;
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
        // The relay keeps the encrypted envelope in lastMessageData. The
        // legacy lastMessage field may not contain the ciphertext/IV.
        final lastMsg = item['lastMessageData'] ?? item['lastMessage'];
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
          lastTime:
              DateTime.tryParse(item['lastTimestamp']?.toString() ?? '') ??
                  DateTime.now(),
          unreadCount: (item['unreadCount'] as num?)?.toInt() ?? 0,
        ));
      }

      // Publish the authenticated server snapshot immediately. UI rendering
      // must not wait for Hive/Drift writes; slow local storage previously made
      // conversations appear empty or load unpredictably.
      _conversations = previews;
      _hasLoadedConversations = true;
      notifyListeners();

      // Persist in the background so the next app launch can hydrate instantly.
      await Future.wait([
        HybridDbService.saveUsers(peers),
        HybridDbService.saveChats(previews),
      ]);
      if (_myUsername != account) return;

      for (final item in list) {
        try {
          final raw = item['lastMessageData'] ?? item['lastMessage'];
          if (raw is! Map || raw['isEncrypted'] != true) continue;
          final peer = item['username']?.toString() ?? '';
          if (peer.isEmpty) continue;

          final decrypted = await encryption.decrypt(
            Message(
              id: raw['id']?.toString() ?? '',
              chatId: peer,
              text: raw['text']?.toString() ?? '🔒 Encrypted message',
              isFromMe: false,
              isEncrypted: true,
              ciphertext: raw['ciphertext']?.toString(),
              iv: raw['iv']?.toString(),
            ),
            account,
            _peerKeys[peer.toLowerCase()],
          );
          if (_myUsername != account) return;
          if (decrypted.needsMessageKey) continue;

          final index = _conversations.indexWhere(
            (chat) => chat.peerUid.toLowerCase() == peer.toLowerCase(),
          );
          // Do not replace a newer live preview with an older snapshot.
          if (index >= 0 &&
              (_conversations[index].lastMessage == '🔒 Encrypted message' ||
                  _conversations[index].lastMessage == raw['text'])) {
            final updated = List<ChatPreview>.from(_conversations);
            updated[index] =
                updated[index].copyWith(lastMessage: decrypted.text);
            _conversations = updated;
            unawaited(HybridDbService.saveChat(updated[index]));
            notifyListeners();
          }
        } catch (error) {
          debugPrint('[NovynSocket] Could not decrypt chat preview: $error');
        }
      }
    } catch (error, stackTrace) {
      debugPrint('[NovynSocket] Friend list refresh failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      // Keep the last good snapshot visible; a later server event can retry.
      notifyListeners();
    }
  }

  // ── Open a chat ────────────────────────────────────────────────────────────
  void openChat(String peerUsername, List<Message> cachedHistory, {bool isGroup = false}) {
    if (_typingTargetKey != null) _stopActiveTyping();
    _currentChatWith = peerUsername;
    _currentChatIsGroup = isGroup;
    _chatWallpaper = '';
    _messages = List<Message>.from(cachedHistory);
    _peerIsTyping = false;
    notifyListeners();

    unawaited(decryptCurrentMessages());

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

  void closeChat() {
    if (_typingTargetKey != null) _stopActiveTyping();
    _currentChatWith = null;
    _currentChatIsGroup = false;
    _activeChatCaptureProtected = false;
    unawaited(SecurityService.setSafeMode(false));
    _messages = [];
    _peerIsTyping = false;
    notifyListeners();
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
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _messages = _resolveReplyPreviews(timeline);
    notifyListeners();
  }

  void prependOlderMessages(List<Message> older) {
    final merged = <String, Message>{};
    for (final message in [...older, ..._messages]) {
      if (message.id.isNotEmpty) merged[message.id] = message;
    }
    final timeline = merged.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
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

    final clientTempId = 'tmp_${DateTime.now().microsecondsSinceEpoch}';
    final toType = isGroup ? 'group' : 'friend';
    final rawText = trimmedText.isNotEmpty
        ? trimmedText
        : (attachment?['kind'] == 'image' ? '[Image]' : '[File]');
    // A resumed app may still be reconnecting after Android suspended its
    // process. Wait for an authenticated socket before rejecting the send.
    if (!_isConnected && !_manualDisconnect) {
      _scheduleReconnect(1);
    }
    await _waitForSocketAuthentication();
    _requireConnection();

    // New Flutter messages are plaintext. Device identity registration is
    // already started in the background after socket authentication, so never
    // wait for secure storage or P-256 key setup before sending a message.
    final payload = <String, dynamic>{
      'to': toPeerUsername,
      'toType': toType,
      'text': rawText,
      'attachment': attachment,
      'replyTo': replyToId == null
          ? null
          : {
              'id': replyToId,
              'text': replyToText ?? '',
              'from': replyToSender ?? '',
            },
      'clientTempId': clientTempId,
    };

    // New messages intentionally remain plaintext. The incoming/history
    // handlers still decrypt older encrypted messages for backward compatibility.

    _messageStatuses[clientTempId] = 'sending';
    _messageStatusRevision++;
    final tempMsg = Message(
      id: clientTempId,
      chatId: toPeerUsername,
      text: rawText,
      senderId: account,
      isFromMe: true,
      createdAt: DateTime.now(),
      replyToId: replyToId,
      replyToText: replyToText,
      replyToSender: replyToSender,
      attachment: attachment,
      isEncrypted: payload['isEncrypted'] == true,
      ciphertext: payload['ciphertext']?.toString(),
      iv: payload['iv']?.toString(),
    );
    _messages = [..._messages, tempMsg];
    notifyListeners();

    final connection = _socket!;
    final acknowledgement = Completer<Map<String, dynamic>>();
    connection.emitWithAck('private_message', payload, ack: (dynamic result) {
      if (acknowledgement.isCompleted) return;
      acknowledgement.complete(
        result is Map
            ? Map<String, dynamic>.from(result)
            : <String, dynamic>{'ok': false, 'message': 'Unexpected server response.'},
      );
    });

    try {
      final result = await acknowledgement.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException(
          'Delivery was not confirmed. Check your connection before retrying.',
        ),
      );
      if (result['ok'] != true) {
        throw StateError(
          result['message']?.toString() ?? 'The server could not send this message.',
        );
      }
      // The server's private_message echo replaces this optimistic message.
    } catch (_) {
      // Keep the optimistic bubble visible so the user can see the failed state
      // and the UI can offer a retry affordance in a later iteration.
      final index = _messages.indexWhere((message) => message.id == clientTempId);
      if (index >= 0) {
        _messageStatuses[clientTempId] = 'failed';
        _messageStatusRevision++;
        notifyListeners();
      }
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

  Future<void> decryptCurrentMessages() async {
    final account = _myUsername;
    final peer = _currentChatWith;
    if (account == null || peer == null) return;
    final snapshot = _messages;
    final decrypted = await Future.wait(
        snapshot.map((message) => encryption.decrypt(message, account, _peerKeys[peer.toLowerCase()])));
    if (_myUsername != account || _currentChatWith != peer) return;
    final byId = {for (final message in decrypted) message.id: message};
    _messages = _messages
        .map((message) => byId[message.id]?.ciphertext == message.ciphertext
            ? byId[message.id] ?? message
            : message)
        .toList();
    _messages = _resolveReplyPreviews(_messages);
    await HybridDbService.saveMessages(_messages);

    // Keep the conversation-list preview in sync with the decrypted latest
    // message. The chat view can decrypt successfully after keys/history load,
    // while the cached friend-list preview may still contain the ciphertext
    // placeholder from the initial socket snapshot.
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
          final updated = List<ChatPreview>.from(_conversations);
          updated[previewIndex] = updated[previewIndex].copyWith(
            lastMessage: latest.text,
            lastTime: latest.createdAt,
          );
          _conversations = updated;
          await HybridDbService.saveChat(updated[previewIndex]);
        }
      }
    }
    notifyListeners();
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

  void requestDiscover() {
    if (_isConnected && _isAuthenticated && _socket != null) {
      _socket!.emit('discover_online');
    }
  }

  void _requireConnection() {
    if (!_isConnected || _socket == null) {
      throw StateError('Connect to Novyn before sending messages or changing contacts.');
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

  Future<Map<String, dynamic>> registerFcmToken(String token) async {
    _requireConnection();
    final completer = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck('register_fcm_token', {'token': token}, ack: (dynamic result) {
      completer.complete(result is Map
          ? Map<String, dynamic>.from(result)
          : {'ok': false, 'message': 'The server did not confirm this device.'});
    });
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => {'ok': false, 'message': 'Device registration timed out.'},
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
    _manualDisconnect = true;
    _myUsername = null;
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
