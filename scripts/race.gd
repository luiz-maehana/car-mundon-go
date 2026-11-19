extends "res://scripts/race_modes.gd"
## Corrida (RF-453): a classe é dividida em camadas, cada uma com um trabalho só:
##   race_state.gd          todo o estado + consultas (base)
##   race_world.gd          ambiente, câmeras, tela dividida, karts no grid
##   race_track_hazards.gd  perigos da pista (cada tipo em scripts/hazards)
##   race_items.gd          itens, caixas, queijinhos, vácuo, batidas, poderes (scripts/powers)
##   race_modes.gd          contra o relógio, Grand Prix, chegada
##   race.gd                montagem, passo da corrida, pausa e entrada (este arquivo)


func _ready() -> void:
	var game := get_node_or_null("/root/Game")
	if game and game.has_method("hide_loading"):
		get_tree().process_frame.connect(game.hide_loading, CONNECT_ONE_SHOT)  # RF-350: tira o "Carregando"
	if use_game_settings and game:
		player_chars = game.selected_chars.slice(0, game.num_players)
		laps = game.laps
		track_id = game.track_id
		difficulty = game.difficulty
		time_trial = game.is_tt()
	if player_chars.is_empty():
		player_chars = ["fejaum"]
	if time_trial:
		player_chars = player_chars.slice(0, 1)  # RF-230: sempre 1 jogador
	rng.randomize()
	track = TrackScript.new(track_id)
	_build_environment()
	add_child(track)
	_spawn_karts()
	if not time_trial:
		_spawn_boxes()  # RF-231: sem caixas no contra o relógio
	_spawn_cheese()
	_spawn_track_hazards()  # RF-271
	if time_trial:
		_tt_setup()
	_build_views()
	_update_cameras(1.0, true)
	if audio_enabled:
		_build_audio()
	_build_pause()
	var game_m := get_node_or_null("/root/Game")
	if game_m:
		game_m.play_music(track.def.get("music", track.def["id"]))  # RF-221
	apply_settings()
	for p in players:
		human_laps.append(1)


func _exit_tree() -> void:
	for e in engines:
		e["player"].stop()
	for ap in sfx_players:
		ap.stop()


## RF-81: o loop do motor (55 Hz) sobe de tom com a velocidade; volume segue o acelerador.
func _process(delta: float) -> void:
	for e in engines:
		var ap: AudioStreamPlayer = e["player"]
		var k: Node3D = e["kart"]
		# motor gravado (CC0): 0.75 parado → ~1.45 no máximo; turbo +12%
		var pitch := 0.75 + absf(k.speed) * 0.022
		if k.boost_time > 0.0:
			pitch *= 1.12
		ap.pitch_scale = lerpf(ap.pitch_scale, clampf(pitch, 0.6, 2.0), 1.0 - exp(-10.0 * delta))
		var target_db: float = -60.0 if paused else float(e["base_db"]) + 3.0 * clampf(k.in_throttle, 0.0, 1.0)
		ap.volume_db = lerpf(ap.volume_db, target_db, 1.0 - exp(-8.0 * delta))


# ---------------------------------------------------------------- pause (RF-90)

func _build_pause() -> void:
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 20
	pause_layer.visible = false
	add_child(pause_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_layer.add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	center.add_child(vb)
	var title := Label.new()
	title.text = "PAUSADO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 10)
	vb.add_child(title)
	var opts := [["Continuar", toggle_pause], ["Configurações", open_settings], ["Reiniciar (R)", restart], ["Menu", menu_from_pause]]
	for o in opts:
		var b := Button.new()
		b.text = o[0]
		b.custom_minimum_size = Vector2(320, 60)
		b.add_theme_font_size_override("font_size", 28)
		b.pressed.connect(o[1])
		vb.add_child(b)
		if pause_resume_btn == null:
			GameScript.make_primary(b)
			pause_resume_btn = b
	_build_confirm()
	var hint := Label.new()
	hint.text = "M: liga/desliga o som"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.7)
	vb.add_child(hint)
	_theme_pause(pause_layer)


## CanvasLayer não herda o tema da janela: aplica o tema do jogo (Kenney) no pause.
func _theme_pause(n: Node) -> void:
	var game := get_node_or_null("/root/Game")
	if game == null or game.theme == null:
		return
	for c in n.get_children():
		if c is Control:
			c.theme = game.theme


func _build_confirm() -> void:
	confirm_box = ColorRect.new()
	confirm_box.color = Color(0, 0, 0, 0.6)
	confirm_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm_box.visible = false
	pause_layer.add_child(confirm_box)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm_box.add_child(center)
	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.07, 0.08, 0.14)
	st.set_corner_radius_all(14)
	st.set_border_width_all(3)
	st.border_color = Color(1.0, 0.82, 0.2, 0.8)
	st.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", st)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	panel.add_child(vb)
	var q := Label.new()
	q.text = "ABANDONAR O GRAND PRIX?"
	q.add_theme_font_size_override("font_size", 36)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(q)
	var sub := Label.new()
	sub.text = "Os pontos desse GP vão ser perdidos."
	sub.modulate = Color(1, 1, 1, 0.75)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	vb.add_child(row)
	confirm_yes_btn = Button.new()
	confirm_yes_btn.text = "SIM, SAIR"
	confirm_yes_btn.custom_minimum_size = Vector2(220, 56)
	confirm_yes_btn.pressed.connect(to_menu)
	row.add_child(confirm_yes_btn)
	confirm_no_btn = Button.new()
	confirm_no_btn.text = "NÃO"
	confirm_no_btn.custom_minimum_size = Vector2(220, 56)
	GameScript.make_primary(confirm_no_btn)
	confirm_no_btn.pressed.connect(confirm_no)
	row.add_child(confirm_no_btn)


## Botão Menu do pause: no GP pergunta antes.
func menu_from_pause() -> void:
	if not is_gp():
		to_menu()
		return
	confirm_box.visible = true
	confirm_no_btn.grab_focus()


func confirm_no() -> void:
	confirm_box.visible = false
	pause_resume_btn.grab_focus()


func toggle_pause() -> void:
	if results_shown:
		return
	paused = not paused
	pause_layer.visible = paused
	var game := get_node_or_null("/root/Game")
	if game and game.music:
		game.music.stream_paused = paused
	if paused:
		pause_resume_btn.grab_focus()


func _physics_process(delta: float) -> void:
	step(delta)


func open_settings() -> void:
	if settings_overlay:
		return
	settings_overlay = SettingsMenu.new()
	pause_layer.add_child(settings_overlay)
	_theme_pause(pause_layer)
	settings_overlay.closed.connect(func():
		settings_overlay = null
		pause_resume_btn.grab_focus())


func _unhandled_input(event: InputEvent) -> void:
	if settings_overlay:
		return
	if confirm_box and confirm_box.visible:
		if GameScript.is_back(event):
			confirm_no()
			get_viewport().set_input_as_handled()
		return
	var pause_pressed := false
	if (paused or results_shown) and GameScript.is_back(event):  # RF-241: B / Backspace
		pause_pressed = true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			pause_pressed = true
		elif event.physical_keycode == KEY_R and not (results_shown and is_gp()):  # RF-194
			restart()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		pause_pressed = true
	if pause_pressed:
		get_viewport().set_input_as_handled()  # antes: to_menu tira a corrida da árvore
		if results_shown:
			to_menu()
		else:
			toggle_pause()


func restart() -> void:
	_leave()
	var game := get_node_or_null("/root/Game")
	if game:
		game.go_race(true)  # RF-350: "Carregando" enquanto a pista remonta
	else:
		get_tree().reload_current_scene()


func to_menu() -> void:
	_leave()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


# ---------------------------------------------------------------- loop

func step(delta: float) -> void:
	if paused:  # RF-90 / CA-12
		return
	if state == "countdown":
		var c := int(ceil(countdown))
		if c < last_beep and c > 0:
			last_beep = c
			sfx("beep")
		countdown -= delta
		if countdown <= 0.0:
			state = "racing"
			sfx("go")
			sfx("crowd")  # RF-222
			for k in karts:
				k.on_race_start()
				if k.is_player and k.start_result != "":
					sfx("start_turbo" if k.start_result == "turbo" else "stall")
			if time_trial:
				player.give_item("triplo")  # RF-231
				player.item_roll = 0.0
	else:
		race_time += delta
		_human_lap_sounds()
		_final_lap_music()
	var can_drive := state != "countdown"
	_update_rubber()
	for k in karts:
		k.step(delta, can_drive)
	_update_track_hazards(delta, can_drive)
	if can_drive:
		_kart_collisions()
		_update_boxes(delta)
		_update_hazards(delta)
		_update_cheese(delta)
		_update_slipstream(delta)
	_update_ranks()
	if time_trial:
		_tt_step()  # antes do _check_finish: grava o último trecho antes do recorde
	_check_finish(delta)
	_update_cameras(delta, false)
	for h in huds:
		h.update_hud(delta)
	if results_shown and results_hud:
		results_hud.refresh_results()  # RF-360: quem termina depois entra no placar
