extends Node

## Global accessibility, localization, audio feedback, and local settings manager.
## Stores preferences only on the user's device (no personal data collected).

signal settings_changed
signal message_announced(text: String, libras_key: String, is_sound_cue: bool)

const SETTINGS_PATH := "user://settings.cfg"

const FONT_REGULAR_PATH := "res://assets/Font/PixeloidSans-lxa3y.ttf"
const FONT_BOLD_PATH := "res://assets/Font/PixeloidSansBold-1jpBg.ttf"

const CAPTION_MODES: Array[String] = ["Desligado", "Padrão", "LSE (com sons)"]
const COLORBLIND_MODES: Array[String] = ["Nenhuma", "Protanopia", "Deuteranopia", "Tritanopia"]
const FONT_STEPS: Array[int] = [100, 125, 150, 175, 200]
const SPEED_STEPS: Array[int] = [50, 75, 100, 125, 150]
const VOLUME_STEPS: Array[int] = [0, 25, 50, 75, 100]

const REMAPPABLE_ACTIONS: Array[Dictionary] = [
	{"action": "move_forward", "label": "Avançar", "default_key": KEY_W},
	{"action": "turn_left", "label": "Virar à esquerda", "default_key": KEY_A},
	{"action": "turn_right", "label": "Virar à direita", "default_key": KEY_D},
	{"action": "turn_around", "label": "Meia-volta", "default_key": KEY_S},
	{"action": "toggle_map", "label": "Abrir Mapa 2D", "default_key": KEY_E},
	{"action": "repeat_description", "label": "Ouvir / repetir descrição", "default_key": KEY_M},
	{"action": "announce_position", "label": "Onde estou", "default_key": KEY_P},
	{"action": "toggle_help", "label": "Abrir ajuda", "default_key": KEY_H},
]

# Persisted settings (aligned with prototype defaults)
var language: String = "pt_BR"
var caption_mode: int = 2
var libras_enabled: bool = true
var tts_enabled: bool = true
var audio_description: bool = true
var minimap_visible: bool = false
var font_scale_percent: int = 100
var colorblind_mode: int = 0
var game_speed_percent: int = 100
var high_contrast: bool = true
var fullscreen: bool = false
var reduced_motion: bool = false
var sfx_enabled: bool = true
var sfx_volume_percent: int = 60

# Runtime state
var last_message: String = ""
var last_libras_key: String = ""
var is_capturing_input: bool = false
var suppress_focus_announcements: bool = false

var _font_regular: Font
var _font_bold: Font
var _cached_tts_voice: String = ""
var _tts_checked: bool = false

var _audio_player: AudioStreamPlayer
var _audio_gen: AudioStreamGenerator
var _phase: float = 0.0


func _ready() -> void:
	_font_regular = load(FONT_REGULAR_PATH)
	_font_bold = load(FONT_BOLD_PATH)
	_setup_audio()
	_ensure_default_actions()
	load_settings()
	apply_window_mode()


func _setup_audio() -> void:
	_audio_gen = AudioStreamGenerator.new()
	_audio_gen.mix_rate = 22050.0
	_audio_gen.buffer_length = 0.35
	_audio_player = AudioStreamPlayer.new()
	_audio_player.stream = _audio_gen
	add_child(_audio_player)


func _ensure_default_actions() -> void:
	for entry in REMAPPABLE_ACTIONS:
		var action_name: String = entry["action"]
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		if InputMap.action_get_events(action_name).is_empty():
			var ev := InputEventKey.new()
			ev.physical_keycode = entry["default_key"]
			InputMap.action_add_event(action_name, ev)

	# Allow WASD in addition to Arrow keys for all menus and modals.
	_ensure_ui_key("ui_up", KEY_W)
	_ensure_ui_key("ui_down", KEY_S)
	_ensure_ui_key("ui_left", KEY_A)
	_ensure_ui_key("ui_right", KEY_D)


func _ensure_ui_key(action_name: String, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		return
	for ev in InputMap.action_get_events(action_name):
		if ev is InputEventKey:
			var kev := ev as InputEventKey
			if kev.physical_keycode == keycode or kev.keycode == keycode:
				return
	var new_ev := InputEventKey.new()
	new_ev.physical_keycode = keycode
	InputMap.action_add_event(action_name, new_ev)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SETTINGS_PATH)
	if err != OK:
		return

	language = str(cfg.get_value("general", "language", language))
	caption_mode = clampi(int(cfg.get_value("general", "caption_mode", caption_mode)), 0, CAPTION_MODES.size() - 1)

	libras_enabled = bool(cfg.get_value("accessibility", "libras_enabled", libras_enabled))
	tts_enabled = bool(cfg.get_value("accessibility", "tts_enabled", tts_enabled))
	audio_description = bool(cfg.get_value("accessibility", "audio_description", audio_description))
	minimap_visible = bool(cfg.get_value("accessibility", "minimap_visible", minimap_visible))
	font_scale_percent = _nearest_step(int(cfg.get_value("accessibility", "font_scale_percent", font_scale_percent)), FONT_STEPS)
	colorblind_mode = clampi(int(cfg.get_value("accessibility", "colorblind_mode", colorblind_mode)), 0, COLORBLIND_MODES.size() - 1)
	game_speed_percent = _nearest_step(int(cfg.get_value("accessibility", "game_speed_percent", game_speed_percent)), SPEED_STEPS)
	high_contrast = bool(cfg.get_value("accessibility", "high_contrast", high_contrast))

	fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
	reduced_motion = bool(cfg.get_value("video", "reduced_motion", reduced_motion))

	sfx_enabled = bool(cfg.get_value("audio", "sfx_enabled", sfx_enabled))
	sfx_volume_percent = clampi(int(cfg.get_value("audio", "sfx_volume_percent", sfx_volume_percent)), 0, 100)

	for entry in REMAPPABLE_ACTIONS:
		var action_name: String = entry["action"]
		var saved_code := int(cfg.get_value("controls", action_name, -1))
		if saved_code > 0:
			var ev := InputEventKey.new()
			ev.physical_keycode = saved_code as Key
			InputMap.action_erase_events(action_name)
			InputMap.action_add_event(action_name, ev)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "language", language)
	cfg.set_value("general", "caption_mode", caption_mode)

	cfg.set_value("accessibility", "libras_enabled", libras_enabled)
	cfg.set_value("accessibility", "tts_enabled", tts_enabled)
	cfg.set_value("accessibility", "audio_description", audio_description)
	cfg.set_value("accessibility", "minimap_visible", minimap_visible)
	cfg.set_value("accessibility", "font_scale_percent", font_scale_percent)
	cfg.set_value("accessibility", "colorblind_mode", colorblind_mode)
	cfg.set_value("accessibility", "game_speed_percent", game_speed_percent)
	cfg.set_value("accessibility", "high_contrast", high_contrast)

	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "reduced_motion", reduced_motion)

	cfg.set_value("audio", "sfx_enabled", sfx_enabled)
	cfg.set_value("audio", "sfx_volume_percent", sfx_volume_percent)

	for entry in REMAPPABLE_ACTIONS:
		var action_name: String = entry["action"]
		var events := InputMap.action_get_events(action_name)
		if not events.is_empty() and events[0] is InputEventKey:
			var kev := events[0] as InputEventKey
			var code: int = kev.physical_keycode if kev.physical_keycode != KEY_NONE else kev.keycode
			cfg.set_value("controls", action_name, code)

	cfg.save(SETTINGS_PATH)


func _nearest_step(value: int, steps: Array[int]) -> int:
	var best: int = steps[0]
	var best_diff: int = absi(value - best)
	for s in steps:
		var diff: int = absi(value - s)
		if diff < best_diff:
			best = s
			best_diff = diff
	return best


func emit_settings_changed(save: bool = true) -> void:
	if save:
		save_settings()
	settings_changed.emit()


func set_libras_enabled(enabled: bool) -> void:
	libras_enabled = enabled
	emit_settings_changed()


func apply_window_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var target := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != target:
		DisplayServer.window_set_mode(target)


func reset_controls_to_default() -> void:
	for entry in REMAPPABLE_ACTIONS:
		var action_name: String = entry["action"]
		InputMap.action_erase_events(action_name)
		var ev := InputEventKey.new()
		ev.physical_keycode = entry["default_key"]
		InputMap.action_add_event(action_name, ev)
	emit_settings_changed()


func reset_all_settings() -> void:
	language = "pt_BR"
	caption_mode = 2
	libras_enabled = true
	tts_enabled = true
	audio_description = true
	font_scale_percent = 100
	colorblind_mode = 0
	game_speed_percent = 100
	high_contrast = true
	fullscreen = false
	reduced_motion = false
	sfx_enabled = true
	sfx_volume_percent = 60
	reset_controls_to_default()
	apply_window_mode()
	emit_settings_changed()


func get_action_key_label(action_name: String) -> String:
	var events := InputMap.action_get_events(action_name)
	for ev in events:
		if ev is InputEventKey:
			var kev := ev as InputEventKey
			var code: Key = kev.physical_keycode if kev.physical_keycode != KEY_NONE else kev.keycode
			return OS.get_keycode_string(code)
	return "Sem tecla"


func remap_action_key(action_name: String, event: InputEventKey) -> Dictionary:
	var new_code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	if new_code == KEY_NONE:
		return {"ok": false, "reason": "Tecla inválida."}
	if new_code == KEY_ESCAPE or new_code == KEY_TAB:
		return {"ok": false, "reason": "Esc e Tab são reservados para navegação."}

	# Prevent duplicate bindings by swapping with any conflicting remappable action.
	var old_events := InputMap.action_get_events(action_name)
	var swapped_with := ""
	for entry in REMAPPABLE_ACTIONS:
		var other_name: String = entry["action"]
		if other_name == action_name:
			continue
		var other_events := InputMap.action_get_events(other_name)
		for oev in other_events:
			if oev is InputEventKey:
				var okev := oev as InputEventKey
				var ocode: Key = okev.physical_keycode if okev.physical_keycode != KEY_NONE else okev.keycode
				if ocode == new_code:
					InputMap.action_erase_events(other_name)
					for old_ev in old_events:
						InputMap.action_add_event(other_name, old_ev.duplicate())
					swapped_with = entry["label"]
					break

	var new_ev := InputEventKey.new()
	new_ev.physical_keycode = new_code
	InputMap.action_erase_events(action_name)
	InputMap.action_add_event(action_name, new_ev)
	emit_settings_changed()

	return {
		"ok": true,
		"key_name": OS.get_keycode_string(new_code),
		"swapped_with": swapped_with,
	}


func get_caption_mode_label() -> String:
	return CAPTION_MODES[clampi(caption_mode, 0, CAPTION_MODES.size() - 1)]


func get_colorblind_mode_label() -> String:
	return COLORBLIND_MODES[clampi(colorblind_mode, 0, COLORBLIND_MODES.size() - 1)]


func _get_tts_voice() -> String:
	if _tts_checked:
		return _cached_tts_voice
	_tts_checked = true
	if DisplayServer.get_name() == "headless":
		return ""
	var voices: Array = DisplayServer.tts_get_voices()
	if voices.is_empty():
		return ""
	for v in voices:
		var lang := str(v.get("language", "")).to_lower()
		if lang.begins_with("pt"):
			_cached_tts_voice = str(v.get("id", ""))
			return _cached_tts_voice
	_cached_tts_voice = str(voices[0].get("id", ""))
	return _cached_tts_voice


func announce(text: String, libras_key: String = "", interrupt: bool = true) -> void:
	var clean := text.strip_edges()
	if clean.is_empty():
		return
	last_message = clean
	last_libras_key = libras_key
	message_announced.emit(clean, libras_key, false)

	if not tts_enabled:
		return
	var voice := _get_tts_voice()
	if voice.is_empty():
		return
	if interrupt:
		DisplayServer.tts_stop()
	DisplayServer.tts_speak(clean, voice, 75, 1.0, 1.0, 0, interrupt)


func announce_sound_cue(cue_text: String) -> void:
	if caption_mode == 2:
		message_announced.emit(cue_text, "", true)


func repeat_last_message() -> void:
	if last_message.is_empty():
		announce("Nenhuma mensagem recente para repetir.", "repetir")
		return
	announce(last_message, last_libras_key, true)


func play_ui_sound(kind: String) -> void:
	if not sfx_enabled or sfx_volume_percent <= 0:
		return
	if DisplayServer.get_name() == "headless":
		return
	if not _audio_player.playing:
		_audio_player.play()
	var playback := _audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var freq := 440.0
	var duration := 0.055
	var wave := 0 # 0=sine, 1=square
	match kind:
		"focus":
			freq = 520.0
			duration = 0.035
		"confirm":
			freq = 740.0
			duration = 0.08
		"back":
			freq = 360.0
			duration = 0.08
		"adjust":
			freq = 640.0
			duration = 0.06
		"error":
			freq = 160.0
			duration = 0.12
			wave = 1

	var sample_rate: float = _audio_gen.mix_rate
	var total_frames: int = mini(int(sample_rate * duration), playback.get_frames_available())
	var gain: float = (float(sfx_volume_percent) / 100.0) * 0.22
	var increment: float = freq / sample_rate

	for i in range(total_frames):
		var env: float = 1.0 - (float(i) / float(maxi(1, total_frames)))
		var sample_val: float
		if wave == 1:
			sample_val = (1.0 if _phase < 0.5 else -1.0) * gain * env
		else:
			sample_val = sin(_phase * TAU) * gain * env
		playback.push_frame(Vector2(sample_val, sample_val))
		_phase = fmod(_phase + increment, 1.0)


func play_game_sound(kind: String, pan: float = 0.0) -> void:
	if not sfx_enabled or sfx_volume_percent <= 0:
		return
	if DisplayServer.get_name() == "headless":
		return
	if not _audio_player.playing:
		_audio_player.play()
	var playback := _audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var segments: Array[Dictionary] = []
	match kind:
		"step":
			segments = [{"freq": 190.0, "dur": 0.05, "wave": 0, "vol": 0.85}]
		"turn":
			segments = [{"freq": 320.0, "dur": 0.04, "wave": 0, "vol": 0.70}]
		"wall":
			segments = [{"freq": 115.0, "dur": 0.14, "wave": 1, "vol": 0.90}]
		"ariadne":
			segments = [
				{"freq": 523.25, "dur": 0.06, "wave": 0, "vol": 0.65},
				{"freq": 659.25, "dur": 0.08, "wave": 0, "vol": 0.75},
			]
		"monster_far":
			segments = [{"freq": 110.0, "dur": 0.09, "wave": 0, "vol": 0.65}]
		"monster_near":
			segments = [
				{"freq": 98.0, "dur": 0.07, "wave": 0, "vol": 0.85},
				{"freq": 0.0, "dur": 0.03, "wave": 0, "vol": 0.0},
				{"freq": 78.0, "dur": 0.09, "wave": 0, "vol": 0.95},
			]
		"monster_danger":
			segments = [
				{"freq": 220.0, "dur": 0.06, "wave": 1, "vol": 0.85},
				{"freq": 0.0, "dur": 0.03, "wave": 0, "vol": 0.0},
				{"freq": 180.0, "dur": 0.09, "wave": 1, "vol": 0.95},
			]
		"map_open":
			segments = [
				{"freq": 440.0, "dur": 0.05, "wave": 0, "vol": 0.75},
				{"freq": 660.0, "dur": 0.07, "wave": 0, "vol": 0.80},
			]
		"map_close":
			segments = [
				{"freq": 560.0, "dur": 0.05, "wave": 0, "vol": 0.70},
				{"freq": 380.0, "dur": 0.07, "wave": 0, "vol": 0.75},
			]
		"victory":
			segments = [
				{"freq": 523.25, "dur": 0.08, "wave": 0, "vol": 0.85},
				{"freq": 659.25, "dur": 0.08, "wave": 0, "vol": 0.90},
				{"freq": 783.99, "dur": 0.14, "wave": 0, "vol": 1.0},
			]
		"defeat":
			segments = [
				{"freq": 240.0, "dur": 0.09, "wave": 1, "vol": 0.85},
				{"freq": 180.0, "dur": 0.09, "wave": 1, "vol": 0.85},
				{"freq": 120.0, "dur": 0.14, "wave": 1, "vol": 0.95},
			]
		_:
			return

	var clamped_pan := clampf(pan, -1.0, 1.0)
	# Keep minimum 0.20 on each channel so unilateral hearing users still perceive the cue.
	var left_gain := clampf(1.0 - maxf(0.0, clamped_pan) * 0.75, 0.20, 1.0)
	var right_gain := clampf(1.0 + minf(0.0, clamped_pan) * 0.75, 0.20, 1.0)

	var sample_rate: float = _audio_gen.mix_rate
	var base_gain: float = (float(sfx_volume_percent) / 100.0) * 0.22
	for seg in segments:
		var freq: float = float(seg["freq"])
		var dur: float = float(seg["dur"])
		var wave: int = int(seg["wave"])
		var seg_vol: float = float(seg["vol"])
		var total_frames: int = mini(int(sample_rate * dur), playback.get_frames_available())
		if total_frames <= 0:
			break
		var increment: float = freq / sample_rate
		for i in range(total_frames):
			var sample_val := 0.0
			if freq > 0.0:
				var env: float = 1.0 - (float(i) / float(maxi(1, total_frames)))
				if wave == 1:
					sample_val = (1.0 if _phase < 0.5 else -1.0) * base_gain * seg_vol * env
				else:
					sample_val = sin(_phase * TAU) * base_gain * seg_vol * env
				_phase = fmod(_phase + increment, 1.0)
			playback.push_frame(Vector2(sample_val * left_gain, sample_val * right_gain))


func get_palette() -> Dictionary:
	if high_contrast:
		return {
			"bg": Color(0.0, 0.0, 0.0, 1.0),
			"panel_bg": Color(0.04, 0.04, 0.04, 0.96),
			"item_bg": Color(0.06, 0.06, 0.06, 1.0),
			"item_hover": Color(0.16, 0.16, 0.16, 1.0),
			"focus_bg": Color(0.22, 0.10, 0.0, 1.0),
			"active_bg": Color(1.0, 0.48, 0.0, 1.0),
			"text": Color(1.0, 1.0, 1.0, 1.0),
			"muted": Color(1.0, 0.86, 0.72, 1.0),
			"accent": Color(1.0, 0.48, 0.0, 1.0),
			"accent_text": Color(0.0, 0.0, 0.0, 1.0),
			"border": Color(1.0, 1.0, 1.0, 1.0),
			"panel_border": Color(1.0, 0.55, 0.10, 1.0),
			"focus_border": Color(1.0, 0.55, 0.0, 1.0),
			"frieze": Color(0.45, 0.50, 1.0, 1.0),
			"ok": Color(0.49, 1.0, 0.63, 1.0),
			"err": Color(1.0, 0.48, 0.48, 1.0),
			"scrim": Color(0.0, 0.0, 0.0, 0.88),
		}
	return {
		"bg": Color(0.04, 0.04, 0.07, 1.0),
		"panel_bg": Color(0.05, 0.05, 0.09, 0.94),
		"item_bg": Color(0.07, 0.07, 0.12, 1.0),
		"item_hover": Color(0.12, 0.13, 0.22, 1.0),
		"focus_bg": Color(0.20, 0.11, 0.05, 1.0),
		"active_bg": Color(0.88, 0.48, 0.18, 1.0),
		"text": Color(0.96, 0.93, 0.89, 1.0),
		"muted": Color(0.89, 0.65, 0.47, 1.0),
		"accent": Color(0.92, 0.50, 0.18, 1.0),
		"accent_text": Color(0.04, 0.04, 0.04, 1.0),
		"border": Color(0.28, 0.34, 0.72, 1.0),
		"panel_border": Color(0.77, 0.45, 0.29, 1.0),
		"focus_border": Color(1.0, 0.52, 0.10, 1.0),
		"frieze": Color(0.25, 0.29, 0.72, 1.0),
		"ok": Color(0.50, 0.92, 0.62, 1.0),
		"err": Color(0.95, 0.45, 0.45, 1.0),
		"scrim": Color(0.03, 0.03, 0.06, 0.78),
	}


func get_scaled_font_size(base_size: int = 16) -> int:
	return int(round(float(base_size) * (float(font_scale_percent) / 100.0)))


func build_theme() -> Theme:
	var pal := get_palette()
	var theme := Theme.new()
	var body_size := get_scaled_font_size(16)
	var title_size := mini(44, get_scaled_font_size(24))

	if _font_regular != null:
		theme.default_font = _font_regular
	theme.default_font_size = body_size

	var btn_normal := _make_box(pal["item_bg"], pal["border"], 2, 10, 6)
	var btn_hover := _make_box(pal["item_hover"], pal["accent"], 3, 10, 6)
	var btn_pressed := _make_box(pal["active_bg"], pal["border"], 3, 10, 6)
	var btn_focus := _make_box(pal["focus_bg"], pal["focus_border"], 4, 10, 6)
	var btn_disabled := _make_box(pal["bg"], pal["muted"], 1, 10, 6)

	theme.set_stylebox("normal", "Button", btn_normal)
	theme.set_stylebox("hover", "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_stylebox("focus", "Button", btn_focus)
	theme.set_stylebox("disabled", "Button", btn_disabled)

	theme.set_color("font_color", "Button", pal["text"])
	theme.set_color("font_hover_color", "Button", pal["text"])
	theme.set_color("font_focus_color", "Button", pal["text"])
	theme.set_color("font_pressed_color", "Button", pal["accent_text"])
	theme.set_color("font_disabled_color", "Button", pal["muted"])
	theme.set_font_size("font_size", "Button", body_size)
	if _font_bold != null:
		theme.set_font("font", "Button", _font_bold)

	theme.set_color("font_color", "Label", pal["text"])
	theme.set_font_size("font_size", "Label", body_size)

	theme.set_color("font_color", "HeaderLabel", pal["accent"])
	theme.set_font_size("font_size", "HeaderLabel", title_size)

	var panel_box := _make_box(pal["panel_bg"], pal["panel_border"], 3, 12, 12)
	theme.set_stylebox("panel", "PanelContainer", panel_box)

	return theme


func _make_box(bg_color: Color, border_color: Color, border_width: int, pad_x: int, pad_y: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


func connect_accessible_button(btn: Button, spoken_label: String, hint: String = "", libras_key: String = "") -> void:
	if not hint.is_empty():
		btn.tooltip_text = hint
	if "accessibility_name" in btn:
		btn.set("accessibility_name", spoken_label)
	btn.focus_entered.connect(func() -> void:
		if suppress_focus_announcements:
			return
		play_ui_sound("focus")
		var msg := spoken_label
		if not hint.is_empty():
			msg += ". " + hint
		announce(msg, libras_key, true)
	)
