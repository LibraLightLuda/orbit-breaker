extends Control

var item_id := ""
var grade := "C"
var known := true

func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, 21, Color("09121f"))
	draw_arc(center, 21, 0, TAU, 32, ItemCatalog.grade_color(grade), 2, true)
	if known:
		ItemCatalog.draw_icon(self, center, item_id, Color("eef3e7"))
	else:
		var text_font := get_theme_default_font()
		draw_string(text_font, center + Vector2(-6, 7), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("8b9ba9"))
