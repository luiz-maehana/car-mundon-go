extends Node
## Autoload "Game": escolhas do menu e mapa de controles por jogador (SPEC §5).
## Ações: "p<N>_<acao>", N = 1..4. Controle (joypad) do jogador N = device N-1.

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
	_setup_ui()
	_setup_buses()
	load_settings()
	# RF-82: música contínua entre menu e corrida
	music = AudioStreamPlayer.new()
	music.stream = Sfx.get_sound("music")
	music.volume_db = -3.0
	music.bus = "Music"
	# limitador no master: vários sons juntos não distorcem
	if AudioServer.get_bus_effect_count(0) == 0:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -0.5
		AudioServer.add_bus_effect(0, lim)
	add_child(music)
	music.play()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		toggle_mute()


func toggle_mute() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)


static func action(player: int, name: String) -> String:
	return "p%d_%s" % [player + 1, name]


static func setup_inputs() -> void:
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


static func build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = load(FONT_PATH)
	t.default_font_size = 22
	t.set_stylebox("normal", "Button", tex_box("button_grey.png"))
	t.set_stylebox("hover", "Button", tex_box("button_grey_hover.png"))
	t.set_stylebox("pressed", "Button", tex_box("button_grey_pressed.png"))
	t.set_stylebox("focus", "Button", tex_box("button_yellow_hover.png"))
	t.set_stylebox("disabled", "Button", tex_box("button_grey_pressed.png"))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", Color(0.16, 0.17, 0.22))
	return t


## Botão de ação principal (amarelo do UI Pack).
static func make_primary(b: Button) -> void:
	b.add_theme_stylebox_override("normal", tex_box("button_yellow.png"))
	b.add_theme_stylebox_override("hover", tex_box("button_yellow_hover.png"))
	b.add_theme_stylebox_override("pressed", tex_box("button_yellow_pressed.png"))
	b.add_theme_stylebox_override("focus", tex_box("button_yellow_hover.png"))


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
	apply_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings:
		cfg.set_value("settings", k, settings[k])
	cfg.save(settings_path)


func reset_settings() -> void:
	settings = DEFAULTS.duplicate()
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
	if fps_label and fps_label.visible:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
