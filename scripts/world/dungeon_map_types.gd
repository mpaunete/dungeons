class_name DungeonMapTypes
extends RefCounted


# Defines the stable numeric values stored in native dungeon map files.
#
# Do not reorder or renumber existing values after maps have been saved.
# New values may be appended later.


# -------------------------------------------------------------------
# Terrain Types
# -------------------------------------------------------------------

enum TerrainType {
	ABYSS = 0,
	BEDROCK = 1,
	ROCK = 2,
	DIRT = 3,
	FLOOR = 4,
	WATER = 5,
	LAVA = 6
}


# -------------------------------------------------------------------
# Resource Types
# -------------------------------------------------------------------

enum ResourceType {
	NONE = 0,
	GOLD = 1,
	GEMS = 2
}


# -------------------------------------------------------------------
# Cell Flags
# -------------------------------------------------------------------

enum CellFlag {
	NONE = 0,
	INDESTRUCTIBLE = 1 << 0,
	HIDDEN = 1 << 1,
	MARKED_FOR_DIGGING = 1 << 2
}


# -------------------------------------------------------------------
# Validation
# -------------------------------------------------------------------

static func is_valid_terrain_type(
	value: int
) -> bool:
	return (
		value >= TerrainType.ABYSS
		and value <= TerrainType.LAVA
	)


static func is_valid_resource_type(
	value: int
) -> bool:
	return (
		value >= ResourceType.NONE
		and value <= ResourceType.GEMS
	)
