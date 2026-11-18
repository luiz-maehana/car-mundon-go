extends Node
## Autoload "Game": escolhas do menu e mapa de controles por jogador (SPEC §5).
## Ações: "p<N>_<acao>", N = 1..4. Controle (joypad) do jogador N = device N-1.

const MAX_PLAYERS := 4
const ACTIONS := ["accelerate", "brake", "steer_left", "steer_right", "drift", "use_item"]

var num_players := 1
var selected_chars: Array = ["fejaum"]
var laps := 3


func _ready() -> void:
	setup_inputs()


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
