extends SceneTree

func _init() -> void:
	call_deferred("capture")

func capture() -> void:
	var game: Node2D=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.records.load_data("user://art_comparison_%d.json" % Time.get_ticks_usec())
	game.sound.set_muted(true)
	game.run.reset(7801,"normal","striker","ring")
	game.run.elapsed=260
	game.run.orbit_count=6
	for i in 24:
		game.run.spawn_enemy(["chaser","runner","tank","shooter"][i%4],game.run.player+Vector2.from_angle(i*2.399)*(140+i*11))
	game.run.spawn_enemy("boss",game.run.player+Vector2(290,-140))
	game._resume()
	game.queue_redraw()
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])==OK)
	game.queue_free()
	await process_frame
	quit()
