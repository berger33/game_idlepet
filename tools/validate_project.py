#!/usr/bin/env python3
"""Validação estrutural/data-driven executável sem o editor Godot."""
from __future__ import annotations
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ERRORS: list[str] = []
WARNINGS: list[str] = []


def require(condition: bool, message: str) -> None:
    if not condition:
        ERRORS.append(message)


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
    require(isinstance(value, dict), f"raiz JSON não é objeto: {relative}")
    return value if isinstance(value, dict) else {}


def validate_resource_paths() -> None:
    for path in ROOT.rglob("*"):
        if not path.is_file() or ".git" in path.parts:
            continue
        if path.suffix not in {".gd", ".tscn", ".godot", ".cfg"}:
            continue
        text = path.read_text(encoding="utf-8")
        for match in re.finditer(r'res://([^"\n]+)', text):
            resource = match.group(1)
            if "%" in resource or "{" in resource:
                continue  # caminho dinâmico validado pelo catálogo específico
            require((ROOT / resource).exists(), f"recurso quebrado em {path.relative_to(ROOT)}: {resource}")


def validate_catalogs() -> None:
    pets = load_json("data/pets.json").get("pets", [])
    require(len(pets) == 50, "catálogo deve conter exatamente 50 pets nesta versão")
    ids = [pet.get("id") for pet in pets]
    require(len(ids) == len(set(ids)), "IDs duplicados em pets")
    require(sum(pet.get("species") == "dog" for pet in pets) == 25, "esperados 25 cães")
    require(sum(pet.get("species") == "cat" for pet in pets) == 25, "esperados 25 gatos")
    allowed_rarities = {"common", "uncommon", "rare", "epic", "legendary"}
    for pet in pets:
        pet_id = pet.get("id", "<sem id>")
        require(pet.get("rarity") in allowed_rarities, f"raridade inválida: {pet_id}")
        require(pet.get("preferred_service") in {"bath", "groom"}, f"serviço inválido: {pet_id}")
        require(1 <= int(pet.get("unlock_level", 0)) <= 120, f"unlock inválido: {pet_id}")
        colors = pet.get("colors", [])
        require(len(colors) == 3, f"paleta incompleta: {pet_id}")
        for color in colors:
            require(bool(re.fullmatch(r"[0-9a-fA-F]{6}", str(color))), f"cor inválida em {pet_id}: {color}")

    career = load_json("data/career_track.json")
    establishments = career.get("establishments", [])
    require([item.get("tier") for item in establishments] == list(range(1, 11)), "tiers devem ser 1..10")
    levels = [int(item.get("unlock_level", 0)) for item in establishments]
    require(levels == sorted(levels) and levels[-1:] == [120], "carreira deve crescer e terminar no nível 120")

    layouts = load_json("data/service_layouts.json").get("stages", [])
    require(len(layouts) == 5, "esperados cinco layouts de serviço")
    require([item.get("unlock_level") for item in layouts] == [1, 3, 5, 7, 10], "gates de salas inválidos")
    for layout in layouts:
        service = layout.get("service", "<sem serviço>")
        require(len(layout.get("pet_position", [])) == 2, f"posição de pet inválida: {service}")
        shelves = layout.get("shelf_y", [])
        require(len(shelves) == 5 and shelves == sorted(shelves), f"prateleiras inválidas: {service}")
        require((ROOT / "art/backgrounds" / layout.get("background", "")).exists(), f"fundo ausente: {service}")

    pet_art = list((ROOT / "art/pets").glob("*.png"))
    require(len(pet_art) >= 20, "dois lotes de arte dos pets devem conter vinte sprites")
    valid_pet_ids = {pet.get("id") for pet in pets}
    for path in pet_art:
        raw = path.read_bytes()
        require(path.stem in valid_pet_ids, f"sprite sem entrada no catálogo: {path.stem}")
        require(len(raw) > 150_000, f"sprite de pet simplificado demais: {path.stem}")
        require(len(raw) > 25 and raw[25] == 6, f"sprite de pet sem canal alfa: {path.stem}")

    for tool in ("soap", "clipper", "dryer", "perfume", "bow"):
        path = ROOT / "art/props" / f"tool_{tool}.png"
        require(path.exists(), f"arte de utensílio ausente: {tool}")
        if path.exists():
            raw = path.read_bytes()
            require(len(raw) > 100_000, f"arte de utensílio simplificada demais: {tool}")
            require(len(raw) > 25 and raw[25] == 6, f"utensílio sem canal alfa RGBA: {tool}")

    upgrades = load_json("data/upgrades.json").get("upgrades", [])
    for upgrade in upgrades:
        require(int(upgrade.get("levels", 0)) > 0, f"upgrade sem níveis: {upgrade.get('id')}")
        require(float(upgrade.get("base_cost", 0)) > 0, f"upgrade sem custo: {upgrade.get('id')}")
        require(float(upgrade.get("growth", 0)) > 1.0, f"upgrade sem crescimento: {upgrade.get('id')}")


def validate_project_contract() -> None:
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    require('run/main_scene="res://scenes/main/Main.tscn"' in project, "main scene incorreta")
    for autoload in ("EventBus", "ContentDB", "GameState", "SaveManager", "AudioManager", "InteractionFX"):
        require(re.search(rf"^{autoload}=", project, re.MULTILINE) is not None, f"autoload ausente: {autoload}")
    main = (ROOT / "scenes/main/Main.gd").read_text(encoding="utf-8")
    require(main.count("Button.new()") == 1, "Button criado fora da factory universal")
    require("InteractionFX.bind_button(button)" in main, "feedback universal não ligado")
    state = (ROOT / "autoload/GameState.gd").read_text(encoding="utf-8")
    require("const SAVE_VERSION: int = 6" in state, "versão de save inesperada")


def validate_repository_hygiene() -> None:
    forbidden = {".env", "google-services.json", "GoogleService-Info.plist"}
    for path in ROOT.rglob("*"):
        if ".git" in path.parts or not path.is_file():
            continue
        require(path.name not in forbidden, f"credencial/configuração sensível versionada: {path.name}")
        if path.stat().st_size > 5_000_000:
            WARNINGS.append(f"arquivo acima de 5 MB: {path.relative_to(ROOT)}")


def main() -> int:
    validate_resource_paths()
    validate_catalogs()
    validate_project_contract()
    validate_repository_hygiene()
    for warning in WARNINGS:
        print("WARNING:", warning)
    for error in ERRORS:
        print("ERROR:", error)
    print(f"validation: {len(ERRORS)} errors, {len(WARNINGS)} warnings")
    return 1 if ERRORS else 0


if __name__ == "__main__":
    sys.exit(main())
