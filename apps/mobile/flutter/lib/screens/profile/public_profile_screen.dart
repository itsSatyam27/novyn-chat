import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/friend_service.dart';
import '../../widgets/novyn_page_route.dart';

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({super.key, required this.username});
  final String username;

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
    _profileFuture = ApiService.getPublicProfile(widget.username);
  }

  Future<void> _sendRequest() async {
    final myUsername = context.read<AuthService>().user?.username ?? '';
    if (myUsername.isEmpty || myUsername.toLowerCase() == widget.username.toLowerCase()) return;
    setState(() {
      _sendingRequest = true;
      _requestMessage = null;
    });
    try {
      await context.read<FriendService>().sendRequest(myUsername, widget.username);
      if (!mounted) return;
      setState(() {
        _requestSent = true;
        _requestMessage = 'Friend request sent';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _requestMessage = error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _sendingRequest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final currentUsername = context.watch<AuthService>().user?.username ?? '';
    final isSelf = currentUsername.toLowerCase() == widget.username.toLowerCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Novyn profile')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ProfileMessage(
              icon: Icons.wifi_off_rounded,
              title: 'Could not load profile',
              message: 'Check your connection and try again.',
              onRetry: () => setState(() => _profileFuture = ApiService.getPublicProfile(widget.username)),
            );
          }
          final profile = snapshot.data;
          if (profile == null) {
            return const _ProfileMessage(
              icon: Icons.person_off_rounded,
              title: 'Profile not found',
              message: 'This Novyn username may have changed or the account may no longer exist.',
            );
          }
          final name = (profile['displayName'] ?? profile['username'] ?? widget.username).toString();
          final username = (profile['username'] ?? widget.username).toString();
          final bio = (profile['bio'] ?? '').toString();
          final avatarUrl = (profile['avatarUrl'] ?? '').toString();
          final canReceiveRequests = profile['canReceiveRequests'] == true;

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 58,
                  backgroundColor: scheme.primaryContainer,
                  backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl.isEmpty
                      ? Text(
                          _initials(name),
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: scheme.onPrimaryContainer),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              Text(name, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              Text('@$username', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: scheme.primary, fontWeight: FontWeight.w700)),
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(bio, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.5, color: scheme.onSurfaceVariant)),
              ],
              const SizedBox(height: 28),
              if (!isSelf && canReceiveRequests)
                FilledButton.icon(
                  onPressed: (_sendingRequest || _requestSent) ? null : _sendRequest,
                  icon: Icon(_requestSent ? Icons.check_rounded : Icons.person_add_alt_1_rounded),
                  label: Text(_requestSent ? 'Request sent' : 'Connect on Novyn'),
                )
              else if (!isSelf)
                OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: const Text('Not accepting friend requests'),
                ),
              if (_requestMessage != null) ...[
                const SizedBox(height: 12),
                Text(_requestMessage!, textAlign: TextAlign.center,
                  style: TextStyle(color: _requestSent ? scheme.primary : scheme.error)),
              ],
              const SizedBox(height: 16),
              Center(
                child: Text('A more thoughtful space for conversations.',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _initials(String value) {
    final words = value.trim().split(RegExp(r'\\s+')).where((part) => part.isNotEmpty).toList();
    if (words.isEmpty) return 'N';
    return words.length > 1
        ? '${words.first[0]}${words.last[0]}'.toUpperCase()
        : words.first[0].toUpperCase();
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
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4)),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}
