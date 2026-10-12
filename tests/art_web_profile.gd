extends "res://scripts/main.gd"

var qa_draw_us := 0
var qa_arena_us := 0
var qa_enemy_us := 0

func _draw() -> void:
	var begin := Time.get_ticks_usec()
	qa_enemy_us = 0
	super._draw()
	qa_draw_us = Time.get_ticks_usec() - begin

func _draw_arena(world: RunModel = null) -> void:
	var begin := Time.get_ticks_usec()
	super._draw_arena(world)
	qa_arena_us = Time.get_ticks_usec() - begin

func _draw_enemy(enemy: Dictionary, model: RunModel = null) -> void:
	var begin := Time.get_ticks_usec()
	super._draw_enemy(enemy, model)
	qa_enemy_us += Time.get_ticks_usec() - begin
