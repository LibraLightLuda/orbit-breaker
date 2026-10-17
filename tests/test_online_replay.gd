extends SceneTree

func _init() -> void:
	call_deferred("check_chunks")

func check_chunks() -> void:
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/online-replay/manifest.json"))
	for index in 2:
		var loader = preload("res://scripts/online_replay.gd").new()
		root.add_child(loader)
		await process_frame
		loader.manifest = metadata.duplicate(true)
		loader.manifest.chunks = [metadata.chunks[index]]
		loader.pending = 0
		var completed: Array = []
		var failed: Array = []
		loader.completed.connect(func(_frames: Array, _meta: Dictionary) -> void: completed.append(true))
		loader.failed.connect(func(reason: String) -> void: failed.append(reason))
		var bytes := FileAccess.get_file_as_bytes("res://tests/fixtures/online-replay/%d.json.gz" % index)
		loader._received(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), bytes)
		assert(completed.size() == 1 and failed.is_empty(), "actual server chunk %d must decode: %s" % [index, str(failed)])
		var first: Array = loader.sample(float(metadata.chunks[index].start))
		assert(first.size() == 14)
		loader.focus = 1
		var second: Array = loader.sample(float(metadata.chunks[index].start))
		assert(first[1] != second[1])
		var with_events: Array = loader.cache[0][0].filter(func(frame: Array) -> bool: return not frame[13].events.is_empty())
		assert(not with_events.is_empty())
		var corrupted: Array = with_events[0].duplicate(true)
		corrupted[13].events[0][0] = float(corrupted[0]) + 1.0
		GhostReplay.align_online_event_times(corrupted)
		assert(not GhostReplay.valid([corrupted], float(corrupted[0])), "precision repair must not accept future events")
		corrupted[13].events[0][0] = -0.00001
		GhostReplay.align_online_event_times(corrupted)
		assert(not GhostReplay.valid([corrupted], float(corrupted[0])), "precision repair must not accept negative clocks")
		bytes[bytes.size() - 1] ^= 1
		loader.pending = 0
		loader._received(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), bytes)
		assert(failed.size() == 1 and str(failed[0]).contains("해시"))
		loader.queue_free()
		await process_frame
	var model := RunModel.new()
	model.reset(123, "normal", "striker", "ring")
	var recorder := GhostReplay.new()
	for tick in 120:
		model.step(1.0 / 60.0, Vector2.ZERO, false)
		var frame := recorder.snapshot_current(model)
		assert(GhostReplay.valid([frame], float(frame[0])), "online snapshot event clocks share the frame precision")
	print("ONLINE REPLAY SELF-CHECK: 134 assertions passed")
	call_deferred("quit")
