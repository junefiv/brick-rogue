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

func _ready():
	font.base_font = preload("res://assets/NotoSansKR.ttf")
	font.variation_opentype = {2003265652:550}
	sim.setup(model)
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

func _process(delta):
	var viewport_size = get_viewport_rect().size
	var usable = Rect2(Vector2.ZERO, viewport_size)
	if OS.get_name() in ["Android", "iOS"]:
		var window_size = Vector2(DisplayServer.window_get_size())
		var safe = Rect2(DisplayServer.get_display_safe_area())
		if window_size.x > 0 and window_size.y > 0 and safe.size.x > 0 and safe.size.y > 0:
			var ratio = viewport_size / window_size
			usable = Rect2(safe.position * ratio, safe.size * ratio).intersection(usable)
	var factor = minf(usable.size.x / 720.0, usable.size.y / 1280.0)
	scale = Vector2.ONE * factor
	position = usable.position + (usable.size - Vector2(720,1280) * factor) / 2
	animation_time += delta
	toast_life = maxf(0, toast_life - delta)
	model.vfx_budget = 0 if low_flash else model.config.vfx_caps[tier]
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
				model.launch_x = sim.first_return if sim.first_return >= 0 else model.launch_x
				state = "resolve"
				resolve_levels()
				break
		simulation_ms = (Time.get_ticks_usec() - began) / 1000.0
		longest_tick_ms = maxf(longest_tick_ms, simulation_ms)
	elif state == "active_resolve":
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
			if state == "aim" and Rect2(38,260,644,750).has_point(point):
				drag_start = point
				aiming = true
				update_direction(point)
		elif aiming:
			aiming = false
			if state == "aim":
				if armed != "":
					use_targeted_active()
				else:
					fire()
	if event is InputEventMouseMotion and aiming and state == "aim":
		update_direction(to_local(event.position))

func update_direction(point: Vector2):
	var aim = point - Vector2(model.launch_x, Simulation.RETURN_Y)
	if point.distance_to(drag_start) > 24 and point.y > drag_start.y:
		aim = drag_start - point
	if aim.length_squared() < 9:
		return
	aim.y = -maxf(absf(aim.y), absf(aim.x) * tan(deg_to_rad(10)))
	direction = aim.normalized()

func fire():
	if state != "aim":
		return
	state = "flight"
	volley_time = 0
	manual_fast = false
	hit_cache = model.hits
	sim.fire(direction)

func resolve_levels():
	if model.consume_level():
		cards = model.draw_cards()
		if cards.is_empty():
			model.score += 500
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
	if int(model.cooldowns.get(id, 0)) > 0:
		notify("%d라운드 후 사용할 수 있습니다." % model.cooldowns[id])
		return
	if id in ["laser", "bomb", "orbital_strike"]:
		armed = "" if armed == id else id
		notify("방향을 조준하고 손을 놓으세요. 다시 누르면 취소합니다.")
		return
	if id == "freeze":
		for b in model.bricks:
			b.frozen = maxi(1, b.frozen)
	elif id == "stop":
		model.stop_rounds = maxi(1, model.stop_rounds)
	consume_active(id)
	state = "active_resolve"

func consume_active(id: String):
	model.cooldowns[id] = maxi(2, int(model.config.skills[id].cooldown) - int((model.skill_level(id) - 1) / 2))
	model.emit_effect(Vector2(360,600), Color(model.config.skills[id].color), 250)

func use_targeted_active():
	var id = armed
	armed = ""
	if id in ["laser", "orbital_strike"]:
		var origin = Vector2(model.launch_x, Simulation.RETURN_Y)
		for b in model.bricks:
			if Simulation.sweep_circle(origin, direction * 1500, model.brick_rect(b), 12).t <= 1:
				model.enqueue(b, 12.0 * model.skill_level(id), 0, "active")
				model.emit_effect(model.brick_rect(b).get_center(), Color("ff7d9b"), 55)
				if id == "orbital_strike":
					model.area_damage(model.brick_rect(b).get_center(), 170, 18.0 * model.skill_level(id), 0, "orbital")
	else:
		var path = sim.aim_path(direction)
		model.area_damage(path.back(), 190, 15.0 * model.skill_level(id), 0, "active")
	consume_active(id)
	state = "active_resolve"

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

func button(rect: Rect2, label: String, action: Callable, primary: bool = false, accent: Color = MINT):
	panel(rect, accent if primary else Color("122037"), accent if primary else Color("2a3b55"), 12)
	var size = 23
	var width = font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	text_at(label, Vector2(rect.position.x+(rect.size.x-width)/2,rect.position.y+rect.size.y/2+8),size,INK if primary else WHITE)
	buttons.append({"rect":rect,"action":action})

func _draw():
	buttons.clear()
	draw_rect(Rect2(0,0,720,1280), Color("080f1c"))
	for x in range(0,721,36):
		draw_line(Vector2(x,0),Vector2(x,1280),Color(0.2,0.5,0.7,0.025))
	if state == "menu":
		draw_menu()
	elif state == "settings":
		draw_settings()
	else:
		draw_game()
		if state in ["upgrade","fusion","forge","pause","result"]:
			draw_rect(Rect2(0,0,720,1280),Color(0.015,0.025,0.06,0.91))
			buttons.clear()
			draw_overlay()
	if toast_life > 0:
		panel(Rect2(30,1214,660,46),Color("192c3e"),Color("35536a"),10)
		centered(toast,1244,18,WHITE)

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
	centered("OFFLINE READY    /    ANDROID    /    GODOT",1210,15,MUTED)

func draw_game():
	text_at("ROGUE / BREAKER",Vector2(38,65),22,WHITE)
	button(Rect2(582,30,100,53),"Ⅱ",func(): previous_state=state; state="pause")
	var sectors = ["NEON GATEWAY","FROZEN RELAY","TOXIC REACTOR","SINGULARITY"]
	text_at("SECTOR %02d  /  %s" % [mini(4,int((model.round_no-1)/10)+1),sectors[mini(3,int((model.round_no-1)/10))]],Vector2(39,109),16,MINT)
	text_at("ROUND",Vector2(40,153),15,MUTED)
	text_at("%02d" % model.round_no,Vector2(38,202),46)
	text_at("LEVEL",Vector2(264,153),15,MUTED)
	text_at("%02d" % model.level,Vector2(262,202),46)
	text_at("SCORE",Vector2(494,153),15,MUTED)
	text_at("%06d" % model.score,Vector2(492,199),32)
	panel(Rect2(38,221,644,7),Color("1a2c43"),Color("1a2c43"),3)
	draw_rect(Rect2(38,221,644*clampf(float(model.xp)/model.required_xp(),0,1),7),MINT)
	text_at("XP  %d / %d" % [model.xp,model.required_xp()],Vector2(39,249),13,MUTED)
	text_at("LAB · 300 LOGICAL" if model.lab else "8 ORBS → YOUR BUILD",Vector2(492,249),13,PURPLE if model.lab else MUTED)
	panel(Rect2(38,260,644,730),Color("0b1728"),Color("253d54"),8)
	for row in range(10):
		draw_line(Vector2(39,260+row*70),Vector2(681,260+row*70),Color(0.2,0.5,0.7,0.075))
	for col in range(8):
		draw_line(Vector2(38+col*92,260),Vector2(38+col*92,890),Color(0.2,0.5,0.7,0.075))
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
		var hp_text = str(maxi(0,ceili(b.hp)))
		var size = 26 if b.kind != "boss" else 42
		var tw = font.get_string_size(hp_text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
		text_at(hp_text,rect.get_center()+Vector2(-tw/2,10),size,WHITE)
		if b.kind != "normal":
			var symbol = {"armor":"A","shield":"S","explosive":"+","boss":"CORE"}.get(b.kind,"")
			text_at(symbol,rect.position+Vector2(7,15),10,color)
		if b.frozen > 0:
			text_at("*",rect.position+Vector2(rect.size.x-17,17),16,WHITE)
		if b.kind == "boss":
			draw_rect(Rect2(rect.position+Vector2(12,rect.size.y-14),Vector2((rect.size.x-24)*maxf(0,b.hp)/b.max_hp,3)),color)
	for effect in model.effects:
		var alpha = effect.life/0.4
		draw_arc(effect.p,effect.r*(1-alpha)+3,0,TAU,24,Color(effect.color,alpha*0.7),2,true)
	for ball in sim.balls:
		if tier > 0 and not manual_fast and volley_time < 9:
			draw_line(ball.p-ball.v.normalized()*16,ball.p,Color(MINT,0.3),5,true)
		draw_circle(ball.p,7,WHITE)
	for i in range(24):
		draw_line(Vector2(45+i*27,899),Vector2(58+i*27,899),Color("ff698c"),2)
	text_at("DANGER LINE",Vector2(50,923),12,Color("ff698c"))
	if state == "aim":
		draw_circle(Vector2(model.launch_x,Simulation.RETURN_Y),22,Color(MINT,0.08))
		draw_circle(Vector2(model.launch_x,Simulation.RETURN_Y),8,WHITE)
		if aiming:
			var path = sim.aim_path(direction)
			for index in range(path.size()-1):
				var distance = path[index].distance_to(path[index+1])
				for point in range(int(distance/17)):
					draw_circle(path[index].lerp(path[index+1],point*17/distance),2.5,MINT if armed == "" else Color("ff7d9b"))
				draw_circle(path[index+1],6,Color(MINT,0.6),false,1.5,true)
		else:
			centered("드래그하여 조준 · 손을 놓아 발사" if armed == "" else "스킬 조준 중 · 손을 놓아 사용",941,18,MUTED)
	text_at("●  %d ORBS" % model.logical_balls(),Vector2(39,1025),19,MINT)
	text_at("%d FPS   SIM %.1f ms" % [Engine.get_frames_per_second(),simulation_ms] if animation_time > 3 else "PERFORMANCE WARMUP",Vector2(446,1025),14,MUTED)
	var passive_index = 0
	for id in model.skills:
		if model.config.skills[id].type != "passive": continue
		var rect = Rect2(38+passive_index*109,1044,99,56)
		var color = Color(model.config.skills[id].color)
		panel(rect,Color(color,0.075),Color(color,0.4),8)
		text_at(model.config.skills[id].short,rect.position+Vector2(8,22),13,color)
		text_at("Lv.%d"%model.skills[id],rect.position+Vector2(8,43),13,WHITE)
		passive_index+=1
	for i in range(passive_index,6):
		panel(Rect2(38+i*109,1044,99,56),Color("0a1424"),Color("1c2a3d"),8)
		text_at("+",Vector2(78+i*109,1080),20,Color("304259"))
	var active_index = 0
	for id in model.skills:
		if model.config.skills[id].type != "active": continue
		var cd = int(model.cooldowns.get(id,0))
		var label = model.config.skills[id].short + (" · %d"%cd if cd>0 else " ✓")
		button(Rect2(38+active_index*164,1120,152,65),label,func(): active(id),armed==id,Color(model.config.skills[id].color))
		active_index+=1
	for i in range(active_index,4):
		panel(Rect2(38+i*164,1120,152,65),Color("0a1424"),Color("1c2a3d"),10)
		text_at("EMPTY",Vector2(76+i*164,1160),15,Color("42546c"))
	if state == "flight":
		button(Rect2(212,1204,296,46),"가속 ×4" if not manual_fast else "×4 진행 중",func(): manual_fast=true)
	elif state == "aim" and not model.available_fusions().is_empty():
		button(Rect2(212,1204,296,46),"FUSION READY",func(): fusion_from_aim=true; state="fusion",true,PURPLE)
	else:
		centered("PASSIVE %d/6   ·   ACTIVE %d/4   ·   오프라인"%[model.count_type("passive"),model.count_type("active")],1229,15,MUTED)

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
			buttons.append({"rect":rect,"action":func(): model.apply_card(id); resolve_levels()})
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
			text_at("2 SLOTS → 1 SLOT    /    융합 Lv.1",rect.position+Vector2(24,128),17,WHITE)
			buttons.append({"rect":rect,"action":func(): model.fuse(recipe); notify("융합 완료! 슬롯 하나가 비었습니다."); state="aim" if fusion_from_aim else "resolve"; finish_fusion()})
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
		centered("%06d"%model.score,531,70,MINT)
		centered("SCORE",570,18,MUTED)
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
	text_at("8 패시브 · 4 액티브 · 3 융합 · 로컬 저장",Vector2(72,866),22)
	text_at("계정 · 광고 · 결제 · 온라인 랭킹은 아직 연결하지 않았습니다.",Vector2(72,902),17,MUTED)
	button(Rect2(160,1040,400,74),"돌아가기",func(): state="pause" if paused_menu else "menu",true)
