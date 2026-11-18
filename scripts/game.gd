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
var graphics_high := true  # RF-161
var music: AudioStreamPlayer


func _ready() -> void:
	setup_inputs()
	_setup_ui()
	# RF-82: música contínua entre menu e corrida
	music = AudioStreamPlayer.new()
	music.stream = Sfx.get_sound("music")
	music.volume_db = -3.0
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
	add_child(click)
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is BaseButton and not n.pressed.is_connected(_play_click):
		n.pressed.connect(_play_click)


func _play_click() -> void:
	if click:
		click.play()
