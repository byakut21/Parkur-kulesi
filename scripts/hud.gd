extends CanvasLayer
## Ekran arayüzü: yükseklik, skor, lav uyarısı, menü ve oyun sonu ekranı.

var _stats: Label
var _lava: Label
var _center: Label
var _sub: Label
var _hint: Label
var _toast: Label
var _toast_t := 0.0
var _dim: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim = ColorRect.new()
	_dim.color = Color(0.05, 0.03, 0.1, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	_stats = _label(30, Vector2(24, 18))
	_lava = _label(30, Vector2(0, 18))
	_lava.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_lava.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lava.offset_left = -520
	_lava.offset_right = -24

	_center = _label(84, Vector2.ZERO)
	_center.set_anchors_preset(Control.PRESET_CENTER)
	_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center.offset_left = -640
	_center.offset_right = 640
	_center.offset_top = -170
	_center.offset_bottom = -40

	_sub = _label(30, Vector2.ZERO)
	_sub.set_anchors_preset(Control.PRESET_CENTER)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.offset_left = -640
	_sub.offset_right = 640
	_sub.offset_top = -30
	_sub.offset_bottom = 240

	_toast = _label(40, Vector2.ZERO)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.offset_left = -400
	_toast.offset_right = 400
	_toast.offset_top = 90
	_toast.modulate = Color(0.6, 1.0, 1.0)

	_hint = _label(20, Vector2.ZERO)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.offset_top = -40
	_hint.offset_bottom = -12
	_hint.text = "WASD: koş   Fare: kamera   Boşluk: zıpla (duvara değerken: duvar zıplama)   Shift/C: kay / çömel   Esc: duraklat"
	_hint.modulate = Color(1, 1, 1, 0.8)


func _label(size: int, pos: Vector2) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", maxi(4, size / 6))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t * 2.0, 0.0, 1.0)
		if _toast_t <= 0.0:
			_toast.text = ""


func set_stats(height: float, score: int, best: int, gems: int, time: float) -> void:
	_stats.text = "Yükseklik: %d m\nSkor: %d\nKristal: %d\nSüre: %d sn\nEn iyi: %d" % [int(height), score, gems, int(time), best]


func set_lava(distance: float, speed: float) -> void:
	_lava.text = "Lav %.1f m aşağıda\nHız: %.1f m/sn" % [maxf(distance, 0.0), speed]
	if distance < 6.0:
		_lava.modulate = Color(1.0, 0.35, 0.25)
	elif distance < 12.0:
		_lava.modulate = Color(1.0, 0.8, 0.3)
	else:
		_lava.modulate = Color(1, 1, 1)


func toast(text: String) -> void:
	_toast.text = text
	_toast_t = 1.2


func show_overlay(title: String, sub: String) -> void:
	_dim.visible = true
	_center.text = title
	_sub.text = sub
	_center.visible = true
	_sub.visible = true


func hide_overlay() -> void:
	_dim.visible = false
	_center.visible = false
	_sub.visible = false
