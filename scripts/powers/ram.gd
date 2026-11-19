extends RefCounted
## RF-426: Ortiz — Trombada: 4 s maior e pesado; quem encosta roda (a corrida cuida da batida).

const TIME := 4.0


static func use(_race: Node, k: Node3D) -> String:
	k.ram_time = TIME
	return ""


static func ai_wants(_race: Node, _k: Node3D, ctx: Dictionary) -> bool:
	return float(ctx["ahead_near"]) < 9.0
