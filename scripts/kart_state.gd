extends Node3D
## Kart — estado (todas as variáveis e constantes) e consultas simples: frente, velocidade máxima, posicionar, itens.
## (camada de kart.gd — ver o topo de kart.gd)

## Kart: física arcade (sem motor de física), drift + mini-turbo, IA e visual procedural.
## Frente do kart = -Z local. heading = rotação em Y.

const TrackScript = preload("res://scripts/track.gd")
const GameScript = preload("res://scripts/game.gd")
const Chars = preload("res://scripts/characters.gd")
const Gfx = preload("res://scripts/gfx.gd")
const MouseModel = preload("res://scripts/mouse_model.gd")
const PowerRegistry = preload("res://scripts/powers/registry.gd")
const Ids = preload("res://scripts/ids.gd")
const KenneyKart = preload("res://assets/kenney/karts/kart-oopi.glb")
const RecolorShader = preload("res://shaders/kart_recolor.gdshader")
const RecolorMask = preload("res://assets/kenney/karts/Textures/colormap_mask.png")  # RF-475
const KART_SCALE := 2.3
const ShieldShader = preload("res://shaders/shield.gdshader")
const LABEL_LAYER_BASE := 10  # camada do nome do jogador N = 10+N (escondida na câmera dele)

const DRIFT_MIN_SPEED := 12.0
const MINI_TURBO_1 := 0.7
const MINI_TURBO_2 := 1.5
const MINI_TURBO_3 := 2.4   # RF-143
const GRAVITY := 28.0
const PAD_BOOST := 0.8
const TRICK_BOOST := 0.7
const ITEM_ROLL := 1.0      # roleta (RF-130)
const SHIELD_TIME := 8.0    # RF-203
const TRAP_TIME := 1.2      # RF-202
const MAX_CHEESE := 10
const ITEM_BOOST := 1.3
const DRIFT_TURN_MIN := 0.2   # RF-280/430: giro no drift (× giro normal) abrindo a curva...
const DRIFT_TURN_MAX := 0.85  # ...e fechando (nunca mais que uma curva normal, igual Mario Kart)
const DRIFT_GRIP := 6.0
const BOOST_MULT := 1.3
const OFFROAD_MULT := 0.5
const RADIUS := 1.0

var track: Node3D
var race: Node

var char_id := ""
var display_name := ""
var color := Color.WHITE
var is_player := false
var player_index := -1  # 0..3 para humanos, -1 para IA
var autopilot := true

# stats (SPEC §3)
var max_speed := 28.0
var accel := 16.0
var turn_rate := 2.0
var weight := 3.0
var ai_skill := 1.0
var rubber := 1.0

# estado
var heading := 0.0
var speed := 0.0
var vel := Vector3.ZERO
var track_idx := 0
var lateral := 0.0
var progress := 0.0
var finished := false
var finish_time := 0.0
var rank := 1
var max_abs_lateral := 0.0

var drifting := false
var drift_dir := 0.0
var drift_charge := 0.0
var boost_time := 0.0
var spin_time := 0.0
var hop_time := 0.0
var item := ""
var item_hold := 0.0
var items_used := 0
var stuck_time := 0.0
var ai_lane := 0.0
var ai_lane_timer := 0.0
var ai_item_delay := 3.0

# largada (RF-85..87)
const START_WINDOW_EARLY := 1.6
const START_WINDOW_LATE := 0.6
var start_hold := -1.0     # countdown no momento em que começou a segurar o acelerador
var start_stall := 0.0
var start_result := ""     # "" | "turbo" | "queimou"
var zone_kind := ""         # RF-270: farofa | sand | belt | belt_side | grill | ""

# RF-310..313: resgate — um cacho de balões leva o kart preso (ou que caiu) de volta pra pista
const RESCUE_TIME := 1.3       # total, sem controle
const RESCUE_LIFT := 0.5       # subindo no lugar; depois desce no ponto seguro
const RESCUE_HEIGHT := 6.0
const RESCUE_GHOST := 1.2      # depois de pousar: pisca e nada acerta
const STUCK_AI_TIME := 2.5
const STUCK_PLAYER_TIME := 3.0
const STUCK_MOVE := 1.5        # m/s: andando menos que isso querendo andar = preso
const FALL_Y := -3.0           # abaixo disso caiu (vãos das pistas futuras)
const WRONG_WAY_SHOW := 1.0
var rescue_time := 0.0
var rescue_ghost := 0.0
var rescue_from := Vector3.ZERO
var rescue_idx := 0
var rescue_moved := false
var rescues := 0
var safe_idx := 0
var wrong_way_time := 0.0
var last_pos := Vector3.ZERO
var balloons: Node3D

# RF-320..323: altura, looping (trilho) e gelo
const LOOP_MIN_SPEED := 20.0   # no looping o kart vai grudado e nunca para
const LOOP_STEER := 7.0        # m/s de troca de faixa dentro do looping
const ICE_GRIP := 1.6
var ground := 0.0              # altura do chão da pista embaixo do kart
var on_loop := false
var loop_s := 0.0              # posição no looping em amostras (com fração)
var loops_done := 0
var loop_fwd := Vector3.FORWARD   # frente e "pra cima" contínuos no looping (sem degraus entre amostras)
var loop_up := Vector3.UP
var pitch := 0.0

# v0.8: ar/rampa, manobra, queijinhos, vácuo, roleta
var vy := 0.0
var airborne := false
var on_ramp := false
var trick := false
var trick_spin := 0.0
var air_time := 0.0
var max_height := 0.0
var cheese := 0
var slip_time := 0.0
var slip_flash := 0.0
var item_roll := 0.0
var ai_trick_chance := 0.7
var ai_pad_target := -1
# RF-213: personalidade (0..1)
var ai_aggro := 0.5
var ai_avoid := 0.5
var ai_focus := 0.5
var ai_drift := 0.5
var ai_box_skip := false
var ai_evading := 0.0
var ai_seen := {}   # perigo (instance id) -> se a IA decidiu desviar
var prev_drift := false
var on_pad := false
var bump_cd := 0.0
var shield_time := 0.0
var trap_time := 0.0
var item_charges := 0
var shield_bubble: MeshInstance3D

# input do frame
var in_throttle := 0.0
var in_steer := 0.0
var in_drift := false
var in_item := false

# visual
var model: Node3D
var sparks: Array = []
var flames: Array = []
var p_flame: CPUParticles3D
var p_dust: CPUParticles3D
var p_smoke: CPUParticles3D
var p_stars: CPUParticles3D
var p_land: CPUParticles3D
var p_confetti: CPUParticles3D

var wheels: Array = []        # MeshInstance3D (giram)
var front_wheels: Array = []  # MeshInstance3D (esterçam)
var kart_body: MeshInstance3D
var driver: Node3D
var m_yaw := 0.0      # RF-484: giro, inclinação e tamanho do modelo (aplicados num movimento só)
var m_roll := 0.0
var m_scale := 1.0
var ghost_tr := 0.0
var vis_far := false  # RF-484: longe das câmeras (sem roda, inclinação e faísca)
const AI_THINK := 0.1  # RF-484: a IA repensa a faixa 10x por segundo (o volante é todo passo)
var ai_plans := 0  # RF-484: quantas vezes a IA pensou (pros testes)
var ai_think := -1.0   # tempo até repensar; começa espalhado entre os karts
var name_label: Label3D
var wheel_spin := 0.0


func forward() -> Vector3:
	return Vector3(-sin(heading), 0.0, -cos(heading))


func rank_value() -> float:
	return progress + track.along_of(position, track_idx) / TrackScript.SPACING


func place(idx: int, lat: float) -> void:
	var n: int = track.sample_count()
	track_idx = idx
	position = track.points[idx] + track.rights[idx] * lat
	heading = track.heading_at(idx)
	rotation.y = heading
	progress = float(idx - n) if idx > n / 2 else float(idx)
	safe_idx = idx
	last_pos = position
	on_loop = false
	ground = position.y
	wrong_way_time = 0.0
	stuck_time = 0.0
	speed = 0.0
	vel = Vector3.ZERO
	lateral = lat
	reset_physics_interpolation()


## Velocidade máxima atual sem turbo/grama (stats + queijinhos + IA).
func top_speed() -> float:
	var top := max_speed * (1.0 + 0.01 * cheese)
	if autopilot and not is_player:
		top *= ai_skill * rubber
	return top


func give_item(it: String) -> void:
	item = it
	item_hold = 0.0
	item_roll = ITEM_ROLL
	item_charges = 3 if it == "triplo" else 1  # RF-204


func can_use_item() -> bool:
	return item != "" and item_roll <= 0.0 and spin_time <= 0.0


## Frente e "pra cima" do kart (no looping seguem a pista; fora, o plano). A câmera usa.
func cam_frame() -> Array:
	if on_loop:
		return [loop_fwd, loop_up]
	return [forward(), Vector3.UP]


# ---------------------------------------------------------------- poderes (RF-420..428)

const SLOW_MULT := 0.5
const PLANT_BOOST := 0.7
const PLANT_WINDOW := 10.0
var power_cd := 0.0          # recarga (20 s depois de usar)
var power_time := 0.0        # efeito ativo / janela da planta
var power_charges := 0       # planta: mini-turbos que sobraram
var slow_time := 0.0         # câmera lenta do FeJauM em mim
var ghost_time := 0.0        # fantasma do Mugurin
var ram_time := 0.0          # trombada do Ortiz
var drift_master_time := 0.0 # drift mestre do Telles
var in_power := false
var powers_used := 0
var ai_power_wait := 0.0
var fx_slow: MeshInstance3D
var fx_plant: Node3D
var ghost_meshes: Array = []
