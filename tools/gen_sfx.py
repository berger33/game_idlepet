#!/usr/bin/env python3
"""Fonte única dos SFX do jogo: sintetiza e versiona os WAVs de `audio/sfx/`.

Cada ação tem o SEU instrumento, modelado fisicamente (não mais osciladores
de 8 bits). 44,1 kHz, 16 bits, dither TPDF; one-shots em estéreo com reverb
de sala, ticks de gesto em mono secos (repetem ~6x/s e precisam de espaço).

  banho     -> bolhas d'água (glissando de Minnaert: a nota SOBE enquanto a
               bolha se forma) + respingo + corpo de água filtrado
  tosa      -> tesourada: lâmina deslizando (ruído em varredura de banda) +
               ring metálico inarmônico + batida do fechamento
  secagem   -> sopro de ar: ruído rosa com corte que sobe + zumbido de motor
  laço      -> corda de náilon dedilhada (Karplus-Strong com detune)
  perfume   -> aerossol: clique da válvula + chiado do bico + ping de vidro
  janela    -> harpa de vidro "pode soltar" (E6 -> G6, com vibrato)
  UI        -> marimba muda (fundamental + 4º parcial, ataque de feltro)
  moeda     -> tilinte metálico inarmônico, duas batidas levemente desafinadas
  recompensa-> glissandos de harpa na pentatônica + shimmer + reverb
  erro      -> thud grave e macio (sem bronca)
  pets      -> chilro/guincho suave (scoop de pitch com fase integrada)

Determinismo: cada som tem semente derivada do próprio nome (crc32), então
`--check` regenera tudo e compara byte a byte com o que está versionado.

Uso:
  python tools/gen_sfx.py           # gera audio/sfx/*.wav + .preview/sfx
  python tools/gen_sfx.py --check   # valida + confere se os WAVs estão em sync
"""

from __future__ import annotations

import math
import random
import sys
import wave
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SR = 44100
TAU = math.tau
SFX_DIR = ROOT / "audio" / "sfx"
PREVIEW_DIR = ROOT / ".preview" / "sfx"

# Pentatônica de Dó maior (a mesma const do AudioManager) em três oitavas.
# Nada melódico sai dessa escala: qualquer sequência de SFX fica consonante
# com o loop ambiente (C, Am, F, G) — inclusive errar.
PENTATONIC = [
    130.81, 146.83, 164.81, 196.00, 220.00,
    261.63, 293.66, 329.63, 392.00, 440.00,
    523.25, 587.33, 659.26, 783.99, 880.00,
    1046.50, 1174.66, 1318.51, 1567.98, 1760.00,
    2093.00,
]
ALLOWED_PITCHES = {round(f, 2) for f in PENTATONIC}

# Escadas progressivas: 10 degraus que o `play_progress` sobe com o progresso.
BUBBLE_PITCHES = [523.25, 587.33, 659.26, 783.99, 880.00,
                  1046.50, 1174.66, 1318.51, 1567.98, 1760.00]
CLIPPER_PITCHES = [261.63, 293.66, 329.63, 392.00, 440.00,
                   523.25, 587.33, 659.26, 783.99, 880.00]
BOW_PITCHES = BUBBLE_PITCHES
DRYER_CUTOFFS = [500.0, 700.0, 950.0, 1250.0, 1600.0,
                 2000.0, 2500.0, 3100.0, 3800.0, 4600.0]
SPRAY_PINGS = [1046.50, 1174.66, 1318.51]

# Picos-alvo. Ticks de loop são bem mais baixos que os eventos: eles repetem
# ~6 vezes por segundo e precisam de espaço sob a música.
TICK_PEAKS = {"bubble": 0.060, "clipper": 0.072, "dryer": 0.075, "bow": 0.062}
LADDERS = {
    "bubble": {"pitches": BUBBLE_PITCHES, "duration": 0.14},
    "clipper": {"pitches": CLIPPER_PITCHES, "duration": 0.085},
    "dryer": {"cutoffs": DRYER_CUTOFFS, "duration": 0.17},
    "bow": {"pitches": BOW_PITCHES, "duration": 0.28},
}


def _seed_of(name: str) -> int:
    return zlib.crc32(name.encode("utf8"))


def _rng(name: str) -> random.Random:
    return random.Random(_seed_of(name))


# ------------------------------------------------------------- DSP básico --
def white(rng: random.Random, n: int) -> list[float]:
    return [rng.random() * 2.0 - 1.0 for _ in range(n)]


def pink(rng: random.Random, n: int) -> list[float]:
    """Ruído rosa (aproximação de Paul Kellet): 1/f, como ar e água reais."""
    b = [0.0] * 7
    rnd = rng.random
    out = [0.0] * n
    for i in range(n):
        w = rnd() * 2.0 - 1.0
        b[0] = 0.99886 * b[0] + w * 0.0555179
        b[1] = 0.99332 * b[1] + w * 0.0750759
        b[2] = 0.96900 * b[2] + w * 0.1538520
        b[3] = 0.86650 * b[3] + w * 0.3104856
        b[4] = 0.55000 * b[4] + w * 0.5329522
        b[5] = -0.7616 * b[5] - w * 0.0168980
        out[i] = (b[0] + b[1] + b[2] + b[3] + b[4] + b[5] + b[6] + w * 0.5362) * 0.11
        b[6] = w * 0.115926
    return out


def one_pole_lp(x: list[float], hz: float) -> list[float]:
    alpha = 1.0 - math.exp(-TAU * hz / SR)
    y = 0.0
    out = [0.0] * len(x)
    for i, s in enumerate(x):
        y += (s - y) * alpha
        out[i] = y
    return out


def one_pole_hp(x: list[float], hz: float) -> list[float]:
    alpha = 1.0 - math.exp(-TAU * hz / SR)
    y = 0.0
    out = [0.0] * len(x)
    for i, s in enumerate(x):
        y += (s - y) * alpha
        out[i] = s - y
    return out


def _biquad_coeffs(hz: float, q: float, kind: str) -> tuple:
    w0 = TAU * hz / SR
    cos_w0 = math.cos(w0)
    alpha = math.sin(w0) / (2.0 * q)
    if kind == "lp":
        b0 = (1.0 - cos_w0) * 0.5
        b1 = 1.0 - cos_w0
        b2 = b0
    elif kind == "hp":
        b0 = (1.0 + cos_w0) * 0.5
        b1 = -(1.0 + cos_w0)
        b2 = b0
    else:
        b0 = alpha
        b1 = 0.0
        b2 = -alpha
    a0 = 1.0 + alpha
    a1 = -2.0 * cos_w0
    a2 = 1.0 - alpha
    return b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0


def biquad(x: list[float], hz: float, q: float, kind: str) -> list[float]:
    b0, b1, b2, a1, a2 = _biquad_coeffs(hz, q, kind)
    x1 = x2 = y1 = y2 = 0.0
    out = [0.0] * len(x)
    for i, s in enumerate(x):
        y = b0 * s + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        out[i] = y
        x2 = x1
        x1 = s
        y2 = y1
        y1 = y
    return out


def band_sweep(x: list[float], hz_from: float, hz_to: float, q: float) -> list[float]:
    """Passa-banda com centro varrendo geometricamente (lâmina deslizando)."""
    n = len(x)
    ratio = hz_to / hz_from
    b0 = b1 = b2 = a1 = a2 = 0.0
    x1 = x2 = y1 = y2 = 0.0
    out = [0.0] * n
    for i, s in enumerate(x):
        if i % 24 == 0:
            frac = i / max(1, n - 1)
            b0, b1, b2, a1, a2 = _biquad_coeffs(
                max(60.0, hz_from * ratio ** frac), q, "bp"
            )
        y = b0 * s + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        out[i] = y
        x2 = x1
        x1 = s
        y2 = y1
        y1 = y
    return out


def env_ar(n: int, attack_ms: float, release_ms: float) -> list[float]:
    na = max(1, int(SR * attack_ms / 1000.0))
    nr = max(1, int(SR * release_ms / 1000.0))
    out = [0.0] * n
    for i in range(n):
        if i < na:
            out[i] = i / na
        elif i >= n - nr:
            k = (n - 1 - i) / nr
            out[i] = 0.5 - 0.5 * math.cos(math.pi * k)
        else:
            out[i] = 1.0
    return out


def env_decay(n: int, tau_ms: float) -> list[float]:
    tau = max(0.0001, tau_ms / 1000.0)
    return [math.exp(-i / SR / tau) for i in range(n)]


def mix_at(base: list[float], add: list[float], at_s: float, gain: float = 1.0):
    start = int(at_s * SR)
    need = start + len(add)
    if need > len(base):
        base.extend([0.0] * (need - len(base)))
    for i, s in enumerate(add):
        base[start + i] += s * gain
    return base


def remove_dc(x: list[float]) -> list[float]:
    mean = sum(x) / max(1, len(x))
    return [s - mean for s in x]


def normalize(channels: list[list[float]], peak: float) -> list[list[float]]:
    top = 0.0
    for ch in channels:
        for s in ch:
            if s > top:
                top = s
            elif -s > top:
                top = -s
    if top <= 0.0:
        return channels
    scale = peak / top
    return [[s * scale for s in ch] for ch in channels]


def fade_edges(x: list[float], in_ms: float = 3.0, out_ms: float = 3.0) -> list[float]:
    ni = max(1, int(SR * in_ms / 1000.0))
    no = max(1, int(SR * out_ms / 1000.0))
    for i in range(min(ni, len(x))):
        x[i] *= i / ni
    for i in range(min(no, len(x))):
        x[-1 - i] *= i / no
    return x


def resample(x: list[float], factor: float) -> list[float]:
    """Leitura em velocidade diferente (jitter de afinação / oitava abaixo)."""
    n = max(1, int(len(x) / factor))
    out = [0.0] * n
    last = len(x) - 1
    for i in range(n):
        pos = i * factor
        lo = int(pos)
        frac = pos - lo
        hi = lo + 1 if lo + 1 < last else last
        out[i] = x[lo] * (1.0 - frac) + x[hi] * frac
    return out


# ------------------------------------------------------------ instrumentos --
def ks_pluck(
    freq: float,
    dur: float,
    dark: float = 0.56,
    sustain: float = 0.9985,
    rng: random.Random | None = None,
) -> list[float]:
    """Karplus-Strong: corda real dedilhada. `dark` controla o timbre
    (0,5 = média pura, mais que isso = náilon macio) e `sustain` o decaimento."""
    n = max(2, int(round(SR / freq)))
    if rng is None:
        rng = random.Random(int(freq * 100.0))
    excitation = one_pole_lp(white(rng, n * 2), max(700.0, freq * 4.0))
    buf = excitation[:n]
    out = [0.0] * int(dur * SR)
    idx = 0
    for i in range(len(out)):
        cur = buf[idx]
        nxt = buf[idx + 1] if idx + 1 < n else buf[0]
        out[i] = cur
        buf[idx] = sustain * ((1.0 - dark) * cur + dark * nxt)
        idx += 1
        if idx == n:
            idx = 0
    return out


def pluck_note(freq: float, dur: float, dark: float = 0.52, gain: float = 1.0,
               seed: str = "") -> list[float]:
    """Corda com segunda camada levemente desafinada (coro quente de harpa)."""
    a = ks_pluck(freq, dur, dark, 0.9987, _rng(f"ks{seed}{freq:.2f}a"))
    b = ks_pluck(freq * 1.0035, dur, min(0.72, dark + 0.06), 0.9984,
                 _rng(f"ks{seed}{freq:.2f}b"))
    return [(x + 0.6 * y) * gain for x, y in zip(a, b)]


def glass_tone(freq: float, dur: float, partials: tuple,
               vib_hz: float = 0.0, vib_depth: float = 0.0,
               phases: tuple | None = None) -> list[float]:
    """Vidro/sino: parciais inarmônicos (razões 2,756 e 5,4) que decaem em
    velocidades diferentes — o que faz soar vidro e não flauta."""
    n = int(dur * SR)
    out = [0.0] * n
    if phases is None:
        phases = tuple(0.4 * i for i in range(len(partials)))
    attack = max(1.0, SR * 0.0015)
    for i in range(n):
        t = i / SR
        vib = 1.0 + vib_depth * math.sin(TAU * vib_hz * t) if vib_hz else 1.0
        s = 0.0
        for k, (ratio, amp, tau_ms) in enumerate(partials):
            f = freq * ratio * (vib if ratio == 1.0 else 1.0)
            s += math.sin(TAU * f * t + phases[k]) * amp * math.exp(-t * 1000.0 / tau_ms)
        out[i] = s * min(1.0, i / attack)
    return out


def marimba(freq: float, dur: float, rng: random.Random) -> list[float]:
    """Marimba muda: fundamental + 4º parcial (assinatura do instrumento)
    + batida de feltro. Redonda, sem o "bip" de seno puro."""
    n = int(dur * SR)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        s = math.sin(TAU * freq * t) * math.exp(-t * 1000.0 / 46.0)
        s += math.sin(TAU * freq * 4.0 * t) * 0.30 * math.exp(-t * 1000.0 / 13.0)
        s += math.sin(TAU * freq * 2.0 * t) * 0.09 * math.exp(-t * 1000.0 / 22.0)
        out[i] = s
    mix_at(out, one_pole_lp(white(rng, int(0.006 * SR)), 1900.0), 0.0, 0.06)
    return out


def bubble_one(f_base: float, dur: float, amp: float, rng: random.Random) -> list[float]:
    """Uma bolha: a frequência SOBE enquanto ela se forma (ressonância de
    Minnaert encolhendo) — é esse glissando que o ouvido lê como água."""
    n = int(dur * SR)
    rise = rng.uniform(1.18, 1.50)
    phase = 0.0
    out = [0.0] * n
    for i in range(n):
        t = i / n
        f = f_base * (1.0 + (rise - 1.0) * t ** 2.2)
        phase += TAU * f / SR
        env = math.exp(-t * 5.5) * min(t / 0.06, 1.0)
        out[i] = math.sin(phase) * env * amp
    return out


def scoop(f_from: float, f_to: float, dur: float, harmonic: float = 0.16,
          seed: str = "scoop") -> list[float]:
    """Guincho de pet: varredura de pitch com fase integrada (sem zipper)."""
    n = int(dur * SR)
    rng = _rng(seed)
    phase = rng.random() * TAU
    ratio = f_to / f_from
    out = [0.0] * n
    for i in range(n):
        t = i / n
        f = f_from * ratio ** (t ** 0.85)
        phase += TAU * f / SR
        env = min(t / 0.10, 1.0) * (1.0 - t) ** 1.5
        out[i] = (math.sin(phase) + math.sin(phase * 2.0) * harmonic) * env
    return out


def shimmer(dur: float, hz: float, gain: float, seed: str) -> list[float]:
    """Ar/poeira de brilho: ruído passa-alta com swell (cauda de recompensa)."""
    n = int(dur * SR)
    noise = one_pole_hp(white(_rng(seed), n), hz)
    # max(0, ...) protege o ** 0.9: sin(PI) pode devolver um epsilon negativo.
    env = [max(0.0, math.sin(math.pi * i / max(1, n - 1))) ** 0.9 for i in range(n)]
    return [s * e * gain for s, e in zip(noise, env)]


def reverb_stereo(mono: list[float], wet: float, seed: int,
                  tail_s: float) -> list[list[float]]:
    """Sala Schroeder (4 combs + 2 all-pass, caudas decorrelacionadas): dá
    espaço e ar aos eventos sem borrar os ticks de gesto."""
    rng = random.Random(seed)
    pad = int(tail_s * SR)
    src = list(mono) + [0.0] * pad
    n = len(src)
    comb_sizes = [c + rng.randrange(-23, 24) for c in (1116, 1188, 1277, 1356)]
    ap_sizes = [a + rng.randrange(-11, 12) for a in (556, 441)]
    damp = 1.0 - math.exp(-TAU * 4500.0 / SR)
    hp_alpha = 1.0 - math.exp(-TAU * 150.0 / SR)
    wet_ch: list[list[float]] = []
    for _ in range(2):
        c0 = [0.0] * comb_sizes[0]
        c1 = [0.0] * comb_sizes[1]
        c2 = [0.0] * comb_sizes[2]
        c3 = [0.0] * comb_sizes[3]
        p0 = [0.0] * ap_sizes[0]
        p1 = [0.0] * ap_sizes[1]
        n0, n1, n2, n3 = comb_sizes
        m0, m1 = ap_sizes
        i0 = i1 = i2 = i3 = j0 = j1 = 0
        l0 = l1 = l2 = l3 = 0.0
        rumble = 0.0
        out = [0.0] * n
        k = 0
        for s in src:
            d0 = c0[i0]
            d1 = c1[i1]
            d2 = c2[i2]
            d3 = c3[i3]
            l0 += (d0 - l0) * damp
            l1 += (d1 - l1) * damp
            l2 += (d2 - l2) * damp
            l3 += (d3 - l3) * damp
            c0[i0] = s + l0 * 0.78
            c1[i1] = s + l1 * 0.78
            c2[i2] = s + l2 * 0.78
            c3[i3] = s + l3 * 0.78
            i0 += 1
            if i0 == n0:
                i0 = 0
            i1 += 1
            if i1 == n1:
                i1 = 0
            i2 += 1
            if i2 == n2:
                i2 = 0
            i3 += 1
            if i3 == n3:
                i3 = 0
            t = (d0 + d1 + d2 + d3) * 0.25
            # as combs ressoam em ~35 Hz: sem isto a cauda vira estrondo grave
            rumble += (t - rumble) * hp_alpha
            t -= rumble
            e0 = p0[j0]
            p0[j0] = t + 0.5 * e0
            t = e0 - 0.5 * t
            j0 += 1
            if j0 == m0:
                j0 = 0
            e1 = p1[j1]
            p1[j1] = t + 0.5 * e1
            t = e1 - 0.5 * t
            j1 += 1
            if j1 == m1:
                j1 = 0
            out[k] = t
            k += 1
        wet_ch.append(out)
    return [
        [src[i] + wet * wet_ch[0][i] for i in range(n)],
        [src[i] + wet * wet_ch[1][i] for i in range(n)],
    ]


# ---------------------------------------------------------- finalização ----
def _finish_tick(body: list[float], base: str) -> tuple[list[list[float]], int]:
    """Ticks: mono, secos (sem reverb) e baixos — repetem a cada 0,16 s."""
    chans = [remove_dc(body)]
    for ch in chans:
        fade_edges(ch, 3.0, 3.0)
    return normalize(chans, TICK_PEAKS[base]), 1


def _event(mono: list[float], peak: float, wet: float, name: str,
           tail_s: float) -> tuple[list[list[float]], int]:
    chans = reverb_stereo(mono, wet, _seed_of(name) % 65536, tail_s)
    # remove_dc DEPOIS do reverb: a cauda da sala tem média própria.
    chans = [remove_dc(ch) for ch in chans]
    for ch in chans:
        fade_edges(ch, 3.0, 4.0)
    return normalize(chans, peak), 2


# ------------------------------------------------------- ticks dos gestos --
def build_bubble_tick(name: str, freq: float) -> tuple[list[list[float]], int]:
    """Glug: a bolha grave dá corpo, a AFINADA (no meio do tick) é a que sobe a
    escada, a terceira é solta; o respingo e o corpo de água dão o "molhado"."""
    rng = _rng(name)
    body: list[float] = [0.0] * int(0.14 * SR)
    mix_at(body, bubble_one(freq * 0.5, 0.050, 0.30, rng), 0.002)
    mix_at(body, bubble_one(freq, 0.100, 1.00, rng), 0.026)
    mix_at(body, bubble_one(freq * 0.75, 0.040, 0.24, rng), 0.008)
    mix_at(body, biquad(white(rng, int(0.008 * SR)), 4200.0, 1.3, "bp"), 0.002, 0.08)
    bed = one_pole_lp(pink(rng, int(0.11 * SR)), 700.0)
    bed_env = [
        max(0.0, math.sin(math.pi * i / len(bed))) ** 0.6 * 0.10 for i in range(len(bed))
    ]
    mix_at(body, [s * e for s, e in zip(bed, bed_env)], 0.000)
    return _finish_tick(body, "bubble")


def build_clipper_tick(name: str, freq: float) -> tuple[list[list[float]], int]:
    rng = _rng(name)
    body: list[float] = [0.0] * int(0.085 * SR)
    slide = band_sweep(white(rng, int(0.014 * SR)), 5600.0, 2400.0, 1.3)
    slide_env = env_decay(len(slide), 4.5)
    mix_at(body, [s * e for s, e in zip(slide, slide_env)], 0.000, 0.90)
    ring = glass_tone(freq * 2.0, 0.050, ((1.0, 0.30, 32.0), (2.76, 0.10, 18.0)))
    mix_at(body, ring, 0.011, 0.55)
    mix_at(body, one_pole_lp(white(rng, int(0.004 * SR)), 1200.0), 0.014, 0.22)
    return _finish_tick(body, "clipper")


def build_dryer_tick(name: str, cutoff: float) -> tuple[list[list[float]], int]:
    rng = _rng(name)
    n = int(0.17 * SR)
    noise = pink(rng, n)
    body = one_pole_lp(noise, cutoff)
    resonant = biquad(noise, min(cutoff * 1.6, 9000.0), 1.1, "bp")
    body = [b + r * 0.35 for b, r in zip(body, resonant)]
    env = env_ar(n, 26.0, 80.0)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        wobble = 1.0 + 0.12 * math.sin(TAU * 5.3 * t)
        hum = 0.05 * math.sin(TAU * 108.0 * t) + 0.02 * math.sin(TAU * 216.0 * t)
        out[i] = (body[i] * wobble + hum) * env[i]
    return _finish_tick(out, "dryer")


def build_bow_tick(name: str, freq: float) -> tuple[list[list[float]], int]:
    a = ks_pluck(freq, 0.28, 0.56, 0.9988, _rng(name + "a"))
    b = ks_pluck(freq * 1.004, 0.28, 0.62, 0.9986, _rng(name + "b"))
    out = [x + 0.55 * y for x, y in zip(a, b)]
    mix_at(out, one_pole_lp(white(_rng(name + "p"), int(0.004 * SR)), 2600.0), 0.0, 0.12)
    return _finish_tick(out, "bow")


# ------------------------------------------------------------- one-shots --
def build_tap(name: str) -> tuple[list[list[float]], int]:
    body = marimba(659.26, 0.13, _rng(name + "m"))
    mix_at(body, one_pole_lp(white(_rng(name + "t"), int(0.03 * SR)), 400.0), 0.0, 0.10)
    return _event(body, 0.105, 0.08, name, 0.22)


def build_tool_pickup(name: str) -> tuple[list[list[float]], int]:
    body = marimba(523.25, 0.12, _rng(name + "a"))
    mix_at(body, marimba(659.26, 0.12, _rng(name + "b")), 0.055, 0.75)
    mix_at(body, biquad(white(_rng(name + "c"), int(0.008 * SR)), 2600.0, 1.4, "bp"),
           0.0, 0.10)
    return _event(body, 0.115, 0.08, name, 0.24)


def build_panel_open(name: str) -> tuple[list[list[float]], int]:
    rng = _rng(name)
    n = int(0.19 * SR)
    noise = pink(rng, n)
    body = [0.0] * n
    for i in range(n):
        frac = i / n
        body[i] = noise[i]
    sliding = band_sweep(body, 320.0, 1200.0, 0.9)
    sliding = [s * e for s, e in zip(sliding, env_ar(n, 30.0, 90.0))]
    sliding = [s * 3.2 for s in sliding]
    knock = [0.0] * int(0.05 * SR)
    for i in range(len(knock)):
        t = i / SR
        knock[i] = math.sin(TAU * 208.0 * t) * math.exp(-t * 1000.0 / 16.0)
    mix_at(sliding, knock, 0.150, 0.35)
    mix_at(sliding, one_pole_lp(white(rng, int(0.006 * SR)), 900.0), 0.150, 0.12)
    return _event(sliding, 0.115, 0.10, name, 0.35)


def build_equip(name: str) -> tuple[list[list[float]], int]:
    rng = _rng(name)
    velcro = biquad(white(rng, int(0.07 * SR)), 1900.0, 1.1, "bp")
    flutter = [s * (0.45 + 0.55 * abs(math.sin(TAU * 31.0 * i / SR)))
               for i, s in enumerate(velcro)]
    body = [s * e for s, e in zip(flutter, env_ar(len(flutter), 6.0, 45.0))]
    mix_at(body, marimba(587.33, 0.13, _rng(name + "a")), 0.045, 0.85)
    mix_at(body, marimba(880.00, 0.13, _rng(name + "b")), 0.115, 0.70)
    return _event(body, 0.120, 0.10, name, 0.35)


def build_service_start(name: str) -> tuple[list[list[float]], int]:
    rng = _rng(name)
    pour = one_pole_lp(pink(rng, int(0.40 * SR)), 900.0)
    pour_env = env_ar(len(pour), 80.0, 200.0)
    body = [s * e * 1.6 for s, e in zip(pour, pour_env)]
    mix_at(body, bubble_one(392.00, 0.05, 0.55, _rng(name + "b1")), 0.10)
    mix_at(body, bubble_one(523.25, 0.05, 0.60, _rng(name + "b2")), 0.19)
    mix_at(body, bubble_one(659.26, 0.05, 0.55, _rng(name + "b3")), 0.28)
    mix_at(body, marimba(523.25, 0.22, _rng(name + "m")), 0.20, 0.60)
    return _event(body, 0.130, 0.14, name, 0.50)


def build_coin(name: str) -> tuple[list[list[float]], int]:
    partials = ((1.0, 1.0, 70.0), (2.32, 0.50, 42.0), (3.01, 0.34, 28.0),
                (4.27, 0.18, 18.0))
    body = glass_tone(1567.98, 0.22, partials)
    second = glass_tone(1567.98 * 1.006, 0.20, partials, phases=(0.7, 1.9, 2.6, 0.3))
    mix_at(body, second, 0.048, 0.70)
    mix_at(body, one_pole_hp(white(_rng(name), int(0.007 * SR)), 7000.0), 0.0, 0.10)
    return _event(body, 0.150, 0.15, name, 0.55)


def build_perfect(name: str) -> tuple[list[list[float]], int]:
    notes = [523.25, 659.26, 783.99, 880.00, 1046.50]
    body = pluck_note(notes[0], 0.55, seed="perfect")
    for k, freq in enumerate(notes[1:], start=1):
        mix_at(body, pluck_note(freq, 0.50, seed="perfect"), 0.045 * k,
               0.85 + 0.05 * k)
    mix_at(body, shimmer(0.34, 6000.0, 0.10, name), 0.02)
    return _event(body, 0.170, 0.22, name, 0.80)


def build_upgrade(name: str) -> tuple[list[list[float]], int]:
    body = pluck_note(659.26, 0.42, seed="upgrade")
    mix_at(body, pluck_note(783.99, 0.40, seed="upgrade"), 0.070)
    mix_at(body, pluck_note(1046.50, 0.45, seed="upgrade"), 0.140, 1.1)
    pad = one_pole_lp(pink(_rng(name), int(0.30 * SR)), 800.0)
    mix_at(body, [s * e for s, e in zip(pad, env_ar(len(pad), 120.0, 140.0))], 0.0, 0.5)
    return _event(body, 0.155, 0.18, name, 0.70)


def build_level_up(name: str) -> tuple[list[list[float]], int]:
    notes = [523.25, 587.33, 659.26, 783.99, 1046.50]
    body = pluck_note(notes[0], 0.40, dark=0.50, seed="level")
    for k, freq in enumerate(notes[1:], start=1):
        mix_at(body, pluck_note(freq, 0.40, dark=0.50, seed="level"), 0.065 * k, 1.0)
        mix_at(body, marimba(freq, 0.12, _rng(f"level{k}")), 0.065 * k, 0.22)
    mix_at(body, shimmer(0.30, 7000.0, 0.09, name), 0.10)
    return _event(body, 0.165, 0.20, name, 0.80)


def build_review(name: str) -> tuple[list[list[float]], int]:
    body = glass_tone(783.99, 0.26, ((1.0, 1.0, 150.0), (2.756, 0.30, 90.0),
                                     (5.4, 0.10, 45.0)))
    mix_at(body, glass_tone(1046.50, 0.30, ((1.0, 1.0, 170.0), (2.756, 0.28, 95.0),
                                            (5.4, 0.09, 48.0))), 0.09, 0.8)
    return _event(body, 0.115, 0.12, name, 0.45)


def build_pass_claim(name: str) -> tuple[list[list[float]], int]:
    notes = [523.25, 659.26, 783.99, 1046.50]
    body = pluck_note(notes[0], 0.42, seed="pass")
    for k, freq in enumerate(notes[1:], start=1):
        mix_at(body, pluck_note(freq, 0.42, seed="pass"), 0.055 * k, 1.0)
    mix_at(body, one_pole_hp(white(_rng(name), int(0.010 * SR)), 7000.0), 0.20, 0.10)
    return _event(body, 0.160, 0.20, name, 0.70)


def build_prestige(name: str) -> tuple[list[list[float]], int]:
    notes = [523.25, 659.26, 783.99, 1046.50, 1318.51, 1567.98]
    body = pluck_note(notes[0], 0.55, dark=0.50, seed="prestige")
    for k, freq in enumerate(notes[1:], start=1):
        mix_at(body, pluck_note(freq, 0.55, dark=0.50, seed="prestige"), 0.060 * k, 1.0)
    mix_at(body, shimmer(0.55, 6500.0, 0.13, name), 0.05)
    return _event(body, 0.175, 0.25, name, 1.00)


def build_comeback(name: str) -> tuple[list[list[float]], int]:
    notes = [392.00, 523.25, 659.26, 783.99]
    body = pluck_note(notes[0], 0.50, dark=0.60, seed="comeback")
    for k, freq in enumerate(notes[1:], start=1):
        mix_at(body, pluck_note(freq, 0.50, dark=0.60, seed="comeback"), 0.090 * k, 1.0)
    pad = one_pole_lp(pink(_rng(name), int(0.35 * SR)), 700.0)
    mix_at(body, [s * e for s, e in zip(pad, env_ar(len(pad), 150.0, 170.0))], 0.0, 0.45)
    return _event(body, 0.150, 0.18, name, 0.70)


def build_share_saved(name: str) -> tuple[list[list[float]], int]:
    rng = _rng(name)
    click = one_pole_lp(biquad(white(rng, int(0.006 * SR)), 2200.0, 1.2, "bp"), 3000.0)
    body = list(click)
    mix_at(body, one_pole_lp(biquad(white(rng, int(0.005 * SR)), 2000.0, 1.2, "bp"),
                             3000.0), 0.045, 0.75)
    mix_at(body, glass_tone(1046.50, 0.24, ((1.0, 1.0, 130.0), (2.756, 0.26, 70.0))),
           0.060, 0.55)
    mix_at(body, glass_tone(1318.51, 0.26, ((1.0, 1.0, 140.0), (2.756, 0.24, 75.0))),
           0.130, 0.45)
    return _event(body, 0.115, 0.12, name, 0.40)


def build_pet_happy(name: str) -> tuple[list[list[float]], int]:
    body = scoop(659.26, 880.00, 0.09, seed=name + "a")
    mix_at(body, scoop(783.99, 1046.50, 0.09, seed=name + "b"), 0.095, 0.85)
    return _event(body, 0.120, 0.10, name, 0.35)


def build_pet_surprise(name: str) -> tuple[list[list[float]], int]:
    body = scoop(392.00, 523.25, 0.13, harmonic=0.12, seed=name)
    return _event(body, 0.105, 0.10, name, 0.35)


def build_error_soft(name: str) -> tuple[list[list[float]], int]:
    body = glass_tone(164.81, 0.20, ((1.0, 1.0, 110.0), (2.0, 0.22, 60.0)))
    mix_at(body, one_pole_lp(white(_rng(name), int(0.05 * SR)), 300.0), 0.0, 0.35)
    return _event(body, 0.105, 0.08, name, 0.35)


def build_error(name: str) -> tuple[list[list[float]], int]:
    dark = ((1.0, 1.0, 120.0), (2.0, 0.24, 65.0), (3.01, 0.08, 40.0))
    body = glass_tone(164.81, 0.20, dark)
    mix_at(body, glass_tone(130.81, 0.24, dark), 0.115, 0.9)
    mix_at(body, one_pole_lp(white(_rng(name), int(0.06 * SR)), 260.0), 0.0, 0.40)
    return _event(body, 0.115, 0.10, name, 0.40)


def build_freeze(name: str) -> tuple[list[list[float]], int]:
    icy = ((1.0, 1.0, 110.0), (2.756, 0.34, 60.0), (5.4, 0.14, 32.0))
    body = glass_tone(1046.50, 0.22, icy, phases=(0.2, 1.1, 2.4))
    mix_at(body, glass_tone(783.99, 0.22, icy, phases=(0.9, 2.2, 0.4)), 0.075, 0.85)
    mix_at(body, glass_tone(659.26, 0.26, icy, phases=(1.7, 0.5, 3.0)), 0.150, 0.75)
    mix_at(body, shimmer(0.26, 8000.0, 0.12, name), 0.0)
    return _event(body, 0.120, 0.18, name, 0.50)


def build_window(name: str) -> tuple[list[list[float]], int]:
    glass = ((1.0, 1.0, 160.0), (2.756, 0.32, 90.0), (5.4, 0.10, 45.0))
    body = glass_tone(1318.51, 0.42, glass)
    second = glass_tone(1567.98, 0.44, glass, vib_hz=5.5, vib_depth=0.0015,
                        phases=(0.6, 1.8, 2.9))
    mix_at(body, second, 0.080, 0.80)
    return _event(body, 0.115, 0.20, name, 0.60)


def build_spray(name: str, ping_hz: float) -> tuple[list[list[float]], int]:
    rng = _rng(name)
    hiss_n = int(0.20 * SR)
    left = one_pole_hp(white(rng, hiss_n), 3200.0)
    left = [s + r for s, r in
            zip(left, biquad(one_pole_hp(white(rng, hiss_n), 3000.0), 6200.0, 1.8, "bp"))]
    right = one_pole_hp(white(rng, hiss_n), 3200.0)
    right = [s + r for s, r in
             zip(right, biquad(one_pole_hp(white(rng, hiss_n), 3000.0), 6200.0, 1.8, "bp"))]
    left = one_pole_lp(left, 9000.0)
    right = one_pole_lp(right, 9000.0)
    env = env_ar(hiss_n, 9.0, 70.0)
    dry_l: list[float] = []
    dry_r: list[float] = []
    for i in range(hiss_n):
        t = i / SR
        flutter = 1.0 + 0.15 * math.sin(TAU * 28.0 * t)
        dry_l.append(left[i] * env[i] * flutter)
        dry_r.append(right[i] * env[i] * (2.0 - flutter))
    mix_at(dry_l, one_pole_hp(white(rng, int(0.003 * SR)), 2000.0), 0.0, 0.30)
    mix_at(dry_r, one_pole_hp(white(rng, int(0.003 * SR)), 2000.0), 0.0, 0.30)
    ping = glass_tone(ping_hz, 0.28, ((1.0, 1.0, 90.0), (2.756, 0.30, 55.0)))
    mix_at(dry_l, ping, 0.004, 0.42)
    mix_at(dry_r, ping, 0.004, 0.42)
    chans = reverb_stereo(
        [(a + b) * 0.5 for a, b in zip(dry_l, dry_r)], 0.10, _seed_of(name) % 65536, 0.35
    )
    chans[0] = [mono + wet_l for mono, wet_l in zip(chans[0], dry_l)]
    chans[1] = [mono + wet_r for mono, wet_r in zip(chans[1], dry_r)]
    chans = [remove_dc(ch) for ch in chans]
    for ch in chans:
        fade_edges(ch, 3.0, 4.0)
    return normalize(chans, 0.140), 2


# ------------------------------------------------------------- manifesto ---
ONESHOTS: list[tuple[str, object, list[float]]] = [
    ("window", build_window, [1318.51, 1567.98]),
    ("tap", build_tap, [659.26]),
    ("tool_pickup", build_tool_pickup, [523.25, 659.26]),
    ("panel_open", build_panel_open, []),
    ("equip", build_equip, [587.33, 880.00]),
    ("service_start", build_service_start, [392.00, 523.25, 659.26]),
    ("coin", build_coin, [1567.98]),
    ("perfect", build_perfect, [523.25, 659.26, 783.99, 880.00, 1046.50]),
    ("upgrade", build_upgrade, [659.26, 783.99, 1046.50]),
    ("level_up", build_level_up, [523.25, 587.33, 659.26, 783.99, 1046.50]),
    ("review", build_review, [783.99, 1046.50]),
    ("pass_claim", build_pass_claim, [523.25, 659.26, 783.99, 1046.50]),
    ("prestige", build_prestige,
     [523.25, 659.26, 783.99, 1046.50, 1318.51, 1567.98]),
    ("comeback", build_comeback, [392.00, 523.25, 659.26, 783.99]),
    ("share_saved", build_share_saved, [1046.50, 1318.51]),
    ("pet_happy", build_pet_happy, [659.26, 880.00, 783.99, 1046.50]),
    ("pet_surprise", build_pet_surprise, [392.00, 523.25]),
    ("error_soft", build_error_soft, [164.81]),
    ("error", build_error, [164.81, 130.81]),
    ("freeze", build_freeze, [1046.50, 783.99, 659.26]),
    ("spray_0", lambda n: build_spray(n, SPRAY_PINGS[0]), [SPRAY_PINGS[0]]),
    ("spray_1", lambda n: build_spray(n, SPRAY_PINGS[1]), [SPRAY_PINGS[1]]),
    ("spray_2", lambda n: build_spray(n, SPRAY_PINGS[2]), [SPRAY_PINGS[2]]),
]

TICK_BUILDERS = {
    "bubble": build_bubble_tick,
    "clipper": build_clipper_tick,
    "dryer": build_dryer_tick,
    "bow": build_bow_tick,
}


def all_names() -> list[str]:
    names: list[str] = []
    for base, spec in LADDERS.items():
        steps = spec.get("pitches", spec.get("cutoffs", []))
        names.extend(f"{base}_{i}" for i in range(len(steps)))
    names.extend(name for name, _, _ in ONESHOTS)
    return names


def build_sound(name: str) -> tuple[list[list[float]], int]:
    for base, spec in LADDERS.items():
        if name.startswith(base + "_"):
            steps = spec.get("pitches", spec.get("cutoffs", []))
            index = int(name[len(base) + 1:])
            return TICK_BUILDERS[base](name, steps[index])
    for one_name, builder, _ in ONESHOTS:
        if name == one_name:
            return builder(name)
    raise KeyError(name)


def render_all() -> dict[str, tuple[list[list[float]], int]]:
    return {name: build_sound(name) for name in all_names()}


# --------------------------------------------------------------- validação --
def validate_manifest() -> list[str]:
    errors = []
    for _, _, pitches in ONESHOTS:
        for freq in pitches:
            if round(freq, 2) not in ALLOWED_PITCHES:
                errors.append(f"manifesto: {freq} fora da pentatônica de Dó")
    for base, spec in LADDERS.items():
        steps = spec.get("pitches", spec.get("cutoffs", []))
        if len(steps) != 10:
            errors.append(f"escada {base}: {len(steps)} degraus (esperados 10)")
        if any(b <= a for a, b in zip(steps, steps[1:])):
            errors.append(f"escada {base} não é ascendente: {steps}")
        for freq in spec.get("pitches", []):
            if round(freq, 2) not in ALLOWED_PITCHES:
                errors.append(f"escada {base}: {freq} fora da pentatônica de Dó")
    if any(b <= a for a, b in zip(SPRAY_PINGS, SPRAY_PINGS[1:])):
        errors.append(f"borrifadas do perfume não sobem: {SPRAY_PINGS}")
    if len(all_names()) != len(set(all_names())):
        errors.append("manifesto com nomes duplicados")
    return errors


def _pitch_power(ch: list[float], hz: float) -> float:
    """Energia na frequência `hz` (Goertzel) relativa à energia da janela —
    diz se a nota declarada é mesmo a que se ouve, sem FFT."""
    third = len(ch) // 3
    window = ch[third:third * 2] or ch
    n = len(window)
    if n == 0:
        return 0.0
    coeff = 2.0 * math.cos(TAU * hz * n / SR / n)
    s1 = s2 = 0.0
    energy = 0.0
    for s in window:
        s0 = s + coeff * s1 - s2
        s2 = s1
        s1 = s0
        energy += s * s
    power = s1 * s1 + s2 * s2 - coeff * s1 * s2
    return power / max(1e-12, energy)


def _dominant_hz(ch: list[float]) -> float:
    """Frequência dominante por taxa de cruzamento de zero (terço do meio,
    longe dos fades) — proxy barato de "a nota é essa" sem FFT."""
    third = len(ch) // 3
    window = ch[third:third * 2] or ch
    crossings = sum(
        1 for a, b in zip(window, window[1:]) if (a < 0.0) != (b < 0.0)
    )
    return crossings * SR / (2.0 * max(1, len(window)))


def validate_assets(rendered: dict[str, tuple[list[list[float]], int]]) -> list[str]:
    errors = []
    tick_peaks: list[float] = []
    oneshot_peaks: list[float] = []

    for name, (chans, nch) in sorted(rendered.items()):
        ch0 = chans[0]
        if len(chans) != nch:
            errors.append(f"{name}: {len(chans)} canais declarados como {nch}")
        if nch not in (1, 2):
            errors.append(f"{name}: {nch} canais (esperado 1 ou 2)")
        is_tick = any(name.startswith(b + "_") for b in LADDERS)
        if is_tick and nch != 1:
            errors.append(f"{name}: tick de gesto deve ser mono")
        if not is_tick and nch != 2:
            errors.append(f"{name}: evento deve ser estéreo")

        duration = len(ch0) / SR
        if is_tick:
            if not 0.06 <= duration <= 0.40:
                errors.append(f"{name}: duração de tick fora do alvo ({duration:.3f}s)")
        elif not 0.12 <= duration <= 2.40:
            errors.append(f"{name}: duração fora do alvo ({duration:.3f}s)")

        peak = max((abs(s) for ch in chans for s in ch), default=0.0)
        if peak > 0.999:
            errors.append(f"{name}: clipping (pico {peak:.3f})")
        if peak <= 0.0:
            errors.append(f"{name}: silêncio")
        mean = abs(sum(ch0) / max(1, len(ch0)))
        if mean > 0.003:
            errors.append(f"{name}: offset DC {mean:.4f}")
        # Sem degrau de silêncio: o primeiro e o último sample são zero.
        if abs(ch0[0]) > 0.005 * peak or abs(ch0[-1]) > 0.005 * peak:
            errors.append(
                f"{name}: borda não zera ({ch0[0]:.4f} / {ch0[-1]:.4f} vs pico {peak:.3f})"
            )
        if is_tick:
            tick_peaks.append(peak)
        else:
            oneshot_peaks.append(peak)

    # Ticks de loop (repetem ~6x/s) bem abaixo dos eventos.
    if tick_peaks and oneshot_peaks:
        tick_max = max(tick_peaks)
        median = sorted(oneshot_peaks)[len(oneshot_peaks) // 2]
        if tick_max > 0.65 * median:
            errors.append(
                f"ticks de loop altos demais: pico {tick_max:.4f} "
                f"vs evento mediano {median:.4f}"
            )

    # Escadas tonais: a nota dominante TEM de subir degrau a degrau — é o que
    # faz o jogador ouvir a aproximação dos 100% sem olhar a barra.
    # Escadas tonais: a nota TEM de soar mais alta degrau a degrau — é o que
    # faz o jogador ouvir a aproximação dos 100% sem olhar a barra.
    for base in ("bubble", "clipper"):
        freqs = [
            _dominant_hz(rendered[f"{base}_{i}"][0][0]) for i in range(10)
        ]
        if any(b < a * 0.98 for a, b in zip(freqs, freqs[1:])):
            errors.append(f"escada {base}: nota dominante não sobe {[round(f) for f in freqs]}")
        if freqs[-1] < freqs[0] * 1.4:
            errors.append(f"escada {base}: variação pequena demais {[round(f) for f in freqs]}")
    # Corda dedilhada tem harmônicos fortes (a taxa de cruzamento de zero leria
    # a 2ª harmônica), então cada degrau é conferido por energia na nota
    # declarada contra as oitavas vizinhas.
    for i, freq in enumerate(BOW_PITCHES):
        ch = rendered[f"bow_{i}"][0][0]
        tone = _pitch_power(ch, freq)
        if tone < _pitch_power(ch, freq * 2.0):
            errors.append(f"bow_{i}: oitava acima domina a nota declarada ({freq:.2f})")
        if tone < _pitch_power(ch, freq * 0.5) * 0.55:
            errors.append(f"bow_{i}: oitava abaixo domina a nota declarada ({freq:.2f})")

    expected = set(all_names())
    if set(rendered) != expected:
        errors.append(f"render != manifesto: {set(rendered) ^ expected}")
    return errors


# ---------------------------------------------------------- arquivos/demos --
def _pcm(name: str, chans: list[list[float]]) -> bytes:
    rng = _rng("dither" + name + ".wav")
    n = len(chans[0])
    nch = len(chans)
    out = bytearray()
    for i in range(n):
        for ch in chans:
            value = ch[i] + (rng.random() + rng.random() - 1.0) / 32767.0
            sample = int(max(-1.0, min(1.0, value)) * 32767.0)
            out += sample.to_bytes(2, "little", signed=True)
    return bytes(out)


def write_wav(path: Path, chans: list[list[float]], label: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(len(chans))
        handle.setsampwidth(2)
        handle.setframerate(SR)
        handle.writeframes(_pcm(label, chans))


def read_wav(path: Path) -> tuple[list[int], int, int]:
    """Retorna (frames entrelaçados, canais, taxa)."""
    with wave.open(str(path), "rb") as handle:
        nch = handle.getnchannels()
        rate = handle.getframerate()
        if handle.getsampwidth() != 2:
            raise ValueError(f"{path.name}: esperado 16 bits")
        raw = handle.readframes(handle.getnframes())
    frames = [
        int.from_bytes(raw[i * 2:i * 2 + 2], "little", signed=True)
        for i in range(len(raw) // 2)
    ]
    return frames, nch, rate


LOOP_SPACING = 0.16


def _demo_loop(base: str, rendered) -> list[float]:
    """Como o arrastar soa de verdade: 30 ticks a 0,16 s com a nota subindo a
    escada (alternando com o degrau seguinte), micro-jitter e swell do jogo —
    e 3 ticks `muted` de aviso (uma oitava abaixo) no final."""
    rng = _rng("demo" + base)
    n = len(LADDERS[base].get("pitches", LADDERS[base].get("cutoffs", [])))
    stream: list[float] = []
    for tick in range(30):
        progress = (tick + 0.5) / 30.0
        rung = min(int(progress * n), n - 1)
        if tick % 2 == 1:
            rung = min(rung + 1, n - 1)
        chans, _ = rendered[f"{base}_{rung}"]
        gain = 0.8 + 0.4 * progress
        jitter = 1.0 / (0.992 + rng.random() * 0.016)
        stream.extend(s * gain for s in resample(chans[0], jitter))
        stream.extend([0.0] * int(LOOP_SPACING * SR))
    for _ in range(3):
        chans, _ = rendered[f"{base}_{n - 1}"]
        stream.extend(s * 0.5 for s in resample(chans[0], 0.5))
        stream.extend([0.0] * int(LOOP_SPACING * SR))
    return stream


def _demo_perfume(rendered) -> list[float]:
    """A história do perfume: três borrifadas subindo C6→D6→E6 (a 3ª é o
    perfect) e o chime de vidro da janela "pode soltar"."""
    stream: list[float] = []
    for index, name in enumerate(("spray_0", "spray_1", "spray_2")):
        chans, _ = rendered[name]
        stream.extend(chans[0])
        stream.extend([0.0] * int(0.42 * SR))
    window, _ = rendered["window"]
    mix_at(stream, window[0], len(stream) / SR + 0.10)
    return stream


INDEX = """# SFX do jogo (estes arquivos SÃO os que o jogo toca)

Gerados por `tools/gen_sfx.py` (44,1 kHz, 16 bits, determinístico). Cada ação
tem o seu instrumento modelado fisicamente — os osciladores de 8 bits foram
aposentados. A música ambiente continua sendo sintetizada no AudioManager e
não foi tocada.

| Arquivo | Ação | Instrumento |
|---|---|---|
| bubble_0..9 | banho (esfregar) | bolhas d'água: glissando de Minnaert + respingo + corpo de água |
| clipper_0..9 | tosa | tesourada: lâmina em varredura + ring metálico + batida |
| dryer_0..9 | secagem | sopro de ar (ruído rosa) com brilho subindo + zumbido de motor |
| bow_0..9 | laço | corda de náilon dedilhada (Karplus-Strong com detune) |
| spray_0/1/2 | borrifadas de perfume | aerossol: válvula + chiado do bico + ping de vidro C6→D6→E6 |
| window | janela perfeita ("pode soltar") | harpa de vidro E6→G6 com vibrato |
| tap | toque de UI | marimba muda (Mi5) com batida de feltro |
| tool_pickup | pegar utensílio | marimba Dó5→Mi5 + clique de ponta |
| panel_open | abrir painel | gaveta: deslizamento filtrado + batida de madeira |
| equip | equipar | velcro + marimba Ré5→Lá5 |
| service_start | começar atendimento | água servida + três bolhas subindo + marimba |
| coin | moeda | tilinte metálico inarmônico, duas batidas desafinadas |
| perfect | atendimento perfeito | glissando de harpa Dó5→Dó6 + shimmer |
| upgrade | melhoria | arpejo de harpa Mi5→Dó6 + colchão quente |
| level_up | subir de nível | corrida Dó5→Dó6 (harpa + marimba) + brilho |
| review | pedir avaliação | vidro Sol5→Dó6 |
| pass_claim | resgatar passe | harpa Dó5→Dó6 + poeira de brilho |
| prestige | prestígio | glissando de 6 notas Dó5→Sol6 + shimmer + sala |
| comeback | volta do jogador | boas-vindas Sol4→Sol5 + colchão |
| share_saved | card salvo | obturador + vidro Dó6→Mi6 |
| pet_happy | pet feliz | chilro em dois guinchos (Mi5→Lá5, Sol5→Dó6) |
| pet_surprise | pet surpreso | guincho curto e suave (Sol4→Dó5) |
| error_soft | erro leve | thud grave macio (Mi3) |
| error | erro | thud grave Mi3→Dó3 (sem bronca) |
| freeze | congelado | gelo: vidro descendente Dó6→Mi5 + brilho |
| demo_loop_* | o arrastar de cada serviço | 30 ticks com a nota subindo + 3 avisos "drenando" |
| demo_perfume_janela | perfume completo | 3 borrifadas subindo + chime da janela |

Os `*_0..9` são os DEGRAUS da escada que o `play_progress` sobe conforme o
progresso se aproxima dos 100% (com micro-jitter de afinação no jogo); os
`demo_loop_*` mostram o arrastar inteiro, incluindo o aviso grave de quando o
progresso drena.
"""


def export_all(rendered: dict[str, tuple[list[list[float]], int]]) -> int:
    for name, (chans, _) in sorted(rendered.items()):
        write_wav(SFX_DIR / f"{name}.wav", chans, name)
        write_wav(PREVIEW_DIR / f"{name}.wav", chans, name)
    for base in LADDERS:
        write_wav(PREVIEW_DIR / f"demo_loop_{base}.wav", [_demo_loop(base, rendered)],
                  f"demo_{base}")
    write_wav(PREVIEW_DIR / "demo_perfume_janela.wav", [_demo_perfume(rendered)],
              "demo_perfume")
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    (PREVIEW_DIR / "index.md").write_text(INDEX, encoding="utf8")
    return len(rendered)


def load_rendered() -> dict[str, tuple[list[list[float]], int]]:
    """Lê os WAVs versionados (o que de fato embarca) como canais float — é o
    que os testes validam: não a intenção do gerador, e sim o arquivo final."""
    rendered: dict[str, tuple[list[list[float]], int]] = {}
    for name in all_names():
        path = SFX_DIR / f"{name}.wav"
        if not path.exists():
            continue
        frames, nch, rate = read_wav(path)
        if rate != SR:
            raise ValueError(f"{name}: {rate} Hz (esperados {SR})")
        chans = [[v / 32767.0 for v in frames[c::nch]] for c in range(nch)]
        rendered[name] = (chans, nch)
    return rendered


def compare_with_files(rendered: dict[str, tuple[list[list[float]], int]]) -> list[str]:
    """Regeração determinística vs. o que está versionado (tolerância de poucos
    LSB: `math.sin` depende da libm de cada máquina)."""
    drift = []
    for name, (chans, nch) in sorted(rendered.items()):
        path = SFX_DIR / f"{name}.wav"
        if not path.exists():
            drift.append(f"{name}: WAV ausente em audio/sfx")
            continue
        frames, file_nch, rate = read_wav(path)
        if rate != SR or file_nch != nch:
            drift.append(f"{name}: formato {rate} Hz / {file_nch} canais")
            continue
        expected = _pcm(name, chans)
        actual = frames
        worst = 0
        differing = 0
        for i, value in enumerate(actual):
            want = int.from_bytes(expected[i * 2:i * 2 + 2], "little", signed=True)
            delta = abs(value - want)
            if delta:
                differing += 1
                if delta > worst:
                    worst = delta
        if worst > 4 or differing > max(4, len(actual) // 100):
            drift.append(
                f"{name}: fora de sync (Δ máx {worst} LSB em {differing}/{len(actual)} samples)"
            )
    return drift


def stats_table(rendered: dict[str, tuple[list[list[float]], int]]) -> str:
    lines = [f"{'som':<16}{'duração':>9}{'pico':>8}{'rms':>8}{'nota dom.':>11}"]
    for name in all_names():
        chans, _ = rendered[name]
        ch = chans[0]
        peak = max((abs(s) for c in chans for s in c), default=0.0)
        rms = math.sqrt(sum(s * s for s in ch) / max(1, len(ch)))
        lines.append(
            f"{name:<16}{len(ch) / SR:>8.3f}s{peak:>8.3f}{rms:>8.4f}"
            f"{_dominant_hz(ch):>10.0f}Hz"
        )
    return "\n".join(lines)


def main() -> int:
    errors = validate_manifest()
    for error in errors:
        print(f"ERRO: {error}")
    if errors:
        return 1
    rendered = render_all()
    quality = validate_assets(rendered)
    for error in quality:
        print(f"ERRO: {error}")
    if "--check" in sys.argv:
        drift = compare_with_files(rendered)
        for item in drift:
            print(f"DRIFT: {item}")
        total = len(errors) + len(quality) + len(drift)
        print(f"sfx: {len(rendered)} sons | erros: {len(quality)} | drift: {len(drift)}")
        return 1 if total else 0
    if "--stats" in sys.argv:
        print(stats_table(rendered))
    count = export_all(rendered)
    print(stats_table(rendered))
    print(f"sfx gerados: {count} em {SFX_DIR.relative_to(ROOT)} "
          f"(demos em {PREVIEW_DIR.relative_to(ROOT)}) | erros: {len(quality)}")
    return 1 if quality else 0


if __name__ == "__main__":
    sys.exit(main())
