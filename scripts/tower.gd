extends Node3D
## Kuleyi oyuncu tırmandıkça yukarı doğru, sonsuz ve rastgele üretir.
## Parçalar merkezi sütunun etrafında spiral şeklinde dizilir.
## Parça türleri: atlama platformu, duvar zıplama bacası, kayma tüneli, hareketli platform.

signal gem_collected

const Gem := preload("res://scripts/gem.gd")
const Mover := preload("res://scripts/mover.gd")

const RING_RADIUS := 10.0
const COLUMN_RADIUS := 6.0
const COLUMN_CHUNK := 20.0
const BUILD_AHEAD := 45.0
const CLEANUP_BELOW := 15.0
const MILESTONE_STEP := 25.0

## Spiraldeki son yüzeyin arka kenarının açısı (radyan) ve üst yüzey yüksekliği.
var angle := 0.0
var height := 0.0

var _rng := RandomNumberGenerator.new()
var _pieces: Array = []  # [{node, top}]
var _column_top := -2.0
var _count := 0
var _last_kind := ""
var _next_milestone := MILESTONE_STEP
var _taught := {}
var _mat_cache := {}
var _column_mat: ShaderMaterial

## Oyunun başında öğretici sıralama, sonra rastgele.
const INTRO := ["hop", "hop", "hop", "slide", "hop", "hop", "chimney", "hop", "hop", "moving", "hop"]


func _ready() -> void:
	_rng.randomize()
	_column_mat = ShaderMaterial.new()
	_column_mat.shader = _column_shader()
	_build_start()


func set_seed(s: int) -> void:
	_rng.seed = s


func update_for(player_y: float, lava_y: float) -> void:
	while height < player_y + BUILD_AHEAD:
		_next_piece()
	while _column_top < height + COLUMN_CHUNK:
		_add_column_chunk()
	for p in _pieces.duplicate():
		if p.top < lava_y - CLEANUP_BELOW:
			p.node.queue_free()
			_pieces.erase(p)


# ---------------------------------------------------------------- yardımcılar

func _polar(a: float, r: float, y: float) -> Vector3:
	return Vector3(cos(a) * r, y, sin(a) * r)


## Kutunun yerel X ekseni spiralin teğetine, yerel Z ekseni merkeze bakar.
func _yaw_for(a: float) -> float:
	return -a - PI * 0.5


func _mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.75
	_mat_cache[key] = m
	return m


func _color_at(y: float, sat := 0.62, val := 0.78) -> Color:
	return Color.from_hsv(fposmod(0.55 + y * 0.0045, 1.0), sat, val)


func _add_box(parent: Node3D, body: PhysicsBody3D, size: Vector3, pos: Vector3, yaw: float, color: Color) -> PhysicsBody3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(mi)
	body.add_child(cs)
	body.position = pos
	body.rotation.y = yaw
	parent.add_child(body)
	return body


func _static_box(parent: Node3D, size: Vector3, pos: Vector3, yaw: float, color: Color) -> StaticBody3D:
	return _add_box(parent, StaticBody3D.new(), size, pos, yaw, color) as StaticBody3D


## Üst yüzeyi `top` yüksekliğinde olan, teğet boyunca `length` uzunluğunda platform.
## `angle` değerini ilerletir ve platformun merkez açısını döndürür.
func _place_platform(parent: Node3D, gap: float, length: float, depth: float, top: float, r := RING_RADIUS) -> float:
	var center := angle + (gap + length * 0.5) / RING_RADIUS
	_static_box(parent, Vector3(length, 0.5, depth), _polar(center, r, top - 0.25), _yaw_for(center), _color_at(top))
	angle = center + length * 0.5 / RING_RADIUS
	return center


func _new_piece() -> Node3D:
	var n := Node3D.new()
	add_child(n)
	return n


func _register(node: Node3D, top: float) -> void:
	_pieces.append({"node": node, "top": top})


func _add_gem(parent: Node3D, pos: Vector3) -> void:
	var g := Gem.new()
	g.position = pos
	g.collected.connect(func(): gem_collected.emit())
	parent.add_child(g)


func _add_sign(parent: Node3D, text: String, pos: Vector3, color := Color.WHITE, size := 96) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.01
	l.outline_size = 18
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	l.position = pos
	parent.add_child(l)


func _teach(parent: Node3D, kind: String, text: String, pos: Vector3) -> void:
	if _taught.has(kind):
		return
	_taught[kind] = true
	_add_sign(parent, text, pos, Color(1.0, 0.95, 0.6), 72)


# ---------------------------------------------------------------- başlangıç

func _build_start() -> void:
	var start := _new_piece()
	var body := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 16.0
	cm.bottom_radius = 16.0
	cm.height = 1.0
	mi.mesh = cm
	mi.material_override = _mat(Color(0.45, 0.42, 0.4))
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 16.0
	sh.height = 1.0
	cs.shape = sh
	body.add_child(mi)
	body.add_child(cs)
	body.position.y = -0.5
	start.add_child(body)
	_register(start, 0.0)
	_add_sign(start, "PARKUR KULESİ", Vector3(RING_RADIUS + 3.0, 4.0, -3.0), Color(1.0, 0.8, 0.4), 160)
	# Oyuncu (RING_RADIUS, 0, 0) noktasında doğar; spiral açısı 0'dan başlar.
	angle = 0.15
	height = 0.0


func _add_column_chunk() -> void:
	var piece := _new_piece()
	var body := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = COLUMN_RADIUS
	cm.bottom_radius = COLUMN_RADIUS
	cm.height = COLUMN_CHUNK
	cm.radial_segments = 32
	mi.mesh = cm
	mi.material_override = _column_mat
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = COLUMN_RADIUS
	sh.height = COLUMN_CHUNK
	cs.shape = sh
	body.add_child(mi)
	body.add_child(cs)
	body.position.y = _column_top + COLUMN_CHUNK * 0.5
	piece.add_child(body)
	_column_top += COLUMN_CHUNK
	_register(piece, _column_top)


# ---------------------------------------------------------------- parça türleri

func _next_piece() -> void:
	var kind: String
	if _count < INTRO.size():
		kind = INTRO[_count]
	else:
		var r := _rng.randf()
		if r < 0.5 or _last_kind != "hop":
			kind = "hop"
		elif r < 0.68:
			kind = "chimney"
		elif r < 0.84:
			kind = "slide"
		else:
			kind = "moving"
	_count += 1
	_last_kind = kind
	match kind:
		"hop":
			_piece_hop()
		"chimney":
			_piece_chimney()
		"slide":
			_piece_slide()
		"moving":
			_piece_moving()


func _difficulty() -> float:
	return clampf(height / 250.0, 0.0, 1.0)


func _piece_hop() -> void:
	var piece := _new_piece()
	var d := _difficulty()
	var gap := _rng.randf_range(1.4, 2.4 + 0.9 * d)
	height += _rng.randf_range(0.5, 1.1 + 0.4 * d)
	var size := lerpf(3.4, 2.6, d) + _rng.randf_range(-0.2, 0.2)
	var milestone := height >= _next_milestone
	if milestone:
		size = 5.0
	var r := RING_RADIUS + _rng.randf_range(-0.7, 0.7)
	var c := _place_platform(piece, gap, size, size, height, r)
	if milestone:
		_add_sign(piece, "%d m" % int(_next_milestone), _polar(c, r, height + 2.5), Color(0.8, 1.0, 0.9), 128)
		_next_milestone += MILESTONE_STEP
	elif _rng.randf() < 0.25:
		_add_gem(piece, _polar(c, r, height + 1.0))
	_register(piece, height)


## İki karşılıklı duvar: duvardan duvara zıplayarak çıkılır.
func _piece_chimney() -> void:
	var piece := _new_piece()
	var gap := _rng.randf_range(1.2, 2.0)
	var wall_h := _rng.randf_range(6.0, 8.5)
	var length := 3.0
	var inner := 3.6  # duvarlar arası boşluk (radyal)
	var base := height
	var center := _place_platform(piece, gap, length, inner, base)
	var yaw := _yaw_for(center)
	var wall_col := _color_at(base, 0.35, 0.6)
	var off := inner * 0.5 + 0.25
	_static_box(piece, Vector3(length, wall_h, 0.5), _polar(center, RING_RADIUS - off, base + wall_h * 0.5), yaw, wall_col)
	_static_box(piece, Vector3(length, wall_h, 0.5), _polar(center, RING_RADIUS + off, base + wall_h * 0.5), yaw, wall_col)
	_teach(piece, "chimney", "Duvar zıplama!\nDuvara değerken ZIPLA", _polar(center, RING_RADIUS, base + 3.0))
	# Çıkış platformu bacanın yanında, duvar tepesinden biraz aşağıda
	height = base + wall_h - 0.8
	var exit_c := _place_platform(piece, 0.25, 3.0, inner, height)
	_add_gem(piece, _polar(exit_c, RING_RADIUS, height + 1.0))
	_register(piece, height + 0.8)


## Alçak tavanlı tünel: altından ancak kayarak (ya da çömelerek) geçilir.
func _piece_slide() -> void:
	var piece := _new_piece()
	var gap := _rng.randf_range(1.4, 2.2)
	height += _rng.randf_range(0.0, 0.6)
	var length := 8.0
	var depth := 3.0
	var center := _place_platform(piece, gap, length, depth, height)
	var yaw := _yaw_for(center)
	var block_h := 3.6
	var clearance := 1.15
	_static_box(piece, Vector3(3.6, block_h, depth), _polar(center, RING_RADIUS, height + clearance + block_h * 0.5), yaw, _color_at(height, 0.35, 0.6))
	_teach(piece, "slide", "Koşarken KAY! (Shift / C)", _polar(center - 3.5 / RING_RADIUS, RING_RADIUS, height + 2.2))
	_add_gem(piece, _polar(center, RING_RADIUS, height + 0.5))
	_register(piece, height + clearance + block_h)


## Teğet boyunca ileri geri giden platform.
func _piece_moving() -> void:
	var piece := _new_piece()
	var amp := 2.0
	var size := 3.0
	height += _rng.randf_range(0.3, 0.9)
	var gap := 1.3
	var center := angle + (gap + size * 0.5 + amp) / RING_RADIUS
	var yaw := _yaw_for(center)
	var mover := Mover.new()
	mover.axis = Vector3(-sin(center), 0.0, cos(center))
	mover.amplitude = amp
	mover.speed = _rng.randf_range(1.3, 1.9)
	_add_box(piece, mover, Vector3(size, 0.5, size), _polar(center, RING_RADIUS, height - 0.25), yaw, Color(1.0, 0.75, 0.3))
	_teach(piece, "moving", "Hareketli platform", _polar(center, RING_RADIUS, height + 2.2))
	angle = center + (amp + size * 0.5) / RING_RADIUS
	_register(piece, height)


func _column_shader() -> Shader:
	var s := Shader.new()
	s.code = """
shader_type spatial;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float band = step(0.93, fract(wp.y / 5.0));
	float row = floor(wp.y / 1.25);
	float brick = step(0.94, fract(atan(wp.z, wp.x) * 18.0 / 6.2831 + mod(row, 2.0) * 0.5));
	float mortar = step(0.9, fract(wp.y / 1.25));
	vec3 base = vec3(0.36, 0.34, 0.42);
	vec3 dark = vec3(0.2, 0.19, 0.24);
	vec3 c = mix(base, dark, max(brick, mortar));
	c = mix(c, vec3(0.75, 0.55, 0.3), band);
	ALBEDO = c;
	ROUGHNESS = 0.9;
}
"""
	return s
