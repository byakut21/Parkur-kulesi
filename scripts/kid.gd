extends Node3D
## Oyuncu karakteri: kapüşonlu küçük bir çocuk.
## Model: Quaternius "Ultimate Modular Men Pack" — Casual_Hoodie (CC0).
## Çocuk oranları için küçültülür ve kafa biraz büyütülür; renkler koddan.
## Model -Z yönüne bakar, ayaklar y=0'da.

const MODEL := preload("res://assets/character/kid.gltf")
const HeadScale := preload("res://scripts/head_scale_modifier.gd")
const KID_SCALE := 0.78
const BLEND := 0.15

## Malzeme adı → yeni renk
const COLORS := {
	"Purple": Color(0.95, 0.42, 0.12),   # kapüşonlu üst: turuncu
	"LightBlue": Color(0.13, 0.2, 0.35), # pantolon: koyu kot
	"White": Color(0.92, 0.92, 0.9),     # ayakkabı
	"Skin": Color(0.82, 0.58, 0.45),
}

var _anim: AnimationPlayer
var _model: Node3D
var _current := ""
var _air_pose := false


func _ready() -> void:
	_model = MODEL.instantiate()
	_model.scale = Vector3.ONE * KID_SCALE
	_model.rotation.y = PI  # glTF modeli +Z'ye bakıyor
	add_child(_model)
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for n in ["Idle", "Idle_Neutral", "Run", "Walk"]:
		if _anim and _anim.has_animation(n):
			_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		_recolor(mi as MeshInstance3D)
	var sk := _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk:
		var hs := HeadScale.new()
		hs.bone_name = "Head"
		hs.head_scale = 1.15
		sk.add_child(hs)
	_play("Idle")


func _recolor(mi: MeshInstance3D) -> void:
	if mi.mesh == null:
		return
	for i in mi.mesh.get_surface_count():
		var m := mi.mesh.surface_get_material(i) as StandardMaterial3D
		if m and COLORS.has(m.resource_name):
			var c := m.duplicate() as StandardMaterial3D
			c.albedo_color = COLORS[m.resource_name]
			mi.set_surface_override_material(i, c)


func _play(anim_name: String, speed := 1.0, blend := BLEND) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	if _current != anim_name or not _anim.is_playing():
		_anim.play(anim_name, blend)
		_current = anim_name
	_anim.speed_scale = speed


## Havada: koşu animasyonunun bacakları açık bir karesinde dondur.
func _hold_pose(anim_name: String, t: float) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	if _current != anim_name + "#hold":
		_anim.play(anim_name, 0.1)
		_anim.seek(t, true)
		_current = anim_name + "#hold"
	_anim.speed_scale = 0.0


## speed: yatay hız (m/sn). state: "ground", "air", "slide", "crouch", "wall".
func animate(_delta: float, speed: float, _vertical: float, state: String) -> void:
	match state:
		"ground":
			if speed > 4.5:
				_play("Run", clampf(speed / 7.0, 0.8, 1.35))
			elif speed > 0.6:
				_play("Walk", clampf(speed / 2.0, 0.8, 1.6))
			else:
				_play("Idle")
		"air", "wall":
			_hold_pose("Run", 0.18)
		"slide":
			_play("Roll", 1.3, 0.08)
		"crouch":
			_play("Walk" if speed > 0.5 else "Idle", 0.7)
