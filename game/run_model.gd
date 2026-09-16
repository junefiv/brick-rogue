extends RefCounted

const SAVE_PATH = "user://run_v1.json"
var config = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
var rng = RandomNumberGenerator.new()
var bricks: Array = []
var skills: Dictionary = {}
var cooldowns: Dictionary = {}
var round_no = 1
var level = 1
var xp = 0
var points = 0
var purchased_balls = 0
var launch_x = 360.0
var serial = 0
var hits = 0
var kills = 0
var shards = 0
var dismantled = 0
var rerolls = 1
var stop_rounds = 0
var lab = false
var final_dead = false
var boss_killed = false
var endless = false
var effects: Array = []
var event_queue: Array = []
var event_cursor = 0
var vfx_budget = 16
var events_peak = 0

func reset(is_lab: bool = false):
	rng.randomize()
	bricks.clear()
	skills.clear()
	cooldowns.clear()
	round_no = 1
	level = 1
	xp = 0
	points = 0
	purchased_balls = 0
	launch_x = 360
	serial = 0
	hits = 0
	kills = 0
	shards = 0
	dismantled = 0
	rerolls = 1
	stop_rounds = 0
	final_dead = false
	boss_killed = false
	endless = false
	lab = is_lab
	event_queue.clear()
	event_cursor = 0
	effects.clear()
	if lab:
		skills = {"multi":5, "lightning":5, "pierce":5, "blast":5, "critical":5, "rebound":5, "laser":5, "bomb":5, "freeze":3, "stop":3}
		purchased_balls = 40
		points = 999999
		for row in range(9):
			for col in range(7):
				add_brick(col, row, 500, "normal")
	else:
		spawn_row(0)
		spawn_row(1)
		spawn_row(2)

func required_xp() -> int:
	return ceili(config.xp_base + config.xp_linear * level + config.xp_power * pow(level, 1.5))

func skill_level(id: String) -> int:
	return int(skills.get(id, 0))

func count_type(type: String) -> int:
	var total = 0
	for id in skills:
		if config.skills[id].type == type:
			total += 1
	return total

func logical_balls() -> int:
	if lab:
		return 300
	return mini(config.ball_cap, config.initial_balls + purchased_balls + (32 + 8 * skill_level("thunder_swarm") if skills.has("thunder_swarm") else 0))

func multiball_cost() -> int:
	# One click buys exactly one ball. Every owned purchase raises the next price.
	return 100 + 50 * maxi(0, logical_balls() - config.initial_balls)

func can_buy_multiball() -> bool:
	if lab or logical_balls() >= config.ball_cap or points < multiball_cost():
		return false
	var next_tier = mini(5, int((purchased_balls + 1) / 8))
	return next_tier <= skill_level("multi") or skills.has("multi") or count_type("passive") < config.passive_slots

func buy_multiball() -> bool:
	if not can_buy_multiball():
		return false
	points -= multiball_cost()
	purchased_balls += 1
	var tier_level = mini(5, int(purchased_balls / 8))
	if tier_level > 0:
		skills["multi"] = tier_level
	emit_effect(Vector2(launch_x, 952), Color("53f5d0"), 90, "multiball", 0.9)
	return true

func damage() -> float:
	return 1.0 + skill_level("power")

func add_brick(col: int, row: int, hp: int, kind: String, width: int = 1, height: int = 1):
	serial += 1
	bricks.append({"id":serial,"col":col,"row":row,"w":width,"h":height,"hp":hp,"max_hp":hp,"kind":kind,"frozen":0,"shield":2 if kind == "shield" else 0,"flash":0.0})

func brick_rect(b: Dictionary) -> Rect2:
	return Rect2(42 + b.col * 92, 264 + b.row * 70, b.w * 92 - 8, b.h * 70 - 8)

func overlaps_cells(b: Dictionary, col: int, row: int, width: int, height: int) -> bool:
	return b.hp > 0 and b.col < col + width and b.col + b.w > col and b.row < row + height and b.row + b.h > row

func prepare_boss_area(width: int, height: int) -> int:
	var candidates: Array = []
	for col in range(0, 8 - width):
		var overlap_count = 0
		for b in bricks:
			if overlaps_cells(b, col, 0, width, height):
				overlap_count += 1
		candidates.append({"col":col,"overlaps":overlap_count,"center_distance":absf((col + width * 0.5) - 3.5)})
	candidates.sort_custom(func(a, b):
		if a.overlaps == b.overlaps:
			return a.center_distance < b.center_distance
		return a.overlaps < b.overlaps
	)
	var boss_col = int(candidates[0].col)
	var displaced = bricks.filter(func(b): return overlaps_cells(b, boss_col, 0, width, height))
	for b in displaced:
		var relocated = false
		for target_row in range(0, height):
			for target_col in range(7):
				if target_col >= boss_col and target_col < boss_col + width:
					continue
				var occupied = bricks.any(func(other):
					return other.id != b.id and overlaps_cells(other, target_col, target_row, 1, 1)
				)
				if not occupied:
					b.col = target_col
					b.row = target_row
					b.w = 1
					b.h = 1
					relocated = true
					break
			if relocated:
				break
		if not relocated:
			b.hp = 0
	bricks = bricks.filter(func(b): return b.hp > 0)
	return boss_col

func spawn_row(row: int = 0):
	if round_no % 10 == 0 and row == 0 and round_no <= 40:
		var boss_width = 3 if round_no == 40 else 2
		var boss_col = prepare_boss_area(boss_width, 2)
		add_brick(boss_col, 0, int(60 + round_no * 9), "boss", boss_width, 2)
		emit_effect(brick_rect(bricks.back()).get_center(), Color("b59aff"), 170, "boss_spawn", 1.2)
		return
	var gap = rng.randi_range(0, 6)
	var base_hp = int(round(config.hp_base + config.hp_linear * round_no + config.hp_power * pow(round_no, config.hp_exponent)))
	for col in range(7):
		if col == gap or rng.randf() > minf(0.78, 0.55 + round_no * 0.004):
			continue
		var occupied = false
		for b in bricks:
			if b.hp > 0 and col >= b.col and col < b.col + b.w and row >= b.row and row < b.row + b.h:
				occupied = true
		if occupied:
			continue
		var kind = "normal"
		if round_no > 3 and rng.randf() < 0.2:
			kind = "armor"
		if round_no > 10 and rng.randf() < 0.14:
			kind = "shield"
		if rng.randf() < 0.09:
			kind = "explosive"
		add_brick(col, row, maxi(1, int(base_hp * rng.randf_range(0.85, 1.2))), kind)

func enqueue(b: Dictionary, amount: float, depth: int = 0, group: String = "primary", weight: float = 1):
	event_queue.append({"brick":b,"amount":amount,"depth":depth,"group":group,"weight":weight})
	events_peak = maxi(events_peak, event_queue.size() - event_cursor)

func emit_effect(pos: Vector2, color: Color, radius: float = 30, kind: String = "burst", duration: float = 0.5, extra: Dictionary = {}):
	if vfx_budget <= 0:
		return
	if kind in ["thunder_swarm","freeze_wave","time_stop","laser","orbital_beam","boss_spawn"]:
		for existing in effects:
			if existing.kind == kind:
				existing.life = maxf(existing.life, duration)
				for key in extra:
					existing[key] = extra[key]
				return
	if effects.size() >= 48:
		return
	vfx_budget -= 1
	var effect = {"p":pos,"color":color,"r":radius,"life":duration,"duration":duration,"kind":kind,"seed":serial + hits * 17 + effects.size() * 31}
	for key in extra:
		effect[key] = extra[key]
	effects.append(effect)

func adjusted_probability(p: float, weight: float) -> float:
	return 1.0 - pow(1.0 - clampf(p, 0, 1), weight)

func drain_events(budget: int = 256):
	var processed = 0
	while event_cursor < event_queue.size() and processed < budget:
		var event = event_queue[event_cursor]
		event_cursor += 1
		processed += 1
		var b = event.brick
		if b.hp <= 0:
			continue
		if b.shield > 0:
			b.shield -= 1
			b.flash = 0.15
			emit_effect(brick_rect(b).get_center(), Color("6fbbff"), 48, "shield", 0.45)
			continue
		var dealt = event.amount
		if b.kind == "armor":
			dealt = maxf(1, dealt - 1)
		b.hp -= dealt
		b.flash = 0.12
		if skill_level("power") > 0 and event.group == "primary" and (hits + 1) % 8 == 0:
			emit_effect(brick_rect(b).get_center(), Color("ffbf69"), 34, "power", 0.34)
		if event.group == "primary":
			hits += 1
			proc_primary(b, event)
		if b.hp <= 0:
			kills += 1
			var reward = 50 if b.kind == "boss" else (3 if b.kind == "normal" else 5)
			xp += reward
			points += reward * 100
			emit_effect(brick_rect(b).get_center(), Color("53f5d0"), 58, "shatter", 0.65)
			if b.kind == "boss":
				shards += 2
				boss_killed = true
				if round_no >= 40:
					final_dead = true
			if b.kind == "explosive" and event.depth < config.chain_depth:
				area_damage(brick_rect(b).get_center(), 150, event.amount + 3, event.depth + 1, "explosive")
	if event_cursor >= event_queue.size():
		event_queue.clear()
		event_cursor = 0

func proc_primary(b: Dictionary, event: Dictionary):
	var center = brick_rect(b).get_center()
	var blast = skill_level("blast")
	if blast > 0 and rng.randf() < adjusted_probability(0.08 * blast, event.weight):
		area_damage(center, 105 + blast * 7, event.amount * 0.6, 1, "blast")
	var chain = skill_level("lightning")
	if chain > 0 and rng.randf() < adjusted_probability(0.07 * chain, event.weight):
		var targets: Array = []
		var lightning_points: Array = [center]
		# Compute geometry once per candidate, not twice per sort comparison.
		for other in bricks:
			if other.hp > 0 and other.id != b.id:
				targets.append([brick_rect(other).get_center().distance_squared_to(center),other])
		targets.sort_custom(func(a, c): return a[0] < c[0])
		for i in range(mini(chain + 1, targets.size())):
			enqueue(targets[i][1], event.amount * 0.7, 1, "lightning")
			lightning_points.append(brick_rect(targets[i][1]).get_center())
		if lightning_points.size() > 1:
			emit_effect(center, Color("c5a1ff"), 40, "lightning_chain", 0.55, {"points":lightning_points})
	if skills.has("thunder_swarm") and hits % 12 == 0:
		var storm_targets: Array = []
		for other in bricks:
			if other.hp > 0:
				storm_targets.append(brick_rect(other).get_center())
		emit_effect(Vector2(360, 270), Color("c5a1ff"), 320, "thunder_swarm", 0.9, {"targets":storm_targets})
		for other in bricks:
			if other.hp > 0:
				enqueue(other, event.amount * (0.5 + 0.25 * skill_level("thunder_swarm")), 1, "swarm")
	var frost = skill_level("frost")
	if frost > 0 and rng.randf() < adjusted_probability(0.03 * frost, event.weight):
		b.frozen = 1
		emit_effect(center, Color("96edff"), 55, "frost", 0.75)

func area_damage(center: Vector2, radius: float, amount: float, depth: int, group: String):
	if depth > config.chain_depth:
		return
	var effect_kind = {
		"blast":"explosion", "explosive":"explosion", "pierce_bomb":"pierce_bomb",
		"orbital":"orbital_explosion", "active":"bomb"
	}.get(group, "explosion")
	var effect_color = Color("96edff") if group == "frost" else Color("ff7d9b")
	emit_effect(center, effect_color, radius, effect_kind, 0.75)
	for b in bricks:
		if b.hp > 0 and brick_rect(b).get_center().distance_to(center) <= radius:
			enqueue(b, amount, depth, group)

func has_events() -> bool:
	return event_cursor < event_queue.size()

func card_pool() -> Array:
	var pool: Array = []
	for id in config.skills:
		if id == "multi":
			continue
		var spec = config.skills[id]
		if skills.has(id):
			if skill_level(id) < (3 if spec.get("fusion", false) else 5):
				pool.append(id)
		elif not spec.get("fusion", false):
			var cap = config.passive_slots if spec.type == "passive" else config.active_slots
			if count_type(spec.type) < cap:
				pool.append(id)
	return pool

func draw_cards() -> Array:
	var pool = card_pool()
	var picks: Array = []
	while not pool.is_empty() and picks.size() < 3:
		var index = rng.randi_range(0, pool.size() - 1)
		picks.append(pool.pop_at(index))
	return picks

func apply_card(id: String) -> bool:
	if not card_pool().has(id):
		return false
	skills[id] = skill_level(id) + 1
	return true

func consume_level() -> bool:
	if level >= config.max_level or xp < required_xp():
		return false
	xp -= required_xp()
	level += 1
	return true

func available_fusions() -> Array:
	return config.fusions.filter(func(recipe): return skill_level(recipe.a) == 5 and skill_level(recipe.b) == 5)

func fuse(recipe: Dictionary) -> bool:
	if not available_fusions().has(recipe):
		return false
	var inherited_cd = maxi(int(cooldowns.get(recipe.a, 0)), int(cooldowns.get(recipe.b, 0)))
	skills.erase(recipe.a)
	skills.erase(recipe.b)
	if recipe.result == "thunder_swarm":
		purchased_balls = maxi(0, purchased_balls - 40)
	cooldowns.erase(recipe.a)
	cooldowns.erase(recipe.b)
	skills[recipe.result] = 1
	cooldowns[recipe.result] = inherited_cd
	return true

func dismantle(id: String) -> bool:
	if not boss_killed or not skills.has(id):
		return false
	var cap = config.passive_slots if config.skills[id].type == "passive" else config.active_slots
	if count_type(config.skills[id].type) >= cap or (dismantled > 0 and shards < 1):
		return false
	for recipe in config.fusions:
		if recipe.result == id:
			if skills.has(recipe.a) or skills.has(recipe.b):
				return false
			var cd = int(cooldowns.get(id, 0))
			skills.erase(id)
			cooldowns.erase(id)
			skills[recipe.a] = 5
			skills[recipe.b] = 5
			if id == "thunder_swarm":
				purchased_balls += 40
			cooldowns[recipe.a] = cd
			cooldowns[recipe.b] = cd
			if dismantled > 0:
				shards -= 1
			dismantled += 1
			return true
	return false

func descend():
	bricks = bricks.filter(func(b): return b.hp > 0)
	# Resolve from bottom upwards so frozen blocks never overlap descending ones.
	bricks.sort_custom(func(a, b): return a.row > b.row)
	for b in bricks:
		if stop_rounds > 0:
			continue
		if b.frozen > 0:
			b.frozen -= 1
			continue
		var blocked = false
		for other in bricks:
			if other.id != b.id and other.row == b.row + b.h and other.col < b.col + b.w and other.col + other.w > b.col:
				blocked = true
		if not blocked:
			b.row += 1
	stop_rounds = maxi(0, stop_rounds - 1)
	round_no += 1
	for id in cooldowns:
		cooldowns[id] = maxi(0, cooldowns[id] - 1)
	spawn_row()

func is_dead() -> bool:
	return bricks.any(func(b): return b.hp > 0 and b.row + b.h > 9)

func save_run():
	if lab:
		return
	var data = {"version":1,"round":round_no,"level":level,"xp":xp,"points":points,"purchased_balls":purchased_balls,"launch_x":launch_x,"serial":serial,"hits":hits,"kills":kills,"skills":skills,"cooldowns":cooldowns,"bricks":bricks,"shards":shards,"dismantled":dismantled,"rerolls":rerolls,"stop_rounds":stop_rounds,"final_dead":final_dead,"endless":endless,"rng_state":str(rng.state),"rng_seed":str(rng.seed)}
	var file = FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH)

func load_run() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(SAVE_PATH)) != OK:
		return false
	var data = parser.data
	if not data is Dictionary or data.get("version") != 1:
		return false
	for key in ["bricks", "skills", "cooldowns", "round", "level", "xp", "launch_x"]:
		if not data.has(key):
			return false
	if not data.bricks is Array or not data.skills is Dictionary or not data.cooldowns is Dictionary:
		return false
	if data.round < 1 or data.level < 1 or data.level > 30 or data.bricks.size() > 80:
		return false
	for b in data.bricks:
		if not b is Dictionary:
			return false
		for key in ["id","col","row","w","h","hp","max_hp","kind","frozen","shield","flash"]:
			if not b.has(key):
				return false
	for id in data.skills:
		if not config.skills.has(id) or data.skills[id] < 1 or data.skills[id] > (3 if config.skills[id].get("fusion", false) else 5):
			return false
	skills = data.skills
	if count_type("passive") > 6 or count_type("active") > 4:
		skills = {}
		return false
	bricks = data.bricks
	cooldowns = data.cooldowns
	round_no = int(data.round)
	level = int(data.level)
	xp = int(data.xp)
	points = int(data.get("points", data.get("score", 0)))
	purchased_balls = clampi(int(data.get("purchased_balls", skill_level("multi") * 8)), 0, config.ball_cap - config.initial_balls)
	launch_x = clampf(data.launch_x, 45, 675)
	serial = int(data.get("serial", 1000))
	hits = int(data.get("hits", 0))
	kills = int(data.get("kills", 0))
	shards = int(data.get("shards", 0))
	dismantled = int(data.get("dismantled", 0))
	rerolls = int(data.get("rerolls", 1))
	stop_rounds = int(data.get("stop_rounds", 0))
	final_dead = data.get("final_dead", false)
	endless = data.get("endless", false)
	rng.seed = int(data.get("rng_seed", "1"))
	rng.state = int(data.get("rng_state", "1"))
	lab = false
	return true
