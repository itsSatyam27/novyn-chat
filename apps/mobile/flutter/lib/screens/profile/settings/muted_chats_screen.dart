import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novyn/services/haptic_service.dart';

import '../../../services/socket_service.dart';
import '../../../theme/novyn_theme.dart';

class MutedChatsScreen extends StatefulWidget {
  const MutedChatsScreen({super.key});

  @override
  State<MutedChatsScreen> createState() => _MutedChatsScreenState();
}

class _MutedChatsScreenState extends State<MutedChatsScreen> {
  static const _keyPrefix = 'novyn_mute_';
  List<String> _mutedChats = [];
  bool _loading = true;
  final Set<String> _updating = {};

  @override
  void initState() {
    super.initState();
    _loadMutedChats();
  }

  Future<void> _loadMutedChats() async {
    final prefs = await SharedPreferences.getInstance();
    final chats = prefs.getKeys()
        .where((key) => key.startsWith(_keyPrefix) && prefs.getBool(key) == true)
        .map((key) => key.substring(_keyPrefix.length).trim())
        .where((username) => username.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (!mounted) return;
    setState(() {
      _mutedChats = chats;
      _loading = false;
    });
  }

  Future<void> _unmute(String username) async {
    final normalized = username.trim().toLowerCase();
    if (normalized.isEmpty || _updating.contains(normalized)) return;
    setState(() => _updating.add(normalized));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_keyPrefix$normalized', false);
      if (!mounted) return;
      context.read<SocketService>().setMute(username, muted: false);
      setState(() {
        _mutedChats.removeWhere((chat) => chat.toLowerCase() == normalized);
        _updating.remove(normalized);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _updating.remove(normalized));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not unmute this chat: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : const Color(0xFF1A1730);
    final muted = dark ? const Color(0xFFAAA8C6) : const Color(0xFF7E7A94);
    final surface = dark ? const Color(0xFF1E1C2E) : Colors.white;
    final border = dark ? const Color(0xFF2C2844) : const Color(0xFFEDE9F6);

    return Scaffold(
      backgroundColor: dark ? NovynTheme.pageBg(context) : const Color(0xFFF4F0FB),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 18),
              child: Row(
                children: [
                  InkWell(
                    onTap: () {
                      HapticService.vibrate(NovynHapticType.light);
                      Navigator.maybePop(context);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: Icon(Icons.arrow_back_ios_new_rounded, color: ink, size: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Muted chats',
                      style: TextStyle(color: ink, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.4),
                    ),
                  ),
                  if (!_loading)
                    Text('${_mutedChats.length}', style: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Text(
              'CHATS WITH MUTED NOTIFICATIONS',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 9),
            Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: border),
              ),
              clipBehavior: Clip.antiAlias,
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(child: CircularProgressIndicator.adaptive()),
                    )
                  : _mutedChats.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
                          child: Column(
                            children: [
                              Icon(Icons.notifications_off_outlined, size: 34, color: muted),
                              const SizedBox(height: 12),
                              Text('No muted chats', style: TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 15)),
                              const SizedBox(height: 5),
                              Text('Chats you mute will appear here.', textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 13)),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            for (var i = 0; i < _mutedChats.length; i++) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: dark ? const Color(0xFF28234B) : const Color(0xFFECE9FB),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(Icons.chat_bubble_outline_rounded, color: Theme.of(context).colorScheme.primary, size: 20),
                                    ),
                                    const SizedBox(width: 13),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(_mutedChats[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: ink, fontSize: 15, fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 2),
                                          Text('Notifications muted', style: TextStyle(color: muted, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _updating.contains(_mutedChats[i].toLowerCase()) ? null : () {
                                        HapticService.vibrate(NovynHapticType.selection);
                                        _unmute(_mutedChats[i]);
                                      },
                                      child: _updating.contains(_mutedChats[i].toLowerCase())
                                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
                                          : const Text('Unmute'),
                                    ),
                                  ],
                                ),
                              ),
                              if (i != _mutedChats.length - 1)
                                Divider(height: 1, thickness: 1, indent: 72, endIndent: 16, color: border),
                            ],
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
