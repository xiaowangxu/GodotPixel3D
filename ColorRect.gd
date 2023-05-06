extends TextureRect

func _on_camera_3d_shift(pos: Vector2) -> void:
	(material as ShaderMaterial).set_shader_parameter("Shift", pos)
	pass # Replace with function body.
