import 'dart:convert';
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
  static String _accountSuffix = '';

  static String _boxName(String base) =>
      _accountSuffix.isEmpty ? base : '${base}_$_accountSuffix';

  /// Initialize all Hive boxes
  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Check if boxes are already open, if so just use them
      if (Hive.isBoxOpen(_boxName('messages'))) {
        _messagesBox = Hive.box<Message>(_boxName('messages'));
      } else {
        _messagesBox = await Hive.openBox<Message>(_boxName('messages'));
      }

      if (Hive.isBoxOpen(_boxName('chats'))) {
        _chatsBox = Hive.box(_boxName('chats'));
      } else {
        _chatsBox = await Hive.openBox(_boxName('chats'));
      }

      if (Hive.isBoxOpen(_boxName('users'))) {
        _usersBox = Hive.box<UserModel>(_boxName('users'));
      } else {
        _usersBox = await Hive.openBox<UserModel>(_boxName('users'));
      }

      if (Hive.isBoxOpen(_boxName('metadata'))) {
        _metaBox = Hive.box(_boxName('metadata'));
      } else {
        _metaBox = await Hive.openBox(_boxName('metadata'));
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
        'isPinned': chat.isPinned,
        'isArchived': chat.isArchived,
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
          'isPinned': c.isPinned,
          'isArchived': c.isArchived,
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
    bool? isPinned,
    bool? isArchived,
  }) async {
    await _ensureInit();
    try {
      final existing = _chatsBox?.get(chatId);
      if (existing != null) {
        final updated = Map<String, dynamic>.from(existing as Map);
        if (lastMessage != null) updated['lastMessage'] = lastMessage;
        if (lastTime != null) updated['lastTime'] = lastTime.toIso8601String();
        if (unreadCount != null) updated['unreadCount'] = unreadCount;
        if (isPinned != null) updated['isPinned'] = isPinned;
        if (isArchived != null) updated['isArchived'] = isArchived;
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

  /// Switch Hive storage to an isolated namespace for one Novyn account.
  /// The legacy shared boxes are copied only when their recorded owner matches.
  static Future<void> activateAccount(String username) async {
    final normalized = username.trim().toLowerCase();
    if (normalized.isEmpty) return;
    await init();
    final currentOwner = _metaBox?.get('account_scope')?.toString();
    final suffix = base64Url.encode(utf8.encode(normalized)).replaceAll('=', '');
    if (_accountSuffix == suffix) {
      await _metaBox?.put('account_scope', normalized);
      return;
    }

    final oldMessages = _messagesBox?.values.toList() ?? <Message>[];
    final oldChats = _chatsBox?.toMap() ?? <dynamic, dynamic>{};
    final oldUsers = _usersBox?.toMap() ?? <dynamic, dynamic>{};
    final oldMeta = _metaBox?.toMap() ?? <dynamic, dynamic>{};

    await close();
    _accountSuffix = suffix;
    await init();

    // Preserve the existing cache only for the account that owned it.
    // Never guess the owner of an unscoped legacy cache.
    if (currentOwner != null &&
        currentOwner.trim().toLowerCase() == normalized) {
      if ((_messagesBox?.isEmpty ?? true) && oldMessages.isNotEmpty) {
        await _messagesBox?.putAll({
          for (final message in oldMessages) message.id: message,
        });
      }
      if ((_chatsBox?.isEmpty ?? true) && oldChats.isNotEmpty) {
        await _chatsBox?.putAll(oldChats);
      }
      if ((_usersBox?.isEmpty ?? true) && oldUsers.isNotEmpty) {
        await _usersBox?.putAll(oldUsers.cast<dynamic, UserModel>());
      }
      if ((_metaBox?.isEmpty ?? true) && oldMeta.isNotEmpty) {
        await _metaBox?.putAll(oldMeta);
      }
    }
    await _metaBox?.put('account_scope', normalized);
  }

  /// Account owner for the active isolated local cache.
  static Future<String?> getAccountScope() async {
    await _ensureInit();
    return _metaBox?.get('account_scope')?.toString();
  }

  static Future<void> setAccountScope(String username) async {
    await _ensureInit();
    await _metaBox?.put('account_scope', username.trim().toLowerCase());
  }

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

  /// Export only the active account's local chat cache for a user-controlled backup.
  static Future<Map<String, dynamic>> exportChatBackupData() async {
    await _ensureInit();
    final owner = await getAccountScope();
    if (owner == null || owner.isEmpty) {
      throw StateError('No active account is associated with this local chat data.');
    }
    return {
      'username': owner,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'messages': (_messagesBox?.values ?? <Message>[]).map((m) => {
        'id': m.id, 'text': m.text, 'time': m.time, 'isFromMe': m.isFromMe,
        'chatId': m.chatId, 'senderId': m.senderId,
        'createdAt': m.createdAt.toIso8601String(), 'reactions': m.reactions,
        'replyToId': m.replyToId, 'replyToText': m.replyToText,
        'replyToSender': m.replyToSender, 'edited': m.edited,
        'isEncrypted': m.isEncrypted, 'ciphertext': m.ciphertext, 'iv': m.iv,
        'attachment': m.attachment, 'poll': m.poll, 'pinnedAt': m.pinnedAt,
        'pinnedBy': m.pinnedBy, 'riddle': m.riddle, 'game': m.game,
      }).toList(),
      'chats': (_chatsBox?.toMap() ?? {}).entries.map((e) => {
        'key': e.key.toString(), 'value': Map<String, dynamic>.from(e.value as Map),
      }).toList(),
      'users': (_usersBox?.toMap() ?? {}).entries.map((e) {
        final u = e.value as UserModel;
        return {
          'uid': u.uid, 'name': u.name, 'username': u.username, 'email': u.email,
          'bio': u.bio, 'age': u.age, 'gender': u.gender,
          'createdAt': u.createdAt.toIso8601String(), 'isOnline': u.isOnline,
          'lastSeen': u.lastSeen?.toIso8601String(), 'status': u.status,
          'photoUrl': u.photoUrl, 'lastSeenVisibility': u.lastSeenVisibility,
          'profilePhotoVisibility': u.profilePhotoVisibility, 'readReceipts': u.readReceipts,
        };
      }).toList(),
    };
  }

  /// Merge a validated backup into the active account without deleting newer local data.
  static Future<Map<String, int>> restoreChatBackupData(Map<String, dynamic> data, String activeUsername) async {
    await _ensureInit();
    final backupOwner = data['username']?.toString().trim().toLowerCase();
    final activeOwner = activeUsername.trim().toLowerCase();
    if (backupOwner == null || backupOwner.isEmpty || backupOwner != activeOwner ||
        await getAccountScope() != activeOwner) {
      throw const FormatException('This backup belongs to a different Novyn account.');
    }
    final rawMessages = data['messages'];
    final rawChats = data['chats'];
    final rawUsers = data['users'];
    if (rawMessages is! List || rawChats is! List || rawUsers is! List ||
        rawMessages.length > 200000 || rawChats.length > 20000 || rawUsers.length > 20000) {
      throw const FormatException('The backup file is invalid or too large.');
    }
    final messages = <String, Message>{};
    for (final raw in rawMessages) {
      if (raw is! Map) throw const FormatException('Invalid message record.');
      final m = Map<String, dynamic>.from(raw);
      final id = m['id']?.toString() ?? '';
      final chatId = m['chatId']?.toString() ?? '';
      if (id.isEmpty || chatId.isEmpty) throw const FormatException('Invalid message record.');
      messages[id] = Message(
        id: id, text: m['text']?.toString() ?? '', time: m['time']?.toString() ?? '',
        isFromMe: m['isFromMe'] == true, chatId: chatId, senderId: m['senderId']?.toString() ?? '',
        createdAt: DateTime.tryParse(m['createdAt']?.toString() ?? '') ?? DateTime.now(),
        reactions: Message.parseReactions(m['reactions']),
        replyToId: m['replyToId']?.toString(), replyToText: m['replyToText']?.toString(),
        replyToSender: m['replyToSender']?.toString(), edited: m['edited'] == true,
        isEncrypted: m['isEncrypted'] == true, ciphertext: m['ciphertext']?.toString(),
        iv: m['iv']?.toString(),
        attachment: m['attachment'] is Map ? Map<String, dynamic>.from(m['attachment']) : null,
        poll: m['poll'] is Map ? Map<String, dynamic>.from(m['poll']) : null,
        pinnedAt: m['pinnedAt']?.toString(), pinnedBy: m['pinnedBy']?.toString(),
        riddle: m['riddle'] is Map ? Map<String, dynamic>.from(m['riddle']) : null,
        game: m['game'] is Map ? Map<String, dynamic>.from(m['game']) : null,
      );
    }
    final chats = <dynamic, dynamic>{};
    for (final raw in rawChats) {
      if (raw is! Map || raw['key'] == null || raw['value'] is! Map) {
        throw const FormatException('Invalid chat record.');
      }
      chats[raw['key']] = Map<String, dynamic>.from(raw['value'] as Map);
    }
    final users = <String, UserModel>{};
    for (final raw in rawUsers) {
      if (raw is! Map) throw const FormatException('Invalid contact record.');
      final u = Map<String, dynamic>.from(raw);
      final uid = u['uid']?.toString() ?? '';
      if (uid.isEmpty) throw const FormatException('Invalid contact record.');
      users[uid] = UserModel(
        uid: uid, name: u['name']?.toString() ?? '', username: u['username']?.toString() ?? '',
        email: u['email']?.toString() ?? '', bio: u['bio']?.toString() ?? '',
        age: u['age'] is num ? (u['age'] as num).toInt() : null,
        gender: u['gender']?.toString() ?? '',
        createdAt: DateTime.tryParse(u['createdAt']?.toString() ?? '') ?? DateTime.now(),
        isOnline: u['isOnline'] == true,
        lastSeen: DateTime.tryParse(u['lastSeen']?.toString() ?? ''),
        status: u['status']?.toString() ?? 'Online', photoUrl: u['photoUrl']?.toString() ?? '',
        lastSeenVisibility: u['lastSeenVisibility']?.toString() ?? 'everyone',
        profilePhotoVisibility: u['profilePhotoVisibility']?.toString() ?? 'everyone',
        readReceipts: u['readReceipts'] != false,
      );
    }
    await _messagesBox?.putAll(messages);
    await _chatsBox?.putAll(chats);
    await _usersBox?.putAll(users);
    return {'messages': messages.length, 'chats': chats.length, 'contacts': users.length};
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
