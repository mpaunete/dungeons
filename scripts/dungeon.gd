extends Node3D


# Coordinates dungeon generation, cell picking and selection input.
#
# Terrain generation, mouse picking and selection visuals are
# delegated to dedicated components.


# -------------------------------------------------------------------
# Selection Debugging
# -------------------------------------------------------------------

@export_category("Selection Debug")

@export var show_fixed_selection: bool = true:
	set(value):
		show_fixed_selection = value
		_request_selection_refresh()


# NO_CELL selects a suitable automatic debug cell.
@export var fixed_selection_cell: Vector2i = DungeonConstants.NO_CELL:
	set(value):
		fixed_selection_cell = value
		_request_selection_refresh()


# -------------------------------------------------------------------
# Scene References
# -------------------------------------------------------------------

@onready var generator: DungeonGenerator = $DungeonGenerator
@onready var dungeon_map: DungeonMap = $DungeonMap
@onready var cell_picker: CellPicker = $CellPicker
@onready var selection_manager: SelectionManager = $SelectionManager


# -------------------------------------------------------------------
# Runtime State
# -------------------------------------------------------------------

var selection_refresh_pending: bool = false


# -------------------------------------------------------------------
# Initialization
# -------------------------------------------------------------------

func _ready() -> void:
	if generator == null:
		push_error(
			"Dungeon: DungeonGenerator is missing."
		)
		return

	if dungeon_map == null:
		push_error(
			"Dungeon: DungeonMap is missing."
		)
		return

	if cell_picker == null:
		push_error(
			"Dungeon: CellPicker is missing."
		)
		return

	if selection_manager == null:
		push_error(
			"Dungeon: SelectionManager is missing."
		)
		return

	if not dungeon_map.load_configured_map():
		return

	generator.initialize(
		dungeon_map
	)

	generator.generate_level()

	cell_picker.initialize(
		generator,
		self
	)

	selection_manager.initialize(
		generator,
		cell_picker
	)

	cell_picker.cell_changed.connect(
		_on_picker_cell_changed
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
	if not show_fixed_selection:
		selection_manager.clear_selection()
		cell_picker.reset()
		return

	var target_cell: Vector2i = (
		_get_fixed_selection_target()
	)

	if not generator.is_valid_map_cell(target_cell):
		push_error(
			"Dungeon: Fixed selection cell is outside the map."
		)
		return

	selection_manager.clear_selection()
	selection_manager.show_hover(
		target_cell
	)


func _get_fixed_selection_target() -> Vector2i:
	if fixed_selection_cell != DungeonConstants.NO_CELL:
		return fixed_selection_cell

	return Vector2i(
		dungeon_map.width / 2,
		dungeon_map.height / 2
	)


# -------------------------------------------------------------------
# Cell Picker Events
# -------------------------------------------------------------------

func _on_picker_cell_changed(
	cell: Vector2i,
	is_valid: bool
) -> void:
	if not is_valid:
		selection_manager.clear_hover()
		return

	selection_manager.show_hover(
		cell
	)


# -------------------------------------------------------------------
# Input
# -------------------------------------------------------------------

func _unhandled_input(
	event: InputEvent
) -> void:
	if show_fixed_selection:
		return

	selection_manager.handle_input(
		event
	)
