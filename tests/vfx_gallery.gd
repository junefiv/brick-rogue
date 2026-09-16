extends SceneTree

var game

func _initialize():
	call_deferred("run")

func capture(name: String):
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://"+name+".png")

func add(kind: String, p: Vector2, color: Color, radius: float = 70, extra: Dictionary = {}):
	game.model.vfx_budget=100
	game.model.emit_effect(p,color,radius,kind,2.0,extra)
	game.model.effects.back().life=1.25

func run():
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.start_run(true)
	await process_frame
	game.model.effects.clear()
	add("power",Vector2(105,350),Color("ffbf69"),55)
	add("critical",Vector2(245,350),Color("ffbf69"),60)
	add("pierce",Vector2(385,350),Color("6fbbff"),65,{"direction":Vector2(0.7,-1).normalized()})
	add("rebound",Vector2(620,350),Color("53f5d0"),60,{"normal":Vector2.LEFT})
	add("frost",Vector2(105,535),Color("96edff"),70)
	add("lightning",Vector2(300,540),Color("c5a1ff"),70,{"from":Vector2(210,430)})
	add("multiball",Vector2(520,565),Color("53f5d0"),90)
	await capture("vfx-passives")
	game.model.effects.clear()
	add("explosion",Vector2(135,420),Color("ff7d9b"),115)
	add("pierce_bomb",Vector2(360,420),Color("ff4f8b"),130)
	add("orbital_explosion",Vector2(585,420),Color("ffbf69"),120)
	add("bomb_drop",Vector2(180,710),Color("ffbf69"),150,{"from":Vector2(180,480)})
	add("laser",Vector2(640,700),Color("ff4f8b"),80,{"from":Vector2(360,960),"to":Vector2(640,300)})
	await capture("vfx-attacks")
	game.model.effects.clear()
	add("freeze_wave",Vector2(360,610),Color("96edff"),330)
	add("time_stop",Vector2(360,610),Color("c5a1ff"),280)
	await capture("vfx-control")
	game.model.effects.clear()
	var targets=[Vector2(90,390),Vector2(180,460),Vector2(300,350),Vector2(430,520),Vector2(560,400),Vector2(640,600)]
	add("thunder_swarm",Vector2(360,270),Color("c5a1ff"),320,{"targets":targets})
	await capture("vfx-thunder")
	game.model.effects.clear()
	game.model.bricks.clear()
	game.model.round_no=10
	game.model.add_brick(2,0,12,"normal")
	game.model.add_brick(3,1,12,"normal")
	game.model.spawn_row()
	await capture("boss-health")
	print("VFX_GALLERY 15 distinct skill animations rendered")
	quit()
