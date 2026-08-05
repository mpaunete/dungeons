class_name SelectionBorderBuilder
extends RefCounted


# Builds glowing border geometry around one or more selected cells.
#
# The builder:
# - excludes invalid and excavated cells;
# - removes internal borders between adjacent selected cells;
# - follows the noisy terrain lattice;
# - outlines exposed vertical faces;
# - avoids duplicate shared edges;
# - generates crossed ribbons with continuous UV coordinates.


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
	if generator == null:
		push_error(
			"SelectionBorderBuilder: DungeonGenerator is not initialized."
		)
		return ArrayMesh.new()

	var surface_tool: SurfaceTool = SurfaceTool.new()

	surface_tool.begin(
		Mesh.PRIMITIVE_TRIANGLES
	)

	var selected_cell_lookup: Dictionary = (
		_build_selected_cell_lookup(
			cells
		)
	)

	var generated_edge_lookup: Dictionary = {}

	for cell_variant: Variant in selected_cell_lookup.keys():
		var cell: Vector2i = cell_variant as Vector2i

		_add_cell_boundary_edges(
			surface_tool,
			cell,
			selected_cell_lookup,
			generated_edge_lookup,
			edge_width,
			surface_offset
		)

	return surface_tool.commit()


# -------------------------------------------------------------------
# Selected Cell Lookup
# -------------------------------------------------------------------

func _build_selected_cell_lookup(
	cells: Array[Vector2i]
) -> Dictionary:
	var selected_cell_lookup: Dictionary = {}

	for cell: Vector2i in cells:
		if not _is_border_cell(cell):
			continue

		selected_cell_lookup[cell] = true

	return selected_cell_lookup


func _is_border_cell(
	cell: Vector2i
) -> bool:
	if not generator.is_valid_map_cell(cell):
		return false

	if generator.is_hole(cell):
		return false

	return true


# -------------------------------------------------------------------
# Cell Boundary Edges
# -------------------------------------------------------------------

func _add_cell_boundary_edges(
	surface_tool: SurfaceTool,
	cell: Vector2i,
	selected_cell_lookup: Dictionary,
	generated_edge_lookup: Dictionary,
	edge_width: float,
	surface_offset: float
) -> void:
	_add_top_boundary_edges(
		surface_tool,
		cell,
		selected_cell_lookup,
		generated_edge_lookup,
		edge_width,
		surface_offset
	)

	_add_exposed_face_borders(
		surface_tool,
		cell,
		selected_cell_lookup,
		generated_edge_lookup,
		edge_width,
		surface_offset
	)


# -------------------------------------------------------------------
# Top Boundary Edges
# -------------------------------------------------------------------

func _add_top_boundary_edges(
	surface_tool: SurfaceTool,
	cell: Vector2i,
	selected_cell_lookup: Dictionary,
	generated_edge_lookup: Dictionary,
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

	var top_offset: Vector3 = (
		Vector3.UP * surface_offset
	)

	var north_cell: Vector2i = (
		cell + Vector2i.UP
	)

	var south_cell: Vector2i = (
		cell + Vector2i.DOWN
	)

	var west_cell: Vector2i = (
		cell + Vector2i.LEFT
	)

	var east_cell: Vector2i = (
		cell + Vector2i.RIGHT
	)

	if not selected_cell_lookup.has(north_cell):
		_add_x_path_once(
			surface_tool,
			generated_edge_lookup,
			_get_top_edge_key(
				cell,
				"north"
			),
			start_x,
			end_x,
			start_z,
			top_offset,
			edge_width,
			_get_edge_seed(
				cell,
				0
			)
		)

	if not selected_cell_lookup.has(east_cell):
		_add_z_path_once(
			surface_tool,
			generated_edge_lookup,
			_get_top_edge_key(
				cell,
				"east"
			),
			start_z,
			end_z,
			end_x,
			top_offset,
			edge_width,
			_get_edge_seed(
				cell,
				1
			)
		)

	if not selected_cell_lookup.has(south_cell):
		_add_x_path_once(
			surface_tool,
			generated_edge_lookup,
			_get_top_edge_key(
				cell,
				"south"
			),
			end_x,
			start_x,
			end_z,
			top_offset,
			edge_width,
			_get_edge_seed(
				cell,
				2
			)
		)

	if not selected_cell_lookup.has(west_cell):
		_add_z_path_once(
			surface_tool,
			generated_edge_lookup,
			_get_top_edge_key(
				cell,
				"west"
			),
			end_z,
			start_z,
			start_x,
			top_offset,
			edge_width,
			_get_edge_seed(
				cell,
				3
			)
		)


# -------------------------------------------------------------------
# Exposed Face Borders
# -------------------------------------------------------------------

func _add_exposed_face_borders(
	surface_tool: SurfaceTool,
	cell: Vector2i,
	selected_cell_lookup: Dictionary,
	generated_edge_lookup: Dictionary,
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

	var north_cell: Vector2i = (
		cell + Vector2i.UP
	)

	var south_cell: Vector2i = (
		cell + Vector2i.DOWN
	)

	var west_cell: Vector2i = (
		cell + Vector2i.LEFT
	)

	var east_cell: Vector2i = (
		cell + Vector2i.RIGHT
	)

	if generator.is_open_cell(north_cell):
		_add_x_face_border(
			surface_tool,
			generated_edge_lookup,
			cell,
			start_x,
			end_x,
			start_z,
			Vector3(
				0.0,
				0.0,
				-surface_offset
			),
			edge_width,
			_get_edge_seed(
				cell,
				4
			),
			not _face_continues(
				selected_cell_lookup,
				west_cell,
				Vector2i.UP
			),
			not _face_continues(
				selected_cell_lookup,
				east_cell,
				Vector2i.UP
			)
		)

	if generator.is_open_cell(south_cell):
		_add_x_face_border(
			surface_tool,
			generated_edge_lookup,
			cell,
			start_x,
			end_x,
			end_z,
			Vector3(
				0.0,
				0.0,
				surface_offset
			),
			edge_width,
			_get_edge_seed(
				cell,
				5
			),
			not _face_continues(
				selected_cell_lookup,
				west_cell,
				Vector2i.DOWN
			),
			not _face_continues(
				selected_cell_lookup,
				east_cell,
				Vector2i.DOWN
			)
		)

	if generator.is_open_cell(west_cell):
		_add_z_face_border(
			surface_tool,
			generated_edge_lookup,
			cell,
			start_z,
			end_z,
			start_x,
			Vector3(
				-surface_offset,
				0.0,
				0.0
			),
			edge_width,
			_get_edge_seed(
				cell,
				6
			),
			not _face_continues(
				selected_cell_lookup,
				north_cell,
				Vector2i.LEFT
			),
			not _face_continues(
				selected_cell_lookup,
				south_cell,
				Vector2i.LEFT
			)
		)

	if generator.is_open_cell(east_cell):
		_add_z_face_border(
			surface_tool,
			generated_edge_lookup,
			cell,
			start_z,
			end_z,
			end_x,
			Vector3(
				surface_offset,
				0.0,
				0.0
			),
			edge_width,
			_get_edge_seed(
				cell,
				7
			),
			not _face_continues(
				selected_cell_lookup,
				north_cell,
				Vector2i.RIGHT
			),
			not _face_continues(
				selected_cell_lookup,
				south_cell,
				Vector2i.RIGHT
			)
		)


# -------------------------------------------------------------------
# Face Continuation
# -------------------------------------------------------------------

# Returns true when an adjacent selected cell has an exposed face
# pointing in the same direction.
#
# A continuing face must not draw the vertical edge shared with the
# current cell.

func _face_continues(
	selected_cell_lookup: Dictionary,
	adjacent_cell: Vector2i,
	outward_direction: Vector2i
) -> bool:
	if not selected_cell_lookup.has(adjacent_cell):
		return false

	var cell_outside_face: Vector2i = (
		adjacent_cell + outward_direction
	)

	return generator.is_open_cell(
		cell_outside_face
	)


# -------------------------------------------------------------------
# Edge Keys
# -------------------------------------------------------------------

func _get_top_edge_key(
	cell: Vector2i,
	side_name: String
) -> String:
	return "top_%s_%s_%s" % [
		side_name,
		cell.x,
		cell.y
	]


func _get_bottom_x_edge_key(
	cell: Vector2i,
	lattice_z: int
) -> String:
	return "bottom_x_%s_%s_%s" % [
		cell.x,
		cell.y,
		lattice_z
	]


func _get_bottom_z_edge_key(
	cell: Vector2i,
	lattice_x: int
) -> String:
	return "bottom_z_%s_%s_%s" % [
		cell.x,
		cell.y,
		lattice_x
	]


func _get_vertical_edge_key(
	lattice_x: int,
	lattice_z: int
) -> String:
	return "vertical_%s_%s" % [
		lattice_x,
		lattice_z
	]


# -------------------------------------------------------------------
# Edge Seeds
# -------------------------------------------------------------------

func _get_edge_seed(
	cell: Vector2i,
	side_index: int
) -> float:
	var seed_input: float = (
		float(cell.x) * 17.13
		+ float(cell.y) * 31.71
		+ float(side_index) * 7.91
	)

	var random_value: float = (
		sin(seed_input) * 43758.5453
	)

	return random_value - floor(
		random_value
	)


# -------------------------------------------------------------------
# X-Facing Vertical Borders
# -------------------------------------------------------------------

func _add_x_face_border(
	surface_tool: SurfaceTool,
	generated_edge_lookup: Dictionary,
	cell: Vector2i,
	start_x: int,
	end_x: int,
	lattice_z: int,
	outward_offset: Vector3,
	edge_width: float,
	edge_seed: float,
	draw_start_vertical: bool,
	draw_end_vertical: bool
) -> void:
	_add_bottom_x_path_once(
		surface_tool,
		generated_edge_lookup,
		_get_bottom_x_edge_key(
			cell,
			lattice_z
		),
		start_x,
		end_x,
		lattice_z,
		outward_offset,
		edge_width,
		edge_seed
	)

	if draw_start_vertical:
		_add_vertical_path_once(
			surface_tool,
			generated_edge_lookup,
			_get_vertical_edge_key(
				start_x,
				lattice_z
			),
			start_x,
			lattice_z,
			outward_offset,
			edge_width,
			edge_seed + 0.07
		)

	if draw_end_vertical:
		_add_vertical_path_once(
			surface_tool,
			generated_edge_lookup,
			_get_vertical_edge_key(
				end_x,
				lattice_z
			),
			end_x,
			lattice_z,
			outward_offset,
			edge_width,
			edge_seed + 0.14
		)


# -------------------------------------------------------------------
# Z-Facing Vertical Borders
# -------------------------------------------------------------------

func _add_z_face_border(
	surface_tool: SurfaceTool,
	generated_edge_lookup: Dictionary,
	cell: Vector2i,
	start_z: int,
	end_z: int,
	lattice_x: int,
	outward_offset: Vector3,
	edge_width: float,
	edge_seed: float,
	draw_start_vertical: bool,
	draw_end_vertical: bool
) -> void:
	_add_bottom_z_path_once(
		surface_tool,
		generated_edge_lookup,
		_get_bottom_z_edge_key(
			cell,
			lattice_x
		),
		start_z,
		end_z,
		lattice_x,
		outward_offset,
		edge_width,
		edge_seed
	)

	if draw_start_vertical:
		_add_vertical_path_once(
			surface_tool,
			generated_edge_lookup,
			_get_vertical_edge_key(
				lattice_x,
				start_z
			),
			lattice_x,
			start_z,
			outward_offset,
			edge_width,
			edge_seed + 0.07
		)

	if draw_end_vertical:
		_add_vertical_path_once(
			surface_tool,
			generated_edge_lookup,
			_get_vertical_edge_key(
				lattice_x,
				end_z
			),
			lattice_x,
			end_z,
			outward_offset,
			edge_width,
			edge_seed + 0.14
		)


# -------------------------------------------------------------------
# Unique Top Paths
# -------------------------------------------------------------------

func _add_x_path_once(
	surface_tool: SurfaceTool,
	generated_edge_lookup: Dictionary,
	edge_key: String,
	start_x: int,
	end_x: int,
	lattice_z: int,
	offset: Vector3,
	edge_width: float,
	edge_seed: float
) -> void:
	if not _claim_edge(
		generated_edge_lookup,
		edge_key
	):
		return

	_add_x_path(
		surface_tool,
		start_x,
		end_x,
		lattice_z,
		offset,
		edge_width,
		edge_seed
	)


func _add_z_path_once(
	surface_tool: SurfaceTool,
	generated_edge_lookup: Dictionary,
	edge_key: String,
	start_z: int,
	end_z: int,
	lattice_x: int,
	offset: Vector3,
	edge_width: float,
	edge_seed: float
) -> void:
	if not _claim_edge(
		generated_edge_lookup,
		edge_key
	):
		return

	_add_z_path(
		surface_tool,
		start_z,
		end_z,
		lattice_x,
		offset,
		edge_width,
		edge_seed
	)


# -------------------------------------------------------------------
# Top Path Construction
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

		points.append(
			point
		)

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

		points.append(
			point
		)

	_add_edge_path(
		surface_tool,
		points,
		edge_width,
		edge_seed
	)


# -------------------------------------------------------------------
# Bottom Border Paths
# -------------------------------------------------------------------

func _add_bottom_x_path_once(
	surface_tool: SurfaceTool,
	generated_edge_lookup: Dictionary,
	edge_key: String,
	start_x: int,
	end_x: int,
	lattice_z: int,
	offset: Vector3,
	edge_width: float,
	edge_seed: float
) -> void:
	if not _claim_edge(
		generated_edge_lookup,
		edge_key
	):
		return

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

		var terrain_point: Vector3 = (
			generator.get_terrain_point(
				lattice_x,
				lattice_z
			)
		)

		points.append(
			Vector3(
				terrain_point.x,
				generator.floor_y,
				terrain_point.z
			)
			+ offset
		)

	_add_edge_path(
		surface_tool,
		points,
		edge_width,
		edge_seed
	)


func _add_bottom_z_path_once(
	surface_tool: SurfaceTool,
	generated_edge_lookup: Dictionary,
	edge_key: String,
	start_z: int,
	end_z: int,
	lattice_x: int,
	offset: Vector3,
	edge_width: float,
	edge_seed: float
) -> void:
	if not _claim_edge(
		generated_edge_lookup,
		edge_key
	):
		return

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

		var terrain_point: Vector3 = (
			generator.get_terrain_point(
				lattice_x,
				lattice_z
			)
		)

		points.append(
			Vector3(
				terrain_point.x,
				generator.floor_y,
				terrain_point.z
			)
			+ offset
		)

	_add_edge_path(
		surface_tool,
		points,
		edge_width,
		edge_seed
	)


# -------------------------------------------------------------------
# Vertical Border Paths
# -------------------------------------------------------------------

func _add_vertical_path_once(
	surface_tool: SurfaceTool,
	generated_edge_lookup: Dictionary,
	edge_key: String,
	lattice_x: int,
	lattice_z: int,
	outward_offset: Vector3,
	edge_width: float,
	edge_seed: float
) -> void:
	if not _claim_edge(
		generated_edge_lookup,
		edge_key
	):
		return

	var terrain_point: Vector3 = (
		generator.get_terrain_point(
			lattice_x,
			lattice_z
		)
	)

	var top_point: Vector3 = (
		terrain_point
		+ Vector3.UP * 0.001
		+ outward_offset
	)

	var bottom_point: Vector3 = Vector3(
		top_point.x,
		generator.floor_y,
		top_point.z
	)

	var points: PackedVector3Array = (
		PackedVector3Array(
			[
				top_point,
				bottom_point
			]
		)
	)

	_add_edge_path(
		surface_tool,
		points,
		edge_width,
		edge_seed
	)


# -------------------------------------------------------------------
# Duplicate Edge Prevention
# -------------------------------------------------------------------

func _claim_edge(
	generated_edge_lookup: Dictionary,
	edge_key: String
) -> bool:
	if generated_edge_lookup.has(edge_key):
		return false

	generated_edge_lookup[edge_key] = true

	return true


# -------------------------------------------------------------------
# Edge Path Geometry
# -------------------------------------------------------------------

# Converts a sequence of points into crossed-ribbon segments.
#
# UV.x remains continuous from zero to one across the complete path,
# allowing shader stars to move across terrain subdivision boundaries.

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
		var segment_length: float = (
			points[segment_index].distance_to(
				points[segment_index + 1]
			)
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
		var start_point: Vector3 = (
			points[segment_index]
		)

		var end_point: Vector3 = (
			points[segment_index + 1]
		)

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

	var first_side: Vector3 = (
		edge_direction.cross(
			Vector3.UP
		).normalized()
	)

	# Vertical edges are parallel to Vector3.UP, so the first cross
	# product can be zero. Use Vector3.RIGHT as a fallback axis.
	if first_side.length_squared() < 0.0001:
		first_side = (
			edge_direction.cross(
				Vector3.RIGHT
			).normalized()
		)

	if first_side.length_squared() < 0.0001:
		return

	var second_side: Vector3 = (
		edge_direction.cross(
			first_side
		).normalized()
	)

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

	# First triangle.
	_add_vertex(
		surface_tool,
		start_left,
		Vector2(
			uv_start,
			0.0
		),
		edge_seed
	)

	_add_vertex(
		surface_tool,
		end_left,
		Vector2(
			uv_end,
			0.0
		),
		edge_seed
	)

	_add_vertex(
		surface_tool,
		start_right,
		Vector2(
			uv_start,
			1.0
		),
		edge_seed
	)

	# Second triangle.
	_add_vertex(
		surface_tool,
		start_right,
		Vector2(
			uv_start,
			1.0
		),
		edge_seed
	)

	_add_vertex(
		surface_tool,
		end_left,
		Vector2(
			uv_end,
			0.0
		),
		edge_seed
	)

	_add_vertex(
		surface_tool,
		end_right,
		Vector2(
			uv_end,
			1.0
		),
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
	surface_tool.set_uv(
		uv
	)

	# UV2.y carries the stable logical-edge seed into the shader.
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
