// Shared Three.js aurora field background for login + chat
(function initAurora() {
  const prefersReduced = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const lowMemory = typeof navigator !== "undefined" && navigator.deviceMemory && navigator.deviceMemory <= 4;
  const saveData = typeof navigator !== "undefined" && navigator.connection && navigator.connection.saveData;
  const isSmallScreen = Math.min(window.innerWidth, window.innerHeight) <= 820;
  if (prefersReduced || lowMemory || saveData || isSmallScreen) return;

  const canvas = document.getElementById("bgScene") || document.getElementById("bgCanvas");
  if (!canvas || !window.THREE) return;

  const renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.8));
  renderer.setSize(window.innerWidth, window.innerHeight);
  renderer.setClearColor(0x000000, 0);

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(55, window.innerWidth / window.innerHeight, 0.1, 3000);
  camera.position.set(0, 0, 520);

  // Aurora ribbon geometry
  const ribbonCount = 5;
  const ribbonSegments = 240;
  const ribbonWidth = 46;
  const ribbons = [];
  const colorStops = [0xf5a623, 0xc0623a, 0xe8b86d, 0x6aab80];

  for (let r = 0; r < ribbonCount; r++) {
    const geo = new THREE.BufferGeometry();
    const positions = new Float32Array((ribbonSegments + 1) * 3);
    const colors = new Float32Array((ribbonSegments + 1) * 3);
    geo.setAttribute("position", new THREE.BufferAttribute(positions, 3));
    geo.setAttribute("color", new THREE.BufferAttribute(colors, 3));
    const mat = new THREE.LineBasicMaterial({
      vertexColors: true,
      transparent: true,
      opacity: 0.50,
      linewidth: 1.6,
    });
    const line = new THREE.Line(geo, mat);
    line.userData = {
      phase: Math.random() * Math.PI * 2,
      speed: 0.0008 + Math.random() * 0.0008,
      amp: 120 + Math.random() * 90,
      hue: colorStops[r % colorStops.length],
      yOff: (r - ribbonCount / 2) * ribbonWidth * 0.6,
      zJitter: 30 + Math.random() * 30,
    };
    ribbons.push(line);
    scene.add(line);
  }

  // Floating particles
  const particleCount = 260;
  const particleGeo = new THREE.BufferGeometry();
  const particlePos = new Float32Array(particleCount * 3);
  const particleCol = new Float32Array(particleCount * 3);
  for (let i = 0; i < particleCount; i++) {
    particlePos[i * 3] = (Math.random() - 0.5) * window.innerWidth * 1.4;
    particlePos[i * 3 + 1] = (Math.random() - 0.5) * window.innerHeight * 1.4;
    particlePos[i * 3 + 2] = (Math.random() - 0.5) * 600;
    const c = new THREE.Color(colorStops[i % colorStops.length]);
    c.multiplyScalar(0.6 + Math.random() * 0.4);
    particleCol[i * 3] = c.r;
    particleCol[i * 3 + 1] = c.g;
    particleCol[i * 3 + 2] = c.b;
  }
  particleGeo.setAttribute("position", new THREE.BufferAttribute(particlePos, 3));
  particleGeo.setAttribute("color", new THREE.BufferAttribute(particleCol, 3));
  const particleMat = new THREE.PointsMaterial({
    size: 6,
    transparent: true,
    opacity: 0.40,
    vertexColors: true,
    depthWrite: false,
  });
  const particles = new THREE.Points(particleGeo, particleMat);
  scene.add(particles);

  let mouseX = 0,
    mouseY = 0;
  window.addEventListener("mousemove", (e) => {
    mouseX = (e.clientX / window.innerWidth - 0.5) * 2;
    mouseY = (e.clientY / window.innerHeight - 0.5) * -2;
  });

  window.addEventListener("resize", () => {
    renderer.setSize(window.innerWidth, window.innerHeight);
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
  });

  const tmpColor = new THREE.Color();
  function render(time) {
    requestAnimationFrame(render);

    camera.position.x += (mouseX * 60 - camera.position.x) * 0.03;
    camera.position.y += (mouseY * 40 - camera.position.y) * 0.03;
    camera.lookAt(0, 0, 0);

    ribbons.forEach((line, idx) => {
      const { phase, speed, amp, hue, yOff, zJitter } = line.userData;
      const positions = line.geometry.attributes.position.array;
      const colors = line.geometry.attributes.color.array;
      for (let i = 0; i <= ribbonSegments; i++) {
        const t = (i / ribbonSegments) * Math.PI * 2;
        const x = Math.cos(t + time * speed + phase) * amp;
        const y = Math.sin(t * 0.8 + phase * 0.5) * 40 + yOff;
        const z = Math.sin(t * 1.6 + phase) * zJitter;
        positions[i * 3] = x;
        positions[i * 3 + 1] = y;
        positions[i * 3 + 2] = z;

        tmpColor.setHSL(((idx * 0.12 + time * 0.00008 + i / ribbonSegments) % 1), 0.65, 0.55);
        tmpColor.multiplyScalar(0.9);
        colors[i * 3] = tmpColor.r;
        colors[i * 3 + 1] = tmpColor.g;
        colors[i * 3 + 2] = tmpColor.b;
      }
      line.geometry.attributes.position.needsUpdate = true;
      line.geometry.attributes.color.needsUpdate = true;
    });

    const pPos = particles.geometry.attributes.position.array;
    for (let i = 0; i < particleCount; i++) {
      pPos[i * 3 + 2] += 0.5;
      if (pPos[i * 3 + 2] > 300) pPos[i * 3 + 2] = -300;
    }
    particles.geometry.attributes.position.needsUpdate = true;

    renderer.render(scene, camera);
  }
  requestAnimationFrame(render);
})();
