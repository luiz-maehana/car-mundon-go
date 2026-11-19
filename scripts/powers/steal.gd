extends RefCounted
## RF-427: Digão — Mão Leve: rouba o item de quem está logo à frente; senão, Queijo Triplo.


static func use(race: Node, k: Node3D) -> String:
	var v = race.kart_ahead_with_item(k)
	if v == null:
		k.give_item("triplo")
		k.item_roll = 0.0
		return "QUEIJO TRIPLO!"
	k.give_item(v.item)
	k.item_roll = 0.0
	v.item = ""
	v.item_charges = 0
	return "ROUBOU DE %s!" % String(v.display_name).to_upper()


static func ai_wants(race: Node, k: Node3D, _ctx: Dictionary) -> bool:
	return race.kart_ahead_with_item(k) != null or randf() < 0.003
