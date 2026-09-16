extends RefCounted

const LEFT = 45.0
const RIGHT = 675.0
const TOP = 157.0
const RETURN_Y = 928.0
const RADIUS = 7.0
var model
var balls: Array = []
var grid: Dictionary = {}
var shot_direction = Vector2.UP
var launch = Vector2(360, RETURN_Y)
var count = 0
var emitted = 0
var weight = 1.0
var clock = 0.0
var first_return = -1.0
var cap = 96
var max_live = 0
var next_ball_id = 0
var pending_children: Array = []

func setup(run_model):
	model = run_model

func rebuild_grid():
	grid.clear()
	for b in model.bricks:
		if b.hp <= 0:
			continue
		for x in range(b.col, b.col + b.w):
			for y in range(b.row, b.row + b.h):
				grid[Vector2i(x, y)] = b

func fire(direction: Vector2):
	balls.clear()
	rebuild_grid()
	shot_direction = direction.normalized()
	launch = Vector2(model.launch_x, RETURN_Y - 0.1)
	count = mini(cap, model.logical_balls())
	weight = float(model.logical_balls()) / count
	emitted = 0
	clock = 0
	first_return = -1
	max_live = 0

func finished() -> bool:
	return emitted >= count and balls.is_empty()

# Exact swept circle against rectangle: face tests and rounded corner tests.
# A broadphase expanded AABB alone would produce false corner bounces.
static func sweep_circle(origin: Vector2, delta: Vector2, rect: Rect2, radius: float = RADIUS) -> Dictionary:
	var best = {"t":2.0,"normal":Vector2.ZERO}
	# A grid cell is much larger than a fixed-step displacement. Reject the
	# majority of nearby cells before evaluating four faces and four quadratics.
	var travel_bounds = Rect2(origin.min(origin + delta), delta.abs()).grow(0.00001)
	if not rect.grow(radius).intersects(travel_bounds, true):
		return best
	for axis in range(2):
		if absf(delta[axis]) < 0.000001:
			continue
		var other = 1 - axis
		for side in [-1, 1]:
			var edge = rect.position[axis] - radius if side == -1 else rect.end[axis] + radius
			var t = (edge - origin[axis]) / delta[axis]
			var coordinate = origin[other] + delta[other] * t
			if t >= -0.00001 and t <= 1.0 and t < best.t and delta[axis] * side < 0 and coordinate >= rect.position[other] and coordinate <= rect.end[other]:
				var normal = Vector2.ZERO
				normal[axis] = side
				best = {"t":maxf(0, t),"normal":normal}
	var a = delta.length_squared()
	if a < 0.0000001:
		return best
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var rel = origin - corner
		var b = 2 * rel.dot(delta)
		var c = rel.length_squared() - radius * radius
		var disc = b * b - 4 * a * c
		if disc < 0:
			continue
		var t = (-b - sqrt(disc)) / (2 * a)
		if t < -0.00001 or t > 1 or t >= best.t:
			continue
		var point = origin + delta * t
		var normal = (point - corner).normalized()
		# Only the outward quadrant belongs to the rounded corner.
		var valid_x = point.x <= corner.x if corner.x == rect.position.x else point.x >= corner.x
		var valid_y = point.y <= corner.y if corner.y == rect.position.y else point.y >= corner.y
		if valid_x and valid_y and delta.dot(normal) < 0:
			best = {"t":maxf(0, t),"normal":normal}
	return best

func candidates(origin: Vector2, delta: Vector2) -> Array:
	var min_point = origin.min(origin + delta) - Vector2.ONE * RADIUS
	var max_point = origin.max(origin + delta) + Vector2.ONE * RADIUS
	var result: Array = []
	for x in range(maxi(0, floori((min_point.x - 38) / 92)), mini(6, floori((max_point.x - 38) / 92)) + 1):
		for y in range(maxi(0, floori((min_point.y - 150) / 75)), mini(10, floori((max_point.y - 150) / 75)) + 1):
			var b = grid.get(Vector2i(x,y))
			if b != null and b.hp > 0 and not result.has(b):
				result.append(b)
	return result

func trace(origin: Vector2, delta: Vector2, ignored: Array = []) -> Dictionary:
	var best = {"t":1.0,"normal":Vector2.ZERO,"brick":null,"return":false}
	var wall_t = 2.0
	if delta.x < -0.000001:
		wall_t = (LEFT - origin.x) / delta.x
	elif delta.x > 0.000001:
		wall_t = (RIGHT - origin.x) / delta.x
	if wall_t >= 0 and wall_t < best.t:
		best = {"t":wall_t,"normal":Vector2.RIGHT if delta.x < 0 else Vector2.LEFT,"brick":null,"return":false}
	if delta.y < -0.000001:
		wall_t = (TOP - origin.y) / delta.y
		if wall_t >= 0 and wall_t < best.t:
			best = {"t":wall_t,"normal":Vector2.DOWN,"brick":null,"return":false}
	elif delta.y > 0.000001:
		wall_t = (RETURN_Y - origin.y) / delta.y
		if wall_t >= 0 and wall_t <= best.t:
			best = {"t":wall_t,"normal":Vector2.UP,"brick":null,"return":true}
	for b in candidates(origin, delta):
		if ignored.has(b.id):
			continue
		var hit = sweep_circle(origin, delta, model.brick_rect(b))
		if hit.t < best.t:
			best = {"t":hit.t,"normal":hit.normal,"brick":b,"return":false}
	return best

func step(dt: float):
	clock += dt
	model.tick_delayed(dt)
	while emitted < count and clock >= emitted * 0.037:
		if balls.size()>=cap: break
		balls.append(make_ball(launch,shot_direction*model.config.ball_speed*(1.0+model.shot_boost),weight))
		emitted += 1
	max_live = maxi(max_live, balls.size())
	for ball in balls:
		ball.age += dt
		# Escape near-horizontal orbits without teleporting or deleting damage events.
		if ball.age > 25:
			ball.v = Vector2(ball.v.x, maxf(absf(ball.v.y), 300)).normalized() * model.config.ball_speed
		var remaining = dt
		for iteration in range(6):
			if remaining < 0.000001:
				break
			var keep_ignored: Array = []
			for id in ball.ignored:
				for b in candidates(ball.p, Vector2.ZERO):
					if b.id == id and model.brick_rect(b).grow(RADIUS + 0.2).has_point(ball.p):
						keep_ignored.append(id)
			ball.ignored = keep_ignored
			var delta = ball.v * remaining
			var hit = trace(ball.p, delta, ball.ignored)
			ball.p += delta * hit.t
			remaining *= 1.0 - hit.t
			if hit.return:
				if try_ricochet(ball):
					continue
				if first_return < 0:
					first_return = ball.p.x
				ball.dead = true
				break
			if hit.normal == Vector2.ZERO:
				break
			var pierces = false
			if hit.brick != null:
				var amount = model.damage() * ball.weight * (1 + minf(1.5, ball.bounce * 0.06 * model.skill_level("rebound"))) * (1.0+model.shot_boost)
				var critical = model.rng.randf() < model.adjusted_probability(0.1 * model.skill_level("critical"), ball.weight)
				if critical:
					amount *= 2
					model.emit_effect(ball.p, Color("ffbf69"), 52, "critical", 0.5)
				model.enqueue(hit.brick, amount, 0, "primary", ball.weight)
				if model.skill_level("power")>0:
					model.emit_effect(ball.p,Color("ffbf69"),35,"power",0.24)
				try_split(ball,-1.0,int(hit.brick.id))
				pierces = ball.get("piercing",false)
				if pierces:
					model.emit_effect(ball.p, Color("6fbbff"), 60, "pierce", 0.45, {"direction":ball.v.normalized()})
					ball.ignored.append(hit.brick.id)
					if model.skills.has("pierce_bomb"):
						model.area_damage(ball.p, 145, amount * (0.8 + 0.2 * model.skill_level("pierce_bomb")), 1, "pierce_bomb")
			else:
				ball.bounce += 1
				if model.skill_level("rebound") > 0:
					model.emit_effect(ball.p, Color("ff7938"), 24, "wall", 0.24, {"normal":hit.normal})
			if not pierces:
				ball.v = ball.v.bounce(hit.normal)
				ball.p += hit.normal * 0.02
			else:
				ball.p += ball.v.normalized() * 0.02
	balls = balls.filter(func(ball): return not ball.dead)
	for child in pending_children:
		if balls.size()<cap: balls.append(child)
		else:
			# Preserve added damage weight without an unbounded physics population.
			var nearest = balls[0]
			for other in balls:
				if other.p.distance_squared_to(child.p)<nearest.p.distance_squared_to(child.p): nearest=other
			nearest.weight += child.weight
	pending_children.clear()
	model.drain_events(model.config.event_budget)

func aim_path(direction: Vector2) -> Array:
	rebuild_grid()
	var origin = Vector2(model.launch_x, RETURN_Y)
	var result: Array = [origin]
	var dir = direction.normalized()
	for bounce in range(2):
		var hit = trace(origin, dir * 1600)
		var point = origin + dir * 1600 * hit.t
		result.append(point)
		if hit.brick != null or hit.return or hit.normal == Vector2.ZERO:
			break
		dir = dir.bounce(hit.normal)
		origin = point + hit.normal * 0.05
	return result

func make_ball(at: Vector2, velocity: Vector2, logical_weight: float, child: bool = false) -> Dictionary:
	next_ball_id += 1
	var chance = 0.55 if model.skills.has("pierce_bomb") else model.skill_level("pierce")*0.09
	return {"id":next_ball_id,"p":at,"v":velocity,"weight":logical_weight,"bounce":0,"age":0.0,"ignored":[],"dead":false,"split":child,"ricochets":0,"piercing":model.rng.randf()<chance}

func try_ricochet(ball: Dictionary, roll: float = -1.0) -> bool:
	var level = model.skill_level("ricochet")
	if level<=0: return false
	var chance = (0.01+0.03*level)*pow(0.5,int(ball.get("ricochets",0)))
	if roll<0: roll=model.rng.randf()
	if roll>=chance: return false
	ball.ricochets = int(ball.get("ricochets",0))+1
	ball.v = Vector2(ball.v.x,-absf(ball.v.y))
	ball.p.y = RETURN_Y-0.05
	ball.age = 0.0
	model.emit_effect(ball.p-Vector2(0,18),Color("8ef8dd"),60,"ricochet",0.7)
	return true

func try_split(ball: Dictionary, roll: float = -1.0, struck_id: int = -1):
	var level = model.skill_level("split")
	if level<=0: return
	var chance = 0.0025+0.0025*level
	if roll<0: roll=model.rng.randf()
	if roll>=chance: return
	var angle = deg_to_rad(model.rng.randf_range(12,18)) * (-1 if model.rng.randf()<0.5 else 1)
	var child = make_ball(ball.p,ball.v.rotated(angle),ball.weight*0.6,true)
	child.ignored = ball.ignored.duplicate()
	if struck_id>=0: child.ignored.append(struck_id)
	pending_children.append(child)
	model.emit_effect(ball.p,Color("42e6cf"),30,"split",0.35)

func laser_path(direction: Vector2) -> Array:
	var angle = clampf(atan2(direction.x,-direction.y),deg_to_rad(-50),deg_to_rad(50))
	var velocity = Vector2(sin(angle),-cos(angle))
	var origin = Vector2(model.launch_x,RETURN_Y)
	var result: Array = [origin]
	for reflection in range(3):
		var top_distance = (TOP-origin.y)/velocity.y
		var side_distance = INF
		if absf(velocity.x)>0.00001:
			side_distance = ((RIGHT if velocity.x>0 else LEFT)-origin.x)/velocity.x
		if top_distance<=side_distance:
			result.append(origin+velocity*top_distance)
			break
		origin += velocity*side_distance
		result.append(origin)
		velocity.x = -velocity.x
	return result
