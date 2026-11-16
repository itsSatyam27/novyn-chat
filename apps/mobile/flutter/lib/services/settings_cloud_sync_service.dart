import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'settings_service.dart';

/// Keeps account-level preferences in sync through the authenticated Novyn
/// API and Firestore. Local settings remain the source of immediate UI state;
/// cloud reads/writes are always performed in the background.
class SettingsCloudSyncService {
  SettingsCloudSyncService(this._settings);

  final SettingsService _settings;

  static const Duration _debounceDuration = Duration(milliseconds: 650);
  static const Duration _pollInterval = Duration(seconds: 6);

  String? _accountKey;
  Timer? _debounce;
  Timer? _poll;
  bool _isApplyingRemote = false;
  bool _syncReady = false;
  bool _requestInFlight = false;
  int _generation = 0;
  int _localRevision = 0;
  bool _localChangedBeforeInitialSync = false;
  int _lastLocalEditAt = 0;
  int _lastRemoteUpdatedAt = 0;
  Map<String, dynamic> _lastSyncedSnapshot = {};

  bool get isActive => _accountKey != null;

  Future<void> startForAccount(String username) async {
    final normalized = username.trim().toLowerCase();
    if (normalized.isEmpty || normalized == _accountKey) return;

    stop();
    _accountKey = normalized;
    final generation = ++_generation;
    _localRevision = 0;
    _localChangedBeforeInitialSync = false;
    _lastLocalEditAt = 0;
    _lastRemoteUpdatedAt = 0;
    _lastSyncedSnapshot = {};
    _syncReady = false;
    _settings.addListener(_onLocalSettingsChanged);

    unawaited(_initialSync(generation));
    _poll = Timer.periodic(_pollInterval, (_) {
      unawaited(_pollRemote(generation));
    });
  }

  void stop() {
    _generation++;
    _debounce?.cancel();
    _poll?.cancel();
    _debounce = null;
    _poll = null;
    if (_accountKey != null) {
      _settings.removeListener(_onLocalSettingsChanged);
    }
    _accountKey = null;
    _syncReady = false;
    _requestInFlight = false;
    _isApplyingRemote = false;
    _localRevision = 0;
    _localChangedBeforeInitialSync = false;
    _lastLocalEditAt = 0;
    _lastRemoteUpdatedAt = 0;
    _lastSyncedSnapshot = {};
  }

  void _onLocalSettingsChanged() {
    if (_accountKey == null || _isApplyingRemote) return;
    _localRevision++;
    if (!_syncReady) _localChangedBeforeInitialSync = true;
    _lastLocalEditAt = DateTime.now().millisecondsSinceEpoch;
    if (_syncReady) _scheduleSave();
  }

  Future<void> _initialSync(int generation) async {
    if (_requestInFlight || !_isCurrent(generation)) return;
    _requestInFlight = true;
    final revisionAtStart = _localRevision;
    try {
      final response = await ApiService.getAccountSettings();
      if (!_isCurrent(generation) || response == null) return;

      final remoteSettings = response['settings'];
      final settingsMap = remoteSettings is Map
          ? Map<String, dynamic>.from(remoteSettings)
          : <String, dynamic>{};
      final updatedAt = _asTimestamp(response['updatedAt']);

      // A user change made while the initial cloud read was in flight wins
      // locally and is uploaded after the read completes.
      if (_localChangedBeforeInitialSync || _localRevision != revisionAtStart) {
        _syncReady = true;
        _scheduleSave();
        return;
      }

      if (response['exists'] == true && settingsMap.isNotEmpty) {
        await _applyRemote(settingsMap, updatedAt, generation);
      } else {
        _syncReady = true;
        _scheduleSave();
      }
    } catch (error) {
      debugPrint('[NovynSettingsSync] Initial sync deferred: $error');
    } finally {
      if (_isCurrent(generation)) _requestInFlight = false;
    }
  }

  Future<void> _pollRemote(int generation) async {
    if (!_isCurrent(generation) || _requestInFlight) return;
    if (!_syncReady) {
      await _initialSync(generation);
      return;
    }

    _requestInFlight = true;
    try {
      final response = await ApiService.getAccountSettings();
      if (!_isCurrent(generation) || response == null) return;
      if (response['exists'] != true) return;

      final updatedAt = _asTimestamp(response['updatedAt']);
      if (updatedAt <= _lastRemoteUpdatedAt) return;

      // Do not replace an unsaved local edit with an older cloud snapshot.
      if (_lastLocalEditAt > updatedAt) {
        _scheduleSave();
        return;
      }

      final remoteSettings = response['settings'];
      if (remoteSettings is! Map || remoteSettings.isEmpty) return;
      await _applyRemote(
        Map<String, dynamic>.from(remoteSettings),
        updatedAt,
        generation,
      );
    } catch (error) {
      debugPrint('[NovynSettingsSync] Remote refresh deferred: $error');
    } finally {
      if (_isCurrent(generation)) _requestInFlight = false;
    }
  }

  Future<void> _applyRemote(
    Map<String, dynamic> values,
    int updatedAt,
    int generation,
  ) async {
    if (!_isCurrent(generation)) return;
    _isApplyingRemote = true;
    try {
      await _settings.applyCloudSyncSnapshot(
        values,
        accountKey: _accountKey,
      );
      _lastRemoteUpdatedAt = updatedAt;
      _lastSyncedSnapshot = Map<String, dynamic>.from(values);
      _lastLocalEditAt = 0;
      _syncReady = true;
      final current = _settings.cloudSyncSnapshot(accountKey: _accountKey);
      if (current.keys.any((key) => !_lastSyncedSnapshot.containsKey(key))) {
        _scheduleSave();
      }
    } finally {
      _isApplyingRemote = false;
    }
  }

  void _scheduleSave() {
    if (!_syncReady || _accountKey == null) return;
    _debounce?.cancel();
    final generation = _generation;
    _debounce = Timer(_debounceDuration, () {
      unawaited(_saveSnapshot(generation));
    });
  }

  Future<void> _saveSnapshot(int generation) async {
    if (!_isCurrent(generation) || !_syncReady || _requestInFlight) return;
    _debounce?.cancel();
    _debounce = null;
    _requestInFlight = true;
    final revisionAtStart = _localRevision;
    try {
      final snapshot = _settings.cloudSyncSnapshot(accountKey: _accountKey);
      final patch = <String, dynamic>{
        for (final entry in snapshot.entries)
          if (!_lastSyncedSnapshot.containsKey(entry.key) ||
              !_sameValue(_lastSyncedSnapshot[entry.key], entry.value))
            entry.key: entry.value,
      };
      if (patch.isEmpty) {
        _lastLocalEditAt = 0;
        return;
      }
      final response = await ApiService.saveAccountSettings(patch);
      if (!_isCurrent(generation)) return;
      if (response == null) {
        // Keep the local change and retry on the next short poll interval.
        _debounce?.cancel();
        _debounce = Timer(const Duration(seconds: 4), () {
          unawaited(_saveSnapshot(generation));
        });
        return;
      }
      _lastRemoteUpdatedAt = _asTimestamp(response['updatedAt']);
      _lastSyncedSnapshot = {..._lastSyncedSnapshot, ...patch};
      _lastLocalEditAt = _lastRemoteUpdatedAt;
      if (_localRevision != revisionAtStart) _scheduleSave();
    } catch (error) {
      debugPrint('[NovynSettingsSync] Cloud save deferred: $error');
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 4), () {
        unawaited(_saveSnapshot(generation));
      });
    } finally {
      if (_isCurrent(generation)) _requestInFlight = false;
    }
  }

  bool _sameValue(dynamic left, dynamic right) {
    if (left is List && right is List) return listEquals(left, right);
    return left == right;
  }

  int _asTimestamp(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  bool _isCurrent(int generation) =>
      _accountKey != null && generation == _generation;

  void dispose() {
    stop();
  }
}
