import '../models/chat_models.dart';

/// Stable timeline order used by Hive, SQLite and the active chat timeline.
/// Message IDs break timestamp ties so paging never depends on row return order.
int compareMessagesChronologically(Message left, Message right) {
  final byTimestamp = left.createdAt.compareTo(right.createdAt);
  if (byTimestamp != 0) return byTimestamp;
  return left.id.compareTo(right.id);
}

/// Whether [message] sorts strictly before the composite (timestamp, ID) cursor.
/// When no ID is supplied, retain the legacy strict timestamp-only boundary.
bool isMessageBeforeCursor(Message message, DateTime before, {String? beforeId}) {
  final byTimestamp = message.createdAt.compareTo(before);
  if (byTimestamp < 0) return true;
  if (byTimestamp > 0 || beforeId == null || beforeId.isEmpty) return false;
  return message.id.compareTo(beforeId) < 0;
}

/// Returns the latest [limit] messages in ascending timeline order.
List<Message> latestMessagesPage(Iterable<Message> source, {int limit = 50}) {
  if (limit <= 0) return <Message>[];
  final sorted = source.toList()..sort(compareMessagesChronologically);
  return sorted.length > limit ? sorted.sublist(sorted.length - limit) : sorted;
}
