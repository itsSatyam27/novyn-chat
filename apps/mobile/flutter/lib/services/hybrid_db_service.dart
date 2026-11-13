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
      // Drift provides indexed ordering; Hive retains the complete Message model
      // (including attachments, polls, games and other optional payloads).
      final indexed = await _fastDb!.getMessages(chatId, limit: limit);
      final complete = await LocalDbService.getMessages(chatId, limit: limit);
      final merged = <String, Message>{
        for (final message in indexed) message.id: message,
        for (final message in complete) message.id: message,
      };
      final result = merged.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return result.length > limit
          ? result.sublist(result.length - limit)
          : result;
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
      final indexed = await _fastDb!.getOlderMessages(chatId, before, limit: limit);
      final complete = await LocalDbService.getOlderMessages(chatId, before, limit: limit);
      final merged = <String, Message>{
        for (final message in indexed) message.id: message,
        for (final message in complete) message.id: message,
      };
      final result = merged.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return result.length > limit
          ? result.sublist(result.length - limit)
          : result;
    } catch (e) {
      print('Error getting older messages: $e');
      return [];
    }
  }

  /// Save a single message - FAST with Drift
  static Future<void> saveMessage(Message message) async {
    await _ensureInit();
    try {
      await Future.wait([
        _fastDb!.saveMessage(message),
        LocalDbService.saveMessage(message),
      ]);
    } catch (e) {
      print('Error saving message: $e');
    }
  }

  /// Save multiple messages (bulk insert) - FAST with Drift
  static Future<void> saveMessages(List<Message> messages) async {
    await _ensureInit();
    try {
      await Future.wait([
        _fastDb!.saveMessages(messages),
        LocalDbService.saveMessages(messages),
      ]);
    } catch (e) {
      print('Error saving messages: $e');
    }
  }

  /// Update a message
  static Future<void> updateMessage(String messageId, Message updated) async {
    await _ensureInit();
    try {
      await Future.wait([
        _fastDb!.updateMessage(messageId, updated),
        LocalDbService.updateMessage(messageId, updated),
      ]);
    } catch (e) {
      print('Error updating message: $e');
    }
  }

  /// Delete a message
  static Future<void> deleteMessage(String messageId) async {
    await _ensureInit();
    try {
      await Future.wait([
        _fastDb!.deleteMessage(messageId),
        LocalDbService.deleteMessage(messageId),
      ]);
    } catch (e) {
      print('Error deleting message: $e');
    }
  }

  /// Get message count for a chat
  static Future<int> getMessageCount(String chatId) async {
    await _ensureInit();
    try {
      final driftCount = await _fastDb!.getMessageCount(chatId);
      final hiveCount = await LocalDbService.getMessageCount(chatId);
      return driftCount > hiveCount ? driftCount : hiveCount;
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
      final hiveChats = await LocalDbService.getChats();
      final merged = <String, Map<String, dynamic>>{
        for (final chat in driftChats)
          chat.chatId: {
            'chatId': chat.chatId,
            'peerUid': chat.peerUid,
            'lastMessage': chat.lastMessage,
            'lastTime': chat.lastTime.toIso8601String(),
            'unreadCount': chat.unreadCount,
            'isPinned': chat.isPinned,
            'isArchived': chat.isArchived,
          },
        for (final chat in hiveChats)
          chat['chatId']?.toString() ?? '': chat,
      }..remove('');
      final result = merged.values.toList()
        ..sort((a, b) {
          final aTime = DateTime.tryParse(a['lastTime']?.toString() ?? '') ?? DateTime(2000);
          final bTime = DateTime.tryParse(b['lastTime']?.toString() ?? '') ?? DateTime(2000);
          return bTime.compareTo(aTime);
        });
      return result;
    } catch (e) {
      print('Error getting chats: $e');
      return [];
    }
  }

  /// Save chat preview - FAST with Drift
  static Future<void> saveChat(ChatPreview chat) async {
    await _ensureInit();
    try {
      await Future.wait([
        _fastDb!.saveChat(
          chat.chatId,
          chat.peerUid,
          chat.lastMessage,
          chat.lastTime,
          chat.unreadCount,
          isPinned: chat.isPinned,
          isArchived: chat.isArchived,
        ),
        LocalDbService.saveChat(chat),
      ]);
    } catch (e) {
      print('Error saving chat: $e');
    }
  }

  /// Save multiple chats (bulk insert) - FAST with Drift
  static Future<void> saveChats(List<ChatPreview> chats) async {
    await _ensureInit();
    try {
      await Future.wait([
        Future.wait(chats.map((chat) => _fastDb!.saveChat(
          chat.chatId,
          chat.peerUid,
          chat.lastMessage,
          chat.lastTime,
          chat.unreadCount,
          isPinned: chat.isPinned,
          isArchived: chat.isArchived,
        ))),
        LocalDbService.saveChats(chats),
      ]);
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
      await Future.wait([
        _fastDb!.updateChat(
          chatId,
          lastMessage: lastMessage,
          lastTime: lastTime,
          unreadCount: unreadCount,
          isPinned: isPinned,
          isArchived: isArchived,
        ),
        LocalDbService.updateChat(
          chatId,
          lastMessage: lastMessage,
          lastTime: lastTime,
          unreadCount: unreadCount,
          isPinned: isPinned,
          isArchived: isArchived,
        ),
      ]);
    } catch (e) {
      print('Error updating chat: $e');
    }
  }

  /// Delete a chat
  static Future<void> deleteChat(String chatId) async {
    await _ensureInit();
    try {
      await Future.wait([
        _fastDb!.deleteChat(chatId),
        LocalDbService.deleteChat(chatId),
      ]);
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

  /// Switch to isolated local databases for the active Novyn account.
  /// Existing shared data is migrated only when its stored owner matches.
  static Future<void> activateAccount(String username) async {
    final normalized = username.trim().toLowerCase();
    if (normalized.isEmpty) return;

    await LocalDbService.init();
    final legacyOwner = await LocalDbService.getAccountScope();
    await LocalDbService.activateAccount(normalized);
    await FastDbService.activateAccount(
      normalized,
      migrateLegacy: legacyOwner != null &&
          legacyOwner.trim().toLowerCase() == normalized,
    );

    _fastDb = await FastDbService.database;
    _isInitialized = true;
    ChatsScreen.resetAccountCache();
  }

  static Future<void> clearAccountScope() async {
    await _ensureInit();
    await LocalDbService.clearAll();
  }

  /// Clear all data (logout)
  static Future<void> clearAll() async {
    await _ensureInit();
    try {
      await _fastDb!.clearAll();
      await LocalDbService.clearAll();
      ChatsScreen.resetAccountCache();
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
