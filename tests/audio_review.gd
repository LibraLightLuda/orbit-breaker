extends SceneTree

var game: Node2D
var record: AudioEffectRecord
var t := 0.0
var length := 90.0
var next_scene := 0
var next_capture := 0
var peak_voices := 0
var samples: Array[float] = []
var output := "res://artifacts/audio-candidate/review"
var stopped := false
var began := 0

func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="): length = float(arg.get_slice("=",1))
		if arg.begins_with("--output="): output = arg.get_slice("=",1)
	call_deferred("begin")

func begin() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.records.load_data("user://test_audio_review_%d.json" % Time.get_ticks_usec())
	game.sound.set_muted(false)
	game.sound.set_music_enabled(true)
	game.sound.set_volumes(1,1,1)
	game._start_run()
	game.run.reset(1217,"normal","striker","ring")
	game.run.audio_enabled = true
	game.sound.begin_run("ring")
	game.sound.set_screen("menu")
	game.sound.set_screen("playing")
	game.run.upgrades = {"missile":3,"chain":3,"pulse":3,"rapid":4,"power":3,"blade":3,"frost":3,"magnet":3,"orbit":3,"orbit_range":3,"dash":3,"speed":3}
	game.run.hp = game.run.max_hp
	record = AudioEffectRecord.new()
	record.format = AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0,record)
	record.set_recording_active(true)
	began = Time.get_ticks_msec()
	print("AUDIO REVIEW START: real-time rendered synthetic encounter sequence; seconds=",length)

func _process(delta: float) -> bool:
	if game == null or stopped: return false
	t = (Time.get_ticks_msec()-began)/1000.0
	var section := mini(9,floori(t/(length/10)))
	if section >= next_scene:
		next_scene = section+1
		stage(section)
	if game.screen == "pause" and (section != 8 or t > length*.8+2): game._resume()
	if game.screen == "upgrade": game._pick_upgrade(0)
	if game.screen == "playing":
		game.mouse_active = true
		game.mouse_target = RunModel.CENTER+Vector2.from_angle(t*.4)*140-game.camera_offset
		if game.run.dash_cooldown <= 0:
			game.dash_queued = true
			game.dash_aim = Vector2.from_angle(t)
		if game.run.hp < game.run.max_hp*.4 and section not in [6,7]: game.run.apply_item("heal","A")
		if game.run.hp < 3: game.run.hp = 6
		var start := Time.get_ticks_usec()
		game._physics_process(delta)
		samples.append((Time.get_ticks_usec()-start)/1000.0)
	peak_voices = maxi(peak_voices,game.sound.active_voices())
	if floori(t/(length/20)) >= next_capture:
		next_capture += 1
		RenderingServer.frame_post_draw.connect(snapshot.bind(next_capture),CONNECT_ONE_SHOT)
	if t >= length:
		stopped = true
		call_deferred("finish")
	return false

func stage(index: int) -> void:
	print("AUDIO REVIEW SECTION ",index," @ ",t)
	match index:
		0:
			game.run.elapsed = 1
			for i in 10: game.run.spawn_enemy("chaser",RunModel.CENTER+Vector2.from_angle(i*.6)*250)
		1:
			for id: String in ["core","drive","shell"]: game.run.collect_part(id)
			game.run.apply_item("power","A")
		2:
			game.run.elapsed = 180
			game.run._add_encounter("meteor",RunModel.CENTER+Vector2(240,0))
		3:
			game.run.elapsed = 300
			game.run._check_evolutions()
			game.run.spawn_enemy("boss",RunModel.CENTER+Vector2(300,0))
			game.run.overdrive_meter = 100
			game.run.activate_overdrive()
		4:
			game.run.sector_id = "storm"
			game.sound._ambience.stream = game.sound._tracks.amb_storm
			game.run._add_lane()
		5:
			game.run.sector_id = "forge"
			game.sound._ambience.stream = game.sound._tracks.amb_forge
			game.run.elapsed = 480
			game.run._add_blast(game.run.player+Vector2(110,0),72)
		6:
			game.run.hp = game.run.max_hp*.12
			game.run.buffs.shield = {"value":500.0,"ttl":length/10,"grade":"A"}
		7:
			game.run.hp = game.run.max_hp*.06
			game.run._add_lane()
		8:
			game.run.hp = game.run.max_hp*.7
			game._show_pause()
			create_timer(2).timeout.connect(func() -> void: game._resume())
		9:
			game.run.elapsed = 590

func snapshot(index: int) -> void:
	root.get_texture().get_image().save_png(output+"/scene-%02d.png" % index)

func finish() -> void:
	record.set_recording_active(false)
	var wav := record.get_recording()
	var error := wav.save_to_wav(output+"/mix.wav")
	samples.sort()
	var summary := {"seconds":t,"recording_frames":wav.data.size()/4,"sample_rate":wav.mix_rate,"save_error":error,"peak_one_shots":peak_voices,"physics_p95_ms":samples[floori(samples.size()*.95)],"physics_p99_ms":samples[floori(samples.size()*.99)],"calls":game.sound.played_counts,"synthetic":true,"human_listening":false,"wall_seconds":(Time.get_ticks_msec()-began)/1000.0}
	var file := FileAccess.open(output+"/capture.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(summary,"\t"))
	file.close()
	print("AUDIO REVIEW COMPLETE: ",JSON.stringify(summary))
	game.sound.stop_all()
	await create_timer(.2).timeout
	game.queue_free()
	await process_frame
	quit(0 if error == OK and wav.data.size() > length*wav.mix_rate*3 else 1)
