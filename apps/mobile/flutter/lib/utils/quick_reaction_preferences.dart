import '../widgets/custom_emoji.dart';

const quickReactionEmojisPreferenceKey = 'novyn_quick_emojis';
const maxQuickReactionEmojiCount = 8;
const defaultQuickReactionEmojis = <String>[
  'baddie',
  'dead_hasna',
  'sigma_stone',
  'melting',
  'clown_moment',
  'ghosted',
  'cutie',
  'savage',
];

List<String> normalizeQuickReactionEmojis(Iterable<String>? values) {
  final normalized = <String>[];
  for (final value in values ?? defaultQuickReactionEmojis) {
    if (!novynCustomEmojis.containsKey(value) || normalized.contains(value)) {
      continue;
    }
    normalized.add(value);
    if (normalized.length == maxQuickReactionEmojiCount) break;
  }
  return normalized.isEmpty
      ? List<String>.from(defaultQuickReactionEmojis)
      : normalized;
}
