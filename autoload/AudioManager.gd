extends Node
## SFX procedurais leves: o core é audível sem depender de assets licenciados.

const SAMPLE_RATE: int = 22050
var player: AudioStreamPlayer
var cache: Dictionary = {}


func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.bus = &"Master"
	add_child(player)
	cache[&"tap"] = _tone(520.0, 0.05, 0.22)
	cache[&"bubble"] = _tone(760.0, 0.07, 0.18)
	cache[&"coin"] = _chime([880.0, 1174.0], 0.09)
	cache[&"perfect"] = _chime([660.0, 880.0, 1320.0], 0.12)
	cache[&"error"] = _chime([220.0, 165.0], 0.13)
	cache[&"review"] = _chime([740.0, 988.0], 0.1)


func play(sfx: StringName) -> void:
	if not cache.has(sfx):
		return
	player.volume_db = linear_to_db(float(GameState.settings.get("sfx", 0.9)))
	player.stream = cache[sfx]
	player.play()


func _tone(frequency: float, duration: float, volume: float) -> AudioStreamWAV:
	var frames: int = int(SAMPLE_RATE * duration)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(frames * 2)
	for i: int in frames:
		var envelope: float = sin(PI * float(i) / float(frames))
		var sample: int = int(
			sin(TAU * frequency * float(i) / SAMPLE_RATE) * 32767.0 * volume * envelope
		)
		bytes.encode_s16(i * 2, sample)
	return _wav(bytes)


func _chime(frequencies: Array, note_duration: float) -> AudioStreamWAV:
	var frames_per_note: int = int(SAMPLE_RATE * note_duration)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(frames_per_note * frequencies.size() * 2)
	for note: int in frequencies.size():
		for i: int in frames_per_note:
			var envelope: float = 1.0 - float(i) / float(frames_per_note)
			var sample: int = int(
				sin(TAU * frequencies[note] * float(i) / SAMPLE_RATE) * 8000.0 * envelope
			)
			bytes.encode_s16((note * frames_per_note + i) * 2, sample)
	return _wav(bytes)


func _wav(bytes: PackedByteArray) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
