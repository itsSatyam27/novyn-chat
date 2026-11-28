import 'dart:math' as math;

/// Legal-move engine and local minimax opponent for offline Chess practice.
class ChessEngine {
  ChessEngine._();

  static const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  static const _knight = [-33, -31, -18, -14, 14, 18, 31, 33];
  static const _bishop = [-17, -15, 15, 17];
  static const _rook = [-16, -1, 1, 16];
  static const _king = [-17, -16, -15, -1, 1, 15, 16, 17];
  static const _value = {'p': 100, 'n': 320, 'b': 335, 'r': 500, 'q': 900, 'k': 20000};

  static bool _on(int s) => s >= 0 && s < 128 && (s & 0x88) == 0;
  static int _color(String p) => p == '.' || p.isEmpty ? 0 : (p == p.toUpperCase() ? 1 : -1);
  static String _name(int s) => String.fromCharCode(97 + (s & 7)) + (8 - (s >> 4)).toString();
  static int _index(String s) => RegExp(r'^[a-h][1-8]$').hasMatch(s)
      ? (8 - int.parse(s[1])) * 16 + s.codeUnitAt(0) - 97 : -1;

  static _Position _parse(String fen) {
    final f = fen.trim().split(RegExp(r'\s+'));
    if (f.length < 4 || f.length > 6 ||
        !RegExp(r'^[wb]$').hasMatch(f[1]) ||
        !RegExp(r'^(?:-|K?Q?k?q?)$').hasMatch(f[2]) ||
        !RegExp(r'^(?:-|[a-h][36])$').hasMatch(f[3])) {
      throw FormatException('Invalid chess position.');
    }
    final board = List<String>.filled(128, '.');
    final ranks = f[0].split('/');
    if (ranks.length != 8) throw FormatException('Invalid chess position.');
    var wk = 0, bk = 0;
    for (var row = 0; row < 8; row++) {
      var file = 0;
      for (final token in ranks[row].split('')) {
        final count = int.tryParse(token);
        if (count != null) {
          file += count;
        } else if (RegExp(r'^[prnbqkPRNBQK]$').hasMatch(token) && file < 8) {
          board[row * 16 + file] = token;
          if (token == 'K') wk++;
          if (token == 'k') bk++;
          file++;
        } else {
          throw FormatException('Invalid chess position.');
        }
      }
      if (file != 8) throw FormatException('Invalid chess position.');
    }
    if (wk != 1 || bk != 1) throw FormatException('Invalid chess position.');
    final half = int.tryParse(f.length > 4 ? f[4] : '0') ?? -1;
    final full = int.tryParse(f.length > 5 ? f[5] : '1') ?? -1;
    if (half < 0 || full < 1) throw FormatException('Invalid chess position.');
    return _Position(board, f[1] == 'w' ? 1 : -1, f[2] == '-' ? '' : f[2],
        f[3] == '-' ? -1 : _index(f[3]), half, full);
  }

  static String _fen(_Position p) {
    final ranks = <String>[];
    for (var row = 0; row < 8; row++) {
      final out = StringBuffer();
      var empty = 0;
      for (var file = 0; file < 8; file++) {
        final piece = p.board[row * 16 + file];
        if (piece == '.') {
          empty++;
        } else {
          if (empty > 0) { out.write(empty); empty = 0; }
          out.write(piece);
        }
      }
      if (empty > 0) out.write(empty);
      ranks.add(out.toString());
    }
    return ranks.join('/') + ' ' + (p.turn == 1 ? 'w' : 'b') + ' ' +
        (p.castling.isEmpty ? '-' : p.castling) + ' ' +
        (p.ep < 0 ? '-' : _name(p.ep)) + ' ' + p.half.toString() + ' ' + p.full.toString();
  }

  static bool _attacked(_Position p, int target, int side) {
    final b = p.board;
    for (var from = 0; from < 128; from++) {
      if (!_on(from) || _color(b[from]) != side) continue;
      final piece = b[from].toLowerCase();
      if (piece == 'p') {
        if (target == from - 16 * side - 1 || target == from - 16 * side + 1) return true;
        continue;
      }
      final dirs = piece == 'n' ? _knight : piece == 'b' ? _bishop :
          piece == 'r' ? _rook : piece == 'q' ? [..._bishop, ..._rook] : _king;
      for (final d in dirs) {
        for (var to = from + d; _on(to); to += d) {
          if (to == target) return true;
          if (b[to] != '.' || piece == 'n' || piece == 'k') break;
        }
      }
    }
    return false;
  }

  static bool _check(_Position p, [int? side]) {
    final color = side ?? p.turn;
    final king = p.board.indexOf(color == 1 ? 'K' : 'k');
    return king < 0 || _attacked(p, king, -color);
  }

  static _Position _apply(_Position p, _Move m) {
    final b = List<String>.from(p.board);
    final piece = b[m.from];
    final captured = m.flags == 'ep' ? b[m.to + (p.turn == 1 ? 16 : -16)] : b[m.to];
    b[m.from] = '.';
    b[m.to] = m.promotion.isEmpty ? piece :
        (p.turn == 1 ? m.promotion.toUpperCase() : m.promotion);
    if (m.flags == 'ep') b[m.to + (p.turn == 1 ? 16 : -16)] = '.';
    if (m.flags == 'castle') {
      final rookFrom = m.to > m.from ? m.from + 3 : m.from - 4;
      final rookTo = m.to > m.from ? m.from + 1 : m.from - 1;
      b[rookTo] = b[rookFrom];
      b[rookFrom] = '.';
    }
    var rights = p.castling;
    void remove(String values) {
      for (final v in values.split('')) { rights = rights.replaceAll(v, ''); }
    }
    if (piece == 'K') remove('KQ');
    if (piece == 'k') remove('kq');
    const rookRights = {112: 'Q', 119: 'K', 0: 'q', 7: 'k'};
    if (piece.toLowerCase() == 'r' && rookRights.containsKey(m.from)) remove(rookRights[m.from]!);
    if (captured.toLowerCase() == 'r' && rookRights.containsKey(m.to)) remove(rookRights[m.to]!);
    final pawn = piece.toLowerCase() == 'p';
    final capture = captured != '.' || m.flags == 'ep';
    return _Position(b, -p.turn, rights,
        pawn && (m.to - m.from).abs() == 32 ? (m.to + m.from) ~/ 2 : -1,
        pawn || capture ? 0 : p.half + 1, p.full + (p.turn == -1 ? 1 : 0));
  }

  static List<_Move> _pseudo(_Position p) {
    final moves = <_Move>[];
    final b = p.board;
    final side = p.turn;
    void add(int from, int to, [String flags = '']) {
      if (!_on(to) || _color(b[to]) == side || b[to].toLowerCase() == 'k') return;
      if (b[from].toLowerCase() == 'p' && ((to >> 4) == 0 || (to >> 4) == 7)) {
        for (final promotion in ['q', 'r', 'b', 'n']) {
          moves.add(_Move(from, to, promotion, flags));
        }
      } else {
        moves.add(_Move(from, to, '', flags));
      }
    }
    for (var from = 0; from < 128; from++) {
      if (!_on(from) || _color(b[from]) != side) continue;
      final piece = b[from].toLowerCase();
      if (piece == 'p') {
        final step = -16 * side;
        final one = from + step;
        if (_on(one) && b[one] == '.') {
          add(from, one);
          final home = side == 1 ? 6 : 1;
          final two = one + step;
          if ((from >> 4) == home && b[two] == '.') add(from, two);
        }
        for (final df in [-1, 1]) {
          final to = one + df;
          if (!_on(to)) continue;
          if (_color(b[to]) == -side) {
            add(from, to);
          } else if (to == p.ep && b[to] == '.') {
            add(from, to, 'ep');
          }
        }
        continue;
      }
      final dirs = piece == 'n' ? _knight : piece == 'b' ? _bishop :
          piece == 'r' ? _rook : piece == 'q' ? [..._bishop, ..._rook] : _king;
      for (final d in dirs) {
        for (var to = from + d; _on(to); to += d) {
          if (_color(b[to]) == side) break;
          add(from, to);
          if (b[to] != '.' || piece == 'n' || piece == 'k') break;
        }
      }
      if (piece == 'k' && !_check(p)) {
        final home = side == 1 ? 116 : 4;
        final rook = side == 1 ? 'R' : 'r';
        final kr = side == 1 ? 'K' : 'k';
        final qr = side == 1 ? 'Q' : 'q';
        if (from == home && p.castling.contains(kr) && b[home + 3] == rook &&
            b[home + 1] == '.' && b[home + 2] == '.' &&
            !_attacked(p, home + 1, -side) && !_attacked(p, home + 2, -side)) {
          add(from, home + 2, 'castle');
        }
        if (from == home && p.castling.contains(qr) && b[home - 4] == rook &&
            b[home - 1] == '.' && b[home - 2] == '.' && b[home - 3] == '.' &&
            !_attacked(p, home - 1, -side) && !_attacked(p, home - 2, -side)) {
          add(from, home - 2, 'castle');
        }
      }
    }
    return moves;
  }

  static List<_Move> _legal(_Position p) =>
      _pseudo(p).where((m) => !_check(_apply(p, m), p.turn)).toList();

  static List<String> legalMoves(String fen) =>
      _legal(_parse(fen)).map((m) => m.uci).toList(growable: false);

  static String? applyMove(String fen, String uci) {
    if (!RegExp(r'^[a-h][1-8][a-h][1-8][qrbn]?$').hasMatch(uci)) return null;
    final p = _parse(fen);
    for (final move in _legal(p)) {
      if (move.uci == uci) return _fen(_apply(p, move));
    }
    return null;
  }

  static ChessEvaluation evaluate(String fen) {
    final p = _parse(fen);
    final moves = _legal(p);
    final check = _check(p);
    if (moves.isEmpty) {
      return check
          ? ChessEvaluation(finished: true, winner: p.turn == 1 ? 'black' : 'white',
              reason: 'checkmate', inCheck: true)
          : const ChessEvaluation(finished: true, winner: 'draw', reason: 'stalemate');
    }
    if (_insufficient(p)) {
      return const ChessEvaluation(finished: true, winner: 'draw', reason: 'insufficient_material');
    }
    if (p.half >= 150) {
      return const ChessEvaluation(finished: true, winner: 'draw', reason: 'seventy_five_move_rule');
    }
    return ChessEvaluation(finished: false, winner: null,
        reason: check ? 'check' : 'playing', inCheck: check);
  }

  static bool _insufficient(_Position p) {
    final pieces = <MapEntry<String, int>>[];
    for (var i = 0; i < 128; i++) {
      if (!_on(i) || p.board[i] == '.' || p.board[i].toLowerCase() == 'k') continue;
      pieces.add(MapEntry(p.board[i].toLowerCase(), ((i >> 4) + (i & 7)) % 2));
    }
    return pieces.isEmpty ||
        (pieces.length == 1 && ['b', 'n'].contains(pieces.first.key)) ||
        (pieces.every((e) => e.key == 'b') && pieces.map((e) => e.value).toSet().length == 1);
  }

  static String? bestMove(String fen, {int depth = 2}) {
    final p = _parse(fen);
    final moves = _ordered(p, _legal(p));
    if (moves.isEmpty) return null;
    final d = depth < 1 ? 1 : depth > 3 ? 3 : depth;
    var best = moves.first;
    var bestScore = -1000000;
    var alpha = -1000000;
    const beta = 1000000;
    for (final move in moves) {
      final score = -_search(_apply(p, move), d - 1, -beta, -alpha, 1);
      if (score > bestScore) { bestScore = score; best = move; }
      if (score > alpha) alpha = score;
    }
    return best.uci;
  }

  static int _search(_Position p, int depth, int alpha, int beta, int ply) {
    final moves = _legal(p);
    if (moves.isEmpty) return _check(p) ? -100000 + ply : 0;
    if (_insufficient(p) || p.half >= 150) return 0;
    if (depth <= 0) return _material(p) * p.turn;
    var best = -1000000;
    for (final move in _ordered(p, moves)) {
      final score = -_search(_apply(p, move), depth - 1, -beta, -alpha, ply + 1);
      if (score > best) best = score;
      if (score > alpha) alpha = score;
      if (alpha >= beta) break;
    }
    return best;
  }

  static int _material(_Position p) {
    var score = 0;
    for (var s = 0; s < 128; s++) {
      if (!_on(s)) continue;
      final piece = p.board[s];
      if (piece == '.') continue;
      final type = piece.toLowerCase();
      final side = _color(piece);
      final row = s >> 4;
      final file = s & 7;
      final center = (file - 3.5).abs() + (row - 3.5).abs();
      var value = _value[type] ?? 0;
      if (type == 'p') value += (side == 1 ? 6 - row : row - 1) * 5;
      if (type == 'n' || type == 'b') value += ((7 - center) * 4).round();
      if (type == 'q') value += ((7 - center) * 2).round();
      score += side * value;
    }
    return score;
  }

  static List<_Move> _ordered(_Position p, List<_Move> moves) {
    final out = List<_Move>.from(moves);
    out.sort((a, b) => _priority(p, b).compareTo(_priority(p, a)));
    return out;
  }

  static int _priority(_Position p, _Move m) {
    final captured = m.flags == 'ep' ? 100 : (_value[p.board[m.to].toLowerCase()] ?? 0);
    final promotion = m.promotion.isEmpty ? 0 : (_value[m.promotion] ?? 0);
    return captured * 10 + promotion;
  }
}

class ChessEvaluation {
  const ChessEvaluation({
    required this.finished,
    required this.winner,
    required this.reason,
    this.inCheck = false,
  });
  final bool finished;
  final String? winner;
  final String reason;
  final bool inCheck;
}

class _Position {
  _Position(this.board, this.turn, this.castling, this.ep, this.half, this.full);
  final List<String> board;
  final int turn;
  final String castling;
  final int ep;
  final int half;
  final int full;
}

class _Move {
  const _Move(this.from, this.to, [this.promotion = '', this.flags = '']);
  final int from;
  final int to;
  final String promotion;
  final String flags;
  String get uci => ChessEngine._name(from) + ChessEngine._name(to) + promotion;
}
