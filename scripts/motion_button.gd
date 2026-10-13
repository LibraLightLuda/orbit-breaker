extends Button

var reduced := false
var hover_amount := 0.0:
	set(value):
		hover_amount = value
		queue_redraw()
var hover_tween: Tween
var press_tween: Tween

func _ready() -> void:
	mouse_entered.connect(_retarget)
	mouse_exited.connect(_retarget)
	focus_entered.connect(_retarget)
	focus_exited.connect(_retarget)
	button_down.connect(func() -> void: _press(true))
	button_up.connect(func() -> void: _press(false))
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	pivot_offset = size * 0.5

func _retarget() -> void:
	var target := 1.0 if not disabled and (is_hovered() or has_focus()) else 0.0
	if hover_tween: hover_tween.kill()
	if reduced:
		hover_amount = target
	else:
		hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		hover_tween.tween_property(self, "hover_amount", target, 0.14)

func _press(down: bool) -> void:
	if press_tween: press_tween.kill()
	if reduced or disabled: return
	press_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	press_tween.tween_property(self, "scale", Vector2.ONE * (0.985 if down else 1.0), 0.07 if down else 0.14)

func _draw() -> void:
	if hover_amount <= 0.001 or disabled: return
	var color := Color("9ff5ed")
	color.a = hover_amount * 0.85
	var length := (size.x - 24.0) * hover_amount
	draw_line(Vector2(12, 3), Vector2(12 + length, 3), color, 2.0)
	for side in [-1, 1]:
		var x := 5.0 if side == -1 else size.x - 5.0
		draw_line(Vector2(x, size.y * 0.5 - 7), Vector2(x, size.y * 0.5 + 7), color, 2.0)
