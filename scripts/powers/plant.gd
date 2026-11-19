extends RefCounted
## RF-422: Nanni — Planta Turbo: 5 mini-turbos, um por aperto (o que ativa já gasta o 1º).
## Os apertos seguintes e a recarga ficam no kart (power_charges).

const CHARGES := 5


static func use(_race: Node, k: Node3D) -> String:
	k.power_charges = CHARGES - 1
	k.power_time = k.PLANT_WINDOW
	k.boost_time = maxf(k.boost_time, k.PLANT_BOOST)
	return ""


static func ai_wants(_race: Node, k: Node3D, _ctx: Dictionary) -> bool:
	return k.track.curvature_at(k.track_idx) < 0.3

