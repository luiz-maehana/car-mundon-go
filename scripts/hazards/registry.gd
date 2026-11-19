extends RefCounted
## RF-450: cada tipo de perigo da pista é um script com a mesma interface:
##   spawn(race, h)                                  cria os nós (filhos da corrida) e preenche h
##   update(race, h, can_drive, t_live, n)           anima e acerta quem encosta
##   ahead(race, h, hi, ds, out)                     avisa a IA (lista de {id, lat})
## Perigo novo = script novo + uma linha aqui (a corrida não muda).

const Ids = preload("res://scripts/ids.gd")
const KINDS := {
	Ids.HZ_FLAME: preload("res://scripts/hazards/flame.gd"),
	Ids.HZ_WHEEL: preload("res://scripts/hazards/wheel.gd"),
	Ids.HZ_PRESS: preload("res://scripts/hazards/press.gd"),
	Ids.HZ_SEESAW: preload("res://scripts/hazards/seesaw.gd"),
	Ids.HZ_CROSSER: preload("res://scripts/hazards/crosser.gd"),
	Ids.HZ_ROOFCAT: preload("res://scripts/hazards/crosser.gd"),
	Ids.HZ_ROVER: preload("res://scripts/hazards/rover.gd"),
}


static func of(kind: String) -> Script:
	return KINDS.get(kind, null)
