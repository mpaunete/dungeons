class_name DungeonMapFile
extends RefCounted


# Reads and writes the project's native JSON-based DMAP format.
#
# Version 1 stores cell properties in parallel arrays:
# - terrain
# - resources
# - resource amounts
# - owners
# - flags


# -------------------------------------------------------------------
# Format Constants
# -------------------------------------------------------------------

const FORMAT_NAME: String = "DMAP"
const CURRENT_VERSION: int = 1


# -------------------------------------------------------------------
# Saving
# -------------------------------------------------------------------

static func save_map(
	file_path: String,
	width: int,
	height: int,
	terrain: PackedByteArray,
	resources: PackedByteArray,
	resource_amounts: PackedInt32Array,
	owners: PackedByteArray,
	flags: PackedByteArray
) -> bool:
	var cell_count: int = width * height

	if width <= 0 or height <= 0:
		push_error(
			"DungeonMapFile: Invalid map dimensions."
		)
		return false

	if not _arrays_have_size(
		cell_count,
		terrain,
		resources,
		resource_amounts,
		owners,
		flags
	):
		return false

	var map_data: Dictionary = {
		"format": FORMAT_NAME,
		"version": CURRENT_VERSION,
		"width": width,
		"height": height,
		"terrain": Array(terrain),
		"resources": Array(resources),
		"resource_amounts": Array(resource_amounts),
		"owners": Array(owners),
		"flags": Array(flags)
	}

	var json_text: String = JSON.stringify(
		map_data,
		"\t"
	)

	var file: FileAccess = FileAccess.open(
		file_path,
		FileAccess.WRITE
	)

	if file == null:
		push_error(
			"DungeonMapFile: Could not write file: %s"
			% file_path
		)
		return false

	file.store_string(
		json_text
	)

	print(
		"DungeonMapFile saved: ",
		file_path,
		" | ",
		width,
		"x",
		height
	)

	return true


# -------------------------------------------------------------------
# Loading
# -------------------------------------------------------------------

static func load_map(
	file_path: String
) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		push_error(
			"DungeonMapFile: File does not exist: %s"
			% file_path
		)
		return {}

	var file: FileAccess = FileAccess.open(
		file_path,
		FileAccess.READ
	)

	if file == null:
		push_error(
			"DungeonMapFile: Could not open file: %s"
			% file_path
		)
		return {}

	var json_text: String = file.get_as_text()

	var parsed_value: Variant = JSON.parse_string(
		json_text
	)

	if not parsed_value is Dictionary:
		push_error(
			"DungeonMapFile: Root value must be a dictionary."
		)
		return {}

	var map_data: Dictionary = parsed_value

	if map_data.get("format", "") != FORMAT_NAME:
		push_error(
			"DungeonMapFile: Invalid map format."
		)
		return {}

	if int(map_data.get("version", 0)) != CURRENT_VERSION:
		push_error(
			"DungeonMapFile: Unsupported map version."
		)
		return {}

	var width: int = int(
		map_data.get("width", 0)
	)

	var height: int = int(
		map_data.get("height", 0)
	)

	var cell_count: int = width * height

	var terrain: PackedByteArray = PackedByteArray(
		map_data.get("terrain", [])
	)

	var resources: PackedByteArray = PackedByteArray(
		map_data.get("resources", [])
	)

	var resource_amounts: PackedInt32Array = PackedInt32Array(
		map_data.get("resource_amounts", [])
	)

	var owners: PackedByteArray = PackedByteArray(
		map_data.get("owners", [])
	)

	var flags: PackedByteArray = PackedByteArray(
		map_data.get("flags", [])
	)

	if not _arrays_have_size(
		cell_count,
		terrain,
		resources,
		resource_amounts,
		owners,
		flags
	):
		return {}

	return {
		"width": width,
		"height": height,
		"terrain": terrain,
		"resources": resources,
		"resource_amounts": resource_amounts,
		"owners": owners,
		"flags": flags
	}


# -------------------------------------------------------------------
# Validation
# -------------------------------------------------------------------

static func _arrays_have_size(
	expected_size: int,
	terrain: PackedByteArray,
	resources: PackedByteArray,
	resource_amounts: PackedInt32Array,
	owners: PackedByteArray,
	flags: PackedByteArray
) -> bool:
	if terrain.size() != expected_size:
		push_error(
			"DungeonMapFile: Terrain array has the wrong size."
		)
		return false

	if resources.size() != expected_size:
		push_error(
			"DungeonMapFile: Resource array has the wrong size."
		)
		return false

	if resource_amounts.size() != expected_size:
		push_error(
			"DungeonMapFile: Resource amount array has the wrong size."
		)
		return false

	if owners.size() != expected_size:
		push_error(
			"DungeonMapFile: Owner array has the wrong size."
		)
		return false

	if flags.size() != expected_size:
		push_error(
			"DungeonMapFile: Flag array has the wrong size."
		)
		return false

	return true
