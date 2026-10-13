extends Node2D

var bounds := Rect2(0, 0, 1280, 720)
var sector := "ring"
var shader_material := ShaderMaterial.new()

func _init() -> void:
	z_index = -10
	shader_material.shader = preload("res://assets/art/space_flow.gdshader")
	material = shader_material

func sync(rect: Rect2, id: String, time: float, world: Vector2, gravity: Vector2 = Vector2(-4000, -4000), force: float = 0.0) -> void:
	bounds = rect
	sector = id
	shader_material.set_shader_parameter("visual_time", time)
	shader_material.set_shader_parameter("world_shift", world)
	shader_material.set_shader_parameter("aspect", rect.size.x / rect.size.y)
	shader_material.set_shader_parameter("gravity_center", (gravity - rect.position) / rect.size)
	shader_material.set_shader_parameter("gravity_power", force)
	queue_redraw()

func _draw() -> void:
	draw_texture_rect(ArtAssets.texture("world/" + sector), bounds, false)
