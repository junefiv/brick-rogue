extends SceneTree

var game
var failures=0

func _initialize():
	call_deferred("run")

func check(value: bool, label: String):
	if not value:
		failures+=1
		printerr("FAIL: ",label)
	else:
		print("PASS: ",label)

func tap(point: Vector2):
	var event=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	event.position=game.to_global(point)
	game._input(event)
	event.pressed=false
	game._input(event)
	await process_frame
	await process_frame

func screenshot(name: String):
	await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("user://"+name+".png")

func run():
	game=load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	print("FONT AXES ", game.font.base_font.get_supported_variation_list())
	await screenshot("01-menu")
	await tap(Vector2(300,800))
	check(game.state=="aim","Menu button enters gameplay")
	await screenshot("02-gameplay")
	var event=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=true
	event.position=game.to_global(Vector2(420,700))
	game._input(event)
	check(game.aiming,"Pointer press starts aim")
	await screenshot("03-aim")
	event.pressed=false
	game._input(event)
	check(game.state=="flight","Pointer release fires volley")
	var before=game.model.round_no
	for i in range(20000):
		game._physics_process(1.0/120)
		if game.state!="flight": break
	check(game.state in ["aim","upgrade"],"Volley settles into aim or level selection")
	check(game.model.round_no<=before+1,"Single volley advances no more than one round")
	game.start_run(true)
	await process_frame
	await process_frame
	await tap(Vector2(360,1225))
	check(game.state=="fusion","Fusion ready button opens choice")
	await screenshot("04-fusion")
	await tap(Vector2(360,453))
	check(game.state=="aim" and game.model.skills.has("pierce_bomb"),"Fusion card applies and returns to aim")
	game.model.xp=100
	game.resolve_levels()
	await process_frame
	await process_frame
	check(game.state=="upgrade","XP opens upgrade cards")
	await screenshot("05-upgrade")
	await tap(Vector2(300,440))
	check(game.state=="upgrade","XP overflow opens next choice")
	game.start_run(true)
	game.active("laser")
	check(game.armed=="laser","Targeted active arms before firing")
	game.use_targeted_active()
	check(game.state=="active_resolve" and game.model.cooldowns.laser>=2,"Targeted active enters resolve and starts cooldown")
	while game.model.has_events(): game._physics_process(1.0/120)
	game._physics_process(1.0/120)
	check(game.state=="aim","Active resolution returns to aim without descent")
	game.fire()
	game.previous_state="flight"
	game.state="pause"
	var old_clock=game.sim.clock
	game._physics_process(1.0/120)
	check(game.sim.clock==old_clock,"Pause freezes simulation")
	await screenshot("06-pause")
	game.state="settings"
	await screenshot("07-settings")
	game.state="result"
	await screenshot("08-result")
	print("UI_SUMMARY failures=",failures)
	quit(failures)

