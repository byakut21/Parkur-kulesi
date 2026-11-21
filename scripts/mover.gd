extends AnimatableBody3D
## Başlangıç noktası etrafında `axis` boyunca ileri geri gider.

var axis := Vector3.RIGHT
var amplitude := 2.0
var speed := 1.5
var _origin := Vector3.ZERO
var _t := 0.0


func _ready() -> void:
	_origin = position
	_t = randf() * TAU


func _physics_process(delta: float) -> void:
	_t += delta * speed
	position = _origin + axis * sin(_t) * amplitude
