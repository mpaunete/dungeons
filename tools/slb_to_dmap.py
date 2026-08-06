#!/usr/bin/env python3

"""Convert a raw two-byte-per-cell SLB map into JSON DMAP format."""

from __future__ import annotations

import argparse
import json
import struct
import sys
from dataclasses import dataclass
from enum import IntEnum
from pathlib import Path
from typing import Any


# -------------------------------------------------------------------
# Native Map Types
# -------------------------------------------------------------------


class TerrainType(IntEnum):
    ABYSS = 0
    BEDROCK = 1
    ROCK = 2
    DIRT = 3
    FLOOR = 4
    WATER = 5
    LAVA = 6


class ResourceType(IntEnum):
    NONE = 0
    GOLD = 1
    GEMS = 2


class CellFlag(IntEnum):
    NONE = 0
    INDESTRUCTIBLE = 1 << 0
    PORTAL = 1 << 1
    DUNGEON_HEART = 1 << 2
    ROOM = 1 << 3
    BRIDGE = 1 << 4
    SPECIAL_PATH = 1 << 5


# -------------------------------------------------------------------
# Converted Cell
# -------------------------------------------------------------------


@dataclass(frozen=True)
class ConvertedCell:
    name: str
    terrain: TerrainType
    resource: ResourceType
    resource_amount: int
    owner: int
    flags: int
    debug_color: str


# -------------------------------------------------------------------
# Mapping Loading
# -------------------------------------------------------------------


def load_mapping(
    path: Path,
) -> dict[int, ConvertedCell]:
    raw_mapping: Any = json.loads(
        path.read_text(
            encoding="utf-8",
        )
    )

    if not isinstance(raw_mapping, dict):
        raise ValueError(
            "Mapping JSON root must be an object."
        )

    converted_mapping: dict[int, ConvertedCell] = {}

    for slab_id_text, entry in raw_mapping.items():
        if not isinstance(entry, dict):
            raise ValueError(
                f"Mapping for slab ID {slab_id_text} "
                "must be an object."
            )

        slab_id = int(
            slab_id_text
        )

        terrain_name = str(
            entry.get("terrain", "")
        )

        resource_name = str(
            entry.get("resource", "NONE")
        )

        flag_names = entry.get(
            "flags",
            [],
        )

        if terrain_name not in TerrainType.__members__:
            raise ValueError(
                f"Unknown terrain type '{terrain_name}' "
                f"for slab ID {slab_id}."
            )

        if resource_name not in ResourceType.__members__:
            raise ValueError(
                f"Unknown resource type '{resource_name}' "
                f"for slab ID {slab_id}."
            )

        flags = parse_flags(
            slab_id,
            flag_names,
        )

        converted_mapping[slab_id] = ConvertedCell(
            name=str(
                entry.get(
                    "name",
                    f"SLB {slab_id}",
                )
            ),
            terrain=TerrainType[terrain_name],
            resource=ResourceType[resource_name],
            resource_amount=validate_resource_amount(
                slab_id,
                entry.get(
                    "resource_amount",
                    0,
                ),
            ),
            owner=validate_owner(
                slab_id,
                entry.get(
                    "owner",
                    0,
                ),
            ),
            flags=flags,
            debug_color=validate_color(
                slab_id,
                entry.get(
                    "debug_color",
                    "#FF00FF",
                ),
            ),
        )

    return converted_mapping


def parse_flags(
    slab_id: int,
    flag_names: Any,
) -> int:
    if not isinstance(flag_names, list):
        raise ValueError(
            f"Flags for slab ID {slab_id} must be an array."
        )

    flags = CellFlag.NONE

    for flag_name_value in flag_names:
        flag_name = str(
            flag_name_value
        )

        if flag_name not in CellFlag.__members__:
            raise ValueError(
                f"Unknown flag '{flag_name}' "
                f"for slab ID {slab_id}."
            )

        flags |= CellFlag[flag_name]

    return int(flags)


def validate_resource_amount(
    slab_id: int,
    value: Any,
) -> int:
    amount = int(
        value
    )

    if amount < 0 or amount > 65535:
        raise ValueError(
            f"Resource amount for slab ID {slab_id} "
            "must be between 0 and 65535."
        )

    return amount


def validate_owner(
    slab_id: int,
    value: Any,
) -> int:
    owner = int(
        value
    )

    if owner < 0 or owner > 255:
        raise ValueError(
            f"Owner for slab ID {slab_id} "
            "must be between 0 and 255."
        )

    return owner


def validate_color(
    slab_id: int,
    value: Any,
) -> str:
    color = str(
        value
    ).upper()

    if (
        len(color) != 7
        or not color.startswith("#")
    ):
        raise ValueError(
            f"Debug colour for slab ID {slab_id} "
            "must use #RRGGBB format."
        )

    try:
        int(
            color[1:],
            16,
        )
    except ValueError as error:
        raise ValueError(
            f"Invalid debug colour '{color}' "
            f"for slab ID {slab_id}."
        ) from error

    return color


# -------------------------------------------------------------------
# SLB Reading
# -------------------------------------------------------------------


def read_slb(
    path: Path,
    width: int,
    height: int,
) -> list[int]:
    data = path.read_bytes()

    expected_size = (
        width
        * height
        * 2
    )

    if len(data) != expected_size:
        raise ValueError(
            f"Expected {expected_size} bytes for a "
            f"{width}x{height} two-byte map, "
            f"found {len(data)}."
        )

    return [
        slab_id
        for (slab_id,) in struct.iter_unpack(
            "<H",
            data,
        )
    ]


# -------------------------------------------------------------------
# Conversion
# -------------------------------------------------------------------


def convert_cells(
    slab_ids: list[int],
    mapping: dict[int, ConvertedCell],
) -> list[ConvertedCell]:
    converted_cells: list[ConvertedCell] = []
    unknown_ids: set[int] = set()

    for slab_id in slab_ids:
        cell = mapping.get(
            slab_id
        )

        if cell is None:
            unknown_ids.add(
                slab_id
            )
            continue

        converted_cells.append(
            cell
        )

    if unknown_ids:
        unknown_text = ", ".join(
            str(value)
            for value in sorted(
                unknown_ids
            )
        )

        raise ValueError(
            "No mapping exists for SLB IDs: "
            f"{unknown_text}"
        )

    return converted_cells


# -------------------------------------------------------------------
# DMAP Writing
# -------------------------------------------------------------------


def write_dmap(
    path: Path,
    width: int,
    height: int,
    cells: list[ConvertedCell],
) -> None:
    expected_cell_count = (
        width * height
    )

    if len(cells) != expected_cell_count:
        raise ValueError(
            f"Expected {expected_cell_count} converted cells, "
            f"received {len(cells)}."
        )

    path.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    map_data = {
        "format": "DMAP",
        "version": 1,
        "width": width,
        "height": height,
        "terrain": [
            int(cell.terrain)
            for cell in cells
        ],
        "resources": [
            int(cell.resource)
            for cell in cells
        ],
        "resource_amounts": [
            cell.resource_amount
            for cell in cells
        ],
        "owners": [
            cell.owner
            for cell in cells
        ],
        "flags": [
            cell.flags
            for cell in cells
        ],
        "debug_colors": [
            cell.debug_color
            for cell in cells
        ],
    }

    path.write_text(
        json.dumps(
            map_data,
            indent=2,
        ),
        encoding="utf-8",
    )


# -------------------------------------------------------------------
# Conversion Summary
# -------------------------------------------------------------------


def print_summary(
    slab_ids: list[int],
    mapping: dict[int, ConvertedCell],
) -> None:
    counts: dict[int, int] = {}

    for slab_id in slab_ids:
        counts[slab_id] = (
            counts.get(
                slab_id,
                0,
            )
            + 1
        )

    print("Converted slab types:")

    for slab_id in sorted(counts):
        cell = mapping[slab_id]

        print(
            f"  {slab_id:>3} "
            f"{cell.name:<20} "
            f"{counts[slab_id]:>5} cells "
            f"{cell.debug_color}"
        )


# -------------------------------------------------------------------
# Command Line
# -------------------------------------------------------------------


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Convert a raw two-byte-per-cell SLB map "
            "into JSON DMAP format."
        )
    )

    parser.add_argument(
        "input",
        type=Path,
        help="Input SLB file.",
    )

    parser.add_argument(
        "output",
        type=Path,
        help="Output DMAP file.",
    )

    parser.add_argument(
        "--mapping",
        type=Path,
        required=True,
        help="SLB mapping JSON file.",
    )

    parser.add_argument(
        "--width",
        type=int,
        required=True,
        help="Map width in cells.",
    )

    parser.add_argument(
        "--height",
        type=int,
        required=True,
        help="Map height in cells.",
    )

    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()

    try:
        mapping = load_mapping(
            arguments.mapping
        )

        slab_ids = read_slb(
            arguments.input,
            arguments.width,
            arguments.height,
        )

        cells = convert_cells(
            slab_ids,
            mapping,
        )

        write_dmap(
            arguments.output,
            arguments.width,
            arguments.height,
            cells,
        )

        print_summary(
            slab_ids,
            mapping,
        )

    except (
        OSError,
        ValueError,
        json.JSONDecodeError,
    ) as error:
        print(
            f"Conversion failed: {error}",
            file=sys.stderr,
        )
        return 1

    print()
    print(
        f"Converted {arguments.width}x{arguments.height} map:"
    )
    print(
        f"  Input:   {arguments.input}"
    )
    print(
        f"  Mapping: {arguments.mapping}"
    )
    print(
        f"  Output:  {arguments.output}"
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(
        main()
    )
