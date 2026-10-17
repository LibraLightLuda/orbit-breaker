extends "res://server/match_server.gd"

func _init() -> void:
	call_deferred("audit")

func _process(_delta: float) -> bool:
	return false

func audit() -> void:
	started = true
	slots = [{"last_seq": -1, "input": {}}]
	var peer := {"slot": 0}
	handle(peer, {"type": "input", "seq": 1, "move": [1,0], "aim": [1,0], "dash": true, "overdrive": true})
	handle(peer, {"type": "input", "seq": 2, "move": [1,0], "aim": [1,0], "dash": false, "overdrive": false})
	print("AUDIT_INPUT_OVERWRITE ", JSON.stringify(slots[0].input))
	assert(slots[0].input.dash == false and slots[0].input.overdrive == false)
	var model := RunModel.new()
	model.reset(12, "normal", "striker", "ring")
	model.dash_time = 0.01
	var recorder := GhostReplay.new()
	var frame := recorder.snapshot_current(model)
	var restored := RunModel.new()
	restored.reset(12, "normal", "striker", "ring")
	GhostReplay.restore(restored, frame)
	print("AUDIT_DASH_STATE ", JSON.stringify({"server_seconds": model.dash_time, "restored_seconds": restored.dash_time}))
	assert(is_equal_approx(restored.dash_time, 0.2))
	model._dash_direction = Vector2.RIGHT
	restored._dash_direction = Vector2.RIGHT
	model._step_player(0.05, Vector2.RIGHT, false, Vector2.RIGHT)
	preload("res://scripts/online_motion.gd").predict(restored, 0.05, Vector2.RIGHT, false, Vector2.RIGHT)
	print("AUDIT_DASH_POSITION_ERROR ", model.player.distance_to(restored.player))
	var client := preload("res://scripts/online_client.gd").new()
	root.add_child(client)
	client.room = {"websocket": "ws://127.0.0.1:1"}
	client.resume_key = "old"
	client.retry_window = 29.5
	client.retry_left = 0.8
	client.leave()
	print("AUDIT_LEAVE_TIMERS ",JSON.stringify({"retry_window":client.retry_window,"retry_left":client.retry_left}))
	client.queue_free()
	quit()

