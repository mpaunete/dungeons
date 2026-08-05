class_name SelectionBorderBuilder
extends RefCounted


# Builds one glowing outer border around a rectangular cell selection.
#
# The border follows the noisy terrain lattice and consists of four
# continuous paths: north, east, south and west.


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
	edge_width: float,
	surface_offset: float
) -> ArrayMesh:
	var surface_tool: SurfaceTool = SurfaceTool.new()
	surface_tool.begin(
		Mesh.PRIMITIVE_TRIANGLES
	)

	var selected_cells: Dictionary = {}

	for cell: Vector2i in cells:
		if not generator.is_valid_map_cell(cell):
			continue

		# Empty/excavated cells are not part of the selection border.
		if generator.is_hole(cell):
			continue

		selected_cells[cell] = true

	for cell_variant: Variant in selected_cells.keys():
		var cell: Vector2i = cell_variant as Vector2i

		_add_cell_boundary_edges(
			surface_tool,
			cell,
			selected_cells,
			edge_width,
			surface_offset
		)

	return surface_tool.commit()


# -------------------------------------------------------------------
# Cell Boundary Edges
# -------------------------------------------------------------------

func _add_cell_boundary_edges(
	surface_tool: SurfaceTool,
	cell: Vector2i,
	selected_cells: Dictionary,
	edge_width: float,
	surface_offset: float
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

	var offset: Vector3 = (
		Vector3.UP * surface_offset
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

	# Draw only edges exposed to a non-selected cell.

	if not selected_cells.has(north_cell):
		_add_x_path(
			surface_tool,
			start_x,
			end_x,
			start_z,
			offset,
			edge_width,
			_get_edge_seed(cell, 0)
		)

	if not selected_cells.has(east_cell):
		_add_z_path(
			surface_tool,
			start_z,
			end_z,
			end_x,
			offset,
			edge_width,
			_get_edge_seed(cell, 1)
		)

	if not selected_cells.has(south_cell):
		_add_x_path(
			surface_tool,
			end_x,
			start_x,
			end_z,
			offset,
			edge_width,
			_get_edge_seed(cell, 2)
		)

	if not selected_cells.has(west_cell):
		_add_z_path(
			surface_tool,
			end_z,
			start_z,
			start_x,
			offset,
			edge_width,
			_get_edge_seed(cell, 3)
		)


# -------------------------------------------------------------------
# Edge Seeds
# -------------------------------------------------------------------

func _get_edge_seed(
	cell: Vector2i,
	side_index: int
) -> float:
	var value: float = (
		float(cell.x) * 17.13
		+ float(cell.y) * 31.71
		+ float(side_index) * 7.91
	)

	return (sin(value) * 43758.5453) - floor(sin(value) * 43758.5453)


# -------------------------------------------------------------------
# Perimeter Paths
# -------------------------------------------------------------------

func _add_x_path(
	surface_tool: SurfaceTool,
	start_x: int,
	end_x: int,
	lattice_z: int,
	offset: Vector3,
	edge_width: float,
	edge_seed: float
) -> void:
	var points: PackedVector3Array = (
		PackedVector3Array()
	)

	var direction: int = 1

	if end_x < start_x:
		direction = -1

	var segment_count: int = absi(
		end_x - start_x
	)

	for point_index: int in range(
		segment_count + 1
	):
		var lattice_x: int = (
			start_x
			+ point_index * direction
		)

		var point: Vector3 = (
			generator.get_terrain_point(
				lattice_x,
				lattice_z
			)
			+ offset
		)

		points.append(point)

	_add_edge_path(
		surface_tool,
		points,
		edge_width,
		edge_seed
	)


func _add_z_path(
	surface_tool: SurfaceTool,
	start_z: int,
	end_z: int,
	lattice_x: int,
	offset: Vector3,
	edge_width: float,
	edge_seed: float
) -> void:
	var points: PackedVector3Array = (
		PackedVector3Array()
	)

	var direction: int = 1

	if end_z < start_z:
		direction = -1

	var segment_count: int = absi(
		end_z - start_z
	)

	for point_index: int in range(
		segment_count + 1
	):
		var lattice_z: int = (
			start_z
			+ point_index * direction
		)

		var point: Vector3 = (
			generator.get_terrain_point(
				lattice_x,
				lattice_z
			)
			+ offset
		)

		points.append(point)

	_add_edge_path(
		surface_tool,
		points,
		edge_width,
		edge_seed
	)


# -------------------------------------------------------------------
# Edge Path Geometry
# -------------------------------------------------------------------

func _add_edge_path(
	surface_tool: SurfaceTool,
	points: PackedVector3Array,
	edge_width: float,
	edge_seed: float
) -> void:
	if points.size() < 2:
		return

	var segment_lengths: PackedFloat32Array = (
		PackedFloat32Array()
	)

	var total_length: float = 0.0

	for segment_index: int in range(
		points.size() - 1
	):
		var segment_length: float = points[
			segment_index
		].distance_to(
			points[segment_index + 1]
		)

		segment_lengths.append(
			segment_length
		)

		total_length += segment_length

	if total_length <= 0.0001:
		return

	var travelled_length: float = 0.0

	for segment_index: int in range(
		points.size() - 1
	):
		var start_point: Vector3 = points[
			segment_index
		]

		var end_point: Vector3 = points[
			segment_index + 1
		]

		var segment_length: float = (
			segment_lengths[segment_index]
		)

		var uv_start: float = (
			travelled_length
			/ total_length
		)

		var uv_end: float = (
			travelled_length + segment_length
		) / total_length

		_add_crossed_edge_segment(
			surface_tool,
			start_point,
			end_point,
			edge_width,
			edge_seed,
			uv_start,
			uv_end
		)

		travelled_length += segment_length


# -------------------------------------------------------------------
# Crossed Edge Geometry
# -------------------------------------------------------------------

func _add_crossed_edge_segment(
	surface_tool: SurfaceTool,
	start_point: Vector3,
	end_point: Vector3,
	edge_width: float,
	edge_seed: float,
	uv_start: float,
	uv_end: float
) -> void:
	var edge_direction: Vector3 = (
		end_point - start_point
	).normalized()

	if edge_direction.length_squared() < 0.0001:
		return

	var first_side: Vector3 = edge_direction.cross(
		Vector3.UP
	).normalized()

	if first_side.length_squared() < 0.0001:
		first_side = edge_direction.cross(
			Vector3.RIGHT
		).normalized()

	if first_side.length_squared() < 0.0001:
		return

	var second_side: Vector3 = edge_direction.cross(
		first_side
	).normalized()

	_add_ribbon(
		surface_tool,
		start_point,
		end_point,
		first_side,
		edge_width,
		edge_seed,
		uv_start,
		uv_end
	)

	_add_ribbon(
		surface_tool,
		start_point,
		end_point,
		second_side,
		edge_width,
		edge_seed,
		uv_start,
		uv_end
	)


# -------------------------------------------------------------------
# Ribbon Geometry
# -------------------------------------------------------------------

func _add_ribbon(
	surface_tool: SurfaceTool,
	start_point: Vector3,
	end_point: Vector3,
	side_direction: Vector3,
	edge_width: float,
	edge_seed: float,
	uv_start: float,
	uv_end: float
) -> void:
	var normalized_side: Vector3 = (
		side_direction.normalized()
	)

	if normalized_side.length_squared() < 0.0001:
		return

	var half_width: Vector3 = (
		normalized_side
		* edge_width
		* 0.5
	)

	var start_left: Vector3 = (
		start_point - half_width
	)

	var start_right: Vector3 = (
		start_point + half_width
	)

	var end_left: Vector3 = (
		end_point - half_width
	)

	var end_right: Vector3 = (
		end_point + half_width
	)

	_add_vertex(
		surface_tool,
		start_left,
		Vector2(uv_start, 0.0),
		edge_seed
	)

	_add_vertex(
		surface_tool,
		end_left,
		Vector2(uv_end, 0.0),
		edge_seed
	)

	_add_vertex(
		surface_tool,
		start_right,
		Vector2(uv_start, 1.0),
		edge_seed
	)

	_add_vertex(
		surface_tool,
		start_right,
		Vector2(uv_start, 1.0),
		edge_seed
	)

	_add_vertex(
		surface_tool,
		end_left,
		Vector2(uv_end, 0.0),
		edge_seed
	)

	_add_vertex(
		surface_tool,
		end_right,
		Vector2(uv_end, 1.0),
		edge_seed
	)


# -------------------------------------------------------------------
# Vertex Data
# -------------------------------------------------------------------

func _add_vertex(
	surface_tool: SurfaceTool,
	vertex_position: Vector3,
	uv: Vector2,
	edge_seed: float
) -> void:
	surface_tool.set_uv(uv)

	surface_tool.set_uv2(
		Vector2(
			0.0,
			edge_seed
		)
	)

	surface_tool.set_color(
		Color.WHITE
	)

	surface_tool.add_vertex(
		vertex_position
	)
