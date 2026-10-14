extends SceneTree

var checks := 0
var failures := 0
var paths: Array[String] = []
var base := "user://feedback317-%d/" % Time.get_ticks_usec()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _init() -> void:
	call_deferred("run_checks")

func fixture() -> RunModel:
	var model := RunModel.new()
	model.reset(317)
	model._spawn_timer = 10000
	model._shot_timer = 10000
	model._hazard_timer = 10000
	model._encounter_timer = 10000
	return model

func write_file(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()
	paths.append(path)

func run_checks() -> void:
	DirAccess.make_dir_recursive_absolute(base)
	var source := base + "old.json"
	var destination := base + "profile/records_v2.json"
	var store := SaveStore.new()
	store.load_data(source)
	var ghost := GhostReplay.new()
	var model := fixture()
	ghost.capture(model)
	model.step(0.2, Vector2.RIGHT, false)
	ghost.capture(model, true)
	check(store.record_run(200, 20, false, {"name": "migration", "ghost_frames": ghost.frames}), "migration fixture writes ranking and ghost")
	check(store.record_run(100, 10, false), "migration fixture retains backup")
	var id: String = store.data.leaderboard[0].ghost
	var original := FileAccess.get_sha256(source)
	var backup := FileAccess.get_sha256(source + ".bak")
	var ghost_hash := FileAccess.get_sha256(store.ghost_path(id))
	var migrated := SaveStore.new()
	check(migrated._migrate_profile(destination, [source]), "first launch copies old profile")
	check(FileAccess.get_sha256(destination) == original and FileAccess.get_sha256(destination + ".bak") == backup, "ranking and last valid backup copy exactly")
	migrated.load_data(destination)
	check(migrated.data == store.data and GhostReplay.valid(migrated.load_ghost(migrated.data.leaderboard[0])), "settings, progress, ranking and ghost load after version-independent relocation")
	check(FileAccess.get_sha256(migrated.ghost_path(id)) == ghost_hash and FileAccess.get_sha256(source) == original, "ghost copy is exact and source is untouched")
	store.record_run(999, 30, false)
	check(migrated._migrate_profile(destination, [source]) and FileAccess.get_sha256(destination) == original, "later old-version runs cannot overwrite the new profile")
	write_file(base + "broken.json", "{")
	DirAccess.copy_absolute(source + ".bak", base + "broken.json.bak")
	var recovered := SaveStore.new()
	check(recovered._migrate_profile(base + "recovered.json", [base + "broken.json"]), "migration recovers a corrupt primary using its valid backup")
	check(FileAccess.get_sha256(base + "recovered.json") == FileAccess.get_sha256(base + "broken.json.bak") and FileAccess.get_file_as_string(base + "broken.json") == "{", "recovery preserves corrupt original for inspection")
	write_file(base + "blocked", "file blocks directory creation")
	var blocked := SaveStore.new()
	check(not blocked._migrate_profile(base + "blocked/records.json", [source]) and not blocked.storage_error.is_empty(), "unwritable migration stops instead of creating empty replacement records")
	check(not blocked.save_data() and FileAccess.get_sha256(source + ".bak") == original, "failed migration disables new writes and preserves the old data")
	var corrupt := SaveStore.new()
	write_file(base + "invalid-old.json", "{")
	check(not corrupt._migrate_profile(base + "invalid.json", [base + "invalid-old.json"]) and not FileAccess.file_exists(base + "invalid.json"), "unrecoverable old data cannot silently become a blank profile")
	var live := SaveStore.new()
	live.load_data(base + "live.json")
	live.data.total_kills = 90
	live.data.achievement_progress.dashes = 9
	var details := {"kills": 10, "dashes": 1, "elapsed": 180.0, "combo": 10, "upgrades": {"frost": 3}, "evolutions": [GameContent.EVOLUTION_IDS[0]]}
	check(live.record_live_achievements(details), "achievements save during combat")
	check("kills_0" in live.data.achievements and "dashes_0" in live.data.achievements and "time_0" in live.data.achievements and "frost" in live.data.achievements and "evolved" in live.data.achievements, "live thresholds combine previous progress and current run")
	var count: int = live.data.achievements.size()
	live.record_live_achievements(details)
	check(live.data.achievements.size() == count and live.data.total_kills == 90 and live.data.achievement_progress.dashes == 9, "live polling cannot duplicate awards or cumulative progress")
	check(live.record_run(100, 180, false, details) and live.data.total_kills == 100 and live.data.achievement_progress.dashes == 10, "result commits cumulative progress exactly once")
	var reloaded := SaveStore.new()
	reloaded.load_data(base + "live.json")
	check(reloaded.data.achievements == live.data.achievements, "live-earned achievements survive restart")
	var failed := SaveStore.new()
	failed.load_data(base + "missing/records.json")
	check(not failed.record_live_achievements({"elapsed": 180}) and failed.data.achievements.is_empty(), "failed live save rolls back the new award")
	await hud_checks()
	for path: String in [source, destination, base + "broken.json", base + "recovered.json", base + "live.json", base + "ui.json", base + "invalid.json"]:
		for suffix: String in ["", ".bak", ".tmp", ".bak.tmp", ".ghost-" + id + ".json"]:
			paths.append(path + suffix)
	for path: String in paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(base + "profile")
	DirAccess.remove_absolute(base)
	print("FEEDBACK317 SELF-CHECK: %d / %d assertions passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)

func hud_checks() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	if DisplayServer.get_name() != "headless":
		root.grab_focus()
		await create_timer(.05).timeout
	game.set_physics_process(false)
	game.sound.set_muted(true)
	game.records.load_data(base + "ui.json")
	game.records.data.achievements.append("runs_0")
	game._start_run()
	game.run = fixture()
	game._resume()
	game._collect_progress_notices()
	check(game.notices.is_empty(), "previously unlocked progress is not reannounced")
	game.records.data.achievements.append("kills_0")
	game.records.data.discovered_items.append("heal")
	game.run.evolutions.append(GameContent.EVOLUTION_IDS[0])
	game.run.parts = {"core": 1, "drive": 1, "shell": 1}
	game.run.hull_forms.append("lancer")
	game._collect_progress_notices()
	check(game.notices.any(func(n: Dictionary) -> bool: return n.title == "업적 달성") and game.notices.any(func(n: Dictionary) -> bool: return n.title == "도감 해금"), "achievement and codex events enter upper-right queue")
	check(game.notices.any(func(n: Dictionary) -> bool: return n.title == "무기 진화") and game.notices.any(func(n: Dictionary) -> bool: return n.title == "기체 진화"), "weapon and hull evolution enter the same queue")
	var count: int = game.notices.size()
	game._collect_progress_notices()
	check(game.notices.size() == count, "each event is announced only once")
	game.run.parts = {"core": 2, "drive": 2, "shell": 2}
	game._collect_progress_notices()
	check(game.notices.size() == count + 1 and game.notices.back().name.ends_with("II"), "second hull rank gets its own evolution cue")
	game.run.player = RunModel.CENTER + Vector2(700, 0)
	game.camera_offset = game._camera_target(game.run.player)
	game.run._grant_xp(2)
	game.run._risk_feedback("risk_score", 160)
	var score: Dictionary = game._reward_feedback(game.run, "risk_score")
	var xp: Dictionary = game._reward_feedback(game.run, "risk_xp")
	game.run.effects.clear()
	check(game._reward_feedback(game.run, "risk_score") == score and game._reward_feedback(game.run, "risk_xp") == xp, "both gain values remain after transient effects expire")
	var replay := fixture()
	check(game._reward_feedback(replay, "risk_score").is_empty(), "spectator seeking never inherits live reward history")
	var pause: Button
	for node: Node in game.ui.get_children():
		if node is Button and node.text == "Ⅱ":
			pause = node
	check(pause != null and pause.size == Vector2(28, 28) and pause.focus_mode == Control.FOCUS_NONE, "pause stays a compact icon with its actual minimum size")
	check(game.HUD_ALPHA <= 0.12 and pause.get_theme_stylebox("normal").bg_color.a < 0.13, "top HUD and pause backgrounds are faint")
	for reduced: bool in [false, true]:
		game.records.data.reduced_motion = reduced
		game._update_hud()
		game.queue_redraw()
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var capture := root.get_texture().get_image()
			var scale := float(capture.get_width()) / 1280.0
			var visible_symbol_pixels := 0
			for y in range(int(71 * scale), int(99 * scale)):
				for x in range(int(902 * scale), int(930 * scale)):
					var pixel := capture.get_pixel(x, y)
					if pixel.r > 0.6 and pixel.get_luminance() > 0.35: visible_symbol_pixels += 1
			check(visible_symbol_pixels >= 24 * scale * scale, "queued event symbol remains readable across its icon area")
			check(capture.get_pixel(int(895 * scale), int(131 * scale)).r > 0.8 and capture.get_pixel(int(895 * scale), int(163 * scale)).r > 0.8, "persistent reward lanes remain below the event in both motion modes")
			if "--capture" in OS.get_cmdline_user_args():
				DirAccess.make_dir_recursive_absolute("res://artifacts/candidate/feedback317")
				check(capture.save_png("res://artifacts/candidate/feedback317/%d-%s.png" % [capture.get_width(), "reduced" if reduced else "full"]) == OK, "save current HUD evidence")
	game.records.data.reduced_motion = true
	game.notices[0].ttl = 0.01
	game.run = fixture()
	game._hud_timer = 100
	game._physics_process(0.02)
	check(game.notices.size() == count, "queued notifications advance without hiding rewards")
	game.notices.clear()
	game._resume()
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_move_to_foreground()
		for frame in 8:
			await process_frame
		check(root.has_focus(), "native cursor fixture owns window focus before the dash")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game.get_global_transform_with_canvas() * (game.run.player + Vector2(400, 0))
	game._unhandled_input(click)
	var native_end_distance := -1.0
	for frame in 16:
		game._physics_process(1.0 / 60.0)
		if DisplayServer.get_name() != "headless" and game.dash_cursor_anchor and native_end_distance < 0:
			var endpoint: Vector2 = root.get_final_transform() * game.dash_cursor_position + Vector2(DisplayServer.window_get_position())
			# Observe the OS acknowledgement; a rendered frame can precede cursor dispatch.
			var deadline := Time.get_ticks_msec() + 500
			while Time.get_ticks_msec() < deadline:
				await process_frame
				native_end_distance = Vector2(DisplayServer.mouse_get_position()).distance_to(endpoint)
				if native_end_distance < 3.0: break
			print("DASH CURSOR: expected=%s OS=%s error=%.3fpx focus=%s screen=%s" % [endpoint, DisplayServer.mouse_get_position(), native_end_distance, root.has_focus(), game.screen])
	check(game.dash_cursor_anchor and not game.mouse_active and not game.click_dash_active, "left-click dash anchors the cursor at actual completion")
	check(game.dash_cursor_position.distance_to(game.get_global_transform_with_canvas() * (game.run.player - game.camera_offset)) < 0.1, "cursor endpoint includes current camera and viewport transforms")
	var end: Vector2 = game.run.player
	for frame in 15:
		game._physics_process(1.0 / 60.0)
	check(game.run.player.distance_to(end) < 0.1, "old cursor cannot pull ship back after dash")
	if DisplayServer.get_name() != "headless":
		check(native_end_distance >= 0 and native_end_distance < 3.0, "native operating-system cursor reaches dash endpoint within screen-pixel rounding")
	var motion := InputEventMouseMotion.new()
	motion.position = game.dash_cursor_position
	game._input(motion)
	check(game.dash_cursor_anchor and not game.mouse_active, "synthetic warp event does not restart movement")
	motion.position += Vector2(60, 0)
	game._input(motion)
	check(not game.dash_cursor_anchor and game.mouse_active and game._movement_direction().x > 0, "real mouse motion resumes normal movement")
	game.run.dash_cooldown = 10
	game._unhandled_input(click)
	game._physics_process(1.0 / 60.0)
	check(not game.click_dash_active, "cooldown click cannot arm an endpoint warp")
	game.mouse_active = false
	game.run.dash_cooldown = 0
	game.dash_queued = true
	game.dash_aim = Vector2.RIGHT
	for frame in 16:
		game._physics_process(1.0 / 60.0)
	check(not game.dash_cursor_anchor, "keyboard dash preserves normal cursor behavior")
	game.queue_free()
	await process_frame
