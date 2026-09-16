extends Node2D

const Model = preload("res://game/run_model.gd")
const Simulation = preload("res://game/ball_simulation.gd")
const MINT = Color("53f5d0")
const INK = Color("0a1424")
const MUTED = Color("7890aa")
const WHITE = Color("eef7ff")
const PURPLE = Color("b59aff")
var font = FontVariation.new()
var style_cache: Dictionary = {}
var model = Model.new()
var sim = Simulation.new()
var state = "menu"
var previous_state = "aim"
var buttons: Array = []
var direction = Vector2(0.3,-1).normalized()
var aiming = false
var drag_start = Vector2.ZERO
var aim_drag_valid = false
var inspected_skill = ""
var inspected_skill_life = 0.0
var armed = ""
var cards: Array = []
var volley_time = 0.0
var animation_time = 0.0
var tier = 1
var sound_on = true
var low_flash = false
var paused_menu = false
var manual_fast = false
var fusion_from_aim = false
var toast = ""
var toast_life = 0.0
var has_save = false
var cleared = false
var hit_cache = 0
var audio_clock = 0.0
var sound_player = AudioStreamPlayer.new()
var simulation_ms = 0.0
var longest_tick_ms = 0.0
var screenshot_requested = false
var vfx = preload("res://ui/vfx_director.gd").new()
var health_layer = preload("res://ui/vfx_health.gd").new()
var studio_index = 0
var echo_in_progress = false

func _ready():
	font.base_font = preload("res://assets/NotoSansKR.ttf")
	font.variation_opentype = {2003265652:550}
	sim.setup(model)
	add_child(vfx)
	add_child(health_layer)
	health_layer.z_index=3
	health_layer.model=model
	health_layer.font=font
	load_settings()
	add_child(sound_player)
	sound_player.volume_db = -19
	sound_player.stream = make_tone()
	has_save = FileAccess.file_exists(Model.SAVE_PATH)
	model.reset()
	if "--screenshot" in OS.get_cmdline_user_args():
		start_run(true)
		screenshot_requested = true
	if "--autoplay" in OS.get_cmdline_user_args():
		start_run(true)
		fire()

func make_tone() -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.mix_rate = 22050
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	var bytes = PackedByteArray()
	bytes.resize(2205 * 2)
	for i in range(2205):
		var envelope = pow(1.0 - float(i) / 2205, 3)
		var sample = int(sin(float(i) / 22050 * TAU * 740) * envelope * 18000)
		bytes.encode_s16(i * 2, sample)
	wav.data = bytes
	return wav

func _exit_tree():
	sound_player.stop()
	sound_player.stream = null

func load_settings():
	var settings = ConfigFile.new()
	if settings.load("user://settings.cfg") == OK:
		tier = clampi(settings.get_value("settings", "tier", 1), 0, 2)
		sound_on = settings.get_value("settings", "sound", true)
		low_flash = settings.get_value("settings", "low_flash", false)
	sim.cap = model.config.physical_caps[tier]

func save_settings():
	var settings = ConfigFile.new()
	settings.set_value("settings", "tier", tier)
	settings.set_value("settings", "sound", sound_on)
	settings.set_value("settings", "low_flash", low_flash)
	settings.save("user://settings.cfg")
	sim.cap = model.config.physical_caps[tier]

func _notification(what):
	if what == NOTIFICATION_APPLICATION_PAUSED and state not in ["menu", "pause", "settings", "result"]:
		previous_state = state
		state = "pause"
		aiming = false
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if state == "pause":
			state = previous_state
		elif state not in ["menu", "result", "settings"]:
			previous_state = state
			state = "pause"

func start_run(lab: bool = false, resume: bool = false):
	vfx.clear()
	echo_in_progress=false
	model.reset(lab)
	if resume and not model.load_run():
		notify("저장을 읽을 수 없어 새 게임을 시작합니다.")
	state = "aim"
	armed = ""
	aiming = false
	manual_fast = false
	cleared = false
	sim.balls.clear()
	sim.rebuild_grid()
	if not lab:
		model.save_run()
	has_save = FileAccess.file_exists(Model.SAVE_PATH)

func notify(message: String):
	toast = message
	toast_life = 3

func purchase_ball():
	var price = model.multiball_cost()
	if model.buy_multiball():
		notify("공 +1 구매 · %d POINT 사용 · 현재 %d개" % [price, model.logical_balls()])
		model.save_run()
	elif model.logical_balls() >= model.config.ball_cap:
		notify("공 최대 수량에 도달했습니다.")
	elif model.points < price:
		notify("POINT가 부족합니다. 필요 %d / 보유 %d" % [price, model.points])
	else:
		notify("패시브 슬롯이 가득 찼습니다.")

func _process(delta):
	var viewport_size = get_viewport_rect().size
	var usable = Rect2(Vector2.ZERO, viewport_size)
	if OS.get_name() in ["Android", "iOS"]:
		var window_size = Vector2(DisplayServer.window_get_size())
		var safe = Rect2(DisplayServer.get_display_safe_area())
		if window_size.x > 0 and window_size.y > 0 and safe.size.x > 0 and safe.size.y > 0:
			var ratio = viewport_size / window_size
			usable = Rect2(safe.position * ratio, safe.size * ratio).intersection(usable)
	# Fill the whole safe display area. The previous uniform fit centered a
	# 16:9 canvas and produced large unused bands on tall Android screens.
	scale = Vector2(usable.size.x / 720.0, usable.size.y / 1280.0)
	position = usable.position
	animation_time += delta
	toast_life = maxf(0, toast_life - delta)
	inspected_skill_life = maxf(0, inspected_skill_life - delta)
	# Accessibility reduces flashes/particles, not readable impact and rebound cues.
	model.vfx_budget = model.config.vfx_caps[tier]
	if state not in ["pause","settings"]:
		for effect in model.effects:
			effect.life -= delta
		model.effects = model.effects.filter(func(effect): return effect.life > 0)
		for b in model.bricks:
			b.flash = maxf(0, b.flash - delta)
	if state == "flight":
		volley_time += delta
		audio_clock += delta
		if sound_on and model.hits > hit_cache and audio_clock > 0.08:
			sound_player.pitch_scale = 0.8 + minf(0.7, (model.hits - hit_cache) * 0.025)
			sound_player.play()
			hit_cache = model.hits
			audio_clock = 0
	var scene_visible = state in ["aim","flight","active_resolve","resolve","studio"]
	vfx.visible=scene_visible
	health_layer.visible=scene_visible and state!="studio"
	vfx.process_mode=Node.PROCESS_MODE_INHERIT if scene_visible else Node.PROCESS_MODE_DISABLED
	if state=="studio":
		vfx.set_speed(1.0)
		vfx.tick(delta)
	elif scene_visible:
		var fx_speed=4.0 if state=="flight" and (volley_time>=9 or manual_fast) else (2.0 if state=="flight" and volley_time>=6 else 1.0)
		vfx.sync(model,sim,delta*fx_speed,tier,low_flash)
		vfx.set_speed(fx_speed)
		health_layer.queue_redraw()
	queue_redraw()
	if screenshot_requested and animation_time > 1:
		screenshot_requested = false
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://preview.png")
		print("SCREENSHOT: ", ProjectSettings.globalize_path("user://preview.png"))
		get_tree().quit()

func _physics_process(delta):
	if state == "flight":
		var began = Time.get_ticks_usec()
		var speed = 4 if volley_time >= 9 or manual_fast else (2 if volley_time >= 6 else 1)
		for substep in range(speed):
			sim.step(delta)
			if sim.finished() and not model.has_events():
				if model.echo_ready and not echo_in_progress:
					echo_in_progress=true
					model.echo_ready=false
					sim.fire(direction)
					sim.count=maxi(1,int(sim.count*(0.2+0.1*model.skill_level("echo"))))
					sim.weight*=0.6
					model.emit_effect(Vector2(model.launch_x,900),PURPLE,60,"echo",0.7)
					break
				model.shot_boost=0.0
				for b in model.bricks: b.marked=0.0
				model.launch_x = sim.first_return if sim.first_return >= 0 else model.launch_x
				state = "resolve"
				resolve_levels()
				break
		simulation_ms = (Time.get_ticks_usec() - began) / 1000.0
		longest_tick_ms = maxf(longest_tick_ms, simulation_ms)
	elif state == "active_resolve":
		model.tick_delayed(delta)
		model.drain_events()
		if not model.has_events():
			state = "aim"
			sim.rebuild_grid()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if state == "pause":
			state = previous_state
		elif state in ["aim", "flight", "upgrade", "fusion", "forge"]:
			previous_state = state
			state = "pause"
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var point = to_local(event.position)
		if event.pressed:
			for button in buttons:
				if button.rect.has_point(point):
					button.action.call()
					return
			if state == "aim" and Rect2(38,150,644,780).has_point(point):
				drag_start = point
				aiming = true
				aim_drag_valid = false
		elif aiming:
			aiming = false
			if state == "aim":
				if not aim_drag_valid:
					notify("아래로 드래그해 방향을 정한 뒤 손을 놓으세요.")
				elif armed != "":
					use_targeted_active()
				else:
					fire()
	if event is InputEventMouseMotion and aiming and state == "aim":
		update_direction(to_local(event.position))

func update_direction(point: Vector2):
	# A single slingshot gesture avoids the old direct/slingshot mode switch,
	# which made the guide flip when the pointer crossed the drag origin.
	var aim = drag_start - point
	if aim.length() < 18:
		return
	aim_drag_valid = true
	aim.y = -maxf(absf(aim.y), absf(aim.x) * tan(deg_to_rad(12)))
	direction = aim.normalized()

func show_skill_info(id: String, seconds: float = 5.0):
	if not model.config.skills.has(id):
		return
	inspected_skill = id
	inspected_skill_life = seconds

func choose_upgrade(id: String):
	if model.apply_card(id):
		show_skill_info(id, 7.0)
		var spec = model.config.skills[id]
		notify("%s Lv.%d 장착 · %s" % [spec.name, model.skill_level(id), spec.description])
	resolve_levels()

func fire():
	if state != "aim":
		return
	state = "flight"
	echo_in_progress=false
	volley_time = 0
	manual_fast = false
	hit_cache = model.hits
	sim.fire(direction)

func resolve_levels():
	if model.consume_level():
		cards = model.draw_cards()
		if cards.is_empty():
			model.points += 500
			resolve_levels()
		else:
			state = "upgrade"
		return
	if not model.available_fusions().is_empty():
		fusion_from_aim = false
		state = "fusion"
		return
	finish_rewards()

func finish_rewards():
	if model.boss_killed:
		state = "forge"
	else:
		next_round()

func next_round():
	model.boss_killed = false
	if model.final_dead and not model.endless:
		cleared = true
		state = "result"
		delete_save()
		return
	model.descend()
	if model.lab and model.is_dead():
		model.bricks.clear()
		for row in range(9):
			for col in range(7):
				model.add_brick(col,row,500,"normal")
		notify("테스트 필드 재생성 · 현재 빌드는 유지됩니다.")
	if model.is_dead():
		cleared = false
		state = "result"
		delete_save()
		return
	state = "aim"
	armed = ""
	model.save_run()
	sim.rebuild_grid()

func delete_save():
	if not model.lab and FileAccess.file_exists(Model.SAVE_PATH):
		DirAccess.remove_absolute(Model.SAVE_PATH)
	has_save = FileAccess.file_exists(Model.SAVE_PATH)

func active(id: String):
	if state != "aim":
		return
	show_skill_info(id)
	if int(model.cooldowns.get(id, 0)) > 0:
		notify("%s 쿨다운 · %d라운드 후 다시 사용" % [model.config.skills[id].name, model.cooldowns[id]])
		return
	if id in ["laser", "bomb", "orbital_strike", "mark", "pulse"]:
		armed = "" if armed == id else id
		notify("방향을 조준하고 손을 놓으세요. 다시 누르면 취소합니다.")
		return
	if id in ["overclock","echo"]:
		if id=="overclock": model.shot_boost=0.05+0.05*model.skill_level(id)
		else: model.echo_ready=true
		model.emit_effect(Vector2(model.launch_x,870),Color(model.config.skills[id].color),60,id,0.7)
	elif id=="missile":
		var targets=model.bricks.filter(func(b): return b.hp>0)
		targets.sort_custom(func(a,b): return a.hp>b.hp)
		for i in range(3+model.skill_level(id)):
			if targets.is_empty(): break
			model.schedule_hit(targets[i%targets.size()],(3+model.skill_level(id))*model.damage(),"missile",0.3)
	elif id == "freeze":
		for b in model.bricks:
			b.frozen = maxi(1, b.frozen)
		model.emit_effect(Vector2(360, 620), Color("96edff"), 330, "freeze_wave", 1.1)
	elif id == "stop":
		model.stop_rounds = maxi(1, model.stop_rounds)
		model.emit_effect(Vector2(360, 610), Color("c5a1ff"), 290, "time_stop", 1.15)
	consume_active(id)
	state = "active_resolve"

func consume_active(id: String):
	model.cooldowns[id] = maxi(2, int(model.config.skills[id].cooldown) - int((model.skill_level(id) - 1) / 2))


func use_targeted_active():
	var id=armed
	armed=""
	var level=model.skill_level(id)
	if id in ["laser","orbital_strike"]:
		var path=sim.laser_path(direction)
		var struck: Dictionary={}
		for i in range(path.size()-1):
			model.emit_effect(path[i+1],Color("ff9bbc"),80,"laser",0.6,{"from":path[i],"to":path[i+1]})
			for b in model.bricks:
				if not struck.has(b.id) and Simulation.sweep_circle(path[i],path[i+1]-path[i],model.brick_rect(b),4).t<=1:
					struck[b.id]=true
					model.enqueue(b,(8+4*level)*model.damage(),0,"active")
					if id=="orbital_strike": model.schedule_hit(b,18*model.damage(),"bomb_drop",0.3)
	else:
		var path=sim.aim_path(direction)
		var point: Vector2=path.back()
		var targets=model.bricks.filter(func(b): return b.hp>0)
		targets.sort_custom(func(a,b): return model.brick_rect(a).get_center().distance_squared_to(point)<model.brick_rect(b).get_center().distance_squared_to(point))
		if not targets.is_empty():
			var target=targets[0]
			if id=="mark":
				target.marked=0.15+0.15*level
				model.emit_effect(model.brick_rect(target).get_center(),Color("ff677a"),70,"mark",0.6)
			elif id=="pulse":
				var center=model.brick_rect(target).get_center()
				model.emit_effect(center,Color("b6efff"),60,"pulse",0.6,{"from":Vector2(45,center.y),"to":Vector2(675,center.y)})
				model.emit_effect(center,Color("b6efff"),60,"pulse",0.6,{"from":Vector2(center.x,157),"to":Vector2(center.x,928)})
				for b in targets:
					if b.col==target.col or b.row==target.row: model.enqueue(b,(3+3*level)*model.damage(),0,"active")
			else:
				for b in targets:
					if model.brick_rect(b).get_center().distance_to(point)<=150+10*(level-1):
						model.schedule_hit(b,(10+5*level)*model.damage(),"bomb_drop",0.3)
	consume_active(id)
	state="active_resolve"

func text_at(value: String, point: Vector2, size: int = 22, color: Color = WHITE):
	draw_string(font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func centered(value: String, y: float, size: int = 24, color: Color = WHITE):
	var width = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text_at(value, Vector2((720-width)/2, y), size, color)

func panel(rect: Rect2, fill: Color = INK, stroke: Color = Color("20334b"), radius: int = 16):
	# Quantized colors keep the cache bounded even while hit flashes fade.
	var key = fill.to_html() + stroke.to_html() + str(radius)
	var style = style_cache.get(key)
	if style == null:
		style = StyleBoxFlat.new()
		style.bg_color = fill
		style.border_color = stroke
		style.set_border_width_all(1)
		style.set_corner_radius_all(radius)
		if style_cache.size() > 512:
			style_cache.clear()
		style_cache[key] = style
	draw_style_box(style, rect)

func draw_bolt(from: Vector2, to: Vector2, color: Color, alpha: float, width: float, seed_value: float):
	var points = PackedVector2Array([from])
	var direction_line = to - from
	var perpendicular = direction_line.normalized().orthogonal()
	for i in range(1, 7):
		var ratio = float(i) / 7.0
		var jitter = sin(seed_value * 0.37 + i * 7.13) * 13.0 * sin(PI * ratio)
		points.append(from.lerp(to, ratio) + perpendicular * jitter)
	points.append(to)
	draw_polyline(points, Color(color, alpha * 0.28), width + 6, true)
	draw_polyline(points, Color(color, alpha), width, true)
	draw_polyline(points, Color(WHITE, alpha * 0.85), maxf(1, width * 0.3), true)

func draw_ice_overlay(rect: Rect2):
	draw_rect(rect.grow(-2), Color("96edff", 0.18))
	for i in range(4):
		var x = rect.position.x + 10 + i * maxf(10, (rect.size.x - 20) / 4.0)
		draw_line(Vector2(x, rect.end.y - 4), Vector2(x + 18, rect.position.y + 5), Color("d9fbff", 0.7), 2, true)
	var center = rect.get_center()
	for angle in range(0, 360, 60):
		var dir = Vector2.RIGHT.rotated(deg_to_rad(angle))
		draw_line(center, center + dir * minf(18, rect.size.y * 0.26), Color("e9fdff", 0.85), 1.5, true)

func draw_skill_effect(effect: Dictionary):
	var duration = maxf(0.001, float(effect.get("duration", 0.5)))
	var t = clampf(1.0 - float(effect.life) / duration, 0, 1)
	var alpha = clampf(float(effect.life) / duration, 0, 1)
	var p: Vector2 = effect.p
	var color: Color = effect.color
	var radius = float(effect.r)
	var seed_value = float(effect.get("seed", 1))
	match String(effect.get("kind", "burst")):
		"multiball":
			for i in range(10):
				var dir = Vector2.UP.rotated((i - 4.5) * 0.17)
				var orb = p + dir * (18 + 72 * t)
				draw_circle(orb, 5 + 2 * (1-t), Color(WHITE, alpha))
				draw_circle(orb, 10, Color(color, alpha * 0.22), false, 3, true)
		"power":
			for i in range(8):
				var dir = Vector2.RIGHT.rotated(i * TAU / 8.0)
				draw_line(p + dir * 5, p + dir * radius * (0.5 + t), Color(color, alpha), 3, true)
			draw_colored_polygon(PackedVector2Array([p+Vector2(0,-13),p+Vector2(10,0),p+Vector2(0,13),p+Vector2(-10,0)]), Color(WHITE, alpha * 0.8))
		"critical":
			draw_line(p+Vector2(-radius,-radius)*0.45,p+Vector2(radius,radius)*0.45,Color(color,alpha),5,true)
			draw_line(p+Vector2(radius,-radius)*0.45,p+Vector2(-radius,radius)*0.45,Color(WHITE,alpha),3,true)
			text_at("CRIT",p+Vector2(-22,-31-18*t),15,Color(color,alpha))
		"pierce":
			var dir: Vector2 = effect.get("direction", Vector2.UP)
			draw_line(p-dir*55,p+dir*70,Color(color,alpha*0.35),10,true)
			draw_line(p-dir*45,p+dir*62,Color(WHITE,alpha),2,true)
			var side = dir.orthogonal()
			draw_colored_polygon(PackedVector2Array([p+dir*68,p+dir*45+side*10,p+dir*45-side*10]),Color(color,alpha))
		"rebound":
			var normal: Vector2 = effect.get("normal", Vector2.RIGHT)
			for i in range(3):
				var spread = (i-1)*0.28
				draw_line(p,p+normal.rotated(spread)*(25+radius*t),Color(color,alpha*(1.0-i*0.16)),3,true)
			draw_arc(p,12+radius*t,-PI*0.75,PI*0.75,16,Color(color,alpha),2,true)
		"lightning":
			draw_bolt(effect.get("from",p-Vector2(0,100)),p,color,alpha,4,seed_value)
			draw_circle(p,10+16*t,Color(color,alpha*0.18))
		"lightning_chain":
			var chain_points: Array=effect.get("points",[])
			for i in range(chain_points.size()-1):
				draw_bolt(chain_points[i],chain_points[i+1],color,alpha,3.5,seed_value+i*17)
				if i>0:
					draw_circle(chain_points[i],8+10*t,Color(color,alpha*0.18))
		"thunder_swarm":
			draw_rect(Rect2(38,150,644,780),Color("8e73ff",alpha*0.08))
			var targets: Array = effect.get("targets",[])
			for i in range(mini(18,targets.size())):
				draw_bolt(Vector2(targets[i].x,260),targets[i],color,alpha,3,seed_value+i*13)
		"frost":
			for i in range(6):
				var dir=Vector2.RIGHT.rotated(i*TAU/6.0)
				draw_line(p-dir*radius*0.35,p+dir*radius*(0.45+t*0.35),Color(color,alpha),2,true)
				draw_line(p+dir*radius*0.35,p+dir*radius*0.2+dir.orthogonal()*8,Color(WHITE,alpha),1,true)
		"freeze_wave":
			var wave_y=lerpf(875,185,t)
			draw_rect(Rect2(38,wave_y-70,644,140),Color(color,alpha*0.12))
			for x in range(48,680,28):
				draw_colored_polygon(PackedVector2Array([Vector2(x,wave_y+12),Vector2(x+14,wave_y-20),Vector2(x+28,wave_y+12)]),Color(color,alpha*0.65))
		"time_stop":
			draw_rect(Rect2(38,150,644,780),Color(color,alpha*0.07))
			draw_arc(p,radius*(0.45+0.25*t),0,TAU,64,Color(color,alpha),5,true)
			draw_line(p,p+Vector2.UP.rotated(-1.1*t)*radius*0.28,Color(WHITE,alpha),4,true)
			draw_line(p,p+Vector2.RIGHT.rotated(-2.6*t)*radius*0.18,Color(color,alpha),3,true)
		"laser":
			var from: Vector2=effect.get("from",p)
			var to: Vector2=effect.get("to",p)
			draw_line(from,to,Color(color,alpha*0.18),22*(1-t*0.5),true)
			draw_line(from,to,Color(color,alpha),7*(1-t*0.4),true)
			draw_line(from,to,Color(WHITE,alpha),2,true)
		"orbital_beam":
			var from: Vector2=effect.get("from",p)
			var to: Vector2=effect.get("to",p)
			draw_line(from,to,Color(color,alpha*0.55),12,true)
			for i in range(6):
				var marker=from.lerp(to,float(i+1)/7.0)
				draw_arc(marker,18+8*t,0,TAU,20,Color(color,alpha),2,true)
		"bomb_drop":
			var from: Vector2=effect.get("from",p-Vector2(0,180))
			if t < 0.48:
				var bomb=from.lerp(p,t/0.48)
				draw_circle(bomb,13,Color("182031",alpha))
				draw_arc(bomb-Vector2(0,12),9,-PI*0.9,-PI*0.2,10,Color("ffbf69",alpha),3,true)
			else:
				var blast_t=(t-0.48)/0.52
				draw_circle(p,radius*blast_t,Color("ffbf69",alpha*0.15))
				draw_arc(p,radius*blast_t,0,TAU,32,Color("ffbf69",alpha),5,true)
		"explosion", "bomb", "pierce_bomb", "orbital_explosion":
			var outer_color=color
			if effect.kind=="pierce_bomb": outer_color=Color("ff4f8b")
			if effect.kind=="orbital_explosion": outer_color=Color("ffbf69")
			draw_circle(p,radius*t,Color(outer_color,alpha*0.16))
			draw_arc(p,radius*t,0,TAU,36,Color(outer_color,alpha),5,true)
			draw_arc(p,radius*t*0.55,0,TAU,28,Color(WHITE,alpha*0.75),2,true)
			for i in range(10):
				var dir=Vector2.RIGHT.rotated(i*TAU/10.0+seed_value*0.01)
				draw_line(p+dir*12,p+dir*radius*t,Color(outer_color,alpha),3,true)
		"shield":
			var poly=PackedVector2Array()
			for i in range(6): poly.append(p+Vector2.RIGHT.rotated(i*TAU/6.0)*radius*(0.55+0.25*t))
			poly.append(poly[0])
			draw_polyline(poly,Color(color,alpha),4,true)
		"boss_spawn":
			draw_rect(Rect2(38,150,644,140),Color(color,alpha*0.09))
			draw_arc(p,radius*(1-t*0.5),0,TAU,48,Color(color,alpha),6,true)
			centered("BOSS SIGNAL",208,21,Color(color,alpha))
		"shatter", _:
			for i in range(9):
				var dir=Vector2.RIGHT.rotated(i*TAU/9.0+seed_value*0.01)
				draw_line(p+dir*8,p+dir*radius*t,Color(color,alpha),3,true)

func button(rect: Rect2, label: String, action: Callable, primary: bool = false, accent: Color = MINT):
	panel(rect, accent if primary else Color("122037"), accent if primary else Color("2a3b55"), 12)
	var size = 23
	var width = font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	text_at(label, Vector2(rect.position.x+(rect.size.x-width)/2,rect.position.y+rect.size.y/2+8),size,INK if primary else WHITE)
	buttons.append({"rect":rect,"action":action})

func draw_purchase_card():
	var rect = Rect2(38, 944, 644, 88)
	var affordable = model.can_buy_multiball()
	panel(rect, Color("0d2130"), Color(MINT, 0.75 if affordable else 0.25), 14)
	text_at("보유 공", rect.position + Vector2(18, 26), 14, MUTED)
	text_at("%d개" % model.logical_balls(), rect.position + Vector2(18, 62), 27, WHITE)
	text_at("POINT로 공을 1개 구매" , rect.position + Vector2(126, 28), 17, MINT)
	text_at("보유 %d POINT" % model.points, rect.position + Vector2(126, 59), 15, MUTED)
	var buy_rect = Rect2(rect.position + Vector2(392, 10), Vector2(238, 68))
	panel(buy_rect, MINT if affordable else Color("172739"), MINT if affordable else Color("34485c"), 11)
	text_at("공 +1 구매", buy_rect.position + Vector2(23, 29), 20, INK if affordable else MUTED)
	text_at("%d POINT" % model.multiball_cost(), buy_rect.position + Vector2(58, 55), 15, INK if affordable else MUTED)
	buttons.append({"rect": buy_rect, "action": func(): purchase_ball()})

func draw_active_tile(id: String, rect: Rect2):
	var spec = model.config.skills[id]
	var color = Color(spec.color)
	var cd = int(model.cooldowns.get(id, 0))
	var selected = armed == id
	panel(rect, color if selected else Color(color, 0.085), color, 10)
	text_at(spec.name, rect.position + Vector2(10, 24), 16, INK if selected else WHITE)
	var status = "사용 가능" if cd == 0 else "쿨다운 %d라운드" % cd
	text_at(status, rect.position + Vector2(10, 48), 13, INK if selected else (color if cd == 0 else MUTED))
	buttons.append({"rect": rect, "action": func(): active(id)})

func draw_skill_info_panel():
	if inspected_skill_life <= 0 or inspected_skill == "" or not model.config.skills.has(inspected_skill):
		return
	var spec = model.config.skills[inspected_skill]
	var color = Color(spec.color)
	var rect = Rect2(48, 778, 624, 102)
	panel(rect, Color("101e31", 0.97), Color(color, 0.8), 13)
	var type_label = "패시브 · 항상 적용" if spec.type == "passive" else "액티브 · 눌러서 사용"
	text_at("%s  Lv.%d" % [spec.name, model.skill_level(inspected_skill)], rect.position + Vector2(18, 29), 20, color)
	text_at(type_label, rect.position + Vector2(397, 27), 14, MUTED)
	text_at(spec.description, rect.position + Vector2(18, 60), 17, WHITE)
	if spec.type == "active":
		var cd = int(model.cooldowns.get(inspected_skill, 0))
		var cd_text = "지금 사용 가능" if cd == 0 else "남은 쿨다운: %d라운드" % cd
		text_at(cd_text, rect.position + Vector2(18, 86), 14, color if cd == 0 else MUTED)
	else:
		text_at("아래 스킬 칸을 누르면 설명을 다시 볼 수 있습니다.", rect.position + Vector2(18, 86), 14, MUTED)

func _draw():
	buttons.clear()
	draw_rect(Rect2(0,0,720,1280), Color("080f1c"))
	for x in range(0,721,36):
		draw_line(Vector2(x,0),Vector2(x,1280),Color(0.2,0.5,0.7,0.025))
	if state == "menu":
		draw_menu()
	elif state == "settings":
		draw_settings()
	elif state == "studio":
		draw_studio()
	else:
		draw_game()
		if state in ["upgrade","fusion","forge","pause","result"]:
			draw_rect(Rect2(0,0,720,1280),Color(0.015,0.025,0.06,0.91))
			buttons.clear()
			draw_overlay()
	if toast_life > 0:
		panel(Rect2(48,872,624,46),Color("192c3e",0.97),Color("35536a"),10)
		centered(toast,902,17,WHITE)

func draw_menu():
	text_at("CORE DEFENSE SYSTEM",Vector2(42,64),18,MINT)
	text_at("PROTOTYPE  /  01",Vector2(497,64),16,MUTED)
	draw_line(Vector2(42,89),Vector2(678,89),Color("253449"))
	text_at("ROGUE",Vector2(44,204),83,WHITE)
	text_at("BREAKER",Vector2(42,294),83,MINT)
	text_at("각도를 만들고, 빌드를 완성하세요.",Vector2(47,346),25,MUTED)
	for row in range(3):
		for col in range(5):
			if (row+col)%4 == 0:
				continue
			var rect = Rect2(112+col*100,411+row*66,88,53)
			var color = MINT if row==0 else (PURPLE if row==1 else Color("ffbf69"))
			panel(rect,Color(color,0.07),Color(color,0.55),7)
			text_at(str(8+row*7+col),rect.position+Vector2(31,35),20,color)
	var origin = Vector2(322,695)
	var dest = Vector2(466,570)
	for i in range(12):
		draw_circle(origin.lerp(dest,i/12.0),2.5,Color(MINT,0.2+i*0.05))
	draw_circle(origin,21,Color(MINT,0.08))
	draw_circle(origin,8,WHITE)
	button(Rect2(48,760,624,76),"이어하기" if has_save else "새로운 다이브 시작",func(): start_run(false,has_save),true)
	if has_save:
		button(Rect2(48,851,302,66),"새 게임",func(): start_run())
		button(Rect2(370,851,302,66),"설정",func(): paused_menu=false; state="settings")
	else:
		button(Rect2(48,851,624,66),"설정",func(): paused_menu=false; state="settings")
	button(Rect2(48,935,624,66),"테스트 랩  ·  공 300개 / 융합",func(): start_run(true),false,PURPLE)
	panel(Rect2(48,1030,624,125),Color("0d192a"),Color("1a2d42"))
	text_at("HOW TO PLAY",Vector2(70,1064),16,MINT)
	text_at("드래그로 조준 → 손을 놓아 발사",Vector2(70,1100),24)
	text_at("벽돌을 부수고 성장하세요. 위험선에 닿으면 종료됩니다.",Vector2(70,1134),17,MUTED)
	button(Rect2(48,1170,624,65),"VFX STUDIO · 114개 연출",func(): state="studio"; vfx.preview_recipe(studio_index),false,PURPLE)

func draw_game():
	text_at("ROGUE / BREAKER",Vector2(38,35),19,WHITE)
	button(Rect2(602,12,80,44),"Ⅱ",func(): previous_state=state; state="pause")
	var sectors = ["NEON GATEWAY","FROZEN RELAY","TOXIC REACTOR","SINGULARITY"]
	text_at("SECTOR %02d · %s" % [mini(4,int((model.round_no-1)/10)+1),sectors[mini(3,int((model.round_no-1)/10))]],Vector2(39,61),13,MINT)
	text_at("ROUND %02d" % model.round_no,Vector2(39,99),22,WHITE)
	text_at("LEVEL %02d" % model.level,Vector2(237,99),22,WHITE)
	text_at("POINT %06d" % model.points,Vector2(445,99),22,MINT)
	panel(Rect2(38,116,644,7),Color("1a2c43"),Color("1a2c43"),3)
	draw_rect(Rect2(38,116,644*clampf(float(model.xp)/model.required_xp(),0,1),7),MINT)
	text_at("XP %d/%d" % [model.xp,model.required_xp()],Vector2(39,141),12,MUTED)
	text_at("LAB · 300 ORBS" if model.lab else "%d ORBS" % model.logical_balls(),Vector2(565,141),12,PURPLE if model.lab else MUTED)
	panel(Rect2(38,150,644,780),Color("0b1728"),Color("253d54"),8)
	for row in range(10):
		draw_line(Vector2(39,150+row*75),Vector2(681,150+row*75),Color(0.2,0.5,0.7,0.075))
	for col in range(8):
		draw_line(Vector2(38+col*92,150),Vector2(38+col*92,900),Color(0.2,0.5,0.7,0.075))
	for b in model.bricks:
		if b.hp <= 0:
			continue
		var rect = model.brick_rect(b)
		var color = MINT
		if b.kind == "armor": color=Color("ffbf69")
		if b.kind == "shield": color=Color("6fbbff")
		if b.kind == "explosive": color=Color("ff7d9b")
		if b.kind == "boss": color=PURPLE
		if b.frozen > 0: color=Color("96edff")
		panel(rect,Color(color,0.12 + (b.flash*2 if not low_flash else 0)),Color(color,0.85),7)
		draw_line(rect.position+Vector2(9,1),rect.position+Vector2(rect.size.x-9,1),color,2)
		var hp_text = "%d/%d" % [maxi(0,ceili(b.hp)), maxi(1,ceili(b.max_hp))]
		var size = 16 if b.kind != "boss" else 25
		var tw = font.get_string_size(hp_text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		text_at(hp_text,rect.get_center()+Vector2(-tw/2,3 if b.kind != "boss" else 13),size,WHITE)
		var bar_rect = Rect2(rect.position+Vector2(7,rect.size.y-12),Vector2(rect.size.x-14,5 if b.kind != "boss" else 8))
		draw_rect(bar_rect,Color("07101d",0.9))
		draw_rect(Rect2(bar_rect.position,Vector2(bar_rect.size.x*clampf(float(b.hp)/maxf(1,b.max_hp),0,1),bar_rect.size.y)),color)
		if b.kind == "boss":
			panel(Rect2(rect.position+Vector2(8,7),Vector2(60,24)),Color("3c275a"),Color("b59aff"),6)
			text_at("BOSS",rect.position+Vector2(17,25),13,WHITE)
		# Ice and treasure are rendered by persistent textured scene nodes.
	for effect in model.effects:
		if effect.kind in ["lightning","lightning_chain","thunder_swarm","time_stop","boss_spawn"]:
			draw_skill_effect(effect)
	for i in range(24):
		draw_line(Vector2(45+i*27,900),Vector2(58+i*27,900),Color("ff698c"),2)
	text_at("DANGER",Vector2(50,918),11,Color("ff698c"))
	if state == "aim":
		draw_circle(Vector2(model.launch_x,Simulation.RETURN_Y),22,Color(MINT,0.08))
		draw_circle(Vector2(model.launch_x,Simulation.RETURN_Y),8,WHITE)
		if aiming:
			var path = sim.laser_path(direction) if armed in ["laser","orbital_strike"] else sim.aim_path(direction)
			for index in range(path.size()-1):
				var distance = path[index].distance_to(path[index+1])
				for point in range(int(distance/17)):
					draw_circle(path[index].lerp(path[index+1],point*17/distance),2.5,MINT if armed == "" else Color("ff7d9b"))
				draw_circle(path[index+1],6,Color(MINT,0.6),false,1.5,true)
		else:
			centered("아래로 드래그해 조준 · 손을 놓아 발사" if armed == "" else "스킬 방향 조준 · 손을 놓아 사용",922,16,MUTED)
	if state == "aim" and not model.lab:
		draw_purchase_card()
	else:
		panel(Rect2(38,944,644,88),Color("0d192a"),Color("26394e"),12)
		text_at("●  %d ORBS" % model.logical_balls(),Vector2(60,996),23,MINT)
		text_at("%d FPS" % Engine.get_frames_per_second() if animation_time > 3 else "WARMUP",Vector2(580,995),13,MUTED)
	var passive_index = 0
	for id in model.skills:
		if model.config.skills[id].type != "passive": continue
		var rect = Rect2(38+passive_index*109,1043,99,56)
		var color = Color(model.config.skills[id].color)
		panel(rect,Color(color,0.075),Color(color,0.4),8)
		text_at(model.config.skills[id].short,rect.position+Vector2(8,22),13,color)
		text_at("Lv.%d"%model.skills[id],rect.position+Vector2(8,43),13,WHITE)
		buttons.append({"rect":rect,"action":func(): show_skill_info(id)})
		passive_index+=1
	for i in range(passive_index,6):
		panel(Rect2(38+i*109,1043,99,56),Color("0a1424"),Color("1c2a3d"),8)
		text_at("+",Vector2(78+i*109,1079),20,Color("304259"))
	var active_index = 0
	for id in model.skills:
		if model.config.skills[id].type != "active": continue
		draw_active_tile(id,Rect2(38+active_index*164,1110,152,62))
		active_index+=1
	for i in range(active_index,4):
		panel(Rect2(38+i*164,1110,152,62),Color("0a1424"),Color("1c2a3d"),10)
		text_at("ACTIVE EMPTY",Vector2(54+i*164,1148),13,Color("42546c"))
	if state == "flight":
		button(Rect2(212,1190,296,52),"가속 ×4" if not manual_fast else "×4 진행 중",func(): manual_fast=true)
	elif state == "aim" and not model.available_fusions().is_empty():
		button(Rect2(212,1190,296,52),"FUSION READY",func(): fusion_from_aim=true; state="fusion",true,PURPLE)
	else:
		centered("스킬 칸을 누르면 효과 설명을 볼 수 있습니다.",1219,14,MUTED)
	draw_skill_info_panel()

func draw_overlay():
	if state == "upgrade":
		text_at("SYSTEM UPGRADE",Vector2(50,214),18,MINT)
		text_at("LEVEL %02d"%model.level,Vector2(46,280),56)
		text_at("세 가지 중 하나를 선택하세요.",Vector2(50,325),24,MUTED)
		for i in range(cards.size()):
			var id = cards[i]
			var spec = model.config.skills[id]
			var color = Color(spec.color)
			var rect = Rect2(46,367+i*190,628,169)
			panel(rect,Color("101f33"),Color(color,0.65))
			text_at("%02d  /  %s"%[i+1,spec.type.to_upper()],rect.position+Vector2(24,34),15,color)
			text_at(spec.name,rect.position+Vector2(24,79),31)
			text_at("Lv.%d → %d"%[model.skill_level(id),model.skill_level(id)+1],rect.position+Vector2(448,77),23,color)
			text_at(spec.description,rect.position+Vector2(24,119),20,MUTED)
			text_at("선택하여 장착  →",rect.position+Vector2(430,147),16,color)
			buttons.append({"rect":rect,"action":func(): choose_upgrade(id)})
		if model.rerolls > 0:
			button(Rect2(180,995,360,65),"다시 뽑기 · %d"%model.rerolls,func(): model.rerolls-=1; cards=model.draw_cards())
	elif state == "fusion":
		centered("SKILL COMPRESSION",223,18,PURPLE)
		centered("FUSION READY",291,48,WHITE)
		centered("Lv.5 스킬 두 개를 합쳐 빈 슬롯을 확보하세요.",338,22,MUTED)
		var recipes = model.available_fusions()
		for i in range(recipes.size()):
			var recipe = recipes[i]
			var rect = Rect2(48,380+i*183,624,160)
			panel(rect,Color("211b39"),Color("746199"))
			text_at(model.config.skills[recipe.a].name+" + "+model.config.skills[recipe.b].name,rect.position+Vector2(24,39),20,MUTED)
			text_at(model.config.skills[recipe.result].name+"  →",rect.position+Vector2(24,86),33,PURPLE)
			text_at(model.config.skills[recipe.result].description,rect.position+Vector2(24,119),17,WHITE)
			text_at("2개 슬롯 → 1개 슬롯 · 융합 Lv.1",rect.position+Vector2(24,146),15,MUTED)
			buttons.append({"rect":rect,"action":func(): apply_fusion(recipe)})
		button(Rect2(180,1014,360,65),"지금은 유지",func(): state="aim" if fusion_from_aim else "resolve"; finish_fusion())
	elif state == "forge":
		centered("CORE DESTROYED",244,18,MINT)
		centered("FORGE",316,62)
		centered("파편 %d  ·  첫 분해 무료 / 이후 파편 1개"%model.shards,366,22,MUTED)
		var index = 0
		for id in model.skills:
			if not model.config.skills[id].get("fusion",false): continue
			button(Rect2(48,440+index*92,624,72),model.config.skills[id].name+" 분해",func():
				if model.dismantle(id): notify("분해 완료 · 원본 스킬 Lv.5 복원")
				else: notify("빈 슬롯·파편·원본 스킬 중복 여부를 확인하세요.")
			)
			index+=1
		if index==0: centered("분해할 융합 스킬이 없습니다.",550,24,MUTED)
		button(Rect2(130,1000,460,72),"계속 진행",func(): next_round(),true)
	elif state == "pause":
		centered("SYSTEM PAUSED",342,43)
		centered("라운드 시작 시 자동 저장됩니다.",396,24,MUTED)
		button(Rect2(100,477,520,74),"계속 플레이",func(): state=previous_state,true)
		button(Rect2(100,574,520,74),"설정",func(): paused_menu=true; state="settings")
		button(Rect2(100,671,520,74),"메인으로",func(): state="menu"; sim.balls.clear(); has_save=FileAccess.file_exists(Model.SAVE_PATH))
		centered("발사 중 종료하면 해당 라운드 시작부터 복구합니다.",805,20,MUTED)
	elif state == "result":
		centered("CORE SECURED" if cleared else "SIGNAL LOST",266,19,MINT if cleared else Color("ff7d9b"))
		centered("RUN CLEAR" if cleared else "DIVE OVER",348,58)
		centered("ROUND %02d    /    LEVEL %02d"%[model.round_no,model.level],422,27,MUTED)
		centered("%06d"%model.points,531,70,MINT)
		centered("POINT",570,18,MUTED)
		centered("충돌 %d회   ·   파괴 %d개"%[model.hits,model.kills],650,24)
		if cleared:
			button(Rect2(100,765,520,74),"ENDLESS 계속하기",func(): model.endless=true; next_round(),true)
		else:
			button(Rect2(100,765,520,74),"다시 도전",func(): start_run(model.lab),true)
		button(Rect2(100,865,520,74),"메인으로",func(): state="menu"; sim.balls.clear())

func finish_fusion():
	if not fusion_from_aim:
		finish_rewards()
	else:
		model.save_run()

func apply_fusion(recipe: Dictionary):
	if not model.fuse(recipe):
		return
	var result = String(recipe.result)
	var kind = {"pierce_bomb":"pierce_bomb","thunder_swarm":"thunder_swarm","orbital_strike":"orbital_beam"}.get(result,"burst")
	var extra = {}
	if result == "thunder_swarm":
		extra.targets = model.bricks.map(func(b): return model.brick_rect(b).get_center())
	elif result == "orbital_strike":
		extra = {"from":Vector2(model.launch_x,Simulation.RETURN_Y),"to":Vector2(360,280)}
	model.emit_effect(Vector2(360,610),Color(model.config.skills[result].color),260,kind,1.1,extra)
	show_skill_info(result, 7.0)
	notify("융합 완료 · %s · %s" % [model.config.skills[result].name, model.config.skills[result].description])
	state="aim" if fusion_from_aim else "resolve"
	finish_fusion()

func draw_settings():
	text_at("PREFERENCES",Vector2(48,193),18,MINT)
	text_at("설정",Vector2(44,266),58)
	text_at("성능 모드",Vector2(48,363),26)
	var labels = ["LOW · 64","BAL · 96","HIGH · 128"]
	for i in range(3):
		button(Rect2(48+i*214,392,196,73),labels[i],func(): tier=i; save_settings(),tier==i)
	text_at("공의 실제 계산 개수입니다. 논리 공 수와 총 가중치는 유지됩니다.",Vector2(48,505),18,MUTED)
	button(Rect2(48,558,624,74),"효과음  "+("켜짐" if sound_on else "꺼짐"),func(): sound_on=not sound_on; save_settings())
	button(Rect2(48,656,624,74),"섬광 줄이기  "+("켜짐" if low_flash else "꺼짐"),func(): low_flash=not low_flash; save_settings())
	panel(Rect2(48,784,624,151),Color("101e30"),Color("263a50"))
	text_at("테스트 빌드",Vector2(72,826),24,MINT)
	text_at("12 패시브 · 8 액티브 · VFX STUDIO",Vector2(72,866),22)
	text_at("계정 · 광고 · 결제 · 온라인 랭킹은 아직 연결하지 않았습니다.",Vector2(72,902),17,MUTED)
	button(Rect2(160,1040,400,74),"돌아가기",func(): state="pause" if paused_menu else "menu",true)

func draw_studio():
	var spec=vfx.catalog[studio_index]
	text_at("VFX STUDIO",Vector2(40,63),31,MINT)
	text_at("%03d / 114 · %s" % [studio_index+1,spec.category],Vector2(40,103),19,MUTED)
	text_at(spec.name,Vector2(40,168),36,WHITE)
	panel(Rect2(38,220,644,720),Color("0b1728"),Color("28425b"))
	for row in range(3):
		for col in range(5):
			panel(Rect2(137+col*92,385+row*75,84,67),Color("123249"),Color("4a8fac"),7)
	text_at("에셋·타이밍 미리보기 / 전투 피해 판정 없음",Vector2(48,975),18,MUTED)
	button(Rect2(38,1020,200,70),"이전",func(): studio_index=posmod(studio_index-1,114); vfx.preview_recipe(studio_index))
	button(Rect2(260,1020,200,70),"다시 재생",func(): vfx.preview_recipe(studio_index),true)
	button(Rect2(482,1020,200,70),"다음",func(): studio_index=posmod(studio_index+1,114); vfx.preview_recipe(studio_index))
	button(Rect2(38,1120,310,70),"이 기본 스킬 테스트" if studio_index<20 else "전투 테스트 랩",func():
		var selected=String(vfx.catalog[studio_index].id)
		start_run(true)
		if studio_index<20:
			model.skills.clear()
			model.skills["rebound" if selected=="wall" else selected]=5
			model.assign_bounty()
	)
	button(Rect2(372,1120,310,70),"메인으로",func(): vfx.clear(); state="menu")
