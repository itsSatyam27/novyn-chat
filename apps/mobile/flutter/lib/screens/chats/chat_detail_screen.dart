import 'dart:convert';
import 'dart:math' as math;
import '../../widgets/novyn_alert.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../widgets/game_message_card.dart';
import '../../widgets/riddle_message_card.dart';
import '../../widgets/voice_message_player.dart';
import '../../models/user_model.dart';
import '../../models/chat_models.dart';
import '../../services/auth_service.dart';
import '../security/app_lock_screen.dart';
import '../../services/socket_service.dart';
import '../../services/api_service.dart';
import '../../services/hybrid_db_service.dart';
import '../../services/draft_service.dart';
import '../../services/settings_service.dart';
import '../../services/media_storage_service.dart';
import '../../widgets/user_avatar.dart';
import '../../utils/presence_utils.dart';
import '../../utils/quick_reaction_preferences.dart';
import '../../widgets/novyn_toast.dart';
import 'profile_info_screen.dart';
import 'group_info_screen.dart';
import '../../widgets/connection_banner.dart';
import '../../screens/calls/call_screen.dart';
import 'package:novyn/services/haptic_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../widgets/custom_emoji.dart';

String _mimeForFile(String filename) {
  final name = filename.toLowerCase();
  if (name.endsWith('.pdf')) return 'application/pdf';
  if (name.endsWith('.doc')) return 'application/msword';
  if (name.endsWith('.docx'))
    return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  if (name.endsWith('.txt')) return 'text/plain';
  if (name.endsWith('.csv')) return 'text/csv';
  if (name.endsWith('.zip')) return 'application/zip';
  if (name.endsWith('.rar')) return 'application/vnd.rar';
  if (name.endsWith('.mp3')) return 'audio/mpeg';
  if (name.endsWith('.m4a')) return 'audio/mp4';
  if (name.endsWith('.wav')) return 'audio/wav';
  if (name.endsWith('.ogg')) return 'audio/ogg';
  if (name.endsWith('.aac')) return 'audio/aac';
  if (name.endsWith('.mp4')) return 'video/mp4';
  if (name.endsWith('.mov')) return 'video/quicktime';
  if (name.endsWith('.m4v')) return 'video/mp4';
  if (name.endsWith('.heic')) return 'image/heic';
  if (name.endsWith('.webm')) return 'video/webm';
  if (name.endsWith('.gif')) return 'image/gif';
  if (name.endsWith('.png')) return 'image/png';
  if (name.endsWith('.webp')) return 'image/webp';
  if (name.endsWith('.bmp')) return 'image/bmp';
  if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
  return 'application/octet-stream';
}

class _ChatAttachmentLoader {
  static final Map<String, Future<Uint8List>> _bytesCache = {};
  static final Map<String, Future<String>> _fileCache = {};

  static Future<Uint8List> loadBytes(
    BuildContext context,
    Map attachment,
    Message message,
  ) async {
    final url = attachment['url']?.toString() ?? '';
    final backupLocalPath = attachment['backupLocalPath']?.toString() ?? '';
    if (url.isEmpty && backupLocalPath.isEmpty) {
      throw StateError('Attachment link is missing.');
    }
    final encrypted = attachment['encrypted'] == true;
    final socket = encrypted ? context.read<SocketService>() : null;
    final account = socket?.myUsername ?? '';
    final peerPublicKey = encrypted
        ? (message.isFromMe ? attachment['peerPublicKey'] : attachment['senderPublicKey'])?.toString() ?? ''
        : '';
    if (encrypted && account.isEmpty) throw StateError('Sign in to open this attachment.');
    if (encrypted && peerPublicKey.isEmpty) throw StateError('The attachment encryption key is missing.');
    final cacheKey = '$url|${attachment['iv'] ?? ''}|${message.isFromMe}|$account|$peerPublicKey';
    final cached = _bytesCache[cacheKey];
    if (cached != null) return cached;
    final loading = () async {
      final localFile = backupLocalPath.isEmpty ? null : File(backupLocalPath);
      final bytes = localFile != null && await localFile.exists()
          ? Uint8List.fromList(await localFile.readAsBytes())
          : await ApiService.downloadMediaBytes(url);
      if (!encrypted) return bytes;
      return socket!.encryption.decryptAttachmentBytes(
        bytes, account, peerPublicKey, attachment['iv']?.toString() ?? '',
      );
    }();
    _bytesCache[cacheKey] = loading;
    try {
      return await loading;
    } catch (_) {
      _bytesCache.remove(cacheKey);
      rethrow;
    }
  }

  static Future<String> prepareFile(
    BuildContext context,
    Map attachment,
    Message message,
  ) async {
    final peerPublicKey = (message.isFromMe
            ? attachment['peerPublicKey']
            : attachment['senderPublicKey'])?.toString() ?? '';
    final account = context.read<SocketService>().myUsername ?? '';
    final cacheKey = '${attachment['url']}|${attachment['iv'] ?? ''}|${message.isFromMe}|$account|$peerPublicKey';
    final existing = _fileCache[cacheKey];
    if (existing != null) return existing;
    final loading = () async {
      final bytes = await loadBytes(context, attachment, message);
      final directory = await getTemporaryDirectory();
      final rawName = attachment['name']?.toString() ?? 'novyn_attachment';
      final safeName = rawName.replaceAll(RegExp(r'[/\\:*?\"<>|]'), '_');
      final file = File('${directory.path}/novyn_${DateTime.now().microsecondsSinceEpoch}_$safeName');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    }();
    _fileCache[cacheKey] = loading;
    try {
      return await loading;
    } catch (_) {
      _fileCache.remove(cacheKey);
      rethrow;
    }
  }
}

class _ChatContentSnapshot {
  const _ChatContentSnapshot({
    required this.messages,
    required this.peerIsTyping,
    required this.peerIsRecordingVoice,
    required this.chatWallpaper,
    required this.messageStatusRevision,
  });

  final List<Message> messages;
  final bool peerIsTyping;
  final bool peerIsRecordingVoice;
  final String chatWallpaper;
  final int messageStatusRevision;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! _ChatContentSnapshot ||
        peerIsTyping != other.peerIsTyping ||
        peerIsRecordingVoice != other.peerIsRecordingVoice ||
        chatWallpaper != other.chatWallpaper ||
        messageStatusRevision != other.messageStatusRevision ||
        messages.length != other.messages.length) {
      return false;
    }
    return identical(messages, other.messages);
  }

  @override
  int get hashCode => Object.hash(
        identityHashCode(messages),
        peerIsTyping,
        peerIsRecordingVoice,
        chatWallpaper,
        messageStatusRevision,
      );
}

class ChatDetailScreen extends StatefulWidget {
  final UserModel peer;
  final bool isGroup;
  final bool chatLockAlreadyVerified;

  const ChatDetailScreen({
    super.key,
    required this.peer,
    this.isGroup = false,
    this.chatLockAlreadyVerified = false,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late final AnimationController _typingAnimation;
  late final SocketService _socketService;
  bool _appIsForeground = true;
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scroll = ScrollController();
  final GlobalKey _headerMenuButtonKey = GlobalKey();
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
  String _peerPresence = 'offline';
  DateTime? _peerLastSeen;
  bool _showPeerLastSeen = false;
  Timer? _presenceTransitionTimer;
  Timer? _lastSeenRefreshTimer;
  dynamic _replyingTo; // the message being replied to
  bool _uploadingAttachment = false;
  double _uploadProgress = 0;
  bool _cancelUploadRequested = false;
  bool _canCancelAttachmentUpload = false;
  Future<void> Function()? _retryAttachment;
  String? _pendingUploadFilePath;
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _voiceRecorder = AudioRecorder();
  Timer? _voiceTimer;
  bool _isRecordingVoice = false;
  bool _showJumpToLatest = false;
  bool _isNearLatest = true;
  bool _suppressNextCountScroll = false;
  int _voiceSeconds = 0;
  String? _voiceRecordingPath;
  bool _peerMuted = false;

  String get _mutePreferenceId => widget.isGroup
      ? (widget.peer.uid.isNotEmpty ? widget.peer.uid : widget.peer.username)
      : widget.peer.username;
  List<String> _quickEmojis =
      List<String>.from(defaultQuickReactionEmojis);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _typingAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _socketService = context.read<SocketService>();
    _socketService.addListener(_syncTypingAnimation);
    _syncTypingAnimation();
    _peerIsOnline = widget.peer.isOnline;
    _peerPresence = widget.peer.status.trim().toLowerCase();
    _peerLastSeen = widget.peer.lastSeen;
    _schedulePeerLastSeenReveal();
    _loadQuickEmojis();
    _loadPeerMutePreference();
    _initializeChatAccess();
    _scroll.addListener(_onScroll);

    // Load draft message
    _loadDraft();

    // Auto-save draft on text change
    _ctrl.addListener(_saveDraft);

    // Listen only to the shared contacts store. Do not wrap the global socket
    // callback here: doing so retained every opened chat in a growing chain.
    _socketService.contacts.addListener(_handlePeerPresenceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _handlePeerPresenceChanged();
    });
  }

  Future<void> _initializeChatAccess() async {
    if (!widget.chatLockAlreadyVerified) {
      final username =
          context.read<AuthService>().user?.username.trim().toLowerCase() ?? '';
      final peerUsername = widget.peer.username.trim().toLowerCase();
      if (username.isNotEmpty && peerUsername.isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final lockedChats =
              prefs.getStringList('novyn_locked_chats_$username') ??
                  const <String>[];
          if (lockedChats
              .map((value) => value.trim().toLowerCase())
              .contains(peerUsername)) {
            final settings = context.read<SettingsService>();
            if (!settings.appLockEnabled ||
                settings.appLockPin == null ||
                settings.appLockPin!.isEmpty ||
                !settings.secureStorageAvailable) {
              if (mounted) {
                context.showNovynAlert(const SnackBar(
                  content: Text(
                      'This chat is locked. Restore App Lock in Security & Privacy to unlock it.'),
                  behavior: SnackBarBehavior.floating,
                ));
                Navigator.of(context).pop();
              }
              return;
            }

            final unlocked = await Navigator.of(context).push<bool>(
              MaterialPageRoute<bool>(
                builder: (lockContext) => AppLockScreen(
                  onUnlocked: () => Navigator.of(lockContext).pop(true),
                ),
              ),
            );
            if (unlocked != true || !mounted) {
              if (mounted) Navigator.of(context).pop();
              return;
            }
          }
        } catch (error) {
          debugPrint('[NovynChatLock] Could not verify chat access: $error');
          if (mounted) {
            context.showNovynAlert(const SnackBar(
              content:
                  Text('Could not verify this chat lock. Please try again.'),
              behavior: SnackBarBehavior.floating,
            ));
            Navigator.of(context).pop();
          }
          return;
        }
      }
    }
    if (mounted) await _init();
  }

  bool _isOfflinePresenceState() =>
      !_peerIsOnline ||
      _peerPresence == 'offline' ||
      _peerPresence == 'invisible';

  String _peerStatusLabel() {
    if (_peerPresence == 'away') return 'Away';
    if (_peerPresence == 'busy' || _peerPresence == 'dnd') return 'Busy';
    if (_isOfflinePresenceState()) {
      return _showPeerLastSeen && _peerLastSeen != null
          ? formatLastSeenLabel(_peerLastSeen)
          : 'Offline';
    }
    return 'Online';
  }

  void _schedulePeerLastSeenReveal() {
    _presenceTransitionTimer?.cancel();
    _lastSeenRefreshTimer?.cancel();
    _showPeerLastSeen = false;
    if (widget.isGroup || !_isOfflinePresenceState() || _peerLastSeen == null)
      return;
    // Keep Offline visible briefly, then transition inside a fixed-height slot.
    _presenceTransitionTimer = Timer(const Duration(milliseconds: 850), () {
      if (!mounted || !_isOfflinePresenceState() || _peerLastSeen == null)
        return;
      setState(() => _showPeerLastSeen = true);
      _lastSeenRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted && _showPeerLastSeen) setState(() {});
      });
    });
  }

  void _handlePeerPresenceChanged() {
    if (!mounted || widget.isGroup) return;
    final currentPeer = _socketService.contacts.findUser(widget.peer.username);
    if (currentPeer == null) return;

    final nextOnline = currentPeer.isOnline;
    final nextPresence = currentPeer.status.trim().toLowerCase();
    final nextLastSeen = currentPeer.lastSeen;
    if (_peerIsOnline == nextOnline &&
        _peerPresence == nextPresence &&
        _peerLastSeen == nextLastSeen) return;

    setState(() {
      _peerIsOnline = nextOnline;
      _peerPresence = nextPresence;
      _peerLastSeen = nextLastSeen;
    });
    _schedulePeerLastSeenReveal();
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

  String get _pendingUploadKey =>
      'novyn_pending_upload_${Uri.encodeComponent((_myUid ?? '').toLowerCase())}_${Uri.encodeComponent((_chatId ?? '').toLowerCase())}';

  Future<void> _persistPendingAttachmentUpload({
    required Uint8List bytes,
    required String filename,
    required String mime,
    required int size,
    required String recipient,
    required String kind,
    required Map<String, dynamic> encryptionMetadata,
    String? displayName,
    Map<String, dynamic> attachmentExtra = const <String, dynamic>{},
    bool voiceEndpoint = false,
    String? replyToId,
    String? replyToText,
    String? replyToSender,
  }) async {
    try {
      final root = await getApplicationSupportDirectory();
      final directory = Directory('${root.path}/novyn_pending_uploads');
      await directory.create(recursive: true);
      final file = File(
        '${directory.path}/upload_${DateTime.now().microsecondsSinceEpoch}.bin',
      );
      await file.writeAsBytes(bytes, flush: true);
      final prefs = await SharedPreferences.getInstance();
      final previousPath = _pendingUploadFilePath;
      await prefs.setString(
        _pendingUploadKey,
        jsonEncode({
          'path': file.path,
          'filename': filename,
          'mime': mime,
          'size': size,
          'recipient': recipient,
          'kind': kind,
          'encryptionMetadata': encryptionMetadata,
          'displayName': displayName,
          'attachmentExtra': attachmentExtra,
          'voiceEndpoint': voiceEndpoint,
          'replyToId': replyToId,
          'replyToText': replyToText,
          'replyToSender': replyToSender,
        }),
      );
      _pendingUploadFilePath = file.path;
      if (previousPath != null && previousPath != file.path) {
        try {
          await File(previousPath).delete();
        } catch (_) {}
      }
    } catch (error) {
      debugPrint('[NovynUpload] Could not persist retry file: $error');
    }
  }

  Future<void> _restorePendingAttachmentUpload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingUploadKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final record = Map<String, dynamic>.from(decoded);
      final path = record['path']?.toString() ?? '';
      final file = File(path);
      if (path.isEmpty || !await file.exists()) {
        await prefs.remove(_pendingUploadKey);
        return;
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        await prefs.remove(_pendingUploadKey);
        return;
      }
      final metadata = record['encryptionMetadata'] is Map
          ? Map<String, dynamic>.from(record['encryptionMetadata'] as Map)
          : <String, dynamic>{};
      final attachmentExtra = record['attachmentExtra'] is Map
          ? Map<String, dynamic>.from(record['attachmentExtra'] as Map)
          : <String, dynamic>{};
      _pendingUploadFilePath = path;
      _retryAttachment = () => _uploadAndSendPreparedAttachment(
            Uint8List.fromList(bytes),
            record['filename']?.toString() ?? 'attachment',
            record['mime']?.toString() ?? 'application/octet-stream',
            (record['size'] as num?)?.toInt() ?? bytes.length,
            record['recipient']?.toString() ?? widget.peer.username,
            record['kind']?.toString() ?? 'file',
            metadata,
            displayName: record['displayName']?.toString(),
            attachmentExtra: attachmentExtra,
            voiceEndpoint: record['voiceEndpoint'] == true,
            replyToId: record['replyToId']?.toString(),
            replyToText: record['replyToText']?.toString(),
            replyToSender: record['replyToSender']?.toString(),
          );
      if (mounted) setState(() {});
    } catch (error) {
      debugPrint('[NovynUpload] Could not restore retry file: $error');
    }
  }

  Future<void> _discardPendingAttachmentUpload() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingUploadKey);
    final path = _pendingUploadFilePath;
    _pendingUploadFilePath = null;
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    if (mounted) setState(() => _retryAttachment = null);
  }

  // Load older messages when scrolled to top
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final nearLatest = _scroll.position.extentAfter <= 120;
    if (nearLatest != _isNearLatest && mounted) {
      setState(() {
        _isNearLatest = nearLatest;
        _showJumpToLatest = !nearLatest;
      });
    }
    if (_scroll.position.pixels <= 80 &&
        !_loadingOlder &&
        _hasMore &&
        _chatId != null) {
      _loadOlderMessages();
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_loadingOlder || !_hasMore || _chatId == null) return;
    final socket = context.read<SocketService>();
    final messages = socket.messages;
    if (messages.isEmpty) return;

    setState(() => _loadingOlder = true);
    final previousExtent =
        _scroll.hasClients ? _scroll.position.maxScrollExtent : 0.0;
    final previousPixels = _scroll.hasClients ? _scroll.position.pixels : 0.0;

    try {
      final hasMore = await socket.loadOlderHistory(
        _chatId!,
        messages.first.id,
        isGroup: widget.isGroup,
      );
      if (!mounted) return;
      _hasMore = hasMore;
      _suppressNextCountScroll = true;
      setState(() => _loadingOlder = false);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients || !mounted) return;
        final newExtent = _scroll.position.maxScrollExtent;
        final delta = newExtent - previousExtent;
        if (delta > 0) {
          _scroll.jumpTo(
            (previousPixels + delta)
                .clamp(0.0, _scroll.position.maxScrollExtent)
                .toDouble(),
          );
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Future<void> _init() async {
    final auth = context.read<AuthService>();
    final socket = context.read<SocketService>();
    _myUid = auth.user?.username;
    if (_myUid == null || _myUid!.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    // Direct-message history and notification deep-links use the peer
    // username as the canonical conversation key. Groups retain their UID key.
    _chatId = widget.isGroup
        ? (widget.peer.uid.isNotEmpty ? widget.peer.uid : widget.peer.username)
        : widget.peer.username;
    await _restorePendingAttachmentUpload();

    final cacheWatch = Stopwatch()..start();
    List<Message> cachedMessages = [];
    try {
      // Render the complete Hive cache first; Drift is warmed and merged later.
      cachedMessages = await HybridDbService.getCachedMessages(_chatId!)
          .timeout(const Duration(seconds: 4), onTimeout: () => <Message>[]);
    } catch (error) {
      debugPrint('[NovynChat] Local message cache read failed: $error');
    }
    debugPrint(
        '[NovynPerf] chat_cache_ms=${cacheWatch.elapsedMilliseconds} count=${cachedMessages.length}');
    if (!mounted) return;

    // openChat requests history from the authenticated Socket.IO session and
    // completes only after the matching conversation response is processed.
    // Avoid the legacy REST history endpoint, which can return an empty list
    // independently of the live conversation and race the socket response.
    final historyRequest = socket.openChat(
      _chatId!,
      cachedMessages,
      isGroup: widget.isGroup,
    );
    unawaited(_hydrateIndexedCache(_chatId!, socket));
    setState(() {
      _loading = false;
      _fetchingFromServer = cachedMessages.isEmpty;
    });

    try {
      final history = await historyRequest;
      if (!mounted) return;

      if (history.isNotEmpty) {
        // The socket service has already merged these messages into the
        // active timeline. Persist the confirmed snapshot and reveal it.
        unawaited(HybridDbService.saveMessages(history));
        unawaited(HybridDbService.setLastSync(_chatId!, DateTime.now()));
        _jumpToLatestImmediately();
      } else if (socket.messages.isNotEmpty) {
        // A live message may have arrived while the history request was in flight.
        _jumpToLatestImmediately();
      }

      final settings = context.read<SettingsService>();
      if (settings.readReceipts && !widget.isGroup) {
        unawaited(ApiService.markRead(_chatId!, _myUid!));
      }
    } catch (error) {
      debugPrint('[NovynChat] Conversation history load failed: $error');
      if (mounted) {
        if (socket.messages.isNotEmpty) {
          _jumpToLatestImmediately();
        }
      }
    } finally {
      if (mounted) setState(() => _fetchingFromServer = false);
    }
  }

  Future<void> _hydrateIndexedCache(String chatId, SocketService socket) async {
    final watch = Stopwatch()..start();
    try {
      final merged = await HybridDbService.getMessages(chatId);
      if (!mounted || _chatId != chatId || merged.isEmpty) return;
      // Do not let a late, potentially stale disk mirror overwrite newer
      // socket/server message state; only backfill IDs missing from memory.
      final existingIds = socket.messages.map((message) => message.id).toSet();
      final missing =
          merged.where((message) => !existingIds.contains(message.id)).toList();
      if (missing.isNotEmpty) socket.mergeChatHistory(missing);
      debugPrint(
          '[NovynPerf] chat_secondary_cache_ms=${watch.elapsedMilliseconds} backfilled=${missing.length}');
    } catch (error) {
      debugPrint('[NovynChat] Secondary cache hydration failed: $error');
    }
  }

  void _syncTypingAnimation() {
    if (!mounted) return;
    final shouldAnimate = _appIsForeground &&
        (_socketService.peerIsTyping ||
            _socketService.peerIsRecordingVoice ||
            _isRecordingVoice);
    if (shouldAnimate) {
      if (!_typingAnimation.isAnimating) _typingAnimation.repeat();
    } else if (_typingAnimation.isAnimating) {
      _typingAnimation.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appIsForeground = true;
      _syncTypingAnimation();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _appIsForeground = false;
      _typingAnimation.stop();
    }
  }

  @override
  void didChangeMetrics() {
    if (!_messageFocusNode.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      // Keyboard insets can change the viewport abruptly on Android. A short,
      // bounded animation keeps the latest message visible without a harsh jump.
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
      _isNearLatest = true;
      if (_showJumpToLatest) setState(() => _showJumpToLatest = false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _typingAnimation.dispose();
    _voiceTimer?.cancel();
    _presenceTransitionTimer?.cancel();
    _lastSeenRefreshTimer?.cancel();
    if (_isRecordingVoice) unawaited(_voiceRecorder.stop());
    _socketService.stopVoiceActivity();
    unawaited(_voiceRecorder.dispose());
    _socketService.removeListener(_syncTypingAnimation);
    _socketService.contacts.removeListener(_handlePeerPresenceChanged);
    _socketService.closeChat(notify: false);
    _scroll.removeListener(_onScroll);
    _ctrl.removeListener(_saveDraft);
    _ctrl.dispose();
    _messageFocusNode.dispose();
    _scroll.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _startReply(dynamic message) {
    setState(() => _replyingTo = message);
    // Bring the composer into view and open the keyboard immediately after
    // the reply preview has been laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _messageFocusNode.requestFocus();
      _scrollToBottom(force: true);
    });
  }

  void _playSentSound() {
    // Audio plugin setup must never hold the composer or the next send.
    unawaited(() async {
      try {
        await _audioPlayer.setAudioContext(AudioContext(
          android: AudioContextAndroid(
            audioFocus: AndroidAudioFocus.none,
            usageType: AndroidUsageType.notification,
            contentType: AndroidContentType.sonification,
          ),
        ));
        await _audioPlayer.play(AssetSource('audio/message_sent.mp3'));
      } catch (error) {
        debugPrint('[NovynChat] Sent sound playback failed: $error');
      }
    }());
  }

  void _send() async {
    final text = _ctrl.text.trim();
    if (_sending || text.isEmpty || _myUid == null || _chatId == null) return;
    HapticService.vibrate(NovynHapticType.light, category: HapticCategory.chat);

    final socket = context.read<SocketService>();
    socket.stopTyping(widget.peer.uid, isGroup: widget.isGroup);
    _sending = true;
    try {
      // sendMessage adds its optimistic bubble synchronously before its first
      // network wait. Clear the composer now so the UI reacts to the tap
      // immediately, even when Android is still resuming the socket.
      final pendingSend = socket.sendMessage(
        text,
        widget.peer.uid.isNotEmpty ? widget.peer.uid : widget.peer.username,
        replyToId: _replyingTo?.id?.toString(),
        replyToText: _replyingTo?.text?.toString(),
        replyToSender: _replyingTo?.isFromMe == true ? 'You' : widget.peer.name,
        isGroup: widget.isGroup,
      );
      final optimisticMessageId = socket.messages.isNotEmpty
          ? socket.messages.last.id
          : null;

      if (mounted) {
        if (_ctrl.text.trim() == text) _ctrl.clear();
        DraftService.deleteDraft(_chatId!);
        setState(() => _replyingTo = null);
        _scrollToBottom();
      }

      await pendingSend;
      if (!mounted) return;
      if (optimisticMessageId != null &&
          socket.messageStatusFor(optimisticMessageId) != 'sending' &&
          socket.messageStatusFor(optimisticMessageId) != 'failed') {
        _playSentSound();
      }
    } catch (error) {
      if (mounted) {
        // Restore the failed text only when the user has not started another
        // draft; never overwrite newer text typed during reconnection.
        if (_ctrl.text.trim().isEmpty) _ctrl.text = text;
        NovynAlert.show(
          context,
          error is StateError
              ? error.message.toString()
              : error is TimeoutException
                  ? (error.message ??
                      'Message delivery was not confirmed. Check your connection.')
                  : 'Could not send message: $error',
          isError: true,
          title: 'Message not sent',
          icon: Icons.send_rounded,
          tone: NovynAlertTone.warning,
        );
      }
    } finally {
      _sending = false;
    }
  }

  // Opening a conversation should land directly on the newest message.
  // Avoid animating through the entire history, which feels slow on long chats.
  void _jumpToLatestImmediately() {
    var attempts = 0;
    var stableFrames = 0;
    double? previousExtent;

    void retryAfterLayout() {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        if (!_scroll.hasClients || !_scroll.position.hasContentDimensions) {
          if (++attempts < 40) {
            await Future<void>.delayed(const Duration(milliseconds: 30));
            if (mounted) retryAfterLayout();
          }
          return;
        }

        final position = _scroll.position;
        final extent = position.maxScrollExtent;
        _scroll.jumpTo(extent);

        if (previousExtent != null &&
            (extent - previousExtent!).abs() < 1.0 &&
            (position.maxScrollExtent - position.pixels).abs() < 1.0) {
          stableFrames++;
        } else {
          stableFrames = 0;
        }
        previousExtent = extent;

        if (++attempts < 40 && stableFrames < 3) {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          if (mounted) retryAfterLayout();
        } else if (mounted) {
          _isNearLatest = true;
          if (_showJumpToLatest) setState(() => _showJumpToLatest = false);
        }
      });
    }

    retryAfterLayout();
    _isNearLatest = true;
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients || !mounted) return;
      if (!force && !_isNearLatest) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
      if (_showJumpToLatest && mounted) {
        setState(() {
          _showJumpToLatest = false;
          _isNearLatest = true;
        });
      }
    });
  }

  void _jumpToLatest() {
    _isNearLatest = true;
    _scrollToBottom(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final socket = context.read<SocketService>();
    final snapshot = context.select<SocketService, _ChatContentSnapshot>(
      (service) => _ChatContentSnapshot(
        messages: service.messages,
        peerIsTyping: service.peerIsTyping,
        peerIsRecordingVoice: service.peerIsRecordingVoice,
        chatWallpaper: service.chatWallpaper,
        messageStatusRevision: service.messageStatusRevision,
      ),
    );
    final messages = snapshot.messages;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _buildAppBar(socket),
      body: Container(
        decoration: _wallpaperDecoration(snapshot.chatWallpaper),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (snapshot.chatWallpaper.trim().isEmpty)
              Positioned.fill(
                child: Builder(
                  builder: (wallpaperContext) {
                    final settings = wallpaperContext.watch<SettingsService>();
                    final theme = Theme.of(wallpaperContext);
                    final accent = settings.accentColorEnabled
                        ? Color(settings.accentColorValue)
                        : theme.colorScheme.primary;
                    return Opacity(
                      opacity: theme.brightness == Brightness.dark ? 0.14 : 0.98,
                      child: SvgPicture.asset(
                        'assets/images/novyn_chat_wallpaper.svg',
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          accent.withValues(
                            alpha: theme.brightness == Brightness.dark ? 0.24 : 0.14,
                          ),
                          BlendMode.srcATop,
                        ),
                      ),
                    );
                  },
                ),
              ),
            Column(
              children: [
            ConnectionBanner(chatId: _chatId ?? widget.peer.username),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _loading
                        ? Center(
                            child: CircularProgressIndicator(
                                color: Theme.of(context).colorScheme.primary))
                        : messages.isEmpty
                            ? _fetchingFromServer
                                ? _buildLoadingShimmer()
                                : _buildEmptyChat()
                            : _buildMessageList(
                                messages,
                                snapshot.peerIsTyping,
                                peerIsRecordingVoice:
                                    snapshot.peerIsRecordingVoice,
                              ),
                  ),
                  if (_showJumpToLatest && messages.isNotEmpty)
                    Positioned(
                      right: 18,
                      bottom: 18,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.82, end: 1),
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutBack,
                        builder: (context, scale, child) => Transform.scale(
                          scale: scale,
                          child: child,
                        ),
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          elevation: 7,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _jumpToLatest,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.18)),
                              ),
                              child: Icon(
                                  Icons.keyboard_double_arrow_down_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 23),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              left: false,
              right: false,
              child: _buildInputBar(socket),
            ),
          ],
            ),
          ],
        ),
      ),
    );
  }

  Color _headerBackdrop(String wallpaper, bool dark) {
    final v = wallpaper.trim();
    if (v.startsWith('#') && v.length == 7) {
      return Color(int.parse('FF${v.substring(1)}', radix: 16));
    }
    return dark ? const Color(0xFF0B0B17) : const Color(0xFFF9F7FF);
  }

  bool _isSameMinute(DateTime a, DateTime b) {
    final x = a.toLocal();
    final y = b.toLocal();
    return x.year == y.year &&
        x.month == y.month &&
        x.day == y.day &&
        x.hour == y.hour &&
        x.minute == y.minute;
  }

  PreferredSizeWidget _buildAppBar(SocketService socket) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final topInset = MediaQuery.paddingOf(context).top;
    const cardHeight = 48.0;
    const gapTop = 8.0;
    const gapBottom = 8.0;

    final peerStatusLabel = widget.isGroup
        ? (widget.peer.bio.isNotEmpty ? widget.peer.bio : 'Group conversation')
        : _peerStatusLabel();
    final peerStatusColor = widget.isGroup
        ? scheme.onSurfaceVariant
        : (_peerPresence == 'away'
            ? const Color(0xFFF59E0B)
            : (_peerPresence == 'busy' || _peerPresence == 'dnd'
                ? const Color(0xFFEC4899)
                : (_isOfflinePresenceState()
                    ? scheme.onSurfaceVariant
                    : const Color(0xFF16A34A))));

    final iconColor = isDark ? Colors.white : const Color(0xFF2D2942);
    final pillBg = isDark ? const Color(0xFF1B1A28) : Colors.white;
    final pillBorder = Border.all(
      color: isDark ? scheme.outlineVariant.withValues(alpha: .2) : const Color(0xFFEEEAF8),
      width: 1,
    );
    final pillShadow = [
      BoxShadow(
        color: isDark ? Colors.black26 : const Color(0xFF5E44F3).withValues(alpha: .04),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ];

    Widget buildCirclePill({
      Key? key,
      required Widget child,
      required VoidCallback onTap,
      String? tooltip,
    }) {
      return Container(
        key: key,
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: pillBg,
          shape: BoxShape.circle,
          border: pillBorder,
          boxShadow: pillShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(child: child),
          ),
        ),
      );
    }

    Widget buildContactPill() {
      return Container(
        height: 48,
        decoration: BoxDecoration(
          color: pillBg,
          borderRadius: BorderRadius.circular(24),
          border: pillBorder,
          boxShadow: pillShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: _showContactInfo,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(5, 4, 14, 4),
              child: Row(
                children: [
                  Hero(
                    tag: 'avatar_${widget.peer.uid}',
                    child: UserAvatar(
                      name: widget.peer.name,
                      photoUrl: widget.peer.photoUrl,
                      radius: 19,
                      showOnlineIndicator: false,
                      isOnline: widget.isGroup ? false : _peerIsOnline,
                      presence: _peerPresence,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.peer.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            height: 1.15,
                            color: isDark ? Colors.white : const Color(0xFF1E1C2A),
                          ),
                        ),
                        const SizedBox(height: 1.5),
                        Text(
                          peerStatusLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11.5,
                            height: 1.1,
                            fontWeight: FontWeight.w600,
                            color: peerStatusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget buildCallsPill() {
      return Container(
        height: 48,
        decoration: BoxDecoration(
          color: pillBg,
          borderRadius: BorderRadius.circular(24),
          border: pillBorder,
          boxShadow: pillShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
                onTap: () => _startCall('voice'),
                child: Container(
                  width: 42,
                  height: 48,
                  alignment: Alignment.center,
                  child: Icon(
                    LucideIcons.phone,
                    size: 18,
                    color: iconColor,
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 18,
                color: isDark ? Colors.white24 : const Color(0xFFE6E2F0),
              ),
              InkWell(
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(24)),
                onTap: () => _startCall('video'),
                child: Container(
                  width: 42,
                  height: 48,
                  alignment: Alignment.center,
                  child: Icon(
                    LucideIcons.video,
                    size: 19,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PreferredSize(
      preferredSize: Size.fromHeight(topInset + gapTop + cardHeight + gapBottom),
      child: ColoredBox(
        color: _headerBackdrop(socket.chatWallpaper, isDark),
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, topInset + gapTop, 12, gapBottom),
          child: Row(
            children: [
              buildCirclePill(
                onTap: () => Navigator.pop(context),
                tooltip: 'Back',
                child: Icon(
                  LucideIcons.chevronLeft,
                  size: 22,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: buildContactPill(),
              ),
              const SizedBox(width: 8),
              if (!widget.isGroup) ...[
                buildCallsPill(),
                const SizedBox(width: 8),
              ],
              buildCirclePill(
                key: _headerMenuButtonKey,
                onTap: _showHeaderMenu,
                tooltip: 'More options',
                child: Icon(
                  Icons.more_vert_rounded,
                  size: 20,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showHeaderMenu() async {
    final buttonContext = _headerMenuButtonKey.currentContext;
    if (buttonContext == null || !mounted) return;
    final box = buttonContext.findRenderObject() as RenderBox?;
    if (box == null) return;
    final anchor = box.localToGlobal(Offset.zero) & box.size;

    final selected = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close menu',
      barrierColor: Colors.black.withValues(alpha: .14),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, __) => _ChatMenuPopover(
        anchor: anchor,
        isGroup: widget.isGroup,
        muted: _peerMuted,
        blocked: _isPeerBlocked(),
      ),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: .92, end: 1).animate(curved),
            alignment: Alignment.topRight,
            child: child,
          ),
        );
      },
    );

    if (!mounted || selected == null) return;
    switch (selected) {
      case 'info':
        _showContactInfo();
        break;
      case 'search':
        showSearch<String>(
          context: context,
          delegate: _MessageSearchDelegate(peer: widget.peer),
        );
        break;
      case 'shared':
        _showSharedMedia();
        break;
      case 'mute':
        await _toggleMute();
        break;
      case 'mute-on':
        await _setPeerMuted(true);
        break;
      case 'mute-off':
        await _setPeerMuted(false);
        break;
      case 'wallpaper':
        _showWallpaperPicker();
        break;
      case 'export':
        _exportChat();
        break;
      case 'clear':
        _confirmClearChat();
        break;
      case 'block':
        _confirmToggleBlock();
        break;
    }
  }

  Widget _buildEmptyChat() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    Widget quickAction({
      required IconData icon,
      required String title,
      required String subtitle,
      required Color tint,
      required Color accent,
      required VoidCallback onTap,
    }) {
      return Material(
        color: scheme.surface,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: tint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: accent, size: 25),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant, size: 24),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 650;
        final illustrationSize = compact ? 160.0 : 188.0;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics()),
          padding: EdgeInsets.fromLTRB(16, compact ? 6 : 12, 16, 12),
          child: Column(
            children: [
              SizedBox(
                width: illustrationSize,
                height: illustrationSize,
                child: CustomPaint(
                  painter: _ChatEmptyRingsPainter(
                    ring: scheme.primary.withValues(alpha: dark ? .18 : .12),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: .13),
                            blurRadius: 22,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: scheme.primary.withValues(alpha: .16),
                            width: 2,
                          ),
                        ),
                        child: UserAvatar(
                          name: widget.peer.name,
                          photoUrl: widget.peer.photoUrl,
                          radius: compact ? 45 : 56,
                          showOnlineIndicator: !widget.isGroup,
                          isOnline: widget.peer.isOnline,
                          presence: widget.peer.status,
                          fallbackColor: widget.peer.avatarColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.peer.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: compact ? 21 : 23,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.55,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.isGroup
                    ? 'Group conversation'
                    : '@${widget.peer.username}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: dark ? .18 : .10),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.isGroup
                          ? Icons.groups_rounded
                          : Icons.lock_outline_rounded,
                      color: scheme.primary,
                      size: 17,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      widget.isGroup
                          ? 'Group conversation'
                          : 'End-to-end encrypted',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: compact ? 18 : 22),
              Text(
                'No messages yet. Start with something quick',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(27),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: .22),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          scheme.primary.withValues(alpha: dark ? .02 : .045),
                      blurRadius: 22,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    quickAction(
                      icon: Icons.waving_hand_rounded,
                      title: 'Wave hello',
                      subtitle: 'Break the ice with a wave',
                      tint: scheme.primaryContainer,
                      accent: scheme.primary,
                      onTap: () {
                        unawaited(context.read<SocketService>().sendMessage(
                              '👋',
                              widget.peer.uid.isNotEmpty
                                  ? widget.peer.uid
                                  : widget.peer.username,
                              isGroup: widget.isGroup,
                            ));
                      },
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 18,
                      endIndent: 18,
                      color: scheme.outlineVariant.withValues(alpha: .42),
                    ),
                    quickAction(
                      icon: Icons.gif_box_rounded,
                      title: 'Send a GIF',
                      subtitle: 'Pick something fun',
                      tint: scheme.primaryContainer,
                      accent: scheme.primary,
                      onTap: _showGifPicker,
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

  /// Shown when cache is empty and we're waiting for the first API response.
  /// Looks like message bubbles so the transition is smooth.
  Widget _buildLoadingShimmer() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = scheme.surfaceContainerHighest;
    final highlight = Color.lerp(
      base,
      scheme.primary,
      theme.brightness == Brightness.dark ? .10 : .045,
    )!;

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
  List<Message>? _timelineSource;
  List<int> _timelineIndices = const <int>[];

  Widget _buildMessageList(
    List<Message> messages,
    bool peerIsTyping, {
    bool peerIsRecordingVoice = false,
  }) {
    if (messages.length > _lastMessageCount) {
      final addedMessages = messages.length - _lastMessageCount;
      _lastMessageCount = messages.length;
      if (_suppressNextCountScroll) {
        _suppressNextCountScroll = false;
      } else if (_isNearLatest || addedMessages == messages.length) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToBottom(force: true));
      } else if (mounted && !_showJumpToLatest) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _showJumpToLatest = true);
        });
      }
    }
    if (!identical(_timelineSource, messages)) {
      final indices = <int>[];
      for (var index = 0; index < messages.length; index++) {
        if (index == 0 ||
            !_isSameChatDay(
                messages[index - 1].createdAt, messages[index].createdAt)) {
          // Negative entries represent a date divider for the following message.
          indices.add(-index - 1);
        }
        indices.add(index);
      }
      _timelineSource = messages;
      _timelineIndices = List<int>.unmodifiable(indices);
    }
    final timelineIndices = _timelineIndices;
    final socket = context.read<SocketService>();
    if (peerIsTyping && _isNearLatest) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToBottom(force: true));
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
      itemCount: timelineIndices.length +
          1 +
          (peerIsTyping || peerIsRecordingVoice ? 1 : 0),
      // Performance optimizations
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      cacheExtent: 500, // Cache 500px above/below viewport
      itemBuilder: (context, i) {
        // Top item: loading indicator or "start of conversation"
        if (i == 0) {
          if (_loadingOlder) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
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
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Start of conversation',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }
          return const SizedBox(height: 8);
        }

        final timelinePosition = i - 1;
        if ((peerIsTyping || peerIsRecordingVoice) &&
            timelinePosition == timelineIndices.length) {
          return _buildTypingIndicator(
            isVoiceRecording: peerIsRecordingVoice,
          );
        }
        final timelineItem = timelineIndices[timelinePosition];
        if (timelineItem < 0) {
          final dateMessageIndex = -timelineItem - 1;
          return _buildDateSeparator(messages[dateMessageIndex].createdAt);
        }
        final msgIndex = timelineItem;
        final current = messages[msgIndex];
        final next = msgIndex + 1 < messages.length ? messages[msgIndex + 1] : null;
        // last bubble of a run from the same sender
        final lastInGroup = next == null ||
            next.isFromMe != current.isFromMe ||
            (widget.isGroup && next.senderId != current.senderId);
        // show time + tick only at the end of a run or when the minute changes
        final showMeta = lastInGroup ||
            next == null ||
            !_isSameMinute(current.createdAt, next.createdAt) ||
            (current.reactions ?? {}).isNotEmpty ||
            (current.isFromMe &&
                socket.messageStatusFor(current.id) == 'failed');
        return _SwipeToReply(
          onSwipe: () => _startReply(current),
          child: _MessageBubble(
            message: current,
            showAvatar: !current.isFromMe && lastInGroup,
            showMeta: showMeta,
            peer: widget.peer,
            isGroup: widget.isGroup,
            messageStatus: socket.messageStatusFor(current.id),
            myUid: _myUid ?? '',
            quickEmojis: _quickEmojis,
            onReply: _startReply,
            onForward: _showForwardDialog,
          ),
        );
      },
    );
  }

  bool _isSameChatDay(DateTime first, DateTime second) {
    final a = first.toLocal();
    final b = second.toLocal();
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildDateSeparator(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(local.year, local.month, local.day);
    final scheme = Theme.of(context).colorScheme;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final label = messageDay == today
        ? 'Today'
        : messageDay == today.subtract(const Duration(days: 1))
            ? 'Yesterday'
            : '${months[local.month - 1]} ${local.day}, ${local.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator({bool isVoiceRecording = false}) {
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) => Opacity(
        opacity: progress,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - progress)),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 4, top: 5, bottom: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            UserAvatar(
                name: widget.peer.name,
                photoUrl: widget.peer.photoUrl,
                radius: 13),
            const SizedBox(width: 8),
            Container(
              width: isVoiceRecording ? 170 : 58,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(17),
                  topRight: Radius.circular(17),
                  bottomRight: Radius.circular(17),
                  bottomLeft: Radius.circular(5),
                ),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: isVoiceRecording
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _typingAnimation,
                          builder: (context, child) => Transform.scale(
                            scale: .85 + (_typingAnimation.value * .3),
                            child: Icon(
                              Icons.mic_rounded,
                              size: 17,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Recording voice',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 30,
                          height: 18,
                          child: AnimatedBuilder(
                            animation: _typingAnimation,
                            builder: (context, child) => Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: List.generate(4, (index) {
                                final wave = math
                                    .sin(
                                      (_typingAnimation.value * math.pi * 2) +
                                          (index * .9),
                                    )
                                    .abs();
                                return Container(
                                  width: 3,
                                  height: 4 + (wave * 12),
                                  decoration: BoxDecoration(
                                    color: scheme.primary,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      ],
                    )
                  : AnimatedBuilder(
                      animation: _typingAnimation,
                      builder: (context, _) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (index) {
                          final phase =
                              (_typingAnimation.value + index * .22) % 1.0;
                          final wave = math.sin(phase * math.pi * 2);
                          final lift = (wave + 1) / 2;
                          return Padding(
                            padding: EdgeInsets.only(right: index == 2 ? 0 : 5),
                            child: Transform.translate(
                              offset: Offset(0, -4 * lift),
                              child: Opacity(
                                opacity: .45 + .55 * lift,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: scheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadQuickEmojis() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(quickReactionEmojisPreferenceKey);
    if (!mounted) return;
    setState(() => _quickEmojis = normalizeQuickReactionEmojis(saved));
  }

  void _insertQuickEmoji(String emoji) {
    _insertEmojiText(novynCustomEmojis[emoji] ?? emoji);
  }

  void _insertEmojiText(String glyph) {
    final current = _ctrl.value;
    final selection = current.selection;
    final start = selection.isValid
        ? selection.start.clamp(0, current.text.length).toInt()
        : current.text.length;
    final end = selection.isValid
        ? selection.end.clamp(start, current.text.length).toInt()
        : current.text.length;
    final updated = current.text.replaceRange(start, end, glyph);
    _ctrl.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + glyph.length),
    );
    setState(() {});
  }

  Future<void> _showQuickEmojiPicker() async {
    final shouldRestoreKeyboard = _messageFocusNode.hasFocus;
    _messageFocusNode.unfocus();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        final media = MediaQuery.of(sheetContext);
        final pickerHeight = math.min(
          440.0,
          math.max(300.0, media.size.height - media.padding.vertical - 28),
        ).toDouble();

        return SafeArea(
          child: Container(
            height: pickerHeight,
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(26),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .18),
                  blurRadius: 24,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 10, 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.emoji_emotions_outlined,
                        color: scheme.primary,
                        size: 21,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Emoji',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close emoji picker',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: Icon(
                          Icons.keyboard_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_quickEmojis.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'NOVYN QUICK EMOJIS',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 9,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w800,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 45,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      scrollDirection: Axis.horizontal,
                      itemCount: _quickEmojis.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final emojiKey = _quickEmojis[index];
                        final glyph = novynCustomEmojis[emojiKey] ?? emojiKey;
                        return Material(
                          color: scheme.primary.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              HapticService.vibrate(
                                NovynHapticType.selection,
                                category: HapticCategory.chat,
                              );
                              _insertQuickEmoji(emojiKey);
                            },
                            child: SizedBox(
                              width: 44,
                              child: Center(
                                child: Text(
                                  glyph,
                                  style: const TextStyle(fontSize: 25),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 7),
                  Divider(
                    height: 1,
                    color: scheme.outlineVariant.withValues(alpha: .45),
                  ),
                ],
                Expanded(
                  child: EmojiPicker(
                    onEmojiSelected: (category, emoji) {
                      _insertEmojiText(emoji.emoji);
                    },
                    config: Config(
                      height: null,
                      checkPlatformCompatibility: true,
                      viewOrderConfig: const ViewOrderConfig(
                        top: EmojiPickerItem.searchBar,
                        middle: EmojiPickerItem.emojiView,
                        bottom: EmojiPickerItem.categoryBar,
                      ),
                      emojiViewConfig: EmojiViewConfig(
                        columns: 8,
                        emojiSizeMax: 27,
                        backgroundColor: scheme.surface,
                        verticalSpacing: 5,
                        horizontalSpacing: 2,
                        gridPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                      ),
                      skinToneConfig: const SkinToneConfig(
                        rememberSkinTone: true,
                      ),
                      categoryViewConfig: CategoryViewConfig(
                        backgroundColor: scheme.surface,
                        dividerColor: Colors.transparent,
                        indicatorColor: scheme.primary,
                        iconColor: scheme.onSurfaceVariant,
                        iconColorSelected: scheme.primary,
                        tabBarHeight: 46,
                      ),
                      bottomActionBarConfig: BottomActionBarConfig(
                        backgroundColor: scheme.surface,
                        buttonIconColor: scheme.onSurfaceVariant,
                      ),
                      searchViewConfig: SearchViewConfig(
                        backgroundColor: scheme.surface,
                        buttonIconColor: scheme.onSurfaceVariant,
                        hintText: 'Search emoji',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (mounted && shouldRestoreKeyboard) {
      _messageFocusNode.requestFocus();
    }
  }

  Widget _buildInputBar(SocketService socket) {
    final hasText = _ctrl.text.trim().isNotEmpty;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_uploadingAttachment)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 7, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        minHeight: 3,
                        value: _uploadProgress > 0 ? _uploadProgress : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _uploadProgress > 0
                            ? 'Uploading ${(_uploadProgress * 100).round()}%'
                            : 'Preparing upload…',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_canCancelAttachmentUpload && _uploadProgress < 1)
                  TextButton(
                    onPressed: () =>
                        setState(() => _cancelUploadRequested = true),
                    child: const Text('Cancel'),
                  )
                else if (_uploadingAttachment && _uploadProgress >= 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Finishing…',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (!_uploadingAttachment && _retryAttachment != null)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 7, 12, 2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud_upload_outlined,
                    size: 18, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Upload paused. File is ready to retry.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: 'PlusJakartaSans', fontSize: 11),
                  ),
                ),
                TextButton(
                  onPressed: _retryFailedAttachmentUpload,
                  child: const Text('Retry'),
                ),
                IconButton(
                  tooltip: 'Discard upload',
                  visualDensity: VisualDensity.compact,
                  onPressed: _discardPendingAttachmentUpload,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
          ),
        if (_isRecordingVoice)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary
                  .withValues(alpha: isDark ? .15 : .07),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: .20)),
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _typingAnimation,
                  builder: (context, child) => Transform.scale(
                    scale: .94 + (_typingAnimation.value * .12),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: .14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.mic_rounded,
                          color: theme.colorScheme.primary, size: 19),
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          AnimatedBuilder(
                            animation: _typingAnimation,
                            builder: (context, child) => Transform.scale(
                              scale: .85 + (_typingAnimation.value * .3),
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.error.withValues(
                                    alpha: .55 + (_typingAnimation.value * .45),
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.colorScheme.error.withValues(
                                        alpha: .15 +
                                            (_typingAnimation.value * .25),
                                      ),
                                      blurRadius:
                                          3 + (_typingAnimation.value * 3),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Text('Recording voice',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              )),
                          const SizedBox(width: 8),
                          Text(_formatVoiceDuration(_voiceSeconds),
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                              )),
                        ],
                      ),
                      const SizedBox(height: 7),
                      AnimatedBuilder(
                        animation: _typingAnimation,
                        builder: (context, child) => Row(
                          children: List.generate(18, (index) {
                            final wave = math
                                .sin(
                                  (_typingAnimation.value * math.pi * 2) +
                                      (index * .58),
                                )
                                .abs();
                            return Expanded(
                              child: Container(
                                height: 4 + (wave * 11),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 1.2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: .30 + (wave * .65)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Discard voice recording',
                  visualDensity: VisualDensity.compact,
                  onPressed: _cancelVoiceNote,
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 20, color: theme.colorScheme.error),
                ),
                Text('Tap stop to send',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
              ],
            ),
          ),
        // ── Reply preview bar ──────────────────────────────────────
        if (_replyingTo != null)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
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
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Text(
                        (_replyingTo!.text?.toString().trim().isNotEmpty ==
                                true)
                            ? _replyingTo!.text.toString()
                            : 'Attachment',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
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
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: Color(0xFF94A3B8)),
                  tooltip: 'Cancel reply',
                  onPressed: () {
                    setState(() => _replyingTo = null);
                    _messageFocusNode.requestFocus();
                  },
                ),
              ],
            ),
          ),

        // ── Main input row ─────────────────────────────────────────
        Container(
          // Keep the composer surface transparent so the chat wallpaper
          // continues behind it instead of painting a full-width opaque strip.
          decoration: const BoxDecoration(color: Colors.transparent),
          padding: EdgeInsets.fromLTRB(12, 10, 12,
              MediaQuery.of(context).viewInsets.bottom > 0 ? 10 : 12),
          child: Row(
            // Keep the action buttons pinned to the bottom typing baseline.
            // The multiline field grows upward without moving either button.
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Keep the attachment control pinned to the same bottom
              // baseline as the send button while the text field grows upward.
              SizedBox(
                width: 48,
                height: 50,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF191A27)
                          : theme.colorScheme.primary.withValues(alpha: .09),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary
                              .withValues(alpha: isDark ? 0.04 : 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _AttachmentButton(onSelected: _handleAttachment),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Standalone message field.
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 50),
                  decoration: BoxDecoration(
                    color: isDark
                        ? theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: .42)
                        : theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: .62),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: .55)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3F358B)
                            .withValues(alpha: isDark ? 0.0 : 0.06),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Text field
                      Expanded(
                        child: TextField(
                          controller: _ctrl,
                          focusNode: _messageFocusNode,
                          maxLines: 4,
                          minLines: 1,
                          textInputAction:
                              context.read<SettingsService>().chatEnterToSend
                                  ? TextInputAction.send
                                  : TextInputAction.newline,
                          cursorColor: Theme.of(context).colorScheme.primary,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize:
                                15 * context.watch<SettingsService>().fontSize,
                            color: theme.colorScheme.onSurface,
                          ),
                          onChanged: (v) {
                            setState(() {});
                            if (v.isNotEmpty) {
                              socket.startTyping(widget.peer.uid,
                                  isGroup: widget.isGroup);
                            } else {
                              socket.stopTyping(widget.peer.uid,
                                  isGroup: widget.isGroup);
                            }
                          },
                          onSubmitted: (_) {
                            if (context.read<SettingsService>().chatEnterToSend)
                              _send();
                          },
                          decoration: InputDecoration(
                            hintText: 'Message...',
                            hintStyle: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 14),
                            suffixIcon: IconButton(
                              tooltip: 'Add emoji',
                              visualDensity: VisualDensity.compact,
                              onPressed: _showQuickEmojiPicker,
                              icon: Icon(Icons.emoji_emotions_outlined,
                                  size: 19,
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
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
                onTap: _uploadingAttachment
                    ? null
                    : hasText
                        ? _send
                        : _isRecordingVoice
                            ? _stopVoiceNote
                            : _startVoiceNote,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: hasText
                          ? [
                              Theme.of(context).colorScheme.primary,
                              Color.lerp(Theme.of(context).colorScheme.primary,
                                  Colors.black, 0.14)!
                            ]
                          : [
                              Theme.of(context).colorScheme.primary,
                              Color.lerp(Theme.of(context).colorScheme.primary,
                                  Colors.black, 0.10)!
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: _isRecordingVoice ? 0.28 : 0.20),
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
                      hasText
                          ? Icons.send_rounded
                          : (_isRecordingVoice
                              ? Icons.stop_rounded
                              : Icons.mic_rounded),
                      key: ValueKey('$hasText-$_isRecordingVoice'),
                      color: Colors.white,
                      size: 21,
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
    if (_retryAttachment != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Retry or discard the paused upload first.'),
        ),
      );
      return;
    }
    if (type.toLowerCase() == 'gifs' || type.toLowerCase() == 'stickers') {
      await _showGifPicker(
          type: type.toLowerCase() == 'stickers' ? 'stickers' : 'gifs');
      return;
    }
    if (type.toLowerCase() == 'poll') {
      await _showCreatePollDialog();
      return;
    }
    if (type.toLowerCase() == 'riddle') {
      await _showCreateRiddleDialog();
      return;
    }
    if (type.toLowerCase() == 'games') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Open the Games tab to choose a game and start a match.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    try {
      Uint8List? bytes;
      String filename = 'attachment';
      String mime = 'application/octet-stream';
      if (type.toLowerCase().contains('photo') ||
          type.toLowerCase().contains('image') ||
          type.toLowerCase().contains('video')) {
        final picked = await _imagePicker.pickMedia();
        if (picked == null) return;
        bytes = await picked.readAsBytes();
        filename = picked.name;
        mime = _mimeForFile(filename);
        if (mime == 'application/octet-stream') {
          mime = 'image/jpeg';
        }
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: type.toLowerCase() == 'sound' ? FileType.audio : FileType.any,
          withData: true,
        );
        if (result == null || result.files.isEmpty) return;
        final file = result.files.single;
        bytes = file.bytes;
        filename = file.name;
        mime = _mimeForFile(filename);
      }
      if (bytes == null || bytes.isEmpty)
        throw StateError('Could not read the selected file.');
      if (bytes.length > 15 * 1024 * 1024) {
        throw StateError('Choose a file smaller than 15 MB.');
      }
      if (!mounted) return;
      final selectedBytes = bytes;

      // Preview the selected item before uploading so an accidental large
      // attachment can be cancelled without consuming data or storage.
      final isImage = mime.startsWith('image/');
      final isVideo = mime.startsWith('video/');
      final shouldSend = await showDialog<bool>(
        context: context,
        builder: (previewContext) {
          final scheme = Theme.of(previewContext).colorScheme;
          final sizeLabel = selectedBytes.length < 1024 * 1024
              ? '${(selectedBytes.length / 1024).toStringAsFixed(0)} KB'
              : '${(selectedBytes.length / (1024 * 1024)).toStringAsFixed(1)} MB';
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: const Text('Review attachment',
                style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w800)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(
                      selectedBytes,
                      height: 190,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 120,
                        alignment: Alignment.center,
                        color: scheme.surfaceContainerHighest,
                        child:
                            const Icon(Icons.broken_image_outlined, size: 36),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 112,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isVideo
                          ? Icons.play_circle_outline_rounded
                          : mime.startsWith('audio/')
                              ? Icons.headphones_rounded
                              : Icons.insert_drive_file_rounded,
                      size: 46,
                      color: scheme.primary,
                    ),
                  ),
                const SizedBox(height: 12),
                Text(filename,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('$sizeLabel · ${mime.toUpperCase()}',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(previewContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(previewContext, true),
                child: const Text('Send'),
              ),
            ],
          );
        },
      );
      if (shouldSend != true || !mounted) return;
      setState(() {
        _uploadingAttachment = true;
        _uploadProgress = 0;
        _cancelUploadRequested = false;
        _canCancelAttachmentUpload = true;
      });

      // Apply the selected Data & Storage photo-quality preference to actual
      // image bytes before upload. Non-image attachments are never recompressed.
      if (mime.startsWith('image/') &&
          !filename.toLowerCase().endsWith('.gif')) {
        final quality = context.read<SettingsService>().photoQuality;
        final jpegQuality = quality == 'low'
            ? 55
            : quality == 'medium'
                ? 75
                : 90;
        final compressed = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: quality == 'low' ? 1280 : 1920,
          minHeight: quality == 'low' ? 1280 : 1920,
          quality: jpegQuality,
          format: CompressFormat.jpeg,
        );
        if (compressed.isNotEmpty) {
          bytes = compressed;
          final dot = filename.lastIndexOf('.');
          final stem = dot > 0 ? filename.substring(0, dot) : filename;
          filename = '$stem.jpg';
          mime = 'image/jpeg';
        }
      }
      final attachmentMime = mime;
      final originalSize = bytes.length;
      final recipient = widget.peer.uid.isNotEmpty
          ? widget.peer.uid
          : widget.peer.username;
      var uploadBytes = bytes;
      final encryptionMetadata = <String, dynamic>{};
      if (!widget.isGroup) {
        final prepared = await context.read<SocketService>()
            .prepareEncryptedAttachment(bytes, recipient);
        uploadBytes = prepared['bytes'] as Uint8List;
        encryptionMetadata.addAll(
          Map<String, dynamic>.from(prepared['metadata'] as Map),
        );
      }
      final kind = attachmentMime.startsWith('image/')
          ? 'image'
          : attachmentMime.startsWith('video/')
              ? 'video'
              : attachmentMime.startsWith('audio/')
                  ? 'audio'
                  : 'file';
      final retryUploadBytes = Uint8List.fromList(uploadBytes);
      final retryFileName = filename;
      final retryMime = attachmentMime;
      final retryMetadata = Map<String, dynamic>.from(encryptionMetadata);
      final retryReplyId = _replyingTo?.id?.toString();
      final retryReplyText = _replyingTo?.text?.toString();
      final retryReplySender =
          _replyingTo?.isFromMe == true ? 'You' : widget.peer.name;
      await _persistPendingAttachmentUpload(
        bytes: retryUploadBytes,
        filename: retryFileName,
        mime: retryMime,
        size: originalSize,
        recipient: recipient,
        kind: kind,
        encryptionMetadata: retryMetadata,
        replyToId: retryReplyId,
        replyToText: retryReplyText,
        replyToSender: retryReplySender,
      );
      _retryAttachment = () => _uploadAndSendPreparedAttachment(
            retryUploadBytes,
            retryFileName,
            retryMime,
            originalSize,
            recipient,
            kind,
            retryMetadata,
            replyToId: retryReplyId,
            replyToText: retryReplyText,
            replyToSender: retryReplySender,
          );
      await _retryAttachment!();
      _retryAttachment = null;
      if (mounted) setState(() => _replyingTo = null);
    } catch (error) {
      if (mounted) {
        if (error is UploadCancelledException) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Upload paused. You can retry it here.')),
          );
        } else NovynAlert.show(
            context,
            error is StateError
                ? error.message.toString()
                : 'Could not attach this file.',
            isError: true,
            title: 'Attachment failed',
            icon: Icons.attach_file_rounded);
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingAttachment = false;
          _uploadProgress = 0;
          _canCancelAttachmentUpload = false;
        });
      }
    }
  }

  void _reportUploadProgress(double progress) {
    if (!mounted) return;
    final next = progress.clamp(0.0, 1.0).toDouble();
    if ((_uploadProgress * 100).floor() == (next * 100).floor()) return;
    setState(() => _uploadProgress = next);
  }

  Future<void> _uploadAndSendPreparedAttachment(
    Uint8List bytes,
    String filename,
    String mime,
    int size,
    String recipient,
    String kind,
    Map<String, dynamic> encryptionMetadata, {
    String? displayName,
    Map<String, dynamic> attachmentExtra = const <String, dynamic>{},
    bool voiceEndpoint = false,
    String? replyToId,
    String? replyToText,
    String? replyToSender,
  }) async {
    final url = voiceEndpoint
        ? await ApiService.uploadVoice(
            bytes,
            filename,
            mime,
            onProgress: _reportUploadProgress,
            shouldCancel: () => _cancelUploadRequested,
          )
        : await ApiService.uploadMedia(
            bytes,
            filename,
            mime,
            onProgress: _reportUploadProgress,
            shouldCancel: () => _cancelUploadRequested,
          );
    if (_cancelUploadRequested) throw const UploadCancelledException();
    if (!mounted) return;
    if (url == null || url.isEmpty) {
      throw StateError('Upload failed. Please try again.');
    }
    await context.read<SocketService>().sendMessage(
          '',
          recipient,
          attachment: {
            'url': url,
            'name': displayName ?? filename,
            'mime': mime,
            'size': size,
            'kind': kind,
            ...encryptionMetadata,
            ...attachmentExtra,
          },
          replyToId: replyToId,
          replyToText: replyToText,
          replyToSender: replyToSender,
          isGroup: widget.isGroup,
        );
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingUploadKey);
    final savedPath = _pendingUploadFilePath;
    _pendingUploadFilePath = null;
    if (savedPath != null) {
      try {
        await File(savedPath).delete();
      } catch (_) {}
    }
    if (mounted) setState(() => _replyingTo = null);
  }

  Future<void> _retryFailedAttachmentUpload() async {
    final retry = _retryAttachment;
    if (retry == null || _uploadingAttachment) return;
    setState(() {
      _uploadingAttachment = true;
      _uploadProgress = 0;
      _cancelUploadRequested = false;
      _canCancelAttachmentUpload = true;
    });
    try {
      await retry();
      _retryAttachment = null;
    } catch (error) {
      if (mounted && error is! UploadCancelledException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload retry failed: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingAttachment = false;
          _uploadProgress = 0;
          _canCancelAttachmentUpload = false;
        });
      }
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
            if (chat.peerUid.toLowerCase() == widget.peer.uid.toLowerCase())
              return false;
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(
                        child: Text('Forward message',
                            style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 17,
                                fontWeight: FontWeight.w700))),
                    IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: Icon(Icons.close_rounded)),
                  ],
                ),
                TextField(
                  controller: search,
                  onChanged: (_) => refresh(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search friends',
                    prefixIcon: Icon(Icons.search_rounded),
                    filled: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
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
                              title: Text(chat.peer.name,
                                  style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text('@${chat.peer.username}',
                                  style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 12)),
                              trailing: Icon(Icons.send_rounded, size: 18),
                              onTap: () {
                                socket.forwardMessage(
                                  message,
                                  chat.peerUid,
                                  isGroup: chat.isGroup,
                                );
                                Navigator.pop(sheetContext);
                                NovynAlert.show(this.context,
                                    'Forwarded to ${chat.peer.name}.',
                                    title: 'Message forwarded',
                                    icon: Icons.forward_rounded,
                                    tone: NovynAlertTone.success);
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


  Widget _composerInput({
    required TextEditingController controller,
    required String hint,
    required int maxLength,
    required ValueChanged<String> onChanged,
    bool multiline = false,
    bool obscureText = false,
    bool showCounter = true,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final border = scheme.primary.withValues(alpha: .20);
    return Container(
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: border, width: 1.2),
      ),
      padding: const EdgeInsets.fromLTRB(15, 3, 14, 8),
      child: Column(
        children: [
          TextField(
            controller: controller,
            maxLength: maxLength,
            minLines: multiline ? 2 : 1,
            maxLines: multiline ? 3 : 1,
            obscureText: obscureText,
            onChanged: onChanged,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 14,
              color: scheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: scheme.onSurfaceVariant.withValues(alpha: .85),
                fontFamily: 'PlusJakartaSans',
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(vertical: 11),
            ),
          ),
          if (showCounter)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${controller.text.length}/$maxLength',
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showCreateRiddleDialog() async {
    if (widget.isGroup) {
      NovynAlert.show(
        context,
        'Riddle Lock is currently available in direct chats only.',
        isError: true,
        title: 'Direct chats only',
        icon: Icons.lock_rounded,
        tone: NovynAlertTone.warning,
      );
      return;
    }

    final secret = TextEditingController();
    final question = TextEditingController();
    final answer = TextEditingController();
    final hint = TextEditingController();
    var maxTries = 3;
    var sending = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, refresh) {
            final scheme = Theme.of(dialogContext).colorScheme;
            final dark = Theme.of(dialogContext).brightness == Brightness.dark;
            final ready = secret.text.trim().isNotEmpty &&
                question.text.trim().isNotEmpty &&
                answer.text.trim().isNotEmpty;

            return Dialog(
              backgroundColor: scheme.surface,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: .28),
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.lock_outline_rounded,
                              color: scheme.primary,
                              size: 23,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Lock a message',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.35,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: Icon(Icons.close_rounded, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _composerInput(
                        controller: secret,
                        hint: 'Secret message',
                        maxLength: 250,
                        multiline: true,
                        onChanged: (_) => refresh(() {}),
                      ),
                      const SizedBox(height: 10),
                      _composerInput(
                        controller: question,
                        hint: 'Riddle question',
                        maxLength: 160,
                        onChanged: (_) => refresh(() {}),
                      ),
                      const SizedBox(height: 10),
                      _composerInput(
                        controller: answer,
                        hint: 'Answer',
                        maxLength: 80,
                        obscureText: true,
                        onChanged: (_) => refresh(() {}),
                      ),
                      const SizedBox(height: 10),
                      _composerInput(
                        controller: hint,
                        hint: 'Hint (optional)',
                        maxLength: 160,
                        onChanged: (_) => refresh(() {}),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Attempts',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          ChoiceChip(
                            label: const Text('3'),
                            selected: maxTries == 3,
                            onSelected: (_) => refresh(() => maxTries = 3),
                            selectedColor: scheme.primary,
                            backgroundColor: scheme.surfaceContainerLow,
                            checkmarkColor: scheme.onPrimary,
                            labelStyle: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontWeight: FontWeight.w800,
                              color: maxTries == 3 ? scheme.onPrimary : scheme.onSurface,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                              side: BorderSide(
                                color: maxTries == 3 ? scheme.primary : scheme.outlineVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('5'),
                            selected: maxTries == 5,
                            onSelected: (_) => refresh(() => maxTries = 5),
                            selectedColor: scheme.primary,
                            backgroundColor: scheme.surfaceContainerLow,
                            checkmarkColor: scheme.onPrimary,
                            labelStyle: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontWeight: FontWeight.w800,
                              color: maxTries == 5 ? scheme.onPrimary : scheme.onSurface,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                              side: BorderSide(
                                color: maxTries == 5 ? scheme.primary : scheme.outlineVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 13),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: dark ? .10 : .055),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 18,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'For fun only. Don’t use this for passwords or private information.',
                                style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 11.5,
                                  height: 1.35,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Spacer(),
                          TextButton(
                            onPressed: sending ? null : () => Navigator.pop(dialogContext),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontWeight: FontWeight.w800,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: scheme.primary,
                              foregroundColor: scheme.onPrimary,
                              minimumSize: const Size(0, 50),
                              padding: const EdgeInsets.symmetric(horizontal: 19),
                              shape: const StadiumBorder(),
                              elevation: 2,
                            ),
                            onPressed: !ready || sending
                                ? null
                                : () async {
                                    refresh(() => sending = true);
                                    try {
                                      final result = await context.read<SocketService>().sendRiddle(
                                        peerUsername: widget.peer.uid.isNotEmpty
                                            ? widget.peer.uid
                                            : widget.peer.username,
                                        secret: secret.text.trim(),
                                        question: question.text.trim(),
                                        answer: answer.text.trim(),
                                        hint: hint.text.trim().isEmpty ? null : hint.text.trim(),
                                        maxTries: maxTries,
                                        isGroup: widget.isGroup,
                                      );
                                      if (!mounted || !dialogContext.mounted) return;
                                      if (result['ok'] == true) {
                                        Navigator.pop(dialogContext);
                                      } else {
                                        refresh(() => sending = false);
                                        NovynAlert.show(
                                          this.context,
                                          result['message']?.toString() ?? 'Could not send riddle.',
                                          isError: true,
                                          title: 'Could not send riddle',
                                          icon: Icons.lock_rounded,
                                        );
                                      }
                                    } catch (error) {
                                      if (!dialogContext.mounted) return;
                                      refresh(() => sending = false);
                                      NovynAlert.show(
                                        this.context,
                                        error.toString().replaceFirst('Bad state: ', ''),
                                        isError: true,
                                        title: 'Could not send riddle',
                                        icon: Icons.lock_rounded,
                                      );
                                    }
                                  },
                            icon: sending
                                ? const SizedBox(
                                    width: 17,
                                    height: 17,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.lock_rounded, size: 17),
                            label: Text(sending ? 'Sending…' : 'Lock & send'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    } finally {
      secret.dispose();
      question.dispose();
      answer.dispose();
      hint.dispose();
    }
  }

  Future<void> _showCreatePollDialog() async {
    final question = TextEditingController();
    final options = <TextEditingController>[
      TextEditingController(),
      TextEditingController(),
    ];
    var sending = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, refresh) {
            final scheme = Theme.of(dialogContext).colorScheme;
            final cleanQuestion = question.text.trim();
            final cleanOptions = options
                .map((item) => item.text.trim())
                .where((item) => item.isNotEmpty)
                .toList();
            final ready = cleanQuestion.isNotEmpty && cleanOptions.length >= 2;

            return Dialog(
              backgroundColor: scheme.surface,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .28)),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.poll_rounded, color: scheme.primary, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Create a poll',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.35,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: Icon(Icons.close_rounded, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _composerInput(
                        controller: question,
                        hint: 'Question',
                        maxLength: 500,
                        onChanged: (_) => refresh(() {}),
                      ),
                      const SizedBox(height: 10),
                      ...List.generate(options.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: Row(
                            children: [
                              Expanded(
                                child: _composerInput(
                                  controller: options[index],
                                  hint: 'Option ${index + 1}',
                                  maxLength: 200,
                                  showCounter: false,
                                  onChanged: (_) => refresh(() {}),
                                ),
                              ),
                              if (options.length > 2) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  tooltip: 'Remove option',
                                  onPressed: sending
                                      ? null
                                      : () => refresh(() {
                                            final removed = options.removeAt(index);
                                            removed.dispose();
                                          }),
                                  icon: Icon(Icons.remove_circle_outline_rounded, color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                      if (options.length < 8)
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: sending
                                ? null
                                : () => refresh(() => options.add(TextEditingController())),
                            icon: Icon(Icons.add_rounded, color: scheme.primary, size: 20),
                            label: Text(
                              'Add option',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontWeight: FontWeight.w800,
                                color: scheme.primary,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: scheme.primary.withValues(alpha: .35),
                                width: 1.3,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Spacer(),
                          TextButton(
                            onPressed: sending ? null : () => Navigator.pop(dialogContext),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontWeight: FontWeight.w800,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: scheme.primary,
                              foregroundColor: scheme.onPrimary,
                              minimumSize: const Size(0, 50),
                              padding: const EdgeInsets.symmetric(horizontal: 19),
                              shape: const StadiumBorder(),
                              elevation: 2,
                            ),
                            onPressed: !ready || sending
                                ? null
                                : () {
                                    final finalQuestion = question.text.trim();
                                    final finalOptions = options
                                        .map((item) => item.text.trim())
                                        .where((item) => item.isNotEmpty)
                                        .toList();
                                    if (finalOptions.toSet().length != finalOptions.length) {
                                      NovynAlert.show(
                                        dialogContext,
                                        'Poll options must be unique.',
                                        isError: true,
                                        title: 'Duplicate options',
                                        icon: Icons.poll_rounded,
                                      );
                                      return;
                                    }
                                    try {
                                      refresh(() => sending = true);
                                      context.read<SocketService>().createPoll(
                                        finalQuestion,
                                        finalOptions,
                                        widget.peer.uid.isNotEmpty
                                            ? widget.peer.uid
                                            : widget.peer.username,
                                        isGroup: widget.isGroup,
                                      );
                                      Navigator.pop(dialogContext);
                                    } catch (error) {
                                      refresh(() => sending = false);
                                      NovynAlert.show(
                                        dialogContext,
                                        error.toString().replaceFirst('Bad state: ', ''),
                                        isError: true,
                                        title: 'Could not send poll',
                                        icon: Icons.poll_rounded,
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.send_rounded, size: 17),
                            label: const Text('Send poll'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    } finally {
      question.dispose();
      for (final option in options) {
        option.dispose();
      }
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
                widget.peer.uid.isNotEmpty
                    ? widget.peer.uid
                    : widget.peer.username,
                attachment: {
                  'url': url,
                  'name': item['title']?.toString().isNotEmpty == true
                      ? item['title'].toString()
                      : 'GIF',
                  'mime': 'image/gif',
                  'kind': 'image',
                },
                replyToId: _replyingTo?.id?.toString(),
                replyToText: _replyingTo?.text?.toString(),
                replyToSender:
                    _replyingTo?.isFromMe == true ? 'You' : widget.peer.name,
                isGroup: widget.isGroup,
              );
          if (mounted) setState(() => _replyingTo = null);
        },
      ),
    );
    search.dispose();
  }

  Future<void> _startVoiceNote() async {
    if (_isRecordingVoice || _uploadingAttachment) return;
    if (_retryAttachment != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Retry or discard the paused upload first.'),
        ),
      );
      return;
    }
    try {
      final allowed = await _voiceRecorder.hasPermission();
      if (!allowed) {
        if (mounted) {
          NovynAlert.show(context,
              'Microphone permission is required to record voice notes.',
              isError: true,
              title: 'Microphone permission needed',
              icon: Icons.mic_off_rounded,
              tone: NovynAlertTone.warning);
        }
        return;
      }
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/novyn_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
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
      HapticService.vibrate(NovynHapticType.medium,
          category: HapticCategory.chat);
      _socketService.startVoiceActivity(
        widget.peer.uid.isNotEmpty ? widget.peer.uid : widget.peer.username,
        isGroup: widget.isGroup,
      );
      setState(() {
        _isRecordingVoice = true;
        _voiceSeconds = 0;
        _voiceRecordingPath = path;
      });
      _syncTypingAnimation();
      _voiceTimer?.cancel();
      _voiceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _isRecordingVoice) {
          setState(() => _voiceSeconds++);
        }
      });
    } catch (error) {
      if (mounted) {
        NovynAlert.show(context, 'Could not start recording: $error',
            isError: true,
            title: 'Recording failed',
            icon: Icons.mic_off_rounded);
      }
    }
  }

  Future<void> _stopVoiceNote() async {
    if (!_isRecordingVoice) return;
    _voiceTimer?.cancel();
    _voiceTimer = null;
    final duration = _voiceSeconds < 1 ? 1 : _voiceSeconds;
    final path = _voiceRecordingPath;
    setState(() {
      _isRecordingVoice = false;
      _uploadingAttachment = true;
      _uploadProgress = 0;
      _cancelUploadRequested = false;
      _canCancelAttachmentUpload = true;
    });
    _socketService.stopVoiceActivity();
    _syncTypingAnimation();
    try {
      final recordedPath = await _voiceRecorder.stop();
      final filePath = recordedPath ?? path;
      if (filePath == null) throw StateError('Voice recording was not saved.');
      final file = File(filePath);
      if (!await file.exists())
        throw StateError('Voice recording file was not found.');
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw StateError('Voice recording is empty.');
      if (widget.isGroup && bytes.length > 6 * 1024 * 1024) {
        throw StateError('Group voice notes must be smaller than 6 MB.');
      }
      final recipient = widget.peer.uid.isNotEmpty
          ? widget.peer.uid
          : widget.peer.username;
      var uploadBytes = Uint8List.fromList(bytes);
      final encryptionMetadata = <String, dynamic>{};
      final voiceEndpoint = widget.isGroup;
      if (!widget.isGroup) {
        final prepared = await context.read<SocketService>()
            .prepareEncryptedAttachment(bytes, recipient);
        uploadBytes = prepared['bytes'] as Uint8List;
        encryptionMetadata.addAll(
          Map<String, dynamic>.from(prepared['metadata'] as Map),
        );
      }
      final retryBytes = Uint8List.fromList(uploadBytes);
      final retryMetadata = Map<String, dynamic>.from(encryptionMetadata);
      final retryReplyId = _replyingTo?.id?.toString();
      final retryReplyText = _replyingTo?.text?.toString();
      final retryReplySender =
          _replyingTo?.isFromMe == true ? 'You' : widget.peer.name;
      await _persistPendingAttachmentUpload(
        bytes: retryBytes,
        filename: 'voice_note.m4a',
        mime: 'audio/mp4',
        size: bytes.length,
        recipient: recipient,
        kind: 'audio',
        encryptionMetadata: retryMetadata,
        displayName: 'Voice message',
        attachmentExtra: {'duration': duration},
        voiceEndpoint: voiceEndpoint,
        replyToId: retryReplyId,
        replyToText: retryReplyText,
        replyToSender: retryReplySender,
      );
      await file.delete();
      _retryAttachment = () => _uploadAndSendPreparedAttachment(
            retryBytes,
            'voice_note.m4a',
            'audio/mp4',
            bytes.length,
            recipient,
            'audio',
            retryMetadata,
            displayName: 'Voice message',
            attachmentExtra: {'duration': duration},
            voiceEndpoint: voiceEndpoint,
            replyToId: retryReplyId,
            replyToText: retryReplyText,
            replyToSender: retryReplySender,
          );
      await _retryAttachment!();
      _retryAttachment = null;
      if (mounted) {
        setState(() => _replyingTo = null);
        _scrollToBottom(force: true);
      }
    } catch (error) {
      if (mounted) {
        if (error is UploadCancelledException) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Voice upload paused. Tap Retry to continue.')),
          );
        } else NovynAlert.show(
            context,
            error is StateError
                ? error.message.toString()
                : 'Could not send voice note.',
            isError: true,
            title: 'Voice message not sent',
            icon: Icons.mic_off_rounded);
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingAttachment = false;
          _uploadProgress = 0;
          _voiceRecordingPath = null;
        });
      }
    }
  }

  Future<void> _cancelVoiceNote() async {
    if (!_isRecordingVoice) return;
    _voiceTimer?.cancel();
    _voiceTimer = null;
    _socketService.stopVoiceActivity();
    final path = _voiceRecordingPath;
    try {
      await _voiceRecorder.stop();
    } catch (_) {
      // Recorder may already have stopped during a lifecycle transition.
    }
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // Temporary-file cleanup must not block returning to the composer.
      }
    }
    if (!mounted) return;
    HapticService.vibrate(NovynHapticType.light, category: HapticCategory.chat);
    setState(() {
      _isRecordingVoice = false;
      _voiceSeconds = 0;
      _voiceRecordingPath = null;
    });
    _syncTypingAnimation();
  }

  String _formatVoiceDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString();
    final remaining = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remaining';
  }

  void _startCall(String type) {
    HapticService.vibrate(NovynHapticType.medium,
        category: HapticCategory.chat);
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

  Future<void> _showPinnedMessages() async {
    final pinned = context
        .read<SocketService>()
        .messages
        .where((message) =>
            message.pinnedAt != null && message.pinnedAt!.isNotEmpty)
        .toList()
        .reversed
        .toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, refreshPinned) => SafeArea(
          child: Container(
            height: MediaQuery.of(sheetContext).size.height * .62,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
            decoration: BoxDecoration(
              color: Theme.of(sheetContext).colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: .4),
                        borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 14),
                Row(children: [
                  const Expanded(
                      child: Text('Pinned messages',
                          style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 17,
                              fontWeight: FontWeight.w700))),
                  IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded)),
                ]),
                Expanded(
                  child: pinned.isEmpty
                      ? const Center(child: Text('No pinned messages yet'))
                      : ListView.separated(
                          itemCount: pinned.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final message = pinned[index];
                            final preview = message.text.trim().isNotEmpty
                                ? message.text
                                : (message.attachment?['name']?.toString() ??
                                    'Attachment');
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: .10),
                                child: Icon(Icons.push_pin_rounded,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 19),
                              ),
                              title: Text(preview,
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                '${message.isFromMe ? 'You' : (widget.isGroup ? message.senderId : widget.peer.name)} · ${message.createdAt.toLocal().toString().substring(0, 16)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                tooltip: 'Unpin message',
                                icon: const Icon(Icons.push_pin_outlined),
                                onPressed: () {
                                  try {
                                    context.read<SocketService>().unpinMessage(
                                          message.id,
                                          widget.peer.uid.isNotEmpty
                                              ? widget.peer.uid
                                              : widget.peer.username,
                                          isGroup: widget.isGroup,
                                        );
                                    refreshPinned(() => pinned.removeAt(index));
                                  } catch (error) {
                                    NovynAlert.show(
                                        context,
                                        error is StateError
                                            ? error.message
                                            : 'Could not unpin message.',
                                        isError: true,
                                        title: 'Could not unpin message',
                                        icon: Icons.push_pin_rounded);
                                  }
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _downloadAttachment(
    BuildContext context,
    String url,
    String name, {
    Message? message,
    Map? attachment,
  }) async {
    try {
      final file = message != null && attachment != null
          ? File(await _ChatAttachmentLoader.prepareFile(context, attachment, message))
          : await ApiService.downloadMedia(url, name);
      final mime = attachment?['mime']?.toString() ?? _mimeForFile(name);
      final kind = mime.startsWith('image/')
          ? 'image'
          : mime.startsWith('video/')
              ? 'video'
              : 'file';
      final saved = await MediaStorageService.exportToDevice(file, kind);
      if (!context.mounted || !saved) return;
      NovynAlert.show(
        context,
        kind == 'image' || kind == 'video'
            ? 'Saved to your Gallery and Novyn Downloads.'
            : 'Saved using the system Files picker.',
        title: 'Saved',
        icon: Icons.download_done_rounded,
        tone: NovynAlertTone.success,
      );
    } catch (error) {
      if (!context.mounted) return;
      NovynAlert.show(
        context, 'Download failed: $error',
        isError: true, title: 'Download failed', icon: Icons.download_rounded,
      );
    }
  }

  Future<void> _showSharedMedia() async {
    final messages = context
        .read<SocketService>()
        .messages
        .where((message) => message.attachment is Map)
        .toList()
        .reversed
        .toList();
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
          return attachment['kind'] == 'image' ||
              attachment['kind'] == 'video' ||
              mime.startsWith('image/') ||
              mime.startsWith('video/');
        }).toList();
        final docs = messages.where((message) {
          final attachment = message.attachment as Map;
          final mime = attachment['mime']?.toString().toLowerCase() ?? '';
          return attachment['kind'] == 'file' &&
              !mime.startsWith('audio/') &&
              !mime.startsWith('image/') &&
              !mime.startsWith('video/') &&
              (attachment['name']?.toString() ?? '')
                  .toLowerCase()
                  .contains(searchQuery);
        }).toList();
        final voice = messages.where((message) {
          final attachment = message.attachment as Map;
          final mime = attachment['mime']?.toString().toLowerCase() ?? '';
          return attachment['kind'] == 'audio' || mime.startsWith('audio/');
        }).toList();
        final activeItems = activeTab == 0
            ? media
            : activeTab == 1
                ? docs
                : voice;
        return Container(
          height: MediaQuery.of(context).size.height * 0.76,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 14),
            Row(children: [
              const Expanded(
                  child: Text('Shared media & files',
                      style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 17,
                          fontWeight: FontWeight.w700))),
              IconButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: Icon(Icons.close_rounded))
            ]),
            Row(children: [
              _sharedMediaTab('Media', media.length, 0, activeTab,
                  (v) => refresh(() => activeTab = v)),
              const SizedBox(width: 7),
              _sharedMediaTab('Documents', docs.length, 1, activeTab,
                  (v) => refresh(() => activeTab = v)),
              const SizedBox(width: 7),
              _sharedMediaTab('Voice', voice.length, 2, activeTab,
                  (v) => refresh(() => activeTab = v)),
            ]),
            if (activeTab == 1) ...[
              const SizedBox(height: 10),
              TextField(
                  onChanged: (value) =>
                      refresh(() => searchQuery = value.toLowerCase()),
                  decoration: InputDecoration(
                      hintText: 'Search files',
                      prefixIcon: Icon(Icons.search_rounded),
                      filled: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none))),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: activeItems.isEmpty
                  ? const Center(child: Text('Nothing shared here yet'))
                  : activeTab == 0
                      ? GridView.builder(
                          itemCount: activeItems.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8),
                          itemBuilder: (context, index) {
                            final message = activeItems[index];
                            final attachment = message.attachment as Map;
                            final url = attachment['url']?.toString() ?? '';
                            final mime = attachment['mime']?.toString().toLowerCase() ?? '';
                            final encrypted = attachment['encrypted'] == true;
                            final imageFuture = encrypted && mime.startsWith('image/')
                                ? _ChatAttachmentLoader.loadBytes(context, attachment, message)
                                : null;
                            return InkWell(
                              onTap: () async {
                                if (encrypted) {
                                  if (mime.startsWith('image/')) {
                                    try {
                                      final bytes = await _ChatAttachmentLoader.loadBytes(context, attachment, message);
                                      if (!context.mounted) return;
                                      showDialog<void>(
                                        context: context,
                                        builder: (_) => Dialog(
                                          backgroundColor: Colors.transparent,
                                          child: InteractiveViewer(child: Image.memory(bytes)),
                                        ),
                                      );
                                    } catch (error) {
                                      if (context.mounted) NovynToast.show(context, 'Could not decrypt this image: $error', isError: true);
                                    }
                                  } else {
                                    await _downloadAttachment(context, url, attachment['name']?.toString() ?? 'Attachment', message: message, attachment: attachment);
                                  }
                                  return;
                                }
                                if (mime.startsWith('image/')) {
                                  showDialog<void>(
                                    context: context,
                                    builder: (_) => Dialog(
                                      backgroundColor: Colors.transparent,
                                      child: InteractiveViewer(
                                        child: Image.network(url, headers: ApiService.imageHeaders),
                                      ),
                                    ),
                                  );
                                } else {
                                  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                }
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: mime.startsWith('image/')
                                    ? encrypted
                                        ? FutureBuilder<Uint8List>(
                                            future: imageFuture,
                                            builder: (_, snapshot) => snapshot.hasData
                                                ? Image.memory(snapshot.data!, fit: BoxFit.cover)
                                                : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                          )
                                        : Image.network(url, headers: ApiService.imageHeaders, fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined))
                                    : Container(
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                        child: const Center(child: Icon(Icons.play_circle_outline_rounded, size: 30)),
                                      ),
                              ),
                            );
                          },
                        )
                      : ListView.separated(
                          itemCount: activeItems.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final message = activeItems[index];
                            final attachment = message.attachment as Map;
                            final url = attachment['url']?.toString() ?? '';
                            final name = attachment['name']?.toString() ?? 'Attachment';
                            final isVoice = activeTab == 2;
                            return ListTile(
                              leading: Icon(isVoice ? Icons.mic_none_rounded : Icons.insert_drive_file_outlined),
                              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(isVoice ? 'Voice message' : name.split('.').last.toUpperCase()),
                              trailing: const Icon(Icons.download_rounded, size: 18),
                              onTap: () {
                                if (attachment['encrypted'] == true) {
                                  _downloadAttachment(context, url, name, message: message, attachment: attachment);
                                } else {
                                  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                }
                              },
                            );
                          },
                        ),
            ),
          ]),
        );
      }),
    );
  }

  Widget _sharedMediaTab(String label, int count, int index, int active,
      ValueChanged<int> onSelected) {
    final selected = active == index;
    return Expanded(
        child: OutlinedButton(
            onPressed: () => onSelected(index),
            style: OutlinedButton.styleFrom(
                backgroundColor: selected
                    ? Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.08)
                    : null,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 10)),
            child: Text('$label $count',
                style:
                    TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11))));
  }

  BoxDecoration _wallpaperDecoration(String wallpaper) {
    final value = wallpaper.trim();
    final defaultBg = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0B0B17)
        : const Color(0xFFF7F6FF);
    if (value.isEmpty) return BoxDecoration(color: defaultBg);
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return BoxDecoration(
          image: DecorationImage(
              image: NetworkImage(value), fit: BoxFit.cover, opacity: 0.13));
    }
    if (value.startsWith('#') && value.length == 7) {
      final color = Color(int.parse('FF' + value.substring(1), radix: 16));
      return BoxDecoration(color: color);
    }
    return BoxDecoration(color: defaultBg);
  }

  Future<void> _showWallpaperPicker() async {
    const presets = <Map<String, String>>[
      {'name': 'Default', 'value': ''},
      {'name': 'Lavender', 'value': '#EDE9FE'},
      {'name': 'Blush', 'value': '#FCE7F3'},
      {'name': 'Cloud', 'value': '#F1F5F9'},
      {'name': 'Mint', 'value': '#D1FAE5'},
      {'name': 'Peach', 'value': '#FFEDD5'},
      {'name': 'Midnight', 'value': '#111827'},
      {'name': 'Amethyst', 'value': '#241B3D'},
      {'name': 'Deep slate', 'value': '#0F172A'},
      {'name': 'Ocean', 'value': '#0B2535'},
      {'name': 'Forest', 'value': '#102A24'},
      {'name': 'Burgundy', 'value': '#351827'},
    ];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * .78,
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: .6)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child:
                          Icon(Icons.wallpaper_rounded, color: scheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Chat wallpaper',
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                          Text('Personalise your conversation background',
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text('PRESETS',
                    style: Theme.of(sheetContext)
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2)),
                const SizedBox(height: 12),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    itemCount: presets.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 14,
                      childAspectRatio: .94,
                    ),
                    itemBuilder: (context, index) {
                      final preset = presets[index];
                      final value = preset['value']!;
                      final selected =
                          context.watch<SocketService>().chatWallpaper == value;
                      final color = value.isEmpty
                          ? (Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF0B0B17)
                              : const Color(0xFFF7F6FF))
                          : Color(
                              int.parse('FF${value.substring(1)}', radix: 16));
                      final foreground = color.computeLuminance() < .35
                          ? Colors.white
                          : const Color(0xFF29243D);
                      return InkWell(
                        onTap: () {
                          context.read<SocketService>().setChatWallpaper(
                                value,
                                widget.peer.uid.isNotEmpty
                                    ? widget.peer.uid
                                    : widget.peer.username,
                                isGroup: widget.isGroup,
                              );
                          Navigator.pop(sheetContext);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Column(
                          children: [
                            Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: double.infinity,
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: selected
                                        ? scheme.primary
                                        : scheme.outlineVariant,
                                    width: selected ? 2.2 : 1,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Align(
                                      alignment: Alignment.topLeft,
                                      child: Container(
                                        width: 35,
                                        height: 13,
                                        decoration: BoxDecoration(
                                          color:
                                              foreground.withValues(alpha: .12),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        width: 43,
                                        height: 17,
                                        decoration: BoxDecoration(
                                          color:
                                              foreground.withValues(alpha: .16),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: Container(
                                        width: 42,
                                        height: 17,
                                        decoration: BoxDecoration(
                                          color: scheme.primary
                                              .withValues(alpha: .78),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                    if (selected)
                                      Align(
                                        alignment: Alignment.topRight,
                                        child: Icon(Icons.check_circle_rounded,
                                            color: scheme.primary, size: 18),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(preset['name']!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(sheetContext)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                        fontWeight: selected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: selected
                                            ? scheme.primary
                                            : scheme.onSurface)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _uploadingAttachment
                        ? null
                        : () async {
                            final picked = await _imagePicker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 82,
                            );
                            if (picked == null || !sheetContext.mounted) return;
                            if (mounted)
                              setState(() => _uploadingAttachment = true);
                            try {
                              final bytes = await picked.readAsBytes();
                              final url = await ApiService.uploadMedia(
                                bytes,
                                picked.name,
                                _mimeForFile(picked.name),
                              );
                              if (url == null)
                                throw StateError('Wallpaper upload failed.');
                              if (!mounted || !sheetContext.mounted) return;
                              context.read<SocketService>().setChatWallpaper(
                                    url,
                                    widget.peer.uid.isNotEmpty
                                        ? widget.peer.uid
                                        : widget.peer.username,
                                  );
                              Navigator.pop(sheetContext);
                            } catch (error) {
                              if (mounted) {
                                NovynAlert.show(
                                    context,
                                    error is StateError
                                        ? error.message.toString()
                                        : 'Could not upload wallpaper. Please try again.',
                                    isError: true,
                                    title: 'Wallpaper upload failed',
                                    icon: Icons.wallpaper_rounded);
                              }
                            } finally {
                              if (mounted)
                                setState(() => _uploadingAttachment = false);
                            }
                          },
                    icon: _uploadingAttachment
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(Icons.photo_library_outlined),
                    label: Text(_uploadingAttachment
                        ? 'Uploading wallpaper…'
                        : 'Choose from gallery'),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text('Wallpaper is saved for this conversation.',
                      style: Theme.of(sheetContext)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showGroupInfo() async {
    HapticService.vibrate(NovynHapticType.light, category: HapticCategory.chat);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupInfoScreen(
          groupId: widget.peer.uid,
          fallbackName: widget.peer.name,
          onSharedMedia: () {
            Navigator.pop(context);
            _showSharedMedia();
          },
          onPinnedMessages: () {
            Navigator.pop(context);
            _showPinnedMessages();
          },
          onWallpaper: () {
            Navigator.pop(context);
            _showWallpaperPicker();
          },
          onLeft: () {
            if (mounted) Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Future<void> _loadPeerMutePreference() async {
    final preferences = await SharedPreferences.getInstance();
    final key = 'novyn_mute_${_mutePreferenceId.toLowerCase()}';
    await preferences.reload();
    var muted = preferences.getBool(key) ?? false;
    try {
      final remote = await _socketService.fetchAccountSettings();
      final settings = remote['settings'];
      if (remote['ok'] == true && settings is Map && settings['mutedChats'] is List) {
        final ids = (settings['mutedChats'] as List)
            .map((value) => value.toString().trim().toLowerCase())
            .toSet();
        muted = ids.contains(_mutePreferenceId.toLowerCase());
        await preferences.setBool(key, muted);
      }
    } catch (_) {
      // Offline: retain the last local mute state and retry on the next open.
    }
    if (mounted) setState(() => _peerMuted = muted);
  }

  Future<void> _toggleMute() async {
    final preferences = await SharedPreferences.getInstance();
    final key = 'novyn_mute_${_mutePreferenceId.toLowerCase()}';
    final nextMuted = !(preferences.getBool(key) ?? _peerMuted);
    await _setPeerMuted(nextMuted);
  }

  Future<void> _setPeerMuted(bool muted) async {
    final key = 'novyn_mute_${_mutePreferenceId.toLowerCase()}';
    final preferences = await SharedPreferences.getInstance();
    try {
      final result = await _socketService.setMute(
        _mutePreferenceId,
        muted: muted,
        isGroup: widget.isGroup,
      );
      if (result['ok'] != true) {
        throw StateError(result['message']?.toString() ??
            'The server did not confirm this mute change.');
      }
      await preferences.setBool(key, muted);
      if (!mounted) return;
      setState(() => _peerMuted = muted);
      NovynToast.show(
        context,
        muted
            ? 'Notifications muted for this chat'
            : 'Notifications unmuted for this chat',
      );
    } catch (error) {
      if (!mounted) return;
      context.showNovynAlert(
        SnackBar(content: Text('Could not update mute status: $error')),
      );
    }
  }

  bool _isPeerBlocked() {
    String normalize(String value) =>
        value.trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase();
    final peer = normalize(widget.peer.username);
    return peer.isNotEmpty &&
        _socketService.blockedUsers.any((name) => normalize(name) == peer);
  }

  Future<void> _toggleBlock({bool closeProfileOnSuccess = false}) async {
    final blocked = _isPeerBlocked();
    late final Map<String, dynamic> result;
    try {
      result = await _socketService.setBlockedUser(
        widget.peer.username,
        blocked: !blocked,
      );
    } catch (_) {
      if (!mounted) return;
      NovynAlert.show(
        context,
        'Could not update block status. Check your connection and try again.',
        isError: true,
      );
      return;
    }
    if (!mounted) return;
    if (result['ok'] == true) {
      NovynAlert.showEvent(
        context,
        blocked
            ? NovynAlertEvent.userUnblocked(widget.peer.name)
            : NovynAlertEvent.userBlocked(widget.peer.name),
      );
      if (closeProfileOnSuccess) Navigator.pop(context);
    } else {
      NovynAlert.show(
        context,
        result['message']?.toString() ?? 'Could not update block status',
        isError: true,
      );
    }
  }

  Future<void> _clearChatHistory() async {
    final socket = context.read<SocketService>();
    final oldMessages = List.of(socket.messages);
    socket.clearChat(widget.peer.username);
    for (final message in oldMessages) {
      await HybridDbService.deleteMessage(message.id);
    }
    await HybridDbService.setLastSync(widget.peer.username, DateTime.now());
    if (mounted) {
      NovynAlert.showEvent(context, NovynAlertEvent.chatCleared);
    }
  }

  Future<void> _confirmToggleBlock() async {
    final blocked = _isPeerBlocked();
    final action = blocked ? 'Unblock' : 'Block';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$action ${widget.peer.name}?'),
        content: Text(
          blocked
              ? 'This contact will be able to message and call you again.'
              : 'This contact will no longer be able to message or call you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: blocked
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
            child: Text(action),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _toggleBlock();
  }

  Future<void> _confirmClearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear chat history?'),
        content: Text(
          'This clears the conversation with ${widget.peer.name} from this device and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear chat'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _clearChatHistory();
  }

  Future<void> _exportChat() async {
    final format = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Export chat',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose a format to save this conversation.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('HTML file'),
                subtitle: const Text('Formatted chat transcript'),
                onTap: () => Navigator.pop(sheetContext, 'html'),
              ),
              ListTile(
                leading: const Icon(Icons.text_snippet_outlined),
                title: const Text('Text file (.txt)'),
                subtitle: const Text('Simple readable plain text'),
                onTap: () => Navigator.pop(sheetContext, 'txt'),
              ),
            ],
          ),
        ),
      ),
    );
    if (format == null || !mounted) return;

    final peerProtectsChat =
        context.read<SocketService>().activeChatCaptureProtected;
    final messages = context
        .read<SocketService>()
        .messages
        .where((message) => !peerProtectsChat || message.isFromMe)
        .toList();
    final title = 'Novyn chat with ${widget.peer.name}';
    final plainLines = messages.map((message) {
      final sender = message.isFromMe
          ? 'You'
          : (widget.isGroup ? message.senderId : widget.peer.name);
      final stamp = message.createdAt.toLocal().toString().substring(0, 16);
      final body = message.text.trim().isNotEmpty ? message.text : '[Attachment]';
      return '[$stamp] $sender: $body';
    }).join('\n');

    String escapeHtml(String value) => value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');

    final htmlMessages = messages.map((message) {
      final sender = message.isFromMe ? 'You' : widget.peer.name;
      final stamp = message.createdAt.toLocal().toString().substring(0, 16);
      final body = message.text.trim().isNotEmpty ? message.text : '[Attachment]';
      return '<article class="message ${message.isFromMe ? 'mine' : ''}"><span class="meta">${escapeHtml(sender)} · ${escapeHtml(stamp)}</span>${escapeHtml(body)}</article>';
    }).join('\\n');

    final content = format == 'html'
        ? '''<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(title)}</title>
<style>
*{box-sizing:border-box}body{margin:0;padding:24px;background:#f4f0ff;color:#211d43;font:15px Arial,sans-serif}
main{max-width:760px;margin:0 auto;background:#fff;border:1px solid #e8e1fa;border-radius:20px;overflow:hidden}
header{padding:24px;background:linear-gradient(120deg,#d5ccfa,#eeeaff)}
h1{margin:0 0 6px;font-size:22px}header p{margin:0;color:#625b82}
section{padding:18px}.message{padding:13px 15px;margin:0 0 10px;border-radius:14px;background:#f7f5fc;white-space:pre-wrap;overflow-wrap:anywhere}
.message.mine{background:#eeeaff}.meta{display:block;margin-bottom:5px;color:#716b8b;font-size:12px}
</style></head><body><main><header><h1>${escapeHtml(title)}</h1>
<p>@${escapeHtml(widget.peer.username)} · Exported from Novyn</p></header><section>
${htmlMessages}
</section></main></body></html>'''
        : 'Novyn chat with ${widget.peer.name} (@${widget.peer.username})\nExported: ${DateTime.now().toLocal()}\n\n$plainLines';

    try {
      final directory = await getTemporaryDirectory();
      final safeName =
          widget.peer.username.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final extension = format == 'html' ? 'html' : 'txt';
      final file = File('${directory.path}/novyn_chat_$safeName.$extension');
      await file.writeAsString(content, flush: true);
      await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType: format == 'html' ? 'text/html' : 'text/plain',
          ),
        ],
        text: title,
        subject: title,
      );
    } catch (error) {
      if (mounted) {
        NovynAlert.show(
          context,
          'Could not export chat: $error',
          isError: true,
          title: 'Chat export failed',
          icon: Icons.ios_share_rounded,
        );
      }
    }
  }

  Future<void> _showContactInfo() async {
    if (widget.isGroup) {
      await _showGroupInfo();
      return;
    }
    HapticService.vibrate(NovynHapticType.light, category: HapticCategory.chat);
    final mutePrefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final muteKey = 'novyn_mute_${widget.peer.username.toLowerCase()}';
    final initiallyMuted = mutePrefs.getBool(muteKey) ?? false;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileInfoScreen(
          user: widget.peer,
          initiallyMuted: initiallyMuted,
          // Only the other participant's protection blocks exporting this chat.
          // Your own Stealth Mode protects your privacy without locking you out.
          chatProtected:
              context.read<SocketService>().activeChatCaptureProtected,
          onVoiceCall: () {
            Navigator.pop(context);
            _startCall('voice');
          },
          onVideoCall: () {
            Navigator.pop(context);
            _startCall('video');
          },
          onSharedMedia: () {
            Navigator.pop(context);
            _showSharedMedia();
          },
          onPinnedMessages: () {
            Navigator.pop(context);
            _showPinnedMessages();
          },
          onWallpaper: () {
            Navigator.pop(context);
            _showWallpaperPicker();
          },
          initiallyBlocked: _isPeerBlocked(),
          onMute: () => _toggleMute(),
          onBlock: () => _toggleBlock(closeProfileOnSuccess: true),
          onClearChat: _clearChatHistory,
          onRemoveFriend: () async {
            final socket = context.read<SocketService>();
            socket.removeFriend(widget.peer.username);
            await HybridDbService.deleteChat(widget.peer.username);
            for (final message in socket.messages) {
              await HybridDbService.deleteMessage(message.id);
            }
            if (mounted) {
              Navigator.pop(context);
              Navigator.pop(context);
            }
          },
          onExportChat: _exportChat,
        ),
      ),
    );
  }
}

// ── Message Bubble ─────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  static final Map<String, Future<Map<String, dynamic>?>> _linkPreviewCache =
      {};

  String? _extractFirstUrl(String text) {
    return RegExp(r'https?://\S+', caseSensitive: false)
        .firstMatch(text)
        ?.group(0);
  }

  Widget _buildLinkPreview(BuildContext context, String url) {
    final future = _linkPreviewCache.putIfAbsent(
        url, () => ApiService.getLinkPreview(url));
    return FutureBuilder<Map<String, dynamic>?>(
        future: future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null ||
              ((data['title']?.toString().isEmpty ?? true) &&
                  (data['image']?.toString().isEmpty ?? true)))
            return const SizedBox.shrink();
          final image = data['image']?.toString() ?? '';
          return InkWell(
            onTap: () => launchUrl(Uri.parse(data['url']?.toString() ?? url),
                mode: LaunchMode.externalApplication),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 245,
              margin: const EdgeInsets.only(top: 8),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.12))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (image.isNotEmpty)
                      Image.network(image,
                          width: 245,
                          height: 112,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox.shrink()),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                data['siteName']?.toString() ??
                                    data['domain']?.toString() ??
                                    'Link',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 10 *
                                        context
                                            .watch<SettingsService>()
                                            .chatLabelSize,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF94A3B8))),
                            const SizedBox(height: 4),
                            Text(data['title']?.toString() ?? url,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12 *
                                        context
                                            .watch<SettingsService>()
                                            .chatLabelSize,
                                    fontWeight: FontWeight.w700)),
                            if ((data['description']?.toString() ?? '')
                                .isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(data['description'].toString(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 10 *
                                          context
                                              .watch<SettingsService>()
                                              .chatLabelSize,
                                      color: Color(0xFF94A3B8))),
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
  final bool showMeta;
  final UserModel peer;
  final bool isGroup;
  final String messageStatus;
  final String myUid;
  final List<String> quickEmojis;
  final ValueChanged<dynamic>? onReply;
  final ValueChanged<dynamic>? onForward;

  const _MessageBubble({
    required this.message,
    required this.showAvatar,
    this.showMeta = true,
    required this.peer,
    this.isGroup = false,
    this.messageStatus = 'sent',
    this.myUid = '',
    this.quickEmojis = defaultQuickReactionEmojis,
    this.onReply,
    this.onForward,
  });

  @override
  Widget build(BuildContext context) {
    final isMe = message.isFromMe as bool;
    final time = _formatTime(
        message.createdAt, context.read<SettingsService>().timeFormat);
    final reactions = Map<String, String>.from(message.reactions ?? {});
    final labelScale = context.watch<SettingsService>().chatLabelSize;
    final bubbleKey = GlobalKey();

    return Padding(
      padding: EdgeInsets.only(bottom: showMeta ? 8 : 3),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            if (showAvatar)
              UserAvatar(
                name: isGroup ? message.senderId.toString() : peer.name,
                photoUrl: isGroup ? '' : peer.photoUrl,
                radius: 14,
              )
            else
              const SizedBox(width: 28),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (isGroup && !isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(
                      message.senderId.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 10 * labelScale,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                // ── Bubble with long-press ──────────────────────────────
                GestureDetector(
                  // Double-tap a bubble to apply the familiar quick ❤️ reaction.
                  // Long-press opens the floating message actions and reaction popup.
                  onDoubleTap: () => _toggleReaction(context, '❤️'),
                  onLongPressStart: (details) {
                    final bubbleContext = bubbleKey.currentContext;
                    final renderObject = bubbleContext?.findRenderObject();
                    final bubbleRect = renderObject is RenderBox
                        ? (renderObject.localToGlobal(Offset.zero) & renderObject.size)
                        : Rect.fromCenter(
                            center: details.globalPosition,
                            width: 240,
                            height: 72,
                          );
                    _showReactionPicker(context, bubbleRect);
                  },
                  child: Container(
                    key: bubbleKey,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 10),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    decoration: BoxDecoration(
                      // Keep Novyn's purple identity without the heavy glow.
                      gradient: isMe
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Color.lerp(
                                  Theme.of(context).colorScheme.primary,
                                  Colors.black,
                                  0.08,
                                )!,
                              ],
                            )
                          : null,
                      color: isMe
                          ? null
                          : (Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1D1C2A)
                              : Colors.white),
                      border: isMe
                          ? null
                          : Border.all(
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? const Color(0x18BEB8FF)
                                  : const Color(0x166D5DFC),
                            ),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isMe ? 18 : 5),
                        bottomRight: Radius.circular(isMe ? 5 : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isMe ? 0.12 : 0.025,
                          ),
                          blurRadius: isMe ? 8 : 5,
                          offset: Offset(0, isMe ? 2 : 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Reply quote
                        if (message.replyToText != null &&
                            message.replyToText != '🔒 Encrypted message') ...[
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border(
                                left: BorderSide(
                                  color: isMe
                                      ? Colors.white.withValues(alpha: 0.6)
                                      : Theme.of(context).colorScheme.primary,
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
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 11 *
                                        context
                                            .watch<SettingsService>()
                                            .chatLabelSize,
                                    fontWeight: FontWeight.w700,
                                    color: isMe
                                        ? Colors.white.withValues(alpha: 0.9)
                                        : Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  message.replyToText ?? '',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12 *
                                        context
                                            .watch<SettingsService>()
                                            .chatLabelSize,
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
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.push_pin_rounded, size: 11),
                                SizedBox(width: 4),
                                Text('Pinned message',
                                    style: TextStyle(
                                        fontFamily: 'PlusJakartaSans',
                                        fontSize: 10 *
                                            context
                                                .watch<SettingsService>()
                                                .chatLabelSize,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        if (message.game is Map) ...[
                          GameMessageCard(
                            messageId: message.id.toString(),
                            game:
                                Map<String, dynamic>.from(message.game as Map),
                            currentUsername: myUid,
                            peerUsername:
                                peer.uid.isNotEmpty ? peer.uid : peer.username,
                            isGroup: isGroup,
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (message.riddle is Map) ...[
                          RiddleMessageCard(
                            messageId: message.id.toString(),
                            fromUsername: isGroup
                                ? (peer.uid.isNotEmpty
                                    ? peer.uid
                                    : peer.username)
                                : message.senderId.toString(),
                            riddle: Map<String, dynamic>.from(
                                message.riddle as Map),
                            isMe: isMe,
                            isGroup: isGroup,
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (message.poll is Map) ...[
                          _buildPollCard(context, message.poll as Map),
                          const SizedBox(height: 6),
                        ],
                        if (message.attachment is Map &&
                            message.attachment['url'] != null) ...[
                          _buildAttachmentPreview(
                              context, message.attachment as Map, message: message),
                          const SizedBox(height: 6),
                        ],
                        if ((message.text as String).isNotEmpty &&
                            !((message.attachment is Map) &&
                                (message.attachment['kind']
                                            ?.toString()
                                            .toLowerCase() ==
                                        'image' ||
                                    message.attachment['mime']
                                            ?.toString()
                                            .toLowerCase()
                                            .startsWith('image/') ==
                                        true) &&
                                (message.text as String).trim() == '[Image]'))
                          Text(
                            novynEmojiText(message.text as String),
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 15 *
                                  context.watch<SettingsService>().messageTextSize,
                              height: 1.35,
                              color: isMe
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        if (context.watch<SettingsService>().chatLinkPreviews &&
                            _extractFirstUrl(message.text as String) != null)
                          _buildLinkPreview(context,
                              _extractFirstUrl(message.text as String)!),
                        if (message.edited == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'edited',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 10 *
                                    context
                                        .watch<SettingsService>()
                                        .chatLabelSize,
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
                if (showMeta) ...[
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.edited == true)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            'edited',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 10 *
                                  context.watch<SettingsService>().chatLabelSize,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      Text(
                        time,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize:
                              10 * context.watch<SettingsService>().chatLabelSize,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 3),
                        _buildTick(context, message),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  void _showReactionPicker(BuildContext context, Rect bubbleRect) {
    HapticService.vibrate(
      NovynHapticType.medium,
      category: HapticCategory.chat,
    );

    final emojis = quickEmojis.isEmpty
        ? defaultQuickReactionEmojis
        : quickEmojis;
    final isMine = message.isFromMe as bool;
    final canCopy = message.text.toString().trim().isNotEmpty &&
        message.text.toString() != '🔒 Encrypted message';
    final socket = context.read<SocketService>();
    final messageId = message.id.toString();
    final status = socket.messageStatusFor(messageId);
    final deliveredAt = socket.messageDeliveredAtFor(messageId);
    final seenAt = socket.messageSeenAtFor(messageId);
    final timeFormat = context.read<SettingsService>().timeFormat;
    final sentAt = message.createdAt as DateTime;
    final isPinned = message.pinnedAt?.toString().isNotEmpty ?? false;
    final canEdit = isMine && !messageId.startsWith('tmp_') && !message.isEncrypted;
    final scheme = Theme.of(context).colorScheme;

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss message options',
      barrierColor: Colors.black.withValues(alpha: .42),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final media = MediaQuery.of(dialogContext);
        final screen = media.size;
        final insets = media.padding;
        final popupWidth = math.min(304.0, screen.width - 32).toDouble();

        final actions = <Widget>[
          _ActionItem(
            icon: Icons.reply_rounded,
            label: 'Reply',
            color: scheme.onSurfaceVariant,
            onTap: () {
              Navigator.of(dialogContext).pop();
              onReply?.call(message);
            },
          ),
          if (canCopy)
            _ActionItem(
              icon: Icons.copy_rounded,
              label: 'Copy text',
              color: scheme.onSurfaceVariant,
              onTap: () async {
                await Clipboard.setData(
                  ClipboardData(text: message.text.toString()),
                );
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                NovynAlert.showEvent(context, NovynAlertEvent.textCopied);
              },
            ),
          _ActionItem(
            icon: Icons.forward_rounded,
            label: 'Forward',
            color: scheme.onSurfaceVariant,
            onTap: () {
              Navigator.of(dialogContext).pop();
              onForward?.call(message);
            },
          ),
          _ActionItem(
            icon: Icons.push_pin_outlined,
            label: isPinned ? 'Unpin' : 'Pin',
            color: scheme.onSurfaceVariant,
            onTap: () {
              Navigator.of(dialogContext).pop();
              if (isPinned) {
                socket.unpinMessage(
                  messageId,
                  peer.uid.isNotEmpty ? peer.uid : peer.username,
                );
                NovynAlert.show(
                  context,
                  'Removed from the top of this chat.',
                  title: 'Message unpinned',
                  icon: Icons.push_pin_outlined,
                  tone: NovynAlertTone.neutral,
                );
              } else {
                socket.pinMessage(
                  messageId,
                  peer.uid.isNotEmpty ? peer.uid : peer.username,
                );
                NovynAlert.showEvent(
                  context,
                  NovynAlertEvent.messagePinned,
                );
              }
            },
          ),
          if (canEdit)
            _ActionItem(
              icon: Icons.edit_outlined,
              label: 'Edit',
              color: scheme.onSurfaceVariant,
              onTap: () {
                Navigator.of(dialogContext).pop();
                _showEditDialog(context);
              },
            ),
          _ActionItem(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: const Color(0xFFE53935),
            onTap: () {
              Navigator.of(dialogContext).pop();
              _deleteMessage(context, forEveryone: isMine);
            },
          ),
        ];

        final statusHeight = isMine ? 88.0 : 0.0;
        final estimatedMenuHeight =
            statusHeight + actions.length * 58.0 + math.max(0, actions.length - 1);
        final availableHeight =
            math.max(240.0, screen.height - insets.top - insets.bottom - 24);
        final maxMenuHeight = math.min(
          estimatedMenuHeight,
          math.min(availableHeight, screen.height * .70),
        ).toDouble();
        final belowTop = bubbleRect.bottom + 12;
        final fitsBelow =
            screen.height - insets.bottom - belowTop >= maxMenuHeight + 8;
        final menuTop = (fitsBelow
                ? belowTop
                : math.max(insets.top + 12, bubbleRect.top - maxMenuHeight - 12))
            .toDouble();
        final reactionTop = (fitsBelow
                ? math.max(insets.top + 12, bubbleRect.top - 66)
                : math.max(insets.top + 12, menuTop - 64))
            .toDouble();
        final maxLeft = math.max(16.0, screen.width - popupWidth - 16.0);
        final desiredLeft =
            isMine ? bubbleRect.right - popupWidth : bubbleRect.left;
        final popupLeft = desiredLeft.clamp(16.0, maxLeft).toDouble();

        Widget statusCell(
          IconData icon,
          String label,
          DateTime? timestamp, {
          bool active = true,
        }) {
          final color = active
              ? (label == 'Seen'
                  ? const Color(0xFF128C7E)
                  : const Color(0xFF706A86))
              : scheme.onSurfaceVariant.withValues(alpha: .42);
          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  timestamp == null
                      ? (active ? 'Recorded' : '—')
                      : _formatTime(timestamp, timeFormat),
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        final statusPanel = Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(8, 13, 8, 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: Row(
            children: [
              statusCell(Icons.check_rounded, 'Sent', sentAt),
              statusCell(
                Icons.done_all_rounded,
                'Delivered',
                deliveredAt,
                active: status == 'delivered' || status == 'seen',
              ),
              statusCell(
                Icons.done_all_rounded,
                'Seen',
                seenAt,
                active: status == 'seen',
              ),
            ],
          ),
        );

        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(dialogContext).pop(),
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(
                left: popupLeft,
                top: reactionTop,
                width: popupWidth,
                child: Material(
                  color: scheme.surface,
                  elevation: 16,
                  shadowColor: Colors.black.withValues(alpha: .24),
                  borderRadius: BorderRadius.circular(40),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    child: Row(
                      children: emojis.map((emoji) {
                        return Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(32),
                            onTap: () {
                              Navigator.of(dialogContext).pop();
                              _toggleReaction(context, emoji);
                            },
                            child: SizedBox(
                              height: 42,
                              child: Center(
                                child: Text(
                                  novynCustomEmojis[emoji] ?? emoji,
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: popupLeft,
                top: menuTop,
                width: popupWidth,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxMenuHeight),
                  child: Material(
                    color: scheme.surface,
                    elevation: 18,
                    shadowColor: Colors.black.withValues(alpha: .28),
                    borderRadius: BorderRadius.circular(25),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isMine) statusPanel,
                          for (var index = 0; index < actions.length; index++) ...[
                            actions[index],
                            if (index < actions.length - 1)
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: scheme.outlineVariant
                                    .withValues(alpha: .42),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: .96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildPollCard(BuildContext context, Map poll) {
    final rawOptions = poll['options'];
    final options =
        rawOptions is List ? rawOptions.whereType<Map>().toList() : <Map>[];
    final scheme = Theme.of(context).colorScheme;
    final totalVotes = options.fold<int>(0, (sum, option) {
      final votes = option['votes'];
      return sum + (votes is List ? votes.length : 0);
    });
    return Container(
      width: 270,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.poll_rounded, size: 17),
              const SizedBox(width: 7),
              Text('POLL',
                  style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize:
                          10 * context.watch<SettingsService>().chatLabelSize,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1)),
              const Spacer(),
              Text('$totalVotes votes',
                  style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize:
                          10 * context.watch<SettingsService>().chatLabelSize,
                      color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            poll['question']?.toString() ?? 'Poll',
            style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...options.map((option) {
            final votes = option['votes'] is List
                ? List<String>.from(option['votes'].map((v) => v.toString()))
                : <String>[];
            final count = votes.length;
            final selected =
                votes.any((vote) => vote.toLowerCase() == myUid.toLowerCase());
            final ratio = totalVotes == 0 ? 0.0 : count / totalVotes;
            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: InkWell(
                onTap: () => context.read<SocketService>().votePoll(
                      message.id.toString(),
                      option['id']?.toString() ?? '',
                      peer.uid.isNotEmpty ? peer.uid : peer.username,
                      isGroup: isGroup,
                    ),
                borderRadius: BorderRadius.circular(9),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                        color:
                            selected ? scheme.primary : scheme.outlineVariant),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                              child: Text(option['text']?.toString() ?? '',
                                  style: TextStyle(
                                      fontFamily: 'PlusJakartaSans',
                                      fontSize: 12 *
                                          context
                                              .watch<SettingsService>()
                                              .chatLabelSize,
                                      fontWeight: FontWeight.w600))),
                          Text('$count',
                              style: TextStyle(
                                  fontFamily: 'PlusJakartaSans',
                                  fontSize: 11 *
                                      context
                                          .watch<SettingsService>()
                                          .chatLabelSize,
                                  color: Color(0xFF94A3B8))),
                          if (selected)
                            const Padding(
                                padding: EdgeInsets.only(left: 5),
                                child: Icon(Icons.check_circle, size: 14)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 4,
                          backgroundColor: scheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Text('Tap an option to vote or change your vote',
              style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 9,
                  color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Future<void> _downloadAttachment(
      BuildContext context, String url, String name, {Message? message, Map? attachment}) async {
    try {
      late final File file;
      if (message != null && attachment != null) {
        final localPath = await _ChatAttachmentLoader.prepareFile(context, attachment, message);
        file = File(localPath);
      } else {
        file = await ApiService.downloadMedia(url, name);
      }
      final mime = attachment?['mime']?.toString() ?? _mimeForFile(name);
      final kind = mime.startsWith('image/')
          ? 'image'
          : mime.startsWith('video/')
              ? 'video'
              : 'file';
      final saved = await MediaStorageService.exportToDevice(file, kind);
      if (!context.mounted || !saved) return;
      NovynAlert.show(
          context,
          kind == 'image' || kind == 'video'
              ? 'Saved to your Gallery and Novyn Downloads.'
              : 'Saved using the system Files picker.',
          title: 'Saved',
          icon: Icons.download_done_rounded,
          tone: NovynAlertTone.success);
    } catch (error) {
      if (!context.mounted) return;
      NovynAlert.show(context, 'Download failed: ' + error.toString(),
          isError: true,
          title: 'Download failed',
          icon: Icons.download_rounded);
    }
  }

  Widget _buildAttachmentPreview(BuildContext context, Map attachment, {Message? message}) {
    final url = attachment['url']?.toString() ?? '';
    final name = attachment['name']?.toString().trim().isNotEmpty == true
        ? attachment['name'].toString().trim()
        : 'Attachment';
    final encrypted = attachment['encrypted'] == true && message != null;
    final rawKind = attachment['kind']?.toString().toLowerCase() ?? '';
    final mime = attachment['mime']?.toString().toLowerCase() ?? '';
    final mediaPath = (Uri.tryParse(url)?.path ?? url).toLowerCase();
    final fileHint = name.toLowerCase();
    final isImage = rawKind == 'image' ||
        mime.startsWith('image/') ||
        const ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic'].any(
            (extension) =>
                mediaPath.endsWith(extension) || fileHint.endsWith(extension));
    final isVideo = rawKind == 'video' ||
        mime.startsWith('video/') ||
        const ['.mp4', '.mov', '.webm', '.m4v'].any((extension) =>
            mediaPath.endsWith(extension) || fileHint.endsWith(extension));
    final kind = isImage
        ? 'image'
        : isVideo
            ? 'video'
            : rawKind.isNotEmpty
                ? rawKind
                : 'file';

    if (kind == 'audio' && url.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          VoiceMessagePlayer(
            url: url,
            label: name,
            durationSeconds: (attachment['duration'] as num?)?.toInt(),
            resolveLocalSource: encrypted
                ? () => _ChatAttachmentLoader.prepareFile(context, attachment, message!)
                : null,
          ),
          TextButton.icon(
            onPressed: () => _downloadAttachment(context, url, name, message: message, attachment: attachment),
            icon: const Icon(Icons.download_rounded, size: 17),
            label: const Text('Download'),
          ),
        ],
      );
    }

    if (kind == 'image' && url.isNotEmpty) {
      final scheme = Theme.of(context).colorScheme;
      final imageFuture = encrypted ? _ChatAttachmentLoader.loadBytes(context, attachment, message!) : null;
      Widget imageContent({required double? width, required double? height, required BoxFit fit}) {
        if (!encrypted) {
          return Image.network(
            url,
            headers: ApiService.imageHeaders,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
          );
        }
        return FutureBuilder<Uint8List>(
          future: imageFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Image.memory(
                snapshot.data!, width: width, height: height, fit: fit,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined),
              );
            }
            if (snapshot.hasError) {
              return SizedBox(
                width: width, height: height,
                child: const Center(child: Icon(Icons.lock_outline_rounded)),
              );
            }
            return SizedBox(
              width: width, height: height,
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
        );
      }
      return Container(
        width: 244,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(17),
          border:
              Border.all(color: scheme.outlineVariant.withValues(alpha: 0.55)),
        ),
        padding: const EdgeInsets.all(4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: Stack(
            children: [
              Material(
                color: scheme.surfaceContainerHighest,
                child: InkWell(
                  onTap: () {
                    showDialog<void>(
                      context: context,
                      barrierColor: Colors.black,
                      builder: (viewerContext) => Dialog.fullscreen(
                        backgroundColor: Colors.black,
                        child: Scaffold(
                          backgroundColor: Colors.black,
                          appBar: AppBar(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            leading: IconButton(
                              tooltip: 'Close image',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () =>
                                  Navigator.of(viewerContext).pop(),
                            ),
                            actions: [
                              IconButton(
                                tooltip: 'Download image',
                                icon: const Icon(Icons.download_rounded),
                                onPressed: () =>
                                    _downloadAttachment(context, url, name, message: message, attachment: attachment),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                          body: Center(
                            child: InteractiveViewer(
                              minScale: 0.7,
                              maxScale: 4,
                              child: imageContent(
                                width: null,
                                height: null,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: imageContent(
                    width: 236,
                    height: 188,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final icon = kind == 'video'
        ? Icons.play_circle_outline_rounded
        : kind == 'audio'
            ? Icons.audio_file_outlined
            : Icons.insert_drive_file_outlined;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: url.isEmpty
                ? null
                : () async {
                    if (encrypted) {
                      await _downloadAttachment(context, url, name, message: message, attachment: attachment);
                      return;
                    }
                    final uri = Uri.tryParse(url);
                    if (uri == null) return;
                    try {
                      final opened = await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                      if (!opened && context.mounted) {
                        NovynToast.show(
                            context, 'No app could open this attachment.',
                            isError: true);
                      }
                    } catch (_) {
                      if (context.mounted) {
                        NovynToast.show(
                            context, 'Could not open this attachment.',
                            isError: true);
                      }
                    }
                  },
            child: _attachmentFileTile(name, icon),
          ),
        ),
        if (url.isNotEmpty)
          IconButton(
            tooltip: 'Download attachment',
            icon: const Icon(Icons.download_rounded),
            onPressed: () => _downloadAttachment(context, url, name, message: message, attachment: attachment),
          ),
      ],
    );
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
              style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12),
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
            style: TextStyle(
                fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700)),
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
            child: Text('Save',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteMessage(BuildContext context,
      {required bool forEveryone}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(forEveryone ? 'Delete for everyone?' : 'Delete for me?'),
        content: Text(forEveryone
            ? 'This message will be removed for everyone in this chat.'
            : 'This message will be removed only from your chat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    context.read<SocketService>().deleteMessage(
          message.id as String,
          peer.uid.isNotEmpty ? peer.uid : peer.username,
          forEveryone: forEveryone,
        );
  }

  void _toggleReaction(BuildContext context, String emoji) {
    final socket = context.read<SocketService>();
    final reactions = Map<String, String>.from(message.reactions ?? {});
    final reactionGlyph = novynCustomEmojis[emoji] ?? emoji;
    final currentEmoji = reactions[myUid];

    if (currentEmoji == reactionGlyph) {
      // Remove reaction
      socket.removeReaction(message.id as String, peer.uid);
    } else {
      // Add/change reaction
      socket.addReaction(message.id as String, reactionGlyph, peer.uid);
    }
  }

  String _formatTime(DateTime dt, String timeFormat) {
    final local = dt.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');
    if (timeFormat == '24h') {
      return '${local.hour.toString().padLeft(2, '0')}:$minute';
    }
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final period = local.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Widget _buildTick(BuildContext context, dynamic message) {
    final status = messageStatus;
    const muted = Color(0xFF625C83);
    const purple = Color(0xFF6246E8);

    switch (status) {
      case 'sending':
        return const SizedBox(
          width: 20,
          height: 20,
          child: CustomPaint(painter: _SendingStatusPainter()),
        );
      case 'sent':
        return const Icon(Icons.check_rounded, color: muted, size: 15);
      case 'delivered':
        return const Icon(Icons.done_all_rounded, color: muted, size: 15);
      case 'seen':
        return const Icon(Icons.done_all_rounded, color: purple, size: 16);
      case 'failed':
        final reason = context
            .read<SocketService>()
            .messageFailureReasonFor(message.id.toString());
        return Tooltip(
          message: reason == null || reason.isEmpty
              ? 'Message failed. Tap to retry.'
              : '$reason Tap to retry.',
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              final socket = context.read<SocketService>();
              unawaited(socket
                  .retryPendingMessage(
                    message.id.toString(),
                    isGroup: isGroup,
                  )
                  .catchError((Object error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not retry message: $error')),
                );
              }));
            },
            child: const Padding(
              padding: EdgeInsets.all(3),
              child: Icon(
                Icons.refresh_rounded,
                color: Color(0xFFD71935),
                size: 17,
              ),
            ),
          ),
        );
      default:
        return const _StatusDot(color: muted);
    }
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  final double size;
  const _StatusDot({required this.color, this.size = 9});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _SendingStatusPainter extends CustomPainter {
  final Color color;

  const _SendingStatusPainter({this.color = const Color(0xFF625C83)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    const count = 8;
    for (var i = 0; i < count; i++) {
      final angle = (i * 3.141592653589793 * 2 / count) - 1.5707963267948966;
      final radius = size.width * .37;
      final dotRadius = i.isEven ? 1.8 : 1.35;
      canvas.drawCircle(
        Offset(center.dx + radius * math.cos(angle),
            center.dy + radius * math.sin(angle)),
        dotRadius,
        paint..color = color.withValues(alpha: .42 + (i / count) * .58),
      );
    }
    canvas.drawCircle(center, 2.5, paint..color = color);
  }

  @override
  bool shouldRepaint(covariant _SendingStatusPainter oldDelegate) =>
      oldDelegate.color != color;
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
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1D2E),
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
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
        ? raw
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: MediaQuery.of(context).size.height * 0.84,
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .55)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .12),
            blurRadius: 24,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withValues(alpha: .32),
                  borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.gif_box_rounded,
                    size: 21, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('GIFs & Stickers',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  Text('Find the perfect reaction',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              )),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded,
                      color: scheme.onSurfaceVariant)),
            ],
          ),
          TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              _category = '';
              _load();
            },
            decoration: InputDecoration(
              hintText: 'Search on GIPHY',
              prefixIcon: Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                onPressed: () {
                  _search.clear();
                  _category = '';
                  _load();
                },
                icon: Icon(Icons.close_rounded, size: 18),
              ),
              filled: true,
              fillColor: scheme.surfaceContainerLow,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
              prefixIconColor: scheme.primary,
              hintStyle: TextStyle(color: scheme.onSurfaceVariant),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: .6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: .6)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: scheme.primary, width: 1.4),
              ),
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
                  for (final category in const [
                    'Trending',
                    'Reaction',
                    'Funny',
                    'Love',
                    'Thumbs up',
                    'Party'
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: _category.toLowerCase() ==
                            (category == 'Trending'
                                ? ''
                                : category.toLowerCase()),
                        onSelected: (_) {
                          _category = category == 'Trending'
                              ? ''
                              : category.toLowerCase();
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
                        ? const Center(
                            child: Text('No results. Try another search.'))
                        : GridView.builder(
                            itemCount: _items.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 1.05,
                            ),
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              final preview = item['previewUrl']?.toString() ??
                                  item['url']?.toString() ??
                                  '';
                              return InkWell(
                                onTap: () => widget.onSelect(item),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: scheme.outlineVariant
                                            .withValues(alpha: .45)),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Image.network(
                                    preview,
                                    fit: _type == 'stickers'
                                        ? BoxFit.contain
                                        : BoxFit.cover,
                                    loadingBuilder:
                                        (context, child, progress) =>
                                            progress == null
                                                ? child
                                                : Center(
                                                    child: SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        value: progress
                                                                    .expectedTotalBytes ==
                                                                null
                                                            ? null
                                                            : progress
                                                                    .cumulativeBytesLoaded /
                                                                progress
                                                                    .expectedTotalBytes!,
                                                      ),
                                                    ),
                                                  ),
                                    errorBuilder: (_, __, ___) => Center(
                                      child: Icon(Icons.broken_image_outlined,
                                          color: scheme.onSurfaceVariant),
                                    ),
                                  ),
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
          Text('Powered by GIPHY',
              style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 10 * context.watch<SettingsService>().chatLabelSize,
                  color: scheme.onSurfaceVariant)),
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
        backgroundColor:
            selected ? Theme.of(context).colorScheme.primaryContainer : null,
        foregroundColor: selected
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSurface,
      ),
      child: Text(label),
    );
  }
}

// ── Attachment Button with PDF-reference share sheet ───────────────────────
class _AttachmentButton extends StatelessWidget {
  final ValueChanged<String> onSelected;
  const _AttachmentButton({required this.onSelected});

  static const _createItems = <_MenuItem>[
    _MenuItem(
      icon: Icons.poll_rounded,
      label: 'Poll',
      action: 'poll',
      tint: Color(0xFF7051E8),
      background: Color(0xFFF0EBFC),
    ),
    _MenuItem(
      icon: Icons.help_outline_rounded,
      label: 'Riddle',
      action: 'riddle',
      tint: Color(0xFF7C4DE2),
      background: Color(0xFFF0E9FC),
    ),
    _MenuItem(
      icon: Icons.gif_box_rounded,
      label: 'GIFs &\nStickers',
      action: 'gifs',
      tint: Color(0xFF398D83),
      background: Color(0xFFE7F4F1),
    ),
  ];

  static const _shareItems = <_MenuItem>[
    _MenuItem(
      icon: Icons.photo_library_outlined,
      label: 'Media',
      action: 'image',
      tint: Color(0xFF3E73D5),
      background: Color(0xFFE9F1FC),
    ),
    _MenuItem(
      icon: Icons.description_outlined,
      label: 'Document',
      action: 'document',
      tint: Color(0xFF398A62),
      background: Color(0xFFE8F4ED),
    ),
    _MenuItem(
      icon: Icons.headphones_rounded,
      label: 'Sound',
      action: 'sound',
      tint: Color(0xFF6545CB),
      background: Color(0xFFEDE8FC),
    ),
    _MenuItem(
      icon: Icons.location_on_outlined,
      label: 'Location',
      action: 'location',
      tint: Color(0xFF9294A6),
      background: Color(0xFFF0F0F5),
      enabled: false,
      footnote: 'Soon',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget sectionTitle(String title) => Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.25,
                color: scheme.primary,
              ),
            ),
          ),
        );

    Widget menuGrid(List<_MenuItem> items, int columns) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 8,
          crossAxisSpacing: columns == 4 ? 4 : 10,
          childAspectRatio: columns == 4 ? .82 : .94,
        ),
        itemBuilder: (tileContext, index) {
          final item = items[index];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(17),
              onTap: () {
                HapticService.vibrate(
                  NovynHapticType.selection,
                  category: HapticCategory.chat,
                );
                Navigator.pop(context);
                if (!item.enabled) {
                  NovynAlert.show(
                    context,
                    '${item.label} sharing is not available yet.',
                    title: 'Coming soon',
                    icon: Icons.hourglass_top_rounded,
                    tone: NovynAlertTone.neutral,
                  );
                  return;
                }
                onSelected(item.action);
              },
              child: Opacity(
                opacity: item.enabled ? 1 : .7,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: item.background,
                        borderRadius: BorderRadius.circular(21),
                      ),
                      child: Icon(item.icon, color: item.tint, size: 27),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12.5,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (item.footnote != null)
                      Text(
                        item.footnote!,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return Material(
      color: scheme.primary.withValues(alpha: .10),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticService.vibrate(
            NovynHapticType.light,
            category: HapticCategory.chat,
          );
          showModalBottomSheet<void>(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            useSafeArea: true,
            builder: (sheetContext) {
              final colors = Theme.of(sheetContext).colorScheme;
              final screenWidth = MediaQuery.of(sheetContext).size.width;
              final bottomSpace = MediaQuery.of(sheetContext).padding.bottom;
              return SafeArea(
                top: false,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    width: math.min(screenWidth - 24, 440.0),
                    margin: EdgeInsets.fromLTRB(10, 0, 10, 84 + bottomSpace),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: colors.outlineVariant.withValues(alpha: .35),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .16),
                          blurRadius: 28,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          sectionTitle('CREATE & PLAY'),
                          menuGrid(_createItems, 3),
                          const SizedBox(height: 10),
                          Divider(
                            height: 1,
                            color: colors.outlineVariant.withValues(alpha: .45),
                          ),
                          const SizedBox(height: 14),
                          sectionTitle('SHARE'),
                          menuGrid(_shareItems, 4),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.grid_view_rounded, size: 20, color: Color(0xFF7051E8)),
        ),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String action;
  final Color tint;
  final Color background;
  final bool enabled;
  final String? footnote;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.action,
    required this.tint,
    required this.background,
    this.enabled = true,
    this.footnote,
  });
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
                  ? Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.15)
                  : Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMine
                    ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.4)
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
                Text(e.key, style: TextStyle(fontSize: 14)),
                if (e.value > 1) ...[
                  const SizedBox(width: 3),
                  Text(
                    '${e.value}',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isMine
                          ? Theme.of(context).colorScheme.primary
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
            HapticService.vibrate(NovynHapticType.light,
                category: HapticCategory.chat);
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
              child: Icon(
                Icons.reply_rounded,
                color: Theme.of(context).colorScheme.primary,
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
    final scheme = Theme.of(context).colorScheme;
    final isDanger = color == const Color(0xFFE53935) ||
        color == const Color(0xFFEF4444);
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 58,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            children: [
              Icon(icon, color: color, size: 23),
              const SizedBox(width: 19),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDanger ? color : scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
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
      scaffoldBackgroundColor: Theme.of(context).colorScheme.surface,
      canvasColor: Theme.of(context).colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme:
            IconThemeData(color: Theme.of(context).colorScheme.onSurface),
      ),
      textTheme: Theme.of(context).textTheme,
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        hintStyle:
            TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: Icon(Icons.clear_rounded),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back_rounded),
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
                fontFamily: 'PlusJakartaSans',
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
                fontFamily: 'PlusJakartaSans',
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
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          time,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
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
            fontFamily: 'PlusJakartaSans',
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
        style: TextStyle(
          backgroundColor: Theme.of(context).colorScheme.primary,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ));
      start = idx + highlight.length;
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        children: spans,
      ),
    );
  }
}

// ── Header square button (web-style) ─────────────────────────────────────────
/// Header icon button: 44px tap target, same look as before.
class _ChatHeaderButton extends StatelessWidget {
  const _ChatHeaderButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
    this.iconSize = 21,
    this.size = 44,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final double iconSize;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: Icon(icon, size: iconSize, color: color ?? scheme.primary)),
        ),
      ),
    );
  }
}

/// Animated popover anchored under the ⋮ button.
/// Pops a String value: info | search | shared | mute | mute-on | mute-off |
/// wallpaper | export | clear | block
class _ChatMenuPopover extends StatelessWidget {
  const _ChatMenuPopover({
    required this.anchor,
    required this.isGroup,
    required this.muted,
    required this.blocked,
  });

  final Rect anchor;
  final bool isGroup;
  final bool muted;
  final bool blocked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final width = math.min(264.0, media.size.width - 24).toDouble();
    final top = anchor.bottom + 6;
    final maxHeight = math.max(120.0, media.size.height - top - media.padding.bottom - 12).toDouble();
    const danger = Color(0xFFE3453B);

    Widget divider() => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 14),
          child: Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: .6)),
        );

    return Stack(
      children: [
        Positioned(
          top: top,
          right: 10,
          width: width,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Material(
              color: scheme.surface,
              elevation: 14,
              shadowColor: Colors.black.withValues(alpha: .28),
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MenuRow(
                      value: 'info',
                      icon: isGroup ? Icons.groups_rounded : Icons.person_outline_rounded,
                      title: isGroup ? 'Group info' : 'View profile',
                      tint: const Color(0xFF705DF4),
                      chevron: true,
                    ),
                    divider(),
                    const _MenuRow(
                      value: 'search',
                      icon: Icons.search_rounded,
                      title: 'Search in chat',
                      tint: Color(0xFF2684D9),
                    ),
                    const _MenuRow(
                      value: 'shared',
                      icon: Icons.photo_library_outlined,
                      title: 'Shared media',
                      tint: Color(0xFF4388D7),
                    ),
                    const _MenuRow(
                      value: 'wallpaper',
                      icon: Icons.palette_outlined,
                      title: 'Chat wallpaper',
                      tint: Color(0xFFC83C77),
                    ),
                    if (!isGroup)
                      _MenuRow(
                        value: 'mute',
                        icon: muted
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_off_outlined,
                        title: 'Mute',
                        tint: const Color(0xFFB8791E),
                        trailing: Transform.scale(
                          scale: .78,
                          child: Switch.adaptive(
                            value: muted,
                            activeTrackColor: scheme.primary,
                            onChanged: (v) =>
                                Navigator.of(context).pop(v ? 'mute-on' : 'mute-off'),
                          ),
                        ),
                      ),
                    const _MenuRow(
                      value: 'export',
                      icon: Icons.file_upload_outlined,
                      title: 'Export chat',
                      tint: Color(0xFF13856F),
                    ),
                    if (!isGroup) ...[
                      divider(),
                      const _MenuRow(
                        value: 'clear',
                        icon: Icons.delete_outline_rounded,
                        title: 'Clear chat history',
                        tint: danger,
                        danger: true,
                      ),
                      _MenuRow(
                        value: 'block',
                        icon: blocked ? Icons.lock_open_rounded : Icons.block_rounded,
                        title: blocked ? 'Unblock contact' : 'Block contact',
                        tint: danger,
                        danger: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.value,
    required this.icon,
    required this.title,
    required this.tint,
    this.trailing,
    this.chevron = false,
    this.danger = false,
  });

  final String value;
  final IconData icon;
  final String title;
  final Color tint;
  final Widget? trailing;
  final bool chevron;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      // Soft violet feedback instead of the default grey highlight.
      highlightColor: scheme.primary.withValues(alpha: .08),
      splashColor: scheme.primary.withValues(alpha: .10),
      onTap: () => Navigator.of(context).pop(value),
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: tint, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: danger ? tint : scheme.onSurface,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
              if (chevron)
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: scheme.onSurfaceVariant.withValues(alpha: .7)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatEmptyRingsPainter extends CustomPainter {
  const _ChatEmptyRingsPainter({required this.ring});
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * .47;
    final paint = Paint()
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var index = 1; index <= 4; index++) {
      canvas.drawCircle(center, radius * index / 4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChatEmptyRingsPainter oldDelegate) =>
      oldDelegate.ring != ring;
}
