extends RefCounted
## RF-451: cada poder é um script com a mesma interface:
##   use(race, k) -> String       aplica o efeito; devolve a mensagem ("" = o nome do poder)
##   ai_wants(race, k, ctx) -> bool   a IA deve usar agora? (ctx: near, ahead_near)
## Poder novo = script novo + uma linha aqui + "power" no piloto (characters.gd).

const Ids = preload("res://scripts/ids.gd")
const POWERS := {
	Ids.PW_SLOWMO: preload("res://scripts/powers/slowmo.gd"),
	Ids.PW_GUITAR: preload("res://scripts/powers/guitar.gd"),
	Ids.PW_PLANT: preload("res://scripts/powers/plant.gd"),
	Ids.PW_BASS: preload("res://scripts/powers/bass.gd"),
	Ids.PW_GHOST: preload("res://scripts/powers/ghost.gd"),
	Ids.PW_DRIFT: preload("res://scripts/powers/drift.gd"),
	Ids.PW_RAM: preload("res://scripts/powers/ram.gd"),
	Ids.PW_STEAL: preload("res://scripts/powers/steal.gd"),
}


static func of(id: String) -> Script:
	return POWERS.get(id, null)

## Esses não começam a recarga no uso: o kart começa quando o efeito acaba (planta).
const COOLDOWN_LATER := [Ids.PW_PLANT]
