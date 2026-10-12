extends SceneTree

func _init() -> void:
	var image := Image.new()
	assert(image.load_svg_from_string(FileAccess.get_file_as_string("res://icon.svg"),4.0)==OK)
	image.resize(256,256,Image.INTERPOLATE_LANCZOS)
	DirAccess.make_dir_recursive_absolute("res://assets/branding")
	assert(image.save_png("res://assets/branding/splash.png")==OK)
	quit()
