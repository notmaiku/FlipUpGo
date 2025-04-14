extends Camera3D

# Camera rotation speed
@export var rotation_speed: float = 0.1

# Vertical rotation limits
@export var min_pitch: float = -80.0
@export var max_pitch: float = 80.0

# Internal variables
var yaw: float = 0.0
var pitch: float = 0.0

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Adjust yaw and pitch based on mouse movement
		yaw -= event.relative.x * rotation_speed
		pitch -= event.relative.y * rotation_speed

		# Clamp pitch to avoid flipping
		pitch = clamp(pitch, min_pitch, max_pitch)

		# Apply rotation to the camera
		rotation_degrees = Vector3(pitch, yaw, 0)
