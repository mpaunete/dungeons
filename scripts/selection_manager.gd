class_name SelectionManager
extends Node


# Tracks click and rectangular drag selections.
#
# It owns selection state but does not yet draw the selection.


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
# Fill Settings
# -------------------------------------------------------------------

@export_category("Selection Fill")

@export_range(0.001, 0.10, 0.001)
var fill_surface_offset: float = 0.015


# -------------------------------------------------------------------
# Border Settings
# -------------------------------------------------------------------

@export_range(0.02, 0.30, 0.001)
var border_edge_width: float = 0.174

@export_range(0.001, 0.10, 0.001)
var border_surface_offset: float = 0.025


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


# -------------------------------------------------------------------
# Runtime State
# -------------------------------------------------------------------

var fill_builder: SelectionFillBuilder
var border_builder: SelectionBorderBuilder

var is_dragging: bool = false

var drag_start_cell: Vector2i = DungeonConstants.NO_CELL
var drag_current_cell: Vector2i = DungeonConstants.NO_CELL

var selected_start_cell: Vector2i = DungeonConstants.NO_CELL
var selected_end_cell: Vector2i = DungeonConstants.NO_CELL

var selected_cells: Array[Vector2i] = []


# -------------------------------------------------------------------
# Initialization
# -------------------------------------------------------------------

func initialize(
	new_generator: DungeonGenerator,
	new_cell_picker: CellPicker
) -> void:
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

	_clear_visuals()


# -------------------------------------------------------------------
# Selection Input
# -------------------------------------------------------------------

func begin_selection(cell: Vector2i) -> void:
	if generator == null:
		return

	if not generator.is_valid_map_cell(cell):
		return

	is_dragging = true
	drag_start_cell = cell
	drag_current_cell = cell

	_update_preview_selection()


func update_selection(cell: Vector2i) -> void:
	if not is_dragging:
		return

	if generator == null:
		return

	if not generator.is_valid_map_cell(cell):
		return

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
	selected_cells = _get_cells_in_rectangle(
		selected_start_cell,
		selected_end_cell
	)


	_show_selection_visuals(
		selected_start_cell,
		selected_end_cell,
		selected_cells
	)

	selection_changed.emit(
		selected_start_cell,
		selected_end_cell,
		selected_cells
	)


func clear_selection() -> void:
	is_dragging = false

	drag_start_cell = DungeonConstants.NO_CELL
	drag_current_cell = DungeonConstants.NO_CELL

	selected_start_cell = DungeonConstants.NO_CELL
	selected_end_cell = DungeonConstants.NO_CELL

	selected_cells.clear()

	_clear_visuals()

	selection_cleared.emit()


# -------------------------------------------------------------------
# Selection Preview
# -------------------------------------------------------------------

func _update_preview_selection() -> void:
	var preview_cells: Array[Vector2i] = (
		_get_cells_in_rectangle(
			drag_start_cell,
			drag_current_cell
		)
	)

	_show_selection_visuals(
		drag_start_cell,
		drag_current_cell,
		preview_cells
	)

	selection_changed.emit(
		drag_start_cell,
		drag_current_cell,
		preview_cells
	)


# -------------------------------------------------------------------
# Selection Display
# -------------------------------------------------------------------

func _show_selection_visuals(
	start_cell: Vector2i,
	end_cell: Vector2i,
	cells: Array[Vector2i]
) -> void:
	if (
		selection_fill != null
		and fill_builder != null
	):
		selection_fill.mesh = fill_builder.build_mesh(
			cells,
			fill_surface_offset
		)

	if (
		selection_border != null
		and border_builder != null
	):
		selection_border.mesh = border_builder.build_mesh(
			cells,
			border_edge_width,
			border_surface_offset
		)


func _clear_visuals() -> void:
	if selection_fill != null:
		selection_fill.mesh = null

	if selection_border != null:
		selection_border.mesh = null


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

			if generator.is_valid_map_cell(cell):
				cells.append(cell)

	return cells


# -------------------------------------------------------------------
# Input
# -------------------------------------------------------------------

func handle_input(event: InputEvent) -> void:
	if cell_picker == null:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton

		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return

		if mouse_event.pressed:
			var cell: Vector2i = (
				cell_picker.get_current_cell()
			)

			if cell != DungeonConstants.NO_CELL:
				begin_selection(cell)
		else:
			finish_selection()

		return

	if event is InputEventMouseMotion:
		if not is_dragging:
			return

		var cell: Vector2i = (
			cell_picker.get_current_cell()
		)

		if cell != DungeonConstants.NO_CELL:
			update_selection(cell)
