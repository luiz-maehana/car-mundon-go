extends RefCounted
## RF-427: Shinando — Violão: escudo por 5 s.

const SHIELD := 5.0


static func use(_race: Node, k: Node3D) -> String:
	k.shield_time = maxf(k.shield_time, SHIELD)
	return ""


static func ai_wants(race: Node, k: Node3D, ctx: Dictionary) -> bool:
	return not race.ground_hazards_ahead(k, 22).is_empty() or float(ctx["near"]) < 5.0 or randf() < 0.004
