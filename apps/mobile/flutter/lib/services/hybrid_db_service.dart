import 'package:novyn/services/fast_db_service.dart';
import 'package:novyn/services/local_db_service.dart';
import '../models/chat_models.dart';
import '../models/chat_preview.dart';
import '../models/user_model.dart';
import '../screens/chats/chats_screen.dart';

/// Hybrid database service that uses:
/// - Drift (SQLite) for fast indexed queries (messages, chats)
/// - Hive for simple key-value storage (users, metadata)
/// 
/// This gives us the best of both worlds:
/// - 3-5x faster queries with Drift indexes
/// - Simple API with Hive for non-query data
class HybridDbService {
  static FastDatabase? _fastDb;
  static bool _isInitialized = false;

  /// Initialize both databases
  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Initialize Hive (for users, metadata)
      await LocalDbService.init();
      
      // Initialize Drift (for messages, chats)
      _fastDb = await FastDbService.database;
      
      _isInitialized = true;
      print('✅ HybridDbService initialized (Drift + Hive)');
    } catch (e) {
      print('❌ HybridDbService init error: $e');
      // Don't set _isInitialized to true on error
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MESSAGES (using Drift for fast indexed queries)
  // ══════════════════════════════════════════════════════════════════════════

  /// Get messages for a chat - FAST with Drift indexes
  static Future<List<Message>> getMessages(String chatId, {int limit = 50}) async {
    await _ensureInit();
    try {
      // FastDbService already returns models.Message (converted in fast_db_service.dart)
      return await _fastDb!.getMessages(chatId, limit: limit);
    } catch (e) {
      print('Error getting messages: $e');
      return [];
    }
  }

  /// Get older messages (pagination) - FAST with Drift indexes
  static Future<List<Message>> getOlderMessages(
    String chatId,
    DateTime before,
    {int limit = 30}
  ) async {
    await _ensureInit();
    try {
      // FastDbService already returns models.Message (converted in fast_db_service.dart)
      return await _fastDb!.getOlderMessages(chatId, before, limit: limit);
    } catch (e) {
      print('Error getting older messages: $e');
      return [];
    }
  }

  /// Save a single message - FAST with Drift
  static Future<void> saveMessage(Message message) async {
    await _ensureInit();
    try {
      await _fastDb!.saveMessage(message);
    } catch (e) {
      print('Error saving message: $e');
    }
  }

  /// Save multiple messages (bulk insert) - FAST with Drift
  static Future<void> saveMessages(List<Message> messages) async {
    await _ensureInit();
    try {
      await _fastDb!.saveMessages(messages);
    } catch (e) {
      print('Error saving messages: $e');
    }
  }

  /// Update a message
  static Future<void> updateMessage(String messageId, Message updated) async {
    await _ensureInit();
    try {
      await _fastDb!.updateMessage(messageId, updated);
    } catch (e) {
      print('Error updating message: $e');
    }
  }

  /// Delete a message
  static Future<void> deleteMessage(String messageId) async {
    await _ensureInit();
    try {
      await _fastDb!.deleteMessage(messageId);
    } catch (e) {
      print('Error deleting message: $e');
    }
  }

  /// Get message count for a chat
  static Future<int> getMessageCount(String chatId) async {
    await _ensureInit();
    try {
      return await _fastDb!.getMessageCount(chatId);
    } catch (e) {
      print('Error getting message count: $e');
      return 0;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CHATS (using Drift for fast indexed queries)
  // ══════════════════════════════════════════════════════════════════════════

  /// Get all chats - FAST with Drift indexes
  static Future<List<Map<String, dynamic>>> getChats() async {
    await _ensureInit();
    try {
      final driftChats = await _fastDb!.getChats();
      
      // Convert Drift Chat to map format
      return driftChats.map((dc) => {
        'chatId': dc.chatId,
        'peerUid': dc.peerUid,
        'lastMessage': dc.lastMessage,
        'lastTime': dc.lastTime.toIso8601String(),
        'unreadCount': dc.unreadCount,
        'isPinned': dc.isPinned,
        'isArchived': dc.isArchived,
      }).toList();
    } catch (e) {
      print('Error getting chats: $e');
      return [];
    }
  }

  /// Save chat preview - FAST with Drift
  static Future<void> saveChat(ChatPreview chat) async {
    await _ensureInit();
    try {
      await _fastDb!.saveChat(
        chat.chatId,
        chat.peerUid,
        chat.lastMessage,
        chat.lastTime,
        chat.unreadCount,
        isPinned: chat.isPinned,
        isArchived: chat.isArchived,
      );
    } catch (e) {
      print('Error saving chat: $e');
    }
  }

  /// Save multiple chats (bulk insert) - FAST with Drift
  static Future<void> saveChats(List<ChatPreview> chats) async {
    await _ensureInit();
    try {
      for (final chat in chats) {
        await _fastDb!.saveChat(
          chat.chatId,
          chat.peerUid,
          chat.lastMessage,
          chat.lastTime,
          chat.unreadCount,
          isPinned: chat.isPinned,
          isArchived: chat.isArchived,
        );
      }
    } catch (e) {
      print('Error saving chats: $e');
    }
  }

  /// Update chat preview
  static Future<void> updateChat(String chatId, {
    String? lastMessage,
    DateTime? lastTime,
    int? unreadCount,
    bool? isPinned,
    bool? isArchived,
  }) async {
    await _ensureInit();
    try {
      await _fastDb!.updateChat(
        chatId,
        lastMessage: lastMessage,
        lastTime: lastTime,
        unreadCount: unreadCount,
        isPinned: isPinned,
        isArchived: isArchived,
      );
    } catch (e) {
      print('Error updating chat: $e');
    }
  }

  /// Delete a chat
  static Future<void> deleteChat(String chatId) async {
    await _ensureInit();
    try {
      await _fastDb!.deleteChat(chatId);
    } catch (e) {
      print('Error deleting chat: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // USERS (using Hive for simple key-value storage)
  // ══════════════════════════════════════════════════════════════════════════

  /// Save user profile (Hive)
  static Future<void> saveUser(UserModel user) async {
    await _ensureInit();
    await LocalDbService.saveUser(user);
  }

  /// Save multiple users (Hive)
  static Future<void> saveUsers(List<UserModel> users) async {
    await _ensureInit();
    await LocalDbService.saveUsers(users);
  }

  /// Get user by UID (Hive)
  static Future<UserModel?> getUser(String uid) async {
    await _ensureInit();
    return await LocalDbService.getUser(uid);
  }

  /// Get multiple users by UIDs (Hive)
  static Future<Map<String, UserModel>> getUsers(List<String> uids) async {
    await _ensureInit();
    return await LocalDbService.getUsers(uids);
  }

  /// Update user online status (Hive)
  static Future<void> updateUserStatus(String uid, bool isOnline) async {
    await _ensureInit();
    await LocalDbService.updateUserStatus(uid, isOnline);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // METADATA (using Hive for simple key-value storage)
  // ══════════════════════════════════════════════════════════════════════════

  /// Set last sync time for a chat (Hive)
  static Future<void> setLastSync(String chatId, DateTime time) async {
    await _ensureInit();
    await LocalDbService.setLastSync(chatId, time);
  }

  /// Get last sync time for a chat (Hive)
  static Future<DateTime?> getLastSync(String chatId) async {
    await _ensureInit();
    return await LocalDbService.getLastSync(chatId);
  }

  /// Set app-wide last sync time (Hive)
  static Future<void> setGlobalLastSync(DateTime time) async {
    await _ensureInit();
    await LocalDbService.setGlobalLastSync(time);
  }

  /// Get app-wide last sync time (Hive)
  static Future<DateTime?> getGlobalLastSync() async {
    await _ensureInit();
    return await LocalDbService.getGlobalLastSync();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ══════════════════════════════════════════════════════════════════════════

  /// Clear all data (logout)
  static Future<void> clearAll() async {
    await _ensureInit();
    try {
      await _fastDb!.clearAll();
      await LocalDbService.clearAll();
      print('✅ Hybrid database cleared');
    } catch (e) {
      print('Error clearing database: $e');
    }
  }

  /// Get database stats
  static Future<Map<String, int>> getStats() async {
    await _ensureInit();
    try {
      final driftStats = await _fastDb!.getStats();
      final hiveStats = await LocalDbService.getStats();
      
      return {
        'messages': driftStats['messages'] ?? 0,
        'chats': driftStats['chats'] ?? 0,
        'users': hiveStats['users'] ?? 0,
      };
    } catch (e) {
      print('Error getting stats: $e');
      return {'messages': 0, 'chats': 0, 'users': 0};
    }
  }

  /// Ensure initialization
  static Future<void> _ensureInit() async {
    if (!_isInitialized) {
      await init();
    }
  }

  /// Close all databases
  static Future<void> close() async {
    await FastDbService.close();
    await LocalDbService.close();
    _isInitialized = false;
  }
}
