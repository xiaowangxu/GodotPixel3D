extends Node3D

signal shift(pos : Vector2)

func _process(delta: float) -> void:
	snap.call_deferred()

func snap() -> void:
	var normal := global_position.direction_to(to_global(Vector3.DOWN))
	var plane := Plane(normal, global_position)
	
	var center := plane.project(Vector3.ZERO)

	var local_center := to_local(center)
	local_center.y = 0
	
	var screen_size := get_viewport().get_visible_rect().size
	var pixel_size : float = $Camera3D.size / screen_size.y

	var delta : Vector3 = - local_center
	var snapped := delta.snapped(Vector3(pixel_size, 0, pixel_size))
	var new_pos := snapped + local_center
	
	var _shift = - new_pos / pixel_size
	shift.emit(Vector2(_shift.x, _shift.z))
	
	$Camera3D.position = new_pos
