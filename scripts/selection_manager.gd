class_name SelectionManager
extends Node


# Tracks hover, click and rectangular drag selections.
#
# Selection is additive:
# - dragging from an unselected cell adds cells;
# - dragging from a selected cell removes cells.
#
# Selection state is stored independently from the generated fill and
# border meshes. Geometry generation is delegated to dedicated builders.


# -------------------------------------------------------------------
# Signals
# -------------------------------------------------------------------

signal selection_changed(
	start_cell: Vector2i,
	end_cell: Vector2i,
	selected_cells: Array[Vector2i]
)

signal selection_cleared


# -------------------------------------------------------------------
# Selection Modes
# -------------------------------------------------------------------

enum SelectionMode {
	ADD,
	REMOVE
}


# -------------------------------------------------------------------
# Fill Settings
# -------------------------------------------------------------------

@export_category("Selection Fill")

@export_range(0.001, 0.10, 0.001)
var fill_surface_offset: float = 0.015

@export_range(0.0, 0.10, 0.001)
var fill_bottom_clearance: float = 0.015


# -------------------------------------------------------------------
# Selection Border Settings
# -------------------------------------------------------------------

@export_category("Selection Border")

@export_range(0.02, 0.30, 0.001)
var border_edge_width: float = 0.174

@export_range(0.001, 0.10, 0.001)
var border_surface_offset: float = 0.025


# -------------------------------------------------------------------
# Hover Border Settings
# -------------------------------------------------------------------

@export_category("Hover Border")

@export_range(0.001, 0.10, 0.001)
var hover_border_surface_offset: float = 0.035


# -------------------------------------------------------------------
# Dependencies
# -------------------------------------------------------------------

var generator: DungeonGenerator
var cell_picker: CellPicker


# -------------------------------------------------------------------
# Scene References
# -------------------------------------------------------------------

@onready var selection_fill: MeshInstance3D = $SelectionFill
@onready var selection_border: MeshInstance3D = $SelectionBorder
@onready var hover_border: MeshInstance3D = $HoverBorder


# -------------------------------------------------------------------
# Geometry Builders
# -------------------------------------------------------------------

var fill_builder: SelectionFillBuilder
var border_builder: SelectionBorderBuilder


# -------------------------------------------------------------------
# Selection State
# -------------------------------------------------------------------

var is_dragging: bool = false
var has_committed_selection: bool = false

var drag_mode: SelectionMode = SelectionMode.ADD

var drag_start_cell: Vector2i = DungeonConstants.NO_CELL
var drag_current_cell: Vector2i = DungeonConstants.NO_CELL

var selected_start_cell: Vector2i = DungeonConstants.NO_CELL
var selected_end_cell: Vector2i = DungeonConstants.NO_CELL

# Authoritative committed selection.
#
# Keys are selected cell coordinates. Values are always true.
var selected_cell_lookup: Dictionary = {}

# Snapshot of the committed selection when a drag begins.
#
# Every preview is rebuilt from this snapshot so shrinking or reversing
# a drag produces the correct result.
var selection_before_drag: Dictionary = {}

# Current live preview while dragging.
var preview_cell_lookup: Dictionary = {}

# Array representations used by builders, signals and gameplay systems.
var selected_cells: Array[Vector2i] = []
var preview_cells: Array[Vector2i] = []


# -------------------------------------------------------------------
# Hover State
# -------------------------------------------------------------------

var hovered_cell: Vector2i = DungeonConstants.NO_CELL


# -------------------------------------------------------------------
# Initialization
# -------------------------------------------------------------------

func initialize(
	new_generator: DungeonGenerator,
	new_cell_picker: CellPicker
) -> void:
	if new_generator == null:
		push_error(
			"SelectionManager: DungeonGenerator dependency is missing."
		)
		return

	if new_cell_picker == null:
		push_error(
			"SelectionManager: CellPicker dependency is missing."
		)
		return

	if selection_fill == null:
		push_error(
			"SelectionManager: SelectionFill child is missing."
		)
		return

	if selection_border == null:
		push_error(
			"SelectionManager: SelectionBorder child is missing."
		)
		return

	if hover_border == null:
		push_error(
			"SelectionManager: HoverBorder child is missing."
		)
		return

	generator = new_generator
	cell_picker = new_cell_picker

	fill_builder = SelectionFillBuilder.new()
	fill_builder.initialize(
		generator
	)

	border_builder = SelectionBorderBuilder.new()
	border_builder.initialize(
		generator
	)

	_clear_selection_visuals()
	clear_hover()


# -------------------------------------------------------------------
# Selection Input
# -------------------------------------------------------------------

func begin_selection(
	cell: Vector2i
) -> void:
	if not _is_selectable_cell(cell):
		return

	is_dragging = true

	drag_start_cell = cell
	drag_current_cell = cell

	selected_start_cell = DungeonConstants.NO_CELL
	selected_end_cell = DungeonConstants.NO_CELL

	selection_before_drag = _copy_cell_lookup(
		selected_cell_lookup
	)

	if selected_cell_lookup.has(cell):
		drag_mode = SelectionMode.REMOVE
	else:
		drag_mode = SelectionMode.ADD

	_update_preview_selection()


func update_selection(
	cell: Vector2i
) -> void:
	if not is_dragging:
		return

	if not _is_selectable_cell(cell):
		return

	show_hover(
		cell
	)

	if cell == drag_current_cell:
		return

	drag_current_cell = cell

	_update_preview_selection()


func finish_selection() -> void:
	if not is_dragging:
		return

	is_dragging = false

	selected_start_cell = drag_start_cell
	selected_end_cell = drag_current_cell

	selected_cell_lookup = _copy_cell_lookup(
		preview_cell_lookup
	)

	selected_cells = _cell_lookup_to_array(
		selected_cell_lookup
	)

	has_committed_selection = (
		not selected_cells.is_empty()
	)

	_show_selection_visuals(
		selected_cells
	)

	selection_before_drag.clear()
	preview_cell_lookup.clear()
	preview_cells.clear()

	selection_changed.emit(
		selected_start_cell,
		selected_end_cell,
		selected_cells
	)


func cancel_drag() -> void:
	if not is_dragging:
		return

	is_dragging = false

	selected_cell_lookup = _copy_cell_lookup(
		selection_before_drag
	)

	selected_cells = _cell_lookup_to_array(
		selected_cell_lookup
	)

	has_committed_selection = (
		not selected_cells.is_empty()
	)

	selection_before_drag.clear()
	preview_cell_lookup.clear()
	preview_cells.clear()

	drag_start_cell = DungeonConstants.NO_CELL
	drag_current_cell = DungeonConstants.NO_CELL

	_show_selection_visuals(
		selected_cells
	)


func clear_selection() -> void:
	is_dragging = false
	has_committed_selection = false

	drag_mode = SelectionMode.ADD

	drag_start_cell = DungeonConstants.NO_CELL
	drag_current_cell = DungeonConstants.NO_CELL

	selected_start_cell = DungeonConstants.NO_CELL
	selected_end_cell = DungeonConstants.NO_CELL

	selected_cell_lookup.clear()
	selection_before_drag.clear()
	preview_cell_lookup.clear()

	selected_cells.clear()
	preview_cells.clear()

	_clear_selection_visuals()

	selection_cleared.emit()


# -------------------------------------------------------------------
# Hover Preview
# -------------------------------------------------------------------

func show_hover(
	cell: Vector2i
) -> void:
	if not _is_selectable_cell(cell):
		clear_hover()
		return

	if (
		cell == hovered_cell
		and hover_border.mesh != null
	):
		return

	hovered_cell = cell

	var hover_cells: Array[Vector2i] = [
		cell
	]

	_show_hover_border(
		hover_cells
	)


func clear_hover() -> void:
	hovered_cell = DungeonConstants.NO_CELL

	if hover_border != null:
		hover_border.mesh = null


# -------------------------------------------------------------------
# Selection Preview
# -------------------------------------------------------------------

func _update_preview_selection() -> void:
	var dragged_cells: Array[Vector2i] = (
		_get_cells_in_rectangle(
			drag_start_cell,
			drag_current_cell
		)
	)

	preview_cell_lookup = _build_drag_preview_lookup(
		dragged_cells
	)

	preview_cells = _cell_lookup_to_array(
		preview_cell_lookup
	)

	_show_selection_visuals(
		preview_cells
	)

	selection_changed.emit(
		drag_start_cell,
		drag_current_cell,
		preview_cells
	)


func _build_drag_preview_lookup(
	dragged_cells: Array[Vector2i]
) -> Dictionary:
	var preview_lookup: Dictionary = _copy_cell_lookup(
		selection_before_drag
	)

	for cell: Vector2i in dragged_cells:
		match drag_mode:
			SelectionMode.ADD:
				preview_lookup[cell] = true

			SelectionMode.REMOVE:
				preview_lookup.erase(
					cell
				)

	return preview_lookup


# -------------------------------------------------------------------
# Selection Display
# -------------------------------------------------------------------

func _show_selection_visuals(
	cells: Array[Vector2i]
) -> void:
	if fill_builder != null:
		selection_fill.mesh = fill_builder.build_mesh(
			cells,
			fill_surface_offset,
			fill_bottom_clearance
		)

	if border_builder != null:
		selection_border.mesh = border_builder.build_mesh(
			cells,
			border_edge_width,
			border_surface_offset
		)


func _clear_selection_visuals() -> void:
	if selection_fill != null:
		selection_fill.mesh = null

	if selection_border != null:
		selection_border.mesh = null


func _show_hover_border(
	cells: Array[Vector2i]
) -> void:
	if border_builder == null:
		return

	hover_border.mesh = border_builder.build_mesh(
		cells,
		border_edge_width,
		hover_border_surface_offset
	)


# -------------------------------------------------------------------
# Rectangle Queries
# -------------------------------------------------------------------

func _get_cells_in_rectangle(
	first_cell: Vector2i,
	second_cell: Vector2i
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []

	var minimum_x: int = mini(
		first_cell.x,
		second_cell.x
	)

	var maximum_x: int = maxi(
		first_cell.x,
		second_cell.x
	)

	var minimum_z: int = mini(
		first_cell.y,
		second_cell.y
	)

	var maximum_z: int = maxi(
		first_cell.y,
		second_cell.y
	)

	for cell_x: int in range(
		minimum_x,
		maximum_x + 1
	):
		for cell_z: int in range(
			minimum_z,
			maximum_z + 1
		):
			var cell: Vector2i = Vector2i(
				cell_x,
				cell_z
			)

			if _is_selectable_cell(cell):
				cells.append(
					cell
				)

	return cells


# -------------------------------------------------------------------
# Selection Lookup Helpers
# -------------------------------------------------------------------

func _copy_cell_lookup(
	source: Dictionary
) -> Dictionary:
	var copy: Dictionary = {}

	for cell_variant: Variant in source.keys():
		var cell: Vector2i = (
			cell_variant as Vector2i
		)

		copy[cell] = true

	return copy


func _cell_lookup_to_array(
	cell_lookup: Dictionary
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []

	for cell_variant: Variant in cell_lookup.keys():
		var cell: Vector2i = (
			cell_variant as Vector2i
		)

		cells.append(
			cell
		)

	cells.sort_custom(
		func(
			first: Vector2i,
			second: Vector2i
		) -> bool:
			if first.y == second.y:
				return first.x < second.x

			return first.y < second.y
	)

	return cells


# -------------------------------------------------------------------
# Cell Validation
# -------------------------------------------------------------------

func _is_selectable_cell(
	cell: Vector2i
) -> bool:
	if generator == null:
		return false

	if not generator.is_valid_map_cell(cell):
		return false

	if generator.is_hole(cell):
		return false

	return true


# -------------------------------------------------------------------
# Input
# -------------------------------------------------------------------

func handle_input(
	event: InputEvent
) -> void:
	if cell_picker == null:
		return

	if event is InputEventKey:
		_handle_key_input(
			event as InputEventKey
		)
		return

	if event is InputEventMouseButton:
		_handle_mouse_button(
			event as InputEventMouseButton
		)
		return

	if event is InputEventMouseMotion:
		_handle_mouse_motion()


func _handle_key_input(
	key_event: InputEventKey
) -> void:
	if not key_event.pressed:
		return

	if key_event.echo:
		return

	if key_event.keycode != KEY_ESCAPE:
		return

	if is_dragging:
		cancel_drag()
	else:
		clear_selection()


func _handle_mouse_button(
	mouse_event: InputEventMouseButton
) -> void:
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if mouse_event.pressed:
		var cell: Vector2i = (
			cell_picker.get_current_cell()
		)

		if cell != DungeonConstants.NO_CELL:
			begin_selection(
				cell
			)

		return

	finish_selection()


func _handle_mouse_motion() -> void:
	if not is_dragging:
		return

	var cell: Vector2i = (
		cell_picker.get_current_cell()
	)

	if cell == DungeonConstants.NO_CELL:
		return

	update_selection(
		cell
	)


# -------------------------------------------------------------------
# Public Queries
# -------------------------------------------------------------------

func has_selection() -> bool:
	return has_committed_selection


func is_cell_selected(
	cell: Vector2i
) -> bool:
	return selected_cell_lookup.has(
		cell
	)


func get_selected_cells() -> Array[Vector2i]:
	return selected_cells.duplicate()


func get_preview_cells() -> Array[Vector2i]:
	return preview_cells.duplicate()


func get_hovered_cell() -> Vector2i:
	return hovered_cell
