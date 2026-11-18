import 'package:flutter/material.dart';
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

/// Returns the characteristic color for a given presence status:
/// - 'online': Emerald Green (0xFF10B981)
/// - 'away': Warm Amber (0xFFF59E0B)
/// - 'busy' / 'dnd': Rose Crimson (0xFFEC4899)
/// - 'invisible': Stealth Violet (0xFF8B5CF6)
/// - 'offline': Slate Grey (0xFF94A3B8)
Color presenceStatusColor(String? status, {bool isOnline = true}) {
  if (!isOnline) {
    return const Color(0xFF94A3B8);
  }
  switch (status?.trim().toLowerCase()) {
    case 'away':
      return const Color(0xFFF59E0B);
    case 'busy' || 'dnd':
      return const Color(0xFFEC4899);
    case 'invisible':
      return const Color(0xFF8B5CF6);
    case 'offline':
      return const Color(0xFF94A3B8);
    case 'online':
    default:
      return const Color(0xFF10B981);
  }
}

/// A sleek vertical indicator strip ("patli patti") placed on the left edge
/// of chat rows or headers to indicate user presence while keeping avatars clean.
class PresenceIndicatorBar extends StatelessWidget {
  final bool isOnline;
  final String? status;
  final double width;
  final double height;
  final EdgeInsetsGeometry margin;

  const PresenceIndicatorBar({
    super.key,
    this.isOnline = true,
    this.status,
    this.width = 3.5,
    this.height = 26.0,
    this.margin = const EdgeInsets.only(right: 10),
  });

  @override
  Widget build(BuildContext context) {
    final color = presenceStatusColor(status, isOnline: isOnline);
    final normalized = status?.trim().toLowerCase();
    final isOffline = !isOnline || normalized == 'offline';

    return Container(
      key: const ValueKey('presence-indicator-bar'),
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: isOffline ? color.withValues(alpha: 0.38) : color,
        borderRadius: BorderRadius.circular(999),
        boxShadow: isOffline
            ? null
            : [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 4,
                  spreadRadius: 0.5,
                ),
              ],
      ),
    );
  }
}
