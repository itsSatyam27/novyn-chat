import { useEffect, useRef } from 'react';
import { useBrowserPreference } from '../../services/browserPreferences';
import data from './regionGlobeData.json';

const regions: Record<string, { id: number; name: string; longitude: number; latitude: number }> = {
  IN: { id: 1, name: 'India', longitude: 79, latitude: 22 },
  US: { id: 2, name: 'United States', longitude: -98, latitude: 39 },
  GB: { id: 3, name: 'United Kingdom', longitude: -3, latitude: 55 },
};
const radians = Math.PI / 180;
const vector = (longitude: number, latitude: number) => {
  const lat = latitude * radians, lon = longitude * radians;
  return [Math.cos(lat) * Math.cos(lon), Math.sin(lat), Math.cos(lat) * Math.sin(lon)];
};
const land = data.points.map(([lon, lat, id]) => ({ point: vector(lon, lat), id }));
const outlines = data.outlines.map(outline => ({ id: outline.id,
  rings: outline.rings.map(ring => ring.map(([lon, lat]) => vector(lon, lat))),
}));
const graticules: number[][][] = [];
for (let lat = -60; lat <= 60; lat += 30) {
  graticules.push(Array.from({ length: 121 }, (_, i) => vector(i * 3 - 180, lat)));
}
for (let lon = -180; lon < 180; lon += 30) {
  graticules.push(Array.from({ length: 61 }, (_, i) => vector(lon, i * 3 - 90)));
}

export function RegionGlobe({ region }: { region: string }) {
  const selected = regions[region] || regions.IN;
  const canvas = useRef<HTMLCanvasElement>(null);
  const view = useRef({ longitude: selected.longitude - 42, latitude: selected.latitude - 8 });
  const reduced = useBrowserPreference('novyn_reduce_motion', 'false') === 'true';

  useEffect(() => {
    const element = canvas.current;
    const ctx = element?.getContext('2d');
    if (!element || !ctx) return;
    const density = Math.min(window.devicePixelRatio || 1, 2);
    element.width = 400 * density;
    element.height = 300 * density;
    ctx.setTransform(density, 0, 0, density, 0, 0);
    const motion = window.matchMedia('(prefers-reduced-motion: reduce)');
    const start = { ...view.current };
    const target = { longitude: selected.longitude - 12, latitude: selected.latitude - 8 };
    const delta = ((target.longitude - start.longitude + 540) % 360) - 180;
    let frame = 0;
    const began = performance.now();

    const draw = () => {
      const lon = view.current.longitude * radians, lat = view.current.latitude * radians;
      const sinLon = Math.sin(lon), cosLon = Math.cos(lon), sinLat = Math.sin(lat), cosLat = Math.cos(lat);
      const project = ([x, y, z]: number[]) => {
        const depth = x * cosLon + z * sinLon;
        return { x: 200 + 124 * (z * cosLon - x * sinLon),
          y: 146 - 124 * (y * cosLat - depth * sinLat), z: y * sinLat + depth * cosLat };
      };
      ctx.clearRect(0, 0, 400, 300);
      const halo = ctx.createRadialGradient(200, 146, 116, 200, 146, 150);
      halo.addColorStop(0, '#8464ff00'); halo.addColorStop(.35, '#8666ff40'); halo.addColorStop(1, '#8666ff00');
      ctx.fillStyle = halo; ctx.fillRect(0, 0, 400, 300);
      ctx.save();
      ctx.beginPath(); ctx.arc(200, 146, 124, 0, Math.PI * 2); ctx.clip();
      const ocean = ctx.createRadialGradient(151, 80, 8, 209, 165, 168);
      ocean.addColorStop(0, '#343369'); ocean.addColorStop(.52, '#191e43'); ocean.addColorStop(1, '#070c1c');
      ctx.fillStyle = ocean; ctx.fillRect(70, 16, 260, 260);
      ctx.strokeStyle = '#9d9ae51a'; ctx.lineWidth = .65;
      for (const line of graticules) {
        ctx.beginPath(); let connected = false;
        for (const point of line) {
          const p = project(point);
          if (p.z <= 0) { connected = false; continue; }
          if (connected) ctx.lineTo(p.x, p.y); else ctx.moveTo(p.x, p.y);
          connected = true;
        }
        ctx.stroke();
      }
      // A single path per color keeps rotation inexpensive on mobile GPUs.
      for (const highlighted of [false, true]) {
        ctx.beginPath();
        for (const point of land) {
          if ((point.id === selected.id) !== highlighted) continue;
          const p = project(point.point);
          if (p.z <= 0) continue;
          const radius = (.55 + p.z * .6) * (highlighted ? 1.15 : 1);
          ctx.moveTo(p.x + radius, p.y); ctx.arc(p.x, p.y, radius, 0, Math.PI * 2);
        }
        ctx.fillStyle = highlighted ? '#7df9e4' : '#aaa4ed'; ctx.fill();
      }
      ctx.shadowColor = '#36e8d5'; ctx.shadowBlur = 12;
      ctx.fillStyle = '#24dbc13d'; ctx.strokeStyle = '#86ffed'; ctx.lineWidth = 1;
      for (const outline of outlines) {
        if (outline.id !== selected.id) continue;
        const rings = outline.rings.map(ring => ring.map(project));
        // Dots remain visible at the horizon while a polygon turns into view.
        if (rings.some(ring => ring.some(p => p.z <= .015))) continue;
        ctx.beginPath();
        for (const ring of rings) {
          ring.forEach((p, index) => index ? ctx.lineTo(p.x, p.y) : ctx.moveTo(p.x, p.y));
          ctx.closePath();
        }
        ctx.fill('evenodd'); ctx.stroke();
      }
      ctx.shadowBlur = 0;
      const pin = project(vector(selected.longitude, selected.latitude));
      if (pin.z > 0) {
        const glow = ctx.createRadialGradient(pin.x, pin.y, 2, pin.x, pin.y, 22);
        glow.addColorStop(0, '#56ffe8aa'); glow.addColorStop(1, '#56ffe800');
        ctx.fillStyle = glow; ctx.beginPath(); ctx.arc(pin.x, pin.y, 22, 0, Math.PI * 2); ctx.fill();
        ctx.strokeStyle = '#94fff1aa'; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.arc(pin.x, pin.y, 8, 0, Math.PI * 2); ctx.stroke();
        ctx.fillStyle = '#effffb'; ctx.beginPath(); ctx.arc(pin.x, pin.y, 3, 0, Math.PI * 2); ctx.fill();
      }
      ctx.restore();
      ctx.strokeStyle = '#aaa0ff55'; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.arc(200, 146, 124, 0, Math.PI * 2); ctx.stroke();
    };
    const animate = (time: number) => {
      const progress = reduced || motion.matches || document.hidden ? 1 : Math.min(1, (time - began) / 1100);
      const eased = 1 - Math.pow(1 - progress, 3);
      view.current = { longitude: start.longitude + delta * eased, latitude: start.latitude + (target.latitude - start.latitude) * eased };
      draw();
      if (progress < 1) frame = requestAnimationFrame(animate);
    };
    const settle = () => { cancelAnimationFrame(frame); view.current = target; draw(); };
    frame = requestAnimationFrame(animate);
    motion.addEventListener('change', settle);
    document.addEventListener('visibilitychange', settle);
    return () => { cancelAnimationFrame(frame); motion.removeEventListener('change', settle); document.removeEventListener('visibilitychange', settle); };
  }, [selected, reduced]);

  return <figure className="region-globe" data-region={region in regions ? region : 'IN'}>
    <canvas ref={canvas} width={400} height={300} role="img" aria-label={'3D globe highlighting ' + selected.name} />
    <figcaption><i aria-hidden="true" />{selected.name}<span>Selected region</span></figcaption>
  </figure>;
}
