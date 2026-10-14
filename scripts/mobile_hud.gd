extends Control

var game: Node2D
var pause: Button
var codex: Button
var dash: Button
var overdrive: Button
var final_accept: Button
var final_decline: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for title in ["Ⅱ", "도감", "돌진", "오버드라이브", "최종 작전 도전", "생존 계속"]:
		var button := preload("res://scripts/motion_button.gd").new()
		button.text = title
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 16)
		for state in ["normal", "pressed", "hover", "focus"]:
			var style: StyleBoxFlat = game._style(Color(game.BG, 0.8), game.LINE if state == "normal" else game.CYAN)
			style.content_margin_left = 6
			style.content_margin_right = 6
			style.content_margin_top = 6
			style.content_margin_bottom = 6
			button.add_theme_stylebox_override(state, style)
		button.reduced = bool(game.records.data.reduced_motion)
		add_child(button)
	pause = get_child(0)
	codex = get_child(1)
	dash = get_child(2)
	overdrive = get_child(3)
	final_accept = get_child(4)
	final_decline = get_child(5)
	final_accept.visible = false
	final_decline.visible = false
	final_accept.pressed.connect(func() -> void: game.run.select_finale(true))
	final_decline.pressed.connect(func() -> void: game.run.select_finale(false))
	pause.pressed.connect(game._show_pause)
	codex.pressed.connect(func() -> void: game._open_arsenal("pause"))
	dash.pressed.connect(func() -> void: game._touch_skill("dash", game.run.player - game.camera_offset + game.run.facing * 80))
	overdrive.pressed.connect(func() -> void: game._touch_skill("overdrive", Vector2.ZERO))

func fit() -> void:
	var window := Vector2(DisplayServer.window_get_size())
	if window.x < 1: window = game.get_viewport_rect().size
	size = window
	scale = Vector2.ONE * game.get_viewport_rect().size.x / window.x
	position = -game.position
	pause.position = Vector2(window.x - 56, 8)
	pause.size = Vector2(48, 44)
	codex.position = Vector2(window.x - 112, 8)
	codex.size = Vector2(48, 44)
	dash.position = Vector2(window.x - 224, window.y - 58)
	dash.size = Vector2(96, 48)
	overdrive.position = Vector2(window.x - 120, window.y - 58)
	overdrive.size = Vector2(112, 48)
	final_accept.position = Vector2(12, 61)
	final_accept.size = Vector2(window.x / 2 - 18, 44)
	final_decline.position = Vector2(window.x / 2 + 6, 61)
	final_decline.size = Vector2(window.x / 2 - 18, 44)

func _process(_delta: float) -> void:
	final_accept.visible = game.run.finale_status == "preview"
	final_decline.visible = final_accept.visible
	final_accept.text = ("✓ " if game.run.finale_selected else "") + "최종 작전 도전"
	final_decline.text = ("✓ " if not game.run.finale_selected else "") + "생존 계속"
	queue_redraw()

func _draw() -> void:
	if game == null: return
	var model: RunModel = game.run
	var w := size.x
	var h := size.y
	var white: Color = game.INK
	var cyan: Color = game.CYAN
	var font: Font = game.font
	draw_rect(Rect2(0, 0, w, 81), Color(game.BG, 0.86))
	var hp_width := minf(190, w * 0.3)
	draw_string(font, Vector2(12, 25), "%d / %d" % [ceili(model.hp), int(model.max_hp)], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, white)
	draw_line(Vector2(12, 36), Vector2(12 + hp_width, 36), game.LINE, 5)
	draw_line(Vector2(12, 36), Vector2(12 + hp_width * clampf(model.hp / model.max_hp, 0, 1), 36), game.LIME, 5)
	draw_string(font, Vector2(12, 57), "%+.1f/s · 추진 %d%%" % [model.net_hull_rate(), roundi(model.current_speed / model.base_speed() * 100)], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, cyan)
	draw_string(font, Vector2(w * 0.42, 25), game._time(model.elapsed), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, white)
	var status := "위험 %d · %d 처치" % [model.boundary_layer(model.player), model.kills]
	for hazard: Dictionary in model.hazards:
		if RunModel.ENCOUNTERS.has(hazard.kind):
			status = "%s · %s" % [RunModel.ENCOUNTERS[hazard.kind].name, "발동" if hazard.active else "예고"]
			break
	draw_string(font, Vector2(w * 0.42, 47), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, game.GOLD)
	var mission: Dictionary = model.mission
	if not mission.is_empty() and game.notices.is_empty() and not model.finale_status in ["preview", "active", "success"]:
		draw_string(font, Vector2(12, 75), str(mission.name) + " · " + (game.mission_progress_text(model) if mission.status == "active" else str({"preview":"곧 시작", "success":"완료", "failed":"종료"}.get(mission.status, ""))), HORIZONTAL_ALIGNMENT_LEFT, w - 24, 13, cyan)
	if not game.notices.is_empty() and not model.finale_status in ["preview", "active", "success"]:
		draw_string(font, Vector2(12, 75), str(game.notices[0].title) + " · " + str(game.notices[0].name), HORIZONTAL_ALIGNMENT_LEFT, w - 24, 13, game.GOLD)
	if model.finale_status in ["active", "success"]:
		draw_string(font, Vector2(12, 75), game.finale_text(model), HORIZONTAL_ALIGNMENT_LEFT, w - 24, 13, game.GOLD)
	if not model.branch_id.is_empty():
		draw_string(font, Vector2(12, h - 92), str(GameContent.branch_info(model.branch_id).name), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, cyan)
	draw_rect(Rect2(0, h - 30, maxf(100, w - 238), 30), Color(game.BG, 0.8))
	draw_string(font, Vector2(12, h - 12), "LV.%d · %d/%d EXP" % [model.level, int(model.xp), int(model.xp_needed)], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, cyan)
	for i in Expedition.PART_IDS.size():
		var id: String = Expedition.PART_IDS[i]
		draw_string(font, Vector2(12 + i * 52, h - (70 if w < 600 else 43)), str(Expedition.part(id).name).left(2) + " %d" % int(model.parts.get(id, 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, game.GOLD)
	draw_line(Vector2(12, h - 5), Vector2(w - 246, h - 5), game.LINE, 3)
	draw_line(Vector2(12, h - 5), Vector2(12 + (w - 258) * clampf(model.xp / model.xp_needed, 0, 1), h - 5), cyan, 3)
	for entry in [[dash, model.dash_charge(), game.LIME], [overdrive, model.overdrive_meter / 100.0, game.GOLD]]:
		var button: Button = entry[0]
		draw_line(button.position + Vector2(6, 46), button.position + Vector2(6 + (button.size.x - 12) * clampf(entry[1], 0, 1), 46), entry[2], 3)
	if game.touch.drag_id != -1:
		var inverse: float = 1.0 / scale.x
		var base: Vector2 = (game.touch.origin - position) * inverse
		var tip: Vector2 = (game.touch.finger - position) * inverse
		draw_arc(base, 28, 0, TAU, 24, Color(cyan, 0.4), 2, true)
		draw_circle(base + (tip - base).limit_length(28), 9, Color(cyan, 0.7), true, -1, true)
