extends SceneTree

const Model = preload("res://game/run_model.gd")
const Simulation = preload("res://game/ball_simulation.gd")

func _initialize():
	call_deferred("run")

func run():
	var model=Model.new()
	model.reset(true)
	model.rng.seed=20260915
	# Unbreakable targets keep all 63 bricks under load for the full duration.
	for b in model.bricks:
		b.hp=100000000
		b.max_hp=b.hp
	var sim=Simulation.new()
	sim.setup(model)
	sim.cap=96
	sim.fire(Vector2(0.61,-1).normalized())
	var volleys=1
	var memory_start=OS.get_static_memory_usage()
	var peak_memory=memory_start
	var times: Array = []
	var begin=Time.get_ticks_usec()
	var max_balls=0
	for frame in range(108000):
		# Keep 96 balls live continuously, including during return/re-emission.
		while sim.balls.size()<sim.cap:
			sim.balls.append({"p":Vector2(model.launch_x,Simulation.RETURN_Y-0.1),"v":sim.shot_direction*model.config.ball_speed,"weight":sim.weight,"bounce":0,"age":0.0,"ignored":[],"dead":false})
		sim.emitted=sim.count
		model.vfx_budget=16 if frame%2==0 else 0
		model.effects.clear()
		var tick_start=Time.get_ticks_usec()
		sim.step(1.0/120.0)
		times.append((Time.get_ticks_usec()-tick_start)/1000.0)
		max_balls=maxi(max_balls,sim.cap)
		if sim.finished() and not model.has_events():
			volleys+=1
			model.launch_x=clampf(sim.first_return,45,675)
			sim.fire(Vector2(sin(volleys*1.7)*1.8,-1).normalized())
		if frame%12000==0:
			sim.shot_direction=Vector2(sin(frame*0.007+1)*1.8,-1).normalized()
			peak_memory=maxi(peak_memory,OS.get_static_memory_usage())
			print("STRESS ",frame/120,"s / 900s; hits=",model.hits," balls=",sim.balls.size())
	var elapsed=(Time.get_ticks_usec()-begin)/1000000.0
	times.sort()
	var sum_ms=0.0
	for value in times: sum_ms+=value
	var report={"simulated_seconds":900,"wall_seconds":elapsed,"fixed_hz":120,"logical_balls":300,"physical_cap":96,"peak_live_balls":max_balls,"bricks":model.bricks.size(),"volleys":volleys,"hits":model.hits,"step_mean_ms":sum_ms/times.size(),"step_p95_ms":times[int(times.size()*0.95)],"step_p99_ms":times[int(times.size()*0.99)],"step_max_ms":times.back(),"event_queue_peak":model.events_peak,"memory_start_bytes":memory_start,"memory_peak_sampled_bytes":peak_memory,"note":"Desktop headless simulation only. No Android rendering, thermal or GPU performance claim. Timing array contributes approximately 1.7 MB to memory growth."}
	print("STRESS_RESULT ",JSON.stringify(report))
	var out=FileAccess.open("user://stress-result.json",FileAccess.WRITE)
	out.store_string(JSON.stringify(report,"  "))
	out.close()
	quit(0 if max_balls<=96 and model.events_peak<10000 else 1)
