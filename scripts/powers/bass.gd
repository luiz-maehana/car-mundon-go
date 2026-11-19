extends RefCounted
## RF-424: Burcca — Grave no Talo: onda de som que derruba quem está a até 12 m (escudo protege).

const RADIUS := 12.0


static func use(race: Node, k: Node3D) -> String:
	for o in race.karts:
		if o != k and o.position.distance_to(k.position) < RADIUS:
			o.hit(1.0)
	_ring(race, k.position)
	return ""


static func ai_wants(_race: Node, _k: Node3D, ctx: Dictionary) -> bool:
	return float(ctx["near"]) < 10.0


## Anel vermelho que cresce e some.
static func _ring(race: Node, pos: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	ring.mesh = tm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.35, 0.3, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(1.0, 0.3, 0.25)
	m.emission_energy_multiplier = 2.5
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = m
	ring.position = pos + Vector3.UP * 0.8
	ring.name = "BassRing"
	race.add_child(ring)
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(RADIUS, 1.0, RADIUS), 0.45).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(ring.queue_free)
