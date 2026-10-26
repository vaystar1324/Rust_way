## A first-person character controller with camera controls, movement, sprinting, and jumping.
## Requires a CameraPivot (Node3D) and Camera3D as children, and a character mesh as a child node.
extends CharacterBody3D




enum CameraMode {
	FIRST_PERSON,
	THIRD_PERSON
}

## Node References
## -----------------------------------------------------------------------------
## These nodes must exist in the scene tree for the controller to work properly.

@onready var camera_pivot: Node3D = %CameraPivot
@onready var camera_3d: Camera3D = %Camera3D
@onready var spring_arm: SpringArm3D = camera_pivot.get_node("SpringArm3D")
@onready var character: Node3D = $character
@onready var raycast: RayCast3D = $RayCast3D
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var hand: Marker3D = $RayCast3D/Marker3D
@onready var voxel_terrain: VoxelLodTerrain = $"../VoxelLodTerrain"

## Movement Settings
## -----------------------------------------------------------------------------
## Configure the character's movement speed and jump behavior.

@export_group("Movement")
@export_range(0.1, 20.0, 0.1, "or_greater") var speed: float = 5.0
## Speed when walking. Should be lower than normal speed.
@export_range(0.1, 10.0, 0.1, "or_greater") var walk_speed: float = 2.5
## Speed multiplier when sprinting. Should be higher than normal speed.
@export_range(0.1, 30.0, 0.1, "or_greater") var sprint_speed: float = 8.0
## Vertical velocity applied when jumping.
@export_range(1.0, 20.0, 0.1) var jump_velocity: float = 4.5
@export var can_walk: bool = true

## Camera Settings
## -----------------------------------------------------------------------------
## Adjust camera sensitivity and rotation limits.

@export_group("Camera")
## Mouse sensitivity for camera rotation. Higher values = faster rotation.
@export_range(0.0, 1.0, 0.001) var mouse_sensitivity: float = 0.005
## Enable controller support for camera look.
@export var controller_support: bool = true
## Controller stick sensitivity for camera rotation.
@export_range(0.1, 10.0, 0.1) var controller_sensitivity: float = 2.0
## Maximum vertical camera tilt angle in radians (prevents over-rotation).
@export_range(0.0, 1.57, 0.01) var tilt_limit: float = deg_to_rad(75)
## Speed at which the character mesh rotates to face movement direction.
@export_range(0.1, 50.0, 0.1) var rotation_speed: float = 10.0
## Camera mode: FIRST_PERSON or THIRD_PERSON.
@export var camera_mode: CameraMode = CameraMode.THIRD_PERSON:
	set(value):
		camera_mode = value
		if is_node_ready():
			_update_camera_mode()
## Camera distance (SpringArm length) for third-person mode.
@export_range(0.0, 10.0, 0.1) var camera_distance: float = 3.5
## Speed at which the camera transitions between modes.
@export_range(1.0, 20.0, 0.1) var camera_transition_speed: float = 8.0
## Allow switching between camera modes with V key.
@export var allow_camera_mode_switch: bool = false


@export var grab_distance: float = 2
@export var min_hold_distance: float = 1
@export var max_hold_distance: float = 2
@export var throw_force: float = 200

# Пружина позиции
@export var stiffness: float = 500.0
@export var damping: float = 15.0
@export var max_force: float = 900.0

# Пружина вращения
@export var angular_stiffness: float = 55.0
@export var angular_damping: float = 12.0

# Чувствительность управления
@export var distance_speed: float = 2          # скорость приближения/отдаления

var held_object: RigidBody3D = null
var is_holding := false

var current_hold_distance: float = 2.3
var target_rotation: Basis = Basis.IDENTITY     # целевой поворот объекта



var input_dir: Vector2 = Vector2.ZERO
var input_strength: float = 0.0
var direction: Vector3 = Vector3.ZERO
var is_sprinting: bool = false
var is_walking: bool = false
var is_jumping: bool = false
var shift: bool = false
var shift_speed = 0.5
# Freeze the character. It may be useful when you want to pause the character.
var frozen: bool = false

var target_camera_distance: float = 3.5
var is_transitioning_camera: bool = false
var rotate_obj: bool = false

var is_moving

func _ready() -> void:
	## Captures the mouse cursor for first-person camera control.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	target_camera_distance = 0.0 if camera_mode == CameraMode.FIRST_PERSON else camera_distance
	spring_arm.spring_length = target_camera_distance
	if character:
		character.visible = camera_mode == CameraMode.THIRD_PERSON

	raycast.target_position = Vector3(0, 0, -grab_distance)
	if not hand:
		hand = Marker3D.new()
		camera_3d.add_child(hand)
	current_hold_distance = 2.3
	_update_hand_position()


func _physics_process(delta: float) -> void:
	_handle_gravity_and_jump(delta)
	_handle_camera_transition(delta)
	_handle_controller_camera(delta)

	if frozen:
		handle_frozen_movement()
		move_and_slide()
		return

	_handle_movement_input()
	if camera_mode == CameraMode.THIRD_PERSON:
		_handle_character_rotation(delta)
	_apply_movement()
	move_and_slide()
	
	if is_holding and is_instance_valid(held_object):
		_hold_object(delta)
		_handle_rotation(delta)

func handle_frozen_movement() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	input_dir = Vector2.ZERO
	is_sprinting = false
	is_walking = false

## Handles gravity application and jump mechanics.
func _handle_gravity_and_jump(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
		is_jumping = velocity.y > 0
	else:
		is_jumping = false

	if not frozen and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		is_jumping = true

## Processes movement input and calculates movement direction relative to camera.
func _handle_movement_input() -> void:
	input_dir = Input.get_vector("left", "right", "forward", "backward")
	input_strength = minf(input_dir.length(), 1.0)
	
	var camera_basis = Transform3D(Basis(Vector3.UP, camera_pivot.rotation.y), Vector3.ZERO).basis
	direction = (camera_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

## Rotates the character mesh to face the movement direction smoothly.
func _handle_character_rotation(delta: float) -> void:
	if camera_mode == CameraMode.FIRST_PERSON:
		return
	character.rotation.y = lerp_angle(character.rotation.y, camera_pivot.rotation.y + PI, rotation_speed * delta)

## Handles controller stick input for camera rotation.
func _handle_controller_camera(delta: float) -> void:
	if not controller_support or frozen:
		return
	if not InputMap.has_action("look_left") or not InputMap.has_action("look_right") or not InputMap.has_action("look_up") or not InputMap.has_action("look_down"):
		return
	var look_dir = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look_dir != Vector2.ZERO:
		camera_pivot.rotation.y -= look_dir.x * controller_sensitivity * delta
		camera_pivot.rotation.x += look_dir.y * controller_sensitivity * delta
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, -tilt_limit, tilt_limit)

		raycast.rotation.y -= look_dir.x * controller_sensitivity * delta
		raycast.rotation.x += look_dir.y * controller_sensitivity * delta
		raycast.rotation.x = clampf(camera_pivot.rotation.x, -tilt_limit, tilt_limit)

## Handles smooth camera transition between modes.
func _handle_camera_transition(delta: float) -> void:
	spring_arm.spring_length = lerp(spring_arm.spring_length, target_camera_distance, camera_transition_speed * delta)
	
	if character and camera_distance > 0.0:
		var transition_progress = spring_arm.spring_length / camera_distance
		var visibility_threshold = 0.3
		character.visible = transition_progress > visibility_threshold
	elif character:
		character.visible = camera_mode == CameraMode.THIRD_PERSON

## Updates camera mode (sets target for smooth transition).
func _update_camera_mode() -> void:
	if camera_mode == CameraMode.FIRST_PERSON:
		target_camera_distance = 0.0
	else:
		target_camera_distance = camera_distance

## Applies horizontal movement velocity based on input and sprint/walk state.
func _apply_movement() -> void:
	is_moving = input_dir != Vector2.ZERO and is_on_floor()
	is_sprinting = Input.is_action_pressed("sprint") and is_moving and not Input.is_action_pressed("walk") and not shift
	is_walking = Input.is_action_pressed("walk") and is_moving and not Input.is_action_pressed("sprint") and can_walk and not shift

	var current_speed: float
	if is_sprinting:
		current_speed = sprint_speed
	elif is_walking and can_walk:
		current_speed = walk_speed
	elif shift:
		current_speed = shift_speed
	else:
		current_speed = speed

	if direction:
		velocity.x = direction.x * current_speed * input_strength
		velocity.z = direction.z * current_speed * input_strength
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)

## Handles mouse input for camera rotation with tilt limits.
func _unhandled_input(event: InputEvent) -> void:
	if frozen:
		return

	if event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
	if event.is_action_pressed("shift"):
		shift = not shift
		set_crouch_height(shift)


	if event is InputEventMouseMotion:
		if not rotate_obj:
			camera_pivot.rotation.x -= event.relative.y * mouse_sensitivity
			camera_pivot.rotation.x = clampf(camera_pivot.rotation.x, -tilt_limit, tilt_limit)
			camera_pivot.rotation.y += -event.relative.x * mouse_sensitivity
				
			raycast.rotation.x -= event.relative.y * mouse_sensitivity
			raycast.rotation.x = clampf(camera_pivot.rotation.x, -tilt_limit, tilt_limit)
			raycast.rotation.y += -event.relative.x * mouse_sensitivity

	if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
				current_hold_distance = clamp(current_hold_distance - 0.3, min_hold_distance, max_hold_distance)
				_update_hand_position()
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
				current_hold_distance = clamp(current_hold_distance + 0.3, min_hold_distance, max_hold_distance)
				_update_hand_position()

	if event.is_action_pressed("grab"):
			if is_holding:
				release_object()
			else:
				if raycast.get_collider() is RigidBody3D:
					try_grab()
	
	if not is_holding or not is_instance_valid(held_object):
		return

func _input(event: InputEvent) -> void:
	if InputMap.has_action("camera_mode_switch") and event.is_action_pressed("camera_mode_switch") and allow_camera_mode_switch:
		camera_mode = CameraMode.THIRD_PERSON if camera_mode == CameraMode.FIRST_PERSON else CameraMode.FIRST_PERSON
		_update_camera_mode()

func set_crouch_height(crouching: bool) -> void:
	var capsule := collision.shape as CapsuleShape3D
	if capsule == null:
		return

	if crouching:
		capsule.height = 1.0
		collision.position.y = -0.318
		camera_pivot.position.y -= 0.4
		raycast.position.y -= 0.4
	else:
		capsule.height = 1.799
		collision.position.y = 0.082
		camera_pivot.position.y += 0.4
		raycast.position.y += 0.4

func _update_hand_position():
	hand.position = Vector3(0.0, -0.15, -current_hold_distance)

func try_grab():
	raycast.force_raycast_update()
	if not raycast.is_colliding():
		return
	
	var collider = raycast.get_collider()
	if collider is RigidBody3D and not collider.freeze:
		held_object = collider
		is_holding = true
		
		# Запоминаем текущий поворот объекта как стартовый
		target_rotation = held_object.global_transform.basis
		
		# Немного гасим скорость
		held_object.linear_velocity *= 0.35
		held_object.angular_velocity *= 0.35
	
	held_object.angular_damp = 5.0
	held_object.linear_damp = 3.0

func _hold_object(delta: float):
	if not is_instance_valid(held_object):
		return
	
	# ---------- Позиция (пружина) ----------
	var target_pos = hand.global_position
	var to_target = target_pos - held_object.global_position
	var force = to_target * stiffness - held_object.linear_velocity * damping
	
	if force.length() > max_force:
		force = force.normalized() * max_force
	
	held_object.apply_central_force(force)
	
	# ---------- Вращение (стабильный способ) ----------
	_apply_stable_rotation(delta)

func _apply_stable_rotation(delta: float):
	if not is_instance_valid(held_object):
		return

	var q_current = held_object.global_transform.basis.get_rotation_quaternion()
	var q_target  = target_rotation.get_rotation_quaternion()

	# Разница кватернионов (самый короткий путь)
	var q_diff = q_target * q_current.inverse()
	if q_diff.w < 0.0:
		q_diff = -q_diff

	# Угол
	var angle = 2.0 * acos(clampf(q_diff.w, -1.0, 1.0))

	# Если уже почти совпали — просто гасим скорость
	if angle < 0.008:          # ~0.5 градуса
		held_object.angular_velocity = held_object.angular_velocity.lerp(Vector3.ZERO, 18.0 * delta)
		return

	# Ось вращения
	var axis = Vector3(q_diff.x, q_diff.y, q_diff.z)
	if axis.length_squared() < 0.000001:
		held_object.angular_velocity = held_object.angular_velocity.lerp(Vector3.ZERO, 18.0 * delta)
		return

	axis = axis.normalized()

	# Желаемая угловая скорость
	var desired_ang_vel = axis * (angle * angular_stiffness)
	desired_ang_vel = desired_ang_vel.limit_length(10.0)   # жёсткий лимит

	# === САМОЕ ВАЖНОЕ ===
	# Не используем torque! Напрямую управляем angular_velocity
	held_object.angular_velocity = held_object.angular_velocity.lerp(
		desired_ang_vel, 
		clampf(angular_damping * delta, 0.0, 1.0)
	)

func _get_torque_to_target(current: Basis, target: Basis) -> Vector3:
	var q = (target * current.inverse()).get_rotation_quaternion()
	var angle = q.get_angle()
	if angle > PI:
		angle -= TAU
	if abs(angle) < 0.001:
		return Vector3.ZERO
	return q.get_axis() * angle

func release_object():
	if not is_instance_valid(held_object):
		is_holding = false
		held_object = null
		return
		
	if Input.is_key_pressed(KEY_Q):
		var throw_dir = -camera_3d.global_transform.basis.z
		held_object.apply_central_impulse(throw_dir * throw_force)
	
		held_object.angular_damp = 0.5
		held_object.linear_damp = 0.5
	
	held_object = null
	is_holding = false


func _handle_rotation(delta: float):
	if not is_holding or not is_instance_valid(held_object):
		return

	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		rotate_obj = false
		return
	rotate_obj = true
	var mouse_vel = Input.get_last_mouse_velocity()
	if mouse_vel.length() < 0.5:
		return

	var cam_basis = camera_3d.global_transform.basis

	# Скорость вращения (подстрой под себя)
	var yaw   = -mouse_vel.x * mouse_sensitivity * 0.015   # горизонталь
	var pitch = -mouse_vel.y * mouse_sensitivity * 0.015   # вертикаль

	# === Главное: обновляем целевой поворот ===
	# Вращаем target_rotation относительно осей камеры
	target_rotation = target_rotation.rotated(cam_basis.y, yaw)
	target_rotation = target_rotation.rotated(cam_basis.x, pitch)

	# Нормализуем базис (защита от накопления ошибок)
	target_rotation = target_rotation.orthonormalized()



func shoot_ray_and_dig():
	# 1. Получаем координаты клика или центра экрана (здесь упрощенно)
	# Предположим, вы использовали RayCast3D и получили точку столкновения:
	var hit_position = raycast.get_collision_point() - Vector3(0, 15, 0)
	
	# 2. Получаем VoxelTool, привязанный к вашему террейну
	var vt = voxel_terrain.get_voxel_tool()
	
	# 3. Настраиваем кисть
	vt.channel = VoxelBuffer.CHANNEL_SDF
	vt.mode = VoxelTool.MODE_REMOVE
	vt.value = 1.0 # Явно указываем силу/значение удаления (воздух)
	
	# 4. Применяем форму (например, сферу радиусом 4 единицы)
	var radius = 1.0
	var bounds = AABB(hit_position - Vector3(radius, radius, radius), Vector3(radius * 2, radius * 2, radius * 2))
	if vt.is_area_editable(bounds):
		vt.do_sphere(hit_position, radius)
		print(hit_position)
	else:
		print("Область еще не загружена или недоступна для редактирования!")
