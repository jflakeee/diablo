extends RefCounted
# 소켓/보석/룬/룬워드/큐브 (Part 6 §2 보석 · Part 2 §4 룬워드 · Part 3 §3 큐브).
# 값은 부분집합 근사 — 정식은 gems.txt/runes.txt/runewords.txt/cubemain.txt. preload로 사용.

const RUNE_ORDER := [
	"Ahn", "Ahnor", "Vey", "Korr", "Saal", "Myr", "Dren", "Pyre", "Volt", "Rime",
	"Nara", "Solun", "Shae", "Doln", "Helm", "Iora", "Luma", "Kovan", "Fara", "Lemn",
	"Pura", "Umon", "Mala", "Istra", "Gulan", "Vexa", "Ohra", "Lorn", "Sura", "Beryn",
	"Jahar", "Chama", "Zorin",
]

# 룬 소켓 스탯(슬롯별) — 룬워드에 쓰이는 룬 위주 부분집합
const RUNE_STATS := {
	"Ahn": {"weapon": {"ar": 50}, "armor": {"def": 15}},
	"Vey": {"weapon": {"mana": 2}, "armor": {"mana": 2}},
	"Korr": {"weapon": {}, "armor": {"def": 30}},
	"Saal": {"weapon": {}, "armor": {"mana": 3}},
	"Dren": {"weapon": {}, "armor": {"res_all": 5}},
	"Pyre": {"weapon": {"res_all": 5}, "armor": {"res_all": 5}},
}

# Perfect 보석 스탯(슬롯별) — Part 6 §2 (매핑 가능한 stat만)
const GEM_STATS := {
	"amethyst": {"weapon": {"ar": 150}, "armor": {"str": 10}},
	"diamond": {"weapon": {"ar": 100}, "armor": {"res_all": 19}},
	"ruby": {"weapon": {}, "armor": {"life": 38}},
	"sapphire": {"weapon": {}, "armor": {"mana": 38}},
	"emerald": {"weapon": {}, "armor": {"dex": 10}},
	"topaz": {"weapon": {}, "armor": {"res_all": 0}},
	"skull": {"weapon": {}, "armor": {"life": 0}},
}

# 룬워드(부분집합) — stats는 매핑 근사
const RUNEWORDS := [
	{"name": "Tempered Edge", "runes": ["Vey", "Ahn"], "slot": "weapon", "sockets": 2, "stats": {"ed": 20, "ar": 50}},
	{"name": "Veiled Step", "runes": ["Dren", "Saal"], "slot": "armor", "sockets": 2, "stats": {"dex": 6, "mana": 15}},
	{"name": "Gloom Crown", "runes": ["Korr", "Vey"], "slot": "helm", "sockets": 2, "stats": {"def": 50}},
]

static func gem_stat(gem: String, slot: String) -> Dictionary:
	var g: Dictionary = GEM_STATS.get(gem, {})
	return g.get(slot, {})

static func rune_stat(rune: String, slot: String) -> Dictionary:
	var r: Dictionary = RUNE_STATS.get(rune, {})
	return r.get(slot, {})

static func match_runeword(slot: String, socketed_runes: Array) -> Dictionary:
	for rw in RUNEWORDS:
		if rw["slot"] == slot and int(rw["sockets"]) == socketed_runes.size():
			var same := true
			for i in socketed_runes.size():
				if String(rw["runes"][i]) != String(socketed_runes[i]):
					same = false
					break
			if same:
				return rw
	return {}

# 큐브: 동일 하위 룬 3개 → 다음 룬 (Part 3 §3)
static func upgrade_rune(id: String) -> String:
	var i := RUNE_ORDER.find(id)
	if i >= 0 and i < RUNE_ORDER.size() - 1:
		return RUNE_ORDER[i + 1]
	return ""

# 큐브: 보석 3개 → 다음 등급
const GEM_QUALITY := ["chipped", "flawed", "normal", "flawless", "perfect"]

static func upgrade_gem_quality(q: String) -> String:
	var i := GEM_QUALITY.find(q)
	if i >= 0 and i < GEM_QUALITY.size() - 1:
		return GEM_QUALITY[i + 1]
	return ""
