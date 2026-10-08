# Region globe data

`regionGlobeData.json` contains sampled land points and simplified country outlines
derived from Natural Earth's public-domain 1:110m Admin 0 countries dataset.

- Source: https://github.com/nvkelso/natural-earth-vector/blob/master/geojson/ne_110m_admin_0_countries.geojson
- License: https://www.naturalearthdata.com/about/terms-of-use/
- Regenerate: `node scripts/generate-region-globe.cjs path/to/ne_110m_admin_0_countries.geojson`

The compact dataset ships with the settings code; rendering does not contact a
map service or send the selected region anywhere. This is a stylized regional
format preview, not a location detector or authoritative boundary map.
