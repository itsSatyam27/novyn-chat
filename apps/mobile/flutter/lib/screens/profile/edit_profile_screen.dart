import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import '../../services/auth_service.dart';
import '../../services/settings_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _ageCtrl;
  DateTime? _selectedDOB;
  String _selectedGender = '';
  bool _checkingUsername = false;
  bool? _usernameAvailable;
  bool _saving = false;

  static const _genders = [
    'Male',
    'Female',
    'Non-binary',
    'Prefer not to say',
  ];

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    final p = auth.user;
    _nameCtrl = TextEditingController(text: p?.displayName ?? '');
    _usernameCtrl = TextEditingController(text: p?.username ?? '');
    _bioCtrl = TextEditingController(text: p?.bio ?? '');
    _ageCtrl = TextEditingController();
    _selectedGender = p?.gender ?? '';
    // If age exists, we don't have DOB stored yet in this version, so we'll just leave it empty or set a default
    // In a real app, you'd store DOB and calculate age.
    if (p?.age != null) {
      _ageCtrl.text = '${p!.age} years old';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkUsername(String value) async {
    final auth = context.read<AuthService>();
    final current = auth.user?.username ?? '';
    if (value.trim() == current) {
      setState(() {
        _usernameAvailable = null;
        _checkingUsername = false;
      });
      return;
    }
    if (value.trim().length < 3) {
      setState(() => _usernameAvailable = null);
      return;
    }
    setState(() {
      _checkingUsername = true;
      _usernameAvailable = null;
    });
    final available = await auth.isUsernameAvailable(value.trim());
    if (!mounted) return;
    setState(() {
      _checkingUsername = false;
      _usernameAvailable = available;
    });
  }

  Future<void> _selectDate() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    DateTime tempDate = _selectedDOB ?? DateTime(2000);
    
    await showDialog(
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
                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
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
                  Text(
                    'Select Date of Birth',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 200,
                    child: CupertinoTheme(
                      data: CupertinoThemeData(
                        textTheme: CupertinoTextThemeData(
                          dateTimePickerTextStyle: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.date,
                        initialDateTime: tempDate,
                        maximumDate: DateTime.now(),
                        onDateTimeChanged: (d) => tempDate = d,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7C6FF7), Color(0xFF40E0D0)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C6FF7).withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              setState(() {
                                _selectedDOB = tempDate;
                                final age = DateTime.now().year - tempDate.year;
                                _ageCtrl.text = '$age years old';
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text(
                              'Confirm',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
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

  Future<void> _save() async {
    HapticFeedback.mediumImpact();
    final auth = context.read<AuthService>();
    final settings = context.read<SettingsService>();
    final username = _usernameCtrl.text.trim();
    final current = auth.user?.username ?? '';

    if (username != current && _usernameAvailable == false) {
      _showError('Choose a different username first.');
      return;
    }

    int? age;
    if (_selectedDOB != null) {
      age = DateTime.now().year - _selectedDOB!.year;
    } else if (_ageCtrl.text.isNotEmpty) {
      age = int.tryParse(_ageCtrl.text.split(' ')[0]);
    }

    setState(() => _saving = true);

    final err = await auth.updateProfile(
      name: _nameCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
      username: username.isNotEmpty ? username : null,
      age: age,
      gender: _selectedGender.isNotEmpty ? _selectedGender : null,
    );

    await settings.setProfile(
      name: _nameCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (err != null) {
      _showError(err);
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showProfilePictureOptions() async {
    final auth = context.read<AuthService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark 
                ? const Color(0xFF1A1D2B).withValues(alpha: 0.8) 
                : Colors.white.withValues(alpha: 0.8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Profile Picture',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 24),
                _buildOptionTile(
                  icon: Icons.photo_library_rounded,
                  title: 'Choose from Gallery',
                  color: const Color(0xFF7C6FF7),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadImage(fromGallery: true);
                  },
                ),
                _buildOptionTile(
                  icon: Icons.camera_alt_rounded,
                  title: 'Take Photo',
                  color: const Color(0xFF40E0D0),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadImage(fromGallery: false);
                  },
                ),
                if (auth.user?.avatarId.isNotEmpty == true)
                  _buildOptionTile(
                    icon: Icons.delete_rounded,
                    title: 'Remove Photo',
                    color: const Color(0xFFEF4444),
                    onTap: () {
                      Navigator.pop(context);
                      _deleteProfilePicture();
                    },
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Outfit',
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
    );
  }

  void _pickAndUploadImage({required bool fromGallery}) async {
    try {
      final auth = context.read<AuthService>();
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: fromGallery ? ImageSource.gallery : ImageSource.camera,
        maxWidth: 200,
        maxHeight: 200,
        imageQuality: 80,
      );

      if (image == null) return;

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF7C6FF7)),
        ),
      );

      final error = await auth.uploadProfilePicture(File(image.path));

      if (!mounted) return;
      Navigator.pop(context);

      if (error != null) {
        _showError(error);
      } else {
        setState(() {}); // Refresh UI
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showError('Failed to pick image: ${e.toString()}');
      }
    }
  }

  void _deleteProfilePicture() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Remove Profile Picture', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to remove your profile picture?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF7C6FF7)),
      ),
    );

    final auth = context.read<AuthService>();
    final error = await auth.deleteProfilePicture();

    if (!mounted) return;
    Navigator.pop(context);

    if (error != null) {
      _showError(error);
    } else {
      setState(() {}); // Refresh UI
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture removed'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final profile = auth.user;
    final displayName = profile?.displayName.isNotEmpty == true ? profile!.displayName : 'You';
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
            size: 32,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Profile',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w900,
            fontSize: 22,
            color: Theme.of(context).colorScheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C6FF7)),
                    )
                  : ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF7C6FF7), Color(0xFF40E0D0)],
                      ).createShader(bounds),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: Colors.white,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Aurora Background
          if (isDark)
            Positioned.fill(
              child: Opacity(
                opacity: 0.5,
                child: CustomPaint(
                  painter: _AuroraBackgroundPainter(),
                ),
              ),
            ),
          
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Picture Section (Aurora Style)
                Center(
                  child: GestureDetector(
                    onTap: _showProfilePictureOptions,
                    child: _EditProfileAvatar(
                      photoUrl: profile?.avatarId,
                      displayName: displayName,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Tap to change photo',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7C6FF7),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
    
                // Form Fields
                _label('Full Name'),
                _field(
                  controller: _nameCtrl,
                  hint: 'Your full name',
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 24),
    
                _label('Username'),
                _field(
                  controller: _usernameCtrl,
                  hint: 'e.g. novyn_user',
                  icon: Icons.alternate_email_rounded,
                  onChanged: _checkUsername,
                  suffix: _checkingUsername
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C6FF7)),
                        )
                      : _usernameAvailable == null
                          ? null
                          : Icon(
                              _usernameAvailable! ? Icons.check_circle_rounded : Icons.cancel_rounded,
                              color: _usernameAvailable! ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              size: 20,
                            ),
                ),
                const SizedBox(height: 24),
    
                _label('Bio'),
                _field(
                  controller: _bioCtrl,
                  hint: 'A short bio...',
                  icon: Icons.edit_note_rounded,
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
    
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Age / DOB'),
                          GestureDetector(
                            onTap: _selectDate,
                            child: AbsorbPointer(
                              child: _field(
                                controller: _ageCtrl,
                                hint: 'Select DOB',
                                icon: Icons.cake_outlined,
                                keyboardType: TextInputType.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Gender'),
                          GestureDetector(
                            onTap: () => _showGenderPicker(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                color: isDark 
                                    ? const Color(0xFF1A1D2B).withValues(alpha: 0.6) 
                                    : Colors.white.withValues(alpha: 0.8),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.wc_rounded,
                                    color: _selectedGender.isEmpty ? const Color(0xFF7C6FF7).withValues(alpha: 0.3) : const Color(0xFF7C6FF7),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _selectedGender.isEmpty ? 'Select' : _selectedGender,
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        color: _selectedGender.isEmpty 
                                            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3) 
                                            : Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.expand_more_rounded, 
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3), 
                                    size: 20
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w900,
            fontSize: 15,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    Widget? suffix,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: const TextStyle(
          fontFamily: 'Outfit',
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(icon, size: 22, color: const Color(0xFF7C6FF7)),
          suffixIcon: suffix != null ? Padding(padding: const EdgeInsets.all(12), child: suffix) : null,
          filled: true,
          fillColor: isDark 
              ? const Color(0xFF1A1D2B).withValues(alpha: 0.6) 
              : Colors.white.withValues(alpha: 0.8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: Color(0xFF7C6FF7), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }

  void _showGenderPicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Center(
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: isDark 
                    ? const Color(0xFF1A1D2B).withValues(alpha: 0.95) 
                    : Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Select Gender',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._genders.map((g) {
                      final isSelected = _selectedGender == g;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                        title: Text(
                          g,
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                            color: isSelected ? const Color(0xFF7C6FF7) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        trailing: isSelected 
                          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF7C6FF7), size: 20)
                          : null,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _selectedGender = g);
                          Navigator.pop(context);
                        },
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditProfileAvatar extends StatelessWidget {
  final String? photoUrl;
  final String displayName;

  const _EditProfileAvatar({
    required this.photoUrl,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF7C6FF7);
    
    return Stack(
      alignment: Alignment.center,
      children: [
        // ── Outer Glow & Ring ──────────────────────────────────────
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
        ),

        // ── Main Avatar ─────────────────────────────────────────────
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.2),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 2,
            ),
            image: photoUrl != null && photoUrl!.isNotEmpty
                ? DecorationImage(
                    image: MemoryImage(base64Decode(photoUrl!)),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: photoUrl == null || photoUrl!.isEmpty
              ? Center(
                  child: Text(
                    displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : '?',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF7C6FF7),
                    ),
                  ),
                )
              : null,
        ),

        // ── Integrated Camera Node ──────────────────────────────────
        Positioned(
          bottom: 4,
          right: 4,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF7C6FF7), Color(0xFF40E0D0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C6FF7).withValues(alpha: 0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}

class _AuroraBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    // 1. Purple glow (Top Right)
    final purpleGlow = RadialGradient(
      colors: [
        const Color(0xFF7C6FF7).withValues(alpha: 0.15),
        Colors.transparent,
      ],
    ).createShader(Rect.fromCircle(center: Offset(size.width * 0.8, size.height * 0.1), radius: size.width * 0.6));
    canvas.drawRect(Offset.zero & size, paint..shader = purpleGlow);

    // 2. Turquoise glow (Bottom Left)
    final turquoiseGlow = RadialGradient(
      colors: [
        const Color(0xFF40E0D0).withValues(alpha: 0.1),
        Colors.transparent,
      ],
    ).createShader(Rect.fromCircle(center: Offset(size.width * 0.2, size.height * 0.9), radius: size.width * 0.5));
    canvas.drawRect(Offset.zero & size, paint..shader = turquoiseGlow);

    // 3. Subtle floating "innovation" lines
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < 5; i++) {
      canvas.drawLine(
        Offset(0, size.height * (0.2 * i)),
        Offset(size.width, size.height * (0.2 * i) + 50),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
