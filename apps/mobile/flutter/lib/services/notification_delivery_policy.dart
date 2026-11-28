/// Decides whether the background FCM handler should create a local alert.
///
/// A message with an FCM notification payload is already rendered by Android's
/// system tray while the app is backgrounded. Rendering it locally as well
/// creates duplicate notifications. Data-only pushes still need local rendering.
bool shouldRenderLocalBackgroundNotification({
  required bool hasSystemNotification,
}) => !hasSystemNotification;
