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

/// Returns the insertion point that preserves chronological order. Equal
/// timestamps are ordered by message ID, matching [compareMessagesChronologically].
int messageInsertionIndex(List<Message> ordered, Message message) {
  var low = 0;
  var high = ordered.length;
  while (low < high) {
    final middle = (low + high) >> 1;
    if (compareMessagesChronologically(ordered[middle], message) <= 0) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  return low;
}

/// Copies the newest [limit] entries from an already ordered timeline.
List<Message> latestMessagesPageFromOrdered(
  List<Message> ordered, {
  int limit = 50,
}) {
  if (limit <= 0 || ordered.isEmpty) return <Message>[];
  final start = ordered.length > limit ? ordered.length - limit : 0;
  return ordered.sublist(start);
}

/// Copies the nearest older page from an already ordered timeline.
List<Message> olderMessagesPageFromOrdered(
  List<Message> ordered,
  DateTime before, {
  String? beforeId,
  int limit = 30,
}) {
  if (limit <= 0 || ordered.isEmpty) return <Message>[];

  // Find the first message that is not strictly before the cursor.
  var low = 0;
  var high = ordered.length;
  while (low < high) {
    final middle = (low + high) >> 1;
    if (isMessageBeforeCursor(
      ordered[middle],
      before,
      beforeId: beforeId,
    )) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }

  final end = low;
  if (end == 0) return <Message>[];
  final start = end > limit ? end - limit : 0;
  return ordered.sublist(start, end);
}
