extends SceneTree

var game: Node2D
var checks := 0
var failures := 0
var folder := "res://artifacts/pregame-candidate"
var captured := {}

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("PREGAME: " + message)

func settle() -> void:
	for i in 4: await process_frame

func visible_controls(node: Node) -> Array[Control]:
	var result: Array[Control] = []
	for child in node.get_children():
		if child is Control and child.is_visible_in_tree():
			result.append(child)
			result.append_array(visible_controls(child))
	return result

func inspect(context: String) -> void:
	var bounds := Rect2(Vector2(-1, -1), Vector2(root.size) + Vector2(2, 2))
	var buttons: Array[Rect2] = []
	for c in visible_controls(game.ui):
		var transform := root.get_final_transform() * c.get_global_transform_with_canvas()
		var rect := Rect2(transform * Vector2.ZERO, c.size * transform.get_scale())
		check(bounds.encloses(rect), context + " bounds " + c.get_class() + " " + str(rect))
		if c.has_meta("pregame_content"):
			for button in game.ui.get_children():
				if button != c and button is Button and button.visible and not button.text.is_empty():
					check(not c.get_rect().intersects(button.get_rect()), context + " content clears fixed navigation")
		check(not c is ScrollContainer, context + " no scrolling")
		if c is Label:
			var measured := c.get_theme_font("font").get_multiline_string_size(c.text, HORIZONTAL_ALIGNMENT_LEFT, c.size.x, c.get_theme_font_size("font_size"))
			check(measured.y <= c.size.y + 2, context + " complete text: " + c.text)
			if c.get_parent() is Panel or c.get_parent() is Button:
				check(Rect2(Vector2.ZERO, c.get_parent().size + Vector2.ONE).encloses(c.get_rect()), context + " text inside card " + c.text)
		if c is Button or c is HSlider:
			check(rect.size.y >= 43 and rect.size.x >= 43, context + " touch size " + str(rect))
			for other in buttons: check(not rect.intersects(other), context + " no overlapping targets")
			buttons.append(rect)
			var at := rect.get_center()
			var mouse := InputEventMouseMotion.new()
			mouse.position = root.get_final_transform().affine_inverse() * at
			root.push_input(mouse, true)
			check(root.gui_get_hovered_control() == c, context + " unobstructed target " + str(c.name))

func tap(c: Control) -> void:
	var at: Vector2 = c.get_global_transform_with_canvas() * (c.size * 0.5)
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = at
		event.pressed = pressed
		root.push_input(event, true)
	await settle()

func audit(context: String) -> void:
	await settle()
	if game.screen == "credits":
		var original := ""
		var paged := ""
		for c in game.ui.get_children():
			if c is RichTextLabel: original = c.text
			elif c is Label and c.has_meta("license_fragment"): paged += c.text
		check(original == paged, "all license characters preserved")
	var reached := {}
	var pages := int(game.ui.get_meta("pregame_page_count", 1))
	if game.ui.has_node("PregamePrevious"):
		while not game.ui.get_node("PregamePrevious").disabled:
			await tap(game.ui.get_node("PregamePrevious"))
	for page in pages:
		inspect(context + " page %d" % page)
		if page == 0 and (context.ends_with("360x606") or context.ends_with("667x341")):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(folder + "/" + context + "-first.png")
		for c in visible_controls(game.ui): reached[c.get_instance_id()] = true
		if page + 1 < pages:
			if game.screen == "credits" and page > 1:
				game.ui.get_node("PregameNext").pressed.emit()
				await process_frame
			else:
				await tap(game.ui.get_node("PregameNext"))
			check(int(game.ui.get_meta("pregame_page", -1)) == page + 1, context + " real viewport tap advances page")
	if game.ui.has_node("PregameNext"):
		for c in game.ui.get_children():
			if (c is Button or c is Panel or c is LineEdit or c is HSlider) and not c.has_meta("pregame_redundant"):
				check(reached.has(c.get_instance_id()), context + " every original choice/card reachable")
	if not captured.has(context) and context.ends_with("360x606"):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder + "/" + context + ".png")
		captured[context] = true

func run_checks() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.records.load_data("user://pregame_test_%d.json" % Time.get_ticks_usec())
	game.sound.set_muted(true)
	game.records.data.discovered_items.assign(preload("res://scripts/item_catalog.gd").IDS)
	for i in 10:
		var entry := {"name":"열여섯글자파일럿의긴이름%02d" % i,"won":false,"ship":"striker","sector":"ring","mode":"normal","score":12345678,"time":543.0,"ghost":""}
		game.records.data.leaderboard.append(entry)
		if i < 8: game.records.data.recent_runs.append(entry)
	root.min_size = Vector2i.ZERO
	for resolution: Vector2i in [Vector2i(320,534),Vector2i(360,606),Vector2i(390,810),Vector2i(412,881),Vector2i(568,286),Vector2i(667,341),Vector2i(844,356),Vector2i(1024,734)]:
		root.size = resolution
		root.content_scale_size = Vector2i(540,960) if resolution.x < resolution.y else Vector2i(960,540)
		game.touch_mode = true
		game.records.data.reduced_motion = true
		await settle()
		var suffix := "-%dx%d" % [resolution.x,resolution.y]
		for method in ["_show_menu", "_show_hangar", "_show_help", "_show_settings", "_show_credits"]:
			game.call(method)
			await audit(method + suffix)
		for tab in ["missions", "history", "ranking"]:
			game.records_tab = tab
			game._show_records()
			await audit("records-" + tab + suffix)
		for tab in ["weapons", "tech", "items"]:
			game.codex_tab = tab
			for page in 2:
				game.arsenal_page = page
				game.tech_page = page
				game.item_page = page
				game._open_arsenal("menu")
				await audit(tab + str(page) + suffix)
		game._show_item_detail("power")
		await audit("item-detail" + suffix)
	# Rotation reuses the production rebuild path and keeps the editable name and choices.
	game._show_hangar()
	await settle()
	game.records.data.player_name = "회전 파일럿"
	for child in game.ui.get_children():
		if child is LineEdit:
			child.text = "회전 파일럿"
			child.grab_focus()
			child.caret_column = 3
	game.selected_ship = "scout"
	game.selected_sector = "storm"
	root.size = Vector2i(390,810)
	root.content_scale_size = Vector2i(540,960)
	await settle()
	check(game.screen == "hangar" and game.selected_ship == "scout" and game.selected_sector == "storm" and game.records.data.player_name == "회전 파일럿", "rotation preserves preflight selections/name")
	var focused := root.gui_get_focus_owner()
	check(focused is LineEdit and focused.text == "회전 파일럿" and focused.caret_column == 3, "rotation preserves editable name focus and caret")
	for choice in [["플레이 방법","help"],["설정","settings"],["무기 도감","arsenal"],["작전 기록","records"],["출격 준비","hangar"]]:
		game._show_menu()
		await settle()
		for c in game.ui.get_children():
			if c is Button and c.text.begins_with(choice[0]):
				await tap(c)
				break
		check(game.screen == choice[1], "touch enters " + choice[1])
		for c in game.ui.get_children():
			if c is Button and c.text == "돌아가기":
				await tap(c)
				break
		check(game.screen == "menu", "fixed return touch leaves " + choice[1])
	game.queue_free()
	await process_frame
	FileAccess.open(folder + "/results.json", FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"physical_device":false,"scope":"pregame only"}))
	print("PREGAME SELF-CHECK: %d / %d assertions passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
