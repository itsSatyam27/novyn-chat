import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const Map<String, String> novynCustomEmojis = {
  'baddie': r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-45 -62 90 100" width="96" height="106"><circle r="32" fill="#F4B8D8" stroke="#B0407F" stroke-width="2"/><path d="M-24,-8 L-4,-8 Q-6,7 -14,7 Q-24,7 -24,-8Z" fill="#2B1B3A"/><path d="M4,-8 L24,-8 Q24,7 14,7 Q6,7 4,-8Z" fill="#2B1B3A"/><path d="M-4,-6 L4,-6" stroke="#2B1B3A" stroke-width="2"/><path d="M-8,18 Q0,25 9,15" fill="none" stroke="#D81B60" stroke-width="3.5" stroke-linecap="round"/><path transform="translate(24,-26)" d="M0,-7 L2,-2 L7,0 L2,2 L0,7 L-2,2 L-7,0 L-2,-2Z" fill="#FFD54F"/></svg>''',
  'dead_hasna': r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-45 -62 90 100" width="96" height="106"><circle r="32" fill="#FFD54F" stroke="#C98F00" stroke-width="2"/><path d="M-20,-14 L-8,-4 M-8,-14 L-20,-4 M8,-14 L20,-4 M20,-14 L8,-4" stroke="#5A3A00" stroke-width="3" stroke-linecap="round"/><path d="M-14,6 Q0,28 14,6Z" fill="#7A2E00"/><ellipse cx="0" cy="16" rx="6" ry="4" fill="#FF6B81"/><ellipse cx="-27" cy="8" rx="3" ry="6" fill="#4FC3F7"/><ellipse cx="27" cy="8" rx="3" ry="6" fill="#4FC3F7"/></svg>''',
  'sigma_stone': r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-45 -62 90 100" width="96" height="106"><circle r="32" fill="#B0B6BF" stroke="#6B7280" stroke-width="2"/><rect x="-20" y="-8" width="14" height="5" rx="2" fill="#2B2F36"/><rect x="6" y="-8" width="14" height="5" rx="2" fill="#2B2F36"/><path d="M-22,-16 L-4,-14 M4,-14 L22,-16" stroke="#2B2F36" stroke-width="3" stroke-linecap="round"/><path d="M-10,15 L10,15" stroke="#2B2F36" stroke-width="3" stroke-linecap="round"/><path d="M12,-31 L8,-21 L14,-16" fill="none" stroke="#6B7280" stroke-width="1.5"/></svg>''',
  'melting': r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-45 -62 90 100" width="96" height="106"><path d="M-32,0 A32,32 0 0 1 32,0 L32,18 Q32,32 24,32 Q18,32 18,20 Q18,38 10,38 Q2,38 2,22 Q2,28 -6,28 Q-14,28 -14,18 Q-14,32 -22,32 Q-32,32 -32,18Z" fill="#FFB74D" stroke="#E65100" stroke-width="2"/><circle cx="-12" cy="-6" r="3.5" fill="#5A2A00"/><circle cx="12" cy="-6" r="3.5" fill="#5A2A00"/><path d="M-10,10 Q-5,5 0,10 Q5,15 10,10" fill="none" stroke="#5A2A00" stroke-width="2.5" stroke-linecap="round"/></svg>''',
  'clown_moment': r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-45 -62 90 100" width="96" height="106"><circle cx="-26" cy="-18" r="10" fill="#FF6F3C"/><circle cx="26" cy="-18" r="10" fill="#FF6F3C"/><circle r="32" fill="#FFFFFF" stroke="#888780" stroke-width="2"/><circle cx="-12" cy="-8" r="3.5" fill="#2B1B3A"/><circle cx="12" cy="-8" r="3.5" fill="#2B1B3A"/><circle cx="0" cy="4" r="7" fill="#E53935"/><path d="M-16,14 Q0,30 16,14" fill="none" stroke="#E53935" stroke-width="3.5" stroke-linecap="round"/></svg>''',
  'ghosted': r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-45 -62 90 100" width="96" height="106"><path d="M-24,28 L-24,-4 A24,24 0 0 1 24,-4 L24,28 L16,21 L8,28 L0,21 L-8,28 L-16,21Z" fill="#ECEFF4" stroke="#8A94A6" stroke-width="2"/><circle cx="-9" cy="-4" r="3.5" fill="#2B1B3A"/><circle cx="9" cy="-4" r="3.5" fill="#2B1B3A"/><ellipse cx="0" cy="8" rx="3.5" ry="4.5" fill="#2B1B3A"/><path d="M20,-30 L24,-26 L32,-36 M26,-30 L30,-26 L38,-36" fill="none" stroke="#29B6F6" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg>''',
  'cutie': r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-45 -62 90 100" width="96" height="106"><circle r="32" fill="#FFE0E9" stroke="#E57A9B" stroke-width="2"/><path d="M-18,-2 Q-12,-12 -6,-2 M6,-2 Q12,-12 18,-2" fill="none" stroke="#2B1B3A" stroke-width="3" stroke-linecap="round"/><ellipse cx="-20" cy="8" rx="6" ry="4" fill="#FF8FB1"/><ellipse cx="20" cy="8" rx="6" ry="4" fill="#FF8FB1"/><path d="M-5,10 Q0,17 5,10" fill="none" stroke="#2B1B3A" stroke-width="2.5" stroke-linecap="round"/><path transform="translate(24,-26)" d="M0,6 C-9,-3 -5,-10 0,-4 C5,-10 9,-3 0,6Z" fill="#F43F5E"/></svg>''',
  'savage': r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-45 -62 90 100" width="96" height="106"><circle r="32" fill="#C7B8F5" stroke="#5B3FB0" stroke-width="2"/><path d="M-20,-14 L-6,-13 M6,-18 L20,-25" stroke="#2B1B3A" stroke-width="3" stroke-linecap="round"/><path d="M-18,-3 A6,6 0 0 1 -6,-3Z M6,-3 A6,6 0 0 1 18,-3Z" fill="#2B1B3A"/><path d="M-10,14 Q4,19 13,8" fill="none" stroke="#2B1B3A" stroke-width="3" stroke-linecap="round"/></svg>''',
  'battery_0': r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-45 -62 90 100" width="96" height="106"><rect x="-30" y="-16" width="54" height="32" rx="6" fill="none" stroke="#E53935" stroke-width="3"/><rect x="24" y="-6" width="6" height="12" rx="2" fill="#E53935"/><rect x="-26" y="-12" width="8" height="24" rx="3" fill="#E53935"/><path d="M-8,-3 Q-3,2 2,-3 M10,-3 Q15,2 20,-3" fill="none" stroke="#2B1B3A" stroke-width="2.5" stroke-linecap="round"/><path d="M-1,8 L11,8" stroke="#2B1B3A" stroke-width="2.5" stroke-linecap="round"/></svg>''',
  'red_flag': r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-45 -62 90 100" width="96" height="106"><path d="M-10,-30 L-10,32" stroke="#6B7280" stroke-width="4" stroke-linecap="round"/><path d="M-8,-28 Q8,-35 24,-22 Q8,-10 -8,-6Z" fill="#E53935" stroke="#B71C1C" stroke-width="1.5"/><ellipse cx="-10" cy="32" rx="12" ry="4" fill="#6B7280"/></svg>''',
  'boss': r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-45 -62 90 100" width="96" height="106"><path d="M-18,-24 L-22,-42 L-10,-32 L0,-45 L10,-32 L22,-42 L18,-24Z" fill="#FFB300" stroke="#C98F00" stroke-width="2" stroke-linejoin="round"/><circle r="32" fill="#FFD54F" stroke="#C98F00" stroke-width="2"/><path d="M-22,-8 L22,-8 L20,2 Q14,6 8,2 L-8,2 Q-14,6 -20,2Z" fill="#2B1B3A"/><path d="M-12,12 Q0,26 12,12Z" fill="#7A2E00"/></svg>''',
  'alien_vibes': r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-45 -62 90 100" width="96" height="106"><path d="M-10,-30 L-16,-42 M10,-30 L16,-42" stroke="#2E7D32" stroke-width="2.5" stroke-linecap="round"/><circle cx="-16" cy="-42" r="3.5" fill="#2E7D32"/><circle cx="16" cy="-42" r="3.5" fill="#2E7D32"/><circle r="32" fill="#8BE28B" stroke="#2E7D32" stroke-width="2"/><ellipse cx="-12" cy="-2" rx="7" ry="11" transform="rotate(20 -12 -2)" fill="#1B1B2F"/><ellipse cx="12" cy="-2" rx="7" ry="11" transform="rotate(-20 12 -2)" fill="#1B1B2F"/><path d="M-6,17 Q0,21 6,17" fill="none" stroke="#1B4D1B" stroke-width="2.5" stroke-linecap="round"/></svg>''',
  'pyaar': r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-45 -62 90 100" width="96" height="106"><circle r="32" fill="#FFB3C7" stroke="#D6336C" stroke-width="2"/><path transform="translate(-12,-4) scale(1.5)" d="M0,6 C-9,-3 -5,-10 0,-4 C5,-10 9,-3 0,6Z" fill="#E11D48"/><path transform="translate(12,-4) scale(1.5)" d="M0,6 C-9,-3 -5,-10 0,-4 C5,-10 9,-3 0,6Z" fill="#E11D48"/><path d="M-10,12 Q0,24 10,12" fill="none" stroke="#9F1239" stroke-width="3" stroke-linecap="round"/><path transform="translate(28,-26) scale(0.9)" d="M0,6 C-9,-3 -5,-10 0,-4 C5,-10 9,-3 0,6Z" fill="#F43F5E"/></svg>''',
  'gussa': r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-45 -62 90 100" width="96" height="106"><circle cx="-16" cy="-36" r="5" fill="#FFCDD2"/><circle cx="16" cy="-38" r="6" fill="#FFCDD2"/><circle r="32" fill="#FF8A80" stroke="#C62828" stroke-width="2"/><path d="M-22,-16 L-6,-8 M22,-16 L6,-8" stroke="#3E0A0A" stroke-width="3.5" stroke-linecap="round"/><circle cx="-12" cy="-2" r="3.5" fill="#3E0A0A"/><circle cx="12" cy="-2" r="3.5" fill="#3E0A0A"/><path d="M-10,18 Q0,10 10,18" fill="none" stroke="#3E0A0A" stroke-width="3" stroke-linecap="round"/></svg>''',
  'neend': r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-45 -62 90 100" width="96" height="106"><circle r="32" fill="#90CAF9" stroke="#1565C0" stroke-width="2"/><path d="M-20,-4 L-6,-4 M6,-4 L20,-4" stroke="#0D2A55" stroke-width="3" stroke-linecap="round"/><ellipse cx="0" cy="14" rx="4" ry="5" fill="#0D2A55"/><text x="20" y="-18" font-family="sans-serif" font-size="16" font-weight="bold" fill="#1565C0">Z</text><text x="30" y="-28" font-family="sans-serif" font-size="11" font-weight="bold" fill="#1565C0">z</text></svg>''',
  'nazar': r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-45 -62 90 100" width="96" height="106"><circle r="32" fill="#1E88E5" stroke="#0D47A1" stroke-width="2"/><circle r="22" fill="#FFFFFF"/><circle r="14" fill="#4FC3F7"/><circle r="7" fill="#0B1B33"/></svg>''',
  'gym_bro': r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-45 -62 90 100" width="96" height="106"><rect x="-20" y="-42" width="40" height="5" rx="2" fill="#6B7280"/><rect x="-26" y="-48" width="8" height="17" rx="3" fill="#374151"/><rect x="18" y="-48" width="8" height="17" rx="3" fill="#374151"/><circle r="32" fill="#FFCC80" stroke="#E65100" stroke-width="2"/><path d="M-20,-10 L-8,-5 L-20,0 M20,-10 L8,-5 L20,0" fill="none" stroke="#4A1F00" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/><rect x="-12" y="10" width="24" height="10" rx="3" fill="#FFFFFF" stroke="#4A1F00" stroke-width="2"/><path d="M-4,10 L-4,20 M4,10 L4,20" stroke="#4A1F00" stroke-width="1.5"/></svg>''',
  'paisa': r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-45 -62 90 100" width="96" height="106"><circle r="32" fill="#A5D6A7" stroke="#2E7D32" stroke-width="2"/><text x="-12" y="-1" text-anchor="middle" font-family="sans-serif" font-size="20" font-weight="bold" fill="#1B5E20">$</text><text x="12" y="-1" text-anchor="middle" font-family="sans-serif" font-size="20" font-weight="bold" fill="#1B5E20">$</text><path d="M-16,8 Q0,28 16,8Z" fill="#1B5E20"/></svg>''',
  'rona_aa_gaya': r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-45 -62 90 100" width="96" height="106"><circle r="32" fill="#FFE082" stroke="#C98F00" stroke-width="2"/><path d="M-20,-6 Q-12,-14 -4,-6 M4,-6 Q12,-14 20,-6" fill="none" stroke="#4A3500" stroke-width="3" stroke-linecap="round"/><path d="M-14,-4 Q-18,10 -14,26 M14,-4 Q18,10 14,26" fill="none" stroke="#4FC3F7" stroke-width="4" stroke-linecap="round"/><path d="M-8,18 Q0,10 8,18" fill="none" stroke="#4A3500" stroke-width="3" stroke-linecap="round"/></svg>''',
  'ice_cold': r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-45 -62 90 100" width="96" height="106"><rect x="-30" y="-30" width="60" height="60" rx="14" fill="#B3E5FC" stroke="#0288D1" stroke-width="2"/><path d="M-22,-22 L-10,-22 M-22,-22 L-22,-10" stroke="#FFFFFF" stroke-width="3" stroke-linecap="round"/><circle cx="-10" cy="-4" r="3.5" fill="#073B5C"/><circle cx="10" cy="-4" r="3.5" fill="#073B5C"/><path d="M-8,12 L8,12" stroke="#073B5C" stroke-width="3" stroke-linecap="round"/></svg>''',
  'sharam': r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-45 -62 90 100" width="96" height="106"><circle r="32" fill="#FFCCBC" stroke="#D84315" stroke-width="2"/><circle cx="-12" cy="-8" r="3.5" fill="#3B1200"/><circle cx="12" cy="-8" r="3.5" fill="#3B1200"/><ellipse cx="-12" cy="2" rx="11" ry="8" fill="#FFAB91" stroke="#D84315" stroke-width="1.5"/><ellipse cx="12" cy="2" rx="11" ry="8" fill="#FFAB91" stroke="#D84315" stroke-width="1.5"/><ellipse cx="-24" cy="12" rx="5" ry="3" fill="#FF6B81"/><ellipse cx="24" cy="12" rx="5" ry="3" fill="#FF6B81"/><path d="M-5,20 Q0,24 5,20" fill="none" stroke="#3B1200" stroke-width="2.5" stroke-linecap="round"/></svg>''',
  'sus': r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-45 -62 90 100" width="96" height="106"><circle r="32" fill="#CE93D8" stroke="#6A1B9A" stroke-width="2"/><ellipse cx="-12" cy="-2" rx="8" ry="7" fill="#FFFFFF"/><ellipse cx="12" cy="-2" rx="8" ry="7" fill="#FFFFFF"/><circle cx="-8" cy="-2" r="3.5" fill="#2B0A3D"/><circle cx="16" cy="-2" r="3.5" fill="#2B0A3D"/><path d="M-22,-12 L-4,-10 M4,-10 L22,-12" stroke="#2B0A3D" stroke-width="3" stroke-linecap="round"/><path d="M-8,16 L8,16" stroke="#2B0A3D" stroke-width="3" stroke-linecap="round"/></svg>''',
  'party': r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-45 -62 90 100" width="96" height="106"><path d="M-14,-26 L0,-52 L14,-26Z" fill="#EC407A" stroke="#AD1457" stroke-width="2" stroke-linejoin="round"/><circle cx="0" cy="-53" r="4" fill="#FFD54F"/><circle r="32" fill="#FFF59D" stroke="#F9A825" stroke-width="2"/><path d="M-18,-4 Q-12,-14 -6,-4 M6,-4 Q12,-14 18,-4" fill="none" stroke="#3A2A00" stroke-width="3" stroke-linecap="round"/><path d="M-14,8 Q0,28 14,8Z" fill="#7A2E00"/><circle cx="-34" cy="-14" r="3" fill="#29B6F6"/><circle cx="36" cy="6" r="3" fill="#EC407A"/><circle cx="34" cy="-22" r="2.5" fill="#66BB6A"/></svg>''',
  'overthinking': r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="-45 -62 90 100" width="96" height="106"><circle r="32" fill="#E0E0E0" stroke="#757575" stroke-width="2"/><path transform="translate(-12,-4)" d="M0,0 C4,-4 8,0 4,4 C0,8 -8,4 -6,-2 C-4,-8 6,-8 8,-2" fill="none" stroke="#2B2F36" stroke-width="2"/><path transform="translate(12,-4)" d="M0,0 C4,-4 8,0 4,4 C0,8 -8,4 -6,-2 C-4,-8 6,-8 8,-2" fill="none" stroke="#2B2F36" stroke-width="2"/><path d="M-12,16 Q-6,10 0,16 Q6,22 12,16" fill="none" stroke="#2B2F36" stroke-width="3" stroke-linecap="round"/></svg>''',
};

const List<String> novynCustomEmojiNames = [
  'baddie',
  'dead_hasna',
  'sigma_stone',
  'melting',
  'clown_moment',
  'ghosted',
  'cutie',
  'savage',
  'battery_0',
  'red_flag',
  'boss',
  'alien_vibes',
  'pyaar',
  'gussa',
  'neend',
  'nazar',
  'gym_bro',
  'paisa',
  'rona_aa_gaya',
  'ice_cold',
  'sharam',
  'sus',
  'party',
  'overthinking',
];

class CustomEmojiView extends StatelessWidget {
  const CustomEmojiView({super.key, required this.name, this.size = 36});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final svg = novynCustomEmojis[name];
    if (svg == null) return const SizedBox.shrink();
    return SizedBox(width: size, height: size, child: SvgPicture.string(svg, fit: BoxFit.contain));
  }
}

class CustomEmojiText extends StatelessWidget {
  const CustomEmojiText({super.key, required this.text, required this.style, this.emojiSize = 22});
  final String text;
  final TextStyle style;
  final double emojiSize;

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r':([a-z0-9_]+):');
    var cursor = 0;
    for (final match in pattern.allMatches(text)) {
      final name = match.group(1)!;
      final svg = novynCustomEmojis[name];
      if (svg == null) continue;
      if (match.start > cursor) spans.add(TextSpan(text: text.substring(cursor, match.start), style: style));
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: SizedBox(width: emojiSize, height: emojiSize, child: SvgPicture.string(svg, fit: BoxFit.contain)),
        ),
      ));
      cursor = match.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor), style: style));
    if (spans.isEmpty) spans.add(TextSpan(text: text, style: style));
    return Text.rich(TextSpan(children: spans), style: style);
  }
}
