import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novyn/widgets/novyn_alert.dart';

import '../../../services/socket_service.dart';
import '../../../theme/novyn_theme.dart';
import '../../../services/haptic_service.dart';

class QuietHoursScreen extends StatefulWidget {
  const QuietHoursScreen({super.key});

  @override
  State<QuietHoursScreen> createState() => _QuietHoursScreenState();
}

class _QuietHoursScreenState extends State<QuietHoursScreen> {
  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;
  TimeOfDay _start = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 7, minute: 0);

  String _format(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  TimeOfDay _parse(dynamic raw, TimeOfDay fallback) {
    final parts = raw?.toString().split(':') ?? const [];
    if (parts.length != 2) return fallback;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) return fallback;
    return TimeOfDay(hour: hour, minute: minute);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await context.read<SocketService>().fetchAccountSettings();
      final raw = result['settings'];
      if (result['ok'] == true && raw is Map) {
        if (!mounted) return;
        setState(() {
          _enabled = raw['quietHoursEnabled'] == true;
          _start = _parse(raw['quietHoursStart'], _start);
          _end = _parse(raw['quietHoursEnd'], _end);
          _loading = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _chooseTime(bool start) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: start ? _start : _end,
      builder: (context, child) => Theme(
        data: Theme.of(context),
        child: child!,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() { if (start) { _start = selected; } else { _end = selected; } });
  }

  Future<void> _save({bool? enabled}) async {
    if (_saving) return;
    setState(() => _saving = true);
    final nextEnabled = enabled ?? _enabled;
    final offset = DateTime.now().timeZoneOffset.inMinutes;
    final timezone = 'UTC${offset >= 0 ? '+' : ''}$offset';
    try {
      final result = await context.read<SocketService>().updateAccountSettings({
        'quietHoursEnabled': nextEnabled,
        'quietHoursStart': _format(_start),
        'quietHoursEnd': _format(_end),
        'quietHoursTimezone': timezone,
      });
      if (result['ok'] != true) throw StateError(result['message']?.toString() ?? 'Could not save quiet hours.');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('quiet_hours_enabled', nextEnabled);
      await prefs.setString('quiet_hours_start', _format(_start));
      await prefs.setString('quiet_hours_end', _format(_end));
      await prefs.setInt('quiet_hours_offset_minutes', offset);
      if (!mounted) return;
      setState(() => _enabled = nextEnabled);
      context.showNovynAlert(const SnackBar(content: Text('Quiet hours updated.')));
    } catch (error) {
      if (mounted) context.showNovynAlert(SnackBar(content: Text('Could not save quiet hours: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : const Color(0xFF1A1730);
    final muted = dark ? const Color(0xFFAAA8C6) : const Color(0xFF7E7A94);
    final card = dark ? const Color(0xFF1E1C2E) : Colors.white;
    final border = dark ? const Color(0xFF2C2844) : const Color(0xFFEDE9F6);
    return Scaffold(
      backgroundColor: dark ? NovynTheme.pageBg(context) : const Color(0xFFF4F0FB),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
          children: [
            Row(children: [
              IconButton(
                onPressed: () { HapticService.vibrate(NovynHapticType.light); Navigator.maybePop(context); },
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: ink, size: 20),
              ),
              const SizedBox(width: 8),
              Text('Quiet hours', style: TextStyle(color: ink, fontSize: 24, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(24), border: Border.all(color: border)),
              child: Column(children: [
                SwitchListTile.adaptive(
                  value: _enabled,
                  onChanged: _loading || _saving ? null : (value) => _save(enabled: value),
                  title: Text('Enable quiet hours', style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
                  subtitle: Text('Silence message, social and game notifications on a schedule.', style: TextStyle(color: muted, fontSize: 12)),
                  activeTrackColor: Theme.of(context).colorScheme.primary,
                ),
                Divider(height: 1, color: border, indent: 16, endIndent: 16),
                ListTile(
                  enabled: !_loading && !_saving && _enabled,
                  title: Text('Start time', style: TextStyle(color: ink)),
                  subtitle: Text(_start.format(context), style: TextStyle(color: muted)),
                  trailing: Icon(Icons.schedule_rounded, color: Theme.of(context).colorScheme.primary),
                  onTap: () => _chooseTime(true),
                ),
                Divider(height: 1, color: border, indent: 16, endIndent: 16),
                ListTile(
                  enabled: !_loading && !_saving && _enabled,
                  title: Text('End time', style: TextStyle(color: ink)),
                  subtitle: Text(_end.format(context), style: TextStyle(color: muted)),
                  trailing: Icon(Icons.schedule_rounded, color: Theme.of(context).colorScheme.primary),
                  onTap: () => _chooseTime(false),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Text('Quiet hours follow this device’s current time-zone offset. Incoming call alerts continue to follow your call and DND settings.', style: TextStyle(color: muted, fontSize: 12, height: 1.45)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading || _saving ? null : () => _save(),
              child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save schedule'),
            ),
          ],
        ),
      ),
    );
  }
}
