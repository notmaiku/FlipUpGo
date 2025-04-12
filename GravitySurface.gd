extends Node3D

## The direction gravity should pull the player *towards* when they touch this surface.
## Make sure this vector points *into* the surface from the player's perspective.
## Example: For a ceiling, this might be Vector3.UP. For a wall, Vector3.LEFT/RIGHT/etc.
@export var target_gravity_direction: Vector3 = Vector3.ZERO


func _ready():
	# Ensure this object is in the correct group for detection
	if  not is_in_group("gravity_blue"):
		add_to_group("gravity_blue")
		print(
			"Object '%s' automatically added to group 'gravity_blue'. "
			+ "Add it manually in the editor for clarity.",
			name
		)

	if target_gravity_direction.is_zero_approx():
		print(
			"GravitySurface '%s' has target_gravity_direction set to zero. "
			+ "Gravity won't change unless this is set to a valid direction in the Inspector.",
			name
		)
