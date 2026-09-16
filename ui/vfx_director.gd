extends Node2D
## Shared textures + fixed actor/ball pools. Combat publishes events; rendering never rolls combat RNG.
const Actor = preload("res://ui/vfx_actor.gd")
const FLAME = preload("res://assets/vfx/flame.gdshader")
const SURFACE = preload("res://assets/vfx/surface.gdshader")
var textures: Dictionary = {}
var frames = SpriteFrames.new()
var actors: Array = []
var ball_views: Array = []
var brick_views: Dictionary = {}
var catalog: Array = []
var time = 0.0
var quiet = false
var limit = 32
var scheduled: Array = []
var preview = false
var preview_bricks: Array = []
var preview_until = 0.0
var shown_recipe = ""
var choreography = preload("res://ui/fusion_choreography.gd").new()

func _ready():
	for name in ["orb","arrow","bomb","coin","spark","particle","shard","ring","missile","beam","ice_frame","chest_atlas","explosion_atlas"]:
		textures[name] = load("res://assets/vfx/"+name+".svg")
	for definition in [["explosion",12,22.0],["chest",6,13.0]]:
		frames.add_animation(definition[0])
		frames.set_animation_loop(definition[0],false)
		frames.set_animation_speed(definition[0],definition[2])
		for index in range(definition[1]):
			var atlas = AtlasTexture.new()
			atlas.atlas = textures[definition[0]+"_atlas"]
			atlas.region = Rect2(index*128,0,128,128)
			frames.add_frame(definition[0],atlas)
	var font = FontVariation.new()
	font.base_font = load("res://assets/NotoSansKR.ttf")
	font.variation_opentype = {2003265652:900}
	for i in range(48):
		var actor = Actor.new()
		add_child(actor)
		actor.setup(textures,frames,font)
		actor.z_index = 5
		actors.append(actor)
	for i in range(128):
		var root = Node2D.new()
		var tail = Sprite2D.new()
		tail.texture = textures.particle
		tail.scale = Vector2(0.55,0.23)
		tail.position.x = -24
		var material = ShaderMaterial.new()
		material.shader = FLAME
		tail.material = material
		root.add_child(tail)
		var sprite = Sprite2D.new()
		sprite.texture = textures.orb
		root.add_child(sprite)
		root.z_index = 4
		add_child(root)
		root.hide()
		ball_views.append({"root":root,"sprite":sprite,"tail":tail})
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/vfx_catalog.json"))

func clear():
	for actor in actors: actor.reset()
	for view in ball_views: view.root.hide()
	for view in brick_views.values(): view.root.queue_free()
	brick_views.clear()
	scheduled.clear()

func emit(kind: String, at: Vector2, tint: Color = Color.WHITE, extra: Dictionary = {}):
	var active_count = 0
	for actor in actors:
		if actor.busy: active_count += 1
	if active_count >= limit: return
	for actor in actors:
		if not actor.busy:
			var options = extra.duplicate()
			options.quiet = quiet or active_count > 12
			actor.play(kind,at,tint,options)
			return

func later(delay: float, kind: String, at: Vector2, tint: Color, extra: Dictionary = {}):
	if scheduled.size()<128:
		scheduled.append({"at":time+delay,"kind":kind,"p":at,"color":tint,"extra":extra})

func tick(delta: float):
	time += delta
	var ready = scheduled.filter(func(e): return e.at<=time)
	scheduled = scheduled.filter(func(e): return e.at>time)
	for e in ready: emit(e.kind,e.p,e.color,e.extra)

func set_speed(value: float):
	for actor in actors:
		if actor.motion and actor.motion.is_valid(): actor.motion.set_speed_scale(value)
		actor.animation.speed_scale=value
		actor.particles.speed_scale=value

func sync(model, simulation, delta: float, tier: int, low_flash: bool):
	quiet = low_flash
	limit = [20,32,48][tier]
	tick(delta)
	for effect in model.effects:
		if effect.get("presented",false): continue
		effect.presented = true
		var kind: String = effect.kind
		if kind=="fusion":
			choreography.play(self,String(effect.recipe),{"target":effect.p})
			continue
		if kind in ["lightning","lightning_chain","thunder_swarm","time_stop","boss_spawn","frost"]: continue
		if kind=="treasure":
			for i in range(7): later(0.12+i*0.035,"coin",effect.p,Color.WHITE,{"offset":Vector2((i-3)*12,-60-abs(i-3)*8)})
		emit(kind,effect.p,effect.color,effect)
	for i in range(ball_views.size()):
		var view = ball_views[i]
		if i>=simulation.balls.size():
			view.root.hide()
			continue
		var ball = simulation.balls[i]
		view.root.show()
		view.root.position = ball.p
		view.root.rotation = ball.v.angle()
		var charged = clampf(float(ball.bounce)*0.06*model.skill_level("rebound")/1.5,0,1)
		var child: bool = ball.get("split",false)
		view.sprite.texture = textures.arrow if ball.get("piercing",false) else textures.orb
		view.sprite.scale = Vector2.ONE*((0.24 if ball.get("piercing",false) else 0.20)*(0.77 if child else 1.0))
		view.sprite.modulate = Color("42e6cf") if child else Color.WHITE.lerp(Color("ff392b"),charged)
		view.tail.visible = charged>=0.99 and not low_flash
		view.tail.material.set_shader_parameter("clock",time)
	var living: Dictionary = {}
	for b in model.bricks:
		if b.hp<=0: continue
		living[b.id] = true
		if not brick_views.has(b.id): make_brick(b.id)
		var view = brick_views[b.id]
		var rect: Rect2 = model.brick_rect(b)
		view.root.position = rect.get_center()
		view.ice.visible = b.frozen>0
		view.ice.flip_h = int(b.id)%2==0
		view.ice.scale = rect.size/Vector2(138,90)
		view.chest.visible = bool(b.get("bounty",false))
		view.mark.visible = float(b.get("marked",0))>0
		view.mark.scale = rect.size/Vector2(100,100)
		view.chest.scale = rect.size/Vector2(114,112)
		view.surface.scale = rect.size/128.0
		view.surface.material.set_shader_parameter("clock",time)
		view.surface.material.set_shader_parameter("corrosion",float(b.get("corrosion",0))/5)
		view.surface.material.set_shader_parameter("resonance",float(b.get("resonance",0))/4)
	for id in brick_views.keys():
		if not living.has(id):
			brick_views[id].root.queue_free()
			brick_views.erase(id)

func make_brick(id: int):
	var root = Node2D.new()
	root.z_index = 1
	add_child(root)
	var chest = Sprite2D.new()
	var tex = AtlasTexture.new()
	tex.atlas = textures.chest_atlas
	tex.region = Rect2(0,0,128,128)
	chest.texture = tex
	root.add_child(chest)
	var ice = Sprite2D.new()
	ice.texture = textures.ice_frame
	root.add_child(ice)
	var surface = Sprite2D.new()
	surface.texture = textures.particle
	var material = ShaderMaterial.new()
	material.shader = SURFACE
	surface.material = material
	root.add_child(surface)
	var marker=Sprite2D.new()
	marker.texture=textures.ring
	marker.modulate=Color("ff677a")
	root.add_child(marker)
	brick_views[id] = {"root":root,"ice":ice,"chest":chest,"surface":surface,"mark":marker}

func preview_recipe(index: int):
	clear()
	preview = true
	var spec: Dictionary = catalog[posmod(index,catalog.size())]
	shown_recipe = spec.id
	var center = Vector2(360,493)
	var sources: Array = spec.sources
	if sources.size()==2:
		choreography.play(self,spec.id)
		preview_until=time+3.2
		return
	# Each recipe has an ordered timeline. Two sources change both emission geometry
	# and timing, rather than just tinting an identical burst.
	for n in range(sources.size()):
		var source: String = sources[n]
		var delay = 0.15+n*0.32
		var p = center+Vector2(0,n*18)
		match source:
			"power": later(delay,"power",p,Color("ffbf69"))
			"pierce":
				later(delay,"arrow_flight",Vector2(330,880),Color("81ddff"),{"to":Vector2(390,250),"travel":1.2})
			"blast", "bomb":
				for offset in [Vector2(-92,0),Vector2(92,0),Vector2(0,-75),Vector2(0,75)]:
					later(delay,"bomb_drop",p+offset,Color("ffab5e"))
			"lightning":
				for i in range(4): later(delay+i*.07,"bolt",p,Color("bc8bff"),{"from":p+Vector2((i-1.5)*100,-200),"to":p+Vector2((i-1.5)*60,50)})
			"frost", "freeze":
				for i in range(5): later(delay+i*.08,"ice",Vector2(179+i*92,493),Color.WHITE)
			"critical": later(delay,"critical",p,Color("ffe58a"))
			"wall":
				later(delay,"orb_flight",Vector2(45,690),Color("ff752c"),{"to":Vector2(675,530),"travel":0.6})
				later(delay+.6,"orb_flight",Vector2(675,530),Color("ff3421"),{"to":Vector2(45,370),"travel":0.6})
			"corrosion":
				for i in range(3): later(delay+i*.1,"corrosion",p+Vector2(i*50-50,0),Color("76e552"))
			"bounty":
				later(delay,"treasure",p,Color.WHITE)
				for i in range(7): later(delay+.2+i*.04,"coin",p,Color.WHITE,{"offset":Vector2((i-3)*20,-80)})
			"split":
				later(delay,"orb_flight",Vector2(360,820),Color.WHITE,{"to":p,"travel":0.3})
				for i in range(2): later(delay+.3,"orb_flight",p,Color("42e6cf"),{"to":p+Vector2(-95 if i==0 else 95,-210),"scale":0.15,"travel":0.7})
			"resonance":
				for i in range(3): later(delay+i*.14,"resonance",p,Color("8ee6ff"))
			"ricochet":
				later(delay,"orb_flight",Vector2(160,590),Color.WHITE,{"to":Vector2(360,880),"travel":0.45})
				later(delay+.45,"ricochet",Vector2(360,850),Color("8ef8dd"))
				later(delay+.45,"orb_flight",Vector2(360,880),Color.WHITE,{"to":Vector2(560,590),"travel":0.45})
			"laser":
				later(delay,"laser",p,Color("ff97bd"),{"from":Vector2(360,900),"to":Vector2(675,460)})
				later(delay+.1,"laser",p,Color("ff97bd"),{"from":Vector2(675,460),"to":Vector2(517.5,240)})
			"mark": later(delay,"mark",p,Color("ff677a"))
			"overclock": later(delay,"overclock",p,Color("ffad61"))
			"pulse":
				later(delay,"pulse",p,Color("b6efff"),{"from":Vector2(45,530),"to":Vector2(675,530)})
				later(delay,"pulse",p,Color("b6efff"),{"from":Vector2(360,240),"to":Vector2(360,900)})
			"missile":
				for i in range(6): later(delay+i*.08,"missile",p+Vector2((i%3-1)*92,(i/3)*75),Color.WHITE,{"from":Vector2(45 if i%2==0 else 675,730)})
			"echo":
				later(delay,"echo",p,Color("bb9cff"))
				for i in range(3): later(delay+.4+i*.18,"resonance",p,Color("bb9cff"))
	preview_until = time+2.6
