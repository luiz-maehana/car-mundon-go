extends Control
## Menu: modo, jogadores, seleção de piloto e voltas (RF-01..03, RF-60, RF-260..263).
## Com 2+ jogadores cada um confirma o seu piloto em sequência; Backspace/B desfaz.

const Chars = preload("res://scripts/characters.gd")
const GameScript = preload("res://scripts/game.gd")
const STATS := [["speed", "VELOCIDADE"], ["accel", "ACELERAÇÃO"], ["handling", "CONTROLE"], ["weight", "PESO"]]
const LAP_OPTIONS := [1, 2, 3, 5]
const TrackScript = preload("res://scripts/track.gd")
const PLAYER_COLORS := [Color(1.0, 0.85, 0.2), Color(0.3, 0.8, 1.0), Color(0.4, 1.0, 0.4), Color(1.0, 0.45, 0.8)]
const CARD_SIZE := Vector2(166, 196)
const SND_MOVE := "res://assets/kenney/ui/sounds/switch-a.ogg"
const SND_OK := "res://assets/audio/sfx/item.ogg"
const BAR_W := 200.0
const BAND_H := 40.0

var selected := 0
var laps_i := 2
var num_players := 1
var picks: Array = []  # índices de Chars.LIST já confirmados (J1, J2, ...)
var cards: Array = []       # Button de cada piloto
var card_styles: Array = []
var card_tags: Array = []
var card_flash: Array = []  # ColorRect branco do "pulo" ao confirmar
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

# painel do piloto em destaque (RF-260/262)
var preview_style: StyleBoxFlat
var preview_art: TextureRect
var preview_holder: Control
var preview_name: Label
var preview_bars: Array = []   # ColorRect de preenchimento por atributo
var preview_vals: Array = []   # Label com o número
var shown := -1                # piloto mostrado no painel
var t := 0.0
var snd: AudioStreamPlayer
var fade: ColorRect


func _ready() -> void:
	var game := get_node_or_null("/root/Game")
	if game:
		game.play_music("menu")  # RF-221
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
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
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
	root_vb.add_theme_constant_override("separation", 14)
	margin.add_child(root_vb)

	# topo: MODO · título · CONFIGURAÇÕES
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	root_vb.add_child(top)
	mode_btn = _button("", 18)  # RF-190
	mode_btn.custom_minimum_size = Vector2(330, 46)
	mode_btn.pressed.connect(func():
		mode_i = (mode_i + 1) % MODE_IDS.size()
		if _is_tt():
			num_players = 1
			picks.clear()
		_refresh())
	top.add_child(mode_btn)
	var title := _label("Car Mundon'GO", 50, Color(1.0, 0.82, 0.15))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	gfx_btn = _button("CONFIGURAÇÕES", 18)  # RF-185
	gfx_btn.custom_minimum_size = Vector2(330, 46)
	gfx_btn.pressed.connect(open_settings)
	top.add_child(gfx_btn)

	# meio: cartas | painel do piloto
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 20)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	root_vb.add_child(mid)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_child(grid)
	for i in Chars.LIST.size():
		grid.add_child(_make_card(i))
	mid.add_child(_build_preview())

	# opções
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	root_vb.add_child(row)
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
	track_btn.custom_minimum_size = Vector2(360, 60)
	track_btn.clip_text = true  # nome longo de pista não estica a linha
	track_btn.pressed.connect(func():
		track_i = (track_i + 1) % TrackScript.TRACKS.size()
		_refresh())
	row.add_child(track_btn)
	go_btn = _button("", 28)
	go_btn.custom_minimum_size = Vector2(240, 60)
	go_btn.pressed.connect(_confirm)
	GameScript.make_primary(go_btn)  # RF-174
	row.add_child(go_btn)

	help = _label("", 15, Color(1, 1, 1, 0.6))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vb.add_child(help)

	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)

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


## RF-260: painel da direita com o piloto em destaque.
func _build_preview() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preview_style = StyleBoxFlat.new()
	preview_style.bg_color = Color(0.11, 0.12, 0.22)
	preview_style.set_corner_radius_all(18)
	preview_style.set_border_width_all(4)
	preview_style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", preview_style)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	sub = _label("", 22, Color(0.85, 0.85, 0.95))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	vb.add_child(hb)
	# arte num "suporte" de tamanho fixo: a animação mexe na posição sem brigar com o container
	preview_holder = Control.new()
	preview_holder.custom_minimum_size = Vector2(190, 254)
	preview_holder.clip_contents = true
	preview_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(preview_holder)
	# holofote atrás e sombra no chão do piloto em destaque
	var spot := TextureRect.new()
	spot.texture = _radial(Color(1, 1, 1, 0.22), Color(1, 1, 1, 0.0))
	spot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spot.size = Vector2(190, 190)
	spot.position = Vector2(0, 24)
	spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_holder.add_child(spot)
	var floor_shadow := TextureRect.new()
	floor_shadow.texture = _radial(Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.0))
	floor_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	floor_shadow.size = Vector2(150, 26)
	floor_shadow.position = Vector2(20, 230)
	floor_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_holder.add_child(floor_shadow)
	preview_art = TextureRect.new()
	preview_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_art.size = Vector2(190, 254)
	preview_art.pivot_offset = Vector2(95, 254)
	preview_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_holder.add_child(preview_art)
	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 6)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(stats)
	preview_name = _label("", 38, Color.WHITE)
	stats.add_child(preview_name)
	for s in STATS:
		var l := _label(s[1], 14, Color(0.8, 0.82, 0.92))
		stats.add_child(l)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		stats.add_child(line)
		var bg := ColorRect.new()
		bg.color = Color(1, 1, 1, 0.1)
		bg.custom_minimum_size = Vector2(BAR_W, 14)
		bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(bg)
		var fill := ColorRect.new()
		fill.size = Vector2(0, 14)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.add_child(fill)
		preview_bars.append(fill)
		var v := _label("", 16, Color.WHITE)
		line.add_child(v)
		preview_vals.append(v)
	return panel


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
	b.custom_minimum_size = Vector2(170, 60)
	return b


static var _tex_cache := {}


## Textura de gradiente radial (centro → borda), em cache.
func _radial(inner: Color, outer: Color) -> Texture2D:
	var key := "r%s%s" % [inner, outer]
	if not _tex_cache.has(key):
		var g := Gradient.new()
		g.set_color(0, inner)
		g.set_color(1, outer)
		var t2 := GradientTexture2D.new()
		t2.gradient = g
		t2.fill = GradientTexture2D.FILL_RADIAL
		t2.fill_from = Vector2(0.5, 0.5)
		t2.fill_to = Vector2(0.5, 0.0)
		t2.width = 128
		t2.height = 128
		_tex_cache[key] = t2
	return _tex_cache[key]


## Gradiente vertical (cima → baixo), em cache.
func _vgrad(top: Color, bottom: Color) -> Texture2D:
	var key := "v%s%s" % [top, bottom]
	if not _tex_cache.has(key):
		var g := Gradient.new()
		g.set_color(0, top)
		g.set_color(1, bottom)
		var t2 := GradientTexture2D.new()
		t2.gradient = g
		t2.fill_from = Vector2(0, 0.35)
		t2.fill_to = Vector2(0, 1)
		t2.width = 4
		t2.height = 64
		_tex_cache[key] = t2
	return _tex_cache[key]


## RF-261: carta em retrato; a cabeça cabe inteira dentro (proporção mantida) e a carta recorta.
func _make_card(i: int) -> Button:
	var c: Dictionary = Chars.LIST[i]
	var col: Color = c["color"]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = CARD_SIZE
	b.clip_contents = true
	var st := StyleBoxFlat.new()
	st.set_corner_radius_all(14)
	for s in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(s, st)
	card_styles.append(st)
	b.pressed.connect(func():
		if picks.has(i):
			return
		if selected == i:
			_confirm()
		else:
			_select(i))
	b.mouse_entered.connect(func():  # RF-262: passar o mouse seleciona
		if nav_zone == 1 and not picks.has(i) and selected != i and not started:
			_select(i))
	# brilho redondo atrás da cabeça + escurecido embaixo (profundidade)
	var glow := TextureRect.new()
	glow.texture = _radial(Color(1, 1, 1, 0.32), Color(1, 1, 1, 0.0))
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.size = Vector2(CARD_SIZE.x * 1.1, CARD_SIZE.x * 1.1)
	glow.position = Vector2(-CARD_SIZE.x * 0.05, 0)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(glow)
	var shade := TextureRect.new()
	shade.texture = _vgrad(Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.45))
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(shade)
	var head := TextureRect.new()
	head.name = "Head"
	head.texture = Chars.art(c["id"], "head")
	head.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	head.stretch_mode = TextureRect.STRETCH_SCALE
	# a arte termina num corte reto nos ombros: a base fica escondida atrás da faixa do nome
	var tex: Texture2D = head.texture
	var hw := CARD_SIZE.x - 2.0  # orelhas quase encostando na borda, sem cortar
	var hh := hw * (float(tex.get_height()) / tex.get_width() if tex else 0.72)
	head.size = Vector2(hw, hh)
	head.position = Vector2((CARD_SIZE.x - hw) * 0.5, CARD_SIZE.y - BAND_H + 10.0 - hh)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(head)
	var band := Panel.new()
	band.name = "Band"
	var band_st := StyleBoxFlat.new()
	band_st.bg_color = Color(0, 0, 0, 0.55)
	band_st.corner_radius_bottom_left = 12  # acompanha a borda arredondada da carta
	band_st.corner_radius_bottom_right = 12
	band.add_theme_stylebox_override("panel", band_st)
	band.anchor_top = 1.0
	band.anchor_right = 1.0
	band.anchor_bottom = 1.0
	band.offset_top = -BAND_H
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(band)
	var nm := _label(c["name"], 22, col.lightened(0.35))
	nm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	band.add_child(nm)
	var tag := _label("", 24, Color.WHITE)
	tag.position = Vector2(CARD_SIZE.x - 52, 6)
	tag.size = Vector2(46, 30)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(tag)
	card_tags.append(tag)
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(flash)
	card_flash.append(flash)
	b.pivot_offset = CARD_SIZE * 0.5
	cards.append(b)
	return b


func _is_gp() -> bool:
	return MODE_IDS[mode_i] == "gp"


func _is_tt() -> bool:
	return MODE_IDS[mode_i] == "tt"


func _current_player() -> int:
	return picks.size()


## Troca a seleção com som (mouse/teclado/controle).
func _select(i: int) -> void:
	selected = i
	_play(SND_MOVE)
	_refresh()


func _play(path: String) -> void:
	if snd and ResourceLoader.exists(path):
		snd.stream = load(path)
		snd.play()


func _refresh() -> void:
	var cur := mini(_current_player(), num_players - 1)
	for i in card_styles.size():
		var st: StyleBoxFlat = card_styles[i]
		var col: Color = Chars.LIST[i]["color"]
		var taken: int = picks.find(i)
		var tag: Label = card_tags[i]
		var sel := i == selected and taken < 0
		if taken >= 0:
			st.set_border_width_all(5)
			st.border_color = PLAYER_COLORS[taken]
			st.bg_color = col.darkened(0.78)
			tag.text = "J%d" % (taken + 1)
			tag.add_theme_color_override("font_color", PLAYER_COLORS[taken])
			cards[i].modulate = Color(0.75, 0.75, 0.8)
		else:
			st.set_border_width_all(5 if sel else 2)
			st.border_color = (PLAYER_COLORS[cur] if num_players > 1 else Color.WHITE) if sel else col.darkened(0.3)
			st.bg_color = col.darkened(0.3 if sel else 0.62)
			tag.text = ""
			cards[i].modulate = Color.WHITE
		_tween_scale(cards[i], 1.07 if sel else 1.0)
	if num_players == 1:
		sub.text = "ESCOLHA SEU PILOTO"
		sub.add_theme_color_override("font_color", Color(0.85, 0.85, 0.95))
	else:
		sub.text = "JOGADOR %d, ESCOLHA SEU PILOTO" % (cur + 1)
		sub.add_theme_color_override("font_color", PLAYER_COLORS[cur])
	_show_preview(selected)
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


func _tween_scale(n: Control, s: float) -> void:
	if not is_inside_tree() or (n.scale.is_equal_approx(Vector2(s, s)) and not n.has_meta("tw")):
		return
	var tw := _new_tween(n)
	tw.tween_property(n, "scale", Vector2(s, s), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## RF-262: painel do piloto — arte desliza/esmaece, barras animam até o valor novo.
func _show_preview(i: int) -> void:
	var c: Dictionary = Chars.LIST[i]
	var col: Color = c["color"]
	var cur := mini(_current_player(), num_players - 1)
	preview_style.border_color = PLAYER_COLORS[cur] if num_players > 1 else col.lightened(0.2)
	preview_style.bg_color = col.darkened(0.78)
	if shown == i:
		return
	var dir := 1.0 if shown < i else -1.0
	shown = i
	preview_art.texture = Chars.art(c["id"], "full")
	preview_name.text = c["name"]
	preview_name.add_theme_color_override("font_color", col.lightened(0.35))
	for k in STATS.size():
		var v := int(c[STATS[k][0]])
		preview_vals[k].text = "%d/5" % v
		preview_bars[k].color = col.lightened(0.15)
	if not is_inside_tree():
		for k in STATS.size():
			preview_bars[k].size.x = BAR_W * int(c[STATS[k][0]]) / 5.0
		return
	var tw := create_tween().set_parallel(true)
	preview_art.modulate.a = 0.0
	preview_art.position.x = 40.0 * dir
	tw.tween_property(preview_art, "modulate:a", 1.0, 0.2)
	tw.tween_property(preview_art, "position:x", 0.0, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	preview_name.pivot_offset = Vector2(0, preview_name.size.y * 0.5)
	preview_name.scale = Vector2(1.15, 1.15)
	tw.tween_property(preview_name, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for k in STATS.size():
		var target := BAR_W * int(c[STATS[k][0]]) / 5.0
		tw.tween_property(preview_bars[k], "size:x", target, 0.3).set_delay(0.03 * k).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Respiração do piloto em destaque e pulso da borda da carta selecionada.
func _process(delta: float) -> void:
	t += delta
	if preview_art:
		preview_art.position.y = sin(t * 2.2) * 3.0
		preview_art.scale = Vector2.ONE * (1.0 + 0.012 * sin(t * 2.2))
	if selected < card_styles.size() and not picks.has(selected):
		var st: StyleBoxFlat = card_styles[selected]
		var a := 0.65 + 0.35 * sin(t * 6.0)
		st.border_color.a = a


## Um tween por carta de cada vez (o novo cancela o anterior).
func _new_tween(n: Node) -> Tween:
	if n.has_meta("tw"):
		var old: Tween = n.get_meta("tw")
		if old and old.is_valid():
			old.kill()
	var tw := create_tween()
	n.set_meta("tw", tw)
	return tw


## RF-263: pulo + brilho na carta confirmada.
func _confirm_fx(i: int) -> void:
	_play(SND_OK)
	if not is_inside_tree():
		return
	var b: Control = cards[i]
	b.scale = Vector2(1.18, 1.18)
	_new_tween(b).tween_property(b, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# brilho e selo num tween à parte: mover a seleção logo depois não pode cortar no meio
	var tw := create_tween().set_parallel(true)
	card_flash[i].color.a = 0.7
	tw.tween_property(card_flash[i], "color:a", 0.0, 0.35)
	var tag: Label = card_tags[i]
	tag.pivot_offset = tag.size * 0.5
	tag.scale = Vector2(2.0, 2.0)
	tw.tween_property(tag, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _move_selection(step: int) -> void:
	var before := selected
	_move_selection_raw(step)
	if selected != before:
		_play(SND_MOVE)


func _move_selection_raw(step: int) -> void:
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
		if nav_zone == 1:
			_confirm()
		else:
			var b: Button = nav_rows[nav_zone][nav_i]
			if not b.disabled:
				b.pressed.emit()
	else:
		return
	vp.set_input_as_handled()


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
				_move_selection_raw(1)
			_play(SND_MOVE)
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
	var kbd := "Setas: navegar · Enter: confirmar · Esc/Backspace: voltar · J1 = %s/controle 1 · J2 = %s/controle 2 · J3/J4 = controles 3/4 · M: som"
	var pad := "Direcional: navegar · A: confirmar · B: voltar · cada jogador usa o seu controle (1 a 4)"
	if game == null:
		help.text = kbd % ["WASD", "setas"]
		return
	help.text = game.hint(kbd % [game.move_keys(0), game.move_keys(1)], pad)


func _confirm() -> void:
	if picks.has(selected):
		return
	var just := selected
	picks.append(selected)
	if picks.size() < num_players:
		_move_selection_raw(1)
		_refresh()
		_confirm_fx(just)
		return
	_refresh()
	_confirm_fx(just)
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
		# RF-263: escurece rápido e vai pra corrida
		var tw := create_tween()
		tw.tween_property(fade, "color:a", 1.0, 0.35).set_delay(0.15)
		tw.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/race.tscn"))
