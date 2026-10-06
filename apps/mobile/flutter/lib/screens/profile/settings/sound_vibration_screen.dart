import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../services/settings_service.dart';
import '../../../services/haptic_service.dart';
import '../widgets/profile_widgets.dart';

class SoundVibrationScreen extends StatefulWidget {
  const SoundVibrationScreen({super.key});

  @override
  State<SoundVibrationScreen> createState() => _SoundVibrationScreenState();
}

class _SoundVibrationScreenState extends State<SoundVibrationScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _previewSound(String tone, {bool isRingtone = false, String? customPath}) {
    if (tone == 'None') return;
    
    // Stop any existing sound before playing new one
    _audioPlayer.stop().then((_) {
      if (customPath != null && customPath.isNotEmpty) {
        _audioPlayer.play(DeviceFileSource(customPath));
      } else {
        String asset = isRingtone ? 'audio/call_ring.mp3' : 'audio/notification.mp3';
        // Handle the old "random" names for backward compatibility or defaults
        if (tone == 'Crystal') asset = 'audio/message_sent.mp3';
        if (tone == 'Ethereal') asset = 'audio/ringtone.mp3';
        if (tone == 'Binary') asset = 'audio/call_ring.mp3';
        if (tone == 'Aurora') asset = 'audio/notification.mp3';
        
        _audioPlayer.play(AssetSource(asset));
      }
    });
  }

  Future<void> _pickCustomSound(bool isRingtone, SettingsService settings) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      if (isRingtone) {
        await settings.setCallRingtone('Custom');
        await settings.setCustomRingtonePath(path);
        _previewSound('Custom', isRingtone: true, customPath: path);
      } else {
        await settings.setNotificationTone('Custom');
        await settings.setCustomNotificationPath(path);
        _previewSound('Custom', isRingtone: false, customPath: path);
      }
    }
  }

  void _previewVibration(String pattern) {
    if (pattern == 'none') return;
    
    if (pattern == 'standard') {
      HapticService.vibrate(NovynHapticType.medium);
    } else if (pattern == 'staccato') {
      HapticService.vibrate(NovynHapticType.heavy);
    } else if (pattern == 'heartbeat') {
      HapticService.vibrate(NovynHapticType.warning);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F121F) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.chevron_left_rounded, 
            color: Theme.of(context).colorScheme.onSurface, 
            size: 32
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF7C6FF7), Color(0xFF40E0D0)],
          ).createShader(bounds),
          child: const Text(
            'Sound & Vibration',
            style: TextStyle(
              fontFamily: 'Outfit', 
              fontWeight: FontWeight.w900, 
              fontSize: 22, 
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        physics: const BouncingScrollPhysics(),
        children: [
          const SectionLabel(label: 'Auditory Node Styles'),
          _SelectionCard(
            icon: Icons.music_note_rounded,
            iconColor: const Color(0xFF8B5CF6),
            iconBgColor: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
            title: 'Notification Tone',
            subtitle: 'Primary auditory alert signature',
            value: settings.notificationTone == 'Custom' && settings.customNotificationPath != null
                ? p.basename(settings.customNotificationPath!)
                : (settings.notificationTone == 'None' ? 'Deactivated' : 'Default'),
            options: const ['Default', 'Custom', 'None'],
            labels: const ['System Default', 'Set from storage...', 'Deactivated'],
            onChanged: (v) {
              if (v == 'Custom') {
                _pickCustomSound(false, settings);
              } else {
                settings.setNotificationTone(v);
                settings.setCustomNotificationPath(null);
                _previewSound(v == 'Default' ? 'Aurora' : v);
              }
            },
          ),
          _SelectionCard(
            icon: Icons.call_rounded,
            iconColor: const Color(0xFF10B981),
            iconBgColor: const Color(0xFF10B981).withValues(alpha: 0.1),
            title: 'Call Ringtone',
            subtitle: 'Auditory stream for incoming calls',
            value: settings.callRingtone == 'Custom' && settings.customRingtonePath != null
                ? p.basename(settings.customRingtonePath!)
                : (settings.callRingtone == 'None' ? 'Deactivated' : 'Default'),
            options: const ['Default', 'Custom', 'None'],
            labels: const ['System Default', 'Set from storage...', 'Deactivated'],
            onChanged: (v) {
              if (v == 'Custom') {
                _pickCustomSound(true, settings);
              } else {
                settings.setCallRingtone(v);
                settings.setCustomRingtonePath(null);
                _previewSound(v == 'Default' ? 'Binary' : v, isRingtone: true);
              }
            },
          ),
          _ToggleCard(
            icon: Icons.volume_up_rounded,
            iconColor: const Color(0xFF7C6FF7),
            iconBgColor: const Color(0xFF7C6FF7).withValues(alpha: 0.1),
            title: 'In-App Sounds',
            subtitle: 'Auditory feedback for internal nodes',
            value: settings.inAppSounds,
            onChanged: (v) => settings.setInAppSounds(v),
          ),
          
          const SizedBox(height: 24),
          const SectionLabel(label: 'Haptic Resonance'),
          _SelectionCard(
            icon: Icons.vibration_rounded,
            iconColor: const Color(0xFFF43F5E),
            iconBgColor: const Color(0xFFF43F5E).withValues(alpha: 0.1),
            title: 'Vibration Rhythm',
            subtitle: 'Tactile pattern for incoming streams',
            value: settings.vibrationPattern,
            options: const ['standard', 'staccato', 'heartbeat', 'none'],
            labels: const ['Standard Node', 'Staccato Pulse', 'Heartbeat Rhythm', 'Deactivated'],
            onChanged: (v) {
              settings.setVibrationPattern(v);
              _previewVibration(v);
            },
          ),
          _IntensitySliderCard(
            value: settings.hapticIntensity,
            onChanged: (v) {
              settings.setHapticIntensity(v);
              // Small tactile feedback as they slide
              if ((v * 100).toInt() % 10 == 0) {
                HapticService.vibrate(NovynHapticType.selection);
              }
            },
          ),
          _ToggleCard(
            icon: Icons.touch_app_rounded,
            iconColor: const Color(0xFF06B6D4),
            iconBgColor: const Color(0xFF06B6D4).withValues(alpha: 0.1),
            title: 'Haptic Feedback',
            subtitle: 'Tactile response for UI interactions',
            value: settings.inAppVibration,
            onChanged: (v) => settings.setInAppVibration(v),
          ),
          
          const SizedBox(height: 24),
          const SectionLabel(label: 'Diagnostic Test'),
          _DiagnosticButton(
            label: 'Test Haptic Resonance',
            icon: Icons.sensors_rounded,
            onTap: () => HapticService.vibrate(NovynHapticType.heavy),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Note: If resonance is not felt, ensure "Battery Saver" or system-level vibration settings are not deactivating the haptic node.',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final String value;
  final List<String> options;
  final List<String> labels;
  final ValueChanged<String> onChanged;

  const _SelectionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.options,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentLabel = value; // Now displaying the filename directly if custom
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isDark 
            ? const Color(0xFF1A1D2B).withValues(alpha: 0.6) 
            : Colors.white.withValues(alpha: 0.8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: InkWell(
            onTap: () {
              HapticService.vibrate(NovynHapticType.selection);
              _showSelectionDialog(context);
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: iconColor.withValues(alpha: 0.1)),
                    ),
                    child: Icon(icon, color: iconColor, size: 24),
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
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currentLabel,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF7C6FF7),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded, 
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2), 
                        size: 20
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSelectionDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: AlertDialog(
          backgroundColor: isDark 
              ? const Color(0xFF1A1D2B).withValues(alpha: 0.9) 
              : Colors.white.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Text(
            title,
            style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final label = labels[index];
              final isSelected = value == option;
              
              return ListTile(
                title: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected ? const Color(0xFF7C6FF7) : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                trailing: isSelected 
                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF7C6FF7)) 
                    : null,
                onTap: () {
                  HapticService.vibrate(NovynHapticType.medium);
                  onChanged(option);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _IntensitySliderCard extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _IntensitySliderCard({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isDark 
            ? const Color(0xFF1A1D2B).withValues(alpha: 0.6) 
            : Colors.white.withValues(alpha: 0.8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C6FF7).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF7C6FF7).withValues(alpha: 0.1)),
                      ),
                      child: const Icon(Icons.fingerprint_rounded, color: Color(0xFF7C6FF7), size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Haptic Intensity',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fine-tune the neural haptic pulse',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${(value * 100).toInt()}%',
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF7C6FF7),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF7C6FF7),
                    inactiveTrackColor: Colors.white12,
                    thumbColor: Colors.white,
                    overlayColor: const Color(0xFF7C6FF7).withValues(alpha: 0.2),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: value,
                    onChanged: (v) {
                      if ((v * 10).toInt() != (value * 10).toInt()) {
                        HapticService.vibrate(NovynHapticType.selection);
                      }
                      onChanged(v);
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
}

class _ToggleCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _ToggleCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabled = onChanged == null;

    return Opacity(
      opacity: disabled ? 0.4 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: isDark 
              ? const Color(0xFF1A1D2B).withValues(alpha: 0.6) 
              : Colors.white.withValues(alpha: 0.8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: iconColor.withValues(alpha: 0.1)),
                    ),
                    child: Icon(icon, color: iconColor, size: 24),
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
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: value,
                    onChanged: disabled ? null : (v) {
                      HapticService.vibrate(NovynHapticType.medium);
                      onChanged?.call(v);
                    },
                    activeTrackColor: const Color(0xFF7C6FF7).withValues(alpha: 0.5),
                    activeColor: const Color(0xFF7C6FF7),
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

class _DiagnosticButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _DiagnosticButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF7C6FF7), Color(0xFF40E0D0)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C6FF7).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
