"""Presentation migration from the preserved 3.18 baseline; run once."""
from pathlib import Path
p=Path('scripts/main.gd'); s=p.read_text(encoding='utf-8')
def replace(old,new):
    global s
    assert old in s,old[:100]
    s=s.replace(old,new)
replace('var space_time := 0.0','var space_time := 0.0\nvar art_styles: Dictionary = {}')
replace('\tvar style := StyleBoxFlat.new()','\tvar key := str(fill) + str(border) + str(width)\n\tif art_styles.has(key): return art_styles[key]\n\tvar style := StyleBoxFlat.new()\n\tart_styles[key] = style')
replace('\tstyle.set_corner_radius_all(7)','\tstyle.set_corner_radius_all(3)\n\tstyle.border_width_top = width + 1')
replace('\tdraw_rect(_viewport_rect(), BG)','\tdraw_rect(_viewport_rect(), BG)\n\tdraw_texture_rect(ArtAssets.texture("world/ring"), _viewport_rect(), false, Color(1, 1, 1, 0.55))')
replace('\t\t_diamond(pos, 11, CYAN, angle)','\t\tArtAssets.sprite(self, "objects/normal", pos, Vector2.ONE * 28, angle)')
start=s.index('\t_diamond(center, 39,');end=s.index('\tdraw_arc(center, 270',start)
s=s[:start]+'\tpreload("res://scripts/ui_glyph.gd").ship(self, center, selected_ship, CYAN, 7.0, -PI / 6)\n'+s[end:]
replace('\t\t_polygon(pos, 15, 3 if i % 2 else 4, CORAL if i % 2 else GOLD, angle + PI)\n\t\t_polygon(pos, 8, 3 if i % 2 else 4, BG, angle + PI)','\t\tArtAssets.sprite(self, "enemies/runner" if i % 2 else "enemies/chaser", pos, Vector2.ONE * 37, angle + PI)')
replace('\tdraw_rect(world_rect, Color("0c1925"))','\tdraw_rect(world_rect, Color("050c16"))\n\tvar bg_id: String = "world/" + model.sector_id\n\tvar bg_size := world_rect.size * 1.18\n\tvar bg_shift := camera_offset * 0.06\n\tdraw_texture_rect(ArtAssets.texture(bg_id), Rect2(world_rect.get_center() - bg_size * 0.5 - bg_shift, bg_size), false, Color(1,1,1,0.8))')
replace('\t\t_draw_enemy(enemy)','\t\t_draw_enemy(enemy, model)')
replace('func _draw_enemy(enemy: Dictionary) -> void:','func _draw_enemy(enemy: Dictionary, model: RunModel = null) -> void:')
replace('\t\t\tangle = (replay_time if screen == "replay" else clock_time) * 0.3','\t\t\tangle = (replay_time if screen == "replay" else run.elapsed) * 0.3')
replace('\t_polygon(pos, radius, sides, color, angle)\n\t_polygon(pos, radius * 0.61, sides, BG, angle)\n\tdraw_circle(pos, 3 if kind != "boss" else 8, color, true, -1, true)', '''\tvar art_id := kind
	if kind == "elite": art_id = "elite_assault" if int(enemy.get("elite_index", 1)) == 1 else "elite_artillery"
	ArtAssets.sprite(self, "enemies/" + art_id, pos, Vector2.ONE * radius * 2.3, angle, camera_offset, Color(1.8,1.8,1.8) if float(enemy.get("flash",0)) > 0 else Color.WHITE)
	if kind == "boss" and model != null:
		var phase_color := CORAL if float(enemy.hp) > float(enemy.max_hp) * 0.5 else GOLD
		var count := 3 if model.sector_id == "forge" else (5 if model.sector_id == "storm" else 6)
		for organ in count:
			var bearing := angle + TAU * organ / count
			var tip := pos + Vector2.from_angle(bearing) * radius * 0.9
			draw_line(tip, tip + Vector2.from_angle(bearing) * (12 if phase_color == GOLD else 5), phase_color, 3, true)''')
start=s.index('\t_diamond(player + Vector2(0, 4),');end=s.index('\tfor i in 3:',start)
s=s[:start]+'\tArtAssets.sprite(self, "ships/" + model.ship_id, player, Vector2.ONE * 40, model.facing.angle(), camera_offset, Color(1.6,1.6,1.6) if hurt_flash > 0 else Color.WHITE)\n'+s[end:]
replace('\t\t\tfor side: float in [-1.0, 1.0]:\n\t\t\t\tdraw_line(player + wing * side * 8, player + wing * side * 8 + model.facing * 27, ship_color, 4, true)\n','')
replace('\t\t\t\tdraw_line(player + model.facing * 9, tip, ship_color, 2, true)\n','')
replace('\t\t\tfor side: float in [-1.0, 1.0]:\n\t\t\t\t_polygon(player + wing * side * 18, 8, 6, ship_color, model.facing.angle())\n','')
replace('\t\t_polygon(pos, 12 if model.evolutions.has("superorbit") else 9, 3 if kind == "blade" else (6 if kind == "frost" else 4), INK if model.dash_time > 0 else orbit_color, angle)\n\t\tif kind == "frost":\n\t\t\tdraw_circle(pos, 3, BG)','\t\tArtAssets.sprite(self, "objects/" + kind, pos, Vector2.ONE * (30 if model.evolutions.has("superorbit") else 23), angle + PI / 2, camera_offset)')
replace('\t\t\t\t_polygon(shot.pos, float(shot.radius) + 4, 4 if kind == "axe" else 6, color, model.elapsed * 5 if kind == "axe" else 0)','\t\t\t\tArtAssets.sprite(self, "objects/" + kind, shot.pos, Vector2.ONE * (float(shot.radius) + 4) * 2.4, model.elapsed * 5 if kind == "axe" else 0, camera_offset)')
replace('\t\t\t\tdraw_circle(pos, 38, Color("245a78"), true, -1, true)\n\t\t\t\tdraw_arc(pos, 39, 0, TAU, 48, CYAN, 2, true)\n\t\t\t\tdraw_arc(pos, 26, -2.8, 0.3, 24, LIME, 8, true)','\t\t\t\tArtAssets.sprite(self, "objects/planet", pos, Vector2.ONE * 90, 0, camera_offset)')
start=s.index('\tfor layer: int in range(3, -1, -1):',s.index('func _draw_orbital_regions'));end=s.index('\nfunc _draw_invasion_markers',start)
s=s[:start]+'''\tfor layer: int in range(4):
		var edge := radius + layer * RunModel.LAYER_WIDTH
		var color: Color = colors[layer]
		draw_arc(center, edge, 0, TAU, 192, Color(color, 0.5), 1.5, true)
		for segment in 24:
			var a := TAU * segment / 24.0
			draw_arc(center, edge + 5, a, a + 0.06, 4, Color(color, 0.25), 5, true)
''' +s[end:]
replace('\t\t_wrap_label(_upgrade_links(id), Rect2(22, 245, 322, 100), 15, CYAN, card)', '''\t\tvar links_scroll := ScrollContainer.new()
		links_scroll.position = Vector2(22, 245)
		links_scroll.size = Vector2(322, 96)
		links_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		links_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
		card.add_child(links_scroll)
		var links_label := Label.new()
		links_label.text = _upgrade_links(id)
		links_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		links_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		links_label.add_theme_font_size_override("font_size",15)
		links_label.add_theme_color_override("font_color",CYAN)
		links_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		links_scroll.add_child(links_label)''')
start=s.index('\tmatch id:',s.index('func _draw_part_icon'));end=s.index('\nfunc _draw_expedition',start)
s=s[:start]+'''\tArtAssets.sprite(self, "objects/" + id, at, Vector2.ONE * 34 * scale, 0, camera_offset)
''' +s[end:]
replace('\t\t\t_label(item.name, Rect2(x + 18, y + 39, 326, 33), 22)','\t\t\t_glyph("achievement", str(item.id), Rect2(x + 18, y + 38, 32, 32), LIME if earned else MUTED)\n\t\t\t_label(item.name, Rect2(x + 58, y + 39, 286, 33), 22)')
p.write_text(s,encoding='utf-8')
p=Path('scripts/item_catalog.gd');s=p.read_text(encoding='utf-8');s=s[:s.index('\tvar lines: Array',s.index('static func draw_icon'))]+'\tArtAssets.icon(canvas, at, id, color, scale)\n';p.write_text(s,encoding='utf-8')
p=Path('export_presets.cfg');s=p.read_text(encoding='utf-8').replace('*.md,.cleanup-archive/*','*.md,.cleanup-archive/*,art_source/*');p.write_text(s,encoding='utf-8')
