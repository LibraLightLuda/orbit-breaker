extends Control
var kind := "upgrade"
var glyph_id := "power"
var tint := Color("72dce6")
static func ship(canvas: CanvasItem, at: Vector2, id: String, _color: Color, scale: float = 1.0, angle: float = 0.0) -> void:
	ArtAssets.sprite(canvas, "ships/" + id, at, Vector2.ONE * 44 * scale, angle)
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var at := size * 0.5
	var side := minf(size.x, size.y)
	match kind:
		"ship": ship(self, at, glyph_id, tint, side / 44.0)
		"sector":
			draw_texture_rect(ArtAssets.texture("world/" + glyph_id), Rect2(Vector2.ZERO, size), false)
			draw_arc(at, side * 0.37, -0.4, PI * 1.7, 40, tint, 1.5, true)
		_:
			var id := glyph_id
			if kind == "achievement" and id.begins_with("ship_"):
				ship(self, at, id.trim_prefix("ship_"), tint, side / 44.0)
				return
			if kind == "achievement": id = ArtAssets.achievement_icon(glyph_id)
			ArtAssets.icon(self, at, id, tint, side / 36.0)
