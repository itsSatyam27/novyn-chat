const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require('typescript');
const React = require('react');

function loadDock() {
  const exported = {};
  const haptics = [];
  const source = fs.readFileSync(path.join(__dirname, '../src/components/layout/NavDock.tsx'), 'utf8');
  const compiled = ts.transpileModule(source, {
    compilerOptions: { module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX },
  }).outputText;
  vm.runInNewContext(compiled, { exports: exported, require(name) {
    if (name === 'react/jsx-runtime') return require(name);
    if (name === 'react') return { ...React, default: React, useState: (value) => [value, () => {}], useRef: () => ({ current: null }), useEffect() {} };
    if (name.endsWith('/dockPreferences')) return { useDockAlwaysVisible: () => false };
    if (name.endsWith('/capacitor')) return { triggerHaptic: (type) => haptics.push(type) };
    return new Proxy({}, { get: (_, key) => key });
  } });
  return { ...exported, haptics };
}

function elements(node) {
  if (Array.isArray(node)) return node.flatMap(elements);
  return React.isValidElement(node) ? [node, ...elements(node.props.children)] : [];
}

for (const className of ['desktop-sidebar', 'mobile-bottom-nav']) {
  test(`${className}: one persistent pill, accessible tabs, and immediate selection`, () => {
    const { NavDock, NAV_ITEMS, haptics } = loadDock();
    const selected = [];
    for (const [index, item] of NAV_ITEMS.entries()) {
      const root = NavDock({ activeTab: item.id, onSelectTab: (id) => selected.push(id), className, requestCount: 2 });
      const tree = elements(root);
      assert.equal(root.props.style['--dock-active-index'], index);
      assert.equal(tree.filter((node) => node.props.className === 'dock-active-pill').length, 1);
      const buttons = tree.filter((node) => node.type === 'button' && node.props.className.startsWith('dock-item'));
      assert.equal(buttons.length, 5);
      assert.equal(buttons.filter((node) => node.props['aria-current'] === 'page').length, 1);
      assert.equal(buttons[index].props['aria-label'], item.label);
      buttons[index].props.onClick();
      assert.equal(selected.length, index, 'reselecting the active tab does not restart navigation');
      buttons[(index + 1) % buttons.length].props.onClick();
      assert.equal(selected[index], NAV_ITEMS[(index + 1) % buttons.length].id);
      assert.ok(tree.some((node) => node.props['aria-label'] === '2 friend requests'));
    }
    assert.equal(haptics.length, 5);
  });
}
