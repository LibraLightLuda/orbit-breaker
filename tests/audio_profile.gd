extends SceneTree

var game: Node2D
var results: Array = []

func _init() -> void:
	root.set_flag(Window.FLAG_NO_FOCUS, true)
	root.set_disable_input(true)
	call_deferred("measure")

func fill() -> void:
	if game.screen != "playing": game._resume()
	var model: RunModel = game.run
	while model.enemies.size() < 240:
		var i := model.enemies.size()
		model.spawn_enemy(["chaser","runner","tank","shooter"][i%4],RunModel.CENTER+Vector2.from_angle(i*2.39996)*(180+i%280))
	while model.shots.size() < 240:
		var i := model.shots.size()
		model.shots.append({"pos":RunModel.CENTER+Vector2.from_angle(i*2.39996)*230,"velocity":Vector2.from_angle(i*.3)*40,"friendly":false,"radius":7.0,"damage":0.0,"ttl":5.0})
	while model.gems.size() < 300:
		var i := model.gems.size()
		model.gems.append({"pos":RunModel.CENTER+Vector2.from_angle(i*2.39996)*400,"kind":"xp","value":0.0})
	model.hp = model.max_hp
	model.invulnerable = 1
	model.state = "playing"
	game.screen = "playing"
	game.run.events.clear()

func measure() -> void:
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.records.load_data("user://test_audio_profile_%d.json" % Time.get_ticks_usec())
	for trial in 3:
		for audible in [false,true]:
			game.records.load_data("user://test_audio_profile_%d_%s_%d.json" % [trial,str(audible),Time.get_ticks_usec()])
			game._start_run()
			game.run.reset(1217,"normal","striker","storm")
			game.run.audio_enabled = true
			game.sound.begin_run("storm")
			game.run.elapsed = 480
			game.run.upgrades = {"missile":3,"chain":3,"pulse":3,"rapid":4,"power":3,"orbit":3,"orbit_range":3}
			game.run._check_evolutions()
			game.sound.set_muted(not audible)
			var physics: Array[float] = []
			var frame_times: Array[float] = []
			var audio: Array[float] = []
			var max_voices := 0
			var last_frame := Time.get_ticks_usec()
			for frame in 360:
				fill()
				var start := Time.get_ticks_usec()
				game._physics_process(1.0/60)
				var cost := (Time.get_ticks_usec()-start)/1000.0
				start=Time.get_ticks_usec()
				game.sound.update_state("playing",game.run,0.0,game.camera_offset)
				var overhead := (Time.get_ticks_usec()-start)/1000.0
				max_voices=maxi(max_voices,game.sound.active_voices())
				await process_frame
				var now := Time.get_ticks_usec()
				if frame >= 60:
					physics.append(cost)
					audio.append(overhead)
					frame_times.append((now-last_frame)/1000.0)
				last_frame=now
			physics.sort()
			audio.sort()
			frame_times.sort()
			var result := {"trial":trial+1,"audible":audible,"samples":300,"physics_p95_ms":physics[284],"physics_p99_ms":physics[296],"audio_state_p95_ms":audio[284],"frame_p95_ms":frame_times[284],"frame_p99_ms":frame_times[296],"max_voices":max_voices,"ram":Performance.get_monitor(Performance.MEMORY_STATIC),"synthetic":true}
			results.append(result)
			print("AUDIO PROFILE TRIAL: ",JSON.stringify(result))
	game.sound.stop_all()
	await create_timer(.2).timeout
	game.queue_free()
	await process_frame
	var file=FileAccess.open("res://artifacts/audio-candidate/profile.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	file.close()
	print("AUDIO PROFILE COMPLETE")
	quit()
