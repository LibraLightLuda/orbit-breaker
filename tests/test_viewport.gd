extends SceneTree

var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAILED: " + message)

func run_checks() -> void:
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.records.load_data("user://test_viewport_%d.json" % Time.get_ticks_usec())
	game.sound.set_muted(true)
	await process_frame
	check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND, "viewport expands without letterboxing or distorted shapes")
	check(game.position.is_equal_approx((root.get_visible_rect().size - Vector2(1280, 720)) * 0.5), "logical layout stays centered")
	check(game.ui.get_parent().offset == game.position, "UI and world share centering")
	check(game._viewport_rect().size == root.get_visible_rect().size, "background fills expanded viewport")
	var capture := "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	if capture:
		await snapshot("title", game.BG)
	game._start_run()
	game.mouse_active = false
	var pointer := InputEventMouseMotion.new()
	pointer.position = game.position + game.run.player + Vector2(100, 0)
	pointer.global_position = pointer.position
	game.mouse_outside = false
	root.push_input(pointer, true)
	check(game.mouse_target.is_equal_approx(game.run.player + Vector2(100, 0)), "pointer coordinates include expanded-view centering")
	check(game._movement_direction().is_equal_approx(Vector2.RIGHT), "centered mouse input steers toward cursor")
	await process_frame
	game.mouse_active = false
	check(game.hud.hp.get_theme_constant("outline_size") == 2, "translucent HUD retains readable text outlines")
	game.run.spawn_enemy("boss", Vector2(780, 25))
	game.queue_redraw()
	await process_frame
	if capture:
		await snapshot("translucent-header")
		var image := root.get_texture().get_image()
		var sample_at := Vector2i((game.position + Vector2(805, 25)) * Vector2(image.get_size()) / root.get_visible_rect().size)
		check(image.get_pixelv(sample_at).r > 0.30, "enemy remains visible through upper HUD background")
	for id: String in ["striker", "scout", "bastion"]:
		game.run.reset(39, "normal", id)
		game.run.dash_cooldown = 1.5
		game.run.overdrive_meter = 55
		game.run.focus_time = 0.6 if id == "striker" else 0
		game._update_hud()
		game.queue_redraw()
		await process_frame
		if capture:
			await snapshot(id + "-charging")
		game.run.dash_cooldown = 0
		game.run.overdrive_meter = 100
		game.run.focus_time = 1.2 if id == "striker" else 0
		game._update_hud()
		game.queue_redraw()
		await process_frame
		if capture:
			await snapshot(id + "-ready")
	game.run.reset(39)
	game.run.focus_time = 1.2
	game.run.step(0.01, Vector2.RIGHT, true)
	game.run.overdrive_meter = 100
	game.run.activate_overdrive()
	game._update_hud()
	game.queue_redraw()
	await process_frame
	if capture:
		await snapshot("striker-burst")
	game._show_pause()
	var shade: ColorRect = game.ui.get_node("Shade")
	check(shade.position == game._viewport_rect().position and shade.size == game._viewport_rect().size, "pause shade covers every viewport edge")
	# Exercise the same signal used by F11 and window resizing while paused.
	root.size_changed.emit()
	check(shade.position == game._viewport_rect().position and shade.size == game._viewport_rect().size, "resize keeps pause shade aligned")
	if capture:
		await snapshot("pause")
	if capture and "--check-fullscreen" in OS.get_cmdline_user_args():
		root.size = Vector2i(1237, 947)
		await process_frame
		await process_frame
		check(shade.position == game._viewport_rect().position and shade.size == game._viewport_rect().size, "actual window resize aligns pause overlay")
		check(game.ui.get_parent().offset == game.position, "actual window resize keeps input and UI aligned")
		await snapshot("resized-pause")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_F11
		key.pressed = true
		game._unhandled_key_input(key)
		await process_frame
		await process_frame
		check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "F11 enters fullscreen")
		game._show_menu()
		game.queue_redraw()
		await process_frame
		await snapshot("fullscreen-title", game.BG)
		game._unhandled_key_input(key)
		await process_frame
		check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "F11 restores window mode")
	game.queue_free()
	await process_frame
	print("VIEWPORT SELF-CHECK: %d / %d assertions passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)

func snapshot(label: String, edge_color: Color = Color.TRANSPARENT) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if edge_color.a > 0:
		for point: Vector2i in [Vector2i(0, 0), Vector2i(image.get_width() - 1, 0), Vector2i(0, image.get_height() - 1), Vector2i(image.get_width() - 1, image.get_height() - 1)]:
			var pixel := image.get_pixelv(point)
			check(absf(pixel.r - edge_color.r) < 0.02 and absf(pixel.g - edge_color.g) < 0.02 and absf(pixel.b - edge_color.b) < 0.02, "screen corner has scene background instead of black border")
	var folder := "res://artifacts/candidate/viewport-%dx%d" % [image.get_width(), image.get_height()]
	DirAccess.make_dir_recursive_absolute(folder)
	check(image.save_png(folder + "/" + label + ".png") == OK, "capture " + label)
