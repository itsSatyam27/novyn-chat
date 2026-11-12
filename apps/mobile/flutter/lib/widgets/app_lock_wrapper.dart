import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../screens/security/app_lock_screen.dart';

class AppLockWrapper extends StatefulWidget {
  final Widget child;

  const AppLockWrapper({super.key, required this.child});

  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<AppLockWrapper> with WidgetsBindingObserver {
  DateTime? _lastPausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final settings = context.read<SettingsService>();
    if (!settings.appLockEnabled) return;

    // Use only 'paused' to mark backgrounding. 
    // 'inactive' often triggers on Android for notification shades, which is too aggressive.
    if (state == AppLifecycleState.paused) {
      _lastPausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_lastPausedAt != null) {
        final now = DateTime.now();
        final diffSeconds = now.difference(_lastPausedAt!).inSeconds;
        _lastPausedAt = null;

        // "Immediately" means every actual background/resume cycle, even
        // when the user returns in under five seconds.
        final timeoutSeconds = settings.appLockTimeout * 60;
        if (settings.appLockTimeout == 0 || diffSeconds >= timeoutSeconds) {
          settings.setLocked(true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final showLock = settings.appLockEnabled && settings.isLocked;

    return Stack(
      children: [
        // The actual app content
        AbsorbPointer(
          absorbing: showLock,
          child: widget.child,
        ),
        
        // The lock overlay
        if (showLock)
          Positioned.fill(
            child: AppLockScreen(
              onUnlocked: () => settings.setLocked(false),
            ),
          ),
      ],
    );
  }
}
