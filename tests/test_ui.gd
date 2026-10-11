extends SceneTree

var checks := 0
var failures := 0
var game: Node2D
var capture := false

func _init() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAILED: " + message)

func run_checks() -> void:
	capture = "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless"
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	# Isolate smoke-test records from the player's real save.
	game.records.load_data("user://test_ui_%d.json" % Time.get_ticks_usec())
	game.sound.set_muted(true)
	await process_frame
	check(game.screen == "menu", "title screen loads")
	check(root.gui_get_focus_owner() is Button, "menu supports keyboard focus")
	await snapshot("01-title")
	game._show_hangar()
	check(game.screen == "hangar", "launch bay opens")
	var selectable: Array[Button] = []
	for child in game.ui.get_children():
		if child is Button and child.text == "":
			selectable.append(child)
	check(selectable.size() == 6, "three ships and three sectors selectable")
	selectable[1].pressed.emit()
	check(game.selected_ship == "scout", "ship card callback chooses correct ship")
	selectable.clear()
	for child in game.ui.get_children():
		if child is Button and child.text == "":
			selectable.append(child)
	selectable[5].pressed.emit()
	check(game.selected_sector == "forge", "sector card callback chooses correct sector")
	await snapshot("09-hangar")
	var card_text_fits := true
	for card in game.ui.get_children():
		if card is Button:
			for label in card.get_children():
				if label is Label and label.position.x + label.size.x > card.size.x:
					card_text_fits = false
	check(card_text_fits, "wrapped launch descriptions stay inside cards")
	game._start_run()
	check(game.run.ship_id == "scout" and game.run.sector_id == "forge" and game.run.hp == 80, "loadout reaches run")
	game._show_records()
	check(game.screen == "records", "missions screen")
	await snapshot("10-missions")
	game._open_arsenal("menu")
	check(game.screen == "arsenal", "evolution guide accessible from menu")
	await snapshot("11-arsenal")
	game._close_arsenal()
	check(game.screen == "menu", "menu guide returns to menu")
	game.selected_ship = "striker"
	game.selected_sector = "ring"
	game._show_help()
	check(game.screen == "help", "help screen")
	await snapshot("02-help")
	game._show_settings()
	check(game.screen == "settings", "settings screen")
	game._show_credits()
	check(game.screen == "credits", "engine licenses accessible")
	game._start_run()
	check(game.screen == "playing" and game.run.hp == 100, "start normal run")
	check(game._mouse_direction(game.run.player + Vector2(100, 0)) == Vector2.RIGHT, "mouse steers toward cursor")
	check(game._mouse_direction(game.run.player + Vector2(4, 0)) == Vector2.ZERO, "cursor deadzone stops jitter")
	check(not game._mouse_direction(Vector2(20, 20)).is_zero_approx(), "cursor outside arena continues steering")
	check(game._mouse_direction(Vector2(1500, game.run.player.y)) == Vector2.RIGHT, "cursor outside screen continues steering")
	check(game.hud.vital_detail.text.contains("+1.00") and game.hud.vital_detail.text.contains("-0.25"), "HUD shows baseline regeneration and decay")
	check(game.hud.vitals.get_theme_color("font_color") == game.LIME and game.net_gauge > 0.0, "net recovery uses green positive gauge")
	check(game._speed_color(0.0).is_equal_approx(game.CORAL) and game._speed_color(1.0).is_equal_approx(game.SPEED_BLUE), "speed colors range from red to blue")
	check(game._speed_color(0.5).r > game.SPEED_BLUE.r and game._speed_color(0.5).b > game.CORAL.b, "intermediate speed blends the colors")
	var pointer := InputEventMouseMotion.new()
	pointer.position = game.run.player + Vector2(120, 0)
	pointer.global_position = pointer.position
	root.push_input(pointer, true)
	await process_frame
	check(game.mouse_active, "pointer event activates mouse movement")
	var mouse_start: Vector2 = game.run.player
	game._physics_process(1.0 / 60.0)
	check(game.run.player.x > mouse_start.x, "mouse event moves ship without keyboard")
	Input.action_press("move_left")
	check(game._movement_direction().x < 0, "keyboard overrides cursor direction")
	Input.action_release("move_left")
	game.mouse_active = false
	check(game.space_time > 0 and not game.space_offset.is_zero_approx(), "background drifts with play and movement")
	var space_before: float = game.space_time
	game.records.data.reduced_motion = true
	game._physics_process(1.0 / 60.0)
	check(game.space_time == space_before, "reduced motion freezes space drift")
	game.records.data.reduced_motion = false
	root.mouse_exited.emit()
	check(game.mouse_active == false and game.mouse_outside, "window exit preserves steering activation state")
	game.mouse_active = true
	root.mouse_exited.emit()
	check(game.mouse_active, "window exit does not deactivate active mouse steering")
	root.mouse_entered.emit()
	game.mouse_active = false
	var start: Vector2 = game.run.player
	Input.action_press("move_right")
	game._physics_process(1.0 / 60.0)
	Input.action_release("move_right")
	check(game.run.player.x > start.x, "movement input reaches simulation")
	var dash := InputEventKey.new()
	dash.physical_keycode = KEY_SPACE
	dash.pressed = true
	game._unhandled_key_input(dash)
	game._physics_process(1.0 / 60.0)
	check(game.run.dash_time > 0, "space triggers dash")
	game.run.dash_time = 0.0
	game.run.dash_cooldown = 0.0
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = game.run.player
	click.pressed = true
	root.push_input(click, true)
	await process_frame
	check(game.dash_queued, "left click queues dash through viewport")
	var drift_before: Vector2 = game.space_offset
	game._physics_process(1.0 / 60.0)
	check(game.run.dash_time > 0.0 and not game.dash_queued, "left click triggers dash once")
	check(game.space_offset.distance_to(drift_before) < 0.8 and game.space_velocity.length() <= 43.21, "dash background drift is smoothed and bounded")
	click.pressed = false
	root.push_input(click, true)
	await process_frame
	check(not game.dash_queued, "mouse release does not trigger dash")
	game.run.overdrive_meter = 100.0
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	root.push_input(click, true)
	await process_frame
	check(game.run.overdrive_time > 0.0 and game.run.overdrive_meter == 0.0, "right click activates charged overdrive")
	click.pressed = false
	root.push_input(click, true)
	game.run.overdrive_time = 0.0
	game.run.overdrive_meter = 100.0
	var overdrive := InputEventKey.new()
	overdrive.physical_keycode = KEY_E
	overdrive.pressed = true
	Input.parse_input_event(overdrive)
	await process_frame
	check(game.run.overdrive_time > 0, "E input event reaches overdrive")
	var tab_key := InputEventKey.new()
	tab_key.physical_keycode = KEY_TAB
	tab_key.pressed = true
	Input.parse_input_event(tab_key)
	await process_frame
	check(game.screen == "arsenal", "Tab input opens combat guide")
	var guide_time: float = game.run.elapsed
	game._physics_process(0.05)
	check(game.run.elapsed == guide_time, "arsenal pauses combat")
	game._close_arsenal()
	check(game.screen == "playing", "arsenal resumes combat")
	game._show_pause()
	var paused_time: float = game.run.elapsed
	space_before = game.space_time
	game._physics_process(0.05)
	check(game.screen == "pause" and game.run.elapsed == paused_time, "pause freezes simulation")
	check(game.space_time == space_before, "pause freezes space drift")
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(100, 600)
	click.pressed = true
	root.push_input(click, true)
	await process_frame
	check(not game.dash_queued, "pause clicks cannot trigger dash")
	click.pressed = false
	root.push_input(click, true)
	await snapshot("03-pause")
	game._resume()
	check(not game.mouse_active, "resuming requires fresh cursor movement")
	await process_frame
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(1190, 50)
	click.pressed = true
	root.push_input(click, true)
	click.pressed = false
	root.push_input(click, true)
	await process_frame
	check(game.screen == "pause" and not game.dash_queued, "pause button consumes click without triggering dash")
	game._resume()
	game.run.reset(631, "normal")
	game.run.elapsed = 98
	game.run.level = 6
	game.run.upgrades = {"power": 2, "orbit": 2}
	game.run.orbit_count = 5
	for i in range(20):
		var kind: String = ["chaser", "runner", "tank", "shooter"][i % 4]
		game.run.spawn_enemy(kind, Vector2(170 + (i * 179) % 940, 170 + (i * 73) % 430))
	for i in range(14):
		game.run.gems.append({"pos": Vector2(380 + i * 27, 500 + sin(i) * 32), "value": 1.0, "kind": "xp"})
	game.toast_time = 0
	for i in range(25):
		game.run.step(1.0 / 60.0, Vector2.RIGHT, false)
	game._update_hud()
	await snapshot("04-gameplay")
	game.run.xp = game.run.xp_needed
	game._physics_process(1.0 / 60.0)
	check(game.screen == "upgrade" and game.choices.size() == 3, "experience opens three cards")
	await snapshot("05-upgrades")
	var upgrade_time: float = game.run.elapsed
	game._physics_process(0.05)
	check(game.run.elapsed == upgrade_time, "upgrade selection freezes time")
	var upgrade_button: Button
	for child in game.ui.get_children():
		if child is Button:
			upgrade_button = child
			break
	click.position = upgrade_button.get_global_rect().get_center()
	click.pressed = true
	root.push_input(click, true)
	click.pressed = false
	root.push_input(click, true)
	await process_frame
	check(game.screen == "playing", "upgrade selection returns to combat")
	check(not game.dash_queued and not game.mouse_active, "upgrade click cannot trigger dash or cursor movement")
	game.run.elapsed = 245
	game.run.spawn_enemy("boss", Vector2(900, 350))
	game._update_hud()
	await snapshot("06-boss")
	game.run.reset(91, "normal", "bastion", "storm")
	game.run.elapsed = 185
	game.run.level = 14
	game.run.upgrades = {"chain": 3, "rapid": 2, "missile": 2, "pulse": 2, "orbit": 3, "power": 2, "blade": 2, "frost": 3, "orbit_range": 2, "repair": 3}
	game.run.orbit_radius = 119.0
	game.run.orbit_count = 7
	game.run._check_evolutions()
	game.run.overdrive_meter = 100
	game.run.activate_overdrive()
	game.run.spawn_enemy("elite", Vector2(800, 430))
	for i in range(12):
		game.run.spawn_enemy("tank" if i % 3 == 0 else "chaser", Vector2(460 + (i * 77) % 500, 180 + (i * 59) % 400))
	game.run._add_lane()
	for i in range(8):
		game.run.step(1.0 / 60.0, Vector2.ZERO, false)
	game.toast_time = 0
	game._resume()
	await snapshot("12-expanded-combat")
	check(game.run.evolutions.size() == 2 and not game.run.hazards.is_empty(), "expanded combat represented")
	game._open_arsenal("pause")
	await snapshot("13-build-guide")
	game._close_arsenal()
	game.run.elapsed = 360.0
	game.run.event_remaining = 0.0
	game.run.survival_cleared = true
	game.run.upgrades.repair = 5
	game._update_hud()
	check(game.hud.time.text.contains("10:00") and game.hud.vital_detail.text.contains("+7.25"), "overtime HUD shows limit and maximum regeneration")
	check(game.hud.vitals.get_theme_color("font_color") == game.CORAL, "net hull loss uses red warning color")
	await snapshot("15-overtime")
	game.run.player = Vector2(1830, 386)
	game.run.boundary_time = 3.0
	game.run.current_speed = game.run.base_speed() * game.run.movement_multiplier(game.run.player)
	game._resume()
	check(game.net_gauge < 0.0 and game.speed_gauge < 0.2 and game.hud.vital_detail.text.contains("외곽 -"), "boundary HUD includes damage and severe slowdown")
	await snapshot("16-boundary-warning")
	game.records.data.reduced_motion = true
	await snapshot("17-boundary-reduced-motion")
	game.records.data.reduced_motion = false
	game.run.player = game.ARENA.get_center()
	game.run.elapsed = 10.0
	game.run.upgrades.repair = 0
	game.run.current_speed = game.run.base_speed()
	game._resume()
	check(game.speed_gauge == 1.0 and game.hud.speed.get_theme_color("font_color").is_equal_approx(game.SPEED_BLUE), "full speed HUD is blue")
	await snapshot("18-full-speed-recovery")
	game.run.state = "lost"
	game._show_result()
	check(game.screen == "result" and game.saved_result, "defeat recorded")
	var records_before: int = game.records.data.runs
	game._show_result()
	check(game.records.data.runs == records_before, "result cannot double-save")
	await snapshot("07-result")
	check(game.records.data.recent_runs.size() == 1 and game.records.data.recent_runs[0].ship == "bastion", "result saves actual run loadout")
	check(game.records.newly_unlocked.has("evolved"), "evolution medal displayed on result")
	game.records_tab = "history"
	game._show_records()
	await snapshot("14-history")
	game.selected_ship = "striker"
	game.selected_sector = "ring"
	game._start_run()
	check(game.run.enemies.is_empty() and game.run.level == 1 and game.run.score == 0, "restart clears previous run")
	game.run.state = "won"
	game.run.score = 19250
	game.run.elapsed = 301
	game._show_result()
	check(game.records.data.wins == 1, "victory recorded")
	await snapshot("08-victory")
	game.queue_free()
	await process_frame
	await process_frame
	print("UI SELF-CHECK: %d / %d assertions passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)

func snapshot(label: String) -> void:
	game.queue_redraw()
	await process_frame
	if capture:
		await RenderingServer.frame_post_draw
		var folder := "res://artifacts/candidate/small" if "--capture-small" in OS.get_cmdline_user_args() else "res://artifacts/candidate"
		DirAccess.make_dir_recursive_absolute(folder)
		var error := root.get_texture().get_image().save_png(folder + "/" + label + ".png")
		check(error == OK, "screenshot saved: " + label)
