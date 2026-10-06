import 'package:hive_flutter/hive_flutter.dart';
import '../models/chat_models.dart';
import '../models/user_model.dart';
import '../models/chat_preview.dart';
import '../screens/chats/chats_screen.dart';

/// Local database service using Hive for instant loads and offline support
class LocalDbService {
  static Box<Message>? _messagesBox;
  static Box? _chatsBox;
  static Box<UserModel>? _usersBox;
  static Box? _metaBox; // For metadata like last sync time

  static bool _isInitialized = false;

  /// Initialize all Hive boxes
  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Check if boxes are already open, if so just use them
      if (Hive.isBoxOpen('messages')) {
        _messagesBox = Hive.box<Message>('messages');
      } else {
        _messagesBox = await Hive.openBox<Message>('messages');
      }

      if (Hive.isBoxOpen('chats')) {
        _chatsBox = Hive.box('chats');
      } else {
        _chatsBox = await Hive.openBox('chats');
      }

      if (Hive.isBoxOpen('users')) {
        _usersBox = Hive.box<UserModel>('users');
      } else {
        _usersBox = await Hive.openBox<UserModel>('users');
      }

      if (Hive.isBoxOpen('metadata')) {
        _metaBox = Hive.box('metadata');
      } else {
        _metaBox = await Hive.openBox('metadata');
      }

      _isInitialized = true;
      print('✅ LocalDbService initialized');
    } catch (e) {
      print('❌ LocalDbService init error: $e');
      // Don't set _isInitialized to true on error
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MESSAGES
  // ══════════════════════════════════════════════════════════════════════════

  /// Save a single message to local DB
  static Future<void> saveMessage(Message message) async {
    await _ensureInit();
    try {
      await _messagesBox?.put(message.id, message);
    } catch (e) {
      print('Error saving message: $e');
    }
  }

  /// Save multiple messages (bulk insert)
  static Future<void> saveMessages(List<Message> messages) async {
    await _ensureInit();
    try {
      final map = {for (var m in messages) m.id: m};
      await _messagesBox?.putAll(map);
    } catch (e) {
      print('Error saving messages: $e');
    }
  }

  /// Get messages for a specific chat (sorted by time)
  static Future<List<Message>> getMessages(String chatId, {int limit = 50}) async {
    await _ensureInit();
    try {
      final all = _messagesBox?.values
          .where((m) => m.chatId == chatId)
          .toList() ?? [];
      
      // Sort by createdAt (oldest first)
      all.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      // Return last N messages
      if (all.length > limit) {
        return all.sublist(all.length - limit);
      }
      return all;
    } catch (e) {
      print('Error getting messages: $e');
      return [];
    }
  }

  /// Get older messages (pagination)
  static Future<List<Message>> getOlderMessages(
    String chatId,
    DateTime before,
    {int limit = 30}
  ) async {
    await _ensureInit();
    try {
      final all = _messagesBox?.values
          .where((m) => m.chatId == chatId && m.createdAt.isBefore(before))
          .toList() ?? [];
      
      // Sort by createdAt (oldest first)
      all.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      // Return last N messages
      if (all.length > limit) {
        return all.sublist(all.length - limit);
      }
      return all;
    } catch (e) {
      print('Error getting older messages: $e');
      return [];
    }
  }

  /// Update a message (for edits, reactions, etc.)
  static Future<void> updateMessage(String messageId, Message updated) async {
    await _ensureInit();
    try {
      await _messagesBox?.put(messageId, updated);
    } catch (e) {
      print('Error updating message: $e');
    }
  }

  /// Delete a message
  static Future<void> deleteMessage(String messageId) async {
    await _ensureInit();
    try {
      await _messagesBox?.delete(messageId);
    } catch (e) {
      print('Error deleting message: $e');
    }
  }

  /// Get message count for a chat
  static Future<int> getMessageCount(String chatId) async {
    await _ensureInit();
    try {
      return _messagesBox?.values
          .where((m) => m.chatId == chatId)
          .length ?? 0;
    } catch (e) {
      print('Error getting message count: $e');
      return 0;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CHATS
  // ══════════════════════════════════════════════════════════════════════════

  /// Save chat preview
  static Future<void> saveChat(ChatPreview chat) async {
    await _ensureInit();
    try {
      await _chatsBox?.put(chat.chatId, {
        'chatId': chat.chatId,
        'peerUid': chat.peerUid,
        'lastMessage': chat.lastMessage,
        'lastTime': chat.lastTime.toIso8601String(),
        'unreadCount': chat.unreadCount,
      });
    } catch (e) {
      print('Error saving chat: $e');
    }
  }

  /// Save multiple chats (bulk insert)
  static Future<void> saveChats(List<ChatPreview> chats) async {
    await _ensureInit();
    try {
      final map = {
        for (var c in chats) c.chatId: {
          'chatId': c.chatId,
          'peerUid': c.peerUid,
          'lastMessage': c.lastMessage,
          'lastTime': c.lastTime.toIso8601String(),
          'unreadCount': c.unreadCount,
        }
      };
      await _chatsBox?.putAll(map);
    } catch (e) {
      print('Error saving chats: $e');
    }
  }

  /// Get all chats (returns raw data, needs user profiles)
  static Future<List<Map<String, dynamic>>> getChats() async {
    await _ensureInit();
    try {
      final chats = _chatsBox?.values
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList() ?? [];
      
      // Sort by lastTime (newest first)
      chats.sort((a, b) {
        final aTime = DateTime.tryParse(a['lastTime'] ?? '') ?? DateTime(2000);
        final bTime = DateTime.tryParse(b['lastTime'] ?? '') ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });
      
      return chats;
    } catch (e) {
      print('Error getting chats: $e');
      return [];
    }
  }

  /// Update chat preview (last message, unread count)
  static Future<void> updateChat(String chatId, {
    String? lastMessage,
    DateTime? lastTime,
    int? unreadCount,
  }) async {
    await _ensureInit();
    try {
      final existing = _chatsBox?.get(chatId);
      if (existing != null) {
        final updated = Map<String, dynamic>.from(existing as Map);
        if (lastMessage != null) updated['lastMessage'] = lastMessage;
        if (lastTime != null) updated['lastTime'] = lastTime.toIso8601String();
        if (unreadCount != null) updated['unreadCount'] = unreadCount;
        await _chatsBox?.put(chatId, updated);
      }
    } catch (e) {
      print('Error updating chat: $e');
    }
  }

  /// Delete a chat
  static Future<void> deleteChat(String chatId) async {
    await _ensureInit();
    try {
      await _chatsBox?.delete(chatId);
      // Also delete all messages in this chat
      final messages = await getMessages(chatId);
      for (final msg in messages) {
        await deleteMessage(msg.id);
      }
    } catch (e) {
      print('Error deleting chat: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // USERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Save user profile
  static Future<void> saveUser(UserModel user) async {
    await _ensureInit();
    try {
      await _usersBox?.put(user.uid, user);
    } catch (e) {
      print('Error saving user: $e');
    }
  }

  /// Save multiple users (bulk insert)
  static Future<void> saveUsers(List<UserModel> users) async {
    await _ensureInit();
    try {
      final map = {for (var u in users) u.uid: u};
      await _usersBox?.putAll(map);
    } catch (e) {
      print('Error saving users: $e');
    }
  }

  /// Get user by UID
  static Future<UserModel?> getUser(String uid) async {
    await _ensureInit();
    try {
      return _usersBox?.get(uid);
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  /// Get multiple users by UIDs
  static Future<Map<String, UserModel>> getUsers(List<String> uids) async {
    await _ensureInit();
    try {
      final result = <String, UserModel>{};
      for (final uid in uids) {
        final user = _usersBox?.get(uid);
        if (user != null) result[uid] = user;
      }
      return result;
    } catch (e) {
      print('Error getting users: $e');
      return {};
    }
  }

  /// Update user online status
  static Future<void> updateUserStatus(String uid, bool isOnline) async {
    await _ensureInit();
    try {
      final user = _usersBox?.get(uid);
      if (user != null) {
        final updated = user.copyWith(isOnline: isOnline);
        await _usersBox?.put(uid, updated);
      }
    } catch (e) {
      print('Error updating user status: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // METADATA
  // ══════════════════════════════════════════════════════════════════════════

  /// Set last sync time for a chat
  static Future<void> setLastSync(String chatId, DateTime time) async {
    await _ensureInit();
    try {
      await _metaBox?.put('sync_$chatId', time.toIso8601String());
    } catch (e) {
      print('Error setting last sync: $e');
    }
  }

  /// Get last sync time for a chat
  static Future<DateTime?> getLastSync(String chatId) async {
    await _ensureInit();
    try {
      final str = _metaBox?.get('sync_$chatId');
      return str != null ? DateTime.tryParse(str) : null;
    } catch (e) {
      print('Error getting last sync: $e');
      return null;
    }
  }

  /// Set app-wide last sync time
  static Future<void> setGlobalLastSync(DateTime time) async {
    await _ensureInit();
    try {
      await _metaBox?.put('global_sync', time.toIso8601String());
    } catch (e) {
      print('Error setting global sync: $e');
    }
  }

  /// Get app-wide last sync time
  static Future<DateTime?> getGlobalLastSync() async {
    await _ensureInit();
    try {
      final str = _metaBox?.get('global_sync');
      return str != null ? DateTime.tryParse(str) : null;
    } catch (e) {
      print('Error getting global sync: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ══════════════════════════════════════════════════════════════════════════

  /// Clear all data (logout)
  static Future<void> clearAll() async {
    await _ensureInit();
    try {
      await _messagesBox?.clear();
      await _chatsBox?.clear();
      await _usersBox?.clear();
      await _metaBox?.clear();
      print('✅ Local database cleared');
    } catch (e) {
      print('Error clearing database: $e');
    }
  }

  /// Get database stats
  static Future<Map<String, int>> getStats() async {
    await _ensureInit();
    return {
      'messages': _messagesBox?.length ?? 0,
      'chats': _chatsBox?.length ?? 0,
      'users': _usersBox?.length ?? 0,
    };
  }

  /// Ensure initialization
  static Future<void> _ensureInit() async {
    if (!_isInitialized) {
      await init();
    }
  }

  /// Close all boxes (call on app dispose)
  static Future<void> close() async {
    await _messagesBox?.close();
    await _chatsBox?.close();
    await _usersBox?.close();
    await _metaBox?.close();
    _isInitialized = false;
  }
}
