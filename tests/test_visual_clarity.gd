extends SceneTree

const Motion = preload("res://scripts/art_motion.gd")
var checks := 0
var failures := 0
var output := "res://artifacts/clarity-work/visual"

class Gallery extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 720), Color("07111d"))
		var font := ThemeDB.fallback_font
		var index := 0
		for id: String in ArtAssets.TEXTURES:
			var at := Vector2(62 + (index % 12) * 106, 30 + (index / 12) * 88)
			ArtAssets.sprite(self, id, at, Vector2.ONE * 32)
			ArtAssets.sprite(self, id, at + Vector2(32, 18), Vector2.ONE * 24, PI / 4)
			draw_string(font, at + Vector2(-48, 45), id, HORIZONTAL_ALIGNMENT_LEFT, 100, 9, Color.WHITE)
			index += 1

func _init() -> void:
	call_deferred("run_checks")
	create_timer(90).timeout.connect(func() -> void: push_error("CLARITY timeout"); quit(1))

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("CLARITY: " + label)

func snapshot(game: Node2D, name: String) -> void:
	var state := var_to_bytes([game.run.elapsed, game.run.hp, game.run.enemies, game.run.shots,
		game.run.gems, game.run.hazards, game.run.rng.state, game.run.mission_rng.state])
	game.queue_redraw()
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output + "/" + name + ".png") == OK, name + " capture")
	check(state == var_to_bytes([game.run.elapsed, game.run.hp, game.run.enemies, game.run.shots,
		game.run.gems, game.run.hazards, game.run.rng.state, game.run.mission_rng.state]), name + " rendering preserves simulation")

func run_checks() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.min_size = Vector2i.ONE
	for id: String in ArtAssets.TEXTURES:
		check(ArtAssets.texture(id) != null, id + " bound")
		if id.begins_with("world/"): continue
		var image := ArtAssets.texture(id).get_image()
		var bounds := image.get_used_rect()
		check(bounds.has_area(), id + " has visible body")
		check(bounds.position.x > 0 and bounds.position.y > 0 and bounds.end.x < image.get_width() and bounds.end.y < image.get_height(), id + " retains alpha padding")
	for id: String in ["xp", "heal"]:
		var image := ArtAssets.texture("objects/" + id).get_image()
		check(float(image.get_used_rect().size.y) / image.get_height() > 0.8, id + " body survives small display")
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.records.load_data("user://clarity_%d.json" % Time.get_ticks_usec())
	game.sound.set_muted(true)
	for size: Vector2i in [Vector2i(1600,900), Vector2i(960,540), Vector2i(1920,1080), Vector2i(1536,864), Vector2i(390,844), Vector2i(844,390), Vector2i(320,568), Vector2i(568,320)]:
		DisplayServer.window_set_size(size)
		game.touch_mode = size.x < 900
		game._fit_viewport()
		await process_frame
		var base: Vector2i = game.get_window().content_scale_size
		check(not game.touch_mode or base == (Vector2i(540,960) if size.x < size.y else Vector2i(960,540)), "mobile viewport uses production base")
		for ship: String in GameContent.SHIP_IDS:
			game.run.reset(7801, "normal", ship, "storm")
			game.run.elapsed = 260
			game.run.gems.append({"pos":game.run.player+Vector2(-45,50),"kind":"xp","value":1})
			game.run.gems.append({"pos":game.run.player+Vector2(45,50),"kind":"heal","value":1})
			game.run.spawn_enemy("runner", game.run.player + Vector2(-90,0))
			game.run.spawn_enemy("shooter", game.run.player + Vector2(90,0))
			var shot_point: Vector2 = game.run.player + Vector2(18,0)
			game.run.shots.append({"pos":shot_point,"velocity":Vector2.ZERO,"friendly":false,"radius":4,"damage":0,"ttl":2.0})
			game._resume()
			game.camera_offset = game._camera_target(game.run.player)
			await snapshot(game, "%dx%d-%s" % [size.x,size.y,ship])
			if DisplayServer.get_name() != "headless":
				var at: Vector2 = root.get_final_transform() * game.get_global_transform_with_canvas() * (shot_point - game.camera_offset)
				var pixel := root.get_texture().get_image().get_pixelv(Vector2i(at))
				check(pixel.r > pixel.g and pixel.g > pixel.b, "hostile core stays visible above " + ship)
	DisplayServer.window_set_size(Vector2i(1600,900))
	game.touch_mode = false
	game._fit_viewport()
	for filter in [CanvasItem.TEXTURE_FILTER_LINEAR, CanvasItem.TEXTURE_FILTER_NEAREST]:
		game.texture_filter = filter
		game.run.reset(7801, "normal", "striker", "ring")
		game._resume()
		for step in range(12):
			game.run.facing = Vector2.from_angle(step * TAU / 12)
			game.camera_offset = game._camera_target(game.run.player)
			await snapshot(game, "filter-%d-angle-%02d" % [filter,step])
	if "--motion" in OS.get_cmdline_user_args():
		DisplayServer.window_set_size(Vector2i(960,540))
		game.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		game._fit_viewport()
		game.run.reset(7801, "normal", "striker", "storm")
		game._resume()
		game.mouse_active = false
		await process_frame
		await process_frame
		for step in 120:
			if game.screen in ["pause", "upgrade", "branch"]:
				for pressed in [true,false]:
					var key := InputEventKey.new()
					key.physical_keycode = KEY_ESCAPE if game.screen == "pause" else KEY_1
					key.pressed = pressed
					root.push_input(key,true)
				await process_frame
			Input.action_press("move_right")
			game._physics_process(1.0 / 60.0)
			game.queue_redraw()
			await RenderingServer.frame_post_draw
			if step % 4 == 0:
				check(root.get_texture().get_image().save_png(output + "/motion-%04d.png" % step) == OK, "moving simulation frame")
		Input.action_release("move_right")
		check(game.run.elapsed > 1.9 and game.run.player.x > RunModel.CENTER.x, "moving preview advances real simulation")
	game.sound.stop_all()
	game.queue_free()
	await process_frame
	root.content_scale_size = Vector2i(1280,720)
	var gallery := Gallery.new()
	root.add_child(gallery)
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output + "/all-textures.png") == OK, "all texture gallery")
	gallery.queue_free()
	await process_frame
	print("CLARITY SELF-CHECK: %d / %d assertions passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
