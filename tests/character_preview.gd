extends Node3D
## Karakter önizleme sahnesi (görsel kontrol için). Ana sahne olarak geçici
## ayarlanıp çalıştırılır; oyuna dahil değildir.

const Kid := preload("res://scripts/kid.gd")

var kids: Array = []
var poses := [["ground", 0.0, PI], ["ground", 0.0, PI * 0.75], ["ground", 0.0, 0.0], ["ground", 8.0, PI * 0.5], ["ground", 3.0, PI * 0.6], ["air", 8.0, PI * 0.5]]
var names := ["Önden", "Çapraz", "Arkadan", "Koşarken", "Hafif koşu", "Zıplarken"]
var view := 0


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.93, 0.85, 0.78)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 0.95, 0.9)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(30), 0)
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 6)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.75, 0.7, 0.68)
	floor_mi.material_override = fm
	add_child(floor_mi)
	for i in poses.size():
		var k := Kid.new()
		k.position = Vector3((i - 2.5) * 0.95, 0, 0)
		k.rotation.y = poses[i][2]
		add_child(k)
		kids.append(k)
		var l := Label3D.new()
		l.text = names[i]
		l.font_size = 36
		l.outline_size = 8
		l.position = Vector3(k.position.x, 1.65, 0)
		l.modulate = Color(0.2, 0.15, 0.15)
		l.outline_modulate = Color(1, 1, 1)
		add_child(l)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.85, 3.2)
	cam.rotation.x = 0.0
	cam.fov = 70
	add_child(cam)
	cam.current = true


func _process(delta: float) -> void:
	for i in kids.size():
		var p: Array = poses[i]
		var vy := 6.0 if p[0] == "air" else 0.0
		kids[i].animate(delta, p[1], vy, p[0])
