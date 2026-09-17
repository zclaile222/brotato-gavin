# 音频管理器 - 程序化生成音效
# 使用方法：在 Project > AutoLoad 中添加此脚本，节点名设为 AudioManager
extends Node

var sfx_volume = 0.8  # 0.0 ~ 1.0

# BGM 相关变量
var bgm_player: AudioStreamPlayer
var bgm_playback: AudioStreamGeneratorPlayback
var bgm_time = 0.0
var bgm_mode = ""  # "battle" or "shop"
var bgm_sample_rate = 22050.0

func _ready():
	# 创建 BGM 专用播放器
	bgm_player = AudioStreamPlayer.new()
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = bgm_sample_rate
	gen.buffer_length = 0.5
	bgm_player.stream = gen
	bgm_player.volume_db = -8.0
	add_child(bgm_player)

func _process(_delta):
	if bgm_mode != "" and bgm_playback != null:
		# 持续填充音频帧
		var frames_available = bgm_playback.get_frames_available()
		for i in range(frames_available):
			bgm_time += 1.0 / bgm_sample_rate
			var sample = _generate_bgm_sample(bgm_time)
			bgm_playback.push_frame(Vector2(sample, sample))
	# 心跳音效
	_generate_heartbeat()

func set_sfx_volume(vol: float):
	sfx_volume = clamp(vol, 0.0, 1.0)

func set_bgm_volume(vol: float):
	if bgm_player:
		bgm_player.volume_db = linear_to_db(clamp(vol, 0.0, 1.0))

func set_master_volume(value: float):
	var vol = clamp(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(vol))

# --- BGM 控制接口 ---

func start_battle_bgm():
	if bgm_mode == "battle":
		return
	bgm_mode = "battle"
	bgm_time = 0.0
	bgm_player.play()
	bgm_playback = bgm_player.get_stream_playback()

func start_shop_bgm():
	if bgm_mode == "shop":
		return
	bgm_mode = "shop"
	bgm_time = 0.0
	bgm_player.play()
	bgm_playback = bgm_player.get_stream_playback()

func stop_bgm():
	bgm_mode = ""
	bgm_player.stop()

func _generate_bgm_sample(t: float) -> float:
	if bgm_mode == "battle":
		return _battle_bgm(t)
	elif bgm_mode == "shop":
		return _shop_bgm(t)
	return 0.0

func _battle_bgm(t: float) -> float:
	# 战斗BGM：节拍=140BPM，低频bass + 高频melody
	var beat = fmod(t, 60.0 / 140.0)

	# Bass line: 低频正弦 100-150Hz，每拍一次
	var bass_freq = 110.0 if beat < 0.05 else 80.0
	var bass = sin(t * TAU * bass_freq) * 0.3 * exp(-beat * 8.0)

	# Kick drum: 极低频噪声爆发
	var kick = (randf() * 2.0 - 1.0) * 0.3 * exp(-beat * 20.0)

	# Hi-hat: 每半拍高频噪声
	var halfbeat = fmod(t, 30.0 / 140.0)
	var hihat = (randf() * 2.0 - 1.0) * 0.1 * exp(-halfbeat * 40.0)

	# Melody: 简单方波旋律（重复8小节）
	var melody_notes = [220.0, 246.0, 261.0, 293.0, 329.0, 261.0, 246.0, 220.0]
	var note_idx = int(fmod(t, 8 * 60.0 / 140.0) / (60.0 / 140.0)) % 8
	var melody_freq = melody_notes[note_idx]
	var melody = sign(sin(t * TAU * melody_freq)) * 0.15

	return clamp(bass + kick + hihat + melody, -1.0, 1.0)

func _shop_bgm(t: float) -> float:
	# 商店BGM：轻柔正弦旋律，100BPM
	var notes = [261.0, 329.0, 392.0, 329.0, 261.0, 329.0, 392.0, 523.0]
	var note_dur = 60.0 / 100.0
	var note_idx = int(fmod(t, 8 * note_dur) / note_dur) % 8
	var freq = notes[note_idx]
	var envelope = sin(fmod(t, note_dur) / note_dur * PI)
	var melody = sin(t * TAU * freq) * 0.2 * envelope

	# 和弦背景
	var chord = sin(t * TAU * 130.0) * 0.1 + sin(t * TAU * 164.0) * 0.08

	return clamp(melody + chord, -1.0, 1.0)

# --- 音效播放接口 ---

func play_shoot():
	_play_tone(880.0, 0.06, -12.0)

func play_hit():
	_play_noise(0.08, -14.0)

func play_enemy_die():
	_play_sweep(600.0, 150.0, 0.15, -10.0)

func play_player_hurt():
	_play_noise(0.15, -8.0)

func play_level_up():
	# 上升音阶：连续三个升调短音
	_play_tone(440.0, 0.08, -10.0)
	get_tree().create_timer(0.1).timeout.connect(func(): _play_tone(554.37, 0.08, -10.0))
	get_tree().create_timer(0.2).timeout.connect(func(): _play_tone(659.25, 0.12, -10.0))

func play_buy():
	_play_tone(1200.0, 0.05, -10.0)
	get_tree().create_timer(0.06).timeout.connect(func(): _play_tone(1600.0, 0.05, -10.0))

func play_wave_start():
	_play_tone(120.0, 0.2, -6.0)
	get_tree().create_timer(0.15).timeout.connect(func(): _play_tone(90.0, 0.25, -6.0))

# 心跳音效（低血量时循环播放）
var heartbeat_player: AudioStreamPlayer = null
var heartbeat_playback: AudioStreamGeneratorPlayback = null
var heartbeat_active = false
var heartbeat_time = 0.0
var heartbeat_volume = 0.5  # 0~1，随HP变化

func play_heartbeat(intensity: float = 0.5):
	heartbeat_volume = clamp(intensity, 0.0, 1.0)
	if heartbeat_active:
		if heartbeat_player:
			heartbeat_player.volume_db = linear_to_db(heartbeat_volume * sfx_volume) - 4.0
		return
	heartbeat_active = true
	heartbeat_time = 0.0
	if heartbeat_player == null:
		heartbeat_player = AudioStreamPlayer.new()
		var gen = AudioStreamGenerator.new()
		gen.mix_rate = 22050.0
		gen.buffer_length = 0.5
		heartbeat_player.stream = gen
		add_child(heartbeat_player)
	heartbeat_player.volume_db = linear_to_db(heartbeat_volume * sfx_volume) - 4.0
	heartbeat_player.play()
	heartbeat_playback = heartbeat_player.get_stream_playback()

func stop_heartbeat():
	heartbeat_active = false
	if heartbeat_player:
		heartbeat_player.stop()

func _generate_heartbeat():
	if not heartbeat_active or heartbeat_playback == null:
		return
	var frames = heartbeat_playback.get_frames_available()
	for i in range(frames):
		heartbeat_time += 1.0 / 22050.0
		# 双峰心跳：每0.7秒一个周期，两个峰间隔0.15秒
		var cycle = fmod(heartbeat_time, 0.7)
		var sample = 0.0
		# 第一个峰（lub）
		if cycle < 0.08:
			sample = sin(cycle / 0.08 * PI) * sin(cycle * TAU * 60.0) * 0.8
		# 第二个峰（dub）
		elif cycle >= 0.15 and cycle < 0.22:
			var t2 = cycle - 0.15
			sample = sin(t2 / 0.07 * PI) * sin(t2 * TAU * 45.0) * 0.6
		heartbeat_playback.push_frame(Vector2(sample, sample))

# --- 内部音效生成 ---

func _play_tone(freq: float, duration: float, base_db: float):
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = duration + 0.05

	var player = AudioStreamPlayer.new()
	player.stream = gen
	player.volume_db = base_db + linear_to_db(sfx_volume)
	add_child(player)
	player.play()

	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	var sample_count = int(gen.mix_rate * duration)
	var phase = 0.0
	var increment = freq / gen.mix_rate

	for i in range(sample_count):
		# 正弦波 + 简单衰减包络
		var envelope = 1.0 - float(i) / float(sample_count)
		var sample = sin(phase * TAU) * envelope
		playback.push_frame(Vector2(sample, sample))
		phase += increment

	# 自动清理
	get_tree().create_timer(duration + 0.1).timeout.connect(player.queue_free)

func _play_noise(duration: float, base_db: float):
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = duration + 0.05

	var player = AudioStreamPlayer.new()
	player.stream = gen
	player.volume_db = base_db + linear_to_db(sfx_volume)
	add_child(player)
	player.play()

	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	var sample_count = int(gen.mix_rate * duration)

	for i in range(sample_count):
		var envelope = 1.0 - float(i) / float(sample_count)
		var sample = randf_range(-1.0, 1.0) * envelope
		playback.push_frame(Vector2(sample, sample))

	get_tree().create_timer(duration + 0.1).timeout.connect(player.queue_free)

func _play_sweep(freq_start: float, freq_end: float, duration: float, base_db: float):
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = duration + 0.05

	var player = AudioStreamPlayer.new()
	player.stream = gen
	player.volume_db = base_db + linear_to_db(sfx_volume)
	add_child(player)
	player.play()

	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	var sample_count = int(gen.mix_rate * duration)
	var phase = 0.0

	for i in range(sample_count):
		var t = float(i) / float(sample_count)
		var freq = lerp(freq_start, freq_end, t)
		var envelope = 1.0 - t
		var sample = sin(phase * TAU) * envelope
		playback.push_frame(Vector2(sample, sample))
		phase += freq / gen.mix_rate

	get_tree().create_timer(duration + 0.1).timeout.connect(player.queue_free)
