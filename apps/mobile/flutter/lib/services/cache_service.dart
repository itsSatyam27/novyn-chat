import 'package:hive_flutter/hive_flutter.dart';
import '../models/chat_models.dart';
import '../models/user_model.dart';

class CacheService {
  static const String chatsBoxName = 'chats';
  static const String messagesBoxPrefix = 'messages_';
  static const String userBoxName = 'user_profile';

  static Future<void> init() async {
    await Hive.initFlutter();
    
    // Register adapters
    Hive.registerAdapter(ChatAdapter());
    Hive.registerAdapter(MessageAdapter());
    Hive.registerAdapter(UserModelAdapter());
    
    // Open main boxes
    await Hive.openBox<Chat>(chatsBoxName);
    await Hive.openBox<UserModel>(userBoxName);
  }

  // ── Chats ──────────────────────────────────────────────────────────────────
  static Box<Chat> get chatsBox => Hive.box<Chat>(chatsBoxName);
  
  static List<Chat> getCachedChats() {
    return chatsBox.values.toList();
  }

  static Future<void> cacheChats(List<Chat> chats) async {
    final Map<String, Chat> chatMap = {for (var c in chats) c.id: c};
    await chatsBox.putAll(chatMap);
  }

  // ── Messages ───────────────────────────────────────────────────────────────
  static Future<Box<Message>> _getMessagesBox(String chatId) async {
    final boxName = '$messagesBoxPrefix$chatId';
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<Message>(boxName);
    }
    return await Hive.openBox<Message>(boxName);
  }

  static Future<List<Message>> getCachedMessages(String chatId) async {
    final box = await _getMessagesBox(chatId);
    return box.values.toList();
  }

  static Future<void> cacheMessage(String chatId, Message message) async {
    final box = await _getMessagesBox(chatId);
    await box.put(message.id, message);
  }

  static Future<void> cacheMessages(String chatId, List<Message> messages) async {
    final box = await _getMessagesBox(chatId);
    final Map<String, Message> messageMap = {for (var m in messages) m.id: m};
    await box.putAll(messageMap);
  }

  // ── Clear Cache ────────────────────────────────────────────────────────────
  static Future<void> clearAll() async {
    await Hive.deleteFromDisk();
  }
}
