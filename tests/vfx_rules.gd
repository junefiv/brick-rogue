extends SceneTree
const Model=preload("res://game/run_model.gd")
const Sim=preload("res://game/ball_simulation.gd")
var checks=0
var failures=0
func check(value: bool, title: String):
	checks+=1
	if not value: failures+=1; printerr("FAIL: ",title)
	else: print("PASS: ",title)
func _initialize(): call_deferred("run")
func run():
	var m=Model.new()
	m.reset()
	m.skills={"ricochet":5}
	var sim=Sim.new()
	sim.setup(m)
	var b=sim.make_ball(Vector2(200,Sim.RETURN_Y),Vector2(300,400),1)
	check(sim.try_ricochet(b,0.159),"Lv5 rebound succeeds below 16 percent")
	check(b.v==Vector2(300,-400) and not b.dead,"Rebound preserves incidence angle and does not recover the ball")
	check(not sim.try_ricochet(b,0.081),"Second rebound probability is halved to 8 percent")
	check(sim.try_ricochet(b,0.079),"Second rebound remains possible below its threshold")
	check(not sim.try_ricochet(b,0.041),"Third rebound probability falls to 4 percent")
	m.skills={}
	check(not sim.try_ricochet(b,0.0),"No floor bounce without rebound skill")
	m.skills={"pierce":5}
	m.bricks.clear()
	m.add_brick(3,2,1000,"normal")
	m.add_brick(3,4,1000,"normal")
	var arrow=sim.make_ball(Vector2(360,850),Vector2(0,-850),1)
	arrow.piercing=true
	sim.balls=[arrow]
	sim.count=0
	sim.rebuild_grid()
	for i in range(80): sim.step(1.0/120)
	check(m.bricks[0].hp<1000 and m.bricks[1].hp<1000,"A single launch-assigned arrow pierces two distinct bricks")
	check(arrow.piercing,"Piercing flag remains set after multiple impacts")
	m.bricks.clear()
	for row in range(3):
		for col in range(3): m.add_brick(col,row,100,"normal")
	var center=m.bricks[4]
	check(m.blast_neighbors(center,false).size()==4,"Lv1-3 explosion targets exactly four cardinal neighbors")
	check(m.blast_neighbors(center,true).size()==8,"Lv4-5 explosion targets exactly eight neighbors")
	m.schedule_hit(center,10,"bomb_drop",0.3)
	m.tick_delayed(0.29)
	m.drain_events()
	check(center.hp==100,"Bomb cannot damage before landing")
	m.tick_delayed(0.02)
	m.drain_events()
	check(center.hp==90,"Bomb damage occurs on landing")
	m.skills={"split":5}
	sim.pending_children.clear()
	sim.try_split(b,0.014)
	check(sim.pending_children.size()==1,"Lv5 split succeeds below 1.5 percent")
	var child=sim.pending_children[0]
	check(child.split and is_equal_approx(child.weight,b.weight*0.6),"Child has distinct visual flag and 60 percent damage")
	sim.try_split(child,0.0)
	check(sim.pending_children.size()==2,"Split children can split without a generation cap")
	sim.try_split(b,0.016)
	check(sim.pending_children.size()==2,"Split fails above its probability")
	var path=sim.laser_path(Vector2(1,-0.001))
	var d: Vector2=(path[1]-path[0]).normalized()
	check(absf(rad_to_deg(atan2(d.x,-d.y)))<=50.01,"Laser cannot be aimed flatter than 40 degrees above horizontal")
	check(path.size()<=4,"Laser reflection count is bounded to two side-wall reflections")
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/vfx_catalog.json"))
	var ids={}
	for item in catalog: ids[item.id]=true
	check(catalog.size()==114 and ids.size()==114,"114 unique effect recipes")
	check(catalog.filter(func(e): return e.category=="passive_fusion").size()==66,"66 passive fusion recipes")
	check(catalog.filter(func(e): return e.category=="active_fusion").size()==28,"28 active fusion recipes")
	print("VFX_RULES: ",checks," checks, ",failures," failures")
	quit(failures)
