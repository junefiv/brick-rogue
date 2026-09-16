extends SceneTree
var game
func _initialize(): call_deferred("run")
func capture(name: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://"+name+".png")
func run():
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.start_run(true)
	game.model.skills={"power":5,"pierce":5,"rebound":5,"ricochet":5,"bounty":5,"frost":5}
	game.model.assign_bounty()
	for b in game.model.bricks:
		if b.col%2==0: b.frozen=1
	game.sim.balls=[]
	for i in range(9):
		var b=game.sim.make_ball(Vector2(110+i*62,825),Vector2(200,-500),1)
		b.piercing=i%3==0
		b.split=i%3==1
		b.bounce=i
		game.sim.balls.append(b)
	await process_frame
	await process_frame
	game.vfx.emit("critical",Vector2(270,715),Color("ffe58a"))
	game.vfx.emit("ricochet",Vector2(490,880),Color("8ef8dd"))
	await create_timer(.15).timeout
	await capture("vfx-materials")
	game.state="studio"
	for index in range(114):
		game.studio_index=index
		game.vfx.preview_recipe(index)
		# Advance recipe scheduling with real rendered frames, not just data checks.
		for step in range(8):
			game.vfx.tick(.20)
			await process_frame
		if index in [2,8,12,20,86,113]: await capture("vfx-recipe-%03d"%index)
	assert(game.vfx.actors.size()==48)
	assert(game.vfx.ball_views.size()==128)
	print("VFX_SCENE: all 114 recipes rendered; fixed actor and ball pools preserved")
	game.queue_free()
	await process_frame
	quit()
