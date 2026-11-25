/// Normalizes call-history values shared by the API and Calls UI.
String normalizeCallType(Object? value) {
  final type = value?.toString().trim().toLowerCase().replaceAll(' ', '_') ?? '';
  return const {
    'video',
    'video_call',
    'video-call',
    'videocall',
    'video_chat',
    'camera',
    '1',
    'true',
  }.contains(type)
      ? 'video'
      : 'voice';
}

/// Stable local identifier for read/unread state, including older records
/// written before the server started attaching a callId.
String callLogStableId(Map<String, dynamic> log) {
  final callId = log['callId']?.toString().trim() ?? '';
  if (callId.isNotEmpty) return callId;
  return [
    log['callerId']?.toString().trim() ?? '',
    log['receiverId']?.toString().trim() ?? '',
    log['createdAt']?.toString().trim() ?? '',
    normalizeCallType(log['type']),
    log['status']?.toString().trim().toLowerCase() ?? '',
  ].join('|');
}

int countUnreadMissedCallLogs(
  Iterable<Map<String, dynamic>> logs,
  Set<String> readCallIds,
) {
  var count = 0;
  for (final log in logs) {
    final status = log['status']?.toString().trim().toLowerCase() ?? '';
    if (status != 'missed') continue;
    if (!readCallIds.contains(callLogStableId(log))) count++;
  }
  return count;
}
