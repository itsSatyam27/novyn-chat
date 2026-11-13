import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/friend_service.dart';
import '../../services/socket_service.dart';
import '../../models/user_model.dart';
import '../../widgets/user_avatar.dart';
import '../../theme/novyn_theme.dart';
import 'package:novyn/services/haptic_service.dart';

class CreateGroupScreen extends StatefulWidget {
  final String myUid;
  const CreateGroupScreen({super.key, required this.myUid});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _nameNotifier = ValueNotifier<String>(''); // Optimized state tracking
  final List<UserModel> _selected = [];
  String _search = '';

  @override
  void dispose() {
    _nameController.dispose();
    _nameNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final friends = context.read<FriendService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration( // Optimized background
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.2,
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: isDark ? 0.05 : 0.08),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: CustomScrollView( // High-performance scrolling
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildGroupNameInput(isDark)),
                    if (_selected.isNotEmpty) 
                      SliverToBoxAdapter(child: _buildSelectedList()),
                    SliverToBoxAdapter(child: _buildSearchInput(isDark)),
                    _buildSliverFriendList(friends),
                  ],
                ),
              ),
              _buildCreateButton(Theme.of(context).colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              'New Group',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 48), // Spacer
        ],
      ),
    );
  }

  Widget _buildGroupNameInput(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        decoration: BoxDecoration(
          color: NovynTheme.cardBg(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .7)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? .12 : .035), blurRadius: 16, offset: const Offset(0, 5))],
        ),
        child: TextField(
          controller: _nameController,
          onChanged: (v) => _nameNotifier.value = v, // Non-rebuilding state update
          style: const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700, fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'Enter Group Name...',
            border: InputBorder.none,
            prefixIcon: Icon(Icons.groups_rounded, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedList() {
    return Container(
      height: 82,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _selected.length,
        itemBuilder: (context, i) {
          final user = _selected[i];
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Stack(
              children: [
                Column(
                  children: [
                    UserAvatar(name: user.name, photoUrl: user.photoUrl, radius: 25),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 50,
                      child: Text(
                        user.name.split(' ')[0],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: GestureDetector(
                    onTap: () {
                      HapticService.vibrate(NovynHapticType.selection, category: HapticCategory.buttons);
                      setState(() => _selected.removeWhere((u) => u.uid == user.uid));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444), 
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 10),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchInput(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .65)),
        ),
        child: TextField(
          onChanged: (v) => setState(() => _search = v.toLowerCase()),
          decoration: const InputDecoration(
            hintText: 'Search friends...',
            border: InputBorder.none,
            icon: Icon(Icons.search_rounded, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildSliverFriendList(FriendService service) {
    return StreamBuilder<List<UserModel>>(
      stream: service.friendsStream(widget.myUid),
      builder: (context, snap) {
        final all = snap.data ?? [];
        final filtered = all.where((u) => 
          u.name.toLowerCase().contains(_search) || 
          u.username.toLowerCase().contains(_search)
        ).toList();

        if (filtered.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(children: [
                Icon(Icons.group_outlined, size: 34, color: Theme.of(context).colorScheme.primary.withValues(alpha: .7)),
                const SizedBox(height: 10),
                Text(_search.isEmpty ? 'No friends yet' : 'No friends found', style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(height: 4),
                Text(_search.isEmpty ? 'Add friends before starting a group.' : 'Try another name or username.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ]),
            ),
          );
        }
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final user = filtered[i];
              final isSelected = _selected.any((u) => u.uid == user.uid);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                child: Card(
                  elevation: 0,
                  color: NovynTheme.cardBg(context),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .55))),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  leading: UserAvatar(name: user.name, photoUrl: user.photoUrl, radius: 22),
                  title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('@${user.username}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: isSelected ? const Color(0xFF6D5DFC) : Colors.grey.withValues(alpha: 0.3)),
                      color: isSelected ? const Color(0xFF6D5DFC) : Colors.transparent,
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                  ),
                  onTap: () {
                    HapticService.vibrate(NovynHapticType.light, category: HapticCategory.buttons);
                    setState(() {
                      if (isSelected) {
                        _selected.removeWhere((u) => u.uid == user.uid);
                      } else {
                        _selected.add(user);
                      }
                    });
                  },
                  ),
                ),
              );
            },
            childCount: filtered.length,
          ),
        );
      },
    );
  }

  Widget _buildCreateButton(Color accent) {
    return ValueListenableBuilder<String>(
      valueListenable: _nameNotifier,
      builder: (context, name, child) {
        final canCreate = name.trim().isNotEmpty && _selected.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: GestureDetector(
            onTap: canCreate ? _handleCreate : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: canCreate ? LinearGradient(
                  colors: [accent, Color.lerp(accent, Colors.black, 0.14)!],
                ) : null,
                color: canCreate ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
                boxShadow: canCreate ? [
                  BoxShadow(color: accent.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))
                ] : null,
              ),
              child: Center(
                child: Text(
                  'Create Group',
                  style: TextStyle(color: canCreate ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleCreate() async {
    HapticService.vibrate(NovynHapticType.heavy, category: HapticCategory.buttons);
    final socket = context.read<SocketService>();
    
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final chatId = await socket.createGroup(
        name: _nameController.text,
        memberIds: _selected.map((u) => u.username.trim().isNotEmpty ? u.username.trim() : u.uid).toList(),
      );

      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Group "${_nameController.text.trim()}" created successfully!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        Navigator.pop(context, chatId); // Return the server-confirmed group ID
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _SubtleAurora extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      painter: _AuroraPainter(isDark: isDark, accent: Theme.of(context).colorScheme.primary),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final bool isDark;
  final Color accent;
  _AuroraPainter({required this.isDark, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: isDark ? 0.05 : 0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(size.width, 0), radius: size.width * 0.8));
    canvas.drawCircle(Offset(size.width, 0), size.width * 0.8, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
