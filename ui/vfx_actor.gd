extends Node2D
## Reusable effect actor: atlas animation, motion tween, GPU particles and action type.
var busy = false
var picture = Sprite2D.new()
var animation = AnimatedSprite2D.new()
var caption = Label.new()
var particles = GPUParticles2D.new()
var bolt = Line2D.new()
var bolt_glow = Line2D.new()
var motion: Tween
var textures: Dictionary
var animations: SpriteFrames

func setup(shared_textures: Dictionary, shared_frames: SpriteFrames, font: Font):
	textures = shared_textures
	animations = shared_frames
	add_child(picture)
	add_child(animation)
	animation.sprite_frames = animations
	add_child(caption)
	caption.add_theme_font_override("font", font)
	caption.add_theme_font_size_override("font_size", 30)
	caption.add_theme_color_override("font_outline_color", Color("172035"))
	caption.add_theme_constant_override("outline_size", 7)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.position = Vector2(-100,-25)
	caption.size = Vector2(200,52)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.pivot_offset = Vector2(100,25)
	add_child(particles)
	add_child(bolt_glow)
	add_child(bolt)
	bolt.width=2.5
	bolt_glow.width=9
	bolt.antialiased=true
	bolt_glow.antialiased=true
	particles.texture = textures.particle
	particles.amount = 12
	particles.lifetime = 0.55
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = false
	particles.visibility_rect = Rect2(-300,-300,600,600)
	var material = ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.direction = Vector3(0,-1,0)
	material.spread = 130
	material.initial_velocity_min = 70
	material.initial_velocity_max = 170
	material.gravity = Vector3(0,170,0)
	material.scale_min = 0.018
	material.scale_max = 0.05
	var gradient = Gradient.new()
	gradient.set_color(0,Color(1,1,1,1))
	gradient.set_color(1,Color(1,0.6,0.1,0))
	var ramp = GradientTexture1D.new()
	ramp.gradient = gradient
	material.color_ramp = ramp
	particles.process_material = material
	hide()

func reset():
	if motion and motion.is_valid(): motion.kill()
	busy = false
	particles.emitting = false
	animation.stop()
	hide()

func play(kind: String, at: Vector2, tint: Color, extra: Dictionary = {}):
	reset()
	busy = true
	show()
	position = at
	rotation = 0
	modulate = Color.WHITE
	scale = Vector2.ONE
	picture.hide()
	picture.position = Vector2.ZERO
	picture.rotation = 0
	picture.modulate = tint
	picture.scale = Vector2.ONE
	animation.hide()
	animation.position = Vector2.ZERO
	animation.modulate = Color.WHITE
	caption.hide()
	bolt.hide()
	bolt_glow.hide()
	caption.rotation = -0.09
	caption.scale = Vector2.ONE
	particles.modulate = tint
	motion = create_tween()
	match kind:
		"bolt":
			var start: Vector2=extra.get("from",at-Vector2(0,150))-at
			var finish: Vector2=extra.get("to",at)-at
			var points=PackedVector2Array([start])
			for i in range(1,9):
				points.append(start.lerp(finish,i/9.0)+(finish-start).normalized().orthogonal()*sin(i*7.31)*11)
			points.append(finish)
			bolt.points=points
			bolt_glow.points=points
			bolt.default_color=tint.lightened(0.6)
			bolt_glow.default_color=Color(tint,0.24)
			bolt.show()
			bolt_glow.show()
			motion.tween_interval(0.12)
			motion.tween_property(self,"modulate:a",0.0,0.25)
		"ice":
			picture.texture=textures.ice_frame
			picture.modulate=Color.WHITE
			picture.scale=Vector2(0.55,0.74)*0.7
			picture.show()
			motion.tween_property(picture,"scale",Vector2(0.61,0.74),0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			motion.tween_interval(1.0)
			motion.tween_property(self,"modulate:a",0.0,0.3)
		"arrow_flight", "orb_flight":
			picture.texture=textures.arrow if kind=="arrow_flight" else textures.orb
			picture.scale=Vector2.ONE*float(extra.get("scale",0.24))
			picture.show()
			var to: Vector2=extra.get("to",at+Vector2(100,-300))
			rotation=(to-at).angle()
			motion.tween_property(self,"position",to,float(extra.get("travel",0.8)))
			motion.tween_property(self,"modulate:a",0.0,0.12)
		"critical", "ricochet", "overclock", "echo":
			caption.text = {"critical":"CRITICAL!","ricochet":"REBOUND","overclock":"OVERCLOCK","echo":"ECHO"}[kind]
			caption.add_theme_color_override("font_color", tint)
			caption.show()
			caption.scale = Vector2(0.5,0.5)
			motion.tween_property(caption,"scale",Vector2(1.13,1.13),0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			motion.tween_property(caption,"scale",Vector2.ONE,0.12)
			motion.parallel().tween_property(self,"position",at+Vector2(7,-25),0.32)
			motion.tween_property(self,"modulate:a",0.0,0.28)
		"bomb_drop", "missile":
			picture.texture = textures.bomb if kind=="bomb_drop" else textures.missile
			picture.modulate = Color.WHITE
			picture.scale = Vector2.ONE * (0.28 if kind=="bomb_drop" else 0.25)
			picture.show()
			var from: Vector2 = extra.get("from", at-Vector2(28,150))
			picture.position = from-at
			picture.rotation = -0.3 if kind=="bomb_drop" else (at-from).angle()
			motion.tween_property(picture,"position",Vector2.ZERO,float(extra.get("travel",0.30))).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			motion.parallel().tween_property(picture,"rotation",0.15 if kind=="bomb_drop" else (at-from).angle(),0.30)
			motion.tween_callback(func():
				picture.hide()
				animation.scale = Vector2.ONE*0.8
				animation.show()
				animation.play("explosion")
				if not extra.get("quiet",false): particles.restart()
			)
			motion.tween_interval(0.55)
		"treasure":
			animation.scale = Vector2.ONE * 0.62
			animation.show()
			animation.play("chest")
			motion.tween_interval(0.42)
			motion.tween_property(self,"modulate:a",0.0,0.5)
		"coin":
			picture.texture = textures.coin
			picture.modulate = Color.WHITE
			picture.scale = Vector2.ONE*0.13
			picture.show()
			var offset: Vector2 = extra.get("offset",Vector2(30,-70))
			motion.tween_property(picture,"position",offset,0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			motion.parallel().tween_property(picture,"rotation",5.0,0.28)
			motion.tween_property(picture,"position",offset+Vector2(offset.x*0.5,80),0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			motion.parallel().tween_property(self,"modulate:a",0.0,0.4)
		"explosion", "pierce_bomb", "orbital_explosion", "bomb":
			animation.scale = Vector2.ONE*clampf(float(extra.get("size",95))/128.0,0.4,2)
			animation.show()
			animation.play("explosion")
			if not extra.get("quiet",false): particles.restart()
			motion.tween_interval(0.62)
		"laser", "orbital_beam", "pulse":
			var from: Vector2 = extra.get("from",at)
			var to: Vector2 = extra.get("to",at+Vector2(0,-250))
			position = (from+to)*0.5
			rotation = (to-from).angle()
			picture.texture = textures.beam
			picture.scale = Vector2(from.distance_to(to)/256.0,0.12)
			picture.show()
			motion.tween_property(picture,"scale:y",0.95,0.10)
			motion.tween_interval(0.12)
			motion.tween_property(picture,"scale:y",0.03,0.30)
			motion.parallel().tween_property(self,"modulate:a",0.0,0.30)
		"resonance", "freeze_wave", "mark", "split", "corrosion":
			picture.texture = textures.ring if kind not in ["split","corrosion"] else textures.shard
			picture.scale = Vector2.ONE * 0.12
			picture.show()
			motion.tween_property(picture,"scale",Vector2.ONE*(1.6 if kind=="freeze_wave" else 0.75),0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			motion.parallel().tween_property(picture,"rotation",0.9,0.38)
			motion.tween_property(self,"modulate:a",0.0,0.22)
		_:
			picture.texture = textures.shard if kind=="shatter" else textures.spark
			picture.scale = Vector2.ONE*0.07
			picture.show()
			picture.rotation = float(extra.get("angle",-0.4))
			motion.tween_property(picture,"scale",Vector2.ONE*(0.45 if kind=="power" else 0.3),0.055)
			motion.tween_property(picture,"scale",Vector2.ONE*0.12,0.18)
			motion.parallel().tween_property(self,"modulate:a",0.0,0.18)
			if not extra.get("quiet",false): particles.restart()
	motion.tween_callback(func(): busy=false; hide())
