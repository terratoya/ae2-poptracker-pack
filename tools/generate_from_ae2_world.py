#!/usr/bin/env python3
"""Generate PopTracker data from the Ape Escape 2 Archipelago world."""

from __future__ import annotations

import argparse
import ast
import json
import re
import subprocess
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


CORE_ITEMS = {
    "Monkey Net": "monkey_net",
    "Stun Club": "stun_club",
    "Monkey Radar": "monkey_radar",
    "Water Net": "water_net",
    "Dash Hoop": "dash_hoop",
    "Catapult": "catapult",
    "Sky Flyer": "sky_flyer",
    "R.C. Car": "rc_car",
    "Bananarang": "bananarang",
    "Water Cannon": "water_cannon",
    "Electro Magnet": "electro_magnet",
    "Power Punch": "power_punch",
    "Pipotchi": "pipotchi",
    "See-All Scope": "see_all_scope",
    "Progressive Catapult": "progressive_catapult",
    "World Key": "world_key",
    "Gotcha Box Restock": "gotcha_box_restock",
    "Air Crawl": "air_crawl",
}


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("world", type=Path, help="Path to the ae2_archipelago world directory")
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Pack root to update (defaults to this repository)",
    )
    return parser.parse_args()


def find_assignment(path: Path, variable: str) -> ast.AST:
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    for node in tree.body:
        if isinstance(node, (ast.Assign, ast.AnnAssign)):
            targets = node.targets if isinstance(node, ast.Assign) else [node.target]
            if any(isinstance(target, ast.Name) and target.id == variable for target in targets):
                if node.value is None:
                    break
                return node.value
    raise ValueError(f"Could not find assignment {variable!r} in {path}")


def decode_node(node: ast.AST) -> Any:
    if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
        if node.args:
            raise ValueError(f"Positional arguments are not supported in {node.func.id}")
        result = {"_type": node.func.id}
        for keyword in node.keywords:
            if keyword.arg is None:
                raise ValueError("Expanded keyword arguments are not supported")
            result[keyword.arg] = decode_node(keyword.value)
        return result
    if isinstance(node, ast.List):
        return [decode_node(value) for value in node.elts]
    if isinstance(node, ast.Tuple):
        return tuple(decode_node(value) for value in node.elts)
    if isinstance(node, ast.Dict):
        return {decode_node(key): decode_node(value) for key, value in zip(node.keys, node.values)}
    return ast.literal_eval(node)


def source_revision(world: Path) -> str:
    try:
        result = subprocess.run(
            ["git", "-C", str(world), "rev-parse", "HEAD"],
            check=True,
            capture_output=True,
            text=True,
        )
        return result.stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def expand_net_requirements(monkey: dict[str, Any]) -> dict[str, list[list[str]]]:
    requirements = monkey.get("connection_requirements", {"Entry from Spawn": [[]]})
    net_requirement = monkey.get("net_requirement", 0)
    if net_requirement == 1:
        return requirements

    expanded: dict[str, list[list[str]]] = {}
    for connection, alternatives in requirements.items():
        expanded_alternatives = []
        for alternative in alternatives:
            expanded_alternatives.append([*alternative, "Monkey Net"])
            if net_requirement == 2:
                expanded_alternatives.append([*alternative, "Water Net"])
        expanded[connection] = expanded_alternatives
    return expanded


def location_name(monkey: dict[str, Any]) -> str:
    level = monkey["level"]
    name = monkey["name"].strip()
    room = monkey.get("room", "Entry")
    return f"{level}: {name}" if room == "Entry" else f"{level} ({room}): {name}"


def poptracker_path(monkey: dict[str, Any]) -> str:
    return f"@{monkey['level']}/{monkey.get('room', 'Entry')}/Monkeys/{monkey['name'].strip()}"


def phone_location_name(phone: dict[str, Any]) -> str:
    level = phone["level"]
    description = phone["description"]
    room = phone.get("room", "Entry")
    return f'{level}: "{description}" Phone' if room == "Entry" else f'{level} ({room}): "{description}" Phone'


def phone_path(phone: dict[str, Any]) -> str:
    return f"@Phone Logic/{phone['level']}/{phone.get('room', 'Entry')}/Phones/{phone['description']}"


def expand_phone_requirements(phone: dict[str, Any]) -> dict[str, list[list[str]]]:
    requirements = phone.get("connection_requirements", {"Entry from Spawn": [[]]})
    if not phone.get("is_blue", False):
        return requirements
    return {
        connection: [expanded for alternative in alternatives
                     for expanded in ([*alternative, "*Attack"], [*alternative, "*Hard"])]
        for connection, alternatives in requirements.items()
    }


def slugify(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_")
    return slug or "unnamed"


def lua_value(value: Any, indent: int = 0) -> str:
    if value is None:
        return "nil"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    padding = " " * indent
    child_padding = " " * (indent + 4)
    if isinstance(value, list):
        if not value:
            return "{}"
        children = [f"{child_padding}{lua_value(item, indent + 4)}" for item in value]
        return "{\n" + ",\n".join(children) + f"\n{padding}}}"
    if isinstance(value, dict):
        if not value:
            return "{}"
        children = []
        for key, item in value.items():
            if isinstance(key, str) and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
                rendered_key = key
            else:
                rendered_key = f"[{lua_value(key)}]"
            children.append(f"{child_padding}{rendered_key} = {lua_value(item, indent + 4)}")
        return "{\n" + ",\n".join(children) + f"\n{padding}}}"
    raise TypeError(f"Unsupported Lua value: {type(value).__name__}")


def write_jsonc(path: Path, data: Any, revision: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    header = f"// Generated from ae2_archipelago revision {revision}. Do not edit manually.\n"
    path.write_text(header + json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def build_logic_locations(levels: list[dict[str, Any]], monkeys: list[dict[str, Any]]) -> list[dict[str, Any]]:
    by_level_and_room: dict[str, dict[str, list[dict[str, Any]]]] = defaultdict(lambda: defaultdict(list))
    for monkey in monkeys:
        by_level_and_room[monkey["level"]][monkey.get("room", "Entry")].append(monkey)

    result = []
    for level in levels:
        level_name = level["name"]
        rooms = []
        for room_name, room_monkeys in by_level_and_room[level_name].items():
            rooms.append(
                {
                    "name": room_name,
                    "children": [
                        {
                            "name": "Monkeys",
                            "sections": [
                                ({
                                    "name": monkey["name"].strip(),
                                    "item_count": 1,
                                    "access_rules": f"^$monkey_accessibility|{monkey['id']}",
                                    "visibility_rules": f"$is_location_active|{monkey['id']}",
                                } | ({
                                    "visibility_rules": "setting_final_specter_goal"
                                } if monkey["level"] == "Final Showdown with Specter!" else {}))
                                for monkey in room_monkeys
                            ],
                        }
                    ],
                }
            )
        result.append(
            {
                "name": level_name,
                "chest_unopened_img": "images/locations/monkey.png",
                "chest_opened_img": "images/locations/monkey_checked.png",
                "children": rooms,
            }
        )
    return result


def build_ui_locations(levels: list[dict[str, Any]], monkeys: list[dict[str, Any]]) -> list[dict[str, Any]]:
    by_level: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for monkey in monkeys:
        by_level[monkey["level"]].append(monkey)

    columns = 7
    x_positions = [125 + column * 225 for column in range(columns)]
    y_positions = [120 + row * 220 for row in range(4)]
    result = []
    for index, level in enumerate(levels):
        level_name = level["name"]
        marker = {
                "name": f"{level_name} - Monkeys",
                "chest_unopened_img": "images/locations/monkey.png",
                "chest_opened_img": "images/locations/monkey_checked.png",
                "sections": [{"ref": poptracker_path(monkey)[1:]} for monkey in by_level[level_name]],
                "visibility_rules": f"$is_level_active|{level_name}",
                "map_locations": [
                    {
                        "map": "Level Select",
                        "x": x_positions[index % columns],
                        "y": y_positions[index // columns],
                    }
                ],
            }
        if level_name == "Final Showdown with Specter!":
            marker["visibility_rules"] = "setting_final_specter_goal"
        result.append(marker)
    return result


def build_phone_logic(phones: list[dict[str, Any]]) -> list[dict[str, Any]]:
    by_level_and_room: dict[str, dict[str, list[dict[str, Any]]]] = defaultdict(lambda: defaultdict(list))
    for phone in phones:
        by_level_and_room[phone["level"]][phone.get("room", "Entry")].append(phone)
    return [
        {
            "name": "Phone Logic",
            "chest_unopened_img": "images/locations/phone.png",
            "chest_opened_img": "images/locations/phone_checked.png",
            "children": [
                {
                    "name": level,
                    "children": [
                        {
                            "name": room,
                            "children": [
                                {
                                    "name": "Phones",
                                    "visibility_rules": "setting_message_phones",
                                    "sections": [
                                        {
                                            "name": phone["description"],
                                            "item_count": 1,
                                            "access_rules": f"^$phone_accessibility|{phone['id']}",
                                            "visibility_rules": f"$is_location_active|{phone['id']}",
                                        }
                                        for phone in room_phones
                                    ],
                                }
                            ],
                        }
                        for room, room_phones in rooms.items()
                    ],
                }
                for level, rooms in by_level_and_room.items()
            ],
        }
    ]


def build_phone_ui(levels: list[dict[str, Any]], phones: list[dict[str, Any]]) -> list[dict[str, Any]]:
    by_level: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for phone in phones:
        by_level[phone["level"]].append(phone)

    result = []
    for level_index, level in enumerate(levels):
        level_name = level["name"]
        if not by_level[level_name]:
            continue
        column = level_index % 7
        row = level_index // 7
        result.append(
            {
                "name": f"{level_name} - Phones",
                "chest_unopened_img": "images/locations/phone.png",
                "chest_opened_img": "images/locations/phone_checked.png",
                "visibility_rules": "setting_message_phones",
                "sections": [{"ref": phone_path(phone)[1:]} for phone in by_level[level_name]],
                "map_locations": [{"map": "Level Select", "x": 180 + column * 225, "y": 170 + row * 220, "size": 32}],
            }
        )
    return result


def gotcha_box_path(number: int) -> str:
    return f"@Gotcha Box Logic/Items/Item #{number}"


def build_gotcha_box_logic() -> list[dict[str, Any]]:
    return [
        {
            "name": "Gotcha Box Logic",
            "chest_unopened_img": "images/locations/gatchabox.png",
            "chest_opened_img": "images/locations/gotcha_box_checked.png",
            "children": [
                {
                    "name": "Items",
                    "sections": [
                        {
                            "name": f"Item #{number}",
                            "item_count": 1,
                            "access_rules": f"^$gotcha_box_accessibility|{number - 1}",
                            "visibility_rules": f"$is_location_active|{2000 + number}",
                        }
                        for number in range(1, 1000)
                    ],
                }
            ],
        }
    ]


def build_gotcha_box_ui() -> list[dict[str, Any]]:
    result = []
    for chunk_index, start in enumerate(range(1, 1000, 100)):
        end = min(start + 99, 999)
        result.append({
            "name": f"Gotcha Box #{start}-{end}",
            "chest_unopened_img": "images/locations/gatchabox.png",
            "chest_opened_img": "images/locations/gotcha_box_checked.png",
            "visibility_rules": f"$is_gotcha_box_range_active|{start}|{end}",
            "sections": [{"ref": gotcha_box_path(number)[1:]} for number in range(start, end + 1)],
            "map_locations": [{
                "map": "Level Select",
                # Two rows of five markers over the Gotcha Box tile.
                "x": 1636 + (chunk_index % 5) * 32,
                "y": 150 + (chunk_index // 5) * 36,
                "size": 26,
            }],
        })
    return result


def build_generated_logic(levels: list[dict[str, Any]], monkeys: list[dict[str, Any]],
                          phones: list[dict[str, Any]], revision: str) -> str:
    monkey_data = {}
    for monkey in monkeys:
        monkey_data[monkey["id"]] = {
            "name": monkey["name"].strip(),
            "location_name": location_name(monkey),
            "level": monkey["level"],
            "room": monkey.get("room", "Entry"),
            "net_requirement": monkey.get("net_requirement", 0),
            "connection_requirements": expand_net_requirements(monkey),
        }

    level_data = {}
    for level in levels:
        entrances = []
        for entrance in level.get("room_entrances", [{"name": "Entry from Spawn"}]):
            entrances.append(
                {
                    "name": entrance["name"],
                    "connection_requirements": entrance.get("connection_requirements", {}),
                    "can_start": entrance.get("can_start", False),
                }
            )
        level_data[level["name"]] = {
            "code": slugify(level["name"]),
            "world_key_requirement": level.get("world_key_requirement", 0),
            "is_boss": level.get("is_boss", False),
            "room_entrances": entrances,
        }

    phone_data = {}
    for phone in phones:
        phone_data[phone["id"]] = {
            "name": phone["name"],
            "description": phone["description"],
            "location_name": phone_location_name(phone),
            "level": phone["level"],
            "room": phone.get("room", "Entry"),
            "is_blue": phone.get("is_blue", False),
            "connection_requirements": expand_phone_requirements(phone),
        }

    return (
        f"-- Generated from ae2_archipelago revision {revision}. Do not edit manually.\n"
        f"MONKEY_DATA = {lua_value(monkey_data)}\n\n"
        f"PHONE_DATA = {lua_value(phone_data)}\n\n"
        f"LEVEL_DATA = {lua_value(level_data)}\n"
    )


def build_location_mapping(monkeys: list[dict[str, Any]], phones: list[dict[str, Any]], revision: str) -> str:
    lines = [
        f"-- Generated from ae2_archipelago revision {revision}. Do not edit manually.",
        "LOCATION_MAPPING = {",
    ]
    for monkey in monkeys:
        lines.append(f"    [{monkey['id']}] = {{ {{ {json.dumps(poptracker_path(monkey), ensure_ascii=False)} }} }},")
    for phone in phones:
        lines.append(f"    [{phone['id']}] = {{ {{ {json.dumps(phone_path(phone), ensure_ascii=False)} }} }},")
    for number in range(1, 1000):
        lines.append(f"    [{2000 + number}] = {{ {{ {json.dumps(gotcha_box_path(number))} }} }},")
    lines.append("}\n")
    return "\n".join(lines)


def build_item_mapping(item_ids: dict[str, int], revision: str) -> str:
    lines = [
        f"-- Generated from ae2_archipelago revision {revision}. Do not edit manually.",
        "ITEM_MAPPING = {",
    ]
    for name, code in CORE_ITEMS.items():
        if name == "Pipotchi":
            lines.append(f"    [{item_ids[name]}] = {{}}, -- Pipotchi is determined by the character setting.")
            continue
        lines.append(f"    [{item_ids[name]}] = {{ {{ {json.dumps(code)} }} }}, -- {name}")
    lines.append("}\n")
    return "\n".join(lines)


def validate(levels: list[dict[str, Any]], monkeys: list[dict[str, Any]], phones: list[dict[str, Any]],
             item_ids: dict[str, int]) -> None:
    if len(levels) != 28:
        raise ValueError(f"Expected 28 levels, found {len(levels)}")
    if len(monkeys) != 308:
        raise ValueError(f"Expected 308 monkeys, found {len(monkeys)}")
    if len(phones) != 30:
        raise ValueError(f"Expected 30 phones, found {len(phones)}")

    level_names = [level["name"] for level in levels]
    unknown_levels = sorted({monkey["level"] for monkey in monkeys} - set(level_names))
    if unknown_levels:
        raise ValueError(f"Monkeys reference unknown levels: {unknown_levels}")

    ids = [monkey["id"] for monkey in monkeys]
    if ids != list(range(1, 309)):
        raise ValueError("Monkey IDs are not the expected contiguous range 1..308")
    if [phone["id"] for phone in phones] != list(range(1001, 1031)):
        raise ValueError("Phone IDs are not the expected contiguous range 1001..1030")

    paths = [poptracker_path(monkey) for monkey in monkeys]
    duplicate_paths = [path for path, count in Counter(paths).items() if count > 1]
    if duplicate_paths:
        raise ValueError(f"Duplicate PopTracker paths: {duplicate_paths}")
    phone_paths = [phone_path(phone) for phone in phones]
    if len(phone_paths) != len(set(phone_paths)):
        raise ValueError("Duplicate phone PopTracker paths")

    missing_items = sorted(set(CORE_ITEMS) - set(item_ids))
    if missing_items:
        raise ValueError(f"Core items missing from Items.py: {missing_items}")


def main() -> None:
    args = parse_arguments()
    world = args.world.resolve()
    output = args.output.resolve()
    revision = source_revision(world)

    monkeys = decode_node(find_assignment(world / "Monkeys.py", "monkeys"))
    phones = decode_node(find_assignment(world / "Phones.py", "phones"))
    levels = decode_node(find_assignment(world / "Levels.py", "levels"))
    item_ids = ast.literal_eval(find_assignment(world / "Items.py", "item_id_from_name"))

    for index, monkey in enumerate(monkeys, start=1):
        monkey["id"] = index
    for index, phone in enumerate(phones, start=1001):
        phone["id"] = index

    validate(levels, monkeys, phones, item_ids)

    write_jsonc(output / "locations" / "logic" / "monkeys.jsonc", build_logic_locations(levels, monkeys), revision)
    write_jsonc(output / "locations" / "ui" / "levels.jsonc", build_ui_locations(levels, monkeys), revision)
    write_jsonc(output / "locations" / "logic" / "phones.jsonc", build_phone_logic(phones), revision)
    write_jsonc(output / "locations" / "ui" / "phones.jsonc", build_phone_ui(levels, phones), revision)
    write_jsonc(output / "locations" / "logic" / "gotcha_box.jsonc", build_gotcha_box_logic(), revision)
    write_jsonc(output / "locations" / "ui" / "gotcha_box.jsonc", build_gotcha_box_ui(), revision)

    generated_logic = build_generated_logic(levels, monkeys, phones, revision)
    generated_logic_path = output / "scripts" / "logic" / "generated_data.lua"
    generated_logic_path.parent.mkdir(parents=True, exist_ok=True)
    generated_logic_path.write_text(generated_logic, encoding="utf-8")

    mappings_path = output / "scripts" / "autotracking"
    mappings_path.mkdir(parents=True, exist_ok=True)
    (mappings_path / "location_mapping.lua").write_text(build_location_mapping(monkeys, phones, revision), encoding="utf-8")
    (mappings_path / "item_mapping.lua").write_text(build_item_mapping(item_ids, revision), encoding="utf-8")

    print(f"Generated {len(levels)} levels, {len(monkeys)} monkey locations, {len(phones)} phone locations, "
          f"999 Gotcha Box locations, and {len(CORE_ITEMS)} item mappings.")
    print(f"Source revision: {revision}")


if __name__ == "__main__":
    main()
