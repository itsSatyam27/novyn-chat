import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/friend_service.dart';

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({
    super.key,
    required this.username,
    this.initialProfile,
  });

  final String username;
  final Map<String, dynamic>? initialProfile;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  late Future<Map<String, dynamic>?> _profileFuture;
  bool _sendingRequest = false;
  String? _requestMessage;
  bool _requestSent = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.initialProfile != null
        ? Future.value(widget.initialProfile)
        : ApiService.getPublicProfile(widget.username);
  }

  Future<void> _sendRequest() async {
    final myUsername = context.read<AuthService>().user?.username ?? '';
    if (myUsername.isEmpty ||
        myUsername.toLowerCase() == widget.username.toLowerCase()) {
      return;
    }

    setState(() {
      _sendingRequest = true;
      _requestMessage = null;
    });

    try {
      await context.read<FriendService>().sendRequest(
            myUsername,
            widget.username,
          );
      if (!mounted) return;
      setState(() {
        _requestSent = true;
        _requestMessage = 'Friend request sent';
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _requestMessage =
            error.toString().replaceFirst('Bad state: ', ''),
      );
    } finally {
      if (mounted) setState(() => _sendingRequest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final pageBackground =
        isDark ? scheme.surface : const Color(0xFFF7F4FD);
    final cardColor = isDark ? scheme.surfaceContainerLow : Colors.white;
    final currentUsername =
        context.watch<AuthService>().user?.username ?? '';
    final isSelf =
        currentUsername.toLowerCase() == widget.username.toLowerCase();

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: pageBackground,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 68,
        centerTitle: false,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Novyn profile',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            Text(
              '@${widget.username}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: .09),
                      shape: BoxShape.circle,
                    ),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.8,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading profile...',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return _ProfileMessage(
              icon: Icons.wifi_off_rounded,
              title: 'Could not load profile',
              message: 'Check your connection and try again.',
              onRetry: () => setState(
                () => _profileFuture =
                    ApiService.getPublicProfile(widget.username),
              ),
            );
          }

          final profile = snapshot.data;
          if (profile == null) {
            return const _ProfileMessage(
              icon: Icons.person_off_rounded,
              title: 'Profile not found',
              message:
                  'This Novyn username may have changed or the account may no longer exist.',
            );
          }

          final name = (profile['displayName'] ??
                  profile['username'] ??
                  widget.username)
              .toString();
          final username =
              (profile['username'] ?? widget.username).toString();
          final bio = (profile['bio'] ?? '').toString();
          final avatarUrl = (profile['avatarUrl'] ?? '').toString();
          final canReceiveRequests =
              profile['canReceiveRequests'] == true;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: .08),
                      blurRadius: 26,
                      offset: const Offset(0, 12),
                    ),
                  ],
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(
                      alpha: isDark ? .35 : .22,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 140,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 100,
                              clipBehavior: Clip.hardEdge,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: isDark
                                      ? const [
                                          Color(0xFF30264F),
                                          Color(0xFF493875),
                                        ]
                                      : const [
                                          Color(0xFFE9E3FA),
                                          Color(0xFFDCD2F5),
                                        ],
                                ),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(26),
                                ),
                              ),
                              child: CustomPaint(
                                painter: _PublicProfileCoverPainter(
                                  color: Colors.white.withValues(
                                    alpha: isDark ? .15 : .62,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Keep the avatar after the cover in the Stack so
                          // it is painted above the banner, not behind it.
                          Positioned(
                            top: 43,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: cardColor,
                                  border: Border.all(
                                    color: scheme.surface.withValues(
                                      alpha: .95,
                                    ),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: scheme.shadow.withValues(
                                        alpha: .16,
                                      ),
                                      blurRadius: 18,
                                      offset: const Offset(0, 7),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 44,
                                  backgroundColor: scheme.primaryContainer,
                                  backgroundImage: avatarUrl.isNotEmpty
                                      ? NetworkImage(avatarUrl)
                                      : null,
                                  child: avatarUrl.isEmpty
                                      ? Text(
                                          _initials(name),
                                          style: TextStyle(
                                            fontFamily: 'PlusJakartaSans',
                                            fontSize: 30,
                                            fontWeight: FontWeight.w800,
                                            color: scheme.onPrimaryContainer,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                      child: Column(
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontSize: 23,
                              letterSpacing: -.45,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: scheme.primary.withValues(alpha: .12),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.alternate_email_rounded,
                                  size: 15,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  username,
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    color: scheme.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isSelf && canReceiveRequests) ...[
                            const SizedBox(height: 19),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: (_sendingRequest || _requestSent)
                                    ? null
                                    : _sendRequest,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  textStyle: const TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                icon: _sendingRequest
                                    ? const SizedBox(
                                        width: 17,
                                        height: 17,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        _requestSent
                                            ? Icons.check_rounded
                                            : Icons.person_add_alt_1_rounded,
                                      ),
                                label: Text(
                                  _sendingRequest
                                      ? 'Sending request...'
                                      : _requestSent
                                          ? 'Request sent'
                                          : 'Connect on Novyn',
                                ),
                              ),
                            ),
                          ] else if (!isSelf) ...[
                            const SizedBox(height: 19),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: null,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(52),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(Icons.lock_outline_rounded),
                                label: const Text(
                                  'Not accepting friend requests',
                                ),
                              ),
                            ),
                          ],
                          if (_requestMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _requestMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _requestSent
                                    ? scheme.primary
                                    : scheme.error,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Text(
                  'ABOUT',
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 11,
                    letterSpacing: 1.15,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(
                      alpha: isDark ? .45 : .55,
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 19,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          bio.trim().isEmpty
                              ? 'This person has not added a bio yet.'
                              : bio,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 14,
                            height: 1.55,
                            color: bio.trim().isEmpty
                                ? scheme.onSurfaceVariant
                                : scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 23),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 14,
                      color: scheme.onSurfaceVariant.withValues(alpha: .75),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'A more thoughtful space for conversations.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _initials(String value) {
    final words = value
        .trim()
        .split(' ')
        .where((part) => part.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'N';
    if (words.length > 1) {
      return (words.first[0] + words.last[0]).toUpperCase();
    }
    return words.first[0].toUpperCase();
  }
}

class _ProfileMessage extends StatelessWidget {
  const _ProfileMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          decoration: BoxDecoration(
            color: isDark ? scheme.surfaceContainerLow : Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: .45),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: .06),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .09),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 31, color: scheme.primary),
              ),
              const SizedBox(height: 17),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 13,
                  height: 1.45,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 19),
                OutlinedButton(
                  onPressed: onRetry,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PublicProfileCoverPainter extends CustomPainter {
  const _PublicProfileCoverPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .18);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final maxRadius = size.width * .56;

    for (var index = 1; index <= 5; index++) {
      canvas.drawCircle(
        center,
        maxRadius * index / 5,
        paint,
      );
    }

    final accentPaint = Paint()
      ..color = color.withValues(alpha: .35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * .83, size.height * .82),
      size.width * .075,
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PublicProfileCoverPainter oldDelegate) =>
      oldDelegate.color != color;
}
