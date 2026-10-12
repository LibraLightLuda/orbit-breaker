class_name ArtAssets
extends RefCounted

const TEXTURES := {
	"ships/bastion": preload("res://assets/art/ships/bastion.png"),
	"ships/scout": preload("res://assets/art/ships/scout.png"),
	"ships/striker": preload("res://assets/art/ships/striker.png"),
	"enemies/boss": preload("res://assets/art/enemies/boss.png"),
	"enemies/chaser": preload("res://assets/art/enemies/chaser.png"),
	"enemies/elite_artillery": preload("res://assets/art/enemies/elite_artillery.png"),
	"enemies/elite_assault": preload("res://assets/art/enemies/elite_assault.png"),
	"enemies/runner": preload("res://assets/art/enemies/runner.png"),
	"enemies/shooter": preload("res://assets/art/enemies/shooter.png"),
	"enemies/tank": preload("res://assets/art/enemies/tank.png"),
	"world/forge": preload("res://assets/art/world/forge.png"),
	"world/ring": preload("res://assets/art/world/ring.png"),
	"world/storm": preload("res://assets/art/world/storm.png"),
	"objects/axe": preload("res://assets/art/objects/axe.png"),
	"objects/blade": preload("res://assets/art/objects/blade.png"),
	"objects/core": preload("res://assets/art/objects/core.png"),
	"objects/drive": preload("res://assets/art/objects/drive.png"),
	"objects/frost": preload("res://assets/art/objects/frost.png"),
	"objects/heal": preload("res://assets/art/objects/heal.png"),
	"objects/meteor": preload("res://assets/art/objects/meteor.png"),
	"objects/mine": preload("res://assets/art/objects/mine.png"),
	"objects/missile": preload("res://assets/art/objects/missile.png"),
	"objects/normal": preload("res://assets/art/objects/normal.png"),
	"objects/planet": preload("res://assets/art/objects/planet.png"),
	"objects/sentry": preload("res://assets/art/objects/sentry.png"),
	"objects/shell": preload("res://assets/art/objects/shell.png"),
	"objects/xp": preload("res://assets/art/objects/xp.png"),
	"ui/achievement": preload("res://assets/art/ui/achievement.svg"),
	"ui/aegis": preload("res://assets/art/ui/aegis.svg"),
	"ui/battery": preload("res://assets/art/ui/battery.svg"),
	"ui/blade": preload("res://assets/art/ui/blade.svg"),
	"ui/blizzard": preload("res://assets/art/ui/blizzard.svg"),
	"ui/bounty": preload("res://assets/art/ui/bounty.svg"),
	"ui/burst": preload("res://assets/art/ui/burst.svg"),
	"ui/cataclysm": preload("res://assets/art/ui/cataclysm.svg"),
	"ui/chain": preload("res://assets/art/ui/chain.svg"),
	"ui/citadel": preload("res://assets/art/ui/citadel.svg"),
	"ui/core": preload("res://assets/art/ui/core.svg"),
	"ui/dash": preload("res://assets/art/ui/dash.svg"),
	"ui/dash_hits": preload("res://assets/art/ui/dash_hits.svg"),
	"ui/drive": preload("res://assets/art/ui/drive.svg"),
	"ui/ellipse": preload("res://assets/art/ui/ellipse.svg"),
	"ui/emp": preload("res://assets/art/ui/emp.svg"),
	"ui/focus_amp": preload("res://assets/art/ui/focus_amp.svg"),
	"ui/focus_memory": preload("res://assets/art/ui/focus_memory.svg"),
	"ui/fortune": preload("res://assets/art/ui/fortune.svg"),
	"ui/frenzy": preload("res://assets/art/ui/frenzy.svg"),
	"ui/frost": preload("res://assets/art/ui/frost.svg"),
	"ui/guard_pulse": preload("res://assets/art/ui/guard_pulse.svg"),
	"ui/guard_reserve": preload("res://assets/art/ui/guard_reserve.svg"),
	"ui/haste": preload("res://assets/art/ui/haste.svg"),
	"ui/hatchet": preload("res://assets/art/ui/hatchet.svg"),
	"ui/heal": preload("res://assets/art/ui/heal.svg"),
	"ui/insight": preload("res://assets/art/ui/insight.svg"),
	"ui/lancer": preload("res://assets/art/ui/lancer.svg"),
	"ui/magnet": preload("res://assets/art/ui/magnet.svg"),
	"ui/minefield": preload("res://assets/art/ui/minefield.svg"),
	"ui/missile": preload("res://assets/art/ui/missile.svg"),
	"ui/normal": preload("res://assets/art/ui/normal.svg"),
	"ui/nova": preload("res://assets/art/ui/nova.svg"),
	"ui/orbit": preload("res://assets/art/ui/orbit.svg"),
	"ui/orbit_range": preload("res://assets/art/ui/orbit_range.svg"),
	"ui/outer": preload("res://assets/art/ui/outer.svg"),
	"ui/outer_kills": preload("res://assets/art/ui/outer_kills.svg"),
	"ui/overdrive": preload("res://assets/art/ui/overdrive.svg"),
	"ui/power": preload("res://assets/art/ui/power.svg"),
	"ui/pulse": preload("res://assets/art/ui/pulse.svg"),
	"ui/rail": preload("res://assets/art/ui/rail.svg"),
	"ui/rapid": preload("res://assets/art/ui/rapid.svg"),
	"ui/relaxed": preload("res://assets/art/ui/relaxed.svg"),
	"ui/repair": preload("res://assets/art/ui/repair.svg"),
	"ui/restore": preload("res://assets/art/ui/restore.svg"),
	"ui/returns": preload("res://assets/art/ui/returns.svg"),
	"ui/salvo": preload("res://assets/art/ui/salvo.svg"),
	"ui/scout_drive": preload("res://assets/art/ui/scout_drive.svg"),
	"ui/scout_lance": preload("res://assets/art/ui/scout_lance.svg"),
	"ui/sentry": preload("res://assets/art/ui/sentry.svg"),
	"ui/shell": preload("res://assets/art/ui/shell.svg"),
	"ui/shield": preload("res://assets/art/ui/shield.svg"),
	"ui/speed": preload("res://assets/art/ui/speed.svg"),
	"ui/storm": preload("res://assets/art/ui/storm.svg"),
	"ui/stun": preload("res://assets/art/ui/stun.svg"),
	"ui/superorbit": preload("res://assets/art/ui/superorbit.svg"),
	"ui/survive": preload("res://assets/art/ui/survive.svg"),
	"ui/trinity": preload("res://assets/art/ui/trinity.svg"),
	"ui/veteran": preload("res://assets/art/ui/veteran.svg"),
	"ui/vitality": preload("res://assets/art/ui/vitality.svg"),
	"ui/wake": preload("res://assets/art/ui/wake.svg"),
	"fx/black_hole": preload("res://assets/art/fx/black_hole.png"),
	"fx/container": preload("res://assets/art/fx/container.png"),
	"fx/explosion": preload("res://assets/art/fx/explosion.png"),
	"fx/projectile": preload("res://assets/art/fx/projectile.svg"),
	"fx/spark": preload("res://assets/art/fx/spark.png"),
	"fx/thrust": preload("res://assets/art/fx/thrust.png"),
	"fx/wave": preload("res://assets/art/fx/wave.png"),
}

static func texture(id: String) -> Texture2D:
	assert(TEXTURES.has(id), "Missing production art: " + id)
	return TEXTURES.get(id)

static func sprite(canvas: CanvasItem, id: String, at: Vector2, size: Vector2, angle: float = 0.0, offset: Vector2 = Vector2.ZERO, tint: Color = Color.WHITE) -> void:
	if is_zero_approx(angle):
		canvas.draw_texture_rect(texture(id), Rect2(at - size * 0.5, size), false, tint)
		return
	var x := Vector2.from_angle(angle) * size.x * 0.5
	var y := x.orthogonal() * (size.y / size.x)
	# Keep the caller transform so repeated hulls can share a canvas batch.
	canvas.draw_primitive(PackedVector2Array([at-x-y, at+x-y, at+x+y, at-x+y]), PackedColorArray([tint]), PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]), texture(id))

static func icon(canvas: CanvasItem, at: Vector2, id: String, color: Color, scale: float = 1.0) -> void:
	canvas.draw_texture_rect(texture("ui/" + id), Rect2(at - Vector2.ONE * 18 * scale, Vector2.ONE * 36 * scale), false, color)

static func container(canvas: CanvasItem, at: Vector2, grade: String, radius: float) -> void:
	canvas.draw_texture_rect(texture("fx/container"), Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2), false)
	var rank: int = ["C","B","A"].find(grade) + 1
	var color: Color = {"C":Color("72dce6"),"B":Color("a798ff"),"A":Color("ffd18a")}.get(grade,Color.WHITE)
	for side in 4:
		for segment in rank:
			var a := PI * 0.25 + side * PI * 0.5 + (segment - rank * 0.5) * 0.18
			canvas.draw_arc(at, radius, a, a + 0.12, 3, color, 2, true)

static func achievement_icon(id: String) -> String:
	if id in ["item_types","part_types","evolved"]: return {"item_types":"power","part_types":"trinity","evolved":"superorbit"}[id]
	if id.begins_with("ship_"): return "normal"
	if id.begins_with("sector_"): return "outer"
	if id.begins_with("hull_"): return id.trim_prefix("hull_")
	if TEXTURES.has("ui/" + id): return id
	var family: String = id.rsplit("_", true, 1)[0]
	return {"missions":"survive", "parts":"core", "items":"power", "items_a":"bounty", "items_risky":"outer", "runs":"normal", "kills":"rail", "wins":"achievement", "dashes":"dash", "overdrives":"overdrive", "returns":"returns", "elites":"focus_amp", "time":"survive", "combo":"chain", "evolved":"superorbit", "item_types":"power", "part_types":"trinity"}.get(family, "achievement")
