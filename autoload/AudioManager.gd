extends Node
## SFX com identidade própria por ação + música ambiente sintetizada aqui.
##
## Os efeitos deixaram de ser osciladores de runtime: cada ação tem o SEU
## instrumento, modelado fisicamente em `tools/gen_sfx.py` (fonte única) e
## versionado como WAV em `audio/sfx/` — 44,1 kHz, 16 bits, estéreo com sala
## nos eventos e mono seco nos ticks de gesto (SFX 44,1 kHz importado;
## BGM procedural 22,05 kHz — cada AudioStreamWAV preserva seu mix_rate).
## O jogo só carrega e mixa, sem custo de síntese na inicialização:
##   * banho — bolhas d'água (glissando de Minnaert) + respingo + corpo de água;
##   * tosa — tesourada: lâmina em varredura + ring metálico + batida;
##   * secagem — sopro de ar (ruído rosa) com brilho subindo + motor;
##   * laço — corda de náilon dedilhada (Karplus-Strong com detune);
##   * perfume — aerossol: válvula + chiado do bico + ping de vidro;
##   * UI/recompensas/erros/pets — marimba, harpa, tilinte, vidro, guinchos.
##
## Contratos que permanecem:
##   * tudo em pentatônica de Dó maior: qualquer sequência de SFX continua
##     consonante com o loop ambiente (C, Am, F, G) — errar não "briga";
##   * pool de 4 vozes (round-robin): sons se sobrepõem em vez de cortar;
##   * play_progress — o som do gesto SOBE com o progresso: 10 degraus por
##     serviço, alternando com o degrau seguinte e micro-jitter de afinação.
##     O jogador ouve a aproximação dos 100%; drenar ou passar da janela toca
##     uma oitava abaixo (aviso de perda);
##   * "window" — harpa de vidro ao entrar na faixa do perfect: dá para dosar
##     o momento de soltar de ouvido;
##   * a música (ambiente + camada de energia) segue sintetizada neste arquivo
##     e não foi tocada — apenas os efeitos mudaram de fonte.

const SAMPLE_RATE: int = 44100
## WAVs de SFX versionados (gerados por tools/gen_sfx.py).
const SFX_DIR: String = "res://audio/sfx/"
## BGM por tier (WAVs gerados por gen_bgm.py) + fallback procedural relaxante.
const BGM_DIR: String = "res://audio/bgm/"
const BGM_BY_TIER: Array[StringName] = [&"bgm_quintal", &"bgm_clinica", &"bgm_imperio"]
## Ganho da música relaxante (loop procedural) — mais baixa e aconchegante.
const BGM_RELAX_GAIN: float = 0.22
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
## Cache em disco para evitar 4.6M sin() no boot (lazy + user://).
const CACHE_DIR: String = "user://audio_cache/"

var voices: Array[AudioStreamPlayer] = []
var voice_index: int = 0
var music_player: AudioStreamPlayer
var energy_player: AudioStreamPlayer
var current_bgm: StringName = &""
var energy_target_db: float = ENERGY_OFF_DB
var cache: Dictionary = {}
var tick_counter: Dictionary = {}
## Chime da janela perfeita: toca UMA vez por entrada na faixa; rearma
## sozinho quando o progresso cai abaixo dela (progresso 0 em novo serviço).
var window_chime_armed: bool = true
# ── Voz / Narração kids (pt-BR) — mutável já na 1ª tela, respeita settings["voice"]
const VO_DIR: String = "res://audio/vo/"
var voice_player: AudioStreamPlayer
var voice_cache: Dictionary = {}
var _ambient_cache: AudioStreamWAV = null
var _energy_cache: AudioStreamWAV = null


func _ready() -> void:
	for i: int in VOICE_COUNT:
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.bus = &"SFX"
		add_child(voice)
		voices.append(voice)
	_build_sfx_cache()
	# Voz kids dedicada (não compete com pool de SFX)
	voice_player = AudioStreamPlayer.new()
	voice_player.bus = &"Master"
	add_child(voice_player)
	_build_voice_cache()
	music_player = AudioStreamPlayer.new()
	music_player.bus = &"Music"
	add_child(music_player)
	play_bgm_for_tier(GameState.establishment_tier)
	# Novo capítulo = nova trilha (crossfade curto), sem tocar no Main.
	EventBus.reveal_requested.connect(
		func(kind: StringName, payload: Dictionary) -> void:
			if kind == &"chapter":
				play_bgm_for_tier(int(payload.get("tier", 1)))
	)
	# Camada de energia: percussão entra durante o serviço e sai suave no fim.
	energy_player = AudioStreamPlayer.new()
	energy_player.bus = &"Music"
	# Lazy: gera apenas quando necessário, com cache
	energy_player.stream = _get_energy_loop_cached()
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
	# --- Ticks progressivos do gesto: 10 degraus que sobem com o progresso.
	_cache_ladder(&"bubble", 10)
	_cache_ladder(&"clipper", 10)
	_cache_ladder(&"dryer", 10)
	_cache_ladder(&"bow", 10)
	# --- Perfume: cada borrifada sobe uma nota (C6→D6→E6) — a 3ª é o perfect.
	cache[&"spray_0"] = _load_sfx(&"spray_0")
	cache[&"spray_1"] = _load_sfx(&"spray_1")
	cache[&"spray_2"] = _load_sfx(&"spray_2")
	cache[&"spray"] = cache[&"spray_0"]
	# Aviso de janela perfeita: harpa de vidro "pode soltar".
	cache[&"window"] = _load_sfx(&"window")
	# --- Toques e painéis (frequentes: discretos) ---
	cache[&"tap"] = _load_sfx(&"tap")
	cache[&"tool_pickup"] = _load_sfx(&"tool_pickup")
	cache[&"panel_open"] = _load_sfx(&"panel_open")
	cache[&"equip"] = _load_sfx(&"equip")
	# --- Serviço e recompensa ---
	cache[&"service_start"] = _load_sfx(&"service_start")
	cache[&"coin"] = _load_sfx(&"coin")
	cache[&"perfect"] = _load_sfx(&"perfect")
	cache[&"upgrade"] = _load_sfx(&"upgrade")
	cache[&"level_up"] = _load_sfx(&"level_up")
	cache[&"review"] = _load_sfx(&"review")
	cache[&"pass_claim"] = _load_sfx(&"pass_claim")
	cache[&"prestige"] = _load_sfx(&"prestige")
	cache[&"comeback"] = _load_sfx(&"comeback")
	cache[&"share_saved"] = _load_sfx(&"share_saved")
	# --- Pets e erros: suaves, graves, sem bronca ---
	cache[&"pet_happy"] = _load_sfx(&"pet_happy")
	cache[&"pet_surprise"] = _load_sfx(&"pet_surprise")
	cache[&"error_soft"] = _load_sfx(&"error_soft")
	cache[&"error"] = _load_sfx(&"error")
	cache[&"freeze"] = _load_sfx(&"freeze")


func play(sfx: StringName) -> void:
	_play_entry(sfx, 1.0)


## Trilha do gesto em andamento (chamada a cada tick do arrastar): tick
## progressivo + chime da janela perfeita. Perfume não tem trilha de arrasto
## — cada borrifada é um evento com nota própria (spray_0..2, via Main).
func play_gesture(service: StringName, bath: BathService) -> void:
	if bath.fill_mode == &"pulse":
		return
	play_progress(
		SalonTuning.service_sound(service),
		bath.progress,
		bath.progress > bath.target_maximum
		or (bath.fill_mode == &"zone" and not bath.zone_inside)
	)
	# Janela perfeita: brilho de harpa "pode soltar" — uma vez por entrada.
	if bath.progress >= bath.target_minimum and bath.progress <= bath.target_maximum:
		if window_chime_armed:
			window_chime_armed = false
			play(&"window")
	elif bath.progress < bath.target_minimum:
		window_chime_armed = true


## Som de loop do gesto COM progresso (0..1): o degrau da pentatônica é
## escolhido pelo avanço da ação — a nota sobe conforme o gesto se aproxima
## dos 100%, alternando com o degrau seguinte (movimento) e micro-jitter de
## afinação (vida). `muted` = drenando ou passado da janela: uma oitava
## abaixo e mais baixo — o jogador ouve que está perdendo progresso.
func play_progress(sfx: StringName, progress: float, muted: bool = false) -> void:
	if String(sfx).is_empty():
		return
	var entry: StringName = sfx
	var variants: int = int(cache.get("variants_" + String(sfx), 0))
	var rung: int = 0
	if variants > 0:
		rung = clampi(int(clampf(progress, 0.0, 1.0) * float(variants)), 0, variants - 1)
		tick_counter[String(sfx)] = int(tick_counter.get(String(sfx), 0)) + 1
		if int(tick_counter[String(sfx)]) % 2 == 1:
			rung = mini(rung + 1, variants - 1)
		entry = StringName("%s_%d" % [sfx, rung])
	var pitch: float = randf_range(0.992, 1.008)
	# Swell: intensifica suavemente conforme a ação avança.
	var volume_scale: float = 0.8 + 0.4 * clampf(progress, 0.0, 1.0)
	if muted:
		pitch *= 0.5
		volume_scale = 0.5
	_play_entry(entry, pitch, volume_scale)


func _play_entry(sfx: StringName, pitch: float, volume_scale: float = 1.0) -> void:
	if not cache.has(sfx):
		return
	# `as` (e não cast direto): o cache também guarda contadores de variantes.
	var stream: AudioStreamWAV = cache[sfx] as AudioStreamWAV
	if stream == null:
		return
	var sfx_volume: float = clampf(
		clampf(float(GameState.settings.get("sfx", 0.9)), 0.0001, 1.0) * volume_scale,
		0.0001,
		1.0
	)
	var voice: AudioStreamPlayer = _next_voice()
	voice.pitch_scale = pitch
	voice.volume_db = linear_to_db(sfx_volume)
	voice.stream = stream
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


func _process(delta: float) -> void:
	if is_instance_valid(energy_player) and not is_equal_approx(
		energy_player.volume_db, energy_target_db
	):
		# Frame-rate independent fade: 90 dB/s aprox (1.5*60)
		energy_player.volume_db = move_toward(energy_player.volume_db, energy_target_db, 90.0 * delta)


## Sliders de ajustes chamam isto para valer na hora (música inclusive).
func apply_volumes() -> void:
	var sfx_volume: float = clampf(float(GameState.settings.get("sfx", 0.9)), 0.0001, 1.0)
	var music_volume: float = clampf(float(GameState.settings.get("music", 0.7)), 0.0001, 1.0)
	# Por player (compat) + por bus (novo layout)
	for voice: AudioStreamPlayer in voices:
		voice.volume_db = linear_to_db(sfx_volume)
	if is_instance_valid(voice_player):
		voice_player.volume_db = linear_to_db(sfx_volume) if is_voice_enabled() else -80.0
	music_player.volume_db = _music_db()
	if is_instance_valid(energy_player):
		# Energy segue música mas um pouco mais baixo
		energy_player.volume_db = clampf(energy_target_db, ENERGY_OFF_DB, ENERGY_ON_DB)
	# Bus volumes (se layout existir)
	if AudioServer.get_bus_index(&"SFX") != -1:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"SFX"), linear_to_db(sfx_volume))
	if AudioServer.get_bus_index(&"Music") != -1:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Music"), linear_to_db(music_volume))

# ── Voz kids ── exposta já na 1ª tela para mutar sem abrir Ajustes
func is_voice_enabled() -> bool:
	return bool(GameState.settings.get("voice", true))

func set_voice_enabled(enabled: bool) -> void:
	GameState.settings["voice"] = enabled
	SaveManager.request_save()
	apply_volumes()
	if not enabled and is_instance_valid(voice_player):
		voice_player.stop()
	EventBus.settings_changed.emit()

## Mapeia serviço → locução kids (pt-BR): gesto específico quando existe.
func voice_for_service(service: StringName) -> StringName:
	match service:
		&"perfume": return &"perfume_spray"
		&"style": return &"bow_here"
		_: return &"drag_soap"


func play_voice(id: StringName) -> void:
	if not is_voice_enabled():
		return
	if voice_cache.is_empty() and not _build_voice_cache():
		pass
	var stream: AudioStream = voice_cache.get(id, null) as AudioStream
	if stream == null:
		stream = _load_voice(id)
		if stream == null:
			return
		voice_cache[id] = stream
	if not is_instance_valid(voice_player):
		return
	# baixa levemente música enquanto narra (ducking)
	if is_instance_valid(music_player):
		music_player.volume_db = _music_db() - 4.0
	voice_player.stream = stream
	voice_player.volume_db = linear_to_db(clampf(float(GameState.settings.get("sfx", 0.9)), 0.0001, 1.0))
	voice_player.play()
	# restaura música quando voz termina
	if voice_player.has_signal("finished"):
		# reconecta a cada play para não acumular
		if voice_player.is_connected("finished", _on_voice_finished):
			voice_player.finished.disconnect(_on_voice_finished)
		voice_player.finished.connect(_on_voice_finished, CONNECT_ONE_SHOT)

func _on_voice_finished() -> void:
	if is_instance_valid(music_player):
		music_player.volume_db = _music_db()

func stop_voice() -> void:
	if is_instance_valid(voice_player):
		voice_player.stop()
		_on_voice_finished()

func _build_voice_cache() -> bool:
	# pré-carrega vozes conhecidas se já existem no disco (não trava se faltar)
	for vid: StringName in [&"drag_soap", &"perfume_spray", &"bow_here", &"perfect", &"choose_client", &"welcome"]:
		var s: AudioStream = _load_voice(vid)
		if s != null:
			voice_cache[vid] = s
	return not voice_cache.is_empty()

func _load_voice(id: StringName) -> AudioStream:
	var base: String = VO_DIR + String(id)
	for ext: String in [".mp3", ".ogg", ".wav"]:
		var path: String = base + ext
		if ResourceLoader.exists(path):
			var loaded: Resource = load(path)
			if loaded is AudioStream:
				return loaded as AudioStream
		# fallback sem import: carrega bytes direto (mp3 gerado em runtime)
		if FileAccess.file_exists(path):
			var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
			if bytes.is_empty():
				continue
			if ext == ".mp3":
				var mp3: AudioStreamMP3 = AudioStreamMP3.new()
				mp3.data = bytes
				return mp3
			elif ext == ".ogg":
				var ogg: AudioStreamOggVorbis = AudioStreamOggVorbis.new()
				# Godot 4 usa _load_ogg? fallback: tenta WAV
				continue
			elif ext == ".wav":
				var wav: AudioStreamWAV = AudioStreamWAV.new()
				wav.data = bytes
				return wav
	return null


## Trilha por tier: tenta WAV por capítulo, fallback para ambient relax procedural.
## Mantém relax como padrão se WAVs não existirem, mas agora usa BGM_BY_TIER.
func play_bgm_for_tier(tier: int) -> void:
	var desired: StringName = &"ambient_relax"
	# Tier mapping: 1-3 quintal, 4-6 clinica, 7+ imperio (se WAVs existirem)
	if tier >= 7 and BGM_BY_TIER.size() > 2:
		desired = BGM_BY_TIER[2]
	elif tier >= 4 and BGM_BY_TIER.size() > 1:
		desired = BGM_BY_TIER[1]
	elif tier >= 1 and BGM_BY_TIER.size() > 0:
		desired = BGM_BY_TIER[0]
	# Se WAV existe, usa; senão fallback relax procedural (mantém relax pedido usuário)
	var wav_path: String = BGM_DIR + String(desired) + ".wav"
	var stream: AudioStreamWAV = null
	if ResourceLoader.exists(wav_path):
		stream = _load_bgm(desired)
		if stream != null:
			desired = desired
		else:
			stream = _get_ambient_loop_cached()
			desired = &"ambient_relax"
	else:
		# Sem WAV, usa procedural relax
		stream = _get_ambient_loop_cached()
		desired = &"ambient_relax"

	if desired == current_bgm and music_player.playing:
		return
	current_bgm = desired
	if music_player.playing:
		var fade: Tween = create_tween()
		fade.tween_property(music_player, "volume_db", -40.0, 0.6)
		fade.tween_callback(
			func() -> void:
				music_player.stream = stream
				music_player.play()
		)
		fade.tween_property(music_player, "volume_db", _music_db(), 0.8)
		return
	music_player.stream = stream
	music_player.volume_db = _music_db()
	music_player.play()


func _music_db() -> float:
	var music_volume: float = clampf(float(GameState.settings.get("music", 0.7)), 0.0001, 1.0)
	return linear_to_db(music_volume * BGM_RELAX_GAIN)


## WAV da trilha (importado) com loop forçado — o importador não sabe que é loop.
func _load_bgm(name: StringName) -> AudioStreamWAV:
	var path: String = BGM_DIR + String(name) + ".wav"
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: BGM ausente: " + path)
		return null
	var stream: AudioStreamWAV = load(path) as AudioStreamWAV
	if stream == null:
		return null
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	var bytes_per_frame: int = 2 if stream.format == AudioStreamWAV.FORMAT_16_BITS else 1
	if stream.stereo:
		bytes_per_frame *= 2
	stream.loop_end = int(stream.data.size() / bytes_per_frame)
	return stream


## Registra os N degraus de uma escada (um WAV por degrau) + o fallback no
## degrau 0 + o contador de variantes usado pelo play_progress.
func _cache_ladder(base: StringName, steps: int) -> void:
	for i: int in steps:
		var entry: StringName = StringName("%s_%d" % [base, i])
		cache[entry] = _load_sfx(entry)
	cache[base] = cache[StringName("%s_%d" % [base, 0])]
	cache["variants_" + String(base)] = steps


## Carrega um SFX versionado (WAV 44,1 kHz gerado por tools/gen_sfx.py).
## Asset ausente não derruba o jogo: devolve null e _play_entry ignora.
func _load_sfx(sfx: StringName) -> AudioStreamWAV:
	var path: String = SFX_DIR + String(sfx) + ".wav"
	if ResourceLoader.exists(path):
		return load(path) as AudioStreamWAV
	push_warning("AudioManager: SFX ausente: " + path)
	return null


## Cache helpers — evita regenerar 352k frames todo boot

func _ensure_cache_dir() -> void:
	if not DirAccess.dir_exists_absolute(CACHE_DIR):
		DirAccess.make_dir_recursive_absolute(CACHE_DIR)


func _get_ambient_loop_cached() -> AudioStreamWAV:
	if _ambient_cache != null:
		return _ambient_cache
	var cache_path: String = CACHE_DIR + "ambient_relax_44100.bin"
	if FileAccess.file_exists(cache_path):
		var fa: FileAccess = FileAccess.open(cache_path, FileAccess.READ)
		if fa != null:
			var expected_frames: int = int(SAMPLE_RATE * 16.0)
			if fa.get_length() == expected_frames * 2:
				var bytes: PackedByteArray = fa.get_buffer(fa.get_length())
				fa.close()
				var s: AudioStreamWAV = _wav(bytes)
				s.loop_mode = AudioStreamWAV.LOOP_FORWARD
				s.loop_begin = 0
				s.loop_end = expected_frames
				_ambient_cache = s
				return s
			fa.close()
	var stream: AudioStreamWAV = _ambient_loop()
	_ambient_cache = stream
	# Salva em background (best effort)
	_ensure_cache_dir()
	var out: FileAccess = FileAccess.open(cache_path, FileAccess.WRITE)
	if out != null:
		out.store_buffer(stream.data)
		out.close()
	return stream


func _get_energy_loop_cached() -> AudioStreamWAV:
	if _energy_cache != null:
		return _energy_cache
	var cache_path: String = CACHE_DIR + "energy_44100.bin"
	if FileAccess.file_exists(cache_path):
		var fa: FileAccess = FileAccess.open(cache_path, FileAccess.READ)
		if fa != null:
			var beat_length: float = 60.0 / MUSIC_BPM
			var expected_frames: int = int(SAMPLE_RATE * beat_length * 8.0)
			if fa.get_length() == expected_frames * 2:
				var bytes: PackedByteArray = fa.get_buffer(fa.get_length())
				fa.close()
				var s: AudioStreamWAV = _wav(bytes)
				s.loop_mode = AudioStreamWAV.LOOP_FORWARD
				s.loop_begin = 0
				s.loop_end = expected_frames
				_energy_cache = s
				return s
			fa.close()
	var stream: AudioStreamWAV = _energy_loop()
	_energy_cache = stream
	_ensure_cache_dir()
	var out: FileAccess = FileAccess.open(cache_path, FileAccess.WRITE)
	if out != null:
		out.store_buffer(stream.data)
		out.close()
	return stream


## Loop relaxante original — restaurado e melhorado:
## 16 s, acordes C/Am/F/G trocando a cada 4 s (antes 2 s), baixo suave uma
## oitava abaixo e melodia pentatônica bem esparsa (1 nota a cada 1 s).
## Ganho baixo (0,22) e crossfade entre acordes = sem cliques, super relax.
func _ambient_loop() -> AudioStreamWAV:
	var duration: float = 16.0
	var frames: int = int(SAMPLE_RATE * duration)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(frames * 2)
	var chords: Array = [
		[261.63, 329.63, 392.00],  # C
		[220.00, 261.63, 329.63],  # Am
		[174.61, 220.00, 261.63],  # F
		[196.00, 246.94, 293.66],  # G
	]
	var chord_duration: float = 4.0
	for i: int in frames:
		var time: float = float(i) / SAMPLE_RATE
		var chord_index: int = int(time / chord_duration) % chords.size()
		var chord: Array = chords[chord_index]
		# Crossfade suave entre acordes (0,4 s)
		var chord_time: float = fmod(time, chord_duration)
		var next_index: int = (chord_index + 1) % chords.size()
		var next_chord: Array = chords[next_index]
		var fade: float = 1.0
		if chord_time > chord_duration - 0.4:
			fade = 1.0 - (chord_time - (chord_duration - 0.4)) / 0.4
		var next_fade: float = 0.0
		if chord_time > chord_duration - 0.4:
			next_fade = (chord_time - (chord_duration - 0.4)) / 0.4
		var sample_value: float = 0.0
		# Acorde atual (pad suave)
		for frequency: float in chord:
			sample_value += sin(TAU * frequency * time) * 0.05 * fade
			# Baixo uma oitava abaixo, bem suave
			sample_value += sin(TAU * frequency * 0.5 * time) * 0.03 * fade
		# Próximo acorde entrando
		for frequency: float in next_chord:
			sample_value += sin(TAU * frequency * time) * 0.05 * next_fade
			sample_value += sin(TAU * frequency * 0.5 * time) * 0.03 * next_fade
		# Melodia pentatônica esparsa: 1 nota a cada 1 s, com decay suave
		var mel_beat: float = fmod(time, 1.0)
		var mel_index: int = int(time) % chord.size()
		var melody_frequency: float = chord[mel_index] * 2.0
		var mel_env: float = (1.0 - mel_beat) * (1.0 - mel_beat)
		sample_value += sin(TAU * melody_frequency * time) * 0.03 * mel_env
		var sample: int = int(clampf(sample_value, -0.25, 0.25) * 32767.0)
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(music_player):
			music_player.stream_paused = true
		if is_instance_valid(energy_player):
			energy_player.stream_paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		if is_instance_valid(music_player):
			music_player.stream_paused = false
		if is_instance_valid(energy_player):
			energy_player.stream_paused = false
