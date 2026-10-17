extends RefCounted

static func restore(model: RunModel, motion: Dictionary) -> void:
	model.dash_time = clampf(float(motion.get("dash_time", 0.0)), 0.0, 0.2)
	var direction: Array = motion.get("dash_direction", [0.0, 0.0])
	if direction.size() == 2: model._dash_direction = Vector2(float(direction[0]), float(direction[1])).limit_length(1.0)

static func predict(model: RunModel, dt: float, move: Vector2, dash: bool, aim: Vector2) -> void:
	var direction := move.limit_length(1.0)
	model.dash_cooldown = maxf(0.0, model.dash_cooldown - dt * (1.0 + model.buff_value("haste") / 100.0))
	model.slipstream_time = maxf(0.0, model.slipstream_time - dt)
	if model.dash_time <= 0.0 and direction.length_squared() > 0.01: model.facing = direction.normalized()
	if dash and model.dash_cooldown <= 0.0:
		model.dash_time = 0.2
		model._dash_direction = aim.normalized() if not aim.is_zero_approx() else model.facing
		model.facing = model._dash_direction
		model.dash_cooldown = maxf(0.8, float(GameContent.ship_info(model.ship_id).dash) - float(model.upgrades.get("dash", 0)) * 0.35)
		if model.ship_id == "scout": model.slipstream_time = 1.6
	var before := model.player
	var speed := model.base_speed() * model.movement_multiplier(model.player) * (1.35 if model.slipstream_time > 0.0 else 1.0) * model.gravity_drag(model.player)
	var dash_dt := minf(dt, model.dash_time)
	model.player += model._dash_direction * 940.0 * model.dash_distance_multiplier() * dash_dt + direction * speed * (dt - dash_dt)
	model.player += model.gravity_pull(model.player) * dt
	model.player += model.boundary_current(model.player) * dt
	model.dash_time = maxf(0.0, model.dash_time - dt)
	model.current_speed = model.player.distance_to(before) / maxf(dt, 0.001)
