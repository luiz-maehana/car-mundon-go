extends "res://scripts/menu_track.gd"
## Menu (RF-453): a classe é dividida em camadas, cada uma com um trabalho só:
##   menu_widgets.gd  estado e peças visuais comuns (base)
##   menu_pilot.gd    etapas MODO e PILOTO
##   menu_track.gd    etapas PISTA e AJUSTES (e a largada)
##   menu.gd          montagem, navegação por etapas e entrada (este arquivo)


func _ready() -> void:
	var game := get_node_or_null("/root/Game")
	if game:
		game.play_music("menu")  # RF-221
		num_players = game.num_players
		selected = Chars.index_of(game.selected_chars[0] if game.selected_chars.size() > 0 else "fejaum")
		laps_i = maxi(0, LAP_OPTIONS.find(game.laps))
		mode_i = maxi(0, MODE_IDS.find(game.mode))
		diff_i = game.difficulty
		cup_i = clampi(game.gp_cup, 0, game.CUPS.size() - 1)
		for ti in TrackScript.TRACKS.size():
			if TrackScript.TRACKS[ti]["id"] == game.track_id:
				track_i = ti
		game.input_device_changed.connect(func(_d): _refresh_help())
	if _is_tt():
		num_players = 1
	_build()
	_go_step(STEP_MODE, false)


# ---------------------------------------------------------------- construção

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.15)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# RF-340: a arte da abertura desfocada e escura atrás de tudo
	if ResourceLoader.exists(BG_ART):
		var art := TextureRect.new()
		art.texture = load(BG_ART)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sm := ShaderMaterial.new()
		sm.shader = load("res://shaders/menu_bg.gdshader")
		art.material = sm
		art.name = "BgArt"
		add_child(art)
	snd = AudioStreamPlayer.new()
	snd.bus = "SFX"
	snd.volume_db = -6.0
	add_child(snd)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24 if side in ["left", "right"] else 14)
	add_child(margin)
	var root_vb := VBoxContainer.new()
	root_vb.add_theme_constant_override("separation", 10)
	margin.add_child(root_vb)

	# topo: VOLTAR · título + etapas · CONFIGURAÇÕES
	var top_panel := PanelContainer.new()
	var tps := StyleBoxFlat.new()
	tps.bg_color = Color(0.04, 0.05, 0.12, 0.72)
	tps.set_corner_radius_all(20)
	tps.border_color = Color(1.0, 0.82, 0.2, 0.45)
	tps.border_width_bottom = 2
	tps.set_content_margin_all(10)
	top_panel.add_theme_stylebox_override("panel", tps)
	root_vb.add_child(top_panel)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	top_panel.add_child(top)
	back_btn = _button("VOLTAR", 18)
	back_btn.custom_minimum_size = Vector2(190, 50)
	back_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back_btn.pressed.connect(_back)
	top.add_child(back_btn)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 2)
	top.add_child(mid)
	var title := _label("Car Mundon'GO", 38, Color(1.0, 0.82, 0.15))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(title)
	var crumb_row := HBoxContainer.new()
	crumb_row.alignment = BoxContainer.ALIGNMENT_CENTER
	crumb_row.add_theme_constant_override("separation", 10)
	mid.add_child(crumb_row)
	for i in STEP_NAMES.size():
		if i > 0:
			var link := ColorRect.new()
			link.custom_minimum_size = Vector2(18, 3)
			link.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			link.color = Color(1, 1, 1, 0.25)
			link.mouse_filter = Control.MOUSE_FILTER_IGNORE
			crumb_row.add_child(link)
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var c := _label("%d  %s" % [i + 1, STEP_NAMES[i]], 15, Color.WHITE)
		c.add_theme_constant_override("outline_size", 0)
		chip.add_child(c)
		crumb_row.add_child(chip)
		crumbs.append(c)
		crumb_chips.append(chip)
	gfx_btn = _button("CONFIGURAÇÕES", 18)  # RF-185
	gfx_btn.custom_minimum_size = Vector2(190, 50)
	gfx_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gfx_btn.pressed.connect(open_settings)
	top.add_child(gfx_btn)

	# etapas (uma visível por vez, mesmo lugar)
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_vb.add_child(stack)
	for builder in [_build_mode, _build_pilot, _build_track, _build_setup]:
		var page := CenterContainer.new()
		page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		page.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.visible = false
		stack.add_child(page)
		page.add_child(builder.call())
		steps_root.append(page)

	help = _label("", 15, Color(1, 1, 1, 0.75))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var help_box := CenterContainer.new()
	help_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.0, 0.0, 0.05, 0.55)
	ps.set_corner_radius_all(18)
	ps.content_margin_left = 20
	ps.content_margin_right = 20
	ps.content_margin_top = 6
	ps.content_margin_bottom = 6
	pill.add_theme_stylebox_override("panel", ps)
	pill.add_child(help)
	help_box.add_child(pill)
	root_vb.add_child(help_box)

	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	for b in [back_btn, gfx_btn]:
		b.focus_mode = Control.FOCUS_ALL


## RF-294: troca de etapa com deslize e põe o foco no item certo.
func _go_step(s: int, animate := true) -> void:
	var dir := 1.0 if s >= step else -1.0
	var old: Control = steps_root[step]
	step = s
	var page: Control = steps_root[s]
	for p in steps_root:
		if p != page and p != old:
			p.visible = false
	page.visible = true
	_shift(page, 0.0)
	page.modulate.a = 1.0
	if animate and is_inside_tree() and old != page:
		old.visible = false
		page.modulate.a = 0.0
		_shift(page, 60.0 * dir)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(page, "modulate:a", 1.0, 0.2)
		tw.tween_method(func(v: float): _shift(page, v), 60.0 * dir, 0.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	elif old != page:
		old.visible = false
	for i in crumbs.size():
		_style_crumb(i, s)
	_build_nav()
	match s:
		STEP_MODE:
			_refresh_mode()
			_focus(1, mode_i)
		STEP_PILOT:
			_release_focus()
			nav_r = 1
			_refresh_pilot()
		STEP_TRACK:
			_refresh_track()
			var sel: int = cup_i if _is_gp() else track_i
			_focus(1 + sel / GRID_COLS, sel % GRID_COLS)
		STEP_SETUP:
			_refresh_setup()
			_focus(nav_rows.size() - 1, 0)
	_refresh_help()


## Desloca a etapa na horizontal sem desfazer a âncora (mexer em position quebraria o layout).
func _shift(page: Control, dx: float) -> void:
	page.offset_left = dx
	page.offset_right = dx


func _build_nav() -> void:
	nav_rows = [[back_btn, gfx_btn]]
	match step:
		STEP_MODE:
			nav_rows.append(mode_cards)
			nav_rows.append(player_btns)
		STEP_PILOT:
			nav_rows.append([])   # cartas: navegação própria (selected)
		STEP_TRACK:
			var shown := []
			for i in track_btns.size():
				if not _is_gp() or i < _cups().size():  # no GP os cartões viram as copas
					shown.append(track_btns[i])
			for r in range(0, shown.size(), GRID_COLS):
				nav_rows.append(shown.slice(r, r + GRID_COLS))
		STEP_SETUP:
			nav_rows.append([laps_btn])
			nav_rows.append([diff_btn])
			nav_rows.append([go_btn])


func _focus(r: int, i: int) -> void:
	nav_r = clampi(r, 0, nav_rows.size() - 1)
	var row: Array = nav_rows[nav_r]
	if row.is_empty():
		_release_focus()
		return
	nav_i = clampi(i, 0, row.size() - 1)
	for k in row.size():
		if not row[nav_i].disabled and row[nav_i].visible:
			break
		nav_i = (nav_i + 1) % row.size()
	if is_inside_tree():
		row[nav_i].grab_focus()


func _release_focus() -> void:
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if f:
		f.release_focus()


func _input(event: InputEvent) -> void:
	if settings_overlay or started:
		return
	var game := get_node_or_null("/root/Game")
	if game:
		game.note_device(event)  # o menu consome o evento antes do Game ver
	var vp := get_viewport()  # trocar de cena tira o menu da árvore no meio do caminho
	if GameScript.is_back(event):
		_back()
	elif event.is_action_pressed("ui_right"):
		_nav(1, 0)
	elif event.is_action_pressed("ui_left"):
		_nav(-1, 0)
	elif event.is_action_pressed("ui_down"):
		_nav(0, 1)
	elif event.is_action_pressed("ui_up"):
		_nav(0, -1)
	elif GameScript.is_accept(event):
		_accept()
	else:
		return
	vp.set_input_as_handled()


func _accept() -> void:
	if step == STEP_PILOT and nav_r == 1:
		_confirm()
		return
	var row: Array = nav_rows[nav_r]
	if row.is_empty():
		return
	var b: Button = row[nav_i]
	if not b.disabled:
		b.pressed.emit()


## RF-295: voltar desfaz o último piloto, sai da barra de cima, volta uma etapa, ou vai pra abertura.
func _back() -> void:
	if step == STEP_PILOT and not picks.is_empty():
		selected = picks.pop_back()
		_focus(1, 0)
		_refresh_pilot()
	elif nav_r == 0:
		_focus(1, 0)
		if step == STEP_PILOT:
			_release_focus()
	elif step > STEP_MODE:
		if step == STEP_TRACK and not picks.is_empty():
			selected = picks.pop_back()  # volta pro piloto com o último escolhido em aberto
		_go_step(step - 1)
	elif start_scene:
		get_tree().change_scene_to_file("res://scenes/intro.tscn")  # RF-103


func _nav(dx: int, dy: int) -> void:
	if step == STEP_PILOT and nav_r == 1:
		if dx != 0:
			_move_selection(dx)
		elif dy < 0 and selected < 4:
			_focus(0, 1)
			return
		elif dy != 0:
			selected = (selected + 4 * dy + 8) % 8
			if picks.has(selected):
				_move_selection_raw(1)
			_play(SND_MOVE)
		_refresh_pilot()
		return
	if dy != 0:
		var r := nav_r + dy
		while r > 0 and r < nav_rows.size() and _row_blocked(nav_rows[r]):
			r += dy
		if r < 0 or r >= nav_rows.size():
			return
		if step == STEP_PILOT and r == 1:
			nav_r = 1
			_release_focus()
			_refresh_pilot()
			return
		_play(SND_MOVE)
		# entra na linha pelo item escolhido (modo atual, nº de jogadores), não pelo índice anterior
		var into := nav_i if nav_rows[r].size() > nav_i else 0
		if r == 0:
			into = 0
		elif step == STEP_MODE:
			into = mode_i if r == 1 else (0 if _is_tt() else num_players - 1)
		_focus(r, into)
		return
	# < > mudam os valores na etapa AJUSTES
	if step == STEP_SETUP and nav_r > 0:
		var b: Button = nav_rows[nav_r][0]
		if b == laps_btn:
			_cycle_laps(dx)
			return
		if b == diff_btn:
			_cycle_diff(dx)
			return
	var row: Array = nav_rows[nav_r]
	if row.size() < 2:
		return
	var i := nav_i
	for k in row.size():
		i = (i + dx + row.size()) % row.size()
		if not row[i].disabled and row[i].visible:
			break
	if i != nav_i:
		_play(SND_MOVE)
	_focus(nav_r, i)


func _row_blocked(row: Array) -> bool:
	if row.is_empty():
		return false
	for b in row:
		if not b.disabled and b.visible:
			return false
	return true


func _refresh_help() -> void:
	if help == null:
		return
	var game := get_node_or_null("/root/Game")
	var kbd := "Setas: navegar · Enter: confirmar · Esc/Backspace: voltar · J1 = %s/controle 1 · J2 = %s/controle 2 · M: som"
	var pad := "Direcional: navegar · A: confirmar · B: voltar · cada jogador usa o seu controle (1 a 4)"
	var touch := "Toque para escolher · VOLTAR volta uma etapa"
	if step == STEP_SETUP:
		kbd = "Setas para os lados: mudar o valor · para cima/baixo: navegar · Enter: confirmar · Esc: voltar"
		pad = "Direcional para os lados: mudar o valor · para cima/baixo: navegar · A: confirmar · B: voltar"
		help.text = game.hint(kbd, pad, "Toque nas opções para mudar · CORRER! para começar") if game else kbd
		return
	if game == null:
		help.text = kbd % ["WASD", "setas"]
		return
	help.text = game.hint(kbd % [game.move_keys(0), game.move_keys(1)], pad, touch)


# ---------------------------------------------------------------- animação contínua

func _process(delta: float) -> void:
	t += delta
	if step == STEP_PILOT and preview_art:
		preview_art.position.y = sin(t * 2.2) * 3.0
		preview_art.scale = Vector2.ONE * (1.0 + 0.012 * sin(t * 2.2))
		if selected < card_styles.size() and not picks.has(selected):
			var st: StyleBoxFlat = card_styles[selected]
			st.border_color.a = 0.65 + 0.35 * sin(t * 6.0)
	if step == STEP_MODE and mode_icons.size() > 2:
		mode_icons[2].queue_redraw()  # ponteiro do cronômetro
