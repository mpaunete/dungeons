@tool
extends Node3D

signal zoom_changed(camera_distance: float)


@export_category("View Angle")

@export_range(30.0, 75.0, 1.0)
var pitch: float = 45.0:
	set(value):
		pitch = value
		_update_camera()


@export_range(-180.0, 180.0, 1.0)
var yaw: float = 40.0:
	set(value):
		yaw = value
		_update_camera()


@export_category("Perspective")

@export_range(20.0, 80.0, 1.0)
var field_of_view: float = 40.0:
	set(value):
		field_of_view = value
		_update_camera()


@export_range(2.5, 30.0, 0.5)
var camera_distance: float = 8.0:
	set(value):
		var new_distance: float = clampf(
			value,
			minimum_distance,
			maximum_distance
		)

		if is_equal_approx(camera_distance, new_distance):
			return

		camera_distance = new_distance
		_update_camera()

		if not Engine.is_editor_hint():
			zoom_changed.emit(camera_distance)


@export_category("Zoom")

@export var minimum_distance: float = 2.5
@export var maximum_distance: float = 30.0
@export var zoom_step: float = 0.5


@export_category("Movement")

@export_range(1.0, 30.0, 0.5)
var movement_speed: float = 8.0

@export_range(1.0, 50.0, 0.5)
var movement_acceleration: float = 18.0

@export_range(1.0, 50.0, 0.5)
var movement_deceleration: float = 24.0


var movement_velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	_update_camera()

	var camera: Camera3D = get_node_or_null("Camera") as Camera3D

	if camera != null and not Engine.is_editor_hint():
		camera.current = true


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	_update_keyboard_movement(delta)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return

	if event is not InputEventMouseButton:
		return

	var mouse_event: InputEventMouseButton = (
		event as InputEventMouseButton
	)

	if not mouse_event.pressed:
		return

	match mouse_event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			camera_distance -= zoom_step

		MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance += zoom_step


func _update_keyboard_movement(delta: float) -> void:
	var input_direction: Vector2 = Input.get_vector(
		"camera_left",
		"camera_right",
		"camera_forward",
		"camera_backward"
	)

	var forward_direction: Vector3 = Vector3(
		sin(deg_to_rad(yaw)),
		0.0,
		cos(deg_to_rad(yaw))
	)

	var right_direction: Vector3 = Vector3(
		cos(deg_to_rad(yaw)),
		0.0,
		-sin(deg_to_rad(yaw))
	)

	var desired_direction: Vector3 = (
		right_direction * input_direction.x
		+ forward_direction * input_direction.y
	)

	if desired_direction.length_squared() > 0.0:
		desired_direction = desired_direction.normalized()

		var desired_velocity: Vector3 = (
			desired_direction
			* movement_speed
		)

		movement_velocity = movement_velocity.move_toward(
			desired_velocity,
			movement_acceleration * delta
		)
	else:
		movement_velocity = movement_velocity.move_toward(
			Vector3.ZERO,
			movement_deceleration * delta
		)

	global_position += movement_velocity * delta


func _update_camera() -> void:
	if not is_inside_tree():
		return

	var camera: Camera3D = get_node_or_null("Camera") as Camera3D

	if camera == null:
		return

	rotation_degrees = Vector3(
		-pitch,
		yaw,
		0.0
	)

	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = field_of_view
	camera.position = Vector3(
		0.0,
		0.0,
		camera_distance
	)
	camera.rotation = Vector3.ZERO
