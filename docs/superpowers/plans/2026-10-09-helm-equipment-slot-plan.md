# 헬름(투구) 장비 슬롯 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `prototype/game_dungeon`에 "helm" 장비 슬롯을 신규 추가해 Gloom Crown
룬워드(Korr+Vey)를 실전에서 완성 가능하게 만든다.

**Architecture:** 기존 장착 디스패치(`_equipment_slot_for_item`)·스탯 합산
(`_recompute_player`)·용병 장비 복원(`Mercenary.normalize_equipment`)이 전부
리스트/딕셔너리 순회 기반 제네릭 구조라, "helm" 문자열을 각 리스트/테이블에
끼워 넣는 것만으로 대부분 자동 연동된다. 신규 코드가 필요한 곳은 (1) 헬름
전용 베이스/유니크 데이터, (2) 소켓 개별 효과(`RUNE_STATS`/`GEM_STATS`)의
helm 열, (3) 드롭 확률 브래킷, (4) 소켓 추가 레시피의 슬롯 화이트리스트,
(5) 용병 방어력 가산 분기 — 5곳뿐이다.

**Tech Stack:** Godot 4.7.2 GDScript. 테스트는 이 프로젝트 고유 관행을 따른다 —
pytest 같은 개별 유닛 테스트 러너가 없고, `system_tests.gd`(`_check()` 누적
방식)와 `main.gd` 내부 `_craft_selftest()`(오토퀴트 전용 print 검증) 두
경로로 모든 로직을 검증한다. Godot headless 기동 자체가 수 초~수십 초
걸리므로, 이 계획은 **한 줄 수정마다 실행하는 엄격한 TDD 대신 "관련 코드
변경을 모은 뒤 해당 테스트 경로 1회 실행"** 단위로 스텝을 구성한다(기존
세션의 실제 작업 리듬과 동일, "Executing Plans" 스킬의 "모든 스텝을 정확히
따르되 검증 커맨드는 명시된 대로" 원칙은 유지).

---

## 사전 확인 사항(참고용, 수정 불필요)

다음은 이미 제네릭하게 동작해 **코드 변경이 필요 없음**을 탐색으로 확인한
지점이다 — 작업 중 "여기도 고쳐야 하나?"라는 의심이 들면 이 목록을 먼저
확인할 것:

- `main.gd _equipment_slot_for_item()` — ring/charm만 특별 처리, 나머지는
  `item_slot` 그대로 반환. helm도 자동 처리됨.
- `main.gd _recompute_player()` — `EQUIPMENT_SLOTS` 순회라 거기 추가하면 자동.
- `main.gd` 아이콘 `match slot:` 분기 — helm은 기본값 "shield" 아이콘을
  그대로 받음, 아틀라스 작업 불필요.
- `main.gd` "Merc" 버튼 노출 조건(`slot in Mercenary.SLOTS`) — `Mercenary.SLOTS`에
  helm을 추가하면 자동으로 뜸.
- `craft.gd can_remove_sockets()` — 슬롯을 전혀 보지 않는 구조라 변경 불필요
  (설계 발표 때 "2곳 수정" 언급했던 것의 정정 — 실제로는 `can_add_sockets()` 한 곳만).
- `item.gd display_name()`/`affix_text()`/`quality_color()`/`durability_max()` —
  전부 슬롯 무관 제네릭.
- `main.gd` 전투 중 HUD 라벨(약 2860행) — 원래도 weapon/armor만 표시(ring/
  amulet/charm도 안 보임), helm도 **의도적으로 추가하지 않음**(인벤토리
  패널의 전체 장비 목록에만 추가).

---

### Task 1: 헬름 베이스/유니크 데이터 + 조회 헬퍼 (`item.gd`)

**Files:**
- Modify: `prototype/game_dungeon/item.gd:13-43` (베이스/유니크 상수), `item.gd:84-89`
  (`_eligible`), `item.gd:148-161` (`find_base`), `item.gd:298-302` (`identify`)
- Test: `prototype/game_dungeon/system_tests.gd` (새 체크 추가는 Task 7에서),
  이 Task는 `tools/progression_combat_test.gd`로 회귀만 확인

- [ ] **Step 1: `HELM_BASES` 상수 추가**

`item.gd`의 `ARMOR_BASES` 정의 바로 다음, `ACCESSORY_BASES` 앞에 삽입:

```gdscript
const HELM_BASES := [
	{"name": "Leather Cap", "slot": "helm", "defense": 5, "req_level": 1, "req_str": 8, "req_dex": 0},
	{"name": "Bone Skullcap", "slot": "helm", "defense": 9, "req_level": 2, "req_str": 12, "req_dex": 0},
	{"name": "Iron Sallet", "slot": "helm", "defense": 16, "req_level": 5, "req_str": 22, "req_dex": 0},
]
```

- [ ] **Step 2: `UNIQUES`에 헬름 3종 추가**

`UNIQUES` 딕셔너리의 마지막 항목(`"Ashen Pendant": ...`) 다음 줄에 추가(닫는
`}` 앞):

```gdscript
	"Leather Cap": {"name": "Scoutlight Hood", "affixes": {"def": [16, 24], "dex": [8, 12], "ar": [20, 30]}},
	"Bone Skullcap": {"name": "Marrowguard", "affixes": {"def": [28, 42], "life": [16, 24], "str": [6, 10]}},
	"Iron Sallet": {"name": "Warden's Judgment", "affixes": {"def": [40, 60], "res_all": [12, 18], "mana": [14, 20]}},
```

- [ ] **Step 3: `find_base()`에 helm 분기 추가**

`find_base()`의 `elif slot == "armor": pool = ARMOR_BASES` 다음 줄에 삽입:

```gdscript
	elif slot == "helm":
		pool = HELM_BASES
```

(전체 함수가 다음과 같은 모양이 되어야 함: weapon → armor → **helm(신규)** →
ring/amulet → charm)

- [ ] **Step 4: `identify()` 슬롯 화이트리스트에 helm 추가**

변경 전:
```gdscript
static func identify(it: Dictionary) -> bool:
	if is_identified(it) or String(it.get("slot", "")) not in ["weapon", "armor", "ring", "amulet", "charm"]:
		return false
```

변경 후:
```gdscript
static func identify(it: Dictionary) -> bool:
	if is_identified(it) or String(it.get("slot", "")) not in ["weapon", "armor", "helm", "ring", "amulet", "charm"]:
		return false
```

- [ ] **Step 5: `_eligible()`에 armor/helm 접사 동치 처리 추가**

변경 전:
```gdscript
static func _eligible(table: Array, ilvl: int, slot: String) -> Array:
	var out: Array = []
	for a in table:
		if int(a["alvl"]) <= ilvl and (a["slot"] == "any" or a["slot"] == slot):
			out.append(a)
	return out
```

변경 후:
```gdscript
static func _eligible(table: Array, ilvl: int, slot: String) -> Array:
	var out: Array = []
	for a in table:
		var a_slot := String(a["slot"])
		var matches := a_slot == "any" or a_slot == slot or (a_slot == "armor" and slot == "helm")
		if int(a["alvl"]) <= ilvl and matches:
			out.append(a)
	return out
```

(이걸 안 하면 "Reinforced"(+def) 접두사가 `slot:"armor"`로만 매칭돼 헬름은
영원히 이 접두사를 못 받는다 — armor 계열 방어 접사 풀에 helm도 편입.)

- [ ] **Step 6: 회귀 확인**

Run: `cd prototype/game_dungeon && godot --headless --path . --script res://tools/progression_combat_test.gd`
Expected: `[PROGRESSION_COMBAT] system_checks=120 save_checks=24 failures=[] verdict=PASS`
(이 시점엔 아직 helm 전용 체크를 추가하지 않았으므로 숫자는 그대로 120 —
기존 로직이 안 깨졌는지만 확인하는 단계)

- [ ] **Step 7: 커밋**

```bash
git add prototype/game_dungeon/item.gd
git commit -m "Add HELM_BASES, helm uniques, and identify/affix-pool support"
```

---

### Task 2: 드롭 확률 브래킷 재조정 (`item.gd`)

**Files:**
- Modify: `prototype/game_dungeon/item.gd:256-291` (`roll_drop`)

- [ ] **Step 1: `roll_drop()`의 베이스 카테고리 분기 수정**

변경 전:
```gdscript
	var base_roll := rng.randf()
	if base_roll < 0.38:
		base = WEAPON_BASES[rng.randi_range(0, WEAPON_BASES.size() - 1)]
	elif base_roll < 0.72:
		base = ARMOR_BASES[rng.randi_range(0, ARMOR_BASES.size() - 1)]
	elif base_roll < 0.86:
		base = ACCESSORY_BASES[rng.randi_range(0, ACCESSORY_BASES.size() - 1)]
	else:
		base = CHARM_BASES[rng.randi_range(0, CHARM_BASES.size() - 1)]
```

변경 후:
```gdscript
	var base_roll := rng.randf()
	if base_roll < 0.38:
		base = WEAPON_BASES[rng.randi_range(0, WEAPON_BASES.size() - 1)]
	elif base_roll < 0.62:
		base = ARMOR_BASES[rng.randi_range(0, ARMOR_BASES.size() - 1)]
	elif base_roll < 0.72:
		base = HELM_BASES[rng.randi_range(0, HELM_BASES.size() - 1)]
	elif base_roll < 0.86:
		base = ACCESSORY_BASES[rng.randi_range(0, ACCESSORY_BASES.size() - 1)]
	else:
		base = CHARM_BASES[rng.randi_range(0, CHARM_BASES.size() - 1)]
```

(weapon 38%는 그대로, armor 34%→24%, helm 신규 10%, accessory/charm 임계값
`0.86`/나머지는 그대로 — 합계 100% 유지. 이 변경은 seed=42 오토퀴트의 아이템
드롭 지문을 합법적으로 바꾼다 — RNG 공유 버그가 아니라 의도된 콘텐츠
변경이니 Task 9에서 `kills=0` 같은 이상 신호만 확인하고 드롭 내용 자체가
달라지는 것은 정상으로 간주할 것.)

- [ ] **Step 2: 회귀 확인**

Run: `cd prototype/game_dungeon && godot --headless --path . --script res://tools/progression_combat_test.gd`
Expected: `[PROGRESSION_COMBAT] system_checks=120 save_checks=24 failures=[] verdict=PASS`

- [ ] **Step 3: 커밋**

```bash
git add prototype/game_dungeon/item.gd
git commit -m "Split helm 10% out of the armor drop bracket"
```

---

### Task 3: 소켓 개별 효과 helm 열 + 소켓 추가 레시피 (`craft.gd`)

**Files:**
- Modify: `prototype/game_dungeon/craft.gd:13-20` (`RUNE_STATS`), `craft.gd:24-32`
  (`GEM_STATS`), `craft.gd:148-149` (`can_add_sockets`)

- [ ] **Step 1: `RUNE_STATS`에 helm 키 추가**

변경 전:
```gdscript
const RUNE_STATS := {
	"Ahn": {"weapon": {"ar": 50}, "armor": {"def": 15}},
	"Vey": {"weapon": {"mana": 2}, "armor": {"mana": 2}},
	"Korr": {"weapon": {}, "armor": {"def": 30}},
	"Saal": {"weapon": {}, "armor": {"mana": 3}},
	"Dren": {"weapon": {}, "armor": {"res_all": 5}},
	"Pyre": {"weapon": {"res_all": 5}, "armor": {"res_all": 5}},
}
```

변경 후:
```gdscript
const RUNE_STATS := {
	"Ahn": {"weapon": {"ar": 50}, "armor": {"def": 15}, "helm": {"def": 10}},
	"Vey": {"weapon": {"mana": 2}, "armor": {"mana": 2}, "helm": {"mana": 1}},
	"Korr": {"weapon": {}, "armor": {"def": 30}, "helm": {"def": 18}},
	"Saal": {"weapon": {}, "armor": {"mana": 3}, "helm": {"mana": 2}},
	"Dren": {"weapon": {}, "armor": {"res_all": 5}, "helm": {"res_all": 3}},
	"Pyre": {"weapon": {"res_all": 5}, "armor": {"res_all": 5}, "helm": {"res_all": 3}},
}
```

- [ ] **Step 2: `GEM_STATS`에 helm 키 추가**

변경 전:
```gdscript
const GEM_STATS := {
	"amethyst": {"weapon": {"ar": 150}, "armor": {"str": 10}},
	"diamond": {"weapon": {"ar": 100}, "armor": {"res_all": 19}},
	"ruby": {"weapon": {}, "armor": {"life": 38}},
	"sapphire": {"weapon": {}, "armor": {"mana": 38}},
	"emerald": {"weapon": {}, "armor": {"dex": 10}},
	"topaz": {"weapon": {}, "armor": {"res_all": 0}},
	"skull": {"weapon": {}, "armor": {"life": 0}},
}
```

변경 후:
```gdscript
const GEM_STATS := {
	"amethyst": {"weapon": {"ar": 150}, "armor": {"str": 10}, "helm": {"str": 6}},
	"diamond": {"weapon": {"ar": 100}, "armor": {"res_all": 19}, "helm": {"res_all": 12}},
	"ruby": {"weapon": {}, "armor": {"life": 38}, "helm": {"life": 24}},
	"sapphire": {"weapon": {}, "armor": {"mana": 38}, "helm": {"mana": 24}},
	"emerald": {"weapon": {}, "armor": {"dex": 10}, "helm": {"dex": 6}},
	"topaz": {"weapon": {}, "armor": {"res_all": 0}, "helm": {"res_all": 0}},
	"skull": {"weapon": {}, "armor": {"life": 0}, "helm": {"life": 0}},
}
```

- [ ] **Step 3: `can_add_sockets()`에 helm 슬롯 허용**

변경 전:
```gdscript
static func can_add_sockets(materials: Dictionary, it: Dictionary) -> bool:
	return int(materials.get(SOCKET_CATALYST, 0)) >= SOCKET_COST and String(it.get("quality", "")) == "normal" and String(it.get("slot", "")) in ["weapon", "armor"] and int(it.get("sockets", 0)) == 0
```

변경 후:
```gdscript
static func can_add_sockets(materials: Dictionary, it: Dictionary) -> bool:
	return int(materials.get(SOCKET_CATALYST, 0)) >= SOCKET_COST and String(it.get("quality", "")) == "normal" and String(it.get("slot", "")) in ["weapon", "armor", "helm"] and int(it.get("sockets", 0)) == 0
```

**이 Step 3이 이 전체 기능의 핵심이다** — 이게 없으면 헬름에 소켓을 못 끼워
넣어 Gloom Crown이 여전히 도달 불가능하다.

- [ ] **Step 4: 회귀 확인**

Run: `cd prototype/game_dungeon && godot --headless --path . --script res://tools/progression_combat_test.gd`
Expected: `[PROGRESSION_COMBAT] system_checks=120 save_checks=24 failures=[] verdict=PASS`

- [ ] **Step 5: 커밋**

```bash
git add prototype/game_dungeon/craft.gd
git commit -m "Add helm socket stats and allow helm in the add-sockets recipe"
```

---

### Task 4: 플레이어 장착 슬롯 통합 (`main.gd`)

**Files:**
- Modify: `prototype/game_dungeon/main.gd:93` (`EQUIPMENT_SLOTS`), `main.gd:196`
  (초기 `_equipped`), `main.gd:2257`(로드 복원), `main.gd:4628-4638`(인벤토리
  패널 라벨)

- [ ] **Step 1: `EQUIPMENT_SLOTS`에 helm 추가**

변경 전(93행):
```gdscript
const EQUIPMENT_SLOTS := ["weapon", "armor", "ring_left", "ring_right", "amulet", "charm_left", "charm_right"]
```

변경 후:
```gdscript
const EQUIPMENT_SLOTS := ["weapon", "armor", "helm", "ring_left", "ring_right", "amulet", "charm_left", "charm_right"]
```

- [ ] **Step 2: 초기 `_equipped` 딕셔너리에 helm 추가**

변경 전(196행):
```gdscript
var _equipped := {"weapon": {}, "armor": {}, "ring_left": {}, "ring_right": {}, "amulet": {}, "charm_left": {}, "charm_right": {}}
```

변경 후:
```gdscript
var _equipped := {"weapon": {}, "armor": {}, "helm": {}, "ring_left": {}, "ring_right": {}, "amulet": {}, "charm_left": {}, "charm_right": {}}
```

- [ ] **Step 3: 세이브 로드 복원에 helm 추가**

변경 전(2257행, 한 줄):
```gdscript
	_equipped = {"weapon": (equipped.get("weapon", {}) as Dictionary).duplicate(true), "armor": (equipped.get("armor", {}) as Dictionary).duplicate(true), "ring_left": (equipped.get("ring_left", legacy_ring) as Dictionary).duplicate(true), "ring_right": (equipped.get("ring_right", {}) as Dictionary).duplicate(true), "amulet": (equipped.get("amulet", {}) as Dictionary).duplicate(true), "charm_left": (equipped.get("charm_left", {}) as Dictionary).duplicate(true), "charm_right": (equipped.get("charm_right", {}) as Dictionary).duplicate(true)}
```

변경 후:
```gdscript
	_equipped = {"weapon": (equipped.get("weapon", {}) as Dictionary).duplicate(true), "armor": (equipped.get("armor", {}) as Dictionary).duplicate(true), "helm": (equipped.get("helm", {}) as Dictionary).duplicate(true), "ring_left": (equipped.get("ring_left", legacy_ring) as Dictionary).duplicate(true), "ring_right": (equipped.get("ring_right", {}) as Dictionary).duplicate(true), "amulet": (equipped.get("amulet", {}) as Dictionary).duplicate(true), "charm_left": (equipped.get("charm_left", {}) as Dictionary).duplicate(true), "charm_right": (equipped.get("charm_right", {}) as Dictionary).duplicate(true)}
```

(구버전 세이브는 `equipped` 딕셔너리에 `"helm"` 키가 없으므로 `.get("helm", {})`가
빈 딕셔너리로 기본값 처리 — additive, 세이브 스키마 버전 번호 변경 불필요.)

- [ ] **Step 4: 인벤토리 패널 "Equipped" 텍스트 라벨에 Helm 추가**

변경 전(4628-4638행):
```gdscript
	var wn := _equipped_label("weapon")
	var an := _equipped_label("armor")
	var rln := _equipped_label("ring_left")
	var rrn := _equipped_label("ring_right")
	var mn := _equipped_label("amulet")
	var cln := _equipped_label("charm_left")
	var crn := _equipped_label("charm_right")
	var merc_weapon := Item.display_name(_merc_equipped["weapon"]) if not (_merc_equipped["weapon"] as Dictionary).is_empty() else "-"
	var merc_armor := Item.display_name(_merc_equipped["armor"]) if not (_merc_equipped["armor"] as Dictionary).is_empty() else "-"
	var head := Label.new()
	head.text = "Weapon: %s\nArmor: %s\nLeft Ring: %s\nRight Ring: %s\nAmulet: %s\nLeft Charm: %s\nRight Charm: %s\nMerc Weapon: %s\nMerc Armor: %s\nBag %d / Stash %d/%d / Materials %d" % [wn, an, rln, rrn, mn, cln, crn, merc_weapon, merc_armor, _inventory.size(), _stash.size(), Stash.CAPACITY, _automation.materials.size()]
```

변경 후:
```gdscript
	var wn := _equipped_label("weapon")
	var an := _equipped_label("armor")
	var hn := _equipped_label("helm")
	var rln := _equipped_label("ring_left")
	var rrn := _equipped_label("ring_right")
	var mn := _equipped_label("amulet")
	var cln := _equipped_label("charm_left")
	var crn := _equipped_label("charm_right")
	var merc_weapon := Item.display_name(_merc_equipped["weapon"]) if not (_merc_equipped["weapon"] as Dictionary).is_empty() else "-"
	var merc_armor := Item.display_name(_merc_equipped["armor"]) if not (_merc_equipped["armor"] as Dictionary).is_empty() else "-"
	var merc_helm := Item.display_name(_merc_equipped["helm"]) if not (_merc_equipped["helm"] as Dictionary).is_empty() else "-"
	var head := Label.new()
	head.text = "Weapon: %s\nArmor: %s\nHelm: %s\nLeft Ring: %s\nRight Ring: %s\nAmulet: %s\nLeft Charm: %s\nRight Charm: %s\nMerc Weapon: %s\nMerc Armor: %s\nMerc Helm: %s\nBag %d / Stash %d/%d / Materials %d" % [wn, an, hn, rln, rrn, mn, cln, crn, merc_weapon, merc_armor, merc_helm, _inventory.size(), _stash.size(), Stash.CAPACITY, _automation.materials.size()]
```

(`merc_helm`은 Task 5에서 `Mercenary.SLOTS`에 helm을 추가하기 전에는
`_merc_equipped["helm"]`가 아직 존재하지 않아 에러가 난다 — 이 Step 4는
Task 5 이후에 실행해도 되고, 순서를 바꿔도 되지만 이 계획의 순서(Task 4 →
Task 5)대로면 Step 4 코드가 참조하는 `_merc_equipped["helm"]` 키는
`Mercenary.empty_equipment()`가 아직 helm을 반환하지 않는 상태이므로 **Task 4
완료 시점엔 런타임 에러가 날 수 있다**. 안전하게 가려면 Task 4의 Step 4를
Task 5 완료 후로 미룰 것 — 아래 Step 5에 순서를 명시했다.)

- [ ] **Step 5: Task 5(용병)까지 완료한 뒤 회귀 확인**

Task 4의 Step 4(merc_helm 참조)는 Task 5가 `Mercenary.SLOTS`/`empty_equipment()`에
helm을 추가해야 안전하게 동작한다. 따라서:
1. Task 4의 Step 1~3(EQUIPMENT_SLOTS/`_equipped` 초기값/로드 복원)만 먼저
   커밋
2. Task 5를 전부 완료
3. Task 4의 Step 4(인벤토리 패널 라벨)를 적용하고 아래 확인 실행

Run: `cd prototype/game_dungeon && godot --headless --path . -- autoquit barb`
Expected: `[GD][RESULT] verdict=PASS` 포함 전체 로그에 에러 없음(특히
`_merc_equipped["helm"]` 관련 "Invalid get index" 류 런타임 에러 부재 확인)

- [ ] **Step 6: 커밋(Step 1~3만)**

```bash
git add prototype/game_dungeon/main.gd
git commit -m "Add helm to player EQUIPMENT_SLOTS and save schema (additive)"
```

(Step 4 커밋은 Task 5 뒤로 미룸 — 아래 Task 5의 Step 4에서 함께 커밋)

---

### Task 5: 용병 헬름 장착 지원 (`mercenary.gd`) + 인벤토리 라벨 마무리

**Files:**
- Modify: `prototype/game_dungeon/mercenary.gd:5`(`SLOTS`), `mercenary.gd:76-87`
  (`stats`), `prototype/game_dungeon/main.gd:4628-4638`(Task 4 Step 4, 여기서 적용)

- [ ] **Step 1: `SLOTS`에 helm 추가**

변경 전:
```gdscript
const SLOTS := ["weapon", "armor"]
```

변경 후:
```gdscript
const SLOTS := ["weapon", "armor", "helm"]
```

(`empty_equipment()`/`normalize_equipment()`/`can_equip()`은 전부 `SLOTS`
순회 기반이라 이 한 줄로 helm이 자동 지원된다.)

- [ ] **Step 2: `stats()`에 helm 방어력 가산 분기 추가**

변경 전:
```gdscript
		if slot == "weapon" and not item_script.is_broken(item):
			result["dmg_min"] += int(item.get("dmin", 0))
			result["dmg_max"] += int(item.get("dmax", 0))
		elif slot == "armor" and not item_script.is_broken(item):
			result["defense"] += int(item.get("defense", 0))
```

변경 후:
```gdscript
		if slot == "weapon" and not item_script.is_broken(item):
			result["dmg_min"] += int(item.get("dmin", 0))
			result["dmg_max"] += int(item.get("dmax", 0))
		elif slot in ["armor", "helm"] and not item_script.is_broken(item):
			result["defense"] += int(item.get("defense", 0))
```

- [ ] **Step 3: Task 4의 Step 4(인벤토리 패널 "Helm"/"Merc Helm" 라벨)를 지금 적용**

위 "Task 4: Step 4"에 적혀 있는 정확한 변경 전/후 코드를 `main.gd`에 지금
적용한다(이 시점엔 `Mercenary.SLOTS`에 helm이 이미 있으므로 `_merc_equipped["helm"]`
참조가 안전함).

- [ ] **Step 4: 전체 회귀 확인**

Run: `cd prototype/game_dungeon && godot --headless --path . -- autoquit barb`
Expected: `[GD][RESULT] verdict=PASS`, 런타임 에러 0건(콘솔에 "Invalid get
index" 등 없음)

Run: `cd prototype/game_dungeon && godot --headless --path . -- autoquit sorc`
Expected: `[GD][RESULT] verdict=PASS`

- [ ] **Step 5: 커밋**

```bash
git add prototype/game_dungeon/mercenary.gd prototype/game_dungeon/main.gd
git commit -m "Let mercenaries equip helms; show Helm/Merc Helm in bag panel"
```

---

### Task 6: Gloom Crown 룬워드 회귀 테스트 (`main.gd _craft_selftest`)

**Files:**
- Modify: `prototype/game_dungeon/main.gd:1956-1970`(`_craft_selftest`의 테스트
  9 다음, `_craft_selftest_ok` 집계 직전)

- [ ] **Step 1: 테스트 10(Gloom Crown) 추가**

`_craft_selftest()`의 테스트 9(`# 9) 소켓 제거: ...`) 블록이 끝나는 지점과
`_craft_selftest_ok = t1 and ... and t9` 줄 사이에 삽입:

```gdscript
	# 10) Gloom Crown 룬워드(Korr+Vey, helm): 헬름 소켓 완성 시 def/mana가
	# 룬워드 완성 보너스(def+50) + 개별 룬 소켓 효과(Korr def+18, Vey mana+1)
	# 합산으로 나오는지 확인 — 2026-10-09 룬 드롭 라운드에서 배운 합산 규칙 적용.
	var helm_item := Item.generate(test_rng, Item.HELM_BASES[2], 1, "normal")
	var helm_materials := {Craft.SOCKET_CATALYST: Craft.SOCKET_COST}
	var t10a := Craft.add_sockets(helm_materials, helm_item)
	Item.socket_insert(helm_item, {"kind": "rune", "id": "Korr"})
	Item.socket_insert(helm_item, {"kind": "rune", "id": "Vey"})
	var e10 := Item.effective_affixes(helm_item)
	var t10: bool = t10a and String(helm_item.get("runeword", "")) == "Gloom Crown" and int(e10.get("def", 0)) == 68 and int(e10.get("mana", 0)) == 1
	print("[P4] sigil: Korr+Vey to %s (def=%d mana=%d) : %s" % [String(helm_item.get("runeword", "")), int(e10.get("def", 0)), int(e10.get("mana", 0)), str(t10)])

	_craft_selftest_ok = t1 and t2 and t3 and t3b and t4 and t5 and t5b and t6 and t7 and t8 and t9 and t10
```

(기존 `_craft_selftest_ok = ... and t9` 줄을 위 `and t10` 포함 버전으로
교체한다.)

- [ ] **Step 2: 실행 및 확인**

Run: `cd prototype/game_dungeon && godot --headless --path . -- autoquit barb 2>&1 | grep "\[P4\] sigil: Korr"`
Expected: `[P4] sigil: Korr+Vey to Gloom Crown (def=68 mana=1) : true`

만약 `false`가 나오면 가장 먼저 확인할 것:
- `Craft.RUNEWORDS`의 Gloom Crown 정의가 `"runes": ["Korr", "Vey"]` 순서
  그대로인지(순서가 바뀌면 `match_runeword`가 매칭 안 함)
- `can_add_sockets()`가 Task 3에서 `"helm"`을 허용하도록 바뀌었는지
- `RUNE_STATS`의 Korr/Vey helm 값이 Task 3대로 들어갔는지

- [ ] **Step 3: 전체 오토퀴트 재확인**

Run: `cd prototype/game_dungeon && godot --headless --path . -- autoquit barb`
Expected: `[GD][RESULT] verdict=PASS`(테스트 10 포함 `_craft_selftest_ok` 전체 PASS)

- [ ] **Step 4: 커밋**

```bash
git add prototype/game_dungeon/main.gd
git commit -m "Add Gloom Crown runeword regression test"
```

---

### Task 7: 헬름 유니크 범위 롤 검증 (`system_tests.gd`)

**Files:**
- Modify: `prototype/game_dungeon/system_tests.gd:239-243`(기존 unique 검증
  블록 바로 다음)

- [ ] **Step 1: 헬름 유니크 범위 체크 추가**

기존 블록:
```gdscript
	var unique_item := Item.generate(rng, Item.WEAPON_BASES[1], 20, "unique")
	_check(Item.display_name(unique_item) == "Rift Cleaver (Hand Axe)", "unique identity", failures)
	var unique_item_ed := int(unique_item["affixes"].get("ed", 0))
	_check(unique_item_ed >= 56 and unique_item_ed <= 84, "unique fixed affix", failures)
	_check(Item.quality_color("unique") == Color(0.72, 0.55, 0.28), "unique quality color", failures)
```

다음 줄 바로 뒤에 추가:
```gdscript
	var unique_helm := Item.generate(rng, Item.HELM_BASES[2], 20, "unique")
	_check(Item.display_name(unique_helm) == "Warden's Judgment (Iron Sallet)", "helm unique identity", failures)
	var unique_helm_def := int(unique_helm["affixes"].get("def", 0))
	_check(unique_helm_def >= 40 and unique_helm_def <= 60, "helm unique fixed affix range", failures)
	_check(String(unique_helm.get("slot", "")) == "helm", "helm unique slot", failures)
```

- [ ] **Step 2: 실행 및 확인**

Run: `cd prototype/game_dungeon && godot --headless --path . --script res://tools/progression_combat_test.gd`
Expected: `[PROGRESSION_COMBAT] system_checks=123 save_checks=24 failures=[] verdict=PASS`

(`_check()` 호출 3개를 추가했으므로 `system_checks`가 120 → 123으로 오른다
— 숫자가 다르게 나오면 `_check()` 호출 개수를 세어 실제로 3개 추가했는지
확인할 것.)

- [ ] **Step 3: 커밋**

```bash
git add prototype/game_dungeon/system_tests.gd
git commit -m "Add helm unique range-roll regression checks"
```

---

### Task 8: 소켓 추가 큐브 UI가 헬름도 지원하는지 확인 (`tools/cube_ui_test.gd`)

**Files:**
- Modify: `prototype/game_dungeon/tools/cube_ui_test.gd`

- [ ] **Step 1: 헬름 소켓 추가 시나리오 추가**

`cube_ui_test.gd`에서 다음 두 줄(77~79행) 바로 다음, `game._automation.materials["rune_Helm"] = 1`로
시작하는 소켓 제거 테스트 블록 **전**에 삽입:

```gdscript
	var socketed_after: Array = socket_target.get("socketed", [])
	if socketed_after.is_empty() or String((socketed_after[0] as Dictionary).get("id", "")) != "ruby:perfect":
		failures.append("insert transaction / quality retained")
```

삽입할 코드:

```gdscript
	game._automation.materials["skull"] = 3
	var helm_target := Item.generate(rng, Item.HELM_BASES[0], 1, "normal")
	game._inventory.append(helm_target)
	game._rebuild_inv()
	await process_frame
	var helm_socket_btn: Button
	for child in panel.get_children():
		if child is Button and child.text == "Add 2 Sockets" and not child.disabled:
			helm_socket_btn = child
	if helm_socket_btn == null:
		failures.append("helm socket button available")
	if helm_socket_btn != null:
		helm_socket_btn.pressed.emit()
	if game._automation.materials.has("skull") or int(helm_target.get("sockets", 0)) != 2:
		failures.append("helm add sockets transaction")
```

(`skull` 3개를 다시 채우는 이유: 기존 `socket_target`용으로 이미 소모됐을
수 있으므로. 버튼 텍스트가 기존 무기용 "Add 2 Sockets"와 동일해 **두 번째로
찾은 비활성화 아닌 버튼**을 헬름용으로 간주하는 방식 — 패널에 동시에 여러
"Add 2 Sockets" 버튼이 뜰 수 있다는 뜻이므로, `not child.disabled` 조건으로
이미 소켓이 찬 무기용 버튼과 구분한다. 무기용 `socket_target`은 이 시점에
이미 소켓 2개가 차 있어 "Add 2 Sockets" 버튼 자체가 더 이상 안 뜬다 —
`socketable` 목록이 `int(bag_item.get("sockets",0)) == 0`인 아이템만 담기
때문. 따라서 이 루프에서 찾아지는 건 helm_target 것 하나뿐이다.)

- [ ] **Step 2: 실행 및 확인**

Run: `cd prototype/game_dungeon && godot --headless --path . --script res://tools/cube_ui_test.gd`
Expected: `[CUBE_UI] click=true stale_input=true reroll=true socket=true socket_remove=true widths=320/640 failures=[] verdict=PASS`

- [ ] **Step 3: 커밋**

```bash
git add prototype/game_dungeon/tools/cube_ui_test.gd
git commit -m "Verify Add Sockets recipe covers helm items in cube UI test"
```

---

### Task 9: 통합 검증 + 배포 + 문서화

이 프로젝트의 표준 배포 사이클([[deployment-workflow]])을 따른다 — 플랜
실행 중 지금까지 Task별로 이미 개별 검증했으므로, 이 Task는 **전체 통합
확인 + 배포 + 문서화**에 집중한다.

**Files:**
- Modify: `prototype/game_dungeon/main.gd`(`DEPLOYED_AT_KST`), `prototype/game_dungeon/README.md`,
  `docs/PROJECT_MEMORY.md`
- Deploy: gh-pages 브랜치(별도 클론 작업 트리)

- [ ] **Step 1: 전체 테스트 스위트 1회씩 실행**

```bash
cd prototype/game_dungeon
godot --headless --path . -- autoquit barb
godot --headless --path . -- autoquit sorc
godot --headless --path . --script res://tools/progression_combat_test.gd
godot --headless --path . --script res://tools/cube_ui_test.gd
```

Expected: 4개 전부 `verdict=PASS`, barb 로그에 `[P4] sigil: Korr+Vey to Gloom
Crown (def=68 mana=1) : true` 포함, `[SYSTEM] checks=123`(Task 7에서
3개 늘어난 숫자).

- [ ] **Step 2: `DEPLOYED_AT_KST` 갱신**

`main.gd`에서 현재 KST 시각으로 교체(형식: `"YYYY-MM-DD HH:MM KST"`, 이전
값은 `"2026-10-09 13:00 KST"`였음 — `date -u`로 UTC를 구해 +9시간 변환).

- [ ] **Step 3: Web 릴리스 export**

```bash
cd prototype/game_dungeon
rm -rf .godot build_web && mkdir -p build_web
godot --headless --path . --export-release "Web" "build_web/index.html"
sha256sum build_web/index.pck
```

- [ ] **Step 4: gh-pages 배포**

gh-pages 브랜치를 별도 경로에 클론 → `index.*` 파일 교체 → 커밋/푸시 →
`gh api repos/jflakeee/diablo/pages/builds/latest`가 `built`가 될 때까지
확인 → `curl`로 루트 HTTP 200과 원격 `index.pck` SHA-256이 로컬과 일치하는지
확인 → playwright로 `https://jflakeee.github.io/diablo/`를 열어 새
`DEPLOYED_AT_KST` 타임스탬프가 렌더링되고 콘솔 에러가 0건인지 스크린샷으로
확인.

- [ ] **Step 5: `README.md`/`PROJECT_MEMORY.md` 갱신**

`prototype/game_dungeon/README.md`에 헬름 슬롯 추가를 설명하는 새 단락
추가(기존 라운드들과 동일한 형식 — 무엇을, 왜, 무엇을 의도적으로 안 했는지).
`docs/PROJECT_MEMORY.md`에 새 날짜 섹션 추가(소스 커밋 해시, 검증 결과,
배포 정보, Gloom Crown 테스트 결과 수치, `SYSTEM checks=123`으로 변경된
숫자, `gems` 배열은 이번 라운드에서 변경 없음 — 드롭 풀 희석 노트 갱신
불필요).

- [ ] **Step 6: 최종 커밋 + 양쪽 브랜치 푸시**

```bash
git add prototype/game_dungeon/main.gd prototype/game_dungeon/README.md docs/PROJECT_MEMORY.md
git commit -m "Deploy helm equipment slot (Gloom Crown reachable)"
git push origin docs/diablo2-clone-design
git checkout main
git cherry-pick <위 커밋 해시>
git push origin main
git checkout docs/diablo2-clone-design
```

- [ ] **Step 7: 세션 메모리 갱신**

`C:\Users\a\.claude\projects\D--htdocs-diablo-clone-diablo-clone\memory\systems-built.md`에
이번 라운드 요약 추가(헬름 슬롯 신규 추가, Gloom Crown 도달 가능, 기존
제네릭 구조 덕에 장착 디스패치/스탯 합산/아이콘은 코드 추가 없이 자동
연동됐다는 점, `_eligible()`의 armor/helm 접사 동치 처리처럼 발견 당시
예상 못 했던 보완 지점).

---

## Self-Review 메모(작성자 기록)

- **스펙 커버리지**: 설계 문서의 "파일별 변경 사항" 절 각 항목이 Task
  1~8에 1:1로 대응됨(item.gd→Task1/2, craft.gd→Task3, main.gd→Task4/6,
  mercenary.gd→Task5). "건드리지 않는 곳" 절의 3개 항목(automation.gd,
  coverage.json/item_bases.json, can_craft)은 플랜에 아무 Task도 없음 —
  의도대로 비범위.
- **플레이스홀더 스캔**: 전체 재확인, "TBD"/"나중에"/"적절히 처리" 패턴
  없음. 모든 코드 블록이 변경 전/후 전문 포함.
- **타입/시그니처 일관성**: `Craft.SOCKET_CATALYST`/`Craft.SOCKET_COST`(Task 8),
  `Item.HELM_BASES`(Task 1에서 정의, Task 2/6/7/8에서 참조) 전부 Task 1에서
  정의된 이름과 동일하게 재사용됨.
- **발견된 순서 의존성**: Task 4(main.gd 라벨)가 Task 5(mercenary.gd SLOTS)보다
  먼저 오면 `_merc_equipped["helm"]` 참조가 런타임 에러를 낼 수 있어, Task 4를
  "Step 1~3 커밋 → Task 5 전체 → Task 4 Step 4" 순서로 명시적으로 쪼갰다 —
  이 계획을 subagent-driven으로 실행할 경우 이 순서 의존성을 반드시 지킬 것
  (Task 4와 Task 5를 병렬 실행하면 안 됨).
