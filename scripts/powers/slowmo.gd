extends RefCounted
## RF-421: FeJauM — Câmera Lenta: todos os outros 50% mais lentos por 1 s (escudo protege).
## Interface de poder: use(race, k) -> mensagem ("" = nome do poder) · ai_wants(race, k, ctx) -> bool

const SLOW_TIME := 1.0


static func use(race: Node, k: Node3D) -> String:
	for o in race.karts:
		if o != k:
			o.apply_slow(SLOW_TIME)
	return ""


static func ai_wants(_race: Node, k: Node3D, _ctx: Dictionary) -> bool:
	return k.rank > 1
