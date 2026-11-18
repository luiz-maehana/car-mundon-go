extends SceneTree
## Gera o banner da marca fictícia do jogo, ZAWSZE (combustível/patrocínio), em
## assets/brand/zawsze_banner.png (512x256, mesmo formato do banner do Racing Kit).
## Rode COM janela (precisa renderizar): godot --path . --script tools/make_brand.gd

const OUT := "res://assets/brand/zawsze_banner.png"
const FONT := "res://assets/kenney/fonts/Kenney Future.ttf"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(512, 256)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(vp)
	var bg := ColorRect.new()
	bg.color = Color(0.11, 0.11, 0.13)
	bg.size = Vector2(512, 256)
	vp.add_child(bg)
	# faixa inferior laranja/amarela (cara de posto de gasolina)
	var stripe := ColorRect.new()
	stripe.color = Color(1.0, 0.55, 0.08)
	stripe.position = Vector2(0, 214)
	stripe.size = Vector2(512, 14)
	vp.add_child(stripe)
	var stripe2 := ColorRect.new()
	stripe2.color = Color(1.0, 0.85, 0.15)
	stripe2.position = Vector2(0, 228)
	stripe2.size = Vector2(512, 8)
	vp.add_child(stripe2)
	# emblema: gota/chama em círculo
	var emblem := _Emblem.new()
	emblem.position = Vector2(40, 58)
	emblem.size = Vector2(120, 120)
	vp.add_child(emblem)
	var lbl := Label.new()
	lbl.text = "ZAWSZE"
	lbl.add_theme_font_override("font", load(FONT))
	lbl.add_theme_font_size_override("font_size", 60)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.position = Vector2(176, 74)
	vp.add_child(lbl)
	var tag := Label.new()
	tag.text = "COMBUSTÍVEL DE CAMPEÃO"
	tag.add_theme_font_override("font", load("res://assets/kenney/fonts/Kenney Future Narrow.ttf"))
	tag.add_theme_font_size_override("font_size", 20)
	tag.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
	tag.position = Vector2(174, 150)
	vp.add_child(tag)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/brand"))
	img.save_png(OUT)
	print("salvo ", OUT, " ", img.get_size())
	quit()


class _Emblem extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c, r, Color(1.0, 0.55, 0.08))
		draw_circle(c, r * 0.82, Color(0.11, 0.11, 0.13))
		# gota de combustível
		var pts := PackedVector2Array()
		for i in 25:
			var a := PI * i / 24.0
			pts.append(c + Vector2(cos(a) * r * 0.42, sin(a) * r * 0.42 + r * 0.12))
		pts.append(c + Vector2(0, -r * 0.62))
		draw_colored_polygon(pts, Color(1.0, 0.85, 0.15))
		draw_circle(c + Vector2(-r * 0.14, r * 0.18), r * 0.1, Color(1, 1, 1, 0.7))
