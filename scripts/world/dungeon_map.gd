class_name DungeonMap
extends Node


# Loads and stores the logical dungeon map.
#
# The native DMAP format currently uses JSON with parallel arrays.
# Every array index represents the same cell:
#
# index = cell.y * width + cell.x


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
	PORTAL = 1 << 1,
	DUNGEON_HEART = 1 << 2,
	ROOM = 1 << 3,
	BRIDGE = 1 << 4,
	SPECIAL_PATH = 1 << 5
}


# -------------------------------------------------------------------
# Map Source
# -------------------------------------------------------------------

@export_category("Map Source")

@export_file("*.dmap")
var map_file_path: String


# -------------------------------------------------------------------
# Map Metadata
# -------------------------------------------------------------------

var width: int = 0
var height: int = 0

var is_loaded: bool = false


# -------------------------------------------------------------------
# Cell Data
# -------------------------------------------------------------------

var terrain_types: PackedByteArray = PackedByteArray()
var resource_types: PackedByteArray = PackedByteArray()
var resource_amounts: PackedInt32Array = PackedInt32Array()
var owner_ids: PackedByteArray = PackedByteArray()
var cell_flags: PackedByteArray = PackedByteArray()

# Debug colours are intentionally retained permanently.
var debug_colors: PackedColorArray = PackedColorArray()


# -------------------------------------------------------------------
# Loading
# -------------------------------------------------------------------

func load_configured_map() -> bool:
	if map_file_path.is_empty():
		push_error(
			"DungeonMap: Map File Path is not assigned."
		)
		return false

	return load_map(
		map_file_path
	)


func load_map(
	file_path: String
) -> bool:
	_clear_map()

	if not FileAccess.file_exists(file_path):
		push_error(
			"DungeonMap: Map file does not exist: %s"
			% file_path
		)
		return false

	var file: FileAccess = FileAccess.open(
		file_path,
		FileAccess.READ
	)

	if file == null:
		push_error(
			"DungeonMap: Could not open map file: %s"
			% file_path
		)
		return false

	var json_text: String = file.get_as_text()

	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(
		json_text
	)

	if parse_error != OK:
		push_error(
			(
				"DungeonMap: JSON error on line %s: %s"
				% [
					json.get_error_line(),
					json.get_error_message()
				]
			)
		)
		return false

	var parsed_data: Variant = json.data

	if not parsed_data is Dictionary:
		push_error(
			"DungeonMap: DMAP root must be a JSON object."
		)
		return false

	var map_data: Dictionary = parsed_data

	if not _validate_header(
		map_data
	):
		return false

	width = int(
		map_data["width"]
	)

	height = int(
		map_data["height"]
	)

	var expected_cell_count: int = (
		width * height
	)

	if not _load_cell_arrays(
		map_data,
		expected_cell_count
	):
		_clear_map()
		return false

	is_loaded = true

	print(
		"DungeonMap loaded: ",
		width,
		"x",
		height,
		" | cells: ",
		expected_cell_count,
		" | ",
		file_path
	)

	return true


# -------------------------------------------------------------------
# Header Validation
# -------------------------------------------------------------------

func _validate_header(
	map_data: Dictionary
) -> bool:
	if str(map_data.get("format", "")) != "DMAP":
		push_error(
			"DungeonMap: Invalid or missing DMAP format identifier."
		)
		return false

	var version: int = int(
		map_data.get("version", 0)
	)

	if version != 1:
		push_error(
			"DungeonMap: Unsupported DMAP version: %s"
			% version
		)
		return false

	var map_width: int = int(
		map_data.get("width", 0)
	)

	var map_height: int = int(
		map_data.get("height", 0)
	)

	if map_width <= 0 or map_height <= 0:
		push_error(
			"DungeonMap: Invalid map dimensions."
		)
		return false

	return true


# -------------------------------------------------------------------
# Cell Array Loading
# -------------------------------------------------------------------

func _load_cell_arrays(
	map_data: Dictionary,
	expected_cell_count: int
) -> bool:
	var terrain_source: Array = map_data.get(
		"terrain",
		[]
	)

	var resource_source: Array = map_data.get(
		"resources",
		[]
	)

	var resource_amount_source: Array = map_data.get(
		"resource_amounts",
		[]
	)

	var owner_source: Array = map_data.get(
		"owners",
		[]
	)

	var flag_source: Array = map_data.get(
		"flags",
		[]
	)

	var color_source: Array = map_data.get(
		"debug_colors",
		[]
	)

	if not _validate_array_size(
		"terrain",
		terrain_source,
		expected_cell_count
	):
		return false

	if not _validate_array_size(
		"resources",
		resource_source,
		expected_cell_count
	):
		return false

	if not _validate_array_size(
		"resource_amounts",
		resource_amount_source,
		expected_cell_count
	):
		return false

	if not _validate_array_size(
		"owners",
		owner_source,
		expected_cell_count
	):
		return false

	if not _validate_array_size(
		"flags",
		flag_source,
		expected_cell_count
	):
		return false

	if not _validate_array_size(
		"debug_colors",
		color_source,
		expected_cell_count
	):
		return false

	terrain_types.resize(
		expected_cell_count
	)

	resource_types.resize(
		expected_cell_count
	)

	resource_amounts.resize(
		expected_cell_count
	)

	owner_ids.resize(
		expected_cell_count
	)

	cell_flags.resize(
		expected_cell_count
	)

	debug_colors.resize(
		expected_cell_count
	)

	for cell_index: int in range(
		expected_cell_count
	):
		var terrain_type: int = int(
			terrain_source[cell_index]
		)

		var resource_type: int = int(
			resource_source[cell_index]
		)

		var resource_amount: int = int(
			resource_amount_source[cell_index]
		)

		var owner_id: int = int(
			owner_source[cell_index]
		)

		var flags: int = int(
			flag_source[cell_index]
		)

		if not _is_valid_terrain_type(
			terrain_type
		):
			push_error(
				(
					"DungeonMap: Invalid terrain type %s "
					+ "at cell index %s."
				) % [
					terrain_type,
					cell_index
				]
			)
			return false

		if not _is_valid_resource_type(
			resource_type
		):
			push_error(
				(
					"DungeonMap: Invalid resource type %s "
					+ "at cell index %s."
				) % [
					resource_type,
					cell_index
				]
			)
			return false

		if resource_amount < 0:
			push_error(
				(
					"DungeonMap: Negative resource amount "
					+ "at cell index %s."
				) % cell_index
			)
			return false

		if owner_id < 0 or owner_id > 255:
			push_error(
				(
					"DungeonMap: Invalid owner ID %s "
					+ "at cell index %s."
				) % [
					owner_id,
					cell_index
				]
			)
			return false

		if flags < 0 or flags > 255:
			push_error(
				(
					"DungeonMap: Invalid cell flags %s "
					+ "at cell index %s."
				) % [
					flags,
					cell_index
				]
			)
			return false

		var color_text: String = str(
			color_source[cell_index]
		)

		if not Color.html_is_valid(
			color_text
		):
			push_error(
				(
					"DungeonMap: Invalid debug colour '%s' "
					+ "at cell index %s."
				) % [
					color_text,
					cell_index
				]
			)
			return false

		terrain_types[cell_index] = terrain_type
		resource_types[cell_index] = resource_type
		resource_amounts[cell_index] = resource_amount
		owner_ids[cell_index] = owner_id
		cell_flags[cell_index] = flags
		debug_colors[cell_index] = Color.html(
			color_text
		)

	return true


func _validate_array_size(
	array_name: String,
	source: Array,
	expected_size: int
) -> bool:
	if source.size() == expected_size:
		return true

	push_error(
		(
			"DungeonMap: Array '%s' contains %s values; "
			+ "expected %s."
		) % [
			array_name,
			source.size(),
			expected_size
		]
	)

	return false


# -------------------------------------------------------------------
# Cell Coordinates
# -------------------------------------------------------------------

func is_valid_cell(
	cell: Vector2i
) -> bool:
	if not is_loaded:
		return false

	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < width
		and cell.y < height
	)


func get_cell_index(
	cell: Vector2i
) -> int:
	if not is_valid_cell(cell):
		return -1

	return (
		cell.y * width
		+ cell.x
	)


func get_cell_from_index(
	cell_index: int
) -> Vector2i:
	if not is_loaded:
		return DungeonConstants.NO_CELL

	if cell_index < 0 or cell_index >= get_cell_count():
		return DungeonConstants.NO_CELL

	return Vector2i(
		cell_index % width,
		cell_index / width
	)


func get_cell_count() -> int:
	return width * height


# -------------------------------------------------------------------
# Cell Data Queries
# -------------------------------------------------------------------

func get_terrain_type(
	cell: Vector2i
) -> TerrainType:
	var cell_index: int = get_cell_index(
		cell
	)

	if cell_index < 0:
		return TerrainType.ABYSS

	return terrain_types[cell_index] as TerrainType


func get_resource_type(
	cell: Vector2i
) -> ResourceType:
	var cell_index: int = get_cell_index(
		cell
	)

	if cell_index < 0:
		return ResourceType.NONE

	return resource_types[cell_index] as ResourceType


func get_resource_amount(
	cell: Vector2i
) -> int:
	var cell_index: int = get_cell_index(
		cell
	)

	if cell_index < 0:
		return 0

	return resource_amounts[cell_index]


func get_owner_id(
	cell: Vector2i
) -> int:
	var cell_index: int = get_cell_index(
		cell
	)

	if cell_index < 0:
		return 0

	return owner_ids[cell_index]


func get_flags(
	cell: Vector2i
) -> int:
	var cell_index: int = get_cell_index(
		cell
	)

	if cell_index < 0:
		return CellFlag.NONE

	return cell_flags[cell_index]


func get_debug_color(
	cell: Vector2i
) -> Color:
	var cell_index: int = get_cell_index(
		cell
	)

	if cell_index < 0:
		return Color.BLACK

	return debug_colors[cell_index]


# -------------------------------------------------------------------
# Flag Queries
# -------------------------------------------------------------------

func has_flag(
	cell: Vector2i,
	flag: CellFlag
) -> bool:
	var flags: int = get_flags(
		cell
	)

	return (
		flags & flag
	) != 0


# -------------------------------------------------------------------
# Terrain Behaviour Queries
# -------------------------------------------------------------------

func has_block(
	cell: Vector2i
) -> bool:
	match get_terrain_type(cell):
		TerrainType.BEDROCK:
			return true

		TerrainType.ROCK:
			return true

		TerrainType.DIRT:
			return true

		_:
			return false


func is_open(
	cell: Vector2i
) -> bool:
	match get_terrain_type(cell):
		TerrainType.FLOOR:
			return true

		TerrainType.WATER:
			return true

		TerrainType.LAVA:
			return true

		_:
			return false


func is_walkable(
	cell: Vector2i
) -> bool:
	return (
		get_terrain_type(cell)
		== TerrainType.FLOOR
	)


func is_diggable(
	cell: Vector2i
) -> bool:
	if has_flag(
		cell,
		CellFlag.INDESTRUCTIBLE
	):
		return false

	match get_terrain_type(cell):
		TerrainType.ROCK:
			return true

		TerrainType.DIRT:
			return true

		_:
			return false


func is_liquid(
	cell: Vector2i
) -> bool:
	match get_terrain_type(cell):
		TerrainType.WATER:
			return true

		TerrainType.LAVA:
			return true

		_:
			return false


# -------------------------------------------------------------------
# Type Validation
# -------------------------------------------------------------------

func _is_valid_terrain_type(
	value: int
) -> bool:
	return (
		value >= TerrainType.ABYSS
		and value <= TerrainType.LAVA
	)


func _is_valid_resource_type(
	value: int
) -> bool:
	return (
		value >= ResourceType.NONE
		and value <= ResourceType.GEMS
	)


# -------------------------------------------------------------------
# Reset
# -------------------------------------------------------------------

func _clear_map() -> void:
	width = 0
	height = 0

	is_loaded = false

	terrain_types.clear()
	resource_types.clear()
	resource_amounts.clear()
	owner_ids.clear()
	cell_flags.clear()
	debug_colors.clear()
