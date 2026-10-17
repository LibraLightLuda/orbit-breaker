extends RefCounted

static func show(game: Node2D, page: String = "online") -> void:
	game.screen = page
	game._clear_ui()
	var window := Vector2(DisplayServer.window_get_size())
	if window.x < 1: window = game.get_viewport_rect().size
	game.ui.set_meta("fitted_menu", true)
	game.ui.scale = Vector2.ONE * game.get_viewport_rect().size.x / window.x
	game.ui.get_parent().offset = Vector2.ZERO
	var width := minf(640.0, window.x - 24.0)
	var x := (window.x - width) * 0.5
	var y := 12.0
	game._panel(Rect2(0, 0, window.x, window.y), game.BG, game.BG)
	game._label({"online": "온라인 출격", "online_options": "출격 조건", "online_lobby": "2인 편대", "online_result": "온라인 출격 완료", "online_rank": "글로벌 기록", "online_rank_filters": "랭킹 조건", "online_practice_result": "연습 도전 완료"}.get(page, "온라인"), Rect2(x, y, width, 32), 25, game.CYAN)
	y += 36
	match page:
		"online":
			line(game, "nickname", "닉네임 · 중복 가능", Rect2(x, y, width, 44))
			y += 48
			game._button("공식 도전", Rect2(x, y, width * 0.49, 44), func() -> void: game._online_create("solo"), true).disabled = not bool(game.online.features.get("combat", false))
			game._button("협동 방 만들기", Rect2(x + width * 0.51, y, width * 0.49, 44), func() -> void: game._online_create("coop")).disabled = not bool(game.online.features.get("combat", false))
			y += 48
			line(game, "code", "방 코드", Rect2(x, y, width * 0.6, 44))
			game._button("방 참가", Rect2(x + width * 0.62, y, width * 0.38, 44), game._online_join)
			y += 48
			game._button("글로벌 기록", Rect2(x, y, width * 0.32, 44), game._online_rank)
			game._button("내 기록", Rect2(x + width * 0.34, y, width * 0.32, 44), func() -> void: game.online_cursor = 0; game._online_history())
			game._button("출격 조건", Rect2(x + width * 0.68, y, width * 0.32, 44), func() -> void: show(game, "online_options"))
			y += 48
		"online_options":
			for spec in [["ship", GameContent.SHIP_IDS, "ship_info"], ["sector", GameContent.SECTOR_IDS, "sector_info"], ["difficulty", GameContent.MODE_IDS, "mode_info"]]:
				var option := OptionButton.new()
				option.position = Vector2(x, y)
				option.size = Vector2(width, 44)
				option.add_theme_font_size_override("font_size", 19)
				for id: String in spec[1]:
					var info: Dictionary = GameContent.ship_info(id) if spec[0] == "ship" else (GameContent.sector_info(id) if spec[0] == "sector" else GameContent.mode_info(id))
					option.add_item(str(info.name))
				option.select(spec[1].find(game.online_form[spec[0]]))
				option.item_selected.connect(func(index: int) -> void: game.online_form[spec[0]] = spec[1][index])
				game.ui.add_child(option)
				y += 48
		"online_rank_filters":
			option(game, "difficulty", GameContent.MODE_IDS, GameContent.MODE_IDS.map(func(id: String) -> String: return GameContent.mode_info(id).name), Rect2(x, y, width * 0.49, 44))
			option(game, "sector", GameContent.SECTOR_IDS, GameContent.SECTOR_IDS.map(func(id: String) -> String: return GameContent.sector_info(id).name), Rect2(x + width * 0.51, y, width * 0.49, 44))
			y += 48
			option(game, "rank_mode", ["solo", "coop"], ["솔로", "협동"], Rect2(x, y, width * 0.49, 44))
			option(game, "rank_ship", ["", "striker", "scout", "bastion"], ["전체 기체", "스트라이커", "스카우트", "배스천"], Rect2(x + width * 0.51, y, width * 0.49, 44))
			y += 48
			line(game, "season", "시즌 YYYY-MM · 빈칸은 현재", Rect2(x, y, width, 44))
			y += 48
			game._button("조건 적용", Rect2(x, y, width, 44), func() -> void: game.online_cursor = 0; game._online_rank(), true)
			y += 48
		"online_lobby":
			game._label("방 " + str(game.online.room.get("code", "")), Rect2(x, y, width, 36), 23, game.GOLD)
			y += 40
			for player: Dictionary in game.online_players:
				game._label(str(player.get("nickname", "대기 중")) + (" · 준비 완료" if player.get("ready", false) else " · 대기"), Rect2(x, y, width, 32), 18)
				y += 36
			game._button("준비 완료", Rect2(x, y, width, 44), func() -> void: game.online.send({"type": "ready", "ready": true}), true)
			y += 48
		"online_result":
			game._label("점수 %s · 생존 %s" % [game._number(int(game.online_result.get("score", 0))), game._time(float(game.online_result.get("ticks", 0)) / 60.0)], Rect2(x, y, width, 36), 23, game.GOLD)
			y += 40
			line(game, "nickname", "공개할 닉네임", Rect2(x, y, width, 44))
			y += 48
			game._button("익명 기록 등록", Rect2(x, y, width, 44), game._online_publish, true)
			y += 48
			game._button("고스트 관전", Rect2(x, y, width * 0.49, 44), func() -> void: game._online_watch(str(game.online_result.id)))
			game._button("글로벌 기록", Rect2(x + width * 0.51, y, width * 0.49, 44), game._online_rank)
			y += 48
		"online_practice_result":
			game._label("내 점수 " + game._number(int(game.online_result.score)), Rect2(x, y, width, 44), 25, game.GOLD)
			y += 48
			game._button("다시 도전", Rect2(x, y, width, 44), game._retry_ghost_race, true)
			y += 48
		"online_rank", "online_history":
			var label := "%s · %s · %s" % ["협동" if game.online_board_mode == "coop" else "솔로", GameContent.mode_info(game.online_form.difficulty).name, GameContent.sector_info(game.online_form.sector).name]
			game._label("이 기기의 최근 20경기" if page == "online_history" else label, Rect2(x, y, width, 28), 16, game.MUTED)
			y += 32
			var count := maxi(1, mini(8, floori((window.y - y - 124.0) / 48.0)))
			for i in mini(count, game.online_rows.size()):
				var entry: Dictionary = game.online_rows[i]
				game._button("%s  %s  · %s" % [str(entry.rank), entry.nickname, game._number(int(entry.score))], Rect2(x, y, width, 44), func() -> void:
					if page == "online_history": game.online_result = entry; show(game, "online_result")
					else: game._online_watch(str(entry.id)))
				y += 48
			game._button("이전", Rect2(x, y, width * 0.24, 44), func() -> void: game.online_cursor = maxi(0, game.online_cursor - count); game._online_history() if page == "online_history" else game._online_rank())
			game._button("다음", Rect2(x + width * 0.26, y, width * 0.24, 44), func() -> void: game.online_cursor += count; game._online_history() if page == "online_history" else game._online_rank())
			if page != "online_history": game._button("조건·시즌", Rect2(x + width * 0.52, y, width * 0.48, 44), func() -> void: show(game, "online_rank_filters"))
			y += 48
	game._button("돌아가기", Rect2(x, y, width, 44), game._show_menu if page == "online" else (func() -> void: game._online_back()), false, true)
	y += 48
	game._label(game.online_notice, Rect2(x, y, width, 24), 14, game.CORAL)

static func line(game: Node2D, key: String, placeholder: String, rect: Rect2) -> void:
	var edit := LineEdit.new()
	edit.position = rect.position
	edit.size = rect.size
	edit.placeholder_text = placeholder
	edit.max_length = 16 if key == "nickname" else 10
	edit.text = str(game.online_form[key])
	edit.add_theme_font_size_override("font_size", 18)
	edit.text_changed.connect(func(value: String) -> void: game.online_form[key] = value)
	game.ui.add_child(edit)

static func option(game: Node2D, key: String, ids: Array, names: Array, rect: Rect2) -> void:
	var control := OptionButton.new()
	control.position = rect.position
	control.size = rect.size
	control.add_theme_font_size_override("font_size", 16)
	for label: String in names: control.add_item(label)
	control.select(maxi(0, ids.find(game.online_form[key])))
	control.item_selected.connect(func(index: int) -> void: game.online_form[key] = ids[index])
	game.ui.add_child(control)
