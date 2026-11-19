extends Control
## RF-195: pódio final do Grand Prix (top 3 de corpo inteiro), tabela e confete.

const Chars = preload("res://scripts/characters.gd")
const GameScript = preload("res://scripts/game.gd")
const Sfx = preload("res://scripts/sfx.gd")
const PODIUM := [[1, 300.0, 70.0, Color(0.75, 0.77, 0.8)], [0, 360.0, 110.0, Color(1.0, 0.8, 0.2)], [2, 270.0, 45.0, Color(0.8, 0.5, 0.25)]]

var game: Node
var standings: Array = []
var podium_ids: Array = []


func _ready() -> void:
	game = get_node_or_null("/root/Game")
	standings = game.gp_standings() if game else []
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := TextureRect.new()
	if ResourceLoader.exists("res://assets/ui/intro.jpg"):
		bg.texture = load("res://assets/ui/intro.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate = Color(0.28, 0.28, 0.36)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_top = 20
	vb.offset_bottom = -20
	vb.add_theme_constant_override("separation", 10)
	add_child(vb)
	var title := _label("CAMPEÃO DO GRAND PRIX", 52, Color(1.0, 0.82, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	if standings.size() > 0:
		var champ := _label(Chars.find(standings[0])["name"] + "!", 34, Chars.find(standings[0])["color"].lightened(0.3))
		champ.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(champ)
	var body := HBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 40)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(body)
	body.add_child(_podium())
	body.add_child(_table())
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	vb.add_child(row)
	var again := Button.new()
	again.text = "NOVO GRAND PRIX"
	again.custom_minimum_size = Vector2(300, 60)
	again.add_theme_font_size_override("font_size", 24)
	GameScript.make_primary(again)
	again.pressed.connect(_new_gp)
	row.add_child(again)
	var menu := Button.new()
	menu.text = "MENU"
	menu.custom_minimum_size = Vector2(220, 60)
	menu.add_theme_font_size_override("font_size", 24)
	menu.pressed.connect(_to_menu)
	row.add_child(menu)
	again.grab_focus.call_deferred()
	_confetti()
	var fanfare := AudioStreamPlayer.new()
	fanfare.stream = Sfx.get_sound("finish")
	fanfare.bus = "SFX"
	add_child(fanfare)
	fanfare.play()
	if game:
		game.play_music("victory")  # RF-221


func _unhandled_input(event: InputEvent) -> void:
	if GameScript.is_back(event):  # RF-241
		get_viewport().set_input_as_handled()
		_to_menu()


func _podium() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	for s in PODIUM:
		var i: int = s[0]
		if i >= standings.size():
			continue
		var id: String = standings[i]
		podium_ids.append(id)
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_END
		col.add_theme_constant_override("separation", 0)
		row.add_child(col)
		var art := Chars.art_rect(id, s[1], "full")
		if art:
			art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			col.add_child(art)
		var block := PanelContainer.new()
		var st := StyleBoxFlat.new()
		st.bg_color = s[3]
		st.set_corner_radius_all(8)
		block.add_theme_stylebox_override("panel", st)
		block.custom_minimum_size = Vector2(190, s[2])
		col.add_child(block)
		var lbl := _label("%dº %s\n%d pts" % [i + 1, Chars.find(id)["name"], int(game.gp_points.get(id, 0))], 22, Color.WHITE)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		block.add_child(lbl)
	return row


func _table() -> Control:
	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.06, 0.12, 0.9)
	st.set_corner_radius_all(14)
	st.content_margin_left = 20
	st.content_margin_right = 20
	st.content_margin_top = 14
	st.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", st)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	vb.add_child(_label("CLASSIFICAÇÃO FINAL", 24, Color(1.0, 0.82, 0.2)))
	for i in standings.size():
		var id: String = standings[i]
		var c: Dictionary = Chars.find(id)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		vb.add_child(hb)
		var pos := _label("%dº" % (i + 1), 24, Color.WHITE)
		pos.custom_minimum_size.x = 48
		hb.add_child(pos)
		var face := Chars.art_rect(id, 34)
		if face:
			hb.add_child(face)
		var nm := _label(c["name"], 24, c["color"].lightened(0.25))
		nm.custom_minimum_size.x = 170
		hb.add_child(nm)
		var wins: int = int(game.gp_wins.get(id, 0))
		var w := _label("%d vit." % wins if wins > 0 else "", 18, Color(1, 1, 1, 0.6))
		w.custom_minimum_size.x = 70
		hb.add_child(w)
		var pts := _label("%d pts" % int(game.gp_points.get(id, 0)), 24, Color.WHITE)
		pts.custom_minimum_size.x = 90
		pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hb.add_child(pts)
	return panel


func _confetti() -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(get_viewport_rect().size.x * 0.5, -20)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(get_viewport_rect().size.x * 0.55, 10)
	p.amount = 160
	p.lifetime = 4.0
	p.direction = Vector2(0, 1)
	p.spread = 25.0
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 220.0
	p.gravity = Vector2(0, 120)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 8.0
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.3, 0.3))
	g.add_point(0.25, Color(1, 0.85, 0.2))
	g.add_point(0.5, Color(0.3, 0.9, 0.4))
	g.add_point(0.75, Color(0.3, 0.6, 1.0))
	g.set_color(g.get_point_count() - 1, Color(0.9, 0.4, 1.0))
	p.color_initial_ramp = g
	add_child(p)
	p.emitting = true


func _new_gp() -> void:
	if game:
		game.start_gp()
	get_tree().change_scene_to_file("res://scenes/race.tscn")


func _to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _label(text: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", maxi(4, size / 6))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
