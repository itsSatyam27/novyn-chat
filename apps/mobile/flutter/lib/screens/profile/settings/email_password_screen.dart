import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_service.dart';
import '../../../services/socket_service.dart';
import '../../../widgets/novyn_alert.dart';
import '../../../theme/novyn_theme.dart';

class AccountInfoScreen extends StatefulWidget {
  const AccountInfoScreen({super.key});

  @override
  State<AccountInfoScreen> createState() => _AccountInfoScreenState();
}

class _AccountInfoScreenState extends State<AccountInfoScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final socket = context.read<SocketService>();
    final user = auth.user;
    final colors = Theme.of(context).colorScheme;
    final email = user?.email ?? '';
    return Scaffold(
      backgroundColor: NovynTheme.pageBg(context),
      appBar: AppBar(
        title: const Text('Account Info',
          style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          _buildUsernameCard(context, auth),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: NovynTheme.cardBg(context),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(radius: 23,
                  backgroundColor: colors.primary.withValues(alpha: .12),
                  child: Icon(Icons.alternate_email_rounded, color: colors.primary)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Account email', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(email.isEmpty ? 'No email linked' : email,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
                  ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (user?.emailVerified == true
                      ? const Color(0xFF159A64) : colors.error).withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(30)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(user?.emailVerified == true ? Icons.verified_rounded : Icons.error_outline_rounded,
                      size: 14, color: user?.emailVerified == true ? const Color(0xFF159A64) : colors.error),
                    const SizedBox(width: 5),
                    Text(user?.emailVerified == true ? 'Verified' : 'Unverified',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                        color: user?.emailVerified == true ? const Color(0xFF159A64) : colors.error)),
                  ]),
                ),
              ]),
              const SizedBox(height: 15),
              Text(user?.emailVerified == true
                ? 'Your email address is verified and can be used for account recovery.'
                : 'Verify a new email address when you change it. Email verification for existing accounts may not be available yet.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant, height: 1.4)),
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: () => _changeEmail(socket, auth),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Change email'),
              )),
            ]),
          ),
          const SizedBox(height: 18),
          Text('PASSWORD', style: TextStyle(color: colors.primary, fontSize: 11,
            fontWeight: FontWeight.w800, letterSpacing: 1.3)),
          const SizedBox(height: 9),
          Container(
            decoration: BoxDecoration(color: NovynTheme.cardBg(context),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.outlineVariant)),
            child: Column(children: [
              ListTile(
                leading: CircleAvatar(backgroundColor: colors.primary.withValues(alpha: .10),
                  child: Icon(Icons.lock_outline_rounded, color: colors.primary)),
                title: const Text('Change password', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(user?.hasPassword == false
                  ? 'Add a password to your account'
                  : 'Update your current sign-in password'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _changePassword(auth),
              ),
              Divider(height: 1, indent: 68, color: colors.outlineVariant),
              ListTile(
                leading: CircleAvatar(backgroundColor: colors.secondaryContainer,
                  child: Icon(Icons.lock_reset_rounded, color: colors.onSecondaryContainer)),
                title: const Text('Forgot password?', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Reset it using a code sent to your email'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _forgotPassword(auth, email),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          if (user?.isGoogleUser == true)
            Text('Google sign-in is also linked to this account. Changing your Novyn password does not change your Google password.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildUsernameCard(BuildContext context, AuthService auth) {
    final colors = Theme.of(context).colorScheme;
    final username = auth.user?.username ?? '';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NovynTheme.cardBg(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(children: [
        CircleAvatar(radius: 23, backgroundColor: colors.primary.withValues(alpha: .12),
          child: Icon(Icons.alternate_email_rounded, color: colors.primary)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Username', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text('@$username', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('Your unique Novyn identity', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
        ])),
        IconButton(onPressed: () => _changeUsername(auth), icon: Icon(Icons.edit_outlined, color: colors.primary), tooltip: 'Change username'),
      ]),
    );
  }

  Future<void> _changeUsername(AuthService auth) async {
    final username = TextEditingController(text: auth.user?.username ?? '');
    final password = TextEditingController();
    var checking = false;
    var available = false;
    var checkedValue = '';
    var saving = false;
    final result = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (sheet) => StatefulBuilder(builder: (sheet, setSheet) {
        final colors = Theme.of(sheet).colorScheme;
        final hasPassword = auth.user?.hasPassword != false;
        final candidate = username.text.trim().toLowerCase();
        final valid = RegExp(r'^[a-z0-9_]{3,24}
    final email = TextEditingController();
    final code = TextEditingController();
    var codeSent = false;
    final result = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (sheet) => StatefulBuilder(builder: (sheet, setSheet) {
        final colors = Theme.of(sheet).colorScheme;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheet).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
            decoration: BoxDecoration(color: colors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
            child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 38, height: 4,
                  decoration: BoxDecoration(color: colors.outlineVariant, borderRadius: BorderRadius.circular(8)))),
                const SizedBox(height: 18),
                Text(codeSent ? 'Verify new email' : 'Change email',
                  style: Theme.of(sheet).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 7),
                Text(codeSent ? 'Enter the verification code sent to ${email.text.trim()}.' :
                  'We will send a one-time verification code to your new email address.',
                  style: Theme.of(sheet).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                const SizedBox(height: 16),
                if (!codeSent) TextField(controller: email, keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email], decoration: const InputDecoration(
                    labelText: 'New email address', prefixIcon: Icon(Icons.mail_outline_rounded))),
                if (codeSent) TextField(controller: code, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '6-digit verification code',
                    prefixIcon: Icon(Icons.verified_user_outlined))),
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: FilledButton(
                  onPressed: () async {
                    setSheet(() {});
                    if (!codeSent) {
                      final response = await socket.requestEmailChangeCode(email.text);
                      if (response['ok'] == true) {
                        setSheet(() => codeSent = true);
                      } else if (sheet.mounted) {
                        NovynAlert.show(sheet, response['message']?.toString() ?? 'Could not send code.', isError: true);
                      }
                    } else {
                      final response = await socket.verifyEmailChangeCode(email: email.text, code: code.text);
                      if (response['ok'] == true) {
                        if (sheet.mounted) Navigator.pop(sheet, true);
                      } else if (sheet.mounted) {
                        NovynAlert.show(sheet, response['message']?.toString() ?? 'Verification failed.', isError: true);
                      }
                    }
                  },
                  child: Text(codeSent ? 'Verify & update email' : 'Send verification code'),
                )),
              ])),
          ),
        );
      }),
    );
    email.dispose();
    code.dispose();
    if (result == true) {
      await auth.refreshProfile();
      if (mounted) NovynAlert.show(context, 'Email address updated successfully.');
    }
  }

  Future<void> _changePassword(AuthService auth) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheet).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
          decoration: BoxDecoration(color: Theme.of(sheet).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
          child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Change password', style: Theme.of(sheet).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 15),
              if (auth.user?.hasPassword != false) ...[
                TextField(controller: current, obscureText: true,
                  decoration: const InputDecoration(labelText: 'Current password')),
                const SizedBox(height: 10),
              ],
              TextField(controller: next, obscureText: true,
                decoration: const InputDecoration(labelText: 'New password')),
              const SizedBox(height: 10),
              TextField(controller: confirm, obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm new password')),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: FilledButton(
                onPressed: () async {
                  if (next.text.length < 12 || next.text != confirm.text) {
                    NovynAlert.show(sheet, next.text.length < 12
                      ? 'Use at least 12 characters.' : 'Passwords do not match.', isError: true);
                    return;
                  }
                  final error = await auth.changePassword(current.text, next.text);
                  if (error == null && sheet.mounted) Navigator.pop(sheet, true);
                  else if (sheet.mounted) NovynAlert.show(sheet, error ?? 'Could not update password.', isError: true);
                },
                child: const Text('Update password'),
              )),
            ])),
        ),
      ),
    );
    current.dispose(); next.dispose(); confirm.dispose();
    if (result == true && mounted) NovynAlert.show(context, 'Password updated successfully.');
  }

  Future<void> _forgotPassword(AuthService auth, String email) async {
    final identifier = TextEditingController(text: email);
    final code = TextEditingController();
    final password = TextEditingController();
    var sent = false;
    final result = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (sheet) => StatefulBuilder(builder: (sheet, setSheet) {
        final colors = Theme.of(sheet).colorScheme;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheet).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
            decoration: BoxDecoration(color: colors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
            child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(sent ? 'Reset password' : 'Forgot password?',
                  style: Theme.of(sheet).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(sent ? 'Enter the code sent to your account email and choose a new password.' :
                  'We will send a one-time reset code if this account is eligible.',
                  style: Theme.of(sheet).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                const SizedBox(height: 14),
                if (!sent) TextField(controller: identifier,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email or username')),
                if (sent) ...[
                  TextField(controller: code, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Reset code')),
                  const SizedBox(height: 10),
                  TextField(controller: password, obscureText: true,
                    decoration: const InputDecoration(labelText: 'New password (12+ characters)')),
                ],
                const SizedBox(height: 15),
                SizedBox(width: double.infinity, child: FilledButton(
                  onPressed: () async {
                    if (!sent) {
                      final response = await auth.requestPasswordReset(identifier.text);
                      if (response['ok'] == true && sheet.mounted) setSheet(() => sent = true);
                      else if (sheet.mounted) NovynAlert.show(sheet,
                        response['message']?.toString() ?? 'Could not request a reset code.', isError: true);
                    } else {
                      if (password.text.length < 12) {
                        NovynAlert.show(sheet, 'Use at least 12 characters.', isError: true);
                        return;
                      }
                      final response = await auth.confirmPasswordReset(
                        identifier: identifier.text, code: code.text, newPassword: password.text);
                      if (response['ok'] == true && sheet.mounted) Navigator.pop(sheet, true);
                      else if (sheet.mounted) NovynAlert.show(sheet,
                        response['message']?.toString() ?? 'Password reset failed.', isError: true);
                    }
                  },
                  child: Text(sent ? 'Reset password' : 'Send reset code'),
                )),
              ])),
          ),
        );
      }),
    );
    identifier.dispose(); code.dispose(); password.dispose();
    if (result == true && mounted) NovynAlert.show(context, 'Password reset successfully. Please sign in again.');
  }
}
).hasMatch(candidate);
        final isSame = candidate == (auth.user?.username.toLowerCase() ?? '');
        final canSave = valid && !isSame && available && checkedValue == candidate && !saving;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheet).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
            decoration: BoxDecoration(color: colors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
            child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Change username', style: Theme.of(sheet).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 7),
                Text('Use 3–24 lowercase letters, numbers or underscores. You may need to sign in again on other devices.',
                  style: Theme.of(sheet).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant, height: 1.4)),
                const SizedBox(height: 15),
                TextField(controller: username, enabled: !saving,
                  autocorrect: false, textCapitalization: TextCapitalization.none,
                  onChanged: (_) => setSheet(() { checkedValue = ''; available = false; }),
                  decoration: InputDecoration(labelText: 'New username', prefixText: '@',
                    helperText: candidate.isEmpty || valid ? null : '3–24 characters: a–z, 0–9 and _',
                    suffixIcon: checkedValue == candidate && available
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF159A64)) : null)),
                const SizedBox(height: 10),
                if (hasPassword) TextField(controller: password, enabled: !saving, obscureText: true,
                  decoration: const InputDecoration(labelText: 'Current password', prefixIcon: Icon(Icons.lock_outline_rounded))),
                if (!hasPassword) Padding(padding: const EdgeInsets.only(top: 8), child: Text(
                  'This account has no Novyn password. The server will verify the signed-in session.',
                  style: Theme.of(sheet).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant))),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: saving ? null : () => Navigator.pop(sheet), child: const Text('Cancel'))),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton(
                    onPressed: (!valid || isSame || checking || saving) ? null : () async {
                      setSheet(() => checking = true);
                      final result = await auth.isUsernameAvailable(candidate);
                      if (!sheet.mounted) return;
                      setSheet(() { checking = false; checkedValue = candidate; available = result; });
                      if (!result) NovynAlert.show(sheet, 'That username is already taken or could not be verified.', isError: true);
                    },
                    child: checking ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Check availability'),
                  )),
                ]),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: FilledButton(
                  onPressed: canSave && (!hasPassword || password.text.isNotEmpty) ? () async {
                    setSheet(() => saving = true);
                    try {
                      await context.read<SocketService>().changeUsername(
                        newUsername: candidate,
                        currentPassword: password.text,
                      );
                      await auth.refreshProfile();
                      if (sheet.mounted) Navigator.pop(sheet, true);
                    } catch (error) {
                      if (sheet.mounted) {
                        setSheet(() => saving = false);
                        NovynAlert.show(sheet, error.toString().replaceFirst('Bad state: ', ''), isError: true);
                      }
                    }
                  } : null,
                  child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Update username'),
                )),
              ])),
          ),
        );
      }),
    );
    username.dispose(); password.dispose();
    if (result == true && mounted) NovynAlert.show(context, 'Username updated successfully.');
  }

  Future<void> _changeEmail(SocketService socket, AuthService auth) async {
    final email = TextEditingController();
    final code = TextEditingController();
    var codeSent = false;
    final result = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (sheet) => StatefulBuilder(builder: (sheet, setSheet) {
        final colors = Theme.of(sheet).colorScheme;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheet).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
            decoration: BoxDecoration(color: colors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
            child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 38, height: 4,
                  decoration: BoxDecoration(color: colors.outlineVariant, borderRadius: BorderRadius.circular(8)))),
                const SizedBox(height: 18),
                Text(codeSent ? 'Verify new email' : 'Change email',
                  style: Theme.of(sheet).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 7),
                Text(codeSent ? 'Enter the verification code sent to ${email.text.trim()}.' :
                  'We will send a one-time verification code to your new email address.',
                  style: Theme.of(sheet).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                const SizedBox(height: 16),
                if (!codeSent) TextField(controller: email, keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email], decoration: const InputDecoration(
                    labelText: 'New email address', prefixIcon: Icon(Icons.mail_outline_rounded))),
                if (codeSent) TextField(controller: code, keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '6-digit verification code',
                    prefixIcon: Icon(Icons.verified_user_outlined))),
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, child: FilledButton(
                  onPressed: () async {
                    setSheet(() {});
                    if (!codeSent) {
                      final response = await socket.requestEmailChangeCode(email.text);
                      if (response['ok'] == true) {
                        setSheet(() => codeSent = true);
                      } else if (sheet.mounted) {
                        NovynAlert.show(sheet, response['message']?.toString() ?? 'Could not send code.', isError: true);
                      }
                    } else {
                      final response = await socket.verifyEmailChangeCode(email: email.text, code: code.text);
                      if (response['ok'] == true) {
                        if (sheet.mounted) Navigator.pop(sheet, true);
                      } else if (sheet.mounted) {
                        NovynAlert.show(sheet, response['message']?.toString() ?? 'Verification failed.', isError: true);
                      }
                    }
                  },
                  child: Text(codeSent ? 'Verify & update email' : 'Send verification code'),
                )),
              ])),
          ),
        );
      }),
    );
    email.dispose();
    code.dispose();
    if (result == true) {
      await auth.refreshProfile();
      if (mounted) NovynAlert.show(context, 'Email address updated successfully.');
    }
  }

  Future<void> _changePassword(AuthService auth) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheet).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
          decoration: BoxDecoration(color: Theme.of(sheet).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
          child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Change password', style: Theme.of(sheet).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 15),
              if (auth.user?.hasPassword != false) ...[
                TextField(controller: current, obscureText: true,
                  decoration: const InputDecoration(labelText: 'Current password')),
                const SizedBox(height: 10),
              ],
              TextField(controller: next, obscureText: true,
                decoration: const InputDecoration(labelText: 'New password')),
              const SizedBox(height: 10),
              TextField(controller: confirm, obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm new password')),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: FilledButton(
                onPressed: () async {
                  if (next.text.length < 12 || next.text != confirm.text) {
                    NovynAlert.show(sheet, next.text.length < 12
                      ? 'Use at least 12 characters.' : 'Passwords do not match.', isError: true);
                    return;
                  }
                  final error = await auth.changePassword(current.text, next.text);
                  if (error == null && sheet.mounted) Navigator.pop(sheet, true);
                  else if (sheet.mounted) NovynAlert.show(sheet, error ?? 'Could not update password.', isError: true);
                },
                child: const Text('Update password'),
              )),
            ])),
        ),
      ),
    );
    current.dispose(); next.dispose(); confirm.dispose();
    if (result == true && mounted) NovynAlert.show(context, 'Password updated successfully.');
  }

  Future<void> _forgotPassword(AuthService auth, String email) async {
    final identifier = TextEditingController(text: email);
    final code = TextEditingController();
    final password = TextEditingController();
    var sent = false;
    final result = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (sheet) => StatefulBuilder(builder: (sheet, setSheet) {
        final colors = Theme.of(sheet).colorScheme;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheet).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
            decoration: BoxDecoration(color: colors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
            child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(sent ? 'Reset password' : 'Forgot password?',
                  style: Theme.of(sheet).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(sent ? 'Enter the code sent to your account email and choose a new password.' :
                  'We will send a one-time reset code if this account is eligible.',
                  style: Theme.of(sheet).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                const SizedBox(height: 14),
                if (!sent) TextField(controller: identifier,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email or username')),
                if (sent) ...[
                  TextField(controller: code, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Reset code')),
                  const SizedBox(height: 10),
                  TextField(controller: password, obscureText: true,
                    decoration: const InputDecoration(labelText: 'New password (12+ characters)')),
                ],
                const SizedBox(height: 15),
                SizedBox(width: double.infinity, child: FilledButton(
                  onPressed: () async {
                    if (!sent) {
                      final response = await auth.requestPasswordReset(identifier.text);
                      if (response['ok'] == true && sheet.mounted) setSheet(() => sent = true);
                      else if (sheet.mounted) NovynAlert.show(sheet,
                        response['message']?.toString() ?? 'Could not request a reset code.', isError: true);
                    } else {
                      if (password.text.length < 12) {
                        NovynAlert.show(sheet, 'Use at least 12 characters.', isError: true);
                        return;
                      }
                      final response = await auth.confirmPasswordReset(
                        identifier: identifier.text, code: code.text, newPassword: password.text);
                      if (response['ok'] == true && sheet.mounted) Navigator.pop(sheet, true);
                      else if (sheet.mounted) NovynAlert.show(sheet,
                        response['message']?.toString() ?? 'Password reset failed.', isError: true);
                    }
                  },
                  child: Text(sent ? 'Reset password' : 'Send reset code'),
                )),
              ])),
          ),
        );
      }),
    );
    identifier.dispose(); code.dispose(); password.dispose();
    if (result == true && mounted) NovynAlert.show(context, 'Password reset successfully. Please sign in again.');
  }
}
