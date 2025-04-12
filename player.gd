extends CharacterBody3D

@export_group("Camera")
@export_range(0.0, 1.0) var mouse_sensitivity := 0.5
@export var tilt_upper_limit := PI / 3.0
@export var tilt_lower_limit := -PI / 6.0

@export_group("Movement")
@export var move_speed := 5.0
@export var acceleration := 5.0
@export var rotation_speed := 12.0 
@export var skin_rotation_speed: float = 10.0
@export var jump_strength := 8.0
@export var gravity_strength := 12.0

var _camera_input_direction := Vector2.ZERO
# var _last_movement_direction := Vector3.BACK # No longer used

# --- Gravity Variables ---
const DEFAULT_GRAVITY_DIRECTION: Vector3 = Vector3.DOWN # Store the default
var _current_gravity_direction: Vector3 = DEFAULT_GRAVITY_DIRECTION
var _target_gravity_direction: Vector3 = DEFAULT_GRAVITY_DIRECTION # For smooth transitions
@export var gravity_change_speed: float = 10.0 # How fast gravity vector rotates

# --- Track active gravity zones ---
var _active_gravity_zones: Array[GravityZone] = []


# Flag to check if character is on a "gravity_blue" surface (optional, maybe useful later)
# var _is_on_gravity_blue: bool = false
# ---------------------------

@onready var _camera_pivot: Node3D = %CameraPivot
@onready var _camera: Camera3D = %Camera3D
@onready var _skin: Node3D = %GobotSkin


func _ready():
	# Add player to a group so zones can identify it
	add_to_group("player")

	# Find all gravity zones in the scene and connect to their signals
	var zones = get_tree().get_nodes_in_group("gravity_zone")
	print("Found %d gravity zones. Connecting signals..." % zones.size())
	for zone in zones:
		# Ensure we are connecting to the correct type and signal exists
		if zone is GravityZone:
			var err_enter = zone.player_entered_gravity_zone.connect(_on_player_entered_gravity_zone)
			var err_exit = zone.player_exited_gravity_zone.connect(_on_player_exited_gravity_zone)
			if err_enter != OK:
				printerr("Failed to connect player_entered_gravity_zone for zone: ", zone.name)
			if err_exit != OK:
				printerr("Failed to connect player_exited_gravity_zone for zone: ", zone.name)
		else:
			push_warning("Node '%s' in group 'gravity_zone' is not a GravityZone script." % zone.name)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("left_click"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# --- Removed Manual Gravity Change Input ---


func _unhandled_input(event: InputEvent) -> void:
	var is_camera_motion := (
		event is InputEventMouseMotion
		and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	)
	if is_camera_motion:
		_camera_input_direction = event.screen_relative * mouse_sensitivity


func _physics_process(delta: float) -> void:
	# --- Smoothly Lerp Gravity Direction ---
	var current_gravity_normal = _current_gravity_direction.normalized() # Get current gravity
	if not _current_gravity_direction.is_equal_approx(_target_gravity_direction):
		var angle_between = _current_gravity_direction.angle_to(_target_gravity_direction)
		var rotation_axis = _current_gravity_direction.cross(_target_gravity_direction).normalized()
		if rotation_axis.is_normalized():
			var rotation_amount = min(angle_between, gravity_change_speed * delta)
			_current_gravity_direction = _current_gravity_direction.rotated(rotation_axis, rotation_amount)
		else:
			_current_gravity_direction = _target_gravity_direction

	# --- Camera Vertical Tilt ---
	# ... (remains the same) ...
	_camera_pivot.rotation.x += _camera_input_direction.y * delta
	_camera_pivot.rotation.x = clamp(
		_camera_pivot.rotation.x, tilt_lower_limit, tilt_upper_limit
	)

	# --- Character Rotation ---
	# ... (remains the same) ...
	self.rotate_y(-_camera_input_direction.x * delta * mouse_sensitivity * 5.0)
	_camera_input_direction = Vector2.ZERO

	# --- Movement Input ---
	var raw_input := Input.get_vector(
		"move_left", "move_right", "move_forward", "move_backward"
	)

# 1. Define the character's current "UP" relative to gravity
	var char_up_relative = -current_gravity_normal

	# 2. Get the character body's intended "FORWARD" direction in world space
	#    (based on where the mouse has rotated the CharacterBody3D)
	#    Adjust sign if your model's forward is +Z
	var intended_forward_world = -self.global_basis.z

	# 3. Project the intended forward direction onto the plane perpendicular to gravity
	#    This gives the actual "FORWARD" direction for movement on the current 'floor'.
	var char_forward_relative = (
		intended_forward_world - current_gravity_normal * intended_forward_world.dot(current_gravity_normal)
	)

	# Handle edge case: If intended forward is aligned with gravity, projection is zero.
	if not char_forward_relative.is_normalized():
		# Fallback: Use the character body's RIGHT vector projected instead.
		var intended_right_world = self.global_basis.x
		var char_right_relative_fallback = (
			intended_right_world - current_gravity_normal * intended_right_world.dot(current_gravity_normal)
		).normalized()
		# If THAT projection also fails (body perfectly aligned with gravity),
		# calculate forward based on the fallback right and the up vector.
		if char_right_relative_fallback.is_normalized():
			char_forward_relative = char_up_relative.cross(char_right_relative_fallback).normalized()
		else:
			# Absolute fallback (e.g., use world forward projected) - should rarely happen
			char_forward_relative = (Vector3.FORWARD - current_gravity_normal * Vector3.FORWARD.dot(current_gravity_normal)).normalized()
			if not char_forward_relative.is_normalized(): # Handle gravity == world forward
				char_forward_relative = (Vector3.RIGHT - current_gravity_normal * Vector3.RIGHT.dot(current_gravity_normal)).normalized()


	# 4. Calculate the character's "RIGHT" direction relative to gravity using cross product
	#    Right = Up x Forward
	var char_right_relative = char_up_relative.cross(char_forward_relative).normalized()

	# --- Calculate Final Movement Direction using Relative Basis ---
	# Use the calculated relative forward and right vectors
	# Test '+' vs '-' for raw_input.x based on your preference / model orientation
	var move_direction = char_forward_relative * raw_input.y + char_right_relative * raw_input.x
	# If A/D are swapped, use:
	# var move_direction = char_forward_relative * raw_input.y - char_right_relative * raw_input.x

	# Normalize the final move_direction if input is diagonal
	move_direction = move_direction.normalized() # Important for consistent speed

	# --- Gravity and Velocity Calculation ---
	# (The rest of the velocity logic can likely remain the same,
	# as it already separates horizontal/vertical based on current_gravity_normal
	# and uses move_direction to determine the target horizontal velocity)

	# 1. Get velocity components relative to CURRENT gravity
	var vertical_velocity_scalar := velocity.dot(current_gravity_normal)
	var vertical_velocity_vector :Vector3= current_gravity_normal * vertical_velocity_scalar
	var horizontal_velocity_vector := velocity - vertical_velocity_vector

	# 2. Apply gravity force along CURRENT gravity direction
	vertical_velocity_scalar += gravity_strength * delta
	vertical_velocity_vector = current_gravity_normal * vertical_velocity_scalar

	# 3. Define target horizontal velocity based on the calculated relative move_direction
	#    (No need to project move_direction again, it's already calculated on the correct plane)
	var target_horizontal_velocity = move_direction * move_speed

	# 4. Move current horizontal velocity towards the target
	horizontal_velocity_vector = horizontal_velocity_vector.move_toward(
		target_horizontal_velocity, acceleration * delta
	)

	# 5. Recombine velocity components
	velocity = horizontal_velocity_vector + vertical_velocity_vector

	# --- Handle Jump ---
	# (Uses char_up_relative implicitly via up_direction)
	up_direction = char_up_relative # Set CharacterBody3D's up direction
	var is_starting_jump := Input.is_action_just_pressed("jump") and is_on_floor()
	if is_starting_jump:
		velocity += up_direction * jump_strength

	# --- Execute Movement ---
	move_and_slide()		# --- Rotate Skin Globally (Align Up with Gravity, Forward with Camera - Revised) ---

	current_gravity_normal = _current_gravity_direction.normalized()
	var target_up_global = -current_gravity_normal # Skin's desired 'up' in world space

	# Ensure target_up is valid
	if target_up_global.is_normalized():
		var target_forward_global: Vector3
		var target_right_global: Vector3

		# 1. Get camera forward and project it onto the horizontal plane
		var camera_forward_global = -_camera.global_basis.z
		var projected_camera_forward = -camera_forward_global - current_gravity_normal * camera_forward_global.dot(current_gravity_normal)

		# Check if projection is valid
		if projected_camera_forward.length_squared() > 0.0001: # Use length_squared for robustness
			projected_camera_forward = projected_camera_forward.normalized()

			# 2. Calculate the target Right vector using the cross product
			# Right = Forward x Up (using projected forward and target up)
			target_right_global = projected_camera_forward.cross(target_up_global).normalized()

			# 3. Recalculate the target Forward vector using the cross product
			# Forward = Up x Right (using target up and calculated target right)
			target_forward_global = target_up_global.cross(target_right_global).normalized()

		else:
			# Fallback: Projection failed (camera likely aligned with gravity)
			# We need a different reference direction. Use camera's RIGHT projected.
			# print("Debug - Camera forward projection failed. Using camera right fallback.") # Optional
			var camera_right_global = _camera.global_basis.x
			var projected_camera_right = camera_right_global - current_gravity_normal * camera_right_global.dot(current_gravity_normal)

			if projected_camera_right.length_squared() > 0.0001:
				# Use the projected camera right directly as the target Right
				target_right_global = projected_camera_right.normalized()
				# Calculate Forward = Up x Right
				target_forward_global = target_up_global.cross(target_right_global).normalized()
			else:
				# Ultimate Fallback: Use world axes (may look odd if gravity isn't Down)
				# print("Debug - Camera right projection also failed. Using world axes fallback.") # Optional
				target_right_global = Vector3.RIGHT.cross(target_up_global).normalized()
				target_forward_global = target_up_global.cross(target_right_global).normalized()


		# --- DEBUG ---
		# print("Debug Fwd: ", target_forward_global.round(), " | Up: ", target_up_global.round(), " | Right: ", target_right_global.round())
		# -----------

		# 4. Construct the target basis using the calculated vectors
		# Basis columns are X, Y, Z (Right, Up, -Forward using Godot convention)
		# Or use looking_at with the recalculated forward.
		var target_global_basis = Basis.looking_at(target_forward_global, target_up_global)

		# --- DEBUG ---
		# print("Debug Basis X: ", target_global_basis.x.round(), " | Y: ", target_global_basis.y.round(), " | Z: ", target_global_basis.z.round())
		# -----------

		# 5. Calculate the required LOCAL basis for the skin node
		var parent_global_basis_inverse = self.global_transform.basis.inverse()
		var target_local_basis = parent_global_basis_inverse * target_global_basis

		# 6. Interpolate the skin's basis
		_skin.basis = _skin.basis.slerp(target_local_basis, skin_rotation_speed * delta)

	# else: # Optional: Handle the case where gravity normal is somehow zero
		# push_warning("Invalid gravity normal for skin rotation.")

	# --- Skin Animation ---
	# (This logic remains the same)
	var current_gravity_normal_for_anim = _current_gravity_direction.normalized()
	var ground_speed := (velocity - current_gravity_normal_for_anim * velocity.dot(current_gravity_normal_for_anim)).length()
	if ground_speed > 0.1:
		if _skin.has_method("run"): _skin.run()
	else:
		if _skin.has_method("idle"): _skin.idle()
	


# --- Signal Handler Functions ---
func _on_player_entered_gravity_zone(new_gravity_direction: Vector3):
	# When entering a zone, immediately target its gravity direction
	print("Player received enter signal. Targeting: ", new_gravity_direction.normalized())
	_target_gravity_direction = new_gravity_direction.normalized()
	# Optional: Add the zone to a list if you need to handle overlapping zones

func _on_player_exited_gravity_zone():
	# When exiting a zone, target the default gravity
	# Optional: More complex logic needed if handling overlapping zones
	print("Player received exit signal. Targeting default gravity.")
	_target_gravity_direction = DEFAULT_GRAVITY_DIRECTION
