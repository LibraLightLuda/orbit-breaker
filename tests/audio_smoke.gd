extends SceneTree

func _init() -> void:
	call_deferred("start")

func start() -> void:
	var game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await create_timer(3).timeout
	if game.screen != "menu" or not (game.sound._music.playing or game.sound.muted or not game.sound._music_enabled):
		push_error("Production main scene did not start correctly")
		quit(1)
		return
	print("AUDIO SMOKE COMPLETE: production main scene rendered; normal close requested")
	game.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
