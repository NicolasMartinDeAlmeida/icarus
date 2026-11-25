extends CanvasLayer

## Global overlay providing:
## 1) Full-screen colorblindness Daltonization shader
## 2) Dedicated Libras (VLibras-ready) window with synchronized captions
## 3) Caption / LSE sound-cue bar
## 4) Global Help modal (H or F1) and Repeat Last Message shortcut (M)

# Future Libras .ogv video streams can be mapped here without changing UI logic.
const LIBRAS_VIDEO_MAP: Dictionary = {
	"iniciar": "",
	"opcoes": "",
	"sair": "",
	"acessibilidade": "",
	"geral": "",
	"controles": "",
	"video": "",
	"audio": "",
	"voltar": "",
	"ajuda": "",
	"repetir": "",
	"avancar": "",
	"esquerda": "",
	"direita": "",
	"meia_volta": "",
	"mapa": "",
	"monstro": "",
	"vitoria": "",
	"derrota": "",
	"pausa": "",
	"onde_estou": "",
	"parede": "",
}

@onready var colorblind_rect: ColorRect = $ColorblindRect
@onready var libras_panel: PanelContainer = $LibrasPanel
@onready var libras_title: Label = $LibrasPanel/VBox/Header/TitleLabel
@onready var libras_frame: ColorRect = $LibrasPanel/VBox/MediaFrame
@onready var libras_video: VideoStreamPlayer = $LibrasPanel/VBox/MediaFrame/VideoStreamPlayer
@onready var libras_icon: TextureRect = $LibrasPanel/VBox/MediaFrame/FallbackBox/IconRect
@onready var libras_state_label: Label = $LibrasPanel/VBox/MediaFrame/FallbackBox/StateLabel
@onready var libras_caption: Label = $LibrasPanel/VBox/CaptionLabel
@onready var libras_repeat_btn: Button = $LibrasPanel/VBox/RepeatButton

@onready var caption_bar: PanelContainer = $CaptionBar
@onready var caption_label: Label = $CaptionBar/CaptionLabel

@onready var help_backdrop: ColorRect = $HelpBackdrop
@onready var help_panel: PanelContainer = $HelpBackdrop/Center/HelpPanel
@onready var help_title: Label = $HelpBackdrop/Center/HelpPanel/VBox/HelpTitle
@onready var help_body: Label = $HelpBackdrop/Center/HelpPanel/VBox/HelpBody
@onready var help_close_btn: Button = $HelpBackdrop/Center/HelpPanel/VBox/CloseHelpButton

var _caption_timer: Timer
var _previous_focus: Control = null


func _ready() -> void:
	_caption_timer = Timer.new()
	_caption_timer.one_shot = true
	_caption_timer.timeout.connect(_on_caption_timeout)
	add_child(_caption_timer)

	libras_repeat_btn.focus_mode = Control.FOCUS_NONE
	libras_repeat_btn.pressed.connect(func() -> void:
		AccessibilityManager.play_ui_sound("confirm")
		AccessibilityManager.repeat_last_message()
	)

	help_close_btn.pressed.connect(_close_help)
	help_backdrop.visible = false
	caption_bar.visible = false

	AccessibilityManager.settings_changed.connect(_apply_settings)
	AccessibilityManager.message_announced.connect(_on_message_announced)
	_apply_settings()


func is_help_open() -> bool:
	return help_backdrop.visible


func _unhandled_input(event: InputEvent) -> void:
	if AccessibilityManager.is_capturing_input:
		return
	if not (event is InputEventKey):
		return
	var kev := event as InputEventKey
	if not kev.pressed or kev.echo:
		return

	var help_action_pressed := InputMap.has_action("toggle_help") and event.is_action_pressed("toggle_help")
	var repeat_action_pressed := InputMap.has_action("repeat_description") and event.is_action_pressed("repeat_description")

	if help_backdrop.visible:
		if kev.keycode == KEY_ESCAPE or kev.keycode == KEY_F1 or kev.keycode == KEY_H or help_action_pressed:
			get_viewport().set_input_as_handled()
			_close_help()
		return

	if kev.keycode == KEY_F1 or kev.keycode == KEY_H or help_action_pressed:
		get_viewport().set_input_as_handled()
		_open_help()
	elif kev.keycode == KEY_M or repeat_action_pressed:
		get_viewport().set_input_as_handled()
		AccessibilityManager.repeat_last_message()


func _apply_settings() -> void:
	var mat := colorblind_rect.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("mode", AccessibilityManager.colorblind_mode)

	var theme := AccessibilityManager.build_theme()
	var pal := AccessibilityManager.get_palette()

	libras_panel.theme = theme
	caption_bar.theme = theme
	help_panel.theme = theme

	libras_panel.visible = AccessibilityManager.libras_enabled
	libras_title.add_theme_color_override("font_color", pal["accent"])
	libras_caption.add_theme_color_override("font_color", pal["text"])
	libras_state_label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05, 1.0))

	var body_sz := AccessibilityManager.get_scaled_font_size(14)
	var cap_sz := clampi(AccessibilityManager.get_scaled_font_size(13), 12, 22)
	libras_title.add_theme_font_size_override("font_size", cap_sz)
	libras_caption.add_theme_font_size_override("font_size", cap_sz)
	libras_state_label.add_theme_font_size_override("font_size", clampi(cap_sz, 12, 18))
	libras_repeat_btn.add_theme_font_size_override("font_size", cap_sz)

	caption_label.add_theme_font_size_override("font_size", clampi(body_sz, 14, 26))
	caption_label.add_theme_color_override("font_color", pal["text"])

	help_title.add_theme_font_size_override("font_size", mini(34, AccessibilityManager.get_scaled_font_size(22)))
	help_title.add_theme_color_override("font_color", pal["accent"])
	help_body.add_theme_font_size_override("font_size", clampi(AccessibilityManager.get_scaled_font_size(15), 14, 24))
	help_body.add_theme_color_override("font_color", pal["text"])

	if AccessibilityManager.caption_mode == 0:
		caption_bar.visible = false


func _on_message_announced(text: String, libras_key: String, is_sound_cue: bool) -> void:
	if not is_sound_cue:
		libras_caption.text = text
		_update_libras_media(libras_key, text)

	if AccessibilityManager.caption_mode == 0:
		caption_bar.visible = false
		return
	if is_sound_cue and AccessibilityManager.caption_mode < 2:
		return

	caption_label.text = text
	caption_bar.visible = true
	var speed_mult := 100.0 / float(maxi(50, AccessibilityManager.game_speed_percent))
	_caption_timer.start(clampf(4.5 * speed_mult, 2.5, 9.0))


func _update_libras_media(libras_key: String, fallback_text: String) -> void:
	var key := libras_key.strip_edges().to_lower()
	var video_path := str(LIBRAS_VIDEO_MAP.get(key, ""))
	if not video_path.is_empty() and ResourceLoader.exists(video_path):
		var stream := load(video_path)
		if stream != null:
			libras_video.stream = stream
			libras_video.visible = true
			libras_icon.visible = false
			libras_state_label.visible = false
			libras_video.play()
			return

	libras_video.stop()
	libras_video.visible = false
	libras_icon.visible = true
	libras_state_label.visible = true
	if not key.is_empty():
		libras_state_label.text = "Sinal em Libras:\n" + key.capitalize()
	elif not fallback_text.is_empty():
		libras_state_label.text = "Intérprete de Libras\n(Legenda sincronizada)"
	else:
		libras_state_label.text = "Espaço reservado\npara vídeos em Libras"


func _on_caption_timeout() -> void:
	caption_bar.visible = false


func _open_help() -> void:
	var owner := get_viewport().gui_get_focus_owner()
	if owner is Control:
		_previous_focus = owner
	help_backdrop.visible = true
	AccessibilityManager.play_ui_sound("confirm")
	AccessibilityManager.announce(
		"Ajuda aberta. Use Tab ou Setas para navegar, Enter ou Espaço para selecionar, Esc para voltar, M para repetir a fala, H ou F1 para ajuda.",
		"ajuda"
	)
	help_close_btn.grab_focus.call_deferred()


func _close_help() -> void:
	help_backdrop.visible = false
	AccessibilityManager.play_ui_sound("back")
	AccessibilityManager.announce("Ajuda fechada.", "voltar")
	if is_instance_valid(_previous_focus) and _previous_focus.is_inside_tree() and _previous_focus.visible:
		_previous_focus.grab_focus.call_deferred()
	_previous_focus = null
