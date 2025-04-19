extends Area3D

const EPSILON: float = 0.0001
const WORLD_UP: Vector3 = Vector3(0.0, 1.0, 0.0)


signal global_timer_start
var body_exited_zone = true

func _ready() -> void:
	var collsion_to_be: int
	if get_groups().has('blue'):
		collsion_to_be = 1 
	if get_groups().has('red'):
		collsion_to_be = 2 
		
	collision_layer = collsion_to_be
	$"..".get_child(1).get_child(0) = collision_to_be
func _process(_delta):
	if !body_exited_zone:
		Refs._on_global_timer_start()
		
func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D && body.get_groups():
		Refs._on_global_timer_start()
		var target_up_direction: Vector3 = -global_transform.basis.x.normalized()
		Refs.flip_direction(target_up_direction, body)
		body.up_direction = target_up_direction

func _on_body_exited(body: Node3D):
	if body is CharacterBody3D:
		if body.get_slide_collision_count() > 0:
			return
		Refs.exited_gravity_zone = true 
