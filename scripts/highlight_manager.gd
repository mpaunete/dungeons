class_name HighlightManager
extends Node


# Creates, replaces and removes dungeon-cell highlight effects.
#
# It owns highlight state, but does not detect the mouse position or
# generate terrain.


# -------------------------------------------------------------------
# Selection Settings
# -------------------------------------------------------------------

var edge_width: float = 0.018
var surface_offset: float = 0.012
var bottom_clearance: float = 0.04


# -------------------------------------------------------------------
# Dependencies
# -------------------------------------------------------------------

var generator: DungeonGenerator
var mesh_builder: SelectionMeshBuilder
var effects_parent: Node3D
var highlight_scene: PackedScene


# -------------------------------------------------------------------
# Runtime State
# -------------------------------------------------------------------

var current_cell: Vector2i = DungeonConstants.NO_CELL
var active_highlight: Node3D


# -------------------------------------------------------------------
# Initialization
# -------------------------------------------------------------------

func initialize(
	new_generator: DungeonGenerator,
	new_mesh_builder: SelectionMeshBuilder,
	new_effects_parent: Node3D,
	new_highlight_scene: PackedScene
) -> void:
	generator = new_generator
	mesh_builder = new_mesh_builder
	effects_parent = new_effects_parent
	highlight_scene = new_highlight_scene


# -------------------------------------------------------------------
# Settings
# -------------------------------------------------------------------

func set_selection_settings(
	new_edge_width: float,
	new_surface_offset: float,
	new_bottom_clearance: float
) -> void:
	edge_width = new_edge_width
	surface_offset = new_surface_offset
	bottom_clearance = new_bottom_clearance


# -------------------------------------------------------------------
# Public Interface
# -------------------------------------------------------------------

func show_cell(
	cell: Vector2i
) -> void:
	if cell == current_cell:
		return

	_fade_out_active_highlight()

	current_cell = cell
	active_highlight = _create_highlight_effect(
		cell
	)


func clear() -> void:
	if current_cell == DungeonConstants.NO_CELL:
		return

	current_cell = DungeonConstants.NO_CELL
	_fade_out_active_highlight()


func show_immediately(
	cell: Vector2i
) -> void:
	clear_immediately()

	current_cell = cell
	active_highlight = _create_highlight_effect(
		cell
	)


func refresh_current() -> void:
	if current_cell == DungeonConstants.NO_CELL:
		return

	show_immediately(
		current_cell
	)


func clear_immediately() -> void:
	current_cell = DungeonConstants.NO_CELL
	active_highlight = null

	if effects_parent == null:
		return

	for child: Node in effects_parent.get_children():
		child.queue_free()


# -------------------------------------------------------------------
# Highlight Creation
# -------------------------------------------------------------------

func _create_highlight_effect(
	cell: Vector2i
) -> Node3D:
	if generator == null:
		push_error(
			"HighlightManager: DungeonGenerator is not initialized."
		)
		return null

	if mesh_builder == null:
		push_error(
			"HighlightManager: SelectionMeshBuilder is not initialized."
		)
		return null

	if effects_parent == null:
		push_error(
			"HighlightManager: HighlightEffects parent is missing."
		)
		return null

	if highlight_scene == null:
		push_error(
			"HighlightManager: Highlight scene is not assigned."
		)
		return null

	var effect: Node3D = (
		highlight_scene.instantiate()
		as Node3D
	)

	if effect == null:
		push_error(
			"HighlightManager: Highlight scene root must be Node3D."
		)
		return null

	var edge_mesh: ArrayMesh = mesh_builder.build_mesh(
		cell,
		edge_width,
		surface_offset,
		bottom_clearance
	)

	effects_parent.add_child(
		effect
	)

	effect.call(
		"setup",
		edge_mesh
	)

	effect.call(
		"play_in"
	)

	return effect


# -------------------------------------------------------------------
# Highlight Removal
# -------------------------------------------------------------------

func _fade_out_active_highlight() -> void:
	if active_highlight == null:
		return

	if is_instance_valid(active_highlight):
		active_highlight.call(
			"play_out"
		)

	active_highlight = null
