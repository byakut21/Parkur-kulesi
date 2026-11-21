extends Control
## Dokunmatik ekran kontrolleri (Android / dokunmatik tarayıcı):
##  - Ekranın sol yarısı: sanal joystick (parmağın değdiği yerde belirir)
##  - Sağ altta ZIPLA ve KAY butonları
##  - Sağ yarının geri kalanı: parmakla kaydırarak kamera
##  - Üstte duraklat butonu

signal pause_pressed

const STICK_RADIUS := 110.0
const KNOB_RADIUS := 48.0
const LOOK_SENS := 0.006

var target: Node  # player.gd (cam_yaw / cam_pitch)

var _stick_index := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _look_index := -1
var _buttons := {}  # action -> {center, radius, label, index}
var _pause_rect := Rect2()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_buttons = {
		"jump": {"label": "ZIPLA", "radius": 95.0, "index": -1, "center": Vector2.ZERO},
		"slide": {"label": "KAY", "radius": 75.0, "index": -1, "center": Vector2.ZERO},
	}
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var s := get_viewport_rect().size
	_buttons["jump"].center = Vector2(s.x - 150.0, s.y - 160.0)
	_buttons["slide"].center = Vector2(s.x - 330.0, s.y - 110.0)
	_pause_rect = Rect2(s.x * 0.5 - 45.0, 10.0, 90.0, 70.0)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
	elif event is InputEventScreenDrag:
		_touch_drag(event.index, event.position, event.relative)


func _touch_down(index: int, pos: Vector2) -> void:
	if get_tree().paused:
		return
	get_viewport().set_input_as_handled()
	if _pause_rect.grow(20.0).has_point(pos):
		pause_pressed.emit()
		return
	for action in _buttons:
		var b: Dictionary = _buttons[action]
		if pos.distance_to(b.center) <= b.radius * 1.25:
			b.index = index
			Input.action_press(action)
			queue_redraw()
			return
	var half := get_viewport_rect().size.x * 0.5
	if pos.x < half and _stick_index == -1:
		_stick_index = index
		_stick_origin = pos
		_stick_pos = pos
		queue_redraw()
	elif pos.x >= half and _look_index == -1:
		_look_index = index


func _touch_up(index: int) -> void:
	for action in _buttons:
		var b: Dictionary = _buttons[action]
		if b.index == index:
			b.index = -1
			Input.action_release(action)
			queue_redraw()
	if index == _stick_index:
		_stick_index = -1
		_apply_stick(Vector2.ZERO)
		queue_redraw()
	if index == _look_index:
		_look_index = -1


func _touch_drag(index: int, pos: Vector2, rel: Vector2) -> void:
	if index == _stick_index:
		var v := pos - _stick_origin
		if v.length() > STICK_RADIUS:
			# Parmak çok uzaklaşırsa joystick merkezi onu takip eder
			_stick_origin = pos - v.normalized() * STICK_RADIUS
			v = pos - _stick_origin
		_stick_pos = pos
		_apply_stick(v / STICK_RADIUS)
		queue_redraw()
	elif index == _look_index and target:
		target.cam_yaw -= rel.x * LOOK_SENS
		target.cam_pitch = clampf(target.cam_pitch - rel.y * LOOK_SENS, -1.25, 0.6)


func _apply_stick(v: Vector2) -> void:
	var dead := 0.15
	_set_axis("move_left", "move_right", v.x, dead)
	_set_axis("move_forward", "move_back", v.y, dead)


func _set_axis(neg: String, pos: String, value: float, dead: float) -> void:
	if value < -dead:
		Input.action_press(neg, clampf(-value, 0.0, 1.0))
		Input.action_release(pos)
	elif value > dead:
		Input.action_press(pos, clampf(value, 0.0, 1.0))
		Input.action_release(neg)
	else:
		Input.action_release(neg)
		Input.action_release(pos)


## Duraklatma / ölüm sonrası tüm basılı girişleri bırak.
func release_all() -> void:
	for action in _buttons:
		_buttons[action].index = -1
		Input.action_release(action)
	_stick_index = -1
	_look_index = -1
	_apply_stick(Vector2.ZERO)
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	# Joystick
	if _stick_index != -1:
		draw_circle(_stick_origin, STICK_RADIUS, Color(1, 1, 1, 0.12))
		draw_arc(_stick_origin, STICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.5), 3.0)
		var knob := _stick_origin + (_stick_pos - _stick_origin).limit_length(STICK_RADIUS)
		draw_circle(knob, KNOB_RADIUS, Color(1, 1, 1, 0.45))
	else:
		var s := get_viewport_rect().size
		var hint := Vector2(200.0, s.y - 190.0)
		draw_arc(hint, STICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.25), 3.0)
		draw_circle(hint, KNOB_RADIUS, Color(1, 1, 1, 0.15))
	# Butonlar
	for action in _buttons:
		var b: Dictionary = _buttons[action]
		var pressed: bool = b.index != -1
		var col := Color(0.2, 0.85, 1.0, 0.55 if pressed else 0.3) if action == "jump" else Color(1.0, 0.6, 0.2, 0.55 if pressed else 0.3)
		draw_circle(b.center, b.radius, col)
		draw_arc(b.center, b.radius, 0, TAU, 48, Color(1, 1, 1, 0.7), 3.0)
		var fs := 34 if action == "jump" else 28
		var w := font.get_string_size(b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, b.center + Vector2(-w * 0.5, fs * 0.35), b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	# Duraklat
	draw_rect(_pause_rect, Color(0, 0, 0, 0.3))
	var c := _pause_rect.get_center()
	draw_rect(Rect2(c.x - 16, c.y - 20, 11, 40), Color(1, 1, 1, 0.85))
	draw_rect(Rect2(c.x + 5, c.y - 20, 11, 40), Color(1, 1, 1, 0.85))
