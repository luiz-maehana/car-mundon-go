extends RefCounted
## RF-425: Telles — Drift Mestre: por 8 s todo drift já sai com o turbo máximo.

const TIME := 8.0


static func use(_race: Node, k: Node3D) -> String:
	k.drift_master_time = TIME
	return ""


static func ai_wants(_race: Node, k: Node3D, _ctx: Dictionary) -> bool:
	return k.drifting
