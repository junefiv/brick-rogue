extends SceneTree

var game
var elapsed=0.0
var frames=0
var sampled_frames=0
var sample_seconds=0.0
var worst_delta=0.0
var done=false

func _initialize():
	call_deferred("start")

func start():
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	game.start_run(true)
	game.fire()

func _process(delta):
	if game==null or done:
		return false
	elapsed+=delta
	frames+=1
	if elapsed>3:
		sampled_frames+=1
		sample_seconds+=delta
		worst_delta=maxf(worst_delta,delta)
	if game.state=="aim":
		game.direction=Vector2(sin(elapsed),-1).normalized()
		game.fire()
	elif game.state=="upgrade":
		game.model.apply_card(game.cards[0])
		game.resolve_levels()
	elif game.state=="fusion":
		game.model.fuse(game.model.available_fusions()[0])
		game.finish_rewards()
	elif game.state=="forge":
		game.next_round()
	if elapsed>=20:
		done=true
		print("RENDER_SMOKE ",JSON.stringify({"seconds":elapsed,"sample_fps":sampled_frames/sample_seconds,"worst_frame_ms":worst_delta*1000,"hits":game.model.hits,"round":game.model.round_no,"engine_fps":Engine.get_frames_per_second(),"max_physics_callback_ms":game.longest_tick_ms,"note":"Windows AMD OpenGL; not a mobile benchmark. Record concurrent workloads separately."}))
		finish.call_deferred()
	return false

func finish():
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://09-live-play.png")
	game.sound_player.stop()
	game.sound_player.stream=null
	await create_timer(0.15).timeout
	quit()

