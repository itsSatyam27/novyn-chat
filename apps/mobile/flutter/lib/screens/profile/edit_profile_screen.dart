import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:ui';
import '../../services/auth_service.dart';
import '../../services/settings_service.dart';
import '../../theme/novyn_theme.dart';
import 'package:novyn/services/haptic_service.dart';

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
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    height: 200,
                    child: CupertinoTheme(
                      data: CupertinoThemeData(
                        textTheme: CupertinoTextThemeData(
                          dateTimePickerTextStyle: TextStyle(
                            fontFamily: 'PlusJakartaSans',
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
                  SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontFamily: 'PlusJakartaSans',
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: LinearGradient(
                              colors: [Theme.of(context).colorScheme.primary, Color(0xFF40E0D0)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              HapticService.vibrate(NovynHapticType.medium);
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
                            child: Text(
                              'Confirm',
                              style: TextStyle(
                                fontFamily: 'PlusJakartaSans',
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
    HapticService.vibrate(NovynHapticType.medium);
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

  Future<void> _showProfilePictureOptions() async {
    final hasPhoto = context.read<AuthService>().user?.avatarId.isNotEmpty == true;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .42),
      elevation: 0,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: .55)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: .28),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  )),
                  const SizedBox(height: 20),
                  Text('Profile photo', style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800, letterSpacing: -.3)),
                  const SizedBox(height: 4),
                  Text('Choose a photo that represents you.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  _buildOptionTile(
                    icon: Icons.photo_library_outlined,
                    title: 'Choose from gallery',
                    subtitle: 'Select an existing photo',
                    color: theme.colorScheme.primary,
                    onTap: () { Navigator.pop(sheetContext); _pickAndUploadImage(fromGallery: true); },
                  ),
                  const SizedBox(height: 8),
                  _buildOptionTile(
                    icon: Icons.camera_alt_outlined,
                    title: 'Take a photo',
                    subtitle: 'Use your device camera',
                    color: const Color(0xFF0FAE9A),
                    onTap: () { Navigator.pop(sheetContext); _pickAndUploadImage(fromGallery: false); },
                  ),
                  if (hasPhoto) ...[
                    const SizedBox(height: 8),
                    _buildOptionTile(
                      icon: Icons.delete_outline_rounded,
                      title: 'Remove photo',
                      subtitle: 'Restore your default avatar',
                      color: const Color(0xFFE5484D),
                      onTap: () { Navigator.pop(sheetContext); _deleteProfilePicture(); },
                    ),
                  ],
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .42),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () { HapticService.vibrate(NovynHapticType.selection); onTap(); },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 13),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
              ],
            )),
            Icon(Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant, size: 20),
          ]),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage({required bool fromGallery}) async {
    var progressDialogOpen = false;
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: fromGallery ? ImageSource.gallery : ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 86,
        requestFullMetadata: false,
      );
      if (image == null || !mounted) return;

      final file = File(image.path);
      if (!await file.exists()) {
        _showError('The selected photo could not be read. Please choose it again.');
        return;
      }
      final fileSize = await file.length();
      if (fileSize == 0) {
        _showError('The selected photo is empty. Please choose another photo.');
        return;
      }
      if (fileSize > 15 * 1024 * 1024) {
        _showError('Please choose a photo smaller than 15 MB.');
        return;
      }

      showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: Center(child: Material(
            color: Theme.of(dialogContext).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            child: const Padding(
              padding: EdgeInsets.all(22),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(),
                SizedBox(height: 14),
                Text('Uploading photo…'),
              ]),
            ),
          )),
        ),
      );
      progressDialogOpen = true;

      final error = await context.read<AuthService>().uploadProfilePicture(file);
      if (!mounted) return;
      if (progressDialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        progressDialogOpen = false;
      }
      if (error != null) {
        _showError(error);
      } else {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile photo updated successfully'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (error) {
      if (!mounted) return;
      if (progressDialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        progressDialogOpen = false;
      }
      _showError(error is StateError
        ? error.message.toString()
        : 'Could not upload this photo. Please check your connection and try again.');
    }
  }

  void _deleteProfilePicture() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Remove Profile Picture', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove your profile picture?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Remove', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                physics: const BouncingScrollPhysics(),
                children: [
                  // No back button here by design.
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit Profile',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800, letterSpacing: -0.8)),
                        const SizedBox(height: 5),
                        Text('Manage how you appear on Novyn.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  _buildProfileHero(
                    _nameCtrl.text.trim().isEmpty
                      ? (profile?.displayName.isNotEmpty == true ? profile!.displayName : 'You')
                      : _nameCtrl.text.trim(),
                    _usernameCtrl.text.trim(),
                  ),
                  const SizedBox(height: 30),
                  _profileSectionLabel('Basic information'),
                  _profileFieldsCard([
                    _profileField('Full name', _nameCtrl, Icons.person_outline_rounded,
                      hint: 'Your full name', onChanged: (_) => setState(() {})),
                    _profileField('Username', _usernameCtrl, Icons.alternate_email_rounded,
                      hint: 'Choose a username',
                      onChanged: (value) { setState(() {}); _checkUsername(value); },
                      suffix: _checkingUsername
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : _usernameAvailable == null ? null : Icon(
                            _usernameAvailable! ? Icons.check_circle_rounded : Icons.error_rounded,
                            color: _usernameAvailable! ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            size: 20)),
                    _profileField('Bio', _bioCtrl, Icons.notes_rounded,
                      hint: 'A little about you...', maxLines: 3,
                      onChanged: (_) => setState(() {})),
                  ]),
                  const SizedBox(height: 28),
                  _profileSectionLabel('Personal details'),
                  _profileFieldsCard([
                    _profilePicker(title: 'Date of birth',
                      value: _ageCtrl.text.isEmpty ? 'Add your birthday' : _ageCtrl.text,
                      icon: Icons.cake_outlined, onTap: _selectDate),
                    _profilePicker(title: 'Gender',
                      value: _selectedGender.isEmpty ? 'Choose your gender' : _selectedGender,
                      icon: Icons.person_outline_rounded,
                      onTap: () => _showGenderPicker(context)),
                  ]),
                  const SizedBox(height: 12),
                  Text('Your personal details help make your profile feel more like you.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                decoration: BoxDecoration(
                  color: NovynTheme.pageBg(context),
                  border: Border(top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: .55))),
                ),
                child: SizedBox(
                  width: double.infinity, height: 54,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: theme.colorScheme.primary.withValues(alpha: .45),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _saving
                      ? const SizedBox(width: 21, height: 21,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save changes',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHero(String displayName, String username) {
    final theme = Theme.of(context);
    final cleanUsername = username.replaceFirst(RegExp(r'^@'), '');
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: NovynTheme.cardBg(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(children: [
        Stack(clipBehavior: Clip.none, children: [
          GestureDetector(
            onTap: _showProfilePictureOptions,
            child: _EditProfileAvatar(
              photoUrl: context.watch<AuthService>().user?.avatarId,
              displayName: displayName)),
          Positioned(right: -2, bottom: 2,
            child: Material(
              color: theme.colorScheme.primary,
              shape: const CircleBorder(), elevation: 2,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _showProfilePictureOptions,
                child: const Padding(
                  padding: EdgeInsets.all(9),
                  child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 17)),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        Text(displayName, textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        const SizedBox(height: 4),
        Text(cleanUsername.isEmpty ? 'Choose a username' : '@$cleanUsername',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        Text('Tap your photo to update it',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant)),
      ]),
    );
  }

  Widget _profileSectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 11),
    child: Text(label, style: TextStyle(
      color: Theme.of(context).colorScheme.primary,
      fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: .7)),
  );

  Widget _profileFieldsCard(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: NovynTheme.cardBg(context),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
    child: Column(children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) Divider(height: 1, thickness: 1, indent: 16, endIndent: 16,
          color: NovynTheme.divider(context)),
        Padding(padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
          child: children[i]),
      ],
    ]),
  );

  Widget _profileField(String title, TextEditingController controller, IconData icon, {
    required String hint,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
    Widget? suffix,
  }) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        maxLines: maxLines,
        minLines: 1,
        maxLength: title == 'Bio' ? 160 : null,
        onChanged: onChanged,
        textCapitalization: title == 'Bio'
          ? TextCapitalization.sentences : TextCapitalization.words,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: .65),
            fontWeight: FontWeight.w400),
          prefixIcon: Icon(icon, size: 21),
          suffixIcon: suffix == null ? null : Padding(
            padding: const EdgeInsets.all(12), child: suffix),
          counterText: '',
          filled: true,
          fillColor: NovynTheme.inputBg(context),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: .7))),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5)),
        ),
      ),
    ]);
  }

  Widget _profilePicker({required String title, required String value,
    required IconData icon, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(14), onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Container(width: 42, height: 42,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: theme.colorScheme.primary, size: 21)),
          const SizedBox(width: 13),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text(value, style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: value.startsWith('Add ') || value.startsWith('Choose ')
                  ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface)),
            ])),
          Icon(Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurfaceVariant, size: 22),
        ]),
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
                    Text(
                      'Select Gender',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    SizedBox(height: 16),
                    ..._genders.map((g) {
                      final isSelected = _selectedGender == g;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                        title: Text(
                          g,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                            color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        trailing: isSelected 
                          ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary, size: 20)
                          : null,
                        onTap: () {
                          HapticService.vibrate(NovynHapticType.light);
                          setState(() => _selectedGender = g);
                          Navigator.pop(context);
                        },
                      );
                    }),
                    SizedBox(height: 8),
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
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    ImageProvider? avatarProvider;
    final rawPhoto = photoUrl?.trim() ?? '';
    if (rawPhoto.startsWith('http://') || rawPhoto.startsWith('https://')) {
      avatarProvider = NetworkImage(rawPhoto);
    } else if (rawPhoto.isNotEmpty) {
      try {
        final encoded = rawPhoto.startsWith('data:')
            ? rawPhoto.substring(rawPhoto.indexOf(',') + 1)
            : rawPhoto;
        avatarProvider = MemoryImage(base64Decode(encoded));
      } catch (_) { avatarProvider = null; }
    }

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
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
          ),
          child: ClipOval(
            child: avatarProvider == null
                ? Center(child: Text(
                    displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : '?',
                    style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 48,
                      fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary),
                  ))
                : Image(
                    image: avatarProvider, width: 120, height: 120, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Center(child: Text(
                      displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : '?',
                      style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 48,
                        fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary),
                    )),
                  ),
          ),
        ),
      ],
    );
  }
}

class _AuroraBackgroundPainter extends CustomPainter {
  final Color accentColor;
  _AuroraBackgroundPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    
    // 1. Purple glow (Top Right)
    final purpleGlow = RadialGradient(
      colors: [
        accentColor.withValues(alpha: 0.15),
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
