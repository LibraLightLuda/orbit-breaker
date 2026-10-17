extends RefCounted

const WHITE := Color("f4ffff")
const CYAN := Color("83f5f3")
const GOLD := Color("ffca76")
const PLAYER_SIZE := 52.0
const PLAYER_VISUAL_SCALE := PLAYER_SIZE / 42.0

# All combat phases come from recorded model time/effects; rendering never advances the simulation.
static func engine(canvas: CanvasItem, at: Vector2, angle: float, power: float, time: float, color: Color, size: float = 1.0, reduced: bool = false) -> void:
	var facing := Vector2.from_angle(angle)
	var flicker := 1.0 if reduced else 0.90 + 0.10 * sin(time * 43.0)
	var length := (14.0 + power * 43.0) * size * flicker
	ArtAssets.sprite(canvas, "fx/thrust", at - facing * length * 0.36, Vector2(length, (7 + power * 5) * size), angle, Vector2.ZERO, Color(color, 0.85))
	ArtAssets.sprite(canvas, "fx/spark", at, Vector2(11, 7) * size, angle, Vector2.ZERO, Color(1.4, 1.5, 1.5, 0.85))

static func hull(canvas: CanvasItem, id: String, at: Vector2, angle: float, size: float, time: float, speed: float, recoil: float, hit: float, reduced: bool) -> void:
	var breath := 0.0 if reduced else sin(time * 3.2) * 0.012
	var lean := 0.0 if reduced else sin(time * 2.1) * 0.025 * speed
	var dimensions := Vector2(size * (1.0 + breath - recoil * 0.045), size * (1.0 - breath + speed * 0.025))
	ArtAssets.sprite(canvas, "ships/" + id, at - Vector2.from_angle(angle) * recoil * 1.8, dimensions, angle + lean, Vector2.ZERO, Color(1.0 + hit * 0.35, 1.02 + hit * 0.35, 1.04 + hit * 0.35))

static func muzzle(canvas: CanvasItem, at: Vector2, angle: float, power: float, color: Color, size: float = 1.0) -> void:
	if power <= 0.01: return
	ArtAssets.sprite(canvas, "fx/spark", at, Vector2(34, 19) * size * (0.55 + power * 0.45), angle, Vector2.ZERO, Color(color, power))

static func debris(canvas: CanvasItem, at: Vector2, direction: Vector2, age: float, life: float, color: Color, count: int = 4) -> void:
	var points := PackedVector2Array()
	for i in count:
		var ray := direction.rotated((i - (count - 1) * 0.5) * 0.58)
		var end := at + ray * (7 + age * (32 + i * 9))
		points.append_array(PackedVector2Array([end - ray * (3 + life * 8), end]))
	canvas.draw_multiline(points, Color(color, life), 1.5, true)

static func effect(canvas: CanvasItem, e: Dictionary, reduced: bool) -> void:
	var kind := str(e.kind)
	var at: Vector2 = e.pos
	var life := clampf(float(e.ttl) / maxf(0.01, float(e.get("max_ttl", 0.5))), 0, 1)
	var age := 1.0 - life
	var radius := maxf(12, float(e.get("radius", 20)))
	var source: Vector2 = e.get("end", at - Vector2.RIGHT)
	var direction := (at - source).normalized() if at.distance_to(source) > 0.1 else Vector2.RIGHT
	if kind == "lightning":
		var points := PackedVector2Array()
		for i in 9:
			var f := i / 8.0
			points.append(at.lerp(source, f) + (source - at).orthogonal().normalized() * sin(f * PI) * sin(i * 8.0 + life * 19.0) * (2 if reduced else 8))
		canvas.draw_polyline(points, Color(CYAN, life * 0.32), 7, true)
		canvas.draw_polyline(points, Color(WHITE, life), 1.6, true)
		return
	if kind == "pickup":
		ArtAssets.sprite(canvas, "fx/spark", at, Vector2.ONE * (14 + age * 14), age, Vector2.ZERO, Color(CYAN, life))
		if not reduced: debris(canvas, at, Vector2.UP, age, life, CYAN, 3)
		return
	if kind in ["hit", "fire", "missile"]:
		muzzle(canvas, at, direction.angle(), life, GOLD if kind != "hit" else WHITE, 0.8)
		if not reduced: debris(canvas, at, direction, age, life, GOLD, 3)
		return
	if kind in ["death", "meteor_impact", "hazard_start", "impact_blast", "impact_meteor"]:
		var spread := 1.5 if reduced else 1.0 + age * 1.3
		ArtAssets.sprite(canvas, "fx/explosion", at, Vector2.ONE * radius * spread, 0.0 if reduced else age * 0.7, Vector2.ZERO, Color(1.1, 1.04, 1.0, life * (0.3 if reduced else 0.72)))
		if not reduced: debris(canvas, at, direction, age * 2, life, GOLD, 6)
		return
	var color := CYAN if kind in ["pulse", "level", "reward", "arrival"] else (GOLD if kind == "guard" else Color("ff8593"))
	if kind == "dash":
		ArtAssets.sprite(canvas, "fx/thrust", at, Vector2(radius * 2, radius * 0.7), direction.angle(), Vector2.ZERO, Color(CYAN, life * 0.75))
		return
	var spread := 1.0 if reduced else 0.6 + age * 1.4
	ArtAssets.sprite(canvas, "fx/wave", at, Vector2.ONE * radius * 2 * spread, 0.0 if reduced else age * 0.2, Vector2.ZERO, Color(color, life * 0.65))
	if not reduced and not kind.begins_with("impact_"):
		for i in 4:
			var ray := Vector2.from_angle(i * TAU / 4 + age * 0.35)
			ArtAssets.sprite(canvas, "fx/spark", at + ray * radius * age, Vector2(12, 5) * life, ray.angle(), Vector2.ZERO, Color(color, life))

static func orbital(canvas: CanvasItem, at: Vector2, kind: String, angle: float, size: float, time: float, reduced: bool) -> void:
	var turn := angle if reduced else angle + (time * 3.5 if kind == "blade" else sin(time * 5) * 0.12)
	ArtAssets.sprite(canvas, "objects/" + kind, at, Vector2.ONE * size, turn, Vector2.ZERO, Color("b1edff") if kind == "frost" else (Color("ffb6b2") if kind == "blade" else Color.WHITE))
	if kind == "frost":
		ArtAssets.sprite(canvas, "fx/spark", at, Vector2.ONE * size * 0.4, turn, Vector2.ZERO, Color(CYAN, 0.65))

static func title(canvas: CanvasItem, center: Vector2, time: float, reduced: bool) -> String:
	var slot := int(time / 8.0) % 3
	var id: String = ["striker", "scout", "bastion"][slot]
	var t := 3.0 if reduced else fposmod(time, 8.0)
	var entry := smoothstep(0.0, 1.0, t)
	var exit := smoothstep(6.8, 8.0, t)
	var travel := Vector2((1 - entry) * 260 + exit * 320, 0)
	var drift := Vector2(sin(t * 1.1) * 22, sin(t * 1.7) * 20)
	if id == "scout": drift += Vector2(sin(t * 1.8) * 44, cos(t * 1.8) * 24)
	if id == "bastion": drift *= 0.45
	var at := center + (Vector2.ZERO if reduced else travel + drift)
	var angle := -0.28 + (0.0 if reduced else sin(t * 1.2) * (0.22 if id == "scout" else 0.08))
	var facing := Vector2.from_angle(angle)
	var wing := facing.orthogonal()
	var power := 0.5 + absf(sin(t * 1.1)) * 0.5
	var firing := not reduced and t > 1.3 and t < 6.5
	var recoil := maxf(0, 1.0 - fposmod(t, 0.48) / 0.12) if firing else 0.0
	for side: int in [-1, 1]: engine(canvas, at - facing * 86 + wing * side * 23, angle, power, time, CYAN if id != "bastion" else GOLD, 2.5, reduced)
	hull(canvas, id, at, angle, 222, time, power, recoil, 0, reduced)
	for i in 3:
		var orbit := (0.0 if reduced else time) * (0.8 if id == "bastion" else 1.4) + TAU * i / 3
		orbital(canvas, at + Vector2.from_angle(orbit) * 132, "frost" if id == "bastion" else "normal", orbit, 31, time, reduced)
	if firing:
		for side: int in [-1, 1]:
			var start := at + facing * 88 + wing * side * 22
			muzzle(canvas, start, angle, recoil, GOLD, 1.8)
			for i in 3:
				var progress := fposmod(t * 1.9 + i / 3.0, 1.0)
				var shot := start + facing.rotated(side * 0.03) * progress * 230
				ArtAssets.sprite(canvas, "fx/thrust", shot, Vector2(32, 9), angle, Vector2.ZERO, Color(CYAN, 1 - progress))
		var m := fposmod(t * 0.65, 1.0)
		var missile := at + facing * (40 + m * 220) + wing * (55 + sin(m * PI) * 60)
		engine(canvas, missile - facing * 14, angle, 0.7, time, GOLD, 0.9, reduced)
		ArtAssets.sprite(canvas, "objects/missile", missile, Vector2(34, 20), angle)
	if id == "bastion": ArtAssets.sprite(canvas, "fx/wave", at, Vector2.ONE * (270 + 12 * sin(t * 2)), 0.0 if reduced else time * 0.1, Vector2.ZERO, Color(GOLD, 0.2))
	return id

