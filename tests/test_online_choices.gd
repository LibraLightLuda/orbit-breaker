extends SceneTree

func _init() -> void:
	var world = preload("res://scripts/online_world.gd").new()
	world.reset(123, "normal", ["striker", "scout"], "ring")
	world.model.state = "upgrade"
	world.save_actor()
	var offered: Array = world.choices(0)
	var cards: Array = world.model._choices.duplicate(true)
	var revision: int = world.actors[0].choice_revision
	assert(not offered.is_empty())
	assert(revision > 0)
	assert(not world.choose(0, str(offered[0]), -1))
	assert(world.choose(0, str(offered[0]), revision))
	world.model.state = "upgrade"
	world.model._choices.assign(cards)
	world.save_actor()
	assert(world.choices(0) == offered)
	var next_revision: int = world.actors[0].choice_revision
	assert(next_revision > revision, "identical future cards still have a new response window")
	assert(not world.choose(0, str(offered[0]), revision))
	assert(world.choose(0, str(offered[0]), next_revision))
	world.dispose()
	print("ONLINE CHOICES SELF-CHECK: 8 assertions passed")
	call_deferred("quit")
