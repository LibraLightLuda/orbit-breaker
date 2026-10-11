extends SceneTree

var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _init() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var model := RunModel.new()
	model.reset(17)
	var ghost := GhostReplay.new()
	ghost.capture(model)
	for i: int in range(20):
		model.step(0.05, Vector2.RIGHT, false)
		ghost.capture(model)
	ghost.capture(model, true)
	check(GhostReplay.valid(ghost.frames), "recorded ghost validates")
	check(ghost.frames.size() >= 5 and ghost.frames.size() <= 7, "ghost samples combat time at five Hz")
	check(float(GhostReplay.sample(ghost.frames, 0.5)[1]) > RunModel.ARENA.get_center().x, "ghost interpolates recorded movement")
	check(GhostReplay.sample(ghost.frames, 600)[1] == ghost.frames.back()[1], "seeking past end clamps")
	var bad := ghost.frames.duplicate(true)
	bad[1][0] = bad[0][0]
	check(not GhostReplay.valid(bad), "reject non-monotonic ghost")
	bad = ghost.frames.duplicate(true)
	bad[1][1] = INF
	check(not GhostReplay.valid(bad), "reject nonfinite ghost")
	check(not GhostReplay.valid({}) and not GhostReplay.valid([[0]]), "reject malformed ghost")
	var count := ghost.frames.size()
	model.state = "upgrade"
	model.step(1, Vector2.RIGHT, true)
	ghost.capture(model)
	check(ghost.frames.size() == count, "upgrade pauses ghost recording")
	var store := SaveStore.new()
	var path := "user://progression_test_%d.json" % Time.get_ticks_usec()
	store.load_data(path)
	check(store.available_modes() == ["normal", "relaxed"], "advanced difficulty starts locked")
	var details := {"name": "루다", "mode": "relaxed", "kills": 100, "dashes": 10, "combo": 30, "returns": 1, "ghost_frames": ghost.frames, "upgrades": {"frost": 3}}
	check(store.record_run(200, 301, true, details), "record with ghost saves")
	check(not "veteran" in store.available_modes(), "relaxed win does not unlock veteran")
	check("runs_0" in store.data.achievements and "frost" in store.data.achievements and "returns_0" in store.data.achievements, "cumulative and style achievements unlock")
	check(Achievements.points(store.data.achievements) > 0, "achievements award permanent points")
	var points := Achievements.points(store.data.achievements)
	check(store.record_run(100, 1, false, {"name": "루다", "mode": "relaxed"}), "lower score still counts a run")
	check(store.data.leaderboard.size() == 1 and store.data.leaderboard[0].score == 200, "personal best is not replaced by lower score")
	check(Achievements.points(store.data.achievements) == points, "repeat achievement cannot award points twice")
	var loaded_ghost := store.load_ghost(store.data.leaderboard[0])
	check(GhostReplay.valid(loaded_ghost) and loaded_ghost.size() == ghost.frames.size() and is_equal_approx(float(loaded_ghost.back()[1]), float(ghost.frames.back()[1])), "ranked player ghost round-trips")
	details.mode = "normal"
	check(store.record_run(300, 301, true, details), "normal win saves")
	check("veteran" in store.available_modes() and not "cataclysm" in store.available_modes(), "normal unlocks veteran only")
	details.mode = "veteran"
	store.record_run(400, 301, true, details)
	check("cataclysm" in store.available_modes(), "veteran unlocks cataclysm")
	var reloaded := SaveStore.new()
	reloaded.load_data(path)
	check(reloaded.data.achievements == store.data.achievements and reloaded.available_modes() == store.available_modes(), "progress survives restart")
	check(reloaded.new_achievements.is_empty(), "loading does not reannounce unlocks")
	for i: int in range(12):
		store.record_run(1000 + i, 20 + i, false, {"name": "파일럿%d" % i})
	var board: Array = store.data.leaderboard.filter(func(e: Dictionary) -> bool: return e.mode == "normal")
	check(board.size() == 10 and board[0].score == 1011 and board[9].score == 1002, "per difficulty ranking keeps ten highest names")
	check(SaveStore.clean_name("  \n \t ") == "파일럿" and SaveStore.clean_name("가".repeat(30)).length() == 16, "names normalize and are bounded")
	check(store._ghost_id("../../records_v2.json").is_empty(), "ghost path traversal is rejected")
	var failed := SaveStore.new()
	failed.load_data("user://missing_%d/records.json" % Time.get_ticks_usec())
	check(not failed.record_run(100, 20, false) and failed.data.runs == 0, "failed save rolls back progression")
	for mode: String in ["normal", "veteran", "cataclysm"]:
		model.reset(2, mode)
		model.score = 100
		check(model.ranked_score() == int(100 * float(GameContent.mode_info(mode).score)), "difficulty score multiplier " + mode)
		var enemy := model.spawn_enemy("chaser", model.player + Vector2(300, 0))
		check(is_equal_approx(float(enemy.hp), 23.0 * float(GameContent.mode_info(mode).health)), "difficulty health multiplier " + mode)
	model.reset(2)
	model.player.x = RunModel.ARENA.end.x + 100
	var old := model.player
	model.step(0.05, Vector2.RIGHT, false)
	check(model.player.x > old.x, "ship can travel well beyond old screen edge")
	model.player.x = RunModel.ARENA.end.x + 600
	old = model.player
	model.step(0.05, Vector2.RIGHT, true)
	check(model.player.x < old.x, "deep current overcomes outward dash without wall clamp")
	model.player = RunModel.ARENA.get_center()
	check(model.boundary_current(model.player) == Vector2.ZERO, "safe area has no added current")
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.records.load_data(path)
	game.sound.set_muted(true)
	game.records_tab = "ranking"
	game._show_records()
	check(game.screen == "records", "ranking screen opens")
	await snapshot(game, "19-ranking")
	var entry: Dictionary = game.records.data.leaderboard.filter(func(e: Dictionary) -> bool: return e.mode == "veteran")[0]
	var runs: int = game.records.data.runs
	game._show_replay(entry)
	check(game.screen == "replay", "ranked ghost can be opened")
	game._physics_process(0.25)
	check(game.replay_time > 0 and game.records.data.runs == runs, "spectator playback cannot create a run")
	await snapshot(game, "20-ghost")
	game.replay_paused = true
	var clock: float = game.replay_time
	game._physics_process(0.25)
	check(game.replay_time == clock, "replay pause freezes time")
	game.replay_slider.value = 0.5
	check(game.replay_time == 0.5, "replay timeline seeks")
	game.records_tab = "missions"
	game.achievement_page = 5
	game._show_records()
	await snapshot(game, "21-style-achievements")
	game.run.reset(2)
	game.run.player.x += 1000
	game.camera_offset = game._camera_target(game.run.player)
	check(game.camera_offset.x > 700 and game._mouse_direction(game.run.player - game.camera_offset + Vector2(100, 0)) == Vector2.RIGHT, "camera tracks world and cursor direction stays correct")
	game.mode = "cataclysm"
	game.records.data.cleared_modes = []
	game._start_run()
	check(game.run.mode == "normal", "start gate rejects locked difficulty")
	game.mode = "veteran"
	game.records.data.cleared_modes = ["normal"]
	game._show_hangar()
	await snapshot(game, "22-unlocked-difficulty")
	game.queue_free()
	await process_frame
	print("PROGRESSION SELF-CHECK: %d / %d assertions passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)

func snapshot(game: Node2D, label: String) -> void:
	game.queue_redraw()
	await process_frame
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var folder := "res://artifacts/candidate/small" if "--capture-small" in OS.get_cmdline_user_args() else "res://artifacts/candidate"
		DirAccess.make_dir_recursive_absolute(folder)
		check(root.get_texture().get_image().save_png(folder + "/" + label + ".png") == OK, "capture " + label)
