// Usage: node scripts/generate-region-globe.cjs <Natural Earth countries.geojson>
// Public-domain source: https://github.com/nvkelso/natural-earth-vector
// Dataset: geojson/ne_110m_admin_0_countries.geojson (Natural Earth 1:110m).
const fs = require('node:fs');
const path = require('node:path');
const source = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const ids = { IND: 1, USA: 2, GBR: 3 };
const inside = (x, y, ring) => {
  let hit = false;
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    const [xi, yi] = ring[i], [xj, yj] = ring[j];
    if ((yi > y) !== (yj > y) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) hit = !hit;
  }
  return hit;
};
const polygons = source.features.flatMap(feature => {
  const id = ids[feature.properties.ADM0_A3] || 0;
  const shapes = feature.geometry.type === 'Polygon' ? [feature.geometry.coordinates] : feature.geometry.coordinates;
  return shapes.map(rings => ({ id, rings, bounds: rings[0].reduce((b, [x, y]) =>
    [Math.min(b[0], x), Math.min(b[1], y), Math.max(b[2], x), Math.max(b[3], y)], [180, 90, -180, -90]) }));
});
const points = [];
for (let lat = -80; lat <= 84; lat += 1.7) {
  const spacing = 1.7 / Math.cos(lat * Math.PI / 180);
  for (let lon = -180; lon < 180; lon += spacing) {
    const land = polygons.find(({ rings, bounds: b }) => lon >= b[0] && lon <= b[2] && lat >= b[1] && lat <= b[3]
      && inside(lon, lat, rings[0]) && !rings.slice(1).some(ring => inside(lon, lat, ring)));
    if (land) points.push([+lon.toFixed(2), +lat.toFixed(2), land.id]);
  }
}
const outlines = polygons.filter(p => p.id).map(p => ({ id: p.id, rings: p.rings.map(r => r.map(([x, y]) => [+x.toFixed(2), +y.toFixed(2)])) }));
const destination = path.join(__dirname, '../apps/web/src/components/settings/regionGlobeData.json');
fs.writeFileSync(destination, JSON.stringify({ points, outlines }) + '\n');
console.log(`Generated ${points.length} land points and ${outlines.length} selected-country polygons.`);
