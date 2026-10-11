extends Control

var kind := "upgrade"
var glyph_id := "power"
var tint := Color("72dce6")

static func polygon(canvas: CanvasItem, at: Vector2, radius: float, sides: int, color: Color, angle: float = 0) -> void:
	var points := PackedVector2Array()
	for i in sides:
		points.append(at + Vector2.from_angle(angle + TAU * i / sides) * radius)
	canvas.draw_colored_polygon(points, color)

static func ship(canvas: CanvasItem, at: Vector2, id: String, color: Color, scale: float = 1, angle: float = 0) -> void:
	var facing := Vector2.from_angle(angle)
	var wing := facing.orthogonal()
	var sides := 3 if id == "scout" else (6 if id == "bastion" else 4)
	polygon(canvas, at, 18 * scale, sides, Color("09121f"), angle)
	polygon(canvas, at, 15 * scale, sides, color, angle)
	polygon(canvas, at, 6 * scale, sides, Color("09121f"), angle)
	for side in [-1.0, 1.0]:
		if id == "striker":
			canvas.draw_line(at + wing * side * 8 * scale, at + (wing * side * 8 + facing * 27) * scale, color, 4 * scale, true)
		elif id == "scout":
			canvas.draw_line(at + facing * 9 * scale, at + (-facing * 12 + wing * side * 22) * scale, color, 2 * scale, true)
		else:
			polygon(canvas, at + wing * side * 18 * scale, 8 * scale, 6, color, angle)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var at := size * 0.5
	var radius := minf(size.x, size.y) * 0.42
	if kind == "ship":
		draw_arc(at, radius, 0, TAU, 48, Color(tint, 0.18), 1, true)
		ship(self, at, glyph_id, tint, radius / 36, -PI * 0.15)
	elif kind == "sector":
		draw_circle(at, radius, Color(tint, 0.07), true, -1, true)
		for ring in 3:
			draw_arc(at, radius * (0.48 + ring * 0.25), 0, TAU, 40, Color(tint, 0.28 + ring * 0.15), 1, true)
		if glyph_id == "storm":
			draw_polyline(PackedVector2Array([at + Vector2(-radius, -radius * 0.6), at + Vector2(radius * 0.2, 0), at + Vector2(-radius * 0.2, 0), at + Vector2(radius, radius * 0.6)]), tint, 3, true)
		elif glyph_id == "forge":
			for i in 3:
				var point := at + Vector2.from_angle(i * 2.1) * radius * 0.5
				draw_arc(point, radius * 0.3, 0, TAU, 24, tint, 2, true)
		else:
			draw_arc(at, radius * 0.7, -0.5, 2.3, 32, tint, 3, true)
	else:
		polygon(self, at, radius, 6, Color(tint, 0.12), PI / 6)
		var mapped: String = {"vitality": "heal", "chain": "stun", "pulse": "emp", "restore": "heal"}.get(glyph_id, glyph_id)
		if mapped in ItemCatalog.IDS:
			ItemCatalog.draw_icon(self, at, mapped, tint, radius / 22)
		else:
			var sides := 3 if glyph_id in ["blade", "missile", "salvo", "rail"] else (6 if glyph_id in ["frost", "blizzard"] else 4)
			polygon(self, at, radius * 0.58, sides, tint, -PI / 2)
			polygon(self, at, radius * 0.28, sides, Color("121f2e"), -PI / 2)
