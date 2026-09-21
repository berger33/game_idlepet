#!/usr/bin/env python3
"""Trilhas de fundo (BGM) por capítulo — fonte única de `audio/bgm/*.wav`.

Auditoria de retenção (§3): a música era um loop procedural de 8 s de acordes
sintetizado no boot. Aqui três composições de 16 compassos (40 s, loop sem
emenda), todas a 96 BPM — o MESMO andamento de `AudioManager.MUSIC_BPM`, porque
o pulso visual da cena lê a posição real da música:

  quintal  -> violão dedilhado (Karplus-Strong), baixo macio, chocalho e
              melodia de ocarina pentatônica: manhã no quintal.
  clinica  -> piano elétrico com sétimas, pad quente, hi-hat de escova e
              marimba: sala de espera moderna e calma.
  imperio  -> bossa: violão de náilon sincopado, baixo em 1 e "e" de 2,
              rim click e marimba com swing: a rede consolidada.

22,05 kHz mono 16 bits (~1,8 MB por faixa). As caudas das notas dão a volta
(soma circular) para o loop fechar sem clique. Determinístico por semente.

Uso:
  python tools/gen_bgm.py           # gera audio/bgm/*.wav
  python tools/gen_bgm.py --check   # valida estrutura (duração, pico, BPM)
"""
from __future__ import annotations

import math
import sys
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "audio" / "bgm"
SR = 22050
BPM = 96.0
BEAT = 60.0 / BPM
BAR = BEAT * 4.0
BARS = 16
LOOP_SECONDS = BAR * BARS
LOOP_FRAMES = int(round(LOOP_SECONDS * SR))
PEAK = 0.6

NOTE = {n: i for i, n in enumerate(["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}


def hz(name: str, octave: int) -> float:
    return 440.0 * 2.0 ** ((NOTE[name] - 9) / 12.0 + (octave - 4))


def chord(root: str, quality: str, octave: int = 3) -> list[float]:
    intervals = {
        "maj": [0, 4, 7], "min": [0, 3, 7], "maj7": [0, 4, 7, 11], "min7": [0, 3, 7, 10],
        "dom7": [0, 4, 7, 10], "maj9": [0, 4, 7, 11, 14],
    }[quality]
    base = hz(root, octave)
    return [base * 2.0 ** (i / 12.0) for i in intervals]


# ---------------------------------------------------------------- instrumentos
def env(n: int, attack: float, decay: float, sustain: float = 0.0) -> np.ndarray:
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0.0, 1.0)
    d = sustain + (1.0 - sustain) * np.exp(-t / max(decay, 1e-4))
    return a * d


def pluck(freq: float, dur: float, rng: np.random.Generator, dark: float = 0.5) -> np.ndarray:
    """Karplus-Strong vetorizado por período: violão/náilon."""
    n = int(dur * SR)
    period = max(2, int(round(SR / freq)))
    buf = rng.uniform(-1.0, 1.0, period)
    buf -= buf.mean()
    out = np.zeros(n + period)
    out[:period] = buf
    prev = buf
    pos = period
    decay = 0.996 - 0.004 * dark
    while pos < n:
        nxt = decay * (prev * (1.0 - dark) + np.roll(prev, 1) * dark)
        out[pos:pos + period] = nxt
        prev = nxt
        pos += period
    return out[:n] * env(n, 0.002, dur * 0.6, 0.0)


def epiano(freq: float, dur: float) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    tone = (
        np.sin(2 * np.pi * freq * t)
        + 0.35 * np.sin(2 * np.pi * freq * 2 * t) * np.exp(-t * 3.0)
        + 0.12 * np.sin(2 * np.pi * freq * 3 * t) * np.exp(-t * 5.0)
    )
    tremolo = 1.0 + 0.06 * np.sin(2 * np.pi * 4.5 * t)
    return tone * tremolo * env(n, 0.006, dur * 0.7, 0.05)


def marimba(freq: float, dur: float) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    tone = np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(2 * np.pi * freq * 4.0 * t) * np.exp(-t * 18.0)
    return tone * env(n, 0.003, 0.25, 0.0)


def ocarina(freq: float, dur: float) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    vib = freq * (1.0 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t * 2.0, 0.0, 1.0))
    phase = 2 * np.pi * np.cumsum(vib) / SR
    tone = np.sin(phase) + 0.18 * np.sin(2 * phase)
    return tone * env(n, 0.04, dur, 0.6) * np.clip((dur - t) / 0.08, 0.0, 1.0)


def bass(freq: float, dur: float, soft: bool = True) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    tone = np.sin(2 * np.pi * freq * t) + (0.25 if soft else 0.45) * np.sin(2 * np.pi * freq * 2 * t)
    tone += 0.1 * np.sign(np.sin(2 * np.pi * freq * t)) * np.exp(-t * 6.0)
    return tone * env(n, 0.01, dur * 0.8, 0.2)


def pad(freqs: list[float], dur: float) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for f in freqs:
        for detune in (0.997, 1.0, 1.003):
            out += np.sin(2 * np.pi * f * detune * t + 0.3 * math.sin(f))
    out /= len(freqs) * 3.0
    lfo = 0.85 + 0.15 * np.sin(2 * np.pi * 0.2 * t)
    return out * lfo * env(n, 0.4, dur * 2.0, 0.9)


def noise_hit(dur: float, rng: np.random.Generator, bright: float, gain: float) -> np.ndarray:
    n = int(dur * SR)
    noise = rng.normal(0.0, 1.0, n)
    kernel = max(1, int(round(6 - 5 * bright)))
    noise = np.convolve(noise, np.ones(kernel) / kernel, mode="same")
    return noise * env(n, 0.001, dur * 0.35, 0.0) * gain


def kick(dur: float = 0.25) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    freq = 55.0 + 60.0 * np.exp(-t * 30.0)
    return np.sin(2 * np.pi * np.cumsum(freq) / SR) * env(n, 0.001, 0.12, 0.0)


def rim(rng: np.random.Generator) -> np.ndarray:
    n = int(0.05 * SR)
    t = np.arange(n) / SR
    return (np.sin(2 * np.pi * 1800 * t) * 0.5 + rng.normal(0, 0.4, n)) * env(n, 0.0005, 0.02, 0.0)


# ------------------------------------------------------------------- montagem
class Track:
    def __init__(self, seed: int) -> None:
        self.buf = np.zeros(LOOP_FRAMES)
        self.rng = np.random.default_rng(seed)

    def add(self, sound: np.ndarray, at_seconds: float, gain: float = 1.0) -> None:
        start = int(round(at_seconds * SR)) % LOOP_FRAMES
        idx = (np.arange(len(sound)) + start) % LOOP_FRAMES  # caudas dão a volta: loop sem emenda
        np.add.at(self.buf, idx, sound * gain)

    def finish(self) -> np.ndarray:
        # Filtro de "sala": rolagem suave acima de ~3,2 kHz (FFT, sem fase),
        # tira o chiado dos ataques e do chocalho sem apagar o brilho.
        spectrum = np.fft.rfft(self.buf)
        freqs = np.fft.rfftfreq(len(self.buf), 1.0 / SR)
        spectrum *= 1.0 / (1.0 + (freqs / 3200.0) ** 4)
        out = np.fft.irfft(spectrum, n=len(self.buf))
        out -= out.mean()
        peak = float(np.max(np.abs(out))) or 1.0
        return out * (PEAK / peak)


def pentatonic_walk(rng: np.random.Generator, chord_tones: list[float], steps: int, prev: float) -> list[float]:
    scale = sorted({f * 2.0 for f in chord_tones} | {f * 4.0 for f in chord_tones[:2]})
    notes = []
    for _ in range(steps):
        candidates = sorted(scale, key=lambda f: abs(math.log(f / prev)))[:3]
        prev = candidates[rng.integers(0, len(candidates))]
        notes.append(prev)
    return notes


def build_quintal() -> np.ndarray:
    track = Track(seed=101)
    rng = track.rng
    progression = [("C", "maj"), ("A", "min"), ("F", "maj"), ("G", "maj")] * 2 + [
        ("C", "maj"), ("E", "min"), ("F", "maj"), ("G", "maj"), ("A", "min"), ("F", "maj"), ("G", "maj"), ("C", "maj")
    ]
    prev_melody = hz("E", 5)
    for bar, (root, quality) in enumerate(progression):
        t0 = bar * BAR
        tones = chord(root, quality, 3)
        pattern = [0, 2, 1, 2, 0, 2, 1, 2]  # dedilhado: grave, agudo, médio...
        for eighth, index in enumerate(pattern):
            freq = tones[index % len(tones)] * (2.0 if index else 1.0)
            track.add(pluck(freq, 1.1, rng, 0.45), t0 + eighth * BEAT / 2.0, 0.55 if eighth % 2 == 0 else 0.4)
        track.add(bass(tones[0] / 2.0, BEAT * 1.6), t0, 0.7)
        track.add(bass(tones[2] / 2.0, BEAT * 1.4), t0 + 2 * BEAT, 0.55)
        for eighth in range(8):
            accent = 1.0 if eighth % 2 == 0 else 0.55
            track.add(noise_hit(0.07, rng, 0.2, 0.08 * accent), t0 + eighth * BEAT / 2.0)
        if bar % 2 == 1:
            notes = pentatonic_walk(rng, tones, 3, prev_melody)
            prev_melody = notes[-1]
            for i, freq in enumerate(notes):
                track.add(ocarina(freq, BEAT * 0.9), t0 + BEAT * (1 + i), 0.28)
    return track.finish()


def build_clinica() -> np.ndarray:
    track = Track(seed=202)
    rng = track.rng
    progression = [("C", "maj7"), ("A", "min7"), ("D", "min7"), ("G", "dom7")] * 2 + [
        ("F", "maj7"), ("E", "min7"), ("D", "min7"), ("G", "dom7"), ("C", "maj7"), ("A", "min7"), ("F", "maj7"), ("G", "dom7")
    ]
    prev_melody = hz("G", 5)
    for bar, (root, quality) in enumerate(progression):
        t0 = bar * BAR
        tones = chord(root, quality, 3)
        track.add(pad([f / 2.0 for f in tones[:3]], BAR * 1.1), t0, 0.16)
        for beat in (0.0, 1.5, 2.0, 3.5):
            for freq in tones:
                track.add(epiano(freq, BEAT * 1.2), t0 + beat * BEAT, 0.16)
        walk = [tones[0] / 4.0, tones[2] / 4.0, tones[0] / 2.0, tones[2] / 4.0]
        for beat, freq in enumerate(walk):
            track.add(bass(freq, BEAT * 0.95, soft=True), t0 + beat * BEAT, 0.6)
        for eighth in range(8):
            track.add(noise_hit(0.05, rng, 0.7, 0.06 if eighth % 2 else 0.09), t0 + eighth * BEAT / 2.0)
        track.add(kick(), t0, 0.35)
        track.add(kick(), t0 + 2 * BEAT, 0.28)
        if bar % 4 in (1, 3):
            notes = pentatonic_walk(rng, tones, 4, prev_melody)
            prev_melody = notes[-1]
            for i, freq in enumerate(notes):
                track.add(marimba(freq, BEAT * 0.8), t0 + BEAT * (0.5 + i * 0.75), 0.3)
    return track.finish()


def build_imperio() -> np.ndarray:
    track = Track(seed=303)
    rng = track.rng
    progression = [
        ("C", "maj7"), ("E", "min7"), ("A", "dom7"), ("D", "min7"), ("G", "dom7"), ("C", "maj7"), ("F", "maj7"), ("G", "dom7"),
        ("C", "maj9"), ("A", "min7"), ("D", "min7"), ("G", "dom7"), ("E", "min7"), ("A", "dom7"), ("D", "min7"), ("G", "dom7"),
    ]
    bossa = [0.0, 0.75, 1.5, 2.0, 2.75, 3.5]  # padrão sincopado (em tempos)
    prev_melody = hz("E", 5)
    for bar, (root, quality) in enumerate(progression):
        t0 = bar * BAR
        tones = chord(root, quality, 3)
        for hit_index, beat in enumerate(bossa):
            for k, freq in enumerate(tones[:4]):
                track.add(pluck(freq * (2.0 if k else 1.0), 0.9, rng, 0.6), t0 + beat * BEAT + k * 0.012, 0.3 if hit_index % 2 == 0 else 0.22)
        track.add(bass(tones[0] / 2.0, BEAT * 1.4, soft=False), t0, 0.62)
        track.add(bass(tones[2] / 2.0, BEAT * 1.2, soft=False), t0 + 1.5 * BEAT, 0.5)
        track.add(bass(tones[0] / 2.0, BEAT * 1.0, soft=False), t0 + 2.0 * BEAT, 0.55)
        track.add(bass(tones[2] / 2.0, BEAT * 1.2, soft=False), t0 + 3.5 * BEAT, 0.45)
        for beat in (0.0, 1.0, 1.5, 3.0):
            track.add(rim(rng), t0 + beat * BEAT, 0.22)
        for eighth in range(8):
            swing = 0.06 if eighth % 2 else 0.0
            track.add(noise_hit(0.05, rng, 0.6, 0.05 if eighth % 2 else 0.08), t0 + eighth * BEAT / 2.0 + swing)
        if bar % 2 == 0:
            notes = pentatonic_walk(rng, tones, 5, prev_melody)
            prev_melody = notes[-1]
            for i, freq in enumerate(notes):
                swing = 0.05 if i % 2 else 0.0
                track.add(marimba(freq, BEAT * 0.7), t0 + BEAT * (0.5 + i * 0.5) + swing, 0.26)
    return track.finish()


TRACKS = {"bgm_quintal": build_quintal, "bgm_clinica": build_clinica, "bgm_imperio": build_imperio}


def write_wav(path: Path, samples: np.ndarray) -> None:
    dither = (np.random.default_rng(7).uniform(-1, 1, len(samples)) + np.random.default_rng(8).uniform(-1, 1, len(samples))) * 0.5
    pcm = np.clip(np.round(samples * 32767.0 + dither), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SR)
        handle.writeframes(pcm.tobytes())


def validate(path: Path) -> list[str]:
    problems: list[str] = []
    if not path.exists():
        return [f"ausente: {path.name}"]
    with wave.open(str(path), "rb") as handle:
        if handle.getnchannels() != 1 or handle.getsampwidth() != 2 or handle.getframerate() != SR:
            problems.append(f"{path.name}: formato deve ser mono/16 bits/{SR} Hz")
        frames = handle.getnframes()
        if frames != LOOP_FRAMES:
            problems.append(f"{path.name}: {frames} frames != {LOOP_FRAMES} (16 compassos a {BPM:.0f} BPM)")
        data = np.frombuffer(handle.readframes(frames), dtype="<i2").astype(np.float64) / 32768.0
    peak = float(np.max(np.abs(data)))
    if not 0.5 <= peak <= 0.7:
        problems.append(f"{path.name}: pico {peak:.2f} fora de 0,5–0,7")
    rms = float(np.sqrt(np.mean(data ** 2)))
    if not 0.03 <= rms <= 0.25:
        problems.append(f"{path.name}: RMS {rms:.3f} fora do esperado")
    if abs(float(data.mean())) > 0.002:
        problems.append(f"{path.name}: offset DC")
    return problems


def main() -> int:
    if "--check" in sys.argv:
        problems = [p for name in TRACKS for p in validate(OUT_DIR / f"{name}.wav")]
        for problem in problems:
            print("ERROR:", problem)
        print(f"bgm check: {len(problems)} problema(s)")
        return 1 if problems else 0
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, builder in TRACKS.items():
        path = OUT_DIR / f"{name}.wav"
        write_wav(path, builder())
        print(f"{path.relative_to(ROOT)}  {path.stat().st_size / 1e6:.2f} MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
