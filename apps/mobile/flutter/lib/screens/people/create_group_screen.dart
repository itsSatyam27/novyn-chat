import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../services/friend_service.dart';
import '../../services/socket_service.dart';
import '../../models/user_model.dart';
import '../../widgets/user_avatar.dart';

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
  bool _isStealth = false;

  @override
  Widget build(BuildContext context) {
    final friends = context.read<FriendService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F121F) : const Color(0xFFF8FAFC),
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration( // Optimized background
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.2,
            colors: [
              const Color(0xFF7C6FF7).withValues(alpha: isDark ? 0.05 : 0.08),
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
                    SliverToBoxAdapter(child: _buildStealthToggle(isDark)),
                    if (_selected.isNotEmpty) 
                      SliverToBoxAdapter(child: _buildSelectedList()),
                    SliverToBoxAdapter(child: _buildSearchInput(isDark)),
                    _buildSliverFriendList(friends),
                  ],
                ),
              ),
              _buildCreateButton(),
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
                fontFamily: 'Outfit',
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
      padding: const EdgeInsets.all(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: TextField(
          controller: _nameController,
          onChanged: (v) => _nameNotifier.value = v, // Non-rebuilding state update
          style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 18),
          decoration: const InputDecoration(
            hintText: 'Enter Group Name...',
            border: InputBorder.none,
            prefixIcon: Icon(Icons.groups_rounded, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildStealthToggle(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isStealth 
            ? const Color(0xFF7C6FF7).withValues(alpha: 0.1) 
            : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isStealth ? const Color(0xFF7C6FF7).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _isStealth ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: _isStealth ? const Color(0xFF7C6FF7) : Colors.grey,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Stealth Group', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text('Hidden from main chat list & encrypted notifications', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            Switch.adaptive(
              value: _isStealth,
              activeColor: const Color(0xFF7C6FF7),
              onChanged: (v) => setState(() => _isStealth = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedList() {
    return Container(
      height: 90,
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
                      HapticFeedback.selectionClick();
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
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

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final user = filtered[i];
              final isSelected = _selected.any((u) => u.uid == user.uid);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListTile(
                  leading: UserAvatar(name: user.name, photoUrl: user.photoUrl, radius: 22),
                  title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('@${user.username}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: isSelected ? const Color(0xFF7C6FF7) : Colors.grey.withValues(alpha: 0.3)),
                      color: isSelected ? const Color(0xFF7C6FF7) : Colors.transparent,
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                  ),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      if (isSelected) {
                        _selected.removeWhere((u) => u.uid == user.uid);
                      } else {
                        _selected.add(user);
                      }
                    });
                  },
                ),
              );
            },
            childCount: filtered.length,
          ),
        );
      },
    );
  }

  Widget _buildCreateButton() {
    return ValueListenableBuilder<String>(
      valueListenable: _nameNotifier,
      builder: (context, name, child) {
        final canCreate = name.isNotEmpty && _selected.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: GestureDetector(
            onTap: canCreate ? _handleCreate : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: canCreate ? const LinearGradient(
                  colors: [Color(0xFF7C6FF7), Color(0xFF6366F1)],
                ) : null,
                color: canCreate ? null : Colors.grey.withValues(alpha: 0.2),
                boxShadow: canCreate ? [
                  BoxShadow(color: const Color(0xFF7C6FF7).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))
                ] : null,
              ),
              child: const Center(
                child: Text(
                  'Create Node Group',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleCreate() async {
    HapticFeedback.heavyImpact();
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
        memberIds: _selected.map((u) => u.uid).toList(),
        isStealth: _isStealth,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading
        Navigator.pop(context); // Close CreateGroupScreen
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Node Group "${_nameController.text}" initialized!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
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
      painter: _AuroraPainter(isDark: isDark),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final bool isDark;
  _AuroraPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF7C6FF7).withValues(alpha: isDark ? 0.05 : 0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(size.width, 0), radius: size.width * 0.8));
    canvas.drawCircle(Offset(size.width, 0), size.width * 0.8, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
