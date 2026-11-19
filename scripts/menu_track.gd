extends "res://scripts/menu_pilot.gd"
## Menu — etapas PISTA e AJUSTES (grade de pistas/copas, trajeto, voltas/IA, resumo e largada).
## (camada de menu.gd — ver o topo de menu.gd)


## RF-292: etapa 3 — lista de pistas + trajeto desenhado + informações.
func _build_track() -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 22)
	# RF-400: grade de cartões (trajeto em miniatura + nome) no lugar da lista comprida
	var list := GridContainer.new()
	list.columns = GRID_COLS
	list.add_theme_constant_override("h_separation", 12)
	list.add_theme_constant_override("v_separation", 12)
	list.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(list)
	for i in TrackScript.TRACKS.size():
		var td: Dictionary = TrackScript.TRACKS[i]
		var b := _button("", 16)
		b.custom_minimum_size = TRACK_CARD
		b.focus_mode = Control.FOCUS_ALL
		var band := ColorRect.new()  # cor do tema da pista
		band.color = td["wall"][0]
		band.position = Vector2(10, 8)
		band.size = Vector2(TRACK_CARD.x - 20, 5)
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(band)
		var mini := TrackMap.new()
		mini.thin = true
		mini.position = Vector2(8, 16)
		mini.size = Vector2(TRACK_CARD.x - 16, TRACK_CARD.y - 58)
		mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mini.line_color = (td["wall"][0] as Color).lightened(0.35)
		mini.set_track(td["id"], false)
		b.add_child(mini)
		track_minis.append(mini)
		var nm := _label(td["name"], 15, Color.WHITE)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.position = Vector2(6, TRACK_CARD.y - 44)
		nm.size = Vector2(TRACK_CARD.x - 12, 38)
		b.add_child(nm)
		track_names.append(nm)
		b.pressed.connect(func(): _pick_track(i))
		b.focus_entered.connect(func():
			if started:
				pass
			elif _is_gp():
				cup_i = mini(i, _cups().size() - 1)
			else:
				track_i = i
			_refresh_track())
		b.mouse_entered.connect(func(): b.grab_focus())
		list.add_child(b)
		track_btns.append(b)
	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.1, 0.11, 0.2)
	st.set_corner_radius_all(18)
	st.set_border_width_all(3)
	st.border_color = Color(1.0, 0.82, 0.2, 0.7)
	st.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", st)
	panel.custom_minimum_size = Vector2(520, 0)
	hb.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	track_title = _label("", 30, Color(1.0, 0.85, 0.3))
	track_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(track_title)
	track_map = TrackMap.new()
	track_map.custom_minimum_size = Vector2(488, 270)
	track_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(track_map)
	track_desc = _label("", 17, Color(0.9, 0.92, 1.0))
	track_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	track_desc.custom_minimum_size.x = 488
	vb.add_child(track_desc)
	track_info = _label("", 16, Color(0.75, 0.9, 1.0))
	track_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	track_info.custom_minimum_size.x = 488
	vb.add_child(track_info)
	return hb


## RF-293: etapa 4 — voltas, IA e resumo, depois CORRER!.
func _build_setup() -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 30)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(col)
	laps_btn = _button("", 24)
	laps_btn.custom_minimum_size = Vector2(420, 66)
	laps_btn.focus_mode = Control.FOCUS_ALL
	laps_btn.pressed.connect(func(): _cycle_laps(1))
	_add_arrows(laps_btn)
	col.add_child(laps_btn)
	diff_btn = _button("", 24)
	diff_btn.custom_minimum_size = Vector2(420, 66)
	diff_btn.focus_mode = Control.FOCUS_ALL
	diff_btn.pressed.connect(func(): _cycle_diff(1))
	_add_arrows(diff_btn)
	col.add_child(diff_btn)
	go_btn = _button("CORRER!", 34)
	go_btn.custom_minimum_size = Vector2(420, 80)
	go_btn.focus_mode = Control.FOCUS_ALL
	GameScript.make_primary(go_btn)  # RF-174
	go_btn.pressed.connect(_start_race)
	col.add_child(go_btn)
	# RF-341: cartão de resumo — modo, retratos dos pilotos e o trajeto da pista
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_style(Color(1.0, 0.82, 0.2, 0.55)))
	panel.custom_minimum_size = Vector2(470, 0)
	hb.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)
	vb.add_child(_caption("MODO"))
	sum_mode = _label("", 26, Color.WHITE)
	vb.add_child(sum_mode)
	sum_pilots_cap = _caption("PILOTO")
	vb.add_child(_gap(8))
	vb.add_child(sum_pilots_cap)
	sum_pilots = HBoxContainer.new()
	sum_pilots.add_theme_constant_override("separation", 12)
	vb.add_child(sum_pilots)
	vb.add_child(_gap(8))
	vb.add_child(_caption("PISTA"))
	sum_track = _label("", 22, Color.WHITE)
	vb.add_child(sum_track)
	sum_map = TrackMap.new()
	sum_map.custom_minimum_size = Vector2(430, 150)
	sum_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(sum_map)
	return hb


## RF-340: chip da etapa — feita (verde), atual (amarelo) ou por vir (contorno apagado).
func _style_crumb(i: int, current: int) -> void:
	var chip: PanelContainer = crumb_chips[i]
	var lbl: Label = crumbs[i]
	var st := StyleBoxFlat.new()
	st.set_corner_radius_all(14)
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 3
	st.content_margin_bottom = 3
	st.set_border_width_all(2)
	if i == current:
		st.bg_color = Color(1.0, 0.8, 0.18)
		st.border_color = Color(1.0, 0.92, 0.6)
		lbl.add_theme_color_override("font_color", Color(0.2, 0.12, 0.02))
	elif i < current:
		st.bg_color = Color(0.25, 0.6, 0.35, 0.85)
		st.border_color = Color(0.5, 0.9, 0.6, 0.6)
		lbl.add_theme_color_override("font_color", Color.WHITE)
	else:
		st.bg_color = Color(1, 1, 1, 0.04)
		st.border_color = Color(1, 1, 1, 0.22)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	chip.add_theme_stylebox_override("panel", st)


# ---------------------------------------------------------------- etapa PISTA

func _pick_track(i: int) -> void:
	if _is_gp():
		cup_i = mini(i, _cups().size() - 1)
	else:
		track_i = i
	_play(SND_OK)
	_go_step(STEP_SETUP)


func _refresh_track() -> void:
	var gp := _is_gp()
	var cup := _cup()
	for i in track_btns.size():
		var b: Button = track_btns[i]
		b.visible = not gp or i < _cups().size()
		var nm: Label = track_names[i]
		var tid: String = (_cups()[i]["tracks"][0] if gp and i < _cups().size() else TrackScript.TRACKS[i]["id"])
		nm.text = ("%s (%d)" % [_cups()[i]["name"], _cups()[i]["tracks"].size()]) if gp and i < _cups().size() else TrackScript.TRACKS[i]["name"]
		track_minis[i].set_track(tid, false)
		var on := i == (cup_i if gp else track_i)
		if on:
			GameScript.make_primary(b)
		else:
			GameScript.clear_primary(b)
		nm.add_theme_color_override("font_color", Color(0.22, 0.13, 0.03) if on else Color.WHITE)
		nm.add_theme_constant_override("outline_size", 0 if on else 4)
	var td: Dictionary = TrackScript.find(cup[0]) if gp else TrackScript.TRACKS[track_i]
	track_map.set_track(td["id"])
	track_map.line_color = (td["wall"][0] as Color).lightened(0.3)
	if gp:
		var names := []
		for id in cup:
			names.append(TrackScript.find(id)["name"])
		track_title.text = String(_cups()[cup_i]["name"]).to_upper()
		track_desc.text = "Corridas em sequência: " + " → ".join(names) + "."
		track_info.text = "Pontos: 15, 12, 10, 8, 6, 4, 2, 1. O trajeto mostrado é o da 1ª pista."
		return
	track_title.text = td["name"]
	track_desc.text = TRACK_DESC.get(td["id"], "")
	var d: Dictionary = TrackMap.data(td["id"])
	var rec: Dictionary = Records.get_record(td["id"])
	var rec_txt := "sem recorde ainda"
	if rec.has("race_time"):
		var secs: float = rec["race_time"]
		rec_txt = "recorde %d:%05.2f (%s)" % [int(secs / 60.0), fmod(secs, 60.0), Chars.find(String(rec.get("race_char", ""))).get("name", "?")]
	var uniq := []
	for z in d["zones"]:
		var e: String = {"farofa": "farofa", "belt": "esteira", "belt_side": "esteira lateral", "grill": "grelha", "sand": "caixa de areia", "ice": "gelo"}.get(z["kind"], "")
		if e != "" and not uniq.has(e):
			uniq.append(e)
	for h in d["hazards"]:
		var e: String = {"flame": "labaredas", "wheel": "rodas de queijo", "press": "prensas", "seesaw": "gangorras", "roofcat": "gato no telhado", "rover": "robô aspirador"}.get(h["kind"], {"cow": "vacas", "tumbleweed": "bolas de feno", "cat": "gato"}.get(String(h.get("model", "")), "") if h["kind"] == "crosser" else "")
		if e != "" and not uniq.has(e):
			uniq.append(e)
	if not d.get("crossings", []).is_empty():
		uniq.append("cruzamento")
	if not d.get("loops", []).is_empty():
		uniq.append("looping")
	if not d.get("overpasses", []).is_empty():
		uniq.append("viaduto")
	if not d.get("islands", []).is_empty():
		uniq.append("atalho")
	if not d.get("pits", []).is_empty():
		uniq.append("buracos")
	if not d.get("bridges", []).is_empty():
		uniq.append("ponte")
	if not d.get("gaps", []).is_empty():
		uniq.append("%d vãos pra pular" % d["gaps"].size())
	track_info.text = "%.1f km · %s%s" % [float(d["length"]) / 1000.0, rec_txt, (" · " + ", ".join(uniq)) if not uniq.is_empty() else ""]


# ---------------------------------------------------------------- etapa AJUSTES

func _cycle_laps(dv: int) -> void:
	laps_i = (laps_i + dv + LAP_OPTIONS.size()) % LAP_OPTIONS.size()
	_play(SND_MOVE)
	_refresh_setup()


func _cycle_diff(dv: int) -> void:
	if _is_tt():
		return
	diff_i = (diff_i + dv + DIFF_NAMES.size()) % DIFF_NAMES.size()
	_play(SND_MOVE)
	_refresh_setup()


func _refresh_setup() -> void:
	laps_btn.text = "VOLTAS: %d" % LAP_OPTIONS[laps_i]
	diff_btn.text = "IA: --" if _is_tt() else "IA: %s" % DIFF_NAMES[diff_i]
	diff_btn.disabled = _is_tt()
	sum_mode.text = MODE_NAMES[mode_i]
	sum_mode.add_theme_color_override("font_color", (MODE_COLORS[mode_i] as Color).lightened(0.25))
	sum_pilots_cap.text = "PILOTOS" if picks.size() > 1 else "PILOTO"
	for c in sum_pilots.get_children():
		c.queue_free()
	for i in picks.size():
		sum_pilots.add_child(_pilot_badge(picks[i], i))
	var track_name: String = ("%s (%d pistas)" % [_cups()[cup_i]["name"], _cup().size()]) if _is_gp() else TrackScript.TRACKS[track_i]["name"]
	sum_track.text = track_name
	var first: String = _cup()[0] if _is_gp() else TrackScript.TRACKS[track_i]["id"]
	sum_map.set_track(first)
	sum_map.line_color = (TrackScript.find(first)["wall"][0] as Color).lightened(0.3)


func _start_race() -> void:
	if started:
		return
	var game := get_node_or_null("/root/Game")
	if game:
		game.num_players = num_players
		game.selected_chars = picks.map(func(i): return Chars.LIST[i]["id"])
		game.laps = LAP_OPTIONS[laps_i]
		game.track_id = TrackScript.TRACKS[track_i]["id"]
		if _is_gp():
			game.gp_cup = cup_i
			game.start_gp()  # RF-191: começa pela 1ª pista do GP
		else:
			game.mode = MODE_IDS[mode_i]
		game.difficulty = diff_i
	started = true
	_play(SND_OK)
	if start_scene:
		# RF-263: escurece rápido e vai pra corrida
		var tw := create_tween()
		tw.tween_property(fade, "color:a", 1.0, 0.35).set_delay(0.15)
		tw.tween_callback(func():
			if game:
				game.go_race()  # RF-350: "Carregando" com o nome da pista
			else:
				get_tree().change_scene_to_file("res://scenes/race.tscn"))


# ---------------------------------------------------------------- entrada (RF-240/241)

func open_settings() -> void:
	if settings_overlay:
		return
	settings_overlay = SettingsMenu.new()
	add_child(settings_overlay)
	settings_overlay.closed.connect(func():
		settings_overlay = null
		if nav_r == 0:
			gfx_btn.grab_focus())
