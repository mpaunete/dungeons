extends Node3D


# Coordinates dungeon generation, cell picking and highlight display.
#
# Terrain generation, selection geometry and highlight lifecycle are
# delegated to dedicated components.


# -------------------------------------------------------------------
# Selection Settings
# -------------------------------------------------------------------

@export_category("Selection Lines")

@export_range(0.005, 0.30, 0.001)
var selection_edge_width: float = 0.18:
	set(value):
		selection_edge_width = value
		_request_selection_refresh()


@export_range(0.0, 0.05, 0.001)
var selection_surface_offset: float = 0.012:
	set(value):
		selection_surface_offset = value
		_request_selection_refresh()


@export_range(0.0, 0.30, 0.01)
var selection_bottom_clearance: float = 0.04:
	set(value):
		selection_bottom_clearance = value
		_request_selection_refresh()


# -------------------------------------------------------------------
# Selection Debugging
# -------------------------------------------------------------------

@export_category("Selection Debug")

@export var show_fixed_selection: bool = true:
	set(value):
		show_fixed_selection = value
		_request_selection_refresh()


# NO_CELL selects the centre cell automatically in debug mode.
@export var fixed_selection_cell: Vector2i = DungeonConstants.NO_CELL:
	set(value):
		fixed_selection_cell = value
		_request_selection_refresh()


# -------------------------------------------------------------------
# Highlight Effect
# -------------------------------------------------------------------

@export_category("Highlight Effect")

@export var highlight_effect_scene: PackedScene


# -------------------------------------------------------------------
# Scene References
# -------------------------------------------------------------------

@onready var highlight_effects: Node3D = $HighlightEffects
@onready var generator: DungeonGenerator = $DungeonGenerator
@onready var cell_picker: CellPicker = $CellPicker
@onready var highlight_manager: HighlightManager = $HighlightManager
@onready var selection_manager: SelectionManager = $SelectionManager


# -------------------------------------------------------------------
# Runtime State
# -------------------------------------------------------------------

var selection_mesh_builder: SelectionMeshBuilder
var selection_refresh_pending: bool = false


# -------------------------------------------------------------------
# Initialization
# -------------------------------------------------------------------

func _ready() -> void:
	if generator == null:
		push_error("Dungeon: DungeonGenerator is missing.")
		return

	if cell_picker == null:
		push_error("Dungeon: CellPicker is missing.")
		return

	if highlight_manager == null:
		push_error("Dungeon: HighlightManager is missing.")
		return

	if highlight_effects == null:
		push_error("Dungeon: HighlightEffects is missing.")
		return

	if highlight_effect_scene == null:
		push_error("Dungeon: Highlight Effect Scene is not assigned.")
		return

	generator.initialize()
	generator.generate_level()

	selection_mesh_builder = SelectionMeshBuilder.new()
	selection_mesh_builder.initialize(
		generator
	)

	highlight_manager.initialize(
		generator,
		selection_mesh_builder,
		highlight_effects,
		highlight_effect_scene
	)

	highlight_manager.set_selection_settings(
		selection_edge_width,
		selection_surface_offset,
		selection_bottom_clearance
	)

	cell_picker.initialize(
		generator,
		self
	)

	cell_picker.cell_changed.connect(
		_on_picker_cell_changed
	)
	
	selection_manager.initialize(
		generator,
		cell_picker
	)


	selection_manager.selection_changed.connect(
		_on_selection_changed
	)

	selection_manager.selection_cleared.connect(
		_on_selection_cleared
	)
	
	_request_selection_refresh()


# -------------------------------------------------------------------
# Frame Update
# -------------------------------------------------------------------

func _process(_delta: float) -> void:
	if selection_refresh_pending:
		selection_refresh_pending = false
		_refresh_selection()

	if show_fixed_selection:
		return

	cell_picker.update_hover()


# -------------------------------------------------------------------
# Selection Refresh
# -------------------------------------------------------------------

func _request_selection_refresh() -> void:
	if not is_inside_tree():
		return

	selection_refresh_pending = true


func _refresh_selection() -> void:
	highlight_manager.set_selection_settings(
		selection_edge_width,
		selection_surface_offset,
		selection_bottom_clearance
	)

	if not show_fixed_selection:
		highlight_manager.clear_immediately()
		return

	var target_cell: Vector2i = get_fixed_selection_target()

	if not generator.is_valid_map_cell(target_cell):
		push_error(
			"Dungeon: Fixed selection cell is outside the map."
		)
		return

	highlight_manager.show_immediately(
		target_cell
	)


func get_fixed_selection_target() -> Vector2i:
	if fixed_selection_cell != DungeonConstants.NO_CELL:
		return fixed_selection_cell

	var centre: int = generator.map_size / 2

	return Vector2i(
		centre,
		centre
	)


# -------------------------------------------------------------------
# Cell Picker Events
# -------------------------------------------------------------------

func _on_picker_cell_changed(
	cell: Vector2i,
	is_valid: bool
) -> void:
	if not is_valid:
		highlight_manager.clear()
		return

	highlight_manager.show_cell(
		cell
	)


# -------------------------------------------------------------------
# Selection Manager Events
# -------------------------------------------------------------------

func _on_selection_changed(
	start_cell: Vector2i,
	end_cell: Vector2i,
	selected_cells: Array[Vector2i]
) -> void:
	print(
		"Selection: ",
		start_cell,
		" → ",
		end_cell,
		" | cells: ",
		selected_cells.size()
	)


func _on_selection_cleared() -> void:
	print("Selection cleared")


# -------------------------------------------------------------------
# Input
# -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if show_fixed_selection:
		return

	selection_manager.handle_input(event)
