extends Node
## SFX procedurais leves: o core é audível sem depender de assets licenciados.

const SAMPLE_RATE: int = 22050
var player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var cache: Dictionary = {}


func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.bus = &"Master"
	add_child(player)
	cache[&"tap"] = _tone(520.0, 0.05, 0.22)
	cache[&"bubble"] = _tone(760.0, 0.07, 0.18)
	cache[&"clipper"] = _chime([145.0, 175.0], 0.035)
	cache[&"coin"] = _chime([880.0, 1174.0], 0.09)
	cache[&"perfect"] = _chime([660.0, 880.0, 1320.0], 0.12)
	cache[&"error"] = _chime([220.0, 165.0], 0.13)
	cache[&"review"] = _chime([740.0, 988.0], 0.1)
	cache[&"pet_happy"] = _chime([520.0, 690.0, 780.0], 0.07)
	cache[&"pet_surprise"] = _chime([430.0, 620.0], 0.08)
	music_player = AudioStreamPlayer.new()
	music_player.bus = &"Master"
	music_player.stream = _ambient_loop()
	var music_volume: float = clampf(float(GameState.settings.get("music", 0.7)), 0.0001, 1.0)
	music_player.volume_db = linear_to_db(music_volume * 0.22)
	add_child(music_player)
	music_player.play()


func play(sfx: StringName) -> void:
	if not cache.has(sfx):
		return
	var sfx_volume: float = clampf(float(GameState.settings.get("sfx", 0.9)), 0.0001, 1.0)
	player.volume_db = linear_to_db(sfx_volume)
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


func _ambient_loop() -> AudioStreamWAV:
	var duration: float = 8.0
	var frames: int = int(SAMPLE_RATE * duration)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(frames * 2)
	var chords: Array = [
		[261.63, 329.63, 392.00],
		[220.00, 261.63, 329.63],
		[174.61, 220.00, 261.63],
		[196.00, 246.94, 293.66],
	]
	for i: int in frames:
		var time: float = float(i) / SAMPLE_RATE
		var chord: Array = chords[int(time / 2.0) % chords.size()]
		var sample_value: float = 0.0
		for frequency: float in chord:
			sample_value += sin(TAU * frequency * time) * 0.06
		var beat_phase: float = fmod(time, 0.5) / 0.5
		var melody_frequency: float = chord[int(time * 2.0) % chord.size()] * 2.0
		sample_value += sin(TAU * melody_frequency * time) * 0.04 * (1.0 - beat_phase)
		var sample: int = int(clampf(sample_value, -0.3, 0.3) * 32767.0)
		bytes.encode_s16(i * 2, sample)
	var stream: AudioStreamWAV = _wav(bytes)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = frames
	return stream


func _wav(bytes: PackedByteArray) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
