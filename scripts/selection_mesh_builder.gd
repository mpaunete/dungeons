class_name SelectionMeshBuilder
extends RefCounted


# Builds the glowing selection-edge geometry for one dungeon cell.
#
# Uses DungeonGenerator for terrain positions and map queries.
# It does not manage hovering, highlight nodes, materials or animation.


# -------------------------------------------------------------------
# Dependencies
# -------------------------------------------------------------------

var generator: DungeonGenerator


# -------------------------------------------------------------------
# Selection Settings
# -------------------------------------------------------------------

var edge_width: float = 0.18
var surface_offset: float = 0.012
var bottom_clearance: float = 0.04


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
	cell: Vector2i,
	edge_width_value: float,
	surface_offset_value: float,
	bottom_clearance_value: float
) -> ArrayMesh:
	edge_width = edge_width_value
	surface_offset = surface_offset_value
	bottom_clearance = bottom_clearance_value

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

	if generator.is_hole(cell):
		return build_empty_cell_selection_mesh(
			start_x,
			start_z,
			end_x,
			end_z
		)

	return build_solid_cell_selection_mesh(
		cell,
		start_x,
		start_z,
		end_x,
		end_z
	)


# -------------------------------------------------------------------
# Empty Cell Selection
# -------------------------------------------------------------------

# Empty cells receive a complete 12-edge cube:
#
# - four top edges;
# - four bottom edges;
# - four vertical edges.

func build_empty_cell_selection_mesh(
	start_x: int,
	start_z: int,
	end_x: int,
	end_z: int
) -> ArrayMesh:
	var surface_tool: SurfaceTool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var top_offset: Vector3 = Vector3(
		0.0,
		surface_offset,
		0.0
	)

	# Top edges.
	add_top_x_edge(
		surface_tool,
		start_x,
		end_x,
		start_z,
		top_offset,
		0.11
	)

	add_top_z_edge(
		surface_tool,
		start_z,
		end_z,
		end_x,
		top_offset,
		0.29
	)

	add_top_x_edge(
		surface_tool,
		end_x,
		start_x,
		end_z,
		top_offset,
		0.47
	)

	add_top_z_edge(
		surface_tool,
		end_z,
		start_z,
		start_x,
		top_offset,
		0.65
	)

	# Bottom edges.
	add_bottom_x_edge(
		surface_tool,
		start_x,
		end_x,
		start_z,
		Vector3.ZERO,
		0.83
	)

	add_bottom_z_edge(
		surface_tool,
		start_z,
		end_z,
		end_x,
		Vector3.ZERO,
		1.01
	)

	add_bottom_x_edge(
		surface_tool,
		end_x,
		start_x,
		end_z,
		Vector3.ZERO,
		1.19
	)

	add_bottom_z_edge(
		surface_tool,
		end_z,
		start_z,
		start_x,
		Vector3.ZERO,
		1.37
	)

	# Vertical edges.
	add_empty_cell_vertical_edge(
		surface_tool,
		start_x,
		start_z,
		1.55
	)

	add_empty_cell_vertical_edge(
		surface_tool,
		end_x,
		start_z,
		1.69
	)

	add_empty_cell_vertical_edge(
		surface_tool,
		end_x,
		end_z,
		1.83
	)

	add_empty_cell_vertical_edge(
		surface_tool,
		start_x,
		end_z,
		1.97
	)

	return surface_tool.commit()


# -------------------------------------------------------------------
# Solid Cell Selection
# -------------------------------------------------------------------

# Solid cells always receive their four top edges.
#
# Bottom and vertical edges are generated only where the cell has an
# exposed face beside open space.

func build_solid_cell_selection_mesh(
	cell: Vector2i,
	start_x: int,
	start_z: int,
	end_x: int,
	end_z: int
) -> ArrayMesh:
	var surface_tool: SurfaceTool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var top_offset: Vector3 = Vector3(
		0.0,
		surface_offset,
		0.0
	)

	# Top edges.
	add_top_x_edge(
		surface_tool,
		start_x,
		end_x,
		start_z,
		top_offset,
		0.11
	)

	add_top_z_edge(
		surface_tool,
		start_z,
		end_z,
		end_x,
		top_offset,
		0.29
	)

	add_top_x_edge(
		surface_tool,
		end_x,
		start_x,
		end_z,
		top_offset,
		0.47
	)

	add_top_z_edge(
		surface_tool,
		end_z,
		start_z,
		start_x,
		top_offset,
		0.65
	)

	var north_open: bool = generator.is_open_cell(
		Vector2i(
			cell.x,
			cell.y - 1
		)
	)

	var south_open: bool = generator.is_open_cell(
		Vector2i(
			cell.x,
			cell.y + 1
		)
	)

	var west_open: bool = generator.is_open_cell(
		Vector2i(
			cell.x - 1,
			cell.y
		)
	)

	var east_open: bool = generator.is_open_cell(
		Vector2i(
			cell.x + 1,
			cell.y
		)
	)

	var drawn_vertical_edges: Dictionary = {}

	if north_open:
		add_exposed_x_face(
			surface_tool,
			start_x,
			end_x,
			start_z,
			Vector3(
				0.0,
				0.0,
				-surface_offset
			),
			0.83,
			drawn_vertical_edges,
			"north_west",
			"north_east"
		)

	if south_open:
		add_exposed_x_face(
			surface_tool,
			start_x,
			end_x,
			end_z,
			Vector3(
				0.0,
				0.0,
				surface_offset
			),
			1.07,
			drawn_vertical_edges,
			"south_west",
			"south_east"
		)

	if west_open:
		add_exposed_z_face(
			surface_tool,
			start_z,
			end_z,
			start_x,
			Vector3(
				-surface_offset,
				0.0,
				0.0
			),
			1.31,
			drawn_vertical_edges,
			"north_west",
			"south_west"
		)

	if east_open:
		add_exposed_z_face(
			surface_tool,
			start_z,
			end_z,
			end_x,
			Vector3(
				surface_offset,
				0.0,
				0.0
			),
			1.55,
			drawn_vertical_edges,
			"north_east",
			"south_east"
		)

	return surface_tool.commit()


# -------------------------------------------------------------------
# Top Edges
# -------------------------------------------------------------------

func add_top_x_edge(
	surface_tool: SurfaceTool,
	start_x: int,
	end_x: int,
	lattice_z: int,
	offset: Vector3,
	edge_seed: float
) -> void:
	var points: PackedVector3Array = PackedVector3Array()

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

		points.append(
			generator.get_terrain_point(
				lattice_x,
				lattice_z
			) + offset
		)

	add_edge_path(
		surface_tool,
		points,
		edge_seed
	)


func add_top_z_edge(
	surface_tool: SurfaceTool,
	start_z: int,
	end_z: int,
	lattice_x: int,
	offset: Vector3,
	edge_seed: float
) -> void:
	var points: PackedVector3Array = PackedVector3Array()

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

		points.append(
			generator.get_terrain_point(
				lattice_x,
				lattice_z
			) + offset
		)

	add_edge_path(
		surface_tool,
		points,
		edge_seed
	)


# -------------------------------------------------------------------
# Exposed Faces
# -------------------------------------------------------------------

func add_exposed_x_face(
	surface_tool: SurfaceTool,
	start_x: int,
	end_x: int,
	lattice_z: int,
	offset: Vector3,
	edge_seed: float,
	drawn_vertical_edges: Dictionary,
	first_corner_name: String,
	second_corner_name: String
) -> void:
	add_bottom_x_edge(
		surface_tool,
		start_x,
		end_x,
		lattice_z,
		offset,
		edge_seed
	)

	add_vertical_edge_once(
		surface_tool,
		drawn_vertical_edges,
		first_corner_name,
		start_x,
		lattice_z,
		offset,
		edge_seed + 0.07
	)

	add_vertical_edge_once(
		surface_tool,
		drawn_vertical_edges,
		second_corner_name,
		end_x,
		lattice_z,
		offset,
		edge_seed + 0.14
	)


func add_exposed_z_face(
	surface_tool: SurfaceTool,
	start_z: int,
	end_z: int,
	lattice_x: int,
	offset: Vector3,
	edge_seed: float,
	drawn_vertical_edges: Dictionary,
	first_corner_name: String,
	second_corner_name: String
) -> void:
	add_bottom_z_edge(
		surface_tool,
		start_z,
		end_z,
		lattice_x,
		offset,
		edge_seed
	)

	add_vertical_edge_once(
		surface_tool,
		drawn_vertical_edges,
		first_corner_name,
		lattice_x,
		start_z,
		offset,
		edge_seed + 0.07
	)

	add_vertical_edge_once(
		surface_tool,
		drawn_vertical_edges,
		second_corner_name,
		lattice_x,
		end_z,
		offset,
		edge_seed + 0.14
	)


# -------------------------------------------------------------------
# Bottom Edges
# -------------------------------------------------------------------

func add_bottom_x_edge(
	surface_tool: SurfaceTool,
	start_x: int,
	end_x: int,
	lattice_z: int,
	offset: Vector3,
	edge_seed: float
) -> void:
	var points: PackedVector3Array = PackedVector3Array()

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
				generator.floor_y
					+ bottom_clearance,
				terrain_point.z
			) + offset
		)

	add_edge_path(
		surface_tool,
		points,
		edge_seed
	)


func add_bottom_z_edge(
	surface_tool: SurfaceTool,
	start_z: int,
	end_z: int,
	lattice_x: int,
	offset: Vector3,
	edge_seed: float
) -> void:
	var points: PackedVector3Array = PackedVector3Array()

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
				generator.floor_y
					+ bottom_clearance,
				terrain_point.z
			) + offset
		)

	add_edge_path(
		surface_tool,
		points,
		edge_seed
	)


# -------------------------------------------------------------------
# Vertical Edges
# -------------------------------------------------------------------

func add_empty_cell_vertical_edge(
	surface_tool: SurfaceTool,
	lattice_x: int,
	lattice_z: int,
	edge_seed: float
) -> void:
	var terrain_point: Vector3 = (
		generator.get_terrain_point(
			lattice_x,
			lattice_z
		)
	)

	var top_point: Vector3 = Vector3(
		terrain_point.x,
		terrain_point.y + surface_offset,
		terrain_point.z
	)

	var bottom_point: Vector3 = Vector3(
		terrain_point.x,
		generator.floor_y + bottom_clearance,
		terrain_point.z
	)

	var points: PackedVector3Array = PackedVector3Array(
		[
			top_point,
			bottom_point
		]
	)

	add_edge_path(
		surface_tool,
		points,
		edge_seed
	)


func add_vertical_edge_once(
	surface_tool: SurfaceTool,
	drawn_edges: Dictionary,
	edge_name: String,
	lattice_x: int,
	lattice_z: int,
	offset: Vector3,
	edge_seed: float
) -> void:
	if drawn_edges.has(edge_name):
		return

	drawn_edges[edge_name] = true

	var terrain_point: Vector3 = (
		generator.get_terrain_point(
			lattice_x,
			lattice_z
		)
	)

	var top_point: Vector3 = (
		terrain_point
		+ Vector3.UP * surface_offset
		+ offset
	)

	var bottom_point: Vector3 = Vector3(
		top_point.x,
		generator.floor_y + bottom_clearance,
		top_point.z
	)

	var points: PackedVector3Array = PackedVector3Array(
		[
			top_point,
			bottom_point
		]
	)

	add_edge_path(
		surface_tool,
		points,
		edge_seed
	)


# -------------------------------------------------------------------
# Edge Paths
# -------------------------------------------------------------------

# Converts a sequence of terrain points into individual edge segments.
#
# UV.x remains continuous from zero to one along the entire path. This
# allows shader stars to move smoothly across subdivision boundaries.

func add_edge_path(
	surface_tool: SurfaceTool,
	points: PackedVector3Array,
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
		var point_a: Vector3 = points[
			segment_index
		]

		var point_b: Vector3 = points[
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

		add_edge_segment(
			surface_tool,
			point_a,
			point_b,
			edge_seed,
			uv_start,
			uv_end
		)

		travelled_length += segment_length


# -------------------------------------------------------------------
# Crossed Edge Segments
# -------------------------------------------------------------------

# Every edge uses two perpendicular ribbons.
#
# This gives the line a cross-shaped profile and prevents it from
# disappearing when viewed from different angles.

func add_edge_segment(
	surface_tool: SurfaceTool,
	start_point: Vector3,
	end_point: Vector3,
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

	# A vertical edge is parallel to Vector3.UP, so that cross product
	# is zero. Use Vector3.RIGHT as a fallback reference axis.
	if first_side.length_squared() < 0.0001:
		first_side = edge_direction.cross(
			Vector3.RIGHT
		).normalized()

	if first_side.length_squared() < 0.0001:
		return

	var second_side: Vector3 = edge_direction.cross(
		first_side
	).normalized()

	add_edge_ribbon(
		surface_tool,
		start_point,
		end_point,
		first_side,
		edge_seed,
		uv_start,
		uv_end
	)

	add_edge_ribbon(
		surface_tool,
		start_point,
		end_point,
		second_side,
		edge_seed,
		uv_start,
		uv_end
	)


# -------------------------------------------------------------------
# Ribbon Geometry
# -------------------------------------------------------------------

func add_edge_ribbon(
	surface_tool: SurfaceTool,
	start_point: Vector3,
	end_point: Vector3,
	side_direction: Vector3,
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
	add_edge_vertex(
		surface_tool,
		start_left,
		Vector2(uv_start, 0.0),
		edge_seed
	)

	add_edge_vertex(
		surface_tool,
		end_left,
		Vector2(uv_end, 0.0),
		edge_seed
	)

	add_edge_vertex(
		surface_tool,
		start_right,
		Vector2(uv_start, 1.0),
		edge_seed
	)

	# Second triangle.
	add_edge_vertex(
		surface_tool,
		start_right,
		Vector2(uv_start, 1.0),
		edge_seed
	)

	add_edge_vertex(
		surface_tool,
		end_left,
		Vector2(uv_end, 0.0),
		edge_seed
	)

	add_edge_vertex(
		surface_tool,
		end_right,
		Vector2(uv_end, 1.0),
		edge_seed
	)


# -------------------------------------------------------------------
# Vertex Data
# -------------------------------------------------------------------

func add_edge_vertex(
	surface_tool: SurfaceTool,
	vertex_position: Vector3,
	uv: Vector2,
	edge_seed: float
) -> void:
	surface_tool.set_uv(uv)

	# UV2.y carries the stable logical-edge seed into the shader.
	#
	# Both crossed ribbons receive the same seed and UV range, so they
	# display the same moving star list.
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
