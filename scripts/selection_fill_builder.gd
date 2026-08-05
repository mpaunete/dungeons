class_name SelectionFillBuilder
extends RefCounted


# Builds a surface-overlay mesh for selected dungeon cells.
#
# The top overlay follows the same subdivided, noisy terrain as the
# dungeon surface. Exposed vertical walls receive matching overlays.


# -------------------------------------------------------------------
# Dependencies
# -------------------------------------------------------------------

var generator: DungeonGenerator


# -------------------------------------------------------------------
# Initialization
# -------------------------------------------------------------------

func initialize(
	new_generator: DungeonGenerator
) -> void:
	generator = new_generator


# -------------------------------------------------------------------
# Public Interface
# -------------------------------------------------------------------

func build_mesh(
	cells: Array[Vector2i],
	surface_offset: float,
	bottom_clearance: float = 0.015
) -> ArrayMesh:
	if generator == null:
		push_error(
			"SelectionFillBuilder: DungeonGenerator is not initialized."
		)
		return ArrayMesh.new()

	var surface_tool: SurfaceTool = SurfaceTool.new()

	surface_tool.begin(
		Mesh.PRIMITIVE_TRIANGLES
	)

	for cell: Vector2i in cells:
		if not _is_fillable_cell(cell):
			continue

		_add_cell_top_surface(
			surface_tool,
			cell,
			surface_offset
		)

		_add_exposed_vertical_faces(
			surface_tool,
			cell,
			surface_offset,
			bottom_clearance
		)

	return surface_tool.commit()


# -------------------------------------------------------------------
# Cell Validation
# -------------------------------------------------------------------

func _is_fillable_cell(
	cell: Vector2i
) -> bool:
	if not generator.is_valid_map_cell(cell):
		return false

	if generator.is_hole(cell):
		return false

	return true


# -------------------------------------------------------------------
# Cell Top Surface
# -------------------------------------------------------------------

func _add_cell_top_surface(
	surface_tool: SurfaceTool,
	cell: Vector2i,
	surface_offset: float
) -> void:
	var lattice_start_x: int = (
		cell.x * generator.subdivisions
	)

	var lattice_start_z: int = (
		cell.y * generator.subdivisions
	)

	var offset: Vector3 = (
		Vector3.UP * surface_offset
	)

	for sub_x: int in range(
		generator.subdivisions
	):
		for sub_z: int in range(
			generator.subdivisions
		):
			var lattice_x: int = (
				lattice_start_x + sub_x
			)

			var lattice_z: int = (
				lattice_start_z + sub_z
			)

			var point_00: Vector3 = (
				generator.get_terrain_point(
					lattice_x,
					lattice_z
				)
				+ offset
			)

			var point_10: Vector3 = (
				generator.get_terrain_point(
					lattice_x + 1,
					lattice_z
				)
				+ offset
			)

			var point_01: Vector3 = (
				generator.get_terrain_point(
					lattice_x,
					lattice_z + 1
				)
				+ offset
			)

			var point_11: Vector3 = (
				generator.get_terrain_point(
					lattice_x + 1,
					lattice_z + 1
				)
				+ offset
			)

			_add_triangle(
				surface_tool,
				point_00,
				point_01,
				point_10
			)

			_add_triangle(
				surface_tool,
				point_10,
				point_01,
				point_11
			)


# -------------------------------------------------------------------
# Exposed Vertical Faces
# -------------------------------------------------------------------

func _add_exposed_vertical_faces(
	surface_tool: SurfaceTool,
	cell: Vector2i,
	surface_offset: float,
	bottom_clearance: float
) -> void:
	var start_x: int = (
		cell.x * generator.subdivisions
	)

	var start_z: int = (
		cell.y * generator.subdivisions
	)

	var end_x: int = (
		start_x + generator.subdivisions
	)

	var end_z: int = (
		start_z + generator.subdivisions
	)

	var north_cell: Vector2i = Vector2i(
		cell.x,
		cell.y - 1
	)

	var south_cell: Vector2i = Vector2i(
		cell.x,
		cell.y + 1
	)

	var west_cell: Vector2i = Vector2i(
		cell.x - 1,
		cell.y
	)

	var east_cell: Vector2i = Vector2i(
		cell.x + 1,
		cell.y
	)

	if generator.is_open_cell(north_cell):
		_add_x_vertical_face(
			surface_tool,
			start_x,
			end_x,
			start_z,
			Vector3(
				0.0,
				0.0,
				-surface_offset
			),
			bottom_clearance
		)

	if generator.is_open_cell(south_cell):
		_add_x_vertical_face(
			surface_tool,
			start_x,
			end_x,
			end_z,
			Vector3(
				0.0,
				0.0,
				surface_offset
			),
			bottom_clearance
		)

	if generator.is_open_cell(west_cell):
		_add_z_vertical_face(
			surface_tool,
			start_z,
			end_z,
			start_x,
			Vector3(
				-surface_offset,
				0.0,
				0.0
			),
			bottom_clearance
		)

	if generator.is_open_cell(east_cell):
		_add_z_vertical_face(
			surface_tool,
			start_z,
			end_z,
			end_x,
			Vector3(
				surface_offset,
				0.0,
				0.0
			),
			bottom_clearance
		)


# -------------------------------------------------------------------
# X-Axis Vertical Faces
# -------------------------------------------------------------------

func _add_x_vertical_face(
	surface_tool: SurfaceTool,
	start_x: int,
	end_x: int,
	lattice_z: int,
	outward_offset: Vector3,
	bottom_clearance: float
) -> void:
	var direction: int = 1

	if end_x < start_x:
		direction = -1

	var segment_count: int = absi(
		end_x - start_x
	)

	for segment_index: int in range(
		segment_count
	):
		var lattice_x_a: int = (
			start_x
			+ segment_index * direction
		)

		var lattice_x_b: int = (
			lattice_x_a + direction
		)

		var top_a: Vector3 = (
			generator.get_terrain_point(
				lattice_x_a,
				lattice_z
			)
			+ outward_offset
		)

		var top_b: Vector3 = (
			generator.get_terrain_point(
				lattice_x_b,
				lattice_z
			)
			+ outward_offset
		)

		var bottom_a: Vector3 = Vector3(
			top_a.x,
			generator.floor_y + bottom_clearance,
			top_a.z
		)

		var bottom_b: Vector3 = Vector3(
			top_b.x,
			generator.floor_y + bottom_clearance,
			top_b.z
		)

		_add_quad(
			surface_tool,
			top_a,
			top_b,
			bottom_a,
			bottom_b
		)


# -------------------------------------------------------------------
# Z-Axis Vertical Faces
# -------------------------------------------------------------------

func _add_z_vertical_face(
	surface_tool: SurfaceTool,
	start_z: int,
	end_z: int,
	lattice_x: int,
	outward_offset: Vector3,
	bottom_clearance: float
) -> void:
	var direction: int = 1

	if end_z < start_z:
		direction = -1

	var segment_count: int = absi(
		end_z - start_z
	)

	for segment_index: int in range(
		segment_count
	):
		var lattice_z_a: int = (
			start_z
			+ segment_index * direction
		)

		var lattice_z_b: int = (
			lattice_z_a + direction
		)

		var top_a: Vector3 = (
			generator.get_terrain_point(
				lattice_x,
				lattice_z_a
			)
			+ outward_offset
		)

		var top_b: Vector3 = (
			generator.get_terrain_point(
				lattice_x,
				lattice_z_b
			)
			+ outward_offset
		)

		var bottom_a: Vector3 = Vector3(
			top_a.x,
			generator.floor_y + bottom_clearance,
			top_a.z
		)

		var bottom_b: Vector3 = Vector3(
			top_b.x,
			generator.floor_y + bottom_clearance,
			top_b.z
		)

		_add_quad(
			surface_tool,
			top_a,
			top_b,
			bottom_a,
			bottom_b
		)


# -------------------------------------------------------------------
# Mesh Helpers
# -------------------------------------------------------------------

func _add_quad(
	surface_tool: SurfaceTool,
	top_a: Vector3,
	top_b: Vector3,
	bottom_a: Vector3,
	bottom_b: Vector3
) -> void:
	_add_triangle(
		surface_tool,
		top_a,
		bottom_a,
		top_b
	)

	_add_triangle(
		surface_tool,
		top_b,
		bottom_a,
		bottom_b
	)


func _add_triangle(
	surface_tool: SurfaceTool,
	point_a: Vector3,
	point_b: Vector3,
	point_c: Vector3
) -> void:
	surface_tool.add_vertex(
		point_a
	)

	surface_tool.add_vertex(
		point_b
	)

	surface_tool.add_vertex(
		point_c
	)
