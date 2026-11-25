extends Control

## Accessible Main Menu controller for Labirinto de Ícaro.

@onready var contrast_scrim: ColorRect = $ContrastScrim
@onready var vlibras_button: Button = $VLibrasButton
@onready var menu_panel: PanelContainer = $MenuPanel
@onready var subtitle_label: Label = $MenuPanel/VBox/SubtitleLabel
@onready var start_button: Button = $MenuPanel/VBox/StartButton
@onready var options_button: Button = $MenuPanel/VBox/OptionsButton
@onready var quit_button: Button = $MenuPanel/VBox/QuitButton
@onready var footer_bar: PanelContainer = $FooterBar
@onready var footer_label: Label = $FooterBar/FooterLabel

const BASE_LABELS: Dictionary = {
	"start": "Iniciar",
	"options": "Opções",
	"quit": "Sair",
}


func _ready() -> void:
	start_button.pressed.connect(_on_start)
	options_button.pressed.connect(_on_options)
	quit_button.pressed.connect(_on_quit)
	vlibras_button.pressed.connect(_on_toggle_vlibras)

	AccessibilityManager.settings_changed.connect(_apply_accessibility)

	_wire_button_accessibility(start_button, "start", "Iniciar o jogo de labirinto", "iniciar")
	_wire_button_accessibility(options_button, "options", "Abrir menu de opções e acessibilidade", "opcoes")
	_wire_button_accessibility(quit_button, "quit", "Fechar o jogo", "sair")
	_wire_vlibras_button()
	_setup_focus_neighbors()

	_apply_accessibility()

	# Grab focus silently on startup and announce a single clear welcome message.
	AccessibilityManager.suppress_focus_announcements = true
	start_button.grab_focus()
	_update_focus_prefixes()
	AccessibilityManager.suppress_focus_announcements = false

	AccessibilityManager.announce.call_deferred(
		"Menu principal de Ícaro. Botão Iniciar selecionado. Use as setas ou Tab para navegar, Enter para selecionar, ou H para ajuda.",
		"iniciar"
	)


func _exit_tree() -> void:
	if AccessibilityManager.settings_changed.is_connected(_apply_accessibility):
		AccessibilityManager.settings_changed.disconnect(_apply_accessibility)


func _wire_button_accessibility(btn: Button, key: String, hint: String, libras_key: String) -> void:
	AccessibilityManager.connect_accessible_button(btn, BASE_LABELS[key], hint, libras_key)
	btn.focus_entered.connect(_update_focus_prefixes)
	btn.focus_exited.connect(_update_focus_prefixes)


func _wire_vlibras_button() -> void:
	if "accessibility_name" in vlibras_button:
		vlibras_button.set("accessibility_name", "Alternar Janela de Libras")
	vlibras_button.tooltip_text = "Ligar ou desligar a Janela de Libras"
	vlibras_button.focus_entered.connect(func() -> void:
		_update_focus_prefixes()
		if AccessibilityManager.suppress_focus_announcements:
			return
		AccessibilityManager.play_ui_sound("focus")
		var state := "Ligado" if AccessibilityManager.libras_enabled else "Desligado"
		AccessibilityManager.announce("Botão VLibras: " + state + ". Pressione Enter para alternar.", "acessibilidade")
	)
	vlibras_button.focus_exited.connect(_update_focus_prefixes)


func _setup_focus_neighbors() -> void:
	var order: Array[Button] = [start_button, options_button, quit_button, vlibras_button]
	for i in range(order.size()):
		var prev_btn := order[(i - 1 + order.size()) % order.size()]
		var next_btn := order[(i + 1) % order.size()]
		order[i].focus_neighbor_top = order[i].get_path_to(prev_btn)
		order[i].focus_neighbor_bottom = order[i].get_path_to(next_btn)
		order[i].focus_previous = order[i].get_path_to(prev_btn)
		order[i].focus_next = order[i].get_path_to(next_btn)


func _apply_accessibility() -> void:
	var th := AccessibilityManager.build_theme()
	var pal := AccessibilityManager.get_palette()
	theme = th
	menu_panel.theme = th
	footer_bar.theme = th

	contrast_scrim.color = Color(0.0, 0.0, 0.0, 0.58 if AccessibilityManager.high_contrast else 0.30)
	subtitle_label.add_theme_color_override("font_color", pal["accent"])
	subtitle_label.add_theme_font_size_override("font_size", mini(32, AccessibilityManager.get_scaled_font_size(18)))

	var footer_sz := clampi(AccessibilityManager.get_scaled_font_size(14), 12, 22)
	footer_label.add_theme_font_size_override("font_size", footer_sz)
	footer_label.add_theme_color_override("font_color", pal["muted"])

	_update_focus_prefixes()


func _update_focus_prefixes() -> void:
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	start_button.text = ("▶ " if focused == start_button else "") + BASE_LABELS["start"]
	options_button.text = ("▶ " if focused == options_button else "") + BASE_LABELS["options"]
	quit_button.text = ("▶ " if focused == quit_button else "") + BASE_LABELS["quit"]
	var v_state := "Ligado" if AccessibilityManager.libras_enabled else "Desligado"
	vlibras_button.text = ("▶ " if focused == vlibras_button else "") + "VLibras: " + v_state


func _on_start() -> void:
	AccessibilityManager.play_ui_sound("confirm")
	AccessibilityManager.announce("Iniciando jogo.", "iniciar")
	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_options() -> void:
	AccessibilityManager.play_ui_sound("confirm")
	AccessibilityManager.announce("Abrindo opções.", "opcoes")
	get_tree().change_scene_to_file("res://scenes/options.tscn")


func _on_quit() -> void:
	AccessibilityManager.play_ui_sound("back")
	AccessibilityManager.announce("Saindo do jogo. Até logo.", "sair")
	get_tree().quit()


func _on_toggle_vlibras() -> void:
	AccessibilityManager.play_ui_sound("adjust")
	AccessibilityManager.set_libras_enabled(not AccessibilityManager.libras_enabled)
	var state := "Ligado" if AccessibilityManager.libras_enabled else "Desligado"
	AccessibilityManager.announce("Janela de Libras: " + state, "acessibilidade")
	_update_focus_prefixes()
