extends SceneTree

var checks := 0
var failures := 0
var sound: SoundBank

func _init() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("AUDIO FAILED: " + message)

func tick(model: RunModel, seconds: float, view: String = "playing") -> void:
	for i in ceili(seconds/.05):
		sound._process(.05)
		sound.update_state(view,model,.05,Vector2.ZERO)

func run_checks() -> void:
	sound = SoundBank.new()
	check(not sound.play("ui_confirm"), "Calls before tree entry are safe")
	root.add_child(sound)
	sound.set_process(false)
	sound.start_music()
	check(sound._music.playing, "Menu music starts")
	check(sound._sounds.size() == SoundBank.CUES.size(), "All one-shots prepared before first combat")
	for cue: String in SoundBank.CUES:
		for stream: AudioStream in sound._sounds[cue]:
			check(stream != null and stream.get_length() > .02, "Usable preloaded cue " + cue)
	check(not sound.play("not_a_cue"), "Unknown event is ignored")
	sound.play("weapon_cannon")
	var count := int(sound.played_counts.weapon_cannon)
	for i in 100: sound.play("weapon_cannon")
	check(int(sound.played_counts.weapon_cannon) == count, "Burst requests are coalesced")
	for cue: String in SoundBank.CUES: sound.play(cue)
	check(sound.active_voices() <= 16, "One-shot pool is bounded")
	sound._clock += 10
	check(sound.play("ui_confirm"), "A real UI confirmation survives notification saturation")
	check(sound.play("warn_hull_critical"), "Hull warning survives a saturated mix")
	check(sound.play("hazard_charge_lane"), "Immediate hazard has its own reserved slot")
	check(sound._voices[0].get_meta("cue") == "warn_hull_critical" and sound._voices[1].get_meta("cue") == "hazard_charge_lane", "Threats cannot steal each other's reserved voice")
	sound.set_muted(true)
	check(sound.active_voices() == 0 and not sound._music.playing, "Mute stops active sound")
	var model := RunModel.new()
	model.audio_enabled = true
	model.reset(1217)
	sound.begin_run("ring")
	tick(model,.5)
	model.hp = 29
	tick(model,.3)
	check(sound._hull_stage == 0, "Low HP debounce prevents boundary chatter")
	tick(model,.15)
	check(sound._hull_stage == 1, "Sustained low hull enters warning")
	model.hp = 31
	tick(model,2)
	check(sound._hull_stage == 1, "Hysteresis preserves warning at 31 percent")
	model.hp = 14
	tick(model,.25)
	check(sound._hull_stage == 2, "Critical hull has distinct state")
	model.hp = 16
	tick(model,2)
	check(sound._hull_stage == 2, "Critical hysteresis resists oscillation")
	model.hp = 21
	tick(model,1.6)
	check(sound._hull_stage == 1, "Recovery lowers warning after stability")
	model.hp = 38
	tick(model,1.6)
	check(sound._hull_stage == 0, "Stable recovery clears hull warning")
	model.hp = 6
	tick(model,.05)
	check(sound._hull_stage == 3, "Imminent destruction enters immediately")
	var stage := sound._hull_stage
	model.hp = 100
	tick(model,3,"pause")
	check(sound._hull_stage == stage, "Pause cannot advance combat warning timers")
	sound.set_music_enabled(false)
	sound.set_muted(false)
	sound.begin_run("forge")
	sound.set_screen("playing")
	model.elapsed = 480
	tick(model,1)
	check(sound._decay_stage > 0, "Actual natural decay produces pressure state")
	check(not sound._music.playing and not sound._stems[0].playing, "Music OFF is independent of warnings")
	check(sound._decay.playing and not sound._decay.stream_paused, "Decay information remains with BGM OFF")
	var high_decay := sound._decay_stage
	model.buffs.shield = {"value":100.0,"ttl":10.0,"grade":"A"}
	tick(model,.2)
	check(sound._decay_stage == high_decay and model.net_hull_rate() >= 0, "Absorption does not fake a natural-decay recovery")
	sound.begin_run("ring")
	model.reset(1217)
	model.player = RunModel.CENTER + Vector2(RunModel.ACTIVITY_RADIUS+RunModel.LAYER_WIDTH*2.4,0)
	tick(model,.4)
	check(sound._layer >= 2 and sound._decay_stage == 0, "Outer damage is independent of natural decay")
	for item: String in ItemCatalog.IDS:
		for grade: String in ItemCatalog.GRADES:
			model.apply_item(item,grade)
			sound.consume(model,Vector2.ZERO)
			model.events.clear()
			check(model.audio_events.is_empty(), "Each item consumed exactly once: " + item + grade)
	model.audio_events.clear()
	model.enemies.clear()
	model.shots.clear()
	model._add_encounter("meteor", RunModel.CENTER)
	check(model.audio_events.has("event_warn_meteor"), "10-second event warning comes from actual creation")
	model.audio_events.clear()
	for i in 202: model._update_hazards(.05)
	check(model.audio_events.has("event_active_meteor") and model.audio_events.has("event_countdown"), "Countdown and activation are typed events")
	sound.set_muted(true)
	sound.consume(model,Vector2.ZERO)
	check(model.audio_events.is_empty(), "Muted events are drained rather than queued")
	sound.set_muted(false)
	check(sound._pending.is_empty(), "Unmute has no historical reward burst")
	sound.set_music_enabled(true)
	sound.set_screen("playing")
	await create_timer(.2).timeout
	var positions: Array[float] = []
	for player in sound._stems: positions.append(player.get_playback_position())
	check(positions.max()-positions.min() < .03, "Three music stems remain phase-aligned")
	sound.set_screen("pause")
	check(sound._stems[0].stream_paused and sound._decay.stream_paused, "Pause freezes all battle loops")
	sound.set_screen("replay")
	check(not sound._stems[0].playing and sound._music.playing, "Replay uses music without synthetic combat events")
	sound.set_volumes(0,1,1)
	check(AudioServer.is_bus_mute(0), "Master zero is exact silence")
	sound.set_volumes(1,0,0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Warnings")) and AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "Zero music/effects are independently silent")
	sound.set_volumes(1,1,1)
	_test_save_volumes()
	await _test_ui()
	_test_model_invariance()
	sound.stop_all()
	await create_timer(.2).timeout
	sound.queue_free()
	await process_frame
	print("AUDIO SELF-CHECK: %d / %d assertions passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)

func _test_save_volumes() -> void:
	var store := SaveStore.new()
	var path := "user://test_audio_%d.json" % Time.get_ticks_usec()
	store.load_data(path)
	store.data.master_volume = .35
	store.data.music_volume = .5
	store.data.effects_volume = .75
	check(store.save_data(), "Volume settings use existing atomic save")
	var reloaded := SaveStore.new()
	reloaded.load_data(path)
	check(is_equal_approx(float(reloaded.data.master_volume),.35) and is_equal_approx(float(reloaded.data.effects_volume),.75), "Volume settings round trip")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string('{"muted":true,"music":false,"master_volume":"bad","music_volume":-5,"effects_volume":12}')
	file.close()
	reloaded.load_data(path)
	check(reloaded.data.muted and not reloaded.data.music, "Legacy toggles preserved")
	check(reloaded.data.master_volume == 1.0 and reloaded.data.music_volume == 0 and reloaded.data.effects_volume == 1, "Corrupt volume type/ranges sanitized")

func _test_ui() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.records.load_data("user://test_audio_ui_%d.json" % Time.get_ticks_usec())
	game._show_settings()
	await process_frame
	var sliders := 0
	for child in game.ui.get_children():
		if child is HSlider:
			sliders += 1
			child.value = 65
	check(sliders == 3, "All three volume controls are present")
	game._start_run()
	game.run.state = "upgrade"
	game.run.upgrades.clear()
	game._show_upgrades()
	game.sound._clock += 1
	game._pick_upgrade(0)
	check(int(game.sound.played_counts.get("ui_upgrade_apply",0)) == 1, "One successful upgrade has one apply sound")
	game.sound.stop_all()
	await create_timer(.2).timeout
	game.queue_free()
	await process_frame

func _test_model_invariance() -> void:
	var path := "res://artifacts/audio-candidate/model-baseline.txt"
	if not FileAccess.file_exists(path):
		path = "res://scripts/run_model.gd"
	var original := GDScript.new()
	original.source_code = FileAccess.get_file_as_string(path).replace("class_name RunModel", "")
	check(original.reload() == OK, "Original model baseline compiles")
	print("MODEL_AUDIO_INVARIANCE: ", "pre-audio source" if path.ends_with(".txt") else "audio ON/OFF")
	for ship: String in GameContent.SHIP_IDS:
		for sector: String in GameContent.SECTOR_IDS:
			for mode: String in GameContent.MODE_IDS:
				var before = original.new()
				var after := RunModel.new()
				after.audio_enabled = true
				for model in [before,after]:
					model.reset(1217,mode,ship,sector)
					model.elapsed = 240 if mode in ["normal","relaxed"] else 480
					model.upgrades = {"missile":3,"chain":3,"pulse":3,"rapid":4,"power":3,"blade":3,"frost":3,"magnet":3,"orbit":3,"orbit_range":3,"dash":3,"speed":3}
					model._check_evolutions()
					model.spawn_enemy("boss",RunModel.CENTER+Vector2(200,0))
				for frame in 240:
					for model in [before,after]:
						if model.state == "upgrade":
							var choice: Variant = model.get_upgrade_choices()[0]
							model.choose_upgrade(str(choice.id) if choice is Dictionary else str(choice))
						if frame % 60 == 0:
							model.apply_item("shield","B")
							model.collect_part(["core","drive","shell"][floori(frame/60.0)%3])
						model.step(.05,Vector2.from_angle(frame*.1),frame%80==0,Vector2.RIGHT)
					if frame % 30 == 0:
						var same := true
						for property: Dictionary in after.get_property_list():
							if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0 or property.name in ["audio_events", "audio_enabled"]: continue
							var a: Variant = before.get(property.name)
							var b: Variant = after.get(property.name)
							if a is RandomNumberGenerator: same = same and a.state == b.state and a.seed == b.seed
							else: same = same and a == b
						check(same, "Audio leaves all model values/RNG unchanged: %s/%s/%s/%d" % [ship,sector,mode,frame])
