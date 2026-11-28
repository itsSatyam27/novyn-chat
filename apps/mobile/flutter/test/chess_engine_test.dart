import 'package:flutter_test/flutter_test.dart';
import 'package:novyn/services/chess_engine.dart';

String playLine(String fen, List<String> moves) {
  var current = fen;
  for (final move in moves) {
    final next = ChessEngine.applyMove(current, move);
    expect(next, isNotNull, reason: '$move should be legal');
    current = next!;
  }
  return current;
}

void main() {
  test('starting position exposes twenty legal moves', () {
    expect(ChessEngine.legalMoves(ChessEngine.startFen), hasLength(20));
    expect(ChessEngine.applyMove(ChessEngine.startFen, 'e2e5'), isNull);
  });

  test('legal moves alternate sides and update FEN', () {
    final afterWhite = ChessEngine.applyMove(ChessEngine.startFen, 'e2e4');
    expect(afterWhite, isNotNull);
    expect(afterWhite!.split(' ')[1], 'b');
    final afterBlack = ChessEngine.applyMove(afterWhite, 'e7e5');
    expect(afterBlack, isNotNull);
    expect(afterBlack!.split(' ')[1], 'w');
    expect(ChessEngine.legalMoves(afterBlack), isNotEmpty);
  });

  test('supports castling, en passant and pawn promotion', () {
    final castle = playLine(ChessEngine.startFen, [
      'e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'g8f6', 'e1g1',
    ]);
    expect(castle.split(' ')[0], contains('RK'));

    final enPassant = playLine(ChessEngine.startFen, [
      'e2e4', 'a7a6', 'e4e5', 'd7d5', 'e5d6',
    ]);
    expect(enPassant.split(' ')[0], contains('p2P4'));

    final promotion = ChessEngine.applyMove(
      '4k3/P7/8/8/8/8/8/4K3 w - - 0 1',
      'a7a8q',
    );
    expect(promotion, isNotNull);
    expect(promotion!.split(' ')[0], startsWith('Q3k3'));
  });

  test('detects checkmate and stalemate', () {
    final foolMate = playLine(ChessEngine.startFen, [
      'f2f3', 'e7e5', 'g2g4', 'd8h4',
    ]);
    final mate = ChessEngine.evaluate(foolMate);
    expect(mate.finished, isTrue);
    expect(mate.winner, 'black');
    expect(mate.reason, 'checkmate');

    final stalemate = ChessEngine.evaluate('7k/5K2/6Q1/8/8/8/8/8 b - - 0 1');
    expect(stalemate.finished, isTrue);
    expect(stalemate.winner, 'draw');
    expect(stalemate.reason, 'stalemate');
  });

  test('bot returns a legal move at each configured search depth', () {
    for (final depth in [1, 2, 3]) {
      final move = ChessEngine.bestMove(ChessEngine.startFen, depth: depth);
      expect(move, isNotNull);
      expect(ChessEngine.legalMoves(ChessEngine.startFen), contains(move));
    }
  });
}
