extends SceneTree

const Model = preload("res://scripts/run_model.gd")
var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAILED: " + message)

func run_checks() -> void:
	_test_striker()
	_test_scout()
	_test_bastion()
	await _test_ui()
	print("SHIP SELF-CHECK: %d / %d assertions passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)

func _test_striker() -> void:
	var model := Model.new()
	model.reset(31)
	model._spawn_timer = 100
	for i: int in range(24):
		model.step(0.05, Vector2.ZERO, false)
	check(is_equal_approx(model.focus_time, 1.2), "stationary pilot locks aim without needing a target")
	model.spawn_enemy("boss", model.player + Vector2(300, 0))
	model._fire_player_shot()
	check(is_equal_approx(float(model.shots.back().damage), 30.4), "locked automatic cannon deals sixty percent extra damage")
	check(is_equal_approx(model._power(), 1.0), "focus does not amplify satellites or other weapons")
	model.upgrades.power = 2
	model.overdrive_meter = 100
	model.activate_overdrive()
	model._fire_player_shot()
	check(is_equal_approx(float(model.shots.back().damage), 19 * 1.5 * 1.45 * 1.6), "focus combines with cannon upgrades and overdrive")
	model.state = "upgrade"
	model.step(0.05, Vector2.RIGHT, true)
	check(is_equal_approx(model.focus_time, 1.2), "upgrade pauses focus")
	model.state = "playing"
	model.step(0.01, Vector2.RIGHT, false)
	check(model.focus_time == 0, "movement immediately breaks aim")
	model.focus_time = 1.2
	model.step(0.01, Vector2.ZERO, true)
	check(model.focus_time == 0, "dash breaks aim even without movement input")
	model.focus_time = 1.2
	model.invulnerable = 1
	model.take_damage(20)
	check(model.focus_time == 1.2, "evaded hit keeps aim")
	model.invulnerable = 0
	model.take_damage(20)
	check(model.focus_time == 0, "actual hit breaks aim")
	model._fire_player_shot()
	check(is_equal_approx(float(model.shots.back().damage), 19 * 1.5 * 1.45), "moving cannon retains base damage")
	model.focus_time = 1.2
	model.reset(31)
	check(model.focus_time == 0, "restart clears focus")
	model.reset(31, "normal", "scout")
	model._spawn_timer = 100
	for i: int in range(30):
		model.step(0.05, Vector2.ZERO, false)
	check(model.focus_time == 0, "other ships cannot lock aim")

func _test_scout() -> void:
	var model := Model.new()
	model.reset(32, "normal", "scout")
	model.step(0.01, Vector2.RIGHT, true)
	check(is_equal_approx(model.slipstream_time, 1.6) and is_equal_approx(model.dash_time, 0.2), "scout dash starts wake without extending dash")
	model.dash_time = 0
	var start: Vector2 = model.player
	model.step(0.05, Vector2.RIGHT, false)
	check(is_equal_approx(model.player.x - start.x, 255.0 * 1.35 * 0.05), "wake boosts normal movement thirty-five percent")
	model.upgrades.speed = 2
	start = model.player
	model.step(0.01, Vector2.RIGHT, false)
	check(is_equal_approx(model.player.x - start.x, 311.0 * 1.35 * 0.01), "wake scales upgraded propulsion")
	model.player.x = 1250
	model.boundary_time = 3
	start = model.player
	model.step(0.01, Vector2.RIGHT, false)
	check(model.player.x - start.x < 311.0 * 1.35 * 0.01, "wake respects boundary drag and current")
	model.state = "upgrade"
	var timer: float = model.slipstream_time
	model.step(0.05, Vector2.RIGHT, true)
	check(model.slipstream_time == timer, "upgrade pauses wake")
	model.state = "playing"
	model.player = Model.ARENA.get_center()
	for i: int in range(33):
		model.step(0.05, Vector2.ZERO, false)
	check(model.slipstream_time == 0, "wake expires")
	model.reset(32, "normal", "scout")
	var enemy: Dictionary = model.spawn_enemy("boss", model.player + Vector2(35, 0))
	enemy.speed = 0
	enemy.orbit_timer = 1
	model.step(0.01, Vector2.RIGHT, true)
	check(is_equal_approx(float(enemy.hp), float(enemy.max_hp) - 52 * 0.9 * 1.75), "scout dash applies extra damage once")
	model.step(0.01, Vector2.RIGHT, false)
	check(is_equal_approx(float(enemy.hp), float(enemy.max_hp) - 52 * 0.9 * 1.75), "same dash cannot repeatedly hit target")
	model.reset(32)
	model.step(0.01, Vector2.RIGHT, true)
	check(model.slipstream_time == 0, "other ships do not receive scout wake")

func _test_bastion() -> void:
	var model := Model.new()
	model.reset(33, "normal", "bastion")
	var near: Dictionary = model.spawn_enemy("tank", model.player + Vector2(100, 0))
	var far: Dictionary = model.spawn_enemy("tank", model.player + Vector2(200, 0))
	model.take_damage(20)
	check(is_equal_approx(model.hp, 132.0) and model.guard_cooldown == 8.0, "ready shield reduces one hit sixty percent")
	check(is_equal_approx(float(near.hp), 54.0) and near.pos.x == model.player.x + 145, "shield counters and pushes nearby enemy")
	check(float(far.hp) == 92 and far.pos.x == model.player.x + 200, "counter does not reach distant enemy")
	model.invulnerable = 0
	model.take_damage(20)
	check(is_equal_approx(model.hp, 112.0), "recharging shield grants no reduction")
	model.enemies.clear()
	model.state = "upgrade"
	model.step(0.05, Vector2.ZERO, false)
	check(model.guard_cooldown == 8, "upgrade cannot recharge shield")
	model.state = "playing"
	model.guard_cooldown = 0.01
	model.step(0.05, Vector2.ZERO, false)
	check(model.guard_cooldown == 0, "shield becomes ready after combat-time recharge")
	model.invulnerable = 1
	model.take_damage(20)
	model.invulnerable = 0
	model.take_damage(0)
	check(model.guard_cooldown == 0, "ignored damage does not consume shield")
	model.overdrive_meter = 100
	model.activate_overdrive()
	var before: float = model.hp
	model.take_damage(20)
	check(is_equal_approx(before - model.hp, 4.4), "shield combines with overdrive damage reduction")
	model.reset(33, "relaxed", "bastion")
	model.take_damage(20)
	check(is_equal_approx(model.hp, 184), "shield combines with relaxed difficulty")
	model.reset(33, "veteran", "bastion")
	model.take_damage(20)
	check(is_equal_approx(model.hp, 130.4), "shield preserves veteran damage multiplier")
	model.reset(33, "normal", "bastion")
	model.elapsed = 300
	model.hp = 100
	model.step(0.05, Vector2.ZERO, false)
	check(model.hp < 100 and model.guard_cooldown == 0, "decay bypasses shield without consuming it")
	model.player.x = Model.ARENA.end.x + 100
	model.boundary_time = 2
	model.step(0.05, Vector2.ZERO, false)
	check(model.boundary_damage_rate() > 0 and model.guard_cooldown == 0, "boundary damage bypasses shield")
	model.reset(33)
	model.take_damage(20)
	check(model.hp == 80 and model.guard_cooldown == 0, "other ships cannot use shield")

func _test_ui() -> void:
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.records.load_data("user://test_ships_%d.json" % Time.get_ticks_usec())
	game.sound.set_muted(true)
	for id: String in ["striker", "scout", "bastion"]:
		game.run.reset(34, "normal", id)
		game.run.focus_time = 1.2 if id == "striker" else 0
		game.run.slipstream_time = 1.4 if id == "scout" else 0
		game._resume()
		check(not game.hud.trait.text.is_empty(), "trait HUD visible for " + id)
		game.queue_redraw()
		await process_frame
		if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var folder := "res://artifacts/candidate/small" if "--capture-small" in OS.get_cmdline_user_args() else "res://artifacts/candidate"
			DirAccess.make_dir_recursive_absolute(folder)
			check(root.get_texture().get_image().save_png(folder + "/ship-" + id + ".png") == OK, "capture ship " + id)
		game.run.guard_cooldown = 5
		game.run.focus_time = 0
		game.run.slipstream_time = 0
		game._update_hud()
		check(game.hud.trait.get_rect().end.x < game.hud.vital_detail.position.x, "trait HUD stays clear of hull rates")
	game.queue_free()
	await process_frame
