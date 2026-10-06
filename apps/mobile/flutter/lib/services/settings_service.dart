import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  static const _kFontSize = 'font_size';
  static const _kTwoFactorAuth = 'two_factor_auth';
  static const _kLastSeen = 'last_seen_visibility';
  static const _kProfilePhoto = 'profile_photo_visibility';
  static const _kBlockedUids = 'blocked_uids';
  static const _kNotificationTone = 'notification_tone';
  static const _kCallRingtone = 'call_ringtone';
  static const _kVibrationPattern = 'vibration_pattern';
  static const _kHapticIntensity = 'haptic_intensity';
  static const _kAppLockEnabled = 'app_lock_enabled';
  static const _kAppLockTimeout = 'app_lock_timeout';
  static const _kAppLockPin = 'app_lock_pin';
  static const _kStealthMode = 'stealth_mode_enabled';
  static const _kPanicPin = 'panic_pin';
  static const _kHideNotificationContent = 'hide_notification_content';
  static const _kStealthIcon = 'stealth_icon_enabled';
  static const _kCustomNotificationPath = 'custom_notification_path';
  static const _kCustomRingtonePath = 'custom_ringtone_path';
  static const _kRegion = 'user_region';

  late SharedPreferences _prefs;
  bool _loaded = false;

  // ── Settings state ──────────────────────────────────────────────────────
  bool _notificationsOn = true;
  bool _messagePreview = true;
  bool _readReceipts = true;
  bool _onlineStatus = true;
  ThemeMode _themeMode = ThemeMode.system;
  String _displayName = '';
  String _bio = '';
  List<SavedSession> _savedSessions = [];
  
  // New settings state
  bool _inAppSounds = true;
  bool _inAppVibration = true;
  bool _groupNotifications = true;
  String _autoDownloadWifi = 'all'; // 'all', 'photos', 'none'
  String _autoDownloadMobile = 'photos'; // 'all', 'photos', 'none'
  String _photoQuality = 'high'; // 'high', 'medium', 'low'
  String _language = 'en'; // Language code
  double _fontSize = 1.0; // Font scale factor
  bool _twoFactorAuth = false;
  String _lastSeenVisibility = 'everyone'; // 'everyone', 'contacts', 'nobody'
  String _profilePhotoVisibility = 'everyone'; // 'everyone', 'contacts', 'nobody'
  List<String> _blockedUids = [];
  String _notificationTone = 'Aurora'; // Default tone
  String _callRingtone = 'Binary'; // Default ringtone
  String _vibrationPattern = 'standard'; // standard, staccato, heartbeat, none
  double _hapticIntensity = 0.8; // 0.0 to 1.0
  bool _appLockEnabled = false;
  int _appLockTimeout = 0; // minutes (0 = immediately)
  String? _appLockPin; // Stored PIN
  bool _isLocked = false; // Transient state
  String? _customNotificationPath;
  String? _customRingtonePath;
  String _region = 'India';
  bool _stealthModeEnabled = false;
  String? _panicPin;
  bool _hideNotificationContent = false;
  bool _decoyMode = false;
  bool _stealthIconEnabled = false;

  // ── Getters ─────────────────────────────────────────────────────────────
  bool get notificationsOn => _notificationsOn;
  bool get messagePreview => _messagePreview;
  bool get readReceipts => _readReceipts;
  bool get onlineStatus => _onlineStatus;
  ThemeMode get themeMode => _themeMode;
  String get displayName => _displayName;
  String get bio => _bio;
  bool get isLoaded => _loaded;
  List<SavedSession> get savedSessions => _savedSessions;
  
  // New getters
  bool get inAppSounds => _inAppSounds;
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
  String get vibrationPattern => _vibrationPattern;
  double get hapticIntensity => _hapticIntensity;
  String get photoQuality => _photoQuality;
  double get fontSize => _fontSize;
  bool get twoFactorAuth => _twoFactorAuth;
  String get lastSeenVisibility => _stealthModeEnabled ? 'Nobody' : _lastSeenVisibility;
  String get profilePhotoVisibility => _stealthModeEnabled ? 'Nobody' : _profilePhotoVisibility;
  List<String> get blockedUids => _blockedUids;
  bool get appLockEnabled => _appLockEnabled;
  int get appLockTimeout => _appLockTimeout;
  String? get appLockPin => _appLockPin;
  bool get isLocked => _isLocked;
  bool get stealthModeEnabled => _stealthModeEnabled;
  String? get panicPin => _panicPin;
  bool get hideNotificationContent => _hideNotificationContent;
  bool get decoyMode => _decoyMode;
  bool get stealthIconEnabled => _stealthIconEnabled;

  // ── Load from disk ───────────────────────────────────────────────────────
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _notificationsOn = _prefs.getBool(_kNotifications) ?? true;
    _messagePreview = _prefs.getBool(_kMessagePreview) ?? true;
    _readReceipts = _prefs.getBool(_kReadReceipts) ?? true;
    _onlineStatus = _prefs.getBool(_kOnlineStatus) ?? true;
    _themeMode = ThemeMode.values[_prefs.getInt(_kThemeMode) ?? 0];
    _displayName = _prefs.getString(_kDisplayName) ?? '';
    _bio = _prefs.getString(_kBio) ?? '';
    
    // Load new settings
    _inAppSounds = _prefs.getBool(_kInAppSounds) ?? true;
    _inAppVibration = _prefs.getBool(_kInAppVibration) ?? true;
    _groupNotifications = _prefs.getBool(_kGroupNotifications) ?? true;
    _autoDownloadWifi = _prefs.getString(_kAutoDownloadWifi) ?? 'all';
    _autoDownloadMobile = _prefs.getString(_kAutoDownloadMobile) ?? 'photos';
    _photoQuality = _prefs.getString(_kPhotoQuality) ?? 'high';
    _language = _prefs.getString(_kLanguage) ?? 'en';
    _fontSize = _prefs.getDouble(_kFontSize) ?? 1.0;
    _twoFactorAuth = _prefs.getBool(_kTwoFactorAuth) ?? false;
    _lastSeenVisibility = _prefs.getString(_kLastSeen) ?? 'everyone';
    _profilePhotoVisibility = _prefs.getString(_kProfilePhoto) ?? 'everyone';
    _blockedUids = _prefs.getStringList(_kBlockedUids) ?? [];
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
    _hapticIntensity = _prefs.getDouble(_kHapticIntensity) ?? 0.8;
    _appLockEnabled = _prefs.getBool(_kAppLockEnabled) ?? false;
    _appLockTimeout = _prefs.getInt(_kAppLockTimeout) ?? 0;
    _appLockPin = _prefs.getString(_kAppLockPin);
    _isLocked = _appLockEnabled && _appLockPin != null; // Initial state
    _stealthModeEnabled = _prefs.getBool(_kStealthMode) ?? false;
    _panicPin = _prefs.getString(_kPanicPin);
    _hideNotificationContent = _prefs.getBool(_kHideNotificationContent) ?? false;
    _stealthIconEnabled = _prefs.getBool(_kStealthIcon) ?? false;
    
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

  Future<void> setFontSize(double v) async {
    _fontSize = v;
    await _prefs.setDouble(_kFontSize, v);
    notifyListeners();
  }

  Future<void> setTwoFactorAuth(bool v) async {
    _twoFactorAuth = v;
    await _prefs.setBool(_kTwoFactorAuth, v);
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

  Future<void> setHapticIntensity(double v) async {
    _hapticIntensity = v;
    await _prefs.setDouble(_kHapticIntensity, v);
    notifyListeners();
  }

  Future<void> setAppLockEnabled(bool v) async {
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
    _appLockPin = pin;
    if (pin == null) {
      await _prefs.remove(_kAppLockPin);
    } else {
      await _prefs.setString(_kAppLockPin, pin);
    }
    notifyListeners();
  }

  void setLocked(bool v) {
    _isLocked = v;
    notifyListeners();
  }

  Future<void> setStealthMode(bool v) async {
    _stealthModeEnabled = v;
    await _prefs.setBool(_kStealthMode, v);
    notifyListeners();
  }

  Future<void> setPanicPin(String? pin) async {
    _panicPin = pin;
    if (pin == null) {
      await _prefs.remove(_kPanicPin);
    } else {
      await _prefs.setString(_kPanicPin, pin);
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
    await _prefs.clear();
    _notificationsOn = true;
    _messagePreview = true;
    _readReceipts = true;
    _onlineStatus = true;
    _themeMode = ThemeMode.system;
    _displayName = '';
    _bio = '';
    _savedSessions = [];
    
    // Reset new settings
    _inAppSounds = true;
    _inAppVibration = true;
    _groupNotifications = true;
    _autoDownloadWifi = 'all';
    _autoDownloadMobile = 'photos';
    _photoQuality = 'high';
    _language = 'en';
    _fontSize = 1.0;
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
}
