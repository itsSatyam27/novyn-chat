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
