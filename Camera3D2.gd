extends Camera3D

signal shift(pos : Vector2)

@export var position_proxy : Vector3 :
	set(val):
		if position_proxy != val:
			position_proxy = val
			position = position_proxy
			if get_viewport() != null:
				snap()
@export var rotation_proxy : Vector3 :
	set(val):
		if rotation_proxy != val:
			rotation_proxy = val
			rotation = rotation_proxy
			if get_viewport() != null:
				snap()

func snap() -> void:
	var rot := Quaternion.from_euler(rotation_proxy)
	var lookat := Vector3.FORWARD.rotated(rot.get_axis(), rot.get_angle())
	var plane := Plane(lookat, 0)
	var proj := plane.project(position_proxy)
	var distance := plane.distance_to(position_proxy)
	var pixel_size := size / get_viewport().get_visible_rect().size.y
	
	var quat := Quaternion(Vector3.DOWN, lookat)
	var inv_quat := quat.inverse()
	var proj_proj := proj.rotated(inv_quat.get_axis(), inv_quat.get_angle())
	
	var snapped := proj_proj.snapped(Vector3(pixel_size, 0, pixel_size))
	var snapped_proj := snapped.rotated(quat.get_axis(), quat.get_angle())
	
	var _shift = (proj_proj - snapped) / pixel_size
	shift.emit(Vector2(_shift.x, _shift.z))
	
	var snapped_pos := snapped_proj + lookat * distance
	position = snapped_pos
	pass
