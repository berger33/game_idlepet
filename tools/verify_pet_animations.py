#!/usr/bin/env python3
"""Verificação funcional das animações de estado dos 50 pets (500 PNGs).

Confere o contrato completo ponta a ponta: tracker -> catálogo -> arquivos ->
formato de imagem -> integração no renderer (PetShopCanvas.gd). Executável sem
o editor Godot; usa apenas Pillow (já instalado no CI).
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ERRORS: list[str] = []
WARNINGS: list[str] = []

EXPECTED_SIZE = 512
MIN_OPAQUE_PIXELS = 3000
MIN_TRANSPARENT_PIXELS = 3000


def require(condition: bool, message: str) -> None:
    if not condition:
        ERRORS.append(message)


def warn(condition: bool, message: str) -> None:
    if not condition:
        WARNINGS.append(message)


def load_json(relative: str) -> dict:
    path = ROOT / relative
    require(path.exists(), f"arquivo ausente: {relative}")
    if not path.exists():
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        ERRORS.append(f"JSON inválido {relative}: {error}")
        return {}
    return value if isinstance(value, dict) else {}


def verify_tracker_contract(tracker: dict) -> dict[str, dict]:
    """Estados autorais, status por pet/estado e resumo recalculado."""
    authored: list[str] = tracker.get("authored_states", [])
    expected_states = [
        "dirty", "wet", "messy", "tilt_left", "tilt_right",
        "happy_squash", "happy_air", "dizzy", "sad", "blink",
    ]
    require(authored == expected_states, "authored_states diverge do contrato de 10 estados")

    pets = tracker.get("pets", [])
    require(len(pets) == 50, f"esperados 50 pets no tracker, encontrados {len(pets)}")

    states_by_pet: dict[str, dict] = {}
    qa_passed_total = 0
    attempts_total = 0
    for pet in pets:
        pet_id = pet.get("pet_id", "<sem id>")
        label = f"{pet.get('sequence', '?')} {pet_id}"
        states = pet.get("states", {})
        require(
            list(states.keys()) == expected_states,
            f"{label}: estados != contrato (faltando/extra: {set(expected_states) ^ set(states)})",
        )
        require(pet.get("generation_status") == "complete", f"{label}: generation_status != complete")
        require(pet.get("normalization_status") == "complete", f"{label}: normalization_status != complete")
        require(pet.get("visual_qa_status") == "passed", f"{label}: visual_qa_status != passed")
        require(pet.get("integration_status") == "integrated", f"{label}: integration_status != integrated")
        for state_name, entry in states.items():
            require(
                entry.get("status") == "qa_passed",
                f"{label}/{state_name}: status {entry.get('status')!r} != qa_passed",
            )
            qa_passed_total += 1
        attempts_total += int(pet.get("generation_attempts", 0))
        states_by_pet[pet_id] = states

    summary = tracker.get("summary", {})
    expected_summary = {
        "pets_total": len(pets),
        "pets_generated": len(pets),
        "images_expected": len(pets) * len(expected_states),
        "images_generated": qa_passed_total,
        "images_qa_passed": qa_passed_total,
        "pets_integrated": len(pets),
        "generation_attempts": attempts_total,
    }
    for key, value in expected_summary.items():
        require(
            summary.get(key) == value,
            f"summary.{key}={summary.get(key)!r} diverge do valor recalculado {value!r}",
        )
    return states_by_pet


def verify_renderer_contract(states_by_pet: dict[str, dict]) -> None:
    """O renderer precisa carregar exatamente os estados produzidos."""
    canvas_path = ROOT / "core/gameplay/PetShopCanvas.gd"
    require(canvas_path.exists(), "PetShopCanvas.gd ausente")
    if not canvas_path.exists():
        return
    canvas = canvas_path.read_text(encoding="utf-8")

    match = re.search(r"PET_STATE_NAMES: Array\[StringName\] = \[(.*?)\]", canvas, re.DOTALL)
    require(match is not None, "PET_STATE_NAMES não encontrado no renderer")
    if match:
        runtime_states = re.findall(r"&\"([a-z_]+)\"", match.group(1))
        expected_states = list(next(iter(states_by_pet.values())).keys()) if states_by_pet else []
        expected_states += load_json("data/pet_animation_production.json").get(
            "blink_variant_states", []
        )
        require(
            runtime_states == expected_states,
            f"estados do renderer != tracker: {runtime_states}",
        )
    require(
        'res://art/pet_animations/%s/%s.png' in canvas,
        "formato de caminho das animações ausente no renderer",
    )
    for state_name in ("dirty", "wet", "messy", "tilt_left", "tilt_right",
                       "happy_squash", "happy_air", "dizzy", "sad", "blink"):
        require(
            f'&"{state_name}"' in canvas,
            f"estado {state_name} sem gatilho funcional no renderer",
        )


def verify_catalog_and_files(states_by_pet: dict[str, dict]) -> None:
    """Catálogo <-> tracker <-> diretórios <-> PNGs válidos e rastreados no git."""
    catalog = load_json("data/pets.json").get("pets", [])
    catalog_ids = {pet.get("id") for pet in catalog}
    require(len(catalog_ids) == 50, f"catálogo com {len(catalog_ids)} ids (esperado 50)")
    require(
        set(states_by_pet) == catalog_ids,
        f"tracker e catálogo divergem: {set(states_by_pet) ^ catalog_ids}",
    )

    variant_states = load_json("data/pet_animation_production.json").get("blink_variant_states", [])

    anim_root = ROOT / "art/pet_animations"
    dir_ids = {path.name for path in anim_root.iterdir() if path.is_dir()} if anim_root.exists() else set()
    require(
        dir_ids == catalog_ids,
        f"diretórios de animação divergem do catálogo: {dir_ids ^ catalog_ids}",
    )

    try:
        tracked = set(
            subprocess.run(
                # quotepath=off evita escapes octal em paths com acento (ex.: paçoca).
                ["git", "-c", "core.quotepath=off", "ls-files", "--", "art/pet_animations"],
                cwd=ROOT, capture_output=True, text=True, check=True,
            ).stdout.split()
        )
    except subprocess.CalledProcessError:
        tracked = set()
        WARNINGS.append("git ls-files indisponível; rastreio git não verificado")

    from PIL import Image

    checked = 0
    for pet_id in sorted(states_by_pet):
        base_sprite = ROOT / "art/pets" / f"{pet_id}.png"
        require(base_sprite.exists(), f"sprite base ausente: art/pets/{pet_id}.png")

        pet_dir = anim_root / pet_id
        files = {path.name for path in pet_dir.iterdir() if path.is_file()} if pet_dir.exists() else set()
        expected_files = {f"{state}.png" for state in states_by_pet[pet_id]}
        expected_files |= {f"{variant}.png" for variant in variant_states}
        require(
            files == expected_files,
            f"{pet_id}: arquivos {sorted(files ^ expected_files)} faltando/extra",
        )
        # Variantes de piscada por estado (BLINK_MATRIX): contrato 512 RGBA.
        for variant in variant_states:
            variant_path = pet_dir / f"{variant}.png"
            require(variant_path.exists(), f"{pet_id}/{variant}: arquivo ausente")
            if not variant_path.exists():
                continue
            with Image.open(variant_path) as variant_image:
                require(
                    variant_image.size == (512, 512) and variant_image.mode == "RGBA",
                    f"{pet_id}/{variant}: formato {variant_image.size}/{variant_image.mode}",
                )

        for state_name, entry in states_by_pet[pet_id].items():
            rel_path = entry.get("path", "")
            path = ROOT / rel_path
            label = f"{pet_id}/{state_name}"
            require(path.exists(), f"{label}: arquivo ausente: {rel_path}")
            if not path.exists():
                continue
            require(
                rel_path == f"art/pet_animations/{pet_id}/{state_name}.png",
                f"{label}: caminho do tracker inesperado: {rel_path}",
            )
            require(
                f"art/pet_animations/{pet_id}/{state_name}.png" in tracked,
                f"{label}: PNG não rastreado no git",
            )

            raw = path.read_bytes()
            require(raw[:8] == b"\x89PNG\r\n\x1a\n", f"{label}: assinatura PNG inválida")
            require(len(raw) > 25_000, f"{label}: PNG suspeito de estar vazio ({len(raw)} bytes)")

            with Image.open(path) as image:
                require(
                    image.size == (EXPECTED_SIZE, EXPECTED_SIZE),
                    f"{label}: dimensões {image.size} != 512x512",
                )
                require(
                    image.mode == "RGBA",
                    f"{label}: modo {image.mode} != RGBA",
                )
                alpha = image.getchannel("A")
                histogram = alpha.histogram()
                transparent = sum(histogram[:32])
                opaque = sum(histogram[224:])
                require(
                    transparent >= MIN_TRANSPARENT_PIXELS,
                    f"{label}: sem transparência real ({transparent} px)",
                )
                require(
                    opaque >= MIN_OPAQUE_PIXELS,
                    f"{label}: conteúdo visível insuficiente ({opaque} px)",
                )
                # Painel de fundo colado renderizaria como quadrado no jogo.
                require(
                    histogram[255] < EXPECTED_SIZE * EXPECTED_SIZE * 0.97,
                    f"{label}: quase totalmente opaco (fundo não removido?)",
                )
                # Margens seguras: a arte não deve encostar nas bordas do canvas.
                bbox = image.getbbox()
                if bbox:
                    warn(
                        bbox[0] > 0 and bbox[1] > 0 and bbox[2] < EXPECTED_SIZE and bbox[3] < EXPECTED_SIZE,
                        f"{label}: arte encosta na borda (bbox={bbox})",
                    )
            checked += 1
    print(f"imagens verificadas: {checked}")


def main() -> int:
    tracker = load_json("data/pet_animation_production.json")
    states_by_pet = verify_tracker_contract(tracker)
    verify_renderer_contract(states_by_pet)
    verify_catalog_and_files(states_by_pet)
    for warning in WARNINGS:
        print("WARNING:", warning)
    for error in ERRORS:
        print("ERROR:", error)
    print(f"pet_animations: {len(ERRORS)} errors, {len(WARNINGS)} warnings")
    return 1 if ERRORS else 0


if __name__ == "__main__":
    sys.exit(main())
