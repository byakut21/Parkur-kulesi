extends Area3D
## Toplanabilir kristal: bonus puan verir.

signal collected

var _mesh: MeshInstance3D
var _t := 0.0


func _ready() -> void:
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.7
	cs.shape = sh
	add_child(cs)
	_mesh = MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.5, 0.7, 0.5)
	_mesh.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 1.0, 0.9)
	m.emission_enabled = true
	m.emission = Color(0.2, 0.9, 1.0)
	m.emission_energy_multiplier = 2.0
	_mesh.material_override = m
	add_child(_mesh)
	_t = randf() * TAU
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	_mesh.rotation.y = _t * 2.0
	_mesh.position.y = sin(_t * 2.5) * 0.15


func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		collected.emit()
		queue_free()
