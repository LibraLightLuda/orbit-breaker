extends SceneTree

func _init() -> void:
	var World = preload("res://scripts/online_world.gd")
	var checks := 0
	for sector: String in GameContent.SECTOR_IDS:
		var world = World.new()
		world.reset(1217,"normal",["striker","bastion"] if sector=="ring" else ["scout","bastion"],sector)
		for i in 2:
			world.select_actor(i)
			world.model.max_hp = 100000.0
			world.model.hp = 100000.0
			world.model.upgrades = {"orbit":5,"power":5,"rapid":5,"blade":5,"frost":5,"missile":5,"chain":5,"pulse":5,"repair":5,"speed":3,"dash":3}
			world.model._check_evolutions()
			world.save_actor()
		var steps := 0
		while not world.phase in ["won","lost"] and steps < 14000:
			for i in 2:
				if world.actors[i].state in ["upgrade","branch"]:
					var choices: Array = world.choices(i)
					assert(not choices.is_empty())
					assert(world.choose(i,str(choices[0]),int(world.actors[i].choice_revision)))
			for i in 2:
				world.select_actor(i)
				world.model.max_hp = 1000000.0
				world.model.hp = 1000000.0
				world.save_actor()
			world.step(0.05,[{"move":Vector2.from_angle(steps*0.01)},{"move":Vector2.from_angle(steps*0.01+PI)}])
			steps += 1
		assert(is_equal_approx(world.model.elapsed,600.0),"co-op completes ten simulation minutes")
		assert(world.model.enemies.size()<=240 and world.model.shots.size()<=240 and world.model.hazards.size()<=6,"world bounds remain enforced")
		for actor: Dictionary in world.actors: assert(Vector2(actor.player).is_finite() and is_finite(float(actor.hp)))
		checks += 4
		world.dispose()
	print("ONLINE SOAK SELF-CHECK: %d checks, three ten-minute simulations passed" % checks)
	quit()
