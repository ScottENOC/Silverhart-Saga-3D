#!/usr/bin/env python3
"""Validate source-backed NPC, enemy and Arena roster manifests."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
NPCS = ROOT / "data/characters/legacy_named_npcs.json"
ENEMIES = ROOT / "data/characters/legacy_enemy_roster.json"
ARENA = ROOT / "data/arena/arena_opponents.json"
VALID_MODEL_STATES = {"hollowmere_profile_available", "appearance_profile_required", "3d_model_required"}


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def unique_ids(items, label):
    ids = [item.get("id", "") for item in items]
    if not all(ids):
        raise SystemExit(f"{label}: empty id")
    if len(ids) != len(set(ids)):
        raise SystemExit(f"{label}: duplicate ids")


def main():
    npcs = load(NPCS).get("named_npcs", [])
    enemies = load(ENEMIES).get("enemies", [])
    arena = load(ARENA)
    unique_ids(npcs, "NPC roster")
    unique_ids(enemies, "Enemy roster")
    unique_ids(arena.get("lobby_npcs", []), "Arena lobby NPC roster")

    for npc in npcs:
        if npc.get("race") not in {"human", "elf", "dwarf", "goblin", "orc"}:
            raise SystemExit(f"NPC {npc['id']}: unsupported race {npc.get('race')!r}")
        if npc.get("gender") not in {"male", "female"}:
            raise SystemExit(f"NPC {npc['id']}: unsupported gender {npc.get('gender')!r}")
        if npc.get("model_status") not in VALID_MODEL_STATES:
            raise SystemExit(f"NPC {npc['id']}: invalid model status")

    enemy_ids = {item["id"] for item in enemies}
    for enemy in enemies:
        if enemy.get("model_status") != "3d_model_required":
            raise SystemExit(f"Enemy {enemy['id']}: model status must not overclaim a finished 3D asset")
        if not enemy.get("model_archetype"):
            raise SystemExit(f"Enemy {enemy['id']}: missing reusable model archetype")

    pool = arena.get("opponent_pool", [])
    if len(pool) != len(set(pool)) or not set(pool).issubset(enemy_ids):
        raise SystemExit("Arena opponent pool contains duplicates or unknown enemy IDs")
    if not set(arena.get("beast_pool", [])).issubset(enemy_ids):
        raise SystemExit("Arena beast pool references an unknown enemy ID")
    for unlock in arena.get("unlocks", []):
        if unlock.get("opponent") not in enemy_ids or int(unlock.get("fights_completed", 0)) < 1:
            raise SystemExit("Arena progression unlock is invalid")

    if len(npcs) != 98:
        raise SystemExit(f"Expected 98 source NPC records, found {len(npcs)}")
    if len(enemies) != 35:
        raise SystemExit(f"Expected 35 source monster templates, found {len(enemies)}")
    if len(pool) != 18:
        raise SystemExit(f"Expected 18 source Arena opponents, found {len(pool)}")
    print(f"Validated {len(npcs)} NPCs, {len(enemies)} enemy templates and {len(pool)} Arena opponents.")


if __name__ == "__main__":
    main()
