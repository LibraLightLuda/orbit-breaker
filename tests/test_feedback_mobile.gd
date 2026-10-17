extends SceneTree

var checks := 0
var failures := 0
var game: Node2D
const FOLDER := "res://artifacts/clarity-work/mobile"

func _initialize() -> void: call_deferred("run_checks")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("MOBILE FEEDBACK: " + message)

func fit_checks(node: Node, window: Vector2, context: String) -> void:
	for c in node.get_children():
		if not c is Control or not c.is_visible_in_tree() or c.name == "Shade": continue
		var transform: Transform2D = game.get_viewport().get_final_transform() * c.get_global_transform_with_canvas()
		var rect := Rect2(transform * Vector2.ZERO, c.size * transform.get_scale())
		check(Rect2(Vector2(-1,-1), window + Vector2(2,2)).encloses(rect), context + " visible control fits " + c.get_class() + " " + str(c.position) + " " + str(c.size))
		if c is Label:
			var measured: Vector2 = c.get_theme_font("font").get_multiline_string_size(c.text,HORIZONTAL_ALIGNMENT_LEFT,c.size.x,c.get_theme_font_size("font_size"))
			check(measured.y <= c.size.y + 2,context + " complete readable text: " + c.text)
			if c.get_parent() is Button:
				check(Rect2(Vector2.ZERO, c.get_parent().size + Vector2(1,1)).encloses(c.get_rect()),context + " text fits its choice card: " + c.text + str(c.get_rect()) + " parent " + str(c.get_parent().size))
		fit_checks(c, window, context)

func capture(label: String) -> void:
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(FOLDER + "/" + label + ".png") == OK,"capture " + label)

func run_checks() -> void:
	var gesture := preload("res://scripts/touch_controls.gd").new()
	for scale_value in [0.5, 1.0, 2.0]:
		for direction: Vector2 in [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]:
			gesture.reset()
			gesture.press(0,Vector2(800,400),scale_value)
			gesture.drag(0,Vector2(800,400)+direction*60/scale_value)
			gesture.advance(0.35)
			check(gesture.release(0,Vector2(800,400)+direction*60/scale_value)=="dash" and gesture.dash_direction.is_equal_approx(direction),"direction derives from drag vector at each pixel scale")
	gesture.reset()
	gesture.press(0,Vector2.ZERO,1)
	gesture.drag(0,Vector2(90,0))
	gesture.advance(0.1)
	check(gesture.release(0,Vector2(90,0))=="","short drag only steers")
	gesture.press(0,Vector2.ZERO,1)
	gesture.drag(0,Vector2(90,0))
	gesture.advance(0.4)
	check(gesture.release(0,Vector2(90,0),true)=="","canceled long drag cannot dash")
	if DisplayServer.get_name()=="headless":
		print("MOBILEFEEDBACK SELF-CHECK: %d / %d assertions passed" % [checks-failures,checks])
		quit(0 if failures==0 else 1)
		return
	DirAccess.make_dir_recursive_absolute(FOLDER)
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.records.load_data("user://feedback_mobile_%d.json" % Time.get_ticks_usec())
	game.sound.set_muted(true)
	root.min_size=Vector2i.ZERO
	for resolution: Vector2i in [Vector2i(360,606),Vector2i(360,640),Vector2i(390,844),Vector2i(667,341),Vector2i(667,375),Vector2i(844,356),Vector2i(844,390),Vector2i(1024,768)]:
		root.size=resolution
		root.content_scale_size=Vector2i(540,960) if resolution.x<resolution.y else Vector2i(960,540)
		game.touch_mode=true
		for i in 3: await process_frame
		for method in ["_show_menu","_show_hangar"]:
			game.call(method)
			for i in 3: await process_frame
			check(not game.ui.has_node("CompactScroll"),method+" no scrolling")
			fit_checks(game.ui,Vector2(resolution),method+str(resolution))
			await capture(method+"-%dx%d" % [resolution.x,resolution.y])
		var cards: Array=game.ui.get_children().filter(func(c: Node)->bool: return c is Button and c.text.is_empty())
		var positions: Array=cards.map(func(c: Control)->Vector2: return c.position)
		cards[1].pressed.emit()
		for i in 3: await process_frame
		check(game.ui.position==Vector2.ZERO,"selection does not restart vertical entrance animation")
		cards=game.ui.get_children().filter(func(c: Node)->bool: return c is Button and c.text.is_empty())
		check(cards.map(func(c: Control)->Vector2: return c.position)==positions,"all hangar choices keep their positions")
		game._start_run()
		game.run.state="upgrade"
		for choices in [["power","orbit","speed"],["rapid","blade","vitality"],["missile","chain","frost"],["pulse","dash","magnet"]]:
			game.choices=choices
			game._show_upgrades(true)
			for i in 3: await process_frame
			fit_checks(game.ui,Vector2(resolution),"upgrade"+str(resolution))
			check(not game.ui.has_node("CompactScroll"),"all choices visible without page scroll")
			for card in game.ui.get_children():
				if card is Button and card.text.is_empty():
					check(card.get_child(5).vertical_scroll_mode==ScrollContainer.SCROLL_MODE_SHOW_NEVER,"recipe conditions never require scroll")
					check(card.get_child(3).get_rect().end.y <= card.get_child(4).position.y,"long effect description cannot overlap change amount")
					check(card.get_child(4).get_rect().end.y <= card.get_child(5).position.y,"change amount cannot overlap evolution conditions")
					check(card.get_child(5).get_child(0).size.y <= card.get_child(5).size.y + 1,"all evolution conditions fit without hidden overflow " + str(resolution) + str(choices) + str(card.get_child(5).get_child(0).size) + " available " + str(card.get_child(5).size))
			if choices[0]=="power": await capture("upgrade-%dx%d" % [resolution.x,resolution.y])
		game._resume()
		game.run.part_drops.clear()
		game.run.items.clear()
		var view: Rect2=game._viewport_rect()
		for i in 8:
			var pos: Vector2=game.camera_offset+view.get_center()+Vector2.from_angle(i*TAU/8)*2000
			if i%2:
				game.run.items.append({"id":"power","grade":"A","pos":pos,"ttl":25})
			else:
				game.run.part_drops.append({"id":"core","pos":pos,"ttl":30,"locked":false})
		var guides: Array=game._pickup_guides(game.run)
		check(guides.size()==8,"one unified guide per offscreen pickup in every direction")
		var physical: Rect2=Rect2(view.position*root.get_final_transform().get_scale().x,Vector2(resolution))
		for guide in guides:
			check(physical.has_point(guide.at) and physical.encloses(guide.label),"edge arrow and distance label stay onscreen")
			check(guide.text.contains("m") and guide.text.contains("s"),"guide includes distance and expiry")
		await capture("guides-%dx%d" % [resolution.x,resolution.y])
	game.queue_free()
	await process_frame
	FileAccess.open(FOLDER+"/feedback-results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"physical_device":false}))
	print("MOBILEFEEDBACK SELF-CHECK: %d / %d assertions passed" % [checks-failures,checks])
	quit(0 if failures==0 else 1)

