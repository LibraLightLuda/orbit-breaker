extends Node2D

const BG := Color("09121f")
const INK := Color("eef3e7")
const MUTED := Color("8b9ba9")
const LIME := Color("b7f878")
const CYAN := Color("72dce6")
const CORAL := Color("ff7185")
const GOLD := Color("ffd18a")
const SPEED_BLUE := Color("58adff")
const PANEL := Color("121f2e")
const LINE := Color("293a49")
const ARENA := RunModel.ARENA
const HUD_ALPHA := 0.12
const TOAST_ALPHA := 0.06

var run := RunModel.new()
var records := SaveStore.new()
var sound := SoundBank.new()
var ui: Control
var font: Font
var screen := "menu"
var mode := "normal"
var selected_ship := "striker"
var selected_sector := "ring"
var records_tab := "missions"
var codex_return := "menu"
var codex_tab := "weapons"
var item_detail := ""
var arsenal_page := 0
var item_page := 0
var tech_page := 0
var item_save_retry := 0.0
var clock_time := 0.0
var hud: Dictionary = {}
var choices: Array = []
var toast := ""
var toast_time := 0.0
var hurt_flash := 0.0
var last_level := 1
var saved_result := false
var save_failed := false
var dash_queued := false
var dash_aim := Vector2.ZERO
var stars: Array[Vector2] = []
var mouse_active := false
var mouse_target := Vector2.ZERO
var space_time := 0.0
var art_styles: Dictionary = {}
var space_offset := Vector2.ZERO
var space_velocity := Vector2.ZERO
var mouse_outside := false
var net_gauge := 0.0
var speed_gauge := 0.0
var camera_offset := Vector2.ZERO
var ghost := GhostReplay.new()
var replay_frames: Array = []
var replay_run := RunModel.new()
var replay_entry: Dictionary = {}
var replay_time := 0.0
var replay_speed := 1.0
var replay_paused := false
var replay_slider: HSlider
var achievement_page := 0
var ranking_mode := "normal"
var record_notice := ""
var ghost_jobs: Array[Dictionary] = []
var _hud_timer := 0.0
var notices: Array[Dictionary] = []
var notice_keys := {}
var known_progress := {}
var reward_cues := {}
var click_dash_queued := false
var click_dash_active := false
var dash_cursor_anchor := false
var dash_cursor_position := Vector2.ZERO

func _ready() -> void:
	var readable_font := FontVariation.new()
	readable_font.base_font = preload("res://assets/fonts/NotoSansKR.ttf")
	readable_font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 500.0}
	font = readable_font
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 18
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = theme
	layer.add_child(ui)
	records.load_data()
	add_child(sound)
	sound.set_muted(bool(records.data.muted))
	sound.set_music_enabled(bool(records.data.music))
	sound.start_music()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1217
	for i in range(65):
		stars.append(Vector2(rng.randf_range(18, 1262), rng.randf_range(16, 704)))
	_setup_inputs()
	get_viewport().mouse_exited.connect(func() -> void: mouse_outside = true)
	get_viewport().mouse_entered.connect(func() -> void: mouse_outside = false)
	get_viewport().size_changed.connect(_fit_viewport)
	_fit_viewport()
	_show_menu()

func _viewport_rect() -> Rect2:
	return Rect2(-position, get_viewport_rect().size)

func _fit_viewport() -> void:
	position = (get_viewport_rect().size - Vector2(1280, 720)) * 0.5
	ui.get_parent().offset = position
	if ui.has_node("CompactScroll"):
		call_deferred("_refresh_menu_layout")
	else:
		preload("res://scripts/menu_flow.gd").apply.call_deferred(self)
	var shade := ui.get_node_or_null("Shade")
	if shade != null:
		shade.position = _viewport_rect().position
		shade.size = _viewport_rect().size
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Native cursor coordinates are rounded to screen pixels after window scaling.
		var cursor_scale := get_viewport().get_final_transform().get_scale().x
		if dash_cursor_anchor and event.position.distance_to(dash_cursor_position) * cursor_scale < 3.0:
			return
		if dash_cursor_anchor and OS.has_feature("web"):
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		dash_cursor_anchor = false
		mouse_target = get_global_transform_with_canvas().affine_inverse() * event.position
		mouse_active = screen == "playing"

func _unhandled_input(event: InputEvent) -> void:
	if screen != "playing" or not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		dash_queued = true
		click_dash_queued = true
		dash_aim = (get_global_transform_with_canvas().affine_inverse() * event.position + camera_offset - run.player).normalized()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		run.activate_overdrive()
	else:
		return
	get_viewport().set_input_as_handled()

func _movement_direction() -> Vector2:
	var keys := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if not keys.is_zero_approx():
		return keys
	if mouse_active and mouse_outside and not dash_cursor_anchor and DisplayServer.get_name() != "headless" and not OS.has_feature("web"):
		# Poll desktop coordinates: window-local mouse events stop at the window edge.
		mouse_target = get_global_transform_with_canvas().affine_inverse() * get_viewport().get_screen_transform().affine_inverse() * Vector2(DisplayServer.mouse_get_position())
	return _mouse_direction(mouse_target) if mouse_active else Vector2.ZERO

func _mouse_direction(cursor: Vector2) -> Vector2:
	var offset := cursor + camera_offset - run.player
	return offset.normalized() * clampf((offset.length() - 10.0) / 30.0, 0.0, 1.0)

func _setup_inputs() -> void:
	var bindings := {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and screen == "playing":
		_show_pause()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_F11:
			var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		KEY_M:
			_toggle_mute()
		KEY_ESCAPE:
			if screen == "playing":
				_show_pause()
			elif screen == "pause":
				_resume()
			elif screen == "arsenal":
				_close_arsenal()
			elif screen in ["help", "settings", "credits", "hangar", "records", "replay"]:
				_show_menu()
		KEY_SPACE:
			if screen == "playing":
				dash_queued = true
				dash_aim = (mouse_target + camera_offset - run.player).normalized() if mouse_active else _movement_direction().normalized()
		KEY_E:
			if screen == "playing":
				run.activate_overdrive()
		KEY_TAB:
			if screen in ["playing", "pause"]:
				_open_arsenal("pause")
		KEY_1, KEY_2, KEY_3:
			if screen == "upgrade":
				_pick_upgrade(event.physical_keycode - KEY_1)
	get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	clock_time += delta
	_poll_ghost_save()
	item_save_retry = maxf(0.0, item_save_retry - delta)
	if not run.pending_tech.is_empty() and item_save_retry <= 0.0:
		if records.record_tech(run.pending_tech):
			run.pending_tech.clear()
		else:
			item_save_retry = 3.0
			toast = "기체 연구 저장 실패 · 자동 재시도 중"
			toast_time = 3.0
	if not run.pending_items.is_empty() and item_save_retry <= 0.0:
		if records.record_items(run.pending_items):
			run.pending_items.clear()
		else:
			item_save_retry = 3.0
			toast = "도감 저장 실패 · 자동 재시도 중"
			toast_time = 3.0
	if screen == "replay":
		if not replay_paused:
			replay_time = minf(float(replay_frames.back()[0]), replay_time + delta * replay_speed)
			replay_slider.set_value_no_signal(replay_time)
			if replay_time >= float(replay_frames.back()[0]):
				replay_paused = true
		var frame := GhostReplay.sample(replay_frames, replay_time)
		camera_offset = _camera_target(Vector2(frame[1], frame[2]))
		hud.replay.text = "%s / %s    %.0f배속    %s" % [_time(replay_time), _time(float(replay_frames.back()[0])), replay_speed, "일시정지" if replay_paused else "재생 중"]
	toast_time = maxf(0.0, toast_time - delta)
	hurt_flash = maxf(0.0, hurt_flash - delta * 2.0)
	if screen == "playing":
		if not notices.is_empty():
			notices[0].ttl -= delta
			if notices[0].ttl <= 0:
				notices.pop_front()
		var direction := _movement_direction()
		var previous_position := run.player
		var was_dashing := run.dash_time > 0.0
		run.step(delta, direction, dash_queued, dash_aim)
		if click_dash_queued and run.events.has("dash"):
			click_dash_active = true
		click_dash_queued = false
		ghost.capture(run)
		camera_offset = camera_offset.lerp(_camera_target(run.player), 1.0 - exp(-7.0 * delta))
		if click_dash_active and was_dashing and run.dash_time <= 0.0:
			_finish_click_dash()
		if not records.data.reduced_motion:
			space_time += delta
			var drift := -(run.player - previous_position) / maxf(delta, 0.001)
			space_velocity = space_velocity.lerp(drift.limit_length(360.0) * 0.12, 1.0 - exp(-7.0 * delta))
			space_offset += space_velocity * delta
		var net := run.net_hull_rate()
		net_gauge = lerpf(net_gauge, net / maxf(1.0, run.regeneration_rate() + run.decay_rate() + run.boundary_damage_rate()), 1.0 - exp(-10.0 * delta))
		speed_gauge = lerpf(speed_gauge, clampf(run.current_speed / run.base_speed(), 0.0, 1.0), 1.0 - exp(-10.0 * delta))
		dash_queued = false
		if not run.loot_notices.is_empty():
			toast = " · ".join(run.loot_notices.slice(0, 2))
			toast_time = 3.0
			run.loot_notices.clear()
		for cue in run.events:
			if cue == "item" and not run.pending_items.is_empty():
				var pickup: Dictionary = run.pending_items.back()
				var info := ItemCatalog.info(str(pickup.id), str(pickup.grade))
				toast = "%s · %s" % [info.name, info.description]
				toast_time = 3.3
			var audio_cue: String = {"shot": "shoot", "kill": "hit", "heal": "pickup", "upgrade": "select", "boss_down": "win", "elite": "boss", "overdrive": "level", "evolution": "win", "milestone": "win", "item": "pickup", "supply": "pickup", "event_reward": "win", "mission_preview": "event_warning", "mission_start": "level", "mission_success": "win", "mission_failed": "hurt", "part_spawn": "pickup", "part_pickup": "level", "hull_evolution": "win"}.get(cue, cue)
			sound.play(audio_cue)
			if cue == "hurt":
				hurt_flash = 0.35
			if cue == "boss":
				toast = run.event_title
				toast_time = 4.0
			if cue == "boss_down":
				toast = "보스 격파! " + ("25초 붕괴 완화 · 공격 강화로 다음 지휘체에 도전하세요" if run.elapsed >= 300.0 else "5분 돌파 후 추격 지휘체가 나타납니다")
				toast_time = 4.0
			if cue == "milestone":
				toast = "5분 돌파! 정예·지휘체 증원 가속 · 매분 20초 붕괴 완화"
				toast_time = 5.0
			if cue == "elite":
				toast = "정예 편대 접근 · 처치하고 보급품을 회수하세요!"
				toast_time = 4.0
			if cue == "overdrive":
				toast = "오버드라이브 가동 · 6초간 화력 증폭!"
				toast_time = 2.0
		run.events.clear()
		_hud_timer -= delta
		if _hud_timer <= 0.0:
			if item_save_retry <= 0.0:
				var details := run.run_stats.duplicate()
				details.elapsed = run.elapsed
				if not records.record_live_achievements(details):
					item_save_retry = 3.0
					toast = "업적 저장 실패 · 자동 재시도 중"
					toast_time = 3.0
			_collect_progress_notices()
			_update_hud()
			_hud_timer = 0.1
		if run.state == "upgrade":
			_show_upgrades()
		elif run.state in ["won", "lost"]:
			_show_result()
	queue_redraw()

func _finish_click_dash() -> void:
	click_dash_active = false
	mouse_active = false
	mouse_outside = false
	mouse_target = run.player - camera_offset
	dash_cursor_position = get_global_transform_with_canvas() * mouse_target
	dash_cursor_anchor = true
	if not OS.has_feature("web") and DisplayServer.get_name() != "headless" and get_window().has_focus():
		get_viewport().warp_mouse(dash_cursor_position)
	elif OS.has_feature("web"):
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _queue_notice(key: String, title: String, name_text: String, color: Color, sides: int) -> void:
	if notice_keys.has(key):
		return
	notice_keys[key] = true
	notices.append({"title": title, "name": name_text, "color": color, "sides": sides, "ttl": 3.0})

func _collect_progress_notices() -> void:
	for achievement: Dictionary in Achievements.catalog():
		if achievement.id in records.data.achievements and not achievement.id in known_progress.get("achievements", []):
			_queue_notice("achievement:" + achievement.id, "업적 달성", achievement.name, GOLD, 5)
	for group: String in ["items", "parts", "hulls"]:
		for id: String in records.data["discovered_" + group]:
			if id in known_progress.get(group, []):
				continue
			var name_text: String = ItemCatalog.info(id, "C").name if group == "items" else (Expedition.part(id).name if group == "parts" else Expedition.recipe(id).name)
			_queue_notice("discovery:" + group + id, "도감 해금", name_text, CYAN, 4)
	for id: String in run.evolutions:
		_queue_notice("weapon:" + id, "무기 진화", GameContent.evolution_info(id).name, LIME, 3)
	for id: String in run.hull_forms:
		var rank := run.hull_rank(id)
		_queue_notice("hull:" + id + str(rank), "기체 진화", Expedition.recipe(id).name + (" II" if rank == 2 else " I"), Color("c69cff"), 6)

func _draw_progress_notice() -> void:
	if notices.is_empty():
		return
	var notice: Dictionary = notices[0]
	var color: Color = notice.color
	var pulse := 0.0 if records.data.reduced_motion else pow(clampf((float(notice.ttl) - 2.4) / 0.6, 0, 1), 2)
	var at := Vector2(894, 62)
	draw_style_box(_style(Color(BG, HUD_ALPHA), Color(color, 0.5 + pulse * 0.5)), Rect2(at, Vector2(338, 46)))
	_polygon(at + Vector2(22, 23), 10 + pulse * 2, int(notice.sides), color, -PI / 2)
	draw_circle(at + Vector2(22, 23), 4, BG)
	draw_string(font, at + Vector2(43, 15), notice.title, HORIZONTAL_ALIGNMENT_LEFT, 265, 11, color)
	draw_string(font, at + Vector2(43, 36), notice.name, HORIZONTAL_ALIGNMENT_LEFT, 279, 16, INK)
	if notices.size() > 1:
		draw_string(font, at + Vector2(295, 15), "+%d" % (notices.size() - 1), HORIZONTAL_ALIGNMENT_RIGHT, 29, 11, MUTED)

func _poll_ghost_save() -> void:
	if ghost_jobs.is_empty():
		return
	var job: Dictionary = ghost_jobs[0]
	var writer: GhostReplay = job.writer
	if not writer.poll_write():
		return
	if job.get("discard", false):
		ghost_jobs.pop_front()
		return
	var linked := writer.save_ok and records.attach_ghost(job.entry, job.id)
	if not linked:
		DirAccess.remove_absolute(records.ghost_path(job.id))
	ghost_jobs.pop_front()
	toast = "고스트 저장 완료" if linked else "고스트 미저장 · 점수 기록은 유지됩니다"
	toast_time = 4.0
	if screen == "result":
		_show_result()
	elif screen == "records":
		_show_records()

func _exit_tree() -> void:
	for job: Dictionary in ghost_jobs:
		job.writer.cancel_write()

func _clear_ui() -> void:
	if dash_cursor_anchor and OS.has_feature("web"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	dash_cursor_anchor = false
	hud.clear()
	ui.scale = Vector2.ONE
	ui.get_parent().offset = position
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	preload("res://scripts/menu_flow.gd").apply.call_deferred(self)

func _refresh_menu_layout() -> void:
	match screen:
		"menu": _show_menu()
		"hangar": _show_hangar()
		"records": _show_records()
		"arsenal":
			if item_detail.is_empty():
				_open_arsenal(codex_return)
			else:
				_show_item_detail(item_detail)
		"help": _show_help()
		"settings": _show_settings()
		"credits": _show_credits()
		"pause": _resume(); _show_pause()
		"upgrade": _show_upgrades(true)
		"result": _show_result()

func _label(text: String, rect: Rect2, size: int = 20, color: Color = INK, parent: Control = null, wrap: bool = false) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	if screen == "playing":
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_color_override("font_outline_color", Color(BG, 0.8))
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else ui).add_child(label)
	label.position = rect.position
	label.size = rect.size
	label.text = text
	label.size = rect.size
	return label

func _style(fill: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var key := str(fill) + str(border) + str(width)
	if art_styles.has(key): return art_styles[key]
	var style := StyleBoxFlat.new()
	art_styles[key] = style
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(3)
	style.border_width_top = width + 1
	style.shadow_color = Color(BG, 0.35)
	style.shadow_size = 3
	style.content_margin_left = 22
	style.content_margin_right = 22
	return style

func _panel(rect: Rect2, fill: Color = PANEL, border: Color = LINE) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", _style(fill, border))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(panel)
	return panel

func _button(text: String, rect: Rect2, callback: Callable, primary: bool = false, focus: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", BG if primary else INK)
	button.add_theme_color_override("font_hover_color", BG if primary else LIME)
	button.add_theme_color_override("font_focus_color", BG if primary else INK)
	button.add_theme_color_override("font_pressed_color", BG if primary else INK)
	button.add_theme_stylebox_override("normal", _style(LIME if primary else PANEL, LIME if primary else LINE))
	button.add_theme_stylebox_override("hover", _style(Color("caff96") if primary else Color("1d3140"), LIME))
	button.add_theme_stylebox_override("pressed", _style(Color("94ce5a") if primary else LINE, CYAN))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), INK, 2))
	button.add_theme_stylebox_override("disabled", _style(Color("101923"), LINE))
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.pressed.connect(func() -> void: sound.play("select"); callback.call())
	ui.add_child(button)
	if focus:
		button.grab_focus()
	return button

func _show_menu() -> void:
	screen = "menu"
	_clear_ui()
	_label("OB / 03     COLLAPSING ORBITS", Rect2(80, 58, 520, 28), 16, LIME)
	_label("오빗 브레이커", Rect2(76, 122, 650, 86), 60)
	_label("ORBIT BREAKER", Rect2(81, 208, 570, 34), 24, MUTED)
	_label("돌진하고, 성장하고, 궤도를 지켜라.", Rect2(80, 278, 590, 36), 25)
	_label("5분을 돌파하고, 붕괴하는 우주에서 한계까지 생존.", Rect2(80, 321, 640, 30), 18, MUTED)
	_button("출격 준비   →", Rect2(80, 385, 290, 64), _show_hangar, true, true)
	_button("작전 기록", Rect2(388, 385, 170, 64), _show_records)
	_button("플레이 방법", Rect2(80, 468, 150, 50), _show_help)
	_button("무기 도감", Rect2(246, 468, 148, 50), func() -> void: _open_arsenal("menu"))
	_button("설정", Rect2(410, 468, 148, 50), _show_settings)
	_label("최고 %s   /   돌파 %d회   /   업적 %d점" % [_number(int(records.data.best_score)), int(records.data.wins), Achievements.points(records.data.achievements)], Rect2(80, 565, 660, 30), 18, MUTED)
	_label("마우스 / WASD 이동    좌클릭 / SPACE 돌진    우클릭 / E 오버드라이브", Rect2(80, 642, 850, 30), 16, MUTED)
	_label("VERSION 3.18  /  MADE WITH GODOT", Rect2(922, 650, 350, 24), 13, MUTED)

func _wrap_label(text: String, rect: Rect2, size: int = 18, color: Color = MUTED, parent: Control = null) -> Label:
	return _label(text, rect, size, color, parent, true)

func _glyph(kind: String, id: String, rect: Rect2, color: Color = CYAN, parent: Control = null) -> Control:
	var glyph := preload("res://scripts/ui_glyph.gd").new()
	glyph.kind = kind
	glyph.glyph_id = id
	glyph.tint = color
	glyph.position = rect.position
	glyph.size = rect.size
	(parent if parent != null else ui).add_child(glyph)
	return glyph

func _show_hangar() -> void:
	screen = "hangar"
	_clear_ui()
	_label("LAUNCH BAY / FLIGHT SYSTEMS", Rect2(64, 32, 740, 28), 16, CYAN)
	_label("출격 준비", Rect2(60, 76, 700, 56), 42)
	_label("파일럿 이름", Rect2(720, 87, 130, 30), 17, MUTED)
	var name_input := LineEdit.new()
	name_input.position = Vector2(850, 77)
	name_input.set_meta("flow_order", 100)
	name_input.size = Vector2(366, 48)
	name_input.max_length = 16
	name_input.text = records.data.player_name
	name_input.placeholder_text = "최대 16자 · 같은 이름은 같은 파일럿"
	name_input.add_theme_font_size_override("font_size", 18)
	name_input.text_changed.connect(func(value: String) -> void: records.data.player_name = SaveStore.clean_name(value))
	ui.add_child(name_input)
	var selected: Dictionary = GameContent.ship_info(selected_ship)
	_panel(Rect2(64, 157, 330, 270), PANEL, Color(selected.color, 0.5))
	_glyph("ship", selected_ship, Rect2(94, 163, 270, 180), selected.color)
	_label(selected.name, Rect2(84, 345, 294, 35), 27, selected.color)
	_label("선체 %d   속도 %d   위성 %d" % [selected.hp, selected.speed, selected.orbits], Rect2(84, 390, 294, 26), 16)
	for i in GameContent.SHIP_IDS.size():
		var id: String = GameContent.SHIP_IDS[i]
		var info: Dictionary = GameContent.ship_info(id)
		var card := _button("", Rect2(416, 157 + i * 91, 800, 88), func() -> void: selected_ship = id; _show_hangar(), false, id == selected_ship)
		card.add_theme_stylebox_override("normal", _style(PANEL, info.color if id == selected_ship else LINE, 2 if id == selected_ship else 1))
		_glyph("ship", id, Rect2(12, 8, 72, 72), info.color, card)
		_label(("● " if id == selected_ship else "○ ") + str(info.name), Rect2(100, 9, 250, 33), 23, info.color, card)
		_label("선체 %d  /  속도 %d  /  위성 %d" % [info.hp, info.speed, info.orbits], Rect2(100, 49, 250, 25), 15, INK, card)
		_wrap_label(info.description, Rect2(362, 14, 415, 66), 16, MUTED, card)
	_label("전장 / 위험 패턴", Rect2(64, 439, 700, 25), 17, CYAN)
	for i in GameContent.SECTOR_IDS.size():
		var id: String = GameContent.SECTOR_IDS[i]
		var info: Dictionary = GameContent.sector_info(id)
		var card := _button("", Rect2(64 + 386 * i, 475, 366, 108), func() -> void: selected_sector = id; _show_hangar())
		card.add_theme_stylebox_override("normal", _style(PANEL, info.color if id == selected_sector else LINE, 2 if id == selected_sector else 1))
		_glyph("sector", id, Rect2(10, 14, 80, 80), info.color, card)
		_label(("● " if id == selected_sector else "○ ") + str(info.name), Rect2(100, 12, 246, 32), 22, info.color, card)
		_wrap_label({"ring": "고속 우회 편대 포위\n스트라이커 화력에 유리", "storm": "전역 교차 번개 회피\n스카우트 기동에 유리", "forge": "시간에 따라 붕괴 가속\n배스천 내구에 유리"}[id], Rect2(100, 51, 246, 51), 16, MUTED, card)
	var key := selected_ship + "|" + selected_sector + "|" + mode
	_label("%s / %s / %s ×%s · 이 조합 최고 %s" % [selected.name, GameContent.sector_info(selected_sector).name, GameContent.mode_info(mode).name, str(GameContent.mode_info(mode).score), _number(int(records.data.best_by_loadout.get(key, 0)))], Rect2(64, 593, 1152, 29), 17, INK)
	_button("돌아가기", Rect2(64, 640, 164, 56), _show_menu)
	var available := records.available_modes()
	for i in GameContent.MODE_IDS.size():
		var id: String = GameContent.MODE_IDS[i]
		var info: Dictionary = GameContent.mode_info(id)
		var unlocked: bool = id in available
		var button := _button(str(info.name) + (" ×" + str(info.score) if unlocked else " · 잠금"), Rect2(246 + i * 156, 640, 146, 56), func() -> void: mode = id; _show_hangar())
		button.add_theme_font_size_override("font_size", 16)
		button.disabled = not unlocked
		_glyph("upgrade",id,Rect2(4,18,20,20), CYAN if unlocked else MUTED,button)
		button.tooltip_text = "표준 돌파로 해금" if id == "veteran" else ("베테랑 돌파로 해금" if id == "cataclysm" else "")
		if id == mode:
			button.add_theme_stylebox_override("normal", _style(PANEL, CYAN, 2))
	_label("표준 돌파 → 베테랑 / 베테랑 돌파 → 대붕괴", Rect2(247, 697, 720, 22), 13, MUTED)
	_button("출격하기  →", Rect2(938, 634, 278, 62), _start_run, true).set_meta("flow_order", 750)

func _show_records() -> void:
	screen = "records"
	camera_offset = Vector2.ZERO
	_clear_ui()
	_label("FLIGHT ARCHIVE / LOCAL", Rect2(64, 32, 900, 28), 16, LIME)
	_label("다음 출격의 이유", Rect2(60, 72, 700, 55), 39)
	_label("업적 %d점  ·  출격 %d회  ·  돌파 %d회  ·  처치 %s  ·  최고 LV.%d" % [Achievements.points(records.data.achievements), records.data.runs, records.data.wins, _number(records.data.total_kills), records.data.best_level], Rect2(67, 137, 1140, 30), 18, GOLD)
	for i: int in range(3):
		var tab: String = ["missions", "history", "ranking"][i]
		_button(["도전 과제", "최근 출격", "랭킹 / 고스트"][i], Rect2(64 + i * 205, 183, 190, 44), func() -> void: records_tab = tab; _show_records(), records_tab == tab, i == 0)
	if records_tab == "missions":
		var catalog := Achievements.catalog()
		var pages := ceili(catalog.size() / 6.0)
		achievement_page = clampi(achievement_page, 0, pages - 1)
		for i: int in range(achievement_page * 6, mini(catalog.size(), (achievement_page + 1) * 6)):
			var item: Dictionary = catalog[i]
			var earned: bool = item.id in records.data.achievements
			var x := 64 + (i % 3) * 386
			var y := 249 + ((i % 6) / 3) * 155
			var card := _panel(Rect2(x, y, 366, 145), PANEL, LIME if earned else LINE)
			_label("%s  ·  %d점" % ["달성 완료" if earned else "도전 중", item.points], Rect2(x + 18, y + 10, 326, 24), 15, LIME if earned else GOLD)
			_glyph("achievement", str(item.id), Rect2(x + 18, y + 38, 32, 32), LIME if earned else MUTED)
			_label(item.name, Rect2(x + 58, y + 39, 286, 33), 22)
			_wrap_label(item.description, Rect2(x + 18, y + 75, 330, 40), 16, MUTED)
			var progress_value := mini(int(records.data.achievement_progress.get(item.stat, 0)), int(item.target))
			var progress := ColorRect.new()
			progress.position = Vector2(18, 125)
			progress.size = Vector2(194, 4)
			progress.color = LINE
			progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(progress)
			var fill := ColorRect.new()
			fill.size = Vector2(194.0 * progress_value / maxf(1, item.target), 4)
			fill.color = LIME if earned else CYAN
			fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			progress.add_child(fill)
			_label("%d / %d" % [progress_value, item.target], Rect2(x + 230, y + 113, 118, 25), 16, LIME if earned else CYAN)
		_button("← 이전", Rect2(685, 565, 150, 42), func() -> void: achievement_page = (achievement_page + pages - 1) % pages; _show_records())
		_label("%d / %d" % [achievement_page + 1, pages], Rect2(852, 572, 110, 30), 18, MUTED)
		_button("다음 →", Rect2(984, 565, 216, 42), func() -> void: achievement_page = (achievement_page + 1) % pages; _show_records())
	elif records_tab == "history":
		for i: int in range(records.data.recent_runs.size()):
			var entry: Dictionary = records.data.recent_runs[i]
			var y := 249 + i * 42
			_panel(Rect2(64, y, 1138, 38))
			_label("%s · %s" % [entry.name, "돌파" if entry.won else "종료"], Rect2(80, y + 4, 330, 29), 17, LIME if entry.won else MUTED)
			_label("%s / %s / %s / %s / %s점" % [GameContent.ship_info(entry.ship).name, GameContent.sector_info(entry.sector).name, GameContent.mode_info(entry.mode).name, _time(entry.time), _number(entry.score)], Rect2(420, y + 4, 770, 29), 16)
		if records.data.recent_runs.is_empty():
			_label("첫 출격으로 비행 일지를 시작하세요.", Rect2(80, 330, 1000, 50), 24, MUTED)
	else:
		for i: int in range(GameContent.MODE_IDS.size()):
			var difficulty: String = GameContent.MODE_IDS[i]
			_button(GameContent.mode_info(difficulty).name, Rect2(64 + 205 * i, 241, 190, 38), func() -> void: ranking_mode = difficulty; _show_records(), ranking_mode == difficulty)
		var entries: Array = records.data.leaderboard.filter(func(entry: Dictionary) -> bool: return entry.mode == ranking_mode)
		for i: int in range(entries.size()):
			var entry: Dictionary = entries[i]
			var y := 293 + i * 28
			_label("%02d  %s" % [i + 1, entry.name], Rect2(72, y, 340, 27), 16, GOLD if i == 0 else INK)
			_label("%s점  ·  %s  ·  %s / %s" % [_number(entry.score), _time(entry.time), GameContent.ship_info(entry.ship).name, GameContent.sector_info(entry.sector).name], Rect2(420, y, 615, 27), 15, MUTED)
			var watch := _button("고스트 관전", Rect2(1040, y, 160, 26), func() -> void: _show_replay(entry))
			watch.add_theme_font_size_override("font_size", 14)
			watch.disabled = str(entry.ghost).is_empty()
		if entries.is_empty():
			_label("이 난이도의 기록이 없습니다. 이름을 정하고 출격하세요.", Rect2(80, 340, 1100, 50), 23, MUTED)
		_label(record_notice if not record_notice.is_empty() else "이 기기/브라우저의 개인 최고 10명 · 동점은 생존 시간순 · 이름이 같으면 같은 파일럿", Rect2(66, 590, 1134, 28), 15, CORAL if not record_notice.is_empty() else MUTED)
	_button("돌아가기", Rect2(64, 637, 200, 51), _show_menu)
	_button("다음 출격 준비 →", Rect2(898, 630, 304, 58), _show_hangar, true)

func _open_arsenal(return_to: String) -> void:
	item_detail = ""
	codex_return = return_to
	screen = "arsenal"
	dash_queued = false
	_clear_ui()
	if return_to == "pause":
		_shade()
	_button("무기 진화", Rect2(890, 28, 150, 42), func() -> void: codex_tab = "weapons"; _open_arsenal(codex_return))
	_button("기체 테크트리", Rect2(692, 28, 184, 42), func() -> void: codex_tab = "tech"; _open_arsenal(codex_return))
	_button("아이템 도감", Rect2(1052, 28, 164, 42), func() -> void: codex_tab = "items"; _open_arsenal(codex_return))
	if codex_tab == "items":
		_show_item_codex()
		return
	if codex_tab == "tech":
		_show_tech_codex()
		return
	_label("ARSENAL / EVOLUTION GUIDE", Rect2(64, 35, 1120, 30), 16, CYAN)
	_label("강화를 연결하면, 무기가 진화합니다.", Rect2(61, 81, 1170, 57), 34)
	_label("필요한 강화 레벨을 모두 갖추면 자동 진화합니다. 도감을 보는 동안 전투는 멈춥니다.", Rect2(65, 148, 1150, 31), 17, MUTED)
	for i in range(arsenal_page * 6, mini((arsenal_page + 1) * 6, GameContent.EVOLUTION_IDS.size())):
		var id: String = GameContent.EVOLUTION_IDS[i]
		var info: Dictionary = GameContent.evolution_info(id)
		var x := 64 + (i % 3) * 386
		var y := 194 + floori((i % 6) / 3.0) * 193
		var acquired: bool = return_to == "pause" and run.evolutions.has(id)
		_panel(Rect2(x, y, 366, 180), PANEL, LIME if acquired else LINE)
		_glyph("upgrade", id, Rect2(x + 304, y + 10, 46, 46), LIME if acquired else CYAN)
		_label(("진화 완료 · 숙련 %d" % run.evolution_mastery(id)) if acquired else "EVOLUTION / 0%d" % (i + 1), Rect2(x + 18, y + 8, 280, 22), 15, LIME if acquired else CYAN)
		_label(info.name, Rect2(x + 18, y + 32, 280, 32), 23)
		_wrap_label(info.description, Rect2(x + 18, y + 68, 330, 49), 16)
		var requirements := ""
		for upgrade_id in info.requirements:
			var current: int = int(run.upgrades.get(upgrade_id, 0)) if return_to == "pause" else 0
			requirements += "%s %s%d\n" % [RunModel.upgrade_info(upgrade_id).name, "%d / " % current if return_to == "pause" else "Lv.", int(info.requirements[upgrade_id])]
		if info.has("after"):
			requirements = "%d분 이후 · " % (int(info.after) / 60) + requirements.replace("\n", " / ")
		_wrap_label(requirements, Rect2(x + 18, y + 119, 330, 54), 15, LIME if acquired else INK)
	_button("진화 %d/2 · 다음 →" % (arsenal_page + 1), Rect2(912, 624, 304, 60), func() -> void: arsenal_page = (arsenal_page + 1) % 2; _open_arsenal(codex_return))
	var owned: Array[String] = []
	if return_to == "pause":
		for id in run.upgrades:
			owned.append("%s %d" % [RunModel.upgrade_info(id).get("name", id), run.upgrades[id]])
	_wrap_label("현재 장비  /  " + " · ".join(owned) if not owned.is_empty() else "진화 후에도 Lv.4~5 숙련 강화로 성장합니다. 매 레벨 회복 1개와 진행 중인 진화/숙련 연계 1개를 보장합니다.", Rect2(66, 583, 1130, 35), 14)
	_button("전투로 돌아가기" if return_to == "pause" else "돌아가기", Rect2(64, 624, 310, 60), _close_arsenal, true, true)

func _close_arsenal() -> void:
	if codex_return == "pause":
		_resume()
	else:
		_show_menu()

func _toggle_mode() -> void:
	var modes := records.available_modes()
	mode = modes[(modes.find(mode) + 1) % modes.size()]
	_show_hangar()

func _start_run() -> void:
	if not records.storage_error.is_empty():
		record_notice = records.storage_error
		_show_records()
		return
	if not run.pending_tech.is_empty():
		if not records.record_tech(run.pending_tech):
			record_notice = "기체 연구 저장 실패 · 저장 공간 확인 후 재시도하세요"
			_show_records()
			return
		run.pending_tech.clear()
	if not run.pending_items.is_empty():
		if not records.record_items(run.pending_items):
			record_notice = "아이템 발견 저장 실패 · 저장 공간 확인 후 재시도하세요"
			_show_records()
			return
		run.pending_items.clear()
	if not mode in records.available_modes():
		mode = "normal"
	run.reset(0, mode, selected_ship, selected_sector)
	notices.clear()
	notice_keys.clear()
	reward_cues.clear()
	known_progress = {"achievements": records.data.achievements.duplicate(), "items": records.data.discovered_items.duplicate(), "parts": records.data.discovered_parts.duplicate(), "hulls": records.data.discovered_hulls.duplicate()}
	click_dash_queued = false
	click_dash_active = false
	dash_cursor_anchor = false
	camera_offset = Vector2.ZERO
	ghost = GhostReplay.new()
	ghost.capture(run)
	record_notice = ""
	space_time = 0.0
	space_offset = Vector2.ZERO
	space_velocity = Vector2.ZERO
	net_gauge = 0.0
	speed_gauge = 0.0
	saved_result = false
	save_failed = false
	last_level = 1
	dash_queued = false
	toast = GameContent.sector_info(selected_sector).name
	toast_time = 2.0
	_resume()

func _resume() -> void:
	screen = "playing"
	camera_offset = _camera_target(run.player)
	mouse_active = false
	dash_queued = false
	click_dash_queued = false
	_clear_ui()
	hud.hp = _label("", Rect2(82, 21, 302, 36), 25)
	hud.trait = _label("", Rect2(718, 77, 124, 22), 13, GameContent.ship_info(run.ship_id).color)
	hud.trait.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.speed = _label("", Rect2(82, 125, 140, 26), 17, SPEED_BLUE)
	hud.speed_detail = _label("", Rect2(222, 128, 162, 24), 13, MUTED)
	hud.speed_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.time = _label("", Rect2(495, 17, 290, 39), 30)
	hud.time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.phase = _label("", Rect2(438, 77, 278, 22), 13, MUTED)
	hud.score = _label("", Rect2(913, 23, 242, 30), 20)
	hud.score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.vitals = _label("", Rect2(54, 79, 140, 25), 16, LIME)
	hud.vital_detail = _label("", Rect2(194, 82, 190, 22), 12, MUTED)
	hud.vital_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.risk = _label("", Rect2(438, 54, 404, 22), 14, CYAN)
	hud.risk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pause := _button("Ⅱ", Rect2(1204, 24, 28, 28), _show_pause)
	pause.add_theme_font_size_override("font_size", 17)
	pause.tooltip_text = "일시정지 (ESC)"
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style := _style(Color(BG, 0.08), Color(INK, 0.5) if state != "normal" else Color(LINE, 0.25))
		for edge: String in ["left", "right", "top", "bottom"]:
			style.set("content_margin_" + edge, 0.0)
		pause.add_theme_stylebox_override(state, style)
	pause.size = Vector2(28, 28)
	pause.focus_mode = Control.FOCUS_NONE
	hud.level = _label("", Rect2(48, 684, 270, 27), 14, CYAN)
	_label("TAB 도감   ESC 정지", Rect2(1060, 684, 210, 27), 14, MUTED)
	net_gauge = run.net_hull_rate() / maxf(1.0, run.regeneration_rate() + run.decay_rate() + run.boundary_damage_rate())
	speed_gauge = clampf(run.current_speed / run.base_speed(), 0.0, 1.0)
	_update_hud()

func _update_hud() -> void:
	if hud.is_empty():
		return
	hud.hp.text = "%d / %d" % [ceili(run.hp), int(run.max_hp)]
	match run.ship_id:
		"striker":
			hud.trait.text = "조준 +%d%%" % roundi(run.focus_bonus() * 100)
		"scout":
			hud.trait.text = "가속 %.1fs" % maxf(0.0, run.slipstream_time - run.dash_time) if run.slipstream_time > 0.0 else "돌진 ×1.75"
		"bastion":
			hud.trait.text = "방벽 %d/%d · %.1fs" % [run.guard_stacks, run.guard_capacity(), run.guard_cooldown]
	hud.time.text = "%s / %s" % [_time(run.elapsed), "05:00" if run.elapsed < 300.0 else "10:00"]
	var net := run.net_hull_rate()
	hud.vitals.text = "%s %+.2f/s" % ["▼" if net < 0.0 else ("▲" if net > 0.0 else "−"), net]
	hud.vitals.add_theme_color_override("font_color", CORAL if net < 0.0 else (LIME if net > 0.0 else MUTED))
	hud.vital_detail.text = "↑+%.2f ↓-%.2f · 수리 %d%%" % [run.regeneration_rate(), run.decay_rate() + run.boundary_damage_rate(), roundi(run.repair_efficiency() * 100)]
	var layer := run.boundary_layer(run.player)
	hud.risk.text = "%s · %s" % [GameContent.sector_info(run.sector_id).name, ["활동영역", "희박권 1", "붕괴권 2", "소멸권 3"][layer]]
	hud.risk.add_theme_color_override("font_color", [CYAN, GOLD, CORAL, Color("c69cff")][layer])
	hud.speed.text = "추진  %d%%" % roundi(run.current_speed / run.base_speed() * 100.0)
	hud.speed.add_theme_color_override("font_color", _speed_color(speed_gauge))
	hud.speed_detail.text = "%d px/s%s" % [roundi(run.current_speed), " · 돌진" if run.dash_time > 0.0 else ""]
	hud.score.text = "%s  /  %d 처치" % [_number(run.ranked_score()), run.kills]
	hud.level.text = "LV.%02d   /   %d EXP → %d" % [run.level, int(run.xp), int(run.xp_needed)]
	if run.elapsed < 60:
		hud.phase.text = "01 · 접촉"
	elif run.elapsed < 150:
		hud.phase.text = "02 · 포위"
	elif run.elapsed < 240:
		hud.phase.text = "03 · 과부하"
	elif run.elapsed < 300:
		hud.phase.text = "04 · 지휘체 교전"
	else:
		var bosses := run.enemies.filter(func(e: Dictionary) -> bool: return e.kind == "boss" and float(e.hp) > 0.0).size()
		var reinforcement := "지휘체 ×2" if bosses >= 2 else "증원 %ds" % maxi(0, ceili(run.next_boss_at - run.elapsed))
		hud.phase.text = "%s · %s" % [reinforcement, "붕괴 완화" if fmod(run.elapsed - 300.0, 60.0) < 20.0 or run.elapsed < run.relief_until else "추격"]
	for hazard: Dictionary in run.hazards:
		if RunModel.ENCOUNTERS.has(hazard.kind):
			var remaining := ceili(float(hazard.ttl) if bool(hazard.active) else float(hazard.warn))
			hud.phase.text = "%s · %s %ds" % [RunModel.ENCOUNTERS[hazard.kind].name, "진행" if bool(hazard.active) else "예고", remaining]
			if hazard.kind == "planet" and bool(hazard.active):
				hud.phase.text = "행성 방어 %.1f/12s · %ds" % [float(hazard.get("hold", 0.0)), remaining]
			break

func _shade() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.018, 0.031, 0.055, 0.91)
	shade.name = "Shade"
	shade.position = _viewport_rect().position
	shade.size = _viewport_rect().size
	ui.add_child(shade)

func _show_pause() -> void:
	if screen != "playing":
		return
	screen = "pause"
	dash_queued = false
	_clear_ui()
	_shade()
	_panel(Rect2(390, 138, 500, 452))
	_label("잠깐, 숨 고르기", Rect2(436, 175, 440, 55), 34)
	_label("다시 준비되면 궤도로 돌아오세요.", Rect2(438, 242, 420, 30), 18, MUTED)
	_button("계속하기   /   ESC", Rect2(437, 308, 406, 60), _resume, true, true)
	_button("무기 도감", Rect2(437, 386, 193, 52), func() -> void: _open_arsenal("pause"))
	_button("처음부터 다시", Rect2(649, 386, 194, 52), _start_run)
	_button("타이틀로 돌아가기", Rect2(437, 456, 406, 52), _confirm_abandon)
	_label("M 소리 켜기/끄기    ·    F11 전체 화면", Rect2(441, 539, 420, 24), 15, MUTED)
	if not run.mission.is_empty():
		_panel(Rect2(48, 230, 310, 232), PANEL, ItemCatalog.grade_color(str(run.mission.grade)))
		_label("선택 미션 · %s급" % run.mission.grade, Rect2(64, 246, 278, 28), 19, CYAN)
		_label(str(run.mission.name), Rect2(64, 283, 278, 30), 23)
		_wrap_label(str(run.mission.hint), Rect2(64, 322, 278, 66), 18)
		_wrap_label("성공: 추가 강화 %d회 + 파츠 %d개\n50초 수행 · 실패 페널티 없음" % [int(run.mission.upgrades), int(run.mission.parts)], Rect2(64, 393, 278, 56), 15)

func _confirm_abandon() -> void:
	_clear_ui()
	_shade()
	_panel(Rect2(360, 210, 560, 300))
	_label("이번 출격을 종료할까요?", Rect2(405, 247, 500, 50), 30)
	_label("진행 중인 기록은 저장되지 않습니다.", Rect2(406, 312, 470, 30), 18, MUTED)
	_button("계속 플레이", Rect2(406, 390, 220, 60), _resume, true, true)
	_button("출격 종료", Rect2(646, 390, 226, 60), _show_menu)

func _show_help() -> void:
	screen = "help"
	_clear_ui()
	_label("FIELD MANUAL / 01", Rect2(100, 58, 800, 30), 17, LIME)
	_label("세 가지만 기억하세요.", Rect2(100, 115, 1080, 60), 42)
	var rows := [
		["01", "커서 방향으로 자동 이동", "창 밖 커서도 따라 이동 · WASD / 방향키 우선. 커서 근처에서 정지. 공격은 자동."],
		["02", "돌진과 오버드라이브", "좌클릭 / SPACE 무적 돌진. 우클릭 / E로 충전된 오버드라이브 발동 · 6초간 화력 증폭."],
		["03", "나만의 진화 조합", "파란 조각을 모아 1 / 2 / 3으로 강화 선택. TAB 도감에서 무기 진화 조건을 확인하세요."]
	]
	for i in range(rows.size()):
		var y := 217 + i * 112
		_panel(Rect2(100, y, 1080, 96))
		_label(rows[i][0], Rect2(124, y + 20, 80, 46), 30, LIME)
		_label(rows[i][1], Rect2(211, y + 13, 850, 34), 23)
		_label(rows[i][2], Rect2(211, y + 54, 930, 28), 16, MUTED)
	_wrap_label("청록 → 금색 → 붉은색 → 보라색 빛으로 위험을 확인하세요. 바깥으로 갈수록 손상과 감속이 강해집니다.\n기체 아래 왼쪽 초록 게이지는 돌진, 오른쪽 금색 게이지는 오버드라이브입니다.", Rect2(103, 567, 1080, 59), 16, GOLD)
	_button("돌아가기", Rect2(100, 640, 190, 50), _show_menu, false, true)

func _show_settings() -> void:
	screen = "settings"
	_clear_ui()
	_label("PREFERENCES", Rect2(270, 95, 700, 30), 16, LIME)
	_label("나에게 맞게", Rect2(270, 143, 760, 70), 44)
	_button("전체 소리  ·  " + ("OFF / 꺼짐" if records.data.muted else "ON / 켜짐"), Rect2(270, 243, 740, 60), func() -> void: _toggle_mute(); _show_settings(), false, true)
	_button("배경 음악  ·  " + ("ON / 켜짐" if records.data.music else "OFF / 꺼짐"), Rect2(270, 327, 740, 60), _toggle_music)
	_button("화면 효과 줄이기  ·  " + ("ON / 켜짐" if records.data.reduced_motion else "OFF / 꺼짐"), Rect2(270, 411, 740, 60), _toggle_motion)
	_wrap_label("배경 이동·화면 흔들림·장식 연출을 줄입니다. 위험 예고는 계속 표시됩니다.", Rect2(273, 480, 740, 30), 16)
	_wrap_label("설정·최고 기록·도감은 이 기기/브라우저에 자동 저장됩니다." + (" 저장 실패 · 저장 공간과 권한을 확인하세요." if save_failed else ""), Rect2(270, 523, 740, 52), 17, CORAL if save_failed else MUTED)
	_button("돌아가기", Rect2(270, 584, 240, 58), _show_menu)
	_button("오픈 소스 라이선스", Rect2(540, 584, 300, 58), _show_credits)

func _show_credits() -> void:
	screen = "credits"
	_clear_ui()
	_label("OPEN SOURCE / GODOT ENGINE", Rect2(90, 42, 1080, 45), 28, LIME)
	var text := RichTextLabel.new()
	text.position = Vector2(90, 115)
	text.size = Vector2(1100, 490)
	text.add_theme_font_size_override("normal_font_size", 16)
	text.text = "ORBIT BREAKER / ART\n기체·침공체·전장·FX: 이 프로젝트를 위해 제작한 Imagegen 이미지.\n위성·장착 모듈: Blender 5.2.2 원형의 오프라인 렌더.\n시스템 도해·앱 아이콘: 자체 작성 SVG. 외부 게임의 이미지는 제품에 포함하지 않음.\n원본·재현 스크립트·제작 이력: art_source/\n\nNoto Sans KR · SIL Open Font License 1.1\n" + FileAccess.get_file_as_string("res://assets/fonts/OFL.txt") + "\n\nGodot Engine · https://godotengine.org/license/\n\n" + Engine.get_license_text()
	for component in Engine.get_copyright_info():
		text.text += "\n\n" + str(component.get("name", ""))
		for part in component.get("parts", []):
			for copyright_line in part.get("copyright", []):
				text.text += "\n" + str(copyright_line)
			text.text += "\nLicense: " + str(part.get("license", ""))
	var licenses := Engine.get_license_info()
	for license_name in licenses:
		text.text += "\n\n" + str(license_name) + "\n" + str(licenses[license_name])
	ui.add_child(text)
	_button("돌아가기", Rect2(90, 632, 240, 54), _show_settings, false, true)

func _toggle_mute() -> void:
	records.data.muted = not bool(records.data.muted)
	sound.set_muted(records.data.muted)
	save_failed = not records.save_data()
	toast = "소리 꺼짐" if records.data.muted else "소리 켜짐"
	toast_time = 1.6

func _toggle_music() -> void:
	records.data.music = not bool(records.data.music)
	sound.set_music_enabled(records.data.music)
	save_failed = not records.save_data()
	_show_settings()

func _toggle_motion() -> void:
	records.data.reduced_motion = not bool(records.data.reduced_motion)
	save_failed = not records.save_data()
	_show_settings()

func _show_upgrades(refresh: bool = false) -> void:
	screen = "upgrade"
	_clear_ui()
	_shade()
	if not refresh:
		choices = run.get_upgrade_choices()
	_label(("MISSION CLEAR / 추가 강화 · 남은 %d회" % (run.mission_bonus_choices + 1)) if run.upgrade_source == "mission" else "LEVEL %02d / SYSTEM UPGRADE" % run.level, Rect2(64, 72, 900, 28), 17, CYAN)
	_label("다음 궤도를 선택하세요.", Rect2(60, 112, 1160, 64), 43)
	_label("전투 정지 · 1 / 2 / 3 선택 · 5분부터 모든 수리 효율 감소 · 현재 %d%%" % roundi(run.repair_efficiency() * 100), Rect2(64, 192, 1152, 30), 18, MUTED)
	for i in range(choices.size()):
		var entry = choices[i]
		var id: String = str(entry.id) if entry is Dictionary else str(entry)
		var info: Dictionary = RunModel.upgrade_info(id)
		var x := 64 + i * 386
		var selected := i
		var card := _button("", Rect2(x, 254, 366, 350), func() -> void: _pick_upgrade(selected))
		card.set_meta("flow_order",254+i*2)
		_glyph("upgrade", id, Rect2(18, 18, 64, 64), LIME if id in ["repair", "vitality", "restore"] else CYAN, card)
		var level_text := "즉시 적용" if int(info.cap) == 0 else "Lv.%d → %d / %d" % [run.upgrades.get(id, 0), int(run.upgrades.get(id, 0)) + 1, info.cap]
		_label(level_text, Rect2(100, 32, 246, 30), 17, INK, card)
		_label(str(info.name), Rect2(22, 94, 322, 40), 26, INK, card)
		_wrap_label(str(info.description), Rect2(22, 143, 322, 60), 18, INK, card)
		_wrap_label(_upgrade_delta(id), Rect2(22, 207, 322, 34), 16, LIME, card)
		var links_scroll := ScrollContainer.new()
		links_scroll.position = Vector2(22, 245)
		links_scroll.size = Vector2(322, 96)
		links_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		links_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
		card.add_child(links_scroll)
		var links_label := Label.new()
		links_label.text = _upgrade_links(id)
		links_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		links_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		links_label.add_theme_font_size_override("font_size",15)
		links_label.add_theme_color_override("font_color",CYAN)
		links_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		links_scroll.add_child(links_label)
		var choose_button := _button("선택   [%d]" % (i + 1), Rect2(x, 620, 366, 60), func() -> void: _pick_upgrade(selected), false, i == 0)
		choose_button.set_meta("flow_order",255+i*2)

func _upgrade_delta(id: String) -> String:
	var level := int(run.upgrades.get(id, 0))
	match id:
		"power": return "코어 보너스 +%d%% → +%d%%" % [level * 25, (level + 1) * 25]
		"rapid": return "속사 보너스 +%d%% → +%d%%" % [level * 24, (level + 1) * 24]
		"repair": return "현재 재생 %.2f → %.2f HP/초" % [run.regeneration_rate(), run.regeneration_rate() + 1.25 * run.repair_efficiency()]
		"vitality": return "최대 선체 %d → %d" % [int(run.max_hp), int(run.max_hp) + 35]
		"restore": return "선체 %.0f → %.0f" % [run.hp, minf(run.max_hp, run.hp + 80 * run.repair_efficiency())]
		"orbit": return "위성 %d → %d기" % [run.orbit_count, run.orbit_count + 1]
		_: return "즉시 적용" if int(RunModel.upgrade_info(id).cap) == 0 else "출격 중 유지 · 일시 보급과 별개"

func _upgrade_links(id: String) -> String:
	var links: Array[String] = []
	for evolution_id in GameContent.EVOLUTION_IDS:
		var info: Dictionary = GameContent.evolution_info(evolution_id)
		if not info.requirements.has(id):
			continue
		if run.evolutions.has(evolution_id):
			links.append(str(info.name) + (" · 숙련 성장" if str(info.mastery) == id else " · 진화 완료"))
			continue
		var requirements: Array[String] = []
		var complete := true
		for required in info.requirements:
			var current := int(run.upgrades.get(required, 0)) + (1 if required == id else 0)
			var target := int(info.requirements[required])
			complete = complete and current >= target
			requirements.append("%s %d/%d" % [str(RunModel.upgrade_info(required).name).replace("고출력 코어", "코어").replace("위성 증설", "위성").replace("속사 회로", "속사"), mini(current, target), target])
		links.append("%s%s\n%s" % [info.name, " · 선택 시 완성" if complete else "", " + ".join(requirements)])
	return "\n".join(links) if not links.is_empty() else "독립 강화 · 모든 빌드에 적용"

func _pick_upgrade(index: int) -> void:
	if screen != "upgrade" or index < 0 or index >= choices.size():
		return
	var entry = choices[index]
	var id: String = str(entry.id) if entry is Dictionary else str(entry)
	if run.choose_upgrade(id):
		_collect_progress_notices()
		sound.play("select")
		if run.state == "upgrade":
			_show_upgrades()
		else:
			_resume()

func _show_result() -> void:
	screen = "result"
	var won := run.state == "won"
	if not saved_result:
		run._update_run_stats()
		ghost.capture(run, true)
		var details := run.run_stats.duplicate(true)
		details.name = records.data.player_name
		save_failed = not records.record_run(run.ranked_score(), run.elapsed, won, details)
		var entry := records.ghost_candidate(run.ranked_score(), run.elapsed, records.data.player_name, run.mode)
		if not save_failed and not entry.is_empty() and entry.ghost.is_empty():
			var id := Crypto.new().generate_random_bytes(16).hex_encode()
			var writer := GhostReplay.new()
			if writer.begin_write(records.ghost_path(id), ghost.frames):
				ghost_jobs.append({"writer": writer, "entry": entry, "id": id})
				ghost.frames = []
				writer.start_background()
		if not ghost.frames.is_empty():
			var disposer := GhostReplay.new()
			disposer.begin_discard(ghost.frames)
			ghost.frames = []
			ghost_jobs.append({"writer": disposer, "discard": true})
			disposer.start_background()
		saved_result = true
		sound.play("win" if won else "lose")
	_clear_ui()
	_shade()
	_label("RUN COMPLETE / " + ("VICTORY" if won else "SIGNAL LOST"), Rect2(120, 79, 1060, 30), 17, LIME if won else CORAL)
	_label("궤도 돌파 성공!" if won else "한 번 더, 더 멀리.", Rect2(116, 135, 1080, 76), 54)
	_label("%s  /  %s  /  %s" % [GameContent.ship_info(run.ship_id).name, GameContent.sector_info(run.sector_id).name, str(GameContent.mode_info(run.mode).name) + " ×" + str(GameContent.mode_info(run.mode).score)], Rect2(120, 229, 1060, 34), 21, MUTED)
	_label({"collapse": "10분 도달 · 우주 완전 붕괴", "decay": "선체 유지 한계 · 붕괴 피해로 종료", "boundary": "안전 궤도 이탈 · 외곽 노출로 선체 붕괴", "combat": "적 공격으로 선체 파괴"}.get(run.end_reason, "") + (" · 5분 돌파 기록 인정" if won else ""), Rect2(123, 275, 1060, 28), 16, CORAL)
	var values := [["최종 점수", _number(run.ranked_score())], ["생존 시간", _time(run.elapsed)], ["처치한 적", str(run.kills)], ["최종 레벨", "LV.%02d" % run.level]]
	for i in range(values.size()):
		var x := 120 + i * 265
		_panel(Rect2(x, 315, 245, 130))
		_label(values[i][0], Rect2(x + 24, 335, 210, 28), 17, MUTED)
		_label(values[i][1], Rect2(x + 24, 378, 215, 49), 34, LIME if i == 0 else INK)
	var evolution_names: Array[String] = []
	for id in run.evolutions:
		evolution_names.append(GameContent.evolution_info(id).name)
	_wrap_label("지휘체 %d / 정예 %d / 진화 %s" % [run.bosses_killed, run.elites_killed, " · ".join(evolution_names) if not evolution_names.is_empty() else "없음 — 다음 출격에서 조합에 도전하세요"], Rect2(123, 460, 1080, 49), 17, CYAN)
	_panel(Rect2(110, 512, 1070, 68), PANEL, CORAL if save_failed else GOLD)
	if save_failed:
		_wrap_label("기록 저장 실패 · 이 기기/브라우저의 저장 공간과 접근 권한을 확인하세요.", Rect2(129, 526, 1030, 44), 18, CORAL)
	else:
		var medals: Array[String] = []
		for item: Dictionary in Achievements.catalog():
			if item.id in records.new_achievements:
				medals.append("%s +%d" % [item.name, item.points])
		_wrap_label(("고스트 저장 중 · 완료 알림 후 종료하세요. 다시 출격할 수 있습니다.\n" if ghost_jobs.any(func(job: Dictionary) -> bool: return not job.get("discard", false)) else "") + ("업적 %d점 / " % Achievements.points(records.data.achievements) + " · ".join(medals.slice(0, 3)) + (" 외 %d개" % (medals.size() - 3) if medals.size() > 3 else "") if not medals.is_empty() else "기록 저장 완료 · 진화 조합으로 새로운 최고 기록에 도전하세요."), Rect2(129, 522, 1030, 52), 16, GOLD)
	_button("다시 출격하기   →", Rect2(120, 591, 350, 64), _start_run, true, true)
	_button("조합 바꾸기", Rect2(494, 591, 300, 64), _show_hangar)
	_button("랭킹 / 고스트", Rect2(818, 591, 282, 64), func() -> void: records_tab = "ranking"; ranking_mode = run.mode; _show_records())
	if won and run.mode in ["normal", "veteran"]:
		_label("상위 난이도 해금 · 출격 준비에서 선택하세요", Rect2(120, 666, 900, 25), 17, LIME)

func _time(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]

func _number(value: int) -> String:
	var source := str(value)
	var formatted := ""
	for i in range(source.length()):
		if i > 0 and (source.length() - i) % 3 == 0:
			formatted += ","
		formatted += source[i]
	return formatted

func _draw() -> void:
	if screen in ["menu", "help", "settings", "credits", "hangar", "records", "replay"] or (screen == "arsenal" and codex_return == "menu"):
		draw_rect(_viewport_rect(), BG)
		draw_texture_rect(ArtAssets.texture("world/ring"), _viewport_rect(), false, Color(1, 1, 1, 0.55))
		for i in range(mini(stars.size(),48)):
			draw_circle(_viewport_rect().position + stars[i] * _viewport_rect().size / Vector2(1280, 720), 1.0 if i % 4 else 1.6, Color(0.25, 0.37, 0.44, 0.42))
	if screen in ["menu", "help", "settings", "credits", "hangar", "records"] or (screen == "arsenal" and codex_return == "menu"):
		if screen == "menu":
			_draw_motif(Vector2(914, 346))
		return
	if screen == "replay":
		_draw_replay()
		return
	_draw_arena()
	if screen == "playing" and run.boundary_depth(run.player) > 0.0:
		_draw_boundary_warning()
	if screen == "playing":
		_draw_item_status()
		_draw_expedition(run)
	if toast_time > 0 and screen == "playing":
		var width := font.get_string_size(toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 48
		var has_event := run.hazards.any(func(h: Dictionary) -> bool: return RunModel.ENCOUNTERS.has(h.kind))
		var pos := Vector2(640 - width / 2, 226 if has_event else 190)
		var notification_style := _style(Color(Color("182b39"), TOAST_ALPHA), Color(LINE, 0.12))
		notification_style.shadow_size = 0
		draw_style_box(notification_style, Rect2(pos, Vector2(width, 45)))
		draw_string(font, pos + Vector2(24, 29), toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(INK, 0.60))

func _draw_motif(center: Vector2) -> void:
	var t := 0.0 if records.data.reduced_motion else clock_time * 0.3
	for radius in [95, 165, 238]:
		draw_arc(center, radius, 0, TAU, 100, LINE, 1.0, true)
	for i in range(4):
		var angle := t + i * TAU / 4
		var pos := center + Vector2.from_angle(angle) * 165
		draw_arc(center, 165, angle - 0.3, angle, 18, Color(CYAN, 0.4), 4, true)
		ArtAssets.sprite(self, "objects/normal", pos, Vector2.ONE * 28, angle)
	preload("res://scripts/ui_glyph.gd").ship(self, center, selected_ship, CYAN, 7.0, -PI / 6)
	draw_arc(center, 270, -0.8, 2.9, 100, Color(CORAL, 0.22), 3, true)
	for i in range(6):
		var angle := -t * 0.4 + i * 1.05
		var pos := center + Vector2.from_angle(angle) * (238 + 12 * sin(t + i))
		ArtAssets.sprite(self, "enemies/runner" if i % 2 else "enemies/chaser", pos, Vector2.ONE * 37, angle + PI)
	draw_string(font, center + Vector2(-106, 292), "SURVIVE. EVOLVE. BREAK.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, MUTED)

func _draw_arena(world: RunModel = null) -> void:
	var model := run if world == null else world
	var sector_color: Color = GameContent.sector_info(model.sector_id).color
	var world_rect := Rect2(camera_offset + _viewport_rect().position, _viewport_rect().size)
	var visible_world := world_rect.grow(80.0)
	draw_set_transform(-camera_offset)
	draw_rect(world_rect, Color("050c16"))
	var bg_id: String = "world/" + model.sector_id
	var bg_size := world_rect.size * 1.18
	var bg_shift := camera_offset * 0.06
	draw_texture_rect(ArtAssets.texture(bg_id), Rect2(world_rect.get_center() - bg_size * 0.5 - bg_shift, bg_size), false, Color(1,1,1,0.8))
	_draw_orbital_regions(sector_color)
	_draw_space(sector_color)
	var center := ARENA.get_center()
	draw_arc(center, RunModel.ACTIVITY_RADIUS / 3, 0, TAU, 96, Color("203344"), 1, true)
	draw_arc(center, RunModel.ACTIVITY_RADIUS * 2 / 3, 0, TAU, 128, Color("203344"), 1, true)
	for hazard in model.hazards:
		_draw_hazard(hazard, model.elapsed)
	for gem in model.gems:
		if not visible_world.has_point(gem.pos):
			continue
		var pos: Vector2 = gem.pos
		var is_heal: bool = str(gem.get("kind", "xp")) == "heal"
		ArtAssets.sprite(self, "objects/heal" if is_heal else "objects/xp", pos, Vector2.ONE * (18 if is_heal else 12), 0, camera_offset)
	for item: Dictionary in model.items:
		if not visible_world.has_point(item.pos):
			continue
		var at: Vector2 = item.pos
		var color := ItemCatalog.grade_color(str(item.grade))
		ArtAssets.container(self, at, str(item.grade), 25)
		ItemCatalog.draw_icon(self, at, str(item.id), INK)
		draw_string(font, at + Vector2(-17, -29), str(item.grade), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)
		draw_string(font, at + Vector2(-17, 40), "%d초" % ceili(float(item.ttl)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
	var decorative_effects := 0
	for effect in model.effects:
		if not visible_world.grow(float(effect.radius)).has_point(effect.pos) and not visible_world.has_point(effect.get("end", effect.pos)):
			continue
		if records.data.reduced_motion and not (str(effect.kind).begins_with("impact_") or str(effect.kind) == "hit" or str(effect.kind).begins_with("risk_")):
			continue
		if str(effect.kind) in ["hit", "death", "pickup", "arrival"]:
			decorative_effects += 1
			if decorative_effects > 72:
				continue
		var life: float = clampf(float(effect.ttl) / maxf(0.01, float(effect.get("max_ttl", 0.5))), 0, 1)
		if str(effect.kind).begins_with("risk_"):
			continue
		if str(effect.kind).begins_with("impact_") or str(effect.kind) in ["hit", "death", "meteor_impact", "reward", "hazard_start"]:
			_draw_impact(effect, life)
			continue
		var color := LIME if str(effect.kind) == "dash" else CORAL
		if str(effect.kind) in ["pickup", "level", "pulse"]:
			color = CYAN
		if str(effect.kind) == "lightning":
			var end: Vector2 = effect.get("end", effect.pos)
			var start: Vector2 = effect.pos
			var middle := (start + end) * 0.5 + (end - start).orthogonal().normalized() * 12
			draw_polyline(PackedVector2Array([start, middle, end]), Color(CYAN, life), 3, true)
			continue
		if str(effect.kind) in ["missile", "guard", "arrival"]:
			color = GOLD
		if str(effect.kind) in ["pulse","guard","arrival","level"]:
			var fx_size := maxf(16, float(effect.radius) * (2.0 - life * 0.4))
			ArtAssets.sprite(self, "fx/wave", effect.pos, Vector2.ONE * fx_size, 0, camera_offset, Color(1,1,1,life*0.3))
		draw_arc(effect.pos, maxf(2, float(effect.get("radius", 20)) * (1.2 - life * 0.4)), 0, TAU, 22, Color(color, life * 0.65), 2, true)
	var friendly_tails := PackedVector2Array()
	var hostile_tails := PackedVector2Array()
	var rail_tails := PackedVector2Array()
	var projectile_bodies: Array[Dictionary] = []
	for shot in model.shots:
		if not visible_world.has_point(shot.pos):
			continue
		var color := LIME if bool(shot.friendly) else GOLD
		if shot.get("kind", "") == "missile":
			color = Color("ffb777")
		var kind: String = str(shot.get("kind", ""))
		if kind in ["sentry", "mine", "wake", "axe"]:
			color = {"sentry": CYAN, "mine": GOLD, "wake": SPEED_BLUE, "axe": CORAL}[kind]
			if kind == "wake":
				ArtAssets.sprite(self, "fx/wave", shot.pos, Vector2.ONE * float(shot.radius) * 2, 0, camera_offset, Color(1,1,1,clampf(float(shot.ttl) / 2.4, 0.2, 0.45)))
			else:
				var deploy_scale := 0.6 if kind == "mine" and float(shot.get("armed",0)) > 0 else 1.0
				ArtAssets.sprite(self, "objects/" + kind, shot.pos, Vector2.ONE * (float(shot.radius) + 4) * 2.4 * deploy_scale, model.elapsed * 5 if kind == "axe" else 0, camera_offset)
			continue
		var velocity: Vector2 = shot.get("velocity", Vector2.ZERO)
		if kind == "missile":
			ArtAssets.sprite(self, "fx/thrust", shot.pos - velocity.normalized() * 13, Vector2(32, 12), velocity.angle(), camera_offset, Color(1,1,1,0.75))
			ArtAssets.sprite(self, "objects/missile", shot.pos, Vector2(24, 15), velocity.angle(), camera_offset)
			continue
		if bool(shot.friendly) and int(shot.get("pierce",1)) > 2:
			rail_tails.append_array(PackedVector2Array([shot.pos - velocity.normalized() * 24, shot.pos]))
		if bool(shot.friendly):
			friendly_tails.append_array(PackedVector2Array([shot.pos - velocity.normalized() * 10, shot.pos]))
		else:
			hostile_tails.append_array(PackedVector2Array([shot.pos - velocity.normalized() * 10, shot.pos]))
		projectile_bodies.append(shot)
	if not friendly_tails.is_empty(): draw_multiline(friendly_tails, Color(LIME,0.5),2,true)
	if not hostile_tails.is_empty(): draw_multiline(hostile_tails, Color(GOLD,0.5),2,true)
	if not rail_tails.is_empty(): draw_multiline(rail_tails,Color(CYAN,0.65),3,true)
	for shot: Dictionary in projectile_bodies:
		var color := LIME if bool(shot.friendly) else GOLD
		var radius := float(shot.get("radius",4))
		# The SVG core is 24/64 of its width: its visible radius equals the model radius.
		ArtAssets.sprite(self,"fx/projectile",shot.pos,Vector2.ONE * radius * (64.0/24.0),0,camera_offset,color)
	if model.buffs.has("shield"):
		draw_arc(model.player, 36, 0, TAU, 40, CYAN, 3, true)
	for enemy in model.enemies:
		if not visible_world.has_point(enemy.pos) and float(enemy.get("warn", 0.0)) <= 0.0:
			continue
		_draw_enemy(enemy, model)
	var player: Vector2 = model.player
	for drop: Dictionary in model.part_drops:
		var info := Expedition.part(str(drop.id))
		var color: Color = info.color
		var at: Vector2 = drop.pos
		draw_circle(at, 26, BG)
		_draw_part_icon(at, str(drop.id), color, 1.0, true)
		draw_arc(at, 26, 0, TAU * clampf(float(drop.ttl) / 45.0, 0, 1), 36, color, 2, true)
		draw_string(font, at + Vector2(-52, -33), str(info.name), HORIZONTAL_ALIGNMENT_CENTER, 104, 13, color)
		draw_string(font, at + Vector2(-52, 43), "%d초 · %s" % [ceili(float(drop.ttl)), "2층 탐사" if bool(drop.locked) else "회수"], HORIZONTAL_ALIGNMENT_CENTER, 104, 12, INK)
	var reduced: bool = records.data.reduced_motion
	var ship_color: Color = GameContent.ship_info(model.ship_id).color
	if not reduced and speed_gauge > 0.1:
		ArtAssets.sprite(self, "fx/thrust", player - model.facing * 23, Vector2(23 + speed_gauge * 22,12), model.facing.angle(), camera_offset, Color(1,1,1,0.5))
	if model.overdrive_time > 0:
		draw_arc(player, 31, 0, TAU, 40, GOLD, 3, true)
		draw_arc(player, model.orbit_radius + 7, 0, TAU, 64, Color(GOLD, 0.35), 2, true)
	if model.evolutions.has("ellipse"):
		var track := PackedVector2Array()
		for point in 65:
			var a := TAU * point / 64.0
			track.append(player + Vector2(cos(a) * model.orbit_radius * 1.8, sin(a) * model.orbit_radius * 0.7).rotated(model.orbit_angle * 0.23))
		draw_polyline(track, Color(CYAN, 0.25), 1, true)
	else:
		draw_arc(player, model.orbit_radius, 0, TAU, 60, Color(CYAN, 0.16), 1, true)
	for i in range(model.orbit_count):
		var angle: float = model.orbit_angle + TAU * i / model.orbit_count
		var pos := model.orbit_position(i)
		var kind := model.orbit_kind(i)
		var orbit_color: Color = CORAL if kind == "blade" else (CYAN if kind == "frost" else GOLD)
		if not reduced and not model.evolutions.has("ellipse"):
			draw_arc(player, model.orbit_radius, angle - 0.45, angle, 16, Color(orbit_color, 0.5), 3, true)
		ArtAssets.sprite(self, "objects/" + kind, pos, Vector2.ONE * (30 if model.evolutions.has("superorbit") else 23), angle + PI / 2, camera_offset)
	if model.dash_time > 0:
		draw_circle(player, 25, Color(LIME, 0.12), true, -1, true)
		if not reduced:
			draw_line(player - model.facing * 70, player, Color(LIME, 0.5), 13, true)
	ArtAssets.sprite(self, "ships/" + model.ship_id, player, Vector2.ONE * 40, model.facing.angle(), camera_offset, Color(1.6,1.6,1.6) if hurt_flash > 0 else Color.WHITE)
	for i in 3:
		var id: String = Expedition.PART_IDS[i]
		if int(model.parts.get(id, 0)) > 0:
			var at := player + Vector2.from_angle(model.facing.angle() + TAU * i / 3.0) * 24.0
			_draw_part_icon(at, id, Expedition.part(id).color, 0.45, true)
	if not model.hull_forms.is_empty():
		for form: String in model.hull_forms:
			var rank := model.hull_rank(form)
			if form == "battery":
				for mount in (3 if rank == 2 else 2):
					var at := player + model.facing * 11 + model.facing.orthogonal() * (mount - (1.0 if rank == 2 else 0.5)) * 13
					ArtAssets.sprite(self, "objects/missile", at, Vector2(19,10), model.facing.angle(), camera_offset)
			elif form == "lancer":
				ArtAssets.sprite(self, "objects/core", player + model.facing * 17, Vector2.ONE * (14 if rank == 2 else 10), model.facing.angle(), camera_offset)
			elif form == "aegis":
				for side in [-1,1]:
					ArtAssets.sprite(self, "objects/shell", player + model.facing.orthogonal() * side * 23, Vector2.ONE * (15 if rank == 2 else 11), model.facing.angle(), camera_offset)
			elif form == "trinity":
				draw_arc(player, 24, model.facing.angle()-1, model.facing.angle()+1, 20, Color(LIME,0.65), rank + 1, true)
	var wing := model.facing.orthogonal()
	match model.ship_id:
		"striker":
			for i: int in range(5):
				draw_circle(player - model.facing * 22 + wing * (i - 2) * 7, 2.5, ship_color if i < floori(model.focus_time / 1.2 * 5) else LINE, true, -1, true)
		"scout":
			for side: float in [-1.0, 1.0]:
				var tip := player - model.facing * 12 + wing * side * 22
				if model.slipstream_time > 0.0:
					draw_line(tip, tip - model.facing * (24 if reduced else 48), Color(ship_color, 0.65), 3, true)
		"bastion":
			draw_arc(player, 29, -PI / 2, -PI / 2 + TAU * maxf(0.01, 1.0 - model.guard_cooldown / 8.0), 40, ship_color, 3 if model.guard_stacks > 0 else 1, true)
			if model.guard_capacity() > 1:
				draw_string(font, player + Vector2(-18, -40), "%d/%d" % [model.guard_stacks, model.guard_capacity()], HORIZONTAL_ALIGNMENT_CENTER, 36, 13, ship_color)
	if screen in ["playing", "replay"]:
		_draw_skill_meter(player + Vector2(-25, 37), model.dash_charge(), LIME, model.dash_cooldown <= 0, true)
		_draw_skill_meter(player + Vector2(25, 37), clampf(model.overdrive_time / 6.0 if model.overdrive_time > 0 else model.overdrive_meter / 100.0, 0, 1), GOLD, model.overdrive_meter >= 100.0 and model.overdrive_time <= 0)
		for side: int in range(2):
			var at := player + Vector2(-25 if side == 0 else 25, 37)
			draw_style_box(_style(BG, MUTED), Rect2(at - Vector2(4, 6), Vector2(8, 12)))
			draw_rect(Rect2(at + Vector2(-3 if side == 0 else 0, -5), Vector2(3, 4)), LIME if side == 0 else GOLD)
	draw_set_transform(Vector2.ZERO)
	if screen == "playing":
		draw_rect(Rect2(_viewport_rect().position, Vector2(_viewport_rect().size.x, 176 - _viewport_rect().position.y)), Color(BG, HUD_ALPHA))
		_draw_meters()
		_draw_invasion_markers()
		_draw_reward_feedback(model)
		_draw_progress_notice()
		if OS.has_feature("web") and dash_cursor_anchor:
			var at := run.player - camera_offset
			draw_arc(at, 17, 0, TAU, 24, INK, 1, true)
			draw_line(at + Vector2(-22, 0), at + Vector2(-12, 0), INK, 1, true)
			draw_line(at + Vector2(12, 0), at + Vector2(22, 0), INK, 1, true)
	if screen in ["playing", "replay"]:
		_draw_event_notice(model)
	if hurt_flash > 0 and not reduced:
		draw_rect(_viewport_rect(), Color(CORAL, hurt_flash * 0.17))

func _reward_feedback(model: RunModel, kind: String) -> Dictionary:
	for index in range(model.effects.size() - 1, -1, -1):
		if model.effects[index].kind == kind:
			if model == run:
				reward_cues[kind] = model.effects[index]
			return model.effects[index]
	return reward_cues.get(kind, {}) if model == run else {}

func _draw_reward_feedback(model: RunModel) -> void:
	# Keep the last two gains below milestones, even after their pulse has ended.
	for kind: String in ["risk_score", "risk_xp"]:
		var effect := _reward_feedback(model, kind)
		if effect.is_empty():
			continue
		var life := clampf(float(effect.ttl) / maxf(0.01, float(effect.max_ttl)), 0, 1)
		var multiplier := Vector2(effect.end).x
		var layer: int = [1.0, 1.25, 1.6, 2.1].find(snappedf(multiplier, 0.01))
		var tier: Color = [MUTED, GOLD, CORAL, Color("c69cff")][maxi(0, layer)]
		var color := CYAN if kind == "risk_xp" else GOLD
		var at := Vector2(894, 151 if kind == "risk_xp" else 119)
		var alpha := 1.0
		var pulse := 0.0 if records.data.reduced_motion else pow(life, 6)
		draw_style_box(_style(Color(BG, HUD_ALPHA), Color(tier, 0.35 + pulse * 0.45)), Rect2(at, Vector2(338, 27)))
		draw_rect(Rect2(at, Vector2(3 + pulse * 2, 27)), tier)
		if kind == "risk_xp":
			_diamond(at + Vector2(17, 14), 6 + pulse, Color(color, alpha), 0)
		else:
			_polygon(at + Vector2(17, 14), 7 + pulse, 6, Color(color, alpha))
			draw_circle(at + Vector2(17, 14), 3, BG)
		var amount := "+%.1f" % float(effect.radius) if kind == "risk_xp" else "+%d" % roundi(float(effect.radius))
		draw_string(font, at + Vector2(34, 20), amount, HORIZONTAL_ALIGNMENT_LEFT, 158, 18, Color(color, alpha))
		if multiplier > 1.0:
			draw_string(font, at + Vector2(226, 20), "×%.2f" % multiplier, HORIZONTAL_ALIGNMENT_RIGHT, 96, 14, Color(tier, alpha))
		for dot in 3:
			draw_circle(at + Vector2(201 + dot * 8, 14), 2.5, Color(tier if dot < layer else LINE, alpha))

func _draw_orbital_regions(sector_color: Color) -> void:
	var center := RunModel.CENTER
	var radius := RunModel.ACTIVITY_RADIUS
	var colors := [sector_color, GOLD, CORAL, Color("bd81ff")]
	for layer: int in range(4):
		var edge := radius + layer * RunModel.LAYER_WIDTH
		var color: Color = colors[layer]
		draw_arc(center, edge, 0, TAU, 192, Color(color, 0.5), 1.5, true)
		for segment in 24:
			var a := TAU * segment / 24.0
			draw_arc(center, edge + 5, a, a + 0.06, 4, Color(color, 0.25), 5, true)

func _draw_invasion_markers() -> void:
	var occupied: Array[Rect2] = []
	for enemy: Dictionary in run.enemies:
		if enemy.kind in ["boss", "elite"] and Vector2(enemy.pos).distance_to(RunModel.CENTER) > RunModel.ACTIVITY_RADIUS:
			var direction := (Vector2(enemy.pos) - run.player).normalized()
			var marker := Vector2(640, 386) + direction * minf(505.0 / maxf(0.01, absf(direction.x)), 173.0 / maxf(0.01, absf(direction.y)))
			_draw_direction_marker(marker, direction, CORAL, str(enemy.kind))
			var rect := Rect2(Vector2(clampf(marker.x - 90, 48, 1050), clampf(marker.y + 12, 205, 430)), Vector2(182, 26))
			for previous in occupied:
				if rect.intersects(previous):
					rect.position.y = previous.end.y + 3
			occupied.append(rect)
			draw_style_box(_style(Color(BG, 0.88), Color(CORAL, 0.4)), rect)
			draw_string(font, rect.position + Vector2(8, 19), "%s · %dm" % ["지휘체" if enemy.kind == "boss" else "정예", roundi(run.player.distance_to(enemy.pos))], HORIZONTAL_ALIGNMENT_LEFT, 168, 15, CORAL)

func _draw_direction_marker(at: Vector2, direction: Vector2, color: Color, kind: String, id: String = "") -> void:
	var ray := direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	var tip := at + ray * 12
	draw_line(at - ray * 12, tip, BG, 7, true)
	draw_line(at - ray * 12, tip, color, 3, true)
	draw_polyline(PackedVector2Array([tip - ray * 10 + ray.orthogonal() * 7, tip, tip - ray * 10 - ray.orthogonal() * 7]), color, 3, true)
	var badge := at - ray * 29
	draw_circle(badge, 13, BG)
	match kind:
		"boss":
			draw_arc(badge, 9, 0, TAU, 20, color, 2, true)
			draw_line(badge - Vector2(12, 0), badge + Vector2(12, 0), color, 2, true)
			draw_line(badge - Vector2(0, 12), badge + Vector2(0, 12), color, 2, true)
		"elite":
			_diamond(badge, 10, color)
			_diamond(badge, 6, BG)
		"part":
			_draw_part_icon(badge, id, color, 0.75)
		"item":
			draw_rect(Rect2(badge - Vector2(9, 9), Vector2(18, 18)), color, false, 2)
			ItemCatalog.draw_icon(self, badge, id, color, 0.6)

func _draw_skill_meter(at: Vector2, progress: float, color: Color, ready: bool, triangular: bool = false) -> void:
	var sides := 3 if triangular else 24
	_polygon(at, 17 if triangular else 15, sides, Color(BG, 0.88), -PI / 2)
	var glow := 1.0 if records.data.reduced_motion or not ready else 0.82 + 0.18 * sin(space_time * 4.0)
	if ready:
		_polygon(at, 16 if triangular else 14, sides, Color(color, 0.10 * glow), -PI / 2)
	for i: int in range(24):
		var t := float(i) * sides / 24.0
		var start := Vector2.from_angle(-PI / 2 + TAU * floorf(t) / sides) * (16 if triangular else 12)
		var end := Vector2.from_angle(-PI / 2 + TAU * (floorf(t) + 1) / sides) * (16 if triangular else 12)
		var a := start.lerp(end, fposmod(t, 1.0))
		var b := start.lerp(end, minf(1.0, fposmod(t, 1.0) + sides / 24.0 * 0.8))
		draw_line(at + a, at + b, Color(color, glow) if float(i) / 24.0 < progress else LINE, 2, true)

func _draw_space(sector_color: Color) -> void:
	var bounds := _viewport_rect()
	for i: int in range(mini(stars.size(), 48)):
		var depth := 0.2 + float(i % 3) * 0.25
		var drift := Vector2.ZERO if records.data.reduced_motion else space_offset * depth + Vector2(-space_time * 3.0 * depth, 0)
		var point := stars[i] - camera_offset * depth + drift
		point = Vector2(fposmod(point.x - bounds.position.x, bounds.size.x), fposmod(point.y - bounds.position.y, bounds.size.y)) + bounds.position + camera_offset
		draw_circle(point, 1.0 + float(i % 3) * 0.35, Color(sector_color, 0.2 + depth * 0.3))

func _draw_hazard(hazard: Dictionary, visual_time: float = 0.0) -> void:
	if RunModel.ENCOUNTERS.has(hazard.kind):
		_draw_encounter(hazard, visual_time)
		return
	var active: bool = hazard.get("active", false)
	var color: Color = CORAL if active else GOLD
	if str(hazard.kind) == "lane":
		var rect: Rect2 = hazard.rect
		draw_rect(rect, Color(color, 0.28 if active else 0.09))
		draw_rect(rect, Color(color, 0.9), false, 2)
		var center := rect.get_center()
		draw_string(font, center + Vector2(-7, 7), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, color)
		if active:
			var vertical := rect.size.y > rect.size.x
			var points := PackedVector2Array()
			for i in 25:
				var along := float(i) / 24.0
				var jitter := 0.0 if records.data.reduced_motion else sin(i * 7.0 + visual_time * 30.0) * 14.0
				points.append(Vector2(center.x + jitter, rect.position.y + rect.size.y * along) if vertical else Vector2(rect.position.x + rect.size.x * along, center.y + jitter))
			draw_polyline(points, Color(CYAN, 0.35), 13, true)
			draw_polyline(points, INK, 3, true)
	else:
		var pos: Vector2 = hazard.pos
		var radius: float = hazard.radius
		draw_circle(pos, radius, Color(color, 0.28 if active else 0.08), true, -1, true)
		draw_arc(pos, radius, 0, TAU, 48, color, 2, true)
		draw_line(pos - Vector2(10, 0), pos + Vector2(10, 0), color, 2, true)
		draw_line(pos - Vector2(0, 10), pos + Vector2(0, 10), color, 2, true)

func _draw_encounter(hazard: Dictionary, visual_time: float = 0.0) -> void:
	var pos: Vector2 = hazard.pos
	var radius: float = hazard.radius
	var active: bool = hazard.active
	var color: Color = {"black_hole": Color("b695ff"), "planet": CYAN, "meteor": GOLD, "flare": CORAL}[str(hazard.kind)]
	draw_circle(pos, radius, Color(color, 0.07), true, -1, true)
	draw_arc(pos, radius, 0, TAU, 96, Color(color, 0.7), 2, true)
	if not active:
		draw_arc(pos, radius + 6, -PI / 2, -PI / 2 + TAU * clampf(float(hazard.warn) / 10.0, 0.001, 1.0), 96, color, 4, true)
		_polygon(pos, 14, 3, color, -PI / 2)
		draw_string(font, pos + Vector2(-100, -28), "%s · %d초" % [RunModel.ENCOUNTERS[hazard.kind].name, ceili(float(hazard.warn))], HORIZONTAL_ALIGNMENT_CENTER, 200, 20, INK)
	match str(hazard.kind):
		"black_hole":
			if active:
				var turn := 0.0 if records.data.reduced_motion else visual_time * 0.7
				ArtAssets.sprite(self, "fx/black_hole", pos, Vector2.ONE * 160, turn, camera_offset, Color(1,1,1,0.9))
				for i in 8:
					var direction := Vector2.from_angle(TAU * i / 8.0)
					var tip := pos + direction * 80
					draw_line(pos + direction * 120, tip, color, 2, true)
					draw_line(tip, tip + direction.rotated(0.5) * 13, color, 2, true)
		"planet":
			if active:
				ArtAssets.sprite(self, "objects/planet", pos, Vector2.ONE * 90, 0, camera_offset)
				draw_arc(pos, radius - 6, -PI / 2, -PI / 2 + TAU * clampf(float(hazard.get("hold", 0.0)) / 12.0, 0.001, 1.0), 96, LIME, 6, true)
		"meteor":
			for point: Vector2 in RunModel.meteor_points(hazard):
				draw_circle(point, 64, Color(color, 0.09), true, -1, true)
				draw_arc(point, 64, 0, TAU, 40, color, 2, true)
				draw_line(point - Vector2(9, 9), point + Vector2(9, 9), color, 2, true)
				draw_line(point - Vector2(-9, 9), point + Vector2(-9, 9), color, 2, true)
				if active and not records.data.reduced_motion:
					var approach := clampf(float(hazard.ttl) / 0.7, 0, 1)
					ArtAssets.sprite(self, "objects/meteor", point + Vector2(-110,-160) * approach, Vector2.ONE * 28, 0.8, camera_offset, Color(1,1,1,1-approach*0.5))
		"flare":
			if active:
				var front := maxf(2.0, radius * clampf(1.0 - float(hazard.ttl) / 3.0, 0.0, 1.0))
				draw_arc(pos, front, 0, TAU, 96, Color(color, 0.18), 44, true)
				draw_arc(pos, front, 0, TAU, 96, INK, 3, true)

func _draw_event_notice(model: RunModel) -> void:
	for hazard: Dictionary in model.hazards:
		if not RunModel.ENCOUNTERS.has(hazard.kind):
			continue
		var info: Dictionary = RunModel.ENCOUNTERS[hazard.kind]
		var status := "%d초 후 발생" % ceili(float(hazard.warn)) if not bool(hazard.active) else "진행 중 · %d초 남음" % ceili(float(hazard.ttl))
		if hazard.kind == "planet" and bool(hazard.active):
			status += " · 방어 %.1f / 12초" % float(hazard.get("hold", 0.0))
		if screen == "replay":
			draw_string(font, Vector2(438, 190), "%s · %s" % [info.name, status], HORIZONTAL_ALIGNMENT_CENTER, 404, 14, GOLD)
		var at: Vector2 = Vector2(hazard.pos) - camera_offset
		var bounds := _viewport_rect().grow(-48)
		if not bounds.has_point(at):
			var direction := (at - bounds.get_center()).normalized()
			var edge := bounds.get_center() + direction * minf(bounds.size.x * 0.5 / maxf(0.001, absf(direction.x)), bounds.size.y * 0.5 / maxf(0.001, absf(direction.y)))
			_polygon(edge, 12, 3, GOLD, direction.angle())
			var text_at := Vector2(clampf(edge.x - 65, bounds.position.x, bounds.end.x - 130), clampf(edge.y + 27, bounds.position.y + 18, bounds.end.y))
			draw_string(font, text_at, "%s %dm" % [info.name, model.player.distance_to(hazard.pos)], HORIZONTAL_ALIGNMENT_CENTER, 130, 15, INK)

func _draw_impact(effect: Dictionary, life: float) -> void:
	var kind := str(effect.kind)
	var pos: Vector2 = effect.pos
	var reduced: bool = records.data.reduced_motion
	var color := GOLD if kind in ["meteor_impact", "impact_meteor", "reward"] else (CYAN if kind == "impact_lane" else CORAL)
	if kind == "hit":
		ArtAssets.sprite(self, "fx/spark", pos, Vector2.ONE * (12 + 16 * life), 0, camera_offset, Color(1,1,1,life))
		return
	var radius := float(effect.radius) * (0.75 if reduced else 1.3 - life * 0.6)
	var art := "fx/explosion" if kind in ["death","meteor_impact","hazard_start","impact_blast","impact_meteor"] else "fx/wave"
	ArtAssets.sprite(self, art, pos, Vector2.ONE * maxf(18,radius * 2), 0, camera_offset, Color(1,1,1,life * (0.3 if reduced else 0.7)))
	if kind.begins_with("impact_"):
		var source: Vector2 = effect.get("end", pos)
		if source.distance_to(pos) > 1.0:
			var direction := (source - pos).normalized()
			draw_arc(pos, 25, direction.angle() - 0.7, direction.angle() + 0.7, 16, INK, 5, true)
		var label: String = {"impact_combat": "피격", "impact_lane": "감전", "impact_blast": "폭발", "impact_meteor": "유성 충돌", "impact_flare": "플레어", "impact_boundary": "외곽 손상"}.get(kind, "피격")
		draw_string(font, pos + Vector2(-70, -38 if reduced else -38 - (1.0 - life) * 18), label, HORIZONTAL_ALIGNMENT_CENTER, 140, 18, Color(color, life))

func _draw_meters() -> void:
	draw_line(Vector2(410, 22), Vector2(410, 164), LINE, 1)
	draw_line(Vector2(870, 22), Vector2(870, 164), LINE, 1)
	preload("res://scripts/ui_glyph.gd").ship(self, Vector2(58, 41), run.ship_id, GameContent.ship_info(run.ship_id).color, 0.6, -PI / 2)
	draw_rect(Rect2(54, 64, 330, 8), LINE)
	draw_rect(Rect2(54, 64, 330 * clampf(run.hp / run.max_hp, 0, 1), 8), LIME if run.hp > run.max_hp * 0.3 else CORAL)
	# Two halves share a zero marker, so direction is readable without color.
	draw_rect(Rect2(54, 110, 165, 4), Color(CORAL, 0.2))
	draw_rect(Rect2(219, 110, 165, 4), Color(LIME, 0.2))
	var net_width := absf(net_gauge) * 165.0
	draw_rect(Rect2(219 - net_width if net_gauge < 0.0 else 219.0, 110, net_width, 4), CORAL if net_gauge < 0.0 else LIME)
	draw_line(Vector2(219, 107), Vector2(219, 117), INK, 1)
	ItemCatalog.draw_icon(self, Vector2(62, 140), "speed", _speed_color(speed_gauge), 0.55)
	for i in range(55):
		var fraction := float(i + 1) / 55.0
		var speed_color := Color(_speed_color(speed_gauge), 0.55 + fraction * 0.45)
		draw_rect(Rect2(54 + i * 6, 157, 4, 4), speed_color if fraction <= speed_gauge else LINE)
	draw_rect(Rect2(438, 16, 404, 2), LINE)
	draw_rect(Rect2(438, 16, 404 * clampf(run.elapsed / 600.0, 0, 1), 2), GOLD if run.elapsed >= 300 else CYAN)
	for dot in 3:
		draw_circle(Vector2(810 + dot * 9, 66), 3, [GOLD, CORAL, Color("c69cff")][dot] if dot < run.boundary_layer(run.player) else LINE)
	_polygon(Vector2(897, 38), 8, 6, GOLD)
	draw_rect(Rect2(48, 714, 1184, 4), LINE)
	draw_rect(Rect2(48, 714, 1184 * clampf(run.xp / run.xp_needed, 0, 1), 4), CYAN)
	for enemy in run.enemies:
		if str(enemy.kind) == "boss":
			draw_rect(Rect2(438, 178, 404, 5), LINE)
			draw_rect(Rect2(438, 178, 404 * float(enemy.hp) / float(enemy.max_hp), 5), CORAL)

func _speed_color(ratio: float) -> Color:
	return CORAL.lerp(SPEED_BLUE, clampf(ratio, 0.0, 1.0))

func _draw_boundary_warning() -> void:
	var depth := run.boundary_depth(run.player)
	var pulse := 1.0 if records.data.reduced_motion else 0.75 + 0.25 * sin(space_time * 4.0)
	var strength := clampf(depth * 0.6 + run.boundary_time * 0.06, 0.15, 1.0)
	draw_rect(_viewport_rect(), Color(CORAL, 0.025 * strength))
	for i in range(6):
		draw_rect(_viewport_rect().grow(-i * 6), Color(CORAL, (0.24 - i * 0.035) * strength * pulse), false, 6)
	var inward := (ARENA.get_center() - run.player).normalized()
	var visible_player := run.player - camera_offset
	var tip := visible_player + inward * 43.0
	draw_line(visible_player + inward * 25.0, tip, CORAL, 3, true)
	draw_line(tip, tip - inward.rotated(0.55) * 11.0, CORAL, 3, true)
	draw_line(tip, tip - inward.rotated(-0.55) * 11.0, CORAL, 3, true)

func _draw_enemy(enemy: Dictionary, model: RunModel = null) -> void:
	var pos: Vector2 = enemy.pos
	var radius: float = enemy.radius
	var kind: String = enemy.kind
	var color := CORAL
	var sides := 4
	var angle: float = float(enemy.get("angle", 0))
	match kind:
		"runner":
			sides = 3
			color = Color("f19abf")
		"tank":
			sides = 6
			color = Color("a293f3")
		"shooter":
			sides = 4
			color = GOLD
		"elite":
			sides = 5
			color = GOLD
			draw_arc(pos, radius + 7, 0, TAU, 32, GOLD, 2, true)
		"boss":
			sides = 6
			color = CORAL if float(enemy.hp) > float(enemy.max_hp) * 0.5 else GOLD
			angle = (model.elapsed if model != null else run.elapsed) * 0.3
			draw_arc(pos, radius + 10, 0, TAU, 36, Color(CORAL, 0.4), 2, true)
	if bool(enemy.get("flanker", false)):
		draw_arc(pos, radius + 5, angle - 1.0, angle + 1.0, 12, Color(color, 0.65), 2, true)
	if float(enemy.get("warn", 0)) > 0:
		var aim: Vector2 = enemy.get("aim", Vector2.RIGHT)
		if kind != "boss":
			draw_line(pos, pos + aim * 360, Color(GOLD, 0.38), 1, true)
		draw_arc(pos, radius + 12, 0, TAU, 24, GOLD, 2, true)
	if float(enemy.get("flash", 0)) > 0:
		color = INK
	if float(enemy.get("stun_time", 0)) > 0:
		ItemCatalog.draw_icon(self, pos + Vector2(0, -radius - 18), "stun", CYAN, 0.7)
	if float(enemy.get("slow_time", 0)) > 0:
		draw_arc(pos, radius + 4, 0, TAU, 24, CYAN, 1.5, true)
	var art_id := kind
	if kind == "elite": art_id = "elite_assault" if int(enemy.get("elite_index", 1)) == 1 else "elite_artillery"
	ArtAssets.sprite(self, "enemies/" + art_id, pos, Vector2.ONE * radius * 2.3, angle, camera_offset, Color(1.8,1.8,1.8) if float(enemy.get("flash",0)) > 0 else Color.WHITE)
	if kind == "boss" and model != null:
		var phase_color := CORAL if float(enemy.hp) > float(enemy.max_hp) * 0.5 else GOLD
		var count := 3 if model.sector_id == "forge" else (5 if model.sector_id == "storm" else 6)
		for organ in count:
			var bearing := angle + TAU * organ / count
			var tip := pos + Vector2.from_angle(bearing) * radius * 0.9
			draw_line(tip, tip + Vector2.from_angle(bearing) * (12 if phase_color == GOLD else 5), phase_color, 3, true)
	if float(enemy.hp) < float(enemy.max_hp):
		draw_rect(Rect2(pos + Vector2(-radius, -radius - 9), Vector2(radius * 2, 3)), LINE)
		draw_rect(Rect2(pos + Vector2(-radius, -radius - 9), Vector2(radius * 2 * maxf(0, float(enemy.hp) / float(enemy.max_hp)), 3)), color)

func _diamond(pos: Vector2, radius: float, color: Color, angle: float = 0) -> void:
	_polygon(pos, radius, 4, color, angle)

func _polygon(pos: Vector2, radius: float, sides: int, color: Color, angle: float = 0) -> void:
	var points := PackedVector2Array()
	for i in range(sides):
		points.append(pos + Vector2.from_angle(angle + TAU * i / sides) * radius)
	draw_colored_polygon(points, color)

func _camera_target(point: Vector2) -> Vector2:
	var relative := point - ARENA.get_center()
	return Vector2(relative.x - clampf(relative.x, -240.0, 240.0), relative.y - clampf(relative.y, -100.0, 100.0))

func _show_replay(entry: Dictionary) -> void:
	replay_frames = records.load_ghost(entry)
	if replay_frames.is_empty():
		record_notice = "고스트 파일이 없거나 손상되었습니다. 순위 기록은 보존됩니다."
		_show_records()
		return
	replay_entry = entry
	replay_run.reset(1, str(entry.mode), str(entry.ship), str(entry.sector))
	replay_time = 0.0
	replay_speed = 1.0
	replay_paused = false
	camera_offset = Vector2.ZERO
	screen = "replay"
	_clear_ui()
	_label("GHOST / " + str(entry.name), Rect2(48, 25, 680, 40), 26, CYAN)
	_label("%s점 · %s · %s" % [_number(entry.score), GameContent.mode_info(entry.mode).name, "전장 전체 기록 · 적 / 탄환 / 보급 / 경험치" if replay_frames[0].size() == 14 else "이전 기록 · 비행 경로 전용"], Rect2(48, 75, 1060, 28), 17, MUTED)
	hud.replay = _label("", Rect2(48, 623, 400, 30), 16)
	replay_slider = HSlider.new()
	replay_slider.position = Vector2(460, 627)
	replay_slider.size = Vector2(440, 24)
	replay_slider.min_value = 0.0
	replay_slider.max_value = maxf(0.01, float(replay_frames.back()[0]))
	replay_slider.step = 0.01
	replay_slider.value_changed.connect(func(value: float) -> void: replay_time = value)
	ui.add_child(replay_slider)
	_button("재생 / 정지", Rect2(48, 655, 205, 48), _toggle_replay)
	_button("배속 변경", Rect2(271, 655, 185, 48), func() -> void: replay_speed = 1.0 if replay_speed == 4.0 else replay_speed * 2.0)
	_button("처음부터", Rect2(474, 655, 180, 48), func() -> void: replay_time = 0.0; replay_paused = false)
	_button("랭킹으로", Rect2(965, 655, 235, 48), _show_records, true, true)

func _draw_replay() -> void:
	var frame := GhostReplay.sample(replay_frames, replay_time)
	if frame.size() == 14:
		GhostReplay.restore(replay_run, frame)
		_draw_arena(replay_run)
		draw_set_transform(-camera_offset)
		_draw_replay_path()
		draw_set_transform(Vector2.ZERO)
		_draw_item_status(replay_run, 126.0)
		_draw_expedition(replay_run)
		draw_rect(Rect2(_viewport_rect().position, Vector2(_viewport_rect().size.x, 112 - _viewport_rect().position.y)), Color(BG, 0.88))
		draw_rect(Rect2(_viewport_rect().position.x, 615, _viewport_rect().size.x, _viewport_rect().end.y - 615), Color(BG, 0.88))
		_draw_reward_feedback(replay_run)
		draw_string(font, Vector2(48, 603), "선체 %.0f / %.0f · 점수 %s · 적 %d · 탄환 %d · 경험치 %d · 아이템 %d" % [replay_run.hp, replay_run.max_hp, _number(int(frame[5])), replay_run.enemies.size(), replay_run.shots.size(), replay_run.gems.size(), replay_run.items.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, CYAN)
		return
	var point := Vector2(frame[1], frame[2])
	draw_set_transform(-camera_offset)
	_draw_orbital_regions(CYAN)
	_draw_replay_path()
	ArtAssets.sprite(self, "ships/" + str(replay_entry.ship), point, Vector2.ONE * 40, float(frame[3]), camera_offset)
	for i: int in range(int(frame[6])):
		var angle := float(frame[8]) + TAU * i / float(frame[6])
		var frost := int(frame[12]) > 0 and i % 3 == 0
		ArtAssets.sprite(self, "objects/" + ("frost" if frost else ("blade" if int(frame[11]) > 0 else "normal")), point + Vector2.from_angle(angle) * float(frame[7]), Vector2.ONE * 23, angle, camera_offset)
	if int(frame[9]) > 0:
		draw_line(point - Vector2.from_angle(float(frame[3])) * 60, point, CYAN, 5, true)
	if int(frame[10]) > 0:
		draw_arc(point, 30, 0, TAU, 32, GOLD, 3, true)
	draw_set_transform(Vector2.ZERO)
	draw_string(font, Vector2(48, 537), "선체 %.0f · 기록 점수 %s" % [frame[4], _number(int(frame[5]))], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, CYAN)

func _toggle_replay() -> void:
	replay_paused = not replay_paused
	if replay_time >= float(replay_frames.back()[0]):
		replay_time = 0.0
		replay_paused = false

func _show_item_codex() -> void:
	_label("SUPPLY / FIELD GUIDE", Rect2(64, 35, 800, 30), 16, CYAN)
	_label("아이템 도감 · %d / %d 발견" % [records.data.discovered_items.size(), ItemCatalog.IDS.size()], Rect2(64, 82, 1100, 50), 34)
	_wrap_label("접촉 즉시 발동 · 외곽일수록 고등급 · 아래 수리는 기본값: 5분부터 효율 감소, 8분 이후 30%", Rect2(64, 142, 1152, 40), 16)
	for i: int in range(item_page * 8, mini((item_page + 1) * 8, ItemCatalog.IDS.size())):
		var id: String = ItemCatalog.IDS[i]
		var known: bool = id in records.data.discovered_items
		var at := Vector2(64 + (i % 4) * 292, 200 + floori(float(i % 8) / 4.0) * 204)
		var card := _button("", Rect2(at, Vector2(276, 188)), func() -> void: _show_item_detail(id))
		var icon := preload("res://scripts/item_icon.gd").new()
		icon.item_id = id
		icon.known = known
		icon.position = at + Vector2(12, 12)
		icon.size = Vector2(46, 46)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
		icon.position -= at
		_label(str(ItemCatalog.info(id).name) if known else "???", Rect2(at + Vector2(70, 20), Vector2(192, 32)), 20, INK if known else MUTED)
		if known:
			for rank: int in range(3):
				var grade: String = ItemCatalog.GRADES[rank]
				_wrap_label(grade + " · " + str(ItemCatalog.info(id, grade).description), Rect2(at + Vector2(14, 62 + rank * 40), Vector2(248, 40)), 14, ItemCatalog.grade_color(grade))
		else:
			_wrap_label("?\n획득하면 아이콘과 효과가 공개됩니다.", Rect2(at + Vector2(18, 76), Vector2(240, 90)), 17)
	_wrap_label("같은 버프는 중첩되지 않습니다. 동급/상위는 갱신, 하위는 기존 효과 유지. 속사·광전은 강한 쪽만 적용.", Rect2(64, 610, 1152, 30), 14)
	_button("전투로 돌아가기" if codex_return == "pause" else "돌아가기", Rect2(64, 650, 310, 48), _close_arsenal, true, true)
	_button("보급 %d/2 · 다음 →" % (item_page + 1), Rect2(912, 650, 304, 48), func() -> void: item_page = (item_page + 1) % 2; _open_arsenal(codex_return))

func _show_item_detail(id: String) -> void:
	item_detail = id
	_clear_ui()
	if codex_return == "pause":
		_shade()
	var known: bool = id in records.data.discovered_items
	_label("SUPPLY / " + (ItemCatalog.info(id).name if known else "미발견 보급"), Rect2(110, 80, 1060, 58), 36, CYAN)
	if known:
		for i in 3:
			var grade: String = ItemCatalog.GRADES[i]
			var y := 180 + i * 123
			_panel(Rect2(110, y, 1060, 105), PANEL, ItemCatalog.grade_color(grade))
			_label(grade + " 등급", Rect2(136, y + 25, 150, 40), 26, ItemCatalog.grade_color(grade))
			_wrap_label(ItemCatalog.info(id, grade).description, Rect2(310, y + 20, 825, 74), 23, INK)
	else:
		_wrap_label("???\n획득하면 아이콘과 등급별 효과가 공개됩니다.", Rect2(110, 235, 1060, 120), 28)
	_button("아이템 도감으로", Rect2(110, 600, 330, 64), func() -> void: codex_tab = "items"; _open_arsenal(codex_return), true, true)

func _draw_item_status(world: RunModel = null, y: float = 586.0) -> void:
	var model := run if world == null else world
	var index := 0
	for id: String in ItemCatalog.IDS:
		if not model.buffs.has(id):
			continue
		var buff: Dictionary = model.buffs[id]
		var color := ItemCatalog.grade_color(str(buff.grade))
		var at := Vector2(52 + (index % 6) * 194, y - floori(index / 6.0) * 42)
		draw_style_box(_style(PANEL, color), Rect2(at, Vector2(186, 38)))
		ItemCatalog.draw_icon(self, at + Vector2(19, 19), id, color, 0.7)
		draw_string(font, at + Vector2(38, 24), ("실드 %.0f · %.1f초" % [buff.value, buff.ttl]) if id == "shield" else "%s %s %.1f초" % [buff.grade, ItemCatalog.info(id).name, buff.ttl], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
		index += 1
	if screen == "replay":
		return
	var nearest: Dictionary = {}
	var distance := INF
	for item: Dictionary in model.items:
		var candidate := model.player.distance_to(item.pos)
		if candidate < distance:
			nearest = item
			distance = candidate
	if not nearest.is_empty():
		var item_point: Vector2 = nearest.pos
		var at := Vector2(640, 508 if model.buffs.size() > 6 else 550)
		var direction := (item_point - model.player).normalized()
		var color := ItemCatalog.grade_color(str(nearest.grade))
		_draw_direction_marker(at, direction, color, "item", str(nearest.id))
		draw_string(font, at + Vector2(38, 6), "%s등급 보급 %dpx · %d초 · %s" % [nearest.grade, roundi(distance), ceili(float(nearest.ttl)), "위험 경계" if model.boundary_layer(item_point) > 0 else "안전 구역"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
		var bounds := _viewport_rect().grow(-48)
		var point: Vector2 = item_point - camera_offset
		if not bounds.has_point(point):
			var ray := (point - bounds.get_center()).normalized()
			var edge := bounds.get_center() + ray * minf(bounds.size.x * 0.5 / maxf(0.001, absf(ray.x)), bounds.size.y * 0.5 / maxf(0.001, absf(ray.y)))
			_draw_direction_marker(edge, ray, color, "item", str(nearest.id))

func _draw_part_icon(at: Vector2, id: String, _color: Color, scale: float = 1.0, world: bool = false) -> void:
	ArtAssets.sprite(self, "objects/" + id, at, Vector2.ONE * 34 * scale, 0, camera_offset if world else Vector2.ZERO)

func _draw_expedition(model: RunModel) -> void:
	var m := model.mission
	var color := CYAN
	var heading := "선택 미션"
	var status := "00:50 공개"
	var countdown := "%ds" % maxi(0, ceili(50.0 - model.elapsed))
	var progress := 0.0
	var grade := "?"
	if not m.is_empty():
		color = ItemCatalog.grade_color(str(m.grade))
		grade = str(m.grade)
		heading = str(m.name)
		countdown = "%ds" % maxi(0, ceili(float(m.start) + 50.0 - model.elapsed))
		match m.status:
			"preview":
				status = "예고 · %ds 후 시작" % maxi(0, ceili(float(m.start) - model.elapsed))
				countdown = "대기"
			"active":
				status = mission_progress_text(model)
				progress = clampf((model.elapsed - float(m.start)) / 50.0 if m.id == "survive" else float(m.progress) / float(m.target), 0, 1)
			"success":
				status = "✓ 완료"
				countdown = ""
				color = LIME
				progress = 1.0
			"failed":
				status = "× 종료"
				countdown = ""
				color = CORAL
	draw_line(Vector2(438, 102), Vector2(842, 102), LINE, 1)
	draw_style_box(_style(Color(color, 0.12), color), Rect2(438, 109, 24, 24))
	draw_string(font, Vector2(438, 127), grade, HORIZONTAL_ALIGNMENT_CENTER, 24, 15, color)
	if not m.is_empty():
		var mission_id: String = str(m.id)
		if mission_id in ["chaser","runner","tank","shooter"]:
			draw_texture_rect(ArtAssets.texture("enemies/" + mission_id), Rect2(469,109,24,24), false)
		else:
			ArtAssets.icon(self, Vector2(481,121), mission_id, color, 0.65)
	draw_string(font, Vector2(500, 127), heading, HORIZONTAL_ALIGNMENT_LEFT, 242, 16, color)
	draw_string(font, Vector2(752, 127), countdown, HORIZONTAL_ALIGNMENT_RIGHT, 90, 14, MUTED)
	draw_string(font, Vector2(438, 151), status, HORIZONTAL_ALIGNMENT_LEFT, 288, 13, INK)
	if not m.is_empty():
		for i in int(m.upgrades):
			_diamond(Vector2(758 + i * 15, 146), 5, color, 0)
		if int(m.parts) > 0:
			_draw_part_icon(Vector2(824, 146), "shell", GOLD, 0.45)
	draw_rect(Rect2(438, 162, 404, 4), LINE)
	draw_rect(Rect2(438, 162, 404 * progress, 4), color)
	for i in 3:
		var id: String = Expedition.PART_IDS[i]
		var at := Vector2(62 + i * 130, 665)
		_draw_part_icon(at, id, Expedition.part(id).color, 0.65)
		draw_string(font, at + Vector2(17, 5), "%s %d/6" % [{"core": "화력", "drive": "추진", "shell": "장갑"}[id], int(model.parts.get(id, 0))], HORIZONTAL_ALIGNMENT_LEFT, 108, 13, INK)
	var form := "기체 조합 미완성 · TAB 테크트리"
	if not model.hull_forms.is_empty():
		var id: String = "trinity" if model.hull_rank("trinity") > 0 else str(model.hull_forms.back())
		form = "%s %s · TAB 조합법" % [Expedition.recipe(id).name, "II" if model.hull_rank(id) == 2 else "I"]
	draw_string(font, Vector2(470, 670), form, HORIZONTAL_ALIGNMENT_LEFT, 570, 13, LIME)
	var nearest: Dictionary = {}
	var distance := INF
	for drop: Dictionary in model.part_drops:
		var candidate := model.player.distance_to(drop.pos)
		if candidate < distance:
			nearest = drop
			distance = candidate
	if not nearest.is_empty():
		var info := Expedition.part(str(nearest.id))
		var at := Vector2(644, 552)
		var direction: Vector2 = (Vector2(nearest.pos) - model.player).normalized()
		_draw_direction_marker(at, direction, info.color, "part", str(nearest.id))
		draw_string(font, at + Vector2(23, 5), "%s %dpx · %d초 · %s" % [info.name, roundi(distance), ceili(float(nearest.ttl)), "2층 직접 탐사" if bool(nearest.locked) else "회수 가능"], HORIZONTAL_ALIGNMENT_LEFT, 550, 14, info.color)
		var point: Vector2 = Vector2(nearest.pos) - camera_offset
		var bounds := _viewport_rect().grow(-46)
		if not bounds.has_point(point):
			var ray := (point - bounds.get_center()).normalized()
			var edge := bounds.get_center() + ray * minf(bounds.size.x * 0.5 / maxf(0.001, absf(ray.x)), bounds.size.y * 0.5 / maxf(0.001, absf(ray.y)))
			_draw_direction_marker(edge, ray, info.color, "part", str(nearest.id))

func mission_progress_text(model: RunModel) -> String:
	var m := model.mission
	var count := "%.1f" % float(m.progress) if m.id == "outer" else "%d" % int(m.progress)
	return "%s / %d%s" % [count, int(m.target), "회 미만 · 생존" if m.id == "survive" else ("초 · 복귀" if m.id == "outer" else "")]

func _show_tech_codex() -> void:
	if tech_page == 1:
		_show_ship_parts()
		return
	_button("전용 파츠 →", Rect2(912, 650, 304, 48), func() -> void: tech_page = 1; _open_arsenal(codex_return))
	_label("HULL / TECH TREE", Rect2(64, 35, 600, 30), 16, CYAN)
	_label("3종 파츠로 기체를 진화시키세요.", Rect2(64, 82, 1150, 50), 34)
	_wrap_label("파츠: A급 미션 1개 / 90초부터 105초 간격 외곽 2층 깊은 탐사 · C/B급·강적은 파츠 없음", Rect2(64, 141, 1152, 38), 16)
	for i in 3:
		var id: String = Expedition.PART_IDS[i]
		var info := Expedition.part(id)
		var x := 64 + i * 386
		_panel(Rect2(x, 190, 368, 94), PANEL, info.color)
		_glyph("upgrade", id, Rect2(x + 16, 199, 28, 28), info.color)
		_label(info.name + (" · 발견" if id in records.data.discovered_parts else " · 미발견"), Rect2(x + 52, 198, 296, 30), 20, info.color)
		_wrap_label(info.effect + " · 최대6개", Rect2(x + 18, 235, 330, 40), 15)
	for i in 4:
		var id: String = Expedition.RECIPE_IDS[i]
		var info := Expedition.recipe(id)
		var x := 64 + i % 2 * 584
		var y := 304 + floori(i / 2.0) * 145
		var rank: int = run.hull_rank(id) if codex_return == "pause" else 0
		_panel(Rect2(x, y, 568, 132), PANEL, LIME if rank > 0 else LINE)
		_glyph("upgrade", id, Rect2(x + 16,y + 7,28,28), LIME if rank > 0 else CYAN)
		_label(info.name + (" · %s 가동" % ("II" if rank == 2 else "I") if rank > 0 else (" · 연구 완료" if id in records.data.discovered_hulls else " · 미진화")), Rect2(x + 52, y + 7, 494, 30), 21, LIME if rank > 0 else CYAN)
		var names: Array[String] = []
		for part_id: String in info.needs:
			names.append(str(Expedition.part(part_id).name).replace(" 파츠", ""))
		_label(" + ".join(names) + " 각1개 → I / 각2개 → II", Rect2(x + 16, y + 43, 530, 28), 16)
		_wrap_label(info.effect, Rect2(x + 16, y + 78, 530, 48), 15)
	_wrap_label("파츠를 소비하지 않고 조합을 동시에 적용합니다. 3종 조합은 세 전투 방식을 통합합니다. 발견·진화 업적은 영구 저장됩니다.", Rect2(64, 600, 1152, 36), 14)
	_button("전투로 돌아가기" if codex_return == "pause" else "돌아가기", Rect2(64, 650, 310, 48), _close_arsenal, true, true)

func _show_ship_parts() -> void:
	_label("SHIP / EXCLUSIVE PARTS", Rect2(64, 35, 600, 30), 16, CYAN)
	_label("기체 전용 파츠 강화", Rect2(64, 82, 1100, 50), 34)
	_wrap_label("파츠를 소모하지 않습니다. 해당 기체만 강화 선택에 등장 · 파츠 1/2/3개로 Lv.1/2/3 해금 · 두 번째 강화는 첫 강화 Lv.1 필요", Rect2(64, 140, 1152, 42), 16)
	for i in 6:
		var id: String = RunModel.SHIP_PARTS.keys()[i]
		var spec: Array = RunModel.SHIP_PARTS[id]
		var info := RunModel.upgrade_info(id)
		var at := Vector2(64 + (i % 2) * 584, 198 + floori(i / 2.0) * 132)
		_panel(Rect2(at, Vector2(568, 120)), PANEL, GameContent.ship_info(spec[0]).color)
		_glyph("upgrade", id, Rect2(at + Vector2(16,10), Vector2(28,28)), GameContent.ship_info(spec[0]).color)
		_label(GameContent.ship_info(spec[0]).name + " · " + info.name.replace("전용 · ", ""), Rect2(at + Vector2(52, 10), Vector2(494, 30)), 22)
		_wrap_label(info.description, Rect2(at + Vector2(16, 46), Vector2(530, 62)), 17)
	_button("전투로 돌아가기" if codex_return == "pause" else "돌아가기", Rect2(64, 650, 310, 48), _close_arsenal, true, true)
	_button("공통 조합 ←", Rect2(912, 650, 304, 48), func() -> void: tech_page = 0; _open_arsenal(codex_return))

func _draw_replay_path() -> void:
	var path := PackedVector2Array()
	for sample: Array in replay_frames:
		if float(sample[0]) > replay_time:
			break
		if float(sample[0]) >= replay_time - 12.0:
			path.append(Vector2(sample[1], sample[2]))
	if path.size() > 1:
		draw_polyline(path, Color(CYAN, 0.4), 2.0, true)
