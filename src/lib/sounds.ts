// Sound-Effekte via Web Audio API
// Keine externen Dateien — alles wird programmatisch generiert

import { isSoundEnabled, isMusicEnabled } from './settings';

let audioCtx: AudioContext | null = null;
let bgMusicNodes: { osc: OscillatorNode; gain: GainNode; lfo: OscillatorNode; lfoGain: GainNode } | null = null;

function getAudioContext(): AudioContext {
  if (!audioCtx) {
    audioCtx = new AudioContext();
  }
  if (audioCtx.state === 'suspended') {
    audioCtx.resume();
  }
  return audioCtx;
}

// Hilfsfunktion: White Noise Buffer erstellen
function createNoiseBuffer(ctx: AudioContext): AudioBuffer {
  const bufferSize = ctx.sampleRate * 0.1; // 100ms
  const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
  const data = buffer.getChannelData(0);
  for (let i = 0; i < bufferSize; i++) {
    data[i] = Math.random() * 2 - 1;
  }
  return buffer;
}

// Hintergrundmusik starten — leises Casino-Ambiente
export function startBackgroundMusic() {
  if (!isMusicEnabled() || bgMusicNodes) return;
  try {
    const ctx = getAudioContext();

    // Hauptoszillator — sehr tiefer, warmer Ton
    const osc = ctx.createOscillator();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(55, ctx.currentTime); // A1

    // LFO für sanfte Frequenz-Modulation
    const lfo = ctx.createOscillator();
    lfo.type = 'sine';
    lfo.frequency.setValueAtTime(0.1, ctx.currentTime); // 0.1 Hz

    const lfoGain = ctx.createGain();
    lfoGain.gain.setValueAtTime(3, ctx.currentTime);

    // Haupt-Gain — sehr leise
    const gain = ctx.createGain();
    gain.gain.setValueAtTime(0, ctx.currentTime);
    gain.gain.linearRampToValueAtTime(0.015, ctx.currentTime + 2);

    lfo.connect(lfoGain);
    lfoGain.connect(osc.frequency);
    osc.connect(gain);
    gain.connect(ctx.destination);

    osc.start();
    lfo.start();

    bgMusicNodes = { osc, gain, lfo, lfoGain };
  } catch {
    // ignore
  }
}

// Hintergrundmusik stoppen
export function stopBackgroundMusic() {
  if (!bgMusicNodes || !audioCtx) return;
  try {
    const now = audioCtx.currentTime;
    bgMusicNodes.gain.gain.setValueAtTime(bgMusicNodes.gain.gain.value, now);
    bgMusicNodes.gain.gain.linearRampToValueAtTime(0, now + 1);

    setTimeout(() => {
      if (bgMusicNodes) {
        bgMusicNodes.osc.stop();
        bgMusicNodes.lfo.stop();
        bgMusicNodes = null;
      }
    }, 1100);
  } catch {
    bgMusicNodes = null;
  }
}

// Karte ziehen — sanfter Swish
export function playCardDraw() {
  if (!isSoundEnabled()) return;
  try {
    const ctx = getAudioContext();
    const noise = ctx.createBufferSource();
    noise.buffer = createNoiseBuffer(ctx);

    const filter = ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.setValueAtTime(800, ctx.currentTime);
    filter.frequency.exponentialRampToValueAtTime(200, ctx.currentTime + 0.15);

    const gain = ctx.createGain();
    gain.gain.setValueAtTime(0.08, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.15);

    noise.connect(filter);
    filter.connect(gain);
    gain.connect(ctx.destination);
    noise.start();
    noise.stop(ctx.currentTime + 0.15);
  } catch {
    // Audio nicht verfügbar — stumm bleiben
  }
}

// Karte ablegen — kurzer Plop
export function playCardPlace() {
  if (!isSoundEnabled()) return;
  try {
    const ctx = getAudioContext();
    const osc = ctx.createOscillator();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(300, ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(80, ctx.currentTime + 0.08);

    const gain = ctx.createGain();
    gain.gain.setValueAtTime(0.12, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.08);

    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start();
    osc.stop(ctx.currentTime + 0.08);
  } catch {
    // stumm
  }
}

// Karte umdrehen — schneller Flip
export function playCardFlip() {
  if (!isSoundEnabled()) return;
  try {
    const ctx = getAudioContext();
    const osc = ctx.createOscillator();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(600, ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(1200, ctx.currentTime + 0.06);

    const gain = ctx.createGain();
    gain.gain.setValueAtTime(0.06, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.06);

    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start();
    osc.stop(ctx.currentTime + 0.06);
  } catch {
    // stumm
  }
}

// Dame Call — Alarm-Ton
export function playDameCall() {
  if (!isSoundEnabled()) return;
  try {
    const ctx = getAudioContext();
    const now = ctx.currentTime;

    for (let i = 0; i < 3; i++) {
      const osc = ctx.createOscillator();
      osc.type = 'square';
      osc.frequency.setValueAtTime(880, now + i * 0.12);
      osc.frequency.setValueAtTime(660, now + i * 0.12 + 0.06);

      const gain = ctx.createGain();
      gain.gain.setValueAtTime(0.08, now + i * 0.12);
      gain.gain.exponentialRampToValueAtTime(0.001, now + i * 0.12 + 0.1);

      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(now + i * 0.12);
      osc.stop(now + i * 0.12 + 0.1);
    }
  } catch {
    // stumm
  }
}

// Sieges-Fanfare
export function playWinSound() {
  if (!isSoundEnabled()) return;
  try {
    const ctx = getAudioContext();
    const now = ctx.currentTime;
    const notes = [523, 659, 784, 1047]; // C5, E5, G5, C6

    notes.forEach((freq, i) => {
      const osc = ctx.createOscillator();
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(freq, now + i * 0.12);

      const gain = ctx.createGain();
      gain.gain.setValueAtTime(0, now + i * 0.12);
      gain.gain.linearRampToValueAtTime(0.1, now + i * 0.12 + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.001, now + i * 0.12 + 0.35);

      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(now + i * 0.12);
      osc.stop(now + i * 0.12 + 0.35);
    });
  } catch {
    // stumm
  }
}

// Strafkarte — negativer Ton
export function playPenaltySound() {
  if (!isSoundEnabled()) return;
  try {
    const ctx = getAudioContext();
    const osc = ctx.createOscillator();
    osc.type = 'sawtooth';
    osc.frequency.setValueAtTime(200, ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(100, ctx.currentTime + 0.2);

    const gain = ctx.createGain();
    gain.gain.setValueAtTime(0.08, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.2);

    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start();
    osc.stop(ctx.currentTime + 0.2);
  } catch {
    // stumm
  }
}
