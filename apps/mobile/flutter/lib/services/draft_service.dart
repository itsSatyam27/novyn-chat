import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

/// Debounced local draft persistence. Avoids a Hive write for every keystroke.
class DraftService {
  static Box? _draftsBox;
  static Future<Box>? _openingBox;
  static final Map<String, String> _pendingDrafts = {};
  static final Map<String, Timer> _draftTimers = {};

  static Future<void> init() async {
    if (_draftsBox?.isOpen == true) return;
    _openingBox ??= Hive.openBox('drafts');
    try {
      _draftsBox = await _openingBox!;
    } finally {
      _openingBox = null;
    }
  }

  static Future<void> _flushDraft(String chatId) async {
    _draftTimers.remove(chatId)?.cancel();
    if (!_pendingDrafts.containsKey(chatId)) return;
    final text = _pendingDrafts.remove(chatId)!;
    await init();
    if (text.trim().isEmpty) {
      await _draftsBox?.delete(chatId);
    } else {
      await _draftsBox?.put(chatId, {
        'text': text,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Schedule one write after typing pauses instead of writing on every key.
  static Future<void> saveDraft(String chatId, String text) async {
    _pendingDrafts[chatId] = text;
    _draftTimers.remove(chatId)?.cancel();
    _draftTimers[chatId] = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_flushDraft(chatId)),
    );
  }

  static Future<String?> getDraft(String chatId) async {
    await init();
    if (_pendingDrafts.containsKey(chatId)) return _pendingDrafts[chatId];
    final draft = _draftsBox?.get(chatId);
    if (draft != null && draft is Map) {
      return draft['text'] as String?;
    }
    return null;
  }

  /// Cancel any queued save before deleting, so an old draft cannot reappear.
  static Future<void> deleteDraft(String chatId) async {
    _draftTimers.remove(chatId)?.cancel();
    _pendingDrafts.remove(chatId);
    await init();
    await _draftsBox?.delete(chatId);
  }

  static Future<Map<String, String>> getAllDrafts() async {
    await init();
    final result = <String, String>{};
    final keys = _draftsBox?.keys ?? [];
    for (final key in keys) {
      final draft = _draftsBox?.get(key);
      if (draft != null && draft is Map) {
        result[key.toString()] = draft['text'] as String? ?? '';
      }
    }
    for (final entry in _pendingDrafts.entries) {
      if (entry.value.trim().isNotEmpty) {
        result[entry.key] = entry.value;
      } else {
        result.remove(entry.key);
      }
    }
    return result;
  }

  static Future<void> clearAll() async {
    for (final timer in _draftTimers.values) {
      timer.cancel();
    }
    _draftTimers.clear();
    _pendingDrafts.clear();
    await init();
    await _draftsBox?.clear();
  }

  static Future<void> close() async {
    for (final timer in _draftTimers.values) {
      timer.cancel();
    }
    _draftTimers.clear();
    final chatIds = _pendingDrafts.keys.toList();
    for (final chatId in chatIds) {
      await _flushDraft(chatId);
    }
    await _draftsBox?.close();
    _draftsBox = null;
  }
}
