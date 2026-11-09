import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/socket_service.dart';

class RiddleMessageCard extends StatefulWidget {
  final String messageId;
  final String fromUsername;
  final Map<String, dynamic> riddle;
  final bool isMe;

  const RiddleMessageCard({
    super.key,
    required this.messageId,
    required this.fromUsername,
    required this.riddle,
    required this.isMe,
  });

  @override
  State<RiddleMessageCard> createState() => _RiddleMessageCardState();
}

class _RiddleMessageCardState extends State<RiddleMessageCard> {
  final TextEditingController _answer = TextEditingController();
  bool _busy = false;
  String? _feedback;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    if (_busy || _answer.text.trim().isEmpty) return;
    setState(() { _busy = true; _feedback = null; });
    try {
      final result = await context.read<SocketService>().unlockRiddle(
        messageId: widget.messageId,
        fromUsername: widget.fromUsername,
        answer: _answer.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (result['ok'] != true) {
          _feedback = result['message']?.toString() ?? 'That answer is not right.';
        } else {
          _answer.clear();
        }
      });
    } catch (_) {
      if (mounted) setState(() { _busy = false; _feedback = 'Could not unlock this riddle.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = widget.riddle['unlocked'] == true;
    final triesLeft = (widget.riddle['triesLeft'] as num?)?.toInt() ?? 0;
    final maxTries = (widget.riddle['maxTries'] as num?)?.toInt() ?? 3;
    final exhausted = !unlocked && triesLeft <= 0;
    return Container(
      width: 250,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(unlocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded, size: 16),
            const SizedBox(width: 7),
            Text(unlocked ? 'UNLOCKED' : 'RIDDLE LOCK', style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
          ]),
          const SizedBox(height: 8),
          Text(
            unlocked ? widget.riddle['secret']?.toString() ?? '' : 'Secret message locked',
            style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(widget.riddle['question']?.toString() ?? '', style: const TextStyle(fontFamily: 'Inter', fontSize: 12)),
          if ((widget.riddle['hint']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 5),
            Text('Hint: ${widget.riddle['hint']}', style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF94A3B8))),
          ],
          if (!unlocked && !widget.isMe) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _answer,
              obscureText: true,
              enabled: !_busy && !exhausted,
              onSubmitted: (_) => _unlock(),
              decoration: InputDecoration(
                hintText: exhausted ? 'No attempts left' : 'Your answer',
                isDense: true,
                suffixIcon: IconButton(
                  onPressed: _busy || exhausted ? null : _unlock,
                  icon: _busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.lock_open_rounded, size: 18),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            if (_feedback != null) Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(_feedback!, style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFFDC2626))),
            ),
            const SizedBox(height: 5),
            Text('$triesLeft tries left', style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFF94A3B8))),
          ],
          if (widget.isMe && !unlocked)
            Text('Recipient gets $maxTries attempts', style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}
