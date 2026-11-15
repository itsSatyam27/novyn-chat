import 'package:flutter/material.dart';

/// Native Unicode emoji equivalents for Novyn's custom emoji names.
/// Messages are stored and sent as ordinary Unicode text, so they work
/// across Flutter, web, and other clients without image assets or renderers.
const Map<String, String> novynCustomEmojis = {
  'baddie': '😏',
  'dead_hasna': '😂',
  'sigma_stone': '😎',
  'melting': '🫠',
  'clown_moment': '🤡',
  'ghosted': '👻',
  'cutie': '🥰',
  'savage': '😈',
  'battery_0': '🪫',
  'red_flag': '🚩',
  'boss': '👑',
  'alien_vibes': '👽',
  'pyaar': '❤️',
  'gussa': '😡',
  'neend': '😴',
  'nazar': '🧿',
  'gym_bro': '💪',
  'paisa': '🤑',
  'rona_aa_gaya': '😭',
  'ice_cold': '🥶',
  'sharam': '☺️',
  'sus': '🤨',
  'party': '🥳',
  'overthinking': '🤯',
};

const List<String> novynCustomEmojiNames = [
  'baddie', 'dead_hasna', 'sigma_stone', 'melting', 'clown_moment', 'ghosted',
  'cutie', 'savage', 'battery_0', 'red_flag', 'boss', 'alien_vibes', 'pyaar',
  'gussa', 'neend', 'nazar', 'gym_bro', 'paisa', 'rona_aa_gaya', 'ice_cold',
  'sharam', 'sus', 'party', 'overthinking',
];

/// Converts shortcode messages created by the earlier SVG picker to native
/// Unicode emoji. New messages are inserted as Unicode directly.
String novynEmojiText(String text) {
  return text.replaceAllMapped(
    RegExp(r':([a-z0-9_]+):'),
    (match) => novynCustomEmojis[match.group(1)] ?? match.group(0)!,
  );
}
