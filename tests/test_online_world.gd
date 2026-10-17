extends SceneTree

const World = preload("res://scripts/online_world.gd")
var checks := 0

func check(ok: bool, message: String) -> void:
	assert(ok, message)
	checks += 1

func _init() -> void:
	var world := World.new()
	world.reset(123, "normal", ["striker"], "ring")
	var solo := RunModel.new()
	solo.reset(123)
	for i in 120:
		var input := {"move": Vector2.RIGHT, "dash": i == 1, "aim": Vector2.RIGHT}
		world.step(1.0 / 60.0, [input])
		solo.step(1.0 / 60.0, Vector2.RIGHT, i == 1, Vector2.RIGHT)
	check(world.model.player.is_equal_approx(solo.player), "single-player movement unchanged")
	check(is_equal_approx(world.model.hp, solo.hp), "single-player vitals unchanged")
	check(world.model.rng.state == solo.rng.state, "single-player random sequence unchanged")
	world.model.xp = world.model.xp_needed
	world.model._check_level()
	world.save_actor()
	var offered: Array = world.choices(0)
	var revision := int(world.actors[0].choice_revision)
	check(not world.choose(0,str(offered[0]),revision-1), "stale choice window rejected")
	check(world.choose(0,str(offered[0]),revision), "current choice window accepted")
	world.reset(456, "normal", ["striker", "scout"], "storm")
	for i in 120: world.step(1.0 / 60.0, [{"move": Vector2.LEFT}, {"move": Vector2.RIGHT}])
	world.save_actor()
	check(is_equal_approx(world.model.elapsed, 2.0), "shared time advances once")
	check(world.actors[0].player.x < world.actors[1].player.x - 100.0, "independent movement")
	world.select_actor(0)
	var enemy := world.model.spawn_enemy("tank", RunModel.CENTER + Vector2(0, 400))
	check(float(enemy.max_hp) > 92.0 * 1.5, "co-op health scaling")
	world.model._hit_enemy(enemy, 100000.0)
	world.model._finish_deaths()
	check(world.team_score() > 0, "server awards team score")
	var score := world.team_score()
	world.model._finish_deaths()
	check(world.team_score() == score, "death awarded once")
	world.select_actor(0)
	world.model.hp = 0
	world.knocked_down()
	world.actors[1].player = world.actors[0].player
	world.actors[1].invulnerable = 0
	world.active = 1
	for key: String in world.FIELDS: world.model.set(key, world.actors[1][key])
	for i in 181: world.update_rescue(1.0 / 60.0)
	check(world.actors[0].life == "alive" and world.actors[0].rescued, "teammate rescue")
	check(is_equal_approx(float(world.actors[0].hp), float(world.actors[0].max_hp) * 0.3), "rescue health")
	print("ONLINE WORLD SELF-CHECK: %d checks passed" % checks)
	world.dispose()
	quit()
