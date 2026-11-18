extends Control
## Menu: jogadores, seleção de piloto e voltas (RF-01..03, RF-60).
## Com 2+ jogadores cada um confirma o seu piloto em sequência; Backspace desfaz.

const Chars = preload("res://scripts/characters.gd")
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
const DIFF_NAMES := ["FÁCIL", "NORMAL", "DIFÍCIL"]
var track_i := 0
var players_btn: Button
var go_btn: Button
var sub: Label


func _ready() -> void:
	var game := get_node_or_null("/root/Game")
	if game:
		num_players = game.num_players
		selected = Chars.index_of(game.selected_chars[0] if game.selected_chars.size() > 0 else "fejaum")
		laps_i = maxi(0, LAP_OPTIONS.find(game.laps))
		diff_i = game.difficulty
		for ti in TrackScript.TRACKS.size():
			if TrackScript.TRACKS[ti]["id"] == game.track_id:
				track_i = ti
	_build()
	_refresh()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.15)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	row.add_child(go_btn)

	var help := _label("Setas: escolher · Enter: confirmar · Backspace: desfazer · J1 = WASD/controle 1 · J2 = setas/controle 2 · J3/J4 = controles 3/4 · M: som", 15, Color(1, 1, 1, 0.6))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(help)


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
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	track_btn.text = "PISTA: %s" % TrackScript.TRACKS[track_i]["name"]
	diff_btn.text = "IA: %s" % DIFF_NAMES[diff_i]
	go_btn.text = "CORRER!" if cur == num_players - 1 else "CONFIRMAR J%d" % (cur + 1)


func _move_selection(step: int) -> void:
	var n := Chars.LIST.size()
	for t in n:
		selected = (selected + step + n) % n
		if not picks.has(selected):
			return


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/intro.tscn")  # RF-103
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_BACKSPACE:
		if not picks.is_empty():
			selected = picks.pop_back()
			_refresh()
		return
	if event.is_action_pressed("ui_right"):
		_move_selection(1)
	elif event.is_action_pressed("ui_left"):
		_move_selection(-1)
	elif event.is_action_pressed("ui_down"):
		_move_selection(4)
	elif event.is_action_pressed("ui_up"):
		_move_selection(-4)
	elif event.is_action_pressed("ui_accept"):
		_confirm()
		return
	else:
		return
	_refresh()


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
		game.difficulty = diff_i
	get_tree().change_scene_to_file("res://scenes/race.tscn")
