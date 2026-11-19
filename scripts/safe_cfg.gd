extends RefCounted
## RF-440: leitura SEGURA dos arquivos do jogador (settings.cfg, records.cfg).
##
## O ConfigFile do Godot desserializa Object(...) e Resource("caminho") — um arquivo trocado
## (ex.: "me manda teu records.cfg pra ver o fantasma") consegue carregar e RODAR um script
## só de ser aberto. Aqui o texto é conferido ANTES de virar ConfigFile: nada de objeto,
## recurso ou chamada; só números, textos, listas e PackedFloat32Array (o que o jogo grava).
## Arquivo recusado é renomeado pra "<nome>.bloqueado" (não some, mas não é mais lido).

const MAX_BYTES := 4 * 1024 * 1024
## Tokens que o VariantParser transforma em objeto/recurso/chamada. Nenhum deles aparece
## nos arquivos que o próprio jogo grava.
const FORBIDDEN := ["Object(", "Resource(", "SubResource(", "ExtResource(", "Callable(", "Signal(", "NodePath(", "RID("]

static var last_rejected := ""   # caminho do último arquivo recusado (testes e log)


## Devolve um ConfigFile com o conteúdo, ou vazio se o arquivo não existe / é inseguro.
static func load_file(path: String) -> ConfigFile:
	var cfg := ConfigFile.new()
	if not FileAccess.file_exists(path):
		return cfg
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return cfg
	if f.get_length() > MAX_BYTES:
		f.close()
		_reject(path, "grande demais")
		return cfg
	var text := f.get_as_text()
	f.close()
	if not is_safe_text(text):
		_reject(path, "tem objeto/recurso embutido")
		return cfg
	if cfg.parse(text) != OK:
		return ConfigFile.new()
	return cfg


static func is_safe_text(text: String) -> bool:
	for tok in FORBIDDEN:
		if text.contains(tok):
			return false
	return true


static func _reject(path: String, why: String) -> void:
	last_rejected = path
	push_warning("[seguranca] %s recusado (%s); usando o padrão." % [path, why])
	var dst := path + ".bloqueado"
	if FileAccess.file_exists(dst):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dst))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(dst))


## Número finito dentro da faixa (ou o padrão).
static func num(v, lo: float, hi: float, fallback: float) -> float:
	if typeof(v) != TYPE_FLOAT and typeof(v) != TYPE_INT:
		return fallback
	var x := float(v)
	if is_nan(x) or is_inf(x):
		return fallback
	return clampf(x, lo, hi)
