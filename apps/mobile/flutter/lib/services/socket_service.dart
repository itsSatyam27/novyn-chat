import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import '../models/chat_models.dart';
import '../models/chat_preview.dart';
import '../models/user_model.dart';
import 'hybrid_db_service.dart';
import 'api_service.dart';
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
  final encryption = MessageEncryptionService();
  final Map<String, String> _peerKeys = {};
  final BackendContacts contacts = BackendContacts();
  io.Socket? _socket;
  bool _isConnected = false;
  String? _myUsername; // novyn-chat username (not Firebase UID)
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Reconnection state
  String? _serverUrl;
  Timer? _reconnectTimer;

  // Messages for the currently open chat (immutable list — replaced on update)
  List<Message> _messages = [];
  String? _currentChatWith; // the username of the other party

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

      onConnected?.call();
      notifyListeners();
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      notifyListeners();
      _scheduleReconnect(3);
    });

    _socket!.onConnectError((_) {
      _isConnected = false;
      notifyListeners();
      _scheduleReconnect(5);
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
      );

      final account = _myUsername;
      if (account == null) return;
      msg = await encryption.decrypt(msg, account);
      if (_myUsername != account) return;

      // Save to local DB
      HybridDbService.saveMessage(msg);

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
      } else if (!isOwn && !(notificationsMuted?.call() ?? false)) {
        // Message for a different chat — play notification sound
        _audioPlayer.play(AssetSource('audio/notification.mp3'));
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
    _messages = List<Message>.from(cachedHistory);
    _peerIsTyping = false;
    notifyListeners();

    unawaited(decryptCurrentMessages());

    // Tell the server which chat is active and request latest history
    _socket?.emit('set_active_chat', {'to': peerUsername, 'kind': 'friend'});
    _socket?.emit('get_history', {'to': peerUsername, 'kind': 'friend'});
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
    final peerKey = _peerKeys[toPeerUsername.toLowerCase()] ?? '';
    Map<String, dynamic>? encrypted;
    if (!isGroup && peerKey.isNotEmpty && text.isNotEmpty) {
      final ownKey = await _requestPublicKey(account);
      encrypted =
          await encryption.encrypt(text, account, toPeerUsername, peerKey, accountPublicKey: ownKey);
      if (encrypted == null) {
        throw StateError(
            'Import message keys from your web browser before sending to this encrypted chat.');
      }
      if (_myUsername != account) {
        throw StateError('Your account changed. Please try again.');
      }
      _requireConnection();
    }

    final clientTempId = 'tmp_${DateTime.now().millisecondsSinceEpoch}';
    final toType = isGroup ? 'group' : 'friend';

    // Optimistic message
    final tempMsg = Message(
      id: clientTempId,
      chatId: toPeerUsername,
      text: text,
      senderId: _myUsername!,
      isFromMe: true,
      createdAt: DateTime.now(),
      replyToId: replyToId,
      replyToText: replyToText,
      replyToSender: replyToSender,
      isEncrypted: encrypted != null,
      ciphertext: encrypted?['ciphertext'],
      iv: encrypted?['iv'],
    );
    _messages = [..._messages, tempMsg];
    notifyListeners();

    // novyn-chat payload shape
    final payload = <String, dynamic>{
      'to': toPeerUsername,
      'toType': toType,
      'text': encrypted == null ? text : '',
      if (encrypted != null) ...encrypted,
      'clientTempId': clientTempId,
      if (attachment != null) 'attachment': attachment,
      if (replyToId != null)
        'replyTo': {
          'id': replyToId,
          'text': encrypted == null ? replyToText ?? '' : '🔒 Encrypted message',
          'from': replyToSender ?? '',
        },
    };

    _socket!.emit('private_message', payload);
  }

  Future<String> _requestPublicKey(String username) async {
    _requireConnection();
    final result = Completer<String>();
    _socket!.emitWithAck('get_public_key', {'username': username}, ack: (dynamic data) {
      if (!result.isCompleted) result.complete(data is Map ? data['publicKey']?.toString() ?? '' : '');
    });
    return result.future.timeout(const Duration(seconds: 10));
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

  void acceptFriendRequest(String fromUsername) {
    _requireConnection();
    _socket?.emit('accept_friend', fromUsername);
  }

  void rejectFriendRequest(String fromUsername) {
    _requireConnection();
    _socket?.emit('reject_friend', fromUsername);
  }

  void removeFriend(String username) {
    _requireConnection();
    _socket!.emit('remove_friend', username);
  }

  void requestDiscover() {
    if (_isConnected) _socket?.emit('discover_online');
  }

  void _requireConnection() {
    if (!_isConnected || _socket == null) {
      throw StateError('Connect to Novyn before changing contacts.');
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
  void Function(Map<String, dynamic>)? onProfileData;
  bool _changingPassword = false;

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
    _myUsername = null;
    _peerKeys.clear();
    contacts.clear();
    _reconnectTimer?.cancel();
    _typingDebounce?.cancel();
    _typingStopTimer?.cancel();
    _socket?.disconnect();
    _socket = null;
    _isConnected = false;
    _audioPlayer.dispose();
  }

  @override
  void dispose() {
    disconnect();
    contacts.dispose();
    super.dispose();
  }
}
