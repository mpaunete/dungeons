class_name CellPicker
extends Node


# Determines which logical dungeon cell is under the mouse.
#
# It does not create highlights or manage selection state.
# It only reports when the hovered cell changes.


# -------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------

signal cell_changed(
	cell: Vector2i,
	is_valid: bool
)


# -------------------------------------------------------------------
# Dependencies
# -------------------------------------------------------------------

var generator: DungeonGenerator
var dungeon_root: Node3D


# -------------------------------------------------------------------
# Runtime State
# -------------------------------------------------------------------

var current_cell: Vector2i = Vector2i(-1, -1)
var current_is_valid: bool = false


# -------------------------------------------------------------------
# Initialization
# -------------------------------------------------------------------

func initialize(
	new_generator: DungeonGenerator,
	new_dungeon_root: Node3D
) -> void:
	generator = new_generator
	dungeon_root = new_dungeon_root


# -------------------------------------------------------------------
# Frame Update
# -------------------------------------------------------------------

func update_hover() -> void:
	if generator == null or dungeon_root == null:
		_set_hover_result(
			Vector2i(-1, -1),
			false
		)
		return

	var camera: Camera3D = (
		dungeon_root.get_viewport().get_camera_3d()
	)

	if camera == null:
		_set_hover_result(
			Vector2i(-1, -1),
			false
		)
		return

	var mouse_position: Vector2 = (
		dungeon_root.get_viewport().get_mouse_position()
	)

	var ray_origin_global: Vector3 = (
		camera.project_ray_origin(
			mouse_position
		)
	)

	var ray_direction_global: Vector3 = (
		camera.project_ray_normal(
			mouse_position
		)
	)

	var ray_origin: Vector3 = (
		dungeon_root.to_local(
			ray_origin_global
		)
	)

	var ray_direction: Vector3 = (
		dungeon_root.global_transform.basis.inverse()
		* ray_direction_global
	).normalized()

	if absf(ray_direction.y) < 0.0001:
		_set_hover_result(
			Vector2i(-1, -1),
			false
		)
		return

	var distance: float = (
		generator.terrain_top_y - ray_origin.y
	) / ray_direction.y

	if distance < 0.0:
		_set_hover_result(
			Vector2i(-1, -1),
			false
		)
		return

	var hit_position: Vector3 = (
		ray_origin
		+ ray_direction * distance
	)

	var cell: Vector2i = (
		generator.local_position_to_cell(
			hit_position
		)
	)

	_set_hover_result(
		cell,
		generator.is_valid_map_cell(cell)
	)


# -------------------------------------------------------------------
# Hover Result
# -------------------------------------------------------------------

func _set_hover_result(
	cell: Vector2i,
	is_valid: bool
) -> void:
	if (
		cell == current_cell
		and is_valid == current_is_valid
	):
		return

	current_cell = cell
	current_is_valid = is_valid

	cell_changed.emit(
		cell,
		is_valid
	)


# -------------------------------------------------------------------
# Public Queries
# -------------------------------------------------------------------

func get_current_cell() -> Vector2i:
	if not current_is_valid:
		return DungeonConstants.NO_CELL

	return current_cell


# -------------------------------------------------------------------
# Reset
# -------------------------------------------------------------------

func reset() -> void:
	current_cell = DungeonConstants.NO_CELL
	current_is_valid = false
