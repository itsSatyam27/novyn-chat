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
    return Card(
      color: NovynTheme.cardBg(context),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colors.primary.withValues(alpha: .12),
          child: Icon(Icons.alternate_email_rounded, color: colors.primary),
        ),
        title: const Text('Username', style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('@${auth.user?.username ?? ''}'),
        trailing: IconButton(
          tooltip: 'Change username',
          onPressed: () => _changeUsername(auth),
          icon: Icon(Icons.edit_outlined, color: colors.primary),
        ),
      ),
    );
  }

  Future<void> _changeUsername(AuthService auth) async {
    final username = TextEditingController(text: auth.user?.username ?? '');
    final password = TextEditingController();
    final hasPassword = auth.user?.hasPassword != false;
    final candidate = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change username'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: username,
              autofocus: true,
              textCapitalization: TextCapitalization.none,
              decoration: const InputDecoration(
                labelText: 'New username',
                prefixText: '@',
                helperText: '3–24 lowercase letters, numbers or underscores',
              ),
            ),
            if (hasPassword) ...[
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password'),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('Your signed-in session will be used to verify this change.'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              username.text.trim().toLowerCase(),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (candidate == null) {
      username.dispose();
      password.dispose();
      return;
    }

    final valid = RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(candidate);
    if (!valid) {
      username.dispose();
      password.dispose();
      if (mounted) {
        NovynAlert.show(
          context,
          'Username must be 3–24 characters and use only lowercase letters, numbers or underscores.',
          isError: true,
        );
      }
      return;
    }

    if (candidate == (auth.user?.username ?? '').toLowerCase()) {
      username.dispose();
      password.dispose();
      return;
    }

    try {
      if (hasPassword && password.text.isEmpty) {
        throw Exception('Enter your current password to continue.');
      }
      final available = await auth.isUsernameAvailable(candidate);
      if (!available) {
        throw Exception('That username is unavailable.');
      }
      await context.read<SocketService>().changeUsername(
        newUsername: candidate,
        currentPassword: password.text,
      );
      await auth.refreshProfile();
      if (mounted) {
        NovynAlert.show(context, 'Username updated successfully.');
      }
    } catch (error) {
      if (mounted) {
        NovynAlert.show(
          context,
          error.toString().replaceFirst('Exception: ', '').replaceFirst('Bad state: ', ''),
          isError: true,
        );
      }
    } finally {
      username.dispose();
      password.dispose();
    }
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
