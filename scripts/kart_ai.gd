extends "res://scripts/kart_power.gd"
## Kart — IA: faixa, desvio (buraco primeiro), caixas, ultrapassagem, drift, itens, barracas e quando usar o poder.
## (camada de kart.gd — ver o topo de kart.gd)


func _ai_input(delta: float) -> void:
	_ai_power(delta)
	var n: int = track.sample_count()
	var m: float = maxf(1.5, minf(track.road_half(track_idx), track.road_half((track_idx + 8) % n)) - 2.5)  # RF-370: largura local
	ai_lane_timer -= delta
	if ai_lane_timer <= 0.0:
		# RF-213: quem tem mais "foco" troca menos de faixa à toa
		ai_lane = clampf(lerpf(randf_range(-m, m), ai_lane, ai_focus * 0.6), -m, m)
		ai_lane_timer = randf_range(2.0, 5.0) * (1.0 + ai_focus)
	_ai_tactics(n, m)
	# RF-371: barracas no meio da pista à frente: escolhe a faixa e fica nela até passar
	for kk in range(0, 36, 3):
		var isl: Dictionary = track.island_at((track_idx + kk) % n)
		if isl.is_empty():
			continue
		var ih: float = track.road_half((int(isl["i0"]) + int(isl["len"]) / 2) % n)
		var ss: float = float(isl["side"])
		var side := ss if ai_aggro >= 0.5 else -ss  # atrevido vai pelo atalho
		var lo := (-ih + 1.5) if side < 0 else (float(isl["lat1"]) + 1.5)
		var hi := (float(isl["lat0"]) - 1.5) if side < 0 else (ih - 1.5)
		if ai_lane < lo or ai_lane > hi:
			ai_lane = (lo + hi) * 0.5
		ai_lane_timer = maxf(ai_lane_timer, 0.4)
		break
	# desviando: olha mais perto pra esterçar mais rápido (RF-210)
	ai_evading = maxf(0.0, ai_evading - delta)
	var look := (3 + int(absf(speed) * 0.12)) if ai_evading > 0.0 else (5 + int(absf(speed) * 0.3))
	var ti := (track_idx + look) % n
	# RF-321: o alvo no meio do looping fica "atrás" no plano; mira a entrada dele
	if not on_loop and track.in_loop(ti):
		ti = int(track.loops[track.loop_id[ti]]["i0"])
	var target: Vector3 = track.points[ti] + track.rights[ti] * ai_lane
	var to := target - position
	var desired := atan2(-to.x, -to.z)
	var diff := wrapf(desired - heading, -PI, PI)
	in_steer = clampf(-diff * 2.2, -1.0, 1.0)
	in_throttle = 0.4 if absf(diff) > 1.2 else 1.0
	var drift_start := lerpf(0.45, 0.25, ai_drift)  # RF-213: quem gosta de drift começa antes
	if drifting:
		in_drift = absf(diff) > 0.08 and signf(-diff) == drift_dir
	else:
		in_drift = absf(diff) > drift_start and speed > DRIFT_MIN_SPEED + 3.0

	# itens (RF-42 + RF-205), agressividade adianta o uso (RF-213)
	if item != "" and item_roll <= 0.0:
		var eager := lerpf(1.5, 0.5, ai_aggro)
		match item:
			"turbo", "triplo":
				in_item = item_hold > (0.8 if item == "turbo" else 1.2) * eager and absf(diff) < 0.2
			"casca", "ratoeira":
				in_item = item_hold > ai_item_delay * eager or race.kart_behind(self, 12.0 + 12.0 * ai_aggro)
			"bomba":
				in_item = item_hold > 8.0 * eager or (item_hold > 0.5 and race.kart_in_sight(self, 30.0 + 30.0 * ai_aggro))
			"escudo":
				in_item = item_hold > 1.0
			"gato":
				in_item = item_hold > 0.6 * eager


## RF-210..212: desviar > caixa > ultrapassar > setas de turbo.
func _ai_tactics(n: int, m: float) -> void:
	# desvio de casca/ratoeira
	var reach := int(16 + 10 * ai_avoid)
	var ahead: Array = race.ground_hazards_ahead(self, reach)
	ahead.sort_custom(func(a, b): return a.get(Ids.AHEAD_PIT, false) and not b.get(Ids.AHEAD_PIT, false))  # buraco primeiro
	for hz in ahead:
		var id: int = hz["id"]
		var must: bool = hz.get(Ids.AHEAD_PIT, false)  # RF-390: buraco — todo mundo desvia, com folga do tamanho dele
		if not ai_seen.has(id):
			ai_seen[id] = must or randf() < 0.25 + 0.75 * ai_avoid
		var clear: float = float(hz.get("r", 0.0)) + 2.4 if must else 2.8
		if ai_seen[id] and (absf(float(hz["lat"]) - ai_lane) < clear or (must and absf(float(hz["lat"]) - lateral) < clear)):
			var lat: float = hz["lat"]
			var side := -1.0 if lat > 0.0 else 1.0
			ai_lane = clampf(lat + side * (clear + 1.2 if must else 4.5), -m, m)
			ai_evading = 1.0
			ai_lane_timer = maxf(ai_lane_timer, 1.2)
			return
	# caixa de item
	if item == "" and not ai_box_skip:
		var box_lat: float = race.box_ahead(self, 30)
		if not is_nan(box_lat):
			ai_lane = clampf(box_lat, -m, m)
			ai_lane_timer = maxf(ai_lane_timer, 0.8)
			return
	# ultrapassagem
	var slow_lat: float = race.slow_kart_ahead(self, 10.0, 2.5)
	if not is_nan(slow_lat):
		var side := 1.0 if slow_lat < 0.0 else -1.0
		ai_lane = clampf(slow_lat + side * 4.0, -m, m)
		ai_lane_timer = maxf(ai_lane_timer, 1.5)
		return
	# RF-140: às vezes mira na seta de turbo à frente
	for p in track.pads:
		var dp := wrapi(int(p["idx"]) - track_idx, 0, n)
		if dp > 4 and dp < 25 and ai_pad_target != int(p["idx"]):
			ai_pad_target = int(p["idx"])
			if randf() < 0.5:
				ai_lane = float(p["lat"])
				ai_lane_timer = 3.0


## IA decide quando usar o poder (cada um do seu jeito).
func _ai_power(delta: float) -> void:
	in_power = false
	ai_power_wait -= delta
	if power_charges > 0:
		# planta: um mini-turbo de tempos em tempos, de preferência na reta
		if ai_power_wait <= 0.0 and track.curvature_at(track_idx) < 0.35:
			in_power = true
			ai_power_wait = 1.1
		return
	if not power_ready() or ai_power_wait > 0.0:
		return
	var near := 99.0
	var ahead_near := 99.0
	for o in race.karts:
		if o == self:
			continue
		var d: float = position.distance_to(o.position)
		near = minf(near, d)
		if (o.position - position).dot(forward()) > 0.0:
			ahead_near = minf(ahead_near, d)
	var impl := PowerRegistry.of(power_id())  # RF-451: cada poder decide (scripts/powers)
	var go: bool = impl != null and impl.ai_wants(race, self, {"near": near, "ahead_near": ahead_near})
	if go:
		in_power = true
		ai_power_wait = 1.0
	else:
		ai_power_wait = 0.25
