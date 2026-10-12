extends SceneTree

var game: Node2D
var checks := 0
var failures := 0
var folder := "D:/Antigravity/NewProject/artifacts/candidate/art/release-input"

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("RELEASE INPUT: "+message)
		quit(1)
		return
	print("RELEASE INPUT: "+message)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	event=InputEventKey.new()
	event.physical_keycode=code
	event.pressed=false
	Input.parse_input_event(event)

func capture(label: String) -> void:
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/"+label+".png")==OK,label+" capture")

func run_checks() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.records.load_data("user://art_release_input_%d.json" % Time.get_ticks_usec())
	game.sound.set_muted(true)
	await process_frame
	check(OS.get_name()=="Windows","Windows native input/render harness")
	print("INPUT HARNESS EXECUTABLE: "+OS.get_executable_path())
	await capture("title")
	game._show_hangar()
	await capture("hangar")
	game._start_run()
	check(game.screen=="playing","start run")
	Input.action_press("move_right")
	var start: Vector2=game.run.player
	for i in 10: await physics_frame
	check(game.run.player.x>start.x+5,"keyboard movement")
	await key(KEY_SPACE)
	for i in 2: await physics_frame
	check(game.run.dash_time>0,"Space dash")
	Input.action_release("move_right")
	await capture("combat-dash")
	await key(KEY_ESCAPE)
	check(game.screen=="pause","Escape pauses")
	var time: float=game.run.elapsed
	for i in 10: await physics_frame
	check(is_equal_approx(time,game.run.elapsed),"pause freezes model time")
	await capture("pause")
	await key(KEY_ESCAPE)
	check(game.screen=="playing","Escape resumes")
	await key(KEY_TAB)
	check(game.screen=="arsenal","Tab opens arsenal")
	await capture("arsenal")
	await key(KEY_ESCAPE)
	check(game.screen=="playing","arsenal returns to combat")
	if "--soak" in OS.get_cmdline_user_args(): await soak()
	print("RELEASE INPUT SELF-CHECK: %d / %d assertions passed" % [checks-failures,checks])
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)

func soak() -> void:
	Engine.max_fps=60
	var begin := Time.get_ticks_msec()
	for frame in 36000:
		await physics_frame
		if game.screen=="upgrade": game._pick_upgrade(0)
		elif game.screen=="pause": game._resume()
		elif game.screen=="result": game._start_run()
		if game.screen=="playing":
			var target := RunModel.CENTER+Vector2.from_angle(game.run.elapsed*0.45)*235
			var direction: Vector2=(target-game.run.player).normalized()
			for action: String in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
			Input.action_press("move_right" if direction.x>=0 else "move_left",absf(direction.x))
			Input.action_press("move_down" if direction.y>=0 else "move_up",absf(direction.y))
			if frame%240==0: await key(KEY_SPACE)
			if frame%300==0: await key(KEY_E)
		if frame%3600==0:
			print("SOAK: %d/36000 frames, state %s, elapsed %.1f, runs %d" % [frame,game.screen,game.run.elapsed,game.records.data.runs])
			await capture("soak-%02d" % (frame/3600))
	for action: String in ["move_left","move_right","move_up","move_down"]: Input.action_release(action)
	check(Time.get_ticks_msec()-begin>=590000,"ten minute real-time render soak")
	check(game.records.data.runs>0,"natural completed runs saved in isolated test profile")
	var replayed := false
	for entry: Dictionary in game.records.data.leaderboard:
		if game.records.load_ghost(entry).is_empty(): continue
		game._show_replay(entry)
		check(game.screen=="replay","natural run ghost opens")
		for speed: float in [1.0,2.0,4.0]:
			game.replay_speed=speed
			game.replay_paused=false
			for i in 90: await physics_frame
			await capture("replay-%dx" % speed)
		game.replay_slider.value=float(game.replay_frames.back()[0])*0.5
		game.replay_paused=true
		await capture("replay-seek-paused")
		var legacy: Array=[]
		for frame: Array in game.replay_frames: legacy.append(frame.slice(0,13))
		check(GhostReplay.valid(legacy),"legacy thirteen-field path remains valid")
		game.replay_frames=legacy
		await capture("replay-legacy-path")
		replayed=true
		break
	check(replayed,"recorded world ghost rendered at 1x/2x/4x and seek")
