extends Node

var game: Node2D
var mixed := false

func _ready() -> void:
	mixed = "--mixed" in OS.get_cmdline_user_args()
	if OS.has_feature("web"): mixed = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('mixed')"))
	if not OS.has_feature("web"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps=0
	# main.tscn is one Node2D; attach the profiling subclass once to avoid orphaning its SoundBank.
	game=Node2D.new()
	game.set_script(load("res://qa_profile.gd"))
	add_child(game)
	game.set_physics_process(false)
	game.records.load_data("user://art_web_qa.json")
	game.sound.set_muted(true)
	await get_tree().process_frame
	if ("--touch" in OS.get_cmdline_user_args()) or (OS.has_feature("web") and bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('touch')"))):
		await touch_checks()
		return
	var results: Array=[]
	for trial in 3:
		game.ghost=GhostReplay.new()
		game.mouse_active=false
		game.run.reset(7801,"normal","bastion","storm")
		game.run.elapsed=260
		game.run.hp=1.0e9
		game.run.max_hp=1.0e9
		game.run._spawn_timer=1.0e6
		game.run.upgrades={"power":3,"rapid":3,"orbit":3,"blade":3,"frost":3,"missile":3,"chain":3,"pulse":3}
		game.run.orbit_count=6
		for i in 240:
			var enemy: Dictionary=game.run.spawn_enemy(["tank", "chaser", "runner", "shooter"][i % 4] if mixed else "tank",game.run.player+Vector2.from_angle(i*2.399)*(260+i*1.5))
			enemy.hp=1.0e9
			enemy.max_hp=1.0e9
		for kind: String in ["sentry","mine","wake"]:
			for i in (3 if kind=="sentry" else (8 if kind=="mine" else 6)):
				game.run._deploy(kind,game.run.player+Vector2.from_angle(i)*180,18,14)
		for i in 223:
			game.run.shots.append({"pos":game.run.player+Vector2.from_angle(i)*350,"velocity":Vector2.from_angle(i+PI/2)*50,"friendly":false,"radius":7,"damage":0,"ttl":30.0})
		for i in 300: game.run.gems.append({"pos":game.run.player+Vector2.from_angle(i*2.399)*(330+i*.8),"kind":"xp","value":1})
		game.run._add_encounter("black_hole",game.run.player+Vector2(240,150))
		game._resume()
		var frames: Array[int]=[]
		var cpu: Array[int]=[]
		var draw: Array[int]=[]
		var arena: Array[int]=[]
		var enemy_draw: Array[int]=[]
		var sample_count := 360 if OS.has_feature("web") else 300
		var initial_elapsed: float=game.run.elapsed
		for step in sample_count+60:
			if game.screen!="playing": game._resume()
			while game.run.shots.size()<240: refill()
			var begin:=Time.get_ticks_usec()
			game.run.state="playing"
			game._physics_process(1.0/60.0)
			while game.run.shots.size()<240: refill()
			var submitted:=Time.get_ticks_usec()
			game.queue_redraw()
			await RenderingServer.frame_post_draw
			if step>=60:
				frames.append(Time.get_ticks_usec()-begin)
				cpu.append(submitted-begin)
				draw.append(game.qa_draw_us)
				arena.append(game.qa_arena_us)
				enemy_draw.append(game.qa_enemy_us)
			for shot: Dictionary in game.run.shots:
				if shot.get("kind","") in ["wake","mine","sentry"]: shot.ttl=18.0
		frames.sort()
		cpu.sort()
		draw.sort()
		arena.sort()
		enemy_draw.sort()
		var p95 := ceili(sample_count*0.95)-1
		var p99 := ceili(sample_count*0.99)-1
		results.append({"trial":trial+1,"samples":sample_count,"p95_ms":frames[p95]/1000.0,"p99_ms":frames[p99]/1000.0,"max_ms":frames.back()/1000.0,"main_physics_p95_ms":cpu[p95]/1000.0,"draw_p95_ms":draw[p95]/1000.0,"arena_p95_ms":arena[p95]/1000.0,"enemy_draw_p95_ms":enemy_draw[p95]/1000.0,"over_33_3ms":frames.filter(func(v: int)->bool: return v>33300).size(),"elapsed_advanced":absf(game.run.elapsed-initial_elapsed-(sample_count+60)/60.0)<0.05,"ghost_frames":game.ghost.frames.size(),"texture_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED),"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"canvas_draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"enemies":game.run.enemies.size(),"shots":game.run.shots.size(),"gems":game.run.gems.size(),"renderer":RenderingServer.get_video_adapter_name(),"viewport":str(get_viewport().get_visible_rect().size)})
	var message:={"kind":"orbit-art-web-stress","profile":"mixed" if mixed else "tank","results":results,"note":"Same production scripts/assets; full main._physics_process includes HUD and ghost capture; muted audio; separate QA scene, synthetic combined maximum installations, warmup60; sample count in results"}
	print(JSON.stringify(message))
	if OS.has_feature("web"): JavaScriptBridge.eval("window.parent.postMessage("+JSON.stringify(message)+",window.location.origin)")
	game._show_pause()
	game.queue_redraw()
	if not OS.has_feature("web"):
		game.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
		get_tree().quit()

func refill() -> void:
	game.run.shots.append({"pos":game.run.player+Vector2(350,0),"velocity":Vector2(0,50),"friendly":false,"radius":7,"damage":0,"ttl":30.0})

func push_touch(at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = at
	event.index = 0
	event.pressed = pressed
	get_viewport().push_input(event, true)

func touch_checks() -> void:
	var results: Array[bool] = []
	game.touch_mode = true
	game._start_run()
	await get_tree().process_frame
	var at: Vector2 = game.position + game.run.player + Vector2(100, 40)
	push_touch(at, true)
	push_touch(at, false)
	game._physics_process(0.25)
	results.append(game.run.dash_time > 0)
	game._start_run()
	game.run.overdrive_meter = 100
	push_touch(at, true)
	push_touch(at, false)
	game._physics_process(0.08)
	push_touch(at, true)
	push_touch(at, false)
	game._physics_process(0.02)
	results.append(game.run.overdrive_time > 0 and game.run.dash_cooldown <= 0)
	game._start_run()
	push_touch(at, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = at + Vector2(110, 0)
	get_viewport().push_input(drag, true)
	var start: Vector2 = game.run.player
	for i in 15: game._physics_process(1.0 / 60)
	results.append(game.run.player.x > start.x + 5)
	push_touch(drag.position, false)
	results.append(game._movement_direction().is_zero_approx() and not game.dash_queued)
	var mobile: Control = game.ui.get_node("MobileHUD")
	at = mobile.pause.get_global_transform_with_canvas() * (mobile.pause.size * 0.5)
	push_touch(at, true)
	push_touch(at, false)
	await get_tree().process_frame
	results.append(game.screen == "pause" and not game.touch.pending)
	var report := {"kind":"orbit-mobile-input","passed":results.count(true),"total":results.size(),"checks":results,"note":"Actual WebAssembly Godot viewport touch events; physical DOM touch/device not tested"}
	print(JSON.stringify(report))
	if OS.has_feature("web"): JavaScriptBridge.eval("window.parent.postMessage("+JSON.stringify(report)+",window.location.origin)")
	else: get_tree().quit(0 if results.count(false) == 0 else 1)
