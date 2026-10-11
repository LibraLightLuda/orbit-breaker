extends SceneTree

func _init() -> void:
	var model := RunModel.new()
	model.reset(380)
	model.upgrades = {"orbit": 5, "power": 5, "rapid": 5, "missile": 3, "chain": 3, "pulse": 3, "repair": 5}
	model.orbit_count = 8
	model.max_hp = 100000.0
	model.hp = model.max_hp
	for i in 240:
		var enemy := model.spawn_enemy("tank", model.player + Vector2.from_angle(i * 2.39996) * (100.0 + i * 3.0))
		enemy.hp = 1000000.0
		enemy.max_hp = enemy.hp
	for i in 300:
		model.gems.append({"pos": model.player + Vector2.from_angle(i) * 900.0, "kind": "xp", "value": 1.0})
	var ghost := GhostReplay.new()
	ghost.capture(model)
	var samples: Array[int] = []
	for frame in 600:
		while model.shots.size() < 240:
			model.shots.append({"pos": model.player, "velocity": Vector2.from_angle(frame * 0.1 + model.shots.size()) * 590.0, "friendly": true, "radius": 5.0, "damage": 1.0, "ttl": 1.45})
		var started := Time.get_ticks_usec()
		model.step(1.0 / 60.0, Vector2.ZERO, false)
		ghost.capture(model)
		samples.append(Time.get_ticks_usec() - started)
		model.events.clear()
	var path := "user://performance-replay.json"
	var started := Time.get_ticks_usec()
	assert(GhostReplay.write(path, ghost.frames))
	var write_us := Time.get_ticks_usec() - started
	assert(GhostReplay.read(path).size() == ghost.frames.size())
	DirAccess.remove_absolute(path)
	var recording: Array = []
	# One minute at continuous maximum density fits the replay byte budget; the
	# separate replay-world suite covers a full ten-minute simulated run.
	for i in 301:
		var snapshot: Array = ghost.frames[i % ghost.frames.size()].duplicate()
		snapshot[0] = i * 0.2
		snapshot[13] = snapshot[13].duplicate()
		snapshot[13].events = []
		recording.append(snapshot)
	var writer := GhostReplay.new()
	assert(writer.begin_write(path, recording))
	var slices: Array[int] = []
	var complete := false
	writer.start_background()
	started = Time.get_ticks_usec()
	while not complete:
		var slice_start := Time.get_ticks_usec()
		complete = writer.poll_write()
		slices.append(Time.get_ticks_usec() - slice_start)
		OS.delay_usec(1000)
	assert(writer.save_ok)
	assert(GhostReplay.read(path).size() == 301)
	var file := FileAccess.open(path, FileAccess.READ)
	var size := file.get_length()
	file.close()
	DirAccess.remove_absolute(path)
	slices.sort()
	print("CHUNK SAVE: 60s / 301 frames using moving ten-second stress snapshots; %d bytes; %d slices; p95 %.3fms max %.3fms; total with read %.3fms" % [size, slices.size(), slices[floori((slices.size() - 1) * 0.95)] / 1000.0, slices.back() / 1000.0, (Time.get_ticks_usec() - started) / 1000.0])
	samples.sort()
	var total := 0
	for sample in samples:
		total += sample
	print("PERFORMANCE: 600 moving frames, 240 enemies/shots, 300 gems; mean %.3fms p95 %.3fms max %.3fms; ghost write %.3fms" % [total / 600000.0, samples[569] / 1000.0, samples.back() / 1000.0, write_us / 1000.0])
	quit()
