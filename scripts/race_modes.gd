extends "res://scripts/race_items.gd"
## Corrida — modos e chegada: contra o relógio (fantasma, recorde), Grand Prix (pontos), sons de volta e chegada.
## (camada de race.gd — ver o topo de race.gd)


func _human_lap_sounds() -> void:
	for i in players.size():
		var p: Node3D = players[i]
		var lap := lap_of(p)
		if lap > human_laps[i] and not p.finished:
			sfx("final_lap" if lap == laps and laps > 1 else "lap")  # RF-207: vinheta da volta final
		human_laps[i] = lap


## RF-134: na volta final de algum humano a música acelera 8%.
func _final_lap_music() -> void:
	var game := get_node_or_null("/root/Game")
	if game == null or game.music == null:
		return
	var fast := false
	for p in players:
		if not p.finished and lap_of(p) == laps and laps > 1:
			fast = true
	game.music.pitch_scale = 1.08 if fast else 1.0


func _check_finish(delta: float) -> void:
	var n: int = track.sample_count()
	for k in karts:
		if not k.finished and k.progress >= laps * n:
			k.finished = true
			k.finish_time = race_time
			k.autopilot = true
			if k.is_player:
				sfx("finish")
				sfx("crowd")
				k.celebrate()
	if state == "racing" and humans_finished():  # RF-65
		state = "finished"
		end_timer = RESULTS_DELAY
	if state == "finished" and not results_shown:
		end_timer -= delta
		if end_timer <= 0.0 or all_finished():
			results_shown = true
			_award_gp()  # RF-192
			_tt_submit()  # RF-232
			if results_hud:
				results_hud.show_results()


func _award_gp() -> void:
	if not is_gp():
		return
	var ids := []
	for k in ranking():
		ids.append(k.char_id)
	var got: Dictionary = get_node("/root/Game").gp_award(ids)
	if not got.is_empty():
		gp_gained = got


## Botão PRÓXIMA / PÓDIO DO GP.
func gp_continue() -> void:
	var game := get_node_or_null("/root/Game")
	if game == null:
		return
	_leave()
	if game.gp_next():
		game.go_race(true)  # RF-350
	else:
		get_tree().change_scene_to_file("res://scenes/gp_final.tscn")


func _tt_setup() -> void:
	tt_record = Records.get_record(track.def["id"])
	tt_ghost_data = tt_record.get("ghost", PackedFloat32Array())
	if tt_ghost_data.size() < 8:
		return
	var who: Dictionary = Chars.find(String(tt_record.get("race_char", "fejaum")))
	tt_ghost = KartScript.new()
	tt_ghost.name = "Fantasma"
	add_child(tt_ghost)
	tt_ghost.setup(who, -1, track, self)
	if tt_ghost.name_label:
		tt_ghost.name_label.text = "RECORDE"
	_ghostify(tt_ghost)
	_tt_ghost_pose(0.0)


## Deixa o kart translúcido e sem sombra.
func _ghostify(n: Node) -> void:
	if n is GeometryInstance3D:
		n.transparency = 0.5
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if n is GPUParticles3D or n is CPUParticles3D:
		n.emitting = false
		n.visible = false
	for c in n.get_children():
		_ghostify(c)


func _tt_ghost_pose(t: float) -> void:
	if tt_ghost == null:
		return
	var s := Records.ghost_sample(tt_ghost_data, t)
	if s.is_empty():
		tt_ghost.visible = t <= 0.0
		return
	tt_ghost.visible = true
	tt_ghost.position = s["pos"]
	tt_ghost.rotation.y = s["heading"]


func _tt_step() -> void:
	var t := race_time if state != "countdown" else 0.0
	_tt_ghost_pose(t)
	if state == "countdown" or player == null:
		return
	# voltas
	var lap := lap_of(player)
	if lap > tt_last_lap and not player.finished:
		tt_laps.append(race_time - tt_lap_start)
		tt_lap_start = race_time
	tt_last_lap = lap
	# RF-233: grava nos instantes exatos k*GHOST_STEP interpolando com o quadro anterior
	var cur := {"t": race_time, "pos": player.position, "h": player.heading}
	if tt_prev.is_empty():
		tt_prev = {"t": 0.0, "pos": player.position, "h": player.heading}
		_tt_push(tt_prev["pos"], tt_prev["h"])
	while not player.finished:
		var next_t := (tt_ghost_rec.size() / 4) * Records.GHOST_STEP
		if next_t > race_time:
			break
		var span: float = cur["t"] - tt_prev["t"]
		var w: float = 1.0 if span <= 0.0 else clampf((next_t - tt_prev["t"]) / span, 0.0, 1.0)
		_tt_push(tt_prev["pos"].lerp(cur["pos"], w), lerp_angle(tt_prev["h"], cur["h"], w))
	tt_prev = cur


func _tt_push(p: Vector3, h: float) -> void:
	tt_ghost_rec.append_array(PackedFloat32Array([p.x, p.y, p.z, h]))


## Fecha a última volta e grava o recorde (uma vez só).
func _tt_submit() -> void:
	if not time_trial or tt_submitted or not player.finished:
		return
	tt_submitted = true
	if tt_laps.size() < laps:
		tt_laps.append(player.finish_time - tt_lap_start)
	tt_result = Records.submit(track.def["id"], player.char_id, player.finish_time, tt_best_lap(), tt_ghost_rec)


func tt_best_lap() -> float:
	var best := INF
	for l in tt_laps:
		best = minf(best, l)
	return best
