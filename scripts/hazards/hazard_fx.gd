extends RefCounted
## Ajudantes visuais comuns dos perigos da pista.


static func emissive(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


static func flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


## Kart encostou num ponto (distância no plano e altura relativa).
static func touches(k: Node3D, p: Vector3, radius: float, max_dy: float) -> bool:
	return Vector2(k.position.x - p.x, k.position.z - p.z).length() < radius and absf(k.position.y - p.y) < max_dy
