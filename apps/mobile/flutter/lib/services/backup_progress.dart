import 'package:flutter/foundation.dart';

@immutable
class BackupProgress {
  const BackupProgress({
    required this.stage,
    required this.percent,
    this.completed = false,
    this.cancelled = false,
    this.failed = false,
  });

  final String stage;
  final int percent;
  final bool completed;
  final bool cancelled;
  final bool failed;
}

class BackupCancelledException implements Exception {
  const BackupCancelledException();

  @override
  String toString() => 'Backup cancelled.';
}

typedef BackupCancellationCheck = void Function();
typedef BackupProgressCallback = void Function(String stage, int percent);
