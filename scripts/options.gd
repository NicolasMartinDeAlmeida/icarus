extends Control

## Accessible Options screen with 5 tabs (Geral, Controles, Vídeo, Áudio, Acessibilidade).
## 100% keyboard navigable (Tab, Arrows, Enter/Space, Esc) with TTS, LSE cues, and High Contrast.

signal closed

const TABS: Array[Dictionary] = [
	{"id": "general", "title": "Geral", "libras": "geral"},
	{"id": "controls", "title": "Controles", "libras": "controles"},
	{"id": "video", "title": "Vídeo", "libras": "video"},
	{"id": "audio", "title": "Áudio", "libras": "audio"},
	{"id": "accessibility", "title": "Acessibilidade", "libras": "acessibilidade"},
]

@onready var background_rect: ColorRect = $Background
@onready var header_label: Label = $RootVBox/BodyMargin/BodyVBox/HeaderHBox/HeaderLabel
@onready var status_label: Label = $RootVBox/BodyMargin/BodyVBox/HeaderHBox/StatusLabel
@onready var items_panel: PanelContainer = $RootVBox/BodyMargin/BodyVBox/MainHBox/ItemsPanel
@onready var items_box: VBoxContainer = $RootVBox/BodyMargin/BodyVBox/MainHBox/ItemsPanel/Scroll/ItemsBox
@onready var tabs_panel: PanelContainer = $RootVBox/BodyMargin/BodyVBox/MainHBox/RightCol/TabsPanel
@onready var tabs_box: VBoxContainer = $RootVBox/BodyMargin/BodyVBox/MainHBox/RightCol/TabsPanel/TabsBox
@onready var libras_spacer: Control = $RootVBox/BodyMargin/BodyVBox/MainHBox/RightCol/LibrasSpacer
@onready var footer_libras_spacer: Control = $RootVBox/BodyMargin/BodyVBox/FooterHBox/FooterLibrasSpacer
@onready var back_button: Button = $RootVBox/BodyMargin/BodyVBox/FooterHBox/BackButton
@onready var footer_hint_label: Label = $RootVBox/BodyMargin/BodyVBox/FooterHBox/FooterHintLabel

var is_overlay: bool = false
var _active_tab: String = "accessibility"
var _capturing_action: String = ""
var _capturing_label: String = ""
var _tab_buttons: Dictionary = {}
var _row_buttons: Dictionary = {}
var _row_meta: Array[Dictionary] = []


func _ready() -> void:
	back_button.pressed.connect(_on_back)
	var back_spoken := "Voltar ao Jogo" if is_overlay else "Voltar ao Menu"
	if "accessibility_name" in back_button:
		back_button.set("accessibility_name", back_spoken)
	back_button.focus_entered.connect(func() -> void:
		_refresh_focus_labels()
		if AccessibilityManager.suppress_focus_announcements:
			return
		AccessibilityManager.play_ui_sound("focus")
		AccessibilityManager.announce(back_spoken + ". Pressione Enter ou Esc.", "voltar")
	)
	back_button.focus_exited.connect(_refresh_focus_labels)

	AccessibilityManager.settings_changed.connect(_on_settings_changed)

	_build_tabs()
	_apply_theme_and_colors()
	_rebuild_items("libras")

	AccessibilityManager.announce.call_deferred(
		"Tela de Opções. Aba Acessibilidade selecionada. Use as setas, WASD ou Tab para navegar, Enter ou setas esquerda e direita para alterar valores, Esc para voltar.",
		"acessibilidade"
	)


func _exit_tree() -> void:
	AccessibilityManager.is_capturing_input = false
	if AccessibilityManager.settings_changed.is_connected(_on_settings_changed):
		AccessibilityManager.settings_changed.disconnect(_on_settings_changed)


func _input(event: InputEvent) -> void:
	if _capturing_action.is_empty():
		return
	if not (event is InputEventKey):
		return
	var kev := event as InputEventKey
	if not kev.pressed or kev.echo:
		return

	get_viewport().set_input_as_handled()

	var code: Key = kev.physical_keycode if kev.physical_keycode != KEY_NONE else kev.keycode
	# Ignore bare modifier keys while waiting for the actual key binding.
	if code in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK]:
		return

	if code == KEY_ESCAPE:
		var prev_action := _capturing_action
		_capturing_action = ""
		_capturing_label = ""
		AccessibilityManager.is_capturing_input = false
		AccessibilityManager.play_ui_sound("back")
		_set_status("Remapeamento cancelado.", false)
		AccessibilityManager.announce("Remapeamento cancelado.", "voltar")
		_rebuild_items(prev_action)
		return

	var res := AccessibilityManager.remap_action_key(_capturing_action, kev)
	if not bool(res.get("ok", false)):
		AccessibilityManager.play_ui_sound("error")
		AccessibilityManager.announce_sound_cue("[Som: tecla reservada]")
		var reason := str(res.get("reason", "Tecla inválida."))
		_set_status("✖ " + reason + " Escolha outra ou Esc.", true)
		AccessibilityManager.announce(reason + " Pressione outra tecla ou Esc para cancelar.")
		return

	var target_action := _capturing_action
	var target_label := _capturing_label
	_capturing_action = ""
	_capturing_label = ""
	AccessibilityManager.is_capturing_input = false

	var msg := target_label + " agora usa a tecla " + str(res["key_name"])
	var swapped := str(res.get("swapped_with", ""))
	if not swapped.is_empty():
		msg += " (trocada com " + swapped + ")"
	AccessibilityManager.play_ui_sound("confirm")
	AccessibilityManager.announce_sound_cue("[Som: tecla salva]")
	_set_status("✔ " + msg, false)
	AccessibilityManager.announce(msg, "controles")
	_rebuild_items(target_action)


func _unhandled_input(event: InputEvent) -> void:
	if not _capturing_action.is_empty():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()


func _on_settings_changed() -> void:
	_apply_theme_and_colors()


func _apply_theme_and_colors() -> void:
	var th := AccessibilityManager.build_theme()
	var pal := AccessibilityManager.get_palette()
	theme = th
	items_panel.theme = th
	tabs_panel.theme = th
	background_rect.color = pal["bg"]

	libras_spacer.visible = AccessibilityManager.libras_enabled
	footer_libras_spacer.visible = AccessibilityManager.libras_enabled

	header_label.add_theme_color_override("font_color", pal["accent"])
	header_label.add_theme_font_size_override("font_size", mini(34, AccessibilityManager.get_scaled_font_size(22)))

	var hint_sz := clampi(AccessibilityManager.get_scaled_font_size(14), 12, 22)
	status_label.add_theme_font_size_override("font_size", hint_sz)
	footer_hint_label.add_theme_font_size_override("font_size", hint_sz)
	footer_hint_label.add_theme_color_override("font_color", pal["muted"])

	_update_tab_visuals()


func _build_tabs() -> void:
	for child in tabs_box.get_children():
		child.queue_free()
	_tab_buttons.clear()

	for i in range(TABS.size()):
		var t: Dictionary = TABS[i]
		var tab_id: String = t["id"]
		var tab_title: String = t["title"]
		var libras_key: String = t["libras"]

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 44)
		btn.text = tab_title
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if "accessibility_name" in btn:
			btn.set("accessibility_name", "Aba " + tab_title)
		btn.pressed.connect(func() -> void:
			_select_tab(tab_id, true)
		)
		btn.focus_entered.connect(func() -> void:
			_refresh_focus_labels()
			if AccessibilityManager.suppress_focus_announcements:
				return
			AccessibilityManager.play_ui_sound("focus")
			var active_note := " (aba ativa)" if _active_tab == tab_id else ""
			AccessibilityManager.announce("Aba " + tab_title + active_note + ". Pressione Enter para abrir.", libras_key)
		)
		btn.focus_exited.connect(_refresh_focus_labels)

		tabs_box.add_child(btn)
		_tab_buttons[tab_id] = btn

	_update_tab_visuals()


func _update_tab_visuals() -> void:
	var pal := AccessibilityManager.get_palette()
	for t in TABS:
		var tab_id: String = t["id"]
		if not _tab_buttons.has(tab_id):
			continue
		var btn: Button = _tab_buttons[tab_id]
		if tab_id == _active_tab:
			var active_box := _make_tab_style(pal["active_bg"], pal["border"], 3)
			var active_focus := _make_tab_style(pal["active_bg"], pal["focus_border"], 4)
			btn.add_theme_stylebox_override("normal", active_box)
			btn.add_theme_stylebox_override("hover", active_focus)
			btn.add_theme_stylebox_override("focus", active_focus)
			btn.add_theme_color_override("font_color", pal["accent_text"])
			btn.add_theme_color_override("font_hover_color", pal["accent_text"])
			btn.add_theme_color_override("font_focus_color", pal["accent_text"])
		else:
			btn.remove_theme_stylebox_override("normal")
			btn.remove_theme_stylebox_override("hover")
			btn.remove_theme_stylebox_override("focus")
			btn.remove_theme_color_override("font_color")
			btn.remove_theme_color_override("font_hover_color")
			btn.remove_theme_color_override("font_focus_color")
	_refresh_focus_labels()


func _make_tab_style(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _select_tab(tab_id: String, focus_first_item: bool) -> void:
	_active_tab = tab_id
	var tab_title := _get_tab_title(tab_id)
	var libras_key := _get_tab_libras(tab_id)
	header_label.text = "OPÇÕES — " + tab_title
	AccessibilityManager.play_ui_sound("confirm")
	_update_tab_visuals()
	_rebuild_items("" if focus_first_item else "__KEEP_TAB__")
	AccessibilityManager.announce("Aba " + tab_title + " aberta.", libras_key)


func _get_tab_title(tab_id: String) -> String:
	for t in TABS:
		if t["id"] == tab_id:
			return str(t["title"])
	return "Opções"


func _get_tab_libras(tab_id: String) -> String:
	for t in TABS:
		if t["id"] == tab_id:
			return str(t["libras"])
	return "opcoes"


func _get_items_for_active_tab() -> Array[Dictionary]:
	match _active_tab:
		"general":
			return [
				{"key": "language", "label": "Idioma", "type": "info", "value": "Português (BR)"},
				{"key": "caption_mode", "label": "Legenda", "type": "cycle", "value": AccessibilityManager.get_caption_mode_label()},
				{"key": "reset_all", "label": "Restaurar todas as opções", "type": "action", "value": "Restaurar padrão"},
			]
		"controls":
			var list: Array[Dictionary] = []
			for entry in AccessibilityManager.REMAPPABLE_ACTIONS:
				var action_name: String = entry["action"]
				var key_txt := AccessibilityManager.get_action_key_label(action_name)
				if _capturing_action == action_name:
					key_txt = "Pressione uma tecla..."
				list.append({
					"key": action_name,
					"label": entry["label"],
					"type": "remap",
					"value": key_txt,
				})
			list.append({"key": "reset_controls", "label": "Restaurar controles padrão", "type": "action", "value": "Restaurar"})
			return list
		"video":
			return [
				{"key": "fullscreen", "label": "Modo de tela", "type": "toggle", "value": "Tela cheia" if AccessibilityManager.fullscreen else "Janela"},
				{"key": "reduced_motion", "label": "Reduzir efeitos visuais", "type": "toggle", "value": "Ligado" if AccessibilityManager.reduced_motion else "Desligado"},
			]
		"audio":
			return [
				{"key": "sfx_enabled", "label": "Efeitos sonoros", "type": "toggle", "value": "Ligado" if AccessibilityManager.sfx_enabled else "Desligado"},
				{"key": "sfx_volume", "label": "Volume dos efeitos", "type": "step", "value": str(AccessibilityManager.sfx_volume_percent) + "%"},
			]
		"accessibility":
			return [
				{"key": "libras", "label": "VLibras", "type": "toggle", "value": "Ligado" if AccessibilityManager.libras_enabled else "Desligado"},
				{"key": "tts", "label": "Conversão de texto em fala", "type": "toggle", "value": "Ligado" if AccessibilityManager.tts_enabled else "Desligado"},
				{"key": "audio_description", "label": "Audiodescrição", "type": "toggle", "value": "Ligado" if AccessibilityManager.audio_description else "Desligado"},
				{"key": "minimap_visible", "label": "Minimapa lateral", "type": "toggle", "value": "Ligado" if AccessibilityManager.minimap_visible else "Desligado"},
				{"key": "font_scale", "label": "Tamanho da fonte", "type": "step", "value": str(AccessibilityManager.font_scale_percent) + "%"},
				{"key": "colorblind", "label": "Opções de cores", "type": "colorblind", "value": AccessibilityManager.get_colorblind_mode_label()},
				{"key": "game_speed", "label": "Velocidade de jogo", "type": "step", "value": str(AccessibilityManager.game_speed_percent) + "%"},
				{"key": "high_contrast", "label": "Alto Contraste", "type": "toggle", "value": "Ligado" if AccessibilityManager.high_contrast else "Desligado"},
			]
	return []


func _rebuild_items(focus_key: String = "") -> void:
	for child in items_box.get_children():
		child.queue_free()
	_row_buttons.clear()
	_row_meta.clear()

	header_label.text = "OPÇÕES — " + _get_tab_title(_active_tab)
	var items := _get_items_for_active_tab()
	var ordered_btns: Array[Button] = []

	for item in items:
		var key: String = item["key"]
		var label_txt: String = item["label"]
		var val_txt: String = item["value"]
		var row_type: String = item["type"]

		var row_hbox := HBoxContainer.new()
		row_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_hbox.add_theme_constant_override("separation", 8)

		var main_btn := Button.new()
		main_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_btn.custom_minimum_size = Vector2(0, 48)
		main_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if "accessibility_name" in main_btn:
			main_btn.set("accessibility_name", label_txt + ": " + val_txt)

		main_btn.pressed.connect(func() -> void:
			_activate_item(key, row_type, 1)
		)
		main_btn.gui_input.connect(func(ev: InputEvent) -> void:
			_on_row_gui_input(ev, key, row_type)
		)
		main_btn.focus_entered.connect(func() -> void:
			_refresh_focus_labels()
			if AccessibilityManager.suppress_focus_announcements:
				return
			AccessibilityManager.play_ui_sound("focus")
			var hint := _get_row_hint(row_type)
			AccessibilityManager.announce(label_txt + ": " + val_txt + ". " + hint, _get_tab_libras(_active_tab))
		)
		main_btn.focus_exited.connect(_refresh_focus_labels)

		row_hbox.add_child(main_btn)

		if row_type == "colorblind":
			var swatch := _make_rgb_swatch()
			row_hbox.add_child(swatch)

		if row_type == "step":
			var dec_btn := Button.new()
			dec_btn.text = "−"
			dec_btn.custom_minimum_size = Vector2(48, 48)
			dec_btn.focus_mode = Control.FOCUS_NONE
			dec_btn.tooltip_text = "Diminuir " + label_txt
			dec_btn.pressed.connect(func() -> void:
				_activate_item(key, row_type, -1)
			)
			var inc_btn := Button.new()
			inc_btn.text = "+"
			inc_btn.custom_minimum_size = Vector2(48, 48)
			inc_btn.focus_mode = Control.FOCUS_NONE
			inc_btn.tooltip_text = "Aumentar " + label_txt
			inc_btn.pressed.connect(func() -> void:
				_activate_item(key, row_type, 1)
			)
			row_hbox.add_child(dec_btn)
			row_hbox.add_child(inc_btn)

		items_box.add_child(row_hbox)
		_row_buttons[key] = main_btn
		_row_meta.append({"key": key, "label": label_txt, "value": val_txt, "type": row_type, "button": main_btn})
		ordered_btns.append(main_btn)

	_wire_row_neighbors(ordered_btns)
	_refresh_focus_labels()

	if focus_key == "__KEEP_TAB__":
		return
	var target_btn: Button = null
	if not focus_key.is_empty() and _row_buttons.has(focus_key):
		target_btn = _row_buttons[focus_key]
	elif not ordered_btns.is_empty():
		target_btn = ordered_btns[0]

	if target_btn != null:
		AccessibilityManager.suppress_focus_announcements = true
		target_btn.grab_focus()
		_refresh_focus_labels()
		AccessibilityManager.suppress_focus_announcements = false


func _make_rgb_swatch() -> PanelContainer:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(56, 48)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	var colors := [Color(0.15, 0.35, 1.0), Color(0, 0, 0, 0), Color(0.20, 0.90, 0.25), Color(0.95, 0.15, 0.15)]
	for c in colors:
		var r := ColorRect.new()
		r.custom_minimum_size = Vector2(12, 12)
		r.color = c
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(r)
	box.add_child(grid)
	return box


func _wire_row_neighbors(ordered_btns: Array[Button]) -> void:
	var active_tab_btn: Button = _tab_buttons.get(_active_tab, null)
	var all_controls: Array[Button] = []

	for b in ordered_btns:
		all_controls.append(b)
	for t in TABS:
		var tab_id: String = t["id"]
		if _tab_buttons.has(tab_id):
			all_controls.append(_tab_buttons[tab_id])
	all_controls.append(back_button)

	if all_controls.is_empty():
		return

	var total := all_controls.size()
	for i in range(total):
		var c := all_controls[i]
		var prev_c := all_controls[(i - 1 + total) % total]
		var next_c := all_controls[(i + 1) % total]
		c.focus_neighbor_top = c.get_path_to(prev_c)
		c.focus_neighbor_bottom = c.get_path_to(next_c)
		c.focus_previous = c.get_path_to(prev_c)
		c.focus_next = c.get_path_to(next_c)

	if active_tab_btn != null:
		for meta in _row_meta:
			var row_btn: Button = meta["button"]
			if not (meta["type"] in ["toggle", "step", "cycle", "colorblind"]):
				row_btn.focus_neighbor_right = row_btn.get_path_to(active_tab_btn)
		back_button.focus_neighbor_right = back_button.get_path_to(active_tab_btn)

	if not ordered_btns.is_empty():
		for t in TABS:
			var tab_id: String = t["id"]
			if _tab_buttons.has(tab_id):
				var tbtn: Button = _tab_buttons[tab_id]
				tbtn.focus_neighbor_left = tbtn.get_path_to(ordered_btns[0])


func _get_row_hint(row_type: String) -> String:
	match row_type:
		"toggle":
			return "Pressione Enter ou setas esquerda e direita para ligar ou desligar."
		"step":
			return "Use as setas esquerda e direita para diminuir ou aumentar."
		"cycle", "colorblind":
			return "Pressione Enter ou setas esquerda e direita para trocar."
		"remap":
			return "Pressione Enter para escolher uma nova tecla."
		"action":
			return "Pressione Enter para executar."
		_:
			return ""


func _on_row_gui_input(ev: InputEvent, key: String, row_type: String) -> void:
	if not _capturing_action.is_empty():
		return
	if row_type in ["toggle", "step", "cycle", "colorblind"]:
		if ev.is_action_pressed("ui_left"):
			accept_event()
			_activate_item(key, row_type, -1)
		elif ev.is_action_pressed("ui_right"):
			accept_event()
			_activate_item(key, row_type, 1)


func _activate_item(key: String, row_type: String, dir: int) -> void:
	if row_type == "info":
		AccessibilityManager.play_ui_sound("focus")
		AccessibilityManager.announce("Idioma atual: Português do Brasil.", "geral")
		return

	if row_type == "remap":
		_start_key_capture(key)
		return

	if key == "reset_controls":
		AccessibilityManager.reset_controls_to_default()
		AccessibilityManager.play_ui_sound("confirm")
		AccessibilityManager.announce_sound_cue("[Som: controles restaurados]")
		_set_status("✔ Controles restaurados para o padrão.", false)
		AccessibilityManager.announce("Controles restaurados para o padrão.", "controles")
		_rebuild_items(key)
		return

	if key == "reset_all":
		AccessibilityManager.reset_all_settings()
		AccessibilityManager.play_ui_sound("confirm")
		AccessibilityManager.announce_sound_cue("[Som: opções restauradas]")
		_set_status("✔ Todas as opções restauradas para o padrão.", false)
		AccessibilityManager.announce("Todas as opções foram restauradas para o padrão.", "geral")
		_rebuild_items(key)
		return

	match key:
		"caption_mode":
			var n := AccessibilityManager.CAPTION_MODES.size()
			AccessibilityManager.caption_mode = (AccessibilityManager.caption_mode + dir + n) % n
			AccessibilityManager.emit_settings_changed()
			_announce_change("Legenda", AccessibilityManager.get_caption_mode_label(), "geral")
		"fullscreen":
			AccessibilityManager.fullscreen = not AccessibilityManager.fullscreen
			AccessibilityManager.apply_window_mode()
			AccessibilityManager.emit_settings_changed()
			_announce_change("Modo de tela", "Tela cheia" if AccessibilityManager.fullscreen else "Janela", "video")
		"reduced_motion":
			AccessibilityManager.reduced_motion = not AccessibilityManager.reduced_motion
			AccessibilityManager.emit_settings_changed()
			_announce_change("Reduzir efeitos visuais", "Ligado" if AccessibilityManager.reduced_motion else "Desligado", "video")
		"sfx_enabled":
			AccessibilityManager.sfx_enabled = not AccessibilityManager.sfx_enabled
			AccessibilityManager.emit_settings_changed()
			_announce_change("Efeitos sonoros", "Ligado" if AccessibilityManager.sfx_enabled else "Desligado", "audio")
		"sfx_volume":
			AccessibilityManager.sfx_volume_percent = _step_value(AccessibilityManager.sfx_volume_percent, AccessibilityManager.VOLUME_STEPS, dir)
			AccessibilityManager.emit_settings_changed()
			_announce_change("Volume dos efeitos", str(AccessibilityManager.sfx_volume_percent) + "%", "audio")
		"libras":
			AccessibilityManager.libras_enabled = not AccessibilityManager.libras_enabled
			AccessibilityManager.emit_settings_changed()
			_announce_change("VLibras", "Ligado" if AccessibilityManager.libras_enabled else "Desligado", "acessibilidade")
		"tts":
			AccessibilityManager.tts_enabled = not AccessibilityManager.tts_enabled
			AccessibilityManager.emit_settings_changed()
			_announce_change("Conversão de texto em fala", "Ligado" if AccessibilityManager.tts_enabled else "Desligado", "acessibilidade")
		"audio_description":
			AccessibilityManager.audio_description = not AccessibilityManager.audio_description
			AccessibilityManager.emit_settings_changed()
			_announce_change("Audiodescrição", "Ligado" if AccessibilityManager.audio_description else "Desligado", "acessibilidade")
		"minimap_visible":
			AccessibilityManager.minimap_visible = not AccessibilityManager.minimap_visible
			AccessibilityManager.emit_settings_changed()
			_announce_change("Minimapa lateral", "Ligado" if AccessibilityManager.minimap_visible else "Desligado", "mapa")
		"font_scale":
			AccessibilityManager.font_scale_percent = _step_value(AccessibilityManager.font_scale_percent, AccessibilityManager.FONT_STEPS, dir)
			AccessibilityManager.emit_settings_changed()
			_announce_change("Tamanho da fonte", str(AccessibilityManager.font_scale_percent) + "%", "acessibilidade")
		"colorblind":
			var m := AccessibilityManager.COLORBLIND_MODES.size()
			AccessibilityManager.colorblind_mode = (AccessibilityManager.colorblind_mode + dir + m) % m
			AccessibilityManager.emit_settings_changed()
			_announce_change("Opções de cores", AccessibilityManager.get_colorblind_mode_label(), "acessibilidade")
		"game_speed":
			AccessibilityManager.game_speed_percent = _step_value(AccessibilityManager.game_speed_percent, AccessibilityManager.SPEED_STEPS, dir)
			AccessibilityManager.emit_settings_changed()
			_announce_change("Velocidade de jogo", str(AccessibilityManager.game_speed_percent) + "%", "acessibilidade")
		"high_contrast":
			AccessibilityManager.high_contrast = not AccessibilityManager.high_contrast
			AccessibilityManager.emit_settings_changed()
			_announce_change("Alto Contraste", "Ligado" if AccessibilityManager.high_contrast else "Desligado", "acessibilidade")

	_rebuild_items(key)


func _step_value(current: int, steps: Array[int], dir: int) -> int:
	var idx := steps.find(current)
	if idx == -1:
		idx = 0
	var next_idx := clampi(idx + dir, 0, steps.size() - 1)
	return steps[next_idx]


func _announce_change(label_txt: String, new_val: String, libras_key: String) -> void:
	AccessibilityManager.play_ui_sound("adjust")
	AccessibilityManager.announce_sound_cue("[Som: " + label_txt + " alterado]")
	_set_status("✔ " + label_txt + ": " + new_val, false)
	AccessibilityManager.announce(label_txt + ": " + new_val, libras_key)


func _start_key_capture(action_name: String) -> void:
	_capturing_action = action_name
	_capturing_label = action_name
	for entry in AccessibilityManager.REMAPPABLE_ACTIONS:
		if entry["action"] == action_name:
			_capturing_label = str(entry["label"])
			break
	AccessibilityManager.is_capturing_input = true
	AccessibilityManager.play_ui_sound("confirm")
	_set_status("Pressione uma tecla para '" + _capturing_label + "' (Esc cancela)...", false)
	AccessibilityManager.announce("Pressione a nova tecla para " + _capturing_label + ". Pressione Esc para cancelar.", "controles")
	_rebuild_items(action_name)


func _set_status(msg: String, is_err: bool) -> void:
	var pal := AccessibilityManager.get_palette()
	status_label.text = msg
	status_label.add_theme_color_override("font_color", pal["err"] if is_err else pal["ok"])


func _refresh_focus_labels() -> void:
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null

	for t in TABS:
		var tab_id: String = t["id"]
		if not _tab_buttons.has(tab_id):
			continue
		var tbtn: Button = _tab_buttons[tab_id]
		var active_mark := "● " if tab_id == _active_tab else ""
		var focus_mark := "▶ " if focused == tbtn else ""
		tbtn.text = focus_mark + active_mark + str(t["title"])

	for meta in _row_meta:
		var btn: Button = meta["button"]
		var is_focused := focused == btn
		var prefix := "▶ " if is_focused else ""
		var val_str := str(meta["value"])
		if meta["type"] == "step":
			val_str = "−  " + val_str + "  +"
		btn.text = "%s%s   [%s]" % [prefix, str(meta["label"]), val_str]

	var back_label := "Voltar ao Jogo (Esc)" if is_overlay else "Voltar ao Menu (Esc)"
	back_button.text = ("▶ " if focused == back_button else "") + back_label


func _on_back() -> void:
	AccessibilityManager.play_ui_sound("back")
	if is_overlay:
		AccessibilityManager.announce("Voltando ao jogo.", "voltar")
		closed.emit()
		queue_free()
		return
	AccessibilityManager.announce("Voltando ao menu principal.", "voltar")
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
