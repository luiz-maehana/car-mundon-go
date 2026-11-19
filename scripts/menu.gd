extends Control
## Menu: jogadores, seleção de piloto e voltas (RF-01..03, RF-60).
## Com 2+ jogadores cada um confirma o seu piloto em sequência; Backspace desfaz.

const Chars = preload("res://scripts/characters.gd")
const GameScript = preload("res://scripts/game.gd")
const STATS := [["speed", "VEL"], ["accel", "ACE"], ["handling", "CTR"], ["weight", "PES"]]
const LAP_OPTIONS := [1, 2, 3, 5]
const TrackScript = preload("res://scripts/track.gd")
const PLAYER_COLORS := [Color(1.0, 0.85, 0.2), Color(0.3, 0.8, 1.0), Color(0.4, 1.0, 0.4), Color(1.0, 0.45, 0.8)]

var selected := 0
var laps_i := 2
var num_players := 1
var picks: Array = []  # índices de Chars.LIST já confirmados (J1, J2, ...)
var card_styles: Array = []
var card_tags: Array = []
var laps_btn: Button
var track_btn: Button
var diff_btn: Button
var diff_i := 1
var gfx_btn: Button
var mode_btn: Button
var mode_i := 0  # RF-230: 0 = CORRIDA, 1 = GRAND PRIX, 2 = CONTRA O RELÓGIO
const MODE_NAMES := ["CORRIDA", "GRAND PRIX", "CONTRA O RELÓGIO"]
const MODE_IDS := ["race", "gp", "tt"]
var settings_overlay: Control
const SettingsMenu = preload("res://scripts/settings_menu.gd")
const DIFF_NAMES := ["FÁCIL", "NORMAL", "DIFÍCIL"]
var track_i := 0
var players_btn: Button
var go_btn: Button
var sub: Label
var help: Label
var nav_rows: Array = []
var nav_zone := 1   # 0 = linha de cima, 1 = cartas, 2 = opções (RF-240)
var nav_i := 0
var start_scene := true  # os testes desligam pra não trocar de cena
var started := false


func _ready() -> void:
	var gm := get_node_or_null("/root/Game")
	if gm:
		gm.play_music("menu")  # RF-221
	var game := get_node_or_null("/root/Game")
	if game:
		num_players = game.num_players
		selected = Chars.index_of(game.selected_chars[0] if game.selected_chars.size() > 0 else "fejaum")
		laps_i = maxi(0, LAP_OPTIONS.find(game.laps))
		mode_i = maxi(0, MODE_IDS.find(game.mode))
		diff_i = game.difficulty
		for ti in TrackScript.TRACKS.size():
			if TrackScript.TRACKS[ti]["id"] == game.track_id:
				track_i = ti
	_build()
	_refresh()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.15)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# RF-185: botão de configurações (canto superior direito)
	gfx_btn = _button("CONFIGURAÇÕES", 18)
	gfx_btn.custom_minimum_size = Vector2(230, 44)
	gfx_btn.anchor_left = 1.0
	gfx_btn.anchor_right = 1.0
	gfx_btn.offset_left = -246
	gfx_btn.offset_right = -16
	gfx_btn.offset_top = 12
	gfx_btn.offset_bottom = 56
	gfx_btn.pressed.connect(open_settings)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	center.add_child(vb)

	var title := _label("CAR'MUNDON'GO!", 76, Color(1.0, 0.82, 0.15))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	sub = _label("", 28, Color(0.85, 0.85, 0.95))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	vb.add_child(grid)
	for i in Chars.LIST.size():
		grid.add_child(_make_card(i))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	vb.add_child(row)
	players_btn = _button("", 22)
	players_btn.pressed.connect(func():
		if _is_tt():
			return
		num_players = num_players % 4 + 1
		picks.clear()
		_refresh())
	row.add_child(players_btn)
	laps_btn = _button("", 22)
	laps_btn.pressed.connect(func():
		laps_i = (laps_i + 1) % LAP_OPTIONS.size()
		_refresh())
	row.add_child(laps_btn)
	diff_btn = _button("", 22)  # RF-151
	diff_btn.pressed.connect(func():
		diff_i = (diff_i + 1) % DIFF_NAMES.size()
		_refresh())
	row.add_child(diff_btn)
	track_btn = _button("", 22)  # RF-122
	track_btn.custom_minimum_size = Vector2(340, 64)
	track_btn.pressed.connect(func():
		track_i = (track_i + 1) % TrackScript.TRACKS.size()
		_refresh())
	row.add_child(track_btn)
	go_btn = _button("", 30)
	go_btn.custom_minimum_size = Vector2(220, 64)
	go_btn.pressed.connect(_confirm)
	GameScript.make_primary(go_btn)  # RF-174
	row.add_child(go_btn)

	help = _label("", 15, Color(1, 1, 1, 0.6))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(help)
	add_child(gfx_btn)  # por cima do resto
	# RF-190: modo de jogo (canto superior esquerdo)
	mode_btn = _button("", 18)
	mode_btn.custom_minimum_size = Vector2(380, 44)
	mode_btn.position = Vector2(16, 12)
	mode_btn.size = Vector2(380, 44)
	mode_btn.pressed.connect(func():
		mode_i = (mode_i + 1) % MODE_IDS.size()
		if _is_tt():
			num_players = 1
			picks.clear()
		_refresh())
	add_child(mode_btn)
	# RF-240: linhas de navegação (cima = 0, cartas = 1, opções = 2)
	nav_rows = [[mode_btn, gfx_btn], [], [players_btn, laps_btn, diff_btn, track_btn, go_btn]]
	for r in [0, 2]:
		for i in nav_rows[r].size():
			var b: Button = nav_rows[r][i]
			b.focus_mode = Control.FOCUS_ALL
			b.focus_entered.connect(func():
				nav_zone = r
				nav_i = i)
	var gm := get_node_or_null("/root/Game")
	if gm:
		gm.input_device_changed.connect(func(_d): _refresh_help())


func _label(text: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", maxi(4, size / 7))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(180, 64)
	return b


func _make_card(i: int) -> Button:
	var c: Dictionary = Chars.LIST[i]
	var col: Color = c["color"]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(300, 160)
	var st := StyleBoxFlat.new()
	st.set_corner_radius_all(12)
	for s in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(s, st)
	card_styles.append(st)
	b.pressed.connect(func():
		if picks.has(i):
			return
		if selected == i:
			_confirm()
		else:
			selected = i
			_refresh())

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 12
	hbox.offset_top = 8
	hbox.offset_right = -10
	hbox.offset_bottom = -8
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 8)
	b.add_child(hbox)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 4)
	hbox.add_child(vb)
	vb.add_child(_label(c["name"], 26, col.lightened(0.3)))
	for s in STATS:
		var hb := HBoxContainer.new()
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_theme_constant_override("separation", 4)
		vb.add_child(hb)
		var l := _label(s[1], 14, Color(0.9, 0.9, 0.9))
		l.custom_minimum_size.x = 36
		hb.add_child(l)
		for k in 5:
			var r := ColorRect.new()
			r.custom_minimum_size = Vector2(12, 11)
			r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			r.color = col if k < int(c[s[0]]) else Color(1, 1, 1, 0.12)
			hb.add_child(r)
	var face := Chars.art_rect(c["id"], 112)  # RF-72
	if face:
		face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(face)
	var tag := _label("", 30, Color.WHITE)
	tag.anchor_left = 1.0
	tag.anchor_right = 1.0
	tag.offset_left = -70
	tag.offset_right = -12
	tag.offset_top = 6
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.add_child(tag)
	card_tags.append(tag)
	return b


func _is_gp() -> bool:
	return MODE_IDS[mode_i] == "gp"


func _is_tt() -> bool:
	return MODE_IDS[mode_i] == "tt"


func _current_player() -> int:
	return picks.size()


func _refresh() -> void:
	var cur := _current_player()
	for i in card_styles.size():
		var st: StyleBoxFlat = card_styles[i]
		var col: Color = Chars.LIST[i]["color"]
		var taken: int = picks.find(i)
		var tag: Label = card_tags[i]
		if taken >= 0:
			st.set_border_width_all(6)
			st.border_color = PLAYER_COLORS[taken]
			st.bg_color = col.darkened(0.75)
			tag.text = "J%d" % (taken + 1)
			tag.add_theme_color_override("font_color", PLAYER_COLORS[taken])
		else:
			var sel := i == selected
			st.set_border_width_all(6 if sel else 3)
			st.border_color = (PLAYER_COLORS[cur] if num_players > 1 else Color.WHITE) if sel else col.darkened(0.2)
			st.bg_color = col.darkened(0.35 if sel else 0.65)
			tag.text = ""
	if num_players == 1:
		sub.text = "Escolha seu piloto"
		sub.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
	else:
		sub.text = "JOGADOR %d, escolha seu piloto" % (cur + 1)
		sub.add_theme_color_override("font_color", PLAYER_COLORS[cur])
	players_btn.text = "JOGADORES: %d" % num_players
	laps_btn.text = "VOLTAS: %d" % LAP_OPTIONS[laps_i]
	var gp_mode := _is_gp()
	track_btn.text = "PISTAS: AS 3" if gp_mode else "PISTA: %s" % TrackScript.TRACKS[track_i]["name"]
	track_btn.disabled = gp_mode
	mode_btn.text = "MODO: %s" % MODE_NAMES[mode_i]
	players_btn.disabled = _is_tt()
	diff_btn.disabled = _is_tt()
	diff_btn.text = "IA: --" if _is_tt() else "IA: %s" % DIFF_NAMES[diff_i]
	go_btn.text = "CORRER!" if cur == num_players - 1 else "CONFIRMAR J%d" % (cur + 1)
	_refresh_help()
	if nav_zone != 1 and nav_rows[nav_zone][nav_i].disabled:
		_focus_zone(nav_zone, nav_i)


func _move_selection(step: int) -> void:
	var n := Chars.LIST.size()
	for t in n:
		selected = (selected + step + n) % n
		if not picks.has(selected):
			return


func open_settings() -> void:
	if settings_overlay:
		return
	settings_overlay = SettingsMenu.new()
	add_child(settings_overlay)
	settings_overlay.closed.connect(func():
		settings_overlay = null
		if nav_zone == 0:
			gfx_btn.grab_focus())


## RF-240/241: toda a navegação do menu passa por aqui (antes da GUI), então funciona igual
## no teclado e no controle e não depende de foco de mouse.
func _input(event: InputEvent) -> void:
	if settings_overlay or started:
		return
	var game := get_node_or_null("/root/Game")
	if game:
		game.note_device(event)  # o menu consome o evento antes do Game ver
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
		if nav_zone == 1:
			_confirm()
		else:
			var b: Button = nav_rows[nav_zone][nav_i]
			if not b.disabled:
				b.pressed.emit()
	else:
		return
	get_viewport().set_input_as_handled()


func _back() -> void:
	if not picks.is_empty():
		selected = picks.pop_back()
		_focus_zone(1)
		_refresh()
	elif nav_zone != 1:
		_focus_zone(1)
	elif start_scene:
		get_tree().change_scene_to_file("res://scenes/intro.tscn")  # RF-103


func _nav(dx: int, dy: int) -> void:
	if nav_zone == 1:
		if dx != 0:
			_move_selection(dx)
		elif dy < 0 and selected < 4:
			_focus_zone(0, 0 if selected % 4 < 2 else 1)
		elif dy > 0 and selected >= 4:
			_focus_zone(2, [0, 1, 3, 4][selected % 4])
		else:
			selected = (selected + 4 * dy + 8) % 8
			if picks.has(selected):
				_move_selection(1)
		_refresh()
		return
	if dy != 0:
		if (nav_zone == 0 and dy > 0) or (nav_zone == 2 and dy < 0):
			_focus_zone(1)
		return
	var row: Array = nav_rows[nav_zone]
	for t in row.size():
		nav_i = (nav_i + dx + row.size()) % row.size()
		if not row[nav_i].disabled:
			break
	row[nav_i].grab_focus()


## Põe o foco numa linha (pulando botão desativado) ou volta pras cartas.
func _focus_zone(zone: int, i := 0) -> void:
	nav_zone = zone
	if zone == 1:
		var f := get_viewport().gui_get_focus_owner()
		if f:
			f.release_focus()
		return
	var row: Array = nav_rows[zone]
	nav_i = clampi(i, 0, row.size() - 1)
	for t in row.size():
		if not row[nav_i].disabled:
			break
		nav_i = (nav_i + 1) % row.size()
	row[nav_i].grab_focus()
	nav_zone = zone


func _refresh_help() -> void:
	var game := get_node_or_null("/root/Game")
	var kbd := "Setas: navegar · Enter: confirmar · Esc/Backspace: voltar · J1 = WASD/controle 1 · J2 = setas/controle 2 · J3/J4 = controles 3/4 · M: som"
	var pad := "Direcional: navegar · A: confirmar · B: voltar · cada jogador usa o seu controle (1 a 4)"
	help.text = game.hint(kbd, pad) if game else kbd


func _confirm() -> void:
	if picks.has(selected):
		return
	picks.append(selected)
	if picks.size() < num_players:
		_move_selection(1)
		_refresh()
		return
	var game := get_node_or_null("/root/Game")
	if game:
		game.num_players = num_players
		game.selected_chars = picks.map(func(i): return Chars.LIST[i]["id"])
		game.laps = LAP_OPTIONS[laps_i]
		game.track_id = TrackScript.TRACKS[track_i]["id"]
		if _is_gp():
			game.start_gp()  # RF-191: começa pela 1ª pista do GP
		else:
			game.mode = MODE_IDS[mode_i]
		game.difficulty = diff_i
	started = true
	if start_scene:
		get_tree().change_scene_to_file("res://scenes/race.tscn")
