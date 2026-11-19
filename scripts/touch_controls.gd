extends CanvasLayer
## RF-470/471: controles na tela pro celular (e qualquer tela de toque), estilo jogo mobile.
##   esquerda: direcional analógico (arrasta pros lados = vira, com força proporcional)
##   direita:  DRIFT (segurar) · ITEM · PODER · FREIO   (acelerador automático, dá pra desligar)
##   em cima:  pausa
## Vários dedos ao mesmo tempo (cada toque guarda o seu botão). Aperta as MESMAS ações do
## teclado/controle (p1_*), então a física e a IA não sabem a diferença.

const Ids = preload("res://scripts/ids.gd")
const STICK_RANGE := 90.0       # px (na escala 720p) do centro até virar tudo
const AUTO_GAS_AT := 1.2        # contagem: o acelerador automático entra aqui (largada turbo)

var race: Node
var root: Control
var buttons: Array = []         # {id, action, label, pos (fração da tela), r, color}
var touches := {}               # índice do toque -> id do botão (ou "stick")
var stick_origin := Vector2.ZERO
var stick_now := Vector2.ZERO
var stick_index := -1
var steer := 0.0
var held := {}                  # id -> true


func setup(r: Node) -> void:
	race = r
	layer = 20
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.draw.connect(_draw_controls)
	add_child(root)
	var game := get_node_or_null("/root/Game")
	var auto_gas: bool = game == null or bool(game.settings.get("touch_auto_gas", true))
	buttons = [
		{"id": "drift", "action": "p1_drift", "label": "DRIFT", "pos": Vector2(0.9, 0.8), "r": 78.0, "color": Color(1.0, 0.82, 0.2)},
		{"id": "item", "action": "p1_use_item", "label": "ITEM", "pos": Vector2(0.765, 0.86), "r": 56.0, "color": Color(0.35, 0.8, 1.0)},
		{"id": "power", "action": "p1_power", "label": "PODER", "pos": Vector2(0.9, 0.54), "r": 50.0, "color": Color(0.45, 1.0, 0.55)},
		{"id": "brake", "action": "p1_brake", "label": "FREIO", "pos": Vector2(0.77, 0.63), "r": 44.0, "color": Color(1.0, 0.45, 0.4)},
		{"id": "pause", "action": "", "label": "II", "pos": Vector2(0.04, 0.5), "r": 30.0, "color": Color(1, 1, 1)},
	]
	if not auto_gas:
		buttons.append({"id": "gas", "action": "p1_accelerate", "label": "ACELERA", "pos": Vector2(0.64, 0.84), "r": 56.0, "color": Color(0.5, 1.0, 0.4)})
	set_meta("auto_gas", auto_gas)


func _scale() -> float:
	var s := root.size
	return minf(s.x, s.y) / 720.0


func _center(b: Dictionary) -> Vector2:
	return root.size * (b["pos"] as Vector2)


func _stick_home() -> Vector2:
	return Vector2(root.size.x * 0.13, root.size.y * 0.78)


func _hit(p: Vector2) -> String:
	var sc := _scale()
	for b in buttons:
		if p.distance_to(_center(b)) < float(b["r"]) * sc * 1.15:
			return b["id"]
	if p.x < root.size.x * 0.45 and p.y > root.size.y * 0.35:
		return "stick"   # metade esquerda de baixo inteira: o direcional nasce onde o dedo encosta
	return ""


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var id := _hit(event.position)
			if id == "":
				return
			touches[event.index] = id
			if id == "stick":
				stick_index = event.index
				stick_origin = event.position
				stick_now = event.position
			else:
				_press(id)
			get_viewport().set_input_as_handled()
		elif touches.has(event.index):
			var id: String = touches[event.index]
			touches.erase(event.index)
			if id == "stick":
				stick_index = -1
				_set_steer(0.0)
			else:
				_release(id)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == stick_index:
		stick_now = event.position
		_set_steer(clampf((stick_now.x - stick_origin.x) / (STICK_RANGE * _scale()), -1.0, 1.0))
		get_viewport().set_input_as_handled()


func _press(id: String) -> void:
	held[id] = true
	if id == "pause":
		if race and race.has_method("toggle_pause"):
			race.toggle_pause()
		return
	for b in buttons:
		if b["id"] == id and b["action"] != "":
			Input.action_press(b["action"])


func _release(id: String) -> void:
	held.erase(id)
	for b in buttons:
		if b["id"] == id and b["action"] != "":
			Input.action_release(b["action"])


func _set_steer(v: float) -> void:
	steer = v
	if v < -0.08:
		Input.action_release("p1_steer_right")
		Input.action_press("p1_steer_left", -v)
	elif v > 0.08:
		Input.action_release("p1_steer_left")
		Input.action_press("p1_steer_right", v)
	else:
		Input.action_release("p1_steer_left")
		Input.action_release("p1_steer_right")


func release_all() -> void:
	for id in held.keys():
		_release(id)
	touches.clear()
	stick_index = -1
	_set_steer(0.0)
	Input.action_release("p1_accelerate")


func _process(_delta: float) -> void:
	if race == null:
		return
	var show: bool = not race.paused and not race.results_shown
	if show != visible:
		visible = show
		if not show:
			release_all()
	# acelerador automático: entra no fim da contagem (dá largada turbo) e solta no freio
	if visible and bool(get_meta("auto_gas", true)):
		var go: bool = (race.state != "countdown" or race.countdown <= AUTO_GAS_AT) and not held.has("brake")
		if go:
			Input.action_press("p1_accelerate")
		else:
			Input.action_release("p1_accelerate")
	root.queue_redraw()


func _exit_tree() -> void:
	release_all()


func _draw_controls() -> void:
	var sc := _scale()
	var font := root.get_theme_default_font()
	# direcional: base + bolinha que segue o dedo
	var home := stick_origin if stick_index >= 0 else _stick_home()
	var rad := STICK_RANGE * sc
	root.draw_circle(home, rad * 1.15, Color(0, 0, 0, 0.28))
	root.draw_arc(home, rad * 1.15, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0 * sc, true)
	for s in [-1.0, 1.0]:  # setinhas
		var tip := home + Vector2(s * rad * 0.85, 0)
		root.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-s * 18, -14) * sc, tip + Vector2(-s * 18, 14) * sc]), Color(1, 1, 1, 0.45))
	var knob := home + Vector2(steer * rad, 0)
	root.draw_circle(knob, 34.0 * sc, Color(1, 1, 1, 0.55 if stick_index >= 0 else 0.3))
	# botões
	var p = race.player if race else null
	for b in buttons:
		var c: Vector2 = _center(b)
		var r: float = float(b["r"]) * sc
		var col: Color = b["color"]
		var on := held.has(b["id"])
		var alpha := 0.55 if on else 0.32
		if b["id"] == "power" and p and p.has_method("power_state"):
			var st: String = p.power_state()
			if st == "ready":
				alpha = 0.45 + 0.3 * (0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01))  # pronto: pisca
			elif st == "charge" or st == "cooldown":
				col = col.darkened(0.55)
		if b["id"] == "item" and p and p.item == "":
			col = col.darkened(0.5)
		root.draw_circle(c, r, Color(col.r, col.g, col.b, alpha))
		root.draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.55), 3.0 * sc, true)
		if font:
			var fs := int(maxf(12.0, r * 0.34))
			var w := font.get_string_size(b["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			root.draw_string(font, c + Vector2(-w * 0.5, fs * 0.35), b["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.95))
