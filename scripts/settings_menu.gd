extends Control
## Tela de configurações (RF-180..185). Overlay usado pelo menu e pelo pause.
## Cada mudança vai direto pro Game.set_setting(): aplica na hora e salva em user://settings.cfg.

signal closed

const GameScript = preload("res://scripts/game.gd")
const FPS_NAMES := ["SEM LIMITE", "30", "60", "120", "144", "240"]

var game: Node
var tabs: TabContainer
var controls := {}   # chave -> {"kind", "node", "value_label", "fmt"}


func _ready() -> void:
	game = get_node_or_null("/root/Game")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(960, 600)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.07, 0.08, 0.14, 1.0)
	st.set_corner_radius_all(16)
	st.set_border_width_all(3)
	st.border_color = Color(1.0, 0.82, 0.2, 0.8)
	st.content_margin_left = 26
	st.content_margin_right = 26
	st.content_margin_top = 16
	st.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", st)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)
	var title := _label("CONFIGURAÇÕES", 40, Color(1.0, 0.82, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_font_size_override("font_size", 22)
	vb.add_child(tabs)
	_build_audio(_tab("ÁUDIO"))
	_build_video(_tab("VÍDEO"))
	_build_game(_tab("JOGO"))
	_build_controls(_tab("CONTROLES"))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	vb.add_child(row)
	var reset := Button.new()
	reset.text = "PADRÃO"
	reset.custom_minimum_size = Vector2(220, 56)
	reset.pressed.connect(_reset)
	row.add_child(reset)
	var back := Button.new()
	back.text = "VOLTAR"
	back.custom_minimum_size = Vector2(220, 56)
	GameScript.make_primary(back)
	back.pressed.connect(close)
	row.add_child(back)
	tabs.get_tab_bar().grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if GameScript.is_back(event) \
			or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	closed.emit()
	queue_free()


# ---------------------------------------------------------------- abas

func _tab(tab_name: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 10)
	scroll.add_child(vb)
	var pad := Control.new()
	pad.custom_minimum_size.y = 6
	vb.add_child(pad)
	return vb


func _build_audio(p: VBoxContainer) -> void:
	_slider(p, "Volume geral", "vol_master", 0.0, 1.0, 0.05, _pct)
	_slider(p, "Música", "vol_music", 0.0, 1.0, 0.05, _pct)
	_slider(p, "Efeitos", "vol_sfx", 0.0, 1.0, 0.05, _pct)
	_slider(p, "Motor", "vol_engine", 0.0, 1.0, 0.05, _pct)
	_note(p, "Dica: M liga/desliga todo o som a qualquer momento.")


func _build_video(p: VBoxContainer) -> void:
	_toggle(p, "Tela cheia", "fullscreen")
	_toggle(p, "Sincronização vertical (vsync)", "vsync")
	var fps_items := []
	for i in GameScript.FPS_OPTIONS.size():
		fps_items.append([FPS_NAMES[i], GameScript.FPS_OPTIONS[i]])
	_options(p, "Limite de FPS", "max_fps", fps_items)
	_options(p, "Qualidade gráfica", "quality", [["BAIXO", 0], ["MÉDIO", 1], ["ALTO", 2]])
	_slider(p, "Escala de resolução 3D", "render_scale", 0.5, 1.0, 0.05, _pct)
	_slider(p, "Campo de visão", "fov", 60.0, 90.0, 1.0, func(v): return "%d°" % int(v))
	_toggle(p, "Mostrar FPS", "show_fps")
	_note(p, "BAIXO desliga bloom, SSAO e antisserrilhado. Resolução menor alivia a placa de vídeo.")


func _build_game(p: VBoxContainer) -> void:
	_slider(p, "Tremida da câmera", "shake", 0.0, 1.0, 0.1, _pct)
	_toggle(p, "Linhas de velocidade no turbo", "speed_lines")
	_options(p, "Partículas", "particles_full", [["NORMAIS", true], ["REDUZIDAS", false]])
	_toggle(p, "Nomes sobre os karts", "show_names")
	_toggle(p, "Minimapa", "show_minimap")
	_toggle(p, "Lista de posições", "show_ranking")
	_options(p, "Velocidade em", "speed_unit", [["KM/H", "kmh"], ["MPH", "mph"]])
	_note(p, "Partículas valem a partir da próxima corrida.")


func _build_controls(p: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 8)
	p.add_child(grid)
	var rows := [
		["AÇÃO", "J1 (TECLADO)", "J2 (TECLADO)", "CONTROLE"],
		["Acelerar", "W", "↑", "A / RT"],
		["Frear / ré", "S", "↓", "B / LT"],
		["Virar", "A  D", "←  →", "Analógico / D-pad"],
		["Drift (no ar: manobra)", "Espaço / Shift esq.", "Shift dir. / Num 0", "RB"],
		["Usar item", "E / Ctrl esq.", "Enter / Ctrl dir.", "LB / X"],
		["Pausar", "Esc", "Esc", "Start"],
		["Liga/desliga o som", "M", "M", "—"],
	]
	for r in rows.size():
		for c in rows[r].size():
			var col := Color(1.0, 0.82, 0.2) if r == 0 else (Color(0.85, 0.88, 1.0) if c == 0 else Color.WHITE)
			grid.add_child(_label(rows[r][c], 18 if r == 0 else 19, col))
	_note(p, "J3 e J4 usam os controles 3 e 4. Sozinho, o J1 também usa as teclas do J2.")
	_slider(p, "Zona morta do analógico", "deadzone", 0.05, 0.5, 0.01, _pct)


# ---------------------------------------------------------------- linhas

func _pct(v: float) -> String:
	return "%d%%" % int(roundf(v * 100.0))


func _val(key: String):
	return game.settings[key] if game else GameScript.DEFAULTS[key]


func _set_value(key: String, v) -> void:
	if game:
		game.set_setting(key, v)


func _row(p: VBoxContainer, text: String) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	p.add_child(hb)
	var l := _label(text, 21, Color.WHITE)
	l.custom_minimum_size.x = 380
	hb.add_child(l)
	return hb


func _slider(p: VBoxContainer, text: String, key: String, lo: float, hi: float, step: float, fmt: Callable) -> void:
	var hb := _row(p, text)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(_val(key))
	s.custom_minimum_size = Vector2(340, 32)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(s)
	var vl := _label(fmt.call(s.value), 21, Color(1.0, 0.82, 0.2))
	vl.custom_minimum_size.x = 90
	hb.add_child(vl)
	s.value_changed.connect(func(v):
		vl.text = fmt.call(v)
		_set_value(key, v))
	controls[key] = {"kind": "slider", "node": s, "value_label": vl, "fmt": fmt}


func _toggle(p: VBoxContainer, text: String, key: String) -> void:
	var hb := _row(p, text)
	var c := CheckButton.new()
	c.button_pressed = bool(_val(key))
	c.text = "LIGADO" if c.button_pressed else "DESLIGADO"
	c.add_theme_font_size_override("font_size", 20)
	hb.add_child(c)
	c.toggled.connect(func(on):
		c.text = "LIGADO" if on else "DESLIGADO"
		_set_value(key, on))
	controls[key] = {"kind": "toggle", "node": c}


func _options(p: VBoxContainer, text: String, key: String, items: Array) -> void:
	var hb := _row(p, text)
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(240, 44)
	o.add_theme_font_size_override("font_size", 20)
	for i in items.size():
		o.add_item(items[i][0], i)
	o.selected = maxi(0, _index_of(items, _val(key)))
	hb.add_child(o)
	o.item_selected.connect(func(i): _set_value(key, items[i][1]))
	controls[key] = {"kind": "options", "node": o, "items": items}


func _index_of(items: Array, v) -> int:
	for i in items.size():
		if items[i][1] == v:
			return i
	return -1


func _note(p: VBoxContainer, text: String) -> void:
	var l := _label(text, 16, Color(1, 1, 1, 0.6))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(l)


func _label(text: String, size: int, c: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", maxi(3, size / 7))
	return l


## RF-180: PADRÃO — restaura tudo e atualiza os controles sem disparar sinais.
func _reset() -> void:
	if game:
		game.reset_settings()
	for key in controls:
		var c: Dictionary = controls[key]
		var v = _val(key)
		match c["kind"]:
			"slider":
				c["node"].set_value_no_signal(float(v))
				c["value_label"].text = c["fmt"].call(float(v))
			"toggle":
				c["node"].set_pressed_no_signal(bool(v))
				c["node"].text = "LIGADO" if v else "DESLIGADO"
			"options":
				c["node"].selected = maxi(0, _index_of(c["items"], v))
