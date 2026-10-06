import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import '../../services/settings_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/auth_service.dart';
import '../auth/onboarding_screen.dart';
import 'widgets/profile_widgets.dart';
import 'edit_profile_screen.dart';
import 'settings/notification_settings_screen.dart';
import 'settings/security_privacy_screen.dart';
import 'settings/data_storage_screen.dart';
import 'settings/language_region_screen.dart';
import 'settings/accessibility_screen.dart';
import 'settings/sound_vibration_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final auth = context.watch<AuthService>();
    final l10n = AppLocalizations.of(context)!;
    final profile = auth.user;

    final displayName = profile?.displayName.isNotEmpty == true ? profile!.displayName : 'You';
    final username = profile?.username ?? 'user';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Dynamic Background Glows ────────────────────────────────
          Positioned(
            top: -150,
            right: -50,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7C6FF7).withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF40E0D0).withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title Section ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Stack(
                      children: [
                        Text(
                          'Settings',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            foreground: Paint()..shader = const LinearGradient(
                              colors: [Color(0xFF7C6FF7), Color(0xFF40E0D0)],
                            ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Profile Glass Card ──────────────────────────────────
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1E2235).withValues(alpha: 0.8)
                            : Colors.white.withValues(alpha: 0.9),
                        Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF0F121F).withValues(alpha: 0.9)
                            : const Color(0xFFF0F2FA).withValues(alpha: 0.9),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Stack(
                      children: [
                        // ── Top Right Edit Pencil (Minimalist) ──────────
                        Positioned(
                          top: 16,
                          right: 16,
                          child: GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.08),
                                border: Border.all(
                                  color: const Color(0xFF40E0D0).withValues(alpha: 0.2),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF40E0D0).withValues(alpha: 0.1),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: const _InnovationTopEditIcon(),
                            ),
                          ),
                        ),
                        
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              // Avatar with Status Orbit
                              Center(
                                child: _ProfileAvatarWithOrbit(
                                  photoUrl: profile?.photoUrl,
                                  displayName: displayName,
                                  status: profile?.status ?? 'Online',
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                displayName,
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF40E0D0).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '@$username',
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF40E0D0),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              
                              // Minimalist Status Dots
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _StatusDot(
                                    label: 'Online',
                                    color: const Color(0xFF10B981),
                                    isSelected: profile?.presenceMode == 'online',
                                    onTap: () => auth.updateStatus('online'),
                                  ),
                                  _StatusDot(
                                    label: 'Away',
                                    color: const Color(0xFFF59E0B),
                                    isSelected: profile?.presenceMode == 'away',
                                    onTap: () => auth.updateStatus('away'),
                                  ),
                                  _StatusDot(
                                    label: 'Busy',
                                    color: const Color(0xFFEC4899),
                                    isSelected: profile?.presenceMode == 'busy',
                                    onTap: () => auth.updateStatus('busy'),
                                  ),
                                  _StatusDot(
                                    label: 'Invisible',
                                    color: const Color(0xFF64748B),
                                    isSelected: profile?.presenceMode == 'invisible',
                                    onTap: () => auth.updateStatus('invisible'),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 24),
                              // We removed the old button here as it's now a Floating Node
                            ],
                          ),
                        ),
                        
                      ],
                    ),
                  ),
                ),

            // ── Account Section ───────────────────────────────────────
            _AuroraSectionLabel(label: l10n.account),
            _AuroraMenuCard(
              icon: Icons.verified_user_rounded,
              title: l10n.securityPrivacy,
              iconColor: const Color(0xFF10B981),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SecurityPrivacyScreen())),
            ),
            _AuroraMenuCard(
              icon: Icons.qr_code_rounded,
              title: l10n.qrCode,
              iconColor: const Color(0xFF7C6FF7),
              onTap: () => _showQRCode(context),
            ),

            // ── Preferences Section ───────────────────────────────────
            _AuroraSectionLabel(label: l10n.preferences),
            _AuroraMenuCard(
              icon: Icons.palette_rounded,
              title: l10n.appearance,
              iconColor: const Color(0xFF7C6FF7),
              onTap: () => _showAppearanceDialog(context, settings),
            ),
            _AuroraMenuCard(
              icon: Icons.volume_up_rounded,
              title: l10n.soundVibration,
              iconColor: const Color(0xFF40E0D0),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SoundVibrationScreen())),
            ),
            _AuroraMenuCard(
              icon: Icons.notifications_rounded,
              title: l10n.notifications,
              iconColor: const Color(0xFFEC4899),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen())),
            ),
            _AuroraMenuCard(
              icon: Icons.language_rounded,
              title: l10n.languageRegion,
              iconColor: const Color(0xFF8B5CF6),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguageRegionScreen())),
            ),

            // ── Support Section ───────────────────────────────────────
            _AuroraSectionLabel(label: l10n.support),
            _AuroraMenuCard(
              icon: Icons.help_rounded,
              title: l10n.helpSupport,
              iconColor: const Color(0xFFF59E0B),
              onTap: () => _showHelpSupport(context),
            ),
            
            // ── Danger Section ────────────────────────────────────────
            _AuroraSectionLabel(label: l10n.danger),
            _AuroraMenuCard(
              icon: Icons.logout_rounded,
              title: l10n.logOut,
              iconColor: const Color(0xFFEF4444),
              onTap: () => _confirmLogout(context, auth),
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    ),
  ],
),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — coming soon!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showHelpSupport(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Need help? Here are some ways to get support:'),
            SizedBox(height: 16),
            Text('• Check our FAQ section'),
            Text('• Contact support team'),
            Text('• Join our community forum'),
            Text('• Report bugs or issues'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showComingSoon(context, 'Contact Support');
            },
            child: const Text('Contact Support', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Terms of Service', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const SingleChildScrollView(
          child: Text(
            'By using Novyn, you agree to our terms of service. '
            'These terms govern your use of our messaging platform and services. '
            'Please read them carefully.\n\n'
            'Key points:\n'
            '• Respect other users\n'
            '• Don\'t share inappropriate content\n'
            '• Protect your account security\n'
            '• Report violations\n\n'
            'For the complete terms, visit our website.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const SingleChildScrollView(
          child: Text(
            'Your privacy is important to us. This policy explains how we collect, '
            'use, and protect your personal information.\n\n'
            'What we collect:\n'
            '• Account information\n'
            '• Messages and media\n'
            '• Usage analytics\n'
            '• Device information\n\n'
            'How we protect your data:\n'
            '• End-to-end encryption\n'
            '• Secure servers\n'
            '• Limited data retention\n'
            '• No selling to third parties\n\n'
            'For detailed information, visit our website.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthService auth) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Log out?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await auth.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                  (_) => false,
                );
              }
            },
            child: const Text('Log out', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showQRCode(BuildContext context) {
    final auth = context.read<AuthService>();
    final myUsername = auth.user?.username ?? 'unknown';
    final username = auth.user?.username ?? 'user';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          bool isGenerated = false;
          bool isGenerating = false;

          return Center(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? const Color(0xFF1A1D2B).withValues(alpha: 0.9) 
                        : Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Profile Node',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w900,
                          fontSize: 26,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your unique cryptographic identity',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // QR Container with Animation
                      _AnimatedQRContainer(
                        data: 'https://novyn.app/user/$myUsername',
                        isDark: isDark,
                      ),

                      const SizedBox(height: 40),
                      Text(
                        '@$username',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          color: Color(0xFF7C6FF7),
                        ),
                      ),
                      const SizedBox(height: 40),

                      Row(
                        children: [
                          Expanded(
                            child: _AuroraDialogButton(
                              label: 'Close',
                              onTap: () => Navigator.pop(dialogContext),
                              isSecondary: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _AuroraDialogButton(
                              label: 'Share Node',
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                // Share logic
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  void _showBackupOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Backup Options', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose what to backup:'),
            SizedBox(height: 16),
            Text('✓ Messages and chats'),
            Text('✓ Media files'),
            Text('✓ Settings and preferences'),
            Text('✓ Contact list'),
            SizedBox(height: 16),
            Text(
              'Backups are encrypted and stored securely.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showComingSoon(context, 'Backup');
            },
            child: const Text('Start Backup', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Online':
        return const Color(0xFF10B981);
      case 'Away':
        return const Color(0xFFF59E0B);
      case 'Busy':
        return const Color(0xFFEC4899);
      case 'Invisible':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF10B981);
    }
  }

  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System default';
      case ThemeMode.light:
        return 'Light mode';
      case ThemeMode.dark:
        return 'Dark mode';
    }
  }

  void _showAppearanceDialog(BuildContext context, SettingsService settings) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Center(
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark 
                    ? const Color(0xFF1A1D2B).withValues(alpha: 0.9) 
                    : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFF7C6FF7), Color(0xFF40E0D0)],
                    ).createShader(bounds),
                    child: const Text(
                      'Appearance',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _ThemeOption(
                    label: 'System Default',
                    icon: Icons.brightness_auto_rounded,
                    iconColor: const Color(0xFF7C6FF7),
                    isSelected: settings.themeMode == ThemeMode.system,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      settings.setThemeMode(ThemeMode.system);
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 12),
                  _ThemeOption(
                    label: 'Light Mode',
                    icon: Icons.light_mode_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    isSelected: settings.themeMode == ThemeMode.light,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      settings.setThemeMode(ThemeMode.light);
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 12),
                  _ThemeOption(
                    label: 'Dark Mode',
                    icon: Icons.dark_mode_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    isSelected: settings.themeMode == ThemeMode.dark,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      settings.setThemeMode(ThemeMode.dark);
                      Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 28),
                  _AuroraDialogButton(
                    label: 'Close',
                    onTap: () => Navigator.pop(context),
                    isSecondary: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Aurora Support Widgets ─────────────────────────────────────────────────

class _ProfileAvatarWithOrbit extends StatefulWidget {
  final String? photoUrl;
  final String displayName;
  final String status;

  const _ProfileAvatarWithOrbit({
    required this.photoUrl,
    required this.displayName,
    required this.status,
  });

  @override
  State<_ProfileAvatarWithOrbit> createState() => _ProfileAvatarWithOrbitState();
}

class _ProfileAvatarWithOrbitState extends State<_ProfileAvatarWithOrbit> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orbitColor = _getStatusColor(widget.status);
    
    return Stack(
      alignment: Alignment.center,
      children: [
        // ── Glowing Orbit ───────────────────────────────────────────
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.rotate(
              angle: _controller.value * 2 * math.pi,
              child: CustomPaint(
                size: const Size(105, 105),
                painter: _OrbitCometPainter(color: orbitColor),
              ),
            );
          },
        ),
        
        // ── Avatar with Outer Glow ──────────────────────────────────
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.brightness == Brightness.dark ? const Color(0xFF1A1D2E) : Colors.white,
            boxShadow: [
              BoxShadow(
                color: orbitColor.withValues(alpha: 0.3),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
            image: widget.photoUrl != null && widget.photoUrl!.isNotEmpty
                ? DecorationImage(
                    image: MemoryImage(base64Decode(widget.photoUrl!)),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: widget.photoUrl == null || widget.photoUrl!.isEmpty
              ? Center(
                  child: Text(
                    widget.displayName.isNotEmpty ? widget.displayName.substring(0, 1).toUpperCase() : '?',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                )
              : null,
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Online':
        return const Color(0xFF10B981);
      case 'Away':
        return const Color(0xFFF59E0B);
      case 'Busy':
        return const Color(0xFFEC4899);
      case 'Invisible':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF10B981);
    }
  }
}

// ── Custom Painter for the Comet Orbit ───────────────────────────────────────
class _OrbitCometPainter extends CustomPainter {
  final Color color;
  _OrbitCometPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Draw the base faint orbit line
    final orbitPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, orbitPaint);

    // 2. Draw the Comet Trail (a fading arc)
    final trailPaint = Paint()
      ..shader = SweepGradient(
        colors: [Colors.transparent, color],
        stops: const [0.8, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 0, math.pi * 0.4, false, trailPaint);

    // 3. Draw the Satellite Head (Glowing Dot)
    final headPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);
    
    // Position at the end of the arc
    final headOffset = Offset(
      center.dx + radius * math.cos(math.pi * 0.4),
      center.dy + radius * math.sin(math.pi * 0.4),
    );
    canvas.drawCircle(headOffset, 4.5, headPaint);
    canvas.drawCircle(headOffset, 2.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _StatusDot extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusDot({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 65,
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: Colors.transparent,
        child: Column(
          children: [
            // Glowing Dot
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isSelected ? 14 : 10,
              height: isSelected ? 14 : 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: isSelected
                    ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 2)]
                    : [],
                border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
              ),
            ),
            const SizedBox(height: 8),
            // Label
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected ? color : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _InnovationTopEditIcon extends StatefulWidget {
  const _InnovationTopEditIcon();
  @override
  State<_InnovationTopEditIcon> createState() => _InnovationTopEditIconState();
}

class _InnovationTopEditIconState extends State<_InnovationTopEditIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(20, 20),
          painter: _InnovationTopEditPainter(progress: _controller.value),
        );
      },
    );
  }
}

class _InnovationTopEditPainter extends CustomPainter {
  final double progress;
  _InnovationTopEditPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final color = const Color(0xFF40E0D0);
    
    // 1. Core Node
    final corePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 1);
    canvas.drawCircle(center, 2.5, corePaint);
    canvas.drawCircle(center, 1, Paint()..color = Colors.white);

    // 2. Orbiting Particles
    final orbitPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 3; i++) {
      final angle = (progress * 2 * math.pi) + (i * (2 * math.pi / 3));
      final radius = 6.0 + (math.sin(progress * 4 * math.pi + i) * 1.5);
      final pPos = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      
      canvas.drawCircle(pPos, 1.2, orbitPaint);
      if (i == 0) {
        // Add a tiny trail for one particle
        canvas.drawCircle(pPos, 3, Paint()..color = color.withValues(alpha: 0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      }
    }

    // 3. Geometric Outer Ring (Faint)
    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawCircle(center, 8, ringPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _GradientBorderPainter extends CustomPainter {
  final double radius;
  final Gradient gradient;

  _GradientBorderPainter({required this.radius, required this.gradient});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _InnovationEditIcon extends StatefulWidget {
  const _InnovationEditIcon();
  @override
  State<_InnovationEditIcon> createState() => _InnovationEditIconState();
}

class _InnovationEditIconState extends State<_InnovationEditIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(24, 24),
          painter: _InnovationEditPainter(progress: _controller.value),
        );
      },
    );
  }
}

class _InnovationEditPainter extends CustomPainter {
  final double progress;
  _InnovationEditPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = const Color(0xFF40E0D0).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final path = Path();
    // Quill Body (Sharp & Futuristic)
    path.moveTo(size.width * 0.2, size.height * 0.8);
    path.lineTo(size.width * 0.5, size.height * 0.5);
    path.lineTo(size.width * 0.8, size.height * 0.1);
    
    // Feather Detailing
    path.moveTo(size.width * 0.5, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.7, size.height * 0.4, size.width * 0.6, size.height * 0.2);
    
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);

    // Ink Node (Glowing Tip)
    final tipPos = Offset(size.width * 0.2, size.height * 0.8);
    final pulse = 2 + (progress * 2);
    canvas.drawCircle(tipPos, pulse, Paint()..color = const Color(0xFF40E0D0));
    canvas.drawCircle(tipPos, 1, Paint()..color = Colors.white);

    // Floating Ink Particles
    for (int i = 0; i < 3; i++) {
      final pPos = Offset(
        size.width * 0.4 + (math.sin(progress * 2 * math.pi + i) * 3),
        size.height * 0.4 + (math.cos(progress * 2 * math.pi + i) * 3),
      );
      canvas.drawCircle(pPos, 0.8, Paint()..color = Colors.white.withValues(alpha: 0.6));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _AuroraMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color iconColor;

  const _AuroraMenuCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1A1D2B).withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected 
                  ? iconColor.withValues(alpha: 0.5) 
                  : Colors.white.withValues(alpha: 0.05),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: iconColor.withValues(alpha: 0.05),
                blurRadius: 15,
                spreadRadius: -5,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      iconColor.withValues(alpha: 0.2),
                      iconColor.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: iconColor.withValues(alpha: 0.1)),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded, 
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2), 
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper for selection state if needed
  bool get isSelected => false; 
}

class _AuroraSectionLabel extends StatelessWidget {
  final String label;
  const _AuroraSectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 32, 8, 16),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF7C6FF7),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF7C6FF7).withValues(alpha: 0.3),
                    const Color(0xFF40E0D0).withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Theme Option Widget ────────────────────────────────────────────────────
class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected 
              ? iconColor.withValues(alpha: 0.1) 
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? iconColor.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: iconColor.withValues(alpha: 0.15),
              blurRadius: 15,
              spreadRadius: -2,
            )
          ] : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? iconColor.withValues(alpha: 0.2) : iconColor.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? const Color(0xFF7C6FF7) : Colors.grey.withValues(alpha: 0.6),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 17,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected ? const Color(0xFF7C6FF7) : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF7C6FF7),
                size: 26,
              ),
          ],
        ),
      ),
    );
  }
}

class _AuroraDialogButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isSecondary;

  const _AuroraDialogButton({
    required this.label,
    required this.onTap,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isSecondary 
              ? null 
              : const LinearGradient(
                  colors: [Color(0xFF7C6FF7), Color(0xFF40E0D0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: isSecondary 
              ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05))
              : null,
          border: isSecondary 
              ? Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1))
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: isSecondary 
                ? Theme.of(context).colorScheme.onSurface 
                : Colors.white,
          ),
        ),
      ),
    );
  }
}

class _AnimatedQRContainer extends StatefulWidget {
  final String data;
  final bool isDark;

  const _AnimatedQRContainer({required this.data, required this.isDark});

  @override
  State<_AnimatedQRContainer> createState() => _AnimatedQRContainerState();
}

class _AnimatedQRContainerState extends State<_AnimatedQRContainer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isGenerating = false;
  bool _isGenerated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startGeneration() async {
    setState(() {
      _isGenerating = true;
    });
    HapticFeedback.mediumImpact();
    
    _controller.repeat();
    
    await Future.delayed(const Duration(seconds: 3));
    
    if (mounted) {
      setState(() {
        _isGenerating = false;
        _isGenerated = true;
      });
      _controller.stop();
      HapticFeedback.vibrate();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        color: widget.isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Initial State: Generate Button ──────────────────────
            if (!_isGenerating && !_isGenerated)
              GestureDetector(
                onTap: _startGeneration,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C6FF7).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF7C6FF7).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.qr_code_2_rounded, size: 48, color: Color(0xFF7C6FF7)),
                      const SizedBox(height: 12),
                      Text(
                        'Generate Node',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: const Color(0xFF7C6FF7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Generating State: Scanning Animation ────────────────
            if (_isGenerating)
              Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: 0.2,
                    child: QrImageView(
                      data: widget.data,
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return CustomPaint(
                        size: const Size(200, 200),
                        painter: _ScanningPainter(progress: _controller.value),
                      );
                    },
                  ),
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 100),
                      Text(
                        'Synthesizing...',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF40E0D0),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

            // ── Resolved State: Final QR Code ───────────────────────
            if (_isGenerated)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 0.8 + (0.2 * value),
                    child: Opacity(
                      opacity: value,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            QrImageView(
                              data: widget.data,
                              version: QrVersions.auto,
                              size: 180.0,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.circle,
                                color: Color(0xFF1A1D2E),
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.circle,
                                color: Color(0xFF1A1D2E),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.hub_rounded, color: Color(0xFF7C6FF7), size: 20),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ScanningPainter extends CustomPainter {
  final double progress;
  _ScanningPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF40E0D0).withValues(alpha: 0),
          const Color(0xFF40E0D0),
          const Color(0xFF40E0D0).withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(0, (size.height * progress) - 10, size.width, 20))
      ..style = PaintingStyle.fill;

    final y = size.height * progress;
    canvas.drawRect(Rect.fromLTWH(0, y - 1, size.width, 2), paint);
    
    // Glow effect
    final glowPaint = Paint()
      ..color = const Color(0xFF40E0D0).withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRect(Rect.fromLTWH(0, y - 5, size.width, 10), glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

