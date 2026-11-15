import 'package:intl/intl.dart';

/// Formats a privacy-approved last-seen timestamp for compact presence labels.
/// A missing timestamp is intentionally shown as Offline; the client must not
/// infer or fabricate a time when the server withholds it.
String formatLastSeenLabel(DateTime? lastSeen, {DateTime? now}) {
  if (lastSeen == null) return 'Offline';
  final current = (now ?? DateTime.now()).toLocal();
  final seen = lastSeen.toLocal();
  final difference = current.difference(seen);
  if (difference.isNegative || difference.inMinutes < 1) {
    return 'Last seen just now';
  }
  if (difference.inMinutes < 60) return 'Last seen ${difference.inMinutes}m ago';
  if (difference.inHours < 24) return 'Last seen ${difference.inHours}h ago';
  final currentDate = DateTime(current.year, current.month, current.day);
  final seenDate = DateTime(seen.year, seen.month, seen.day);
  final calendarDays = currentDate.difference(seenDate).inDays;
  if (calendarDays == 1) return 'Last seen yesterday';
  if (calendarDays > 1 && calendarDays < 7) {
    return 'Last seen ${calendarDays}d ago';
  }
  final pattern = seen.year == current.year ? 'd MMM' : 'd MMM yyyy';
  return 'Last seen ${DateFormat(pattern).format(seen)}';
}
