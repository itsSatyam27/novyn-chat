/// Serializes session restore work across startup, app resume and
/// connectivity callbacks.
///
/// Returning the same in-flight Future is important: callers must wait for
/// credentials to finish restoring/rotating before opening a new socket.
class SessionRestoreCoordinator {
  Future<void>? _inFlight;

  Future<void> run(Future<void> Function() operation) {
    final pending = _inFlight;
    if (pending != null) return pending;

    late final Future<void> task;
    task = Future<void>.sync(operation).whenComplete(() {
      if (identical(_inFlight, task)) {
        _inFlight = null;
      }
    });
    _inFlight = task;
    return task;
  }
}


/// Prevents one short burst of backend failures from being mistaken for
/// independent, definitive session revocations.
class SessionRejectionTracker {
  SessionRejectionTracker({
    this.requiredRejections = 3,
    this.minimumInterval = const Duration(seconds: 30),
  })  : assert(requiredRejections > 0),
        assert(minimumInterval >= Duration.zero);

  final int requiredRejections;
  final Duration minimumInterval;
  int _count = 0;
  DateTime? _lastRejectionAt;

  int get count => _count;

  /// Returns true only after [requiredRejections] spaced rejections.
  /// Repeated responses in the same failure burst count once.
  bool record(DateTime now) {
    final previous = _lastRejectionAt;
    if (previous != null && now.difference(previous) < minimumInterval) {
      return false;
    }
    _lastRejectionAt = now;
    _count++;
    return _count >= requiredRejections;
  }

  void reset() {
    _count = 0;
    _lastRejectionAt = null;
  }
}
