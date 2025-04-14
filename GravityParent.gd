extends Node3D

## Set this in the Inspector when placing this object in the world scene.
## It controls the gravity direction for the child StaticBody3D.
@export var gravity_direction_setting: Vector3 = Vector3.DOWN

# Adjust the path "$GravityBody" if your StaticBody3D has a different name or path!
@onready var gravity_body: Area3D = %GravityBody

func _ready():
    # Check if we found the gravity body node
    if gravity_body:
        # Check if the gravity body actually has the GravitySurface script
        # (This check relies on class_name GravitySurface in the other script)
        if gravity_body is GravityZone:
            # Pass the value from this script's export var
            # down to the target_gravity_direction var on the child script.
            gravity_body.target_gravity_direction = gravity_direction_setting
            print("'%s': Set child gravity direction to: %s" % [name, gravity_direction_setting])
        else:
            printerr("'%s': Child node '%s' does not have GravitySurface script attached!" % [name, gravity_body.name])
    else:
        printerr("'%s': Could not find child StaticBody3D node at path '$GravityBody'!" % name)

