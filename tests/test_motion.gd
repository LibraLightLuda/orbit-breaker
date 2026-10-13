extends SceneTree

var game: Node2D
var checks := 0
var failures := 0
var folder := "res://artifacts/candidate/motion"
var clips: Array[Dictionary] = []

func _init() -> void:
	call_deferred("run_checks")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("MOTION: " + message)

func render() -> Image:
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func capture(clip: String, index: int) -> void:
	var im := await render()
	check(im.save_webp(folder + "/%s-%03d.webp" % [clip, index], false, 0.82) == OK, "capture " + clip)
	if index in [0, 24, 48, 96, 120, 192, 216]:
		im.save_png(folder + "/%s-%03d.png" % [clip, index])

func fingerprint() -> int:
	return hash(var_to_bytes([game.run.rng.state, game.run.elapsed, game.run.player, game.run.hp, game.run.shots, game.run.enemies, game.run.gems, game.run.effects, game.run.upgrades, game.run.parts]))

func check_reduced_explosions() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var canvas := Node2D.new()
	var effect := {"kind": "impact_blast", "pos": Vector2(128, 128), "radius": 60.0, "ttl": 1.0, "max_ttl": 1.0}
	canvas.draw.connect(func() -> void: preload("res://scripts/art_motion.gd").effect(canvas, effect, true))
	viewport.add_child(canvas)
	root.add_child(viewport)
	for kind: String in ["impact_blast", "impact_meteor"]:
		effect.kind = kind
		effect.ttl = 1.0
		canvas.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var first := viewport.get_texture().get_image().get_used_rect()
		effect.ttl = 0.5
		canvas.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var faded := viewport.get_texture().get_image().get_used_rect()
		check(first.has_area() and Vector2(first.position).distance_to(Vector2(faded.position)) < 4 and Vector2(first.size).distance_to(Vector2(faded.size)) < 6, "reduced explosion fades without expanding " + kind)
	viewport.queue_free()
	await process_frame

func fixture(ship: String, sector: String) -> void:
	game.run.reset(7801, "normal", ship, sector)
	game.run.elapsed = 260
	game.run.hp = 10000
	game.run.max_hp = 10000
	game.run.orbit_count = 6
	game.run.upgrades = {"power": 3, "rapid": 3, "orbit": 3, "blade": 3, "frost": 3, "missile": 3, "chain": 3, "pulse": 3, "magnet": 2}
	game.run.parts = {"core": 2, "drive": 2, "shell": 2}
	game.run.hull_forms.assign(Expedition.RECIPE_IDS)
	game.camera_offset = Vector2.ZERO
	game.mouse_active = true
	game.ghost = GhostReplay.new()
	for i in 32:
		game.run.spawn_enemy(["chaser", "runner", "tank", "shooter"][i % 4], game.run.player + Vector2.from_angle(i * 2.399) * (160 + i * 8))
	game.run.spawn_enemy("boss", game.run.player + Vector2(290, -140))
	for i in 48:
		game.run.gems.append({"pos": game.run.player + Vector2.from_angle(i * 2.399) * (25 + i * 6), "kind": "xp", "value": 1})
	game.run.spawn_item(game.run.player + Vector2(130, 70), "A", "shield")
	game.run.spawn_part(game.run.player + Vector2(-130, 60), "elite", "drive")
	game._resume()

func run_checks() -> void:
	assert(DisplayServer.get_name() != "headless", "Motion checks require real rendering")
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1280, 720)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.records.load_data("user://motion_fixture_%d.json" % Time.get_ticks_usec())
	game.sound.set_muted(true)
	game.records.data.reduced_motion = false
	game._show_menu()
	var before := fingerprint()
	for i in 288:
		game.clock_time = i / 12.0
		await capture("title", i)
	check(before == fingerprint(), "title demonstration never changes game state or RNG")
	clips.append({"name": "title", "frames": 288, "fps": 12})
	for ship_index in 3:
		var ship: String = GameContent.SHIP_IDS[ship_index]
		fixture(ship, GameContent.SECTOR_IDS[ship_index])
		var start: float = game.run.elapsed
		var start_pos: Vector2 = game.run.player
		for i in 72:
			game.mouse_active = true
			game.mouse_outside = false
			game.mouse_target = game.run.player - game.camera_offset + Vector2.from_angle(i * 0.06) * 220
			if i == 18: game.dash_queued = true
			if i == 30:
				game.run.invulnerable = 0
				game.run.take_damage(1, "combat", game.run.player + Vector2(80, 0))
			for step in 5:
				if game.run.state == "upgrade": game.run.choose_upgrade(game.run.get_upgrade_choices()[0])
				if game.screen != "playing":
					game._resume()
					game.mouse_active = true
				game._physics_process(1.0 / 60.0)
			await capture("combat-" + ship, i)
		check(game.run.player.distance_to(start_pos) > 100, "player actually moves " + ship)
		check(game.run.elapsed > start + 5, "actual combat advances " + ship)
		check(game.ghost.frames.size() >= 25, "actual main loop captures ghost " + ship)
		before = fingerprint()
		await render()
		await render()
		check(before == fingerprint(), "rendering preserves simulation " + ship)
		clips.append({"name": "combat-" + ship, "frames": 72, "fps": 12})
	fixture("scout", "storm")
	game.run.hazards.clear()
	game.run._add_encounter("black_hole", game.run.player + Vector2(170, 90))
	game.run.hazards.back().active = true
	game.run.hazards.back().ttl = 20
	for i in 60:
		game.mouse_active = true
		game.mouse_outside = false
		game.mouse_target = game.run.player - game.camera_offset + Vector2.LEFT * 140
		for step in 5:
			if game.run.state == "upgrade": game.run.choose_upgrade(game.run.get_upgrade_choices()[0])
			if game.screen != "playing":
				game._resume()
				game.mouse_active = true
			game._physics_process(1.0 / 60.0)
		await capture("gravity", i)
	clips.append({"name": "gravity", "frames": 60, "fps": 12})
	game._show_pause()
	await create_timer(0.3).timeout
	var frozen := hash((await render()).get_data())
	before = fingerprint()
	for i in 15: game._physics_process(1.0 / 60.0)
	check(before == fingerprint(), "pause preserves simulation")
	check(frozen == hash((await render()).get_data()), "pause freezes background, actors and combat effects")
	game.records.data.reduced_motion = true
	var shade: ColorRect = game.ui.get_node("Shade")
	shade.size = Vector2.ONE
	game._fit_viewport()
	check(shade.size.is_equal_approx(game._viewport_rect().size) and shade.position.is_equal_approx(game._viewport_rect().position), "reduced motion still resizes modal shade")
	game._resume()
	game.run.effects.assign([{"kind": "risk_xp", "pos": game.run.player, "radius": 1.0, "ttl": 1.0, "max_ttl": 1.0, "end": Vector2(1, 0)}])
	var pickup_region := Rect2i(Vector2i(game.run.player - game.camera_offset) - Vector2i(64, 64), Vector2i(128, 128))
	frozen = hash((await render()).get_region(pickup_region).get_data())
	game.run.effects[0].ttl = 0.8
	check(frozen == hash((await render()).get_region(pickup_region).get_data()), "reduced XP feedback has no moving absorption spiral")
	await check_reduced_explosions()
	game._show_menu()
	game.clock_time = 2.0
	frozen = hash((await render()).get_data())
	game.clock_time = 3.0
	check(frozen == hash((await render()).get_data()), "reduced title has no drift, recoil or flashing")
	game.records.data.reduced_motion = false
	game._show_hangar()
	await process_frame
	var button: Button = game.ui.find_children("*", "Button", true, false)[0]
	button.grab_focus()
	for i in 12:
		if i == 3: button.button_down.emit()
		if i == 5: button.button_up.emit()
		await capture("ui", i)
		await create_timer(1.0 / 12).timeout
	check(button.hover_amount > 0.99 and button.scale.is_equal_approx(Vector2.ONE), "focus and press settle without moving layout")
	clips.append({"name": "ui", "frames": 12, "fps": 12})
	game._show_settings()
	var transition_started: Array[bool] = [false]
	(func() -> void: transition_started[0] = game.ui.position.y > 0 and game.ui.modulate.a < 1.0).call_deferred()
	await process_frame
	check(transition_started[0], "actual menu change starts slide and fade")
	await create_timer(0.25).timeout
	check(game.ui.position.is_equal_approx(Vector2.ZERO) and is_equal_approx(game.ui.modulate.a, 1), "menu transition settles")
	var source := RunModel.new()
	source.reset(7801, "normal", "striker", "ring")
	var recording := GhostReplay.new()
	recording.capture(source, true)
	source.elapsed = 0.2
	source.player += Vector2(20, 0)
	recording.capture(source, true)
	game.screen = "replay"
	game._clear_ui()
	game.replay_frames = recording.frames
	game.replay_entry = {"ship": "striker", "sector": "ring", "mode": "normal"}
	game.replay_run.reset(7801, "normal", "striker", "ring")
	game.replay_time = 0.1
	game.camera_offset = Vector2.ZERO
	game.hurt_flash = 0.0
	frozen = hash((await render()).get_data())
	check(is_equal_approx(game.replay_run.elapsed, 0.1) and is_equal_approx(game.replay_run.current_speed, 100), "ghost initial interval uses interpolated visual time and real sample interval")
	game.hurt_flash = 0.35
	check(frozen == hash((await render()).get_data()), "ghost rendering ignores residual live hit flash")
	var report := {"checks": checks, "failures": failures, "clips": clips, "renderer": RenderingServer.get_video_adapter_name(), "note": "Native Godot frames; combat uses production main physics at 60Hz, film sampled at 12fps. Fixtures isolate persistence."}
	FileAccess.open(folder + "/motion-results.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("MOTION SELF-CHECK: %d / %d assertions passed" % [checks - failures, checks])
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures == 0 else 1)
