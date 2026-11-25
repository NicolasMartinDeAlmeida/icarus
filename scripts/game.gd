extends Control

## Accessible turn-based first-person RPG gameplay controller for Labirinto de Ícaro.
## Supports remappable actions, 100% keyboard navigation (Tab/Arrows/WASD/Enter/Esc),
## structured audio descriptions (TTS), Ariadne's thread human guidance, stereo audio cues,
## persistent right-side minimap, and in-game Options overlay without losing progress.

const OPTIONS_SCENE: PackedScene = preload("res://scenes/options.tscn")

@onready var background_rect: ColorRect = $Background
@onready var hud_panel: PanelContainer = $RootVBox/BodyMargin/BodyVBox/HudPanel
@onready var objective_label: Label = $RootVBox/BodyMargin/BodyVBox/HudPanel/HudHBox/ObjectiveLabel
@onready var stats_label: Label = $RootVBox/BodyMargin/BodyVBox/HudPanel/HudHBox/StatsLabel
@onready var corridor_panel: PanelContainer = $RootVBox/BodyMargin/BodyVBox/MainHBox/StageCol/CorridorPanel
@onready var corridor_view: CorridorView = $RootVBox/BodyMargin/BodyVBox/MainHBox/StageCol/CorridorPanel/CorridorView

@onready var advance_button: Button = $RootVBox/BodyMargin/BodyVBox/MainHBox/StageCol/PadGrid/AdvanceButton
@onready var turn_left_button: Button = $RootVBox/BodyMargin/BodyVBox/MainHBox/StageCol/PadGrid/TurnLeftButton
@onready var turn_around_button: Button = $RootVBox/BodyMargin/BodyVBox/MainHBox/StageCol/PadGrid/TurnAroundButton
@onready var turn_right_button: Button = $RootVBox/BodyMargin/BodyVBox/MainHBox/StageCol/PadGrid/TurnRightButton

@onready var feedback_panel: PanelContainer = $RootVBox/BodyMargin/BodyVBox/MainHBox/InfoCol/FeedbackPanel
@onready var feedback_label: Label = $RootVBox/BodyMargin/BodyVBox/MainHBox/InfoCol/FeedbackPanel/FeedbackLabel
@onready var danger_panel: PanelContainer = $RootVBox/BodyMargin/BodyVBox/MainHBox/InfoCol/DangerPanel
@onready var danger_label: Label = $RootVBox/BodyMargin/BodyVBox/MainHBox/InfoCol/DangerPanel/DangerLabel
@onready var tools_panel: PanelContainer = $RootVBox/BodyMargin/BodyVBox/MainHBox/InfoCol/ToolsPanel

@onready var map_button: Button = $RootVBox/BodyMargin/BodyVBox/MainHBox/InfoCol/ToolsPanel/ToolsVBox/MapButton
@onready var describe_button: Button = $RootVBox/BodyMargin/BodyVBox/MainHBox/InfoCol/ToolsPanel/ToolsVBox/DescribeButton
@onready var position_button: Button = $RootVBox/BodyMargin/BodyVBox/MainHBox/InfoCol/ToolsPanel/ToolsVBox/PositionButton
@onready var options_button: Button = $RootVBox/BodyMargin/BodyVBox/MainHBox/InfoCol/ToolsPanel/ToolsVBox/OptionsButton
@onready var help_button: Button = $RootVBox/BodyMargin/BodyVBox/MainHBox/InfoCol/ToolsPanel/ToolsVBox/HelpButton
@onready var pause_button: Button = $RootVBox/BodyMargin/BodyVBox/MainHBox/InfoCol/ToolsPanel/ToolsVBox/PauseButton

@onready var right_col: VBoxContainer = $RootVBox/BodyMargin/BodyVBox/MainHBox/RightCol
@onready var minimap_panel: PanelContainer = $RootVBox/BodyMargin/BodyVBox/MainHBox/RightCol/MiniMapPanel
@onready var mini_title: Label = $RootVBox/BodyMargin/BodyVBox/MainHBox/RightCol/MiniMapPanel/MiniVBox/MiniHeader/MiniTitle
@onready var expand_map_button: Button = $RootVBox/BodyMargin/BodyVBox/MainHBox/RightCol/MiniMapPanel/MiniVBox/MiniHeader/ExpandMapButton
@onready var side_maze_map_view: MazeMapView = $RootVBox/BodyMargin/BodyVBox/MainHBox/RightCol/MiniMapPanel/MiniVBox/SideMazeMapView
@onready var mini_legend: Label = $RootVBox/BodyMargin/BodyVBox/MainHBox/RightCol/MiniMapPanel/MiniVBox/MiniLegend
@onready var libras_spacer: Control = $RootVBox/BodyMargin/BodyVBox/MainHBox/RightCol/LibrasSpacer

@onready var map_modal: ColorRect = $MapModal
@onready var map_panel: PanelContainer = $MapModal/Center/MapPanel
@onready var map_title: Label = $MapModal/Center/MapPanel/VBox/MapTitle
@onready var maze_map_view: MazeMapView = $MapModal/Center/MapPanel/VBox/MazeMapView
@onready var legend_label: Label = $MapModal/Center/MapPanel/VBox/LegendLabel
@onready var map_summary_label: Label = $MapModal/Center/MapPanel/VBox/MapSummaryLabel
@onready var map_speak_button: Button = $MapModal/Center/MapPanel/VBox/MapButtons/MapSpeakButton
@onready var map_close_button: Button = $MapModal/Center/MapPanel/VBox/MapButtons/MapCloseButton

@onready var pause_modal: ColorRect = $PauseModal
@onready var pause_panel: PanelContainer = $PauseModal/Center/PausePanel
@onready var pause_title: Label = $PauseModal/Center/PausePanel/VBox/PauseTitle
@onready var pause_hint: Label = $PauseModal/Center/PausePanel/VBox/PauseHint
@onready var resume_button: Button = $PauseModal/Center/PausePanel/VBox/ResumeButton
@onready var pause_options_button: Button = $PauseModal/Center/PausePanel/VBox/PauseOptionsButton
@onready var restart_button: Button = $PauseModal/Center/PausePanel/VBox/RestartButton
@onready var back_to_menu_button: Button = $PauseModal/Center/PausePanel/VBox/BackToMenuButton

@onready var end_modal: ColorRect = $EndModal
@onready var end_panel: PanelContainer = $EndModal/Center/EndPanel
@onready var end_title: Label = $EndModal/Center/EndPanel/VBox/EndTitle
@onready var end_body: Label = $EndModal/Center/EndPanel/VBox/EndBody
@onready var play_again_button: Button = $EndModal/Center/EndPanel/VBox/EndButtons/PlayAgainButton
@onready var end_menu_button: Button = $EndModal/Center/EndPanel/VBox/EndButtons/EndMenuButton

@onready var options_overlay_host: Control = $OptionsOverlayHost

var maze: MazeData
var _previous_focus: Control = null
var _options_return_focus: Control = null
var _base_texts: Dictionary = {}


func _ready() -> void:
	maze = MazeData.new()
	corridor_view.set_maze(maze)
	maze_map_view.set_maze(maze)
	side_maze_map_view.set_maze(maze)

	_connect_buttons()
	_setup_focus_navigation()
	AccessibilityManager.settings_changed.connect(_apply_accessibility)

	_apply_accessibility()
	_start_new_run(true)


func _exit_tree() -> void:
	if AccessibilityManager.settings_changed.is_connected(_apply_accessibility):
		AccessibilityManager.settings_changed.disconnect(_apply_accessibility)


func _connect_buttons() -> void:
	advance_button.pressed.connect(_do_move_forward)
	turn_left_button.pressed.connect(func() -> void: _do_turn(-1))
	turn_right_button.pressed.connect(func() -> void: _do_turn(1))
	turn_around_button.pressed.connect(func() -> void: _do_turn(2))

	map_button.pressed.connect(_toggle_side_minimap)
	expand_map_button.pressed.connect(_open_map)
	describe_button.pressed.connect(_announce_scene_description)
	position_button.pressed.connect(_announce_ariadne)
	options_button.pressed.connect(_open_options_overlay)
	help_button.pressed.connect(_open_help_from_button)
	pause_button.pressed.connect(_open_pause)

	map_speak_button.pressed.connect(_announce_map_summary)
	map_close_button.pressed.connect(_close_map)

	resume_button.pressed.connect(_close_pause)
	pause_options_button.pressed.connect(_open_options_overlay)
	restart_button.pressed.connect(func() -> void:
		AccessibilityManager.play_ui_sound("confirm")
		_close_pause_silent()
		_start_new_run(false)
	)
	back_to_menu_button.pressed.connect(_go_to_menu)

	play_again_button.pressed.connect(func() -> void:
		AccessibilityManager.play_ui_sound("confirm")
		end_modal.visible = false
		_start_new_run(false)
	)
	end_menu_button.pressed.connect(_go_to_menu)

	var all_btns: Array[Button] = [
		advance_button, turn_left_button, turn_around_button, turn_right_button,
		map_button, expand_map_button, describe_button, position_button, options_button, help_button, pause_button,
		map_speak_button, map_close_button,
		resume_button, pause_options_button, restart_button, back_to_menu_button,
		play_again_button, end_menu_button,
	]
	for b in all_btns:
		b.focus_entered.connect(_on_any_button_focused.bind(b))
		b.focus_exited.connect(_refresh_focus_labels)


func _on_any_button_focused(btn: Button) -> void:
	_refresh_focus_labels()
	if AccessibilityManager.suppress_focus_announcements:
		return
	AccessibilityManager.play_ui_sound("focus")
	var spoken := str(_base_texts.get(btn, btn.text))
	if not spoken.is_empty():
		AccessibilityManager.announce(spoken, _get_button_libras_key(btn), true)


func _get_button_libras_key(btn: Button) -> String:
	match btn:
		advance_button: return "avancar"
		turn_left_button: return "esquerda"
		turn_right_button: return "direita"
		turn_around_button: return "meia_volta"
		map_button, expand_map_button, map_speak_button: return "mapa"
		describe_button: return "repetir"
		position_button: return "onde_estou"
		options_button, pause_options_button: return "opcoes"
		help_button: return "ajuda"
		pause_button, resume_button: return "pausa"
		back_to_menu_button, end_menu_button: return "voltar"
		play_again_button, restart_button: return "iniciar"
	return ""


func _setup_focus_navigation() -> void:
	var main_order: Array[Button] = [
		advance_button, turn_left_button, turn_around_button, turn_right_button,
		map_button, describe_button, position_button, options_button, help_button, pause_button,
	]
	if AccessibilityManager.minimap_visible:
		main_order.append(expand_map_button)

	for i in range(main_order.size()):
		var prev_b := main_order[(i - 1 + main_order.size()) % main_order.size()]
		var next_b := main_order[(i + 1) % main_order.size()]
		main_order[i].focus_neighbor_top = main_order[i].get_path_to(prev_b)
		main_order[i].focus_neighbor_bottom = main_order[i].get_path_to(next_b)
		main_order[i].focus_previous = main_order[i].get_path_to(prev_b)
		main_order[i].focus_next = main_order[i].get_path_to(next_b)

	# Modal focus loops so Tab/Arrows/WASD stay inside the active modal
	map_speak_button.focus_neighbor_left = map_speak_button.get_path_to(map_close_button)
	map_speak_button.focus_neighbor_right = map_speak_button.get_path_to(map_close_button)
	map_speak_button.focus_next = map_speak_button.get_path_to(map_close_button)
	map_speak_button.focus_previous = map_speak_button.get_path_to(map_close_button)

	map_close_button.focus_neighbor_left = map_close_button.get_path_to(map_speak_button)
	map_close_button.focus_neighbor_right = map_close_button.get_path_to(map_speak_button)
	map_close_button.focus_next = map_close_button.get_path_to(map_speak_button)
	map_close_button.focus_previous = map_close_button.get_path_to(map_speak_button)

	var pause_order: Array[Button] = [resume_button, pause_options_button, restart_button, back_to_menu_button]
	for i in range(pause_order.size()):
		var prev_p := pause_order[(i - 1 + pause_order.size()) % pause_order.size()]
		var next_p := pause_order[(i + 1) % pause_order.size()]
		pause_order[i].focus_neighbor_top = pause_order[i].get_path_to(prev_p)
		pause_order[i].focus_neighbor_bottom = pause_order[i].get_path_to(next_p)
		pause_order[i].focus_previous = pause_order[i].get_path_to(prev_p)
		pause_order[i].focus_next = pause_order[i].get_path_to(next_p)

	play_again_button.focus_neighbor_left = play_again_button.get_path_to(end_menu_button)
	play_again_button.focus_neighbor_right = play_again_button.get_path_to(end_menu_button)
	play_again_button.focus_next = play_again_button.get_path_to(end_menu_button)
	play_again_button.focus_previous = play_again_button.get_path_to(end_menu_button)

	end_menu_button.focus_neighbor_left = end_menu_button.get_path_to(play_again_button)
	end_menu_button.focus_neighbor_right = end_menu_button.get_path_to(play_again_button)
	end_menu_button.focus_next = end_menu_button.get_path_to(play_again_button)
	end_menu_button.focus_previous = end_menu_button.get_path_to(play_again_button)


func _input(event: InputEvent) -> void:
	if AccessibilityManager.is_capturing_input:
		return
	if options_overlay_host.visible:
		return
	if AccessibilityOverlay != null and AccessibilityOverlay.is_help_open():
		return
	if not (event is InputEventKey):
		return
	var kev := event as InputEventKey
	if not kev.pressed or kev.echo:
		return

	if end_modal.visible:
		if kev.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_go_to_menu()
		return

	if pause_modal.visible:
		if kev.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_close_pause()
		return

	if map_modal.visible:
		if kev.keycode == KEY_ESCAPE or event.is_action_pressed("toggle_map"):
			get_viewport().set_input_as_handled()
			_close_map()
		elif event.is_action_pressed("repeat_description"):
			get_viewport().set_input_as_handled()
			_announce_map_summary()
		return

	# Active maze gameplay shortcuts (Arrows + remapped WASD/custom keys)
	if event.is_action_pressed("move_forward") or kev.keycode == KEY_UP:
		get_viewport().set_input_as_handled()
		_do_move_forward()
	elif event.is_action_pressed("turn_left") or kev.keycode == KEY_LEFT:
		get_viewport().set_input_as_handled()
		_do_turn(-1)
	elif event.is_action_pressed("turn_right") or kev.keycode == KEY_RIGHT:
		get_viewport().set_input_as_handled()
		_do_turn(1)
	elif event.is_action_pressed("turn_around") or kev.keycode == KEY_DOWN:
		get_viewport().set_input_as_handled()
		_do_turn(2)
	elif event.is_action_pressed("toggle_map"):
		get_viewport().set_input_as_handled()
		_toggle_side_minimap()
	elif event.is_action_pressed("repeat_description"):
		get_viewport().set_input_as_handled()
		_announce_scene_description()
	elif event.is_action_pressed("announce_position"):
		get_viewport().set_input_as_handled()
		_announce_ariadne()
	elif kev.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_open_pause()


func _apply_accessibility() -> void:
	var th := AccessibilityManager.build_theme()
	var pal := AccessibilityManager.get_palette()
	theme = th
	hud_panel.theme = th
	corridor_panel.theme = th
	feedback_panel.theme = th
	danger_panel.theme = th
	tools_panel.theme = th
	minimap_panel.theme = th
	map_panel.theme = th
	pause_panel.theme = th
	end_panel.theme = th
	background_rect.color = pal["bg"]

	minimap_panel.visible = AccessibilityManager.minimap_visible
	libras_spacer.visible = AccessibilityManager.libras_enabled
	right_col.visible = AccessibilityManager.minimap_visible or AccessibilityManager.libras_enabled

	var body_sz := AccessibilityManager.get_scaled_font_size(14)
	var title_sz := mini(32, AccessibilityManager.get_scaled_font_size(20))
	objective_label.add_theme_color_override("font_color", pal["accent"])
	objective_label.add_theme_font_size_override("font_size", clampi(body_sz, 13, 22))
	stats_label.add_theme_font_size_override("font_size", clampi(body_sz, 13, 22))
	feedback_label.add_theme_font_size_override("font_size", clampi(body_sz, 13, 22))
	danger_label.add_theme_font_size_override("font_size", clampi(body_sz, 13, 22))

	mini_title.add_theme_color_override("font_color", pal["accent"])
	mini_title.add_theme_font_size_override("font_size", clampi(body_sz, 13, 20))
	mini_legend.add_theme_font_size_override("font_size", clampi(AccessibilityManager.get_scaled_font_size(12), 11, 16))
	expand_map_button.add_theme_font_size_override("font_size", clampi(AccessibilityManager.get_scaled_font_size(12), 11, 18))

	map_title.add_theme_color_override("font_color", pal["accent"])
	map_title.add_theme_font_size_override("font_size", title_sz)
	legend_label.add_theme_font_size_override("font_size", clampi(AccessibilityManager.get_scaled_font_size(13), 12, 20))
	map_summary_label.add_theme_font_size_override("font_size", clampi(AccessibilityManager.get_scaled_font_size(14), 12, 22))

	pause_title.add_theme_color_override("font_color", pal["accent"])
	pause_title.add_theme_font_size_override("font_size", title_sz)
	pause_hint.add_theme_font_size_override("font_size", clampi(body_sz, 14, 22))

	end_title.add_theme_font_size_override("font_size", mini(36, AccessibilityManager.get_scaled_font_size(24)))
	end_body.add_theme_font_size_override("font_size", clampi(body_sz, 15, 24))

	_style_movement_buttons()
	_setup_focus_navigation()
	_update_dynamic_button_labels()
	_refresh_all_views()


func _style_movement_buttons() -> void:
	# Prototype terracotta-orange movement pads with high-contrast black border and focus ring
	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = Color(0.85, 0.45, 0.16, 1.0)
	normal_sb.border_color = Color(0.05, 0.05, 0.05, 1.0)
	normal_sb.set_border_width_all(3)
	normal_sb.set_corner_radius_all(4)
	normal_sb.content_margin_left = 6
	normal_sb.content_margin_right = 6
	normal_sb.content_margin_top = 6
	normal_sb.content_margin_bottom = 6

	var hover_sb := normal_sb.duplicate() as StyleBoxFlat
	hover_sb.bg_color = Color(0.95, 0.55, 0.22, 1.0)
	hover_sb.border_color = Color.WHITE
	hover_sb.set_border_width_all(3)

	var focus_sb := normal_sb.duplicate() as StyleBoxFlat
	focus_sb.bg_color = Color(1.0, 0.56, 0.15, 1.0)
	focus_sb.border_color = Color.WHITE
	focus_sb.set_border_width_all(4)

	for b in [advance_button, turn_left_button, turn_around_button, turn_right_button]:
		b.add_theme_stylebox_override("normal", normal_sb)
		b.add_theme_stylebox_override("hover", hover_sb)
		b.add_theme_stylebox_override("focus", focus_sb)
		b.add_theme_color_override("font_color", Color.BLACK)
		b.add_theme_color_override("font_hover_color", Color.BLACK)
		b.add_theme_color_override("font_focus_color", Color.BLACK)


func _update_dynamic_button_labels() -> void:
	var k_fwd := AccessibilityManager.get_action_key_label("move_forward")
	var k_left := AccessibilityManager.get_action_key_label("turn_left")
	var k_right := AccessibilityManager.get_action_key_label("turn_right")
	var k_back := AccessibilityManager.get_action_key_label("turn_around")
	var k_map := AccessibilityManager.get_action_key_label("toggle_map")
	var k_desc := AccessibilityManager.get_action_key_label("repeat_description")
	var k_pos := AccessibilityManager.get_action_key_label("announce_position")
	var k_help := AccessibilityManager.get_action_key_label("toggle_help")

	var mini_state := "Aberto" if AccessibilityManager.minimap_visible else "Fechado"
	_base_texts = {
		advance_button: "▲ Avançar (%s)" % k_fwd,
		turn_left_button: "◀ Esquerda (%s)" % k_left,
		turn_around_button: "▼ Meia-volta (%s)" % k_back,
		turn_right_button: "▶ Direita (%s)" % k_right,
		map_button: "Minimapa (%s): %s" % [k_map, mini_state],
		expand_map_button: "Ampliar",
		describe_button: "Ouvir descrição (%s)" % k_desc,
		position_button: "Fio de Ariadne (%s)" % k_pos,
		options_button: "Opções",
		help_button: "Ajuda (%s)" % k_help,
		pause_button: "Pausar / Menu (Esc)",
		map_speak_button: "Ouvir resumo (%s)" % k_desc,
		map_close_button: "Fechar Mapa (Esc)",
		resume_button: "Continuar (Esc)",
		pause_options_button: "Opções",
		restart_button: "Reiniciar Labirinto",
		back_to_menu_button: "Voltar ao Menu",
		play_again_button: "Jogar de novo",
		end_menu_button: "Voltar ao Menu",
	}
	_refresh_focus_labels()


func _refresh_focus_labels() -> void:
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	for btn_var in _base_texts.keys():
		var btn: Button = btn_var
		var base: String = str(_base_texts[btn])
		btn.text = ("▶ " if focused == btn else "") + base
		if "accessibility_name" in btn:
			btn.set("accessibility_name", base)


func _start_new_run(is_initial: bool) -> void:
	maze.reset()
	map_modal.visible = false
	pause_modal.visible = false
	end_modal.visible = false
	options_overlay_host.visible = false

	_set_feedback("✔ Você entrou no labirinto. Chegue ao centro fugindo do monstro.", "ok")
	_refresh_all_views()

	AccessibilityManager.suppress_focus_announcements = true
	advance_button.grab_focus()
	_refresh_focus_labels()
	AccessibilityManager.suppress_focus_announcements = false

	var intro := "Labirinto de Ícaro. Objetivo: chegar ao centro fugindo do monstro."
	if AccessibilityManager.audio_description:
		intro += " " + maze.get_scene_description()
	if is_initial:
		AccessibilityManager.announce.call_deferred(intro, "avancar")
	else:
		AccessibilityManager.announce(intro, "avancar")


func _refresh_all_views() -> void:
	if maze == null:
		return
	var zone := maze.get_zone_name()
	var dir_name := MazeData.DIR_NAMES[maze.player_dir]
	stats_label.text = "%s  |  %s  |  Passos: %d" % [zone, dir_name, maze.steps]
	_update_danger_panel()
	corridor_view.refresh()
	maze_map_view.refresh()
	side_maze_map_view.refresh()


func _update_danger_panel() -> void:
	var pal := AccessibilityManager.get_palette()
	var danger := maze.get_danger_level()
	var sensory := maze.get_monster_sensory_cue()
	var next_move_txt := "Monstro se move em %d passo%s." % [
		maze.monster_cooldown,
		"" if maze.monster_cooldown == 1 else "s",
	]

	var col: Color = pal["ok"]
	match danger:
		0: col = pal["ok"]
		1: col = pal["muted"]
		2: col = pal["accent"]
		3: col = pal["err"]

	danger_label.text = sensory + "\n" + next_move_txt
	danger_label.add_theme_color_override("font_color", col)


func _set_feedback(msg: String, kind: String) -> void:
	var pal := AccessibilityManager.get_palette()
	feedback_label.text = msg
	match kind:
		"err":
			feedback_label.add_theme_color_override("font_color", pal["err"])
		"warn":
			feedback_label.add_theme_color_override("font_color", pal["accent"])
		_:
			feedback_label.add_theme_color_override("font_color", pal["ok"])


func _do_move_forward() -> void:
	if maze.status != "playing":
		return
	var prev_zone := maze.get_zone_name()
	var res := maze.try_move_forward()

	if bool(res.get("hit_wall", false)):
		AccessibilityManager.play_game_sound("wall", 0.0)
		AccessibilityManager.announce_sound_cue("[Som: parede de pedra à frente]")
		corridor_view.trigger_bump_feedback()
		var msg := "✖ Parede à frente. Vire à esquerda, à direita ou faça meia-volta. Seu turno não foi gasto."
		_set_feedback(msg, "err")
		AccessibilityManager.announce(msg, "parede")
		return

	_refresh_all_views()

	if res["status"] == "victory":
		_show_end_screen(true)
		return
	if res["status"] == "defeat":
		_show_end_screen(false)
		return

	AccessibilityManager.play_game_sound("step", 0.0)
	AccessibilityManager.announce_sound_cue("[Som: passos no corredor]")

	var danger: int = int(res["danger_level"])
	var mdir: String = str(res["monster_rel_dir"])
	var mpan: float = maze.get_relative_pan(maze.monster_pos)
	if bool(res.get("monster_moved", false)):
		if danger >= 3:
			AccessibilityManager.play_game_sound("monster_danger", mpan)
			AccessibilityManager.announce_sound_cue("[Som: rugido e passos muito perto %s]" % mdir)
		elif danger == 2:
			AccessibilityManager.play_game_sound("monster_near", mpan)
			AccessibilityManager.announce_sound_cue("[Som: passos pesados do monstro %s]" % mdir)
		elif danger == 1:
			AccessibilityManager.play_game_sound("monster_far", mpan)
			AccessibilityManager.announce_sound_cue("[Som: passos distantes do monstro %s]" % mdir)

	var step_msg := maze.get_step_speech(prev_zone)
	if danger >= 2:
		_set_feedback("⚠ " + step_msg, "warn")
	else:
		_set_feedback("✔ " + step_msg, "ok")

	var spoken := "Avançou. " + (step_msg if AccessibilityManager.audio_description else ("Voltado para " + MazeData.DIR_NAMES[maze.player_dir] + "."))
	AccessibilityManager.announce(spoken, "avancar")


func _do_turn(delta: int) -> void:
	if maze.status != "playing":
		return
	var res := maze.turn(delta)
	if not bool(res.get("ok", false)):
		return
	_refresh_all_views()

	var pan := -0.6 if delta == -1 else (0.6 if delta == 1 else 0.0)
	AccessibilityManager.play_game_sound("turn", pan)
	AccessibilityManager.announce_sound_cue("[Som: girou no corredor]")

	var action_txt := "Fez meia-volta."
	var libras_k := "meia_volta"
	if delta == -1:
		action_txt = "Virou à esquerda."
		libras_k = "esquerda"
	elif delta == 1:
		action_txt = "Virou à direita."
		libras_k = "direita"

	var step_msg := maze.get_step_speech()
	_set_feedback("✔ " + action_txt + " " + step_msg, "ok")

	var spoken := action_txt + " Voltado para " + str(res["dir_name"]) + "."
	if AccessibilityManager.audio_description:
		spoken += " " + step_msg
	AccessibilityManager.announce(spoken, libras_k)


func _announce_scene_description() -> void:
	AccessibilityManager.play_ui_sound("confirm")
	AccessibilityManager.announce(maze.get_scene_description(), "repetir")


func _announce_ariadne() -> void:
	var pan := maze.get_relative_pan(maze.goal_pos)
	AccessibilityManager.play_game_sound("ariadne", pan)
	AccessibilityManager.announce_sound_cue("[Som: Fio de Ariadne indicando o caminho]")
	var guide := maze.get_ariadne_guidance()
	_set_feedback("✔ " + guide, "ok")
	AccessibilityManager.announce(guide, "onde_estou")


func _open_help_from_button() -> void:
	if AccessibilityOverlay != null and AccessibilityOverlay.has_method("_open_help"):
		AccessibilityOverlay._open_help()


func _toggle_side_minimap() -> void:
	AccessibilityManager.minimap_visible = not AccessibilityManager.minimap_visible
	AccessibilityManager.emit_settings_changed()
	if AccessibilityManager.minimap_visible:
		AccessibilityManager.play_game_sound("map_open")
		AccessibilityManager.announce_sound_cue("[Som: minimapa lateral aberto]")
		AccessibilityManager.announce("Minimapa aberto à direita. " + maze.get_ariadne_guidance(), "mapa")
	else:
		AccessibilityManager.play_game_sound("map_close")
		AccessibilityManager.announce_sound_cue("[Som: minimapa fechado]")
		AccessibilityManager.announce("Minimapa fechado.", "voltar")


func _open_map() -> void:
	if map_modal.visible or pause_modal.visible or end_modal.visible or options_overlay_host.visible:
		return
	var owner := get_viewport().gui_get_focus_owner()
	if owner is Control:
		_previous_focus = owner
	maze_map_view.refresh()
	var summary := maze.get_map_summary()
	map_summary_label.text = summary
	map_modal.visible = true

	AccessibilityManager.play_game_sound("map_open")
	AccessibilityManager.announce_sound_cue("[Som: mapa 2D ampliado aberto]")
	AccessibilityManager.suppress_focus_announcements = true
	map_close_button.grab_focus()
	_refresh_focus_labels()
	AccessibilityManager.suppress_focus_announcements = false
	AccessibilityManager.announce("Mapa ampliado aberto. " + summary, "mapa")


func _announce_map_summary() -> void:
	AccessibilityManager.play_ui_sound("confirm")
	AccessibilityManager.announce(maze.get_map_summary(), "mapa")


func _close_map() -> void:
	map_modal.visible = false
	AccessibilityManager.play_game_sound("map_close")
	AccessibilityManager.announce_sound_cue("[Som: mapa fechado]")
	AccessibilityManager.announce("Mapa ampliado fechado.", "voltar")
	_restore_previous_focus()


func _open_options_overlay() -> void:
	if options_overlay_host.visible:
		return
	var owner := get_viewport().gui_get_focus_owner()
	if owner is Control:
		_options_return_focus = owner
	for child in options_overlay_host.get_children():
		child.queue_free()

	var opt := OPTIONS_SCENE.instantiate()
	opt.set("is_overlay", true)
	opt.connect("closed", _on_options_closed)
	options_overlay_host.add_child(opt)
	options_overlay_host.visible = true
	AccessibilityManager.play_ui_sound("confirm")


func _on_options_closed() -> void:
	options_overlay_host.visible = false
	_apply_accessibility()
	if is_instance_valid(_options_return_focus) and _options_return_focus.is_inside_tree() and _options_return_focus.visible:
		AccessibilityManager.suppress_focus_announcements = true
		_options_return_focus.grab_focus()
		_refresh_focus_labels()
		AccessibilityManager.suppress_focus_announcements = false
	elif pause_modal.visible:
		resume_button.grab_focus()
	else:
		advance_button.grab_focus()
	_options_return_focus = null


func _open_pause() -> void:
	if pause_modal.visible or end_modal.visible or options_overlay_host.visible:
		return
	var owner := get_viewport().gui_get_focus_owner()
	if owner is Control:
		_previous_focus = owner
	pause_modal.visible = true

	AccessibilityManager.play_ui_sound("confirm")
	AccessibilityManager.suppress_focus_announcements = true
	resume_button.grab_focus()
	_refresh_focus_labels()
	AccessibilityManager.suppress_focus_announcements = false
	AccessibilityManager.announce("Jogo pausado. Selecione Continuar, Opções, Reiniciar Labirinto ou Voltar ao Menu.", "pausa")


func _close_pause() -> void:
	_close_pause_silent()
	AccessibilityManager.play_ui_sound("back")
	AccessibilityManager.announce("Voltando ao jogo.", "avancar")
	_restore_previous_focus()


func _close_pause_silent() -> void:
	pause_modal.visible = false


func _restore_previous_focus() -> void:
	if is_instance_valid(_previous_focus) and _previous_focus.is_inside_tree() and _previous_focus.visible:
		AccessibilityManager.suppress_focus_announcements = true
		_previous_focus.grab_focus()
		_refresh_focus_labels()
		AccessibilityManager.suppress_focus_announcements = false
	else:
		AccessibilityManager.suppress_focus_announcements = true
		advance_button.grab_focus()
		_refresh_focus_labels()
		AccessibilityManager.suppress_focus_announcements = false
	_previous_focus = null


func _show_end_screen(victory: bool) -> void:
	var pal := AccessibilityManager.get_palette()
	end_modal.visible = true

	if victory:
		end_title.text = "★ VOCÊ CHEGOU AO CENTRO!"
		end_title.add_theme_color_override("font_color", pal["ok"])
		end_body.text = "Parabéns! Você escapou do monstro e alcançou o centro do labirinto em %d passos.\nVocê pode jogar de novo no seu ritmo ou voltar ao menu." % maze.steps
		AccessibilityManager.play_game_sound("victory")
		AccessibilityManager.announce_sound_cue("[Som: vitória!]")
		AccessibilityManager.announce("Vitória! Você chegou ao centro do labirinto em %d passos." % maze.steps, "vitoria")
	else:
		end_title.text = "✖ O MONSTRO ALCANÇOU VOCÊ!"
		end_title.add_theme_color_override("font_color", pal["err"])
		end_body.text = "O monstro encontrou você após %d passos no labirinto.\nNão desanime: tente usar o Minimapa, o Fio de Ariadne (P) e os avisos sonoros na próxima tentativa!" % maze.steps
		AccessibilityManager.play_game_sound("defeat")
		AccessibilityManager.announce_sound_cue("[Som: o monstro alcançou você]")
		AccessibilityManager.announce("Fim de jogo. O monstro alcançou você após %d passos. Selecione Jogar de novo ou Voltar ao Menu." % maze.steps, "derrota")

	AccessibilityManager.suppress_focus_announcements = true
	play_again_button.grab_focus()
	_refresh_focus_labels()
	AccessibilityManager.suppress_focus_announcements = false


func _go_to_menu() -> void:
	AccessibilityManager.play_ui_sound("back")
	AccessibilityManager.announce("Voltando ao menu principal.", "voltar")
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
