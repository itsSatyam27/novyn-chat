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
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
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
  static const _kFocusModeUntil = 'focus_mode_until_ms';

  late SharedPreferences _prefs;
  bool _loaded = false;

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
  String _autoDownloadWifi = 'all'; // 'all', 'photos', 'none'
  String _autoDownloadMobile = 'photos'; // 'all', 'photos', 'none'
  String _photoQuality = 'high'; // 'high', 'medium', 'low'
  String _language = 'en'; // Language code
  String _timeFormat = '12h'; // '12h' or '24h'
  double _fontSize = 1.0; // Message body font scale
  double _chatLabelSize = 1.0;
  int _accentColorValue = 0xFF6D5DFC;
  bool _accentColorEnabled = true;
  String _dockStyle = 'floating_pill';
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
  int? _focusModeUntilMs;
  Timer? _focusModeExpiryTimer;

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
  bool get focusModeEnabled => _focusModeUntilMs != null && _focusModeUntilMs! > DateTime.now().millisecondsSinceEpoch;
  DateTime? get focusModeEndsAt => focusModeEnabled ? DateTime.fromMillisecondsSinceEpoch(_focusModeUntilMs!) : null;

  // ── Load from disk ───────────────────────────────────────────────────────
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _notificationsOn = _prefs.getBool(_kNotifications) ?? true;
    _messagePreview = _prefs.getBool(_kMessagePreview) ?? true;
    _chatLinkPreviews = _prefs.getBool(_kChatLinkPreviews) ?? true;
    _readReceipts = _prefs.getBool(_kReadReceipts) ?? true;
    _onlineStatus = _prefs.getBool(_kOnlineStatus) ?? true;
    _themeMode = ThemeMode.values[_prefs.getInt(_kThemeMode) ?? ThemeMode.dark.index];
    _displayName = _prefs.getString(_kDisplayName) ?? '';
    _bio = _prefs.getString(_kBio) ?? '';
    
    // Load new settings
    _inAppSounds = _prefs.getBool(_kInAppSounds) ?? true;
    _chatEnterToSend = _prefs.getBool('chat_enter_to_send') ?? true;
    _inAppVibration = _prefs.getBool(_kInAppVibration) ?? true;
    _groupNotifications = _prefs.getBool(_kGroupNotifications) ?? true;
    _autoDownloadWifi = _prefs.getString(_kAutoDownloadWifi) ?? 'all';
    _autoDownloadMobile = _prefs.getString(_kAutoDownloadMobile) ?? 'photos';
    _photoQuality = _prefs.getString(_kPhotoQuality) ?? 'high';
    _language = _prefs.getString(_kLanguage) ?? 'en';
    final savedTimeFormat = _prefs.getString(_kTimeFormat) ?? '12h';
    _timeFormat = savedTimeFormat == '24h' ? '24h' : '12h';
    _fontSize = (_prefs.getDouble(_kFontSize) ?? 1.0).clamp(0.85, 1.25).toDouble();
    _chatLabelSize = (_prefs.getDouble(_kChatLabelSize) ?? 1.0).clamp(0.8, 1.4).toDouble();
    _accentColorValue = _prefs.getInt(_kAccentColor) ?? 0xFF6D5DFC;
    _accentColorEnabled = _prefs.getBool(_kAccentColorEnabled) ?? true;
    const dockStyles = ['floating_pill','rounded_bar','minimal','glass','sliding','elevated','full_width','glow'];
    final savedDockStyle = _prefs.getString(_kDockStyle) ?? 'floating_pill';
    _dockStyle = dockStyles.contains(savedDockStyle) ? savedDockStyle : 'floating_pill';
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
    _appLockPin = await _secureStorage.read(key: _secureAppLockPin);
    final legacyAppPin = _prefs.getString(_kAppLockPin);
    if (_appLockPin == null && legacyAppPin != null) {
      _appLockPin = legacyAppPin;
      await _secureStorage.write(key: _secureAppLockPin, value: legacyAppPin);
    }
    if (legacyAppPin != null) await _prefs.remove(_kAppLockPin);
    _isLocked = _appLockEnabled && _appLockPin != null; // Initial state
    _appLockFailedAttempts = int.tryParse(
          await _secureStorage.read(key: _secureAppLockFailures) ?? '0',
        ) ?? 0;
    final lockUntilRaw = await _secureStorage.read(key: _secureAppLockUntil);
    final lockUntilMillis = int.tryParse(lockUntilRaw ?? '');
    _appLockLockedUntil = lockUntilMillis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lockUntilMillis);
    if (_appLockLockedUntil != null && !_appLockLockedUntil!.isAfter(DateTime.now())) {
      _appLockLockedUntil = null;
      await _secureStorage.delete(key: _secureAppLockUntil);
    }
    if (_appLockEnabled && _appLockPin == null) {
      _appLockEnabled = false;
      await _prefs.setBool(_kAppLockEnabled, false);
    }
    _stealthModeEnabled = _prefs.getBool(_kStealthMode) ?? false;
    _panicPin = await _secureStorage.read(key: _securePanicPin);
    final legacyPanicPin = _prefs.getString(_kPanicPin);
    if (_panicPin == null && legacyPanicPin != null) {
      _panicPin = legacyPanicPin;
      await _secureStorage.write(key: _securePanicPin, value: legacyPanicPin);
    }
    if (legacyPanicPin != null) await _prefs.remove(_kPanicPin);
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
    _focusModeUntilMs = _prefs.getInt(_kFocusModeUntil);
    _scheduleFocusModeExpiry();
    
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
  Future<void> setNotifications(bool v) async {
    _notificationsOn = v;
    await _prefs.setBool(_kNotifications, v);
    notifyListeners();
  }

  Future<void> setChatLinkPreviews(bool v) async {
    _chatLinkPreviews = v;
    await _prefs.setBool(_kChatLinkPreviews, v);
    notifyListeners();
  }

  Future<void> setMessagePreview(bool v) async {
    _messagePreview = v;
    await _prefs.setBool(_kMessagePreview, v);
    notifyListeners();
  }

  Future<void> setReadReceipts(bool v) async {
    _readReceipts = v;
    await _prefs.setBool(_kReadReceipts, v);
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

  Future<void> setInAppSounds(bool v) async {
    _inAppSounds = v;
    await _prefs.setBool(_kInAppSounds, v);
    notifyListeners();
  }

  Future<void> setInAppVibration(bool v) async {
    _inAppVibration = v;
    await _prefs.setBool(_kInAppVibration, v);
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

  Future<void> setGroupNotifications(bool v) async {
    _groupNotifications = v;
    await _prefs.setBool(_kGroupNotifications, v);
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

  Future<void> setDockStyle(String style) async {
    const allowed = {'floating_pill','rounded_bar','minimal','glass','sliding','elevated','full_width','glow'};
    if (!allowed.contains(style)) return;
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
    v = v.clamp(0.85, 1.25).toDouble();
    _fontSize = v;
    await _prefs.setDouble(_kFontSize, v);
    notifyListeners();
  }

  Future<void> setHighContrast(bool v) async {
    _highContrast = v;
    await _prefs.setBool(_kHighContrast, v);
    notifyListeners();
  }

  Future<void> setFocusMode(Duration? duration) async {
    _focusModeExpiryTimer?.cancel();
    if (duration == null) {
      _focusModeUntilMs = null;
      await _prefs.remove(_kFocusModeUntil);
    } else {
      _focusModeUntilMs = DateTime.now().add(duration).millisecondsSinceEpoch;
      await _prefs.setInt(_kFocusModeUntil, _focusModeUntilMs!);
      _scheduleFocusModeExpiry();
    }
    notifyListeners();
  }

  void _scheduleFocusModeExpiry() {
    _focusModeExpiryTimer?.cancel();
    final until = _focusModeUntilMs;
    if (until == null) return;
    final remaining = until - DateTime.now().millisecondsSinceEpoch;
    if (remaining <= 0) {
      _focusModeUntilMs = null;
      unawaited(_prefs.remove(_kFocusModeUntil));
      return;
    }
    _focusModeExpiryTimer = Timer(Duration(milliseconds: remaining), () {
      _focusModeUntilMs = null;
      unawaited(_prefs.remove(_kFocusModeUntil));
      notifyListeners();
    });
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
    _reduceMotion = v;
    await _prefs.setBool(_kReduceMotion, v);
    notifyListeners();
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

  Future<void> setLastSeenVisibility(String v) async {
    _lastSeenVisibility = v;
    await _prefs.setString(_kLastSeen, v);
    notifyListeners();
  }

  Future<void> setProfilePhotoVisibility(String v) async {
    _profilePhotoVisibility = v;
    await _prefs.setString(_kProfilePhoto, v);
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
      await _secureStorage.delete(key: _secureAppLockPin);
    } else {
      await _secureStorage.write(key: _secureAppLockPin, value: pin);
    }
    notifyListeners();
  }

  Future<void> recordFailedAppLockAttempt() async {
    _appLockFailedAttempts += 1;
    await _secureStorage.write(
      key: _secureAppLockFailures,
      value: _appLockFailedAttempts.toString(),
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
      await _secureStorage.write(
        key: _secureAppLockUntil,
        value: _appLockLockedUntil!.millisecondsSinceEpoch.toString(),
      );
    }
    notifyListeners();
  }

  Future<void> resetAppLockFailures() async {
    _appLockFailedAttempts = 0;
    _appLockLockedUntil = null;
    await _secureStorage.delete(key: _secureAppLockFailures);
    await _secureStorage.delete(key: _secureAppLockUntil);
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
    _stealthModeEnabled = v;
    await _prefs.setBool(_kStealthMode, v);
    notifyListeners();
  }

  Future<void> setPanicPin(String? pin) async {
    if (pin != null && (pin.length != 4 || int.tryParse(pin) == null)) {
      throw ArgumentError('Panic PIN must contain exactly 4 digits.');
    }
    _panicPin = pin;
    if (pin == null) {
      await _secureStorage.delete(key: _securePanicPin);
    } else {
      await _secureStorage.write(key: _securePanicPin, value: pin);
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

  Future<void> clearAll() async {
    _focusModeExpiryTimer?.cancel();
    _focusModeUntilMs = null;
    await _prefs.clear();
    await _secureStorage.delete(key: _secureAppLockPin);
    await _secureStorage.delete(key: _securePanicPin);
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
    _fontSize = 1.0;
    _chatLabelSize = 1.0;
    _accentColorValue = 0xFF6D5DFC;
    _accentColorEnabled = true;
    _dockStyle = 'floating_pill';
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
    _focusModeExpiryTimer?.cancel();
    super.dispose();
  }

}
