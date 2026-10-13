extends RefCounted

# Small windows use physical pixel sizes so the desktop canvas cannot shrink text/touch targets.
static func apply(game: Node2D) -> void:
	if game.screen in ["playing", "replay"] or game.ui.has_node("CompactScroll") or game.ui.has_meta("fitted_menu"):
		return
	var window := Vector2(DisplayServer.window_get_size())
	if (window.x >= 900 and not game.touch_mode) or window.x < 1:
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
	if game.screen in ["menu", "hangar", "upgrade"]:
		_fit_core(game, controls, window)
		return
	controls.sort_custom(func(a: Control, b: Control) -> bool: return a.position.x < b.position.x if is_equal_approx(float(a.get_meta("flow_order", a.position.y)), float(b.get_meta("flow_order", b.position.y))) else float(a.get_meta("flow_order", a.position.y)) < float(b.get_meta("flow_order", b.position.y)))
	var launch: Button
	if game.screen == "hangar":
		for control in controls.duplicate():
			if control is Button and int(control.get_meta("flow_order", 0)) == 750:
				launch = control
				controls.erase(control)
	var scroll := ScrollContainer.new()
	scroll.name = "CompactScroll"
	scroll.size = window
	if launch: scroll.size.y -= 76
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
	if launch:
		launch.position = Vector2(20, window.y - 66)
		launch.size = Vector2(window.x - 40, 56)
		game.ui.move_child(launch, game.ui.get_child_count() - 1)

static func _place(control: Control, rect: Rect2, font_size: int = 16) -> void:
	control.position = rect.position
	control.visible = true
	if control is Label or control is Button:
		control.add_theme_font_size_override("font_size", font_size)
		control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control.reset_size()
	control.size = rect.size
	control.set_deferred("size", rect.size)
	if control is Button:
		# Compact touch targets have no animated displacement or focus scrolling.
		control.reduced = true
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var style: StyleBoxFlat = control.get_theme_stylebox(state).duplicate()
			style.content_margin_left = 6
			style.content_margin_right = 6
			control.add_theme_stylebox_override(state, style)

static func _fit_core(game: Node2D, controls: Array[Control], window: Vector2) -> void:
	game.ui.set_meta("fitted_menu", true)
	game.ui.size = window
	game.ui.scale = Vector2.ONE * game.get_viewport_rect().size.x / window.x
	game.ui.get_parent().offset = Vector2.ZERO
	var w := window.x
	var h := window.y
	var portrait := h > w
	var gap := 8.0
	for control in controls: control.hide()
	match game.screen:
		"menu":
			var buttons: Array[Control] = []
			for c in controls:
				if c is Button: buttons.append(c)
				if c is Label and c.text == "오빗 브레이커":
					_place(c, Rect2(16, h * 0.1, w - 32, 54), 32 if portrait else 38)
				if c is Label and c.text == "돌진하고, 성장하고, 궤도를 지켜라.":
					_place(c, Rect2(16, h * 0.1 + 60, w - 32, 30), 16)
				if c is Label and c.text.begins_with("최고 "):
					_place(c, Rect2(16, h - 42, w - 32, 30), 13)
			var start := maxf(h * 0.33, h * 0.1 + 98)
			var cols := 1 if portrait else 2
			var rows := ceili(float(buttons.size()) / cols)
			var bh := minf(64, (h - start - 62) / rows - gap)
			for i in buttons.size():
				var bw := (w - 32 - gap * (cols - 1)) / cols
				_place(buttons[i], Rect2(16 + (i % cols) * (bw + gap), start + (i / cols) * (bh + gap), bw, bh), 18)
		"hangar":
			var ships: Array[Control] = []
			var sectors: Array[Control] = []
			var modes: Array[Control] = []
			for c in controls:
				if c is Label and c.text == "출격 준비": _place(c, Rect2(12, 6, 140, 34), 25)
				if c is LineEdit: _place(c, Rect2(160, 8, w - 172, 34))
				if not c is Button: continue
				if c.text.is_empty():
					if c.get_child(0).kind == "ship": ships.append(c)
					else: sectors.append(c)
				elif c.text == "돌아가기": _place(c, Rect2(12, h - 56, 100, 44), 15)
				elif int(c.get_meta("flow_order", 0)) == 750: _place(c, Rect2(120, h - 56, w - 132, 44), 18)
				else: modes.append(c)
			var mode_rows := 2 if portrait else 1
			var mode_top := h - 60 - mode_rows * 48
			var sector_h := clampf(h * 0.15, 76, 112) if portrait else 78.0
			var sector_top := mode_top - sector_h - gap
			var ship_top := 48.0
			var ship_h := (sector_top - ship_top - gap * 3) / 3 if portrait else sector_top - ship_top - gap
			for i in ships.size():
				var cw := w - 24 if portrait else (w - 40) / 3
				var card := ships[i]
				_place(card, Rect2(12 if portrait else 12 + i * (cw + gap), ship_top + i * (ship_h + gap) if portrait else ship_top, cw, ship_h))
				_place(card.get_child(0), Rect2(6, 8, 48, 48))
				_place(card.get_child(1), Rect2(60, 6, cw - 68, 25), 17)
				var info: Dictionary = preload("res://scripts/game_content.gd").ship_info(["striker", "scout", "bastion"][i])
				card.get_child(2).text = "%dHP · 속%d · 위%d" % [info.hp, info.speed, info.orbits]
				_place(card.get_child(2), Rect2(60, 32, cw - 68, 20), 12)
				card.get_child(3).text = ["자동포 +8~45% · 관성 조준\n고속 이동·급선회 시 충전 감소", "돌진 피해 ×1.75\n돌진 후 1.4초 속도 +35%", "8초마다 방벽 · 피해 -60%\n방벽 피격 시 근거리 반격"][i]
				_place(card.get_child(3), Rect2(10, 52, cw - 20, ship_h - 55), 12)
			for i in sectors.size():
				var cw := (w - 40) / 3
				var card := sectors[i]
				_place(card, Rect2(12 + i * (cw + gap), sector_top, cw, sector_h))
				card.get_child(0).hide()
				card.get_child(2).text = ["고속 포위\n화력 기체 유리", "교차 번개\n기동 기체 유리", "붕괴 가속\n내구 기체 유리"][i]
				_place(card.get_child(1), Rect2(6, 5, cw - 12, 24), 14 if portrait else 17)
				_place(card.get_child(2), Rect2(6, 30, cw - 12, sector_h - 34), 12 if portrait else 13)
			for i in modes.size():
				var cols := 2 if portrait else 4
				var cw := (w - 24 - gap * (cols - 1)) / cols
				_place(modes[i], Rect2(12 + (i % cols) * (cw + gap), mode_top + (i / cols) * 48, cw, 44), 14)
				for child in modes[i].get_children(): child.hide()
		"upgrade":
			var cards: Array[Control] = []
			for c in controls:
				if c is Label and c.text.begins_with("다음 궤도"):
					_place(c, Rect2(12, 8, w - 24, 32), 22)
				if c is Label and c.text.begins_with("전투 정지"):
					c.text = "전투 정지 · 수리 효율 %d%% · 카드를 눌러 선택" % roundi(game.run.repair_efficiency() * 100)
					_place(c, Rect2(12, 42, w - 24, 22), 12)
				if c is Button and c.text.is_empty(): cards.append(c)
			var count := cards.size()
			for i in count:
				var cw := w - 24 if portrait else (w - 24 - gap * (count - 1)) / count
				var ch := (h - 80 - gap * (count - 1)) / count if portrait else h - 80
				var card := cards[i]
				_place(card, Rect2(12 if portrait else 12 + i * (cw + gap), 70 + i * (ch + gap) if portrait else 70, cw, ch))
				_place(card.get_child(0), Rect2(8, 8, 30, 30))
				_place(card.get_child(1), Rect2(10, 34, cw - 20, 18), 12)
				_place(card.get_child(2), Rect2(44, 7, cw - 54, 27), 17)
				var description: Label = card.get_child(3)
				var description_h := description.get_theme_font("font").get_multiline_string_size(description.text, HORIZONTAL_ALIGNMENT_LEFT, cw - 20, 13).y + 4
				_place(description, Rect2(10, 55, cw - 20, description_h), 13)
				var delta: Label = card.get_child(4)
				var delta_y := 55 + description_h + 5
				var delta_h := delta.get_theme_font("font").get_multiline_string_size(delta.text, HORIZONTAL_ALIGNMENT_LEFT, cw - 20, 12).y + 4
				_place(delta, Rect2(10, delta_y, cw - 20, delta_h), 12)
				var links_y := delta_y + delta_h + 5
				var links: ScrollContainer = card.get_child(5)
				links.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
				links.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
				links.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var label: Label = links.get_child(0)
				label.text = game._upgrade_links(str(game.choices[i].id) if game.choices[i] is Dictionary else str(game.choices[i]), true)
				var fs := 12
				while fs > 10:
					var height := label.get_theme_font("font").get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, cw - 20, fs).y
					height += label.get_theme_constant("line_spacing") * maxi(0, ceili(height / label.get_theme_font("font").get_height(fs)) - 1)
					if height <= ch - links_y - 6: break
					fs -= 1
				_place(links, Rect2(10, links_y, cw - 20, ch - links_y - 6))
				label.add_theme_font_size_override("font_size", fs)
				label.custom_minimum_size = Vector2(cw - 20, 0)
				label.size = Vector2(cw - 20, 0)

static func _layout(control: Control, width: float) -> float:
	# Wide compact upgrade cards show the name and effect before scrolling into recipes.
	if control is Button and control.text.is_empty() and width >= 600 and control.get_child_count() == 6 and control.get_child(5) is ScrollContainer:
		var icon: Control = control.get_child(0)
		icon.position = Vector2(16, 12)
		icon.size = Vector2(40, 40)
		var rank: Label = control.get_child(1)
		rank.position = Vector2(width - 220, 18)
		rank.size = Vector2(200, 30)
		rank.add_theme_font_size_override("font_size", 18)
		var title: Label = control.get_child(2)
		title.position = Vector2(72, 12)
		title.size = Vector2(width - 310, 36)
		title.add_theme_font_size_override("font_size", 24)
		var y := 64.0
		for i in [3, 4, 5]:
			var child: Control = control.get_child(i)
			var height := _layout(child, width - 36)
			child.position = Vector2(18, y)
			child.size = Vector2(width - 36, height)
			y += height + 10
		return y + 8
	if control is ScrollContainer and control.get_child_count()==1 and control.get_child(0) is Label:
		var label: Label=control.get_child(0)
		var height := _layout(label,width-16)
		label.custom_minimum_size=Vector2(width-16,height)
		return clampf(height,96,200)
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
