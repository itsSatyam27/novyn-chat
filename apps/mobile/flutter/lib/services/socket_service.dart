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
///   EMIT  call_end                 — { to, reason? }
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
///   ON    call_end
///   ON    webrtc_signal            — { from, signal }
///   ON    profile_updated
///   ON    friend_request_received  — { from }
///   ON    friend_request_accepted  — { by }
///   ON    friend_removed           — { username }
///   ON    error_message            — { message }

class SocketService extends ChangeNotifier {
  // Uses the same per-conversation AES-GCM keys and relay envelope as the web client.
  final encryption = MessageEncryptionService();
  final Map<String, String> _peerKeys = {};
  final BackendContacts contacts = BackendContacts();
  io.Socket? _socket;
  bool _isConnected = false;
  bool _manualDisconnect = false;
  String? _myUsername; // novyn-chat username (not Firebase UID)
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Reconnection state
  String? _serverUrl;
  Timer? _reconnectTimer;

  // Messages for the currently open chat (immutable list — replaced on update)
  List<Message> _messages = [];
  String? _currentChatWith; // the username of the other party
  String _chatWallpaper = '';
  String get chatWallpaper => _chatWallpaper;

  // Typing
  bool _peerIsTyping = false;
  Timer? _typingDebounce;
  Timer? _typingStopTimer;

  // Typing across other chats: peerUsername → true
  final Map<String, bool> _typingInChats = {};
  Map<String, bool> get typingInChats => Map.unmodifiable(_typingInChats);

  // Conversations list (mirrors novyn-chat's friend_list)
  List<ChatPreview> _conversations = [];
  List<ChatPreview> get conversations => List.unmodifiable(_conversations);
  List<String> _blockedUsers = [];
  List<String> get blockedUsers => List.unmodifiable(_blockedUsers);

  // Call event callbacks
  Function(Map)? onCallInviteCallback;
  Function(Map)? onCallAcceptedCallback;
  Function()? onCallRejectedCallback;
  Function()? onCallEndedCallback;
  Function(Map)? onWebRTCSignalCallback;

  // Status callbacks
  Function(String username, bool isOnline)? onUserStatusChanged;
  VoidCallback? onConnected;

  List<Message> get messages => List.unmodifiable(_messages);
  bool get isConnected => _isConnected;
  bool get peerIsTyping => _peerIsTyping;
  String? get currentChatWith => _currentChatWith;
  String? get myUsername => _myUsername;

  // ── Connect ───────────────────────────────────────────────────────────────
  void connect(String serverUrl, String username) {
    _manualDisconnect = false;
    if (_socket != null && _myUsername != null &&
        _myUsername!.toLowerCase() != username.toLowerCase()) {
      disconnect();
    }
    _serverUrl = serverUrl;
    _myUsername = username;
    if (_socket != null && _isConnected) return;
    _doConnect();
  }

  void _doConnect() {
    if (_serverUrl == null || _myUsername == null) return;

    // novyn-chat authenticates via cookie on the HTTP handshake,
    // not via a query param. We pass the cookie in extraHeaders.
    final headers = <String, dynamic>{};
    if (ApiService.sessionCookie != null) {
      headers['Cookie'] = ApiService.sessionCookie!;
    }

    _socket = io.io(_serverUrl!, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'extraHeaders': headers,
      'reconnection': false, // manual reconnection
    });

    _socket!.onConnect((_) {
      _isConnected = true;
      _reconnectTimer?.cancel();

      // novyn-chat requires resume_session after connect to authenticate
      // the socket and receive the initial friend_list + requests.
      _socket!.emit('resume_session');

      MediaStorageService.watchConnectivity();
      onConnected?.call();
      notifyListeners();
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      notifyListeners();
      if (!_manualDisconnect) _scheduleReconnect(3);
    });

    _socket!.onConnectError((_) {
      _isConnected = false;
      notifyListeners();
      if (!_manualDisconnect) _scheduleReconnect(5);
    });

    _registerEventHandlers();
    _socket!.connect();
  }

  void _scheduleReconnect(int seconds) {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      if (!_isConnected) _doConnect();
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
    });
    // ── Initial data + friend list ────────────────────────────────────────
    _socket!.on('init', (data) {
      if (data is Map && data['friends'] != null) {
        _handleFriendList(data['friends']);
      }
    });

    _socket!.on('friend_list', (data) => _handleFriendList(data));
    _socket!.on('friend_list_updated', (data) => _handleFriendList(data));

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
        _peerKeys[data['username'].toString().toLowerCase()] =
            data['publicKey']?.toString() ?? '';
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
        final decrypted = await Future.wait(
            parsed.map((message) => encryption.decrypt(message, account)));
        if (_myUsername != account ||
            _currentChatWith?.toLowerCase() != withUser.toLowerCase()) {
          return;
        }
        // Keep messages received while asynchronous history decryption ran.
        final ids = parsed.map((message) => message.id).toSet();
        final newest = parsed.isEmpty
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : parsed.last.createdAt;
        _messages = [
          ...decrypted,
          ..._messages.where((message) =>
              !ids.contains(message.id) && message.createdAt.isAfter(newest))
        ];
        HybridDbService.saveMessages(decrypted);
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
      final chatPartner = isOwn ? receiver : sender;

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
      msg = await encryption.decrypt(msg, account);
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
        // Message for a different chat — sound and vibration are independent preferences.
        if (!(notificationsMuted?.call() ?? false)) {
          unawaited(_playIncomingMessageSound());
        }
        final vibrate = notificationsVibrate;
        if (vibrate != null) unawaited(vibrate());
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
      final msgId = data['id']?.toString() ?? '';
      if (msgId.isEmpty) return;
      final idx = _messages.indexWhere((m) => m.id == msgId);
      if (idx != -1) {
        // We store status info as a flag in the message for now.
        // A full implementation would carry a status field on Message.
        notifyListeners();
      }
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

      if (_currentChatWith != null &&
          from.toLowerCase() == _currentChatWith!.toLowerCase()) {
        _peerIsTyping = isTyping;
      }
      _typingInChats[from.toLowerCase()] = isTyping;
      notifyListeners();
    });

    // ── User presence ─────────────────────────────────────────────────────
    _socket!.on('user_status', (data) {
      if (data is! Map) return;
      final username = data['username']?.toString() ?? '';
      final online = data['online'] == true;
      if (username.isNotEmpty) onUserStatusChanged?.call(username, online);
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

    _socket!.on('call_end', (_) {
      onCallEndedCallback?.call();
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
      debugPrint('[NovynSocket] Server error: ${data['message']}');
    });
  }

  // ── Parse friend_list payload into ChatPreview list ───────────────────────
  void _handleFriendList(dynamic data) async {
    final list = data is List ? data : (data is Map ? data['friends'] : null);
    if (list is! List) return;

    final previews = list.map<ChatPreview>((item) {
      final username =
          item['username']?.toString() ?? item['groupId']?.toString() ?? '';
      final displayName = item['displayName']?.toString() ??
          item['name']?.toString() ??
          username;
      final lastMsg = item['lastMessage'];
      if (item['publicKey'] != null) {
        _peerKeys[username.toLowerCase()] = item['publicKey'].toString();
      }

      // Build a minimal UserModel so ChatPreview's required field is satisfied
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

      return ChatPreview(
        chatId: username.toLowerCase(),
        peerUid: username,
        peer: peerModel,
        isGroup: item['kind'] == 'group' || item['groupId'] != null,
        lastMessage: lastMsg is Map
            ? lastMsg['text']?.toString() ?? ''
            : lastMsg?.toString() ?? '',
        lastTime: DateTime.tryParse(item['lastTimestamp']?.toString() ?? '') ??
            DateTime.now(),
        unreadCount: (item['unreadCount'] as num?)?.toInt() ?? 0,
      );
    }).toList();

    _conversations = previews;
    HybridDbService.saveChats(previews);
    notifyListeners();
    final account = _myUsername;
    if (account == null) return;
    for (final item in list) {
      final raw = item['lastMessage'];
      if (raw is! Map || raw['isEncrypted'] != true) continue;
      final peer = item['username']?.toString() ?? '';
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
          account);
      if (_myUsername != account) return;
      if (decrypted.needsMessageKey) continue;
      final index = _conversations.indexWhere(
          (chat) => chat.peerUid.toLowerCase() == peer.toLowerCase());
      // Avoid replacing a newer live preview with the older friend-list snapshot.
      if (index >= 0 && _conversations[index].lastMessage == raw['text']) {
        final updated = List<ChatPreview>.from(_conversations);
        updated[index] = updated[index].copyWith(lastMessage: decrypted.text);
        _conversations = updated;
        HybridDbService.saveChat(updated[index]);
        notifyListeners();
      }
    }
  }

  // ── Open a chat ────────────────────────────────────────────────────────────
  void openChat(String peerUsername, List<Message> cachedHistory) {
    _currentChatWith = peerUsername;
    _chatWallpaper = '';
    _messages = List<Message>.from(cachedHistory);
    _peerIsTyping = false;
    notifyListeners();

    unawaited(decryptCurrentMessages());

    // Tell the server which chat is active and request latest history
    _socket?.emit('set_active_chat', {'to': peerUsername, 'kind': 'friend'});
    _socket?.emit('get_history', {'to': peerUsername, 'kind': 'friend'});
    _socket?.emit('get_chat_wallpaper', {'to': peerUsername, 'toType': 'friend'});
  }

  void closeChat() {
    _currentChatWith = null;
    _messages = [];
    _peerIsTyping = false;
    notifyListeners();
  }

  void prependOlderMessages(List<Message> older) {
    _messages = [...older, ..._messages];
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
    _requireConnection();
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
    final peerKey = isGroup ? null : _peerKeys[toPeerUsername.toLowerCase()];

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

    // Match the web client: encrypt only when the peer has a published key.
    // A missing local conversation key is an actionable error, never a silent
    // plaintext fallback.
    if (peerKey != null && peerKey.isNotEmpty && !isGroup) {
      final encrypted = await encryption.encrypt(
        rawText,
        account,
        toPeerUsername,
        peerKey,
      );
      if (encrypted == null) {
        throw StateError(
          'This chat needs its message key. Import your Novyn message keys from the web app before sending.',
        );
      }
      payload
        ..['text'] = '🔒 Encrypted message'
        ..['ciphertext'] = encrypted['ciphertext']
        ..['iv'] = encrypted['iv']
        ..['isEncrypted'] = true;
      if (payload['replyTo'] is Map) {
        payload['replyTo'] = {
          ...Map<String, dynamic>.from(payload['replyTo']),
          'text': '🔒 Encrypted message',
        };
      }
    }

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
      // Remove only the temporary bubble. If the server echo already replaced
      // it, keep the confirmed message visible.
      final index = _messages.indexWhere((message) => message.id == clientTempId);
      if (index >= 0) {
        _messages = List<Message>.from(_messages)..removeAt(index);
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

  void makeGameMove(String messageId, String peerUsername, Map<String, dynamic> moveData,
      {bool isGroup = false}) {
    _requireConnection();
    _socket!.emit('game_move', {
      'messageId': messageId,
      'to': peerUsername,
      'toType': isGroup ? 'group' : 'friend',
      'moveData': moveData,
    });
  }

  Future<Map<String, dynamic>> sendRiddle({
    required String peerUsername,
    required String secret,
    required String question,
    required String answer,
    String? hint,
    int maxTries = 3,
  }) async {
    _requireConnection();
    final completer = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck('riddle_message', {
      'to': peerUsername,
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
  }) async {
    _requireConnection();
    final completer = Completer<Map<String, dynamic>>();
    _socket!.emitWithAck('unlock_riddle', {
      'messageId': messageId,
      'from': fromUsername,
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
        snapshot.map((message) => encryption.decrypt(message, account)));
    if (_myUsername != account || _currentChatWith != peer) return;
    final byId = {for (final message in decrypted) message.id: message};
    _messages = _messages
        .map((message) => byId[message.id]?.ciphertext == message.ciphertext
            ? byId[message.id] ?? message
            : message)
        .toList();
    await HybridDbService.saveMessages(decrypted);
    notifyListeners();
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

  // ── Typing indicators (debounced) ─────────────────────────────────────────
  void startTyping(String peerUsername, {bool isGroup = false}) {
    _typingDebounce?.cancel();
    _typingStopTimer?.cancel();
    _socket?.emit('typing', {
      'to': peerUsername,
      'isTyping': true,
      'toType': isGroup ? 'group' : 'friend',
    });
    _typingDebounce = Timer(const Duration(milliseconds: 300), () {});
    _typingStopTimer = Timer(const Duration(seconds: 3), () {
      stopTyping(peerUsername, isGroup: isGroup);
    });
  }

  void stopTyping(String peerUsername, {bool isGroup = false}) {
    _typingDebounce?.cancel();
    _typingStopTimer?.cancel();
    _socket?.emit('typing', {
      'to': peerUsername,
      'isTyping': false,
      'toType': isGroup ? 'group' : 'friend',
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
    if (_isConnected) _socket?.emit('discover_online');
  }

  void _requireConnection() {
    if (!_isConnected || _socket == null) {
      throw StateError('Connect to Novyn before sending messages or changing contacts.');
    }
  }

  // ── Call signaling ────────────────────────────────────────────────────────
  void sendCallInvite(String toUsername, {bool isVideo = false}) {
    _socket?.emit('call_invite', {'to': toUsername, 'isVideo': isVideo});
  }

  void acceptCall(String fromUsername) {
    _socket?.emit('call_accept', {'to': fromUsername});
  }

  void rejectCall(String fromUsername) {
    _socket?.emit('call_reject', {'to': fromUsername});
  }

  void endCall(String peerUsername, {String? reason}) {
    _socket?.emit(
        'call_end', {'to': peerUsername, if (reason != null) 'reason': reason});
  }

  // ── WebRTC signaling ──────────────────────────────────────────────────────
  void sendWebRTCSignal(String toUsername, dynamic signal) {
    _socket?.emit('webrtc_signal', {'to': toUsername, 'signal': signal});
  }

  // ── Callback registrations ────────────────────────────────────────────────
  VoidCallback? onProfileUpdated;
  bool Function()? notificationsMuted;
  Future<void> Function()? notificationsVibrate;
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
      await _audioPlayer.stop();
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
    _requireConnection();
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
    _requireConnection();
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
    _requireConnection();
    final connection = _socket!;
    final confirmed = Completer<void>();
    void received(dynamic data) {
      if (data is Map &&
          data['presenceMode'] == mode &&
          data['username'] == _myUsername &&
          !confirmed.isCompleted) {
        confirmed.complete();
      }
    }

    connection.on('profile_updated', received);
    try {
      connection.emit('update_profile', {'presenceMode': mode});
      await confirmed.future.timeout(const Duration(seconds: 10));
    } finally {
      connection.off('profile_updated', received);
    }
  }

  // messagesReadByPeer — used by chat_detail_screen for read tick color
  bool get messagesReadByPeer =>
      false; // novyn-chat tracks this via message_status events

  void onCallInvite(Function(Map) cb) => onCallInviteCallback = cb;
  void onCallAccepted(Function(Map) cb) => onCallAcceptedCallback = cb;
  void onCallRejected(VoidCallback cb) => onCallRejectedCallback = cb;
  void onCallEnded(VoidCallback cb) => onCallEndedCallback = cb;
  void onWebRTCSignal(Function(Map) cb) => onWebRTCSignalCallback = cb;

  // WebRTC setters used by call_screen.dart (old API used separate offer/answer/ice)
  // novyn-chat uses a single 'webrtc_signal' event; we map them here.
  Function(Map)? onWebRTCOffer;
  Function(Map)? onWebRTCAnswer;
  Function(Map)? onWebRTCIceCandidate;

  // sendOffer / sendAnswer / sendIceCandidate — old webrtc_service.dart API
  void sendOffer(String receiverId, dynamic offer) {
    sendWebRTCSignal(receiverId, {'type': 'offer', 'sdp': offer});
  }

  void sendAnswer(String callerId, dynamic answer) {
    sendWebRTCSignal(callerId, {'type': 'answer', 'sdp': answer});
  }

  void sendIceCandidate(String receiverId, dynamic candidate) {
    sendWebRTCSignal(receiverId, {'type': 'candidate', 'candidate': candidate});
  }

  // createGroup — emits create_group socket event
  Future<String> createGroup({
    required String name,
    required List<String> memberIds,
    bool isStealth = false,
  }) async {
    final chatId = 'grp_${DateTime.now().millisecondsSinceEpoch}';
    _socket?.emit('create_group', {
      'chatId': chatId,
      'name': name,
      'memberIds': memberIds,
      'isStealth': isStealth,
    });
    return chatId;
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
    _peerKeys.clear();
    _blockedUsers.clear();
    _conversations = [];
    _messages = [];
    _currentChatWith = null;
    _chatWallpaper = '';
    _peerIsTyping = false;
    _typingInChats.clear();
    contacts.clear();
    _reconnectTimer?.cancel();
    _typingDebounce?.cancel();
    _typingStopTimer?.cancel();
    _socket?.disconnect();
    _reconnectTimer?.cancel();
    _socket = null;
    _isConnected = false;
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
