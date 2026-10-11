extends RefCounted

# Small windows use physical pixel sizes so the desktop canvas cannot shrink text/touch targets.
static func apply(game: Node2D) -> void:
	if game.screen in ["playing", "replay"] or game.ui.has_node("CompactScroll"):
		return
	var window := Vector2(DisplayServer.window_get_size())
	if window.x >= 900 or window.x < 1:
		return
	var controls: Array[Control] = []
	for child in game.ui.get_children():
		if child is Control and child.name != "Shade":
			controls.append(child)
	# Existing cards keep their content and callbacks; only their layout changes.
	for panel in controls.duplicate():
		if not (panel is Panel or (panel is Button and panel.text.is_empty())):
			continue
		for child in controls.duplicate():
			if child == panel or child is Panel:
				continue
			if Rect2(panel.position, panel.size).encloses(Rect2(child.position, child.size)):
				child.position -= panel.position
				child.reparent(panel, false)
				controls.erase(child)
	controls.sort_custom(func(a: Control, b: Control) -> bool: return a.position.x < b.position.x if is_equal_approx(float(a.get_meta("flow_order", a.position.y)), float(b.get_meta("flow_order", b.position.y))) else float(a.get_meta("flow_order", a.position.y)) < float(b.get_meta("flow_order", b.position.y)))
	var scroll := ScrollContainer.new()
	scroll.name = "CompactScroll"
	scroll.size = window
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	game.ui.add_child(scroll)
	var content := Control.new()
	content.custom_minimum_size.x = window.x - 16
	scroll.add_child(content)
	var y := 24.0
	for control in controls:
		control.reparent(content, false)
		control.position = Vector2(20, y)
		control.size = Vector2(window.x - 56, _layout(control, window.x - 56))
		y += control.size.y + 16
	content.custom_minimum_size.y = y + 24
	game.ui.scale = Vector2.ONE * game.get_viewport_rect().size.x / window.x
	game.ui.get_parent().offset = Vector2.ZERO

static func _layout(control: Control, width: float) -> float:
	if control is Label:
		var size := clampi(control.get_theme_font_size("font_size"), 18, 28)
		control.add_theme_font_size_override("font_size", size)
		control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		control.size.x = width
		var height := maxf(32, control.get_theme_font("font").get_multiline_string_size(control.text, HORIZONTAL_ALIGNMENT_LEFT, width, size).y + 8)
		control.set_deferred("size", Vector2(width, height))
		return height
	if control.get_child_count() > 0 and (control is Panel or control is Button):
		var children: Array[Control] = []
		for child in control.get_children():
			if child is Control:
				children.append(child)
		children.sort_custom(func(a: Control, b: Control) -> bool: return a.position.y < b.position.y)
		var y := 18.0
		for child in children:
			var h := _layout(child, width - 36)
			child.position = Vector2(18, y)
			child.size = Vector2(width - 36, h)
			y += h + 10
		return y + 8
	if control is Button:
		control.add_theme_font_size_override("font_size", 18)
		control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		control.size.x = width
		return maxf(56, control.get_theme_font("font").get_multiline_string_size(control.text, HORIZONTAL_ALIGNMENT_CENTER, width - 44, 18).y + 24)
	if control is RichTextLabel:
		return 360
	if control is ColorRect:
		return 4
	if control.get_script() == preload("res://scripts/ui_glyph.gd"):
		return 90
	return maxf(56, control.size.y)
