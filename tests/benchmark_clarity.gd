extends "res://tests/test_art.gd"

func run_checks() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1600,900)
	root.content_scale_size = Vector2i(1280,720)
	root.grab_focus()
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.records.load_data("user://clarity_benchmark_%d.json" % Time.get_ticks_usec())
	game.records.data.reduced_motion = false
	game.sound.set_muted(true)
	game.touch_mode = false
	await process_frame
	await moving_benchmark()
	game.sound.stop_all()
	game.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	print("CLARITY BENCHMARK: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
