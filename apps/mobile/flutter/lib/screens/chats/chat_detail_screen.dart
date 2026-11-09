import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
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
  bool _sending = false;
  bool _loadingOlder = false;
  bool _hasMore = true;
  bool _fetchingFromServer =
      false; // true only when cache empty + waiting for API
  String? _chatId;
  String? _myUid;
  bool _peerIsOnline = false;
  dynamic _replyingTo; // the message being replied to
  bool _uploadingAttachment = false;
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _voiceRecorder = AudioRecorder();
  Timer? _voiceTimer;
  bool _isRecordingVoice = false;
  int _voiceSeconds = 0;
  String? _voiceRecordingPath;

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
    _chatId =
        widget.peer.uid.isNotEmpty ? widget.peer.uid : widget.peer.username;

    // 1. Load cache immediately
    final cacheF = HybridDbService.getMessages(_chatId!);
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
    _voiceTimer?.cancel();
    if (_isRecordingVoice) unawaited(_voiceRecorder.stop());
    unawaited(_voiceRecorder.dispose());
    context.read<SocketService>().closeChat();
    _scroll.removeListener(_onScroll);
    _ctrl.removeListener(_saveDraft);
    _ctrl.dispose();
    _scroll.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _send() async {
    final text = _ctrl.text.trim();
    if (_sending || text.isEmpty || _myUid == null || _chatId == null) return;
    HapticFeedback.lightImpact();

    final socket = context.read<SocketService>();
    socket.stopTyping(widget.peer.uid);
    _sending = true;
    try {
      await socket.sendMessage(
        text,
        widget.peer.uid.isNotEmpty ? widget.peer.uid : widget.peer.username,
        replyToId: _replyingTo?.id?.toString(),
        replyToText: _replyingTo?.text?.toString(),
        replyToSender: _replyingTo?.isFromMe == true ? 'You' : widget.peer.name,
      );
      if (!mounted) return;
      if (_ctrl.text.trim() == text) _ctrl.clear();
      DraftService.deleteDraft(_chatId!);
      setState(() => _replyingTo = null);
      _audioPlayer.play(AssetSource('audio/message_sent.mp3'));
      _scrollToBottom();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error is StateError
              ? error.message.toString()
              : 'Could not send message. Please try again.'),
        ));
      }
    } finally {
      _sending = false;
    }
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
            child: Container(
              decoration: _wallpaperDecoration(socket.chatWallpaper),
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF7C6FF7)))
                  : messages.isEmpty
                      ? _fetchingFromServer
                          ? _buildLoadingShimmer()
                          : _buildEmptyChat()
                      : _buildMessageList(messages),
            ),
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
              presence: widget.peer.status,
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
          tooltip: 'Shared media',
          icon: const Icon(Icons.perm_media_outlined, color: Color(0xFF94A3B8)),
          onPressed: _showSharedMedia,
        ),
        IconButton(
          tooltip: 'Chat wallpaper',
          icon: const Icon(Icons.wallpaper_rounded, color: Color(0xFF94A3B8)),
          onPressed: _showWallpaperPicker,
        ),
        IconButton(
          icon:
              const Icon(Icons.info_outline_rounded, color: Color(0xFF94A3B8)),
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
    final highlight =
        isDark ? const Color(0xFF2A2F45) : const Color(0xFFF5F5F5);

    Widget shimmerBox(
        {double width = 200, double height = 40, bool fromMe = false}) {
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
          onForward: _showForwardDialog,
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
        if (_uploadingAttachment)
          const LinearProgressIndicator(minHeight: 2),
        if (_isRecordingVoice)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.fiber_manual_record, color: Color(0xFFEF4444), size: 13),
                const SizedBox(width: 9),
                Text('Recording  ${_formatVoiceDuration(_voiceSeconds)}',
                  style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                const Spacer(),
                const Text('Release to send', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
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
                    color: isDark ? const Color(0xFF1E2235) : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: isDark ? 0.2 : 0.07),
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
                          : _isRecordingVoice
                              ? [const Color(0xFFDC2626), const Color(0xFFEF4444)]
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
                      hasText ? Icons.send_rounded : (_isRecordingVoice ? Icons.stop_rounded : Icons.mic_rounded),
                      key: ValueKey('$hasText-$_isRecordingVoice'),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ), // close Container (main input row)
      ], // close Column children
    ); // close Column
  }

  Future<void> _handleAttachment(String type) async {
    if (_uploadingAttachment) return;
    if (type.toLowerCase() == 'gifs' || type.toLowerCase() == 'stickers') {
      await _showGifPicker(type: type.toLowerCase() == 'stickers' ? 'stickers' : 'gifs');
      return;
    }
    if (type.toLowerCase() == 'poll') {
      await _showCreatePollDialog();
      return;
    }
    try {
      List<int>? bytes;
      String filename = 'attachment';
      String mime = 'application/octet-stream';
      if (type.toLowerCase().contains('photo') || type.toLowerCase().contains('image') || type.toLowerCase().contains('video')) {
        final picked = await _imagePicker.pickMedia();
        if (picked == null) return;
        bytes = await picked.readAsBytes();
        filename = picked.name;
        final lower = filename.toLowerCase();
        mime = lower.endsWith('.mp4') || lower.endsWith('.mov') ? 'video/mp4' : 'image/jpeg';
      } else {
        final result = await FilePicker.platform.pickFiles(withData: true);
        if (result == null || result.files.isEmpty) return;
        final file = result.files.single;
        bytes = file.bytes;
        filename = file.name;
        mime = _mimeForFile(filename);
      }
      if (bytes == null || bytes.isEmpty) throw StateError('Could not read the selected file.');
      setState(() => _uploadingAttachment = true);
      final url = await ApiService.uploadMedia(bytes, filename, mime);
      if (!mounted) return;
      if (url == null || url.isEmpty) throw StateError('Upload failed. Please try again.');
      final kind = mime.startsWith('image/') ? 'image' : mime.startsWith('video/') ? 'video' : 'file';
      await context.read<SocketService>().sendMessage(
        '',
        widget.peer.uid.isNotEmpty ? widget.peer.uid : widget.peer.username,
        attachment: {'url': url, 'name': filename, 'mime': mime, 'size': bytes.length, 'kind': kind},
        replyToId: _replyingTo?.id?.toString(),
        replyToText: _replyingTo?.text?.toString(),
        replyToSender: _replyingTo?.isFromMe == true ? 'You' : widget.peer.name,
      );
      if (mounted) setState(() => _replyingTo = null);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error is StateError ? error.message.toString() : 'Could not attach this file.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _uploadingAttachment = false);
    }
  }

  Future<void> _showForwardDialog(dynamic message) async {
    final socket = context.read<SocketService>();
    final search = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refresh) {
          final chats = socket.conversations.where((chat) {
            if (chat.peerUid.toLowerCase() == widget.peer.uid.toLowerCase()) return false;
            final query = search.text.trim().toLowerCase();
            return query.isEmpty ||
                chat.peer.name.toLowerCase().contains(query) ||
                chat.peer.username.toLowerCase().contains(query);
          }).toList();
          return Container(
            height: MediaQuery.of(context).size.height * 0.68,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(width: 38, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(child: Text('Forward message', style: TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w700))),
                    IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                TextField(
                  controller: search,
                  onChanged: (_) => refresh(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search friends',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: chats.isEmpty
                      ? const Center(child: Text('No other chats found'))
                      : ListView.separated(
                          itemCount: chats.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final chat = chats[index];
                            return ListTile(
                              leading: UserAvatar(
                                name: chat.peer.name,
                                photoUrl: chat.peer.photoUrl,
                                radius: 22,
                                isOnline: chat.peer.isOnline,
                              ),
                              title: Text(chat.peer.name, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                              subtitle: Text('@${chat.peer.username}', style: const TextStyle(fontFamily: 'Inter', fontSize: 12)),
                              trailing: const Icon(Icons.send_rounded, size: 18),
                              onTap: () {
                                socket.forwardMessage(
                                  message,
                                  chat.peerUid,
                                  isGroup: chat.isGroup,
                                );
                                Navigator.pop(sheetContext);
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(content: Text('Forwarded to ${chat.peer.name}')),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
    search.dispose();
  }

  Future<void> _showCreatePollDialog() async {
    final question = TextEditingController();
    final options = [TextEditingController(), TextEditingController()];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.poll_outlined, size: 21),
              SizedBox(width: 9),
              Text('Create a poll'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: question,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Question',
                    hintText: 'Ask your friends...',
                  ),
                ),
                const SizedBox(height: 12),
                ...List.generate(options.length, (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: options[index],
                          maxLength: 200,
                          decoration: InputDecoration(
                            labelText: 'Option ${index + 1}',
                            counterText: '',
                          ),
                        ),
                      ),
                      if (options.length > 2)
                        IconButton(
                          tooltip: 'Remove option',
                          onPressed: () => refresh(() => options.removeAt(index)),
                          icon: const Icon(Icons.close_rounded),
                        ),
                    ],
                  ),
                )),
                if (options.length < 8)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => refresh(() => options.add(TextEditingController())),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add option'),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                final cleanQuestion = question.text.trim();
                final cleanOptions = options.map((item) => item.text.trim()).where((item) => item.isNotEmpty).toList();
                if (cleanQuestion.isEmpty || cleanOptions.length < 2) return;
                context.read<SocketService>().createPoll(
                  cleanQuestion,
                  cleanOptions,
                  widget.peer.uid.isNotEmpty ? widget.peer.uid : widget.peer.username,
                );
                Navigator.pop(dialogContext);
              },
              icon: const Icon(Icons.send_rounded, size: 17),
              label: const Text('Send poll'),
            ),
          ],
        ),
      ),
    );
    question.dispose();
    for (final option in options) {
      option.dispose();
    }
  }

  Future<void> _showGifPicker({String type = 'gifs'}) async {
    final search = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _GifPickerSheet(
        initialType: type,
        onSelect: (item) async {
          Navigator.pop(sheetContext);
          final url = item['url']?.toString() ?? '';
          if (url.isEmpty) return;
          await context.read<SocketService>().sendMessage(
            '',
            widget.peer.uid.isNotEmpty ? widget.peer.uid : widget.peer.username,
            attachment: {
              'url': url,
              'name': item['title']?.toString().isNotEmpty == true ? item['title'].toString() : 'GIF',
              'mime': 'image/gif',
              'kind': 'image',
            },
            replyToId: _replyingTo?.id?.toString(),
            replyToText: _replyingTo?.text?.toString(),
            replyToSender: _replyingTo?.isFromMe == true ? 'You' : widget.peer.name,
          );
          if (mounted) setState(() => _replyingTo = null);
        },
      ),
    );
    search.dispose();
  }

  String _mimeForFile(String filename) {
    final name = filename.toLowerCase();
    if (name.endsWith('.pdf')) return 'application/pdf';
    if (name.endsWith('.doc')) return 'application/msword';
    if (name.endsWith('.docx')) return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (name.endsWith('.txt')) return 'text/plain';
    if (name.endsWith('.mp3')) return 'audio/mpeg';
    if (name.endsWith('.m4a')) return 'audio/mp4';
    if (name.endsWith('.wav')) return 'audio/wav';
    if (name.endsWith('.mp4')) return 'video/mp4';
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    return 'application/octet-stream';
  }

  Future<void> _startVoiceNote() async {
    if (_isRecordingVoice || _uploadingAttachment) return;
    try {
      final allowed = await _voiceRecorder.hasPermission();
      if (!allowed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission is required to record voice notes.')),
          );
        }
        return;
      }
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/novyn_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _voiceRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );
      if (!mounted) {
        await _voiceRecorder.stop();
        return;
      }
      HapticFeedback.mediumImpact();
      setState(() {
        _isRecordingVoice = true;
        _voiceSeconds = 0;
        _voiceRecordingPath = path;
      });
      _voiceTimer?.cancel();
      _voiceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _isRecordingVoice) {
          setState(() => _voiceSeconds++);
        }
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start recording: $error')),
        );
      }
    }
  }

  Future<void> _stopVoiceNote() async {
    if (!_isRecordingVoice) return;
    _voiceTimer?.cancel();
    _voiceTimer = null;
    final duration = _voiceSeconds;
    final path = _voiceRecordingPath;
    setState(() {
      _isRecordingVoice = false;
      _uploadingAttachment = true;
    });
    try {
      final recordedPath = await _voiceRecorder.stop();
      final filePath = recordedPath ?? path;
      if (filePath == null) throw StateError('Voice recording was not saved.');
      final file = File(filePath);
      if (!await file.exists()) throw StateError('Voice recording file was not found.');
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw StateError('Voice recording is empty.');
      final url = await ApiService.uploadVoice(bytes, 'voice_note.m4a', 'audio/mp4');
      if (url == null || url.isEmpty) throw StateError('Voice note upload failed. Please try again.');
      await context.read<SocketService>().sendMessage(
        '',
        widget.peer.uid.isNotEmpty ? widget.peer.uid : widget.peer.username,
        attachment: {
          'url': url,
          'name': 'Voice message',
          'mime': 'audio/mp4',
          'size': bytes.length,
          'kind': 'audio',
          'duration': duration,
        },
        replyToId: _replyingTo?.id?.toString(),
        replyToText: _replyingTo?.text?.toString(),
        replyToSender: _replyingTo?.isFromMe == true ? 'You' : widget.peer.name,
      );
      if (mounted) setState(() => _replyingTo = null);
      await file.delete();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error is StateError ? error.message.toString() : 'Could not send voice note.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingAttachment = false;
          _voiceRecordingPath = null;
        });
      }
    }
  }

  String _formatVoiceDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString();
    final remaining = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remaining';
  }

  void _startCall(String type) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          peer: widget.peer,
          callType: type,
        ),
      ),
    );
  }

  Future<void> _showSharedMedia() async {
    final messages = context.read<SocketService>().messages.where((message) => message.attachment is Map).toList().reversed.toList();
    var activeTab = 0;
    var searchQuery = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(builder: (context, refresh) {
        final media = messages.where((message) {
          final attachment = message.attachment as Map;
          final mime = attachment['mime']?.toString().toLowerCase() ?? '';
          return attachment['kind'] == 'image' || attachment['kind'] == 'video' || mime.startsWith('image/') || mime.startsWith('video/');
        }).toList();
        final docs = messages.where((message) {
          final attachment = message.attachment as Map;
          final mime = attachment['mime']?.toString().toLowerCase() ?? '';
          return attachment['kind'] == 'file' && !mime.startsWith('audio/') && !mime.startsWith('image/') && !mime.startsWith('video/') && (attachment['name']?.toString() ?? '').toLowerCase().contains(searchQuery);
        }).toList();
        final voice = messages.where((message) {
          final attachment = message.attachment as Map;
          final mime = attachment['mime']?.toString().toLowerCase() ?? '';
          return attachment['kind'] == 'audio' || mime.startsWith('audio/');
        }).toList();
        final activeItems = activeTab == 0 ? media : activeTab == 1 ? docs : voice;
        return Container(
          height: MediaQuery.of(context).size.height * 0.76,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            Container(width: 38, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 14),
            Row(children: [const Expanded(child: Text('Shared media & files', style: TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w700))), IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close_rounded))]),
            Row(children: [
              _sharedMediaTab('Media', media.length, 0, activeTab, (v) => refresh(() => activeTab = v)),
              const SizedBox(width: 7),
              _sharedMediaTab('Documents', docs.length, 1, activeTab, (v) => refresh(() => activeTab = v)),
              const SizedBox(width: 7),
              _sharedMediaTab('Voice', voice.length, 2, activeTab, (v) => refresh(() => activeTab = v)),
            ]),
            if (activeTab == 1) ...[
              const SizedBox(height: 10),
              TextField(onChanged: (value) => refresh(() => searchQuery = value.toLowerCase()), decoration: InputDecoration(hintText: 'Search files', prefixIcon: const Icon(Icons.search_rounded), filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: activeItems.isEmpty
                  ? const Center(child: Text('Nothing shared here yet'))
                  : activeTab == 0
                      ? GridView.builder(
                          itemCount: activeItems.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                          itemBuilder: (context, index) {
                            final attachment = activeItems[index].attachment as Map;
                            final url = attachment['url']?.toString() ?? '';
                            final mime = attachment['mime']?.toString().toLowerCase() ?? '';
                            return InkWell(
                              onTap: () {
                                if (mime.startsWith('image/')) {
                                  showDialog<void>(context: context, builder: (_) => Dialog(backgroundColor: Colors.transparent, child: InteractiveViewer(child: Image.network(url))));
                                } else {
                                  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                }
                              },
                              child: ClipRRect(borderRadius: BorderRadius.circular(10), child: mime.startsWith('image/') ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)) : Container(color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Center(child: Icon(Icons.play_circle_outline_rounded, size: 30)))),
                            );
                          },
                        )
                      : ListView.separated(
                          itemCount: activeItems.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final attachment = activeItems[index].attachment as Map;
                            final url = attachment['url']?.toString() ?? '';
                            final name = attachment['name']?.toString() ?? 'Attachment';
                            final isVoice = activeTab == 2;
                            return ListTile(leading: Icon(isVoice ? Icons.mic_none_rounded : Icons.insert_drive_file_outlined), title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text(isVoice ? 'Voice message' : name.split('.').last.toUpperCase()), trailing: const Icon(Icons.open_in_new_rounded, size: 18), onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication));
                          },
                        ),
            ),
          ]),
        );
      }),
    );
  }

  Widget _sharedMediaTab(String label, int count, int index, int active, ValueChanged<int> onSelected) {
    final selected = active == index;
    return Expanded(child: OutlinedButton(onPressed: () => onSelected(index), style: OutlinedButton.styleFrom(backgroundColor: selected ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08) : null, foregroundColor: Theme.of(context).colorScheme.onSurface, padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10)), child: Text('$label $count', style: const TextStyle(fontFamily: 'Inter', fontSize: 11))));
  }
  BoxDecoration _wallpaperDecoration(String wallpaper) {
    final value = wallpaper.trim();
    if (value.isEmpty) return const BoxDecoration();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return BoxDecoration(image: DecorationImage(image: NetworkImage(value), fit: BoxFit.cover, opacity: 0.13));
    }
    if (value.startsWith('#') && value.length == 7) {
      final color = Color(int.parse('FF' + value.substring(1), radix: 16));
      return BoxDecoration(color: color);
    }
    return const BoxDecoration();
  }

  Future<void> _showWallpaperPicker() async {
    const presets = <Map<String, String>>[
      {'name': 'Default', 'value': ''},
      {'name': 'Midnight', 'value': '#111827'},
      {'name': 'Deep slate', 'value': '#0f172a'},
      {'name': 'Ocean', 'value': '#0b2535'},
      {'name': 'Warm light', 'value': '#f1f5f9'},
      {'name': 'Soft grey', 'value': '#e5e7eb'},
    ];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chat wallpaper', style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: presets.map((preset) {
                final value = preset['value']!;
                final selected = context.read<SocketService>().chatWallpaper == value;
                final color = value.isEmpty ? Theme.of(context).colorScheme.surface : Color(int.parse('FF' + value.substring(1), radix: 16));
                return InkWell(
                  onTap: () {
                    context.read<SocketService>().setChatWallpaper(value, widget.peer.uid.isNotEmpty ? widget.peer.uid : widget.peer.username);
                    Navigator.pop(sheetContext);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 92,
                    child: Column(
                      children: [
                        Container(width: 76, height: 64, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.18))), child: selected ? const Icon(Icons.check_circle_rounded) : null),
                        const SizedBox(height: 5),
                        Text(preset['name']!, style: const TextStyle(fontFamily: 'Inter', fontSize: 11)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 82);
                  if (picked == null) return;
                  if (mounted) setState(() => _uploadingAttachment = true);
                  try {
                    final bytes = await picked.readAsBytes();
                    final url = await ApiService.uploadMedia(bytes, picked.name, _mimeForFile(picked.name));
                    if (url == null) throw StateError('Wallpaper upload failed.');
                    if (!mounted) return;
                    context.read<SocketService>().setChatWallpaper(url, widget.peer.uid.isNotEmpty ? widget.peer.uid : widget.peer.username);
                    Navigator.pop(sheetContext);
                  } catch (error) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error is StateError ? error.message.toString() : 'Could not upload wallpaper.')));
                  } finally {
                    if (mounted) setState(() => _uploadingAttachment = false);
                  }
                },
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose from gallery'),
              ),
            ),
          ],
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
  static final Map<String, Future<Map<String, dynamic>?>> _linkPreviewCache = {};

  String? _extractFirstUrl(String text) {
    return RegExp(r'https?://\S+, caseSensitive: false).firstMatch(text)?.group(0);
  }

  Widget _buildLinkPreview(BuildContext context, String url) {
    final future = _linkPreviewCache.putIfAbsent(url, () => ApiService.getLinkPreview(url));
    return FutureBuilder<Map<String, dynamic>?>(future: future, builder: (context, snapshot) {
      final data = snapshot.data;
      if (data == null || ((data['title']?.toString().isEmpty ?? true) && (data['image']?.toString().isEmpty ?? true))) return const SizedBox.shrink();
      final image = data['image']?.toString() ?? '';
      return InkWell(
        onTap: () => launchUrl(Uri.parse(data['url']?.toString() ?? url), mode: LaunchMode.externalApplication),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 245,
          margin: const EdgeInsets.only(top: 8),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (image.isNotEmpty) Image.network(image, width: 245, height: 112, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(data['siteName']?.toString() ?? data['domain']?.toString() ?? 'Link', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
                const SizedBox(height: 4),
                Text(data['title']?.toString() ?? url, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700)),
                if ((data['description']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(data['description'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFF94A3B8))),
                ],
              ]),
            ),
          ]),
        ),
      );
    });
  }

  final dynamic message;
  final bool showAvatar;
  final UserModel peer;
  final bool messagesRead;
  final String myUid;
  final ValueChanged<dynamic>? onReply;
  final ValueChanged<dynamic>? onForward;

  const _MessageBubble({
    required this.message,
    required this.showAvatar,
    required this.peer,
    this.messagesRead = false,
    this.myUid = '',
    this.onReply,
    this.onForward,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = message.isFromMe as bool;
    final time = _formatTime(message.createdAt);
    final reactions = Map<String, String>.from(message.reactions ?? {});

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
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
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // ── Bubble with long-press ──────────────────────────────
                GestureDetector(
                  onLongPress: () => _showReactionPicker(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
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
                                  : const Color(0xFF7C6FF7)
                                      .withValues(alpha: 0.08),
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
                        if ((message.pinnedAt?.toString().isNotEmpty ?? false))
                          const Padding(
                            padding: EdgeInsets.only(bottom: 5),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.push_pin_rounded, size: 11),
                                SizedBox(width: 4),
                                Text('Pinned message', style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        if (message.poll is Map) ...[
                          _buildPollCard(context, message.poll as Map),
                          const SizedBox(height: 6),
                        ],
                        if (message.attachment is Map && message.attachment['url'] != null) ...[
                          _buildAttachmentPreview(context, message.attachment as Map),
                          const SizedBox(height: 6),
                        ],
                        if ((message.text as String).isNotEmpty)
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
                        if (_extractFirstUrl(message.text as String) != null)
                          _buildLinkPreview(context, _extractFirstUrl(message.text as String)!),
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
              children: emojis
                  .map((e) => GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _toggleReaction(context, e);
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF7C6FF7).withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child:
                                Text(e, style: const TextStyle(fontSize: 22)),
                          ),
                        ),
                      ))
                  .toList(),
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
                const Divider(height: 1),
                _ActionItem(
                  icon: Icons.forward_rounded,
                  label: 'Forward',
                  color: const Color(0xFF64748B),
                  onTap: () {
                    Navigator.pop(context);
                    onForward?.call(message);
                  },
                ),
                const Divider(height: 1),
                _ActionItem(
                  icon: Icons.push_pin_outlined,
                  label: (message.pinnedAt?.toString().isNotEmpty ?? false) ? 'Unpin message' : 'Pin message',
                  color: const Color(0xFF64748B),
                  onTap: () {
                    Navigator.pop(context);
                    final socket = context.read<SocketService>();
                    if (message.pinnedAt?.toString().isNotEmpty ?? false) {
                      socket.unpinMessage(message.id.toString(), peer.uid.isNotEmpty ? peer.uid : peer.username);
                    } else {
                      socket.pinMessage(message.id.toString(), peer.uid.isNotEmpty ? peer.uid : peer.username);
                    }
                  },
                ),
                if ((message.isFromMe as bool)) ...[
                  const Divider(height: 1),
                  // Edit (only own messages, not tmp)
                  if (!(message.id as String).startsWith('tmp_') && !message.isEncrypted)
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

  Widget _buildPollCard(BuildContext context, Map poll) {
    final rawOptions = poll['options'];
    final options = rawOptions is List ? rawOptions.whereType<Map>().toList() : <Map>[];
    final totalVotes = options.fold<int>(0, (sum, option) {
      final votes = option['votes'];
      return sum + (votes is List ? votes.length : 0);
    });
    return Container(
      width: 250,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.poll_rounded, size: 17),
              const SizedBox(width: 7),
              const Text('POLL', style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
              const Spacer(),
              Text('$totalVotes votes', style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            poll['question']?.toString() ?? 'Poll',
            style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...options.map((option) {
            final votes = option['votes'] is List ? List<String>.from(option['votes'].map((v) => v.toString())) : <String>[];
            final count = votes.length;
            final selected = votes.any((vote) => vote.toLowerCase() == myUid.toLowerCase());
            final ratio = totalVotes == 0 ? 0.0 : count / totalVotes;
            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: InkWell(
                onTap: () => context.read<SocketService>().votePoll(
                  message.id.toString(),
                  option['id']?.toString() ?? '',
                  peer.uid.isNotEmpty ? peer.uid : peer.username,
                ),
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: selected ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(option['text']?.toString() ?? '', style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600))),
                          Text('$count', style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF94A3B8))),
                          if (selected) const Padding(padding: EdgeInsets.only(left: 5), child: Icon(Icons.check_circle, size: 14)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 4,
                          backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Text('Tap an option to vote or change your vote', style: TextStyle(fontFamily: 'Inter', fontSize: 9, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildAttachmentPreview(BuildContext context, Map attachment) {
    final url = attachment['url']?.toString() ?? '';
    final name = attachment['name']?.toString() ?? 'Attachment';
    final kind = attachment['kind']?.toString() ?? 'file';
    if (kind == 'image' && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          width: 220,
          height: 180,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _attachmentFileTile(name, Icons.broken_image_outlined),
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : Container(
                  width: 220,
                  height: 130,
                  alignment: Alignment.center,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
        ),
      );
    }
    final icon = kind == 'video'
        ? Icons.play_circle_outline_rounded
        : kind == 'audio'
            ? Icons.audio_file_outlined
            : Icons.insert_drive_file_outlined;
    return _attachmentFileTile(name, icon);
  }

  Widget _attachmentFileTile(String name, IconData icon) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 12),
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
    final color =
        messagesRead ? const Color(0xFF0EA5E9) : const Color(0xFF7C6FF7);

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

class _GifPickerSheet extends StatefulWidget {
  final String initialType;
  final ValueChanged<Map<String, dynamic>> onSelect;
  const _GifPickerSheet({required this.initialType, required this.onSelect});

  @override
  State<_GifPickerSheet> createState() => _GifPickerSheetState();
}

class _GifPickerSheetState extends State<_GifPickerSheet> {
  final TextEditingController _search = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String _type = 'gifs';
  String _category = '';
  int _nextOffset = 0;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool append = false}) async {
    if (append) {
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final result = await ApiService.getGiphy(
      query: _search.text.trim().isNotEmpty ? _search.text.trim() : _category,
      type: _type,
      offset: append ? _nextOffset : 0,
    );
    if (!mounted) return;
    final raw = result['items'];
    final incoming = raw is List
        ? raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
        : <Map<String, dynamic>>[];
    setState(() {
      if (append) {
        _items = [..._items, ...incoming];
      } else {
        _items = incoming;
      }
      _nextOffset = (result['nextOffset'] as num?)?.toInt() ?? _items.length;
      _error = result['error']?.toString();
      _loading = false;
      _loadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(width: 38, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.gif_box_rounded, size: 22),
              const SizedBox(width: 9),
              const Expanded(child: Text('GIFs & Stickers', style: TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w700))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ],
          ),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) { _category = ''; _load(); },
            decoration: InputDecoration(
              hintText: 'Search on GIPHY',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                onPressed: () { _search.clear(); _category = ''; _load(); },
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _gifTypeTab('GIFs', 'gifs')),
              const SizedBox(width: 8),
              Expanded(child: _gifTypeTab('Stickers', 'stickers')),
            ],
          ),
          if (_search.text.isEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final category in const ['Trending', 'Reaction', 'Funny', 'Love', 'Thumbs up', 'Party'])
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: _category.toLowerCase() == (category == 'Trending' ? '' : category.toLowerCase()),
                        onSelected: (_) {
                          _category = category == 'Trending' ? '' : category.toLowerCase();
                          _search.clear();
                          _load();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, textAlign: TextAlign.center))
                    : _items.isEmpty
                        ? const Center(child: Text('No results. Try another search.'))
                        : GridView.builder(
                            itemCount: _items.length,
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 1.05,
                            ),
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              final preview = item['previewUrl']?.toString() ?? item['url']?.toString() ?? '';
                              return InkWell(
                                onTap: () => widget.onSelect(item),
                                borderRadius: BorderRadius.circular(10),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(preview, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined))),
                                ),
                              );
                            },
                          ),
          ),
          if (!_loading && _error == null && _items.isNotEmpty)
            TextButton(
              onPressed: _loadingMore ? null : () => _load(append: true),
              child: Text(_loadingMore ? 'Loading…' : 'Load more'),
            ),
          const Text('Powered by GIPHY', style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _gifTypeTab(String label, String type) {
    final selected = _type == type;
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _type = type;
          _category = '';
        });
        _load();
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08) : null,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      child: Text(label),
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
    _MenuItem(
        icon: Icons.poll_rounded, label: 'Poll', color: Color(0xFF7C6FF7)),
    _MenuItem(
        icon: Icons.gif_box_rounded, label: 'GIFs', color: Color(0xFF0EA5E9)),
    _MenuItem(
        icon: Icons.sticky_note_2_outlined, label: 'Stickers', color: Color(0xFFEC4899)),
    _MenuItem(
        icon: Icons.photo_library_rounded,
        label: 'Media',
        color: Color(0xFF0EA5E9)),
    _MenuItem(
        icon: Icons.insert_drive_file_rounded,
        label: 'Document',
        color: Color(0xFFF59E0B)),
    _MenuItem(
        icon: Icons.headphones_rounded,
        label: 'Sound',
        color: Color(0xFFEC4899)),
    _MenuItem(
        icon: Icons.location_on_rounded,
        label: 'Location',
        color: Color(0xFF10B981)),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
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
                      Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.08),
                      const Color(0xFF7C6FF7).withValues(alpha: 0.15),
                      _ctrl.value,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: CustomPaint(
                    painter: _SparkIconPainter(
                      progress: _ctrl.value,
                      color: Color.lerp(
                        Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
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
                          color:
                              const Color(0xFF7C6FF7).withValues(alpha: 0.12),
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
                        color: Theme.of(ctx)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.08),
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
  const _MenuItem(
      {required this.icon, required this.label, required this.color});
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
    final armWidth = size.width * 0.065 + (progress * size.width * 0.04);

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
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.1),
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
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Text(
              'Type to search messages',
              style: TextStyle(
                fontFamily: 'Inter',
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    // Search through socket service messages
    final socket = context.read<SocketService>();
    final results = socket.messages
        .where((m) => m.text.toLowerCase().contains(query.toLowerCase()))
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
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Text(
              'No messages found for "$query"',
              style: TextStyle(
                fontFamily: 'Inter',
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
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
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
