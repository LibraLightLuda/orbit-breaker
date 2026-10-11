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
	var model := Model.new()
	model.reset(45)
	check(is_equal_approx(PI * Model.ACTIVITY_RADIUS * Model.ACTIVITY_RADIUS, 1136 * 516 * 2.0), "activity circle has twice the original area")
	for i: int in range(8):
		var direction := Vector2.from_angle(i * TAU / 8)
		check(model.boundary_layer(Model.CENTER + direction * (Model.ACTIVITY_RADIUS - 20)) == 0, "radial safe zone " + str(i))
		for layer: int in range(1, 4):
			model.player = Model.CENTER + direction * (Model.ACTIVITY_RADIUS - Model.PLAYER_RADIUS + (layer - 0.5) * Model.LAYER_WIDTH)
			check(model.boundary_layer(model.player) == layer, "equal radial layer " + str(layer))
			var rate: float = model.boundary_damage_rate()
			check(rate < 5 if layer == 1 else rate > (20 if layer == 2 else 200), "graded exposure damage")
	model.player = Model.CENTER + Vector2.ONE * Model.ACTIVITY_RADIUS * 0.8
	check(model.boundary_layer(model.player) == 1, "corners of bounding square are outside the circle")
	model.player = Model.CENTER + Vector2.RIGHT * (Model.ACTIVITY_RADIUS + Model.BOUNDARY_BUFFER)
	check(model.boundary_drag(model.player) <= 0.061 and model.boundary_current(model.player).x < -1800, "third layer has severe drag and return current")
	model.hp = 280
	model.max_hp = 280
	model.upgrades.repair = 5
	model.overdrive_time = 6
	model.invulnerable = 100
	for frame: int in range(60):
		model._update_vitals(0.05)
	check(model.hp == 0 and model.end_reason == "boundary", "even max normal hull and healing cannot camp third layer")
	model.reset(45)
	for kind: String in ["chaser", "runner", "tank", "shooter", "elite", "boss"]:
		for attempt: int in range(8):
			var enemy: Dictionary = model.spawn_enemy(kind)
			var radius: float = Vector2(enemy.pos).distance_to(Model.CENTER)
			check(radius > Model.ACTIVITY_RADIUS + (int(enemy.spawn_layer) - 1) * Model.LAYER_WIDTH and radius < Model.ACTIVITY_RADIUS + int(enemy.spawn_layer) * Model.LAYER_WIDTH, "spawn in assigned outer stratum " + kind)
	check(model.events.has("invasion") and model.event_title.contains("접근"), "strong invader announces approach")
	var boss: Dictionary = model.enemies.back()
	var distance: float = Vector2(boss.pos).distance_to(model.player)
	model._update_enemies(0.05, model.player)
	check(Vector2(boss.pos).distance_to(model.player) < distance and distance - Vector2(boss.pos).distance_to(model.player) < 2, "strong invader approaches slowly without teleport")
	model.enemies.clear()
	model.player = Model.CENTER + Vector2.RIGHT * (Model.ACTIVITY_RADIUS + 80)
	for attempt: int in range(20):
		check(Vector2(model.spawn_enemy("chaser").pos).distance_to(model.player) >= 180, "spawns avoid popping on player")
	model.reset(45)
	model._add_blast(Model.CENTER + Vector2(1000, 1000), 72)
	check(Vector2(model.hazards[0].pos).distance_to(Model.CENTER) <= Model.ACTIVITY_RADIUS - 71.99, "blast fits circular activity zone")
	model._add_lane()
	check(model.hazards[1].rect.size.x > 0 and model.hazards[1].rect.size.y > 0, "lane chord remains valid")
	for id: String in ["striker", "scout", "bastion"]:
		model.reset(45, "normal", id)
		model.upgrades.dash = 3
		check(model.dash_charge() == 1, "initial dash is charged")
		model.step(0.01, Vector2.RIGHT, true)
		check(model.dash_charge() == 0, "dash consumes gauge")
		var duration: float = model.dash_recharge_total
		model.dash_cooldown = duration / 2
		check(is_equal_approx(model.dash_charge(), 0.5), "gauge reflects actual upgraded ship cooldown")
		model.state = "upgrade"
		model.step(0.05, Vector2.ZERO, false)
		check(is_equal_approx(model.dash_charge(), 0.5), "upgrade pauses recharge gauge")
	await _test_ui()
	print("ORBITAL SELF-CHECK: %d / %d assertions passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)

func _test_ui() -> void:
	var game: Node2D = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.records.load_data("user://test_orbital_%d.json" % Time.get_ticks_usec())
	game.sound.set_muted(true)
	for layer: int in range(4):
		game.run.reset(45)
		game.run.player = Model.CENTER + Vector2.RIGHT * (0 if layer == 0 else Model.ACTIVITY_RADIUS - Model.PLAYER_RADIUS + (layer - 0.5) * Model.LAYER_WIDTH)
		game.run.boundary_time = 0.5
		game.run.dash_cooldown = 1.5
		game.run.overdrive_meter = 50
		game.run.spawn_enemy("boss")
		game._resume()
		check(game.hud.dash_charge.text.contains("50%") and game.hud.overdrive_charge.text.contains("50%"), "both charging skills have numeric state")
		await snapshot(game, "orbital-layer-" + str(layer))
	for id: String in ["scout", "bastion"]:
		game.run.reset(45, "normal", id)
		game.run.overdrive_meter = 100
		game._resume()
		check(game.hud.dash_charge.text.contains("준비 완료") and game.hud.overdrive_charge.text.contains("준비 완료"), "both skills clearly ready")
		game.records.data.reduced_motion = true
		await snapshot(game, "orbital-ready-" + id)
	game.queue_free()
	await process_frame

func snapshot(game: Node2D, label: String) -> void:
	game.queue_redraw()
	await process_frame
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var folder := "res://artifacts/candidate/small" if "--capture-small" in OS.get_cmdline_user_args() else "res://artifacts/candidate"
		DirAccess.make_dir_recursive_absolute(folder)
		check(root.get_texture().get_image().save_png(folder + "/" + label + ".png") == OK, "capture " + label)
