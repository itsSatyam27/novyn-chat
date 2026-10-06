import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/auth_service.dart';
import '../../../services/settings_service.dart';

class EditProfileSheet extends StatefulWidget {
  final AuthService auth;
  final SettingsService settings;

  const EditProfileSheet({super.key, required this.auth, required this.settings});

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _bioCtrl;
  late final TextEditingController _ageCtrl;

  String _selectedGender = '';
  bool _checkingUsername = false;
  bool? _usernameAvailable;
  bool _saving = false;
  String? _error;

  static const _genders = [
    'Male', 'Female', 'Non-binary', 'Prefer not to say',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.auth.userProfile;
    _nameCtrl     = TextEditingController(text: p?.name ?? '');
    _usernameCtrl = TextEditingController(text: p?.username ?? '');
    _bioCtrl      = TextEditingController(text: p?.bio ?? '');
    _ageCtrl      = TextEditingController(text: p?.age != null ? '${p!.age}' : '');
    _selectedGender = p?.gender ?? '';
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
    final current = widget.auth.userProfile?.username ?? '';
    if (value.trim() == current) {
      setState(() { _usernameAvailable = null; _checkingUsername = false; });
      return;
    }
    if (value.trim().length < 3) {
      setState(() { _usernameAvailable = null; });
      return;
    }
    setState(() { _checkingUsername = true; _usernameAvailable = null; });
    final available = await widget.auth.isUsernameAvailable(value.trim());
    if (!mounted) return;
    setState(() { _checkingUsername = false; _usernameAvailable = available; });
  }

  Future<void> _save() async {
    HapticFeedback.mediumImpact();
    final username = _usernameCtrl.text.trim();
    final current  = widget.auth.userProfile?.username ?? '';

    if (username != current && _usernameAvailable == false) {
      setState(() => _error = 'Choose a different username first.');
      return;
    }

    final ageText = _ageCtrl.text.trim();
    int? age;
    if (ageText.isNotEmpty) {
      age = int.tryParse(ageText);
      if (age == null || age < 1 || age > 120) {
        setState(() => _error = 'Please enter a valid age.');
        return;
      }
    }

    setState(() { _saving = true; _error = null; });

    final err = await widget.auth.updateProfile(
      name: _nameCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
      username: username.isNotEmpty ? username : null,
      age: age,
      gender: _selectedGender.isNotEmpty ? _selectedGender : null,
    );

    await widget.settings.setProfile(
      name: _nameCtrl.text.trim(),
      bio: _bioCtrl.text.trim(),
    );

    if (!mounted) return;
    if (err != null) {
      setState(() { _error = err; _saving = false; });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE2E5F0), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Edit Profile', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF1A1D2E))),
            const SizedBox(height: 20),
            
            _label('Full Name'),
            _field(controller: _nameCtrl, hint: 'Your full name', icon: Icons.person_outline_rounded),
            const SizedBox(height: 16),

            _label('Username'),
            _field(
              controller: _usernameCtrl,
              hint: 'e.g. novyn_user',
              icon: Icons.alternate_email_rounded,
              onChanged: _checkUsername,
              suffix: _checkingUsername
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C6FF7)))
                  : _usernameAvailable == null ? null : Icon(
                      _usernameAvailable! ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: _usernameAvailable! ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      size: 20,
                    ),
            ),
            const SizedBox(height: 16),

            _label('Bio'),
            _field(controller: _bioCtrl, hint: 'A short bio...', icon: Icons.edit_note_rounded, maxLines: 3),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Age'),
                      _field(controller: _ageCtrl, hint: '22', icon: Icons.cake_outlined, keyboardType: TextInputType.number),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Gender'),
                      GestureDetector(
                        onTap: () => _showGenderPicker(context),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F2FA),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E5F0)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.wc_rounded, color: _selectedGender.isEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF7C6FF7), size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_selectedGender.isEmpty ? 'Select' : _selectedGender, style: TextStyle(color: _selectedGender.isEmpty ? const Color(0xFFCBD5E1) : const Color(0xFF1A1D2E)))),
                              const Icon(Icons.expand_more_rounded, color: Color(0xFFCBD5E1), size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C6FF7),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _saving 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 6),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF64748B))),
  );

  Widget _field({required TextEditingController controller, required String hint, required IconData icon, int maxLines = 1, TextInputType? keyboardType, ValueChanged<String>? onChanged, Widget? suffix}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF7C6FF7)),
        suffixIcon: suffix != null ? Padding(padding: const EdgeInsets.all(12), child: suffix) : null,
        filled: true,
        fillColor: const Color(0xFFF0F2FA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  void _showGenderPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Select Gender', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          ..._genders.map((g) => ListTile(
            title: Text(g),
            onTap: () { setState(() => _selectedGender = g); Navigator.pop(context); },
            trailing: _selectedGender == g ? const Icon(Icons.check_circle, color: Color(0xFF7C6FF7)) : null,
          )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
