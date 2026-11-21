extends Node3D
## Oyunun ana düğümü: dünyayı kurar, lavı yükseltir, skoru ve oyun durumunu yönetir.

const Player := preload("res://scripts/player.gd")
const Tower := preload("res://scripts/tower.gd")
const Hud := preload("res://scripts/hud.gd")

const SAVE_PATH := "user://best_score.save"
const LAVA_START_Y := -6.0
const LAVA_GRACE := 4.0
const LAVA_BASE_SPEED := 0.7
const LAVA_SPEED_GROWTH := 0.008
const LAVA_CATCHUP_DIST := 22.0
const GEM_SCORE := 50

enum State { MENU, PLAYING, PAUSED, DEAD }

## Yeniden başlatmada menüyü atlamak için sahne yeniden yüklense de korunur.
static var skip_menu := false

var state := State.MENU
var player: CharacterBody3D
var tower: Node3D
var hud: CanvasLayer
var lava: MeshInstance3D
var lava_light: OmniLight3D
var lava_y := LAVA_START_Y
var lava_speed := 0.0
var elapsed := 0.0
var max_height := 0.0
var gems := 0
var best := 0
var _was_captured := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_load_best()
	_build_environment()

	tower = Tower.new()
	tower.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(tower)
	tower.gem_collected.connect(_on_gem)

	player = Player.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.position = Vector3(Tower.RING_RADIUS, 0.1, -1.5)
	add_child(player)
	# Kamera spiralin ilerleme yönüne (teğet, +Z) baksın
	player.cam_yaw = PI
	player.wall_jumped.connect(func(): hud.toast("Duvar zıplama!"))

	_build_lava()

	hud = Hud.new()
	add_child(hud)

	tower.update_for(0.0, lava_y)
	if skip_menu:
		skip_menu = false
		_start()
	else:
		hud.show_overlay("PARKUR KULESİ", "Lav yükseliyor! Kuleye tırman, olabildiğince yükseğe çık.\n\nBaşlamak için TIKLA ya da ENTER'a bas\n\nEn iyi skor: %d" % best)
	_update_hud()


# ---------------------------------------------------------------- kurulum

func _setup_input() -> void:
	if InputMap.has_action("jump"):
		return
	_action("move_forward", [KEY_W, KEY_UP], [], [[JOY_AXIS_LEFT_Y, -1.0]])
	_action("move_back", [KEY_S, KEY_DOWN], [], [[JOY_AXIS_LEFT_Y, 1.0]])
	_action("move_left", [KEY_A, KEY_LEFT], [], [[JOY_AXIS_LEFT_X, -1.0]])
	_action("move_right", [KEY_D, KEY_RIGHT], [], [[JOY_AXIS_LEFT_X, 1.0]])
	_action("look_left", [KEY_Q], [], [[JOY_AXIS_RIGHT_X, -1.0]])
	_action("look_right", [KEY_E], [], [[JOY_AXIS_RIGHT_X, 1.0]])
	_action("look_up", [], [], [[JOY_AXIS_RIGHT_Y, -1.0]])
	_action("look_down", [], [], [[JOY_AXIS_RIGHT_Y, 1.0]])
	_action("jump", [KEY_SPACE], [JOY_BUTTON_A], [])
	_action("slide", [KEY_SHIFT, KEY_C, KEY_CTRL], [JOY_BUTTON_B, JOY_BUTTON_RIGHT_SHOULDER], [])
	_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START], [])
	_action("restart", [KEY_R, KEY_ENTER], [JOY_BUTTON_Y], [])


func _action(action_name: String, keys: Array, buttons: Array, axes: Array) -> void:
	InputMap.add_action(action_name, 0.25)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action_name, e)
	for b in buttons:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		InputMap.action_add_event(action_name, e)
	for a in axes:
		var e := InputEventJoypadMotion.new()
		e.axis = a[0]
		e.axis_value = a[1]
		InputMap.action_add_event(action_name, e)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.18, 0.24, 0.5)
	sm.sky_horizon_color = Color(0.95, 0.6, 0.45)
	sm.ground_horizon_color = Color(0.9, 0.45, 0.3)
	sm.ground_bottom_color = Color(0.35, 0.08, 0.04)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.85, 0.55, 0.45)
	env.fog_density = 0.006
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(35), 0)
	sun.light_energy = 1.1
	sun.light_color = Color(1.0, 0.92, 0.82)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)


func _build_lava() -> void:
	lava = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(240, 240)
	lava.mesh = pm
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
	vec2 uv = UV * 60.0;
	float n = sin(uv.x * 1.3 + TIME * 1.4) * sin(uv.y * 1.1 - TIME * 1.1);
	n += 0.6 * sin((uv.x + uv.y) * 2.3 + TIME * 2.2);
	n += 0.3 * sin(uv.x * 4.7 - uv.y * 3.1 - TIME * 3.0);
	vec3 c = mix(vec3(0.75, 0.08, 0.0), vec3(1.0, 0.72, 0.12), smoothstep(-0.6, 1.3, n));
	ALBEDO = c;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	lava.material_override = mat
	lava.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(lava)
	lava_light = OmniLight3D.new()
	lava_light.light_color = Color(1.0, 0.45, 0.15)
	lava_light.light_energy = 2.5
	lava_light.omni_range = 18.0
	add_child(lava_light)
	_place_lava()


func _place_lava() -> void:
	lava.position = Vector3(0, lava_y, 0)
	lava_light.position = Vector3(player.position.x, lava_y + 1.5, player.position.z)


# ---------------------------------------------------------------- oyun akışı

func _start() -> void:
	state = State.PLAYING
	player.controls_enabled = true
	hud.hide_overlay()
	_capture_mouse()


func _capture_mouse() -> void:
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _pause(p: bool) -> void:
	if p:
		state = State.PAUSED
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		hud.show_overlay("DURAKLATILDI", "Devam etmek için TIKLA ya da ENTER'a bas")
	else:
		state = State.PLAYING
		get_tree().paused = false
		hud.hide_overlay()
		_capture_mouse()
	_was_captured = false


func _die() -> void:
	state = State.DEAD
	player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var score := _score()
	var record := score > best
	if record:
		best = score
		_save_best()
	var sub := "Yükseklik: %d m   Kristal: %d   Süre: %d sn\nSkor: %d%s\n\nTekrar denemek için TIKLA, R ya da ENTER" % [
		int(max_height), gems, int(elapsed), score, "   YENİ REKOR!" if record else "   (En iyi: %d)" % best]
	hud.show_overlay("LAVA DÜŞTÜN!", sub)


func restart() -> void:
	get_tree().paused = false
	skip_menu = true
	get_tree().reload_current_scene()


func _score() -> int:
	return int(max_height) * 10 + gems * GEM_SCORE


func _on_gem() -> void:
	gems += 1
	hud.toast("+%d" % GEM_SCORE)


func _unhandled_input(event: InputEvent) -> void:
	var click: bool = event is InputEventMouseButton and event.pressed
	match state:
		State.MENU:
			if click or event.is_action_pressed("restart") or event.is_action_pressed("jump"):
				_start()
		State.PLAYING:
			if event.is_action_pressed("pause"):
				_pause(true)
			elif click and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				_capture_mouse()
		State.PAUSED:
			if click or event.is_action_pressed("restart") or event.is_action_pressed("pause"):
				_pause(false)
		State.DEAD:
			if click or event.is_action_pressed("restart"):
				restart()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == State.PLAYING:
		_pause(true)


func _process(_delta: float) -> void:
	# Tarayıcıda Esc fare kilidini kendisi bırakır; bunu duraklatma olarak yorumla.
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if state == State.PLAYING and _was_captured and not captured:
		_pause(true)
	_was_captured = captured


func _physics_process(delta: float) -> void:
	if state == State.PAUSED:
		return
	if state == State.PLAYING:
		elapsed += delta
		max_height = maxf(max_height, player.global_position.y)
		if elapsed > LAVA_GRACE:
			lava_speed = LAVA_BASE_SPEED + (elapsed - LAVA_GRACE) * LAVA_SPEED_GROWTH
			var gap := player.global_position.y - lava_y
			var catchup := maxf(0.0, gap - LAVA_CATCHUP_DIST) * 0.15
			lava_y += (lava_speed + catchup) * delta
		if player.global_position.y < lava_y + 0.2:
			_die()
	tower.update_for(player.global_position.y, lava_y)
	_place_lava()
	_update_hud()


func _update_hud() -> void:
	hud.set_stats(max_height, _score(), best, gems, elapsed)
	hud.set_lava(player.global_position.y - lava_y, lava_speed)


func _load_best() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			best = f.get_32()


func _save_best() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_32(best)
