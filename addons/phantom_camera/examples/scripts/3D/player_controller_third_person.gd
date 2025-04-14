extends "player_controller.gd"

@onready var _player_pcam: PhantomCamera3D
@onready var _aim_pcam: PhantomCamera3D
@onready var _player_direction: Node3D = %PlayerDirection
@onready var _ceiling_pcam: PhantomCamera3D

@export var mouse_sensitivity: float = 0.05

@export var min_pitch: float = -89.9
@export var max_pitch: float = 50

@export var min_yaw: float = 0
@export var max_yaw: float = 360

@export var speed: float = 5.0
@export var jump_velocity: float = 4.5

func _ready() -> void:
	super()

	_player_pcam = owner.get_node("%PlayerPhantomCamera3D")
	_aim_pcam = owner.get_node("%PlayerAimPhantomCamera3D")
	_ceiling_pcam = owner.get_node("%CeilingPhantomCamera3D")

	if _player_pcam.get_follow_mode() == _player_pcam.FollowMode.THIRD_PERSON:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta: float) -> void:
	super(delta)

	if velocity.length() > 0.2:
		var look_direction: Vector2 = Vector2(velocity.z, velocity.x)
		_player_direction.rotation.y = look_direction.angle()

	velocity.x = 0
	velocity.z = 0


	var input_dir: Vector3 = Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1
	if Input.is_action_pressed("move_backward"):
		input_dir.z += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1

   
	if input_dir.length() > 0:
		input_dir = input_dir.normalized() * speed

	# Apply movement in the global space
	velocity.x = input_dir.x
	velocity.z = input_dir.z

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jumping
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Move the character
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if _player_pcam.get_follow_mode() == _player_pcam.FollowMode.THIRD_PERSON:
		var active_pcam: PhantomCamera3D

		_set_pcam_rotation(_player_pcam, event)
		_set_pcam_rotation(_aim_pcam, event)
		if _player_pcam.get_priority() > _aim_pcam.get_priority():
			_toggle_aim_pcam(event)
		else:
			_toggle_aim_pcam(event)

		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_SPACE:
				if _ceiling_pcam.get_priority() < 30 and _player_pcam.is_active():
					_ceiling_pcam.set_priority(30)
				else:
					_ceiling_pcam.set_priority(1)


func _set_pcam_rotation(pcam: PhantomCamera3D, event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var pcam_rotation_degrees: Vector3

		# Assigns the current 3D rotation of the SpringArm3D node - so it starts off where it is in the editor
		pcam_rotation_degrees = pcam.get_third_person_rotation_degrees()

		# Change the X rotation
		pcam_rotation_degrees.x -= event.relative.y * mouse_sensitivity

		# Clamp the rotation in the X axis so it go over or under the target
		pcam_rotation_degrees.x = clampf(pcam_rotation_degrees.x, min_pitch, max_pitch)

		# Change the Y rotation value
		pcam_rotation_degrees.y -= event.relative.x * mouse_sensitivity

		# Sets the rotation to fully loop around its target, but witout going below or exceeding 0 and 360 degrees respectively
		pcam_rotation_degrees.y = wrapf(pcam_rotation_degrees.y, min_yaw, max_yaw)

		# Change the SpringArm3D node's rotation and rotate around its target
		pcam.set_third_person_rotation_degrees(pcam_rotation_degrees)


func _toggle_aim_pcam(event: InputEvent) -> void:
	if event is InputEventMouseButton \
		and event.is_pressed() \
		and event.button_index == 2 \
		and (_player_pcam.is_active() or _aim_pcam.is_active()):
		if _player_pcam.get_priority() > _aim_pcam.get_priority():
			_aim_pcam.set_priority(30)
		else:
			_aim_pcam.set_priority(0)
