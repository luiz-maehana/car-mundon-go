extends Node
## Autoload "Game": escolhas do menu e mapa de controles por jogador (SPEC §5).
## Ações: "p<N>_<acao>", N = 1..4. Controle (joypad) do jogador N = device N-1.

const GAME_TITLE := "Car Mundon'GO"
const MAX_PLAYERS := 4
const ACTIONS := ["accelerate", "brake", "steer_left", "steer_right", "drift", "use_item"]

const Sfx = preload("res://scripts/sfx.gd")

var num_players := 1
var selected_chars: Array = ["fejaum"]
var laps := 3
var track_id := "queijo"
var difficulty := 1
var muted := false
var music: AudioStreamPlayer
var current_music := ""

## RF-242: último dispositivo usado ("kbd" | "pad"); as dicas da tela seguem ele.
signal input_device_changed(device: String)
var last_device := "kbd"

# ---------------------------------------------------------------- configurações (RF-180..185)

const SETTINGS_PATH := "user://settings.cfg"
const QUALITY_NAMES := ["BAIXO", "MÉDIO", "ALTO"]
const FPS_OPTIONS := [0, 30, 60, 120, 144, 240]
const DEFAULTS := {
	"vol_master": 0.85, "vol_music": 0.7, "vol_sfx": 0.9, "vol_engine": 0.7,
	"fullscreen": false, "vsync": true, "max_fps": 0, "quality": 2, "render_scale": 1.0, "fov": 72.0, "show_fps": false,
	"shake": 1.0, "speed_lines": true, "particles_full": true, "show_names": true, "show_minimap": true,
	"show_ranking": true, "speed_unit": "kmh", "deadzone": 0.25,
}

var settings: Dictionary = DEFAULTS.duplicate()
var settings_path := SETTINGS_PATH  # os testes trocam pra não mexer no arquivo do jogador
var fps_label: Label

## Compatibilidade (RF-161): ALTO = qualidade 2.
var graphics_high: bool:
	get:
		return int(settings["quality"]) == 2
	set(v):
		settings["quality"] = 2 if v else 0


func _ready() -> void:
	setup_inputs()
	# nome mostrado: Car Mundon'GO. O config/name do projeto continua o antigo de propósito:
	# ele define a pasta de save (user://) e trocar apagaria configurações e recordes.
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title(GAME_TITLE)
	_setup_ui()
	_setup_buses()
	load_settings()
	# RF-82: música contínua entre menu e corrida
	music = AudioStreamPlayer.new()
	music.stream = Sfx.music("menu")
	current_music = "menu"
	music.volume_db = -3.0
	music.bus = "Music"
	# limitador no master: vários sons juntos não distorcem
	if AudioServer.get_bus_effect_count(0) == 0:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -0.5
		AudioServer.add_bus_effect(0, lim)
	add_child(music)
	music.play()
	print("[boot] Game pronto em %d ms" % Time.get_ticks_msec())


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		toggle_mute()
	note_device(event)


func note_device(event: InputEvent) -> void:
	var dev := ""
	if event is InputEventKey and event.pressed:
		dev = "kbd"
	elif (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		dev = "pad"
	if dev != "" and dev != last_device:
		last_device = dev
		input_device_changed.emit(dev)


## RF-241: "voltar" = Esc / Backspace / B do controle.
static func is_back(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and event.physical_keycode in [KEY_ESCAPE, KEY_BACKSPACE]
	if event is InputEventJoypadButton:
		return event.pressed and event.button_index == JOY_BUTTON_B
	return false


## RF-240: "confirmar" = ui_accept (Enter/Espaço) ou A do controle.
static func is_accept(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		return event.pressed and event.button_index == JOY_BUTTON_A
	return event.is_action_pressed("ui_accept")


## RF-242: texto de dica conforme o dispositivo.
func hint(kbd: String, pad: String) -> String:
	return pad if last_device == "pad" else kbd


func toggle_mute() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)


static func action(player: int, name: String) -> String:
	return "p%d_%s" % [player + 1, name]


static func setup_inputs() -> void:
	# RF-240: o Godot não põe botão de controle no ui_accept/ui_cancel — A confirma e B volta em toda tela
	for pair in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var has := false
		for ev in InputMap.action_get_events(pair[0]):
			if ev is InputEventJoypadButton and ev.button_index == pair[1]:
				has = true
		if not has:
			var jb := InputEventJoypadButton.new()
			jb.button_index = pair[1]
			jb.device = -1
			InputMap.action_add_event(pair[0], jb)
	# teclado: J1 = WASD, J2 = setas (location diferencia Shift/Ctrl esquerdo e direito)
	var keys := {
		0: {
			"accelerate": [[KEY_W]], "brake": [[KEY_S]], "steer_left": [[KEY_A]], "steer_right": [[KEY_D]],
			"drift": [[KEY_SPACE], [KEY_SHIFT, KEY_LOCATION_LEFT]],
			"use_item": [[KEY_E], [KEY_CTRL, KEY_LOCATION_LEFT]],
		},
		1: {
			"accelerate": [[KEY_UP]], "brake": [[KEY_DOWN]], "steer_left": [[KEY_LEFT]], "steer_right": [[KEY_RIGHT]],
			"drift": [[KEY_SHIFT, KEY_LOCATION_RIGHT], [KEY_KP_0]],
			"use_item": [[KEY_ENTER], [KEY_KP_ENTER], [KEY_CTRL, KEY_LOCATION_RIGHT]],
		},
	}
	var pad := {
		"accelerate": [[JOY_BUTTON_A], [JOY_AXIS_TRIGGER_RIGHT, 1.0]],
		"brake": [[JOY_BUTTON_B], [JOY_AXIS_TRIGGER_LEFT, 1.0]],
		"steer_left": [[JOY_AXIS_LEFT_X, -1.0], [JOY_BUTTON_DPAD_LEFT]],
		"steer_right": [[JOY_AXIS_LEFT_X, 1.0], [JOY_BUTTON_DPAD_RIGHT]],
		"drift": [[JOY_BUTTON_RIGHT_SHOULDER]],
		"use_item": [[JOY_BUTTON_LEFT_SHOULDER], [JOY_BUTTON_X]],
	}
	for p in MAX_PLAYERS:
		for a in ACTIONS:
			var act := action(p, a)
			if InputMap.has_action(act):
				continue
			InputMap.add_action(act, 0.25)
			if keys.has(p):
				for k in keys[p][a]:
					var e := InputEventKey.new()
					e.physical_keycode = k[0]
					if k.size() > 1:
						e.location = k[1]
					InputMap.action_add_event(act, e)
			for j in pad[a]:
				if j.size() == 1:
					var e := InputEventJoypadButton.new()
					e.button_index = j[0]
					e.device = p
					InputMap.action_add_event(act, e)
				else:
					var e := InputEventJoypadMotion.new()
					e.axis = j[0]
					e.axis_value = j[1]
					e.device = p
					InputMap.action_add_event(act, e)


# ---------------------------------------------------------------- tema da interface (RF-174)

const UI := "res://assets/kenney/ui/"
const FONT_PATH := "res://assets/kenney/fonts/Kenney Future Narrow.ttf"

var theme: Theme
var click: AudioStreamPlayer


static func tex_box(file: String) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load(UI + file)
	s.texture_margin_left = 18
	s.texture_margin_right = 18
	s.texture_margin_top = 16
	s.texture_margin_bottom = 22
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 8
	s.content_margin_bottom = 14
	return s


## RF-340: botão "bala" escuro com borda clara; o foco desenha um contorno amarelo com brilho por cima.
static func candy_box(bg: Color, border: Color, bottom := 5, radius := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.border_width_bottom = bottom
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 8
	s.content_margin_bottom = 10
	s.anti_aliasing = true
	return s


static func focus_ring(radius := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.border_color = Color(1.0, 0.84, 0.2)
	s.set_border_width_all(3)
	s.set_corner_radius_all(radius + 2)
	s.expand_margin_left = 3
	s.expand_margin_right = 3
	s.expand_margin_top = 3
	s.expand_margin_bottom = 3
	s.shadow_color = Color(1.0, 0.8, 0.2, 0.35)
	s.shadow_size = 10
	s.anti_aliasing = true
	return s


static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = load(FONT_PATH)
	t.default_font_size = 22
	t.set_stylebox("normal", "Button", candy_box(Color(0.17, 0.19, 0.34), Color(1, 1, 1, 0.14)))
	t.set_stylebox("hover", "Button", candy_box(Color(0.23, 0.26, 0.45), Color(1, 1, 1, 0.3)))
	t.set_stylebox("pressed", "Button", candy_box(Color(0.12, 0.13, 0.25), Color(1, 1, 1, 0.14), 2))
	t.set_stylebox("focus", "Button", focus_ring())
	t.set_stylebox("disabled", "Button", candy_box(Color(0.12, 0.13, 0.2, 0.8), Color(1, 1, 1, 0.06)))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", Color(0.95, 0.96, 1.0))
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.58, 0.7, 0.6))
	t.set_color("font_outline_color", "Button", Color(0, 0, 0, 0.55))
	t.set_constant("outline_size", "Button", 4)
	return t


## Botão de ação principal: amarelo-queijo com a base mais escura (efeito 3D).
static func make_primary(b: Button) -> void:
	b.add_theme_stylebox_override("normal", candy_box(Color(1.0, 0.78, 0.16), Color(0.85, 0.5, 0.05), 6))
	b.add_theme_stylebox_override("hover", candy_box(Color(1.0, 0.86, 0.32), Color(0.9, 0.55, 0.08), 6))
	b.add_theme_stylebox_override("pressed", candy_box(Color(0.95, 0.7, 0.1), Color(0.85, 0.5, 0.05), 2))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color(0.22, 0.13, 0.03))
	b.add_theme_constant_override("outline_size", 0)


## Desfaz o make_primary (volta pro botão escuro do tema).
static func clear_primary(b: Button) -> void:
	for s in ["normal", "hover", "pressed", "focus"]:
		b.remove_theme_stylebox_override(s)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.remove_theme_color_override(c)
	b.remove_theme_constant_override("outline_size")


func _setup_ui() -> void:
	theme = build_theme()
	get_tree().root.theme = theme
	click = AudioStreamPlayer.new()
	click.stream = load(UI + "sounds/click-a.ogg")
	click.volume_db = -6.0
	click.bus = "SFX"
	add_child(click)
	get_tree().node_added.connect(_on_node_added)
	# contador de FPS global (RF-182)
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	fps_label = Label.new()
	fps_label.position = Vector2(8, 4)
	fps_label.add_theme_font_size_override("font_size", 16)
	fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	fps_label.add_theme_constant_override("outline_size", 6)
	fps_label.visible = false
	layer.add_child(fps_label)


func _on_node_added(n: Node) -> void:
	if n is BaseButton and not n.pressed.is_connected(_play_click):
		n.pressed.connect(_play_click)


func _play_click() -> void:
	if click:
		click.play()


# ---------------------------------------------------------------- configurações: buses, salvar, aplicar

func _setup_buses() -> void:
	for b in ["Music", "SFX", "Engine"]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")


func load_settings() -> void:
	settings = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		for k in DEFAULTS:
			var v = cfg.get_value("settings", k, DEFAULTS[k])
			if typeof(v) == typeof(DEFAULTS[k]) or (typeof(DEFAULTS[k]) == TYPE_FLOAT and typeof(v) == TYPE_INT):
				settings[k] = v
	# RF-253: teclas e botões trocados
	key_binds.clear()
	pad_binds.clear()
	if cfg.has_section("keys"):
		for act in cfg.get_section_keys("keys"):
			var v = cfg.get_value("keys", act)
			if v is Array:
				key_binds[act] = v
	if cfg.has_section("pad"):
		for a in cfg.get_section_keys("pad"):
			var v = cfg.get_value("pad", a)
			if v is Array and PAD_REMAP.has(a):
				pad_binds[a] = v
	rebuild_inputs()
	apply_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings:
		cfg.set_value("settings", k, settings[k])
	for act in key_binds:
		cfg.set_value("keys", act, key_binds[act])
	for a in pad_binds:
		cfg.set_value("pad", a, pad_binds[a])
	cfg.save(settings_path)


func reset_settings() -> void:
	settings = DEFAULTS.duplicate()
	key_binds.clear()  # RF-253: PADRÃO também restaura os controles
	pad_binds.clear()
	rebuild_inputs()
	apply_settings()
	save_settings()


func set_setting(key: String, value) -> void:
	settings[key] = value
	apply_settings()
	save_settings()


static func vol_db(v: float) -> float:
	return -80.0 if v <= 0.001 else linear_to_db(v)


## Aplica o que é global (áudio, janela, FPS, resolução, zona morta). O que é da corrida
## (bloom, MSAA, nomes, minimapa...) é aplicado por race.apply_settings().
func apply_settings() -> void:
	var s := settings
	for pair in [["Master", "vol_master"], ["Music", "vol_music"], ["SFX", "vol_sfx"], ["Engine", "vol_engine"]]:
		var i := AudioServer.get_bus_index(pair[0])
		if i >= 0:
			AudioServer.set_bus_volume_db(i, vol_db(float(s[pair[1]])))
	AudioServer.set_bus_mute(0, muted)
	if DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if s["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want:
			DisplayServer.window_set_mode(want)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if s["vsync"] else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(s["max_fps"])
	get_tree().root.scaling_3d_scale = float(s["render_scale"])
	for p in MAX_PLAYERS:
		for a in ACTIONS:
			var act := action(p, a)
			if InputMap.has_action(act):
				InputMap.action_set_deadzone(act, float(s["deadzone"]))
	if fps_label:
		fps_label.visible = s["show_fps"]
	var race := get_tree().current_scene
	if race and race.has_method("apply_settings"):
		race.apply_settings()


func _process(_delta: float) -> void:
	if loading and loading.visible and loading_spin:
		loading_spin.rotation += _delta * 7.0
	if fps_label and fps_label.visible:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()


# ---------------------------------------------------------------- Grand Prix (RF-190..195)

const GP_POINTS := [15, 12, 10, 8, 6, 4, 2, 1]
## RF-305: copas do Grand Prix (a Copa Farofa junta as pistas novas com uma das antigas)
const CUPS := [
	{"id": "queijo", "name": "Copa Queijo", "tracks": ["queijo", "deserto", "cozinha"]},
	{"id": "farofa", "name": "Copa Farofa", "tracks": ["churrasco", "parquinho", "deserto", "fabrica"]},
]
const CharsData = preload("res://scripts/characters.gd")

var mode := "race"          # "race" | "gp" | "tt" (contra o relógio, RF-230)
var gp_cup := 0             # índice em CUPS
var gp_index := 0           # corrida atual (0..2)
var gp_points := {}         # id -> pontos
var gp_wins := {}           # id -> vitórias
var gp_last_pos := {}       # id -> posição na última corrida
var gp_awarded_race := -1   # índice da última corrida já pontuada (evita pontuar 2x)


func start_gp() -> void:
	mode = "gp"
	gp_index = 0
	gp_awarded_race = -1
	gp_points.clear()
	gp_wins.clear()
	gp_last_pos.clear()
	for c in CharsData.LIST:
		gp_points[c["id"]] = 0
		gp_wins[c["id"]] = 0
		gp_last_pos[c["id"]] = 8
	track_id = gp_tracks()[0]


func gp_tracks() -> Array:
	return CUPS[clampi(gp_cup, 0, CUPS.size() - 1)]["tracks"]


func gp_cup_name() -> String:
	return CUPS[clampi(gp_cup, 0, CUPS.size() - 1)]["name"]


func is_gp() -> bool:
	return mode == "gp"


func is_tt() -> bool:
	return mode == "tt"


## Pontua a corrida atual a partir da ordem final (ids, 1º primeiro). Devolve id -> pontos
## ganhos; numa segunda chamada pra mesma corrida não pontua de novo e devolve {}.
func gp_award(order_ids: Array) -> Dictionary:
	if gp_awarded_race == gp_index:
		return {}
	gp_awarded_race = gp_index
	var got := {}
	for i in order_ids.size():
		var id: String = order_ids[i]
		var pts: int = GP_POINTS[i] if i < GP_POINTS.size() else 0
		gp_points[id] = int(gp_points.get(id, 0)) + pts
		gp_last_pos[id] = i + 1
		if i == 0:
			gp_wins[id] = int(gp_wins.get(id, 0)) + 1
		got[id] = pts
	return got


## Classificação: pontos → vitórias → melhor posição na última corrida.
func gp_standings() -> Array:
	var ids: Array = gp_points.keys()
	ids.sort_custom(func(a, b):
		if gp_points[a] != gp_points[b]:
			return gp_points[a] > gp_points[b]
		if gp_wins[a] != gp_wins[b]:
			return gp_wins[a] > gp_wins[b]
		return gp_last_pos[a] < gp_last_pos[b])
	return ids


func gp_is_last() -> bool:
	return gp_index >= gp_tracks().size() - 1


func gp_is_over() -> bool:
	return gp_is_last() and gp_awarded_race == gp_index


## Vai pra próxima pista. Devolve false se o GP já acabou.
func gp_next() -> bool:
	if gp_is_last():
		return false
	gp_index += 1
	track_id = gp_tracks()[gp_index]
	return true


## RF-221: troca a trilha (sem reiniciar se o estilo já está tocando).
func play_music(style: String) -> void:
	if music == null:
		return
	if current_music == style and music.playing:
		return
	current_music = style
	music.stream = Sfx.music(style)
	music.pitch_scale = 1.0
	music.play()


# ---------------------------------------------------------------- trocar teclas (RF-250..254)

const PAD_REMAP := ["accelerate", "brake", "drift", "use_item"]
const RESERVED_KEYS := [KEY_ESCAPE, KEY_M, KEY_R]
const ACTION_NAMES := {
	"accelerate": "Acelerar", "brake": "Frear / ré", "steer_left": "Virar à esquerda",
	"steer_right": "Virar à direita", "drift": "Drift (no ar: manobra)", "use_item": "Usar item",
}
const KEY_NAMES := {
	KEY_SPACE: "Espaço", KEY_UP: "↑", KEY_DOWN: "↓", KEY_LEFT: "←", KEY_RIGHT: "→",
	KEY_ENTER: "Enter", KEY_KP_ENTER: "Enter num.", KEY_KP_0: "Num 0", KEY_SHIFT: "Shift",
	KEY_CTRL: "Ctrl", KEY_ALT: "Alt", KEY_TAB: "Tab", KEY_BACKSPACE: "Backspace",
}
const PAD_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_DPAD_UP: "Direcional ↑",
	JOY_BUTTON_DPAD_DOWN: "Direcional ↓", JOY_BUTTON_DPAD_LEFT: "Direcional ←", JOY_BUTTON_DPAD_RIGHT: "Direcional →",
}

var key_binds := {}  # "p1_drift" -> [[physical_keycode, location], ...] (só as ações mexidas)
var pad_binds := {}  # "drift" -> [button_index, ...] (vale pros 4 controles)


## Recria o mapa a partir do padrão e aplica as trocas por cima.
func rebuild_inputs() -> void:
	for p in MAX_PLAYERS:
		for a in ACTIONS:
			if InputMap.has_action(action(p, a)):
				InputMap.erase_action(action(p, a))
	setup_inputs()
	for act in key_binds:
		if not InputMap.has_action(act):
			continue
		for ev in InputMap.action_get_events(act):
			if ev is InputEventKey:
				InputMap.action_erase_event(act, ev)
		for k in key_binds[act]:
			var e := InputEventKey.new()
			e.physical_keycode = int(k[0]) as Key
			e.location = int(k[1]) as KeyLocation
			InputMap.action_add_event(act, e)
	for a in pad_binds:
		for p in MAX_PLAYERS:
			var act := action(p, a)
			for ev in InputMap.action_get_events(act):
				if ev is InputEventJoypadButton:
					InputMap.action_erase_event(act, ev)
			for b in pad_binds[a]:
				var e := InputEventJoypadButton.new()
				e.button_index = int(b) as JoyButton
				e.device = p
				InputMap.action_add_event(act, e)
	for p in MAX_PLAYERS:
		for a in ACTIONS:
			InputMap.action_set_deadzone(action(p, a), float(settings.get("deadzone", 0.25)))
	input_device_changed.emit(last_device)  # dicas da tela se atualizam (RF-254)


static func _key_of(ev: InputEventKey) -> Array:
	return [int(ev.physical_keycode), int(ev.location)]


static func _same_key(a: Array, b: Array) -> bool:
	return a[0] == b[0] and (a[1] == 0 or b[1] == 0 or a[1] == b[1])


func keys_of(player: int, a: String) -> Array:
	var out := []
	for ev in InputMap.action_get_events(action(player, a)):
		if ev is InputEventKey:
			out.append(_key_of(ev))
	return out


func pad_buttons_of(a: String) -> Array:
	var out := []
	for ev in InputMap.action_get_events(action(0, a)):
		if ev is InputEventJoypadButton:
			out.append(int(ev.button_index))
	return out


## RF-251/252: troca a tecla de (player, ação). Devolve {"ok", "msg"}.
## Se a tecla era a única de outra ação, as duas trocam; se era uma alternativa, só sai de lá.
func rebind_key(player: int, a: String, ev: InputEventKey) -> Dictionary:
	var k := _key_of(ev)
	if k[0] in RESERVED_KEYS or k[0] == KEY_NONE:
		return {"ok": false, "msg": "%s é reservada (pausar/som/reiniciar)." % key_name(k)}
	var old: Array = keys_of(player, a)
	var msg := ""
	for q in 2:
		for b in ACTIONS:
			if q == player and b == a:
				continue
			var cur: Array = keys_of(q, b)
			var rest := cur.filter(func(o): return not _same_key(o, k))
			if rest.size() == cur.size():
				continue
			if rest.is_empty() and not old.is_empty():
				rest = [old[0]]
				msg = "Trocou com J%d · %s (agora %s)." % [q + 1, ACTION_NAMES[b], key_name(old[0])]
			key_binds[action(q, b)] = rest
	key_binds[action(player, a)] = [k]
	rebuild_inputs()
	save_settings()
	return {"ok": true, "msg": msg}


## RF-251/252: troca o botão do controle de uma ação (vale pros 4 controles).
func rebind_pad(a: String, button: int) -> Dictionary:
	if not PAD_REMAP.has(a):
		return {"ok": false, "msg": "Essa ação usa o analógico/direcional."}
	if button == JOY_BUTTON_START:
		return {"ok": false, "msg": "Start é reservado (pausar)."}
	var old: Array = pad_buttons_of(a)
	var msg := ""
	for b in PAD_REMAP:
		var cur: Array = pad_buttons_of(b)
		if b == a or not cur.has(button):
			continue
		var rest := cur.filter(func(x): return x != button)
		if rest.is_empty() and not old.is_empty():
			rest = [old[0]]
			msg = "Trocou com %s (agora %s)." % [ACTION_NAMES[b], pad_name(old[0])]
		pad_binds[b] = rest
	pad_binds[a] = [button]
	rebuild_inputs()
	save_settings()
	return {"ok": true, "msg": msg}

func reset_bindings() -> void:
	key_binds.clear()
	pad_binds.clear()
	rebuild_inputs()
	save_settings()


static func key_name(k: Array) -> String:
	if int(k[0]) == KEY_NONE:
		return "—"
	var s: String = KEY_NAMES.get(int(k[0]), OS.get_keycode_string(int(k[0])))
	if int(k[1]) == KEY_LOCATION_LEFT:
		s += " esq."
	elif int(k[1]) == KEY_LOCATION_RIGHT:
		s += " dir."
	return s


static func pad_name(button: int) -> String:
	return PAD_NAMES.get(button, "Botão %d" % button) if button >= 0 else "—"


## Texto das teclas de uma ação (ex.: "Espaço / Shift esq.").
func key_label(player: int, a: String) -> String:
	var names := []
	for k in keys_of(player, a):
		names.append(key_name(k))
	return " / ".join(names) if not names.is_empty() else "—"


## Texto do controle de uma ação, incluindo gatilhos (ex.: "A / RT").
func pad_label(a: String) -> String:
	var names := []
	var triggers := []
	for ev in InputMap.action_get_events(action(0, a)):
		if ev is InputEventJoypadButton:
			names.append(pad_name(int(ev.button_index)))
		elif ev is InputEventJoypadMotion and a in ["accelerate", "brake"]:
			triggers.append("RT" if ev.axis == JOY_AXIS_TRIGGER_RIGHT else "LT")
	names.append_array(triggers)  # botões primeiro: "A / RT"
	if a in ["steer_left", "steer_right"]:
		return "Analógico / direcional"
	return " / ".join(names) if not names.is_empty() else "—"


## RF-254: dicas da corrida com as teclas atuais.
func race_hint_kbd() -> String:
	var steer := "%s %s" % [key_label(0, "steer_left"), key_label(0, "steer_right")]
	return "%s %s %s: pilotar · %s: drift · %s: item · Esc: pausar · M: som" % [key_label(0, "accelerate"), key_label(0, "brake"), steer, key_label(0, "drift").split(" / ")[0], key_label(0, "use_item").split(" / ")[0]]


func race_hint_pad() -> String:
	return "Analógico: pilotar · %s: acelerar · %s: frear · %s: drift · %s: item · Start: pausar" % [pad_label("accelerate"), pad_label("brake"), pad_label("drift"), pad_label("use_item")]


func move_keys(player: int) -> String:
	var ks := []
	for a in ["accelerate", "steer_left", "brake", "steer_right"]:
		ks.append(key_label(player, a).split(" / ")[0])
	var short := ks.all(func(s): return s.length() == 1)
	return "".join(ks) if short else " ".join(ks)


# ---------------------------------------------------------------- tela de carregamento (RF-350)

const TrackData = preload("res://scripts/track.gd")
var loading: CanvasLayer
var loading_root: Control
var loading_spin: Control
var loading_name: Label
var loading_tw: Tween


func _build_loading() -> void:
	loading = CanvasLayer.new()
	loading.layer = 100
	add_child(loading)
	loading_root = Control.new()
	loading_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading_root.mouse_filter = Control.MOUSE_FILTER_STOP
	loading.add_child(loading_root)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading_root.add_child(bg)
	if ResourceLoader.exists("res://assets/ui/intro.jpg"):
		var art := TextureRect.new()
		art.texture = load("res://assets/ui/intro.jpg")
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var sm := ShaderMaterial.new()
		sm.shader = load("res://shaders/menu_bg.gdshader")
		art.material = sm
		loading_root.add_child(art)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading_root.add_child(center)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	center.add_child(vb)
	loading_spin = Control.new()
	loading_spin.custom_minimum_size = Vector2(80, 80)
	loading_spin.pivot_offset = Vector2(40, 40)
	loading_spin.draw.connect(func():
		var c := Vector2(40, 40)
		loading_spin.draw_arc(c, 30, 0.0, TAU, 48, Color(1, 1, 1, 0.12), 8.0, true)
		loading_spin.draw_arc(c, 30, 0.0, TAU * 0.3, 24, Color(1.0, 0.82, 0.2), 8.0, true)
		loading_spin.draw_circle(c + Vector2(30, 0).rotated(TAU * 0.3), 6.0, Color(1.0, 0.92, 0.5)))
	var spin_box := CenterContainer.new()
	spin_box.add_child(loading_spin)
	vb.add_child(spin_box)
	var title := Label.new()
	title.text = "CARREGANDO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.15))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 10)
	vb.add_child(title)
	loading_name = Label.new()
	loading_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_name.add_theme_font_size_override("font_size", 26)
	loading_name.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0))
	loading_name.add_theme_color_override("font_outline_color", Color.BLACK)
	loading_name.add_theme_constant_override("outline_size", 8)
	vb.add_child(loading_name)
	loading.visible = false


func show_loading(sub := "") -> void:
	if loading == null:
		_build_loading()
	if loading_tw:
		loading_tw.kill()
	loading_name.text = sub
	loading_root.modulate.a = 1.0
	loading.visible = true


func hide_loading() -> void:
	if loading == null or not loading.visible:
		return
	if loading_tw:
		loading_tw.kill()
	loading_tw = create_tween()
	loading_tw.tween_property(loading_root, "modulate:a", 0.0, 0.3)
	loading_tw.tween_callback(func(): loading.visible = false)


func is_loading() -> bool:
	return loading != null and loading.visible


## Texto da tela de carregamento: nome da pista (e a corrida do GP).
func loading_text() -> String:
	var name: String = TrackData.find(track_id)["name"]
	if is_gp():
		return "%s · corrida %d/%d\n%s" % [gp_cup_name(), gp_index + 1, gp_tracks().size(), name]
	return name


## RF-350: mostra "Carregando" e só depois troca pra corrida (a pista monta com a tela de pé).
## A corrida chama hide_loading() quando o primeiro quadro dela estiver pronto.
func go_race(reload := false) -> void:
	show_loading(loading_text())
	await get_tree().process_frame
	await get_tree().process_frame
	if reload:
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file("res://scenes/race.tscn")
