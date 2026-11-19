extends RefCounted
## RF-232/233: recordes do contra o relógio (por pista) + dados do fantasma.
## Arquivo: user://records.cfg — seção = id da pista.
##   race_time, race_char, lap_time, lap_char, ghost (PackedFloat32Array: x, y, z, heading a cada GHOST_STEP s)

const GHOST_STEP := 0.1
const DEFAULT_PATH := "user://records.cfg"

static var path := DEFAULT_PATH  # os testes trocam


static func _cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(path)
	return cfg


static func get_record(track_id: String) -> Dictionary:
	var cfg := _cfg()
	if not cfg.has_section(track_id):
		return {}
	var out := {}
	for k in cfg.get_section_keys(track_id):
		out[k] = cfg.get_value(track_id, k)
	return out


## Registra um resultado. Devolve {"race": bool, "lap": bool} dizendo o que virou recorde.
static func submit(track_id: String, char_id: String, race_time: float, best_lap: float, ghost: PackedFloat32Array) -> Dictionary:
	var cfg := _cfg()
	var got := {"race": false, "lap": false}
	var old_race: float = cfg.get_value(track_id, "race_time", INF)
	if race_time < old_race:
		cfg.set_value(track_id, "race_time", race_time)
		cfg.set_value(track_id, "race_char", char_id)
		cfg.set_value(track_id, "ghost", ghost)
		got["race"] = true
	var old_lap: float = cfg.get_value(track_id, "lap_time", INF)
	if best_lap < old_lap:
		cfg.set_value(track_id, "lap_time", best_lap)
		cfg.set_value(track_id, "lap_char", char_id)
		got["lap"] = true
	if got["race"] or got["lap"]:
		cfg.save(path)
	return got


static func clear_all() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Posição e direção do fantasma no instante t (interpolado). {} se acabou/sem dados.
static func ghost_sample(ghost: PackedFloat32Array, t: float) -> Dictionary:
	var frames := ghost.size() / 4
	if frames < 2 or t < 0.0:
		return {}
	var f := t / GHOST_STEP
	var i := int(floor(f))
	if i >= frames - 1:
		return {}
	var a := i * 4
	var b := a + 4
	var w := f - i
	var pos := Vector3(lerpf(ghost[a], ghost[b], w), lerpf(ghost[a + 1], ghost[b + 1], w), lerpf(ghost[a + 2], ghost[b + 2], w))
	return {"pos": pos, "heading": lerp_angle(ghost[a + 3], ghost[b + 3], w)}
