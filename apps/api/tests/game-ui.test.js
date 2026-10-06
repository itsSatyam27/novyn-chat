const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require('typescript');
const React = require('react');

function loadComponent(name) {
  const exported = {};
  const code = ts.transpileModule(fs.readFileSync(path.join(__dirname, `../../web/src/components/chat/${name}.tsx`), 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX },
  }).outputText;
  vm.runInNewContext(code, { exports: exported, require(name) {
    if (name === 'react/jsx-runtime') return require(name);
    if (name === 'react') return { ...React, default: React };
    if (name === 'framer-motion') return { motion: new Proxy({}, { get: (_, key) => key }) };
    if (name.endsWith('/capacitor')) return { triggerHaptic() {} };
    return new Proxy({}, { get: (_, key) => key });
  }});
  return exported[name];
}
function elements(node) {
  if (Array.isArray(node)) return node.flatMap(elements);
  return React.isValidElement(node) ? [node, ...elements(node.props.children)] : [];
}
const GameMessageBubble = loadComponent('GameMessageBubble');
const GameLauncherModal = loadComponent('GameLauncherModal');

test('tic-tac-toe retains equal tracks and bounded cells before and after a move', () => {
  const game = { gameType: 'tictactoe', title: 'Tic-Tac-Toe', state: 'in_progress', turn: 'alice', createdBy: 'alice', opponent: 'bob', data: { board: Array(9).fill(null), playerX: 'alice', playerO: 'bob' } };
  let move;
  const render = () => elements(GameMessageBubble({ game, messageId: 'g1', currentUsername: 'alice', onMove: (id, data) => { move = { id, data }; } }));
  const before = render();
  const first = before.find((node) => node.props['aria-label'] === 'Row 1, column 1: empty');
  first.props.onClick();
  assert.equal(move.id, 'g1');
  assert.equal(move.data.board[0], 'X');
  game.data = { ...game.data, ...move.data };
  game.turn = move.data.turn;
  const after = render();
  for (const tree of [before, after]) {
    const board = tree.find((node) => node.props.className === 'tic-tac-toe-board');
    assert.equal(board.props.style.gridTemplateRows, 'repeat(3, minmax(0, 1fr))');
    assert.equal(board.props.style.gridTemplateColumns, 'repeat(3, minmax(0, 1fr))');
    assert.equal(board.props.style.aspectRatio, '1');
    const cells = elements(board).filter((node) => node.type === 'button');
    assert.equal(cells.length, 9);
    for (const cell of cells) {
      assert.equal(cell.props.style.minHeight, 0);
      assert.equal(cell.props.style.lineHeight, 1);
      assert.equal(cell.props.whileHover?.scale, undefined);
    }
  }
});

test('game picker uses one keyboard-accessible button per game and launches once', () => {
  const calls = [];
  const tree = elements(GameLauncherModal({ isOpen: true, opponentName: 'bob', onLaunchGame: (type) => calls.push(type), onClose: () => calls.push('close') }));
  const options = tree.filter((node) => node.type === 'button');
  assert.equal(options.length, 3);
  for (const option of options) {
    assert.match(option.props['aria-label'], /^Play /);
    assert.equal(elements(option).filter((node) => node.type === 'button').length, 1, 'no nested buttons');
    option.props.onClick();
  }
  assert.deepEqual(calls, ['tictactoe', 'close', 'rps', 'close', 'connect4', 'close']);
});
