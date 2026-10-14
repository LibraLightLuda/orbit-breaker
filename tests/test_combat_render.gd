extends SceneTree

var checks := 0
var failures := 0
var output := "res://artifacts/combat-work/screens"

func _init() -> void:
	call_deferred("run_checks")
	create_timer(40).timeout.connect(func() -> void: push_error("COMBAT UI timeout"); quit(1))

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("COMBAT UI: " + message)

func snapshot(game: Node2D, name: String) -> void:
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	check(picture != null and picture.get_width() > 0, name + " rendered")
	picture.save_png(output + "/" + name + ".png")

func click(button: Button) -> void:
	await create_timer(0.08).timeout
	var at := button.get_global_transform_with_canvas() * (button.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func run_checks() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	root.min_size = Vector2i(1, 1)
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.records.load_data("user://combat_ui_%d.json" % Time.get_ticks_usec())
	game.sound.set_muted(true)
	game.records.data.reduced_motion = true
	for dimensions: Vector2i in [Vector2i(1600, 900), Vector2i(960, 540), Vector2i(390, 844), Vector2i(844, 390), Vector2i(320, 568), Vector2i(568, 320)]:
		DisplayServer.window_set_size(dimensions)
		await process_frame
		await process_frame
		check(DisplayServer.window_get_size() == dimensions, "Actual window matches requested dimensions")
		game.touch_mode = dimensions.x < 900
		for ship: String in GameContent.SHIP_IDS:
			game.run.reset(42, "normal", ship, "storm")
			game.run.evolutions.append({"striker":"sentry", "scout":"wake", "bastion":"citadel"}[ship])
			game.run.branch_pending = true
			game.run._check_level()
			game._show_branch()
			await process_frame
			var frozen: float = game.run.elapsed
			var codex_key := InputEventKey.new()
			codex_key.physical_keycode = KEY_TAB
			codex_key.pressed = true
			root.push_input(codex_key, true)
			await process_frame
			check(game.screen == "arsenal" and game.run.state == "branch", "TAB opens codex from focused branch card")
			game._close_arsenal()
			await process_frame
			check(game.screen == "branch" and game.run.elapsed == frozen, "Codex returns to frozen pending branch")
			check(game.ui.get_node_or_null("CompactScroll") == null, "Branch has no scroll at " + str(dimensions))
			var cards: Array[Button] = []
			for child in game.ui.get_children():
				if child is Button and child.has_meta("branch_id"): cards.append(child)
			check(cards.size() == 2, "Two branch options " + ship)
			for card in cards:
				check(card.size.x > 40 and card.size.y > 44, "Branch target reachable")
				var labels: Array[Label] = []
				for label in card.get_children():
					if label is Label:
						labels.append(label)
						check(Rect2(Vector2.ZERO, card.size).encloses(Rect2(label.position, label.size)), "Branch text inside card")
				for i in labels.size() - 1:
					check(labels[i].position.y + labels[i].size.y <= labels[i + 1].position.y, "Branch labels never overlap")
			await snapshot(game, "%dx%d-branch-%s" % [dimensions.x, dimensions.y, ship])
			var before: float = game.run.elapsed
			var expected: String = str(cards[0].get_meta("branch_id"))
			game.run.step(0.05, Vector2.RIGHT, true)
			check(game.run.elapsed == before, "Choice pauses clock")
			await click(cards[0])
			check(game.screen == "playing" and game.run.branch_id == expected, "Choice resumes correct tactic %s %s (%s)" % [dimensions, ship, game.screen])
		game.run.reset(42)
		game.run.survival_cleared = true
		game.run.elapsed = 530
		game.run._tick_finale()
		game._resume()
		await process_frame
		await snapshot(game, "%dx%d-final-offer" % [dimensions.x, dimensions.y])
		var accept: Button = game.ui.get_node("MobileHUD").final_accept if game.touch_mode else game.hud.final_accept
		check(accept.visible and accept.size.y >= 44, "Final operation choice is visible and touch sized")
		await click(accept)
		check(game.run.finale_selected and not game.dash_queued, "Choice consumes no dash")
		for code: int in [KEY_2, KEY_1]:
			var key := InputEventKey.new()
			key.physical_keycode = code
			key.pressed = true
			root.push_input(key, true)
			await process_frame
			check(game.run.finale_selected == (code == KEY_1), "Final operation keyboard alternative")
		if not game.run.finale_selected:
			quit(1)
			return
		game.run.elapsed = 540
		game.run._tick_finale()
		var boss: Dictionary = game.run.final_commander()
		boss.pos = game.run.player + Vector2(100, 95)
		game.run.branch_id = "focus"
		game._update_hud()
		await snapshot(game, "%dx%d-final-shields" % [dimensions.x, dimensions.y])
		game.run._hit_enemy(boss, 100000, 0)
		game.run._hit_enemy(boss, 100000, 1)
		boss.env_vulnerable = 3.0
		await snapshot(game, "%dx%d-final-core" % [dimensions.x, dimensions.y])
		check(float(boss.weakpoint) > 0.0, "Core visible after attachment destruction")
	game.touch_mode = false
	DisplayServer.window_set_size(Vector2i(1600, 900))
	await process_frame
	game.tech_page = 2
	game.codex_tab = "tech"
	game._open_arsenal("pause")
	await snapshot(game, "combat-codex")
	game.run.elapsed = 575
	game.run._hit_enemy(game.run.final_commander(), 100000)
	game.run._finish_deaths()
	game.run._finish_run("combat")
	game.run.evolutions.assign(GameContent.EVOLUTION_IDS)
	game.saved_result = true
	game._show_result()
	await snapshot(game, "final-success-result")
	for child in game.ui.get_children():
		if child is Label and child.text.begins_with("지휘체 "):
			check(child.position.y + child.size.y <= 512, "All evolutions and final result stay above record panel")
	check(game.run.state == "won" and game.run.finale_status == "success", "Result preserves final success and breakthrough")
	game.sound.stop_all()
	game.queue_free()
	await process_frame
	print("COMBAT UI SELF-CHECK: %d / %d assertions passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)
