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
var stars: Array[Vector2] = []
var mouse_active := false
var mouse_target := Vector2.ZERO
var space_time := 0.0
var space_offset := Vector2.ZERO
var space_velocity := Vector2.ZERO
var mouse_outside := false
var net_gauge := 0.0
var speed_gauge := 0.0
var camera_offset := Vector2.ZERO
var ghost := GhostReplay.new()
var replay_frames: Array = []
var replay_entry: Dictionary = {}
var replay_time := 0.0
var replay_speed := 1.0
var replay_paused := false
var replay_slider: HSlider
var achievement_page := 0
var ranking_mode := "normal"
var record_notice := ""

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
	_show_menu()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_target = get_global_transform_with_canvas().affine_inverse() * event.position
		mouse_active = screen == "playing"

func _unhandled_input(event: InputEvent) -> void:
	if screen != "playing" or not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		dash_queued = true
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		run.activate_overdrive()
	else:
		return
	get_viewport().set_input_as_handled()

func _movement_direction() -> Vector2:
	var keys := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if not keys.is_zero_approx():
		return keys
	if mouse_active and mouse_outside and DisplayServer.get_name() != "headless" and not OS.has_feature("web"):
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
	if screen == "replay":
		if not replay_paused:
			replay_time = minf(float(replay_frames.back()[0]), replay_time + delta * replay_speed)
			replay_slider.set_value_no_signal(replay_time)
			if replay_time >= float(replay_frames.back()[0]):
				replay_paused = true
		camera_offset = _camera_target(Vector2(GhostReplay.sample(replay_frames, replay_time)[1], GhostReplay.sample(replay_frames, replay_time)[2]))
		hud.replay.text = "%s / %s    %.0f배속    %s" % [_time(replay_time), _time(float(replay_frames.back()[0])), replay_speed, "일시정지" if replay_paused else "재생 중"]
	toast_time = maxf(0.0, toast_time - delta)
	hurt_flash = maxf(0.0, hurt_flash - delta * 2.0)
	if screen == "playing":
		var direction := _movement_direction()
		var previous_position := run.player
		run.step(delta, direction, dash_queued)
		ghost.capture(run)
		camera_offset = camera_offset.lerp(_camera_target(run.player), 1.0 - exp(-7.0 * delta))
		if not records.data.reduced_motion:
			space_time += delta
			var drift := -(run.player - previous_position) / maxf(delta, 0.001)
			space_velocity = space_velocity.lerp(drift.limit_length(360.0) * 0.12, 1.0 - exp(-7.0 * delta))
			space_offset += space_velocity * delta
		var net := run.net_hull_rate()
		net_gauge = lerpf(net_gauge, net / maxf(1.0, run.regeneration_rate() + run.decay_rate() + run.boundary_damage_rate()), 1.0 - exp(-10.0 * delta))
		speed_gauge = lerpf(speed_gauge, clampf(run.current_speed / run.base_speed(), 0.0, 1.0), 1.0 - exp(-10.0 * delta))
		dash_queued = false
		for cue in run.events:
			var audio_cue: String = {"shot": "shoot", "kill": "hit", "heal": "pickup", "upgrade": "select", "boss_down": "win", "elite": "boss", "overdrive": "level", "evolution": "win", "milestone": "win"}.get(cue, cue)
			sound.play(audio_cue)
			if cue == "hurt":
				hurt_flash = 0.35
			if cue == "boss":
				toast = "경고 · 코어 브레이커 접근"
				toast_time = 4.0
			if cue == "boss_down":
				toast = "보스 격파! 회복을 강화하고 생존 기록에 도전하세요."
				toast_time = 4.0
			if cue == "milestone":
				toast = "5분 돌파! 붕괴가 가속됩니다 · 최대 10분까지 한계 생존"
				toast_time = 5.0
			if cue == "elite":
				toast = "정예 편대 접근 · 처치하고 보급품을 회수하세요!"
				toast_time = 4.0
			if cue == "overdrive":
				toast = "오버드라이브 가동 · 6초간 화력 증폭!"
				toast_time = 2.0
			if cue == "evolution":
				toast = "무기 진화 완료 · " + str(GameContent.evolution_info(run.evolutions.back()).name)
				toast_time = 4.0
		run.events.clear()
		_update_hud()
		if run.state == "upgrade":
			_show_upgrades()
		elif run.state in ["won", "lost"]:
			_show_result()
	queue_redraw()

func _clear_ui() -> void:
	hud.clear()
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()

func _label(text: String, rect: Rect2, size: int = 20, color: Color = INK, parent: Control = null, wrap: bool = false) -> Label:
	var label := Label.new()
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", size)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else ui).add_child(label)
	label.position = rect.position
	label.size = rect.size
	return label

func _style(fill: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(12)
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
	_label("VERSION 3.3  /  MADE WITH GODOT", Rect2(922, 650, 350, 24), 13, MUTED)

func _wrap_label(text: String, rect: Rect2, size: int = 18, color: Color = MUTED, parent: Control = null) -> Label:
	return _label(text, rect, size, color, parent, true)

func _show_hangar() -> void:
	screen = "hangar"
	_clear_ui()
	_label("LAUNCH BAY / LOADOUT", Rect2(64, 32, 740, 28), 16, LIME)
	_label("이번 출격은, 어떤 조합?", Rect2(60, 73, 1000, 56), 39)
	_label("01  기체 선택", Rect2(64, 150, 400, 28), 18, CYAN)
	for i in range(GameContent.SHIP_IDS.size()):
		var id: String = GameContent.SHIP_IDS[i]
		var info: Dictionary = GameContent.ship_info(id)
		var card := _button("", Rect2(64 + 386 * i, 191, 366, 145), func() -> void: selected_ship = id; _show_hangar(), false, id == selected_ship)
		card.add_theme_stylebox_override("normal", _style(PANEL, info.color if id == selected_ship else LINE, 2 if id == selected_ship else 1))
		_label(("● " if id == selected_ship else "○ ") + str(info.name), Rect2(22, 14, 325, 36), 24, info.color, card)
		_wrap_label(info.description, Rect2(22, 56, 320, 52), 15, MUTED, card)
		_label("선체 %d   속도 %d   위성 %d" % [info.hp, info.speed, info.orbits], Rect2(22, 111, 330, 22), 15, INK, card)
	_label("02  전장 선택", Rect2(64, 358, 400, 28), 18, CYAN)
	for i in range(GameContent.SECTOR_IDS.size()):
		var id: String = GameContent.SECTOR_IDS[i]
		var info: Dictionary = GameContent.sector_info(id)
		var card := _button("", Rect2(64 + 386 * i, 399, 366, 139), func() -> void: selected_sector = id; _show_hangar())
		card.add_theme_stylebox_override("normal", _style(PANEL, info.color if id == selected_sector else LINE, 2 if id == selected_sector else 1))
		_label(("● " if id == selected_sector else "○ ") + str(info.name), Rect2(22, 14, 325, 36), 23, info.color, card)
		_wrap_label(info.description, Rect2(22, 58, 320, 65), 16, MUTED, card)
	_label("파일럿 이름", Rect2(695, 82, 130, 30), 17, CYAN)
	var name_input := LineEdit.new()
	name_input.position = Vector2(831, 77)
	name_input.size = Vector2(369, 44)
	name_input.max_length = 16
	name_input.text = records.data.player_name
	name_input.placeholder_text = "최대 16자 · 같은 이름은 같은 파일럿"
	name_input.text_changed.connect(func(value: String) -> void: records.data.player_name = SaveStore.clean_name(value))
	ui.add_child(name_input)
	var record_key := selected_ship + "|" + selected_sector + "|" + mode
	_label("이 조합 최고 %s  ·  표준 돌파 → 베테랑 ×1.5  ·  베테랑 돌파 → 대붕괴 ×2.0" % _number(int(records.data.best_by_loadout.get(record_key, 0))), Rect2(67, 559, 1120, 30), 17, MUTED)
	_button("돌아가기", Rect2(64, 624, 178, 56), _show_menu)
	_button("난이도  ·  " + str(GameContent.mode_info(mode).name) + " ×" + str(GameContent.mode_info(mode).score), Rect2(264, 624, 280, 56), _toggle_mode)
	_button("출격하기   →", Rect2(870, 613, 330, 67), _start_run, true)

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
			_panel(Rect2(x, y, 366, 139), PANEL, LIME if earned else LINE)
			_label("%s  ·  %d점" % ["달성 완료" if earned else "도전 중", item.points], Rect2(x + 18, y + 10, 326, 24), 15, LIME if earned else GOLD)
			_label(item.name, Rect2(x + 18, y + 39, 326, 33), 22)
			_label(item.description, Rect2(x + 18, y + 77, 330, 26), 16, MUTED)
			_label("%d / %d" % [mini(int(records.data.achievement_progress.get(item.stat, 0)), int(item.target)), item.target], Rect2(x + 18, y + 107, 326, 25), 16, CYAN)
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
	codex_return = return_to
	screen = "arsenal"
	dash_queued = false
	_clear_ui()
	if return_to == "pause":
		_shade()
	_label("ARSENAL / EVOLUTION GUIDE", Rect2(64, 35, 1120, 30), 16, CYAN)
	_label("강화를 연결하면, 무기가 진화합니다.", Rect2(61, 81, 1170, 57), 34)
	_label("필요한 강화 레벨을 모두 갖추면 자동 진화합니다. 도감을 보는 동안 전투는 멈춥니다.", Rect2(65, 148, 1150, 31), 17, MUTED)
	for i in range(GameContent.EVOLUTION_IDS.size()):
		var id: String = GameContent.EVOLUTION_IDS[i]
		var info: Dictionary = GameContent.evolution_info(id)
		var x := 64 + i * 386
		var acquired: bool = return_to == "pause" and run.evolutions.has(id)
		_panel(Rect2(x, 207, 366, 258), PANEL, LIME if acquired else LINE)
		_label("진화 완료" if acquired else "EVOLUTION / 0%d" % (i + 1), Rect2(x + 23, 224, 320, 27), 15, LIME if acquired else CYAN)
		_label(info.name, Rect2(x + 23, 261, 320, 40), 25)
		_wrap_label(info.description, Rect2(x + 23, 311, 319, 62), 17)
		var requirements := ""
		for upgrade_id in info.requirements:
			var current: int = int(run.upgrades.get(upgrade_id, 0)) if return_to == "pause" else 0
			requirements += "%s %s%d\n" % [RunModel.upgrade_info(upgrade_id).name, "%d / " % current if return_to == "pause" else "Lv.", int(info.requirements[upgrade_id])]
		_label(requirements, Rect2(x + 23, 385, 320, 69), 17, INK)
	var owned: Array[String] = []
	if return_to == "pause":
		for id in run.upgrades:
			owned.append("%s %d" % [RunModel.upgrade_info(id).get("name", id), run.upgrades[id]])
	_wrap_label("현재 장비  /  " + " · ".join(owned) if not owned.is_empty() else "위성 개조: 절삭형(피해 강화) · 빙결형(적 감속) · 확장 궤도(반경 +22)\n자가 수리: 초당 +1.25 재생 · 선체 보강: 최대 체력 +35 / 즉시 70 회복\n화력과 회복을 함께 성장시키세요. 매 레벨 회복 선택지 1개 이상을 보장합니다.", Rect2(66, 484, 1130, 113), 16)
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
	if not mode in records.available_modes():
		mode = "normal"
	run.reset(0, mode, selected_ship, selected_sector)
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
	toast = "%s · 마우스 방향으로 이동 · 회복을 강화해 붕괴에 대비하세요" % GameContent.sector_info(selected_sector).name
	toast_time = 6.0
	_resume()

func _resume() -> void:
	screen = "playing"
	camera_offset = _camera_target(run.player)
	mouse_active = false
	dash_queued = false
	_clear_ui()
	_label("ORBIT / BREAKER", Rect2(48, 20, 250, 30), 20, LIME)
	_label("%s / %s" % [GameContent.ship_info(run.ship_id).name, GameContent.sector_info(run.sector_id).name], Rect2(49, 48, 365, 21), 12, MUTED)
	hud.hp = _label("", Rect2(48, 57, 280, 26), 18)
	hud.trait = _label("", Rect2(49, 96, 700, 24), 14, GameContent.ship_info(run.ship_id).color)
	hud.speed = _label("", Rect2(336, 21, 164, 26), 16, SPEED_BLUE)
	hud.speed_detail = _label("", Rect2(336, 66, 170, 20), 11, MUTED)
	hud.time = _label("", Rect2(531, 22, 240, 46), 32)
	hud.time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.phase = _label("", Rect2(428, 68, 425, 22), 14, MUTED)
	hud.phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.score = _label("", Rect2(894, 28, 260, 30), 20)
	hud.score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.vitals = _label("", Rect2(866, 57, 288, 26), 17, LIME)
	hud.vitals.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.vital_detail = _label("", Rect2(834, 95, 320, 18), 11, MUTED)
	hud.vital_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var pause := _button("Ⅱ", Rect2(1170, 26, 60, 54), _show_pause)
	pause.focus_mode = Control.FOCUS_NONE
	hud.level = _label("", Rect2(48, 684, 270, 27), 14, CYAN)
	hud.dash = _label("", Rect2(320, 684, 350, 27), 14, LIME)
	hud.dash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.dash_charge = _label("", Rect2(380, 650, 285, 28), 17, LIME)
	hud.overdrive = _label("", Rect2(678, 684, 354, 27), 14, GOLD)
	hud.overdrive.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.overdrive_charge = _label("", Rect2(738, 650, 288, 28), 17, GOLD)
	_label("TAB 도감   ESC 정지", Rect2(1060, 684, 210, 27), 14, MUTED)
	net_gauge = run.net_hull_rate() / maxf(1.0, run.regeneration_rate() + run.decay_rate() + run.boundary_damage_rate())
	speed_gauge = clampf(run.current_speed / run.base_speed(), 0.0, 1.0)
	_update_hud()

func _update_hud() -> void:
	if hud.is_empty():
		return
	hud.hp.text = "선체  %d / %d" % [ceili(run.hp), int(run.max_hp)]
	match run.ship_id:
		"striker":
			hud.trait.text = "연속 포격  %d/5  ·  모든 화력 +%d%%  ·  피격 / 사격 중단 시 초기화" % [run.firing_heat, run.firing_heat * 8]
		"scout":
			hud.trait.text = "돌파 추진  ·  돌진 피해 ×1.75  ·  " + ("가속 +35%%  %.1f초" % maxf(0.0, run.slipstream_time - run.dash_time) if run.slipstream_time > 0.0 else "대시 후 1.4초 가속 +35%")
		"bastion":
			hud.trait.text = "반격 방벽  ·  " + ("준비 완료: 다음 피격 -60% + 근거리 반격" if run.guard_cooldown <= 0.0 else "재충전 %.1f초 / 8초" % run.guard_cooldown)
	hud.time.text = "%s / %s" % [_time(run.elapsed), "05:00" if run.elapsed < 300.0 else "10:00"]
	var net := run.net_hull_rate()
	hud.vitals.text = "%s  %+.2f HP/초" % ["선체 붕괴 ▼" if net < 0.0 else ("선체 회복 ▲" if net > 0.0 else "선체 균형 −"), net]
	hud.vitals.add_theme_color_override("font_color", CORAL if net < 0.0 else (LIME if net > 0.0 else MUTED))
	hud.vital_detail.text = "재생 +%.2f   붕괴 -%.2f" % [run.regeneration_rate(), run.decay_rate()]
	if run.boundary_damage_rate() > 0.0:
		hud.vital_detail.text += "   외곽 -%.2f" % run.boundary_damage_rate()
	hud.speed.text = "추진  %d%%" % roundi(run.current_speed / run.base_speed() * 100.0)
	hud.speed.add_theme_color_override("font_color", _speed_color(speed_gauge))
	hud.speed_detail.text = "%d px/s · %s" % [roundi(run.current_speed), "돌진" if run.dash_time > 0.0 else ("외곽 감속" if run.boundary_depth(run.player) > 0.0 else "현재 속도")]
	hud.score.text = "%s  /  %d 처치" % [_number(run.ranked_score()), run.kills]
	hud.level.text = "LV.%02d   /   %d EXP → %d" % [run.level, int(run.xp), int(run.xp_needed)]
	hud.dash.text = "좌클릭 / SPACE  ·  돌진"
	hud.dash_charge.text = "돌진  ✓ 준비 완료" if run.dash_cooldown <= 0.0 else "돌진  %d%% · %.1f초" % [floori(run.dash_charge() * 100), run.dash_cooldown]
	hud.overdrive_charge.text = "오버드라이브  ✓ 준비 완료" if run.overdrive_meter >= 100.0 else "오버드라이브  %d%%" % run.overdrive_meter
	hud.overdrive.text = "우클릭 / E  ·  적 처치로 충전"
	if run.overdrive_time > 0:
		hud.overdrive.text = "화력 증폭 중  %.1f초" % run.overdrive_time
		hud.overdrive_charge.text = "화력 증폭  ·  작동 중"
	if run.elapsed < 60:
		hud.phase.text = "01 / 접촉   ·   경험치를 모아 위성을 강화하세요"
	elif run.elapsed < 150:
		hud.phase.text = "02 / 포위   ·   SPACE로 적 사이를 돌파하세요"
	elif run.elapsed < 240:
		hud.phase.text = "03 / 과부하   ·   주황색 포격수를 먼저 처치하세요"
	elif run.elapsed < 300:
		hud.phase.text = "04 / 코어 브레이커   ·   보스를 격파하고 5분 생존"
	else:
		hud.phase.text = "05 / 붕괴 가속 · 회복하며 한계 생존 (10분 한계)"
	if run.event_remaining > 0:
		hud.phase.text = run.event_title

func _shade() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.018, 0.031, 0.055, 0.91)
	shade.size = Vector2(1280, 720)
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
	_wrap_label("원형 활동영역 밖: 1층 희박권 → 2층 붕괴권 → 3층 소멸권. 깊을수록 손상·감속이 강해집니다.\n오른쪽 원형 항법도로 궤도와 침공 방향을 확인하세요. 하단 게이지가 가득 차면 스킬 사용 가능!", Rect2(103, 567, 1080, 59), 16, GOLD)
	_button("돌아가기", Rect2(100, 640, 190, 50), _show_menu, false, true)

func _show_settings() -> void:
	screen = "settings"
	_clear_ui()
	_label("PREFERENCES", Rect2(270, 95, 700, 30), 16, LIME)
	_label("나에게 맞게", Rect2(270, 143, 760, 70), 44)
	_button("전체 소리  ·  " + ("꺼짐" if records.data.muted else "켜짐"), Rect2(270, 255, 740, 60), func() -> void: _toggle_mute(); _show_settings(), false, true)
	_button("배경 음악  ·  " + ("켜짐" if records.data.music else "꺼짐"), Rect2(270, 337, 740, 60), _toggle_music)
	_button("화면 효과 줄이기  ·  " + ("켜짐" if records.data.reduced_motion else "꺼짐"), Rect2(270, 419, 740, 60), _toggle_motion)
	_label("설정과 최고 기록은 이 PC에 자동 저장됩니다." + ("  저장 실패" if save_failed else ""), Rect2(270, 518, 900, 30), 18, MUTED)
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
	text.text = "Godot Engine · https://godotengine.org/license/\n\n" + Engine.get_license_text()
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

func _show_upgrades() -> void:
	screen = "upgrade"
	_clear_ui()
	_shade()
	choices = run.get_upgrade_choices()
	_label("LEVEL %02d / SYSTEM UPGRADE" % run.level, Rect2(100, 100, 900, 28), 17, CYAN)
	_label("다음 궤도를 선택하세요.", Rect2(100, 149, 1080, 64), 43)
	_label("선택하는 동안 시간은 멈춥니다.  ·  무기 진화 조건은 전투 중 TAB 도감에서 확인", Rect2(103, 221, 1100, 30), 17, MUTED)
	for i in range(choices.size()):
		var entry = choices[i]
		var id: String = str(entry.id) if entry is Dictionary else str(entry)
		var info: Dictionary = RunModel.upgrade_info(id)
		var x := 100 + i * 367
		_panel(Rect2(x, 297, 345, 270), PANEL, LINE)
		_label("0%d  /  Lv.%d → %d" % [i + 1, run.upgrades.get(id, 0), int(run.upgrades.get(id, 0)) + 1], Rect2(x + 26, 321, 290, 30), 15, LIME)
		_label(str(info.get("name", id)), Rect2(x + 26, 368, 292, 43), 25)
		_wrap_label(str(info.get("description", "")), Rect2(x + 26, 422, 289, 89), 18)
		for evolution_id in GameContent.EVOLUTION_IDS:
			var evolution: Dictionary = GameContent.evolution_info(evolution_id)
			if evolution.requirements.has(id):
				_label("진화 연계 · " + str(evolution.name), Rect2(x + 26, 524, 310, 28), 14, CYAN)
				break
		var selected := i
		_button("선택   [%d]" % (i + 1), Rect2(x, 586, 345, 60), func() -> void: _pick_upgrade(selected), i == 0, i == 0)

func _pick_upgrade(index: int) -> void:
	if screen != "upgrade" or index < 0 or index >= choices.size():
		return
	var entry = choices[index]
	var id: String = str(entry.id) if entry is Dictionary else str(entry)
	if run.choose_upgrade(id):
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
		details.ghost_frames = ghost.frames
		save_failed = not records.record_run(run.ranked_score(), run.elapsed, won, details)
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
	_label("정예 격파 %d  /  진화 %s" % [run.elites_killed, " · ".join(evolution_names) if not evolution_names.is_empty() else "없음 — 다음 출격에서 조합에 도전하세요"], Rect2(123, 470, 1080, 30), 17, CYAN)
	if save_failed:
		_label("기록을 저장하지 못했습니다. 저장 폴더 접근 권한을 확인하세요.", Rect2(123, 521, 1050, 30), 17, CORAL)
	else:
		var medals: Array[String] = []
		for item: Dictionary in Achievements.catalog():
			if item.id in records.new_achievements:
				medals.append("%s +%d" % [item.name, item.points])
		_wrap_label("업적 %d점 / " % Achievements.points(records.data.achievements) + " · ".join(medals.slice(0, 3)) + (" 외 %d개" % (medals.size() - 3) if medals.size() > 3 else "") if not medals.is_empty() else "기록 저장 완료  ·  다른 기체와 전장으로 새로운 최고 기록에 도전하세요.", Rect2(123, 516, 1060, 57), 18, GOLD)
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
	draw_rect(Rect2(0, 0, 1280, 720), BG)
	for i in range(stars.size()):
		draw_circle(stars[i], 1.0 if i % 4 else 1.6, Color(0.25, 0.37, 0.44, 0.42))
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
	if toast_time > 0 and screen == "playing" and run.boundary_depth(run.player) <= 0.0:
		var width := font.get_string_size(toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 48
		var pos := Vector2(640 - width / 2, 143)
		draw_style_box(_style(Color("182b39"), LINE), Rect2(pos, Vector2(width, 45)))
		draw_string(font, pos + Vector2(24, 29), toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK)

func _draw_motif(center: Vector2) -> void:
	var t := 0.0 if records.data.reduced_motion else clock_time * 0.3
	for radius in [95, 165, 238]:
		draw_arc(center, radius, 0, TAU, 100, LINE, 1.0, true)
	for i in range(4):
		var angle := t + i * TAU / 4
		var pos := center + Vector2.from_angle(angle) * 165
		draw_arc(center, 165, angle - 0.3, angle, 18, Color(CYAN, 0.4), 4, true)
		_diamond(pos, 11, CYAN, angle)
	_diamond(center, 39, Color(LIME, 0.06))
	_diamond(center, 26, LIME)
	_diamond(center, 13, BG)
	for i in range(6):
		var angle := -t * 0.4 + i * 1.05
		var pos := center + Vector2.from_angle(angle) * (238 + 12 * sin(t + i))
		_polygon(pos, 15, 3 if i % 2 else 4, CORAL if i % 2 else GOLD, angle + PI)
		_polygon(pos, 8, 3 if i % 2 else 4, BG, angle + PI)
	draw_string(font, center + Vector2(-106, 292), "SURVIVE. EVOLVE. BREAK.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, MUTED)

func _draw_arena() -> void:
	var sector_color: Color = GameContent.sector_info(run.sector_id).color
	draw_set_transform(-camera_offset)
	draw_rect(Rect2(camera_offset, Vector2(1280, 720)), Color("0c1925"))
	_draw_orbital_regions(sector_color)
	_draw_space(sector_color)
	var center := ARENA.get_center()
	draw_arc(center, RunModel.ACTIVITY_RADIUS / 3, 0, TAU, 96, Color("203344"), 1, true)
	draw_arc(center, RunModel.ACTIVITY_RADIUS * 2 / 3, 0, TAU, 128, Color("203344"), 1, true)
	for hazard in run.hazards:
		_draw_hazard(hazard)
	for gem in run.gems:
		var pos: Vector2 = gem.pos
		var is_heal: bool = str(gem.get("kind", "xp")) == "heal"
		_diamond(pos, 5 if not is_heal else 8, CYAN if not is_heal else LIME)
	for effect in run.effects:
		if records.data.reduced_motion:
			continue
		var life: float = clampf(float(effect.ttl) / maxf(0.01, float(effect.get("max_ttl", 0.5))), 0, 1)
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
		draw_arc(effect.pos, maxf(2, float(effect.get("radius", 20)) * (1.2 - life * 0.4)), 0, TAU, 22, Color(color, life * 0.65), 2, true)
	for shot in run.shots:
		var color := LIME if bool(shot.friendly) else GOLD
		if shot.get("kind", "") == "missile":
			color = Color("ffb777")
		var velocity: Vector2 = shot.get("velocity", Vector2.ZERO)
		draw_line(shot.pos - velocity.normalized() * 10, shot.pos, Color(color, 0.5), 2, true)
		draw_circle(shot.pos, float(shot.get("radius", 4)), color, true, -1, true)
	for enemy in run.enemies:
		_draw_enemy(enemy)
	var player: Vector2 = run.player
	var reduced: bool = records.data.reduced_motion
	var ship_color: Color = GameContent.ship_info(run.ship_id).color
	if run.overdrive_time > 0:
		draw_arc(player, 31, 0, TAU, 40, GOLD, 3, true)
		draw_arc(player, run.orbit_radius + 7, 0, TAU, 64, Color(GOLD, 0.35), 2, true)
	draw_arc(player, run.orbit_radius, 0, TAU, 60, Color(CYAN, 0.16), 1, true)
	for i in range(run.orbit_count):
		var angle: float = run.orbit_angle + TAU * i / run.orbit_count
		var pos := run.orbit_position(i)
		var kind := run.orbit_kind(i)
		var orbit_color: Color = CORAL if kind == "blade" else (CYAN if kind == "frost" else GOLD)
		if not reduced:
			draw_arc(player, run.orbit_radius, angle - 0.45, angle, 16, Color(orbit_color, 0.5), 3, true)
		_polygon(pos, 12 if run.evolutions.has("superorbit") else 9, 3 if kind == "blade" else (6 if kind == "frost" else 4), INK if run.dash_time > 0 else orbit_color, angle)
		if kind == "frost":
			draw_circle(pos, 3, BG)
	if run.dash_time > 0:
		draw_circle(player, 25, Color(LIME, 0.12), true, -1, true)
		if not reduced:
			draw_line(player - run.facing * 70, player, Color(LIME, 0.5), 13, true)
	_diamond(player + Vector2(0, 4), 16, Color(0, 0, 0, 0.5), run.facing.angle())
	var ship_sides := 3 if run.ship_id == "scout" else (6 if run.ship_id == "bastion" else 4)
	_polygon(player, 15, ship_sides, INK if hurt_flash > 0 else ship_color, run.facing.angle())
	_polygon(player, 6, ship_sides, BG, run.facing.angle())
	var wing := run.facing.orthogonal()
	match run.ship_id:
		"striker":
			for side: float in [-1.0, 1.0]:
				draw_line(player + wing * side * 8, player + wing * side * 8 + run.facing * 27, ship_color, 4, true)
			for i: int in range(5):
				draw_circle(player - run.facing * 22 + wing * (i - 2) * 7, 2.5, ship_color if i < run.firing_heat else LINE, true, -1, true)
		"scout":
			for side: float in [-1.0, 1.0]:
				var tip := player - run.facing * 12 + wing * side * 22
				draw_line(player + run.facing * 9, tip, ship_color, 2, true)
				if run.slipstream_time > 0.0:
					draw_line(tip, tip - run.facing * (24 if reduced else 48), Color(ship_color, 0.65), 3, true)
		"bastion":
			for side: float in [-1.0, 1.0]:
				_polygon(player + wing * side * 18, 8, 6, ship_color, run.facing.angle())
			draw_arc(player, 29, -PI / 2, -PI / 2 + TAU * maxf(0.01, 1.0 - run.guard_cooldown / 8.0), 40, ship_color, 3 if run.guard_cooldown <= 0.0 else 1, true)
	if run.dash_cooldown <= 0:
		draw_arc(player, 23, -0.5, 0.5, 12, LIME, 2, true)
	draw_set_transform(Vector2.ZERO)
	if screen == "playing":
		draw_rect(Rect2(0, 0, 1280, 124), Color(BG, 0.95))
		_draw_meters()
		_draw_navigation()
	if hurt_flash > 0 and not reduced:
		draw_rect(Rect2(0, 0, 1280, 720), Color(CORAL, hurt_flash * 0.17))

func _draw_orbital_regions(sector_color: Color) -> void:
	var center := RunModel.CENTER
	var radius := RunModel.ACTIVITY_RADIUS
	var colors := [sector_color, GOLD, CORAL, Color("bd81ff")]
	for layer: int in range(3, -1, -1):
		var edge := radius + layer * RunModel.LAYER_WIDTH
		draw_circle(center, edge, Color(colors[layer], 0.035), true, -1, true)
	for layer: int in range(4):
		var edge := radius + layer * RunModel.LAYER_WIDTH
		var color: Color = colors[layer]
		for band: int in range(6):
			draw_arc(center, edge - band * 4, 0, TAU, 256, Color(color, 0.10 - band * 0.014), 4, true)
		draw_arc(center, edge, 0, TAU, 256, Color(color, 0.65), 1.5, true)
		for mark: int in range(48):
			var normal := Vector2.from_angle(TAU * mark / 48.0)
			draw_line(center + normal * (edge - 8), center + normal * (edge + 8), Color(color, 0.35), 1, true)
		for quadrant: int in range(4):
			var at := center + Vector2.from_angle(quadrant * PI / 2) * (edge - 32)
			draw_string(font, at + Vector2(-62, -70), ["ORBIT / 활동영역", "01 / 희박권", "02 / 붕괴권", "03 / 소멸권"][layer], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)

func _draw_navigation() -> void:
	var at := Vector2(1171, 564)
	var scale := 63.0 / (RunModel.ACTIVITY_RADIUS + RunModel.BOUNDARY_BUFFER + 180)
	draw_circle(at, 78, Color(BG, 0.94), true, -1, true)
	for layer: int in range(4):
		draw_arc(at, (RunModel.ACTIVITY_RADIUS + layer * RunModel.LAYER_WIDTH) * scale, 0, TAU, 64, Color([CYAN, GOLD, CORAL, Color("bd81ff")][layer], 0.5), 1, true)
	draw_string(font, at + Vector2(-57, -86), "ORBITAL / 항법", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, MUTED)
	for enemy: Dictionary in run.enemies:
		var offset := (Vector2(enemy.pos) - RunModel.CENTER) * scale
		draw_circle(at + offset.limit_length(70), 3 if enemy.kind in ["boss", "elite"] else 1, CORAL if enemy.kind in ["boss", "elite"] else GOLD, true, -1, true)
		if enemy.kind in ["boss", "elite"] and Vector2(enemy.pos).distance_to(RunModel.CENTER) > RunModel.ACTIVITY_RADIUS:
			var direction := (Vector2(enemy.pos) - run.player).normalized()
			var marker := Vector2(640, 386) + direction * minf(505.0 / maxf(0.01, absf(direction.x)), 173.0 / maxf(0.01, absf(direction.y)))
			_polygon(marker, 9, 3, CORAL, direction.angle())
			draw_string(font, marker + Vector2(-68, 25), "%s 접근 · %dm" % ["지휘체" if enemy.kind == "boss" else "정예", roundi(run.player.distance_to(enemy.pos))], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, CORAL)
	draw_circle(at + ((run.player - RunModel.CENTER) * scale).limit_length(73), 3.5, INK, true, -1, true)
	draw_string(font, at + Vector2(-60, 90), ["활동영역 · 안정", "1층 · 희박권", "2층 · 붕괴권", "3층 · 소멸권"][run.boundary_layer(run.player)], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)

func _draw_skill_meter(at: Vector2, progress: float, color: Color, ready: bool) -> void:
	var sides := 3 if run.ship_id == "scout" else (6 if run.ship_id == "bastion" else 24)
	var glow := 1.0 if records.data.reduced_motion or not ready else 0.82 + 0.18 * sin(space_time * 4.0)
	if ready:
		draw_circle(at, 25, Color(color, 0.10 * glow), true, -1, true)
	for i: int in range(24):
		var t := float(i) * sides / 24.0
		var start := Vector2.from_angle(-PI / 2 + TAU * floorf(t) / sides) * 20
		var end := Vector2.from_angle(-PI / 2 + TAU * (floorf(t) + 1) / sides) * 20
		var a := start.lerp(end, fposmod(t, 1.0))
		var b := start.lerp(end, minf(1.0, fposmod(t, 1.0) + sides / 24.0 * 0.8))
		draw_line(at + a, at + b, Color(color, glow) if float(i) / 24.0 < progress else LINE, 3, true)
	if ready:
		draw_line(at + Vector2(-6, 0), at + Vector2(-1, 5), color, 2, true)
		draw_line(at + Vector2(-1, 5), at + Vector2(8, -6), color, 2, true)

func _draw_space(sector_color: Color) -> void:
	for i: int in range(stars.size()):
		var depth := 0.2 + float(i % 3) * 0.25
		var drift := Vector2.ZERO if records.data.reduced_motion else space_offset * depth + Vector2(-space_time * 3.0 * depth, 0)
		var point := stars[i] - camera_offset * depth + drift
		point = Vector2(fposmod(point.x, 1280), fposmod(point.y, 720)) + camera_offset
		draw_circle(point, 1.0 + float(i % 3) * 0.35, Color(sector_color, 0.2 + depth * 0.3))

func _draw_hazard(hazard: Dictionary) -> void:
	var active: bool = hazard.get("active", false)
	var color: Color = CORAL if active else GOLD
	if str(hazard.kind) == "lane":
		var rect: Rect2 = hazard.rect
		draw_rect(rect, Color(color, 0.28 if active else 0.09))
		draw_rect(rect, Color(color, 0.9), false, 2)
		var center := rect.get_center()
		draw_string(font, center + Vector2(-7, 7), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, color)
	else:
		var pos: Vector2 = hazard.pos
		var radius: float = hazard.radius
		draw_circle(pos, radius, Color(color, 0.28 if active else 0.08), true, -1, true)
		draw_arc(pos, radius, 0, TAU, 48, color, 2, true)
		draw_line(pos - Vector2(10, 0), pos + Vector2(10, 0), color, 2, true)
		draw_line(pos - Vector2(0, 10), pos + Vector2(0, 10), color, 2, true)

func _draw_meters() -> void:
	draw_rect(Rect2(48, 86, 260, 6), LINE)
	draw_rect(Rect2(48, 86, maxf(1, 260 * run.hp / run.max_hp), 6), LIME if run.hp > run.max_hp * 0.3 else CORAL)
	# Two halves share a zero marker, so direction is readable without color.
	draw_rect(Rect2(866, 86, 144, 6), Color(CORAL, 0.15))
	draw_rect(Rect2(1010, 86, 144, 6), Color(LIME, 0.15))
	var net_width := absf(net_gauge) * 144.0
	draw_rect(Rect2(1010 - net_width if net_gauge < 0.0 else 1010.0, 86, net_width, 6), CORAL if net_gauge < 0.0 else LIME)
	draw_line(Vector2(1010, 83), Vector2(1010, 95), INK, 1)
	for i in range(24):
		var fraction := float(i) / 23.0
		var speed_color := Color(_speed_color(speed_gauge), 0.55 + fraction * 0.45)
		draw_rect(Rect2(336 + i * 6, 52, 4, 9), speed_color if fraction <= speed_gauge and speed_gauge > 0.0 else LINE)
	draw_rect(Rect2(48, 718, 1184, 2), LINE)
	draw_rect(Rect2(48, 718, 1184 * clampf(run.xp / run.xp_needed, 0, 1), 2), CYAN)
	draw_style_box(_style(Color(BG, 0.94), LINE), Rect2(320, 638, 350, 77))
	draw_style_box(_style(Color(BG, 0.94), LINE), Rect2(678, 638, 354, 77))
	_draw_skill_meter(Vector2(347, 666), run.dash_charge(), LIME, run.dash_cooldown <= 0)
	_draw_skill_meter(Vector2(705, 666), clampf(run.overdrive_time / 6.0 if run.overdrive_time > 0 else run.overdrive_meter / 100.0, 0, 1), GOLD, run.overdrive_meter >= 100.0 and run.overdrive_time <= 0)
	for enemy in run.enemies:
		if str(enemy.kind) == "boss":
			draw_rect(Rect2(438, 114, 404, 6), LINE)
			draw_rect(Rect2(438, 114, 404 * float(enemy.hp) / float(enemy.max_hp), 6), CORAL)

func _speed_color(ratio: float) -> Color:
	return CORAL.lerp(SPEED_BLUE, clampf(ratio, 0.0, 1.0))

func _draw_boundary_warning() -> void:
	var depth := run.boundary_depth(run.player)
	var pulse := 1.0 if records.data.reduced_motion else 0.75 + 0.25 * sin(space_time * 4.0)
	var strength := clampf(depth * 0.6 + run.boundary_time * 0.06, 0.15, 1.0)
	draw_rect(Rect2(0, 0, 1280, 720), Color(CORAL, 0.025 * strength))
	for i in range(6):
		draw_rect(Rect2(i * 6, i * 6, 1280 - i * 12, 720 - i * 12), Color(CORAL, (0.24 - i * 0.035) * strength * pulse), false, 6)
	var banner := Rect2(382, 132, 516, 54)
	draw_style_box(_style(Color("321d2a"), CORAL), banner)
	draw_circle(Vector2(406, 151), 5, Color(CORAL, pulse))
	draw_string(font, Vector2(424, 155), "%d층 %s · 중앙 궤도로 복귀" % [run.boundary_layer(run.player), ["안정", "희박권", "붕괴권", "소멸권"][run.boundary_layer(run.player)]], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, CORAL)
	draw_string(font, Vector2(424, 177), "외곽 노출 %.1f초   추가 선체 손상 -%.2f HP/초" % [run.boundary_time, run.boundary_damage_rate()], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, INK)
	var inward := (ARENA.get_center() - run.player).normalized()
	var visible_player := run.player - camera_offset
	var tip := visible_player + inward * 43.0
	draw_line(visible_player + inward * 25.0, tip, CORAL, 3, true)
	draw_line(tip, tip - inward.rotated(0.55) * 11.0, CORAL, 3, true)
	draw_line(tip, tip - inward.rotated(-0.55) * 11.0, CORAL, 3, true)

func _draw_enemy(enemy: Dictionary) -> void:
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
			angle = clock_time * 0.3
			draw_arc(pos, radius + 10, 0, TAU, 36, Color(CORAL, 0.4), 2, true)
	if float(enemy.get("warn", 0)) > 0:
		var aim: Vector2 = enemy.get("aim", Vector2.RIGHT)
		if kind != "boss":
			draw_line(pos, pos + aim * 360, Color(GOLD, 0.38), 1, true)
		draw_arc(pos, radius + 12, 0, TAU, 24, GOLD, 2, true)
	if float(enemy.get("flash", 0)) > 0:
		color = INK
	if float(enemy.get("slow_time", 0)) > 0:
		draw_arc(pos, radius + 4, 0, TAU, 24, CYAN, 1.5, true)
	_polygon(pos, radius, sides, color, angle)
	_polygon(pos, radius * 0.61, sides, BG, angle)
	draw_circle(pos, 3 if kind != "boss" else 8, color, true, -1, true)
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
	replay_time = 0.0
	replay_speed = 1.0
	replay_paused = false
	camera_offset = Vector2.ZERO
	screen = "replay"
	_clear_ui()
	_label("GHOST / " + str(entry.name), Rect2(48, 25, 680, 40), 26, CYAN)
	_label("%s점 · %s · 비행 경로 관전 (전투 재시뮬레이션 아님)" % [_number(entry.score), GameContent.mode_info(entry.mode).name], Rect2(48, 75, 1060, 28), 17, MUTED)
	hud.replay = _label("", Rect2(48, 570, 700, 32), 20)
	replay_slider = HSlider.new()
	replay_slider.position = Vector2(48, 616)
	replay_slider.size = Vector2(680, 32)
	replay_slider.min_value = 0.0
	replay_slider.max_value = maxf(0.01, float(replay_frames.back()[0]))
	replay_slider.step = 0.01
	replay_slider.value_changed.connect(func(value: float) -> void: replay_time = value)
	ui.add_child(replay_slider)
	_button("재생 / 정지", Rect2(48, 661, 205, 42), _toggle_replay)
	_button("배속 변경", Rect2(271, 661, 185, 42), func() -> void: replay_speed = 1.0 if replay_speed == 4.0 else replay_speed * 2.0)
	_button("처음부터", Rect2(474, 661, 180, 42), func() -> void: replay_time = 0.0; replay_paused = false)
	_button("랭킹으로", Rect2(965, 637, 235, 56), _show_records, true, true)

func _draw_replay() -> void:
	var frame := GhostReplay.sample(replay_frames, replay_time)
	var point := Vector2(frame[1], frame[2])
	draw_set_transform(-camera_offset)
	_draw_orbital_regions(CYAN)
	var path := PackedVector2Array()
	for sample: Array in replay_frames:
		if float(sample[0]) > replay_time:
			break
		if float(sample[0]) >= replay_time - 12.0:
			path.append(Vector2(sample[1], sample[2]))
	if path.size() > 1:
		draw_polyline(path, Color(CYAN, 0.4), 2.0, true)
	_polygon(point, 16, 3 if replay_entry.ship == "scout" else (6 if replay_entry.ship == "bastion" else 4), Color(CYAN, 0.75), float(frame[3]))
	for i: int in range(int(frame[6])):
		var angle := float(frame[8]) + TAU * i / float(frame[6])
		var frost := int(frame[12]) > 0 and i % 3 == 0
		_polygon(point + Vector2.from_angle(angle) * float(frame[7]), 9, 6 if frost else (3 if int(frame[11]) > 0 else 4), CYAN if frost else GOLD, angle)
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
