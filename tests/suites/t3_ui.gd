extends "res://tests/suites/t2_modes.gd"
## Testes — interface: navegação, layout, troca de teclas, escolha de piloto, visual, carregamento, placar, analógico, cores.
## (camada de run_tests.gd — ver o topo de run_tests.gd)


func _test_ui_nav() -> void:
	var game = root.get_node_or_null("Game")
	if game == null:
		return
	game.mode = "race"
	game.num_players = 1
	game.laps = 3
	game.track_id = "queijo"
	game.difficulty = 1
	print("CA-46 menu em etapas só com controle")
	check(_pad(JOY_BUTTON_A).is_action_pressed("ui_accept") and _pad(JOY_BUTTON_B).is_action_pressed("ui_cancel"), "A = ui_accept e B = ui_cancel (botões focados funcionam no controle)")
	var menu = await _new_menu()
	var up := JOY_BUTTON_DPAD_UP
	var down := JOY_BUTTON_DPAD_DOWN
	var right := JOY_BUTTON_DPAD_RIGHT
	var left := JOY_BUTTON_DPAD_LEFT
	var a := JOY_BUTTON_A
	check(menu.step == menu.STEP_MODE and menu.get_viewport().gui_get_focus_owner() == menu.mode_cards[0], "começa na etapa MODO com foco no cartão")
	menu._input(_pad(right))
	menu._input(_pad(right))
	check(menu.MODE_IDS[menu.mode_i] == "tt", "→→ escolhe CONTRA O RELÓGIO")
	menu._input(_pad(down))
	check(menu.nav_r == 2 and menu.player_btns[1].disabled, "↓ vai pros jogadores (só 1 no contra o relógio)")
	menu._input(_pad(up))
	menu._input(_pad(left))
	menu._input(_pad(down))
	menu._input(_pad(right))
	menu._input(_pad(a))
	check(menu.MODE_IDS[menu.mode_i] == "gp" and menu.num_players == 2, "GRAND PRIX com 2 jogadores")
	menu._input(_pad(up))
	menu._input(_pad(up))
	menu._input(_pad(right))
	menu._input(_pad(a))
	check(menu.settings_overlay != null, "↑ até a barra de cima e A em CONFIGURAÇÕES abre")
	if menu.settings_overlay:
		menu.settings_overlay._unhandled_input(_pad(JOY_BUTTON_B))
	await process_frame
	check(menu.settings_overlay == null, "B fecha as configurações")
	menu._input(_pad(down))
	menu._input(_pad(right))
	menu._input(_pad(right))
	menu._input(_pad(right))  # volta pro GRAND PRIX (3 cartões, dá a volta)
	menu._input(_pad(a))
	check(menu.step == menu.STEP_PILOT, "A no cartão vai pra etapa PILOTO")
	menu._input(_pad(right))
	menu._input(_pad(a))
	menu._input(_pad(a))
	check(menu.picks.size() == 2 and menu.step == menu.STEP_TRACK, "J1 e J2 escolhem e vai pra PISTA")
	check(menu.track_btns[2].visible and not menu.track_btns[3].visible, "no Grand Prix a etapa PISTA mostra as 3 copas")
	menu._input(_pad(a))
	check(menu.step == menu.STEP_SETUP and menu.get_viewport().gui_get_focus_owner() == menu.go_btn, "A na copa vai pra AJUSTES com foco no CORRER!")
	menu._input(_pad(up))
	menu._input(_pad(up))
	var laps0: int = menu.laps_i
	menu._input(_pad(right))
	check(menu.laps_i == (laps0 + 1) % menu.LAP_OPTIONS.size(), "→ em VOLTAS muda o valor")
	menu._input(_pad(down))
	var diff0: int = menu.diff_i
	menu._input(_pad(left))
	check(menu.diff_i != diff0, "← em IA muda a dificuldade")
	menu._input(_pad(down))
	menu._input(_pad(a))
	check(menu.started and game.is_gp() and game.num_players == 2 and game.selected_chars.size() == 2, "A em CORRER! começa o GP com 2 jogadores")
	menu.queue_free()
	await process_frame

	game.mode = "race"
	game.num_players = 1
	menu = await _new_menu()
	menu._input(_pad(a))       # CORRIDA
	menu._input(_pad(a))       # piloto
	menu._input(_pad(down))   # grade 3x3: ↓ pula uma linha (4ª pista)
	menu._input(_pad(right))  # → 5ª pista
	check(menu.TrackScript.TRACKS[menu.track_i]["id"] == "fabrica" and menu.track_map.track_id == "fabrica", "↓ na lista troca a pista e o trajeto")
	menu._input(_pad(a))
	menu._input(_pad(a))
	check(menu.started and game.track_id == "fabrica" and game.mode == "race", "corrida na pista escolhida (%s)" % game.track_id)
	menu.queue_free()
	await process_frame

	print("CA-47 voltar (B)")
	game.mode = "race"
	game.num_players = 2
	menu = await _new_menu()
	menu._input(_pad(a))
	menu._input(_pad(a))
	check(menu.picks.size() == 1, "J1 confirmou")
	menu._input(_pad(JOY_BUTTON_B))
	check(menu.picks.is_empty() and menu.step == menu.STEP_PILOT, "B desfaz o piloto")
	menu._input(_pad(JOY_BUTTON_B))
	check(menu.step == menu.STEP_MODE, "B sem piloto escolhido volta pra MODO")
	menu._input(_pad(a))
	menu._input(_pad(a))
	menu._input(_pad(a))
	check(menu.step == menu.STEP_TRACK, "de volta na PISTA")
	menu._input(_pad(JOY_BUTTON_B))
	check(menu.step == menu.STEP_PILOT and menu.picks.size() == 1, "B na PISTA volta pro PILOTO reabrindo o último")
	menu.queue_free()
	game.num_players = 1
	await process_frame
	var race = await _new_race(["nanni"], true)
	race.toggle_pause()
	race._unhandled_input(_pad(JOY_BUTTON_B))
	check(not race.paused, "B no pause continua a corrida")
	race.queue_free()
	await process_frame

	print("CA-48 dicas por dispositivo")
	game.note_device(_key(KEY_W))
	menu = await _new_menu()
	var kbd_text: String = menu.help.text
	game.note_device(_pad(a))
	check(game.last_device == "pad" and menu.help.text != kbd_text and "A:" in menu.help.text, "controle → dicas de botão")
	game.note_device(_key(KEY_W))
	check(game.last_device == "kbd" and menu.help.text == kbd_text, "tecla → dicas de teclado")
	menu.queue_free()
	await process_frame
	race = await _new_race(["nanni"], true)
	game.note_device(_pad(a))
	check(race.huds[0].lbl_hint.text.begins_with("Analógico"), "dica da corrida muda pro controle")
	game.note_device(_key(KEY_W))
	race.queue_free()
	await process_frame

	print("CA-50 confirmação ao sair do GP")
	game.start_gp()
	game.laps = 1
	race = load("res://scripts/race.gd").new()
	race.autopilot_player = true
	race.player_chars = ["nanni"]
	root.add_child(race)
	if race.karts.is_empty():
		await process_frame
	race.toggle_pause()
	race.menu_from_pause()
	check(race.confirm_box.visible and race.get_viewport().gui_get_focus_owner() == race.confirm_no_btn, "Menu no pause do GP pergunta (foco no NÃO)")
	race._unhandled_input(_pad(JOY_BUTTON_B))
	check(not race.confirm_box.visible and race.paused and game.is_gp(), "B/NÃO fecha e o GP continua")
	var conns: Array = race.confirm_yes_btn.pressed.get_connections()
	check(conns.any(func(c): return c["callable"].get_method() == "to_menu"), "SIM vai pro menu")
	race.queue_free()
	game.mode = "race"
	game.laps = 3
	await process_frame


func _test_layout() -> void:
	print("CA-49 interface dentro da tela")
	var game = root.get_node_or_null("Game")
	for sz in [Vector2(1280, 720), Vector2(1280, 960), Vector2(1707, 720)]:
		var label := "%dx%d" % [sz.x, sz.y]
		for mode in ["race", "gp", "tt"]:
			if game:
				game.mode = mode
			var box := Control.new()
			box.size = sz
			root.add_child(box)
			var menu = load("res://scenes/menu.tscn").instantiate()
			menu.start_scene = false
			box.add_child(menu)
			var bad := []
			for s in 4:  # cada etapa
				menu._go_step(s, false)
				await process_frame
				await process_frame
				_all_inside(menu, Rect2(Vector2.ZERO, sz), bad)
			check(bad.is_empty(), "menu (%s, 4 etapas) em %s %s" % [mode, label, str(bad.slice(0, 3))])
			menu._go_step(menu.STEP_PILOT, false)
			await process_frame
			var heads_ok := true
			for card in menu.cards:
				var cr: Rect2 = card.get_global_rect()
				var hr: Rect2 = card.get_node("Head").get_global_rect()
				var band_top: float = card.get_node("Band").get_global_rect().position.y
				# carta recorta (clip_contents); topo da arte dentro e o corte reto escondido atrás da faixa
				if not card.clip_contents or hr.position.y < cr.position.y or hr.end.y < band_top + 4.0 or hr.end.y > cr.end.y:
					heads_ok = false
			check(heads_ok, "CA-55 arte recortada na carta, corte escondido na faixa (%s, %s)" % [mode, label])
			if mode == "race":
				menu.open_settings()
				await process_frame
				await process_frame
				bad = []
				_all_inside(menu.settings_overlay, Rect2(Vector2.ZERO, sz), bad)
				check(bad.is_empty(), "configurações em %s %s" % [label, str(bad.slice(0, 3))])
			box.queue_free()
			await process_frame
	if game:
		game.mode = "race"
	# resultados (corrida e contra o relógio) e pause na tela real
	var Records = load("res://scripts/records.gd")
	Records.path = "user://test_records.cfg"
	for tt in [false, true]:
		var race = load("res://scripts/race.gd").new()
		race.use_game_settings = false
		race.autopilot_player = true
		race.time_trial = tt
		race.player_chars = ["digao"]
		race.laps = 2
		root.add_child(race)
		if race.karts.is_empty():
			await process_frame
		race.toggle_pause()
		await process_frame
		var area: Rect2 = race.get_viewport().get_visible_rect()
		var bad := []
		if game:
			game.note_device(_pad(JOY_BUTTON_A))
			await process_frame
			_all_inside(race.huds[0].root, area, bad)
			check(bad.is_empty(), "HUD com dicas de controle dentro da tela %s" % str(bad.slice(0, 3)))
			game.note_device(_key(KEY_W))
			bad = []
		_all_inside(race.pause_layer, area, bad)
		check(bad.is_empty(), "pause dentro da tela %s" % str(bad.slice(0, 3)))
		race.toggle_pause()
		while not race.results_shown:
			race.step(1.0 / 60.0)
		await process_frame
		await process_frame
		bad = []
		var res: Control = race.results_hud.results
		var need: Vector2 = res.get_combined_minimum_size()
		if need.x > 1280.0 or need.y > 720.0:
			bad.append("painel precisa de %s" % need)
		_all_inside(res, area, bad)
		check(bad.is_empty(), "resultado %s dentro da tela (%s) %s" % ["contra o relógio" if tt else "da corrida", area.size, str(bad.slice(0, 3))])
		race.queue_free()
		await process_frame
	Records.clear_all()
	Records.path = Records.DEFAULT_PATH


func _test_remap() -> void:
	var game = root.get_node_or_null("Game")
	if game == null:
		return
	game.reset_settings()
	print("CA-51 trocar tecla")
	var res: Dictionary = game.rebind_key(0, "drift", _keyev(KEY_J))
	check(res["ok"], "J1 drift → J")
	check(_keyev(KEY_J).is_action("p1_drift") and not _keyev(KEY_SPACE).is_action("p1_drift"), "J aciona o drift; Espaço não")
	check(not _keyev(KEY_SHIFT, KEY_LOCATION_LEFT).is_action("p1_drift"), "alternativa (Shift esq.) saiu")
	game.load_settings()
	check(_keyev(KEY_J).is_action("p1_drift") and game.key_label(0, "drift") == "J", "salvo e recarregado (%s)" % game.key_label(0, "drift"))

	print("CA-52 conflito e tecla reservada")
	res = game.rebind_key(0, "accelerate", _keyev(KEY_S))  # S era o frear do J1
	check(res["ok"] and _keyev(KEY_S).is_action("p1_accelerate") and _keyev(KEY_W).is_action("p1_brake"), "W↔S trocaram (%s)" % res["msg"])
	check(res["msg"] != "", "aviso de troca")
	res = game.rebind_key(0, "use_item", _keyev(KEY_UP))  # ↑ é acelerar do J2
	check(_keyev(KEY_UP).is_action("p1_use_item") and _keyev(KEY_E).is_action("p2_accelerate"), "conflito com o outro jogador troca (%s)" % res["msg"])
	res = game.rebind_key(1, "drift", _keyev(KEY_CTRL, KEY_LOCATION_RIGHT))  # Ctrl dir. era alternativa do item do J2
	check(_keyev(KEY_CTRL, KEY_LOCATION_RIGHT).is_action("p2_drift") and _keyev(KEY_ENTER).is_action("p2_use_item") and not _keyev(KEY_CTRL, KEY_LOCATION_RIGHT).is_action("p2_use_item"), "alternativa sai só dela, o resto fica")
	var before: String = game.key_label(0, "steer_left")
	for k in [KEY_ESCAPE, KEY_M, KEY_R]:
		res = game.rebind_key(0, "steer_left", _keyev(k))
		check(not res["ok"] and game.key_label(0, "steer_left") == before, "%s recusada" % OS.get_keycode_string(k))

	print("CA-53 controle e restaurar")
	res = game.rebind_pad("drift", JOY_BUTTON_Y)
	var all_ok := true
	for p in 4:
		var e := InputEventJoypadButton.new()
		e.button_index = JOY_BUTTON_Y
		e.device = p
		e.pressed = true
		if not e.is_action("p%d_drift" % (p + 1)):
			all_ok = false
	check(res["ok"] and all_ok, "Y vira drift nos 4 controles")
	var rt := InputEventJoypadMotion.new()
	rt.axis = JOY_AXIS_TRIGGER_RIGHT
	rt.axis_value = 1.0
	game.rebind_pad("accelerate", JOY_BUTTON_X)  # X era alternativa do item
	check(rt.is_action("p1_accelerate") and game.pad_label("use_item") == "LB", "gatilho RT continua; item fica só com LB (%s)" % game.pad_label("use_item"))
	check(not game.rebind_pad("drift", JOY_BUTTON_START)["ok"], "Start recusado")
	game.reset_bindings()
	check(_keyev(KEY_SPACE).is_action("p1_drift") and _keyev(KEY_W).is_action("p1_accelerate") and game.pad_label("drift") == "RB" and game.key_binds.is_empty(), "RESTAURAR volta ao padrão")
	game.load_settings()
	check(_keyev(KEY_SPACE).is_action("p1_drift") and not _keyev(KEY_J).is_action("p1_drift"), "padrão também fica salvo")

	print("CA-54 tela de configurações")
	var sm = load("res://scripts/settings_menu.gd").new()
	root.add_child(sm)
	await process_frame
	sm.start_capture(0, "use_item")
	check(sm.bind_buttons["0:use_item"].text.begins_with("APERTE"), "botão mostra APERTE...")
	sm._input(_keyev(KEY_ESCAPE))
	check(sm.capture.is_empty() and _keyev(KEY_E).is_action("p1_use_item") and is_instance_valid(sm) and sm.is_inside_tree(), "Esc cancela sem mudar e sem fechar a tela")
	sm.start_capture(0, "use_item")
	sm._input(_keyev(KEY_Q))
	check(_keyev(KEY_Q).is_action("p1_use_item") and sm.bind_buttons["0:use_item"].text == "Q", "tecla nova aplicada (%s)" % sm.bind_buttons["0:use_item"].text)
	sm.start_capture(-1, "brake")
	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_Y
	jb.pressed = true
	sm._input(jb)
	check(game.pad_label("brake").begins_with("Y"), "coluna do controle aceita botão (%s)" % game.pad_label("brake"))
	check(sm.bind_buttons["pad:steer_left"].disabled, "virar no controle não é trocável (analógico)")
	sm.queue_free()
	await process_frame
	var race = await _new_race(["nanni"], true)
	game.note_device(_keyev(KEY_W))
	race.huds[0].refresh_hint()
	check(" Q: item" in race.huds[0].lbl_hint.text, "dica da corrida mostra a tecla nova (%s)" % race.huds[0].lbl_hint.text)
	race.queue_free()
	game.reset_settings()
	await process_frame


func _test_char_select() -> void:
	var game = root.get_node_or_null("Game")
	if game == null:
		return
	print("CA-56 painel do piloto e confirmação")
	game.mode = "race"
	game.num_players = 2
	var menu = await _new_menu()
	var Chars = load("res://scripts/characters.gd")
	menu._go_step(menu.STEP_PILOT, false)
	menu._select(3)
	await create_timer(0.6).timeout
	var c: Dictionary = Chars.LIST[3]
	check(menu.preview_name.text == c["name"], "painel mostra %s" % c["name"])
	var bars_ok := true
	for k in menu.STATS.size():
		var want: float = menu.BAR_W * int(c[menu.STATS[k][0]]) / 5.0
		if absf(menu.preview_bars[k].size.x - want) > 1.0:
			bars_ok = false
	check(bars_ok, "barras chegam no valor do piloto")
	menu._input(_pad(JOY_BUTTON_A))
	await process_frame
	check(menu.card_tags[3].text == "J1" and menu.picks == [3], "confirmar marca a carta com J1")
	await create_timer(0.6).timeout
	check(menu.card_flash[3].color.a < 0.05 and menu.card_tags[3].scale.is_equal_approx(Vector2.ONE), "brilho e selo terminam a animação")
	menu.queue_free()
	game.num_players = 1
	await process_frame


func _test_menu_look() -> void:
	print("CA-85 visual do menu")
	var game = root.get_node_or_null("Game")
	game.mode = "race"
	game.num_players = 2
	var menu = await _new_menu()
	check(menu.get_node_or_null("BgArt") != null, "fundo com a arte da abertura")
	var th: Theme = root.theme
	check(th.get_stylebox("normal", "Button") is StyleBoxFlat and th.get_stylebox("focus", "Button") is StyleBoxFlat, "botões do tema novo (sem a textura branca)")
	check(menu.crumb_chips.size() == 4, "4 chips de etapa")
	menu._input(_pad(JOY_BUTTON_A))
	menu._input(_pad(JOY_BUTTON_A))
	menu._input(_pad(JOY_BUTTON_DPAD_RIGHT))
	menu._input(_pad(JOY_BUTTON_A))
	menu._input(_pad(JOY_BUTTON_A))
	await process_frame
	check(menu.step == menu.STEP_SETUP and menu.sum_pilots.get_child_count() == 2 and menu.sum_map.track_id != "", "AJUSTES mostra os 2 retratos e o trajeto")
	var cur: StyleBoxFlat = menu.crumb_chips[menu.STEP_SETUP].get_theme_stylebox("panel")
	var done: StyleBoxFlat = menu.crumb_chips[0].get_theme_stylebox("panel")
	check(cur.bg_color != done.bg_color, "chip da etapa atual destacado")
	menu.queue_free()
	game.num_players = 1
	await process_frame


func _test_loading() -> void:
	print("CA-86 tela de carregamento")
	var game = root.get_node_or_null("Game")
	check(ProjectSettings.get_setting("application/boot_splash/image") == "res://assets/ui/splash.png" and ResourceLoader.exists("res://assets/ui/splash.png"), "imagem de inicialização configurada")
	game.track_id = "geladeira"
	game.mode = "race"
	game.show_loading(game.loading_text())
	check(game.is_loading() and game.loading_name.text == "Geladeira Polar" and game.loading.layer >= 100, "CARREGANDO com o nome da pista, por cima de tudo")
	game.gp_cup = 1
	game.start_gp()
	check("Copa Farofa" in game.loading_text() and "1/4" in game.loading_text(), "no GP mostra a copa e a corrida (%s)" % game.loading_text().replace("\n", " / "))
	game.mode = "race"
	game.gp_cup = 0
	# a corrida tira a tela quando o primeiro quadro dela fica pronto
	var race = load("res://scripts/race.gd").new()
	race.use_game_settings = false
	race.autopilot_player = true
	race.player_chars = ["nanni"]
	race.track_id = "queijo"
	root.add_child(race)
	await process_frame
	await process_frame
	await create_timer(0.5).timeout
	check(not game.is_loading(), "a corrida tira o CARREGANDO sozinha")
	race.queue_free()
	await process_frame


func _test_results_live() -> void:
	print("CA-87 placar atualiza quando as IAs terminam")
	var game = root.get_node_or_null("Game")
	game.mode = "race"
	var race = load("res://scripts/race.gd").new()
	race.use_game_settings = false
	race.autopilot_player = true
	race.player_chars = ["shinando"]
	race.track_id = "cozinha"
	race.laps = 1
	root.add_child(race)
	if race.karts.is_empty():
		await process_frame
	# o jogador é rapidíssimo: termina bem antes da maioria
	race.player.max_speed = 60.0
	race.player.accel = 60.0
	var t := 0.0
	while t < 200.0 and not race.results_shown:
		race.step(1.0 / 60.0)
		t += 1.0 / 60.0
	var hud = race.results_hud
	var before := _result_texts(hud)
	var running := before.count("correndo")
	check(race.results_shown and running > 0, "placar abre com quem ainda está correndo (%d)" % running)
	while t < 260.0 and not race.all_finished():
		race.step(1.0 / 60.0)
		t += 1.0 / 60.0
	race.step(1.0 / 60.0)
	var after := _result_texts(hud)
	var times := after.filter(func(s): return ":" in s and "." in s).size()
	check(race.all_finished() and after.count("correndo") == 0 and times == race.karts.size(), "quando todos terminam, todos têm tempo no placar (%d tempos)" % times)
	race.queue_free()
	await process_frame


func _test_char_colors() -> void:
	print("CA-91 cor e número de cada piloto = o carro dele na arte")
	var chars: Array = load("res://scripts/characters.gd").LIST
	var nums := {}
	for c in chars:
		nums[int(c.get("number", 0))] = true
	check(nums.size() == 8 and nums.has(1) and nums.has(8) and not nums.has(0), "números de 1 a 8 sem repetir")
	# na arte: 1 azul, 2 vermelho, 3 amarelo, 4 verde, 5 laranja, 6 azul-claro, 7 vermelho, 8 roxo
	var want := {"fejaum": "azul", "burcca": "vermelho", "nanni": "amarelo", "mugurin": "verde", "digao": "laranja", "shinando": "azul-claro", "telles": "vermelho", "ortiz": "roxo"}
	var bad := []
	for c in chars:
		var col: Color = c["color"]
		var h := col.h * 360.0
		var name := ""
		if col.s < 0.3:
			name = "cinza"
		elif h < 15.0 or h >= 330.0:
			name = "vermelho"
		elif h < 40.0:
			name = "laranja"
		elif h < 65.0:
			name = "amarelo"
		elif h < 160.0:
			name = "verde"
		elif h < 210.0:
			name = "azul-claro"
		elif h < 250.0:
			name = "azul"
		else:
			name = "roxo"
		if name != want[c["id"]]:
			bad.append("%s=%s" % [c["id"], name])
	check(bad.is_empty(), "cores batem com a arte %s" % str(bad))


func _test_stick_menu() -> void:
	print("CA-97 analógico no menu: uma casa por empurrão")
	var game = root.get_node_or_null("Game")
	game.mode = "race"
	game.num_players = 1
	var menu = await _new_menu()
	var has_axis := false
	for a in ["ui_left", "ui_right", "ui_up", "ui_down"]:
		for ev in InputMap.action_get_events(a):
			if ev is InputEventJoypadMotion:
				has_axis = true
	check(not has_axis, "analógico fora das ações de menu (o Game converte)")
	var m0: int = menu.mode_i
	# um empurrão "tremido" chega como vários eventos acima do limite
	for v in [0.4, 0.65, 0.8, 0.95, 1.0, 0.9, 0.7, 0.62]:
		Input.parse_input_event(_stick(v))
	await process_frame
	await process_frame
	check(menu.mode_i == (m0 + 1) % 3, "um empurrão = uma casa (%d → %d)" % [m0, menu.mode_i])
	Input.parse_input_event(_stick(0.5))  # ainda inclinado: não conta de novo
	await process_frame
	check(menu.mode_i == (m0 + 1) % 3, "voltar só um pouco não dá outro passo")
	Input.parse_input_event(_stick(0.05))
	Input.parse_input_event(_stick(0.9))
	await process_frame
	await process_frame
	check(menu.mode_i == (m0 + 2) % 3, "soltou e empurrou de novo: mais uma casa")
	# segurando: repete devagar
	var before: int = menu.mode_i
	for s in 60:  # 1 s segurado
		game._stick_repeat(1.0 / 60.0)
	await process_frame
	await process_frame
	var steps := wrapi(menu.mode_i - before, 0, 3)
	check(steps >= 1, "segurando 1 s repete (%d passos a mais)" % steps)
	Input.parse_input_event(_stick(0.0))
	await process_frame
	menu.queue_free()
	await process_frame


func _touch(idx: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = pressed
	return e


func _drag(idx: int, pos: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	return e


func _test_touch() -> void:
	print("CA-112 controles de toque (celular)")
	var game = root.get_node_or_null("Game")
	game.settings["touch_controls"] = "on"
	game.settings["touch_auto_gas"] = true
	game.num_players = 1
	game.mode = "race"
	game.track_id = "queijo"
	game.selected_chars = ["nanni"]
	var race = load("res://scenes/race.tscn").instantiate()
	root.add_child(race)
	await process_frame
	race._process(0.016)
	var tl = race.touch_layer
	check(tl != null and tl.visible, "controles aparecem na corrida")
	check(race.huds[0].lbl_hint == null or race.huds[0].lbl_hint.text == "", "sem dicas de teclado no toque")
	var sz: Vector2 = tl.root.size
	var drift_c: Vector2 = tl._center(tl.buttons.filter(func(b): return b["id"] == "drift")[0])
	var home: Vector2 = tl._stick_home()
	# dois dedos: um no direcional arrastando pra direita, outro segurando o drift
	tl._input(_touch(0, home, true))
	tl._input(_drag(0, home + Vector2(tl.STICK_RANGE * tl._scale() * 0.6, 0)))
	tl._input(_touch(1, drift_c, true))
	var sr := Input.get_action_strength("p1_steer_right")
	check(sr > 0.4 and sr < 0.8 and Input.is_action_pressed("p1_drift"), "vira proporcional (%.2f) e segura o drift ao mesmo tempo" % sr)
	tl._input(_touch(0, home, false))
	tl._input(_touch(1, drift_c, false))
	check(Input.get_action_strength("p1_steer_right") == 0.0 and not Input.is_action_pressed("p1_drift"), "soltou: para de virar e de driftar")
	# acelerador automático: no começo da contagem não (queimaria a largada), no fim sim
	race.countdown = 2.5
	tl._process(0.016)
	var early := Input.is_action_pressed("p1_accelerate")
	race.countdown = 1.0
	tl._process(0.016)
	check(not early and Input.is_action_pressed("p1_accelerate"), "acelera sozinho no fim da contagem (largada turbo)")
	var brake_c: Vector2 = tl._center(tl.buttons.filter(func(b): return b["id"] == "brake")[0])
	tl._input(_touch(2, brake_c, true))
	tl._process(0.016)
	check(Input.is_action_pressed("p1_brake") and not Input.is_action_pressed("p1_accelerate"), "freio solta o acelerador")
	tl._input(_touch(2, brake_c, false))
	var pause_c: Vector2 = tl._center(tl.buttons.filter(func(b): return b["id"] == "pause")[0])
	tl._input(_touch(3, pause_c, true))
	tl._input(_touch(3, pause_c, false))
	tl._process(0.016)
	check(race.paused and not tl.visible and not Input.is_action_pressed("p1_accelerate"), "botão de pausa pausa e esconde os controles (soltando tudo)")
	race.toggle_pause()
	race.queue_free()
	await process_frame
	# abertura no toque
	var intro = load("res://scenes/intro.tscn").instantiate()
	root.add_child(intro)
	await process_frame
	check("TOQUE" in intro.prompt.text and intro.get_node_or_null("Fullscreen") != null, "abertura: TOQUE PARA COMEÇAR e botão de tela cheia")
	var fs: Control = intro.get_node("Fullscreen")
	intro._input(_touch(0, fs.get_global_rect().get_center(), false))
	check(not intro.leaving, "toque no TELA CHEIA não começa o jogo")
	intro._input(_touch(0, Vector2(400, 400), false))
	check(intro.leaving, "toque na tela começa (mesmo sem o clique emulado do navegador)")
	await process_frame
	await process_frame
	if current_scene:
		current_scene.queue_free()
	if is_instance_valid(intro):
		intro.queue_free()
	await process_frame
	check(game.move_keys(1) == "setas", "J2 nas setas aparece como \"setas\" (a fonte não tem os símbolos de seta)")
	var dev_was: String = game.last_device
	game.last_device = "touch"
	check(game.hint("k", "p", "t") == "t" and game.hint("k", "p") == "k", "dicas de toque no toque (e a do teclado quando não há texto de toque)")
	game.last_device = dev_was
	game.settings["touch_controls"] = "auto"
	game.load_settings()
