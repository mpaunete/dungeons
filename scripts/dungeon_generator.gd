class_name DungeonGenerator
extends Node

# Generates and describes the dungeon terrain.
#
# Owns the dungeon layout, terrain settings and mesh generation.


# -------------------------------------------------------------------
# Map layout
# -------------------------------------------------------------------

@export_category("Map Layout")

@export_range(1, 128, 1)
var map_size: int = 21

@export_range(0.1, 10.0, 0.1)
var cell_size: float = 1.0

@export_range(0, 20, 1)
var starting_area_radius: int = 2

@export_range(1, 16, 1)
var subdivisions: int = 5


# -------------------------------------------------------------------
# Terrain shape
# -------------------------------------------------------------------

@export_category("Terrain Shape")

@export var noise_seed: int = 12345

@export_range(0.0, 0.15, 0.005)
var horizontal_noise_strength: float = 0.055

@export_range(0.0, 0.15, 0.005)
var vertical_noise_strength: float = 0.035

@export_range(0.001, 0.5, 0.005)
var noise_frequency: float = 0.08


# -------------------------------------------------------------------
# Scene references
# -------------------------------------------------------------------

# These references point to the meshes owned by the parent Dungeon node.
@onready var terrain_instance: MeshInstance3D = $"../Terrain"
@onready var floor_instance: MeshInstance3D = $"../Floor"


# -------------------------------------------------------------------
# Noise Sources
# -------------------------------------------------------------------

var noise_x: FastNoiseLite
var noise_y: FastNoiseLite
var noise_z: FastNoiseLite


# -------------------------------------------------------------------
# Materials
# -------------------------------------------------------------------

var terrain_material: StandardMaterial3D
var floor_material: StandardMaterial3D


# -------------------------------------------------------------------
# Derived Properties
# -------------------------------------------------------------------

var map_half_size: float:
	get:
		return float(map_size) * cell_size * 0.5


var terrain_top_y: float:
	get:
		return cell_size * 0.5


var floor_y: float:
	get:
		return -cell_size * 0.5


# -------------------------------------------------------------------
# Initialization
# -------------------------------------------------------------------

func initialize() -> void:
	validate_settings()
	create_noise_generators()
	create_materials()


# -------------------------------------------------------------------
# Validation
# -------------------------------------------------------------------

func validate_settings() -> void:
	map_size = maxi(
		map_size,
		1
	)

	cell_size = maxf(
		cell_size,
		0.01
	)

	subdivisions = maxi(
		subdivisions,
		1
	)

	var maximum_starting_radius: int = (
		(map_size - 1) / 2
	)

	starting_area_radius = clampi(
		starting_area_radius,
		0,
		maximum_starting_radius
	)


# -------------------------------------------------------------------
# Noise setup
# -------------------------------------------------------------------

func create_noise_generators() -> void:
	noise_x = create_noise(
		noise_seed
	)

	noise_y = create_noise(
		noise_seed + 1000
	)

	noise_z = create_noise(
		noise_seed + 2000
	)


func create_noise(
	seed_value: int
) -> FastNoiseLite:
	var noise: FastNoiseLite = FastNoiseLite.new()

	noise.seed = seed_value
	noise.frequency = noise_frequency
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH

	return noise


# -------------------------------------------------------------------
# Material Setup
# -------------------------------------------------------------------

func create_materials() -> void:
	terrain_material = StandardMaterial3D.new()
	terrain_material.albedo_color = Color(
		0.35,
		0.18,
		0.08
	)
	terrain_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	floor_material = StandardMaterial3D.new()
	floor_material.albedo_color = Color(
		0.22,
		0.24,
		0.27
	)
	floor_material.cull_mode = BaseMaterial3D.CULL_DISABLED


# -------------------------------------------------------------------
# Map queries
# -------------------------------------------------------------------

# Returns true when the cell coordinate exists inside the map.
func is_valid_map_cell(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.x < map_size
		and cell.y >= 0
		and cell.y < map_size
	)


# Returns true when the cell belongs to the excavated starting area.
func is_hole(cell: Vector2i) -> bool:
	var centre: int = map_size / 2

	var distance_x: int = absi(
		cell.x - centre
	)

	var distance_z: int = absi(
		cell.y - centre
	)

	return (
		distance_x <= starting_area_radius
		and distance_z <= starting_area_radius
	)


# Checks whether a valid map cell is part of the starting hole.
# Cells outside the map are treated as solid.
func is_excavated_in_bounds(cell: Vector2i) -> bool:
	if not is_valid_map_cell(cell):
		return false

	return is_hole(cell)


# Returns true when a cell contains open space.
# Space beyond the map boundary is also considered open.
func is_open_cell(cell: Vector2i) -> bool:
	if not is_valid_map_cell(cell):
		return true

	return is_hole(cell)


# Converts a Dungeon-local 3D position into a logical map cell.
func local_position_to_cell(
	local_position: Vector3
) -> Vector2i:
	var cell_x: int = floori(
		(local_position.x + map_half_size)
		/ cell_size
	)

	var cell_z: int = floori(
		(local_position.z + map_half_size)
		/ cell_size
	)

	return Vector2i(
		cell_x,
		cell_z
	)


# Returns the generated Dungeon-local position of one terrain lattice point.
func get_terrain_point(
	lattice_x: int,
	lattice_z: int
) -> Vector3:
	var subdivisions_float: float = float(
		subdivisions
	)

	var world_x: float = (
		float(lattice_x)
		/ subdivisions_float
		* cell_size
		- map_half_size
	)

	var world_z: float = (
		float(lattice_z)
		/ subdivisions_float
		* cell_size
		- map_half_size
	)

	var sample_x: float = float(lattice_x)
	var sample_z: float = float(lattice_z)

	var offset_x: float = (
		noise_x.get_noise_2d(
			sample_x,
			sample_z
		)
		* horizontal_noise_strength
	)

	var offset_y: float = (
		noise_y.get_noise_2d(
			sample_x,
			sample_z
		)
		* vertical_noise_strength
	)

	var offset_z: float = (
		noise_z.get_noise_2d(
			sample_x,
			sample_z
		)
		* horizontal_noise_strength
	)

	return Vector3(
		world_x + offset_x,
		terrain_top_y + offset_y,
		world_z + offset_z
	)


# -------------------------------------------------------------------
# Level Generation
# -------------------------------------------------------------------

func generate_level() -> void:
	terrain_instance.mesh = build_terrain_mesh()
	floor_instance.mesh = build_floor_mesh()


# -------------------------------------------------------------------
# Terrain Mesh Generation
# -------------------------------------------------------------------

func build_terrain_mesh() -> ArrayMesh:
	var surface_tool: SurfaceTool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	create_top_surface(surface_tool)
	create_hole_walls(surface_tool)

	surface_tool.generate_normals()

	var generated_mesh: ArrayMesh = surface_tool.commit()

	generated_mesh.surface_set_material(
		0,
		terrain_material
	)

	return generated_mesh

# -------------------------------------------------------------------
# Terrain Top Surface
# -------------------------------------------------------------------

func create_top_surface(
	surface_tool: SurfaceTool
) -> void:
	for cell_x: int in range(map_size):
		for cell_z: int in range(map_size):
			if is_hole(
				Vector2i(
					cell_x,
					cell_z
				)
			):
				continue

			create_cell_top(
				surface_tool,
				cell_x,
				cell_z
			)


func create_cell_top(
	surface_tool: SurfaceTool,
	cell_x: int,
	cell_z: int
) -> void:
	var lattice_start_x: int = (
		cell_x * subdivisions
	)

	var lattice_start_z: int = (
		cell_z * subdivisions
	)

	for sub_x: int in range(subdivisions):
		for sub_z: int in range(subdivisions):
			var lattice_x: int = (
				lattice_start_x + sub_x
			)

			var lattice_z: int = (
				lattice_start_z + sub_z
			)

			var point_00: Vector3 = get_terrain_point(
				lattice_x,
				lattice_z
			)

			var point_10: Vector3 = get_terrain_point(
				lattice_x + 1,
				lattice_z
			)

			var point_01: Vector3 = get_terrain_point(
				lattice_x,
				lattice_z + 1
			)

			var point_11: Vector3 = get_terrain_point(
				lattice_x + 1,
				lattice_z + 1
			)

			add_triangle(
				surface_tool,
				point_00,
				point_01,
				point_10
			)

			add_triangle(
				surface_tool,
				point_10,
				point_01,
				point_11
			)


# -------------------------------------------------------------------
# Excavated Walls
# -------------------------------------------------------------------

func create_hole_walls(
	surface_tool: SurfaceTool
) -> void:
	for cell_x: int in range(map_size):
		for cell_z: int in range(map_size):
			var cell: Vector2i = Vector2i(
				cell_x,
				cell_z
			)

			if not is_hole(cell):
				continue

			if not is_excavated_in_bounds(
				Vector2i(
					cell_x,
					cell_z - 1
				)
			):
				create_horizontal_wall(
					surface_tool,
					cell_x,
					cell_z
				)

			if not is_excavated_in_bounds(
				Vector2i(
					cell_x,
					cell_z + 1
				)
			):
				create_horizontal_wall(
					surface_tool,
					cell_x,
					cell_z + 1
				)

			if not is_excavated_in_bounds(
				Vector2i(
					cell_x - 1,
					cell_z
				)
			):
				create_vertical_wall(
					surface_tool,
					cell_x,
					cell_z
				)

			if not is_excavated_in_bounds(
				Vector2i(
					cell_x + 1,
					cell_z
				)
			):
				create_vertical_wall(
					surface_tool,
					cell_x + 1,
					cell_z
				)


func create_horizontal_wall(
	surface_tool: SurfaceTool,
	cell_x: int,
	boundary_z: int
) -> void:
	var start_lattice_x: int = (
		cell_x * subdivisions
	)

	var lattice_z: int = (
		boundary_z * subdivisions
	)

	for segment: int in range(subdivisions):
		var top_left: Vector3 = get_terrain_point(
			start_lattice_x + segment,
			lattice_z
		)

		var top_right: Vector3 = get_terrain_point(
			start_lattice_x + segment + 1,
			lattice_z
		)

		var bottom_left: Vector3 = Vector3(
			top_left.x,
			floor_y,
			top_left.z
		)

		var bottom_right: Vector3 = Vector3(
			top_right.x,
			floor_y,
			top_right.z
		)

		add_quad(
			surface_tool,
			top_left,
			top_right,
			bottom_left,
			bottom_right
		)


func create_vertical_wall(
	surface_tool: SurfaceTool,
	boundary_x: int,
	cell_z: int
) -> void:
	var lattice_x: int = (
		boundary_x * subdivisions
	)

	var start_lattice_z: int = (
		cell_z * subdivisions
	)

	for segment: int in range(subdivisions):
		var top_left: Vector3 = get_terrain_point(
			lattice_x,
			start_lattice_z + segment
		)

		var top_right: Vector3 = get_terrain_point(
			lattice_x,
			start_lattice_z + segment + 1
		)

		var bottom_left: Vector3 = Vector3(
			top_left.x,
			floor_y,
			top_left.z
		)

		var bottom_right: Vector3 = Vector3(
			top_right.x,
			floor_y,
			top_right.z
		)

		add_quad(
			surface_tool,
			top_left,
			top_right,
			bottom_left,
			bottom_right
		)


# -------------------------------------------------------------------
# Floor Mesh Generation
# -------------------------------------------------------------------

func build_floor_mesh() -> ArrayMesh:
	var surface_tool: SurfaceTool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var north_west: Vector3 = Vector3(
		-map_half_size,
		floor_y,
		-map_half_size
	)

	var north_east: Vector3 = Vector3(
		map_half_size,
		floor_y,
		-map_half_size
	)

	var south_west: Vector3 = Vector3(
		-map_half_size,
		floor_y,
		map_half_size
	)

	var south_east: Vector3 = Vector3(
		map_half_size,
		floor_y,
		map_half_size
	)

	add_triangle(
		surface_tool,
		north_west,
		south_west,
		north_east
	)

	add_triangle(
		surface_tool,
		north_east,
		south_west,
		south_east
	)

	surface_tool.generate_normals()

	var generated_mesh: ArrayMesh = surface_tool.commit()

	generated_mesh.surface_set_material(
		0,
		floor_material
	)

	return generated_mesh


# -------------------------------------------------------------------
# Mesh Helpers
# -------------------------------------------------------------------

func add_triangle(
	surface_tool: SurfaceTool,
	point_a: Vector3,
	point_b: Vector3,
	point_c: Vector3
) -> void:
	surface_tool.add_vertex(point_a)
	surface_tool.add_vertex(point_b)
	surface_tool.add_vertex(point_c)


func add_quad(
	surface_tool: SurfaceTool,
	top_left: Vector3,
	top_right: Vector3,
	bottom_left: Vector3,
	bottom_right: Vector3
) -> void:
	add_triangle(
		surface_tool,
		top_left,
		bottom_left,
		top_right
	)

	add_triangle(
		surface_tool,
		top_right,
		bottom_left,
		bottom_right
	)
