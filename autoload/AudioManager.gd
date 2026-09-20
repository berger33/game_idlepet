extends Node
## SFX procedurais leves: o core é audível sem depender de assets licenciados.

const SAMPLE_RATE: int = 22050
## Âncora de sincronia: VFX pulsam no compasso da música REAL em execução
## (get_playback_position), não em relógio próprio.
const MUSIC_BPM: float = 96.0
const ENERGY_ON_DB: float = -13.0
const ENERGY_OFF_DB: float = -60.0
var player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var energy_player: AudioStreamPlayer
var energy_target_db: float = ENERGY_OFF_DB
var cache: Dictionary = {}


func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.bus = &"Master"
	add_child(player)
	cache[&"tap"] = _tone(520.0, 0.05, 0.22)
	cache[&"bubble"] = _tone(760.0, 0.07, 0.18)
	cache[&"clipper"] = _chime([145.0, 175.0], 0.035)
	cache[&"dryer"] = _chime([180.0, 230.0, 190.0], 0.045)
	cache[&"spray"] = _chime([980.0, 1320.0], 0.045)
	cache[&"bow"] = _chime([740.0, 988.0, 1244.0], 0.055)
	cache[&"tool_pickup"] = _chime([420.0, 620.0], 0.045)
	cache[&"panel_open"] = _chime([392.0, 523.0, 659.0], 0.06)
	cache[&"service_start"] = _chime([520.0, 660.0], 0.07)
	cache[&"upgrade"] = _chime([520.0, 780.0, 1040.0, 1320.0], 0.085)
	cache[&"level_up"] = _chime([523.0, 659.0, 784.0, 1046.0], 0.11)
	cache[&"error_soft"] = _chime([310.0, 280.0], 0.07)
	cache[&"coin"] = _chime([880.0, 1174.0], 0.09)
	cache[&"perfect"] = _chime([660.0, 880.0, 1320.0], 0.12)
	cache[&"error"] = _chime([220.0, 165.0], 0.13)
	cache[&"review"] = _chime([740.0, 988.0], 0.1)
	cache[&"pet_happy"] = _chime([520.0, 690.0, 780.0], 0.07)
	cache[&"pet_surprise"] = _chime([430.0, 620.0], 0.08)
	cache[&"freeze"] = _chime([1320.0, 988.0, 784.0], 0.09)
	cache[&"pass_claim"] = _chime([659.0, 784.0, 988.0, 1319.0], 0.08)
	cache[&"comeback"] = _chime([392.0, 523.0, 659.0, 784.0], 0.1)
	cache[&"share_saved"] = _chime([1568.0, 1046.0], 0.05)
	cache[&"equip"] = _chime([587.0, 880.0], 0.05)
	cache[&"prestige"] = _chime([523.0, 659.0, 784.0, 1046.0, 1319.0, 1568.0], 0.11)
	music_player = AudioStreamPlayer.new()
	music_player.bus = &"Master"
	music_player.stream = _ambient_loop()
	var music_volume: float = clampf(float(GameState.settings.get("music", 0.7)), 0.0001, 1.0)
	music_player.volume_db = linear_to_db(music_volume * 0.22)
	add_child(music_player)
	music_player.play()
	# Camada de energia: percussão entra durante o serviço e sai suave no fim.
	energy_player = AudioStreamPlayer.new()
	energy_player.bus = &"Master"
	energy_player.stream = _energy_loop()
	energy_player.volume_db = ENERGY_OFF_DB
	add_child(energy_player)
	energy_player.play()
	EventBus.service_started.connect(
		func(_service: StringName) -> void: set_energy(true)
	)
	EventBus.service_completed.connect(
		func(_s: StringName, _q: StringName, _r: float) -> void: set_energy(false)
	)
	EventBus.service_failed.connect(
		func(_s: StringName, _r: StringName) -> void: set_energy(false)
	)


func play(sfx: StringName) -> void:
	if not cache.has(sfx):
		return
	var sfx_volume: float = clampf(float(GameState.settings.get("sfx", 0.9)), 0.0001, 1.0)
	player.volume_db = linear_to_db(sfx_volume)
	player.stream = cache[sfx]
	player.play()


## Fase do compasso atual (0..1) lida do playback real da música.
func beat_phase() -> float:
	var beat_length: float = 60.0 / MUSIC_BPM
	if not is_instance_valid(music_player) or not music_player.playing:
		return fmod(Time.get_ticks_msec() / 1000.0 / beat_length, 1.0)
	return fmod(music_player.get_playback_position() / beat_length, 1.0)


## Percussão de fundo entra só enquanto um atendimento está em curso.
func set_energy(is_on: bool) -> void:
	energy_target_db = ENERGY_ON_DB if is_on else ENERGY_OFF_DB


func _process(_delta: float) -> void:
	if is_instance_valid(energy_player) and not is_equal_approx(
		energy_player.volume_db, energy_target_db
	):
		energy_player.volume_db = move_toward(energy_player.volume_db, energy_target_db, 1.5)


## Sliders de ajustes chamam isto para valer na hora (música inclusive).
func apply_volumes() -> void:
	var sfx_volume: float = clampf(float(GameState.settings.get("sfx", 0.9)), 0.0001, 1.0)
	player.volume_db = linear_to_db(sfx_volume)
	var music_volume: float = clampf(float(GameState.settings.get("music", 0.7)), 0.0001, 1.0)
	music_player.volume_db = linear_to_db(music_volume * 0.22)


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
		var beat_frac: float = fmod(time, 0.5) / 0.5
		var melody_frequency: float = chord[int(time * 2.0) % chord.size()] * 2.0
		sample_value += sin(TAU * melody_frequency * time) * 0.04 * (1.0 - beat_frac)
		var sample: int = int(clampf(sample_value, -0.3, 0.3) * 32767.0)
		bytes.encode_s16(i * 2, sample)
	var stream: AudioStreamWAV = _wav(bytes)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = frames
	return stream


func _energy_loop() -> AudioStreamWAV:
	var beat_length: float = 60.0 / MUSIC_BPM
	var duration: float = beat_length * 8.0
	var frames: int = int(SAMPLE_RATE * duration)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(frames * 2)
	for i: int in frames:
		var time: float = float(i) / SAMPLE_RATE
		var beat_position: float = fmod(time, beat_length)
		var sample_value: float = 0.0
		# Bumbo no tempo, contratempo curto agudo: pulso tátil sem brigar com o tema.
		sample_value += sin(TAU * 58.0 * beat_position * (1.0 - beat_position * 2.2)) * 0.16
		if int(time / (beat_length * 0.5)) % 2 == 1:
			var offbeat: float = fmod(time, beat_length * 0.5) / (beat_length * 0.5)
			sample_value += sin(TAU * 3100.0 * time) * 0.05 * (1.0 - offbeat)
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
