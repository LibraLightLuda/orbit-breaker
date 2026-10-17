extends SceneTree

func _init() -> void:
	var world = preload("res://scripts/online_world.gd").new()
	world.reset(123, "normal", ["striker", "scout"], "ring")
	var teammate_hp: float = world.actors[1].hp
	world.model.take_damage(1000000.0)
	assert(world.actors[0].life == "down")
	assert(world.model.state == "playing")
	assert(world.model.hp == 0.0)
	assert(world.actors[1].hp == teammate_hp)
	world.step(1.0 / 60.0, [{}, {}])
	assert(world.actors[0].life == "down" and world.actors[0].hp == 0.0, "lethal projectiles cannot regenerate a lost-but-alive actor next tick")
	world.actors[0].life = "alive"
	world.actors[0].rescued = true
	world.actors[0].hp = 100.0
	world.select_actor(0)
	world.model.invulnerable = 0.0
	world.model.take_damage(1000000.0)
	assert(world.actors[0].life == "dead")
	world.select_actor(1)
	world.model.invulnerable = 0.0
	world.model.take_damage(1000000.0)
	assert(world.actors[1].life == "down")
	world.step(1.0 / 60.0, [{}, {}])
	assert(world.phase == "lost")
	world.dispose()
	print("ONLINE DAMAGE SELF-CHECK: 8 assertions passed")
	call_deferred("quit")
