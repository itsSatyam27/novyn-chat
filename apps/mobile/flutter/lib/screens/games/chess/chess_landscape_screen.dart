import 'package:flutter/material.dart';

/// Landscape-first presentation scaffold for the future online Chess match.
/// Game state, matchmaking and voice transport are intentionally not wired here.
class ChessLandscapeScreen extends StatelessWidget {
  const ChessLandscapeScreen({super.key});

  static const _dark = Color(0xFF11152B);
  static const _panel = Color(0xFF20264A);
  static const _purple = Color(0xFF7650F5);
  static const _lightSquare = Color(0xFFF0D9B5);
  static const _darkSquare = Color(0xFFB58863);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dark,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          if (constraints.maxWidth < constraints.maxHeight) {
            return const _RotateHint();
          }
          return Padding(
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              _topBar(),
              const SizedBox(height: 8),
              Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: constraints.maxWidth * .22, child: _players()),
                  const SizedBox(width: 10),
                  Expanded(child: _boardArea()),
                  const SizedBox(width: 10),
                  SizedBox(width: constraints.maxWidth * .24, child: _chatPanel()),
                ]),
              ),
            ]),
          );
        }),
      ),
    );
  }

  Widget _topBar() => Row(children: [
    const Icon(Icons.arrow_back_rounded, color: Colors.white70),
    const SizedBox(width: 10),
    const Text('NOVYN  /  GAMES', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
    const Spacer(),
    const Icon(Icons.workspace_premium_rounded, color: Colors.amber),
    const SizedBox(width: 8),
    const Text('Chess  ·  1v1 Online', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    const Spacer(),
    const Icon(Icons.signal_cellular_alt_rounded, color: Colors.greenAccent),
    const SizedBox(width: 6),
    const Text('42 ms', style: TextStyle(color: Colors.greenAccent)),
    const SizedBox(width: 16),
    _iconButton(Icons.settings_rounded),
    const SizedBox(width: 6),
    _iconButton(Icons.more_vert_rounded),
  ]);

  Widget _players() => Column(children: [
    Expanded(child: _playerCard('Opponent', '1385', '04:45', false)),
    const Padding(padding: EdgeInsets.symmetric(vertical: 5), child: Text('VS', style: TextStyle(color: _purple, fontWeight: FontWeight.w900, fontSize: 22))),
    Expanded(child: _playerCard('You', '1420', '04:32', true)),
    const SizedBox(height: 8),
    _voiceControls(),
  ]);

  Widget _playerCard(String name, String rating, String time, bool isYou) =>
    Container(margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: _panel, border: Border.all(color: _purple.withOpacity(.45)),
        borderRadius: BorderRadius.circular(20)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircleAvatar(radius: 26, backgroundColor: _purple.withOpacity(.3),
          child: Icon(isYou ? Icons.person_rounded : Icons.face_rounded, color: Colors.white, size: 28)),
        const SizedBox(height: 6),
        Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        Text('Rating $rating', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        Container(width: double.infinity, padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: _dark, borderRadius: BorderRadius.circular(14)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.timer_outlined, color: Colors.white, size: 18),
            const SizedBox(width: 6), Text(time, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))
          ]))
      ]));

  Widget _boardArea() => Column(children: [
    Expanded(child: Center(child: AspectRatio(aspectRatio: 1, child: _board()))),
    const SizedBox(height: 8),
    Wrap(alignment: WrapAlignment.center, spacing: 6, children: [
      _action('Resign', Icons.flag_rounded),
      _action('Draw', Icons.handshake_rounded),
      _action('Rematch', Icons.refresh_rounded),
    ]),
  ]);

  Widget _board() {
    const pieces = [
      ['♜','♞','♝','♛','♚','♝','♞','♜'],
      ['♟','♟','♟','♟','','♟','♟','♟'],
      ['','','','','','','',''],
      ['','','','','♟','','',''],
      ['','','','','','','',''],
      ['','','','','','♘','',''],
      ['♙','♙','♙','♙','♙','♙','♙','♙'],
      ['♖','♘','♗','♕','♔','♗','♙','♖'],
    ];
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: GridView.builder(
      physics: const NeverScrollableScrollPhysics(), itemCount: 64,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
      itemBuilder: (context, index) {
        final row = index ~/ 8, col = index % 8;
        final isLight = (row + col) % 2 == 1;
        final selected = index == 45, lastMove = index == 36;
        return Container(color: selected ? const Color(0xFF9ACB59) : lastMove ? const Color(0xFFDE7772) : isLight ? _lightSquare : _darkSquare,
          alignment: Alignment.center, child: FittedBox(child: Text(pieces[row][col],
            style: TextStyle(fontSize: 40, color: row < 2 ? const Color(0xFF191919) : Colors.white,
              shadows: const [Shadow(color: Colors.black54, blurRadius: 2)])))));
      }));
  }

  Widget _chatPanel() => Container(decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _purple.withOpacity(.35))), padding: const EdgeInsets.all(8),
    child: Column(children: [
      Row(children: [Expanded(child: _tab('Chat', Icons.chat_bubble_rounded, true)),
        Expanded(child: _tab('History', Icons.history_rounded, false))]),
      const SizedBox(height: 8),
      const Expanded(child: Center(child: Text('Match chat\n\nMove history will appear here', textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70)))),
      Row(children: [Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: _dark, borderRadius: BorderRadius.circular(24)),
        child: const Text('Message…', style: TextStyle(color: Colors.white54)))),
        const SizedBox(width: 6), _iconButton(Icons.send_rounded)])
    ]));

  Widget _voiceControls() => Container(padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18)),
    child: Row(children: [Expanded(child: _voiceButton(Icons.mic_rounded, 'Mic', 'Off')),
      Container(width: 1, height: 44, color: Colors.white24),
      Expanded(child: _voiceButton(Icons.volume_up_rounded, 'Sound', 'On'))]));

  Widget _voiceButton(IconData icon, String label, String state) => Column(children: [
    CircleAvatar(backgroundColor: _purple, child: Icon(icon, color: Colors.white)),
    const SizedBox(height: 4), Text(label, style: const TextStyle(color: Colors.white)),
    Text(state, style: const TextStyle(color: Colors.white60, fontSize: 11))]);

  Widget _tab(String label, IconData icon, bool selected) => Container(padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(color: selected ? _purple : Colors.transparent, borderRadius: BorderRadius.circular(16)),
    child: Column(children: [Icon(icon, color: Colors.white, size: 18), Text(label, style: const TextStyle(color: Colors.white, fontSize: 12))]));

  Widget _action(String label, IconData icon) => FilledButton.tonalIcon(
    onPressed: null, icon: Icon(icon, size: 16), label: Text(label),
    style: FilledButton.styleFrom(backgroundColor: _panel, foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))));

  Widget _iconButton(IconData icon) => Container(padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(30)),
    child: Icon(icon, color: Colors.white70, size: 20));

  Widget _RotateHint() => const Center(child: Padding(padding: EdgeInsets.all(24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.screen_rotation_rounded, size: 48, color: _purple),
      SizedBox(height: 12), Text('Rotate your phone to play Chess', textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))
    ])));
}
