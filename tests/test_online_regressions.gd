extends "res://server/match_server.gd"

func _init() -> void:
	call_deferred("check_regressions")

func _process(_delta: float) -> bool:
	return false

func check_regressions() -> void:
	var config := preload("res://scripts/online_config.gd")
	assert(config.web_service_url("https://libralightluda.github.io", "libralightluda.github.io") == config.API_URL)
	assert(config.web_service_url("https://candidate.chatgpt.site", "candidate.chatgpt.site") == "https://candidate.chatgpt.site")
	assert(config.web_service_url("http://localhost:8060", "localhost") == "http://localhost:8060")
	assert(config.web_service_url("https://candidate.github.io.invalid", "candidate.github.io.invalid") == "https://candidate.github.io.invalid")
	print("ONLINE API ROUTING: 4 checks passed")
	started = true
	slots = [{"last_seq": -1, "applied_seq": -1, "last_input": 0, "pending": {}, "input": {}}]
	var peer := {"slot": 0}
	handle(peer, {"type": "input", "seq": 1, "move": [1,0], "aim": [-1,0], "dash": true, "overdrive": true})
	handle(peer, {"type": "input", "seq": 2, "move": [0,1], "aim": [1,0]})
	assert(slots[0].applied_seq == -1)
	var consumed := consume_input(slots[0])
	assert(consumed.dash and consumed.overdrive and consumed.aim == Vector2.LEFT)
	assert(consumed.move == Vector2.DOWN and slots[0].applied_seq == 2)
	assert(not consume_input(slots[0]).has("dash"))
	assert(not consume_input(slots[0]).has("overdrive"))
	handle(peer, {"type": "input", "seq": 1, "dash": true})
	assert(slots[0].pending.is_empty())
	slots[0].last_input = Time.get_ticks_msec() - 300
	assert(consume_input(slots[0]).is_empty())
	var model := RunModel.new()
	model.reset(12, "normal", "striker", "ring")
	model.dash_time = 0.01
	model._dash_direction = Vector2.RIGHT
	var restored := RunModel.new()
	restored.reset(12, "normal", "striker", "ring")
	GhostReplay.restore(restored, GhostReplay.new().snapshot_current(model))
	preload("res://scripts/online_motion.gd").restore(restored, {"dash_time": model.dash_time, "dash_direction": [1,0]})
	assert(is_equal_approx(restored.dash_time, model.dash_time))
	model._step_player(0.05, Vector2.RIGHT, false, Vector2.RIGHT)
	preload("res://scripts/online_motion.gd").predict(restored, 0.05, Vector2.RIGHT, false, Vector2.RIGHT)
	assert(model.player.distance_to(restored.player) < 0.001)
	var client := preload("res://scripts/online_client.gd").new()
	client.session_path = "user://test_online_session_%d.json" % Time.get_ticks_usec()
	root.add_child(client)
	client.retry_left = 0.8
	client.retry_window = 29.5
	client.leave()
	assert(client.retry_left == 0.0 and client.retry_window == 0.0)
	client.queue_free()
	print("ONLINE REGRESSIONS: 10 checks passed")
	quit()
