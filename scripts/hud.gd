extends CanvasLayer
## HUD de um jogador (RF-50/51/62) e tela de resultado (RF-34/65).
## Em tela dividida cada SubViewport tem o seu HUD; ui_scale encolhe tudo junto.
## Com kart == null vira só a camada do resultado.

const MinimapScript = preload("res://scripts/minimap.gd")
const Chars = preload("res://scripts/characters.gd")
const ITEM_NAMES := {"turbo": "TURBO", "casca": "CASCA", "bomba": "BOMBA"}
const ITEM_COLORS := {"turbo": Color(1.0, 0.55, 0.1), "casca": Color(1.0, 0.88, 0.15), "bomba": Color(0.9, 0.2, 0.15)}
const FINISH_TEXT_TIME := 2.5

var race: Node
var kart: Node3D
var ui_scale := 1.0
var root: Control
var lbl_lap: Label
var lbl_time: Label
var lbl_pos: Label
var lbl_center: Label
var lbl_msg: Label
var lbl_item: Label
var item_style: StyleBoxFlat
var results: PanelContainer
var last_lap := 1
var msg_time := 0.0
var start_shown := false
var lbl_mute: Label


func setup(r: Node, k: Node3D, s: float, show_hint: bool) -> void:
	race = r
	kart = k
	ui_scale = s
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.scale = Vector2(s, s)
	add_child(root)
	_fit()
	if kart == null:
		return

	lbl_lap = _label(40)
	lbl_lap.position = Vector2(24, 12)
	lbl_time = _label(28)
	lbl_time.position = Vector2(26, 62)
	if race.players.size() > 1:
		var tag := _label(30)
		tag.text = "J%d · %s" % [kart.player_index + 1, kart.display_name]
		tag.position = Vector2(26, 100)
		tag.add_theme_color_override("font_color", kart.color.lightened(0.25))

	lbl_pos = _label(84)
	lbl_pos.anchor_left = 1.0
	lbl_pos.anchor_right = 1.0
	lbl_pos.offset_left = -300
	lbl_pos.offset_right = -24
	lbl_pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var face := Chars.art_rect(kart.char_id, 104)  # RF-73
	if face:
		face.anchor_left = 1.0
		face.anchor_right = 1.0
		face.offset_left = -236 - face.custom_minimum_size.x
		face.offset_right = -236
		face.offset_top = 8
		face.offset_bottom = 112
		root.add_child(face)

	var item_panel := PanelContainer.new()
	item_style = _panel_style(Color(0, 0, 0, 0.55))
	item_panel.add_theme_stylebox_override("panel", item_style)
	item_panel.anchor_left = 0.5
	item_panel.anchor_right = 0.5
	item_panel.offset_left = -80
	item_panel.offset_right = 80
	item_panel.offset_top = 12
	item_panel.offset_bottom = 92
	item_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(item_panel)
	lbl_item = _label(30, item_panel)
	lbl_item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_item.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	lbl_center = _label(140)
	lbl_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_center.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))

	lbl_msg = _label(48)
	lbl_msg.anchor_right = 1.0
	lbl_msg.offset_top = 130
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	lbl_mute = _label(20)
	lbl_mute.text = "SEM SOM (M)"
	lbl_mute.anchor_left = 0.5
	lbl_mute.anchor_right = 0.5
	lbl_mute.offset_left = -100
	lbl_mute.offset_right = 100
	lbl_mute.offset_top = 96
	lbl_mute.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_mute.visible = false

	if show_hint:
		var hint := _label(16)
		hint.text = "WASD/Setas: pilotar · Espaço: drift · E: item · Esc: pausar · M: som"
		hint.anchor_left = 1.0
		hint.anchor_right = 1.0
		hint.anchor_top = 1.0
		hint.anchor_bottom = 1.0
		hint.offset_left = -700
		hint.offset_right = -20
		hint.offset_top = -36
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hint.modulate = Color(1, 1, 1, 0.7)

	var mm: Control = MinimapScript.new()
	mm.anchor_top = 1.0
	mm.anchor_bottom = 1.0
	mm.offset_left = 20
	mm.offset_right = 250
	mm.offset_top = -250
	mm.offset_bottom = -20
	mm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(mm)
	mm.setup(race.track, race.karts, kart)


## O root tem o tamanho do quadro dividido pela escala, então as âncoras continuam valendo.
func _fit() -> void:
	var vp := get_viewport()
	if vp:
		root.size = vp.get_visible_rect().size / ui_scale


func _label(size: int, parent: Control = null) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", maxi(4, size / 6))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else root).add_child(l)
	return l


func _panel_style(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(14)
	s.set_border_width_all(3)
	s.border_color = Color(1, 1, 1, 0.6)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


static func fmt_time(t: float) -> String:
	var m := int(t / 60.0)
	var s := fmod(t, 60.0)
	return "%d:%05.2f" % [m, s]


func _flash(text: String, secs := 1.6) -> void:
	lbl_msg.text = text
	msg_time = secs


func update_hud(delta: float) -> void:
	_fit()
	if kart == null:
		return
	var p := kart
	var lap: int = race.lap_of(p)
	lbl_lap.text = "VOLTA %d/%d" % [lap, race.laps]
	lbl_time.text = fmt_time(race.race_time)
	lbl_pos.text = "%dº/%d" % [p.rank, race.karts.size()]
	lbl_pos.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if p.rank == 1 else Color.WHITE)

	if p.item == "":
		lbl_item.text = "—"
		item_style.border_color = Color(1, 1, 1, 0.4)
	else:
		lbl_item.text = ITEM_NAMES[p.item]
		item_style.border_color = ITEM_COLORS[p.item]
	lbl_item.add_theme_color_override("font_color", ITEM_COLORS.get(p.item, Color(1, 1, 1, 0.5)))

	if race.state == "countdown":
		lbl_center.text = str(int(ceil(race.countdown)))
	elif race.race_time < 0.8:
		lbl_center.text = "VAI!"
	elif p.finished and race.race_time - p.finish_time < FINISH_TEXT_TIME:
		lbl_center.text = "CHEGOU! %dº" % p.rank
	else:
		lbl_center.text = ""

	if p.start_result != "" and not start_shown:
		start_shown = true
		_flash("LARGADA TURBO!" if p.start_result == "turbo" else "QUEIMOU!", 1.5)
		lbl_msg.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0) if p.start_result == "turbo" else Color(1.0, 0.4, 0.3))
	elif msg_time <= 0.0:
		lbl_msg.remove_theme_color_override("font_color")
	var game := get_node_or_null("/root/Game")
	lbl_mute.visible = game != null and game.muted
	if not p.finished:
		if lap > last_lap:
			_flash("VOLTA FINAL!" if lap == race.laps else "VOLTA %d" % lap)
		last_lap = lap
		if p.vel.dot(race.track.tangents[p.track_idx]) < -4.0:
			_flash("CONTRAMÃO!", 0.2)
	if msg_time > 0.0:
		msg_time -= delta
		if msg_time <= 0.0:
			lbl_msg.text = ""


func show_results() -> void:
	if results:
		return
	_fit()
	results = PanelContainer.new()
	results.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.06, 0.12, 0.94)))
	results.anchor_left = 0.5
	results.anchor_right = 0.5
	results.anchor_top = 0.5
	results.anchor_bottom = 0.5
	results.offset_left = -580
	results.offset_right = 580
	results.offset_top = -320
	results.offset_bottom = 320
	root.add_child(results)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	results.add_child(outer)
	var title := _label(44, outer)
	title.text = "RESULTADO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)
	var ranking: Array = race.ranking()
	body.add_child(_podium(ranking))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(vb)
	var multi: bool = race.players.size() > 1
	for k in ranking:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		vb.add_child(hb)
		var pos := _label(26, hb)
		pos.text = "%dº" % k.rank
		pos.custom_minimum_size.x = 60
		var face := Chars.art_rect(k.char_id, 34)
		if face:
			hb.add_child(face)
		var nm := _label(26, hb)
		var tag := ""
		if k.is_player:
			tag = "  (J%d)" % (k.player_index + 1) if multi else "  (você)"
		nm.text = k.display_name + tag
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.add_theme_color_override("font_color", k.color.lightened(0.2))
		var tm := _label(26, hb)
		tm.text = fmt_time(k.finish_time) if k.finished else "--:--"
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	outer.add_child(buttons)
	var again := Button.new()
	again.text = "Correr de novo (R)"
	again.add_theme_font_size_override("font_size", 22)
	again.pressed.connect(race.restart)
	buttons.add_child(again)
	var menu := Button.new()
	menu.text = "Menu (Esc)"
	menu.add_theme_font_size_override("font_size", 22)
	menu.pressed.connect(race.to_menu)
	buttons.add_child(menu)
	again.grab_focus()


## RF-73: pódio com o top 3 de corpo inteiro (2º, 1º, 3º).
func _podium(ranking: Array) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size = Vector2(500, 0)
	var spec := [[1, 250.0, 60.0, Color(0.75, 0.77, 0.8)], [0, 300.0, 95.0, Color(1.0, 0.8, 0.2)], [2, 230.0, 40.0, Color(0.8, 0.5, 0.25)]]
	for s in spec:
		var i: int = s[0]
		if i >= ranking.size():
			continue
		var k: Node3D = ranking[i]
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_END
		col.size_flags_vertical = Control.SIZE_FILL
		col.add_theme_constant_override("separation", 0)
		row.add_child(col)
		var art := Chars.art_rect(k.char_id, s[1], "full")
		if art:
			art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			col.add_child(art)
		var block := PanelContainer.new()
		var st := StyleBoxFlat.new()
		st.bg_color = s[3]
		st.set_corner_radius_all(6)
		block.add_theme_stylebox_override("panel", st)
		block.custom_minimum_size = Vector2(155, s[2])
		col.add_child(block)
		var lbl := _label(34, block)
		lbl.text = "%dº %s" % [i + 1, k.display_name]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 22)
	return row
