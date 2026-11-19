extends Control
## Menu em etapas (RF-290..295): MODO → PILOTO → PISTA → AJUSTES → corrida.
## Toda a navegação passa por _input (teclado e controle iguais, RF-240/241).
## Voltar (Esc/Backspace/B): desfaz o piloto confirmado → etapa anterior → abertura.

const Chars = preload("res://scripts/characters.gd")
const GameScript = preload("res://scripts/game.gd")
const TrackScript = preload("res://scripts/track.gd")
const TrackMap = preload("res://scripts/track_map.gd")
const Records = preload("res://scripts/records.gd")
const SettingsMenu = preload("res://scripts/settings_menu.gd")
const STATS := [["speed", "VELOCIDADE"], ["accel", "ACELERAÇÃO"], ["handling", "CONTROLE"], ["weight", "PESO"]]
const LAP_OPTIONS := [1, 2, 3, 5]
const PLAYER_COLORS := [Color(1.0, 0.85, 0.2), Color(0.3, 0.8, 1.0), Color(0.4, 1.0, 0.4), Color(1.0, 0.45, 0.8)]
const CARD_SIZE := Vector2(166, 196)
const SND_MOVE := "res://assets/kenney/ui/sounds/switch-a.ogg"
const SND_OK := "res://assets/audio/sfx/item.ogg"
const BAR_W := 200.0
const BAND_H := 40.0
const STEP_NAMES := ["MODO", "PILOTO", "PISTA", "AJUSTES"]
enum { STEP_MODE, STEP_PILOT, STEP_TRACK, STEP_SETUP }
const MODE_NAMES := ["CORRIDA", "GRAND PRIX", "CONTRA O RELÓGIO"]
const MODE_IDS := ["race", "gp", "tt"]
const MODE_DESC := [
	"Uma corrida contra 7 pilotos na pista que você escolher.",
	"As 3 pistas da Copa Queijo em sequência. Pontos por posição; quem somar mais leva a taça.",
	"Sozinho contra o tempo, com o fantasma do seu recorde. Começa com Queijo Triplo.",
]
const MODE_COLORS := [Color(0.95, 0.35, 0.2), Color(0.95, 0.75, 0.15), Color(0.3, 0.75, 1.0)]
const DIFF_NAMES := ["FÁCIL", "NORMAL", "DIFÍCIL"]
const TRACK_DESC := {
	"queijo": "Circuito clássico no campo, com curvas de todo tipo. Bom pra aprender.",
	"deserto": "Areia, cactos e retas longas sob o sol do fim de tarde.",
	"cozinha": "A cozinha de madrugada: azulejo escorregadio e luz de geladeira.",
	"churrasco": "Em cima da mesa do churrasco: farofa que segura e grelha com labaredas.",
	"fabrica": "Linha de produção: esteiras, rodas de queijo rolando e prensas.",
}

var step := STEP_MODE
var mode_i := 0
var num_players := 1
var selected := 0
var picks: Array = []
var track_i := 0
var laps_i := 2
var diff_i := 1
var start_scene := true   # os testes desligam pra não trocar de cena
var started := false
var settings_overlay: Control

# navegação: linhas da etapa atual; linha 0 = barra de cima (VOLTAR, CONFIGURAÇÕES)
var nav_rows: Array = []
var nav_r := 1
var nav_i := 0

# nós
var steps_root: Array = []     # Control de cada etapa
var crumbs: Array = []         # Label de cada etapa no topo
var back_btn: Button
var gfx_btn: Button
var help: Label
var fade: ColorRect
var snd: AudioStreamPlayer
var mode_cards: Array = []
var mode_styles: Array = []
var mode_icons: Array = []
var player_btns: Array = []
var cards: Array = []
var card_styles: Array = []
var card_tags: Array = []
var card_flash: Array = []
var sub: Label
var preview_style: StyleBoxFlat
var preview_art: TextureRect
var preview_name: Label
var preview_bars: Array = []
var preview_vals: Array = []
var shown := -1
var track_btns: Array = []
var track_map: Control
var track_title: Label
var track_info: Label
var track_desc: Label
var laps_btn: Button
var diff_btn: Button
var go_btn: Button
var summary: Label
var t := 0.0


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
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	root_vb.add_child(top)
	back_btn = _button("VOLTAR", 18)
	back_btn.custom_minimum_size = Vector2(200, 46)
	back_btn.pressed.connect(_back)
	top.add_child(back_btn)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 2)
	top.add_child(mid)
	var title := _label("Car Mundon'GO", 40, Color(1.0, 0.82, 0.15))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(title)
	var crumb_row := HBoxContainer.new()
	crumb_row.alignment = BoxContainer.ALIGNMENT_CENTER
	crumb_row.add_theme_constant_override("separation", 10)
	mid.add_child(crumb_row)
	for i in STEP_NAMES.size():
		if i > 0:
			crumb_row.add_child(_label("·", 18, Color(1, 1, 1, 0.35)))
		var c := _label("%d %s" % [i + 1, STEP_NAMES[i]], 17, Color.WHITE)
		crumb_row.add_child(c)
		crumbs.append(c)
	gfx_btn = _button("CONFIGURAÇÕES", 18)  # RF-185
	gfx_btn.custom_minimum_size = Vector2(200, 46)
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

	help = _label("", 15, Color(1, 1, 1, 0.6))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_vb.add_child(help)

	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	for b in [back_btn, gfx_btn]:
		b.focus_mode = Control.FOCUS_ALL


## RF-291: etapa 1 — três cartões de modo + quantos jogadores.
func _build_mode() -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 26)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)
	for i in MODE_NAMES.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(340, 300)
		b.focus_mode = Control.FOCUS_ALL
		b.clip_contents = true
		var st := StyleBoxFlat.new()
		st.set_corner_radius_all(18)
		st.set_border_width_all(3)
		for s in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(s, st)
		mode_styles.append(st)
		var inner := VBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.offset_left = 22
		inner.offset_right = -22
		inner.offset_top = 22
		inner.offset_bottom = -22
		inner.add_theme_constant_override("separation", 14)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(inner)
		var icon := _mode_icon(i)
		inner.add_child(icon)
		mode_icons.append(icon)
		var nm := _label(MODE_NAMES[i], 28, MODE_COLORS[i].lightened(0.3))
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(nm)
		var desc := _label(MODE_DESC[i], 16, Color(0.88, 0.9, 1.0))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(desc)
		b.pressed.connect(func(): _pick_mode(i))
		b.focus_entered.connect(func():
			if not started:
				mode_i = i
			_refresh_mode())
		b.mouse_entered.connect(func(): b.grab_focus())
		b.pivot_offset = b.custom_minimum_size * 0.5
		row.add_child(b)
		mode_cards.append(b)
	var prow := HBoxContainer.new()
	prow.alignment = BoxContainer.ALIGNMENT_CENTER
	prow.add_theme_constant_override("separation", 12)
	vb.add_child(prow)
	prow.add_child(_label("JOGADORES", 22, Color(0.85, 0.87, 0.95)))
	for n in 4:
		var b := _button("%d" % (n + 1), 26)
		b.custom_minimum_size = Vector2(76, 60)
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(func():
			if not _is_tt():
				num_players = n + 1
				picks.clear()
				_play(SND_MOVE)
				_refresh_mode())
		prow.add_child(b)
		player_btns.append(b)
	return vb


## Ícone desenhado do modo (bandeira, taça, cronômetro).
func _mode_icon(i: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 92)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col: Color = MODE_COLORS[i]
	c.draw.connect(func():
		var m := Vector2(c.size.x * 0.5, 46)
		match i:
			0:  # bandeira quadriculada
				c.draw_line(m + Vector2(-34, 40), m + Vector2(-34, -40), Color(0.85, 0.85, 0.9), 5.0)
				for y in 4:
					for x in 6:
						var cc := Color.WHITE if (x + y) % 2 == 0 else Color(0.1, 0.1, 0.12)
						c.draw_rect(Rect2(m + Vector2(-31 + x * 11, -40 + y * 11), Vector2(11, 11)), cc)
			1:  # taça
				c.draw_colored_polygon(PackedVector2Array([m + Vector2(-30, -38), m + Vector2(30, -38), m + Vector2(18, 4), m + Vector2(-18, 4)]), col)
				c.draw_rect(Rect2(m + Vector2(-5, 4), Vector2(10, 20)), col.darkened(0.2))
				c.draw_rect(Rect2(m + Vector2(-22, 24), Vector2(44, 12)), col.darkened(0.35))
				c.draw_arc(m + Vector2(-30, -22), 12, PI * 0.5, PI * 1.5, 12, col, 5.0)
				c.draw_arc(m + Vector2(30, -22), 12, -PI * 0.5, PI * 0.5, 12, col, 5.0)
			2:  # cronômetro
				c.draw_circle(m + Vector2(0, 4), 36, col.darkened(0.3))
				c.draw_circle(m + Vector2(0, 4), 30, Color(0.95, 0.97, 1.0))
				c.draw_rect(Rect2(m + Vector2(-6, -42), Vector2(12, 10)), col.darkened(0.3))
				var ang := t * 2.0
				c.draw_line(m + Vector2(0, 4), m + Vector2(0, 4) + Vector2(sin(ang), -cos(ang)) * 24, Color(0.9, 0.2, 0.15), 4.0)
				c.draw_line(m + Vector2(0, 4), m + Vector2(0, -12), Color(0.15, 0.15, 0.2), 4.0)
	)
	return c


## RF-260..263: etapa 2 — cartas dos pilotos + painel em destaque.
func _build_pilot() -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(grid)
	for i in Chars.LIST.size():
		grid.add_child(_make_card(i))
	hb.add_child(_build_preview())
	return hb


## RF-292: etapa 3 — lista de pistas + trajeto desenhado + informações.
func _build_track() -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 22)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(list)
	for i in TrackScript.TRACKS.size():
		var td: Dictionary = TrackScript.TRACKS[i]
		var b := _button(td["name"], 20)
		b.custom_minimum_size = Vector2(380, 62)
		b.focus_mode = Control.FOCUS_ALL
		b.clip_text = true
		var chip := ColorRect.new()  # cor do tema da pista
		chip.color = td["wall"][0]
		chip.size = Vector2(10, 40)
		chip.position = Vector2(-2, 9)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(chip)
		b.pressed.connect(func(): _pick_track(i))
		b.focus_entered.connect(func():
			if not _is_gp() and not started:
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
	panel.custom_minimum_size = Vector2(560, 0)
	hb.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)
	track_title = _label("", 30, Color(1.0, 0.85, 0.3))
	track_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(track_title)
	track_map = TrackMap.new()
	track_map.custom_minimum_size = Vector2(528, 290)
	track_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(track_map)
	track_desc = _label("", 17, Color(0.9, 0.92, 1.0))
	track_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	track_desc.custom_minimum_size.x = 528
	vb.add_child(track_desc)
	track_info = _label("", 16, Color(0.75, 0.9, 1.0))
	track_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	track_info.custom_minimum_size.x = 528
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
	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.1, 0.11, 0.2)
	st.set_corner_radius_all(18)
	st.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", st)
	panel.custom_minimum_size = Vector2(440, 0)
	hb.add_child(panel)
	summary = _label("", 21, Color(0.92, 0.94, 1.0))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(summary)
	return hb


## Setinhas desenhadas nos dois lados do botão de valor (a fonte não tem < >).
func _add_arrows(b: Button) -> void:
	for side in [-1.0, 1.0]:
		var a := Control.new()
		a.mouse_filter = Control.MOUSE_FILTER_IGNORE
		a.anchor_top = 0.5
		a.anchor_bottom = 0.5
		a.anchor_left = 0.0 if side < 0 else 1.0
		a.anchor_right = a.anchor_left
		a.offset_left = 22.0 if side < 0 else -42.0
		a.offset_right = a.offset_left + 20.0
		a.offset_top = -12.0
		a.offset_bottom = 8.0
		a.draw.connect(func():
			var col := Color(0.16, 0.17, 0.22, 0.25 if b.disabled else 0.9)
			var pts := PackedVector2Array([Vector2(0, 10), Vector2(18, 0), Vector2(18, 20)]) if side < 0 else PackedVector2Array([Vector2(20, 10), Vector2(2, 0), Vector2(2, 20)])
			a.draw_colored_polygon(pts, col))
		b.add_child(a)


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


## RF-261: carta em retrato; a base reta da arte fica escondida atrás da faixa do nome.
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
	b.mouse_entered.connect(func():
		if step == STEP_PILOT and not picks.has(i) and selected != i and not started:
			_select(i))
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
	var tex: Texture2D = head.texture
	var hw := CARD_SIZE.x - 2.0
	var hh := hw * (float(tex.get_height()) / tex.get_width() if tex else 0.72)
	head.size = Vector2(hw, hh)
	head.position = Vector2((CARD_SIZE.x - hw) * 0.5, CARD_SIZE.y - BAND_H + 10.0 - hh)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(head)
	var band := Panel.new()
	band.name = "Band"
	var band_st := StyleBoxFlat.new()
	band_st.bg_color = Color(0, 0, 0, 0.55)
	band_st.corner_radius_bottom_left = 12
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
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(190, 254)
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(holder)
	var spot := TextureRect.new()
	spot.texture = _radial(Color(1, 1, 1, 0.22), Color(1, 1, 1, 0.0))
	spot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	spot.size = Vector2(190, 190)
	spot.position = Vector2(0, 24)
	spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(spot)
	var floor_shadow := TextureRect.new()
	floor_shadow.texture = _radial(Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.0))
	floor_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	floor_shadow.size = Vector2(150, 26)
	floor_shadow.position = Vector2(20, 230)
	floor_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(floor_shadow)
	preview_art = TextureRect.new()
	preview_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_art.size = Vector2(190, 254)
	preview_art.pivot_offset = Vector2(95, 254)
	preview_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(preview_art)
	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 6)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(stats)
	preview_name = _label("", 38, Color.WHITE)
	stats.add_child(preview_name)
	for s in STATS:
		stats.add_child(_label(s[1], 14, Color(0.8, 0.82, 0.92)))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		stats.add_child(line)
		var bgr := ColorRect.new()
		bgr.color = Color(1, 1, 1, 0.1)
		bgr.custom_minimum_size = Vector2(BAR_W, 14)
		bgr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bgr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(bgr)
		var fill := ColorRect.new()
		fill.size = Vector2(0, 14)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bgr.add_child(fill)
		preview_bars.append(fill)
		var v := _label("", 16, Color.WHITE)
		line.add_child(v)
		preview_vals.append(v)
	return panel


# ---------------------------------------------------------------- estado

func _is_gp() -> bool:
	return MODE_IDS[mode_i] == "gp"


func _is_tt() -> bool:
	return MODE_IDS[mode_i] == "tt"


func _current_player() -> int:
	return mini(picks.size(), num_players - 1)


func _play(path: String) -> void:
	if snd and ResourceLoader.exists(path):
		snd.stream = load(path)
		snd.play()


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
		var c: Label = crumbs[i]
		c.add_theme_color_override("font_color", Color(1.0, 0.82, 0.2) if i == s else (Color(0.6, 0.9, 0.6) if i < s else Color(1, 1, 1, 0.4)))
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
			_focus(1 + (0 if _is_gp() else track_i), 0)
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
			for b in track_btns:
				nav_rows.append([b])
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


# ---------------------------------------------------------------- etapa MODO

func _pick_mode(i: int) -> void:
	mode_i = i
	if _is_tt():
		num_players = 1
	picks.clear()
	_play(SND_OK)
	_go_step(STEP_PILOT)


func _refresh_mode() -> void:
	for i in mode_cards.size():
		var st: StyleBoxFlat = mode_styles[i]
		var sel := i == mode_i
		st.bg_color = MODE_COLORS[i].darkened(0.55 if sel else 0.78)
		st.border_color = Color.WHITE if sel else MODE_COLORS[i].darkened(0.3)
		st.set_border_width_all(5 if sel else 2)
		_tween_scale(mode_cards[i], 1.05 if sel else 1.0)
	# só mostra 1 jogador no contra o relógio; o valor de verdade só muda ao escolher o modo
	var shown_players := 1 if _is_tt() else num_players
	for n in player_btns.size():
		var b: Button = player_btns[n]
		b.disabled = _is_tt() and n > 0
		if n + 1 == shown_players:
			GameScript.make_primary(b)
		else:
			for s in ["normal", "hover", "pressed", "focus"]:
				b.remove_theme_stylebox_override(s)


# ---------------------------------------------------------------- etapa PILOTO

func _select(i: int) -> void:
	selected = i
	_play(SND_MOVE)
	_refresh_pilot()


func _move_selection(stp: int) -> void:
	var before := selected
	_move_selection_raw(stp)
	if selected != before:
		_play(SND_MOVE)


func _move_selection_raw(stp: int) -> void:
	var n := Chars.LIST.size()
	for k in n:
		selected = (selected + stp + n) % n
		if not picks.has(selected):
			return


func _refresh_pilot() -> void:
	var cur := _current_player()
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


func _confirm() -> void:
	if step != STEP_PILOT or picks.has(selected) or picks.size() >= num_players:
		return
	var just := selected
	picks.append(selected)
	_confirm_fx(just)
	if picks.size() < num_players:
		_move_selection_raw(1)
		_refresh_pilot()
		return
	_refresh_pilot()
	_go_step(STEP_TRACK)


func _tween_scale(n: Control, s: float) -> void:
	if not is_inside_tree() or (n.scale.is_equal_approx(Vector2(s, s)) and not n.has_meta("tw")):
		return
	_new_tween(n).tween_property(n, "scale", Vector2(s, s), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _new_tween(n: Node) -> Tween:
	if n.has_meta("tw"):
		var old: Tween = n.get_meta("tw")
		if old and old.is_valid():
			old.kill()
	var tw := create_tween()
	n.set_meta("tw", tw)
	return tw


func _show_preview(i: int) -> void:
	var c: Dictionary = Chars.LIST[i]
	var col: Color = c["color"]
	var cur := _current_player()
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
		preview_vals[k].text = "%d/5" % int(c[STATS[k][0]])
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


# ---------------------------------------------------------------- etapa PISTA

func _pick_track(i: int) -> void:
	if not _is_gp():
		track_i = i
	_play(SND_OK)
	_go_step(STEP_SETUP)


func _cup() -> Array:
	var game_m := get_node_or_null("/root/Game")
	return game_m.GP_TRACKS if game_m else ["queijo", "deserto", "cozinha"]


func _refresh_track() -> void:
	var gp := _is_gp()
	var cup := _cup()
	for i in track_btns.size():
		var b: Button = track_btns[i]
		b.visible = not gp or i == 0
		b.text = "COPA QUEIJO (3 PISTAS)" if gp and i == 0 else TrackScript.TRACKS[i]["name"]
		if not gp and i == track_i:
			GameScript.make_primary(b)
		else:
			for s in ["normal", "hover", "pressed", "focus"]:
				b.remove_theme_stylebox_override(s)
	var td: Dictionary = TrackScript.find(cup[0]) if gp else TrackScript.TRACKS[track_i]
	track_map.set_track(td["id"])
	track_map.line_color = (td["wall"][0] as Color).lightened(0.3)
	if gp:
		var names := []
		for id in cup:
			names.append(TrackScript.find(id)["name"])
		track_title.text = "COPA QUEIJO"
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
		var e: String = {"farofa": "farofa", "belt": "esteira", "belt_side": "esteira lateral", "grill": "grelha"}.get(z["kind"], "")
		if e != "" and not uniq.has(e):
			uniq.append(e)
	for h in d["hazards"]:
		var e: String = {"flame": "labaredas", "wheel": "rodas de queijo", "press": "prensas"}.get(h["kind"], "")
		if e != "" and not uniq.has(e):
			uniq.append(e)
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
	var pilots := []
	for i in picks.size():
		pilots.append(("J%d " % (i + 1) if num_players > 1 else "") + Chars.LIST[picks[i]]["name"])
	var track_name: String = "Copa Queijo (3 pistas)" if _is_gp() else TrackScript.TRACKS[track_i]["name"]
	summary.text = "MODO\n%s\n\nPILOTO%s\n%s\n\nPISTA\n%s" % [MODE_NAMES[mode_i], "S" if picks.size() > 1 else "", ", ".join(pilots) if not pilots.is_empty() else "—", track_name]


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
		tw.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/race.tscn"))


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
	if step == STEP_SETUP:
		kbd = "Setas para os lados: mudar o valor · para cima/baixo: navegar · Enter: confirmar · Esc: voltar"
		pad = "Direcional para os lados: mudar o valor · para cima/baixo: navegar · A: confirmar · B: voltar"
		help.text = game.hint(kbd, pad) if game else kbd
		return
	if game == null:
		help.text = kbd % ["WASD", "setas"]
		return
	help.text = game.hint(kbd % [game.move_keys(0), game.move_keys(1)], pad)


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
