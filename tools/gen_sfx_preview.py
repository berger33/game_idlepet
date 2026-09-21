"""Gera e valida os SFX procedurais do AudioManager (porta fiel em Python).

O AudioManager.gd é a fonte única da verdade: este tool faz PARSE das linhas
de cache (notas, durações, volumes) e sintetiza as mesmas ondas das fórmulas
GDScript. Isso serve para:

  1. QA programático de som (sem ouvidos): sem clipping, ataque sem clique
     (o "bip" antigo), todo tom é pentatônico, ticks de loop mais baixos
     que os one-shots, determinismo do ruído;
  2. Audição: exporta .preview/sfx/*.wav para escutar cada som antes do CI.

Uso:
  python tools/gen_sfx_preview.py            # valida + exporta wavs
  python tools/gen_sfx_preview.py --check    # só valida (exit 1 se falhar)
"""

import math
import re
import sys
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SR = 22050
TAU = math.tau
ATTACK = 0.12
OUT_DIR = ROOT / ".preview" / "sfx"

# Pentatônica de Dó maior (const no AudioManager) + oitavas baixas/altas
# usadas pelos sons graves de erro e pelo topo do prestígio.
BASE_PENTATONIC = [261.63, 293.66, 329.63, 392.00, 440.00,
                   523.25, 587.33, 659.26, 783.99, 880.00,
                   1046.50, 1174.66, 1318.51]
ALLOWED_PITCHES = set(BASE_PENTATONIC)
for _f in BASE_PENTATONIC:
    ALLOWED_PITCHES.add(round(_f * 0.5, 2))
    ALLOWED_PITCHES.add(round(_f * 2.0, 2))


# ---------------------------------------------------------------- síntese --
def synth_pluck(freqs, dur, vol):
    fpn = int(SR * dur)
    out = []
    for f in freqs:
        for i in range(fpn):
            t = i / fpn
            env = min(t / ATTACK, 1.0) * (1.0 - t) ** 2.4
            phase = TAU * f * i / SR
            w = math.sin(phase)
            w += math.sin(TAU * f * 1.004 * i / SR) * 0.24
            w += math.sin(phase * 2.0) * 0.30 * (1.0 - t) ** 1.4
            w += math.sin(phase * 3.0) * 0.08 * (1.0 - t) ** 1.9
            out.append(w * env * vol)
    return out


def synth_bloop(freqs, dur, vol):
    fpn = int(SR * dur)
    out = []
    for target in freqs:
        phase = 0.0
        for i in range(fpn):
            t = i / fpn
            f = target + target * 0.45 * (1.0 - t) ** 1.3
            phase += TAU * f / SR
            env = min(t / 0.18, 1.0) * (1.0 - t) ** 1.7
            w = math.sin(phase) + math.sin(phase * 2.0) * 0.12 * (1.0 - t)
            out.append(w * env * vol)
    return out


def _norm(samples, vol):
    peak = max(abs(s) for s in samples)
    scale = vol * 0.95 / peak if peak > 0 else 0.0
    return [s * scale for s in samples]


def synth_air(dur, vol, cutoff):
    frames = int(SR * dur)
    filtered = 0.0
    out = []
    for i in range(frames):
        t = i / frames
        noise = (math.fmod(math.sin(i * 12.9898) * 43758.5453, 1.0) * 2.0) - 1.0
        filtered += (noise - filtered) * cutoff
        env = math.sin(math.pi * t) ** 0.8
        out.append(filtered * env)
    return _norm(out, vol)


def synth_spray(vol, ping_hz):
    frames = int(SR * 0.16)
    filtered = 0.0
    out = []
    for i in range(frames):
        t = i / frames
        noise = (math.fmod(math.sin(i * 12.9898) * 43758.5453, 1.0) * 2.0) - 1.0
        filtered += (noise - filtered) * 0.38
        air = filtered * math.sin(math.pi * t) ** 0.7
        ping_env = min(t / ATTACK, 1.0) * (1.0 - t) ** 2.2
        ping = math.sin(TAU * ping_hz * i / SR) * ping_env * 0.25
        out.append(air + ping)
    return _norm(out, vol)


# ------------------------------------------------------------------ parse --
def _floats(text):
    return [float(x) for x in re.findall(r"\d+\.\d+", text)]


def parse_audio_manager():
    """Lê as definições de SFX do AudioManager.gd -> {nome: (gerador, args)}."""
    src = (ROOT / "autoload" / "AudioManager.gd").read_text(encoding="utf8")
    sounds = {}

    for m in re.finditer(
        r'cache\[&"(\w+)"\] = _pluck\((\[[^\]]*\]), ([\d.]+), ([\d.]+)\)', src
    ):
        name, freqs, dur, vol = m.group(1), _floats(m.group(2)), float(m.group(3)), float(m.group(4))
        sounds[name] = ("pluck", (freqs, dur, vol))

    for m in re.finditer(
        r'cache\[&"(\w+)"\] = _bloop\((\[[^\]]*\]), ([\d.]+), ([\d.]+)\)', src
    ):
        name, freqs, dur, vol = m.group(1), _floats(m.group(2)), float(m.group(3)), float(m.group(4))
        sounds[name] = ("bloop", (freqs, dur, vol))

    # Escadas declaradas como variáveis (var X: Array = [...]) — o GDScript
    # agora passa a ladder inteira, não um literal inline.
    ladders = {}
    for m in re.finditer(r'var (\w+): Array = (\[[^\]]*\])', src):
        ladders[m.group(1)] = _floats(m.group(2))

    for m in re.finditer(r'cache\[&"(\w+)"\] = _spray\(([\d.]+), ([\d.]+)\)', src):
        sounds[m.group(1)] = ("spray", (float(m.group(2)), float(m.group(3))))

    for m in re.finditer(r'cache\[&"(\w+)"\] = cache\[&"(\w+)"\]', src):
        if m.group(2) in sounds:
            sounds[m.group(1)] = sounds[m.group(2)]

    for m in re.finditer(
        r'_cache_ticks\(&"(\w+)", &"(\w+)", ((?:\[[^\]]*\])|(?:\w+)), ([\d.]+), ([\d.]+)\)',
        src,
    ):
        base, kind = m.group(1), m.group(2)
        notes_src = m.group(3)
        notes = _floats(notes_src) if notes_src.startswith("[") else ladders.get(notes_src, [])
        dur, vol = float(m.group(4)), float(m.group(5))
        for i, note in enumerate(notes):
            if kind == "bloop":
                sounds[f"{base}_{i}"] = ("bloop", ([note], dur, vol))
            else:
                sounds[f"{base}_{i}"] = ("pluck", ([note], dur, vol))
        sounds[base] = sounds[f"{base}_0"]

    for m in re.finditer(
        r'_cache_air_ticks\(&"(\w+)", ([\d.]+), ([\d.]+), ((?:\[[^\]]*\])|(?:\w+))\)',
        src,
    ):
        base, dur, vol = m.group(1), float(m.group(2)), float(m.group(3))
        bright_src = m.group(4)
        brightness = _floats(bright_src) if bright_src.startswith("[") else ladders.get(bright_src, [])
        for i, cutoff in enumerate(brightness):
            sounds[f"{base}_{i}"] = ("air", (dur, vol, cutoff))
        sounds[base] = sounds[f"{base}_0"]

    return sounds


def render(name, spec):
    kind, args = spec
    if kind == "pluck":
        return synth_pluck(*args)
    if kind == "bloop":
        return synth_bloop(*args)
    if kind == "air":
        return synth_air(*args)
    return synth_spray(*args)


# --------------------------------------------------------------- validação --
def validate(sounds):
    errors = []
    tick_prefixes = ("bubble_", "clipper_", "dryer_", "bow_")
    oneshot_peaks, tick_peaks = [], []

    for name in sorted(sounds):
        samples = render(name, sounds[name])
        spec = sounds[name]
        peak = max(abs(s) for s in samples)
        if peak > 0.999:
            errors.append(f"{name}: clipping (pico {peak:.3f})")
        # Ataque sem clique: a maior derivada nos primeiros 3 ms tem de ser
        # baixa — o _chime antigo saltava direto para a amplitude cheia.
        head = samples[: int(SR * 0.003)]
        jump = max((abs(head[i] - head[i - 1]) for i in range(1, len(head))), default=0.0)
        if jump > 0.12:
            errors.append(f"{name}: transiente de clique no ataque (Δ {jump:.3f})")
        # Cauda sem clique: termina perto de zero.
        if abs(samples[-1]) > 0.02 and spec[0] != "air":
            errors.append(f"{name}: termina longe de zero ({samples[-1]:.3f})")
        # Pentatônica: todo tom melódico pertence à escala.
        if spec[0] in ("pluck", "bloop"):
            for f in spec[1][0]:
                if round(f, 2) not in ALLOWED_PITCHES:
                    errors.append(f"{name}: {f} fora da pentatônica de Dó")
        if name.startswith(tick_prefixes):
            tick_peaks.append(peak)
        elif spec[0] in ("pluck", "bloop"):
            oneshot_peaks.append(peak)

    # Escadas progressivas: 10 degraus por serviço, sempre ascendentes —
    # é isso que faz o jogador OUvir a aproximação dos 100%.
    for base in ("bubble", "clipper", "bow", "dryer"):
        variant_names = sorted(n for n in sounds if n.startswith(base + "_"))
        if len(variant_names) < 5:
            errors.append(f"escada {base}: só {len(variant_names)} degraus (mínimo 5)")
            continue
        key = 2 if base == "dryer" else 0  # dryer sobe pelo corte (brilho), índice 2
        steps = [sounds[n][1][key] for n in variant_names]
        if any(b <= a for a, b in zip(steps, steps[1:])):
            errors.append(f"escada {base} não é ascendente: {steps}")

    sprays = sorted(n for n in sounds if re.fullmatch(r"spray_\d+", n))
    if len(sprays) < 3:
        errors.append(f"perfume: {len(sprays)} borrifadas (mínimo 3, uma por pulso)")

    # Ticks de loop (repetem ~6x/s) precisam ser claramente mais baixos que
    # os one-shots — comparação por PICO (o que domina o volume percebido).
    if tick_peaks and oneshot_peaks:
        tick_max = max(tick_peaks)
        oneshot_median = sorted(oneshot_peaks)[len(oneshot_peaks) // 2]
        if tick_max > 0.65 * oneshot_median:
            errors.append(
                f"ticks de loop altos demais: pico {tick_max:.4f}"
                f" vs one-shot mediano {oneshot_median:.4f}"
            )
    return errors


# --------------------------------------------------------------- exportação --
LOOP_TICK_SPACING = 0.16


def _muted(samples):
    """Tick `muted` (drenando/passou da janela): uma oitava abaixo e mais
    baixo — upsampling linear 2x divide as frequências por 2."""
    out = []
    for i in range(len(samples) * 2):
        pos = i / 2.0
        lo = int(pos)
        frac = pos - lo
        hi = min(lo + 1, len(samples) - 1)
        out.append((samples[lo] * (1.0 - frac) + samples[hi] * frac) * 0.5)
    return out


def export_loop_demos(sounds):
    """Como soa o ARRASTAR de verdade: 30 ticks a 0,16 s com o progresso
    subindo 0→100% (a nota sobe a escada, alternando com o degrau seguinte —
    o jogo acrescenta micro-jitter de afinação por cima) e, no fim, 3 ticks
    `muted` de aviso: uma oitava abaixo, como drenar/passar da janela."""
    demos = {
        "loop_banho_bubble": "bubble",
        "loop_tosa_clipper": "clipper",
        "loop_secagem_dryer": "dryer",
        "loop_laco_bow": "bow",
    }
    for demo, base in demos.items():
        variants = sorted(n for n in sounds if n.startswith(base + "_"))
        if not variants:
            continue
        n = len(variants)
        stream = []
        for tick in range(30):
            progress = (tick + 0.5) / 30.0
            rung = min(int(progress * n), n - 1)
            if tick % 2 == 1:  # movimento: alterna com o degrau seguinte
                rung = min(rung + 1, n - 1)
            stream.extend(render(variants[rung], sounds[variants[rung]]))
            stream.extend([0.0] * int(SR * LOOP_TICK_SPACING))
        for _ in range(3):  # aviso: drenando (oitava abaixo, mais baixo)
            stream.extend(_muted(render(variants[n - 1], sounds[variants[n - 1]])))
            stream.extend([0.0] * int(SR * LOOP_TICK_SPACING))
        write_wav(OUT_DIR / f"demo_{demo}.wav", stream)


def write_wav(path, samples):
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SR)
        frames = b"".join(
            int(max(-1.0, min(1.0, s)) * 32767.0).to_bytes(2, "little", signed=True)
            for s in samples
        )
        handle.writeframes(frames)


def export_wavs(sounds):
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name in sorted(sounds):
        samples = render(name, sounds[name])
        path = OUT_DIR / f"{name}.wav"
        write_wav(path, samples)
    export_loop_demos(sounds)
    (OUT_DIR / "index.md").write_text(
        "# Preview dos SFX (síntese idêntica ao jogo)\n\n"
        "Cada arquivo é o WAV exato que o AudioManager gera em runtime para o "
        "som correspondente. Variantes `*_0..9` são os DEGRAUS da escada "
        "pentatônica que o `play_progress` sobe conforme o progresso da ação "
        "chega perto dos 100% (com micro-jitter por cima, no jogo).\n\n"
        "| Som | O que é |\n|---|---|\n"
        "| bubble_* | banho — gotas d'água (a chuvinha do esfregar) |\n"
        "| clipper_* | tosa — duo grave abafado (ritmo de tesourada) |\n"
        "| dryer_* | secagem — sopros de ar filtrado |\n"
        "| bow_* | laço — harpa pentatônica |\n"
        "| spray_0 / spray_1 / spray_2 | borrifadas do perfume — cada uma sobe uma nota; a 3ª é o perfect |\n"
        "| window | chime da janela perfeita — \"pode soltar\" |\n"
        "| tap / panel_open / equip | toques de UI |\n"
        "| coin / perfect / upgrade / level_up / prestige | recompensas |\n"
        "| error / error_soft | erros suaves e graves |\n"
        "| pet_happy / pet_surprise | reações do pet (gotas) |\n"
        "| demo_loop_* | o arrastar de cada serviço: rampa 0→100% (nota subindo) + 3 ticks de aviso \"drenando\" |\n",
        encoding="utf8",
    )
    return len(sounds)


def main():
    sounds = parse_audio_manager()
    if not sounds:
        print("gen_sfx_preview: nenhuma definição encontrada (parse falhou?)")
        return 1
    errors = validate(sounds)
    for error in errors:
        print(f"ERRO: {error}")
    print(f"sfx parseados: {len(sounds)} | erros: {len(errors)}")
    if "--check" in sys.argv:
        return 1 if errors else 0
    count = export_wavs(sounds)
    print(f"wavs exportados: {count} em {OUT_DIR.relative_to(ROOT)}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
