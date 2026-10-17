extends "res://server/match_server.gd"

func begin() -> void:
	super.begin()
	world.model.duration = 2.0
	world.actors[0].state = "upgrade"
