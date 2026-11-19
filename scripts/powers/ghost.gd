extends RefCounted
## RF-423: Mugurin — Fantasma: 4 s transparente; nada acerta e atravessa os karts.

const TIME := 4.0


static func use(_race: Node, k: Node3D) -> String:
	k.ghost_time = TIME
	return ""


static func ai_wants(race: Node, k: Node3D, ctx: Dictionary) -> bool:
	return not race.ground_hazards_ahead(k, 22).is_empty() or float(ctx["near"]) < 5.0 or randf() < 0.004
