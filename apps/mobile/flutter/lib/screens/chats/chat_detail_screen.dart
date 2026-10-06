import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/socket_service.dart';
import '../../services/api_service.dart';
import '../../services/hybrid_db_service.dart';
import '../../services/draft_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/profile_preview_sheet.dart';
import '../../widgets/connection_banner.dart';
import '../../screens/calls/call_screen.dart';
class ChatDetailScreen extends StatefulWidget {
  final UserModel peer; // the person we're chatting with

  const ChatDetailScreen({super.key, required this.peer});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _loading = true;
  bool _loadingOlder = false;
  bool _hasMore = true;
  bool _fetchingFromServer = false; // true only when cache empty + waiting for API
  String? _chatId;
  String? _myUid;
  bool _peerIsOnline = false;
  dynamic _replyingTo; // the message being replied to

  @override
  void initState() {
    super.initState();
    _peerIsOnline = widget.peer.isOnline;
    _init();
    _scroll.addListener(_onScroll);

    // Load draft message
    _loadDraft();

    // Auto-save draft on text change
    _ctrl.addListener(_saveDraft);

    // Listen for real-time presence changes on this peer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final socket = context.read<SocketService>();
      final prev = socket.onUserStatusChanged;
      socket.onUserStatusChanged = (uid, isOnline) {
        prev?.call(uid, isOnline);
        if (uid == widget.peer.uid && mounted) {
          setState(() => _peerIsOnline = isOnline);
        }
      };
    });
  }

  // Load draft message for this chat
  Future<void> _loadDraft() async {
    if (_chatId == null) {
      // Wait for chatId to be set
      await Future.delayed(const Duration(milliseconds: 500));
    }
    if (_chatId != null) {
      final draft = await DraftService.getDraft(_chatId!);
      if (draft != null && draft.isNotEmpty && mounted) {
        _ctrl.text = draft;
      }
    }
  }

  // Auto-save draft (debounced)
  void _saveDraft() {
    if (_chatId != null) {
      DraftService.saveDraft(_chatId!, _ctrl.text);
    }
  }

  // Load older messages when scrolled to top
  void _onScroll() {
    if (_scroll.position.pixels <= 80 &&
        !_loadingOlder &&
        _hasMore &&
        _chatId != null) {
      _loadOlderMessages();
    }
  }

  Future<void> _loadOlderMessages() async {
    final socket = context.read<SocketService>();
    final messages = socket.messages;
    if (messages.isEmpty) return;

    setState(() => _loadingOlder = true);

    // Use the oldest message's timestamp as cursor
    final oldest = messages.first.createdAt.toIso8601String();
    final older = await ApiService.getMessages(
      _chatId!,
      myUsername: _myUid,
      before: oldest,
      limit: 30,
    );

    if (!mounted) return;

    if (older.isEmpty) {
      setState(() {
        _loadingOlder = false;
        _hasMore = false;
      });
      return;
    }

    // Preserve scroll position when prepending
    final prevExtent = _scroll.position.maxScrollExtent;

    socket.prependMessages(older);

    setState(() => _loadingOlder = false);

    // Jump scroll to maintain position after prepend
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        final newExtent = _scroll.position.maxScrollExtent;
        _scroll.jumpTo(newExtent - prevExtent);
      }
    });
  }

  Future<void> _init() async {
    final auth = context.read<AuthService>();
    final socket = context.read<SocketService>();
    _myUid = auth.user?.username; // username is our identity
    if (_myUid == null) return;

    // chatId on novyn-chat is just the peer's username
    _chatId = widget.peer.uid.isNotEmpty ? widget.peer.uid : widget.peer.username;

    // 1. Load cache immediately
    final cacheF   = HybridDbService.getMessages(_chatId!);
    final historyF = ApiService.getHistory(_chatId!, myUsername: _myUid);

    final cachedMessages = await cacheF;
    if (mounted) {
      socket.openChat(_chatId!, cachedMessages);
      if (cachedMessages.isEmpty) _fetchingFromServer = true;
      setState(() => _loading = false);
      if (cachedMessages.isNotEmpty) _scrollToBottom();
    }

    final history = await historyF;
    if (!mounted) return;

    if (history.isNotEmpty) {
      await HybridDbService.saveMessages(history);
      await HybridDbService.setLastSync(_chatId!, DateTime.now());
      socket.openChat(_chatId!, history);
      if (mounted) setState(() => _fetchingFromServer = false);
      _scrollToBottom();
    } else if (mounted) {
      setState(() => _fetchingFromServer = false);
    }

    final settings = context.read<SettingsService>();
    if (settings.readReceipts) {
      ApiService.markRead(_chatId!, _myUid!);
    }
  }

  @override
  void dispose() {
    context.read<SocketService>().closeChat();
    _scroll.removeListener(_onScroll);
    _ctrl.removeListener(_saveDraft);
    _ctrl.dispose();
    _scroll.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _myUid == null || _chatId == null) return;
    HapticFeedback.lightImpact();

    final socket = context.read<SocketService>();
    socket.stopTyping(widget.peer.uid);
    _ctrl.clear();

    // Delete draft after sending
    DraftService.deleteDraft(_chatId!);

    socket.sendMessage(
      text,
      widget.peer.uid.isNotEmpty ? widget.peer.uid : widget.peer.username,
      replyToId:     _replyingTo?.id?.toString(),
      replyToText:   _replyingTo?.text?.toString(),
      replyToSender: _replyingTo?.isFromMe == true ? 'You' : widget.peer.name,
    );

    setState(() => _replyingTo = null);
    _audioPlayer.play(AssetSource('audio/message_sent.mp3'));
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final socket = context.watch<SocketService>();
    final messages = socket.messages;
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _buildAppBar(socket),
      body: Column(
        children: [
          const ConnectionBanner(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C6FF7)))
                : messages.isEmpty
                    ? _fetchingFromServer
                        ? _buildLoadingShimmer()
                        : _buildEmptyChat()
                    : _buildMessageList(messages),
          ),
          _buildInputBar(socket),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(SocketService socket) {
    final theme = Theme.of(context);
    return AppBar(
      backgroundColor: theme.colorScheme.surface,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.chevron_left_rounded, 
            color: theme.colorScheme.onSurface, size: 32),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Hero(
            tag: 'avatar_${widget.peer.uid}',
            child: UserAvatar(
              name: widget.peer.name,
              photoUrl: widget.peer.photoUrl,
              radius: 20,
              showOnlineIndicator: true,
              isOnline: widget.peer.isOnline,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.peer.name,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  socket.peerIsTyping
                      ? 'typing...'
                      : _peerIsOnline
                          ? 'Online'
                          : 'Offline',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: socket.peerIsTyping
                        ? const Color(0xFF7C6FF7)
                        : _peerIsOnline
                            ? const Color(0xFF10B981)
                            : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.call_rounded, color: Color(0xFF7C6FF7)),
          onPressed: () => _startCall('voice'),
        ),
        IconButton(
          icon: const Icon(Icons.videocam_rounded, color: Color(0xFF7C6FF7)),
          onPressed: () => _startCall('video'),
        ),
        IconButton(
          icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF94A3B8)),
          onPressed: () => _showContactInfo(),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildEmptyChat() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          UserAvatar(
            name: widget.peer.name,
            photoUrl: widget.peer.photoUrl,
            radius: 40,
          ),
          const SizedBox(height: 16),
          Text(
            widget.peer.name,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Say hello! 👋',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  /// Shown when cache is empty and we're waiting for the first API response.
  /// Looks like message bubbles so the transition is smooth.
  Widget _buildLoadingShimmer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF1E2235) : const Color(0xFFEEEEEE);
    final highlight = isDark ? const Color(0xFF2A2F45) : const Color(0xFFF5F5F5);

    Widget shimmerBox({double width = 200, double height = 40, bool fromMe = false}) {
      return Align(
        alignment: fromMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: width,
          height: height,
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(fromMe ? 18 : 4),
              bottomRight: Radius.circular(fromMe ? 4 : 18),
            ),
          ),
          child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds),
            child: Container(color: Colors.white),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        shimmerBox(width: 180, height: 44, fromMe: false),
        shimmerBox(width: 240, height: 44, fromMe: true),
        shimmerBox(width: 140, height: 36, fromMe: false),
        shimmerBox(width: 200, height: 60, fromMe: true),
        shimmerBox(width: 160, height: 44, fromMe: false),
        shimmerBox(width: 220, height: 36, fromMe: true),
      ],
    );
  }

  int _lastMessageCount = 0;

  Widget _buildMessageList(List messages) {
    if (messages.length > _lastMessageCount) {
      _lastMessageCount = messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
    final socket = context.read<SocketService>();
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length + 1, // +1 for top loader
      // Performance optimizations
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      cacheExtent: 500, // Cache 500px above/below viewport
      itemBuilder: (context, i) {
        // Top item: loading indicator or "start of conversation"
        if (i == 0) {
          if (_loadingOlder) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF7C6FF7),
                  ),
                ),
              ),
            );
          }
          if (!_hasMore) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C6FF7).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Start of conversation',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: Color(0xFF7C6FF7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }
          return const SizedBox(height: 8);
        }

        final msgIndex = i - 1;
        return _SwipeToReply(
          onSwipe: () => setState(() => _replyingTo = messages[msgIndex]),
          child: _MessageBubble(
            message: messages[msgIndex],
            showAvatar: !messages[msgIndex].isFromMe &&
                (msgIndex == 0 || messages[msgIndex - 1].isFromMe),
            peer: widget.peer,
            messagesRead: socket.messagesReadByPeer,
            myUid: _myUid ?? '',
            onReply: (msg) => setState(() => _replyingTo = msg),
          ),
        );
      },
    );
  }

  Widget _buildInputBar(SocketService socket) {
    final hasText = _ctrl.text.trim().isNotEmpty;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Reply preview bar ──────────────────────────────────────
        if (_replyingTo != null)
          Container(
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C6FF7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _replyingTo!.isFromMe ? 'You' : widget.peer.name,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7C6FF7),
                        ),
                      ),
                      Text(
                        _replyingTo!.text ?? '',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: Color(0xFF94A3B8)),
                  onPressed: () => setState(() => _replyingTo = null),
                ),
              ],
            ),
          ),

        // ── Main input row ─────────────────────────────────────────
        Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Pill-shaped input with spark inside ────────────────────
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E2235)
                    : Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.07),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Spark icon inside pill
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: _AttachmentButton(onSelected: _handleAttachment),
                  ),

                  // Text field
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      maxLines: 4,
                      minLines: 1,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        color: theme.colorScheme.onSurface,
                      ),
                      onChanged: (v) {
                        setState(() {});
                        if (v.isNotEmpty) {
                          socket.startTyping(widget.peer.uid);
                        } else {
                          socket.stopTyping(widget.peer.uid);
                        }
                      },
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Message...',
                        hintStyle: TextStyle(
                          fontFamily: 'Inter',
                          color: Color(0xFF94A3B8),
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 8, vertical: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // ── Mic / Send button ──────────────────────────────────────
          GestureDetector(
            onTap: hasText ? _send : null,
            onLongPressStart: hasText ? null : (_) => _startVoiceNote(),
            onLongPressEnd: hasText ? null : (_) => _stopVoiceNote(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: hasText
                      ? [const Color(0xFF7C6FF7), const Color(0xFF9B8FFF)]
                      : [const Color(0xFF10B981), const Color(0xFF34D399)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (hasText
                            ? const Color(0xFF7C6FF7)
                            : const Color(0xFF10B981))
                        .withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: child,
                ),
                child: Icon(
                  hasText ? Icons.send_rounded : Icons.mic_rounded,
                  key: ValueKey(hasText),
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
      ),  // close Container (main input row)
      ],  // close Column children
    );   // close Column
  }

  void _handleAttachment(String type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$type — coming soon'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _startVoiceNote() {
    HapticFeedback.mediumImpact();
    // Voice note recording — coming soon
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Hold to record voice note'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _stopVoiceNote() {
    // Stop recording and send — coming soon
  }

  void _startCall(String type) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          peer:     widget.peer,
          callType: type,
        ),
      ),
    );
  }

  void _showContactInfo() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProfilePreviewSheet(
        user: widget.peer,
        onVoiceCall: () {
          Navigator.pop(context);
          _startCall('voice');
        },
        onVideoCall: () {
          Navigator.pop(context);
          _startCall('video');
        },
      ),
    );
  }
}

// ── Message Bubble ─────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final dynamic message;
  final bool showAvatar;
  final UserModel peer;
  final bool messagesRead;
  final String myUid;
  final ValueChanged<dynamic>? onReply;

  const _MessageBubble({
    required this.message,
    required this.showAvatar,
    required this.peer,
    this.messagesRead = false,
    this.myUid = '',
    this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = message.isFromMe as bool;
    final time = _formatTime(message.createdAt);
    final reactions = Map<String, String>.from(message.reactions ?? {});

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            if (showAvatar)
              UserAvatar(name: peer.name, photoUrl: peer.photoUrl, radius: 14)
            else
              const SizedBox(width: 28),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // ── Bubble with long-press ──────────────────────────────
                GestureDetector(
                  onLongPress: () => _showReactionPicker(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.68,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? const Color(0xFF7C6FF7)
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Reply quote
                        if (message.replyToText != null) ...[
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : const Color(0xFF7C6FF7).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border(
                                left: BorderSide(
                                  color: isMe
                                      ? Colors.white.withValues(alpha: 0.6)
                                      : const Color(0xFF7C6FF7),
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.replyToSender ?? '',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isMe
                                        ? Colors.white.withValues(alpha: 0.9)
                                        : const Color(0xFF7C6FF7),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  message.replyToText ?? '',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: isMe
                                        ? Colors.white.withValues(alpha: 0.7)
                                        : const Color(0xFF64748B),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                        Text(
                          message.text as String,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            color: isMe
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if (message.edited == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'edited',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                color: isMe
                                    ? Colors.white.withValues(alpha: 0.5)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // ── Reactions row ───────────────────────────────────────
                if (reactions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _ReactionsRow(
                      reactions: reactions,
                      myUid: myUid,
                      onTap: (emoji) => _toggleReaction(context, emoji),
                    ),
                  ),

                // ── Time + tick ─────────────────────────────────────────
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.edited == true)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Text(
                          'edited',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    Text(
                      time,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 3),
                      _buildTick(message),
                    ],
                  ],
                ),
              ],
            ),
          ),

          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  void _showReactionPicker(BuildContext context) {
    HapticFeedback.mediumImpact();
    const emojis = ['❤️', '😂', '😮', '😢', '👍', '🔥'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Emoji row ──────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: emojis.map((e) => GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _toggleReaction(context, e);
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C6FF7).withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(e, style: const TextStyle(fontSize: 22)),
                  ),
                ),
              )).toList(),
            ),
          ),

          // ── Action options ─────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                // Reply
                _ActionItem(
                  icon: Icons.reply_rounded,
                  label: 'Reply',
                  color: const Color(0xFF7C6FF7),
                  onTap: () {
                    Navigator.pop(context);
                    onReply?.call(message);
                  },
                ),
                if ((message.isFromMe as bool)) ...[
                  const Divider(height: 1),
                  // Edit (only own messages, not tmp)
                  if (!(message.id as String).startsWith('tmp_'))
                    _ActionItem(
                      icon: Icons.edit_rounded,
                      label: 'Edit',
                      color: const Color(0xFF0EA5E9),
                      onTap: () {
                        Navigator.pop(context);
                        _showEditDialog(context);
                      },
                    ),
                  const Divider(height: 1),
                  _ActionItem(
                    icon: Icons.delete_rounded,
                    label: 'Delete for everyone',
                    color: const Color(0xFFEF4444),
                    onTap: () {
                      Navigator.pop(context);
                      _deleteMessage(context, forEveryone: true);
                    },
                  ),
                ],
                const Divider(height: 1),
                _ActionItem(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete for me',
                  color: const Color(0xFF94A3B8),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessage(context, forEveryone: false);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final ctrl = TextEditingController(text: message.text as String);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit message',
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 4,
          minLines: 1,
          decoration: InputDecoration(
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newText = ctrl.text.trim();
              if (newText.isNotEmpty && newText != message.text) {
                context.read<SocketService>().editMessage(
                  message.id as String,
                  newText,
                  peer.uid,
                );
              }
              Navigator.pop(context);
            },
            child: const Text('Save',
                style: TextStyle(
                    color: Color(0xFF7C6FF7), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _deleteMessage(BuildContext context, {required bool forEveryone}) {
    context.read<SocketService>().deleteMessage(
      message.id as String,
      peer.uid,
      forEveryone: forEveryone,
    );
  }

  void _toggleReaction(BuildContext context, String emoji) {
    final socket = context.read<SocketService>();
    final reactions = Map<String, String>.from(message.reactions ?? {});
    final currentEmoji = reactions[myUid];

    if (currentEmoji == emoji) {
      // Remove reaction
      socket.removeReaction(message.id as String, peer.uid);
    } else {
      // Add/change reaction
      socket.addReaction(message.id as String, emoji, peer.uid);
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  Widget _buildTick(dynamic message) {
    final isSending = (message.id as String).startsWith('tmp_');

    if (isSending) {
      return const Icon(Icons.access_time_rounded,
          size: 11, color: Color(0xFF94A3B8));
    }

    // Blue = seen by peer, purple = delivered
    final color = messagesRead
        ? const Color(0xFF0EA5E9)
        : const Color(0xFF7C6FF7);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.done_rounded, size: 13, color: color),
        Transform.translate(
          offset: const Offset(-4, 0),
          child: Icon(Icons.done_rounded, size: 13, color: color),
        ),
      ],
    );
  }
}

// ── Contact Info Sheet ─────────────────────────────────────────────────────

// ── Action tile ────────────────────────────────────────────────────────────
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1D2E),
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFCBD5E1), size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Attachment Button with popup menu ─────────────────────────────────────
class _AttachmentButton extends StatefulWidget {
  final ValueChanged<String> onSelected;
  const _AttachmentButton({required this.onSelected});

  @override
  State<_AttachmentButton> createState() => _AttachmentButtonState();
}

class _AttachmentButtonState extends State<_AttachmentButton>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  static const _items = [
    _MenuItem(icon: Icons.poll_rounded,              label: 'Poll',     color: Color(0xFF7C6FF7)),
    _MenuItem(icon: Icons.photo_library_rounded,     label: 'Media',    color: Color(0xFF0EA5E9)),
    _MenuItem(icon: Icons.insert_drive_file_rounded, label: 'Document', color: Color(0xFFF59E0B)),
    _MenuItem(icon: Icons.headphones_rounded,        label: 'Sound',    color: Color(0xFFEC4899)),
    _MenuItem(icon: Icons.location_on_rounded,       label: 'Location', color: Color(0xFF10B981)),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scale  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade   = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.lightImpact();
    setState(() => _open = !_open);
    _open ? _ctrl.forward() : _ctrl.reverse();
  }

  void _close() {
    setState(() => _open = false);
    _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Unique spark/grid button ───────────────────────────────
        GestureDetector(
          onTap: _toggle,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_ctrl.value * 0.12),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                      const Color(0xFF7C6FF7).withValues(alpha: 0.15),
                      _ctrl.value,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: CustomPaint(
                    painter: _SparkIconPainter(
                      progress: _ctrl.value,
                      color: Color.lerp(
                        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        const Color(0xFF7C6FF7),
                        _ctrl.value,
                      )!,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // ── Popup menu ────────────────────────────────────────────
        Positioned(
          bottom: 48,
          left: 0,
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              alignment: Alignment.bottomLeft,
              child: Material(
                color: Colors.transparent,
                child: Builder(
                  builder: (ctx) => Container(
                  width: 190,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C6FF7).withValues(alpha: 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(
                      color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _items.asMap().entries.map((entry) {
                        final i = entry.key;
                        final item = entry.value;
                        // Stagger each item's appearance
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: _open ? 1 : 0),
                          duration: Duration(milliseconds: 120 + (i * 30)),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, child) => Opacity(
                            opacity: v,
                            child: Transform.translate(
                              offset: Offset(0, (1 - v) * 8),
                              child: child,
                            ),
                          ),
                          child: _buildMenuItem(item),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                ), // close Builder
              ),
            ),
          ),
        ),

        // Invisible overlay to close on tap outside
        if (_open)
          Positioned(
            left: -300,
            right: -300,
            top: -600,
            bottom: -100,
            child: GestureDetector(
              onTap: _close,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),
      ],
    );
  }

  Widget _buildMenuItem(_MenuItem item) {
    return InkWell(
      onTap: () {
        _close();
        widget.onSelected(item.label);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(item.icon, color: item.color, size: 18),
            ),
            const SizedBox(width: 12),
            Builder(
              builder: (ctx) => Text(
                item.label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(ctx).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final Color color;
  const _MenuItem({required this.icon, required this.label, required this.color});
}

// ── Spark Icon Painter ─────────────────────────────────────────────────────
// Draws a 4-pointed star (spark) that morphs into an X when progress = 1
class _SparkIconPainter extends CustomPainter {
  final double progress; // 0 = spark, 1 = X
  final Color color;

  _SparkIconPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(cx, cy);

    // Rotate from 0° (spark) to 45° (X shape)
    canvas.rotate(progress * (3.14159 / 4));

    // Draw 4-pointed star
    // Each arm: thin at base, pointed at tip
    final armLength = size.width * 0.32;
    final armWidth  = size.width * 0.065 + (progress * size.width * 0.04);

    for (int i = 0; i < 4; i++) {
      canvas.save();
      canvas.rotate(i * 3.14159 / 2);

      final path = Path()
        ..moveTo(-armWidth, 0)
        ..lineTo(0, -armLength)
        ..lineTo(armWidth, 0)
        ..lineTo(0, armWidth * 0.4)
        ..close();

      canvas.drawPath(path, paint);
      canvas.restore();
    }

    // Center dot
    canvas.drawCircle(
      Offset.zero,
      size.width * 0.07,
      paint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SparkIconPainter old) =>
      old.progress != progress || old.color != color;
}

// ── Reactions Row ──────────────────────────────────────────────────────────
class _ReactionsRow extends StatelessWidget {
  final Map<String, String> reactions;
  final String myUid;
  final ValueChanged<String> onTap;

  const _ReactionsRow({
    required this.reactions,
    required this.myUid,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Group by emoji → count
    final counts = <String, int>{};
    for (final emoji in reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }

    return Wrap(
      spacing: 4,
      children: counts.entries.map((e) {
        final isMine = reactions[myUid] == e.key;
        return GestureDetector(
          onTap: () => onTap(e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isMine
                  ? const Color(0xFF7C6FF7).withValues(alpha: 0.15)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMine
                    ? const Color(0xFF7C6FF7).withValues(alpha: 0.4)
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.key, style: const TextStyle(fontSize: 14)),
                if (e.value > 1) ...[
                  const SizedBox(width: 3),
                  Text(
                    '${e.value}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isMine
                          ? const Color(0xFF7C6FF7)
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Swipe to reply ─────────────────────────────────────────────────────────
class _SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipe;
  const _SwipeToReply({required this.child, required this.onSwipe});

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply> {
  double _drag = 0;
  bool _triggered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (d) {
        if (d.delta.dx > 0) {
          setState(() => _drag = (_drag + d.delta.dx).clamp(0, 60));
          if (_drag >= 50 && !_triggered) {
            _triggered = true;
            HapticFeedback.lightImpact();
            widget.onSwipe();
          }
        }
      },
      onHorizontalDragEnd: (_) {
        setState(() {
          _drag = 0;
          _triggered = false;
        });
      },
      child: Stack(
        children: [
          // Reply icon that appears as you swipe
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Opacity(
              opacity: (_drag / 50).clamp(0, 1),
              child: const Icon(
                Icons.reply_rounded,
                color: Color(0xFF7C6FF7),
                size: 20,
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(_drag, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

// ── Action Item (for message options sheet) ────────────────────────────────
class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: color == const Color(0xFF94A3B8)
                    ? Theme.of(context).colorScheme.onSurface
                    : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Message Search ─────────────────────────────────────────────────────────
class _MessageSearchDelegate extends SearchDelegate<String> {
  final UserModel peer;

  _MessageSearchDelegate({required this.peer});

  @override
  String get searchFieldLabel => 'Search messages...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults(context);

  Widget _buildSearchResults(BuildContext context) {
    if (query.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Text(
              'Type to search messages',
              style: TextStyle(
                fontFamily: 'Inter',
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    // Search through socket service messages
    final socket = context.read<SocketService>();
    final results = socket.messages
        .where((m) =>
            m.text.toLowerCase().contains(query.toLowerCase()))
        .toList()
        .reversed
        .toList();

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Text(
              'No messages found for "$query"',
              style: TextStyle(
                fontFamily: 'Inter',
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, i) {
        final msg = results[i];
        final isMe = msg.isFromMe;
        final time = _formatSearchTime(msg.createdAt);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(
                name: isMe ? 'You' : peer.name,
                photoUrl: isMe ? '' : peer.photoUrl,
                radius: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isMe ? 'You' : peer.name,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          time,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _HighlightedText(
                      text: msg.text,
                      highlight: query,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatSearchTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:${m} ${dt.hour < 12 ? 'AM' : 'PM'}';
    }
    return '${dt.day}/${dt.month}';
  }
}

// ── Highlighted text widget ────────────────────────────────────────────────
class _HighlightedText extends StatelessWidget {
  final String text;
  final String highlight;

  const _HighlightedText({required this.text, required this.highlight});

  @override
  Widget build(BuildContext context) {
    if (highlight.isEmpty) {
      return Text(text,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ));
    }

    final spans = <TextSpan>[];
    final lower = text.toLowerCase();
    final lowerHighlight = highlight.toLowerCase();
    int start = 0;

    while (true) {
      final idx = lower.indexOf(lowerHighlight, start);
      if (idx == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + highlight.length),
        style: const TextStyle(
          backgroundColor: Color(0xFF7C6FF7),
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ));
      start = idx + highlight.length;
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        children: spans,
      ),
    );
  }
}
