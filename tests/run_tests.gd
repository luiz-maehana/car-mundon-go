extends "res://tests/suites/t5_powers_security.gd"
## Testes headless dos critérios de aceite (SPEC.md §8). Rodar:
##   godot --headless --path . --script tests/run_tests.gd
## Os testes moram em tests/suites (cadeia: test_base → t1_core → t2_modes → t3_ui → t4_tracks →
## t5_powers_security → este arquivo, que só define a ordem). Ajudantes em test_base.gd.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(42)
	# configurações isoladas: não usa nem altera o arquivo do jogador
	var g = root.get_node_or_null("Game")
	if g:
		g.settings_path = "user://test_settings.cfg"
		g.reset_settings()
	_test_characters()
	_test_track()
	await _test_race()
	_test_inputs()
	await _test_multiplayer()
	_test_sounds()
	await _test_start()
	await _test_pause()
	await _test_intro()
	await _test_faces()
	await _test_all_tracks()
	await _test_v08()
	await _test_graphics()
	await _test_assets()
	await _test_settings()
	await _test_hud_layout()
	await _test_gp()
	await _test_new_items()
	await _test_smart_ai()
	_test_music()
	await _test_time_trial()
	await _test_ui_nav()
	await _test_layout()
	await _test_remap()
	await _test_char_select()
	await _test_new_tracks()
	await _test_drift_feel()
	await _test_parquinho()
	await _test_rescue()
	await _test_geladeira()
	await _test_telhados()
	await _test_menu_look()
	await _test_loading()
	await _test_results_live()
	await _test_feira()
	_test_char_colors()
	await _test_redone_tracks()
	await _test_stick_menu()
	await _test_powers()
	await _test_drift_vs_turn()
	_test_safe_files()
	print("\n%s (%d falha(s))" % ["PASSOU" if fails == 0 else "FALHOU", fails])
	quit(1 if fails > 0 else 0)
