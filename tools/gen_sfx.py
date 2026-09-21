"""Fonte única dos SFX do jogo: gera os assets .wav de assets/audio/sfx/.

O AudioManager.gd apenas CARREGA estes WAVs (44.1 kHz, 16 bits) — toda a
síntese acontece aqui, offline, com modelagem física de instrumento. Cada
ação tem timbre próprio que evoca o gesto real:

  banho    bubble_N   bolhas d'água de verdade (glissando ascendente de
                      Minnaert + respingo + leito de água)
  tosa     clipper_N  tesourada: deslize de lâmina (ruído com varredura) +
                      anel metálico desafinado + "tc" de fechamento
  secagem  dryer_N    sopro: ruído rosa filtrado (corte sobe com o progresso)
                      + zumbido de motor + ondulação de ar
  laço     bow_N      corda de nylon dedilhada (Karplus-Strong) na pentatônica
  perfume  spray_N    atomizador: válvula + "psst" turbulento + sino de vidro
                      (C6, D6, E6 — a terceira borrifada é o perfect)
  janela   window     harpa de vidro "pode soltar" (E6 → G6 com vibrato)

Qualidade: 44.1 kHz, estéreo com reverb Schroeder nos eventos, dither TPDF,
fade anti-clique nas bordas, pico normalizado por classe de som (ticks de
loop bem mais baixos que one-shots). Tudo determinístico (seed por nome) —
`--check` regenera e compara amostra a amostra com os assets versionados.

Uso:
  python tools/gen_sfx.py            # gera assets + .preview/sfx (demos)
  python tools/gen_sfx.py --check    # regenera e valida (exit 1 se divergir)
"""

import math
import random
import sys
import wave
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SR = 44100
TAU = math.tau
ASSET_DIR = ROOT / "assets" / "audio" / "sfx"
PREVIEW_DIR = ROOT / ".preview" / "sfx"

## Pentatônica de Dó maior (C D E G A) em quatro oitavas — todo material
## melódico vive aqui para ficar consonante com o loop ambiente (C, Am, F, G).
ALLOWED_PITCHES = {
    130.81, 146.83, 164.81, 196.00, 220.00,
    261.63, 293.66, 329.63, 392.00, 440.00,
    523.25, 587.33, 659.26, 783.99, 880.00,
    1046.50, 1174.66, 1318.51, 1567.98, 1760.00, 2093.00,
}

## Escadas progressivas (10 degraus — o som sobe com o progresso do gesto).
LADDERS = {
    "bubble": [523.25, 587.33, 659.26, 783.99, 880.00,
               1046.50, 1174.66, 1318.51, 1567.98, 1760.00],
    "clipper": [261.63, 293.66, 329.63, 392.00, 440.00,
                523.25, 587.33, 659.26, 783.99, 880.00],
    "bow": [523.25, 587.33, 659.26, 783.99, 880.00,
            1046.50, 1174.66, 1318.51, 1567.98, 1760.00],
    # secador: sobe o BRILHO do ar (corte do filtro em Hz), não a nota
    "dryer": [500, 700, 950, 1250, 1600, 2000, 2500, 3100, 3800, 4600],
}
SPRAY_PINGS = [1046.50, 1174.66, 1318.51]  # C6, D6, E6

## Loudness-alvo por tick (normalização por RMS — o que o ouvido percebe;
## cordas agudas têm crista alta e ficariam fracas se normalizadas por pico).
## Pico de tick limitado a 0.072: bem abaixo da mediana dos one-shots.
TICK_RMS = {"bubble": 0.011, "clipper": 0.0115, "dryer": 0.018, "bow": 0.0062}
TICK_PEAK_CAP = 0.072


# ------------------------------------------------------------------ DSP ---

def rng_for(name):
    """Random determinístico por nome (mesma seed em qualquer máquina)."""
    return random.Random(zlib.crc32(name.encode("utf8")))


def _seed_of(name):
    return zlib.crc32(name.encode("utf8"))


def pink_noise(n, rng):
    """Ruído rosa (Paul Kellet): energia equilibrada por oitava — 'ar' real."""
    b0 = b1 = b2 = b3 = b4 = b5 = b6 = 0.0
    out = []
    for _ in range(n):
        w = rng.random() * 2.0 - 1.0
        b0 = 0.99886 * b0 + w * 0.0555179
        b1 = 0.99332 * b1 + w * 0.0750759
        b2 = 0.96900 * b2 + w * 0.1538520
        b3 = 0.86650 * b3 + w * 0.3104856
        b4 = 0.55000 * b4 + w * 0.5329522
        b5 = -0.7616 * b5 - w * 0.0168980
        b6 = w * 0.115926
        out.append((b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362) * 0.11)
    return out


def white_noise(n, rng):
    return [rng.random() * 2.0 - 1.0 for _ in range(n)]


def one_pole_lp(x, cutoff_hz):
    """Filtro passa-baixa de 1 polo (suave, sem ringing)."""
    alpha = 1.0 - math.exp(-TAU * cutoff_hz / SR)
    y = 0.0
    out = []
    for s in x:
        y += (s - y) * alpha
        out.append(y)
    return out


def one_pole_hp(x, cutoff_hz):
    lp = one_pole_lp(x, cutoff_hz)
    return [s - l for s, l in zip(x, lp)]


def _biquad_coeffs(kind, fc, q):
    w0 = TAU * fc / SR
    cosw = math.cos(w0)
    alpha = math.sin(w0) / (2.0 * q)
    if kind == "lp":
        b0 = (1.0 - cosw) * 0.5
        b1 = 1.0 - cosw
        b2 = (1.0 - cosw) * 0.5
        a0 = 1.0 + alpha
        a1 = -2.0 * cosw
        a2 = 1.0 - alpha
    elif kind == "hp":
        b0 = (1.0 + cosw) * 0.5
        b1 = -(1.0 + cosw)
        b2 = (1.0 + cosw) * 0.5
        a0 = 1.0 + alpha
        a1 = -2.0 * cosw
        a2 = 1.0 - alpha
    else:  # bp (peaking, ganho unitário no centro)
        b0 = alpha
        b1 = 0.0
        b2 = -alpha
        a0 = 1.0 + alpha
        a1 = -2.0 * cosw
        a2 = 1.0 - alpha
    return (b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0)


def biquad(x, kind, fc, q=0.707):
    b0, b1, b2, a1, a2 = _biquad_coeffs(kind, fc, q)
    x1 = x2 = y1 = y2 = 0.0
    out = []
    for s in x:
        y = b0 * s + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1
        x1 = s
        y2 = y1
        y1 = y
        out.append(y)
    return out


def bp_sweep(x, fc_start, fc_end, q, seconds):
    """Passa-banda com centro deslizante (deslize de lâmina/sopro)."""
    n = len(x)
    out = []
    x1 = x2 = y1 = y2 = 0.0
    coeffs = None
    for i, s in enumerate(x):
        if coeffs is None or (i & 31) == 0:
            t = min(1.0, (i / SR) / seconds)
            fc = fc_start + (fc_end - fc_start) * t
            coeffs = _biquad_coeffs("bp", fc, q)
        b0, b1, b2, a1, a2 = coeffs
        y = b0 * s + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1
        x1 = s
        y2 = y1
        y1 = y
        out.append(y)
    return out


def mix_at(base, add, at_seconds, gain=1.0):
    """Soma `add` sobre `base` a partir de at_seconds (cresce se preciso)."""
    start = int(at_seconds * SR)
    need = start + len(add)
    if need > len(base):
        base.extend([0.0] * (need - len(base)))
    for i, s in enumerate(add):
        base[start + i] += s * gain
    return base


def env_ar(n, attack_s, release_s):
    """Envelope ataque/solto com rampas de cosseno (sem degraus)."""
    na = max(1, int(attack_s * SR))
    nr = max(1, int(release_s * SR))
    out = []
    for i in range(n):
        g = 1.0
        if i < na:
            g = 0.5 - 0.5 * math.cos(math.pi * i / na)
        if i > n - nr:
            j = (i - (n - nr)) / nr
            g *= 0.5 + 0.5 * math.cos(math.pi * j)
        out.append(g)
    return out


def resample(x, factor):
    """Reamostragem linear: factor 2.0 = toca 2x mais devagar (pitch/2)."""
    n = int(len(x) * factor)
    out = []
    for i in range(n):
        pos = i / factor
        lo = int(pos)
        frac = pos - lo
        hi = min(lo + 1, len(x) - 1)
        out.append(x[lo] * (1.0 - frac) + x[hi] * frac)
    return out


def normalize_rms(x, target_rms, peak_cap):
    """Equaliza loudness percebida entre timbres (crista de ruído ≠ crista
    de tom) e limita o pico — todo degrau da escada soa igualmente forte."""
    n = max(1, len(x))
    rms = math.sqrt(sum(s * s for s in x) / n)
    scale = target_rms / rms if rms > 1e-9 else 0.0
    out = [s * scale for s in x]
    peak = max((abs(s) for s in out), default=0.0)
    if peak > peak_cap:
        cap = peak_cap / peak
        out = [s * cap for s in out]
    return out


def remove_dc(x):
    """Remove o componente DC (média) — não satura alto-falante."""
    mean = sum(x) / max(1, len(x))
    return [s - mean for s in x]


def fade_edges(x, in_ms=3.0, out_ms=3.0):
    ni = int(SR * in_ms / 1000.0)
    no = int(SR * out_ms / 1000.0)
    for i in range(min(ni, len(x))):
        x[i] *= i / ni
    for i in range(min(no, len(x))):
        x[-1 - i] *= i / no
    return x


def normalize_peak(channels, target):
    peak = 0.0
    for ch in channels:
        for s in ch:
            a = abs(s)
            if a > peak:
                peak = a
    if peak <= 0.0:
        return channels
    scale = target / peak
    return [[s * scale for s in ch] for ch in channels]


def reverb_stereo(mono, wet, seed, tail_s=0.7):
    """Reverb Schroeder (Freeverb-lite): 4 combs + 2 allpass por canal,
    canais descorrelacionados (largura estério real)."""
    tail = [0.0] * int(tail_s * SR)
    src = mono + tail
    n = len(src)
    rng = random.Random(seed)
    comb_base = (1116, 1188, 1277, 1356)
    ap_base = (556, 441)
    channels = []
    for _ in range(2):
        # combs paralelos com feedback e amortecimento no laço
        combs = []
        for c in comb_base:
            size = c + rng.randrange(-23, 24)
            combs.append({"buf": [0.0] * size, "idx": 0, "lp": 0.0})
        aps = []
        for c in ap_base:
            size = c + rng.randrange(-11, 12)
            aps.append({"buf": [0.0] * size, "idx": 0})
        out = [0.0] * n
        damp_alpha = 1.0 - math.exp(-TAU * 4500.0 / SR)
        for i, s in enumerate(src):
            rev = 0.0
            for comb in combs:
                feedback = 0.78
                y = comb["buf"][comb["idx"]]
                comb["lp"] += (y - comb["lp"]) * damp_alpha
                comb["buf"][comb["idx"]] = s + comb["lp"] * feedback
                comb["idx"] = (comb["idx"] + 1) % len(comb["buf"])
                rev += y
            rev *= 0.25
            for ap in aps:
                buf_out = ap["buf"][ap["idx"]]
                inp = rev + buf_out * 0.5
                ap["buf"][ap["idx"]] = inp
                ap["idx"] = (ap["idx"] + 1) % len(ap["buf"])
                rev = buf_out - inp * 0.5
            out[i] = s + rev * wet
        channels.append(out)
    return channels


# ---------------------------------------------------------- instrumentos ---

def ks_pluck(freq, dur, dark=0.56, sustain=0.9995, rng=None):
    """Karplus-Strong: corda dedilhada de verdade (delay line + lowpass).

    `dark` é a força do filtro no laço (0.5 = média pura = corda brilhante;
    maior = mais abafada, timbre de nylon). `sustain` é o decaimento por
    volta — a corda soa por centenas de ms, não um blip.
    """
    if rng is None:
        rng = rng_for("ks%d" % int(freq * 100))
    n_delay = max(2, round(SR / freq))
    # decaimento por volta calibrado para o mesmo TEMPO de vida em qualquer
    # nota (agudo = mais voltas por segundo = sustain mais próximo de 1):
    # amplitude cai a 5% em ~1,2 s, uniforme em toda a escala.
    sustain = min(sustain, max(0.99, 0.05 ** (1.0 / (freq * 1.2))))
    # excitação: burst de ruído abafado (dedo macio na corda)
    burst = white_noise(n_delay, rng)
    burst = one_pole_lp(burst, freq * 4.0)
    peak = max(abs(s) for s in burst) or 1.0
    buf = [s / peak for s in burst]
    out = []
    idx = 0
    m = len(buf)
    keep = 1.0 - dark
    for _ in range(int(dur * SR)):
        cur = buf[idx]
        nxt = buf[(idx + 1) % m]
        out.append(cur)
        buf[idx] = sustain * (keep * cur + dark * nxt)
        idx = (idx + 1) % m
    return out


def pluck_note(freq, dur, gain=1.0, dark=0.56, rng=None):
    """Corda dupla: duas KS levemente desafinadas (corus quente de nylon)."""
    if rng is None:
        rng = rng_for("ks%d" % int(freq * 100))
    a = ks_pluck(freq, dur, dark=dark, rng=rng)
    b = ks_pluck(freq * 1.0017, dur, dark=dark + 0.04, rng=rng)
    mixed = [x + 0.55 * y for x, y in zip(a, b)]
    # Saturação suave (tanh): limita as cristas aleatórias do ataque do
    # burst (crista 4–10x) e esquenta o timbre — "amplificador" analógico.
    return [math.tanh(s * 1.3) / 1.3 * gain for s in mixed]


def glass_tone(freq, dur, partials, vib_hz=0.0, vib_depth=0.0, phase=0.0):
    """Tom de vidro/sino: parciais inarmônicos com decaimentos próprios."""
    n = int(dur * SR)
    out = [0.0] * n
    for ratio, amp, tau_ms in partials:
        ph = phase * ratio
        for i in range(n):
            t = i / SR
            f = freq * ratio
            if vib_hz > 0.0:
                f *= 1.0 + vib_depth * math.sin(TAU * vib_hz * t)
            ph += TAU * f / SR
            out[i] += math.sin(ph) * amp * math.exp(-t * 1000.0 / tau_ms)
    return out


def marimba_note(freq, dur=0.30, rng=None):
    """Marimba: fundamental + parcial de 4x curto (a "arcada" da madeira)."""
    body = glass_tone(freq, dur, [(1.0, 1.0, 55.0), (4.0, 0.22, 16.0)])
    if rng is None:
        rng = rng_for("mar%d" % int(freq * 100))
    strike = one_pole_lp(white_noise(int(0.006 * SR), rng), freq * 3.0)
    strike = [s * 0.18 for s in strike]
    return mix_at(body, strike, 0.0)


def scoop_chirp(f0, f1, dur, harmonic=0.18):
    """Glide exponencial de afinação (integra fase — sem 'zipper')."""
    n = int(dur * SR)
    out = []
    ph = 0.0
    ratio = f1 / f0
    for i in range(n):
        t = i / n
        f = f0 * (ratio ** t)
        ph += TAU * f / SR
        env = min(t / 0.12, 1.0) * ((1.0 - t) ** 1.6)
        out.append((math.sin(ph) + harmonic * math.sin(2.0 * ph)) * env)
    return out


def bubble_one(f_base, dur, amp, rng, decay=7.0):
    """Bolha d'água real: ressonância de Minnaert — pitch SOBE acelerando."""
    n = int(dur * SR)
    rise = 1.0 + rng.uniform(1.15, 1.45)
    out = []
    ph = 0.0
    for i in range(n):
        t = i / n
        f = f_base * (1.0 + (rise - 1.0) * (t ** 2.4))
        ph += TAU * f / SR
        env = min(t / 0.10, 1.0) * math.exp(-t * decay)
        out.append(math.sin(ph) * env * amp)
    return out


def _finish_tick(body, base):
    """Tick de loop: sem DC, RMS da classe, pico limitado, fades."""
    body = remove_dc(body)
    body = normalize_rms(body, TICK_RMS[base], TICK_PEAK_CAP)
    return [fade_edges(body)], False


# ------------------------------------------------------------ ticks (loop) --

def build_bubble_tick(name, freq):
    """Banho: 3 bolhas em glissando + respingo + leito de água."""
    rng = rng_for(name)
    dur = 0.14
    n = int(dur * SR)
    body = [0.0] * n
    # leito de água: ruído grave bem baixo (a "molhado" do esfregar)
    bed = one_pole_lp(pink_noise(n, rng), 700.0)
    bed_env = env_ar(n, 0.012, 0.09)
    for i in range(n):
        body[i] += bed[i] * bed_env[i] * 0.20
    # bolhas: corpo grave + A NOTA DA ESCADA (a mais forte e a que mais
    # soa — é o degrau que o jogador ouve subir) + textura frouxa
    mix_at(body, bubble_one(freq * 0.5, 0.05, 0.45, rng, decay=5.0), 0.000)
    mix_at(body, bubble_one(freq, 0.065, 1.0, rng, decay=3.2), 0.004)
    mix_at(body, bubble_one(freq * 0.75, 0.032, 0.35, rng, decay=6.0), 0.012)
    # respingo de superfície
    splash = biquad(white_noise(int(0.008 * SR), rng), "bp", 4200.0, 1.4)
    mix_at(body, [s * 0.35 for s in splash], 0.004)
    return _finish_tick(body, "bubble")


def build_clipper_tick(name, freq):
    """Tosa: tesourada — deslize de lâmina + anel metálico + fechamento."""
    rng = rng_for(name)
    dur = 0.085
    n = int(dur * SR)
    body = [0.0] * n
    # deslize: ruído com banda descendo (lâmina cortando)
    slide = bp_sweep(white_noise(int(0.016 * SR), rng), 5600.0, 2400.0, 1.1, 0.014)
    slide_env = [math.exp(-t * SR / 16000.0) for t in range(len(slide))]
    slide = [s * e for s, e in zip(slide, slide_env)]
    mix_at(body, slide, 0.000, 0.9)
    # anel metálico (parciais inarmônicos de aço) — sobe com a escada
    ring = glass_tone(freq * 2.0, 0.055, [(1.0, 0.5, 14.0), (2.76, 0.22, 8.0)])
    mix_at(body, ring, 0.012, 0.30)
    # "tc" de fechamento das lâminas
    catch = one_pole_lp(white_noise(int(0.004 * SR), rng), 1400.0)
    mix_at(body, [s * 0.5 for s in catch], 0.015, 0.55)
    return _finish_tick(body, "clipper")


def build_dryer_tick(name, cutoff):
    """Secagem: sopro de ar rosa (corte = brilho do degrau) + motor + ondulação."""
    rng = rng_for(name)
    dur = 0.17
    n = int(dur * SR)
    air = one_pole_lp(pink_noise(n, rng), cutoff)
    # corpo ressonante do bico
    air = [a + 0.5 * b for a, b in zip(air, biquad(air, "bp", cutoff * 1.6, 1.2))]
    env = env_ar(n, 0.03, 0.09)
    # ondulação do ar + zumbido de motor discreto
    body = [0.0] * n
    hum_ph = 0.0
    for i in range(n):
        t = i / SR
        wobble = 1.0 + 0.12 * math.sin(TAU * 5.2 * t + 1.3)
        hum_ph += TAU * 108.0 / SR
        hum = math.sin(hum_ph) * 0.05 + math.sin(2.0 * hum_ph) * 0.02
        body[i] = air[i] * env[i] * wobble + hum * env[i]
    return _finish_tick(body, "dryer")


def build_bow_tick(name, freq):
    """Laço: corda de nylon dedilhada na nota da escada."""
    rng = rng_for(name)
    body = pluck_note(freq, 0.26, rng=rng)
    # "toque" de dedo quase inaudível — dá o ataque sem virar clique
    pick = one_pole_lp(white_noise(int(0.004 * SR), rng), freq * 2.5)
    mix_at(body, [s * 0.12 for s in pick], 0.0)
    return _finish_tick(body, "bow")


# ------------------------------------------------------- one-shots (eventos) --

def _event(mono, peak, wet=0.15, seed=1, tail_s=0.7):
    """Finaliza um evento: sem DC + reverb estéreo + normalização + fades."""
    mono = remove_dc(mono)
    channels = reverb_stereo(mono, wet, seed, tail_s) if wet > 0 else [list(mono), list(mono)]
    channels = normalize_peak(channels, peak)
    return [fade_edges(list(ch)) for ch in channels], True


def build_spray(name, ping_hz):
    """Perfume: válvula + psst turbulento + sino de vidro na nota da escada."""
    rng = rng_for(name)
    dur = 0.30
    n = int(dur * SR)
    # psst: ruído branco agudo com ressonância de bico + flutter do aerossol
    hiss = white_noise(n, rng)
    hiss = one_pole_hp(hiss, 3200.0)
    hiss = [h + 0.6 * b for h, b in zip(hiss, biquad(hiss, "bp", 6200.0, 1.8))]
    env = env_ar(n, 0.010, 0.085)
    body = [0.0] * n
    for i in range(n):
        t = i / SR
        flutter = 1.0 + 0.15 * math.sin(TAU * 28.0 * t + 0.7)
        body[i] = hiss[i] * env[i] * flutter
    # clique da válvula
    valve = one_pole_hp(white_noise(int(0.003 * SR), rng), 2200.0)
    mix_at(body, [s * 0.8 for s in valve], 0.0, 0.5)
    # sino de vidro (a nota — C6/D6/E6 por borrifada)
    ping = glass_tone(ping_hz, 0.26, [(1.0, 1.0, 80.0), (2.756, 0.30, 50.0)])
    mix_at(body, ping, 0.012, 0.28)
    return _event(body, 0.140, wet=0.10, tail_s=0.35, seed=_seed_of(name))


def build_window(name):
    """Janela perfeita: harpa de vidro E6 → G6 com vibrato — "pode soltar"."""
    body = glass_tone(1318.51, 0.55, [(1.0, 1.0, 150.0), (2.756, 0.30, 85.0), (5.4, 0.10, 40.0)])
    second = glass_tone(1567.98, 0.45, [(1.0, 1.0, 130.0), (2.756, 0.28, 75.0)],
                        vib_hz=5.5, vib_depth=0.0012)
    mix_at(body, second, 0.08, 0.8)
    return _event(body, 0.115, wet=0.20, tail_s=0.6, seed=_seed_of(name))


def build_tap(name):
    """Toque de UI: marimba macia em Mi5 — redondo, discreto."""
    rng = rng_for(name)
    body = marimba_note(659.26, 0.30, rng)
    wool = one_pole_lp(pink_noise(int(0.05 * SR), rng), 500.0)
    mix_at(body, [s * 0.25 * math.exp(-i / (SR * 0.012)) for i, s in enumerate(wool)], 0.0)
    return _event(body, 0.105, wet=0.08, tail_s=0.3, seed=_seed_of(name))


def build_tool_pickup(name):
    """Pegar ferramenta: pano + duas marimbas curtas subindo."""
    rng = rng_for(name)
    body = marimba_note(523.25, 0.22, rng)
    mix_at(body, marimba_note(659.26, 0.20, rng), 0.055, 0.7)
    cloth = one_pole_lp(white_noise(int(0.05 * SR), rng), 1500.0)
    mix_at(body, [s * 0.18 for s in cloth], 0.0)
    return _event(body, 0.115, wet=0.08, tail_s=0.3, seed=_seed_of(name))


def build_panel_open(name):
    """Abrir painel: gaveta — swoosh de pano + toque de madeira no fim."""
    rng = rng_for(name)
    n = int(0.20 * SR)
    swoosh = bp_sweep(pink_noise(n, rng), 350.0, 1100.0, 0.9, 0.16)
    env = env_ar(n, 0.05, 0.08)
    body = [s * e for s, e in zip(swoosh, env)]
    knock = glass_tone(196.0, 0.09, [(1.0, 1.0, 18.0), (2.4, 0.3, 9.0)])
    mix_at(body, knock, 0.13, 0.5)
    return _event(body, 0.115, wet=0.10, tail_s=0.35, seed=_seed_of(name))


def build_equip(name):
    """Equipar: rasgo de velcro + confirmação em marimba Ré5→Lá5."""
    rng = rng_for(name)
    n = int(0.075 * SR)
    velcro = biquad(white_noise(n, rng), "bp", 1900.0, 0.9)
    body = []
    for i, s in enumerate(velcro):
        t = i / SR
        stutter = 1.0 if math.sin(TAU * 34.0 * t) > -0.2 else 0.15
        body.append(s * stutter * math.exp(-t / 0.045) * 0.7)
    mix_at(body, marimba_note(587.33, 0.22, rng), 0.055, 0.9)
    mix_at(body, marimba_note(880.00, 0.20, rng), 0.115, 0.6)
    return _event(body, 0.120, wet=0.10, tail_s=0.35, seed=_seed_of(name))


def build_service_start(name):
    """Início do serviço: água caindo — swell + bolhas subindo + marimba."""
    rng = rng_for(name)
    n = int(0.42 * SR)
    pour = one_pole_lp(pink_noise(n, rng), 900.0)
    env = env_ar(n, 0.07, 0.22)
    body = [s * e * 0.8 for s, e in zip(pour, env)]
    mix_at(body, bubble_one(392.00, 0.05, 0.7, rng), 0.05)
    mix_at(body, bubble_one(523.25, 0.04, 0.8, rng), 0.12)
    mix_at(body, bubble_one(659.26, 0.035, 0.8, rng), 0.19)
    mix_at(body, marimba_note(523.25, 0.25, rng), 0.22, 0.55)
    return _event(body, 0.130, wet=0.14, tail_s=0.5, seed=_seed_of(name))


def build_coin(name):
    """Moeda: tilintar metálico (parciais inarmônicos) + brilho agudo."""
    rng = rng_for(name)
    partials = [(1.0, 1.0, 70.0), (2.32, 0.5, 40.0), (3.01, 0.35, 28.0), (4.27, 0.2, 18.0)]
    body = glass_tone(1567.98, 0.22, partials)
    second = glass_tone(1567.98 * 1.006, 0.16, partials)
    mix_at(body, second, 0.048, 0.65)
    sparkle = one_pole_hp(white_noise(int(0.008 * SR), rng), 7000.0)
    mix_at(body, [s * 0.3 for s in sparkle], 0.0)
    return _event(body, 0.150, wet=0.15, tail_s=0.55, seed=_seed_of(name))


def build_perfect(name):
    """Perfect: glissando de harpa C5→C6 com brilho — a recompensa máxima."""
    rng = rng_for(name)
    notes = [523.25, 659.26, 783.99, 880.00, 1046.50]
    body = []
    for i, f in enumerate(notes):
        mix_at(body, pluck_note(f, 0.42, rng=rng), 0.045 * i, 0.55 + 0.09 * i)
    shimmer = one_pole_hp(pink_noise(int(0.45 * SR), rng), 6000.0)
    sh_env = env_ar(len(shimmer), 0.10, 0.30)
    mix_at(body, [s * e * 0.16 for s, e in zip(shimmer, sh_env)], 0.10)
    return _event(body, 0.170, wet=0.22, tail_s=0.8, seed=_seed_of(name))


def build_upgrade(name):
    """Upgrade: três cordas subindo + colchão de ar — "abriu algo melhor"."""
    rng = rng_for(name)
    body = []
    for i, f in enumerate([659.26, 783.99, 1046.50]):
        mix_at(body, pluck_note(f, 0.40, rng=rng), 0.07 * i, 0.8)
    pad = one_pole_lp(pink_noise(int(0.5 * SR), rng), 800.0)
    pad_env = env_ar(len(pad), 0.16, 0.30)
    mix_at(body, [s * e * 0.20 for s, e in zip(pad, pad_env)], 0.0)
    return _event(body, 0.155, wet=0.18, tail_s=0.7, seed=_seed_of(name))


def build_level_up(name):
    """Level up: run de 5 notas corda+marimba + faísca — subida de nível."""
    rng = rng_for(name)
    body = []
    notes = [523.25, 587.33, 659.26, 783.99, 1046.50]
    for i, f in enumerate(notes):
        mix_at(body, pluck_note(f, 0.40, rng=rng), 0.065 * i, 0.75)
        mix_at(body, marimba_note(f, 0.20, rng), 0.065 * i, 0.35)
    sparkle = one_pole_hp(white_noise(int(0.30 * SR), rng), 7000.0)
    sp_env = env_ar(len(sparkle), 0.05, 0.22)
    mix_at(body, [s * e * 0.12 for s, e in zip(sparkle, sp_env)], 0.20)
    return _event(body, 0.165, wet=0.20, tail_s=0.8, seed=_seed_of(name))


def build_review(name):
    """Pedido de review: dois toques de vidro suaves G5→C6 — gratidão."""
    rng = rng_for(name)
    body = glass_tone(783.99, 0.35, [(1.0, 1.0, 110.0), (2.756, 0.25, 60.0)])
    mix_at(body, glass_tone(1046.50, 0.30, [(1.0, 1.0, 95.0), (2.756, 0.22, 55.0)]), 0.09, 0.85)
    return _event(body, 0.115, wet=0.18, tail_s=0.45, seed=_seed_of(name))


def build_pass_claim(name):
    """Recompensa do passe: harpa C5→C6 + tilintar de moeda no fim."""
    rng = rng_for(name)
    body = []
    for i, f in enumerate([523.25, 659.26, 783.99, 1046.50]):
        mix_at(body, pluck_note(f, 0.38, rng=rng), 0.055 * i, 0.75)
    jingle = glass_tone(1567.98, 0.18, [(1.0, 1.0, 60.0), (2.32, 0.4, 35.0)])
    mix_at(body, jingle, 0.24, 0.45)
    return _event(body, 0.160, wet=0.18, tail_s=0.7, seed=_seed_of(name))


def build_prestige(name):
    """Prestígio: run de 6 cordas até G6 + shimmer longo — o som maior do jogo."""
    rng = rng_for(name)
    body = []
    notes = [523.25, 659.26, 783.99, 1046.50, 1318.51, 1567.98]
    for i, f in enumerate(notes):
        mix_at(body, pluck_note(f, 0.55, rng=rng), 0.06 * i, 0.7 + 0.05 * i)
    shimmer = one_pole_hp(pink_noise(int(0.9 * SR), rng), 5500.0)
    sh_env = env_ar(len(shimmer), 0.25, 0.55)
    mix_at(body, [s * e * 0.15 for s, e in zip(shimmer, sh_env)], 0.15)
    return _event(body, 0.175, wet=0.25, tail_s=1.0, seed=_seed_of(name))


def build_comeback(name):
    """Volta do jogador: acolhimento — 4 cordas macias G4→G5 + colchão."""
    rng = rng_for(name)
    body = []
    for i, f in enumerate([392.00, 523.25, 659.26, 783.99]):
        mix_at(body, pluck_note(f, 0.50, dark=0.62, rng=rng), 0.09 * i, 0.8)
    pad = one_pole_lp(pink_noise(int(0.8 * SR), rng), 600.0)
    pad_env = env_ar(len(pad), 0.30, 0.40)
    mix_at(body, [s * e * 0.22 for s, e in zip(pad, pad_env)], 0.0)
    return _event(body, 0.150, wet=0.20, tail_s=0.7, seed=_seed_of(name))


def build_share_saved(name):
    """Compartilhamento salvo: obturador macio + vidro C6→E6 — confirmação."""
    rng = rng_for(name)
    n = int(0.005 * SR)
    body = list(one_pole_lp(white_noise(n, rng), 2600.0))
    mix_at(body, one_pole_lp(white_noise(n, rng), 2100.0), 0.045, 0.8)
    mix_at(body, glass_tone(1046.50, 0.25, [(1.0, 1.0, 85.0)]), 0.07, 0.5)
    mix_at(body, glass_tone(1318.51, 0.25, [(1.0, 1.0, 80.0), (2.756, 0.2, 45.0)]), 0.13, 0.45)
    return _event(body, 0.115, wet=0.12, tail_s=0.4, seed=_seed_of(name))


def build_pet_happy(name):
    """Pet feliz: dois glides ascendentes quentes — gorjeio de bichinho."""
    body = scoop_chirp(659.26, 880.00, 0.085, harmonic=0.15)
    mix_at(body, scoop_chirp(783.99, 1046.50, 0.075, harmonic=0.12), 0.10, 0.85)
    return _event(body, 0.120, wet=0.10, tail_s=0.35, seed=_seed_of(name))


def build_pet_surprise(name):
    """Pet curioso: um glide médio que assenta — "hmm?"."""
    body = scoop_chirp(392.00, 523.25, 0.11, harmonic=0.10)
    return _event(body, 0.105, wet=0.10, tail_s=0.35, seed=_seed_of(name))


def build_error_soft(name):
    """Erro leve: nota grave escura + baque de lã — "quase", sem bronca."""
    rng = rng_for(name)
    body = glass_tone(164.81, 0.28, [(1.0, 1.0, 95.0), (2.0, 0.18, 50.0)])
    thump = one_pole_lp(pink_noise(int(0.07 * SR), rng), 320.0)
    mix_at(body, [s * 0.4 * math.exp(-i / (SR * 0.02)) for i, s in enumerate(thump)], 0.0)
    return _event(body, 0.105, wet=0.08, tail_s=0.35, seed=_seed_of(name))


def build_error(name):
    """Erro: duas notas graves descendo Mi3→Dó3 — "perdeu", suave."""
    rng = rng_for(name)
    body = glass_tone(164.81, 0.25, [(1.0, 1.0, 85.0), (2.0, 0.2, 45.0)])
    mix_at(body, glass_tone(130.81, 0.30, [(1.0, 1.0, 95.0), (2.0, 0.2, 50.0)]), 0.12, 0.95)
    thump = one_pole_lp(pink_noise(int(0.09 * SR), rng), 280.0)
    mix_at(body, [s * 0.5 * math.exp(-i / (SR * 0.025)) for i, s in enumerate(thump)], 0.0)
    return _event(body, 0.115, wet=0.10, tail_s=0.4, seed=_seed_of(name))


def build_freeze(name):
    """Congelar: vidro descendo C6→E5 + faísca gelada apagando."""
    rng = rng_for(name)
    body = glass_tone(1046.50, 0.25, [(1.0, 1.0, 90.0), (2.756, 0.25, 50.0)])
    mix_at(body, glass_tone(783.99, 0.25, [(1.0, 1.0, 85.0), (2.756, 0.22, 45.0)]), 0.07, 0.85)
    mix_at(body, glass_tone(659.26, 0.30, [(1.0, 1.0, 90.0), (2.756, 0.2, 45.0)]), 0.14, 0.8)
    ice = one_pole_hp(pink_noise(int(0.4 * SR), rng), 6500.0)
    ice_env = env_ar(len(ice), 0.02, 0.34)
    mix_at(body, [s * e * 0.14 for s, e in zip(ice, ice_env)], 0.0)
    return _event(body, 0.120, wet=0.18, tail_s=0.5, seed=_seed_of(name))


# --------------------------------------------------------------- catálogo ---

## Construtores dos one-shots (eventos): nome → builder.
ONESHOT_BUILDERS = {
    "spray_0": lambda n: build_spray(n, SPRAY_PINGS[0]),
    "spray_1": lambda n: build_spray(n, SPRAY_PINGS[1]),
    "spray_2": lambda n: build_spray(n, SPRAY_PINGS[2]),
    "window": build_window,
    "tap": build_tap,
    "tool_pickup": build_tool_pickup,
    "panel_open": build_panel_open,
    "equip": build_equip,
    "service_start": build_service_start,
    "coin": build_coin,
    "perfect": build_perfect,
    "upgrade": build_upgrade,
    "level_up": build_level_up,
    "review": build_review,
    "pass_claim": build_pass_claim,
    "prestige": build_prestige,
    "comeback": build_comeback,
    "share_saved": build_share_saved,
    "pet_happy": build_pet_happy,
    "pet_surprise": build_pet_surprise,
    "error_soft": build_error_soft,
    "error": build_error,
    "freeze": build_freeze,
}


def build_sound(name):
    """Gera `name` → (canais, é_estéreo)."""
    for base, ladder in LADDERS.items():
        if name.startswith(base + "_"):
            idx = int(name.split("_")[1])
            value = ladder[idx]
            if base == "bubble":
                return build_bubble_tick(name, value)
            if base == "clipper":
                return build_clipper_tick(name, value)
            if base == "dryer":
                return build_dryer_tick(name, value)
            return build_bow_tick(name, value)
    if name in ONESHOT_BUILDERS:
        return ONESHOT_BUILDERS[name](name)
    raise KeyError(name)


def all_names():
    names = []
    for base in LADDERS:
        names.extend("%s_%d" % (base, i) for i in range(10))
    names.extend(ONESHOT_BUILDERS)
    return names


# ------------------------------------------------------------------ WAV ----

def samples_to_pcm(name, channels):
    """Quantização 16 bits com dither TPDF (sem buzz de quantização)."""
    rng = rng_for("dither" + name + ".wav")
    frames = []
    for i in range(len(channels[0])):
        for ch in channels:
            dither = (rng.random() + rng.random() - 1.0) / 32767.0
            v = int(round(max(-1.0, min(1.0, ch[i] + dither)) * 32767.0))
            frames.append(v)
    return frames


def write_wav(path, channels):
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(len(channels))
        handle.setsampwidth(2)
        handle.setframerate(SR)
        frames = samples_to_pcm(path.name[:-4], channels)
        handle.writeframes(b"".join(v.to_bytes(2, "little", signed=True) for v in frames))


def read_wav(path):
    with wave.open(str(path), "rb") as handle:
        assert handle.getsampwidth() == 2, f"{path.name}: não é 16 bits"
        nch = handle.getnchannels()
        rate = handle.getframerate()
        n = handle.getnframes()
        raw = handle.readframes(n)
    vals = [int.from_bytes(raw[i * 2:i * 2 + 2], "little", signed=True) for i in range(n * nch)]
    channels = [vals[c::nch] for c in range(nch)]
    return channels, rate


# -------------------------------------------------------------- validação ---

def validate_manifest():
    """Contratos musicais (rápido, sem renderizar): pentatônica e escadas."""
    errors = []
    for base in ("bubble", "clipper", "bow"):
        ladder = LADDERS[base]
        if len(ladder) != 10:
            errors.append(f"escada {base}: {len(ladder)} degraus (mínimo 10)")
        for f in ladder:
            if round(f, 2) not in ALLOWED_PITCHES:
                errors.append(f"escada {base}: {f} fora da pentatônica")
        if any(b <= a for a, b in zip(ladder, ladder[1:])):
            errors.append(f"escada {base} não é ascendente")
    if len(LADDERS["dryer"]) != 10 or any(
        b <= a for a, b in zip(LADDERS["dryer"], LADDERS["dryer"][1:])
    ):
        errors.append("escada dryer (brilho) inválida")
    if len(SPRAY_PINGS) != 3 or any(
        b <= a for a, b in zip(SPRAY_PINGS, SPRAY_PINGS[1:])
    ):
        errors.append("borrifadas do perfume devem ser 3 notas ascendentes")
    for f in SPRAY_PINGS:
        if round(f, 2) not in ALLOWED_PITCHES:
            errors.append(f"perfume: {f} fora da pentatônica")
    return errors


def validate_assets(rendered):
    """Contratos de qualidade sobre as amostras renderizadas (float)."""
    errors = []
    tick_names = [n for n in rendered if n.split("_")[0] in LADDERS]
    oneshot_names = [n for n in rendered if n not in tick_names]
    peaks = {}
    for name, (channels, nch) in rendered.items():
        n = len(channels[0])
        dur = n / SR
        peak = max((abs(s) for ch in channels for s in ch), default=0.0)
        mean = sum(channels[0]) / max(1, n)
        peaks[name] = peak
        if name in tick_names:
            if not 0.05 <= dur <= 0.40:
                errors.append(f"{name}: duração de tick {dur:.3f}s")
            if nch != 1:
                errors.append(f"{name}: tick deve ser mono")
        else:
            if not 0.10 <= dur <= 2.4:
                errors.append(f"{name}: duração {dur:.3f}s")
            if nch != 2:
                errors.append(f"{name}: evento deve ser estéreo")
        if peak > 0.999:
            errors.append(f"{name}: clipping (pico {peak:.3f})")
        if abs(mean) > 0.003:
            errors.append(f"{name}: offset DC {mean:.4f}")
        # bordas sem estalo: o degrau silêncio→som é o que estala; a rampa
        # interna é conteúdo (transiente natural da tesourada, do pluck...).
        ch0 = channels[0]
        if abs(ch0[0]) > 0.005 * peak:
            errors.append(f"{name}: degrau no primeiro sample (estalo)")
        if abs(ch0[-1]) > 0.005 * peak:
            errors.append(f"{name}: degrau no último sample (estalo)")
    # todos os degraus da escada igualmente audíveis (nada de agudo sumido)
    for base in LADDERS:
        rungs = [n for n in rendered if n.split("_")[0] == base]
        rms = []
        for name in rungs:
            ch = rendered[name][0][0]
            rms.append(math.sqrt(sum(s * s for s in ch) / len(ch)))
        if rms and max(rms) / max(1e-9, min(rms)) > 1.35:
            errors.append(f"escada {base}: degraus com loudness desigual "
                          f"(RMS {min(rms):.4f}..{max(rms):.4f})")
    # subida audível: a frequência dominante sobe com o degrau (tonais)
    for base in ("bubble", "clipper"):
        freqs = []
        for i in range(10):
            ch = rendered[f"{base}_{i}"][0][0]
            act = [j for j, s in enumerate(ch) if abs(s) > 0.05 * max(abs(s) for s in ch)]
            mid = ch[act[0] + (act[-1] - act[0]) // 3: act[0] + 2 * (act[-1] - act[0]) // 3]
            zc = sum(1 for a, b in zip(mid, mid[1:]) if (a >= 0) != (b >= 0))
            freqs.append(zc / 2 / (len(mid) / SR))
        if any(b < a * 0.92 for a, b in zip(freqs, freqs[1:])):
            errors.append(f"escada {base} não sobe de forma audível: {[round(f) for f in freqs]}")
        if freqs[-1] < freqs[0] * 1.6:
            errors.append(f"escada {base}: subida fraca ({freqs[0]:.0f}→{freqs[-1]:.0f} Hz)")
    # ticks de loop (repetem ~6x/s) claramente abaixo dos one-shots
    if tick_names and oneshot_names:
        tick_max = max(peaks[n] for n in tick_names)
        sorted_p = sorted(peaks[n] for n in oneshot_names)
        oneshot_median = sorted_p[len(sorted_p) // 2]
        if tick_max > 0.65 * oneshot_median:
            errors.append(
                f"ticks altos demais: pico {tick_max:.4f} vs one-shot mediano {oneshot_median:.4f}"
            )
    return errors


def compare_with_files(rendered):
    """Assets versionados batem (amostra a amostra) com a geração atual?"""
    drift = []
    for name, (channels, nch) in rendered.items():
        path = ASSET_DIR / f"{name}.wav"
        if not path.exists():
            drift.append(f"{name}.wav: asset ausente — rode sem --check")
            continue
        disk_ch, disk_rate = read_wav(path)
        if disk_rate != SR or len(disk_ch) != nch:
            drift.append(f"{name}.wav: formato divergente")
            continue
        expect = samples_to_pcm(name, channels)  # entrelaçado por frame
        flat = [v for frame in zip(*disk_ch) for v in frame]  # idem
        if len(flat) != len(expect):
            drift.append(f"{name}.wav: tamanho divergente")
            continue
        worst = 0
        differing = 0
        for a, b in zip(flat, expect):
            d = abs(a - b)
            if d:
                differing += 1
                worst = max(worst, d)
        # tolerância: libm pode divergir em ~1 ulp entre plataformas
        if worst > 4 or differing > len(flat) * 0.005:
            drift.append(f"{name}.wav: drift (max {worst} LSB, {differing} amostras)")
    return drift


# ------------------------------------------------------------- exportação ---

LOOP_SPACING = 0.16


def demo_stream(tick_names, spacing=LOOP_SPACING):
    """Rampa 0→100% (nota subindo com wiggle + swell + jitter) e aviso muted."""
    n = len(tick_names)
    out = [0.0]
    for tick in range(30):
        progress = (tick + 0.5) / 30.0
        rung = min(int(progress * n), n - 1)
        if tick % 2 == 1:
            rung = min(rung + 1, n - 1)
        name = tick_names[rung]
        channels, _ = build_sound(name)
        mono = channels[0]
        jitter = 1.0 + ((tick * 37) % 17 - 8) / 1000.0  # ±0.8%
        mono = resample(mono, 1.0 / jitter)
        gain = 0.8 + 0.4 * progress
        mix_at(out, [s * gain for s in mono], (spacing * tick), 1.0)
    for k in range(3):  # drenando: uma oitava abaixo, mais baixo
        channels, _ = build_sound(tick_names[n - 1])
        muted = resample(channels[0], 2.0)
        mix_at(out, [s * 0.5 for s in muted], spacing * (30 + k), 1.0)
    return out


def export_demos(preview_dir):
    demos = {
        "demo_loop_banho_bubble": ["bubble_%d" % i for i in range(10)],
        "demo_loop_tosa_clipper": ["clipper_%d" % i for i in range(10)],
        "demo_loop_secagem_dryer": ["dryer_%d" % i for i in range(10)],
        "demo_loop_laco_bow": ["bow_%d" % i for i in range(10)],
    }
    for demo, names in demos.items():
        stream = demo_stream(names)
        write_wav(preview_dir / f"{demo}.wav", [stream])
    # história do perfume: 3 borrifadas subindo + janela perfeita
    story = [0.0]
    for i, ping in enumerate(SPRAY_PINGS):
        channels, _ = build_sound("spray_%d" % i)
        mix_at(story, channels[0], 0.45 * i)
    window_ch, _ = build_sound("window")
    mix_at(story, window_ch[0], 1.5)
    write_wav(preview_dir / "demo_perfume_e_janela.wav", [story])


INDEX_MD = """# Preview dos SFX (assets reais do jogo)

Cada arquivo é EXATAMENTE o WAV que o jogo carrega em `assets/audio/sfx/` —
44.1 kHz, 16 bits, eventos em estéreo com reverb, dither TPDF. Síntese por
modelagem física (`tools/gen_sfx.py`), um instrumento diferente por ação.

## Como ouvir a progressão

| Demo | O que conta |
|---|---|
| demo_loop_banho_bubble | arrastar do banho: bolhas subindo 0→100% + aviso grave no fim (drenando) |
| demo_loop_tosa_clipper | tesouradas com anel subindo + aviso |
| demo_loop_secagem_dryer | sopro de ar ficando mais brilhante + aviso |
| demo_loop_laco_bow | corda dedilhada subindo a pentatônica + aviso |
| demo_perfume_e_janela | as 3 borrifadas (C6→D6→E6) e o chime "pode soltar" |

## Catálogo

| Som | Instrumento / ação |
|---|---|
| bubble_* | banho — bolhas d'água (glissando de Minnaert) |
| clipper_* | tosa — tesourada: lâmina + anel de aço + fechamento |
| dryer_* | secagem — sopro de ar rosa (brilho sobe com o progresso) |
| bow_* | laço — corda de nylon dedilhada (Karplus-Strong) |
| spray_0/1/2 | perfume — atomizador + sino de vidro (C6, D6, E6) |
| window | janela perfeita — harpa de vidro "pode soltar" |
| tap / tool_pickup / panel_open / equip | UI — marimba, pano, gaveta, velcro |
| service_start | água caindo + bolhas + marimba |
| coin / perfect / upgrade / level_up / pass_claim / prestige | recompensas — moeda, harpa, run de cordas |
| review / comeback / share_saved | social — vidro suave, acolhimento, obturador |
| pet_happy / pet_surprise | pets — glides quentes (gorjeio) |
| error / error_soft / freeze | erros — notas graves escuras, gelo |
"""


def render_all():
    rendered = {}
    for name in all_names():
        channels, _stereo = build_sound(name)
        rendered[name] = (channels, len(channels))
    return rendered


def main():
    errors = validate_manifest()
    for error in errors:
        print(f"ERRO: {error}")

    if "--check" in sys.argv:
        rendered = render_all()
        errors += validate_assets(rendered)
        drift = compare_with_files(rendered)
        for d in drift:
            print(f"DRIFT: {d}")
        print(f"sfx: {len(rendered)} sons | erros: {len(errors)} | drift: {len(drift)}")
        return 1 if errors or drift else 0

    rendered = render_all()
    errors += validate_assets(rendered)
    for error in errors:
        print(f"ERRO: {error}")
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    for name, (channels, nch) in rendered.items():
        write_wav(ASSET_DIR / f"{name}.wav", channels)
    # preview: cópia dos assets + demos de gameplay + índice
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    for name in all_names():
        (PREVIEW_DIR / f"{name}.wav").write_bytes((ASSET_DIR / f"{name}.wav").read_bytes())
    export_demos(PREVIEW_DIR)
    (PREVIEW_DIR / "index.md").write_text(INDEX_MD, encoding="utf8")
    print(f"sfx gerados: {len(rendered)} em {ASSET_DIR.relative_to(ROOT)}")
    print(f"preview: {PREVIEW_DIR.relative_to(ROOT)} (+ demos)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
