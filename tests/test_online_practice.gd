extends SceneTree

func _init() -> void:
	call_deferred("check_practice")

func check_practice() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	var path := "user://online-practice-test-%d.json" % OS.get_process_id()
	game.records = SaveStore.new()
	game.records.load_data(path)
	game.ghost_race = preload("res://scripts/online_replay.gd").new()
	game.add_child(game.ghost_race)
	game.run.reset(123, "cataclysm", "striker", "ring")
	game.run.score = 556
	game.run.elapsed = 17.0
	game.run.state = "lost"
	game._show_result()
	assert(game.screen == "online_practice_result")
	assert(game.records.data.runs == 0)
	assert(game.records.data.best_score == 0)
	assert(game.records.data.total_kills == 0)
	assert(game.records.data.recent_runs.is_empty())
	assert(game.records.data.leaderboard.is_empty())
	assert(game.records.data.online_records.is_empty())
	assert(not FileAccess.file_exists(path), "practice must not write a profile or publish a result")
	game.sound.stop_all()
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	game = null
	print("ONLINE PRACTICE SELF-CHECK: 8 assertions passed")
	call_deferred("quit")
