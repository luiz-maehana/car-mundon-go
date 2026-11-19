extends Node3D
## Corrida — estado (todas as variáveis) e consultas: som, tremida, voltas, classificação, elástico da IA.
## (camada de race.gd — ver o topo de race.gd)

## Orquestra a corrida: grid, contagem, itens, colisões, ranking, chegada e câmera.
## Toda a lógica roda em step(delta) — os testes chamam step() direto (RNF-02).

const TrackScript = preload("res://scripts/track.gd")
const KartScript = preload("res://scripts/kart.gd")
const HudScript = preload("res://scripts/hud.gd")
const Chars = preload("res://scripts/characters.gd")
const Ids = preload("res://scripts/ids.gd")
const HazardRegistry = preload("res://scripts/hazards/registry.gd")
const PowerRegistry = preload("res://scripts/powers/registry.gd")
const Sfx = preload("res://scripts/sfx.gd")
const Gfx = preload("res://scripts/gfx.gd")
const GameScript = preload("res://scripts/game.gd")
const HazardModels = preload("res://scripts/hazard_models.gd")
const Records = preload("res://scripts/records.gd")
const CHEESE_MODEL := "res://assets/kenney/food/cheese.glb"
const BANANA_MODEL := "res://assets/kenney/food/banana.glb"


const COUNTDOWN := 3.0
const BOX_RESPAWN := 3.0
const RESULTS_DELAY := 3.0
const SLIP_TIME := 1.2
const CHEESE_RESPAWN := 8.0
## RF-151: skill = faixa de habilidade da IA; rubber = limites do rubber band.
const DIFFICULTY := [
	{"name": "FÁCIL", "skill": [0.84, 0.9], "rubber": [0.92, 1.04]},
	{"name": "NORMAL", "skill": [0.9, 0.97], "rubber": [0.94, 1.08]},
	{"name": "DIFÍCIL", "skill": [0.97, 1.02], "rubber": [0.96, 1.12]},
]

var use_game_settings := true
var audio_enabled := true
var engines_enabled := true
var autopilot_player := false
var player_chars: Array = ["fejaum"]  # um por jogador humano (1..4)
var laps := 3
var track_id := "queijo"
var difficulty := 1
var time_trial := false  # RF-230..234: contra o relógio

var track: Node3D
var karts: Array = []
var players: Array = []   # karts humanos, na ordem J1..J4
var player: Node3D        # = players[0]
var cameras: Array = []
var huds: Array = []
var results_hud: CanvasLayer
var state := "countdown"  # countdown | racing | finished
var countdown := COUNTDOWN
var race_time := 0.0
var end_timer := 0.0
var results_shown := false
var boxes: Array = []    # {node, pos, cd}
var hazards: Array = []  # {node, type, pos, vel, life, owner, age, idx}
var boxes_picked := 0
var cheeses: Array = []  # {node, pos, cd}
var rng := RandomNumberGenerator.new()
var paused := false
var pause_layer: CanvasLayer
var pause_resume_btn: Button
var sfx_players: Array = []
var sfx_next := 0
var sfx_log: Array = []   # nomes tocados (usado pelos testes)
var engines: Array = []   # {kart, player, base_db} — um loop de motor por humano

var last_beep := 4
var human_laps: Array = []
var world_env: WorldEnvironment
var sun_light: DirectionalLight3D
var subviewports: Array = []
var base_fov := 72.0
var shakes: Array = []    # tremida por câmera (RF-166)
var settings_overlay: Control
const SettingsMenu = preload("res://scripts/settings_menu.gd")


func sfx(sound_name: String) -> void:
	sfx_log.append(sound_name)
	if sfx_players.is_empty():
		return
	var ap: AudioStreamPlayer = sfx_players[sfx_next]
	sfx_next = (sfx_next + 1) % sfx_players.size()
	ap.stream = Sfx.get_sound(sound_name)
	ap.play()


# ---------------------------------------------------------------- confirmação de abandonar o GP (RF-243)

var confirm_box: Control
var confirm_no_btn: Button
var confirm_yes_btn: Button


func _leave() -> void:
	var game := get_node_or_null("/root/Game")
	if game and game.music:
		game.music.stream_paused = false
		game.music.pitch_scale = 1.0


func lap_of(k: Node3D) -> int:
	var n: int = track.sample_count()
	return clampi(floori(k.progress / n) + 1, 1, laps)


func all_finished() -> bool:
	for k in karts:
		if not k.finished:
			return false
	return true


func humans_finished() -> bool:
	for p in players:
		if not p.finished:
			return false
	return true


## RF-43/66: referência = humano mais adiantado que ainda corre.
func _update_rubber() -> void:
	var ref := -INF
	for p in players:
		if not p.finished:
			ref = maxf(ref, p.rank_value())
	for k in karts:
		if k.is_player or ref == -INF or autopilot_player:
			k.rubber = 1.0
			continue
		var gap: float = k.rank_value() - ref
		var rb: Array = DIFFICULTY[difficulty]["rubber"]
		k.rubber = clampf(1.0 - gap * 0.0006, rb[0], rb[1])


## RF-200: sorteio ponderado pela posição. O GATO só sai de 5º pra trás e só um por vez.
const ITEM_TABLE := {
	"front": [["casca", 35], ["ratoeira", 20], ["escudo", 25], ["bomba", 15], ["turbo", 5]],
	"mid": [["casca", 15], ["ratoeira", 15], ["escudo", 15], ["bomba", 25], ["turbo", 20], ["triplo", 10]],
	"back": [["bomba", 20], ["turbo", 20], ["triplo", 30], ["escudo", 10], ["casca", 5], ["gato", 15]],
}
const ITEM_SFX := {"turbo": "boost", "triplo": "boost", "casca": "drop", "ratoeira": "drop", "bomba": "shoot", "gato": "meow", "escudo": "shield"}
const GATO_SPEED := 50.0
const GATO_LIFE := 15.0


## Perigos que ficam no chão (alvo de bombas e da IA que desvia).
const GROUND_HAZARDS := ["casca", "ratoeira"]


func _update_ranks() -> void:
	var sorted := karts.duplicate()
	sorted.sort_custom(func(a, b):
		if a.finished and b.finished:
			return a.finish_time < b.finish_time
		if a.finished != b.finished:
			return a.finished
		return a.rank_value() > b.rank_value())
	for i in sorted.size():
		sorted[i].rank = i + 1


func ranking() -> Array:
	var sorted := karts.duplicate()
	sorted.sort_custom(func(a, b): return a.rank < b.rank)
	return sorted


var cam_ups: Array = []  # por câmera


## RF-166: tremida da câmera do jogador dono do kart.
func shake(k: Node3D, amount: float) -> void:
	if not k.is_player:
		return
	var i: int = k.player_index
	while shakes.size() <= i:
		shakes.append(0.0)
	shakes[i] = maxf(shakes[i], amount * float(Gfx.setting("shake", 1.0)))  # RF-183


# ---------------------------------------------------------------- Grand Prix (RF-190..195)

var gp_gained := {}   # id -> pontos ganhos nesta corrida


func is_gp() -> bool:
	var game := get_node_or_null("/root/Game")
	return game != null and game.is_gp()


# ---------------------------------------------------------------- contra o relógio (RF-230..234)

var tt_record := {}                  # recorde da pista antes desta corrida
var tt_laps: Array = []              # tempo de cada volta do jogador
var tt_lap_start := 0.0
var tt_last_lap := 1
var tt_ghost_rec := PackedFloat32Array()  # gravação desta corrida (x, y, z, heading)
var tt_prev := {}                    # amostra do quadro anterior (pra gravar no instante exato)
var tt_ghost_data := PackedFloat32Array()  # fantasma do recorde (reprodução)
var tt_ghost: Node3D
var tt_result := {}                  # {"race": bool, "lap": bool} depois do submit
var tt_submitted := false


# ---------------------------------------------------------------- perigos da pista (RF-271/272, RF-450)
# Cada tipo mora em scripts/hazards/<tipo>.gd (registro em scripts/hazards/registry.gd).

var track_hazards: Array = []  # {spec, state, ...o que o script do tipo guardar}
var hazard_clock := 0.0        # anda sempre (visual); perigo só depois do VAI!


# ---------------------------------------------------------------- poderes (RF-420..428, RF-451)
# Cada poder mora em scripts/powers/<id>.gd (registro em scripts/powers/registry.gd).

signal power_used(k: Node3D, power: String, msg: String)
