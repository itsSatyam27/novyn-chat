const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require('typescript');
const React = require('react');

// Exercise the real component handlers without a browser or a signed-in account.
// Child components and effects are isolated; state persists across layout renders.
function loadComponent(relativePath, chat, { width = 360, initialTab } = {}) {
  let cursor = 0;
  const state = [];
  const hooks = {
    ...React,
    useState(initial) {
      const index = cursor++;
      if (!(index in state)) {
        state[index] = initial === 'chats' && initialTab
          ? initialTab
          : typeof initial === 'function' ? initial() : initial;
      }
      return [state[index], (next) => {
        state[index] = typeof next === 'function' ? next(state[index]) : next;
      }];
    },
    useEffect() {},
    useRef: (current) => ({ current }),
    lazy: () => 'LazyComponent',
  };
  const exports = {};
  const filename = path.join(__dirname, '../../web', relativePath);
  const compiled = ts.transpileModule(fs.readFileSync(filename, 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX },
  }).outputText;
  vm.runInNewContext(compiled, {
    exports,
    window: { innerWidth: width },
    localStorage: { getItem: () => null },
    require(name) {
      if (name === 'react') return { ...hooks, default: hooks };
      if (name === 'react/jsx-runtime') return require(name);
      if (name.endsWith('/ChatContext')) return { useChat: () => chat };
      if (name.endsWith('/AuthContext')) return { useAuth: () => ({ isAuthenticated: true, isLoading: false }) };
      if (name.endsWith('/capacitor')) return { triggerHaptic() {}, setupMobileEnvironment() {} };
      return new Proxy({}, { get: (_, key) => key });
    },
  }, { filename });
  return (name, props = {}) => {
    cursor = 0;
    return exports[name](props);
  };
}

function elements(node) {
  if (Array.isArray(node)) return node.flatMap(elements);
  if (!React.isValidElement(node)) return [];
  return [node, ...elements(node.props.children)];
}

test('quiet inbox offers one compose control with working message and group actions', () => {
  let openedContacts = 0;
  const render = loadComponent('src/components/chat/ChatList.tsx', {
    conversations: [], activeChat: null,
    pinnedChats: new Set(), archivedChats: new Set(), favouriteChats: new Set(),
    manualUnreadChats: new Set(), mutedUsers: new Set(), blockedUsers: new Set(),
  });
  const props = { onOpenContacts: () => openedContacts++ };
  let tree = elements(render('ChatList', props));
  assert.equal(tree.filter((node) => node.props['aria-label'] === 'Compose a message').length, 1);
  assert.ok(!tree.some((node) => node.props.className === 'quick-contacts'));
  tree.find((node) => node.props['aria-label'] === 'Compose a message').props.onClick();
  tree = elements(render('ChatList', props));
  const actions = elements(tree.find((node) => node.props.className === 'inbox-compose-options')).filter((node) => node.type === 'button');
  actions[0].props.onClick();
  assert.equal(openedContacts, 1);
  tree = elements(render('ChatList', props));
  assert.ok(!tree.some((node) => node.props.className === 'inbox-compose-options'));
  tree.find((node) => node.props['aria-label'] === 'Compose a message').props.onClick();
  tree = elements(render('ChatList', props));
  elements(tree.find((node) => node.props.className === 'inbox-compose-options')).filter((node) => node.type === 'button')[1].props.onClick();
  tree = elements(render('ChatList', props));
  assert.equal(tree.find((node) => node.type === 'CreateGroupModal').props.isOpen, true);
});

test('inbox filters retain all labels and move the shared pill to the selected filter', () => {
  const render = loadComponent('src/components/chat/ChatList.tsx', {
    conversations: [], activeChat: null,
    pinnedChats: new Set(), archivedChats: new Set(), favouriteChats: new Set(),
    manualUnreadChats: new Set(), mutedUsers: new Set(), blockedUsers: new Set(),
  });
  for (const index of [1, 3, 2, 0]) {
    let tree = elements(render('ChatList', { onOpenContacts() {} }));
    const filters = elements(tree.find((node) => node.props.className === 'chat-filters'));
    const buttons = filters.filter((node) => node.type === 'button');
    assert.equal(buttons.length, 4);
    buttons[index].props.onClick();
    tree = elements(render('ChatList', { onOpenContacts() {} }));
    const group = tree.find((node) => node.props.className === 'chat-filters');
    assert.equal(group.props.style['--filter-index'], index);
    assert.equal(elements(group).filter((node) => node.props['aria-pressed'] === true).length, 1);
    assert.equal(elements(group).filter((node) => node.props.className === 'chat-filter-pill').length, 1);
  }
});

for (const component of ['ContactsPanel', 'ContactsModal']) {
  test(`${component} uses one sliding pill and preserves all three contact views`, () => {
    const render = loadComponent(`src/components/contacts/${component}.tsx`, {
      conversations: [], friendRequests: [],
    });
    const props = { isOpen: true, onClose() {}, onOpenChat() {} };
    for (const index of [1, 2, 0]) {
      let tree = elements(render(component, props));
      let group = tree.find((node) => node.props['aria-label'] === 'Filter contacts');
      const buttons = elements(group).filter((node) => node.type === 'button');
      assert.equal(buttons.length, 3);
      buttons[index].props.onClick();
      tree = elements(render(component, props));
      group = tree.find((node) => node.props['aria-label'] === 'Filter contacts');
      assert.equal(group.props.style['--filter-index'], index);
      assert.equal(elements(group).filter((node) => node.props['aria-pressed'] === true).length, 1);
      assert.equal(elements(group).filter((node) => node.props.className === 'chat-filter-pill').length, 1);
    }
  });
}

for (const entry of ['friend name', 'compact avatar']) {
  test(`Contacts ${entry} selects the friend and opens Chats`, () => {
    const calls = [];
    const render = loadComponent('src/components/contacts/ContactsPanel.tsx', {
      conversations: [{ username: 'hii', displayName: 'Hii', online: true }],
      friendRequests: [],
      setActiveChat: (username) => calls.push(['select', username]),
    });
    const tree = elements(render('ContactsPanel', {
      isCompact: entry === 'compact avatar',
      onOpenChat: () => calls.push(['navigate', 'chats']),
    }));
    const target = tree.find((element) => {
      if (entry === 'compact avatar') return element.props.title === 'Chat with Hii';
      return element.props.onClick && element.props.style?.flex === 1;
    });
    assert.ok(target, `Missing ${entry}`);
    target.props.onClick();
    assert.deepEqual(calls, [['select', 'hii'], ['navigate', 'chats']]);
  });
}

test('settings sections remain accessible for every category', () => {
  const render = loadComponent('src/components/settings/SettingsSubPanel.tsx', {});
  const counts = { profile: 4, privacy: 7, notifications: 3, appearance: 3, storage: 3, feedback: 3 };
  for (const [category, count] of Object.entries(counts)) {
    let selected;
    const tree = elements(render('SettingsSubPanel', { activeCategory: category, activeSubSection: '', blockedCount: 2, onSelectSubSection: (id) => { selected = id; } }));
    const group = tree.find((node) => node.props['aria-label'] === 'Settings sections');
    const buttons = elements(group).filter((node) => node.type === 'button');
    assert.equal(buttons.length, count);
    for (const button of buttons) {
      button.props.onClick();
      assert.ok(selected);
      assert.equal(typeof selected, 'string');
    }
  }
});

for (const tab of ['calls', 'discover', 'contacts']) {
  test(`${tab} shows its own overview even with an existing active conversation`, () => {
    const render = loadComponent('src/components/layout/AppLayout.tsx', { activeChat: 'hii', blockedUsers: new Set() }, { width: 1280, initialTab: tab });
    let tree = elements(render('AppLayout'));
    const welcome = tree.find((node) => node.type === 'TabWelcome');
    assert.equal(welcome.props.tab, tab);
    assert.equal(typeof welcome.props.onAction, 'function');
    if (tab === 'calls') {
      welcome.props.onAction();
      tree = elements(render('AppLayout'));
      assert.ok(tree.some((node) => node.type === 'ContactsPanel'));
    }
    if (tab === 'contacts') {
      welcome.props.onAction();
      tree = elements(render('AppLayout'));
      assert.equal(tree.find((node) => node.type === 'ContactsPanel').props.addRequest, 1);
    }
  });
}

for (const width of [360, 768, 1280]) {
  test(`settings retains section navigation and mobile back at ${width}px`, () => {
    const render = loadComponent('src/components/layout/AppLayout.tsx', { activeChat: null, blockedUsers: new Set() }, { width, initialTab: 'settings' });
    let tree = elements(render('AppLayout'));
    const panel = tree.find((node) => node.type === 'SettingsPanel');
    panel.props.onSelectCategory('appearance', 'appear-font');
    tree = elements(render('AppLayout'));
    const sections = tree.find((node) => node.type === 'SettingsSubPanel');
    assert.equal(sections.props.activeCategory, 'appearance');
    assert.equal(sections.props.activeSubSection, 'appear-font');
    if (width <= 768) {
      const workspace = () => tree.find((node) => node.props.className?.includes('workspace-pane'));
      assert.equal(workspace().props.style.display, 'flex');
      sections.props.onBack();
      tree = elements(render('AppLayout'));
      assert.equal(workspace().props.style.display, 'none');
    }
  });
  test(`Contacts navigation reveals an already-selected conversation at ${width}px`, () => {
    const render = loadComponent('src/components/layout/AppLayout.tsx', {
      activeChat: 'hii',
      blockedUsers: new Set(),
    }, { width, initialTab: 'contacts' });
    const before = elements(render('AppLayout'));
    const contacts = before.find((element) => element.type === 'ContactsPanel');
    assert.equal(typeof contacts.props.onOpenChat, 'function');
    contacts.props.onOpenChat();
    const after = elements(render('AppLayout'));
    assert.equal(after.find((element) => element.type === 'Sidebar').props.activeTab, 'chats');
    assert.ok(after.some((element) => element.type === 'ChatList'));
    assert.ok(!after.some((element) => element.type === 'ContactsPanel'));
    if (width <= 768) {
      const panes = after.filter((element) => element.props.className?.includes('sm-flex-always'));
      assert.equal(panes[0].props.style.display, 'none');
      assert.equal(panes[1].props.style.display, 'flex');
    }
  });
}
