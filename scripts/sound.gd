extends Node
## Müzik ve ses efektleri. Sesler tools/make_audio.py ile üretildi.

const STREAMS := {
	"jump": preload("res://assets/audio/jump.ogg"),
	"wall_jump": preload("res://assets/audio/wall_jump.ogg"),
	"slide": preload("res://assets/audio/slide.ogg"),
	"gem": preload("res://assets/audio/gem.ogg"),
	"land": preload("res://assets/audio/land.ogg"),
	"death": preload("res://assets/audio/death.ogg"),
}
const MUSIC := preload("res://assets/audio/music.ogg")
const LAVA := preload("res://assets/audio/lava.ogg")

static var muted := false

var _music: AudioStreamPlayer
var _lava: AudioStreamPlayer
var _pool: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var m := MUSIC.duplicate() as AudioStreamOggVorbis
	m.loop = true
	_music = AudioStreamPlayer.new()
	_music.stream = m
	_music.volume_db = -7.0
	add_child(_music)
	var l := LAVA.duplicate() as AudioStreamOggVorbis
	l.loop = true
	_lava = AudioStreamPlayer.new()
	_lava.stream = l
	_lava.volume_db = -40.0
	add_child(_lava)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_apply_mute()


func start_music() -> void:
	if not _music.playing:
		_music.play()
	if not _lava.playing:
		_lava.play()


func play(sfx: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not STREAMS.has(sfx):
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = STREAMS[sfx]
	p.volume_db = volume_db - 4.0
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	p.play()


## Lava yaklaştıkça gürültüsü artar.
func set_lava_distance(d: float) -> void:
	_lava.volume_db = lerpf(-4.0, -40.0, clampf(d / 18.0, 0.0, 1.0))


func set_paused(p: bool) -> void:
	_music.stream_paused = p
	_lava.stream_paused = p


func toggle_mute() -> bool:
	muted = not muted
	_apply_mute()
	return muted


func _apply_mute() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)
