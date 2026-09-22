extends RefCounted
# 절차적 효과음 생성기 — 코드로 PCM 생성(AudioStreamWAV). 라이선스 청정·에셋 0.
# preload로 사용: const SfxGen := preload("res://sfx_gen.gd")

const RATE := 22050
const VERSION := 1

static func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

# 톤(주파수 스윕 + 감쇠). wave: "sine"/"square"/"noise"
static func tone(f0: float, f1: float, dur: float, wave: String, vol: float, seed: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var u := float(i) / float(n)
		var f := lerpf(f0, f1, u)
		phase += TAU * f / RATE
		var s := 0.0
		if wave == "square":
			s = 1.0 if sin(phase) >= 0.0 else -1.0
		elif wave == "noise":
			s = rng.randf() * 2.0 - 1.0
		else:
			s = sin(phase)
		var env := 1.0 - u          # 선형 감쇠
		var v := int(clampf(s * env * vol, -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	return _wav(data)

# 상승 아르페지오(레벨업)
static func arpeggio(freqs: Array, step: float, wave: String, vol: float) -> AudioStreamWAV:
	var seg := int(step * RATE)
	var data := PackedByteArray()
	data.resize(seg * freqs.size() * 2)
	var idx := 0
	for fi in freqs.size():
		var f := float(freqs[fi])
		var phase := 0.0
		for i in seg:
			phase += TAU * f / RATE
			var s := 1.0 if (wave == "square" and sin(phase) >= 0.0) else sin(phase)
			var env := 1.0 - float(i) / float(seg) * 0.5
			data.encode_s16(idx * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32000.0))
			idx += 1
	return _wav(data)

# 이름별 프리셋 생성
static func make(name: String) -> AudioStreamWAV:
	match name:
		"attack":  return tone(600.0, 200.0, 0.10, "square", 0.35, 1)   # 스윙
		"spell":   return tone(300.0, 900.0, 0.16, "sine", 0.4, 2)      # 시전 상승
		"hit":     return tone(160.0, 60.0, 0.12, "noise", 0.45, 3)     # 타격 노이즈
		"pickup":  return tone(700.0, 1300.0, 0.10, "sine", 0.4, 4)     # 획득 딩
		"levelup": return arpeggio([523.0, 659.0, 784.0, 1046.0], 0.09, "square", 0.35)  # 팡파레
		"death":   return tone(400.0, 80.0, 0.25, "square", 0.4, 6)     # 사망 하강
	return tone(440.0, 440.0, 0.1, "sine", 0.3, 0)
