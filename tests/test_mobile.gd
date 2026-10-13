extends SceneTree

var checks := 0
var failures := 0
var game: Node2D
var folder := "res://artifacts/mobile-candidate"

func _initialize() -> void:
	call_deferred("run_checks")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("MOBILE: " + message)

func touch_event(index: int, at: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event, true)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	game.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder + "/" + label + ".png") == OK, label + " screenshot")

func run_checks() -> void:
	var gesture := preload("res://scripts/touch_controls.gd").new()
	gesture.press(0, Vector2(100, 100), 1)
	check(gesture.release(0, Vector2(100, 100)) == "", "single tap waits for possible second tap")
	check(gesture.advance(0.2) == "", "tap window remains open")
	check(gesture.advance(0.05) == "dash" and gesture.dash_position == Vector2(100, 100), "single tap emits exactly one aimed dash")
	check(gesture.advance(1) == "", "tap never repeats")
	gesture.press(0, Vector2(100, 100), 1)
	gesture.release(0, Vector2(100, 100))
	gesture.advance(0.1)
	gesture.press(0, Vector2(108, 100), 1)
	check(gesture.release(0, Vector2(108, 100)) == "overdrive" and gesture.advance(1) == "", "double tap emits only overdrive")
	gesture.press(0, Vector2(100, 100), 1)
	gesture.drag(0, Vector2(148, 100))
	check(gesture.direction == Vector2.RIGHT, "floating drag reaches full movement")
	gesture.press(1, Vector2(500, 150), 1)
	gesture.release(1, Vector2(500, 150))
	gesture.drag(0, Vector2(150, 102))
	check(gesture.advance(0.25) == "dash" and not gesture.direction.is_zero_approx(), "second finger can tap while first continues steering")
	check(gesture.release(0, Vector2(150, 102)) == "" and gesture.direction == Vector2.ZERO, "drag release stops steering without skill")
	gesture.press(0, Vector2.ZERO, 1)
	gesture.advance(0.4)
	check(gesture.release(0, Vector2.ZERO) == "", "long hold is not a tap")
	gesture.press(0, Vector2.ZERO, 1)
	check(gesture.release(0, Vector2.ZERO, true) == "" and not gesture.pending, "canceled touch never triggers skill")
	gesture.press(0, Vector2.ZERO, 1)
	gesture.release(0, Vector2.ZERO)
	gesture.reset()
	check(gesture.advance(1) == "" and gesture.contacts.is_empty(), "menu/focus reset clears pending taps")
	if DisplayServer.get_name() == "headless":
		print("MOBILE SELF-CHECK: %d / %d assertions passed" % [checks - failures, checks])
		quit(0 if failures == 0 else 1)
		return
	DirAccess.make_dir_recursive_absolute(folder)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.records.load_data("user://mobile_test_%d.json" % Time.get_ticks_usec())
	game.sound.set_muted(true)
	game.touch_mode = true
	game._start_run()
	await process_frame
	check(game.ui.has_node("MobileHUD"), "touch mode creates physical-size HUD")
	var point: Vector2 = game.position + game.run.player + Vector2(130, 50)
	touch_event(0, point, true)
	touch_event(0, point, false)
	game._physics_process(0.25)
	check(game.run.dash_time > 0 and game.run.dash_cooldown > 0, "real viewport tap activates existing dash")
	game._start_run()
	game.run.overdrive_meter = 100
	touch_event(0, point, true)
	touch_event(0, point, false)
	game._physics_process(0.08)
	touch_event(0, point, true)
	touch_event(0, point, false)
	game._physics_process(0.02)
	check(game.run.overdrive_time > 0 and game.run.overdrive_meter < 1 and game.run.dash_cooldown <= 0, "viewport double tap consumes only charged overdrive")
	game._start_run()
	touch_event(0, point, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = point + Vector2(110, 0)
	root.push_input(drag, true)
	var start: Vector2 = game.run.player
	for i in 15: game._physics_process(1.0 / 60)
	check(game.run.player.x > start.x + 5, "viewport drag moves the actual ship")
	touch_event(0, drag.position, false)
	check(game._movement_direction().is_zero_approx() and not game.dash_queued, "drag release stops input and does not queue a dash")
	touch_event(0, point, true)
	touch_event(0, point, false)
	game._show_pause()
	game._resume()
	game._physics_process(0.3)
	check(game.run.dash_cooldown <= 0, "menu transition cannot replay a stale touch skill")
	var emulated := InputEventMouseButton.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.pressed = true
	emulated.button_index = MOUSE_BUTTON_LEFT
	game._unhandled_input(emulated)
	check(not game.dash_queued, "touch-emulated mouse cannot duplicate dash")
	var mobile: Control = game.ui.get_node("MobileHUD")
	check(mobile.pause.size.x >= 44 and mobile.codex.size.y >= 44 and mobile.dash.size.y >= 44, "combat controls keep 44px minimum targets")
	check(mobile.pause.position.x + mobile.pause.size.x <= mobile.size.x and mobile.overdrive.position.x + mobile.overdrive.size.x <= mobile.size.x, "touch buttons fit without overlap or clipping")
	var button_point: Vector2 = mobile.pause.get_global_transform_with_canvas() * (mobile.pause.size * 0.5)
	touch_event(0, button_point, true)
	touch_event(0, button_point, false)
	await process_frame
	check(game.screen == "pause" and not game.touch.pending, "touch pause button does not leak a combat tap")
	for resolution: Vector2i in [Vector2i(844, 390), Vector2i(667, 375), Vector2i(390, 844), Vector2i(360, 800)]:
		root.content_scale_size = Vector2i(540, 960) if resolution.x < resolution.y else Vector2i(960, 540)
		root.min_size = Vector2i.ZERO
		root.size = resolution
		await process_frame
		game.touch_mode = true
		game._resume()
		game.ui.get_node("MobileHUD").fit()
		await capture("combat-%dx%d" % [resolution.x, resolution.y])
		game._show_hangar()
		await process_frame
		await process_frame
		check(game.ui.has_node("CompactScroll") or DisplayServer.get_name() == "headless", "small screen menu uses readable scrolling layout")
		var launch: Array = game.ui.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return int(b.get_meta("flow_order", 0)) == 750)
		check(launch.size() == 1 and launch[0].get_parent() == game.ui, "mobile launch stays accessible while cards scroll")
		await capture("hangar-%dx%d" % [resolution.x, resolution.y])
		game.run.state = "upgrade"
		game._show_upgrades()
		await process_frame
		await process_frame
		if resolution.x >= 800:
			var content: Control = game.ui.get_node("CompactScroll").get_child(0)
			var card: Button = content.get_children().filter(func(c: Node) -> bool: return c is Button and c.text.is_empty())[0]
			check(card.get_child(2).position.y < 64 and card.get_child(3).position.y < 96, "landscape upgrade name and effect are visible together")
		await capture("upgrade-%dx%d" % [resolution.x, resolution.y])
	game.queue_free()
	await process_frame
	FileAccess.open(folder + "/mobile-results.json", FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"physical_device":false}))
	print("MOBILE SELF-CHECK: %d / %d assertions passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)
