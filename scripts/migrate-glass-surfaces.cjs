// One-time mechanical migration of presentation literals to shared theme tokens.
// Only inline style values are changed; wallpaper presets, media, SVGs, and
// application behavior are deliberately left untouched.
const fs = require('node:fs');
const path = require('node:path');
const ts = require('typescript');
const root = path.resolve(__dirname, '..');
const darkSurfaces = /#(?:030712|070a11|090d16|0b0f19|101624|111827|0f172a|161f30|0c121e|0d131f|131b2e|0b1120|151d2e|1b263b|1c2431|151d2c|020617)\b/gi;
const neutralText = new Map([
  ['#ffffff', 'var(--text-main)'], ['#fff', 'var(--text-main)'], ['white', 'var(--text-main)'],
  ['#f8fafc', 'var(--text-main)'], ['#e2e8f0', 'var(--text-main)'], ['#f1f5f9', 'var(--text-main)'],
  ['#cbd5e1', 'var(--text-muted)'], ['#94a3b8', 'var(--text-muted)'],
  ['#64748b', 'var(--text-dark)'], ['#475569', 'var(--text-dark)'],
]);
const contrastText = new Map([
  ['#10b981', '#0e9f8a'], ['#34d399', '#078779'], ['#6ee7b7', '#08745f'],
  ['#38bdf8', '#087fac'], ['#60a5fa', '#2569b2'], ['#fbbf24', '#a0690b'],
  ['#f59e0b', '#a86d0b'], ['#f87171', '#bd3750'], ['#fca5a5', '#ac3049'],
  ['#c084fc', '#8651b3'],
]);
function transform(value, property, onAccent = false) {
  if (/^(color|stroke|fill)$/i.test(property)) {
    if (onAccent && ['#fff', '#ffffff', 'white'].includes(value.toLowerCase())) return 'var(--text-on-primary)';
    if (neutralText.has(value.toLowerCase())) return neutralText.get(value.toLowerCase());
    if (contrastText.has(value.toLowerCase())) return contrastText.get(value.toLowerCase());
    return value.replace(/rgba\(255,\s*255,\s*255,\s*([.\d]+)\)/g, (_, a) => `rgba(20, 52, 63, ${Math.max(0.45, Number(a))})`);
  }
  if (/^background(?:Color)?$/i.test(property)) {
    return value.replace(darkSurfaces, 'var(--bg-surface)')
      .replace(/rgba\((?:3,\s*7,\s*18|7,\s*10,\s*17|9,\s*13,\s*22|11,\s*15,\s*25|15,\s*23,\s*42|16,\s*22,\s*36|17,\s*24,\s*39),\s*([.\d]+)\)/g, 'rgba(247, 254, 253, $1)')
      .replace(/rgba\(255,\s*255,\s*255,\s*([.\d]+)\)/g, (_, a) => `rgba(255, 255, 255, ${Math.max(0.55, Number(a))})`)
      .replace(/rgba\(0,\s*0,\s*0,\s*([.\d]+)\)/g, (_, a) => `rgba(23, 66, 78, ${Math.min(0.12, Number(a) * 0.25)})`);
  }
  if (/^border/i.test(property)) return value.replace(darkSurfaces, '#e4f0f0').replace(/rgba\(255,\s*255,\s*255,\s*[.\d]+\)/g, 'var(--border)');
  if (/shadow/i.test(property)) return value.replace(/rgba\(0,\s*0,\s*0,\s*[.\d]+\)/g, 'rgba(36, 76, 96, 0.1)');
  return value;
}
function walk(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const filename = path.join(directory, entry.name);
    return entry.isDirectory() ? walk(filename) : [filename];
  });
}
let changed = 0;
for (const filename of walk(path.join(root, 'src/components')).filter((file) => file.endsWith('.tsx'))) {
  if (filename.endsWith('Avatar.tsx')) continue;
  const source = fs.readFileSync(filename, 'utf8');
  const tree = ts.createSourceFile(filename, source, ts.ScriptTarget.Latest, true, ts.ScriptKind.TSX);
  const edits = [];
  function visit(node) {
    if (ts.isStringLiteral(node)) {
      let current = node.parent;
      let property;
      let object;
      let inStyle = false;
      while (current) {
        if (!property && ts.isPropertyAssignment(current)) { property = current.name.getText(tree); object = current.parent; }
        if (ts.isJsxAttribute(current) && current.name.getText(tree) === 'style') { inStyle = true; break; }
        if (ts.isBinaryExpression(current) && /\.style\.(color|background|borderColor)$/.test(current.left.getText(tree))) {
          property = current.left.getText(tree).split('.').at(-1); inStyle = true; break;
        }
        current = current.parent;
      }
      if (inStyle && property) {
        const bg = object?.properties?.find((p) => p.name && /^(background|backgroundColor)$/.test(p.name.getText(tree)))?.initializer;
        const onAccent = bg && ts.isStringLiteral(bg) && /#(?:10b981|059669|ef4444|ec4899|8b5cf6)|var\(--primary\)/i.test(bg.text);
        const replacement = transform(node.text, property, onAccent);
        if (replacement !== node.text) edits.push({ start: node.getStart(tree) + 1, end: node.end - 1, text: replacement });
      }
    }
    ts.forEachChild(node, visit);
  }
  visit(tree);
  let next = source;
  for (const edit of edits.sort((a, b) => b.start - a.start)) next = next.slice(0, edit.start) + edit.text + next.slice(edit.end);
  if (next !== source) { fs.writeFileSync(filename, next); changed++; }
}
console.log(`Updated theme tokens in ${changed} component files.`);
