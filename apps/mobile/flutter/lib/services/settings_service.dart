import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Lightweight saved session — no password stored, just identity info
class SavedSession {
  final String uid;
  final String email;
  final String name;
  final String initial;

  const SavedSession({
    required this.uid,
    required this.email,
    required this.name,
    required this.initial,
  });

  factory SavedSession.fromJson(Map<String, dynamic> j) => SavedSession(
        uid: j['uid'] ?? '',
        email: j['email'] ?? '',
        name: j['name'] ?? '',
        initial: j['initial'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'name': name,
        'initial': initial,
      };
}

class SettingsService extends ChangeNotifier {
  static const _kNotifications = 'notifications_on';
  static const _kMessagePreview = 'message_preview';
  static const _kChatLinkPreviews = 'chat_link_previews';
  static const _kReadReceipts = 'read_receipts';
  static const _kOnlineStatus = 'online_status';
  static const _kThemeMode = 'theme_mode';
  static const _kDisplayName = 'display_name';
  static const _kBio = 'bio';
  static const _kSavedSessions = 'saved_sessions'; // JSON list
  
  // New settings
  static const _kInAppSounds = 'in_app_sounds';
  static const _kInAppVibration = 'in_app_vibration';
  static const _kGroupNotifications = 'group_notifications';
  static const _kQuietHoursStart = 'notification_quiet_hours_start';
  static const _kQuietHoursEnd = 'notification_quiet_hours_end';
  static const _kQuietHoursOffsetMinutes = 'notification_quiet_hours_offset';
  static const _kAutoDownloadWifi = 'auto_download_wifi';
  static const _kAutoDownloadMobile = 'auto_download_mobile';
  static const _kPhotoQuality = 'photo_quality';
  static const _kLanguage = 'language';
  static const _kTimeFormat = 'chat_time_format';
  static const _kFontSize = 'font_size';
  static const _kChatLabelSize = 'chat_label_size';
  static const _kAccentColor = 'appearance_accent_color';
  static const _kAccentColorEnabled = 'appearance_accent_color_enabled';
  static const _kDockStyle = 'dock_style';
  static const _kAlertStyle = 'alert_style';
  static const _kCallMiniStyle = 'call_mini_style';
  static const _kTwoFactorAuth = 'two_factor_auth';
  static const _kLastSeen = 'last_seen_visibility';
  static const _kProfilePhoto = 'profile_photo_visibility';
  static const _kBlockedUids = 'blocked_uids';
  static const _kFavoriteChatIds = 'favorite_chat_ids';
  static const _kNotificationTone = 'notification_tone';
  static const _kCallRingtone = 'call_ringtone';
  static const _kVibrationPattern = 'vibration_pattern';
  static const _kHapticIntensity = 'haptic_intensity';
  static const _kHapticNavigation = 'haptic_navigation';
  static const _kHapticTyping = 'haptic_typing';
  static const _kHapticChat = 'haptic_chat';
  static const _kHapticButtons = 'haptic_buttons';
  static const _kHapticNotifications = 'haptic_notifications';
  static const _kHapticCalls = 'haptic_calls';
  static const _kAppLockEnabled = 'app_lock_enabled';
  static const _kAppLockTimeout = 'app_lock_timeout';
  static const _kAppLockPin = 'app_lock_pin';
  static const _secureAppLockPin = 'app_lock_pin';
  static const _securePanicPin = 'panic_pin';
  static const _secureAppLockFailures = 'app_lock_failed_attempts';
  static const _secureAppLockUntil = 'app_lock_locked_until';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: false,
      migrateWithBackup: true,
    ),
  );
  static const _kStealthMode = 'stealth_mode_enabled';
  static const _kStealthPreviousNotificationPrivacy = 'stealth_previous_notification_privacy';
  static const _kPanicPin = 'panic_pin';
  static const _kHideNotificationContent = 'hide_notification_content';
  static const _kStealthIcon = 'stealth_icon_enabled';
  static const _kCustomNotificationPath = 'custom_notification_path';
  static const _kCustomRingtonePath = 'custom_ringtone_path';
  static const _kRegion = 'user_region';
  static const _kHighContrast = 'accessibility_high_contrast';
  static const _kReduceMotion = 'accessibility_reduce_motion';
  static const _kBusyPreviousPresence = 'busy_previous_presence_mode';
  static const _kDoNotDisturb = 'do_not_disturb_enabled';
  static const _kSmartPresenceOverrides = 'smart_presence_overrides_v1';
  static const _kActiveSmartPresenceMode = 'active_smart_presence_mode_v1';

  // Settings-screen shortcuts are account-scoped and never change the setting
  // values themselves. Keep the catalog limited to actions with real setters.
  static const int maxQuickToggles = 4;
  static const List<String> defaultQuickToggleIds = [
    'app_lock',
    'do_not_disturb',
    'dark_mode',
    'stealth_mode',
  ];
  static const Set<String> supportedQuickToggleIds = {
    'app_lock',
    'do_not_disturb',
    'read_receipts',
    'in_app_sounds',
    'in_app_vibration',
    'group_notifications',
    'dark_mode',
    'stealth_mode',
  };

  late SharedPreferences _prefs;
  bool _loaded = false;
  bool _secureStorageReadFailed = false;

  Future<String?> _readSecureValue(String key) async {
    if (_secureStorageReadFailed) return null;
    try {
      return await _secureStorage
          .read(key: key)
          .timeout(const Duration(seconds: 2));
    } catch (error) {
      _secureStorageReadFailed = true;
      debugPrint('[NovynSettings] Secure storage read failed: $error');
      return null;
    }
  }

  Future<bool> _writeSecureValue(String key, String value) async {
    if (_secureStorageReadFailed) return false;
    try {
      await _secureStorage
          .write(key: key, value: value)
          .timeout(const Duration(seconds: 2));
      return true;
    } catch (error) {
      _secureStorageReadFailed = true;
      debugPrint('[NovynSettings] Secure storage write failed: $error');
      return false;
    }
  }

  Future<void> _deleteSecureValue(String key) async {
    if (_secureStorageReadFailed) return;
    try {
      await _secureStorage
          .delete(key: key)
          .timeout(const Duration(seconds: 2));
    } catch (error) {
      _secureStorageReadFailed = true;
      debugPrint('[NovynSettings] Secure storage delete failed: $error');
    }
  }

  // ── Settings state ──────────────────────────────────────────────────────
  bool _notificationsOn = true;
  bool _messagePreview = true;
  bool _chatLinkPreviews = true;
  bool _readReceipts = true;
  bool _onlineStatus = true;
  ThemeMode _themeMode = ThemeMode.dark;
  String _displayName = '';
  String _bio = '';
  List<SavedSession> _savedSessions = [];
  
  // New settings state
  bool _inAppSounds = true;
  bool _chatEnterToSend = true;
  bool _inAppVibration = true;
  bool _groupNotifications = true;
  Map<String, bool> _notificationPreferences = {
    ...notificationPreferenceDefaults,
  };
  String _quietHoursStart = '22:00';
  String _quietHoursEnd = '07:00';
  int _quietHoursOffsetMinutes = 0;
  String _autoDownloadWifi = 'all'; // 'all', 'photos', 'none'
  String _autoDownloadMobile = 'photos'; // 'all', 'photos', 'none'
  String _photoQuality = 'high'; // 'high', 'medium', 'low'
  String _language = 'en'; // Language code
  String _timeFormat = '12h'; // '12h' or '24h'
  double _fontSize = 0.85; // Default accessibility scale (85%)
  double _chatLabelSize = 1.0;
  int _accentColorValue = 0xFF6D5DFC;
  bool _accentColorEnabled = true;
  String _dockStyle = 'slide_pill';
  String _alertStyle = 'snackbar';
  String _callMiniStyle = 'top_banner';
  bool _twoFactorAuth = false;
  String _lastSeenVisibility = 'everyone'; // 'everyone', 'contacts', 'nobody'
  String _profilePhotoVisibility = 'everyone'; // 'everyone', 'contacts', 'nobody'
  List<String> _blockedUids = [];
  List<String> _favoriteChatIds = [];
  String _notificationTone = 'Aurora'; // Default tone
  String _callRingtone = 'Binary'; // Default ringtone
  String _vibrationPattern = 'standard'; // standard, staccato, heartbeat, none
  double _hapticIntensity = 0.8; // 0.0 to 1.0
  bool _hapticNavigation = true;
  bool _hapticTyping = true;
  bool _hapticChat = true;
  bool _hapticButtons = true;
  bool _hapticNotifications = true;
  bool _hapticCalls = true;
  double _messageVolume = 0.8;
  double _callVolume = 0.85;
  bool _appLockEnabled = false;
  int _appLockTimeout = 0; // minutes (0 = immediately)
  String? _appLockPin; // Stored PIN
  bool _isLocked = false; // Transient state
  int _appLockFailedAttempts = 0;
  DateTime? _appLockLockedUntil;
  String? _customNotificationPath;
  String? _customRingtonePath;
  String _region = 'India';
  bool _stealthModeEnabled = false;
  String? _panicPin;
  bool _hideNotificationContent = false;
  bool _decoyMode = false;
  bool _stealthIconEnabled = false;
  bool _highContrast = false;
  bool _reduceMotion = false;
  String? _busyPreviousPresenceMode;
  bool _doNotDisturbEnabled = false;
  Map<String, Map<String, dynamic>> _smartPresenceOverrides = {};
  String _activeSmartPresenceMode = 'online';

  static const Map<String, String> notificationPreferenceStorageKeys = {
    'directMessagesEnabled': 'notification_direct_messages',
    'groupMessagesEnabled': 'notification_group_messages',
    'mentionsRepliesEnabled': 'notification_mentions_replies',
    'friendRequestsEnabled': 'notification_friend_requests',
    'friendRequestAcceptedEnabled': 'notification_friend_request_accepted',
    'groupInvitationsEnabled': 'notification_group_invitations',
    'voiceCallsEnabled': 'notification_voice_calls',
    'videoCallsEnabled': 'notification_video_calls',
    'missedCallsEnabled': 'notification_missed_calls',
    'gameInvitationsEnabled': 'notification_game_invitations',
    'gameTurnEnabled': 'notification_game_turn',
    'gameResultsEnabled': 'notification_game_results',
    'quietHoursEnabled': 'notification_quiet_hours_enabled',
    'notificationSoundEnabled': 'notification_sound_enabled',
    'notificationVibrationEnabled': 'notification_vibration_enabled',
  };
  static const Map<String, bool> notificationPreferenceDefaults = {
    'directMessagesEnabled': true,
    'groupMessagesEnabled': true,
    'mentionsRepliesEnabled': true,
    'friendRequestsEnabled': true,
    'friendRequestAcceptedEnabled': true,
    'groupInvitationsEnabled': true,
    'voiceCallsEnabled': true,
    'videoCallsEnabled': true,
    'missedCallsEnabled': true,
    'gameInvitationsEnabled': true,
    'gameTurnEnabled': true,
    'gameResultsEnabled': true,
    'quietHoursEnabled': false,
    'notificationSoundEnabled': true,
    'notificationVibrationEnabled': true,
  };

  static String _quickToggleStorageKey(String accountKey) {
    final normalized = accountKey.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_-]'),
      '_',
    );
    final safeAccountKey = normalized.isEmpty ? 'guest' : normalized;
    return 'quick_toggles_v1_$safeAccountKey';
  }

  /// Removes unsupported/duplicate shortcut IDs and enforces the visible cap.
  static List<String> sanitizeQuickToggleIds(Iterable<String> ids) {
    final result = <String>[];
    for (final id in ids) {
      if (!supportedQuickToggleIds.contains(id) || result.contains(id)) continue;
      result.add(id);
      if (result.length == maxQuickToggles) break;
    }
    return List<String>.unmodifiable(result);
  }

  /// Returns the saved shortcut order for one account, or the recommended
  /// defaults when that account has not customized the Settings screen yet.
  List<String> quickToggleIdsFor(String accountKey) {
    if (!_loaded) {
      return List<String>.unmodifiable(defaultQuickToggleIds);
    }
    final saved = _prefs.getStringList(_quickToggleStorageKey(accountKey));
    if (saved == null) {
      return List<String>.unmodifiable(defaultQuickToggleIds);
    }
    return sanitizeQuickToggleIds(saved);
  }

  /// Saves only shortcut visibility/order; it does not toggle any setting.
  /// One shortcut must remain available so the Settings screen stays editable.
  Future<void> setQuickToggleIdsFor(
    String accountKey,
    Iterable<String> ids,
  ) async {
    if (!_loaded) {
      throw StateError('Settings must be loaded before saving quick toggles.');
    }
    final cleaned = <String>[];
    for (final id in ids) {
      if (!supportedQuickToggleIds.contains(id) || cleaned.contains(id)) continue;
      cleaned.add(id);
    }
    if (cleaned.isEmpty) {
      throw ArgumentError('At least one quick toggle must remain visible.');
    }
    if (cleaned.length > maxQuickToggles) {
      throw ArgumentError('A maximum of $maxQuickToggles quick toggles is allowed.');
    }
    await _prefs.setStringList(_quickToggleStorageKey(accountKey), cleaned);
    notifyListeners();
  }

  // ── Getters ─────────────────────────────────────────────────────────────
  bool get notificationsOn => _notificationsOn;
  bool get messagePreview => _messagePreview;
  bool get chatLinkPreviews => _chatLinkPreviews;
  bool get readReceipts => _readReceipts;
  bool get onlineStatus => _onlineStatus;
  ThemeMode get themeMode => _themeMode;
  String get displayName => _displayName;
  String get bio => _bio;
  bool get isLoaded => _loaded;
  List<SavedSession> get savedSessions => _savedSessions;
  
  // New getters
  bool get inAppSounds => _inAppSounds;
  bool get chatEnterToSend => _chatEnterToSend;
  bool get inAppVibration => _inAppVibration;
  bool get groupNotifications => _groupNotifications;
  bool notificationPreference(String key) =>
      _notificationPreferences[key] ?? notificationPreferenceDefaults[key] ?? false;
  Map<String, dynamic> notificationPreferencesPayload() => {
    ..._notificationPreferences,
    'quietHoursStart': _quietHoursStart,
    'quietHoursEnd': _quietHoursEnd,
    'quietHoursOffsetMinutes': _quietHoursOffsetMinutes,
  };
  String get quietHoursStart => _quietHoursStart;
  String get quietHoursEnd => _quietHoursEnd;
  int get quietHoursOffsetMinutes => _quietHoursOffsetMinutes;

  Future<void> setNotificationPreference(String key, bool value) async {
    final storageKey = notificationPreferenceStorageKeys[key];
    if (storageKey == null) {
      throw ArgumentError.value(key, 'key', 'Unsupported notification preference');
    }
    _notificationPreferences[key] = value;
    await _prefs.setBool(storageKey, value);
    notifyListeners();
  }

  Future<void> hydrateNotificationPreferencesFromServer(
    Map<String, dynamic> values,
  ) async {
    var changed = false;
    for (final entry in notificationPreferenceStorageKeys.entries) {
      final value = values[entry.key];
      if (value is bool) {
        _notificationPreferences[entry.key] = value;
        await _prefs.setBool(entry.value, value);
        changed = true;
      }
    }
    final start = values['quietHoursStart'];
    final end = values['quietHoursEnd'];
    final offset = values['quietHoursOffsetMinutes'];
    if (start is String && RegExp(r'^([01]\\d|2[0-3]):[0-5]\\d
  String get autoDownloadWifi => _autoDownloadWifi;
  String get autoDownloadMobile => _autoDownloadMobile;
  String get notificationTone => _notificationTone;
  String get callRingtone => _callRingtone;
  String? get customNotificationPath => _customNotificationPath;
  String? get customRingtonePath => _customRingtonePath;
  String get region => _region;
  String get language => _language;
  String get timeFormat => _timeFormat;
  String get vibrationPattern => _vibrationPattern;
  double get hapticIntensity => _hapticIntensity;
  bool get hapticNavigation => _hapticNavigation;
  bool get hapticTyping => _hapticTyping;
  bool get hapticChat => _hapticChat;
  bool get hapticButtons => _hapticButtons;
  bool get hapticNotifications => _hapticNotifications;
  bool get hapticCalls => _hapticCalls;
  bool hapticCategoryEnabled(String category) => switch (category) {
    'navigation' => _hapticNavigation,
    'typing' => _hapticTyping,
    'chat' => _hapticChat,
    'notifications' => _hapticNotifications,
    'calls' => _hapticCalls,
    _ => _hapticButtons,
  };
  double get messageVolume => _messageVolume;
  double get callVolume => _callVolume;
  String get photoQuality => _photoQuality;
  double get fontSize => _fontSize;
  double get chatLabelSize => _chatLabelSize;
  int get accentColorValue => _accentColorValue;
  bool get accentColorEnabled => _accentColorEnabled;
  String get dockStyle => _dockStyle;
  String get alertStyle => _alertStyle;
  String get callMiniStyle => _callMiniStyle;
  bool get twoFactorAuth => _twoFactorAuth;
  String get lastSeenVisibility => _stealthModeEnabled ? 'nobody' : _lastSeenVisibility;
  String get profilePhotoVisibility => _stealthModeEnabled ? 'nobody' : _profilePhotoVisibility;
  String get configuredLastSeenVisibility => _lastSeenVisibility;
  String get configuredProfilePhotoVisibility => _profilePhotoVisibility;
  List<String> get blockedUids => _blockedUids;
  List<String> get favoriteChatIds => List.unmodifiable(_favoriteChatIds);
  bool get appLockEnabled => _appLockEnabled;
  int get appLockTimeout => _appLockTimeout;
  String? get appLockPin => _appLockPin;
  bool get secureStorageAvailable => !_secureStorageReadFailed;
  bool get isLocked => _isLocked;
  int get appLockFailedAttempts => _appLockFailedAttempts;
  Duration get appLockRemaining {
    final until = _appLockLockedUntil;
    if (until == null) return Duration.zero;
    final remaining = until.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
  bool get isAppLockCoolingDown => appLockRemaining > Duration.zero;
  bool get stealthModeEnabled => _stealthModeEnabled;
  String? get panicPin => _panicPin;
  bool get hideNotificationContent => _hideNotificationContent;
  bool get decoyMode => _decoyMode;
  bool get stealthIconEnabled => _stealthIconEnabled;
  bool get highContrast => _highContrast;
  bool get reduceMotion => _reduceMotion;
  String? get busyPreviousPresenceMode => _busyPreviousPresenceMode;
  bool get doNotDisturbEnabled => _doNotDisturbEnabled;
  String get activeSmartPresenceMode => _activeSmartPresenceMode;
  static const Set<String> _smartPresenceServerKeys = {
    'callsEnabled', 'callPrivacy', 'messagePrivacy', 'profilePhotoPrivacy', 'presencePrivacy',
    'discoverPrivacy', 'groupInvitePrivacy', 'friendRequestPrivacy',
    'readReceiptsEnabled', 'typingIndicatorsEnabled', 'notificationsEnabled',
    'messagePreviewEnabled', 'groupNotificationsEnabled',
  };
  static const Set<String> _smartPresenceLocalKeys = {'inAppSoundsEnabled', 'inAppVibrationEnabled'};
  static const Set<String> _smartPresenceAllowedKeys = {
    ..._smartPresenceServerKeys, ..._smartPresenceLocalKeys,
  };
  static String normalizeSmartPresenceMode(String mode) {
    final value = mode.trim().toLowerCase();
    if (value == 'away' || value == 'idle') return 'idle';
    if (value == 'dnd') return 'busy';
    if (value == 'offline') return 'invisible';
    return const {'online', 'busy', 'invisible'}.contains(value) ? value : 'online';
  }
  static String presenceStatusForSmartMode(String mode) =>
      normalizeSmartPresenceMode(mode) == 'idle' ? 'away' : normalizeSmartPresenceMode(mode);
  static Map<String, dynamic> smartPresenceDefaults(String mode) {
    switch (normalizeSmartPresenceMode(mode)) {
      case 'idle':
        return {
          'callsEnabled': true, 'callPrivacy': 'friends', 'messagePrivacy': 'friends',
          'profilePhotoPrivacy': 'friends', 'presencePrivacy': 'friends',
          'discoverPrivacy': 'friends', 'groupInvitePrivacy': 'friends',
          'friendRequestPrivacy': 'mutuals',
          'readReceiptsEnabled': true, 'typingIndicatorsEnabled': true,
          'notificationsEnabled': true, 'messagePreviewEnabled': true,
          'groupNotificationsEnabled': true, 'inAppSoundsEnabled': true,
          'inAppVibrationEnabled': true,
        };
      case 'busy':
        return {
          'callsEnabled': true, 'callPrivacy': 'nobody', 'messagePrivacy': 'friends',
          'profilePhotoPrivacy': 'friends', 'presencePrivacy': 'friends',
          'discoverPrivacy': 'friends', 'groupInvitePrivacy': 'friends',
          'friendRequestPrivacy': 'mutuals',
          'readReceiptsEnabled': false, 'typingIndicatorsEnabled': false,
          'notificationsEnabled': false, 'messagePreviewEnabled': false,
          'groupNotificationsEnabled': false, 'inAppSoundsEnabled': false,
          'inAppVibrationEnabled': false,
        };
      case 'invisible':
        return {
          'callsEnabled': false, 'callPrivacy': 'nobody', 'messagePrivacy': 'friends',
          'profilePhotoPrivacy': 'nobody', 'presencePrivacy': 'nobody',
          'discoverPrivacy': 'nobody', 'groupInvitePrivacy': 'nobody',
          'friendRequestPrivacy': 'nobody',
          'readReceiptsEnabled': false, 'typingIndicatorsEnabled': false,
          'notificationsEnabled': false, 'messagePreviewEnabled': false,
          'groupNotificationsEnabled': false, 'inAppSoundsEnabled': false,
          'inAppVibrationEnabled': false,
        };
      case 'online':
      default:
        return {
          'callsEnabled': true, 'callPrivacy': 'everyone', 'messagePrivacy': 'everyone',
          'profilePhotoPrivacy': 'everyone', 'presencePrivacy': 'everyone',
          'discoverPrivacy': 'everyone', 'groupInvitePrivacy': 'everyone',
          'friendRequestPrivacy': 'everyone',
          'readReceiptsEnabled': true, 'typingIndicatorsEnabled': true,
          'notificationsEnabled': true, 'messagePreviewEnabled': true,
          'groupNotificationsEnabled': true, 'inAppSoundsEnabled': true,
          'inAppVibrationEnabled': true,
        };
    }
  }
  Map<String, dynamic> smartPresencePolicyFor(String mode) {
    final key = normalizeSmartPresenceMode(mode);
    return {...smartPresenceDefaults(key), ...?_smartPresenceOverrides[key]};
  }
  bool hasSmartPresenceCustomizations(String mode) =>
      _smartPresenceOverrides[normalizeSmartPresenceMode(mode)]?.isNotEmpty ?? false;
  static Map<String, dynamic> smartPresenceServerFields(Map<String, dynamic> policy) => {
    for (final entry in policy.entries)
      if (_smartPresenceServerKeys.contains(entry.key)) entry.key: entry.value,
  };
  Future<void> saveSmartPresenceOverride(String mode, String key, dynamic value) async {
    if (!_smartPresenceAllowedKeys.contains(key)) {
      throw ArgumentError.value(key, 'key', 'Unsupported Smart Presence setting');
    }
    final normalized = normalizeSmartPresenceMode(mode);
    final overrides = _smartPresenceOverrides.putIfAbsent(normalized, () => <String, dynamic>{});
    if (smartPresenceDefaults(normalized)[key] == value) {
      overrides.remove(key);
    } else {
      overrides[key] = value;
    }
    if (overrides.isEmpty) _smartPresenceOverrides.remove(normalized);
    await _prefs.setString(_kSmartPresenceOverrides, jsonEncode(_smartPresenceOverrides));
    notifyListeners();
  }
  Future<void> hydrateSmartPresenceModeFromServer(
    String mode,
    Map<String, dynamic> serverPolicy,
  ) async {
    final normalized = normalizeSmartPresenceMode(mode);
    final defaults = smartPresenceDefaults(normalized);
    final previous = _smartPresenceOverrides[normalized] ?? const <String, dynamic>{};
    final next = <String, dynamic>{};
    const privacyValues = {'everyone', 'friends', 'nobody', 'mutuals'};

    for (final key in _smartPresenceServerKeys) {
      if (!serverPolicy.containsKey(key)) continue;
      final value = serverPolicy[key];
      final defaultValue = defaults[key];
      if (defaultValue is bool && value is bool) {
        if (value != defaultValue) next[key] = value;
      } else if (defaultValue is String &&
          value is String &&
          privacyValues.contains(value)) {
        if (value != defaultValue) next[key] = value;
      }
    }
    for (final key in _smartPresenceLocalKeys) {
      if (previous.containsKey(key)) next[key] = previous[key];
    }

    if (next.isEmpty) {
      _smartPresenceOverrides.remove(normalized);
    } else {
      _smartPresenceOverrides[normalized] = next;
    }
    await _prefs.setString(_kSmartPresenceOverrides, jsonEncode(_smartPresenceOverrides));
    notifyListeners();
  }

  Future<void> recordActiveSmartPresenceOverride(String key, dynamic value) =>
      saveSmartPresenceOverride(_activeSmartPresenceMode, key, value);
  Future<void> resetSmartPresenceOverrides(String mode) async {
    _smartPresenceOverrides.remove(normalizeSmartPresenceMode(mode));
    await _prefs.setString(_kSmartPresenceOverrides, jsonEncode(_smartPresenceOverrides));
    notifyListeners();
  }
  Future<void> applySmartPresenceLocalPolicy(String mode, {Map<String, dynamic>? policy}) async {
    final normalized = normalizeSmartPresenceMode(mode);
    final values = policy ?? smartPresencePolicyFor(normalized);
    _activeSmartPresenceMode = normalized;
    _notificationsOn = values['notificationsEnabled'] != false;
    _messagePreview = values['messagePreviewEnabled'] != false;
    _groupNotifications = values['groupNotificationsEnabled'] != false;
    _readReceipts = values['readReceiptsEnabled'] != false;
    _inAppSounds = values['inAppSoundsEnabled'] != false;
    _inAppVibration = values['inAppVibrationEnabled'] != false;
    final presence = values['presencePrivacy']?.toString() ?? 'everyone';
    final photo = values['profilePhotoPrivacy']?.toString() ?? 'everyone';
    _lastSeenVisibility = presence == 'friends' ? 'contacts' : presence;
    _profilePhotoVisibility = photo == 'friends' ? 'contacts' : photo;
    await Future.wait([
      _prefs.setString(_kActiveSmartPresenceMode, normalized),
      _prefs.setBool(_kNotifications, _notificationsOn),
      _prefs.setBool(_kMessagePreview, _messagePreview),
      _prefs.setBool(_kGroupNotifications, _groupNotifications),
      _prefs.setBool(_kReadReceipts, _readReceipts),
      _prefs.setBool(_kInAppSounds, _inAppSounds),
      _prefs.setBool(_kInAppVibration, _inAppVibration),
      _prefs.setString(_kLastSeen, _lastSeenVisibility),
      _prefs.setString(_kProfilePhoto, _profilePhotoVisibility),
    ]);
    notifyListeners();
  }
  Future<void> setActiveSmartPresenceMode(String mode) async {
    _activeSmartPresenceMode = normalizeSmartPresenceMode(mode);
    await _prefs.setString(_kActiveSmartPresenceMode, _activeSmartPresenceMode);
    notifyListeners();
  }

  // ── Load from disk ───────────────────────────────────────────────────────
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _notificationsOn = _prefs.getBool(_kNotifications) ?? true;
    _messagePreview = _prefs.getBool(_kMessagePreview) ?? true;
    _chatLinkPreviews = _prefs.getBool(_kChatLinkPreviews) ?? true;
    _readReceipts = _prefs.getBool(_kReadReceipts) ?? true;
    _onlineStatus = _prefs.getBool(_kOnlineStatus) ?? true;
    _themeMode = ThemeMode.values[_prefs.getInt(_kThemeMode) ?? ThemeMode.light.index];
    _displayName = _prefs.getString(_kDisplayName) ?? '';
    _bio = _prefs.getString(_kBio) ?? '';
    
    // Load new settings
    _inAppSounds = _prefs.getBool(_kInAppSounds) ?? true;
    _chatEnterToSend = _prefs.getBool('chat_enter_to_send') ?? true;
    _inAppVibration = _prefs.getBool(_kInAppVibration) ?? true;
    _groupNotifications = _prefs.getBool(_kGroupNotifications) ?? true;
    _notificationPreferences = {...notificationPreferenceDefaults};
    for (final entry in notificationPreferenceStorageKeys.entries) {
      _notificationPreferences[entry.key] =
          _prefs.getBool(entry.value) ?? notificationPreferenceDefaults[entry.key]!;
    }
    _quietHoursStart = _prefs.getString(_kQuietHoursStart) ?? '22:00';
    _quietHoursEnd = _prefs.getString(_kQuietHoursEnd) ?? '07:00';
    _quietHoursOffsetMinutes = (_prefs.getInt(_kQuietHoursOffsetMinutes) ??
        DateTime.now().timeZoneOffset.inMinutes).clamp(-840, 840);
    _autoDownloadWifi = _prefs.getString(_kAutoDownloadWifi) ?? 'all';
    _autoDownloadMobile = _prefs.getString(_kAutoDownloadMobile) ?? 'photos';
    _photoQuality = _prefs.getString(_kPhotoQuality) ?? 'high';
    _language = _prefs.getString(_kLanguage) ?? 'en';
    final savedTimeFormat = _prefs.getString(_kTimeFormat) ?? '12h';
    _timeFormat = savedTimeFormat == '24h' ? '24h' : '12h';
    _fontSize = (_prefs.getDouble(_kFontSize) ?? 0.85).clamp(0.75, 1.25).toDouble();
    _chatLabelSize = (_prefs.getDouble(_kChatLabelSize) ?? 1.0).clamp(0.8, 1.4).toDouble();
    _accentColorValue = _prefs.getInt(_kAccentColor) ?? 0xFF6D5DFC;
    _accentColorEnabled = _prefs.getBool(_kAccentColorEnabled) ?? true;
    const alertStyles = {'snackbar', 'top_banner', 'capsule', 'switch_card', 'centre_hud', 'countdown_card'};
    final savedAlertStyle = _prefs.getString(_kAlertStyle) ?? 'snackbar';
    _alertStyle = alertStyles.contains(savedAlertStyle) ? savedAlertStyle : 'snackbar';
    if (_alertStyle != savedAlertStyle) await _prefs.setString(_kAlertStyle, _alertStyle);
    const callMiniStyles = {
      'top_banner', 'floating_avatar', 'compact_pill',
      'bottom_bar', 'video_card', 'edge_chip',
    };
    const legacyCallMiniStyles = <String, String>{
      'floating_bar': 'top_banner',
      'glass_card': 'video_card',
      'accent_strip': 'top_banner',
      'avatar_bubble': 'floating_avatar',
      'video_focus': 'video_card',
    };
    final savedCallMiniStyle = _prefs.getString(_kCallMiniStyle) ?? 'top_banner';
    _callMiniStyle = callMiniStyles.contains(savedCallMiniStyle)
        ? savedCallMiniStyle
        : legacyCallMiniStyles[savedCallMiniStyle] ?? 'top_banner';
    if (_callMiniStyle != savedCallMiniStyle) {
      await _prefs.setString(_kCallMiniStyle, _callMiniStyle);
    }
    const dockStyles = [
      'slide_pill',
      'expand_capsule',
      'edge_to_edge',
      'dot_minimal',
      'soft_glow_glass',
      'liquid_stretch',
      'flip_tiles',
      'draw_ring',
    ];
    const legacyDockStyles = <String, String>{
      'floating_pill': 'slide_pill',
      'rounded_bar': 'slide_pill',
      'minimal': 'dot_minimal',
      'glass': 'soft_glow_glass',
      'sliding': 'slide_pill',
      'elevated': 'expand_capsule',
      'full_width': 'edge_to_edge',
      'glow': 'soft_glow_glass',
    };
    final savedDockStyle = _prefs.getString(_kDockStyle) ?? 'slide_pill';
    if (dockStyles.contains(savedDockStyle)) {
      _dockStyle = savedDockStyle;
    } else {
      _dockStyle = legacyDockStyles[savedDockStyle] ?? 'slide_pill';
      await _prefs.setString(_kDockStyle, _dockStyle);
    }
    _twoFactorAuth = _prefs.getBool(_kTwoFactorAuth) ?? false;
    _lastSeenVisibility = _prefs.getString(_kLastSeen) ?? 'everyone';
    _profilePhotoVisibility = _prefs.getString(_kProfilePhoto) ?? 'everyone';
    _blockedUids = _prefs.getStringList(_kBlockedUids) ?? [];
    _favoriteChatIds = _prefs.getStringList(_kFavoriteChatIds) ?? [];
    _notificationTone = _prefs.getString(_kNotificationTone) ?? 'Aurora';
    _callRingtone = _prefs.getString(_kCallRingtone) ?? 'Binary';
    _customNotificationPath = _prefs.getString(_kCustomNotificationPath);
    _customRingtonePath = _prefs.getString(_kCustomRingtonePath);
    _region = _prefs.getString(_kRegion) ?? _detectDeviceRegion();
    
    // Recovery: If region is "Germany" (previous bug) or "United States" (old default),
    // and we are actually in India (via offset), force reset to India.
    if ((_region == 'Germany' || _region == 'United States') && _detectDeviceRegion() == 'India') {
      _region = 'India';
    }
    _language = _prefs.getString(_kLanguage) ?? _detectDeviceLanguage();
    _vibrationPattern = _prefs.getString(_kVibrationPattern) ?? 'standard';
    _hapticIntensity = (_prefs.getDouble(_kHapticIntensity) ?? 0.8).clamp(0.0, 1.0).toDouble();
    _hapticNavigation = _prefs.getBool(_kHapticNavigation) ?? true;
    _hapticTyping = _prefs.getBool(_kHapticTyping) ?? true;
    _hapticChat = _prefs.getBool(_kHapticChat) ?? true;
    _hapticButtons = _prefs.getBool(_kHapticButtons) ?? true;
    _hapticNotifications = _prefs.getBool(_kHapticNotifications) ?? true;
    _hapticCalls = _prefs.getBool(_kHapticCalls) ?? true;
    _messageVolume = (_prefs.getDouble('novyn_message_volume') ?? 0.8).clamp(0.0, 1.0).toDouble();
    _callVolume = (_prefs.getDouble('novyn_call_volume') ?? 0.85).clamp(0.0, 1.0).toDouble();
    _appLockEnabled = _prefs.getBool(_kAppLockEnabled) ?? false;
    _appLockTimeout = _prefs.getInt(_kAppLockTimeout) ?? 0;
    // Migrate legacy PINs from plain preferences into encrypted storage.
    // Keystore errors are recoverable startup conditions, not a reason to
    // abort runApp or silently disable an enabled App Lock.
    _secureStorageReadFailed = false;
    _appLockPin = await _readSecureValue(_secureAppLockPin);
    final legacyAppPin = _prefs.getString(_kAppLockPin);
    if (_appLockPin == null && legacyAppPin != null) {
      _appLockPin = legacyAppPin;
      final migrated = await _writeSecureValue(_secureAppLockPin, legacyAppPin);
      if (migrated) await _prefs.remove(_kAppLockPin);
    }
    _isLocked = _appLockEnabled &&
        (_appLockPin != null || _secureStorageReadFailed);
    _appLockFailedAttempts = int.tryParse(
          await _readSecureValue(_secureAppLockFailures) ?? '0',
        ) ?? 0;
    final lockUntilRaw = await _readSecureValue(_secureAppLockUntil);
    final lockUntilMillis = int.tryParse(lockUntilRaw ?? '');
    _appLockLockedUntil = lockUntilMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lockUntilMillis);
    if (_appLockLockedUntil != null && !_appLockLockedUntil!.isAfter(DateTime.now())) {
      _appLockLockedUntil = null;
      await _deleteSecureValue(_secureAppLockUntil);
    }
    if (_appLockEnabled && _appLockPin == null && !_secureStorageReadFailed) {
      // Only disable App Lock when secure storage responded successfully and
      // confirmed the PIN is genuinely absent.
      _appLockEnabled = false;
      await _prefs.setBool(_kAppLockEnabled, false);
    }
    _stealthModeEnabled = _prefs.getBool(_kStealthMode) ?? false;
    _panicPin = await _readSecureValue(_securePanicPin);
    final legacyPanicPin = _prefs.getString(_kPanicPin);
    if (_panicPin == null && legacyPanicPin != null) {
      _panicPin = legacyPanicPin;
      final migrated = await _writeSecureValue(_securePanicPin, legacyPanicPin);
      if (migrated) await _prefs.remove(_kPanicPin);
    }
    _hideNotificationContent = _prefs.getBool(_kHideNotificationContent) ?? false;
    // Keep older installations safe when Stealth Mode was already enabled.
    if (_stealthModeEnabled && !_hideNotificationContent) {
      await _prefs.setBool(_kStealthPreviousNotificationPrivacy, false);
      _hideNotificationContent = true;
      await _prefs.setBool(_kHideNotificationContent, true);
    }
    _stealthIconEnabled = _prefs.getBool(_kStealthIcon) ?? false;
    _highContrast = _prefs.getBool(_kHighContrast) ?? false;
    _reduceMotion = _prefs.getBool(_kReduceMotion) ?? false;
    _busyPreviousPresenceMode = _prefs.getString(_kBusyPreviousPresence);
    _doNotDisturbEnabled = _prefs.getBool(_kDoNotDisturb) ?? false;
    _activeSmartPresenceMode = normalizeSmartPresenceMode(_prefs.getString(_kActiveSmartPresenceMode) ?? 'online');
    _smartPresenceOverrides = {};
    final rawPresenceOverrides = _prefs.getString(_kSmartPresenceOverrides);
    if (rawPresenceOverrides != null) {
      try {
        final decoded = jsonDecode(rawPresenceOverrides);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final mode = normalizeSmartPresenceMode(entry.key.toString());
            if (entry.value is! Map) continue;
            final values = Map<String, dynamic>.from(entry.value as Map)
              ..removeWhere((key, _) => !_smartPresenceAllowedKeys.contains(key));
            if (values.isNotEmpty) _smartPresenceOverrides[mode] = values;
          }
        }
      } catch (_) { _smartPresenceOverrides = {}; }
    }
    
    // Load saved sessions
    final raw = _prefs.getString(_kSavedSessions);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _savedSessions = list
            .map((e) => SavedSession.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _savedSessions = [];
      }
    }
    _loaded = true;
    notifyListeners();
  }

  // ── Setters (persist immediately) ───────────────────────────────────────
  Future<void> setNotifications(bool v, {bool recordPresenceOverride = true}) async {
    _notificationsOn = v;
    await _prefs.setBool(_kNotifications, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('notificationsEnabled', v);
    notifyListeners();
  }

  Future<void> setChatLinkPreviews(bool v) async {
    _chatLinkPreviews = v;
    await _prefs.setBool(_kChatLinkPreviews, v);
    notifyListeners();
  }

  Future<void> setMessagePreview(bool v, {bool recordPresenceOverride = true}) async {
    _messagePreview = v;
    await _prefs.setBool(_kMessagePreview, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('messagePreviewEnabled', v);
    notifyListeners();
  }

  Future<void> setReadReceipts(bool v, {bool recordPresenceOverride = true}) async {
    _readReceipts = v;
    await _prefs.setBool(_kReadReceipts, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('readReceiptsEnabled', v);
    notifyListeners();
  }

  Future<void> setOnlineStatus(bool v) async {
    _onlineStatus = v;
    await _prefs.setBool(_kOnlineStatus, v);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setInt(_kThemeMode, mode.index);
    notifyListeners();
  }

  Future<void> setProfile({required String name, required String bio}) async {
    _displayName = name;
    _bio = bio;
    await _prefs.setString(_kDisplayName, name);
    await _prefs.setString(_kBio, bio);
    notifyListeners();
  }

  // ── New setters ──────────────────────────────────────────────────────────
  Future<void> setChatEnterToSend(bool v) async {
    _chatEnterToSend = v;
    await _prefs.setBool('chat_enter_to_send', v);
    notifyListeners();
  }

  Future<void> setInAppSounds(bool v, {bool recordPresenceOverride = true}) async {
    _inAppSounds = v;
    await _prefs.setBool(_kInAppSounds, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('inAppSoundsEnabled', v);
    notifyListeners();
  }

  Future<void> setInAppVibration(bool v, {bool recordPresenceOverride = true}) async {
    _inAppVibration = v;
    await _prefs.setBool(_kInAppVibration, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('inAppVibrationEnabled', v);
    notifyListeners();
  }

  Future<void> setHapticCategory(String category, bool enabled) async {
    final key = switch (category) {
      'navigation' => _kHapticNavigation,
      'typing' => _kHapticTyping,
      'chat' => _kHapticChat,
      'notifications' => _kHapticNotifications,
      'calls' => _kHapticCalls,
      'buttons' => _kHapticButtons,
      _ => null,
    };
    if (key == null) return;
    switch (category) {
      case 'navigation': _hapticNavigation = enabled; break;
      case 'typing': _hapticTyping = enabled; break;
      case 'chat': _hapticChat = enabled; break;
      case 'notifications': _hapticNotifications = enabled; break;
      case 'calls': _hapticCalls = enabled; break;
      case 'buttons': _hapticButtons = enabled; break;
    }
    await _prefs.setBool(key, enabled);
    notifyListeners();
  }

  Future<void> setGroupNotifications(bool v, {bool recordPresenceOverride = true}) async {
    _groupNotifications = v;
    await _prefs.setBool(_kGroupNotifications, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('groupNotificationsEnabled', v);
    notifyListeners();
  }

  Future<void> setAutoDownloadWifi(String v) async {
    _autoDownloadWifi = v;
    await _prefs.setString(_kAutoDownloadWifi, v);
    notifyListeners();
  }

  Future<void> setAutoDownloadMobile(String v) async {
    _autoDownloadMobile = v;
    await _prefs.setString(_kAutoDownloadMobile, v);
    notifyListeners();
  }

  Future<void> setPhotoQuality(String v) async {
    _photoQuality = v;
    await _prefs.setString(_kPhotoQuality, v);
    notifyListeners();
  }

  Future<void> setLanguage(String v) async {
    _language = v;
    await _prefs.setString(_kLanguage, v);
    notifyListeners();
  }

  Future<void> setAccentColor(int value) async {
    _accentColorValue = value;
    await _prefs.setInt(_kAccentColor, value);
    notifyListeners();
  }

  Future<void> setAccentColorEnabled(bool enabled) async {
    _accentColorEnabled = enabled;
    await _prefs.setBool(_kAccentColorEnabled, enabled);
    notifyListeners();
  }

  Future<void> setAlertStyle(String style) async {
    const allowed = {'snackbar', 'top_banner', 'capsule', 'switch_card', 'centre_hud', 'countdown_card'};
    if (!allowed.contains(style) || _alertStyle == style) return;
    _alertStyle = style;
    await _prefs.setString(_kAlertStyle, style);
    notifyListeners();
  }

  Future<void> setCallMiniStyle(String style) async {
    const allowed = {
      'top_banner', 'floating_avatar', 'compact_pill',
      'bottom_bar', 'video_card', 'edge_chip',
    };
    if (!allowed.contains(style) || _callMiniStyle == style) return;
    _callMiniStyle = style;
    await _prefs.setString(_kCallMiniStyle, style);
    notifyListeners();
  }

  Future<void> setDockStyle(String style) async {
    const allowed = {
      'slide_pill',
      'expand_capsule',
      'edge_to_edge',
      'dot_minimal',
      'soft_glow_glass',
      'liquid_stretch',
      'flip_tiles',
      'draw_ring',
    };
    if (!allowed.contains(style)) return;
    if (_dockStyle == style) return;
    _dockStyle = style;
    await _prefs.setString(_kDockStyle, style);
    notifyListeners();
  }

  Future<void> setChatLabelSize(double v) async {
    _chatLabelSize = v.clamp(0.8, 1.4).toDouble();
    await _prefs.setDouble(_kChatLabelSize, _chatLabelSize);
    notifyListeners();
  }

  Future<void> setFontSize(double v) async {
    v = v.clamp(0.75, 1.25).toDouble();
    _fontSize = v;
    await _prefs.setDouble(_kFontSize, v);
    notifyListeners();
  }

  Future<void> setHighContrast(bool v) async {
    _highContrast = v;
    await _prefs.setBool(_kHighContrast, v);
    notifyListeners();
  }

  Future<void> setDoNotDisturbEnabled(bool enabled) async {
    if (_doNotDisturbEnabled == enabled) return;

    // Persist first so a failed device-storage write never leaves the UI
    // showing a value that was not actually saved.
    final saved = await _prefs.setBool(_kDoNotDisturb, enabled);
    if (!saved) {
      throw StateError('Your device could not save the Do Not Disturb setting.');
    }

    _doNotDisturbEnabled = enabled;
    notifyListeners();
  }

  Future<void> setBusyPreviousPresenceMode(String? mode) async {
    const allowed = {'online', 'away', 'invisible'};
    _busyPreviousPresenceMode = mode != null && allowed.contains(mode) ? mode : null;
    if (_busyPreviousPresenceMode == null) {
      await _prefs.remove(_kBusyPreviousPresence);
    } else {
      await _prefs.setString(_kBusyPreviousPresence, _busyPreviousPresenceMode!);
    }
    notifyListeners();
  }

  Future<void> setReduceMotion(bool v) async {
    if (_reduceMotion == v) return;
    _reduceMotion = v;
    // Update MediaQuery immediately so the accessibility control never waits
    // on a disk write before reflecting the user's choice.
    notifyListeners();
    await _prefs.setBool(_kReduceMotion, v);
  }

  Future<void> setTwoFactorAuth(bool v) async {
    _twoFactorAuth = v;
    await _prefs.setBool(_kTwoFactorAuth, v);
    notifyListeners();
  }

  Future<void> setTimeFormat(String value) async {
    _timeFormat = value == '24h' ? '24h' : '12h';
    await _prefs.setString(_kTimeFormat, _timeFormat);
    notifyListeners();
  }

  Future<void> setLastSeenVisibility(String v, {bool recordPresenceOverride = true}) async {
    _lastSeenVisibility = v;
    await _prefs.setString(_kLastSeen, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('presencePrivacy', v == 'contacts' ? 'friends' : v);
    notifyListeners();
  }

  Future<void> setProfilePhotoVisibility(String v, {bool recordPresenceOverride = true}) async {
    _profilePhotoVisibility = v;
    await _prefs.setString(_kProfilePhoto, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('profilePhotoPrivacy', v == 'contacts' ? 'friends' : v);
    notifyListeners();
  }

  Future<void> toggleFavoriteChat(String chatId) async {
    if (_favoriteChatIds.contains(chatId)) {
      _favoriteChatIds.remove(chatId);
    } else {
      _favoriteChatIds.add(chatId);
    }
    await _prefs.setStringList(_kFavoriteChatIds, _favoriteChatIds);
    notifyListeners();
  }

  Future<void> blockUser(String uid) async {
    if (!_blockedUids.contains(uid)) {
      _blockedUids.add(uid);
      await _prefs.setStringList(_kBlockedUids, _blockedUids);
      notifyListeners();
    }
  }

  Future<void> unblockUser(String uid) async {
    if (_blockedUids.contains(uid)) {
      _blockedUids.remove(uid);
      await _prefs.setStringList(_kBlockedUids, _blockedUids);
      notifyListeners();
    }
  }

  Future<void> setNotificationTone(String v) async {
    _notificationTone = v;
    await _prefs.setString(_kNotificationTone, v);
    notifyListeners();
  }

  Future<void> setCallRingtone(String v) async {
    _callRingtone = v;
    await _prefs.setString(_kCallRingtone, v);
    notifyListeners();
  }

  Future<void> setCustomNotificationPath(String? path) async {
    _customNotificationPath = path;
    if (path == null) {
      await _prefs.remove(_kCustomNotificationPath);
    } else {
      await _prefs.setString(_kCustomNotificationPath, path);
    }
    notifyListeners();
  }

  Future<void> setCustomRingtonePath(String? path) async {
    _customRingtonePath = path;
    if (path == null) {
      await _prefs.remove(_kCustomRingtonePath);
    } else {
      await _prefs.setString(_kCustomRingtonePath, path);
    }
    notifyListeners();
  }

  Future<void> setRegion(String v) async {
    _region = v;
    await _prefs.setString(_kRegion, v);
    
    // Auto-update language if current language is not in the new region's list
    final allowed = getLanguagesForRegion(v).keys.toList();
    if (!allowed.contains(_language)) {
      await setLanguage(allowed.first);
    }
    
    notifyListeners();
  }

  Map<String, String> getLanguagesForRegion(String regionName) {
    switch (regionName) {
      case 'India':
        return {
          'hi': 'हिन्दी (Hindi)',
          'en': 'English',
          'mr': 'मराठी (Marathi)',
          'bn': 'বাংলা (Bengali)',
          'ta': 'தமிழ் (Tamil)',
          'te': 'తెలుగు (Telugu)',
        };
      case 'United States':
        return {'en': 'English', 'es': 'Español'};
      case 'United Kingdom':
        return {'en': 'English'};
      case 'Germany':
        return {'de': 'Deutsch', 'en': 'English'};
      case 'France':
        return {'fr': 'Français', 'en': 'English'};
      case 'Spain':
        return {'es': 'Español', 'en': 'English'};
      case 'Italy':
        return {'it': 'Italiano', 'en': 'English'};
      case 'Japan':
        return {'ja': '日本語 (Japanese)', 'en': 'English'};
      case 'South Korea':
        return {'ko': '한국어 (Korean)', 'en': 'English'};
      case 'Russia':
        return {'ru': 'Русский (Russian)', 'en': 'English'};
      case 'Canada':
        return {'en': 'English', 'fr': 'Français'};
      default:
        return {'en': 'English'};
    }
  }

  Future<void> setVibrationPattern(String v) async {
    _vibrationPattern = v;
    await _prefs.setString(_kVibrationPattern, v);
    notifyListeners();
  }

  String _detectDeviceRegion() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final countryCode = locale.countryCode?.toUpperCase();
    
    // Fallback: Detection via Timezone Offset (India is UTC+5.5)
    final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    if (offsetMinutes == 330) return 'India';
    
    switch (countryCode) {
      case 'IN': return 'India';
      case 'GB': return 'United Kingdom';
      case 'CA': return 'Canada';
      case 'AU': return 'Australia';
      case 'DE': return 'Germany';
      case 'FR': return 'France';
      case 'ES': return 'Spain';
      case 'IT': return 'Italy';
      case 'JP': return 'Japan';
      case 'KR': return 'South Korea';
      case 'RU': return 'Russia';
      default: return 'United States';
    }
  }

  String _detectDeviceLanguage() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    return locale.languageCode.toLowerCase();
  }

  Future<void> setMessageVolume(double v) async {
    _messageVolume = v.clamp(0.0, 1.0).toDouble();
    await _prefs.setDouble('novyn_message_volume', _messageVolume);
    notifyListeners();
  }

  Future<void> setCallVolume(double v) async {
    _callVolume = v.clamp(0.0, 1.0).toDouble();
    await _prefs.setDouble('novyn_call_volume', _callVolume);
    notifyListeners();
  }

  Future<void> setHapticIntensity(double v) async {
    v = v.clamp(0.0, 1.0).toDouble();
    _hapticIntensity = v;
    await _prefs.setDouble(_kHapticIntensity, v);
    notifyListeners();
  }

  Future<void> setAppLockEnabled(bool v) async {
    if (v && _appLockPin == null) {
      throw StateError('Set an app lock PIN before enabling App Lock.');
    }
    _appLockEnabled = v;
    await _prefs.setBool(_kAppLockEnabled, v);
    notifyListeners();
  }

  Future<void> setAppLockTimeout(int v) async {
    _appLockTimeout = v;
    await _prefs.setInt(_kAppLockTimeout, v);
    notifyListeners();
  }

  Future<void> setAppLockPin(String? pin) async {
    if (pin != null && (pin.length != 4 || int.tryParse(pin) == null)) {
      throw ArgumentError('App lock PIN must contain exactly 4 digits.');
    }
    _appLockPin = pin;
    if (pin == null) {
      await _deleteSecureValue(_secureAppLockPin);
    } else if (!await _writeSecureValue(_secureAppLockPin, pin)) {
      throw StateError('Secure storage is temporarily unavailable. Try again.');
    }
    notifyListeners();
  }

  Future<void> recordFailedAppLockAttempt() async {
    _appLockFailedAttempts += 1;
    await _writeSecureValue(
      _secureAppLockFailures,
      _appLockFailedAttempts.toString(),
    );
    Duration? cooldown;
    if (_appLockFailedAttempts == 15) {
      cooldown = const Duration(minutes: 10);
    } else if (_appLockFailedAttempts == 10) {
      cooldown = const Duration(minutes: 2);
    } else if (_appLockFailedAttempts == 5) {
      cooldown = const Duration(seconds: 30);
    }
    if (cooldown != null) {
      _appLockLockedUntil = DateTime.now().add(cooldown);
      await _writeSecureValue(
        _secureAppLockUntil,
        _appLockLockedUntil!.millisecondsSinceEpoch.toString(),
      );
    }
    notifyListeners();
  }

  Future<void> resetAppLockFailures() async {
    _appLockFailedAttempts = 0;
    _appLockLockedUntil = null;
    await _deleteSecureValue(_secureAppLockFailures);
    await _deleteSecureValue(_secureAppLockUntil);
    notifyListeners();
  }

  // Recovery deliberately requires a fresh account sign-in. The PIN is
  // removed only after the user confirms they want to sign out.
  Future<void> prepareAppLockAccountRecovery() async {
    _appLockEnabled = false;
    _isLocked = false;
    await _prefs.setBool(_kAppLockEnabled, false);
    await setAppLockPin(null);
    await resetAppLockFailures();
    notifyListeners();
  }

  void setLocked(bool v) {
    _isLocked = v;
    notifyListeners();
  }

  Future<void> setStealthMode(bool v) async {
    if (v == _stealthModeEnabled) return;

    // Commit the in-memory value only after the device confirms persistence.
    final saved = await _prefs.setBool(_kStealthMode, v);
    if (!saved) {
      throw StateError('Your device could not save the Stealth Mode setting.');
    }

    _stealthModeEnabled = v;
    notifyListeners();
  }

  Future<void> setPanicPin(String? pin) async {
    if (pin != null && (pin.length != 4 || int.tryParse(pin) == null)) {
      throw ArgumentError('Panic PIN must contain exactly 4 digits.');
    }
    _panicPin = pin;
    if (pin == null) {
      await _deleteSecureValue(_securePanicPin);
    } else if (!await _writeSecureValue(_securePanicPin, pin)) {
      throw StateError('Secure storage is temporarily unavailable. Try again.');
    }
    notifyListeners();
  }

  Future<void> setHideNotificationContent(bool v) async {
    _hideNotificationContent = v;
    await _prefs.setBool(_kHideNotificationContent, v);
    notifyListeners();
  }

  void setDecoyMode(bool v) {
    _decoyMode = v;
    notifyListeners();
  }

  Future<void> setStealthIconEnabled(bool v) async {
    _stealthIconEnabled = v;
    await _prefs.setBool(_kStealthIcon, v);
    notifyListeners();
  }

  void unlockWithDecoy(bool isDecoy) {
    _decoyMode = isDecoy;
    _isLocked = false;
    resetAppLockFailures();
    notifyListeners();
  }

  bool isBlocked(String uid) => _blockedUids.contains(uid);

  // ── Saved sessions ───────────────────────────────────────────────────────
  Future<void> saveSession(SavedSession session) async {
    // Remove existing entry for same uid/email, then add fresh
    _savedSessions.removeWhere(
        (s) => s.uid == session.uid || s.email == session.email);
    _savedSessions.insert(0, session); // most recent first
    // Keep max 5 saved accounts
    if (_savedSessions.length > 5) _savedSessions = _savedSessions.sublist(0, 5);
    await _persistSessions();
    notifyListeners();
  }

  Future<void> removeSession(String uid) async {
    _savedSessions.removeWhere((s) => s.uid == uid);
    await _persistSessions();
    notifyListeners();
  }

  Future<void> _persistSessions() async {
    final encoded = jsonEncode(_savedSessions.map((s) => s.toJson()).toList());
    await _prefs.setString(_kSavedSessions, encoded);
  }

  /// Export only account-level preferences. Device secrets, local file paths,
  /// biometric/app-lock state and transient runtime flags are intentionally
  /// excluded from cloud sync.
  Map<String, dynamic> cloudSyncSnapshot({String? accountKey}) => {
        'chatLinkPreviews': _chatLinkPreviews,
        'onlineStatus': _onlineStatus,
        'themeMode': _themeMode.name,
        'chatEnterToSend': _chatEnterToSend,
        'autoDownloadWifi': _autoDownloadWifi,
        'autoDownloadMobile': _autoDownloadMobile,
        'photoQuality': _photoQuality,
        'language': _language,
        'timeFormat': _timeFormat,
        'fontSize': _fontSize,
        'chatLabelSize': _chatLabelSize,
        'accentColorValue': _accentColorValue,
        'accentColorEnabled': _accentColorEnabled,
        'dockStyle': _dockStyle,
        'alertStyle': _alertStyle,
        'notificationTone': _notificationTone,
        'callRingtone': _callRingtone,
        'vibrationPattern': _vibrationPattern,
        'hapticIntensity': _hapticIntensity,
        'hapticNavigation': _hapticNavigation,
        'hapticTyping': _hapticTyping,
        'hapticChat': _hapticChat,
        'hapticButtons': _hapticButtons,
        'hapticNotifications': _hapticNotifications,
        'hapticCalls': _hapticCalls,
        'messageVolume': _messageVolume,
        'callVolume': _callVolume,
        'region': _region,
        'highContrast': _highContrast,
        'reduceMotion': _reduceMotion,
        'doNotDisturbEnabled': _doNotDisturbEnabled,
        if (accountKey != null && accountKey.trim().isNotEmpty)
          'quickToggleIds': quickToggleIdsFor(accountKey),
      };

  /// Apply an account snapshot without invoking each public setter (and
  /// therefore without causing a burst of listener notifications/network work).
  /// The UI receives one notification after the local cache has been updated.
  Future<void> applyCloudSyncSnapshot(
    Map<String, dynamic> values, {
    String? accountKey,
  }) async {
    if (!_loaded) {
      throw StateError('Settings must be loaded before applying cloud settings.');
    }

    bool boolValue(String key, bool fallback) =>
        values[key] is bool ? values[key] as bool : fallback;
    String stringValue(String key, String fallback) =>
        values[key] is String ? (values[key] as String) : fallback;
    double doubleValue(String key, double fallback, double min, double max) {
      final raw = values[key];
      final value = raw is num ? raw.toDouble() : fallback;
      return value.clamp(min, max).toDouble();
    }

    _notificationsOn = boolValue('notificationsOn', _notificationsOn);
    _messagePreview = boolValue('messagePreview', _messagePreview);
    _chatLinkPreviews = boolValue('chatLinkPreviews', _chatLinkPreviews);
    _readReceipts = boolValue('readReceipts', _readReceipts);
    _onlineStatus = boolValue('onlineStatus', _onlineStatus);
    final themeName = stringValue('themeMode', _themeMode.name);
    _themeMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == themeName,
      orElse: () => _themeMode,
    );
    _inAppSounds = boolValue('inAppSounds', _inAppSounds);
    _chatEnterToSend = boolValue('chatEnterToSend', _chatEnterToSend);
    _inAppVibration = boolValue('inAppVibration', _inAppVibration);
    _groupNotifications = boolValue('groupNotifications', _groupNotifications);
    _autoDownloadWifi = stringValue('autoDownloadWifi', _autoDownloadWifi);
    _autoDownloadMobile = stringValue('autoDownloadMobile', _autoDownloadMobile);
    _photoQuality = stringValue('photoQuality', _photoQuality);
    _language = stringValue('language', _language);
    _timeFormat = stringValue('timeFormat', _timeFormat) == '24h' ? '24h' : '12h';
    _fontSize = doubleValue('fontSize', _fontSize, 0.75, 1.25);
    _chatLabelSize = doubleValue('chatLabelSize', _chatLabelSize, 0.8, 1.4);
    final accent = values['accentColorValue'];
    if (accent is num && accent.toInt() >= 0 && accent.toInt() <= 0xFFFFFFFF) {
      _accentColorValue = accent.toInt();
    }
    _accentColorEnabled = boolValue('accentColorEnabled', _accentColorEnabled);

    const dockStyles = {
      'slide_pill', 'expand_capsule', 'edge_to_edge', 'dot_minimal',
      'soft_glow_glass', 'liquid_stretch', 'flip_tiles', 'draw_ring',
    };
    final dockStyle = stringValue('dockStyle', _dockStyle);
    if (dockStyles.contains(dockStyle)) _dockStyle = dockStyle;
    const alertStyles = {
      'snackbar', 'top_banner', 'capsule', 'switch_card',
      'centre_hud', 'countdown_card',
    };
    final alertStyle = stringValue('alertStyle', _alertStyle);
    if (alertStyles.contains(alertStyle)) _alertStyle = alertStyle;

    _notificationTone = stringValue('notificationTone', _notificationTone);
    _callRingtone = stringValue('callRingtone', _callRingtone);
    _vibrationPattern = stringValue('vibrationPattern', _vibrationPattern);
    _hapticIntensity = doubleValue('hapticIntensity', _hapticIntensity, 0, 1);
    _hapticNavigation = boolValue('hapticNavigation', _hapticNavigation);
    _hapticTyping = boolValue('hapticTyping', _hapticTyping);
    _hapticChat = boolValue('hapticChat', _hapticChat);
    _hapticButtons = boolValue('hapticButtons', _hapticButtons);
    _hapticNotifications = boolValue('hapticNotifications', _hapticNotifications);
    _hapticCalls = boolValue('hapticCalls', _hapticCalls);
    _messageVolume = doubleValue('messageVolume', _messageVolume, 0, 1);
    _callVolume = doubleValue('callVolume', _callVolume, 0, 1);
    _region = stringValue('region', _region);
    _highContrast = boolValue('highContrast', _highContrast);
    _reduceMotion = boolValue('reduceMotion', _reduceMotion);
    _doNotDisturbEnabled = boolValue('doNotDisturbEnabled', _doNotDisturbEnabled);

    final writes = <Future<bool>>[
      _prefs.setBool(_kNotifications, _notificationsOn),
      _prefs.setBool(_kMessagePreview, _messagePreview),
      _prefs.setBool(_kChatLinkPreviews, _chatLinkPreviews),
      _prefs.setBool(_kReadReceipts, _readReceipts),
      _prefs.setBool(_kOnlineStatus, _onlineStatus),
      _prefs.setInt(_kThemeMode, _themeMode.index),
      _prefs.setBool(_kInAppSounds, _inAppSounds),
      _prefs.setBool('chat_enter_to_send', _chatEnterToSend),
      _prefs.setBool(_kInAppVibration, _inAppVibration),
      _prefs.setBool(_kGroupNotifications, _groupNotifications),
      _prefs.setString(_kAutoDownloadWifi, _autoDownloadWifi),
      _prefs.setString(_kAutoDownloadMobile, _autoDownloadMobile),
      _prefs.setString(_kPhotoQuality, _photoQuality),
      _prefs.setString(_kLanguage, _language),
      _prefs.setString(_kTimeFormat, _timeFormat),
      _prefs.setDouble(_kFontSize, _fontSize),
      _prefs.setDouble(_kChatLabelSize, _chatLabelSize),
      _prefs.setInt(_kAccentColor, _accentColorValue),
      _prefs.setBool(_kAccentColorEnabled, _accentColorEnabled),
      _prefs.setString(_kDockStyle, _dockStyle),
      _prefs.setString(_kAlertStyle, _alertStyle),
      _prefs.setString(_kNotificationTone, _notificationTone),
      _prefs.setString(_kCallRingtone, _callRingtone),
      _prefs.setString(_kVibrationPattern, _vibrationPattern),
      _prefs.setDouble(_kHapticIntensity, _hapticIntensity),
      _prefs.setBool(_kHapticNavigation, _hapticNavigation),
      _prefs.setBool(_kHapticTyping, _hapticTyping),
      _prefs.setBool(_kHapticChat, _hapticChat),
      _prefs.setBool(_kHapticButtons, _hapticButtons),
      _prefs.setBool(_kHapticNotifications, _hapticNotifications),
      _prefs.setBool(_kHapticCalls, _hapticCalls),
      _prefs.setDouble('novyn_message_volume', _messageVolume),
      _prefs.setDouble('novyn_call_volume', _callVolume),
      _prefs.setString(_kRegion, _region),
      _prefs.setBool(_kHighContrast, _highContrast),
      _prefs.setBool(_kReduceMotion, _reduceMotion),
      _prefs.setBool(_kDoNotDisturb, _doNotDisturbEnabled),
    ];
    final quickIds = values['quickToggleIds'];
    if (accountKey != null &&
        accountKey.trim().isNotEmpty &&
        quickIds is List) {
      final cleaned = sanitizeQuickToggleIds(
        quickIds.whereType<String>(),
      );
      if (cleaned.isNotEmpty) {
        writes.add(_prefs.setStringList(
          _quickToggleStorageKey(accountKey),
          cleaned,
        ));
      }
    }
    await Future.wait(writes);
    notifyListeners();
  }

  Future<void> clearAll() async {
    await _prefs.clear();
    await _deleteSecureValue(_secureAppLockPin);
    await _deleteSecureValue(_securePanicPin);
    _notificationsOn = true;
    _messagePreview = true;
    _chatLinkPreviews = true;
    _readReceipts = true;
    _onlineStatus = true;
    _themeMode = ThemeMode.system;
    _displayName = '';
    _bio = '';
    _savedSessions = [];
    
    // Reset new settings
    _inAppSounds = true;
    _chatEnterToSend = true;
    _inAppVibration = true;
    _groupNotifications = true;
    _autoDownloadWifi = 'all';
    _autoDownloadMobile = 'photos';
    _photoQuality = 'high';
    _language = 'en';
    _fontSize = 0.85;
    _chatLabelSize = 1.0;
    _accentColorValue = 0xFF6D5DFC;
    _accentColorEnabled = true;
    _dockStyle = 'slide_pill';
    _alertStyle = 'snackbar';
    _callMiniStyle = 'top_banner';
    _twoFactorAuth = false;
    _lastSeenVisibility = 'everyone';
    _profilePhotoVisibility = 'everyone';
    _blockedUids = [];
    _notificationTone = 'Aurora';
    _vibrationPattern = 'standard';
    _hapticIntensity = 0.8;
    _appLockEnabled = false;
    _appLockTimeout = 0;
    
    notifyListeners();
  }
  @override
  void dispose() {
    super.dispose();
  }

}
).hasMatch(start)) {
      _quietHoursStart = start;
      await _prefs.setString(_kQuietHoursStart, start);
      changed = true;
    }
    if (end is String && RegExp(r'^([01]\\d|2[0-3]):[0-5]\\d
  String get autoDownloadWifi => _autoDownloadWifi;
  String get autoDownloadMobile => _autoDownloadMobile;
  String get notificationTone => _notificationTone;
  String get callRingtone => _callRingtone;
  String? get customNotificationPath => _customNotificationPath;
  String? get customRingtonePath => _customRingtonePath;
  String get region => _region;
  String get language => _language;
  String get timeFormat => _timeFormat;
  String get vibrationPattern => _vibrationPattern;
  double get hapticIntensity => _hapticIntensity;
  bool get hapticNavigation => _hapticNavigation;
  bool get hapticTyping => _hapticTyping;
  bool get hapticChat => _hapticChat;
  bool get hapticButtons => _hapticButtons;
  bool get hapticNotifications => _hapticNotifications;
  bool get hapticCalls => _hapticCalls;
  bool hapticCategoryEnabled(String category) => switch (category) {
    'navigation' => _hapticNavigation,
    'typing' => _hapticTyping,
    'chat' => _hapticChat,
    'notifications' => _hapticNotifications,
    'calls' => _hapticCalls,
    _ => _hapticButtons,
  };
  double get messageVolume => _messageVolume;
  double get callVolume => _callVolume;
  String get photoQuality => _photoQuality;
  double get fontSize => _fontSize;
  double get chatLabelSize => _chatLabelSize;
  int get accentColorValue => _accentColorValue;
  bool get accentColorEnabled => _accentColorEnabled;
  String get dockStyle => _dockStyle;
  String get alertStyle => _alertStyle;
  String get callMiniStyle => _callMiniStyle;
  bool get twoFactorAuth => _twoFactorAuth;
  String get lastSeenVisibility => _stealthModeEnabled ? 'nobody' : _lastSeenVisibility;
  String get profilePhotoVisibility => _stealthModeEnabled ? 'nobody' : _profilePhotoVisibility;
  String get configuredLastSeenVisibility => _lastSeenVisibility;
  String get configuredProfilePhotoVisibility => _profilePhotoVisibility;
  List<String> get blockedUids => _blockedUids;
  List<String> get favoriteChatIds => List.unmodifiable(_favoriteChatIds);
  bool get appLockEnabled => _appLockEnabled;
  int get appLockTimeout => _appLockTimeout;
  String? get appLockPin => _appLockPin;
  bool get secureStorageAvailable => !_secureStorageReadFailed;
  bool get isLocked => _isLocked;
  int get appLockFailedAttempts => _appLockFailedAttempts;
  Duration get appLockRemaining {
    final until = _appLockLockedUntil;
    if (until == null) return Duration.zero;
    final remaining = until.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
  bool get isAppLockCoolingDown => appLockRemaining > Duration.zero;
  bool get stealthModeEnabled => _stealthModeEnabled;
  String? get panicPin => _panicPin;
  bool get hideNotificationContent => _hideNotificationContent;
  bool get decoyMode => _decoyMode;
  bool get stealthIconEnabled => _stealthIconEnabled;
  bool get highContrast => _highContrast;
  bool get reduceMotion => _reduceMotion;
  String? get busyPreviousPresenceMode => _busyPreviousPresenceMode;
  bool get doNotDisturbEnabled => _doNotDisturbEnabled;
  String get activeSmartPresenceMode => _activeSmartPresenceMode;
  static const Set<String> _smartPresenceServerKeys = {
    'callsEnabled', 'callPrivacy', 'messagePrivacy', 'profilePhotoPrivacy', 'presencePrivacy',
    'discoverPrivacy', 'groupInvitePrivacy', 'friendRequestPrivacy',
    'readReceiptsEnabled', 'typingIndicatorsEnabled', 'notificationsEnabled',
    'messagePreviewEnabled', 'groupNotificationsEnabled',
  };
  static const Set<String> _smartPresenceLocalKeys = {'inAppSoundsEnabled', 'inAppVibrationEnabled'};
  static const Set<String> _smartPresenceAllowedKeys = {
    ..._smartPresenceServerKeys, ..._smartPresenceLocalKeys,
  };
  static String normalizeSmartPresenceMode(String mode) {
    final value = mode.trim().toLowerCase();
    if (value == 'away' || value == 'idle') return 'idle';
    if (value == 'dnd') return 'busy';
    if (value == 'offline') return 'invisible';
    return const {'online', 'busy', 'invisible'}.contains(value) ? value : 'online';
  }
  static String presenceStatusForSmartMode(String mode) =>
      normalizeSmartPresenceMode(mode) == 'idle' ? 'away' : normalizeSmartPresenceMode(mode);
  static Map<String, dynamic> smartPresenceDefaults(String mode) {
    switch (normalizeSmartPresenceMode(mode)) {
      case 'idle':
        return {
          'callsEnabled': true, 'callPrivacy': 'friends', 'messagePrivacy': 'friends',
          'profilePhotoPrivacy': 'friends', 'presencePrivacy': 'friends',
          'discoverPrivacy': 'friends', 'groupInvitePrivacy': 'friends',
          'friendRequestPrivacy': 'mutuals',
          'readReceiptsEnabled': true, 'typingIndicatorsEnabled': true,
          'notificationsEnabled': true, 'messagePreviewEnabled': true,
          'groupNotificationsEnabled': true, 'inAppSoundsEnabled': true,
          'inAppVibrationEnabled': true,
        };
      case 'busy':
        return {
          'callsEnabled': true, 'callPrivacy': 'nobody', 'messagePrivacy': 'friends',
          'profilePhotoPrivacy': 'friends', 'presencePrivacy': 'friends',
          'discoverPrivacy': 'friends', 'groupInvitePrivacy': 'friends',
          'friendRequestPrivacy': 'mutuals',
          'readReceiptsEnabled': false, 'typingIndicatorsEnabled': false,
          'notificationsEnabled': false, 'messagePreviewEnabled': false,
          'groupNotificationsEnabled': false, 'inAppSoundsEnabled': false,
          'inAppVibrationEnabled': false,
        };
      case 'invisible':
        return {
          'callsEnabled': false, 'callPrivacy': 'nobody', 'messagePrivacy': 'friends',
          'profilePhotoPrivacy': 'nobody', 'presencePrivacy': 'nobody',
          'discoverPrivacy': 'nobody', 'groupInvitePrivacy': 'nobody',
          'friendRequestPrivacy': 'nobody',
          'readReceiptsEnabled': false, 'typingIndicatorsEnabled': false,
          'notificationsEnabled': false, 'messagePreviewEnabled': false,
          'groupNotificationsEnabled': false, 'inAppSoundsEnabled': false,
          'inAppVibrationEnabled': false,
        };
      case 'online':
      default:
        return {
          'callsEnabled': true, 'callPrivacy': 'everyone', 'messagePrivacy': 'everyone',
          'profilePhotoPrivacy': 'everyone', 'presencePrivacy': 'everyone',
          'discoverPrivacy': 'everyone', 'groupInvitePrivacy': 'everyone',
          'friendRequestPrivacy': 'everyone',
          'readReceiptsEnabled': true, 'typingIndicatorsEnabled': true,
          'notificationsEnabled': true, 'messagePreviewEnabled': true,
          'groupNotificationsEnabled': true, 'inAppSoundsEnabled': true,
          'inAppVibrationEnabled': true,
        };
    }
  }
  Map<String, dynamic> smartPresencePolicyFor(String mode) {
    final key = normalizeSmartPresenceMode(mode);
    return {...smartPresenceDefaults(key), ...?_smartPresenceOverrides[key]};
  }
  bool hasSmartPresenceCustomizations(String mode) =>
      _smartPresenceOverrides[normalizeSmartPresenceMode(mode)]?.isNotEmpty ?? false;
  static Map<String, dynamic> smartPresenceServerFields(Map<String, dynamic> policy) => {
    for (final entry in policy.entries)
      if (_smartPresenceServerKeys.contains(entry.key)) entry.key: entry.value,
  };
  Future<void> saveSmartPresenceOverride(String mode, String key, dynamic value) async {
    if (!_smartPresenceAllowedKeys.contains(key)) {
      throw ArgumentError.value(key, 'key', 'Unsupported Smart Presence setting');
    }
    final normalized = normalizeSmartPresenceMode(mode);
    final overrides = _smartPresenceOverrides.putIfAbsent(normalized, () => <String, dynamic>{});
    if (smartPresenceDefaults(normalized)[key] == value) {
      overrides.remove(key);
    } else {
      overrides[key] = value;
    }
    if (overrides.isEmpty) _smartPresenceOverrides.remove(normalized);
    await _prefs.setString(_kSmartPresenceOverrides, jsonEncode(_smartPresenceOverrides));
    notifyListeners();
  }
  Future<void> hydrateSmartPresenceModeFromServer(
    String mode,
    Map<String, dynamic> serverPolicy,
  ) async {
    final normalized = normalizeSmartPresenceMode(mode);
    final defaults = smartPresenceDefaults(normalized);
    final previous = _smartPresenceOverrides[normalized] ?? const <String, dynamic>{};
    final next = <String, dynamic>{};
    const privacyValues = {'everyone', 'friends', 'nobody', 'mutuals'};

    for (final key in _smartPresenceServerKeys) {
      if (!serverPolicy.containsKey(key)) continue;
      final value = serverPolicy[key];
      final defaultValue = defaults[key];
      if (defaultValue is bool && value is bool) {
        if (value != defaultValue) next[key] = value;
      } else if (defaultValue is String &&
          value is String &&
          privacyValues.contains(value)) {
        if (value != defaultValue) next[key] = value;
      }
    }
    for (final key in _smartPresenceLocalKeys) {
      if (previous.containsKey(key)) next[key] = previous[key];
    }

    if (next.isEmpty) {
      _smartPresenceOverrides.remove(normalized);
    } else {
      _smartPresenceOverrides[normalized] = next;
    }
    await _prefs.setString(_kSmartPresenceOverrides, jsonEncode(_smartPresenceOverrides));
    notifyListeners();
  }

  Future<void> recordActiveSmartPresenceOverride(String key, dynamic value) =>
      saveSmartPresenceOverride(_activeSmartPresenceMode, key, value);
  Future<void> resetSmartPresenceOverrides(String mode) async {
    _smartPresenceOverrides.remove(normalizeSmartPresenceMode(mode));
    await _prefs.setString(_kSmartPresenceOverrides, jsonEncode(_smartPresenceOverrides));
    notifyListeners();
  }
  Future<void> applySmartPresenceLocalPolicy(String mode, {Map<String, dynamic>? policy}) async {
    final normalized = normalizeSmartPresenceMode(mode);
    final values = policy ?? smartPresencePolicyFor(normalized);
    _activeSmartPresenceMode = normalized;
    _notificationsOn = values['notificationsEnabled'] != false;
    _messagePreview = values['messagePreviewEnabled'] != false;
    _groupNotifications = values['groupNotificationsEnabled'] != false;
    _readReceipts = values['readReceiptsEnabled'] != false;
    _inAppSounds = values['inAppSoundsEnabled'] != false;
    _inAppVibration = values['inAppVibrationEnabled'] != false;
    final presence = values['presencePrivacy']?.toString() ?? 'everyone';
    final photo = values['profilePhotoPrivacy']?.toString() ?? 'everyone';
    _lastSeenVisibility = presence == 'friends' ? 'contacts' : presence;
    _profilePhotoVisibility = photo == 'friends' ? 'contacts' : photo;
    await Future.wait([
      _prefs.setString(_kActiveSmartPresenceMode, normalized),
      _prefs.setBool(_kNotifications, _notificationsOn),
      _prefs.setBool(_kMessagePreview, _messagePreview),
      _prefs.setBool(_kGroupNotifications, _groupNotifications),
      _prefs.setBool(_kReadReceipts, _readReceipts),
      _prefs.setBool(_kInAppSounds, _inAppSounds),
      _prefs.setBool(_kInAppVibration, _inAppVibration),
      _prefs.setString(_kLastSeen, _lastSeenVisibility),
      _prefs.setString(_kProfilePhoto, _profilePhotoVisibility),
    ]);
    notifyListeners();
  }
  Future<void> setActiveSmartPresenceMode(String mode) async {
    _activeSmartPresenceMode = normalizeSmartPresenceMode(mode);
    await _prefs.setString(_kActiveSmartPresenceMode, _activeSmartPresenceMode);
    notifyListeners();
  }

  // ── Load from disk ───────────────────────────────────────────────────────
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _notificationsOn = _prefs.getBool(_kNotifications) ?? true;
    _messagePreview = _prefs.getBool(_kMessagePreview) ?? true;
    _chatLinkPreviews = _prefs.getBool(_kChatLinkPreviews) ?? true;
    _readReceipts = _prefs.getBool(_kReadReceipts) ?? true;
    _onlineStatus = _prefs.getBool(_kOnlineStatus) ?? true;
    _themeMode = ThemeMode.values[_prefs.getInt(_kThemeMode) ?? ThemeMode.light.index];
    _displayName = _prefs.getString(_kDisplayName) ?? '';
    _bio = _prefs.getString(_kBio) ?? '';
    
    // Load new settings
    _inAppSounds = _prefs.getBool(_kInAppSounds) ?? true;
    _chatEnterToSend = _prefs.getBool('chat_enter_to_send') ?? true;
    _inAppVibration = _prefs.getBool(_kInAppVibration) ?? true;
    _groupNotifications = _prefs.getBool(_kGroupNotifications) ?? true;
    _notificationPreferences = {...notificationPreferenceDefaults};
    for (final entry in notificationPreferenceStorageKeys.entries) {
      _notificationPreferences[entry.key] =
          _prefs.getBool(entry.value) ?? notificationPreferenceDefaults[entry.key]!;
    }
    _quietHoursStart = _prefs.getString(_kQuietHoursStart) ?? '22:00';
    _quietHoursEnd = _prefs.getString(_kQuietHoursEnd) ?? '07:00';
    _quietHoursOffsetMinutes = (_prefs.getInt(_kQuietHoursOffsetMinutes) ??
        DateTime.now().timeZoneOffset.inMinutes).clamp(-840, 840);
    _autoDownloadWifi = _prefs.getString(_kAutoDownloadWifi) ?? 'all';
    _autoDownloadMobile = _prefs.getString(_kAutoDownloadMobile) ?? 'photos';
    _photoQuality = _prefs.getString(_kPhotoQuality) ?? 'high';
    _language = _prefs.getString(_kLanguage) ?? 'en';
    final savedTimeFormat = _prefs.getString(_kTimeFormat) ?? '12h';
    _timeFormat = savedTimeFormat == '24h' ? '24h' : '12h';
    _fontSize = (_prefs.getDouble(_kFontSize) ?? 0.85).clamp(0.75, 1.25).toDouble();
    _chatLabelSize = (_prefs.getDouble(_kChatLabelSize) ?? 1.0).clamp(0.8, 1.4).toDouble();
    _accentColorValue = _prefs.getInt(_kAccentColor) ?? 0xFF6D5DFC;
    _accentColorEnabled = _prefs.getBool(_kAccentColorEnabled) ?? true;
    const alertStyles = {'snackbar', 'top_banner', 'capsule', 'switch_card', 'centre_hud', 'countdown_card'};
    final savedAlertStyle = _prefs.getString(_kAlertStyle) ?? 'snackbar';
    _alertStyle = alertStyles.contains(savedAlertStyle) ? savedAlertStyle : 'snackbar';
    if (_alertStyle != savedAlertStyle) await _prefs.setString(_kAlertStyle, _alertStyle);
    const callMiniStyles = {
      'top_banner', 'floating_avatar', 'compact_pill',
      'bottom_bar', 'video_card', 'edge_chip',
    };
    const legacyCallMiniStyles = <String, String>{
      'floating_bar': 'top_banner',
      'glass_card': 'video_card',
      'accent_strip': 'top_banner',
      'avatar_bubble': 'floating_avatar',
      'video_focus': 'video_card',
    };
    final savedCallMiniStyle = _prefs.getString(_kCallMiniStyle) ?? 'top_banner';
    _callMiniStyle = callMiniStyles.contains(savedCallMiniStyle)
        ? savedCallMiniStyle
        : legacyCallMiniStyles[savedCallMiniStyle] ?? 'top_banner';
    if (_callMiniStyle != savedCallMiniStyle) {
      await _prefs.setString(_kCallMiniStyle, _callMiniStyle);
    }
    const dockStyles = [
      'slide_pill',
      'expand_capsule',
      'edge_to_edge',
      'dot_minimal',
      'soft_glow_glass',
      'liquid_stretch',
      'flip_tiles',
      'draw_ring',
    ];
    const legacyDockStyles = <String, String>{
      'floating_pill': 'slide_pill',
      'rounded_bar': 'slide_pill',
      'minimal': 'dot_minimal',
      'glass': 'soft_glow_glass',
      'sliding': 'slide_pill',
      'elevated': 'expand_capsule',
      'full_width': 'edge_to_edge',
      'glow': 'soft_glow_glass',
    };
    final savedDockStyle = _prefs.getString(_kDockStyle) ?? 'slide_pill';
    if (dockStyles.contains(savedDockStyle)) {
      _dockStyle = savedDockStyle;
    } else {
      _dockStyle = legacyDockStyles[savedDockStyle] ?? 'slide_pill';
      await _prefs.setString(_kDockStyle, _dockStyle);
    }
    _twoFactorAuth = _prefs.getBool(_kTwoFactorAuth) ?? false;
    _lastSeenVisibility = _prefs.getString(_kLastSeen) ?? 'everyone';
    _profilePhotoVisibility = _prefs.getString(_kProfilePhoto) ?? 'everyone';
    _blockedUids = _prefs.getStringList(_kBlockedUids) ?? [];
    _favoriteChatIds = _prefs.getStringList(_kFavoriteChatIds) ?? [];
    _notificationTone = _prefs.getString(_kNotificationTone) ?? 'Aurora';
    _callRingtone = _prefs.getString(_kCallRingtone) ?? 'Binary';
    _customNotificationPath = _prefs.getString(_kCustomNotificationPath);
    _customRingtonePath = _prefs.getString(_kCustomRingtonePath);
    _region = _prefs.getString(_kRegion) ?? _detectDeviceRegion();
    
    // Recovery: If region is "Germany" (previous bug) or "United States" (old default),
    // and we are actually in India (via offset), force reset to India.
    if ((_region == 'Germany' || _region == 'United States') && _detectDeviceRegion() == 'India') {
      _region = 'India';
    }
    _language = _prefs.getString(_kLanguage) ?? _detectDeviceLanguage();
    _vibrationPattern = _prefs.getString(_kVibrationPattern) ?? 'standard';
    _hapticIntensity = (_prefs.getDouble(_kHapticIntensity) ?? 0.8).clamp(0.0, 1.0).toDouble();
    _hapticNavigation = _prefs.getBool(_kHapticNavigation) ?? true;
    _hapticTyping = _prefs.getBool(_kHapticTyping) ?? true;
    _hapticChat = _prefs.getBool(_kHapticChat) ?? true;
    _hapticButtons = _prefs.getBool(_kHapticButtons) ?? true;
    _hapticNotifications = _prefs.getBool(_kHapticNotifications) ?? true;
    _hapticCalls = _prefs.getBool(_kHapticCalls) ?? true;
    _messageVolume = (_prefs.getDouble('novyn_message_volume') ?? 0.8).clamp(0.0, 1.0).toDouble();
    _callVolume = (_prefs.getDouble('novyn_call_volume') ?? 0.85).clamp(0.0, 1.0).toDouble();
    _appLockEnabled = _prefs.getBool(_kAppLockEnabled) ?? false;
    _appLockTimeout = _prefs.getInt(_kAppLockTimeout) ?? 0;
    // Migrate legacy PINs from plain preferences into encrypted storage.
    // Keystore errors are recoverable startup conditions, not a reason to
    // abort runApp or silently disable an enabled App Lock.
    _secureStorageReadFailed = false;
    _appLockPin = await _readSecureValue(_secureAppLockPin);
    final legacyAppPin = _prefs.getString(_kAppLockPin);
    if (_appLockPin == null && legacyAppPin != null) {
      _appLockPin = legacyAppPin;
      final migrated = await _writeSecureValue(_secureAppLockPin, legacyAppPin);
      if (migrated) await _prefs.remove(_kAppLockPin);
    }
    _isLocked = _appLockEnabled &&
        (_appLockPin != null || _secureStorageReadFailed);
    _appLockFailedAttempts = int.tryParse(
          await _readSecureValue(_secureAppLockFailures) ?? '0',
        ) ?? 0;
    final lockUntilRaw = await _readSecureValue(_secureAppLockUntil);
    final lockUntilMillis = int.tryParse(lockUntilRaw ?? '');
    _appLockLockedUntil = lockUntilMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lockUntilMillis);
    if (_appLockLockedUntil != null && !_appLockLockedUntil!.isAfter(DateTime.now())) {
      _appLockLockedUntil = null;
      await _deleteSecureValue(_secureAppLockUntil);
    }
    if (_appLockEnabled && _appLockPin == null && !_secureStorageReadFailed) {
      // Only disable App Lock when secure storage responded successfully and
      // confirmed the PIN is genuinely absent.
      _appLockEnabled = false;
      await _prefs.setBool(_kAppLockEnabled, false);
    }
    _stealthModeEnabled = _prefs.getBool(_kStealthMode) ?? false;
    _panicPin = await _readSecureValue(_securePanicPin);
    final legacyPanicPin = _prefs.getString(_kPanicPin);
    if (_panicPin == null && legacyPanicPin != null) {
      _panicPin = legacyPanicPin;
      final migrated = await _writeSecureValue(_securePanicPin, legacyPanicPin);
      if (migrated) await _prefs.remove(_kPanicPin);
    }
    _hideNotificationContent = _prefs.getBool(_kHideNotificationContent) ?? false;
    // Keep older installations safe when Stealth Mode was already enabled.
    if (_stealthModeEnabled && !_hideNotificationContent) {
      await _prefs.setBool(_kStealthPreviousNotificationPrivacy, false);
      _hideNotificationContent = true;
      await _prefs.setBool(_kHideNotificationContent, true);
    }
    _stealthIconEnabled = _prefs.getBool(_kStealthIcon) ?? false;
    _highContrast = _prefs.getBool(_kHighContrast) ?? false;
    _reduceMotion = _prefs.getBool(_kReduceMotion) ?? false;
    _busyPreviousPresenceMode = _prefs.getString(_kBusyPreviousPresence);
    _doNotDisturbEnabled = _prefs.getBool(_kDoNotDisturb) ?? false;
    _activeSmartPresenceMode = normalizeSmartPresenceMode(_prefs.getString(_kActiveSmartPresenceMode) ?? 'online');
    _smartPresenceOverrides = {};
    final rawPresenceOverrides = _prefs.getString(_kSmartPresenceOverrides);
    if (rawPresenceOverrides != null) {
      try {
        final decoded = jsonDecode(rawPresenceOverrides);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final mode = normalizeSmartPresenceMode(entry.key.toString());
            if (entry.value is! Map) continue;
            final values = Map<String, dynamic>.from(entry.value as Map)
              ..removeWhere((key, _) => !_smartPresenceAllowedKeys.contains(key));
            if (values.isNotEmpty) _smartPresenceOverrides[mode] = values;
          }
        }
      } catch (_) { _smartPresenceOverrides = {}; }
    }
    
    // Load saved sessions
    final raw = _prefs.getString(_kSavedSessions);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _savedSessions = list
            .map((e) => SavedSession.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _savedSessions = [];
      }
    }
    _loaded = true;
    notifyListeners();
  }

  // ── Setters (persist immediately) ───────────────────────────────────────
  Future<void> setNotifications(bool v, {bool recordPresenceOverride = true}) async {
    _notificationsOn = v;
    await _prefs.setBool(_kNotifications, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('notificationsEnabled', v);
    notifyListeners();
  }

  Future<void> setChatLinkPreviews(bool v) async {
    _chatLinkPreviews = v;
    await _prefs.setBool(_kChatLinkPreviews, v);
    notifyListeners();
  }

  Future<void> setMessagePreview(bool v, {bool recordPresenceOverride = true}) async {
    _messagePreview = v;
    await _prefs.setBool(_kMessagePreview, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('messagePreviewEnabled', v);
    notifyListeners();
  }

  Future<void> setReadReceipts(bool v, {bool recordPresenceOverride = true}) async {
    _readReceipts = v;
    await _prefs.setBool(_kReadReceipts, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('readReceiptsEnabled', v);
    notifyListeners();
  }

  Future<void> setOnlineStatus(bool v) async {
    _onlineStatus = v;
    await _prefs.setBool(_kOnlineStatus, v);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setInt(_kThemeMode, mode.index);
    notifyListeners();
  }

  Future<void> setProfile({required String name, required String bio}) async {
    _displayName = name;
    _bio = bio;
    await _prefs.setString(_kDisplayName, name);
    await _prefs.setString(_kBio, bio);
    notifyListeners();
  }

  // ── New setters ──────────────────────────────────────────────────────────
  Future<void> setChatEnterToSend(bool v) async {
    _chatEnterToSend = v;
    await _prefs.setBool('chat_enter_to_send', v);
    notifyListeners();
  }

  Future<void> setInAppSounds(bool v, {bool recordPresenceOverride = true}) async {
    _inAppSounds = v;
    await _prefs.setBool(_kInAppSounds, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('inAppSoundsEnabled', v);
    notifyListeners();
  }

  Future<void> setInAppVibration(bool v, {bool recordPresenceOverride = true}) async {
    _inAppVibration = v;
    await _prefs.setBool(_kInAppVibration, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('inAppVibrationEnabled', v);
    notifyListeners();
  }

  Future<void> setHapticCategory(String category, bool enabled) async {
    final key = switch (category) {
      'navigation' => _kHapticNavigation,
      'typing' => _kHapticTyping,
      'chat' => _kHapticChat,
      'notifications' => _kHapticNotifications,
      'calls' => _kHapticCalls,
      'buttons' => _kHapticButtons,
      _ => null,
    };
    if (key == null) return;
    switch (category) {
      case 'navigation': _hapticNavigation = enabled; break;
      case 'typing': _hapticTyping = enabled; break;
      case 'chat': _hapticChat = enabled; break;
      case 'notifications': _hapticNotifications = enabled; break;
      case 'calls': _hapticCalls = enabled; break;
      case 'buttons': _hapticButtons = enabled; break;
    }
    await _prefs.setBool(key, enabled);
    notifyListeners();
  }

  Future<void> setGroupNotifications(bool v, {bool recordPresenceOverride = true}) async {
    _groupNotifications = v;
    await _prefs.setBool(_kGroupNotifications, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('groupNotificationsEnabled', v);
    notifyListeners();
  }

  Future<void> setAutoDownloadWifi(String v) async {
    _autoDownloadWifi = v;
    await _prefs.setString(_kAutoDownloadWifi, v);
    notifyListeners();
  }

  Future<void> setAutoDownloadMobile(String v) async {
    _autoDownloadMobile = v;
    await _prefs.setString(_kAutoDownloadMobile, v);
    notifyListeners();
  }

  Future<void> setPhotoQuality(String v) async {
    _photoQuality = v;
    await _prefs.setString(_kPhotoQuality, v);
    notifyListeners();
  }

  Future<void> setLanguage(String v) async {
    _language = v;
    await _prefs.setString(_kLanguage, v);
    notifyListeners();
  }

  Future<void> setAccentColor(int value) async {
    _accentColorValue = value;
    await _prefs.setInt(_kAccentColor, value);
    notifyListeners();
  }

  Future<void> setAccentColorEnabled(bool enabled) async {
    _accentColorEnabled = enabled;
    await _prefs.setBool(_kAccentColorEnabled, enabled);
    notifyListeners();
  }

  Future<void> setAlertStyle(String style) async {
    const allowed = {'snackbar', 'top_banner', 'capsule', 'switch_card', 'centre_hud', 'countdown_card'};
    if (!allowed.contains(style) || _alertStyle == style) return;
    _alertStyle = style;
    await _prefs.setString(_kAlertStyle, style);
    notifyListeners();
  }

  Future<void> setCallMiniStyle(String style) async {
    const allowed = {
      'top_banner', 'floating_avatar', 'compact_pill',
      'bottom_bar', 'video_card', 'edge_chip',
    };
    if (!allowed.contains(style) || _callMiniStyle == style) return;
    _callMiniStyle = style;
    await _prefs.setString(_kCallMiniStyle, style);
    notifyListeners();
  }

  Future<void> setDockStyle(String style) async {
    const allowed = {
      'slide_pill',
      'expand_capsule',
      'edge_to_edge',
      'dot_minimal',
      'soft_glow_glass',
      'liquid_stretch',
      'flip_tiles',
      'draw_ring',
    };
    if (!allowed.contains(style)) return;
    if (_dockStyle == style) return;
    _dockStyle = style;
    await _prefs.setString(_kDockStyle, style);
    notifyListeners();
  }

  Future<void> setChatLabelSize(double v) async {
    _chatLabelSize = v.clamp(0.8, 1.4).toDouble();
    await _prefs.setDouble(_kChatLabelSize, _chatLabelSize);
    notifyListeners();
  }

  Future<void> setFontSize(double v) async {
    v = v.clamp(0.75, 1.25).toDouble();
    _fontSize = v;
    await _prefs.setDouble(_kFontSize, v);
    notifyListeners();
  }

  Future<void> setHighContrast(bool v) async {
    _highContrast = v;
    await _prefs.setBool(_kHighContrast, v);
    notifyListeners();
  }

  Future<void> setDoNotDisturbEnabled(bool enabled) async {
    if (_doNotDisturbEnabled == enabled) return;

    // Persist first so a failed device-storage write never leaves the UI
    // showing a value that was not actually saved.
    final saved = await _prefs.setBool(_kDoNotDisturb, enabled);
    if (!saved) {
      throw StateError('Your device could not save the Do Not Disturb setting.');
    }

    _doNotDisturbEnabled = enabled;
    notifyListeners();
  }

  Future<void> setBusyPreviousPresenceMode(String? mode) async {
    const allowed = {'online', 'away', 'invisible'};
    _busyPreviousPresenceMode = mode != null && allowed.contains(mode) ? mode : null;
    if (_busyPreviousPresenceMode == null) {
      await _prefs.remove(_kBusyPreviousPresence);
    } else {
      await _prefs.setString(_kBusyPreviousPresence, _busyPreviousPresenceMode!);
    }
    notifyListeners();
  }

  Future<void> setReduceMotion(bool v) async {
    if (_reduceMotion == v) return;
    _reduceMotion = v;
    // Update MediaQuery immediately so the accessibility control never waits
    // on a disk write before reflecting the user's choice.
    notifyListeners();
    await _prefs.setBool(_kReduceMotion, v);
  }

  Future<void> setTwoFactorAuth(bool v) async {
    _twoFactorAuth = v;
    await _prefs.setBool(_kTwoFactorAuth, v);
    notifyListeners();
  }

  Future<void> setTimeFormat(String value) async {
    _timeFormat = value == '24h' ? '24h' : '12h';
    await _prefs.setString(_kTimeFormat, _timeFormat);
    notifyListeners();
  }

  Future<void> setLastSeenVisibility(String v, {bool recordPresenceOverride = true}) async {
    _lastSeenVisibility = v;
    await _prefs.setString(_kLastSeen, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('presencePrivacy', v == 'contacts' ? 'friends' : v);
    notifyListeners();
  }

  Future<void> setProfilePhotoVisibility(String v, {bool recordPresenceOverride = true}) async {
    _profilePhotoVisibility = v;
    await _prefs.setString(_kProfilePhoto, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('profilePhotoPrivacy', v == 'contacts' ? 'friends' : v);
    notifyListeners();
  }

  Future<void> toggleFavoriteChat(String chatId) async {
    if (_favoriteChatIds.contains(chatId)) {
      _favoriteChatIds.remove(chatId);
    } else {
      _favoriteChatIds.add(chatId);
    }
    await _prefs.setStringList(_kFavoriteChatIds, _favoriteChatIds);
    notifyListeners();
  }

  Future<void> blockUser(String uid) async {
    if (!_blockedUids.contains(uid)) {
      _blockedUids.add(uid);
      await _prefs.setStringList(_kBlockedUids, _blockedUids);
      notifyListeners();
    }
  }

  Future<void> unblockUser(String uid) async {
    if (_blockedUids.contains(uid)) {
      _blockedUids.remove(uid);
      await _prefs.setStringList(_kBlockedUids, _blockedUids);
      notifyListeners();
    }
  }

  Future<void> setNotificationTone(String v) async {
    _notificationTone = v;
    await _prefs.setString(_kNotificationTone, v);
    notifyListeners();
  }

  Future<void> setCallRingtone(String v) async {
    _callRingtone = v;
    await _prefs.setString(_kCallRingtone, v);
    notifyListeners();
  }

  Future<void> setCustomNotificationPath(String? path) async {
    _customNotificationPath = path;
    if (path == null) {
      await _prefs.remove(_kCustomNotificationPath);
    } else {
      await _prefs.setString(_kCustomNotificationPath, path);
    }
    notifyListeners();
  }

  Future<void> setCustomRingtonePath(String? path) async {
    _customRingtonePath = path;
    if (path == null) {
      await _prefs.remove(_kCustomRingtonePath);
    } else {
      await _prefs.setString(_kCustomRingtonePath, path);
    }
    notifyListeners();
  }

  Future<void> setRegion(String v) async {
    _region = v;
    await _prefs.setString(_kRegion, v);
    
    // Auto-update language if current language is not in the new region's list
    final allowed = getLanguagesForRegion(v).keys.toList();
    if (!allowed.contains(_language)) {
      await setLanguage(allowed.first);
    }
    
    notifyListeners();
  }

  Map<String, String> getLanguagesForRegion(String regionName) {
    switch (regionName) {
      case 'India':
        return {
          'hi': 'हिन्दी (Hindi)',
          'en': 'English',
          'mr': 'मराठी (Marathi)',
          'bn': 'বাংলা (Bengali)',
          'ta': 'தமிழ் (Tamil)',
          'te': 'తెలుగు (Telugu)',
        };
      case 'United States':
        return {'en': 'English', 'es': 'Español'};
      case 'United Kingdom':
        return {'en': 'English'};
      case 'Germany':
        return {'de': 'Deutsch', 'en': 'English'};
      case 'France':
        return {'fr': 'Français', 'en': 'English'};
      case 'Spain':
        return {'es': 'Español', 'en': 'English'};
      case 'Italy':
        return {'it': 'Italiano', 'en': 'English'};
      case 'Japan':
        return {'ja': '日本語 (Japanese)', 'en': 'English'};
      case 'South Korea':
        return {'ko': '한국어 (Korean)', 'en': 'English'};
      case 'Russia':
        return {'ru': 'Русский (Russian)', 'en': 'English'};
      case 'Canada':
        return {'en': 'English', 'fr': 'Français'};
      default:
        return {'en': 'English'};
    }
  }

  Future<void> setVibrationPattern(String v) async {
    _vibrationPattern = v;
    await _prefs.setString(_kVibrationPattern, v);
    notifyListeners();
  }

  String _detectDeviceRegion() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final countryCode = locale.countryCode?.toUpperCase();
    
    // Fallback: Detection via Timezone Offset (India is UTC+5.5)
    final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    if (offsetMinutes == 330) return 'India';
    
    switch (countryCode) {
      case 'IN': return 'India';
      case 'GB': return 'United Kingdom';
      case 'CA': return 'Canada';
      case 'AU': return 'Australia';
      case 'DE': return 'Germany';
      case 'FR': return 'France';
      case 'ES': return 'Spain';
      case 'IT': return 'Italy';
      case 'JP': return 'Japan';
      case 'KR': return 'South Korea';
      case 'RU': return 'Russia';
      default: return 'United States';
    }
  }

  String _detectDeviceLanguage() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    return locale.languageCode.toLowerCase();
  }

  Future<void> setMessageVolume(double v) async {
    _messageVolume = v.clamp(0.0, 1.0).toDouble();
    await _prefs.setDouble('novyn_message_volume', _messageVolume);
    notifyListeners();
  }

  Future<void> setCallVolume(double v) async {
    _callVolume = v.clamp(0.0, 1.0).toDouble();
    await _prefs.setDouble('novyn_call_volume', _callVolume);
    notifyListeners();
  }

  Future<void> setHapticIntensity(double v) async {
    v = v.clamp(0.0, 1.0).toDouble();
    _hapticIntensity = v;
    await _prefs.setDouble(_kHapticIntensity, v);
    notifyListeners();
  }

  Future<void> setAppLockEnabled(bool v) async {
    if (v && _appLockPin == null) {
      throw StateError('Set an app lock PIN before enabling App Lock.');
    }
    _appLockEnabled = v;
    await _prefs.setBool(_kAppLockEnabled, v);
    notifyListeners();
  }

  Future<void> setAppLockTimeout(int v) async {
    _appLockTimeout = v;
    await _prefs.setInt(_kAppLockTimeout, v);
    notifyListeners();
  }

  Future<void> setAppLockPin(String? pin) async {
    if (pin != null && (pin.length != 4 || int.tryParse(pin) == null)) {
      throw ArgumentError('App lock PIN must contain exactly 4 digits.');
    }
    _appLockPin = pin;
    if (pin == null) {
      await _deleteSecureValue(_secureAppLockPin);
    } else if (!await _writeSecureValue(_secureAppLockPin, pin)) {
      throw StateError('Secure storage is temporarily unavailable. Try again.');
    }
    notifyListeners();
  }

  Future<void> recordFailedAppLockAttempt() async {
    _appLockFailedAttempts += 1;
    await _writeSecureValue(
      _secureAppLockFailures,
      _appLockFailedAttempts.toString(),
    );
    Duration? cooldown;
    if (_appLockFailedAttempts == 15) {
      cooldown = const Duration(minutes: 10);
    } else if (_appLockFailedAttempts == 10) {
      cooldown = const Duration(minutes: 2);
    } else if (_appLockFailedAttempts == 5) {
      cooldown = const Duration(seconds: 30);
    }
    if (cooldown != null) {
      _appLockLockedUntil = DateTime.now().add(cooldown);
      await _writeSecureValue(
        _secureAppLockUntil,
        _appLockLockedUntil!.millisecondsSinceEpoch.toString(),
      );
    }
    notifyListeners();
  }

  Future<void> resetAppLockFailures() async {
    _appLockFailedAttempts = 0;
    _appLockLockedUntil = null;
    await _deleteSecureValue(_secureAppLockFailures);
    await _deleteSecureValue(_secureAppLockUntil);
    notifyListeners();
  }

  // Recovery deliberately requires a fresh account sign-in. The PIN is
  // removed only after the user confirms they want to sign out.
  Future<void> prepareAppLockAccountRecovery() async {
    _appLockEnabled = false;
    _isLocked = false;
    await _prefs.setBool(_kAppLockEnabled, false);
    await setAppLockPin(null);
    await resetAppLockFailures();
    notifyListeners();
  }

  void setLocked(bool v) {
    _isLocked = v;
    notifyListeners();
  }

  Future<void> setStealthMode(bool v) async {
    if (v == _stealthModeEnabled) return;

    // Commit the in-memory value only after the device confirms persistence.
    final saved = await _prefs.setBool(_kStealthMode, v);
    if (!saved) {
      throw StateError('Your device could not save the Stealth Mode setting.');
    }

    _stealthModeEnabled = v;
    notifyListeners();
  }

  Future<void> setPanicPin(String? pin) async {
    if (pin != null && (pin.length != 4 || int.tryParse(pin) == null)) {
      throw ArgumentError('Panic PIN must contain exactly 4 digits.');
    }
    _panicPin = pin;
    if (pin == null) {
      await _deleteSecureValue(_securePanicPin);
    } else if (!await _writeSecureValue(_securePanicPin, pin)) {
      throw StateError('Secure storage is temporarily unavailable. Try again.');
    }
    notifyListeners();
  }

  Future<void> setHideNotificationContent(bool v) async {
    _hideNotificationContent = v;
    await _prefs.setBool(_kHideNotificationContent, v);
    notifyListeners();
  }

  void setDecoyMode(bool v) {
    _decoyMode = v;
    notifyListeners();
  }

  Future<void> setStealthIconEnabled(bool v) async {
    _stealthIconEnabled = v;
    await _prefs.setBool(_kStealthIcon, v);
    notifyListeners();
  }

  void unlockWithDecoy(bool isDecoy) {
    _decoyMode = isDecoy;
    _isLocked = false;
    resetAppLockFailures();
    notifyListeners();
  }

  bool isBlocked(String uid) => _blockedUids.contains(uid);

  // ── Saved sessions ───────────────────────────────────────────────────────
  Future<void> saveSession(SavedSession session) async {
    // Remove existing entry for same uid/email, then add fresh
    _savedSessions.removeWhere(
        (s) => s.uid == session.uid || s.email == session.email);
    _savedSessions.insert(0, session); // most recent first
    // Keep max 5 saved accounts
    if (_savedSessions.length > 5) _savedSessions = _savedSessions.sublist(0, 5);
    await _persistSessions();
    notifyListeners();
  }

  Future<void> removeSession(String uid) async {
    _savedSessions.removeWhere((s) => s.uid == uid);
    await _persistSessions();
    notifyListeners();
  }

  Future<void> _persistSessions() async {
    final encoded = jsonEncode(_savedSessions.map((s) => s.toJson()).toList());
    await _prefs.setString(_kSavedSessions, encoded);
  }

  /// Export only account-level preferences. Device secrets, local file paths,
  /// biometric/app-lock state and transient runtime flags are intentionally
  /// excluded from cloud sync.
  Map<String, dynamic> cloudSyncSnapshot({String? accountKey}) => {
        'chatLinkPreviews': _chatLinkPreviews,
        'onlineStatus': _onlineStatus,
        'themeMode': _themeMode.name,
        'chatEnterToSend': _chatEnterToSend,
        'autoDownloadWifi': _autoDownloadWifi,
        'autoDownloadMobile': _autoDownloadMobile,
        'photoQuality': _photoQuality,
        'language': _language,
        'timeFormat': _timeFormat,
        'fontSize': _fontSize,
        'chatLabelSize': _chatLabelSize,
        'accentColorValue': _accentColorValue,
        'accentColorEnabled': _accentColorEnabled,
        'dockStyle': _dockStyle,
        'alertStyle': _alertStyle,
        'notificationTone': _notificationTone,
        'callRingtone': _callRingtone,
        'vibrationPattern': _vibrationPattern,
        'hapticIntensity': _hapticIntensity,
        'hapticNavigation': _hapticNavigation,
        'hapticTyping': _hapticTyping,
        'hapticChat': _hapticChat,
        'hapticButtons': _hapticButtons,
        'hapticNotifications': _hapticNotifications,
        'hapticCalls': _hapticCalls,
        'messageVolume': _messageVolume,
        'callVolume': _callVolume,
        'region': _region,
        'highContrast': _highContrast,
        'reduceMotion': _reduceMotion,
        'doNotDisturbEnabled': _doNotDisturbEnabled,
        if (accountKey != null && accountKey.trim().isNotEmpty)
          'quickToggleIds': quickToggleIdsFor(accountKey),
      };

  /// Apply an account snapshot without invoking each public setter (and
  /// therefore without causing a burst of listener notifications/network work).
  /// The UI receives one notification after the local cache has been updated.
  Future<void> applyCloudSyncSnapshot(
    Map<String, dynamic> values, {
    String? accountKey,
  }) async {
    if (!_loaded) {
      throw StateError('Settings must be loaded before applying cloud settings.');
    }

    bool boolValue(String key, bool fallback) =>
        values[key] is bool ? values[key] as bool : fallback;
    String stringValue(String key, String fallback) =>
        values[key] is String ? (values[key] as String) : fallback;
    double doubleValue(String key, double fallback, double min, double max) {
      final raw = values[key];
      final value = raw is num ? raw.toDouble() : fallback;
      return value.clamp(min, max).toDouble();
    }

    _notificationsOn = boolValue('notificationsOn', _notificationsOn);
    _messagePreview = boolValue('messagePreview', _messagePreview);
    _chatLinkPreviews = boolValue('chatLinkPreviews', _chatLinkPreviews);
    _readReceipts = boolValue('readReceipts', _readReceipts);
    _onlineStatus = boolValue('onlineStatus', _onlineStatus);
    final themeName = stringValue('themeMode', _themeMode.name);
    _themeMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == themeName,
      orElse: () => _themeMode,
    );
    _inAppSounds = boolValue('inAppSounds', _inAppSounds);
    _chatEnterToSend = boolValue('chatEnterToSend', _chatEnterToSend);
    _inAppVibration = boolValue('inAppVibration', _inAppVibration);
    _groupNotifications = boolValue('groupNotifications', _groupNotifications);
    _autoDownloadWifi = stringValue('autoDownloadWifi', _autoDownloadWifi);
    _autoDownloadMobile = stringValue('autoDownloadMobile', _autoDownloadMobile);
    _photoQuality = stringValue('photoQuality', _photoQuality);
    _language = stringValue('language', _language);
    _timeFormat = stringValue('timeFormat', _timeFormat) == '24h' ? '24h' : '12h';
    _fontSize = doubleValue('fontSize', _fontSize, 0.75, 1.25);
    _chatLabelSize = doubleValue('chatLabelSize', _chatLabelSize, 0.8, 1.4);
    final accent = values['accentColorValue'];
    if (accent is num && accent.toInt() >= 0 && accent.toInt() <= 0xFFFFFFFF) {
      _accentColorValue = accent.toInt();
    }
    _accentColorEnabled = boolValue('accentColorEnabled', _accentColorEnabled);

    const dockStyles = {
      'slide_pill', 'expand_capsule', 'edge_to_edge', 'dot_minimal',
      'soft_glow_glass', 'liquid_stretch', 'flip_tiles', 'draw_ring',
    };
    final dockStyle = stringValue('dockStyle', _dockStyle);
    if (dockStyles.contains(dockStyle)) _dockStyle = dockStyle;
    const alertStyles = {
      'snackbar', 'top_banner', 'capsule', 'switch_card',
      'centre_hud', 'countdown_card',
    };
    final alertStyle = stringValue('alertStyle', _alertStyle);
    if (alertStyles.contains(alertStyle)) _alertStyle = alertStyle;

    _notificationTone = stringValue('notificationTone', _notificationTone);
    _callRingtone = stringValue('callRingtone', _callRingtone);
    _vibrationPattern = stringValue('vibrationPattern', _vibrationPattern);
    _hapticIntensity = doubleValue('hapticIntensity', _hapticIntensity, 0, 1);
    _hapticNavigation = boolValue('hapticNavigation', _hapticNavigation);
    _hapticTyping = boolValue('hapticTyping', _hapticTyping);
    _hapticChat = boolValue('hapticChat', _hapticChat);
    _hapticButtons = boolValue('hapticButtons', _hapticButtons);
    _hapticNotifications = boolValue('hapticNotifications', _hapticNotifications);
    _hapticCalls = boolValue('hapticCalls', _hapticCalls);
    _messageVolume = doubleValue('messageVolume', _messageVolume, 0, 1);
    _callVolume = doubleValue('callVolume', _callVolume, 0, 1);
    _region = stringValue('region', _region);
    _highContrast = boolValue('highContrast', _highContrast);
    _reduceMotion = boolValue('reduceMotion', _reduceMotion);
    _doNotDisturbEnabled = boolValue('doNotDisturbEnabled', _doNotDisturbEnabled);

    final writes = <Future<bool>>[
      _prefs.setBool(_kNotifications, _notificationsOn),
      _prefs.setBool(_kMessagePreview, _messagePreview),
      _prefs.setBool(_kChatLinkPreviews, _chatLinkPreviews),
      _prefs.setBool(_kReadReceipts, _readReceipts),
      _prefs.setBool(_kOnlineStatus, _onlineStatus),
      _prefs.setInt(_kThemeMode, _themeMode.index),
      _prefs.setBool(_kInAppSounds, _inAppSounds),
      _prefs.setBool('chat_enter_to_send', _chatEnterToSend),
      _prefs.setBool(_kInAppVibration, _inAppVibration),
      _prefs.setBool(_kGroupNotifications, _groupNotifications),
      _prefs.setString(_kAutoDownloadWifi, _autoDownloadWifi),
      _prefs.setString(_kAutoDownloadMobile, _autoDownloadMobile),
      _prefs.setString(_kPhotoQuality, _photoQuality),
      _prefs.setString(_kLanguage, _language),
      _prefs.setString(_kTimeFormat, _timeFormat),
      _prefs.setDouble(_kFontSize, _fontSize),
      _prefs.setDouble(_kChatLabelSize, _chatLabelSize),
      _prefs.setInt(_kAccentColor, _accentColorValue),
      _prefs.setBool(_kAccentColorEnabled, _accentColorEnabled),
      _prefs.setString(_kDockStyle, _dockStyle),
      _prefs.setString(_kAlertStyle, _alertStyle),
      _prefs.setString(_kNotificationTone, _notificationTone),
      _prefs.setString(_kCallRingtone, _callRingtone),
      _prefs.setString(_kVibrationPattern, _vibrationPattern),
      _prefs.setDouble(_kHapticIntensity, _hapticIntensity),
      _prefs.setBool(_kHapticNavigation, _hapticNavigation),
      _prefs.setBool(_kHapticTyping, _hapticTyping),
      _prefs.setBool(_kHapticChat, _hapticChat),
      _prefs.setBool(_kHapticButtons, _hapticButtons),
      _prefs.setBool(_kHapticNotifications, _hapticNotifications),
      _prefs.setBool(_kHapticCalls, _hapticCalls),
      _prefs.setDouble('novyn_message_volume', _messageVolume),
      _prefs.setDouble('novyn_call_volume', _callVolume),
      _prefs.setString(_kRegion, _region),
      _prefs.setBool(_kHighContrast, _highContrast),
      _prefs.setBool(_kReduceMotion, _reduceMotion),
      _prefs.setBool(_kDoNotDisturb, _doNotDisturbEnabled),
    ];
    final quickIds = values['quickToggleIds'];
    if (accountKey != null &&
        accountKey.trim().isNotEmpty &&
        quickIds is List) {
      final cleaned = sanitizeQuickToggleIds(
        quickIds.whereType<String>(),
      );
      if (cleaned.isNotEmpty) {
        writes.add(_prefs.setStringList(
          _quickToggleStorageKey(accountKey),
          cleaned,
        ));
      }
    }
    await Future.wait(writes);
    notifyListeners();
  }

  Future<void> clearAll() async {
    await _prefs.clear();
    await _deleteSecureValue(_secureAppLockPin);
    await _deleteSecureValue(_securePanicPin);
    _notificationsOn = true;
    _messagePreview = true;
    _chatLinkPreviews = true;
    _readReceipts = true;
    _onlineStatus = true;
    _themeMode = ThemeMode.system;
    _displayName = '';
    _bio = '';
    _savedSessions = [];
    
    // Reset new settings
    _inAppSounds = true;
    _chatEnterToSend = true;
    _inAppVibration = true;
    _groupNotifications = true;
    _autoDownloadWifi = 'all';
    _autoDownloadMobile = 'photos';
    _photoQuality = 'high';
    _language = 'en';
    _fontSize = 0.85;
    _chatLabelSize = 1.0;
    _accentColorValue = 0xFF6D5DFC;
    _accentColorEnabled = true;
    _dockStyle = 'slide_pill';
    _alertStyle = 'snackbar';
    _callMiniStyle = 'top_banner';
    _twoFactorAuth = false;
    _lastSeenVisibility = 'everyone';
    _profilePhotoVisibility = 'everyone';
    _blockedUids = [];
    _notificationTone = 'Aurora';
    _vibrationPattern = 'standard';
    _hapticIntensity = 0.8;
    _appLockEnabled = false;
    _appLockTimeout = 0;
    
    notifyListeners();
  }
  @override
  void dispose() {
    super.dispose();
  }

}
).hasMatch(end)) {
      _quietHoursEnd = end;
      await _prefs.setString(_kQuietHoursEnd, end);
      changed = true;
    }
    if (offset is num) {
      _quietHoursOffsetMinutes = offset.toInt().clamp(-840, 840);
      await _prefs.setInt(_kQuietHoursOffsetMinutes, _quietHoursOffsetMinutes);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  Future<void> setQuietHoursSchedule({
    String? start,
    String? end,
    int? offsetMinutes,
  }) async {
    final timePattern = RegExp(r'^([01]\\d|2[0-3]):[0-5]\\d
  String get autoDownloadWifi => _autoDownloadWifi;
  String get autoDownloadMobile => _autoDownloadMobile;
  String get notificationTone => _notificationTone;
  String get callRingtone => _callRingtone;
  String? get customNotificationPath => _customNotificationPath;
  String? get customRingtonePath => _customRingtonePath;
  String get region => _region;
  String get language => _language;
  String get timeFormat => _timeFormat;
  String get vibrationPattern => _vibrationPattern;
  double get hapticIntensity => _hapticIntensity;
  bool get hapticNavigation => _hapticNavigation;
  bool get hapticTyping => _hapticTyping;
  bool get hapticChat => _hapticChat;
  bool get hapticButtons => _hapticButtons;
  bool get hapticNotifications => _hapticNotifications;
  bool get hapticCalls => _hapticCalls;
  bool hapticCategoryEnabled(String category) => switch (category) {
    'navigation' => _hapticNavigation,
    'typing' => _hapticTyping,
    'chat' => _hapticChat,
    'notifications' => _hapticNotifications,
    'calls' => _hapticCalls,
    _ => _hapticButtons,
  };
  double get messageVolume => _messageVolume;
  double get callVolume => _callVolume;
  String get photoQuality => _photoQuality;
  double get fontSize => _fontSize;
  double get chatLabelSize => _chatLabelSize;
  int get accentColorValue => _accentColorValue;
  bool get accentColorEnabled => _accentColorEnabled;
  String get dockStyle => _dockStyle;
  String get alertStyle => _alertStyle;
  String get callMiniStyle => _callMiniStyle;
  bool get twoFactorAuth => _twoFactorAuth;
  String get lastSeenVisibility => _stealthModeEnabled ? 'nobody' : _lastSeenVisibility;
  String get profilePhotoVisibility => _stealthModeEnabled ? 'nobody' : _profilePhotoVisibility;
  String get configuredLastSeenVisibility => _lastSeenVisibility;
  String get configuredProfilePhotoVisibility => _profilePhotoVisibility;
  List<String> get blockedUids => _blockedUids;
  List<String> get favoriteChatIds => List.unmodifiable(_favoriteChatIds);
  bool get appLockEnabled => _appLockEnabled;
  int get appLockTimeout => _appLockTimeout;
  String? get appLockPin => _appLockPin;
  bool get secureStorageAvailable => !_secureStorageReadFailed;
  bool get isLocked => _isLocked;
  int get appLockFailedAttempts => _appLockFailedAttempts;
  Duration get appLockRemaining {
    final until = _appLockLockedUntil;
    if (until == null) return Duration.zero;
    final remaining = until.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
  bool get isAppLockCoolingDown => appLockRemaining > Duration.zero;
  bool get stealthModeEnabled => _stealthModeEnabled;
  String? get panicPin => _panicPin;
  bool get hideNotificationContent => _hideNotificationContent;
  bool get decoyMode => _decoyMode;
  bool get stealthIconEnabled => _stealthIconEnabled;
  bool get highContrast => _highContrast;
  bool get reduceMotion => _reduceMotion;
  String? get busyPreviousPresenceMode => _busyPreviousPresenceMode;
  bool get doNotDisturbEnabled => _doNotDisturbEnabled;
  String get activeSmartPresenceMode => _activeSmartPresenceMode;
  static const Set<String> _smartPresenceServerKeys = {
    'callsEnabled', 'callPrivacy', 'messagePrivacy', 'profilePhotoPrivacy', 'presencePrivacy',
    'discoverPrivacy', 'groupInvitePrivacy', 'friendRequestPrivacy',
    'readReceiptsEnabled', 'typingIndicatorsEnabled', 'notificationsEnabled',
    'messagePreviewEnabled', 'groupNotificationsEnabled',
  };
  static const Set<String> _smartPresenceLocalKeys = {'inAppSoundsEnabled', 'inAppVibrationEnabled'};
  static const Set<String> _smartPresenceAllowedKeys = {
    ..._smartPresenceServerKeys, ..._smartPresenceLocalKeys,
  };
  static String normalizeSmartPresenceMode(String mode) {
    final value = mode.trim().toLowerCase();
    if (value == 'away' || value == 'idle') return 'idle';
    if (value == 'dnd') return 'busy';
    if (value == 'offline') return 'invisible';
    return const {'online', 'busy', 'invisible'}.contains(value) ? value : 'online';
  }
  static String presenceStatusForSmartMode(String mode) =>
      normalizeSmartPresenceMode(mode) == 'idle' ? 'away' : normalizeSmartPresenceMode(mode);
  static Map<String, dynamic> smartPresenceDefaults(String mode) {
    switch (normalizeSmartPresenceMode(mode)) {
      case 'idle':
        return {
          'callsEnabled': true, 'callPrivacy': 'friends', 'messagePrivacy': 'friends',
          'profilePhotoPrivacy': 'friends', 'presencePrivacy': 'friends',
          'discoverPrivacy': 'friends', 'groupInvitePrivacy': 'friends',
          'friendRequestPrivacy': 'mutuals',
          'readReceiptsEnabled': true, 'typingIndicatorsEnabled': true,
          'notificationsEnabled': true, 'messagePreviewEnabled': true,
          'groupNotificationsEnabled': true, 'inAppSoundsEnabled': true,
          'inAppVibrationEnabled': true,
        };
      case 'busy':
        return {
          'callsEnabled': true, 'callPrivacy': 'nobody', 'messagePrivacy': 'friends',
          'profilePhotoPrivacy': 'friends', 'presencePrivacy': 'friends',
          'discoverPrivacy': 'friends', 'groupInvitePrivacy': 'friends',
          'friendRequestPrivacy': 'mutuals',
          'readReceiptsEnabled': false, 'typingIndicatorsEnabled': false,
          'notificationsEnabled': false, 'messagePreviewEnabled': false,
          'groupNotificationsEnabled': false, 'inAppSoundsEnabled': false,
          'inAppVibrationEnabled': false,
        };
      case 'invisible':
        return {
          'callsEnabled': false, 'callPrivacy': 'nobody', 'messagePrivacy': 'friends',
          'profilePhotoPrivacy': 'nobody', 'presencePrivacy': 'nobody',
          'discoverPrivacy': 'nobody', 'groupInvitePrivacy': 'nobody',
          'friendRequestPrivacy': 'nobody',
          'readReceiptsEnabled': false, 'typingIndicatorsEnabled': false,
          'notificationsEnabled': false, 'messagePreviewEnabled': false,
          'groupNotificationsEnabled': false, 'inAppSoundsEnabled': false,
          'inAppVibrationEnabled': false,
        };
      case 'online':
      default:
        return {
          'callsEnabled': true, 'callPrivacy': 'everyone', 'messagePrivacy': 'everyone',
          'profilePhotoPrivacy': 'everyone', 'presencePrivacy': 'everyone',
          'discoverPrivacy': 'everyone', 'groupInvitePrivacy': 'everyone',
          'friendRequestPrivacy': 'everyone',
          'readReceiptsEnabled': true, 'typingIndicatorsEnabled': true,
          'notificationsEnabled': true, 'messagePreviewEnabled': true,
          'groupNotificationsEnabled': true, 'inAppSoundsEnabled': true,
          'inAppVibrationEnabled': true,
        };
    }
  }
  Map<String, dynamic> smartPresencePolicyFor(String mode) {
    final key = normalizeSmartPresenceMode(mode);
    return {...smartPresenceDefaults(key), ...?_smartPresenceOverrides[key]};
  }
  bool hasSmartPresenceCustomizations(String mode) =>
      _smartPresenceOverrides[normalizeSmartPresenceMode(mode)]?.isNotEmpty ?? false;
  static Map<String, dynamic> smartPresenceServerFields(Map<String, dynamic> policy) => {
    for (final entry in policy.entries)
      if (_smartPresenceServerKeys.contains(entry.key)) entry.key: entry.value,
  };
  Future<void> saveSmartPresenceOverride(String mode, String key, dynamic value) async {
    if (!_smartPresenceAllowedKeys.contains(key)) {
      throw ArgumentError.value(key, 'key', 'Unsupported Smart Presence setting');
    }
    final normalized = normalizeSmartPresenceMode(mode);
    final overrides = _smartPresenceOverrides.putIfAbsent(normalized, () => <String, dynamic>{});
    if (smartPresenceDefaults(normalized)[key] == value) {
      overrides.remove(key);
    } else {
      overrides[key] = value;
    }
    if (overrides.isEmpty) _smartPresenceOverrides.remove(normalized);
    await _prefs.setString(_kSmartPresenceOverrides, jsonEncode(_smartPresenceOverrides));
    notifyListeners();
  }
  Future<void> hydrateSmartPresenceModeFromServer(
    String mode,
    Map<String, dynamic> serverPolicy,
  ) async {
    final normalized = normalizeSmartPresenceMode(mode);
    final defaults = smartPresenceDefaults(normalized);
    final previous = _smartPresenceOverrides[normalized] ?? const <String, dynamic>{};
    final next = <String, dynamic>{};
    const privacyValues = {'everyone', 'friends', 'nobody', 'mutuals'};

    for (final key in _smartPresenceServerKeys) {
      if (!serverPolicy.containsKey(key)) continue;
      final value = serverPolicy[key];
      final defaultValue = defaults[key];
      if (defaultValue is bool && value is bool) {
        if (value != defaultValue) next[key] = value;
      } else if (defaultValue is String &&
          value is String &&
          privacyValues.contains(value)) {
        if (value != defaultValue) next[key] = value;
      }
    }
    for (final key in _smartPresenceLocalKeys) {
      if (previous.containsKey(key)) next[key] = previous[key];
    }

    if (next.isEmpty) {
      _smartPresenceOverrides.remove(normalized);
    } else {
      _smartPresenceOverrides[normalized] = next;
    }
    await _prefs.setString(_kSmartPresenceOverrides, jsonEncode(_smartPresenceOverrides));
    notifyListeners();
  }

  Future<void> recordActiveSmartPresenceOverride(String key, dynamic value) =>
      saveSmartPresenceOverride(_activeSmartPresenceMode, key, value);
  Future<void> resetSmartPresenceOverrides(String mode) async {
    _smartPresenceOverrides.remove(normalizeSmartPresenceMode(mode));
    await _prefs.setString(_kSmartPresenceOverrides, jsonEncode(_smartPresenceOverrides));
    notifyListeners();
  }
  Future<void> applySmartPresenceLocalPolicy(String mode, {Map<String, dynamic>? policy}) async {
    final normalized = normalizeSmartPresenceMode(mode);
    final values = policy ?? smartPresencePolicyFor(normalized);
    _activeSmartPresenceMode = normalized;
    _notificationsOn = values['notificationsEnabled'] != false;
    _messagePreview = values['messagePreviewEnabled'] != false;
    _groupNotifications = values['groupNotificationsEnabled'] != false;
    _readReceipts = values['readReceiptsEnabled'] != false;
    _inAppSounds = values['inAppSoundsEnabled'] != false;
    _inAppVibration = values['inAppVibrationEnabled'] != false;
    final presence = values['presencePrivacy']?.toString() ?? 'everyone';
    final photo = values['profilePhotoPrivacy']?.toString() ?? 'everyone';
    _lastSeenVisibility = presence == 'friends' ? 'contacts' : presence;
    _profilePhotoVisibility = photo == 'friends' ? 'contacts' : photo;
    await Future.wait([
      _prefs.setString(_kActiveSmartPresenceMode, normalized),
      _prefs.setBool(_kNotifications, _notificationsOn),
      _prefs.setBool(_kMessagePreview, _messagePreview),
      _prefs.setBool(_kGroupNotifications, _groupNotifications),
      _prefs.setBool(_kReadReceipts, _readReceipts),
      _prefs.setBool(_kInAppSounds, _inAppSounds),
      _prefs.setBool(_kInAppVibration, _inAppVibration),
      _prefs.setString(_kLastSeen, _lastSeenVisibility),
      _prefs.setString(_kProfilePhoto, _profilePhotoVisibility),
    ]);
    notifyListeners();
  }
  Future<void> setActiveSmartPresenceMode(String mode) async {
    _activeSmartPresenceMode = normalizeSmartPresenceMode(mode);
    await _prefs.setString(_kActiveSmartPresenceMode, _activeSmartPresenceMode);
    notifyListeners();
  }

  // ── Load from disk ───────────────────────────────────────────────────────
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _notificationsOn = _prefs.getBool(_kNotifications) ?? true;
    _messagePreview = _prefs.getBool(_kMessagePreview) ?? true;
    _chatLinkPreviews = _prefs.getBool(_kChatLinkPreviews) ?? true;
    _readReceipts = _prefs.getBool(_kReadReceipts) ?? true;
    _onlineStatus = _prefs.getBool(_kOnlineStatus) ?? true;
    _themeMode = ThemeMode.values[_prefs.getInt(_kThemeMode) ?? ThemeMode.light.index];
    _displayName = _prefs.getString(_kDisplayName) ?? '';
    _bio = _prefs.getString(_kBio) ?? '';
    
    // Load new settings
    _inAppSounds = _prefs.getBool(_kInAppSounds) ?? true;
    _chatEnterToSend = _prefs.getBool('chat_enter_to_send') ?? true;
    _inAppVibration = _prefs.getBool(_kInAppVibration) ?? true;
    _groupNotifications = _prefs.getBool(_kGroupNotifications) ?? true;
    _notificationPreferences = {...notificationPreferenceDefaults};
    for (final entry in notificationPreferenceStorageKeys.entries) {
      _notificationPreferences[entry.key] =
          _prefs.getBool(entry.value) ?? notificationPreferenceDefaults[entry.key]!;
    }
    _quietHoursStart = _prefs.getString(_kQuietHoursStart) ?? '22:00';
    _quietHoursEnd = _prefs.getString(_kQuietHoursEnd) ?? '07:00';
    _quietHoursOffsetMinutes = (_prefs.getInt(_kQuietHoursOffsetMinutes) ??
        DateTime.now().timeZoneOffset.inMinutes).clamp(-840, 840);
    _autoDownloadWifi = _prefs.getString(_kAutoDownloadWifi) ?? 'all';
    _autoDownloadMobile = _prefs.getString(_kAutoDownloadMobile) ?? 'photos';
    _photoQuality = _prefs.getString(_kPhotoQuality) ?? 'high';
    _language = _prefs.getString(_kLanguage) ?? 'en';
    final savedTimeFormat = _prefs.getString(_kTimeFormat) ?? '12h';
    _timeFormat = savedTimeFormat == '24h' ? '24h' : '12h';
    _fontSize = (_prefs.getDouble(_kFontSize) ?? 0.85).clamp(0.75, 1.25).toDouble();
    _chatLabelSize = (_prefs.getDouble(_kChatLabelSize) ?? 1.0).clamp(0.8, 1.4).toDouble();
    _accentColorValue = _prefs.getInt(_kAccentColor) ?? 0xFF6D5DFC;
    _accentColorEnabled = _prefs.getBool(_kAccentColorEnabled) ?? true;
    const alertStyles = {'snackbar', 'top_banner', 'capsule', 'switch_card', 'centre_hud', 'countdown_card'};
    final savedAlertStyle = _prefs.getString(_kAlertStyle) ?? 'snackbar';
    _alertStyle = alertStyles.contains(savedAlertStyle) ? savedAlertStyle : 'snackbar';
    if (_alertStyle != savedAlertStyle) await _prefs.setString(_kAlertStyle, _alertStyle);
    const callMiniStyles = {
      'top_banner', 'floating_avatar', 'compact_pill',
      'bottom_bar', 'video_card', 'edge_chip',
    };
    const legacyCallMiniStyles = <String, String>{
      'floating_bar': 'top_banner',
      'glass_card': 'video_card',
      'accent_strip': 'top_banner',
      'avatar_bubble': 'floating_avatar',
      'video_focus': 'video_card',
    };
    final savedCallMiniStyle = _prefs.getString(_kCallMiniStyle) ?? 'top_banner';
    _callMiniStyle = callMiniStyles.contains(savedCallMiniStyle)
        ? savedCallMiniStyle
        : legacyCallMiniStyles[savedCallMiniStyle] ?? 'top_banner';
    if (_callMiniStyle != savedCallMiniStyle) {
      await _prefs.setString(_kCallMiniStyle, _callMiniStyle);
    }
    const dockStyles = [
      'slide_pill',
      'expand_capsule',
      'edge_to_edge',
      'dot_minimal',
      'soft_glow_glass',
      'liquid_stretch',
      'flip_tiles',
      'draw_ring',
    ];
    const legacyDockStyles = <String, String>{
      'floating_pill': 'slide_pill',
      'rounded_bar': 'slide_pill',
      'minimal': 'dot_minimal',
      'glass': 'soft_glow_glass',
      'sliding': 'slide_pill',
      'elevated': 'expand_capsule',
      'full_width': 'edge_to_edge',
      'glow': 'soft_glow_glass',
    };
    final savedDockStyle = _prefs.getString(_kDockStyle) ?? 'slide_pill';
    if (dockStyles.contains(savedDockStyle)) {
      _dockStyle = savedDockStyle;
    } else {
      _dockStyle = legacyDockStyles[savedDockStyle] ?? 'slide_pill';
      await _prefs.setString(_kDockStyle, _dockStyle);
    }
    _twoFactorAuth = _prefs.getBool(_kTwoFactorAuth) ?? false;
    _lastSeenVisibility = _prefs.getString(_kLastSeen) ?? 'everyone';
    _profilePhotoVisibility = _prefs.getString(_kProfilePhoto) ?? 'everyone';
    _blockedUids = _prefs.getStringList(_kBlockedUids) ?? [];
    _favoriteChatIds = _prefs.getStringList(_kFavoriteChatIds) ?? [];
    _notificationTone = _prefs.getString(_kNotificationTone) ?? 'Aurora';
    _callRingtone = _prefs.getString(_kCallRingtone) ?? 'Binary';
    _customNotificationPath = _prefs.getString(_kCustomNotificationPath);
    _customRingtonePath = _prefs.getString(_kCustomRingtonePath);
    _region = _prefs.getString(_kRegion) ?? _detectDeviceRegion();
    
    // Recovery: If region is "Germany" (previous bug) or "United States" (old default),
    // and we are actually in India (via offset), force reset to India.
    if ((_region == 'Germany' || _region == 'United States') && _detectDeviceRegion() == 'India') {
      _region = 'India';
    }
    _language = _prefs.getString(_kLanguage) ?? _detectDeviceLanguage();
    _vibrationPattern = _prefs.getString(_kVibrationPattern) ?? 'standard';
    _hapticIntensity = (_prefs.getDouble(_kHapticIntensity) ?? 0.8).clamp(0.0, 1.0).toDouble();
    _hapticNavigation = _prefs.getBool(_kHapticNavigation) ?? true;
    _hapticTyping = _prefs.getBool(_kHapticTyping) ?? true;
    _hapticChat = _prefs.getBool(_kHapticChat) ?? true;
    _hapticButtons = _prefs.getBool(_kHapticButtons) ?? true;
    _hapticNotifications = _prefs.getBool(_kHapticNotifications) ?? true;
    _hapticCalls = _prefs.getBool(_kHapticCalls) ?? true;
    _messageVolume = (_prefs.getDouble('novyn_message_volume') ?? 0.8).clamp(0.0, 1.0).toDouble();
    _callVolume = (_prefs.getDouble('novyn_call_volume') ?? 0.85).clamp(0.0, 1.0).toDouble();
    _appLockEnabled = _prefs.getBool(_kAppLockEnabled) ?? false;
    _appLockTimeout = _prefs.getInt(_kAppLockTimeout) ?? 0;
    // Migrate legacy PINs from plain preferences into encrypted storage.
    // Keystore errors are recoverable startup conditions, not a reason to
    // abort runApp or silently disable an enabled App Lock.
    _secureStorageReadFailed = false;
    _appLockPin = await _readSecureValue(_secureAppLockPin);
    final legacyAppPin = _prefs.getString(_kAppLockPin);
    if (_appLockPin == null && legacyAppPin != null) {
      _appLockPin = legacyAppPin;
      final migrated = await _writeSecureValue(_secureAppLockPin, legacyAppPin);
      if (migrated) await _prefs.remove(_kAppLockPin);
    }
    _isLocked = _appLockEnabled &&
        (_appLockPin != null || _secureStorageReadFailed);
    _appLockFailedAttempts = int.tryParse(
          await _readSecureValue(_secureAppLockFailures) ?? '0',
        ) ?? 0;
    final lockUntilRaw = await _readSecureValue(_secureAppLockUntil);
    final lockUntilMillis = int.tryParse(lockUntilRaw ?? '');
    _appLockLockedUntil = lockUntilMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lockUntilMillis);
    if (_appLockLockedUntil != null && !_appLockLockedUntil!.isAfter(DateTime.now())) {
      _appLockLockedUntil = null;
      await _deleteSecureValue(_secureAppLockUntil);
    }
    if (_appLockEnabled && _appLockPin == null && !_secureStorageReadFailed) {
      // Only disable App Lock when secure storage responded successfully and
      // confirmed the PIN is genuinely absent.
      _appLockEnabled = false;
      await _prefs.setBool(_kAppLockEnabled, false);
    }
    _stealthModeEnabled = _prefs.getBool(_kStealthMode) ?? false;
    _panicPin = await _readSecureValue(_securePanicPin);
    final legacyPanicPin = _prefs.getString(_kPanicPin);
    if (_panicPin == null && legacyPanicPin != null) {
      _panicPin = legacyPanicPin;
      final migrated = await _writeSecureValue(_securePanicPin, legacyPanicPin);
      if (migrated) await _prefs.remove(_kPanicPin);
    }
    _hideNotificationContent = _prefs.getBool(_kHideNotificationContent) ?? false;
    // Keep older installations safe when Stealth Mode was already enabled.
    if (_stealthModeEnabled && !_hideNotificationContent) {
      await _prefs.setBool(_kStealthPreviousNotificationPrivacy, false);
      _hideNotificationContent = true;
      await _prefs.setBool(_kHideNotificationContent, true);
    }
    _stealthIconEnabled = _prefs.getBool(_kStealthIcon) ?? false;
    _highContrast = _prefs.getBool(_kHighContrast) ?? false;
    _reduceMotion = _prefs.getBool(_kReduceMotion) ?? false;
    _busyPreviousPresenceMode = _prefs.getString(_kBusyPreviousPresence);
    _doNotDisturbEnabled = _prefs.getBool(_kDoNotDisturb) ?? false;
    _activeSmartPresenceMode = normalizeSmartPresenceMode(_prefs.getString(_kActiveSmartPresenceMode) ?? 'online');
    _smartPresenceOverrides = {};
    final rawPresenceOverrides = _prefs.getString(_kSmartPresenceOverrides);
    if (rawPresenceOverrides != null) {
      try {
        final decoded = jsonDecode(rawPresenceOverrides);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final mode = normalizeSmartPresenceMode(entry.key.toString());
            if (entry.value is! Map) continue;
            final values = Map<String, dynamic>.from(entry.value as Map)
              ..removeWhere((key, _) => !_smartPresenceAllowedKeys.contains(key));
            if (values.isNotEmpty) _smartPresenceOverrides[mode] = values;
          }
        }
      } catch (_) { _smartPresenceOverrides = {}; }
    }
    
    // Load saved sessions
    final raw = _prefs.getString(_kSavedSessions);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _savedSessions = list
            .map((e) => SavedSession.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _savedSessions = [];
      }
    }
    _loaded = true;
    notifyListeners();
  }

  // ── Setters (persist immediately) ───────────────────────────────────────
  Future<void> setNotifications(bool v, {bool recordPresenceOverride = true}) async {
    _notificationsOn = v;
    await _prefs.setBool(_kNotifications, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('notificationsEnabled', v);
    notifyListeners();
  }

  Future<void> setChatLinkPreviews(bool v) async {
    _chatLinkPreviews = v;
    await _prefs.setBool(_kChatLinkPreviews, v);
    notifyListeners();
  }

  Future<void> setMessagePreview(bool v, {bool recordPresenceOverride = true}) async {
    _messagePreview = v;
    await _prefs.setBool(_kMessagePreview, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('messagePreviewEnabled', v);
    notifyListeners();
  }

  Future<void> setReadReceipts(bool v, {bool recordPresenceOverride = true}) async {
    _readReceipts = v;
    await _prefs.setBool(_kReadReceipts, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('readReceiptsEnabled', v);
    notifyListeners();
  }

  Future<void> setOnlineStatus(bool v) async {
    _onlineStatus = v;
    await _prefs.setBool(_kOnlineStatus, v);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setInt(_kThemeMode, mode.index);
    notifyListeners();
  }

  Future<void> setProfile({required String name, required String bio}) async {
    _displayName = name;
    _bio = bio;
    await _prefs.setString(_kDisplayName, name);
    await _prefs.setString(_kBio, bio);
    notifyListeners();
  }

  // ── New setters ──────────────────────────────────────────────────────────
  Future<void> setChatEnterToSend(bool v) async {
    _chatEnterToSend = v;
    await _prefs.setBool('chat_enter_to_send', v);
    notifyListeners();
  }

  Future<void> setInAppSounds(bool v, {bool recordPresenceOverride = true}) async {
    _inAppSounds = v;
    await _prefs.setBool(_kInAppSounds, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('inAppSoundsEnabled', v);
    notifyListeners();
  }

  Future<void> setInAppVibration(bool v, {bool recordPresenceOverride = true}) async {
    _inAppVibration = v;
    await _prefs.setBool(_kInAppVibration, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('inAppVibrationEnabled', v);
    notifyListeners();
  }

  Future<void> setHapticCategory(String category, bool enabled) async {
    final key = switch (category) {
      'navigation' => _kHapticNavigation,
      'typing' => _kHapticTyping,
      'chat' => _kHapticChat,
      'notifications' => _kHapticNotifications,
      'calls' => _kHapticCalls,
      'buttons' => _kHapticButtons,
      _ => null,
    };
    if (key == null) return;
    switch (category) {
      case 'navigation': _hapticNavigation = enabled; break;
      case 'typing': _hapticTyping = enabled; break;
      case 'chat': _hapticChat = enabled; break;
      case 'notifications': _hapticNotifications = enabled; break;
      case 'calls': _hapticCalls = enabled; break;
      case 'buttons': _hapticButtons = enabled; break;
    }
    await _prefs.setBool(key, enabled);
    notifyListeners();
  }

  Future<void> setGroupNotifications(bool v, {bool recordPresenceOverride = true}) async {
    _groupNotifications = v;
    await _prefs.setBool(_kGroupNotifications, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('groupNotificationsEnabled', v);
    notifyListeners();
  }

  Future<void> setAutoDownloadWifi(String v) async {
    _autoDownloadWifi = v;
    await _prefs.setString(_kAutoDownloadWifi, v);
    notifyListeners();
  }

  Future<void> setAutoDownloadMobile(String v) async {
    _autoDownloadMobile = v;
    await _prefs.setString(_kAutoDownloadMobile, v);
    notifyListeners();
  }

  Future<void> setPhotoQuality(String v) async {
    _photoQuality = v;
    await _prefs.setString(_kPhotoQuality, v);
    notifyListeners();
  }

  Future<void> setLanguage(String v) async {
    _language = v;
    await _prefs.setString(_kLanguage, v);
    notifyListeners();
  }

  Future<void> setAccentColor(int value) async {
    _accentColorValue = value;
    await _prefs.setInt(_kAccentColor, value);
    notifyListeners();
  }

  Future<void> setAccentColorEnabled(bool enabled) async {
    _accentColorEnabled = enabled;
    await _prefs.setBool(_kAccentColorEnabled, enabled);
    notifyListeners();
  }

  Future<void> setAlertStyle(String style) async {
    const allowed = {'snackbar', 'top_banner', 'capsule', 'switch_card', 'centre_hud', 'countdown_card'};
    if (!allowed.contains(style) || _alertStyle == style) return;
    _alertStyle = style;
    await _prefs.setString(_kAlertStyle, style);
    notifyListeners();
  }

  Future<void> setCallMiniStyle(String style) async {
    const allowed = {
      'top_banner', 'floating_avatar', 'compact_pill',
      'bottom_bar', 'video_card', 'edge_chip',
    };
    if (!allowed.contains(style) || _callMiniStyle == style) return;
    _callMiniStyle = style;
    await _prefs.setString(_kCallMiniStyle, style);
    notifyListeners();
  }

  Future<void> setDockStyle(String style) async {
    const allowed = {
      'slide_pill',
      'expand_capsule',
      'edge_to_edge',
      'dot_minimal',
      'soft_glow_glass',
      'liquid_stretch',
      'flip_tiles',
      'draw_ring',
    };
    if (!allowed.contains(style)) return;
    if (_dockStyle == style) return;
    _dockStyle = style;
    await _prefs.setString(_kDockStyle, style);
    notifyListeners();
  }

  Future<void> setChatLabelSize(double v) async {
    _chatLabelSize = v.clamp(0.8, 1.4).toDouble();
    await _prefs.setDouble(_kChatLabelSize, _chatLabelSize);
    notifyListeners();
  }

  Future<void> setFontSize(double v) async {
    v = v.clamp(0.75, 1.25).toDouble();
    _fontSize = v;
    await _prefs.setDouble(_kFontSize, v);
    notifyListeners();
  }

  Future<void> setHighContrast(bool v) async {
    _highContrast = v;
    await _prefs.setBool(_kHighContrast, v);
    notifyListeners();
  }

  Future<void> setDoNotDisturbEnabled(bool enabled) async {
    if (_doNotDisturbEnabled == enabled) return;

    // Persist first so a failed device-storage write never leaves the UI
    // showing a value that was not actually saved.
    final saved = await _prefs.setBool(_kDoNotDisturb, enabled);
    if (!saved) {
      throw StateError('Your device could not save the Do Not Disturb setting.');
    }

    _doNotDisturbEnabled = enabled;
    notifyListeners();
  }

  Future<void> setBusyPreviousPresenceMode(String? mode) async {
    const allowed = {'online', 'away', 'invisible'};
    _busyPreviousPresenceMode = mode != null && allowed.contains(mode) ? mode : null;
    if (_busyPreviousPresenceMode == null) {
      await _prefs.remove(_kBusyPreviousPresence);
    } else {
      await _prefs.setString(_kBusyPreviousPresence, _busyPreviousPresenceMode!);
    }
    notifyListeners();
  }

  Future<void> setReduceMotion(bool v) async {
    if (_reduceMotion == v) return;
    _reduceMotion = v;
    // Update MediaQuery immediately so the accessibility control never waits
    // on a disk write before reflecting the user's choice.
    notifyListeners();
    await _prefs.setBool(_kReduceMotion, v);
  }

  Future<void> setTwoFactorAuth(bool v) async {
    _twoFactorAuth = v;
    await _prefs.setBool(_kTwoFactorAuth, v);
    notifyListeners();
  }

  Future<void> setTimeFormat(String value) async {
    _timeFormat = value == '24h' ? '24h' : '12h';
    await _prefs.setString(_kTimeFormat, _timeFormat);
    notifyListeners();
  }

  Future<void> setLastSeenVisibility(String v, {bool recordPresenceOverride = true}) async {
    _lastSeenVisibility = v;
    await _prefs.setString(_kLastSeen, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('presencePrivacy', v == 'contacts' ? 'friends' : v);
    notifyListeners();
  }

  Future<void> setProfilePhotoVisibility(String v, {bool recordPresenceOverride = true}) async {
    _profilePhotoVisibility = v;
    await _prefs.setString(_kProfilePhoto, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('profilePhotoPrivacy', v == 'contacts' ? 'friends' : v);
    notifyListeners();
  }

  Future<void> toggleFavoriteChat(String chatId) async {
    if (_favoriteChatIds.contains(chatId)) {
      _favoriteChatIds.remove(chatId);
    } else {
      _favoriteChatIds.add(chatId);
    }
    await _prefs.setStringList(_kFavoriteChatIds, _favoriteChatIds);
    notifyListeners();
  }

  Future<void> blockUser(String uid) async {
    if (!_blockedUids.contains(uid)) {
      _blockedUids.add(uid);
      await _prefs.setStringList(_kBlockedUids, _blockedUids);
      notifyListeners();
    }
  }

  Future<void> unblockUser(String uid) async {
    if (_blockedUids.contains(uid)) {
      _blockedUids.remove(uid);
      await _prefs.setStringList(_kBlockedUids, _blockedUids);
      notifyListeners();
    }
  }

  Future<void> setNotificationTone(String v) async {
    _notificationTone = v;
    await _prefs.setString(_kNotificationTone, v);
    notifyListeners();
  }

  Future<void> setCallRingtone(String v) async {
    _callRingtone = v;
    await _prefs.setString(_kCallRingtone, v);
    notifyListeners();
  }

  Future<void> setCustomNotificationPath(String? path) async {
    _customNotificationPath = path;
    if (path == null) {
      await _prefs.remove(_kCustomNotificationPath);
    } else {
      await _prefs.setString(_kCustomNotificationPath, path);
    }
    notifyListeners();
  }

  Future<void> setCustomRingtonePath(String? path) async {
    _customRingtonePath = path;
    if (path == null) {
      await _prefs.remove(_kCustomRingtonePath);
    } else {
      await _prefs.setString(_kCustomRingtonePath, path);
    }
    notifyListeners();
  }

  Future<void> setRegion(String v) async {
    _region = v;
    await _prefs.setString(_kRegion, v);
    
    // Auto-update language if current language is not in the new region's list
    final allowed = getLanguagesForRegion(v).keys.toList();
    if (!allowed.contains(_language)) {
      await setLanguage(allowed.first);
    }
    
    notifyListeners();
  }

  Map<String, String> getLanguagesForRegion(String regionName) {
    switch (regionName) {
      case 'India':
        return {
          'hi': 'हिन्दी (Hindi)',
          'en': 'English',
          'mr': 'मराठी (Marathi)',
          'bn': 'বাংলা (Bengali)',
          'ta': 'தமிழ் (Tamil)',
          'te': 'తెలుగు (Telugu)',
        };
      case 'United States':
        return {'en': 'English', 'es': 'Español'};
      case 'United Kingdom':
        return {'en': 'English'};
      case 'Germany':
        return {'de': 'Deutsch', 'en': 'English'};
      case 'France':
        return {'fr': 'Français', 'en': 'English'};
      case 'Spain':
        return {'es': 'Español', 'en': 'English'};
      case 'Italy':
        return {'it': 'Italiano', 'en': 'English'};
      case 'Japan':
        return {'ja': '日本語 (Japanese)', 'en': 'English'};
      case 'South Korea':
        return {'ko': '한국어 (Korean)', 'en': 'English'};
      case 'Russia':
        return {'ru': 'Русский (Russian)', 'en': 'English'};
      case 'Canada':
        return {'en': 'English', 'fr': 'Français'};
      default:
        return {'en': 'English'};
    }
  }

  Future<void> setVibrationPattern(String v) async {
    _vibrationPattern = v;
    await _prefs.setString(_kVibrationPattern, v);
    notifyListeners();
  }

  String _detectDeviceRegion() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final countryCode = locale.countryCode?.toUpperCase();
    
    // Fallback: Detection via Timezone Offset (India is UTC+5.5)
    final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    if (offsetMinutes == 330) return 'India';
    
    switch (countryCode) {
      case 'IN': return 'India';
      case 'GB': return 'United Kingdom';
      case 'CA': return 'Canada';
      case 'AU': return 'Australia';
      case 'DE': return 'Germany';
      case 'FR': return 'France';
      case 'ES': return 'Spain';
      case 'IT': return 'Italy';
      case 'JP': return 'Japan';
      case 'KR': return 'South Korea';
      case 'RU': return 'Russia';
      default: return 'United States';
    }
  }

  String _detectDeviceLanguage() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    return locale.languageCode.toLowerCase();
  }

  Future<void> setMessageVolume(double v) async {
    _messageVolume = v.clamp(0.0, 1.0).toDouble();
    await _prefs.setDouble('novyn_message_volume', _messageVolume);
    notifyListeners();
  }

  Future<void> setCallVolume(double v) async {
    _callVolume = v.clamp(0.0, 1.0).toDouble();
    await _prefs.setDouble('novyn_call_volume', _callVolume);
    notifyListeners();
  }

  Future<void> setHapticIntensity(double v) async {
    v = v.clamp(0.0, 1.0).toDouble();
    _hapticIntensity = v;
    await _prefs.setDouble(_kHapticIntensity, v);
    notifyListeners();
  }

  Future<void> setAppLockEnabled(bool v) async {
    if (v && _appLockPin == null) {
      throw StateError('Set an app lock PIN before enabling App Lock.');
    }
    _appLockEnabled = v;
    await _prefs.setBool(_kAppLockEnabled, v);
    notifyListeners();
  }

  Future<void> setAppLockTimeout(int v) async {
    _appLockTimeout = v;
    await _prefs.setInt(_kAppLockTimeout, v);
    notifyListeners();
  }

  Future<void> setAppLockPin(String? pin) async {
    if (pin != null && (pin.length != 4 || int.tryParse(pin) == null)) {
      throw ArgumentError('App lock PIN must contain exactly 4 digits.');
    }
    _appLockPin = pin;
    if (pin == null) {
      await _deleteSecureValue(_secureAppLockPin);
    } else if (!await _writeSecureValue(_secureAppLockPin, pin)) {
      throw StateError('Secure storage is temporarily unavailable. Try again.');
    }
    notifyListeners();
  }

  Future<void> recordFailedAppLockAttempt() async {
    _appLockFailedAttempts += 1;
    await _writeSecureValue(
      _secureAppLockFailures,
      _appLockFailedAttempts.toString(),
    );
    Duration? cooldown;
    if (_appLockFailedAttempts == 15) {
      cooldown = const Duration(minutes: 10);
    } else if (_appLockFailedAttempts == 10) {
      cooldown = const Duration(minutes: 2);
    } else if (_appLockFailedAttempts == 5) {
      cooldown = const Duration(seconds: 30);
    }
    if (cooldown != null) {
      _appLockLockedUntil = DateTime.now().add(cooldown);
      await _writeSecureValue(
        _secureAppLockUntil,
        _appLockLockedUntil!.millisecondsSinceEpoch.toString(),
      );
    }
    notifyListeners();
  }

  Future<void> resetAppLockFailures() async {
    _appLockFailedAttempts = 0;
    _appLockLockedUntil = null;
    await _deleteSecureValue(_secureAppLockFailures);
    await _deleteSecureValue(_secureAppLockUntil);
    notifyListeners();
  }

  // Recovery deliberately requires a fresh account sign-in. The PIN is
  // removed only after the user confirms they want to sign out.
  Future<void> prepareAppLockAccountRecovery() async {
    _appLockEnabled = false;
    _isLocked = false;
    await _prefs.setBool(_kAppLockEnabled, false);
    await setAppLockPin(null);
    await resetAppLockFailures();
    notifyListeners();
  }

  void setLocked(bool v) {
    _isLocked = v;
    notifyListeners();
  }

  Future<void> setStealthMode(bool v) async {
    if (v == _stealthModeEnabled) return;

    // Commit the in-memory value only after the device confirms persistence.
    final saved = await _prefs.setBool(_kStealthMode, v);
    if (!saved) {
      throw StateError('Your device could not save the Stealth Mode setting.');
    }

    _stealthModeEnabled = v;
    notifyListeners();
  }

  Future<void> setPanicPin(String? pin) async {
    if (pin != null && (pin.length != 4 || int.tryParse(pin) == null)) {
      throw ArgumentError('Panic PIN must contain exactly 4 digits.');
    }
    _panicPin = pin;
    if (pin == null) {
      await _deleteSecureValue(_securePanicPin);
    } else if (!await _writeSecureValue(_securePanicPin, pin)) {
      throw StateError('Secure storage is temporarily unavailable. Try again.');
    }
    notifyListeners();
  }

  Future<void> setHideNotificationContent(bool v) async {
    _hideNotificationContent = v;
    await _prefs.setBool(_kHideNotificationContent, v);
    notifyListeners();
  }

  void setDecoyMode(bool v) {
    _decoyMode = v;
    notifyListeners();
  }

  Future<void> setStealthIconEnabled(bool v) async {
    _stealthIconEnabled = v;
    await _prefs.setBool(_kStealthIcon, v);
    notifyListeners();
  }

  void unlockWithDecoy(bool isDecoy) {
    _decoyMode = isDecoy;
    _isLocked = false;
    resetAppLockFailures();
    notifyListeners();
  }

  bool isBlocked(String uid) => _blockedUids.contains(uid);

  // ── Saved sessions ───────────────────────────────────────────────────────
  Future<void> saveSession(SavedSession session) async {
    // Remove existing entry for same uid/email, then add fresh
    _savedSessions.removeWhere(
        (s) => s.uid == session.uid || s.email == session.email);
    _savedSessions.insert(0, session); // most recent first
    // Keep max 5 saved accounts
    if (_savedSessions.length > 5) _savedSessions = _savedSessions.sublist(0, 5);
    await _persistSessions();
    notifyListeners();
  }

  Future<void> removeSession(String uid) async {
    _savedSessions.removeWhere((s) => s.uid == uid);
    await _persistSessions();
    notifyListeners();
  }

  Future<void> _persistSessions() async {
    final encoded = jsonEncode(_savedSessions.map((s) => s.toJson()).toList());
    await _prefs.setString(_kSavedSessions, encoded);
  }

  /// Export only account-level preferences. Device secrets, local file paths,
  /// biometric/app-lock state and transient runtime flags are intentionally
  /// excluded from cloud sync.
  Map<String, dynamic> cloudSyncSnapshot({String? accountKey}) => {
        'chatLinkPreviews': _chatLinkPreviews,
        'onlineStatus': _onlineStatus,
        'themeMode': _themeMode.name,
        'chatEnterToSend': _chatEnterToSend,
        'autoDownloadWifi': _autoDownloadWifi,
        'autoDownloadMobile': _autoDownloadMobile,
        'photoQuality': _photoQuality,
        'language': _language,
        'timeFormat': _timeFormat,
        'fontSize': _fontSize,
        'chatLabelSize': _chatLabelSize,
        'accentColorValue': _accentColorValue,
        'accentColorEnabled': _accentColorEnabled,
        'dockStyle': _dockStyle,
        'alertStyle': _alertStyle,
        'notificationTone': _notificationTone,
        'callRingtone': _callRingtone,
        'vibrationPattern': _vibrationPattern,
        'hapticIntensity': _hapticIntensity,
        'hapticNavigation': _hapticNavigation,
        'hapticTyping': _hapticTyping,
        'hapticChat': _hapticChat,
        'hapticButtons': _hapticButtons,
        'hapticNotifications': _hapticNotifications,
        'hapticCalls': _hapticCalls,
        'messageVolume': _messageVolume,
        'callVolume': _callVolume,
        'region': _region,
        'highContrast': _highContrast,
        'reduceMotion': _reduceMotion,
        'doNotDisturbEnabled': _doNotDisturbEnabled,
        if (accountKey != null && accountKey.trim().isNotEmpty)
          'quickToggleIds': quickToggleIdsFor(accountKey),
      };

  /// Apply an account snapshot without invoking each public setter (and
  /// therefore without causing a burst of listener notifications/network work).
  /// The UI receives one notification after the local cache has been updated.
  Future<void> applyCloudSyncSnapshot(
    Map<String, dynamic> values, {
    String? accountKey,
  }) async {
    if (!_loaded) {
      throw StateError('Settings must be loaded before applying cloud settings.');
    }

    bool boolValue(String key, bool fallback) =>
        values[key] is bool ? values[key] as bool : fallback;
    String stringValue(String key, String fallback) =>
        values[key] is String ? (values[key] as String) : fallback;
    double doubleValue(String key, double fallback, double min, double max) {
      final raw = values[key];
      final value = raw is num ? raw.toDouble() : fallback;
      return value.clamp(min, max).toDouble();
    }

    _notificationsOn = boolValue('notificationsOn', _notificationsOn);
    _messagePreview = boolValue('messagePreview', _messagePreview);
    _chatLinkPreviews = boolValue('chatLinkPreviews', _chatLinkPreviews);
    _readReceipts = boolValue('readReceipts', _readReceipts);
    _onlineStatus = boolValue('onlineStatus', _onlineStatus);
    final themeName = stringValue('themeMode', _themeMode.name);
    _themeMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == themeName,
      orElse: () => _themeMode,
    );
    _inAppSounds = boolValue('inAppSounds', _inAppSounds);
    _chatEnterToSend = boolValue('chatEnterToSend', _chatEnterToSend);
    _inAppVibration = boolValue('inAppVibration', _inAppVibration);
    _groupNotifications = boolValue('groupNotifications', _groupNotifications);
    _autoDownloadWifi = stringValue('autoDownloadWifi', _autoDownloadWifi);
    _autoDownloadMobile = stringValue('autoDownloadMobile', _autoDownloadMobile);
    _photoQuality = stringValue('photoQuality', _photoQuality);
    _language = stringValue('language', _language);
    _timeFormat = stringValue('timeFormat', _timeFormat) == '24h' ? '24h' : '12h';
    _fontSize = doubleValue('fontSize', _fontSize, 0.75, 1.25);
    _chatLabelSize = doubleValue('chatLabelSize', _chatLabelSize, 0.8, 1.4);
    final accent = values['accentColorValue'];
    if (accent is num && accent.toInt() >= 0 && accent.toInt() <= 0xFFFFFFFF) {
      _accentColorValue = accent.toInt();
    }
    _accentColorEnabled = boolValue('accentColorEnabled', _accentColorEnabled);

    const dockStyles = {
      'slide_pill', 'expand_capsule', 'edge_to_edge', 'dot_minimal',
      'soft_glow_glass', 'liquid_stretch', 'flip_tiles', 'draw_ring',
    };
    final dockStyle = stringValue('dockStyle', _dockStyle);
    if (dockStyles.contains(dockStyle)) _dockStyle = dockStyle;
    const alertStyles = {
      'snackbar', 'top_banner', 'capsule', 'switch_card',
      'centre_hud', 'countdown_card',
    };
    final alertStyle = stringValue('alertStyle', _alertStyle);
    if (alertStyles.contains(alertStyle)) _alertStyle = alertStyle;

    _notificationTone = stringValue('notificationTone', _notificationTone);
    _callRingtone = stringValue('callRingtone', _callRingtone);
    _vibrationPattern = stringValue('vibrationPattern', _vibrationPattern);
    _hapticIntensity = doubleValue('hapticIntensity', _hapticIntensity, 0, 1);
    _hapticNavigation = boolValue('hapticNavigation', _hapticNavigation);
    _hapticTyping = boolValue('hapticTyping', _hapticTyping);
    _hapticChat = boolValue('hapticChat', _hapticChat);
    _hapticButtons = boolValue('hapticButtons', _hapticButtons);
    _hapticNotifications = boolValue('hapticNotifications', _hapticNotifications);
    _hapticCalls = boolValue('hapticCalls', _hapticCalls);
    _messageVolume = doubleValue('messageVolume', _messageVolume, 0, 1);
    _callVolume = doubleValue('callVolume', _callVolume, 0, 1);
    _region = stringValue('region', _region);
    _highContrast = boolValue('highContrast', _highContrast);
    _reduceMotion = boolValue('reduceMotion', _reduceMotion);
    _doNotDisturbEnabled = boolValue('doNotDisturbEnabled', _doNotDisturbEnabled);

    final writes = <Future<bool>>[
      _prefs.setBool(_kNotifications, _notificationsOn),
      _prefs.setBool(_kMessagePreview, _messagePreview),
      _prefs.setBool(_kChatLinkPreviews, _chatLinkPreviews),
      _prefs.setBool(_kReadReceipts, _readReceipts),
      _prefs.setBool(_kOnlineStatus, _onlineStatus),
      _prefs.setInt(_kThemeMode, _themeMode.index),
      _prefs.setBool(_kInAppSounds, _inAppSounds),
      _prefs.setBool('chat_enter_to_send', _chatEnterToSend),
      _prefs.setBool(_kInAppVibration, _inAppVibration),
      _prefs.setBool(_kGroupNotifications, _groupNotifications),
      _prefs.setString(_kAutoDownloadWifi, _autoDownloadWifi),
      _prefs.setString(_kAutoDownloadMobile, _autoDownloadMobile),
      _prefs.setString(_kPhotoQuality, _photoQuality),
      _prefs.setString(_kLanguage, _language),
      _prefs.setString(_kTimeFormat, _timeFormat),
      _prefs.setDouble(_kFontSize, _fontSize),
      _prefs.setDouble(_kChatLabelSize, _chatLabelSize),
      _prefs.setInt(_kAccentColor, _accentColorValue),
      _prefs.setBool(_kAccentColorEnabled, _accentColorEnabled),
      _prefs.setString(_kDockStyle, _dockStyle),
      _prefs.setString(_kAlertStyle, _alertStyle),
      _prefs.setString(_kNotificationTone, _notificationTone),
      _prefs.setString(_kCallRingtone, _callRingtone),
      _prefs.setString(_kVibrationPattern, _vibrationPattern),
      _prefs.setDouble(_kHapticIntensity, _hapticIntensity),
      _prefs.setBool(_kHapticNavigation, _hapticNavigation),
      _prefs.setBool(_kHapticTyping, _hapticTyping),
      _prefs.setBool(_kHapticChat, _hapticChat),
      _prefs.setBool(_kHapticButtons, _hapticButtons),
      _prefs.setBool(_kHapticNotifications, _hapticNotifications),
      _prefs.setBool(_kHapticCalls, _hapticCalls),
      _prefs.setDouble('novyn_message_volume', _messageVolume),
      _prefs.setDouble('novyn_call_volume', _callVolume),
      _prefs.setString(_kRegion, _region),
      _prefs.setBool(_kHighContrast, _highContrast),
      _prefs.setBool(_kReduceMotion, _reduceMotion),
      _prefs.setBool(_kDoNotDisturb, _doNotDisturbEnabled),
    ];
    final quickIds = values['quickToggleIds'];
    if (accountKey != null &&
        accountKey.trim().isNotEmpty &&
        quickIds is List) {
      final cleaned = sanitizeQuickToggleIds(
        quickIds.whereType<String>(),
      );
      if (cleaned.isNotEmpty) {
        writes.add(_prefs.setStringList(
          _quickToggleStorageKey(accountKey),
          cleaned,
        ));
      }
    }
    await Future.wait(writes);
    notifyListeners();
  }

  Future<void> clearAll() async {
    await _prefs.clear();
    await _deleteSecureValue(_secureAppLockPin);
    await _deleteSecureValue(_securePanicPin);
    _notificationsOn = true;
    _messagePreview = true;
    _chatLinkPreviews = true;
    _readReceipts = true;
    _onlineStatus = true;
    _themeMode = ThemeMode.system;
    _displayName = '';
    _bio = '';
    _savedSessions = [];
    
    // Reset new settings
    _inAppSounds = true;
    _chatEnterToSend = true;
    _inAppVibration = true;
    _groupNotifications = true;
    _autoDownloadWifi = 'all';
    _autoDownloadMobile = 'photos';
    _photoQuality = 'high';
    _language = 'en';
    _fontSize = 0.85;
    _chatLabelSize = 1.0;
    _accentColorValue = 0xFF6D5DFC;
    _accentColorEnabled = true;
    _dockStyle = 'slide_pill';
    _alertStyle = 'snackbar';
    _callMiniStyle = 'top_banner';
    _twoFactorAuth = false;
    _lastSeenVisibility = 'everyone';
    _profilePhotoVisibility = 'everyone';
    _blockedUids = [];
    _notificationTone = 'Aurora';
    _vibrationPattern = 'standard';
    _hapticIntensity = 0.8;
    _appLockEnabled = false;
    _appLockTimeout = 0;
    
    notifyListeners();
  }
  @override
  void dispose() {
    super.dispose();
  }

}
);
    if (start != null && !timePattern.hasMatch(start)) {
      throw ArgumentError.value(start, 'start', 'Use 24-hour HH:mm time');
    }
    if (end != null && !timePattern.hasMatch(end)) {
      throw ArgumentError.value(end, 'end', 'Use 24-hour HH:mm time');
    }
    if (start != null) {
      _quietHoursStart = start;
      await _prefs.setString(_kQuietHoursStart, start);
    }
    if (end != null) {
      _quietHoursEnd = end;
      await _prefs.setString(_kQuietHoursEnd, end);
    }
    if (offsetMinutes != null) {
      _quietHoursOffsetMinutes = offsetMinutes.clamp(-840, 840);
      await _prefs.setInt(_kQuietHoursOffsetMinutes, _quietHoursOffsetMinutes);
    }
    notifyListeners();
  }
  String get autoDownloadWifi => _autoDownloadWifi;
  String get autoDownloadMobile => _autoDownloadMobile;
  String get notificationTone => _notificationTone;
  String get callRingtone => _callRingtone;
  String? get customNotificationPath => _customNotificationPath;
  String? get customRingtonePath => _customRingtonePath;
  String get region => _region;
  String get language => _language;
  String get timeFormat => _timeFormat;
  String get vibrationPattern => _vibrationPattern;
  double get hapticIntensity => _hapticIntensity;
  bool get hapticNavigation => _hapticNavigation;
  bool get hapticTyping => _hapticTyping;
  bool get hapticChat => _hapticChat;
  bool get hapticButtons => _hapticButtons;
  bool get hapticNotifications => _hapticNotifications;
  bool get hapticCalls => _hapticCalls;
  bool hapticCategoryEnabled(String category) => switch (category) {
    'navigation' => _hapticNavigation,
    'typing' => _hapticTyping,
    'chat' => _hapticChat,
    'notifications' => _hapticNotifications,
    'calls' => _hapticCalls,
    _ => _hapticButtons,
  };
  double get messageVolume => _messageVolume;
  double get callVolume => _callVolume;
  String get photoQuality => _photoQuality;
  double get fontSize => _fontSize;
  double get chatLabelSize => _chatLabelSize;
  int get accentColorValue => _accentColorValue;
  bool get accentColorEnabled => _accentColorEnabled;
  String get dockStyle => _dockStyle;
  String get alertStyle => _alertStyle;
  String get callMiniStyle => _callMiniStyle;
  bool get twoFactorAuth => _twoFactorAuth;
  String get lastSeenVisibility => _stealthModeEnabled ? 'nobody' : _lastSeenVisibility;
  String get profilePhotoVisibility => _stealthModeEnabled ? 'nobody' : _profilePhotoVisibility;
  String get configuredLastSeenVisibility => _lastSeenVisibility;
  String get configuredProfilePhotoVisibility => _profilePhotoVisibility;
  List<String> get blockedUids => _blockedUids;
  List<String> get favoriteChatIds => List.unmodifiable(_favoriteChatIds);
  bool get appLockEnabled => _appLockEnabled;
  int get appLockTimeout => _appLockTimeout;
  String? get appLockPin => _appLockPin;
  bool get secureStorageAvailable => !_secureStorageReadFailed;
  bool get isLocked => _isLocked;
  int get appLockFailedAttempts => _appLockFailedAttempts;
  Duration get appLockRemaining {
    final until = _appLockLockedUntil;
    if (until == null) return Duration.zero;
    final remaining = until.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
  bool get isAppLockCoolingDown => appLockRemaining > Duration.zero;
  bool get stealthModeEnabled => _stealthModeEnabled;
  String? get panicPin => _panicPin;
  bool get hideNotificationContent => _hideNotificationContent;
  bool get decoyMode => _decoyMode;
  bool get stealthIconEnabled => _stealthIconEnabled;
  bool get highContrast => _highContrast;
  bool get reduceMotion => _reduceMotion;
  String? get busyPreviousPresenceMode => _busyPreviousPresenceMode;
  bool get doNotDisturbEnabled => _doNotDisturbEnabled;
  String get activeSmartPresenceMode => _activeSmartPresenceMode;
  static const Set<String> _smartPresenceServerKeys = {
    'callsEnabled', 'callPrivacy', 'messagePrivacy', 'profilePhotoPrivacy', 'presencePrivacy',
    'discoverPrivacy', 'groupInvitePrivacy', 'friendRequestPrivacy',
    'readReceiptsEnabled', 'typingIndicatorsEnabled', 'notificationsEnabled',
    'messagePreviewEnabled', 'groupNotificationsEnabled',
  };
  static const Set<String> _smartPresenceLocalKeys = {'inAppSoundsEnabled', 'inAppVibrationEnabled'};
  static const Set<String> _smartPresenceAllowedKeys = {
    ..._smartPresenceServerKeys, ..._smartPresenceLocalKeys,
  };
  static String normalizeSmartPresenceMode(String mode) {
    final value = mode.trim().toLowerCase();
    if (value == 'away' || value == 'idle') return 'idle';
    if (value == 'dnd') return 'busy';
    if (value == 'offline') return 'invisible';
    return const {'online', 'busy', 'invisible'}.contains(value) ? value : 'online';
  }
  static String presenceStatusForSmartMode(String mode) =>
      normalizeSmartPresenceMode(mode) == 'idle' ? 'away' : normalizeSmartPresenceMode(mode);
  static Map<String, dynamic> smartPresenceDefaults(String mode) {
    switch (normalizeSmartPresenceMode(mode)) {
      case 'idle':
        return {
          'callsEnabled': true, 'callPrivacy': 'friends', 'messagePrivacy': 'friends',
          'profilePhotoPrivacy': 'friends', 'presencePrivacy': 'friends',
          'discoverPrivacy': 'friends', 'groupInvitePrivacy': 'friends',
          'friendRequestPrivacy': 'mutuals',
          'readReceiptsEnabled': true, 'typingIndicatorsEnabled': true,
          'notificationsEnabled': true, 'messagePreviewEnabled': true,
          'groupNotificationsEnabled': true, 'inAppSoundsEnabled': true,
          'inAppVibrationEnabled': true,
        };
      case 'busy':
        return {
          'callsEnabled': true, 'callPrivacy': 'nobody', 'messagePrivacy': 'friends',
          'profilePhotoPrivacy': 'friends', 'presencePrivacy': 'friends',
          'discoverPrivacy': 'friends', 'groupInvitePrivacy': 'friends',
          'friendRequestPrivacy': 'mutuals',
          'readReceiptsEnabled': false, 'typingIndicatorsEnabled': false,
          'notificationsEnabled': false, 'messagePreviewEnabled': false,
          'groupNotificationsEnabled': false, 'inAppSoundsEnabled': false,
          'inAppVibrationEnabled': false,
        };
      case 'invisible':
        return {
          'callsEnabled': false, 'callPrivacy': 'nobody', 'messagePrivacy': 'friends',
          'profilePhotoPrivacy': 'nobody', 'presencePrivacy': 'nobody',
          'discoverPrivacy': 'nobody', 'groupInvitePrivacy': 'nobody',
          'friendRequestPrivacy': 'nobody',
          'readReceiptsEnabled': false, 'typingIndicatorsEnabled': false,
          'notificationsEnabled': false, 'messagePreviewEnabled': false,
          'groupNotificationsEnabled': false, 'inAppSoundsEnabled': false,
          'inAppVibrationEnabled': false,
        };
      case 'online':
      default:
        return {
          'callsEnabled': true, 'callPrivacy': 'everyone', 'messagePrivacy': 'everyone',
          'profilePhotoPrivacy': 'everyone', 'presencePrivacy': 'everyone',
          'discoverPrivacy': 'everyone', 'groupInvitePrivacy': 'everyone',
          'friendRequestPrivacy': 'everyone',
          'readReceiptsEnabled': true, 'typingIndicatorsEnabled': true,
          'notificationsEnabled': true, 'messagePreviewEnabled': true,
          'groupNotificationsEnabled': true, 'inAppSoundsEnabled': true,
          'inAppVibrationEnabled': true,
        };
    }
  }
  Map<String, dynamic> smartPresencePolicyFor(String mode) {
    final key = normalizeSmartPresenceMode(mode);
    return {...smartPresenceDefaults(key), ...?_smartPresenceOverrides[key]};
  }
  bool hasSmartPresenceCustomizations(String mode) =>
      _smartPresenceOverrides[normalizeSmartPresenceMode(mode)]?.isNotEmpty ?? false;
  static Map<String, dynamic> smartPresenceServerFields(Map<String, dynamic> policy) => {
    for (final entry in policy.entries)
      if (_smartPresenceServerKeys.contains(entry.key)) entry.key: entry.value,
  };
  Future<void> saveSmartPresenceOverride(String mode, String key, dynamic value) async {
    if (!_smartPresenceAllowedKeys.contains(key)) {
      throw ArgumentError.value(key, 'key', 'Unsupported Smart Presence setting');
    }
    final normalized = normalizeSmartPresenceMode(mode);
    final overrides = _smartPresenceOverrides.putIfAbsent(normalized, () => <String, dynamic>{});
    if (smartPresenceDefaults(normalized)[key] == value) {
      overrides.remove(key);
    } else {
      overrides[key] = value;
    }
    if (overrides.isEmpty) _smartPresenceOverrides.remove(normalized);
    await _prefs.setString(_kSmartPresenceOverrides, jsonEncode(_smartPresenceOverrides));
    notifyListeners();
  }
  Future<void> hydrateSmartPresenceModeFromServer(
    String mode,
    Map<String, dynamic> serverPolicy,
  ) async {
    final normalized = normalizeSmartPresenceMode(mode);
    final defaults = smartPresenceDefaults(normalized);
    final previous = _smartPresenceOverrides[normalized] ?? const <String, dynamic>{};
    final next = <String, dynamic>{};
    const privacyValues = {'everyone', 'friends', 'nobody', 'mutuals'};

    for (final key in _smartPresenceServerKeys) {
      if (!serverPolicy.containsKey(key)) continue;
      final value = serverPolicy[key];
      final defaultValue = defaults[key];
      if (defaultValue is bool && value is bool) {
        if (value != defaultValue) next[key] = value;
      } else if (defaultValue is String &&
          value is String &&
          privacyValues.contains(value)) {
        if (value != defaultValue) next[key] = value;
      }
    }
    for (final key in _smartPresenceLocalKeys) {
      if (previous.containsKey(key)) next[key] = previous[key];
    }

    if (next.isEmpty) {
      _smartPresenceOverrides.remove(normalized);
    } else {
      _smartPresenceOverrides[normalized] = next;
    }
    await _prefs.setString(_kSmartPresenceOverrides, jsonEncode(_smartPresenceOverrides));
    notifyListeners();
  }

  Future<void> recordActiveSmartPresenceOverride(String key, dynamic value) =>
      saveSmartPresenceOverride(_activeSmartPresenceMode, key, value);
  Future<void> resetSmartPresenceOverrides(String mode) async {
    _smartPresenceOverrides.remove(normalizeSmartPresenceMode(mode));
    await _prefs.setString(_kSmartPresenceOverrides, jsonEncode(_smartPresenceOverrides));
    notifyListeners();
  }
  Future<void> applySmartPresenceLocalPolicy(String mode, {Map<String, dynamic>? policy}) async {
    final normalized = normalizeSmartPresenceMode(mode);
    final values = policy ?? smartPresencePolicyFor(normalized);
    _activeSmartPresenceMode = normalized;
    _notificationsOn = values['notificationsEnabled'] != false;
    _messagePreview = values['messagePreviewEnabled'] != false;
    _groupNotifications = values['groupNotificationsEnabled'] != false;
    _readReceipts = values['readReceiptsEnabled'] != false;
    _inAppSounds = values['inAppSoundsEnabled'] != false;
    _inAppVibration = values['inAppVibrationEnabled'] != false;
    final presence = values['presencePrivacy']?.toString() ?? 'everyone';
    final photo = values['profilePhotoPrivacy']?.toString() ?? 'everyone';
    _lastSeenVisibility = presence == 'friends' ? 'contacts' : presence;
    _profilePhotoVisibility = photo == 'friends' ? 'contacts' : photo;
    await Future.wait([
      _prefs.setString(_kActiveSmartPresenceMode, normalized),
      _prefs.setBool(_kNotifications, _notificationsOn),
      _prefs.setBool(_kMessagePreview, _messagePreview),
      _prefs.setBool(_kGroupNotifications, _groupNotifications),
      _prefs.setBool(_kReadReceipts, _readReceipts),
      _prefs.setBool(_kInAppSounds, _inAppSounds),
      _prefs.setBool(_kInAppVibration, _inAppVibration),
      _prefs.setString(_kLastSeen, _lastSeenVisibility),
      _prefs.setString(_kProfilePhoto, _profilePhotoVisibility),
    ]);
    notifyListeners();
  }
  Future<void> setActiveSmartPresenceMode(String mode) async {
    _activeSmartPresenceMode = normalizeSmartPresenceMode(mode);
    await _prefs.setString(_kActiveSmartPresenceMode, _activeSmartPresenceMode);
    notifyListeners();
  }

  // ── Load from disk ───────────────────────────────────────────────────────
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _notificationsOn = _prefs.getBool(_kNotifications) ?? true;
    _messagePreview = _prefs.getBool(_kMessagePreview) ?? true;
    _chatLinkPreviews = _prefs.getBool(_kChatLinkPreviews) ?? true;
    _readReceipts = _prefs.getBool(_kReadReceipts) ?? true;
    _onlineStatus = _prefs.getBool(_kOnlineStatus) ?? true;
    _themeMode = ThemeMode.values[_prefs.getInt(_kThemeMode) ?? ThemeMode.light.index];
    _displayName = _prefs.getString(_kDisplayName) ?? '';
    _bio = _prefs.getString(_kBio) ?? '';
    
    // Load new settings
    _inAppSounds = _prefs.getBool(_kInAppSounds) ?? true;
    _chatEnterToSend = _prefs.getBool('chat_enter_to_send') ?? true;
    _inAppVibration = _prefs.getBool(_kInAppVibration) ?? true;
    _groupNotifications = _prefs.getBool(_kGroupNotifications) ?? true;
    _notificationPreferences = {...notificationPreferenceDefaults};
    for (final entry in notificationPreferenceStorageKeys.entries) {
      _notificationPreferences[entry.key] =
          _prefs.getBool(entry.value) ?? notificationPreferenceDefaults[entry.key]!;
    }
    _quietHoursStart = _prefs.getString(_kQuietHoursStart) ?? '22:00';
    _quietHoursEnd = _prefs.getString(_kQuietHoursEnd) ?? '07:00';
    _quietHoursOffsetMinutes = (_prefs.getInt(_kQuietHoursOffsetMinutes) ??
        DateTime.now().timeZoneOffset.inMinutes).clamp(-840, 840);
    _autoDownloadWifi = _prefs.getString(_kAutoDownloadWifi) ?? 'all';
    _autoDownloadMobile = _prefs.getString(_kAutoDownloadMobile) ?? 'photos';
    _photoQuality = _prefs.getString(_kPhotoQuality) ?? 'high';
    _language = _prefs.getString(_kLanguage) ?? 'en';
    final savedTimeFormat = _prefs.getString(_kTimeFormat) ?? '12h';
    _timeFormat = savedTimeFormat == '24h' ? '24h' : '12h';
    _fontSize = (_prefs.getDouble(_kFontSize) ?? 0.85).clamp(0.75, 1.25).toDouble();
    _chatLabelSize = (_prefs.getDouble(_kChatLabelSize) ?? 1.0).clamp(0.8, 1.4).toDouble();
    _accentColorValue = _prefs.getInt(_kAccentColor) ?? 0xFF6D5DFC;
    _accentColorEnabled = _prefs.getBool(_kAccentColorEnabled) ?? true;
    const alertStyles = {'snackbar', 'top_banner', 'capsule', 'switch_card', 'centre_hud', 'countdown_card'};
    final savedAlertStyle = _prefs.getString(_kAlertStyle) ?? 'snackbar';
    _alertStyle = alertStyles.contains(savedAlertStyle) ? savedAlertStyle : 'snackbar';
    if (_alertStyle != savedAlertStyle) await _prefs.setString(_kAlertStyle, _alertStyle);
    const callMiniStyles = {
      'top_banner', 'floating_avatar', 'compact_pill',
      'bottom_bar', 'video_card', 'edge_chip',
    };
    const legacyCallMiniStyles = <String, String>{
      'floating_bar': 'top_banner',
      'glass_card': 'video_card',
      'accent_strip': 'top_banner',
      'avatar_bubble': 'floating_avatar',
      'video_focus': 'video_card',
    };
    final savedCallMiniStyle = _prefs.getString(_kCallMiniStyle) ?? 'top_banner';
    _callMiniStyle = callMiniStyles.contains(savedCallMiniStyle)
        ? savedCallMiniStyle
        : legacyCallMiniStyles[savedCallMiniStyle] ?? 'top_banner';
    if (_callMiniStyle != savedCallMiniStyle) {
      await _prefs.setString(_kCallMiniStyle, _callMiniStyle);
    }
    const dockStyles = [
      'slide_pill',
      'expand_capsule',
      'edge_to_edge',
      'dot_minimal',
      'soft_glow_glass',
      'liquid_stretch',
      'flip_tiles',
      'draw_ring',
    ];
    const legacyDockStyles = <String, String>{
      'floating_pill': 'slide_pill',
      'rounded_bar': 'slide_pill',
      'minimal': 'dot_minimal',
      'glass': 'soft_glow_glass',
      'sliding': 'slide_pill',
      'elevated': 'expand_capsule',
      'full_width': 'edge_to_edge',
      'glow': 'soft_glow_glass',
    };
    final savedDockStyle = _prefs.getString(_kDockStyle) ?? 'slide_pill';
    if (dockStyles.contains(savedDockStyle)) {
      _dockStyle = savedDockStyle;
    } else {
      _dockStyle = legacyDockStyles[savedDockStyle] ?? 'slide_pill';
      await _prefs.setString(_kDockStyle, _dockStyle);
    }
    _twoFactorAuth = _prefs.getBool(_kTwoFactorAuth) ?? false;
    _lastSeenVisibility = _prefs.getString(_kLastSeen) ?? 'everyone';
    _profilePhotoVisibility = _prefs.getString(_kProfilePhoto) ?? 'everyone';
    _blockedUids = _prefs.getStringList(_kBlockedUids) ?? [];
    _favoriteChatIds = _prefs.getStringList(_kFavoriteChatIds) ?? [];
    _notificationTone = _prefs.getString(_kNotificationTone) ?? 'Aurora';
    _callRingtone = _prefs.getString(_kCallRingtone) ?? 'Binary';
    _customNotificationPath = _prefs.getString(_kCustomNotificationPath);
    _customRingtonePath = _prefs.getString(_kCustomRingtonePath);
    _region = _prefs.getString(_kRegion) ?? _detectDeviceRegion();
    
    // Recovery: If region is "Germany" (previous bug) or "United States" (old default),
    // and we are actually in India (via offset), force reset to India.
    if ((_region == 'Germany' || _region == 'United States') && _detectDeviceRegion() == 'India') {
      _region = 'India';
    }
    _language = _prefs.getString(_kLanguage) ?? _detectDeviceLanguage();
    _vibrationPattern = _prefs.getString(_kVibrationPattern) ?? 'standard';
    _hapticIntensity = (_prefs.getDouble(_kHapticIntensity) ?? 0.8).clamp(0.0, 1.0).toDouble();
    _hapticNavigation = _prefs.getBool(_kHapticNavigation) ?? true;
    _hapticTyping = _prefs.getBool(_kHapticTyping) ?? true;
    _hapticChat = _prefs.getBool(_kHapticChat) ?? true;
    _hapticButtons = _prefs.getBool(_kHapticButtons) ?? true;
    _hapticNotifications = _prefs.getBool(_kHapticNotifications) ?? true;
    _hapticCalls = _prefs.getBool(_kHapticCalls) ?? true;
    _messageVolume = (_prefs.getDouble('novyn_message_volume') ?? 0.8).clamp(0.0, 1.0).toDouble();
    _callVolume = (_prefs.getDouble('novyn_call_volume') ?? 0.85).clamp(0.0, 1.0).toDouble();
    _appLockEnabled = _prefs.getBool(_kAppLockEnabled) ?? false;
    _appLockTimeout = _prefs.getInt(_kAppLockTimeout) ?? 0;
    // Migrate legacy PINs from plain preferences into encrypted storage.
    // Keystore errors are recoverable startup conditions, not a reason to
    // abort runApp or silently disable an enabled App Lock.
    _secureStorageReadFailed = false;
    _appLockPin = await _readSecureValue(_secureAppLockPin);
    final legacyAppPin = _prefs.getString(_kAppLockPin);
    if (_appLockPin == null && legacyAppPin != null) {
      _appLockPin = legacyAppPin;
      final migrated = await _writeSecureValue(_secureAppLockPin, legacyAppPin);
      if (migrated) await _prefs.remove(_kAppLockPin);
    }
    _isLocked = _appLockEnabled &&
        (_appLockPin != null || _secureStorageReadFailed);
    _appLockFailedAttempts = int.tryParse(
          await _readSecureValue(_secureAppLockFailures) ?? '0',
        ) ?? 0;
    final lockUntilRaw = await _readSecureValue(_secureAppLockUntil);
    final lockUntilMillis = int.tryParse(lockUntilRaw ?? '');
    _appLockLockedUntil = lockUntilMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lockUntilMillis);
    if (_appLockLockedUntil != null && !_appLockLockedUntil!.isAfter(DateTime.now())) {
      _appLockLockedUntil = null;
      await _deleteSecureValue(_secureAppLockUntil);
    }
    if (_appLockEnabled && _appLockPin == null && !_secureStorageReadFailed) {
      // Only disable App Lock when secure storage responded successfully and
      // confirmed the PIN is genuinely absent.
      _appLockEnabled = false;
      await _prefs.setBool(_kAppLockEnabled, false);
    }
    _stealthModeEnabled = _prefs.getBool(_kStealthMode) ?? false;
    _panicPin = await _readSecureValue(_securePanicPin);
    final legacyPanicPin = _prefs.getString(_kPanicPin);
    if (_panicPin == null && legacyPanicPin != null) {
      _panicPin = legacyPanicPin;
      final migrated = await _writeSecureValue(_securePanicPin, legacyPanicPin);
      if (migrated) await _prefs.remove(_kPanicPin);
    }
    _hideNotificationContent = _prefs.getBool(_kHideNotificationContent) ?? false;
    // Keep older installations safe when Stealth Mode was already enabled.
    if (_stealthModeEnabled && !_hideNotificationContent) {
      await _prefs.setBool(_kStealthPreviousNotificationPrivacy, false);
      _hideNotificationContent = true;
      await _prefs.setBool(_kHideNotificationContent, true);
    }
    _stealthIconEnabled = _prefs.getBool(_kStealthIcon) ?? false;
    _highContrast = _prefs.getBool(_kHighContrast) ?? false;
    _reduceMotion = _prefs.getBool(_kReduceMotion) ?? false;
    _busyPreviousPresenceMode = _prefs.getString(_kBusyPreviousPresence);
    _doNotDisturbEnabled = _prefs.getBool(_kDoNotDisturb) ?? false;
    _activeSmartPresenceMode = normalizeSmartPresenceMode(_prefs.getString(_kActiveSmartPresenceMode) ?? 'online');
    _smartPresenceOverrides = {};
    final rawPresenceOverrides = _prefs.getString(_kSmartPresenceOverrides);
    if (rawPresenceOverrides != null) {
      try {
        final decoded = jsonDecode(rawPresenceOverrides);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final mode = normalizeSmartPresenceMode(entry.key.toString());
            if (entry.value is! Map) continue;
            final values = Map<String, dynamic>.from(entry.value as Map)
              ..removeWhere((key, _) => !_smartPresenceAllowedKeys.contains(key));
            if (values.isNotEmpty) _smartPresenceOverrides[mode] = values;
          }
        }
      } catch (_) { _smartPresenceOverrides = {}; }
    }
    
    // Load saved sessions
    final raw = _prefs.getString(_kSavedSessions);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _savedSessions = list
            .map((e) => SavedSession.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _savedSessions = [];
      }
    }
    _loaded = true;
    notifyListeners();
  }

  // ── Setters (persist immediately) ───────────────────────────────────────
  Future<void> setNotifications(bool v, {bool recordPresenceOverride = true}) async {
    _notificationsOn = v;
    await _prefs.setBool(_kNotifications, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('notificationsEnabled', v);
    notifyListeners();
  }

  Future<void> setChatLinkPreviews(bool v) async {
    _chatLinkPreviews = v;
    await _prefs.setBool(_kChatLinkPreviews, v);
    notifyListeners();
  }

  Future<void> setMessagePreview(bool v, {bool recordPresenceOverride = true}) async {
    _messagePreview = v;
    await _prefs.setBool(_kMessagePreview, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('messagePreviewEnabled', v);
    notifyListeners();
  }

  Future<void> setReadReceipts(bool v, {bool recordPresenceOverride = true}) async {
    _readReceipts = v;
    await _prefs.setBool(_kReadReceipts, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('readReceiptsEnabled', v);
    notifyListeners();
  }

  Future<void> setOnlineStatus(bool v) async {
    _onlineStatus = v;
    await _prefs.setBool(_kOnlineStatus, v);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setInt(_kThemeMode, mode.index);
    notifyListeners();
  }

  Future<void> setProfile({required String name, required String bio}) async {
    _displayName = name;
    _bio = bio;
    await _prefs.setString(_kDisplayName, name);
    await _prefs.setString(_kBio, bio);
    notifyListeners();
  }

  // ── New setters ──────────────────────────────────────────────────────────
  Future<void> setChatEnterToSend(bool v) async {
    _chatEnterToSend = v;
    await _prefs.setBool('chat_enter_to_send', v);
    notifyListeners();
  }

  Future<void> setInAppSounds(bool v, {bool recordPresenceOverride = true}) async {
    _inAppSounds = v;
    await _prefs.setBool(_kInAppSounds, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('inAppSoundsEnabled', v);
    notifyListeners();
  }

  Future<void> setInAppVibration(bool v, {bool recordPresenceOverride = true}) async {
    _inAppVibration = v;
    await _prefs.setBool(_kInAppVibration, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('inAppVibrationEnabled', v);
    notifyListeners();
  }

  Future<void> setHapticCategory(String category, bool enabled) async {
    final key = switch (category) {
      'navigation' => _kHapticNavigation,
      'typing' => _kHapticTyping,
      'chat' => _kHapticChat,
      'notifications' => _kHapticNotifications,
      'calls' => _kHapticCalls,
      'buttons' => _kHapticButtons,
      _ => null,
    };
    if (key == null) return;
    switch (category) {
      case 'navigation': _hapticNavigation = enabled; break;
      case 'typing': _hapticTyping = enabled; break;
      case 'chat': _hapticChat = enabled; break;
      case 'notifications': _hapticNotifications = enabled; break;
      case 'calls': _hapticCalls = enabled; break;
      case 'buttons': _hapticButtons = enabled; break;
    }
    await _prefs.setBool(key, enabled);
    notifyListeners();
  }

  Future<void> setGroupNotifications(bool v, {bool recordPresenceOverride = true}) async {
    _groupNotifications = v;
    await _prefs.setBool(_kGroupNotifications, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('groupNotificationsEnabled', v);
    notifyListeners();
  }

  Future<void> setAutoDownloadWifi(String v) async {
    _autoDownloadWifi = v;
    await _prefs.setString(_kAutoDownloadWifi, v);
    notifyListeners();
  }

  Future<void> setAutoDownloadMobile(String v) async {
    _autoDownloadMobile = v;
    await _prefs.setString(_kAutoDownloadMobile, v);
    notifyListeners();
  }

  Future<void> setPhotoQuality(String v) async {
    _photoQuality = v;
    await _prefs.setString(_kPhotoQuality, v);
    notifyListeners();
  }

  Future<void> setLanguage(String v) async {
    _language = v;
    await _prefs.setString(_kLanguage, v);
    notifyListeners();
  }

  Future<void> setAccentColor(int value) async {
    _accentColorValue = value;
    await _prefs.setInt(_kAccentColor, value);
    notifyListeners();
  }

  Future<void> setAccentColorEnabled(bool enabled) async {
    _accentColorEnabled = enabled;
    await _prefs.setBool(_kAccentColorEnabled, enabled);
    notifyListeners();
  }

  Future<void> setAlertStyle(String style) async {
    const allowed = {'snackbar', 'top_banner', 'capsule', 'switch_card', 'centre_hud', 'countdown_card'};
    if (!allowed.contains(style) || _alertStyle == style) return;
    _alertStyle = style;
    await _prefs.setString(_kAlertStyle, style);
    notifyListeners();
  }

  Future<void> setCallMiniStyle(String style) async {
    const allowed = {
      'top_banner', 'floating_avatar', 'compact_pill',
      'bottom_bar', 'video_card', 'edge_chip',
    };
    if (!allowed.contains(style) || _callMiniStyle == style) return;
    _callMiniStyle = style;
    await _prefs.setString(_kCallMiniStyle, style);
    notifyListeners();
  }

  Future<void> setDockStyle(String style) async {
    const allowed = {
      'slide_pill',
      'expand_capsule',
      'edge_to_edge',
      'dot_minimal',
      'soft_glow_glass',
      'liquid_stretch',
      'flip_tiles',
      'draw_ring',
    };
    if (!allowed.contains(style)) return;
    if (_dockStyle == style) return;
    _dockStyle = style;
    await _prefs.setString(_kDockStyle, style);
    notifyListeners();
  }

  Future<void> setChatLabelSize(double v) async {
    _chatLabelSize = v.clamp(0.8, 1.4).toDouble();
    await _prefs.setDouble(_kChatLabelSize, _chatLabelSize);
    notifyListeners();
  }

  Future<void> setFontSize(double v) async {
    v = v.clamp(0.75, 1.25).toDouble();
    _fontSize = v;
    await _prefs.setDouble(_kFontSize, v);
    notifyListeners();
  }

  Future<void> setHighContrast(bool v) async {
    _highContrast = v;
    await _prefs.setBool(_kHighContrast, v);
    notifyListeners();
  }

  Future<void> setDoNotDisturbEnabled(bool enabled) async {
    if (_doNotDisturbEnabled == enabled) return;

    // Persist first so a failed device-storage write never leaves the UI
    // showing a value that was not actually saved.
    final saved = await _prefs.setBool(_kDoNotDisturb, enabled);
    if (!saved) {
      throw StateError('Your device could not save the Do Not Disturb setting.');
    }

    _doNotDisturbEnabled = enabled;
    notifyListeners();
  }

  Future<void> setBusyPreviousPresenceMode(String? mode) async {
    const allowed = {'online', 'away', 'invisible'};
    _busyPreviousPresenceMode = mode != null && allowed.contains(mode) ? mode : null;
    if (_busyPreviousPresenceMode == null) {
      await _prefs.remove(_kBusyPreviousPresence);
    } else {
      await _prefs.setString(_kBusyPreviousPresence, _busyPreviousPresenceMode!);
    }
    notifyListeners();
  }

  Future<void> setReduceMotion(bool v) async {
    if (_reduceMotion == v) return;
    _reduceMotion = v;
    // Update MediaQuery immediately so the accessibility control never waits
    // on a disk write before reflecting the user's choice.
    notifyListeners();
    await _prefs.setBool(_kReduceMotion, v);
  }

  Future<void> setTwoFactorAuth(bool v) async {
    _twoFactorAuth = v;
    await _prefs.setBool(_kTwoFactorAuth, v);
    notifyListeners();
  }

  Future<void> setTimeFormat(String value) async {
    _timeFormat = value == '24h' ? '24h' : '12h';
    await _prefs.setString(_kTimeFormat, _timeFormat);
    notifyListeners();
  }

  Future<void> setLastSeenVisibility(String v, {bool recordPresenceOverride = true}) async {
    _lastSeenVisibility = v;
    await _prefs.setString(_kLastSeen, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('presencePrivacy', v == 'contacts' ? 'friends' : v);
    notifyListeners();
  }

  Future<void> setProfilePhotoVisibility(String v, {bool recordPresenceOverride = true}) async {
    _profilePhotoVisibility = v;
    await _prefs.setString(_kProfilePhoto, v);
    if (recordPresenceOverride) await recordActiveSmartPresenceOverride('profilePhotoPrivacy', v == 'contacts' ? 'friends' : v);
    notifyListeners();
  }

  Future<void> toggleFavoriteChat(String chatId) async {
    if (_favoriteChatIds.contains(chatId)) {
      _favoriteChatIds.remove(chatId);
    } else {
      _favoriteChatIds.add(chatId);
    }
    await _prefs.setStringList(_kFavoriteChatIds, _favoriteChatIds);
    notifyListeners();
  }

  Future<void> blockUser(String uid) async {
    if (!_blockedUids.contains(uid)) {
      _blockedUids.add(uid);
      await _prefs.setStringList(_kBlockedUids, _blockedUids);
      notifyListeners();
    }
  }

  Future<void> unblockUser(String uid) async {
    if (_blockedUids.contains(uid)) {
      _blockedUids.remove(uid);
      await _prefs.setStringList(_kBlockedUids, _blockedUids);
      notifyListeners();
    }
  }

  Future<void> setNotificationTone(String v) async {
    _notificationTone = v;
    await _prefs.setString(_kNotificationTone, v);
    notifyListeners();
  }

  Future<void> setCallRingtone(String v) async {
    _callRingtone = v;
    await _prefs.setString(_kCallRingtone, v);
    notifyListeners();
  }

  Future<void> setCustomNotificationPath(String? path) async {
    _customNotificationPath = path;
    if (path == null) {
      await _prefs.remove(_kCustomNotificationPath);
    } else {
      await _prefs.setString(_kCustomNotificationPath, path);
    }
    notifyListeners();
  }

  Future<void> setCustomRingtonePath(String? path) async {
    _customRingtonePath = path;
    if (path == null) {
      await _prefs.remove(_kCustomRingtonePath);
    } else {
      await _prefs.setString(_kCustomRingtonePath, path);
    }
    notifyListeners();
  }

  Future<void> setRegion(String v) async {
    _region = v;
    await _prefs.setString(_kRegion, v);
    
    // Auto-update language if current language is not in the new region's list
    final allowed = getLanguagesForRegion(v).keys.toList();
    if (!allowed.contains(_language)) {
      await setLanguage(allowed.first);
    }
    
    notifyListeners();
  }

  Map<String, String> getLanguagesForRegion(String regionName) {
    switch (regionName) {
      case 'India':
        return {
          'hi': 'हिन्दी (Hindi)',
          'en': 'English',
          'mr': 'मराठी (Marathi)',
          'bn': 'বাংলা (Bengali)',
          'ta': 'தமிழ் (Tamil)',
          'te': 'తెలుగు (Telugu)',
        };
      case 'United States':
        return {'en': 'English', 'es': 'Español'};
      case 'United Kingdom':
        return {'en': 'English'};
      case 'Germany':
        return {'de': 'Deutsch', 'en': 'English'};
      case 'France':
        return {'fr': 'Français', 'en': 'English'};
      case 'Spain':
        return {'es': 'Español', 'en': 'English'};
      case 'Italy':
        return {'it': 'Italiano', 'en': 'English'};
      case 'Japan':
        return {'ja': '日本語 (Japanese)', 'en': 'English'};
      case 'South Korea':
        return {'ko': '한국어 (Korean)', 'en': 'English'};
      case 'Russia':
        return {'ru': 'Русский (Russian)', 'en': 'English'};
      case 'Canada':
        return {'en': 'English', 'fr': 'Français'};
      default:
        return {'en': 'English'};
    }
  }

  Future<void> setVibrationPattern(String v) async {
    _vibrationPattern = v;
    await _prefs.setString(_kVibrationPattern, v);
    notifyListeners();
  }

  String _detectDeviceRegion() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    final countryCode = locale.countryCode?.toUpperCase();
    
    // Fallback: Detection via Timezone Offset (India is UTC+5.5)
    final offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;
    if (offsetMinutes == 330) return 'India';
    
    switch (countryCode) {
      case 'IN': return 'India';
      case 'GB': return 'United Kingdom';
      case 'CA': return 'Canada';
      case 'AU': return 'Australia';
      case 'DE': return 'Germany';
      case 'FR': return 'France';
      case 'ES': return 'Spain';
      case 'IT': return 'Italy';
      case 'JP': return 'Japan';
      case 'KR': return 'South Korea';
      case 'RU': return 'Russia';
      default: return 'United States';
    }
  }

  String _detectDeviceLanguage() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    return locale.languageCode.toLowerCase();
  }

  Future<void> setMessageVolume(double v) async {
    _messageVolume = v.clamp(0.0, 1.0).toDouble();
    await _prefs.setDouble('novyn_message_volume', _messageVolume);
    notifyListeners();
  }

  Future<void> setCallVolume(double v) async {
    _callVolume = v.clamp(0.0, 1.0).toDouble();
    await _prefs.setDouble('novyn_call_volume', _callVolume);
    notifyListeners();
  }

  Future<void> setHapticIntensity(double v) async {
    v = v.clamp(0.0, 1.0).toDouble();
    _hapticIntensity = v;
    await _prefs.setDouble(_kHapticIntensity, v);
    notifyListeners();
  }

  Future<void> setAppLockEnabled(bool v) async {
    if (v && _appLockPin == null) {
      throw StateError('Set an app lock PIN before enabling App Lock.');
    }
    _appLockEnabled = v;
    await _prefs.setBool(_kAppLockEnabled, v);
    notifyListeners();
  }

  Future<void> setAppLockTimeout(int v) async {
    _appLockTimeout = v;
    await _prefs.setInt(_kAppLockTimeout, v);
    notifyListeners();
  }

  Future<void> setAppLockPin(String? pin) async {
    if (pin != null && (pin.length != 4 || int.tryParse(pin) == null)) {
      throw ArgumentError('App lock PIN must contain exactly 4 digits.');
    }
    _appLockPin = pin;
    if (pin == null) {
      await _deleteSecureValue(_secureAppLockPin);
    } else if (!await _writeSecureValue(_secureAppLockPin, pin)) {
      throw StateError('Secure storage is temporarily unavailable. Try again.');
    }
    notifyListeners();
  }

  Future<void> recordFailedAppLockAttempt() async {
    _appLockFailedAttempts += 1;
    await _writeSecureValue(
      _secureAppLockFailures,
      _appLockFailedAttempts.toString(),
    );
    Duration? cooldown;
    if (_appLockFailedAttempts == 15) {
      cooldown = const Duration(minutes: 10);
    } else if (_appLockFailedAttempts == 10) {
      cooldown = const Duration(minutes: 2);
    } else if (_appLockFailedAttempts == 5) {
      cooldown = const Duration(seconds: 30);
    }
    if (cooldown != null) {
      _appLockLockedUntil = DateTime.now().add(cooldown);
      await _writeSecureValue(
        _secureAppLockUntil,
        _appLockLockedUntil!.millisecondsSinceEpoch.toString(),
      );
    }
    notifyListeners();
  }

  Future<void> resetAppLockFailures() async {
    _appLockFailedAttempts = 0;
    _appLockLockedUntil = null;
    await _deleteSecureValue(_secureAppLockFailures);
    await _deleteSecureValue(_secureAppLockUntil);
    notifyListeners();
  }

  // Recovery deliberately requires a fresh account sign-in. The PIN is
  // removed only after the user confirms they want to sign out.
  Future<void> prepareAppLockAccountRecovery() async {
    _appLockEnabled = false;
    _isLocked = false;
    await _prefs.setBool(_kAppLockEnabled, false);
    await setAppLockPin(null);
    await resetAppLockFailures();
    notifyListeners();
  }

  void setLocked(bool v) {
    _isLocked = v;
    notifyListeners();
  }

  Future<void> setStealthMode(bool v) async {
    if (v == _stealthModeEnabled) return;

    // Commit the in-memory value only after the device confirms persistence.
    final saved = await _prefs.setBool(_kStealthMode, v);
    if (!saved) {
      throw StateError('Your device could not save the Stealth Mode setting.');
    }

    _stealthModeEnabled = v;
    notifyListeners();
  }

  Future<void> setPanicPin(String? pin) async {
    if (pin != null && (pin.length != 4 || int.tryParse(pin) == null)) {
      throw ArgumentError('Panic PIN must contain exactly 4 digits.');
    }
    _panicPin = pin;
    if (pin == null) {
      await _deleteSecureValue(_securePanicPin);
    } else if (!await _writeSecureValue(_securePanicPin, pin)) {
      throw StateError('Secure storage is temporarily unavailable. Try again.');
    }
    notifyListeners();
  }

  Future<void> setHideNotificationContent(bool v) async {
    _hideNotificationContent = v;
    await _prefs.setBool(_kHideNotificationContent, v);
    notifyListeners();
  }

  void setDecoyMode(bool v) {
    _decoyMode = v;
    notifyListeners();
  }

  Future<void> setStealthIconEnabled(bool v) async {
    _stealthIconEnabled = v;
    await _prefs.setBool(_kStealthIcon, v);
    notifyListeners();
  }

  void unlockWithDecoy(bool isDecoy) {
    _decoyMode = isDecoy;
    _isLocked = false;
    resetAppLockFailures();
    notifyListeners();
  }

  bool isBlocked(String uid) => _blockedUids.contains(uid);

  // ── Saved sessions ───────────────────────────────────────────────────────
  Future<void> saveSession(SavedSession session) async {
    // Remove existing entry for same uid/email, then add fresh
    _savedSessions.removeWhere(
        (s) => s.uid == session.uid || s.email == session.email);
    _savedSessions.insert(0, session); // most recent first
    // Keep max 5 saved accounts
    if (_savedSessions.length > 5) _savedSessions = _savedSessions.sublist(0, 5);
    await _persistSessions();
    notifyListeners();
  }

  Future<void> removeSession(String uid) async {
    _savedSessions.removeWhere((s) => s.uid == uid);
    await _persistSessions();
    notifyListeners();
  }

  Future<void> _persistSessions() async {
    final encoded = jsonEncode(_savedSessions.map((s) => s.toJson()).toList());
    await _prefs.setString(_kSavedSessions, encoded);
  }

  /// Export only account-level preferences. Device secrets, local file paths,
  /// biometric/app-lock state and transient runtime flags are intentionally
  /// excluded from cloud sync.
  Map<String, dynamic> cloudSyncSnapshot({String? accountKey}) => {
        'chatLinkPreviews': _chatLinkPreviews,
        'onlineStatus': _onlineStatus,
        'themeMode': _themeMode.name,
        'chatEnterToSend': _chatEnterToSend,
        'autoDownloadWifi': _autoDownloadWifi,
        'autoDownloadMobile': _autoDownloadMobile,
        'photoQuality': _photoQuality,
        'language': _language,
        'timeFormat': _timeFormat,
        'fontSize': _fontSize,
        'chatLabelSize': _chatLabelSize,
        'accentColorValue': _accentColorValue,
        'accentColorEnabled': _accentColorEnabled,
        'dockStyle': _dockStyle,
        'alertStyle': _alertStyle,
        'notificationTone': _notificationTone,
        'callRingtone': _callRingtone,
        'vibrationPattern': _vibrationPattern,
        'hapticIntensity': _hapticIntensity,
        'hapticNavigation': _hapticNavigation,
        'hapticTyping': _hapticTyping,
        'hapticChat': _hapticChat,
        'hapticButtons': _hapticButtons,
        'hapticNotifications': _hapticNotifications,
        'hapticCalls': _hapticCalls,
        'messageVolume': _messageVolume,
        'callVolume': _callVolume,
        'region': _region,
        'highContrast': _highContrast,
        'reduceMotion': _reduceMotion,
        'doNotDisturbEnabled': _doNotDisturbEnabled,
        if (accountKey != null && accountKey.trim().isNotEmpty)
          'quickToggleIds': quickToggleIdsFor(accountKey),
      };

  /// Apply an account snapshot without invoking each public setter (and
  /// therefore without causing a burst of listener notifications/network work).
  /// The UI receives one notification after the local cache has been updated.
  Future<void> applyCloudSyncSnapshot(
    Map<String, dynamic> values, {
    String? accountKey,
  }) async {
    if (!_loaded) {
      throw StateError('Settings must be loaded before applying cloud settings.');
    }

    bool boolValue(String key, bool fallback) =>
        values[key] is bool ? values[key] as bool : fallback;
    String stringValue(String key, String fallback) =>
        values[key] is String ? (values[key] as String) : fallback;
    double doubleValue(String key, double fallback, double min, double max) {
      final raw = values[key];
      final value = raw is num ? raw.toDouble() : fallback;
      return value.clamp(min, max).toDouble();
    }

    _notificationsOn = boolValue('notificationsOn', _notificationsOn);
    _messagePreview = boolValue('messagePreview', _messagePreview);
    _chatLinkPreviews = boolValue('chatLinkPreviews', _chatLinkPreviews);
    _readReceipts = boolValue('readReceipts', _readReceipts);
    _onlineStatus = boolValue('onlineStatus', _onlineStatus);
    final themeName = stringValue('themeMode', _themeMode.name);
    _themeMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == themeName,
      orElse: () => _themeMode,
    );
    _inAppSounds = boolValue('inAppSounds', _inAppSounds);
    _chatEnterToSend = boolValue('chatEnterToSend', _chatEnterToSend);
    _inAppVibration = boolValue('inAppVibration', _inAppVibration);
    _groupNotifications = boolValue('groupNotifications', _groupNotifications);
    _autoDownloadWifi = stringValue('autoDownloadWifi', _autoDownloadWifi);
    _autoDownloadMobile = stringValue('autoDownloadMobile', _autoDownloadMobile);
    _photoQuality = stringValue('photoQuality', _photoQuality);
    _language = stringValue('language', _language);
    _timeFormat = stringValue('timeFormat', _timeFormat) == '24h' ? '24h' : '12h';
    _fontSize = doubleValue('fontSize', _fontSize, 0.75, 1.25);
    _chatLabelSize = doubleValue('chatLabelSize', _chatLabelSize, 0.8, 1.4);
    final accent = values['accentColorValue'];
    if (accent is num && accent.toInt() >= 0 && accent.toInt() <= 0xFFFFFFFF) {
      _accentColorValue = accent.toInt();
    }
    _accentColorEnabled = boolValue('accentColorEnabled', _accentColorEnabled);

    const dockStyles = {
      'slide_pill', 'expand_capsule', 'edge_to_edge', 'dot_minimal',
      'soft_glow_glass', 'liquid_stretch', 'flip_tiles', 'draw_ring',
    };
    final dockStyle = stringValue('dockStyle', _dockStyle);
    if (dockStyles.contains(dockStyle)) _dockStyle = dockStyle;
    const alertStyles = {
      'snackbar', 'top_banner', 'capsule', 'switch_card',
      'centre_hud', 'countdown_card',
    };
    final alertStyle = stringValue('alertStyle', _alertStyle);
    if (alertStyles.contains(alertStyle)) _alertStyle = alertStyle;

    _notificationTone = stringValue('notificationTone', _notificationTone);
    _callRingtone = stringValue('callRingtone', _callRingtone);
    _vibrationPattern = stringValue('vibrationPattern', _vibrationPattern);
    _hapticIntensity = doubleValue('hapticIntensity', _hapticIntensity, 0, 1);
    _hapticNavigation = boolValue('hapticNavigation', _hapticNavigation);
    _hapticTyping = boolValue('hapticTyping', _hapticTyping);
    _hapticChat = boolValue('hapticChat', _hapticChat);
    _hapticButtons = boolValue('hapticButtons', _hapticButtons);
    _hapticNotifications = boolValue('hapticNotifications', _hapticNotifications);
    _hapticCalls = boolValue('hapticCalls', _hapticCalls);
    _messageVolume = doubleValue('messageVolume', _messageVolume, 0, 1);
    _callVolume = doubleValue('callVolume', _callVolume, 0, 1);
    _region = stringValue('region', _region);
    _highContrast = boolValue('highContrast', _highContrast);
    _reduceMotion = boolValue('reduceMotion', _reduceMotion);
    _doNotDisturbEnabled = boolValue('doNotDisturbEnabled', _doNotDisturbEnabled);

    final writes = <Future<bool>>[
      _prefs.setBool(_kNotifications, _notificationsOn),
      _prefs.setBool(_kMessagePreview, _messagePreview),
      _prefs.setBool(_kChatLinkPreviews, _chatLinkPreviews),
      _prefs.setBool(_kReadReceipts, _readReceipts),
      _prefs.setBool(_kOnlineStatus, _onlineStatus),
      _prefs.setInt(_kThemeMode, _themeMode.index),
      _prefs.setBool(_kInAppSounds, _inAppSounds),
      _prefs.setBool('chat_enter_to_send', _chatEnterToSend),
      _prefs.setBool(_kInAppVibration, _inAppVibration),
      _prefs.setBool(_kGroupNotifications, _groupNotifications),
      _prefs.setString(_kAutoDownloadWifi, _autoDownloadWifi),
      _prefs.setString(_kAutoDownloadMobile, _autoDownloadMobile),
      _prefs.setString(_kPhotoQuality, _photoQuality),
      _prefs.setString(_kLanguage, _language),
      _prefs.setString(_kTimeFormat, _timeFormat),
      _prefs.setDouble(_kFontSize, _fontSize),
      _prefs.setDouble(_kChatLabelSize, _chatLabelSize),
      _prefs.setInt(_kAccentColor, _accentColorValue),
      _prefs.setBool(_kAccentColorEnabled, _accentColorEnabled),
      _prefs.setString(_kDockStyle, _dockStyle),
      _prefs.setString(_kAlertStyle, _alertStyle),
      _prefs.setString(_kNotificationTone, _notificationTone),
      _prefs.setString(_kCallRingtone, _callRingtone),
      _prefs.setString(_kVibrationPattern, _vibrationPattern),
      _prefs.setDouble(_kHapticIntensity, _hapticIntensity),
      _prefs.setBool(_kHapticNavigation, _hapticNavigation),
      _prefs.setBool(_kHapticTyping, _hapticTyping),
      _prefs.setBool(_kHapticChat, _hapticChat),
      _prefs.setBool(_kHapticButtons, _hapticButtons),
      _prefs.setBool(_kHapticNotifications, _hapticNotifications),
      _prefs.setBool(_kHapticCalls, _hapticCalls),
      _prefs.setDouble('novyn_message_volume', _messageVolume),
      _prefs.setDouble('novyn_call_volume', _callVolume),
      _prefs.setString(_kRegion, _region),
      _prefs.setBool(_kHighContrast, _highContrast),
      _prefs.setBool(_kReduceMotion, _reduceMotion),
      _prefs.setBool(_kDoNotDisturb, _doNotDisturbEnabled),
    ];
    final quickIds = values['quickToggleIds'];
    if (accountKey != null &&
        accountKey.trim().isNotEmpty &&
        quickIds is List) {
      final cleaned = sanitizeQuickToggleIds(
        quickIds.whereType<String>(),
      );
      if (cleaned.isNotEmpty) {
        writes.add(_prefs.setStringList(
          _quickToggleStorageKey(accountKey),
          cleaned,
        ));
      }
    }
    await Future.wait(writes);
    notifyListeners();
  }

  Future<void> clearAll() async {
    await _prefs.clear();
    await _deleteSecureValue(_secureAppLockPin);
    await _deleteSecureValue(_securePanicPin);
    _notificationsOn = true;
    _messagePreview = true;
    _chatLinkPreviews = true;
    _readReceipts = true;
    _onlineStatus = true;
    _themeMode = ThemeMode.system;
    _displayName = '';
    _bio = '';
    _savedSessions = [];
    
    // Reset new settings
    _inAppSounds = true;
    _chatEnterToSend = true;
    _inAppVibration = true;
    _groupNotifications = true;
    _autoDownloadWifi = 'all';
    _autoDownloadMobile = 'photos';
    _photoQuality = 'high';
    _language = 'en';
    _fontSize = 0.85;
    _chatLabelSize = 1.0;
    _accentColorValue = 0xFF6D5DFC;
    _accentColorEnabled = true;
    _dockStyle = 'slide_pill';
    _alertStyle = 'snackbar';
    _callMiniStyle = 'top_banner';
    _twoFactorAuth = false;
    _lastSeenVisibility = 'everyone';
    _profilePhotoVisibility = 'everyone';
    _blockedUids = [];
    _notificationTone = 'Aurora';
    _vibrationPattern = 'standard';
    _hapticIntensity = 0.8;
    _appLockEnabled = false;
    _appLockTimeout = 0;
    
    notifyListeners();
  }
  @override
  void dispose() {
    super.dispose();
  }

}
