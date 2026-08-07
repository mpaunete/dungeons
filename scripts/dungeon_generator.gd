class_name DungeonGenerator
extends Node

# Generates and describes the dungeon terrain.
#
# Owns the dungeon layout, terrain settings and mesh generation.


# -------------------------------------------------------------------
# Map layout
# -------------------------------------------------------------------

@export_category("Map Layout")

@export_range(0.1, 10.0, 0.1)
var cell_size: float = 1.0

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

var map_half_width: float:
	get:
		if dungeon_map == null:
			return 0.0

		return (
			float(dungeon_map.width)
			* cell_size
			* 0.5
		)


var map_half_depth: float:
	get:
		if dungeon_map == null:
			return 0.0

		return (
			float(dungeon_map.height)
			* cell_size
			* 0.5
		)


var terrain_top_y: float:
	get:
		return cell_size * 0.5


var floor_y: float:
	get:
		return -cell_size * 0.5


# -------------------------------------------------------------------
# Dependencies
# -------------------------------------------------------------------

var dungeon_map: DungeonMap


# -------------------------------------------------------------------
# Initialization
# -------------------------------------------------------------------

func initialize(
	new_dungeon_map: DungeonMap
) -> void:
	if new_dungeon_map == null:
		push_error(
			"DungeonGenerator: DungeonMap dependency is missing."
		)
		return

	if not new_dungeon_map.is_loaded:
		push_error(
			"DungeonGenerator: DungeonMap has not been loaded."
		)
		return

	dungeon_map = new_dungeon_map

	validate_settings()
	create_noise_generators()
	create_materials()


# -------------------------------------------------------------------
# Validation
# -------------------------------------------------------------------

func validate_settings() -> void:
	cell_size = maxf(
		cell_size,
		0.01
	)

	subdivisions = maxi(
		subdivisions,
		1
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
	terrain_material.vertex_color_use_as_albedo = true
	terrain_material.albedo_color = Color.WHITE
	terrain_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	terrain_material.roughness = 1.0
	terrain_material.metallic = 0.0
	terrain_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	floor_material = StandardMaterial3D.new()
	floor_material.vertex_color_use_as_albedo = true
	floor_material.albedo_color = Color.WHITE
	floor_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	floor_material.roughness = 1.0
	floor_material.metallic = 0.0
	floor_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED


## -------------------------------------------------------------------
# Map Queries
# -------------------------------------------------------------------

# Returns true when the cell coordinate exists inside the loaded map.
func is_valid_map_cell(
	cell: Vector2i
) -> bool:
	if dungeon_map == null:
		return false

	return dungeon_map.is_valid_cell(
		cell
	)


# Returns true when a valid map cell contains open terrain.
func is_hole(
	cell: Vector2i
) -> bool:
	if dungeon_map == null:
		return false

	if not dungeon_map.is_valid_cell(
		cell
	):
		return false

	return dungeon_map.is_open(
		cell
	)


# Returns true when a cell contains open space.
#
# Space beyond the map boundary is treated as open so exposed outer
# faces can still be generated.
func is_open_cell(
	cell: Vector2i
) -> bool:
	if not is_valid_map_cell(cell):
		return true

	return dungeon_map.is_open(
		cell
	)


# Converts a Dungeon-local 3D position into a logical map cell.
func local_position_to_cell(
	local_position: Vector3
) -> Vector2i:
	var cell_x: int = floori(
		(local_position.x + map_half_width)
		/ cell_size
	)

	var cell_z: int = floori(
		(local_position.z + map_half_depth)
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
		- map_half_width
	)

	var world_z: float = (
		float(lattice_z)
		/ subdivisions_float
		* cell_size
		- map_half_depth
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
	surface_tool.set_smooth_group(-1)

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
	for cell_x: int in range(dungeon_map.width):
		for cell_z: int in range(dungeon_map.height):
			var cell: Vector2i = Vector2i(
				cell_x,
				cell_z
			)

			if is_hole(cell):
				continue

			create_cell_top(
				surface_tool,
				cell
			)


func create_cell_top(
	surface_tool: SurfaceTool,
	cell: Vector2i
) -> void:
	var cell_color: Color = dungeon_map.get_debug_color(
		cell
	)

	var cell_x: int = cell.x
	var cell_z: int = cell.y

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
				point_10,
				cell_color
			)

			add_triangle(
				surface_tool,
				point_10,
				point_01,
				point_11,
				cell_color
			)


# -------------------------------------------------------------------
# Excavated Walls
# -------------------------------------------------------------------

func create_hole_walls(
	surface_tool: SurfaceTool
) -> void:
	for cell_x: int in range(
		dungeon_map.width
	):
		for cell_z: int in range(
			dungeon_map.height
		):
			var cell: Vector2i = Vector2i(
				cell_x,
				cell_z
			)

			if not is_hole(cell):
				continue

			var north_cell: Vector2i = Vector2i(
				cell_x,
				cell_z - 1
			)

			var south_cell: Vector2i = Vector2i(
				cell_x,
				cell_z + 1
			)

			var west_cell: Vector2i = Vector2i(
				cell_x - 1,
				cell_z
			)

			var east_cell: Vector2i = Vector2i(
				cell_x + 1,
				cell_z
			)

			# North wall.
			if (
				is_valid_map_cell(north_cell)
				and not is_hole(north_cell)
			):
				create_horizontal_wall(
					surface_tool,
					cell_x,
					cell_z,
					dungeon_map.get_debug_color(
						north_cell
					)
				)

			# South wall.
			if (
				is_valid_map_cell(south_cell)
				and not is_hole(south_cell)
			):
				create_horizontal_wall(
					surface_tool,
					cell_x,
					cell_z + 1,
					dungeon_map.get_debug_color(
						south_cell
					)
				)

			# West wall.
			if (
				is_valid_map_cell(west_cell)
				and not is_hole(west_cell)
			):
				create_vertical_wall(
					surface_tool,
					cell_x,
					cell_z,
					dungeon_map.get_debug_color(
						west_cell
					)
				)

			# East wall.
			if (
				is_valid_map_cell(east_cell)
				and not is_hole(east_cell)
			):
				create_vertical_wall(
					surface_tool,
					cell_x + 1,
					cell_z,
					dungeon_map.get_debug_color(
						east_cell
					)
				)


func create_horizontal_wall(
	surface_tool: SurfaceTool,
	cell_x: int,
	boundary_z: int,
	color: Color
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
			bottom_right,
			color
		)


func create_vertical_wall(
	surface_tool: SurfaceTool,
	boundary_x: int,
	cell_z: int,
	color: Color
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
			bottom_right,
			color
		)


# -------------------------------------------------------------------
# Floor Mesh Generation
# -------------------------------------------------------------------

func build_floor_mesh() -> ArrayMesh:
	var surface_tool: SurfaceTool = SurfaceTool.new()
	surface_tool.begin(
		Mesh.PRIMITIVE_TRIANGLES
	)

	for cell_y: int in range(
		dungeon_map.height
	):
		for cell_x: int in range(
			dungeon_map.width
		):
			var cell: Vector2i = Vector2i(
				cell_x,
				cell_y
			)

			if not dungeon_map.is_open(cell):
				continue

			_add_floor_cell(
				surface_tool,
				cell
			)

	surface_tool.generate_normals()

	var generated_mesh: ArrayMesh = (
		surface_tool.commit()
	)

	generated_mesh.surface_set_material(
		0,
		floor_material
	)

	return generated_mesh


func _add_floor_cell(
	surface_tool: SurfaceTool,
	cell: Vector2i
) -> void:
	var minimum_x: float = (
		float(cell.x) * cell_size
		- map_half_width
	)

	var minimum_z: float = (
		float(cell.y) * cell_size
		- map_half_depth
	)

	var maximum_x: float = (
		minimum_x + cell_size
	)

	var maximum_z: float = (
		minimum_z + cell_size
	)

	var north_west: Vector3 = Vector3(
		minimum_x,
		floor_y,
		minimum_z
	)

	var north_east: Vector3 = Vector3(
		maximum_x,
		floor_y,
		minimum_z
	)

	var south_west: Vector3 = Vector3(
		minimum_x,
		floor_y,
		maximum_z
	)

	var south_east: Vector3 = Vector3(
		maximum_x,
		floor_y,
		maximum_z
	)

	var cell_color: Color = dungeon_map.get_debug_color(
		cell
	)

	add_triangle(
		surface_tool,
		north_west,
		south_west,
		north_east,
		cell_color
	)

	add_triangle(
		surface_tool,
		north_east,
		south_west,
		south_east,
		cell_color
	)
	
	
# -------------------------------------------------------------------
# Mesh Helpers
# -------------------------------------------------------------------

func add_triangle(
	surface_tool: SurfaceTool,
	point_a: Vector3,
	point_b: Vector3,
	point_c: Vector3,
	color: Color
) -> void:
	surface_tool.set_color(color)
	surface_tool.add_vertex(point_a)

	surface_tool.set_color(color)
	surface_tool.add_vertex(point_b)

	surface_tool.set_color(color)
	surface_tool.add_vertex(point_c)


func add_quad(
	surface_tool: SurfaceTool,
	top_left: Vector3,
	top_right: Vector3,
	bottom_left: Vector3,
	bottom_right: Vector3,
	color: Color
) -> void:
	add_triangle(
		surface_tool,
		top_left,
		bottom_left,
		top_right,
		color
	)

	add_triangle(
		surface_tool,
		top_right,
		bottom_left,
		bottom_right,
		color
	)
