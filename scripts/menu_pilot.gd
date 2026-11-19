extends "res://scripts/menu_widgets.gd"
## Menu — etapas MODO e PILOTO (cartões de modo, cartas dos pilotos, painel com stats e poder).
## (camada de menu.gd — ver o topo de menu.gd)


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
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.add_child(hb)
	power_howto = _label("PODERES: " + Chars.POWER_HOWTO, 15, Color(1.0, 0.9, 0.55))
	power_howto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_howto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	power_howto.custom_minimum_size = Vector2(1100, 0)
	vb.add_child(power_howto)
	return vb


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
	# RF-428: o poder do piloto, explicado
	preview_power = _label("", 18, Color(1.0, 0.85, 0.3))
	stats.add_child(_gap(4))
	stats.add_child(preview_power)
	preview_power_desc = _label("", 14, Color(0.9, 0.92, 1.0))
	preview_power_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_power_desc.custom_minimum_size = Vector2(250, 0)
	stats.add_child(preview_power_desc)
	return panel


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
			GameScript.clear_primary(b)


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
	var pw: Dictionary = c.get("power", {})
	preview_power.text = "PODER: " + String(pw.get("name", "")).to_upper()
	preview_power_desc.text = String(pw.get("desc", ""))
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


## RF-341: retrato do piloto no resumo (cabeça num círculo da cor dele + nome; "J2" no multi).
func _pilot_badge(ci: int, slot: int) -> Control:
	var c: Dictionary = Chars.LIST[ci]
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := Panel.new()
	ring.custom_minimum_size = Vector2(76, 76)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = (c["color"] as Color).darkened(0.35)
	st.border_color = PLAYER_COLORS[slot % PLAYER_COLORS.size()] if num_players > 1 else (c["color"] as Color).lightened(0.3)
	st.set_border_width_all(3)
	st.set_corner_radius_all(38)
	ring.add_theme_stylebox_override("panel", st)
	ring.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var head := TextureRect.new()
	head.texture = Chars.art(c["id"], "head")
	head.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	head.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	head.position = Vector2(-4, 2)
	head.size = Vector2(84, 84)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_child(head)
	vb.add_child(ring)
	var name_l := _label(("J%d " % (slot + 1) if num_players > 1 else "") + String(c["name"]).to_upper(), 14, (c["color"] as Color).lightened(0.35))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(name_l)
	return vb
