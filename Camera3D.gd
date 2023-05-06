extends Camera3D

signal shift(pos : Vector2)

@export var distance : float = 2 :
	set(val):
		distance = val
		if get_viewport() != null:
			_snap()
@export var position_proxy : Vector3 :
	set(val):
		position_proxy = val
		if get_viewport() != null:
			_snap()

func _snap() -> void:
	var plane := Plane(%Scene.to_global(Vector3(0, 1, 0)))
	var point := Vector3(position_proxy.x, 0, position_proxy.z)
	var dir := Vector3.DOWN if plane.is_point_over(point) else Vector3.UP
	var intersect = plane.intersects_ray(point, dir)
	if intersect != null:
		position.y = intersect.y + distance
	var screen_size := get_viewport().get_visible_rect().size
	var pixel_size := size / screen_size.y
	var axis := Vector3(1, 1, 1) * pixel_size
	var snap := position_proxy.snapped(axis)
	position.x = snap.x
	position.z = snap.z
	var _shift = (position_proxy - position) / pixel_size
	shift.emit(Vector2(_shift.x, _shift.z))
	pass
