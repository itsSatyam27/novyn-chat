const fs = require('fs');
const whiteB64 = fs.readFileSync('apps/web/public/icons/novyn-wings-white.png').toString('base64');

const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="100" height="100">
  <defs>
    <linearGradient id="badgeGrad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#10b981" />
      <stop offset="100%" stop-color="#059669" />
    </linearGradient>
    <filter id="glow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="2" stdDeviation="3" flood-color="#047857" flood-opacity="0.4"/>
    </filter>
  </defs>
  
  <!-- Rounded Badge -->
  <rect width="100" height="100" rx="24" fill="url(#badgeGrad)" />
  
  <!-- White Wings Center -->
  <image href="data:image/png;base64,${whiteB64}" x="12" y="12" width="76" height="76" filter="url(#glow)" />
</svg>`;

fs.writeFileSync('apps/web/public/favicon.svg', svg);
fs.writeFileSync('apps/web/public/icons/novyn-badge.svg', svg);
console.log('Saved public/favicon.svg and novyn-badge.svg successfully!');
