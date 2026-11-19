extends SceneTree
## RF-170/RF-475: gera a máscara de recolor do kart (assets/kenney/karts/Textures/colormap_mask.png).
## A carroceria do Kenney é um branco levemente lilás; a saturação só aparece no espaço linear.
## O Forward+ convertia sRGB→linear e achava a cor; o Compatibility (navegador) não, e o kart saía
## branco. Com a máscara pronta numa textura, os dois renderizadores pintam igual.
##   godot --headless --path . --script tools/make_kart_mask.gd

const SRC := "res://assets/kenney/karts/Textures/colormap.png"
const DST := "res://assets/kenney/karts/Textures/colormap_mask.png"


func _initialize() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	img.convert(Image.FORMAT_RGBA8)
	var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_L8)
	for y in img.get_height():
		for x in img.get_width():
			out.set_pixel(x, y, Color(mask_of(img.get_pixel(x, y)), 0, 0))
	out.save_png(ProjectSettings.globalize_path(DST))
	print("máscara salva: ", DST)
	quit()


## Mesma conta que o shader fazia (no espaço linear).
static func mask_of(srgb: Color) -> float:
	var c := srgb.srgb_to_linear()
	var mx := maxf(c.r, maxf(c.g, c.b))
	var mn := minf(c.r, minf(c.g, c.b))
	var sat := (mx - mn) / maxf(mx, 0.001)
	return smoothstep(0.18, 0.32, sat)
