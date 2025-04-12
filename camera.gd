extends Node

# Rotation speed
@export var rotation_speed: float = 0.1

# Internal variables
var yaw: float = 0.0

var player: CharacterBody3D = null

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * rotation_speed
		references.player.rotation_degrees.y = yaw
