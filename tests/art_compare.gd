extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var view := Control.new()
	root.add_child(view)
	var bg := ColorRect.new()
	bg.color = Color("07101d")
	bg.size = Vector2(1280,720)
	view.add_child(bg)
	var paths := ["res://art_source/comparison/striker_blender.png", "res://assets/art/ships/striker.png"]
	for i in range(2):
		var label := Label.new()
		label.text = "BLENDER / beveled mesh" if i == 0 else "IMAGEGEN / ceramic interceptor"
		label.position = Vector2(70+i*640,40)
		label.add_theme_font_size_override("font_size",24)
		view.add_child(label)
		var texture := ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(paths[i])))
		for j in range(4):
			var sprite := TextureRect.new()
			sprite.texture = texture
			sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var side: int = [320,80,48,36][j]
			sprite.size = Vector2.ONE*side
			sprite.position = Vector2(80+i*640+j*110 if j>0 else 120+i*640,390 if j>0 else 80)
			view.add_child(sprite)
	for i in 4:
		var logo := TextureRect.new()
		logo.texture=load("res://icon.svg")
		logo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		var side: int=[16,32,64,128][i]
		logo.size=Vector2.ONE*side
		logo.position=Vector2(660+i*145,540)
		view.add_child(logo)
		var caption := Label.new()
		caption.text="APP %dpx" % side
		caption.position=Vector2(660+i*145,680)
		view.add_child(caption)
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/candidate/art/production-comparison.png")
	quit()
