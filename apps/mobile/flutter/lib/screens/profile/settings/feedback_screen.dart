import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:novyn/widgets/novyn_alert.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_service.dart';
import '../../../theme/novyn_theme.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  static const _types = <(String, String, IconData, Color, Color)>[
    ('general', 'General', Icons.chat_bubble_outline_rounded, Color(0xFF6246EA), Color(0xFFECE7FD)),
    ('bug', 'Bug report', Icons.pest_control_rounded, Color(0xFFE25241), Color(0xFFFDECEB)),
    ('feature', 'Feature request', Icons.lightbulb_outline_rounded, Color(0xFFD69836), Color(0xFFFCF4E4)),
    ('praise', 'Praise', Icons.favorite_border_rounded, Color(0xFFD34F88), Color(0xFFFCE8F0)),
  ];

  final _messageController = TextEditingController();
  final _emailController = TextEditingController();
  String _type = 'general';
  int _rating = 0;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _emailController.text.trim().isNotEmpty) return;
      final accountEmail = context.read<AuthService>().user?.email.trim() ?? '';
      if (accountEmail.isNotEmpty) {
        setState(() => _emailController.text = accountEmail);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _messageController.text.trim();
    final email = _emailController.text.trim();
    if (message.length < 5) {
      context.showNovynAlert(const SnackBar(
        content: Text('Please write at least 5 characters.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (email.isNotEmpty &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      context.showNovynAlert(const SnackBar(
        content: Text('Enter a valid email address or leave it blank.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    setState(() => _sending = true);
    try {
      final result = await ApiService.submitFeedback(
        type: _type,
        message: message,
        email: email,
        rating: _rating == 0 ? null : _rating,
      );
      if (!mounted) return;

      final delivery = result['email'] is Map
          ? Map<String, dynamic>.from(result['email'] as Map)
          : <String, dynamic>{};
      final adminSent = delivery['adminSent'] == true;
      final receiptSent = delivery['receiptSent'] == true;
      final reference = result['id']?.toString() ?? 'saved';

      String statusText;
      if (adminSent && receiptSent) {
        statusText =
            'Your feedback was saved and delivered to the Novyn team. A receipt was sent to $email.';
      } else if (adminSent) {
        statusText =
            'Your feedback was saved and delivered to the Novyn team. No email receipt was sent.';
      } else if (receiptSent) {
        statusText =
            'Your feedback was saved. A receipt was sent to $email, but the team email could not be delivered right now.';
      } else {
        statusText =
            'Your feedback was saved (reference: $reference), but email delivery is not confirmed. The team can still review your submission.';
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          icon: const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF5E4AE3),
            size: 46,
          ),
          title: const Text('Feedback received'),
          content: Text(statusText),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF5E4AE3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      );

      if (mounted) {
        _messageController.clear();
        _rating = 0;
        setState(() => _type = 'general');
      }
    } catch (error) {
      if (!mounted) return;
      final errorMessage = error.toString().replaceFirst('Exception: ', '');
      context.showNovynAlert(SnackBar(
        content: Text(errorMessage),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _sectionLabel(String title, {String? optionalLabel}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 22, bottom: 10),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Color(0xFF6246EA),
            ),
          ),
          if (optionalLabel != null) ...[
            const SizedBox(width: 8),
            Text(
              optionalLabel,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF7E7A94),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _categoryCard(
    (String, String, IconData, Color, Color) item,
    Color ink,
    Color surface,
    Color border,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selected = _type == item.$1;
    final iconBg = dark ? item.$4.withValues(alpha: 0.16) : item.$5;

    return Expanded(
      child: InkWell(
        onTap: _sending ? null : () => setState(() => _type = item.$1),
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected
                  ? const Color(0xFF5E4AE3)
                  : border.withValues(alpha: 0.5),
              width: selected ? 1.8 : 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.$3, color: item.$4, size: 20),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  item.$2,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: ink,
                    height: 1.15,
                  ),
                ),
              ),
              if (selected)
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Color(0xFF5E4AE3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 14),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = dark ? NovynTheme.pageBg(context) : const Color(0xFFF4F0FB);
    final surface = dark ? const Color(0xFF191824) : Colors.white;
    final ink = dark ? const Color(0xFFF0EFFF) : const Color(0xFF1D1B26);
    final muted = dark ? const Color(0xFFAAA8C6) : const Color(0xFF7E7A94);
    final border = dark ? const Color(0xFF39345F) : const Color(0xFFE4DFFB);

    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    color: ink,
                    onPressed: () => Navigator.maybePop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Send Feedback',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            _sectionLabel('TYPE'),
            Row(
              children: [
                _categoryCard(_types[0], ink, surface, border),
                const SizedBox(width: 10),
                _categoryCard(_types[1], ink, surface, border),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _categoryCard(_types[2], ink, surface, border),
                const SizedBox(width: 10),
                _categoryCard(_types[3], ink, surface, border),
              ],
            ),
            _sectionLabel('RATING', optionalLabel: 'Optional'),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: border.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) {
                  final value = index + 1;
                  final selected = value <= _rating;
                  return InkWell(
                    onTap: _sending
                        ? null
                        : () => setState(
                            () => _rating = _rating == value ? 0 : value),
                    borderRadius: BorderRadius.circular(24),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        selected ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 32,
                        color: selected
                            ? const Color(0xFFF4A51C)
                            : muted.withValues(alpha: 0.6),
                      ),
                    ),
                  );
                }),
              ),
            ),
            _sectionLabel('FEEDBACK'),
            Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: border.withValues(alpha: 0.5)),
              ),
              child: TextField(
                controller: _messageController,
                enabled: !_sending,
                minLines: 5,
                maxLines: 7,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: ink, fontSize: 14.5),
                buildCounter: (context,
                        {required currentLength,
                        required isFocused,
                        maxLength}) =>
                    Padding(
                  padding: const EdgeInsets.only(right: 14, bottom: 10),
                  child: Text(
                    '$currentLength / 2000',
                    style: TextStyle(
                      color: muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                decoration: InputDecoration(
                  hintText: 'Tell us what is on your mind...',
                  hintStyle: TextStyle(color: muted, fontSize: 14.5),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            _sectionLabel('EMAIL FOR A REPLY', optionalLabel: 'Optional'),
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: border.withValues(alpha: 0.5)),
              ),
              child: TextField(
                controller: _emailController,
                enabled: !_sending,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                style: TextStyle(color: ink, fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: 'Email address',
                  hintStyle: TextStyle(color: muted, fontSize: 14.5),
                  prefixIcon: Icon(
                    Icons.mail_outline_rounded,
                    color: muted.withValues(alpha: 0.8),
                    size: 21,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _sending ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF5E4AE3),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      const Color(0xFF5E4AE3).withValues(alpha: 0.55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 20),
                label: Text(
                  _sending ? 'Sending...' : 'Send feedback',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
