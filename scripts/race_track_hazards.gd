extends "res://scripts/race_world.gd"
## Corrida — perigos da pista (cada tipo em scripts/hazards; aqui só cria, atualiza e avisa a IA).
## (camada de race.gd — ver o topo de race.gd)


func _spawn_track_hazards() -> void:
	for s in track.hazard_specs:
		var impl := HazardRegistry.of(String(s["kind"]))
		if impl == null:
			push_warning("perigo desconhecido: %s" % s["kind"])
			continue
		var h := {"spec": s, "state": "off", "impl": impl}
		impl.spawn(self, h)
		track_hazards.append(h)
	_update_track_hazards(0.0, false)


func _update_track_hazards(delta: float, can_drive: bool) -> void:
	hazard_clock += delta
	var t_live := race_time if state != "countdown" else -1.0
	var n: int = track.sample_count()
	for h in track_hazards:
		h["impl"].update(self, h, can_drive, t_live, n)


## RF-272: perigos que a IA deve evitar agora (mesmo formato da casca: id, lat).
func _track_hazards_ahead(k: Node3D, samples: int, out: Array) -> void:
	var n: int = track.sample_count()
	for hi in track_hazards.size():
		var h: Dictionary = track_hazards[hi]
		var ds := wrapi(int(h["spec"]["idx"]) - k.track_idx, 0, n)
		if ds > 0 and ds < samples:
			h["impl"].ahead(self, h, hi, ds, out)
	for pi in track.pits.size():  # RF-390: buracos (desvio obrigatório)
		var pt: Dictionary = track.pits[pi]
		var dp := wrapi(int(pt["idx"]) - k.track_idx, 0, n)
		if dp > 0 and dp < samples:
			out.append({"id": 3000000 + pi, "lat": float(pt["lat"]), "r": float(pt["r"]), Ids.AHEAD_PIT: true})
	for zi in track.zones.size():
		var z: Dictionary = track.zones[zi]
		if not Ids.SLOW_ZONES.has(z["kind"]):
			continue
		var dz := wrapi(int(z["i0"]) - k.track_idx, 0, n)
		if dz > 0 and dz < samples:
			out.append({"id": 2000000 + zi, "lat": (float(z["lat0"]) + float(z["lat1"])) * 0.5})
