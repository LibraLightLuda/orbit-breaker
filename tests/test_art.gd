extends SceneTree

var game: Node2D
var checks := 0
var failures := 0
var folder := "res://artifacts/candidate/art/final"

func _init() -> void:
	call_deferred("run_checks")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("ART: " + message)

func capture(label: String) -> void:
	game.queue_redraw()
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(folder + "/" + label + ".png") == OK, label)

func fixture(ship: String = "striker", sector: String = "ring") -> void:
	game.run.reset(7801,"normal",ship,sector)
	game.run.elapsed = 260
	game.camera_offset = Vector2.ZERO
	game.hurt_flash = 0
	game.run.orbit_count = 6
	game.run.upgrades = {"power":3,"rapid":3,"orbit":3,"blade":3,"frost":3,"missile":3,"chain":3,"pulse":3}
	for i in 24:
		game.run.spawn_enemy(["chaser","runner","tank","shooter"][i%4],game.run.player + Vector2.from_angle(i*2.399) * (140+i*11))
	game.run.spawn_enemy("boss",game.run.player+Vector2(290,-140))
	game._resume()

func run_checks() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	for ids in [GameContent.SHIP_IDS,GameContent.SECTOR_IDS,GameContent.EVOLUTION_IDS,RunModel.UPGRADE_IDS,ItemCatalog.IDS,Expedition.PART_IDS,Expedition.RECIPE_IDS,GameContent.MODE_IDS,["restore","burst","fortune","survive","outer","outer_kills","returns","dash_hits","overdrive"]]:
		for id: String in ids:
			var prefix := "ships/" if id in GameContent.SHIP_IDS else ("world/" if id in GameContent.SECTOR_IDS else "ui/")
			check(ArtAssets.TEXTURES.has(prefix+id),"bound content id " + prefix + id)
	for entry: Dictionary in Achievements.catalog():
		check(ArtAssets.TEXTURES.has("ui/" + ArtAssets.achievement_icon(entry.id)),"achievement " + entry.id)
	for key: String in ArtAssets.TEXTURES:
		var texture: Texture2D = ArtAssets.TEXTURES[key]
		check(texture.get_width() > 0 and texture.get_width() <= 2048, "texture dimensions " + key)
		if not key.begins_with("world/") and not key.begins_with("ui/"):
			var im := texture.get_image()
			check(im.get_pixel(0,0).a == 0 and im.get_pixel(im.get_width()-1,im.get_height()-1).a == 0,"alpha padding " + key)
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.records.load_data("user://art_fixture_%d.json" % Time.get_ticks_usec())
	game.sound.set_muted(true)
	await process_frame
	for sector: String in GameContent.SECTOR_IDS:
		fixture("striker",sector)
		game.run.enemies.back().hp *= 0.4
		await capture("sector-"+sector)
	for ship: String in GameContent.SHIP_IDS:
		var first_body := PackedByteArray()
		for rank in [1,2]:
			fixture(ship)
			game.run.parts={"core":rank,"drive":rank,"shell":rank}
			game.run.hull_forms.assign(Expedition.RECIPE_IDS)
			await capture("forms-"+ship+"-"+str(rank))
			if DisplayServer.get_name()!="headless":
				var im := root.get_texture().get_image()
				var body := im.get_region(Rect2i(im.get_size()/2-Vector2i(60,60),Vector2i(120,120))).get_data()
				if rank==1: first_body=body
				else: check(first_body!=body,"rank I/II physical attachments differ: "+ship)
	fixture()
	game.run.enemies[0].flash=1.0
	game.run.enemies[1].slow_time=2.0
	game.run.enemies[2].stun_time=2.0
	for i in 2:
		var elite: Dictionary=game.run.spawn_enemy("elite",game.run.player+Vector2(-140+i*280,65))
		elite.elite_index=i+1
	await capture("elite-statuses")
	fixture()
	game.run.gems.append({"pos":game.run.player+Vector2(-65,50),"kind":"heal","value":1})
	game.run.gems.append({"pos":game.run.player+Vector2(65,50),"kind":"xp","value":1})
	await capture("legacy-recovery-gem")
	for id: String in GameContent.EVOLUTION_IDS:
		fixture("bastion" if id == "citadel" else ("scout" if id == "wake" else "striker"))
		game.run.evolutions.assign([id])
		game.run.parts = {"core":2,"drive":2,"shell":2}
		game.run.hull_forms.assign(Expedition.RECIPE_IDS)
		for kind: String in ["sentry","mine","wake"]:
			var count := 3 if kind=="sentry" else (8 if kind=="mine" else 6)
			if id != {"sentry":"sentry","mine":"minefield","wake":"wake"}[kind]: continue
			for i in count:
				game.run._deploy(kind, game.run.player + Vector2.from_angle(i*TAU/count)*140,14.0,14.0 if kind=="sentry" else (12.0 if kind=="mine" else 24.0))
		if id == "hatchet": game.run.shots.append({"kind":"axe","pos":game.run.player+Vector2(150,0),"radius":12,"ttl":3,"friendly":true,"returning":true})
		if id in ["storm","nova","citadel"]: game.run._effect(game.run.player,"lightning" if id=="storm" else "pulse",195,0.5,game.run.player+Vector2(180,-80))
		await capture("evolution-"+id)
	fixture()
	game.run.enemies.clear()
	for i in ItemCatalog.IDS.size():
		for rank in 3:
			game.run.items.append({"id":ItemCatalog.IDS[i],"grade":ItemCatalog.GRADES[rank],"pos":Vector2(100+i%6*215,260+floori(i/6.0)*240+rank*62),"ttl":8.0+rank})
	await capture("items-36-grades")
	for kind: String in ["lane","blast","black_hole","planet","meteor","flare"]:
		for active in [false,true]:
			fixture("scout","storm" if kind=="lane" else "forge")
			game.run.hazards.clear()
			if RunModel.ENCOUNTERS.has(kind):
				game.run._add_encounter(kind,game.run.player+Vector2(160,0))
				game.run.hazards.back().active = active
				game.run.hazards.back().ttl = 1.5 if kind=="flare" else 8.0
				game.run.hazards.back().hold = 6.0
			else:
				game.run.hazards.append({"kind":kind,"pos":game.run.player+Vector2(160,0),"radius":90.0,"rect":Rect2(400,300,480,90),"active":active,"warn":0.7,"ttl":0.5})
			await capture("event-"+kind+("-active" if active else "-warn"))
	fixture()
	game.run._effect(game.run.player+Vector2(90,0),"death",50,0.5)
	game.run._effect(game.run.player+Vector2(-90,0),"hit",20,0.2)
	await capture("impact-fx")
	game.run.effects.clear()
	game._show_pause()
	game.queue_redraw()
	for i in 8: await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var before: int = hash(root.get_texture().get_image().get_data())
		root.get_texture().get_image().save_png(folder+"/pause-before.png")
		for i in 20: await process_frame
		game.queue_redraw()
		await RenderingServer.frame_post_draw
		check(before==hash(root.get_texture().get_image().get_data()),"pause freezes entire rendered combat")
		root.get_texture().get_image().save_png(folder+"/pause-after.png")
	game._confirm_abandon()
	await capture("abandon-confirm")
	game._show_credits()
	await capture("credits")
	fixture()
	game.run.state="upgrade"
	game.choices.assign(["power","orbit","repair"])
	game._show_upgrades(true)
	await process_frame
	var scrollers: Array[Node] = game.ui.find_children("*","ScrollContainer",true,false)
	check(scrollers.size()==3,"each upgrade has bounded evolution links")
	if not scrollers.is_empty():
		var scroll: ScrollContainer = scrollers[0]
		check(scroll.get_child(0).text == game._upgrade_links("power"),"complete evolution conditions retained")
		check(scroll.position.y+scroll.size.y<=scroll.get_parent().size.y,"links fit card")
		check(scroll.get_v_scroll_bar().max_value>scroll.size.y,"overflow scrolls")
	await capture("upgrade-scroll")
	if DisplayServer.get_name()!="headless":
		var original_size := root.size
		for dimensions in [Vector2i(390,844),Vector2i(844,390)]:
			root.size=dimensions
			for i in 3: await process_frame
			game._show_upgrades(true)
			for i in 3: await process_frame
			var compact: ScrollContainer=game.ui.get_node("CompactScroll")
			var sequence: Array=[]
			for child in compact.get_child(0).get_children():
				if child is Button: sequence.append(child)
			check(sequence.size()==6,"three compact cards and selection targets")
			for i in 3:
				check(sequence[i*2].text.is_empty() and sequence[i*2+1].text.contains("[%d]" % (i+1)),"compact selection follows its card")
			var links: ScrollContainer=sequence[0].find_children("*","ScrollContainer",true,false)[0]
			check(links.get_child(0).text==game._upgrade_links("power"),"compact retains all power evolution links")
			check(links.get_child(0).get_theme_font_size("font_size")>=18,"compact links readable font")
			await capture("upgrade-%dx%d-top" % [dimensions.x,dimensions.y])
			links.scroll_vertical=int(links.get_v_scroll_bar().max_value)
			compact.scroll_vertical=maxi(0,int(sequence[1].position.y)-dimensions.y+90)
			await capture("upgrade-%dx%d-links-bottom" % [dimensions.x,dimensions.y])
		root.size=original_size
		for i in 3: await process_frame
	game._show_menu()
	game._clear_ui()
	game.screen = "settings"
	var icon_keys: Array[String] = []
	for key: String in ArtAssets.TEXTURES:
		if key.begins_with("ui/"): icon_keys.append(key.trim_prefix("ui/"))
	for i in icon_keys.size():
		var at := Vector2(28+(i%10)*125,20+floori(i/10.0)*100)
		game._glyph("upgrade",icon_keys[i],Rect2(at,Vector2(54,54)))
		game._label(icon_keys[i],Rect2(at+Vector2(0,58),Vector2(124,22)),13)
	await capture("icon-catalog")
	if "--performance" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless":
		await moving_benchmark()
	print("ART SELF-CHECK: %d / %d assertions passed" % [checks-failures,checks])
	game.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)

func moving_benchmark() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps=0
	var results: Array = []
	for trial in 3:
		fixture("bastion","storm")
		game.ghost=GhostReplay.new()
		game.mouse_active=false
		game.run.hp=1.0e9
		game.run.max_hp=1.0e9
		game.run._spawn_timer=1.0e6
		game.run.enemies.clear()
		for i in 240:
			var e: Dictionary=game.run.spawn_enemy("tank",game.run.player+Vector2.from_angle(i*2.399)*(260+i*1.5))
			e.hp=1.0e9
			e.max_hp=1.0e9
		for kind: String in ["sentry","mine","wake"]:
			for i in (3 if kind=="sentry" else (8 if kind=="mine" else 6)):
				game.run._deploy(kind,game.run.player+Vector2.from_angle(i)*180,18,14)
		for i in 223:
			game.run.shots.append({"pos":game.run.player+Vector2.from_angle(i)*350,"velocity":Vector2.from_angle(i+PI/2)*50,"friendly":false,"radius":7,"damage":0,"ttl":30.0})
		for i in 300:
			game.run.gems.append({"pos":game.run.player+Vector2.from_angle(i*2.399)*(330+i*.8),"kind":"xp","value":1})
		game.run._add_encounter("black_hole",game.run.player+Vector2(240,150))
		var samples: Array[int]=[]
		var min_enemies:=240
		var min_shots:=240
		for frame in 360:
			# Refill natural shot expiry outside the measured interval; installations obey the real cap.
			while game.run.shots.size()<240:
				game.run.shots.append({"pos":game.run.player+Vector2(350,0),"velocity":Vector2(0,50),"friendly":false,"radius":7,"damage":0,"ttl":30.0})
			var started := Time.get_ticks_usec()
			game.run.state="playing"
			game._physics_process(1.0/60.0)
			while game.run.shots.size()<240:
				game.run.shots.append({"pos":game.run.player+Vector2(350,0),"velocity":Vector2(0,50),"friendly":false,"radius":7,"damage":0,"ttl":30.0})
			game.queue_redraw()
			await RenderingServer.frame_post_draw
			if frame>=60: samples.append(Time.get_ticks_usec()-started)
			min_enemies=mini(min_enemies,game.run.enemies.size())
			min_shots=mini(min_shots,game.run.shots.size())
			for shot: Dictionary in game.run.shots:
				if shot.get("kind","") in ["wake","mine","sentry"]: shot.ttl=18.0
			samples.sort()
		var result := {"trial":trial+1,"samples":samples.size(),"p95_ms":samples[284]/1000.0,"p99_ms":samples[296]/1000.0,"max_ms":samples.back()/1000.0,"min_enemies":min_enemies,"min_shots":min_shots,"gems":game.run.gems.size(),"texture_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED),"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"renderer":RenderingServer.get_video_adapter_name(),"window":str(root.size),"note":"full main._physics_process + render, includes HUD and ghost capture; muted Dummy audio; 240 enemies/240 shots, synthetic combined 3 sentry+8 mine+6 wake, 300 gems; pre/post-step refill"}
		results.append(result)
		print("ART MOVING PERFORMANCE: "+JSON.stringify(result))
		await capture("moving-density")
	var f:=FileAccess.open(folder+"/moving-performance.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(results,"  "))
