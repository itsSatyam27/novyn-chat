// Original notification tones. Run with node scripts/generate-chimes.cjs.
const fs = require('node:fs');
const path = require('node:path');
const rate = 22050;
const chimes = {
  pulse: { seconds: .55, notes: [[0, 660, .16, .6], [.2, 660, .2, .5]] },
  glass: { seconds: .85, notes: [[0, 1046.5, .65, .48], [.08, 1568, .65, .2]] },
  echo: { seconds: 1.15, notes: [[0, 523.25, .3, .5], [.15, 783.99, .3, .45], [.4, 523.25, .3, .22], [.55, 783.99, .4, .18]] },
};
for (const [name, { seconds, notes }] of Object.entries(chimes)) {
  const samples = Math.ceil(rate * seconds);
  const wav = Buffer.alloc(44 + samples * 2);
  wav.write('RIFF'); wav.writeUInt32LE(wav.length - 8, 4); wav.write('WAVEfmt ', 8);
  wav.writeUInt32LE(16, 16); wav.writeUInt16LE(1, 20); wav.writeUInt16LE(1, 22);
  wav.writeUInt32LE(rate, 24); wav.writeUInt32LE(rate * 2, 28);
  wav.writeUInt16LE(2, 32); wav.writeUInt16LE(16, 34); wav.write('data', 36);
  wav.writeUInt32LE(samples * 2, 40);
  for (let i = 0; i < samples; i++) {
    const time = i / rate;
    let sample = 0;
    for (const [start, frequency, duration, amplitude] of notes) {
      const t = time - start;
      if (t < 0 || t >= duration) continue;
      const envelope = Math.min(t / .008, 1) * Math.exp(-5 * t / duration) * Math.min((duration - t) / .025, 1);
      sample += Math.sin(2 * Math.PI * frequency * t) * envelope * amplitude;
    }
    wav.writeInt16LE(Math.round(Math.max(-1, Math.min(1, sample)) * 32767), 44 + i * 2);
  }
  fs.writeFileSync(path.join(__dirname, '../apps/web/public/audio', `chime-${name}.wav`), wav);
}
