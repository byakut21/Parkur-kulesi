extends SkeletonModifier3D
## Çocuk oranları için kafayı biraz büyütür (animasyondan sonra uygulanır).

var bone_name := "DEF-head"
var head_scale := 1.18
var _bone := -1


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if _bone == -1:
		_bone = sk.find_bone(bone_name)
		if _bone == -1:
			return
	sk.set_bone_pose_scale(_bone, Vector3.ONE * head_scale)
