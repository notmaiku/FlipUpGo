# GravityZone.gd (Attached to the Area3D node)
extends Area3D

class_name GravityZone
## The direction gravity should pull the player *towards* when they are inside this zone.
@export var target_gravity_direction: Vector3 = Vector3.DOWN

# Signal emitted when the player enters the zone.
# Passes the desired gravity direction for this zone.
signal player_entered_gravity_zone(new_gravity_direction: Vector3)

# Signal emitted when the player exits the zone.
signal player_exited_gravity_zone

func _ready():
	# Ensure this Area3D can be found easily if needed
	add_to_group("gravity_zone")

	# Connect the Area3D's built-in signals to our functions
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if target_gravity_direction.is_zero_approx():
		print("GravityZone '%s' has target_gravity_direction set to zero." % name)


func _on_body_entered(body: Node3D):
	# Check if the body that entered is the player
	# (Using a group is generally the most flexible way)
	if body.is_in_group("player"):
		print("Player entered gravity zone: ", name, " | Target Gravity: ", target_gravity_direction)
		# Emit our custom signal, sending the gravity direction
		emit_signal("player_entered_gravity_zone", target_gravity_direction)


func _on_body_exited(body: Node3D):
	# Check if the body that exited is the player
	if body.is_in_group("player"):
		print("Player exited gravity zone: ", name)
		# Emit our custom signal indicating exit
		emit_signal("player_exited_gravity_zone")
