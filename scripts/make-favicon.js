const fs = require('fs');
const iconB64 = fs.readFileSync('apps/web/public/icons/novyn-app-icon.png').toString('base64');

const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
  <image href="data:image/png;base64,${iconB64}" width="1024" height="1024" />
</svg>`;

fs.writeFileSync('apps/web/public/favicon.svg', svg);
fs.writeFileSync('apps/web/public/icons/novyn-badge.svg', svg);
console.log('Saved public/favicon.svg and novyn-badge.svg successfully!');
