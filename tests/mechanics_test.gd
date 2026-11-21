extends SceneTree
## Başsız (headless) mekanik testi:
##   godot --headless -s res://tests/mechanics_test.gd
## Kayma tüneli, duvar zıplama bacası ve kulenin üretimini dener.

const Player := preload("res://scripts/player.gd")
const Tower := preload("res://scripts/tower.gd")

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _box(parent: Node, size: Vector3, pos: Vector3) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	b.add_child(cs)
	b.position = pos
	parent.add_child(b)


func _setup_actions() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "look_left", "look_right", "look_up", "look_down", "jump", "slide"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(name: String, ok: bool, detail: String) -> void:
	print(("GEÇTİ  " if ok else "KALDI  ") + name + "  (" + detail + ")")
	if not ok:
		failures += 1


func _make_world() -> Node3D:
	var w := Node3D.new()
	root.add_child(w)
	return w


func _make_player(w: Node3D, pos: Vector3, yaw: float) -> CharacterBody3D:
	var p := Player.new()
	p.position = pos
	w.add_child(p)
	p.cam_yaw = yaw
	p.controls_enabled = true
	return p


func _run() -> void:
	_setup_actions()
	await _test_walk_blocked()
	await _test_slide()
	await _test_chimney()
	await _test_tower()
	print("SONUÇ: %s" % ("TÜM TESTLER GEÇTİ" if failures == 0 else "%d test kaldı" % failures))
	quit(1 if failures > 0 else 0)


func _test_walk_blocked() -> void:
	var w := _make_world()
	_box(w, Vector3(40, 0.5, 3), Vector3(10, -0.25, 0))
	_box(w, Vector3(3.6, 3.6, 3), Vector3(8, 1.15 + 1.8, 0))
	var p := _make_player(w, Vector3(0, 0.1, 0), -PI / 2)
	Input.action_press("move_forward")
	await _frames(150)
	Input.action_release("move_forward")
	_check("Alçak tavanın altından yürüyerek geçilemez", p.position.x < 6.5, "x=%.2f" % p.position.x)
	w.queue_free()
	await _frames(2)


func _test_slide() -> void:
	var w := _make_world()
	_box(w, Vector3(40, 0.5, 3), Vector3(10, -0.25, 0))
	_box(w, Vector3(3.6, 3.6, 3), Vector3(8, 1.15 + 1.8, 0))
	var p := _make_player(w, Vector3(0, 0.1, 0), -PI / 2)
	Input.action_press("move_forward")
	await _frames(25)
	Input.action_press("slide")
	await _frames(3)
	Input.action_release("slide")
	await _frames(120)
	Input.action_release("move_forward")
	_check("Kayarak tünelden geçilir", p.position.x > 10.5 and p.position.y > -0.5, "x=%.2f y=%.2f" % [p.position.x, p.position.y])
	await _frames(30)
	_check("Tünelden çıkınca ayağa kalkar", not p.is_crouched(), "crouched=%s" % p.is_crouched())
	w.queue_free()
	await _frames(2)


func _test_chimney() -> void:
	var w := _make_world()
	_box(w, Vector3(3, 0.5, 3.6), Vector3(0, -0.25, 0))
	_box(w, Vector3(3, 8, 0.5), Vector3(0, 4, -2.05))
	_box(w, Vector3(3, 8, 0.5), Vector3(0, 4, 2.05))
	var p := _make_player(w, Vector3(0, 0.1, 0), 0.0)
	await _frames(10)
	# Duvara doğru zıpla, sonra her duvara değişte zıplamaya bas
	Input.action_press("move_back")  # kamera -Z'ye bakıyor, geri = +Z duvarı
	Input.action_press("jump")
	await _frames(20)
	Input.action_release("jump")
	Input.action_release("move_back")
	var max_y := 0.0
	var jumps := [0]
	p.wall_jumped.connect(func(): jumps[0] += 1)
	for i in 30:
		await _frames(14)
		Input.action_press("jump")
		await _frames(2)
		Input.action_release("jump")
		max_y = maxf(max_y, p.position.y)
	for i in 30:
		await physics_frame
		max_y = maxf(max_y, p.position.y)
	_check("Duvar zıplamayla 8 m'lik bacanın tepesine çıkılır", max_y > 6.8, "max_y=%.2f, duvar zıplama=%d" % [max_y, jumps[0]])
	w.queue_free()
	await _frames(2)

	# Tek duvarda sonsuz tırmanma olmamalı
	var w2 := _make_world()
	_box(w2, Vector3(6, 0.5, 6), Vector3(0, -0.25, 0))
	_box(w2, Vector3(6, 12, 0.5), Vector3(0, 6, 1.0))
	var p2 := _make_player(w2, Vector3(0, 0.1, 0), 0.0)
	await _frames(10)
	var top := 0.0
	Input.action_press("move_back")
	for i in 20:
		Input.action_press("jump")
		await _frames(2)
		Input.action_release("jump")
		await _frames(10)
		top = maxf(top, p2.position.y)
	Input.action_release("move_back")
	_check("Tek duvarda sonsuz tırmanılamaz", top < 4.0, "max_y=%.2f" % top)
	w2.queue_free()
	await _frames(2)


func _test_tower() -> void:
	var w := _make_world()
	var t := Tower.new()
	w.add_child(t)
	t.update_for(300.0, -10.0)
	var kinds_ok := t.height > 300.0
	_check("Kule 300 m'nin üzerine üretilir", kinds_ok, "yükseklik=%.1f, parça=%d" % [t.height, t._pieces.size()])
	var before: int = t._pieces.size()
	t.update_for(300.0, 250.0)
	var lowest := INF
	for p in t._pieces:
		lowest = minf(lowest, p.top)
	_check("Lavın altında kalan parçalar temizlenir", t._pieces.size() < before and lowest >= 250.0 - Tower.CLEANUP_BELOW, "önce=%d sonra=%d en alçak=%.1f" % [before, t._pieces.size(), lowest])
	w.queue_free()
	await _frames(2)
