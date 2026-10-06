import 'package:hive_flutter/hive_flutter.dart';

/// Service for saving and loading draft messages
class DraftService {
  static Box? _draftsBox;

  /// Initialize drafts box
  static Future<void> init() async {
    if (_draftsBox == null || !_draftsBox!.isOpen) {
      _draftsBox = await Hive.openBox('drafts');
    }
  }

  /// Save draft for a chat
  static Future<void> saveDraft(String chatId, String text) async {
    await init();
    if (text.trim().isEmpty) {
      // Delete draft if empty
      await _draftsBox?.delete(chatId);
    } else {
      await _draftsBox?.put(chatId, {
        'text': text,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Get draft for a chat
  static Future<String?> getDraft(String chatId) async {
    await init();
    final draft = _draftsBox?.get(chatId);
    if (draft != null && draft is Map) {
      return draft['text'] as String?;
    }
    return null;
  }

  /// Delete draft for a chat
  static Future<void> deleteDraft(String chatId) async {
    await init();
    await _draftsBox?.delete(chatId);
  }

  /// Get all drafts (for showing in chat list)
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
    
    return result;
  }

  /// Clear all drafts
  static Future<void> clearAll() async {
    await init();
    await _draftsBox?.clear();
  }

  /// Close box
  static Future<void> close() async {
    await _draftsBox?.close();
  }
}
