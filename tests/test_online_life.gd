extends SceneTree

func _init() -> void:
	call_deferred("check_life")

func check_life() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.run.reset(123, "normal", "striker", "ring")
	game.run.elapsed = 10.0
	game.online.slot = 0
	game.online_mode = true
	game._resume()
	var frame := GhostReplay.new().snapshot_current(game.run)
	var participant := {"position":[640,360],"ship":"striker","facing":0.0,"life":"down","rescue":0.0,"hp":100.0,"max_hp":100.0}
	var packet := {"type":"state","tick":600,"ack":0,"frame":frame,"players":[participant,participant.duplicate()],"phase":"playing","state":"playing","choices":[],"choice_revision":0,"score":123,"team_score":456,"speed":200.0,"finale_offered":false,"finale_selected":false,"events":[],"audio":{}}
	game._online_message(packet)
	assert(game.run.hp == 0.0)
	assert(game.toast.contains("구조 대기"))
	game._online_tick(0.2)
	assert(game.hud.score.text == "456")
	participant.life = "dead"
	packet.players[1].life = "alive"
	packet.players[1].position = [1600,360]
	packet.team_score = 700
	game._online_message(packet)
	assert(game.run.hp == 0.0)
	assert(game.toast.contains("관전 중"))
	game._online_tick(0.2)
	assert(game.hud.score.text == "700")
	assert(game.camera_offset.x > 0.0)
	participant.life = "alive"
	packet.phase = "selection"
	game._online_message(packet)
	assert(game.online_paused)
	assert(game.toast.contains("동료 강화"))
	var world = preload("res://scripts/online_world.gd").new()
	world.reset(123, "normal", ["striker", "scout"], "ring")
	world.actors[0].life = "dead"
	world.model.hp = 55.0
	world.save_actor()
	assert(world.model.hp == 0.0 and world.actors[0].hp == 0.0, "shared parts cannot restore a dead actor without rescue")
	world.dispose()
	game.sound.stop_all()
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	game = null
	print("ONLINE LIFE SELF-CHECK: 10 assertions passed")
	call_deferred("quit")
