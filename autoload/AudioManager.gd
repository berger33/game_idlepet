extends Node
## SFX procedurais leves: o core é audível sem depender de assets licenciados.
##
## Design de som (revisão de conforto): a música ambiente ficou intocada e
## TODOS os efeitos foram re-sintetizados para serem agradáveis e hipnóticos:
##   * _pluck — "kalimba/caixinha de música": parciais harmônicos que decaem
##     rápido + ataque suave (sem clique) + leve desafinação (chorus quente);
##   * _bloop — gota d'água: varredura de pitch descendente com fase integrada;
##   * _air — sopro de ruído filtrado (one-pole), determinístico;
##   * tudo em pentatônica de Dó maior: qualquer sequência de SFX permanece
##     consonante com o loop ambiente (C, Am, F, G) — errar não "briga";
##   * pool de 4 vozes (round-robin): sinos se sobrepõem em vez de cortar;
##   * play_tick — os sons de loop do gesto ciclam um arpejo pentatônico com
##     micro-jitter de afinação: textura contínua, não metralhadora de bips.

const SAMPLE_RATE: int = 22050
## Âncora de sincronia: VFX pulsam no compasso da música REAL em execução
## (get_playback_position), não em relógio próprio.
const MUSIC_BPM: float = 96.0
const ENERGY_ON_DB: float = -13.0
const ENERGY_OFF_DB: float = -60.0
## Pool de vozes: sons simultâneos tocam juntos em vez de se truncarem.
const VOICE_COUNT: int = 4
## Escala pentatônica de Dó maior (Dó Ré Mi Sol Lá, duas oitavas e meia).
const PENTATONIC: Array[float] = [
	261.63, 293.66, 329.63, 392.00, 440.00,
	523.25, 587.33, 659.26, 783.99, 880.00, 1046.50, 1174.66, 1318.51,
]
## Fração do início de cada nota reservada ao fade-in (mata o "clique").
const ATTACK: float = 0.12

var voices: Array[AudioStreamPlayer] = []
var voice_index: int = 0
var music_player: AudioStreamPlayer
var energy_player: AudioStreamPlayer
var energy_target_db: float = ENERGY_OFF_DB
var cache: Dictionary = {}
var tick_counter: Dictionary = {}


func _ready() -> void:
	for i: int in VOICE_COUNT:
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.bus = &"Master"
		add_child(voice)
		voices.append(voice)
	_build_sfx_cache()
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


func _build_sfx_cache() -> void:
	# --- Ticks do gesto (loop do arrastar): quietos, em arpejo pentatônico ---
	# Banho: gotas d'água sobem e descem a escala — esfregar vira chuvinha.
	_cache_ticks(&"bubble", &"bloop", [523.25, 587.33, 659.26, 783.99, 659.26], 0.085, 0.05)
	# Tosa: duo grave Mi/Sol curto e abafado — tesourada ritmada, nunca zumbido.
	_cache_ticks(&"clipper", &"pluck", [261.63, 329.63], 0.05, 0.05)
	# Secagem: dois sopros de ar com brilho diferente — respiração do secador.
	_cache_air_ticks(&"dryer", 0.14, 0.05, [0.16, 0.24])
	# Laço: harpa subindo a pentatônica — cada carinho no lacinho, uma nota.
	_cache_ticks(&"bow", &"pluck", [523.25, 587.33, 659.26, 783.99, 880.00], 0.06, 0.05)
	# --- Toques e painéis (frequentes: discretos) ---
	cache[&"tap"] = _pluck([659.26], 0.045, 0.07)
	cache[&"tool_pickup"] = _pluck([523.25, 659.26], 0.05, 0.09)
	cache[&"panel_open"] = _pluck([392.00, 523.25, 659.26], 0.065, 0.10)
	cache[&"equip"] = _pluck([587.33, 880.00], 0.055, 0.09)
	# --- Serviço e recompensa ---
	cache[&"service_start"] = _pluck([392.00, 523.25], 0.07, 0.11)
	cache[&"coin"] = _pluck([880.00, 1046.50], 0.055, 0.10)
	cache[&"perfect"] = _pluck([523.25, 659.26, 783.99, 1046.50], 0.09, 0.13)
	cache[&"upgrade"] = _pluck([659.26, 783.99, 1046.50], 0.07, 0.11)
	cache[&"level_up"] = _pluck(
		[523.25, 587.33, 659.26, 783.99, 1046.50], 0.075, 0.12
	)
	cache[&"review"] = _pluck([783.99, 1046.50], 0.07, 0.10)
	cache[&"pass_claim"] = _pluck([523.25, 659.26, 783.99, 1046.50], 0.08, 0.12)
	cache[&"prestige"] = _pluck(
		[523.25, 659.26, 783.99, 1046.50, 1318.51, 1568.00], 0.095, 0.13
	)
	cache[&"comeback"] = _pluck([392.00, 523.25, 659.26, 783.99], 0.085, 0.11)
	cache[&"share_saved"] = _pluck([1046.50, 1318.51], 0.05, 0.09)
	# --- Pets e erros: suaves, graves, sem bronca ---
	cache[&"pet_happy"] = _bloop([783.99, 1046.50], 0.075, 0.10)
	cache[&"pet_surprise"] = _bloop([392.00], 0.08, 0.09)
	cache[&"spray"] = _spray(0.11)
	cache[&"error_soft"] = _pluck([196.00, 164.81], 0.07, 0.09)
	cache[&"error"] = _pluck([164.81, 130.81], 0.09, 0.10)
	cache[&"freeze"] = _pluck([1046.50, 783.99, 659.26], 0.07, 0.09)


func play(sfx: StringName) -> void:
	_play_entry(sfx, 1.0)


## Som de loop do gesto (um tick a cada intervalo do arrastar): cicla as
## variantes do sfx como arpejo e aplica micro-jitter de afinação — o gesto
## vira textura musical contínua em vez do mesmo bip repetido.
func play_tick(sfx: StringName) -> void:
	var entry: StringName = sfx
	var variants: int = int(cache.get("variants_" + String(sfx), 0))
	if variants > 0:
		var next_tick: int = (int(tick_counter.get(String(sfx), -1)) + 1) % variants
		tick_counter[String(sfx)] = next_tick
		entry = StringName("%s_%d" % [sfx, next_tick])
	_play_entry(entry, randf_range(0.992, 1.008))


func _play_entry(sfx: StringName, pitch: float) -> void:
	if not cache.has(sfx):
		return
	var sfx_volume: float = clampf(float(GameState.settings.get("sfx", 0.9)), 0.0001, 1.0)
	var voice: AudioStreamPlayer = _next_voice()
	voice.pitch_scale = pitch
	voice.volume_db = linear_to_db(sfx_volume)
	voice.stream = cache[sfx]
	voice.play()


func _next_voice() -> AudioStreamPlayer:
	var voice: AudioStreamPlayer = voices[voice_index]
	voice_index = (voice_index + 1) % voices.size()
	return voice


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
	for voice: AudioStreamPlayer in voices:
		voice.volume_db = linear_to_db(sfx_volume)
	var music_volume: float = clampf(float(GameState.settings.get("music", 0.7)), 0.0001, 1.0)
	music_player.volume_db = linear_to_db(music_volume * 0.22)


## Registra N variantes de tick (uma por nota) + contador de ciclo + fallback.
func _cache_ticks(
	base: StringName, kind: StringName, notes: Array, note_duration: float, volume: float
) -> void:
	for i: int in notes.size():
		var entry: StringName = StringName("%s_%d" % [base, i])
		if kind == &"bloop":
			cache[entry] = _bloop([float(notes[i])], note_duration, volume)
		else:
			cache[entry] = _pluck([float(notes[i])], note_duration, volume)
	cache[base] = cache[StringName("%s_%d" % [base, 0])]
	cache["variants_" + String(base)] = notes.size()


## Ticks de ar (secador): variantes variam o brilho do filtro, não a nota.
func _cache_air_ticks(
	base: StringName, duration: float, volume: float, cutoffs: Array
) -> void:
	for i: int in cutoffs.size():
		cache[StringName("%s_%d" % [base, i])] = _air(duration, volume, float(cutoffs[i]))
	cache[base] = cache[StringName("%s_%d" % [base, 0])]
	cache["variants_" + String(base)] = cutoffs.size()


## Nota "tocada": fundamental + oitava e terça-cima fracas que decaem antes
## (timbre de kalimba), desafinação leve para calor, ataque suave e cauda
## exponencial — sem transiente de clique em nenhum dos dois lados.
func _pluck(frequencies: Array, note_duration: float, volume: float) -> AudioStreamWAV:
	var frames_per_note: int = int(SAMPLE_RATE * note_duration)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(frames_per_note * frequencies.size() * 2)
	for note: int in frequencies.size():
		var frequency: float = float(frequencies[note])
		for i: int in frames_per_note:
			var t: float = float(i) / float(frames_per_note)
			var env: float = minf(t / ATTACK, 1.0) * pow(1.0 - t, 2.4)
			var phase: float = TAU * frequency * float(i) / SAMPLE_RATE
			var wave: float = sin(phase)
			wave += sin(TAU * frequency * 1.004 * float(i) / SAMPLE_RATE) * 0.24
			wave += sin(phase * 2.0) * 0.30 * pow(1.0 - t, 1.4)
			wave += sin(phase * 3.0) * 0.08 * pow(1.0 - t, 1.9)
			bytes.encode_s16(
				(note * frames_per_note + i) * 2, int(wave * env * 32767.0 * volume)
			)
	return _wav(bytes)


## Gota d'água: a frequência desce (integrando a fase, sem "zipper") e o
## envelope respira — lê como água em qualquer altura da pentatônica.
func _bloop(frequencies: Array, note_duration: float, volume: float) -> AudioStreamWAV:
	var frames_per_note: int = int(SAMPLE_RATE * note_duration)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(frames_per_note * frequencies.size() * 2)
	for note: int in frequencies.size():
		var target: float = float(frequencies[note])
		var phase: float = 0.0
		for i: int in frames_per_note:
			var t: float = float(i) / float(frames_per_note)
			var frequency: float = target + target * 0.45 * pow(1.0 - t, 1.3)
			phase += TAU * frequency / SAMPLE_RATE
			var env: float = minf(t / 0.18, 1.0) * pow(1.0 - t, 1.7)
			var wave: float = sin(phase) + sin(phase * 2.0) * 0.12 * (1.0 - t)
			bytes.encode_s16(
				(note * frames_per_note + i) * 2, int(wave * env * 32767.0 * volume)
			)
	return _wav(bytes)


## Sopro suave: ruído branco determinístico filtrado por one-pole — o corte
## baixo vira "ar abafado" (secador), o alto vira "psst" curto (perfume).
func _air(duration: float, volume: float, cutoff: float) -> AudioStreamWAV:
	var frames: int = int(SAMPLE_RATE * duration)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(frames)
	var filtered: float = 0.0
	for i: int in frames:
		var t: float = float(i) / float(frames)
		var noise: float = fmod(sin(float(i) * 12.9898) * 43758.5453, 1.0) * 2.0 - 1.0
		filtered += (noise - filtered) * cutoff
		samples[i] = filtered * pow(sin(PI * t), 0.8)
	return _wav_norm(samples, volume)


## Borrifada: sopro brilhante com um ping pentatônico discreto por cima —
## recompensa a borrifada certa sem assobio agudo.
func _spray(volume: float) -> AudioStreamWAV:
	var duration: float = 0.16
	var frames: int = int(SAMPLE_RATE * duration)
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(frames)
	var filtered: float = 0.0
	for i: int in frames:
		var t: float = float(i) / float(frames)
		var noise: float = fmod(sin(float(i) * 12.9898) * 43758.5453, 1.0) * 2.0 - 1.0
		filtered += (noise - filtered) * 0.38
		var air: float = filtered * pow(sin(PI * t), 0.7)
		var ping_env: float = minf(t / ATTACK, 1.0) * pow(1.0 - t, 2.2)
		var ping: float = sin(TAU * 1046.50 * float(i) / SAMPLE_RATE) * ping_env * 0.25
		samples[i] = air + ping
	return _wav_norm(samples, volume)


## Ruído tem pico ~2x maior que tom pelo mesmo volume; normalizar pelo pico
## faz `volume` significar a mesma intensidade em qualquer timbre (0.95 é a
## relação pico/volume medida nos plucks).
func _wav_norm(samples: PackedFloat32Array, volume: float) -> AudioStreamWAV:
	var peak: float = 0.0
	for s: float in samples:
		peak = maxf(peak, absf(s))
	var scale: float = volume * 0.95 / peak if peak > 0.0 else 0.0
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		bytes.encode_s16(i * 2, int(samples[i] * scale * 32767.0))
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
	var filtered: float = 0.0
	for i: int in frames:
		var time: float = float(i) / SAMPLE_RATE
		var beat_position: float = fmod(time, beat_length)
		var sample_value: float = 0.0
		# Bumbo macio no tempo: pulso tátil sem estouro.
		sample_value += sin(TAU * 58.0 * beat_position * (1.0 - beat_position * 2.2)) * 0.12
		# Contratempo: "tique" de ruído filtrado (vassourinha), bem baixo —
		# antes era um apito de 3,1 kHz puro que irritava em loop longo.
		if int(time / (beat_length * 0.5)) % 2 == 1:
			var offbeat: float = fmod(time, beat_length * 0.5) / (beat_length * 0.5)
			var noise: float = fmod(sin(float(i) * 12.9898) * 43758.5453, 1.0) * 2.0 - 1.0
			filtered += (noise - filtered) * 0.55
			sample_value += filtered * (1.0 - offbeat) * 0.028
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
