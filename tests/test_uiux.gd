extends SceneTree

var game: Node2D
var checks := 0
var failures := 0
var stage := 0
var folder := "res://artifacts/candidate/uiux/stage0"

func _init() -> void:
	call_deferred("run_checks")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("UIUX: " + message)

func shot(label: String) -> void:
	game.queue_redraw()
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(folder + "/" + label + ".png") == OK, label + " capture")

func run_checks() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="):
			stage = int(arg.trim_prefix("--stage="))
	folder = "res://artifacts/candidate/uiux/stage%d" % stage
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			folder = arg.trim_prefix("--output=")
	var baseline := "--baseline" in OS.get_cmdline_user_args()
	if baseline:
		folder += "-timing-corrected"
	DirAccess.make_dir_recursive_absolute(folder)
	game = load("res://main.tscn").instantiate()
	if baseline:
		game.set_script(load("res://.cleanup-archive/uiux-source-3.12/main.gd"))
	root.add_child(game)
	game.set_physics_process(false)
	game.records.load_data("user://uiux_test_%d.json" % Time.get_ticks_usec())
	game.sound.set_muted(true)
	await process_frame
	game._show_menu()
	await shot("title")
	game._show_hangar()
	await shot("hangar")
	game._start_run()
	for id in GameContent.SHIP_IDS:
		game.run.reset(381, "normal", id, "storm")
		game.run.elapsed = 245.0
		game.run.spawn_enemy("boss", game.run.player + Vector2(260, -160))
		for i in 40:
			game.run.spawn_enemy(["chaser", "runner", "tank", "shooter"][i % 4], game.run.player + Vector2.from_angle(i * 2.39996) * (85 + i * 7))
		game._resume()
		await shot("combat-" + id)
	if not baseline:
		game.run.reset(94)
		game.run.boss_spawned = true
		game.run._elite_stage = 2
		for time: float in [330.0, 385.0]:
			game.run.elapsed = time
			game.run.state = "playing"
			game.run.step(0.01, Vector2.ZERO, false)
		var strong_index := 0
		for enemy: Dictionary in game.run.enemies:
			if enemy.kind in ["boss", "elite"]:
				enemy.pos = game.run.player + Vector2.from_angle(0.8 + strong_index * PI * 0.5) * 280.0
				strong_index += 1
		check(strong_index == 4, "late combat shows two bosses and both elite variants")
		game._resume()
		await shot("combat-late-reinforcements")
		game._show_pause()
		await shot("mission-pause-details")
	game.records.data.reduced_motion = true
	game.run.player += Vector2(700, 0)
	game._resume()
	await shot("reduced-boundary")
	game.records.data.reduced_motion = false
	game.run.reset(41)
	game.run.level = 7
	game.run.upgrades = {"power": 2, "rapid": 2, "orbit": 3}
	game.run.state = "upgrade"
	game._show_upgrades()
	await shot("upgrades")
	game.codex_tab = "weapons"
	game._open_arsenal("pause")
	await shot("weapons")
	game.codex_tab = "items"
	game._open_arsenal("menu")
	await shot("items-unknown")
	game.records.data.discovered_items.assign(ItemCatalog.IDS)
	game._open_arsenal("menu")
	await shot("items-known")
	game.codex_tab = "tech"
	game._open_arsenal("pause")
	await shot("tech")
	game._show_records()
	await shot("achievements")
	game.saved_result = true
	game.run.state = "lost"
	game._show_result()
	await shot("result")
	game._show_settings()
	await shot("settings")
	game._show_help()
	await shot("help")
	if stage > 0:
		await feature_checks()
	await benchmark()
	game.queue_free()
	await process_frame
	await process_frame
	print("UIUX SELF-CHECK: %d / %d assertions passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)

func feature_checks() -> void:
	game._start_run()
	game._show_pause()
	var before: float = game.run.elapsed
	game._physics_process(0.25)
	check(game.run.elapsed == before, "pause freezes combat")
	game._resume()
	check(not game.mouse_active and not game.dash_queued, "resume disarms UI click")
	if stage >= 2:
		var rng_before: int = game.run.rng.state
		var upgrades_before: Dictionary = game.run.upgrades.duplicate(true)
		var preview: String = game._upgrade_links("power")
		check(preview.contains("태양 고리") and preview.contains("관통 성창"), "all power evolution links")
		check(game.run.rng.state == rng_before and game.run.upgrades == upgrades_before, "preview is read-only")
		game.run.upgrades = {"power": 2, "orbit": 3}
		check(game._upgrade_links("power").contains("완성"), "choice completes evolution")
		game._show_upgrades()
		var selected_choices: Array = game.choices.duplicate(true)
		rng_before = game.run.rng.state
		game._refresh_menu_layout()
		check(game.choices == selected_choices and game.run.rng.state == rng_before, "resize cannot reroll choices")
	if stage >= 3:
		game._show_hangar()
		var cards := 0
		var locked := 0
		for child in game.ui.get_children():
			if child is Button and child.text.is_empty():
				cards += 1
			if child is Button and child.disabled:
				locked += 1
		check(cards == 6 and locked >= 2, "six loadout cards and locked difficulty")
		if DisplayServer.get_name() != "headless":
			root.min_size = Vector2i(1, 1)
			for dimensions in [Vector2i(390, 844), Vector2i(844, 390)]:
				root.size = dimensions
				await process_frame
				await process_frame
				game._show_hangar()
				await process_frame
				await process_frame
				var scroll: ScrollContainer = game.ui.get_node_or_null("CompactScroll")
				check(scroll == null and game.ui.has_meta("fitted_menu"), "hangar fits without scroll %s" % dimensions)
				await shot("hangar-%dx%d" % [dimensions.x, dimensions.y])
				if scroll != null:
					scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
					await shot("hangar-bottom-%dx%d" % [dimensions.x, dimensions.y])
				for menu in ["_show_menu", "_show_settings", "_show_records", "_show_upgrades"]:
					if menu=="_show_upgrades": game.run.state="upgrade"
					game.call(menu)
					await process_frame
					await process_frame
					check(_compact_fits(game.ui), "compact text and targets " + menu)
					if menu=="_show_upgrades": check(game.choices.size()==3,"compact upgrades have real choices")
					await shot(menu.trim_prefix("_show_") + "-%dx%d" % [dimensions.x, dimensions.y])
				for tab in ["items", "weapons", "tech"]:
					game.codex_tab = tab
					game._open_arsenal("pause")
					await process_frame
					await process_frame
					check(_compact_fits(game.ui), "compact codex " + tab)
					await shot(tab + "-%dx%d" % [dimensions.x, dimensions.y])
				game._show_hangar()
				await process_frame
				await process_frame
				var launch: Button
				for button in game.ui.find_children("*", "Button", true, false):
					if button.text.begins_with("출격하기"):
						launch = button
				launch.grab_focus()
				await process_frame
				await process_frame
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				click.position = launch.get_global_transform_with_canvas() * (launch.size * 0.5)
				click.pressed = true
				root.push_input(click, true)
				click.pressed = false
				root.push_input(click, true)
				await process_frame
				check(game.screen == "playing" and not game.dash_queued, "compact launch click consumed")
			root.size = Vector2i(1600, 900)
			await process_frame
			await process_frame
	if stage >= 4:
		game.records_tab = "missions"
		game.achievement_page = 2
		game._show_records()
		check(game.achievement_page == 2 and Achievements.catalog().size() == 61, "achievement structure preserved")
		game.records.data.discovered_items.clear()
		game._show_item_detail("power")
		check(not _text(game.ui).contains(ItemCatalog.info("power").description), "unknown detail hides effects")
		await shot("item-detail-unknown")
		game.records.data.discovered_items.assign(ItemCatalog.IDS)
		game._show_item_detail("power")
		check(_text(game.ui).contains(ItemCatalog.info("power", "A").description), "detail shows highest grade")
		await shot("item-detail-known")

func _text(node: Node) -> String:
	var result: String = node.text if node is Label else ""
	for child in node.get_children():
		result += _text(child)
	return result

func _compact_fits(node: Node) -> bool:
	for child in node.get_children():
		if child is Label and child.is_visible_in_tree() and child.get_parent() is Control:
			if child.position.x + child.size.x > child.get_parent().size.x + 1 or child.get_theme_font_size("font_size") < (10 if game.ui.has_meta("fitted_menu") else 18):
				push_error("Compact overflow: " + child.text)
				return false
		if child is Button and child.is_visible_in_tree() and child.size.y < (36 if game.ui.has_meta("fitted_menu") else 44):
			return false
		if not _compact_fits(child):
			return false
	return true

func benchmark() -> void:
	game.run.reset(380)
	game.run.elapsed = 380
	game.run.upgrades = {"orbit": 5, "power": 5, "rapid": 5, "missile": 5, "chain": 5, "pulse": 5, "repair": 5}
	for i in 240:
		game.run.spawn_enemy("tank", game.run.player + Vector2.from_angle(i * 2.39996) * (90.0 + i * 2.0))
	for i in 240:
		game.run.shots.append({"pos": game.run.player + Vector2.from_angle(i) * (i + 20), "velocity": Vector2.RIGHT * 590, "friendly": i % 2 == 0, "radius": 5.0, "damage": 1.0, "ttl": 1.45})
	for i in 300:
		game.run.gems.append({"pos": game.run.player + Vector2.from_angle(i) * (i + 30), "kind": "xp", "value": 1.0})
	game._resume()
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var samples: Array[int] = []
	for i in 240:
		var started := Time.get_ticks_usec()
		game.queue_redraw()
		await RenderingServer.frame_post_draw
		if i >= 60:
			samples.append(Time.get_ticks_usec() - started)
	samples.sort()
	var result := {"samples": samples.size(), "p95_ms": samples[170] / 1000.0, "median_ms": samples[90] / 1000.0, "max_ms": samples.back() / 1000.0, "renderer": RenderingServer.get_video_adapter_name(), "window": str(DisplayServer.window_get_size()), "note": "static identical 240 enemies / 240 shots / 300 gems; rendering only, model benchmark separate"}
	var file := FileAccess.open(folder + "/render-performance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	print("UIUX RENDER PERFORMANCE: " + JSON.stringify(result))
