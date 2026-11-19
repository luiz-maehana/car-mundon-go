extends Control
## Menu — estado e peças visuais comuns (rótulos, botões, cartões, gradientes, sons).
## (camada de menu.gd — ver o topo de menu.gd)

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
	"Escolha uma copa e corra as pistas dela em sequência. Pontos por posição; quem somar mais leva a taça.",
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
	"parquinho": "Pista em 8 na praça: cruzamento no meio, escorregador gigante, caixa de areia e gangorras.",
	"geladeira": "Dentro da geladeira: 3 andares, looping na prateleira, viaduto, gelo no congelador e túnel de caixa de leite.",
	"telhados": "De noite, nos telhados da vila: pule os vãos entre os prédios, passe por baixo dos varais e cuidado com o gatão.",
	"feira": "Rua de feira de manhã: afunila entre as barracas, abre numa praça com atalho por baixo dos toldos e chicane estreita.",
}

var step := STEP_MODE
var mode_i := 0
var num_players := 1
var selected := 0
var picks: Array = []
var track_i := 0
var cup_i := 0             # RF-305: copa escolhida no Grand Prix
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
var crumb_chips: Array = []     # chip (PanelContainer) de cada etapa
const BG_ART := "res://assets/ui/intro.jpg"
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
var preview_power: Label
var preview_power_desc: Label
var power_howto: Label
var shown := -1
var track_btns: Array = []
var track_minis: Array = []    # RF-400: trajeto em miniatura de cada cartão
var track_names: Array = []    # nome no cartão (no GP vira o nome da copa)
const GRID_COLS := 3
const TRACK_CARD := Vector2(200, 150)
var track_map: Control
var track_title: Label
var track_info: Label
var track_desc: Label
var laps_btn: Button
var diff_btn: Button
var go_btn: Button
var sum_mode: Label
var sum_pilots_cap: Label
var sum_pilots: HBoxContainer
var sum_track: Label
var sum_map: Control
var t := 0.0


func _caption(text: String) -> Label:
	var l := _label(text, 14, Color(1.0, 0.82, 0.25))
	l.add_theme_constant_override("outline_size", 0)
	return l


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _card_style(border: Color) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.06, 0.15, 0.86)
	st.border_color = border
	st.set_border_width_all(2)
	st.set_corner_radius_all(20)
	st.set_content_margin_all(22)
	st.shadow_color = Color(0, 0, 0, 0.4)
	st.shadow_size = 12
	return st


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
			var col := Color(1.0, 0.84, 0.25, 0.25 if b.disabled else 0.95)
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


func _cups() -> Array:
	return GameScript.CUPS


func _cup() -> Array:
	return _cups()[cup_i]["tracks"]


## Template Method: as etapas pedem a troca; quem implementa é o menu.gd (navegação).
func _go_step(_s: int, _animate := true) -> void:
	pass
