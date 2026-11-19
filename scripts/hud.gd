extends CanvasLayer
## HUD de um jogador (RF-50/51/62) e tela de resultado (RF-34/65).
## Em tela dividida cada SubViewport tem o seu HUD; ui_scale encolhe tudo junto.
## Com kart == null vira só a camada do resultado.

const MinimapScript = preload("res://scripts/minimap.gd")
const IconScript = preload("res://scripts/icons.gd")
const KartScript = preload("res://scripts/kart.gd")
const ROLL_ORDER := ["turbo", "casca", "gato", "bomba", "escudo", "ratoeira", "triplo"]
const SpeedLinesShader = preload("res://shaders/speed_lines.gdshader")
const Chars = preload("res://scripts/characters.gd")
const GameScript = preload("res://scripts/game.gd")
const Gfx = preload("res://scripts/gfx.gd")
const ITEM_NAMES := {"turbo": "TURBO", "casca": "CASCA", "bomba": "BOMBA", "triplo": "QUEIJO TRIPLO", "ratoeira": "RATOEIRA", "escudo": "ESCUDO", "gato": "GATO!"}
const ITEM_COLORS := {"turbo": Color(1.0, 0.55, 0.1), "casca": Color(1.0, 0.88, 0.15), "bomba": Color(0.9, 0.2, 0.15), "triplo": Color(1.0, 0.82, 0.25), "ratoeira": Color(0.75, 0.5, 0.28), "escudo": Color(0.5, 0.85, 1.0), "gato": Color(1.0, 0.55, 0.15)}
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
var item_icon: Control
var lbl_cheese: Label
var lbl_laptime: Label
var lbl_speed: Label
var drift_bar_bg: ColorRect
var drift_bar: ColorRect
var roll_t := 0.0
var last_rank := 0
var pos_pop := 0.0
var lap_start := 0.0
var best_lap := INF
var final_lap_counted := false
var item_style: StyleBoxFlat
var results: PanelContainer
var last_lap := 1
var msg_time := 0.0
var start_shown := false
var lbl_mute: Label
var rank_rows: Array = []
var minimap: Control
var speed_lines: ColorRect
var ranking_box: Control
var lbl_unit: Label
var boost_fx := 0.0
var lbl_record: Label
var lbl_hint: Label
const HINT_KBD := "WASD/Setas: pilotar · Espaço: drift · E: item · Esc: pausar · M: som"
const HINT_PAD := "Analógico: pilotar · A: acelerar · B: frear · RB: drift · LB: item · Start: pausar"


func setup(r: Node, k: Node3D, s: float, show_hint: bool) -> void:
	race = r
	kart = k
	ui_scale = s
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.scale = Vector2(s, s)
	var game := get_node_or_null("/root/Game")
	if game and game.theme:
		root.theme = game.theme  # SubViewport não herda o tema da janela
	add_child(root)
	_fit()
	if kart == null:
		return
	# RF-166: linhas de velocidade (atrás do resto do HUD)
	speed_lines = ColorRect.new()
	speed_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	speed_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slm := ShaderMaterial.new()
	slm.shader = SpeedLinesShader
	speed_lines.material = slm
	root.add_child(speed_lines)

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
	item_icon = IconScript.new()
	item_icon.custom_minimum_size = Vector2(60, 60)
	item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_panel.add_child(item_icon)
	lbl_item = _label(14)
	lbl_item.anchor_left = 0.5
	lbl_item.anchor_right = 0.5
	lbl_item.offset_left = -80
	lbl_item.offset_right = 80
	lbl_item.offset_top = 94
	lbl_item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# RF-135: queijinhos ao lado do item
	var cheese_icon: Control = IconScript.new()
	cheese_icon.kind = "cheese"
	cheese_icon.anchor_left = 0.5
	cheese_icon.anchor_right = 0.5
	cheese_icon.offset_left = 90
	cheese_icon.offset_right = 136
	cheese_icon.offset_top = 22
	cheese_icon.offset_bottom = 68
	cheese_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cheese_icon)
	lbl_cheese = _label(30)
	lbl_cheese.anchor_left = 0.5
	lbl_cheese.anchor_right = 0.5
	lbl_cheese.offset_left = 138
	lbl_cheese.offset_top = 24
	# RF-133: tempo da volta
	lbl_laptime = _label(20)
	lbl_laptime.position = Vector2(26, 98 if race.players.size() == 1 else 138)
	lbl_laptime.modulate = Color(1, 1, 1, 0.85)
	# RF-193: indicador do Grand Prix
	var g := get_node_or_null("/root/Game")
	if g and g.is_gp():
		var gpl := _label(20)
		gpl.text = "GRAND PRIX · CORRIDA %d/%d" % [g.gp_index + 1, g.GP_TRACKS.size()]
		gpl.position = lbl_laptime.position + Vector2(0, 26)
		gpl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.2))
	# RF-232: recorde da pista no contra o relógio
	if race.time_trial:
		lbl_record = _label(20)
		lbl_record.position = lbl_laptime.position + Vector2(0, 26)
		lbl_record.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
		lbl_record.text = record_text(race.tt_record)
	# RF-131: velocímetro + barra de drift (canto inferior direito)
	lbl_speed = _label(64)
	lbl_speed.anchor_left = 1.0
	lbl_speed.anchor_right = 1.0
	lbl_speed.anchor_top = 1.0
	lbl_speed.anchor_bottom = 1.0
	lbl_speed.offset_left = -260
	lbl_speed.offset_right = -96
	lbl_speed.offset_top = -150
	lbl_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var kmh := _label(22)
	kmh.text = "km/h"
	lbl_unit = kmh
	kmh.anchor_left = 1.0
	kmh.anchor_right = 1.0
	kmh.anchor_top = 1.0
	kmh.anchor_bottom = 1.0
	kmh.offset_left = -90
	kmh.offset_top = -112
	drift_bar_bg = ColorRect.new()
	drift_bar_bg.color = Color(0, 0, 0, 0.5)
	drift_bar_bg.anchor_left = 1.0
	drift_bar_bg.anchor_right = 1.0
	drift_bar_bg.anchor_top = 1.0
	drift_bar_bg.anchor_bottom = 1.0
	drift_bar_bg.offset_left = -250
	drift_bar_bg.offset_right = -30
	drift_bar_bg.offset_top = -66
	drift_bar_bg.offset_bottom = -52
	drift_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drift_bar_bg.visible = false
	root.add_child(drift_bar_bg)
	drift_bar = ColorRect.new()
	drift_bar.size = Vector2(0, 14)
	drift_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drift_bar_bg.add_child(drift_bar)

	lbl_center = _label(140)
	lbl_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
		lbl_hint = hint
		refresh_hint()
		if game:
			game.input_device_changed.connect(func(_d): refresh_hint())
		hint.anchor_left = 1.0
		hint.anchor_right = 1.0
		hint.anchor_top = 1.0
		hint.anchor_bottom = 1.0
		hint.offset_left = -960
		hint.offset_right = -20
		hint.offset_top = -36
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hint.modulate = Color(1, 1, 1, 0.7)

	var mm: Control = MinimapScript.new()
	mm.anchor_top = 1.0
	mm.anchor_bottom = 1.0
	mm.offset_left = 20
	mm.offset_right = 290
	mm.offset_top = -290
	mm.offset_bottom = -20
	mm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(mm)
	mm.setup(race.track, race.karts, kart)
	minimap = mm
	_build_ranking()
	if race.time_trial:
		lbl_pos.visible = false
		ranking_box.visible = false


## RF-113: lista de posições ao vivo com busto + nome, na lateral direita.
func _build_ranking() -> void:
	var vb := VBoxContainer.new()
	vb.anchor_left = 1.0
	vb.anchor_right = 1.0
	vb.offset_left = -236
	vb.offset_right = -16
	vb.offset_top = 124
	vb.add_theme_constant_override("separation", 3)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vb)
	ranking_box = vb
	for i in race.karts.size():
		var row := PanelContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0, 0, 0, 0.45)
		st.set_corner_radius_all(8)
		st.content_margin_left = 6
		st.content_margin_right = 8
		row.add_theme_stylebox_override("panel", st)
		vb.add_child(row)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 6)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(hb)
		var pos := _label(20, hb)
		pos.text = "%dº" % (i + 1)
		pos.custom_minimum_size.x = 34
		var head := TextureRect.new()
		head.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		head.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		head.custom_minimum_size = Vector2(44, 32)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(head)
		var nm := _label(20, hb)
		rank_rows.append({"style": st, "head": head, "name": nm})


func _update_ranking() -> void:
	if race.time_trial:
		return
	var order: Array = race.ranking()
	for i in rank_rows.size():
		var r: Dictionary = rank_rows[i]
		var k: Node3D = order[i]
		r["head"].texture = Chars.art(k.char_id, "head")
		r["name"].text = k.display_name
		r["name"].add_theme_color_override("font_color", k.color.lightened(0.25))
		var me: bool = k == kart
		r["style"].bg_color = Color(1.0, 0.85, 0.2, 0.55) if me else (Color(0.3, 0.3, 0.45, 0.5) if k.is_player else Color(0, 0, 0, 0.45))


func _process(_delta: float) -> void:
	if root:
		_fit()


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
	_update_ranking()
	boost_fx = lerpf(boost_fx, 1.0 if p.boost_time > 0.0 else 0.0, 1.0 - exp(-8.0 * delta))
	var slm := speed_lines.material as ShaderMaterial
	slm.set_shader_parameter("intensity", boost_fx if Gfx.setting("speed_lines", true) else 0.0)
	slm.set_shader_parameter("aspect", root.size.x / maxf(1.0, root.size.y))
	var lap: int = race.lap_of(p)
	lbl_lap.text = "VOLTA %d/%d" % [lap, race.laps]
	# RF-134: volta final em vermelho
	lbl_lap.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3) if lap == race.laps and race.laps > 1 and not p.finished else Color.WHITE)
	lbl_time.text = fmt_time(race.race_time)
	# RF-133: tempo da volta atual e melhor volta
	if race.state != "countdown" and not p.finished:
		lbl_laptime.text = "Volta %s" % fmt_time(race.race_time - lap_start) + ("   Melhor %s" % fmt_time(best_lap) if best_lap < INF else "")
	# RF-132: posição com cor de pódio e "pulo" quando muda
	lbl_pos.text = "%dº/%d" % [p.rank, race.karts.size()]
	var pod := [Color(1.0, 0.82, 0.15), Color(0.85, 0.88, 0.95), Color(0.9, 0.55, 0.25)]
	lbl_pos.add_theme_color_override("font_color", pod[p.rank - 1] if p.rank <= 3 else Color.WHITE)
	if p.rank != last_rank:
		pos_pop = 1.0 if last_rank != 0 else 0.0
		last_rank = p.rank
	pos_pop = maxf(0.0, pos_pop - delta * 3.0)
	lbl_pos.pivot_offset = lbl_pos.size * Vector2(1.0, 0.5)
	lbl_pos.scale = Vector2.ONE * (1.0 + 0.35 * pos_pop)

	# RF-130: ícone do item com roleta
	if p.item_roll > 0.0:
		roll_t += delta
		item_icon.set_kind(ROLL_ORDER[int(roll_t * 14.0) % ROLL_ORDER.size()])
		item_style.border_color = Color(1, 1, 1, 0.9)
	else:
		item_icon.set_kind(p.item)
		item_style.border_color = ITEM_COLORS.get(p.item, Color(1, 1, 1, 0.4))
	lbl_item.text = (ITEM_NAMES.get(p.item, "") + (" x%d" % p.item_charges if p.item == "triplo" else "")) if p.item_roll <= 0.0 else ""
	if p.shield_time > 0.0 and p.item == "":
		lbl_item.text = "ESCUDO %ds" % int(ceil(p.shield_time))
	# RF-135: queijinhos
	lbl_cheese.text = "%d/10" % p.cheese
	lbl_cheese.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if p.cheese >= 10 else Color.WHITE)
	# RF-131: velocímetro + carga do drift
	var mph: bool = Gfx.setting("speed_unit", "kmh") == "mph"
	lbl_speed.text = "%d" % int(absf(p.speed) * (2.237 if mph else 3.6))
	lbl_unit.text = "mph" if mph else "km/h"
	lbl_speed.add_theme_color_override("font_color", Color(1.0, 0.6, 0.15) if p.boost_time > 0.0 else Color.WHITE)
	drift_bar_bg.visible = p.drifting
	if p.drifting:
		var f := clampf(p.drift_charge / KartScript.MINI_TURBO_3, 0.0, 1.0)
		drift_bar.size.x = drift_bar_bg.size.x * f
		drift_bar.color = KartScript.drift_color(p.drift_charge)
	if p.slip_flash > 1.1 and msg_time < 0.5:
		_flash("VÁCUO!", 0.9)

	# RF-31: contagem no centro; cada número entra grande e encolhe, "VAI!" em verde
	var pop := 0.0
	var center_color := Color(1.0, 0.85, 0.2)
	if race.state == "countdown":
		lbl_center.text = str(int(ceil(race.countdown)))
		pop = fmod(race.countdown, 1.0)
	elif race.race_time < 0.8:
		lbl_center.text = "VAI!"
		pop = 1.0 - race.race_time / 0.8
		center_color = Color(0.35, 1.0, 0.45)
	elif p.finished and race.race_time - p.finish_time < FINISH_TEXT_TIME:
		lbl_center.text = "CHEGOU!" if race.time_trial else "CHEGOU! %dº" % p.rank
	else:
		lbl_center.text = ""
	lbl_center.add_theme_color_override("font_color", center_color)
	lbl_center.pivot_offset = lbl_center.size * 0.5
	lbl_center.scale = Vector2.ONE * (1.0 + 0.6 * pop * pop)

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
			var lt: float = race.race_time - lap_start
			best_lap = minf(best_lap, lt)
			lap_start = race.race_time
			_flash(("VOLTA FINAL!" if lap == race.laps else "VOLTA %d" % lap) + "   " + fmt_time(lt), 2.0)
		last_lap = lap
	elif p.finished and not final_lap_counted:
		final_lap_counted = true
		best_lap = minf(best_lap, p.finish_time - lap_start)
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
	if race.time_trial:
		_show_tt_results()
		return
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
	var game := get_node_or_null("/root/Game")
	var gp: bool = game != null and game.is_gp()
	title.text = "GRAND PRIX · CORRIDA %d/%d" % [game.gp_index + 1, game.GP_TRACKS.size()] if gp else "RESULTADO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 24)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)
	var ranking: Array = race.ranking()
	body.add_child(_podium(ranking, 0.82 if gp else 1.0))
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
		pos.custom_minimum_size.x = 48 if gp else 60
		var face := Chars.art_rect(k.char_id, 34)
		if face:
			hb.add_child(face)
		var nm := _label(22 if gp else 26, hb)
		var tag := ""
		if k.is_player:
			tag = "  (J%d)" % (k.player_index + 1) if multi else "  (você)"
		nm.text = k.display_name + tag
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.add_theme_color_override("font_color", k.color.lightened(0.2))
		var tm := _label(24 if gp else 26, hb)
		tm.text = fmt_time(k.finish_time) if k.finished else "--:--"
		if gp:  # RF-194: +pontos e total
			var plus := _label(24, hb)
			plus.text = "+%d" % int(race.gp_gained.get(k.char_id, 0))
			plus.custom_minimum_size.x = 48
			plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			plus.add_theme_color_override("font_color", Color(0.45, 1.0, 0.5))
			var total := _label(24, hb)
			total.text = "%d pts" % int(game.gp_points.get(k.char_id, 0))
			total.custom_minimum_size.x = 84
			total.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	outer.add_child(buttons)
	var again := Button.new()
	if gp:
		var TrackScript = load("res://scripts/track.gd")
		again.text = "PÓDIO DO GP" if game.gp_is_last() else "PRÓXIMA: %s" % TrackScript.find(game.GP_TRACKS[game.gp_index + 1])["name"]
		again.pressed.connect(race.gp_continue)
	else:
		again.text = "Correr de novo (R)"
		again.pressed.connect(race.restart)
	GameScript.make_primary(again)
	again.add_theme_font_size_override("font_size", 22)
	buttons.add_child(again)
	var menu := Button.new()
	menu.text = "Menu (Esc)"
	menu.add_theme_font_size_override("font_size", 22)
	menu.pressed.connect(race.to_menu)
	buttons.add_child(menu)
	_focus_later(again)


## RF-73: pódio com o top 3 de corpo inteiro (2º, 1º, 3º).
func _podium(ranking: Array, f := 1.0) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size = Vector2(500 * f, 0)
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
		var art := Chars.art_rect(k.char_id, s[1] * f, "full")
		if art:
			art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			col.add_child(art)
		var block := PanelContainer.new()
		var st := StyleBoxFlat.new()
		st.bg_color = s[3]
		st.set_corner_radius_all(6)
		block.add_theme_stylebox_override("panel", st)
		block.custom_minimum_size = Vector2(155 * f, s[2] * f)
		col.add_child(block)
		var lbl := _label(34, block)
		lbl.text = "%dº %s" % [i + 1, k.display_name]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 22)
	return row


## RF-183: liga/desliga minimapa e lista de posições.
func apply_settings() -> void:
	if minimap:
		minimap.visible = Gfx.setting("show_minimap", true)
	if ranking_box:
		ranking_box.visible = Gfx.setting("show_ranking", true) and not race.time_trial


# ---------------------------------------------------------------- contra o relógio (RF-232/234)

static func record_text(rec: Dictionary) -> String:
	if not rec.has("race_time"):
		return "RECORDE: --  (seja o primeiro!)"
	var who: String = Chars.find(String(rec.get("race_char", ""))).get("name", "?")
	return "RECORDE %s (%s)" % [fmt_time(float(rec["race_time"])), who]


## Diferença pro recorde antigo: "-0:01.23" (melhor) ou "+0:00.50" (pior).
static func diff_text(t: float, ref: float) -> String:
	var d := t - ref
	return ("-" if d < 0.0 else "+") + fmt_time(absf(d))


func _show_tt_results() -> void:
	_fit()
	var k: Node3D = race.player
	var old: Dictionary = race.tt_record
	var got: Dictionary = race.tt_result
	results = PanelContainer.new()
	results.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.06, 0.12, 0.94)))
	results.anchor_left = 0.5
	results.anchor_right = 0.5
	results.anchor_top = 0.5
	results.anchor_bottom = 0.5
	results.offset_left = -440
	results.offset_right = 440
	results.offset_top = -300
	results.offset_bottom = 300
	root.add_child(results)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	results.add_child(outer)
	var title := _label(40, outer)
	title.text = "CONTRA O RELÓGIO · %s" % race.track.def["name"]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 28)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)
	var art := Chars.art_rect(k.char_id, 300, "full")
	if art:
		art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		body.add_child(art)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(vb)
	if got.get("race", false):
		var nr := _label(46, vb)
		nr.text = "NOVO RECORDE!"
		nr.add_theme_color_override("font_color", Color(0.45, 1.0, 0.5))
	var total := _label(56, vb)
	total.text = fmt_time(k.finish_time)
	if old.has("race_time"):
		var cmp := _label(24, vb)
		cmp.text = "Recorde anterior %s   (%s)" % [fmt_time(float(old["race_time"])), diff_text(k.finish_time, float(old["race_time"]))]
		cmp.add_theme_color_override("font_color", Color(0.45, 1.0, 0.5) if k.finish_time < float(old["race_time"]) else Color(1.0, 0.5, 0.4))
	var best: float = race.tt_best_lap()
	for i in race.tt_laps.size():
		var lt: float = race.tt_laps[i]
		var row := _label(26, vb)
		row.text = "Volta %d   %s" % [i + 1, fmt_time(lt)]
		if is_equal_approx(lt, best):
			row.text += "   ★ melhor"
			row.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	var lap_rec := _label(22, vb)
	if got.get("lap", false):
		lap_rec.text = "NOVA MELHOR VOLTA DA PISTA!"
		lap_rec.add_theme_color_override("font_color", Color(0.45, 1.0, 0.5))
	elif old.has("lap_time"):
		var who: String = Chars.find(String(old.get("lap_char", ""))).get("name", "?")
		lap_rec.text = "Melhor volta da pista %s (%s)" % [fmt_time(float(old["lap_time"])), who]
		lap_rec.modulate = Color(1, 1, 1, 0.75)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	outer.add_child(buttons)
	var again := Button.new()
	again.text = "TENTAR DE NOVO (R)"
	again.pressed.connect(race.restart)
	GameScript.make_primary(again)
	again.add_theme_font_size_override("font_size", 22)
	buttons.add_child(again)
	var menu := Button.new()
	menu.text = "MENU (Esc)"
	menu.add_theme_font_size_override("font_size", 22)
	menu.pressed.connect(race.to_menu)
	buttons.add_child(menu)
	_focus_later(again)


## RF-242: dica de controle conforme o último dispositivo.
func refresh_hint() -> void:
	if lbl_hint == null:
		return
	var game := get_node_or_null("/root/Game")
	lbl_hint.text = game.hint(HINT_KBD, HINT_PAD) if game else HINT_KBD


## Foco no botão do resultado só depois de um instante: quem ainda está segurando
## A/Enter pra acelerar não reinicia sem querer.
func _focus_later(b: Button) -> void:
	b.focus_mode = Control.FOCUS_ALL
	get_tree().create_timer(0.8).timeout.connect(func():
		if is_instance_valid(b):
			b.grab_focus())
