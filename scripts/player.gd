extends CharacterBody3D
## Üçüncü şahıs parkur karakteri: koşma, değişken yükseklikte zıplama,
## duvar zıplama / duvarda kayma, kayma (slide) ve çömelerek yürüme.

signal wall_jumped
signal slid

const RUN_SPEED := 8.0
const CROUCH_SPEED := 3.5
const GROUND_ACCEL := 60.0
const GROUND_FRICTION := 50.0
const AIR_ACCEL := 14.0
const AIR_DRAG := 2.0
const GRAVITY := 24.0
const FALL_GRAVITY_MULT := 1.3
const MAX_FALL_SPEED := 30.0
const JUMP_VELOCITY := 10.0
const WALL_JUMP_UP := 9.5
const WALL_JUMP_OUT := 7.5
const WALL_JUMP_LOCK := 0.25
const WALL_SLIDE_SPEED := 2.5
const WALL_PROBE := 0.75
const SLIDE_SPEED := 13.5
const SLIDE_TIME := 0.75
const SLIDE_DECEL := 9.0
const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.15
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 0.9
const RADIUS := 0.4
const MOUSE_SENS := 0.0025
const STICK_SENS := 2.6

var controls_enabled := false
var cam_yaw := 0.0
var cam_pitch := -0.35

var _pivot: Node3D
var _spring: SpringArm3D
var camera: Camera3D
var _visual: Node3D
var _shape: CollisionShape3D
var _capsule: CapsuleShape3D

var _coyote := 0.0
var _jump_buffer := 0.0
var _control_lock := 0.0
var _used_wall_normal := Vector3.ZERO
var _slide_timer := 0.0
var _crouched := false
var _ground_jump := false


func _ready() -> void:
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50)

	_capsule = CapsuleShape3D.new()
	_capsule.radius = RADIUS
	_capsule.height = STAND_HEIGHT
	_shape = CollisionShape3D.new()
	_shape.shape = _capsule
	_shape.position.y = STAND_HEIGHT * 0.5
	add_child(_shape)

	_build_visual()

	_pivot = Node3D.new()
	_pivot.position.y = 1.4
	add_child(_pivot)
	_spring = SpringArm3D.new()
	_spring.spring_length = 6.0
	_spring.margin = 0.25
	var probe := SphereShape3D.new()
	probe.radius = 0.3
	_spring.shape = probe
	_spring.add_excluded_object(get_rid())
	_pivot.add_child(_spring)
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.far = 400.0
	_spring.add_child(camera)
	camera.current = true
	_apply_camera()


func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = RADIUS
	cap.height = STAND_HEIGHT
	body.mesh = cap
	body.position.y = STAND_HEIGHT * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.35, 0.25)
	mat.roughness = 0.5
	body.material_override = mat
	_visual.add_child(body)
	# Yüzün baktığı yönü gösteren vizör (-Z yönü ileri)
	var visor := MeshInstance3D.new()
	var vb := BoxMesh.new()
	vb.size = Vector3(0.5, 0.18, 0.2)
	visor.mesh = vb
	visor.position = Vector3(0, 1.45, -0.33)
	var vmat := StandardMaterial3D.new()
	vmat.albedo_color = Color(0.2, 0.9, 1.0)
	vmat.emission_enabled = true
	vmat.emission = Color(0.2, 0.9, 1.0)
	vmat.emission_energy_multiplier = 1.5
	visor.material_override = vmat
	_visual.add_child(visor)
	# Sırt çantası
	var pack := MeshInstance3D.new()
	var pb := BoxMesh.new()
	pb.size = Vector3(0.45, 0.55, 0.22)
	pack.mesh = pb
	pack.position = Vector3(0, 1.05, 0.38)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.2, 0.22, 0.3)
	pack.material_override = pmat
	_visual.add_child(pack)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam_yaw -= event.relative.x * MOUSE_SENS
		cam_pitch = clampf(cam_pitch - event.relative.y * MOUSE_SENS, -1.25, 0.6)


func _apply_camera() -> void:
	_pivot.rotation = Vector3(cam_pitch, cam_yaw, 0.0)


func is_sliding() -> bool:
	return _slide_timer > 0.0


func is_crouched() -> bool:
	return _crouched


func _physics_process(delta: float) -> void:
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	cam_yaw -= look.x * STICK_SENS * delta
	cam_pitch = clampf(cam_pitch - look.y * STICK_SENS * 0.8 * delta, -1.25, 0.6)
	_apply_camera()

	var input := Vector2.ZERO
	if controls_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward := Vector3(-sin(cam_yaw), 0.0, -cos(cam_yaw))
	var right := Vector3(cos(cam_yaw), 0.0, -sin(cam_yaw))
	var wish := right * input.x + forward * (-input.y)
	if wish.length() > 1.0:
		wish = wish.normalized()

	var on_floor := is_on_floor()
	if on_floor:
		_coyote = COYOTE_TIME
		_used_wall_normal = Vector3.ZERO
	else:
		_coyote -= delta
	_control_lock -= delta
	if controls_enabled and Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER
	else:
		_jump_buffer -= delta

	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var vy := velocity.y

	# --- Kayma başlatma ---
	if controls_enabled and Input.is_action_just_pressed("slide") and on_floor and _slide_timer <= 0.0:
		var dir := hv if hv.length() > 2.0 else wish
		if dir.length() > 0.1:
			dir = dir.normalized()
			hv = dir * maxf(SLIDE_SPEED, hv.length())
			_slide_timer = SLIDE_TIME
			slid.emit()

	# --- Yatay hareket ---
	if _slide_timer > 0.0:
		_slide_timer -= delta
		hv = hv.move_toward(Vector3.ZERO, SLIDE_DECEL * delta)
		if wish.length() > 0.1:  # hafif yönlendirme
			hv = hv.slerp(wish * hv.length(), 1.5 * delta)
		if not on_floor and _coyote <= 0.0:
			_slide_timer = 0.0
	elif _control_lock <= 0.0:
		var target := wish * (CROUCH_SPEED if _crouched else RUN_SPEED)
		var accel: float
		if on_floor:
			accel = GROUND_ACCEL if wish.length() > 0.05 else GROUND_FRICTION
		else:
			accel = AIR_ACCEL if wish.length() > 0.05 else AIR_DRAG
		hv = hv.move_toward(target, accel * delta)

	# --- Çömelme durumu (kayarken ya da tuş basılıyken) ---
	var want_crouch := _slide_timer > 0.0 or (controls_enabled and Input.is_action_pressed("slide"))
	if want_crouch and not _crouched:
		_set_crouch(true)
	elif not want_crouch and _crouched and _can_stand():
		_set_crouch(false)

	# --- Zıplama ---
	if _jump_buffer > 0.0:
		if (on_floor or _coyote > 0.0) and (not _crouched or _can_stand()):
			vy = JUMP_VELOCITY
			_ground_jump = true
			_coyote = 0.0
			_jump_buffer = 0.0
			_slide_timer = 0.0  # kayarken zıplamak hızı korur (uzun atlayış)
			if _crouched:
				_set_crouch(false)
		elif not on_floor:
			var n := _find_wall()
			if n != Vector3.ZERO and (_used_wall_normal == Vector3.ZERO or n.dot(_used_wall_normal) < 0.7):
				hv = n * WALL_JUMP_OUT
				vy = WALL_JUMP_UP
				_ground_jump = false
				_used_wall_normal = n
				_control_lock = WALL_JUMP_LOCK
				_jump_buffer = 0.0
				_slide_timer = 0.0
				wall_jumped.emit()

	# Zıplama tuşu erken bırakılırsa kısa zıplama (duvar zıplamada uygulanmaz)
	if _ground_jump and controls_enabled and Input.is_action_just_released("jump") and vy > 3.0:
		vy *= 0.55

	# --- Yerçekimi ve duvarda kayma ---
	if not on_floor:
		var g := GRAVITY * (FALL_GRAVITY_MULT if vy < 0.0 else 1.0)
		vy = maxf(vy - g * delta, -MAX_FALL_SPEED)
		if vy < -WALL_SLIDE_SPEED and is_on_wall() and wish.dot(get_wall_normal()) < -0.3:
			vy = -WALL_SLIDE_SPEED

	velocity = Vector3(hv.x, vy, hv.z)
	move_and_slide()

	# Görselin yönü
	var face := Vector3(velocity.x, 0.0, velocity.z)
	if face.length() > 0.5:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-face.x, -face.z), minf(1.0, 12.0 * delta))


## Yakındaki dikey duvarın normalini bulur (yoksa Vector3.ZERO).
func _find_wall() -> Vector3:
	var space := get_world_3d().direct_space_state
	var best := Vector3.ZERO
	var best_d := INF
	var heights := [0.5, 1.2]
	for h in heights:
		var from := global_position + Vector3(0.0, h * (_capsule.height / STAND_HEIGHT), 0.0)
		for i in 12:
			var a := TAU * float(i) / 12.0
			var dir := Vector3(cos(a), 0.0, sin(a))
			var q := PhysicsRayQueryParameters3D.create(from, from + dir * WALL_PROBE)
			q.exclude = [get_rid()]
			var hit := space.intersect_ray(q)
			if hit.is_empty():
				continue
			var n: Vector3 = hit.normal
			if absf(n.y) > 0.3:
				continue
			var d := from.distance_to(hit.position)
			if d < best_d:
				best_d = d
				best = Vector3(n.x, 0.0, n.z).normalized()
	return best


func _can_stand() -> bool:
	var space := get_world_3d().direct_space_state
	var shape := CapsuleShape3D.new()
	shape.radius = RADIUS - 0.05
	shape.height = STAND_HEIGHT - 0.1
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), global_position + Vector3(0.0, STAND_HEIGHT * 0.5 + 0.05, 0.0))
	q.exclude = [get_rid()]
	q.collide_with_areas = false
	return space.intersect_shape(q, 1).is_empty()


func _set_crouch(c: bool) -> void:
	_crouched = c
	_capsule.height = CROUCH_HEIGHT if c else STAND_HEIGHT
	_shape.position.y = _capsule.height * 0.5
	_visual.scale.y = _capsule.height / STAND_HEIGHT
	_pivot.position.y = 0.9 if c else 1.4
