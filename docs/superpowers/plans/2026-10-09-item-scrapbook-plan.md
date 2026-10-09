# Item Scrapbook + Unique/Set Range Rolls Implementation Plan

> **For agentic workers:** This plan is executed inline in the current session (not dispatched to subagents) — the implementer already holds the full design context from the brainstorming conversation. Steps use checkbox (`- [ ]`) syntax for tracking. This project has no fast unit-test runner (GDScript requires a Godot SceneTree); "run the test" steps mean a full `godot --headless --path . -- autoquit barb` boot (~20-40s), so verification happens once per task, not per assertion — this is the established pattern for this codebase (see `prototype/game_dungeon/system_tests.gd` and `main.gd _craft_selftest()`).

**Goal:** Add a consumable "scrapbook ticket" system (pick up equipment → existing auto-equip/sell flow unchanged → a ticket recording base/quality/ilvl is also logged → spend gold later to redeem a freshly-rolled copy, manual equip only) and give unique/set item affixes randomized ranges instead of fixed values (applies to all generation, not just scrapbook redeems).

**Architecture:** One new `RefCounted` script (`scrapbook.gd`, mirrors `collection_book.gd`/`craft.gd`'s dependency-injection style — takes `item_script: GDScript` as a parameter rather than preloading `Item` itself). `item.gd`'s `UNIQUES`/`SETS` tables change from `{stat: int}` to `{stat: [min,max]}`; `generate()`'s unique/set branches roll within range. `main.gd` wires pickup → ticket, a new "Scrapbook" bag view, and save/load.

**Tech Stack:** Godot 4.7 GDScript, `RandomNumberGenerator`, existing save-snapshot dictionary pattern.

Design doc: `docs/superpowers/specs/2026-10-09-item-scrapbook-design.md` — read it first for the full rationale; this plan only restates what's needed to implement it.

---

### Task 1: Range-roll unique/set affixes

**Files:**
- Modify: `prototype/game_dungeon/item.gd:30-53` (UNIQUES/SETS tables), `item.gd:106-136` (`generate()`), add new `find_base()` function near `generate()`.

- [ ] **Step 1: Replace `UNIQUES` and `SETS` fixed values with `[min, max]` ranges**

Replace lines 30-53 of `item.gd` (the `UNIQUES`, `SETS`, `SET_BONUSES` block — `SET_BONUSES` stays untouched, only `UNIQUES`/`SETS` change) with:

```gdscript
# 유니크 아이템(범위 롤) — 베이스명 → 유니크. 각 접사는 [min,max] 범위,
# generate()가 매번 범위 내 랜덤값으로 확정한다(2026-10-09, 기존 고정값
# 원본의 ±20% 내외로 설정). 상세: docs/superpowers/specs/2026-10-09-item-scrapbook-design.md
const UNIQUES := {
	"Short Sword": {"name": "Emberneedle", "affixes": {"ed": [40, 60], "fdmg": [8, 12], "ar": [32, 48]}},
	"Hand Axe": {"name": "Rift Cleaver", "affixes": {"ed": [56, 84], "ar": [32, 48], "cdmg": [6, 10]}},
	"Mace": {"name": "Storm Knell", "affixes": {"ed": [48, 72], "str": [8, 12], "ldmg": [10, 14]}},
	"Quilted Armor": {"name": "Ashweave", "affixes": {"def": [24, 36], "res_all": [10, 14], "dex": [6, 10], "life": [12, 18]}},
	"Leather Armor": {"name": "Frostveil", "affixes": {"def": [36, 54], "res_cold": [28, 42], "res_all": [8, 12], "life": [20, 30]}},
	"Ring Mail": {"name": "Crownless Mantle", "affixes": {"def": [44, 66], "res_all": [12, 18], "mana": [24, 36], "str": [6, 10]}},
	"Copper Ring": {"name": "Kindled Circuit", "affixes": {"life": [14, 22], "res_fire": [16, 24], "ar": [28, 42]}},
	"Moonstone Ring": {"name": "Pale Orbit", "affixes": {"mana": [19, 29], "res_cold": [16, 24], "dex": [4, 6]}},
	"Ashen Pendant": {"name": "Depthward Seal", "affixes": {"res_all": [13, 19], "str": [4, 6], "life": [10, 14]}},
}

# 독자 세트 장비. 동일 set_id 두 부위를 함께 장착하면 SET_BONUSES가 활성화된다.
# 접사는 UNIQUES와 동일하게 [min,max] 범위(2026-10-09). SET_BONUSES(완성 보너스)는
# 개별 부위 수치가 아니라 "N부위 장착" 보너스라 범위화 대상이 아니다 — 고정값 유지.
const SETS := {
	"Short Sword": {"set_id": "ember_oath", "set_name": "Ember Oath", "piece_name": "Oathspark", "affixes": {"ed": [26, 38], "fdmg": [6, 8]}},
	"Quilted Armor": {"set_id": "ember_oath", "set_name": "Ember Oath", "piece_name": "Oathweave", "affixes": {"def": [18, 26], "res_fire": [14, 22]}},
	"Mace": {"set_id": "storm_vigil", "set_name": "Storm Vigil", "piece_name": "Vigil Bell", "affixes": {"ed": [22, 34], "ldmg": [8, 12]}},
	"Ring Mail": {"set_id": "storm_vigil", "set_name": "Storm Vigil", "piece_name": "Vigil Links", "affixes": {"def": [30, 46], "res_light": [18, 26]}}
}
const SET_BONUSES := {
	"ember_oath": {2: {"life": 30, "res_all": 12}},
	"storm_vigil": {2: {"mana": 24, "ar": 65}}
}
```

- [ ] **Step 2: Make `generate()`'s unique/set branches roll within the range**

In `item.gd`, find this block (currently around line 121-134):

```gdscript
	if quality == "unique" and UNIQUES.has(String(base["name"])):
		var u: Dictionary = UNIQUES[String(base["name"])]
		it["prefix"] = String(u["name"])   # 유니크 이름 저장
		for k in u["affixes"]:
			it["affixes"][k] = int(u["affixes"][k])
		return it
	if quality == "set" and SETS.has(String(base["name"])):
		var set_piece: Dictionary = SETS[String(base["name"])]
		it["set_id"] = String(set_piece["set_id"])
		it["set_name"] = String(set_piece["set_name"])
		it["prefix"] = String(set_piece["piece_name"])
		for k in set_piece["affixes"]:
			it["affixes"][k] = int(set_piece["affixes"][k])
		return it
```

Replace the two `for k in ...: it["affixes"][k] = int(...[k])` lines with range rolls:

```gdscript
	if quality == "unique" and UNIQUES.has(String(base["name"])):
		var u: Dictionary = UNIQUES[String(base["name"])]
		it["prefix"] = String(u["name"])   # 유니크 이름 저장
		for k in u["affixes"]:
			var range_vals: Array = u["affixes"][k]
			it["affixes"][k] = rng.randi_range(int(range_vals[0]), int(range_vals[1]))
		return it
	if quality == "set" and SETS.has(String(base["name"])):
		var set_piece: Dictionary = SETS[String(base["name"])]
		it["set_id"] = String(set_piece["set_id"])
		it["set_name"] = String(set_piece["set_name"])
		it["prefix"] = String(set_piece["piece_name"])
		for k in set_piece["affixes"]:
			var range_vals: Array = set_piece["affixes"][k]
			it["affixes"][k] = rng.randi_range(int(range_vals[0]), int(range_vals[1]))
		return it
```

- [ ] **Step 3: Add `find_base()` helper (needed by scrapbook redeem in Task 3)**

Add this function in `item.gd` right after `generate()` (after its closing `return it` / before `static func _apply_quality_roll`):

```gdscript
# 스크랩북 티켓 복원용 — 베이스명+슬롯으로 원본 베이스 딕셔너리를 역조회한다.
# 티켓은 베이스 딕셔너리 전체가 아니라 이름만 저장하므로(세이브 용량/데이터
# 신선도 때문 — WEAPON_BASES 등이 나중에 바뀌어도 티켓은 항상 최신 베이스를
# 참조), 복원 시점에 매번 이 함수로 찾는다.
static func find_base(base_name: String, slot: String) -> Dictionary:
	var pool: Array = []
	if slot == "weapon":
		pool = WEAPON_BASES
	elif slot == "armor":
		pool = ARMOR_BASES
	elif slot in ["ring", "amulet"]:
		pool = ACCESSORY_BASES
	elif slot == "charm":
		pool = CHARM_BASES
	for base in pool:
		if String(base["name"]) == base_name:
			return base
	return {}
```

- [ ] **Step 4: Run the full verification chain to confirm nothing broke yet**

Run (from `prototype/game_dungeon`):
```
godot --headless --path . -- autoquit barb
```
Expected: `[GD][RESULT] verdict=FAIL` is **expected at this step** — `system_tests.gd` still has hardcoded exact-value assertions against the old fixed unique/set numbers (Task 2 fixes those). Confirm the failure is specifically in `[SYSTEM]` (grep the output for `failures=` — it should list entries like `"accessory fixed affixes"`, `"unique fixed affix"`, `"dual ring affix aggregation"`, `"dual ring resistance aggregation"`) and that no *other* subsystem regressed. Do not proceed to Task 2 if failures include anything outside these known range-related checks.

- [ ] **Step 5: Commit**

```bash
git add prototype/game_dungeon/item.gd
git commit -m "Range-roll unique and set item affixes instead of fixed values

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 2: Update system_tests.gd assertions for ranged values

**Files:**
- Modify: `prototype/game_dungeon/system_tests.gd:142`, `:153-154`, `:236`

- [ ] **Step 1: Fix the accessory fixed-affix check (line ~142)**

Find:
```gdscript
	_check(String(unique_ring.get("slot", "")) == "ring" and int(unique_ring["affixes"].get("res_fire", 0)) == 20, "accessory fixed affixes", failures)
```
Replace with (Kindled Circuit's res_fire range is now `[16, 24]`):
```gdscript
	var ring_res_fire := int(unique_ring["affixes"].get("res_fire", 0))
	_check(String(unique_ring.get("slot", "")) == "ring" and ring_res_fire >= 16 and ring_res_fire <= 24, "accessory fixed affixes", failures)
```

- [ ] **Step 2: Fix the dual-ring aggregation checks (lines ~153-154)**

Find:
```gdscript
	_check(int(dual_ring_affixes.get("mana", 0)) == 24 and int(dual_ring_affixes.get("life", 0)) == 18, "dual ring affix aggregation", failures)
	_check(int(dual_ring_affixes.get("res_fire", 0)) == 20 and int(dual_ring_affixes.get("res_cold", 0)) == 20, "dual ring resistance aggregation", failures)
```
Replace with (Pale Orbit mana `[19,29]`, Kindled Circuit life `[14,22]`, Kindled Circuit res_fire `[16,24]`, Pale Orbit res_cold `[16,24]`):
```gdscript
	var dual_mana := int(dual_ring_affixes.get("mana", 0))
	var dual_life := int(dual_ring_affixes.get("life", 0))
	_check(dual_mana >= 19 and dual_mana <= 29 and dual_life >= 14 and dual_life <= 22, "dual ring affix aggregation", failures)
	var dual_res_fire := int(dual_ring_affixes.get("res_fire", 0))
	var dual_res_cold := int(dual_ring_affixes.get("res_cold", 0))
	_check(dual_res_fire >= 16 and dual_res_fire <= 24 and dual_res_cold >= 16 and dual_res_cold <= 24, "dual ring resistance aggregation", failures)
```

- [ ] **Step 3: Fix the unique fixed-affix check (line ~236)**

Find:
```gdscript
	_check(int(unique_item["affixes"].get("ed", 0)) == 70, "unique fixed affix", failures)
```
Replace with (Rift Cleaver's ed range is now `[56, 84]`):
```gdscript
	var unique_item_ed := int(unique_item["affixes"].get("ed", 0))
	_check(unique_item_ed >= 56 and unique_item_ed <= 84, "unique fixed affix", failures)
```

- [ ] **Step 4: Run the full verification chain**

```
godot --headless --path . -- autoquit barb
```
Expected: `[SYSTEM] checks=120 failures=[] verdict=PASS` and `[GD][RESULT] verdict=PASS`. The checks count stays 120 (no new checks added in this task, only existing ones changed from equality to range comparisons). If it still fails, grep the log for the specific failing check name and re-verify the range math against the table from Task 1 Step 1.

Also run:
```
godot --headless --path . -- autoquit sorc
godot --headless --path . --script tools/progression_combat_test.gd
```
Expected: both `verdict=PASS`.

- [ ] **Step 5: Commit**

```bash
git add prototype/game_dungeon/system_tests.gd
git commit -m "Update unique/set affix test assertions for ranged rolls

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 3: Create `scrapbook.gd`

**Files:**
- Create: `prototype/game_dungeon/scrapbook.gd`

- [ ] **Step 1: Write the full file**

```gdscript
extends RefCounted
# 장비 습득 시 발급되는 소모형 "복원 티켓" 보관함. 기존 습득→자동장착 흐름은
# 전혀 바뀌지 않는다 — 이 스크립트는 그 흐름과 별개로, 같은 베이스/등급/ilvl로
# 하나 더 뽑을 수 있는 영수증만 쌓아둔다. 복원(redeem)은 항상 수동이며,
# 복원된 아이템은 자동장착되지 않고 가방에 들어가 사용자가 직접 장착해야
# 한다. 상세: docs/superpowers/specs/2026-10-09-item-scrapbook-design.md

const RESTORE_BASE := {"normal": 15, "magic": 60, "rare": 160, "set": 350, "unique": 500}

var tickets: Array = []

func add_ticket(base_name: String, slot: String, quality: String, ilvl: int) -> void:
	if not RESTORE_BASE.has(quality):
		return
	tickets.append({"base_name": base_name, "slot": slot, "quality": quality, "ilvl": ilvl})

func cost(ticket: Dictionary) -> int:
	var base_cost: int = int(RESTORE_BASE.get(String(ticket.get("quality", "")), 0))
	var ilvl := int(ticket.get("ilvl", 1))
	return roundi(float(base_cost) * (1.0 + float(ilvl) / 20.0))

func can_restore(ticket: Dictionary, gold: int) -> bool:
	return tickets.has(ticket) and gold >= cost(ticket)

# item_script는 main.gd가 항상 Item(item.gd)을 넘긴다 — craft.gd의 기존
# 의존성 주입 패턴(reroll/add_sockets가 item_script: GDScript를 받는 것)과
# 동일하게 맞춰 scrapbook.gd가 item.gd를 직접 preload하지 않도록 했다.
func redeem(rng: RandomNumberGenerator, ticket: Dictionary, item_script: GDScript) -> Dictionary:
	if not tickets.has(ticket):
		return {}
	var base: Dictionary = item_script.find_base(String(ticket.get("base_name", "")), String(ticket.get("slot", "")))
	if base.is_empty():
		return {}
	tickets.erase(ticket)
	return item_script.generate(rng, base, int(ticket.get("ilvl", 1)), String(ticket.get("quality", "")))

func snapshot() -> Dictionary:
	return {"tickets": tickets.duplicate(true)}

func restore(raw: Variant) -> void:
	if not raw is Dictionary:
		return
	tickets = ((raw as Dictionary).get("tickets", []) as Array).duplicate(true)

func selftest() -> bool:
	var item_script := load("res://item.gd")
	add_ticket("Short Sword", "weapon", "magic", 15)
	var ok := tickets.size() == 1
	var ticket: Dictionary = tickets[0]
	var expected_cost := roundi(60.0 * (1.0 + 15.0 / 20.0))
	ok = ok and cost(ticket) == expected_cost
	ok = ok and not can_restore(ticket, expected_cost - 1)
	ok = ok and can_restore(ticket, expected_cost)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var redeemed := redeem(rng, ticket, item_script)
	ok = ok and not redeemed.is_empty() and String(redeemed.get("quality", "")) == "magic" and tickets.is_empty()
	ok = ok and redeem(rng, ticket, item_script).is_empty()
	add_ticket("Hand Axe", "weapon", "unique", 10)
	var saved := snapshot()
	tickets.clear()
	restore(saved)
	ok = ok and tickets.size() == 1 and String(tickets[0]["quality"]) == "unique"
	return ok
```

- [ ] **Step 2: Write a standalone headless check for this one file before wiring it into main.gd**

Create a throwaway script at `prototype/game_dungeon/tools/_scrapbook_check.gd` (temporary — deleted in Step 4):
```gdscript
extends SceneTree
const Scrapbook := preload("res://scrapbook.gd")
func _initialize() -> void:
	var ok := Scrapbook.new().selftest()
	print("[SCRAPBOOK_STANDALONE] verdict=", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
```

- [ ] **Step 3: Run it**

```
godot --headless --path . --script tools/_scrapbook_check.gd
```
Expected: `[SCRAPBOOK_STANDALONE] verdict=PASS`. If it fails, check the `expected_cost` math (`60 * (1 + 15/20) = 60 * 1.75 = 105`) and the range values from Task 1 didn't drift.

- [ ] **Step 4: Delete the throwaway script**

```bash
rm prototype/game_dungeon/tools/_scrapbook_check.gd
```

- [ ] **Step 5: Commit**

```bash
git add prototype/game_dungeon/scrapbook.gd
git commit -m "Add scrapbook.gd: consumable ticket store for item redemption

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 4: Wire the scrapbook into `main.gd` (pickup, save/load, UI, self-test)

**Files:**
- Modify: `prototype/game_dungeon/main.gd` (multiple locations, see each step)

- [ ] **Step 1: Preload and member variable**

Find (near line 34):
```gdscript
const CollectionBook := preload("res://collection_book.gd")
```
Add directly after it:
```gdscript
const Scrapbook := preload("res://scrapbook.gd")
```

Find (near line 199):
```gdscript
var _collection := CollectionBook.new()
```
Add directly after it:
```gdscript
var _scrapbook := Scrapbook.new()
```

- [ ] **Step 2: Hook ticket creation into the existing pickup flow**

In `_pickup()`, find the end of the equipment branch:
```gdscript
	_push_item_event(item_action, it, power_before, _loadout_combat_power(_equipped), item_note)
	_rebuild_inv()
```
Replace with:
```gdscript
	_push_item_event(item_action, it, power_before, _loadout_combat_power(_equipped), item_note)
	_scrapbook.add_ticket(String(it["name"]), String(it["slot"]), String(it["quality"]), int(it.get("ilvl", 1)))
	_rebuild_inv()
```

- [ ] **Step 3: Save/load wiring**

Find (in the snapshot dictionary, near `"collection_book": _collection.snapshot(),`):
```gdscript
			"collection_book": _collection.snapshot(),
```
Add directly after it:
```gdscript
			"scrapbook": _scrapbook.snapshot(),
```

Find (in the load function, near `_collection.restore(state.get("collection_book", {}))`):
```gdscript
	_collection.restore(state.get("collection_book", {}))
```
Add directly after it:
```gdscript
	_scrapbook.restore(state.get("scrapbook", {}))
```

- [ ] **Step 4: Add a "Scrapbook" nav button and view dispatch**

Find in `_rebuild_inv()`:
```gdscript
	if _inventory_view == "collection":
		_rebuild_collection()
		_apply_large_panel_text(_inv_vbox)
		return
```
Add directly after it:
```gdscript
	if _inventory_view == "scrapbook":
		_rebuild_scrapbook()
		_apply_large_panel_text(_inv_vbox)
		return
```

Find:
```gdscript
	var collection_button := Button.new()
	collection_button.text = "Collection & Ranking Book (%d)" % _collection.records.size()
	collection_button.pressed.connect(_show_collection)
	_inv_vbox.add_child(collection_button)
```
Add directly after it:
```gdscript
	var scrapbook_button := Button.new()
	scrapbook_button.text = "Scrapbook (%d)" % _scrapbook.tickets.size()
	scrapbook_button.pressed.connect(_show_scrapbook)
	_inv_vbox.add_child(scrapbook_button)
```

- [ ] **Step 5: Add `_show_scrapbook()`, `_rebuild_scrapbook()`, `_redeem_scrapbook_ticket()`**

Find:
```gdscript
func _show_collection() -> void:
	_inventory_view = "collection"
	_rebuild_inv()
```
Add directly after it:
```gdscript
func _show_scrapbook() -> void:
	_inventory_view = "scrapbook"
	_rebuild_inv()
```

Find the end of `_rebuild_collection()` (right before `func _rebuild_inv() -> void:`) and add this new function just before `_rebuild_inv()`:
```gdscript
func _rebuild_scrapbook() -> void:
	var nav := Button.new()
	nav.text = "Back to Bag"
	nav.pressed.connect(_show_bag)
	_inv_vbox.add_child(nav)
	var title := Label.new()
	title.text = "SCRAPBOOK\n%d ticket(s) - spend gold to redeem a freshly rolled copy" % _scrapbook.tickets.size()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.3))
	_inv_vbox.add_child(title)
	if _scrapbook.tickets.is_empty():
		var empty := Label.new()
		empty.text = "No tickets yet - pick up equipment to earn one."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_inv_vbox.add_child(empty)
		return
	for ticket in _scrapbook.tickets:
		var quality := String(ticket.get("quality", ""))
		var redeem_cost := _scrapbook.cost(ticket)
		var line := Label.new()
		line.text = "%s %s Lv.%d" % [quality.capitalize(), String(ticket.get("base_name", "")), int(ticket.get("ilvl", 1))]
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_color_override("font_color", Item.quality_color(quality))
		_inv_vbox.add_child(line)
		var redeem_btn := Button.new()
		redeem_btn.text = "Restore (%dg)" % redeem_cost
		var captured_ticket: Dictionary = ticket
		redeem_btn.disabled = not _scrapbook.can_restore(captured_ticket, _gold)
		redeem_btn.pressed.connect(func(): _redeem_scrapbook_ticket(captured_ticket))
		_inv_vbox.add_child(redeem_btn)

func _redeem_scrapbook_ticket(ticket: Dictionary) -> void:
	if not _scrapbook.can_restore(ticket, _gold):
		_combat_log = "Not enough gold to restore this item"
		return
	var redeem_cost := _scrapbook.cost(ticket)
	var new_item := _scrapbook.redeem(_rng, ticket, Item)
	if new_item.is_empty():
		_combat_log = "Scrapbook restore failed"
		_rebuild_inv()
		return
	_gold -= redeem_cost
	_inventory.append(new_item)
	if _collection.accepts(new_item):
		_collection.register(new_item, _item_combat_power(new_item))
	_combat_log = "SCRAPBOOK RESTORED: %s / %s" % [Item.display_name(new_item), Item.affix_text(new_item)]
	_rebuild_inv()
```

- [ ] **Step 6: Wire `scrapbook.gd`'s own `selftest()` into the verification chain**

`scrapbook.gd`'s `selftest()` (written in Task 3) already covers cost formula, gating, redeem, and snapshot/restore round-trip — it just needs to actually be *called* somewhere, the same way `Mercenary.selftest()` is: a print line plus a term in the final `ok` aggregate. It creates its own local `RandomNumberGenerator` internally and never touches `_rng`, so — unlike `_craft_selftest()` — it carries no risk of shifting the live dungeon's RNG stream ([[shared-rng-selftest-pitfall]] doesn't apply here by construction; no `test_rng` wrapper needed).

Find (in `_ready()`, inside the `if _auto_quit:` block):
```gdscript
		_immune_selftest()
```
Add directly after it:
```gdscript
		print("[SCRAPBOOK] selftest verdict=", "PASS" if Scrapbook.new().selftest() else "FAIL")
```

- [ ] **Step 7: Fold into the final aggregate verdict**

Find the big `ok` expression (search for `_immune_selftest_ok` — it's the last term in the chain):
```gdscript
		var ok: bool = (_kills > 0 or _spells_cast > 0) and bool(asset_report["ok"]) and bool(perf_report["ok"]) and _ui_selftest_ok and _identity_selftest_ok and _system_selftest_ok and _save_selftest_ok and _online_selftest_ok and _coverage_selftest_ok and _waypoint_selftest_ok and _pack_selftest_ok and _boss_room_selftest_ok and ai_cull_ok and Mercenary.selftest() and _craft_selftest_ok and _immune_selftest_ok
```
Replace with (append `and Scrapbook.new().selftest()`, matching how `Mercenary.selftest()` is called a second time here):
```gdscript
		var ok: bool = (_kills > 0 or _spells_cast > 0) and bool(asset_report["ok"]) and bool(perf_report["ok"]) and _ui_selftest_ok and _identity_selftest_ok and _system_selftest_ok and _save_selftest_ok and _online_selftest_ok and _coverage_selftest_ok and _waypoint_selftest_ok and _pack_selftest_ok and _boss_room_selftest_ok and ai_cull_ok and Mercenary.selftest() and _craft_selftest_ok and _immune_selftest_ok and Scrapbook.new().selftest()
```

- [ ] **Step 8: Run the full verification chain**

```
godot --headless --path . -- autoquit barb
```
Expected: `[SCRAPBOOK] selftest verdict=PASS` appears in the log, `[GD][RESULT] verdict=PASS`, and `kills > 0` (not a flaky zero-kill run — if it comes back `kills=0`, re-run once to check for the determinism-vs-flakiness signature from `[[shared-rng-selftest-pitfall]]`: compare `champs=`/`uniques=`/`kills=` across two runs; identical values across runs means a real RNG-consumption regression was introduced in this task, not flakiness).

```
godot --headless --path . -- autoquit sorc
godot --headless --path . --script tools/progression_combat_test.gd
godot --headless --path . --script tools/cube_ui_test.gd
```
Expected: all four `verdict=PASS`. `cube_ui_test.gd` should be unaffected (nothing in this plan touches the cube UI).

- [ ] **Step 9: Commit**

```bash
git add prototype/game_dungeon/main.gd
git commit -m "Wire scrapbook into pickup, save/load, UI, and self-test

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
```

---

### Task 5: Docs, deploy, final commit

**Files:**
- Modify: `prototype/game_dungeon/README.md`, `docs/PROJECT_MEMORY.md`, `prototype/game_dungeon/main.gd:40` (`DEPLOYED_AT_KST`)

- [ ] **Step 1: Add a README section** describing the scrapbook (scope, cost formula, manual-equip-only, unique-duplicate-bypass-is-intentional note) — follow the exact style of the existing "제작(Crafted) 레시피" section added 2026-10-08.

- [ ] **Step 2: Add a dated `PROJECT_MEMORY.md` section** following the established per-round format (see the 2026-10-08 sections for the exact structure: what changed, what was found during implementation, verification results, deploy info).

- [ ] **Step 3: Bump `DEPLOYED_AT_KST`** to the current time before export (check actual current time with `date -u` and convert to KST, UTC+9 — do not guess).

- [ ] **Step 4: Export, deploy to gh-pages, verify hash via `curl`, playwright screenshot check** — follow the exact sequence used in every prior round this session (see `[[deployment-workflow]]` memory): `rm -rf .godot build_web && godot --headless --path . --export-release "Web" "build_web/index.html"`, clone/update the gh-pages scratchpad checkout, copy `index.*`, commit, push, poll `gh api repos/jflakeee/diablo/pages/builds/latest` until `built`, `curl` the **remote** `index.pck` and hash it (not two local copies), compare to local build hash, playwright screenshot of the deployed class-select screen showing the new timestamp.

- [ ] **Step 5: Commit source + docs to both branches**

```bash
git add prototype/game_dungeon/README.md docs/PROJECT_MEMORY.md prototype/game_dungeon/main.gd
git commit -m "Document scrapbook round and bump deploy timestamp

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>"
git push origin docs/diablo2-clone-design
git push origin HEAD:main
```

- [ ] **Step 6: Update session memory** — append a dated entry to `systems-built.md` (the memory file, not the repo) summarizing this round, following the exact pattern of every prior round's entry in that file.
