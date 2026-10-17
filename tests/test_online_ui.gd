extends SceneTree

var checks := 0

func _init() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	for size in [Vector2i(320,568),Vector2i(390,844),Vector2i(568,320),Vector2i(844,390),Vector2i(1280,720)]:
		root.size = size
		if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(size)
		game.online_rows = range(20).map(func(i: int) -> Dictionary: return {"id":"a".repeat(32),"rank":i+1,"nickname":"긴 닉네임 파일럿","score":12345})
		game.online_players = [{"nickname":"파일럿1","ready":true},{"nickname":"파일럿2","ready":false}]
		game.online_result = {"id":"a".repeat(32),"score":12345,"ticks":36000}
		for page in ["online","online_options","online_lobby","online_result","online_rank","online_rank_filters","online_practice_result","online_history"]:
			preload("res://scripts/online_menu.gd").show(game,page)
			await process_frame
			var expected := Vector2(DisplayServer.window_get_size())
			if expected.x < 1: expected = root.get_visible_rect().size
			for child in game.ui.get_children():
				if child is Button or child is LineEdit or child is OptionButton:
					assert(child.position.x>=0 and child.position.y>=0 and child.position.x+child.size.x<=expected.x+1 and child.position.y+child.size.y<=expected.y+1,"online controls within viewport")
					assert(child.size.y>=44,"online touch targets")
					checks += 2
			assert(not game.ui.has_node("CompactScroll"),"online choices never scroll")
			checks += 1
	game.sound.stop_all()
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("ONLINE UI SELF-CHECK: %d checks passed" % checks)
	game = null
	call_deferred("quit")
