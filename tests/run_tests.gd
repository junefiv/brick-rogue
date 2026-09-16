extends SceneTree

const Model = preload("res://game/run_model.gd")
const Simulation = preload("res://game/ball_simulation.gd")
var failures: Array = []
var checks = 0

func check(condition: bool, label: String):
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: ", label)
	else:
		print("PASS: ", label)

func _initialize():
	call_deferred("run")

func run():
	var m = Model.new()
	m.reset()
	m.bricks.clear()
	m.add_brick(2,2,10,"normal")
	m.add_brick(2,3,10,"normal")
	var a = m.bricks[0]
	var b = m.bricks[1]
	m.descend()
	check(a.row==3 and b.row==4 and m.round_no==2,"Round descent moves each brick exactly once")
	a.frozen=1
	m.descend()
	check(a.row==3 and a.frozen==0,"Frozen brick skips exactly one descent")
	m.stop_rounds=1
	var before=b.row
	m.descend()
	check(b.row==before and m.stop_rounds==0,"Time stop suppresses descent")
	m.xp=100
	var levels=0
	while m.consume_level(): levels+=1
	check(levels==4 and m.level==5 and m.xp==7,"XP overflow produces four choices and preserves remainder")
	m.reset()
	m.points=300
	check(m.multiball_cost()==100 and m.buy_multiball() and m.logical_balls()==9 and m.points==200,"One click buys exactly one ball and deducts POINT")
	check(m.multiball_cost()==150 and m.buy_multiball() and m.logical_balls()==10 and m.points==50,"Next ball costs more than the previous ball")
	check(not m.buy_multiball() and m.logical_balls()==10,"Insufficient POINT cannot buy a ball")
	check(not m.card_pool().has("multi"),"Multi Ball is excluded from random level-up cards")
	m.reset()
	m.points=999999
	for i in range(40):
		check(m.buy_multiball(),"Single-ball purchase %d succeeds"%(i+1))
	check(m.skill_level("multi")==0 and m.logical_balls()==48 and m.count_type("passive")==0,"Forty purchased balls use no passive slot and grant no fusion ingredient")
	m.skills={"ricochet":5,"pierce":5,"blast":5,"power":5,"laser":5,"bomb":5,"freeze":5}
	check(m.count_type("passive")==4 and m.count_type("active")==3,"Skill slot caps")
	check(not m.apply_card("critical"),"New passive rejected when four slots are full")
	var recipe=m.config.fusions[0]
	check(m.fuse(recipe) and m.count_type("passive")==3 and m.skill_level("pierce_bomb")==1 and not m.skills.has("blast") and not m.skills.has("pierce"),"Fusion consumes two Lv5 skills and creates one Lv1 skill")
	check(not m.dismantle("pierce_bomb"),"Dismantle forbidden outside forge")
	m.boss_killed=true
	m.skills.critical=1
	check(not m.dismantle("pierce_bomb"),"Dismantle rejected with no empty slot")
	m.skills.erase("critical")
	m.skills.blast=1
	check(not m.dismantle("pierce_bomb"),"Dismantle cannot overwrite a reacquired source skill")
	m.skills.erase("blast")
	check(m.dismantle("pierce_bomb") and m.skill_level("blast")==5 and m.skill_level("pierce")==5,"First forge dismantle restores both Lv5 sources")
	m.cooldowns.laser=4
	m.cooldowns.bomb=6
	check(m.fuse(m.config.fusions[2]) and m.cooldowns.orbital_strike==6,"Active fusion retains longest cooldown")
	check(absf(m.adjusted_probability(0.1,3)-0.271)<0.000001,"Weighted proc probability equals 1-(1-p)^weight")
	var rect=Rect2(100,100,80,60)
	var hit=Simulation.sweep_circle(Vector2(0,130),Vector2(1000,0),rect)
	check(absf(hit.t-0.093)<0.00001 and hit.normal==Vector2.LEFT,"Swept collision catches high speed wall crossing")
	hit=Simulation.sweep_circle(Vector2(90,90),Vector2(4,4),rect)
	check(hit.t>1,"Rounded corner rejects expanded-AABB false positive")
	hit=Simulation.sweep_circle(Vector2(80,80),Vector2(40,40),rect)
	check(hit.t<0.5 and absf(hit.normal.length()-1)<0.00001,"Exact corner collision has a unit normal")
	m.reset()
	m.bricks.clear()
	var sim=Simulation.new()
	sim.setup(m)
	sim.fire(Vector2(0.3,-1).normalized())
	var frames=0
	while not sim.finished() and frames<10000:
		sim.step(1.0/120)
		frames+=1
	check(sim.finished() and sim.first_return>=45 and sim.first_return<=675,"All balls return and first-return X is valid")
	check(sim.max_live==8,"Initial volley simulates eight balls")
	m.reset(true)
	sim.cap=96
	sim.fire(Vector2(0.4,-1).normalized())
	check(sim.count==96 and absf(sim.weight*sim.count-300)<0.00001,"300 logical balls preserve total weight under 96 cap")
	m.bricks.clear()
	for i in range(7): m.add_brick(i,0,1,"explosive")
	m.area_damage(Vector2(360,295),1000,10,0,"test")
	var drains=0
	while m.has_events() and drains<100:
		m.drain_events(2)
		drains+=1
	check(not m.has_events() and m.kills==7,"Explosive cascade drains incrementally without losing events")
	m.area_damage(Vector2.ZERO,1000,10,5,"test")
	check(not m.has_events(),"Events beyond chain depth four are rejected")
	m.reset()
	m.bricks.clear()
	m.add_brick(2,0,10,"normal")
	m.add_brick(3,1,10,"normal")
	m.add_brick(4,0,10,"normal")
	m.round_no=10
	m.spawn_row()
	var bosses=m.bricks.filter(func(brick): return brick.kind=="boss")
	check(bosses.size()==1,"Boss spawns once on round ten")
	var boss=bosses[0]
	check(not m.bricks.any(func(brick): return brick.id!=boss.id and m.overlaps_cells(brick,boss.col,boss.row,boss.w,boss.h)),"Boss spawn area never overlaps a regular brick")
	m.reset()
	m.skills={"multi":2,"laser":1}
	m.purchased_balls=16
	m.points=1250
	m.round_no=7
	m.launch_x=198.0
	m.cooldowns={"laser":3}
	m.save_run()
	var expected_rng=m.rng.randf()
	var restored=Model.new()
	check(restored.load_run() and restored.round_no==7 and restored.launch_x==198 and restored.cooldowns.laser==3 and restored.skills.multi==2 and restored.purchased_balls==16 and restored.points==1250,"Round snapshot restores gameplay state and POINT purchases")
	check(restored.rng.randf()==expected_rng,"Save restores deterministic random state")
	var bad=FileAccess.open(Model.SAVE_PATH,FileAccess.WRITE)
	bad.store_string("{corrupted")
	bad.close()
	check(not restored.load_run(),"Corrupt save rejected")
	DirAccess.remove_absolute(Model.SAVE_PATH)
	print("SUMMARY: ",checks," checks, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
