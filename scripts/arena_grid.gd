extends Node2D

var sector_color := Color.TRANSPARENT

func _init() -> void:
	z_index = -5
	visible = false

func configure(color: Color) -> void:
	visible = true
	if sector_color != color:
		sector_color = color
		queue_redraw()

func _draw() -> void:
	var center := RunModel.CENTER
	var radius := RunModel.ACTIVITY_RADIUS
	var colors := [sector_color, Color("ffd18a"), Color("ff7185"), Color("bd81ff")]
	for layer: int in range(4):
		var edge := radius + layer * RunModel.LAYER_WIDTH
		var color: Color = colors[layer]
		draw_arc(center, edge, 0, TAU, 192, Color(color, 0.5), 1.5, true)
		var ticks := PackedVector2Array()
		for segment in 24:
			var a := TAU * segment / 24.0
			ticks.append_array(PackedVector2Array([center + Vector2.from_angle(a) * (edge + 5), center + Vector2.from_angle(a + 0.06) * (edge + 5)]))
		draw_multiline(ticks, Color(color, 0.25), 5, true)
	draw_arc(center, RunModel.ACTIVITY_RADIUS / 3, 0, TAU, 96, Color("203344"), 1, true)
	draw_arc(center, RunModel.ACTIVITY_RADIUS * 2 / 3, 0, TAU, 128, Color("203344"), 1, true)
