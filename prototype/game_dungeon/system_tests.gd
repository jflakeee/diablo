extends RefCounted

const Combat := preload("res://combat.gd")
const Skills := preload("res://skills.gd")
const Craft := preload("res://craft.gd")
const LevelGen := preload("res://level_gen.gd")
const Item := preload("res://item.gd")
const Data := preload("res://data.gd")
const Quest := preload("res://quest.gd")
const Waypoint := preload("res://waypoint.gd")

static func _check(condition: bool, label: String, failures: Array) -> void:
	if not condition:
		failures.append(label)

static func _connected(level: Dictionary) -> bool:
	var start: Vector2i = level["entrance"]
	var goal: Vector2i = level["exit"]
	var grid: Array = level["grid"]
	var width := int(level["w"])
	var height := int(level["h"])
	var queue: Array[Vector2i] = [start]
	var visited := {start: true}
	var cursor := 0
	while cursor < queue.size():
		var current := queue[cursor]
		cursor += 1
		if current == goal:
			return true
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = current + direction
			if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height:
				continue
			if not visited.has(next) and int(grid[next.y][next.x]) == 1:
				visited[next] = true
				queue.append(next)
	return false

static func run() -> Dictionary:
	var failures: Array = []

	_check(is_equal_approx(Combat.chance_to_hit(1, 100000, 1, 99), 5.0), "combat hit floor", failures)
	_check(is_equal_approx(Combat.chance_to_hit(100000, 0, 99, 1), 95.0), "combat hit cap", failures)
	_check(Combat.apply_resistance(100, 100) == 0, "resistance immunity", failures)
	_check(Combat.apply_resistance(100, -50) == 150, "negative resistance", failures)
	_check(Combat.sorc_fcr_frames(0) == 13 and Combat.sorc_fcr_frames(200) == 7, "cast breakpoints", failures)
	_check(is_equal_approx(Combat.frames_to_sec(25), 1.0), "25 fps timing", failures)
	_check(Combat.diff_player_resist_penalty(2) == -100 and Combat.diff_hell_physical_floor(2) == 50, "difficulty penalties", failures)
	_check(Combat.warden_max_life(25, 1) == 157 and Combat.warden_max_mana(15, 1) == 26, "warden vitals", failures)

	var expected_skills := ["ember_bolt", "frost_shard", "iron_chant", "phase_step", "storm_lance", "sundering_strike", "void_fury", "weapon_discipline"]
	var actual_skills: Array = Skills.DEFS.keys()
	actual_skills.sort()
	_check(actual_skills == expected_skills, "project-owned skill ids", failures)
	_check(Skills.mana_cost("iron_chant") == 10, "skill mana cost", failures)
	_check(Skills.mana_cost("ember_bolt") == 3 and Skills.mana_cost("storm_lance") == 4 and Skills.mana_cost("phase_step") == 6, "arcanist mana costs", failures)
	_check(is_equal_approx(Skills.sundering_damage_pct(1), 45.0), "sundering scaling", failures)
	_check(is_equal_approx(Skills.iron_chant_bonus_pct(1), 35.0), "iron chant scaling", failures)
	var arcanist_tree := {"ember_bolt": 1, "frost_shard": 0, "storm_lance": 0, "phase_step": 0}
	_check(not Skills.can_invest("frost_shard", arcanist_tree, 1) and Skills.can_invest("frost_shard", arcanist_tree, 2), "skill level prerequisite", failures)
	_check(not Skills.can_invest("storm_lance", arcanist_tree, 4), "skill dependency rejection", failures)
	arcanist_tree["frost_shard"] = 3
	_check(Skills.apply_synergy(100, "ember_bolt", arcanist_tree) == 109, "spell synergy damage", failures)
	var capped_tree := {"ember_bolt": Skills.MAX_LEVEL}
	_check(not Skills.can_invest("ember_bolt", capped_tree, 99), "skill maximum level", failures)
	_check(is_equal_approx(Skills.synergy_bonus_pct("void_fury", {"sundering_strike": 2}), 12.0), "attack synergy damage", failures)

	_check(String(Craft.match_runeword("weapon", ["Vey", "Ahn"]).get("name", "")) == "Tempered Edge", "sigil order match", failures)
	_check(Craft.match_runeword("weapon", ["Ahn", "Vey"]).is_empty(), "sigil reverse rejection", failures)
	_check(Craft.upgrade_rune("Ahn") == "Ahnor", "sigil upgrade", failures)
	_check(Craft.upgrade_gem_quality("flawless") == "perfect", "gem upgrade", failures)

	var level_a := LevelGen.generate(424242)
	var level_b := LevelGen.generate(424242)
	_check(int(level_a["w"]) == 27 and int(level_a["h"]) == 27, "level dimensions", failures)
	_check(int(level_a["rooms"]) == 9 and int(level_a["doors"]) == 8, "level topology", failures)
	_check(level_a["entrance"] != level_a["exit"], "distinct level endpoints", failures)
	_check(level_a["entrance"] == level_b["entrance"] and level_a["exit"] == level_b["exit"] and level_a["grid"] == level_b["grid"], "level determinism", failures)
	_check(_connected(level_a), "level connectivity", failures)

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var unique_item := Item.generate(rng, Item.WEAPON_BASES[1], 20, "unique")
	_check(Item.display_name(unique_item) == "Rift Cleaver (Hand Axe)", "unique identity", failures)
	_check(int(unique_item["affixes"].get("ed", 0)) == 70, "unique fixed affix", failures)
	_check(Item.quality_color("unique") == Color(0.72, 0.55, 0.28), "unique quality color", failures)
	var durable_item := Item.generate(rng, Item.WEAPON_BASES[0], 10, "rare")
	_check(Item.durability(durable_item) == 24 and not Item.is_broken(durable_item), "item initial durability", failures)
	Item.lose_durability(durable_item, 24)
	_check(Item.is_broken(durable_item) and Item.effective_affixes(durable_item).is_empty(), "broken item disabled", failures)
	var expected_repair_cost := Item.repair_cost(durable_item)
	_check(expected_repair_cost == 216 and Item.repair(durable_item) == expected_repair_cost and Item.durability(durable_item) == 24, "item repair cost", failures)
	var legacy_item := {"slot": "armor", "quality": "normal", "ilvl": 1}
	_check(Item.durability(legacy_item) == 32 and not Item.is_broken(legacy_item), "legacy item durability migration", failures)

	var quest_defs := Data.quests()
	var quest_state := Quest.new_state(quest_defs)
	_check(quest_defs.size() == 6 and String(quest_state["embers_at_the_gate"]["status"]) == "active", "quest campaign initialization", failures)
	for i in 5:
		Quest.apply_kill(quest_defs, quest_state, 1, "melee")
	_check(String(quest_state["embers_at_the_gate"]["status"]) == "complete" and String(quest_state["silence_the_matron"]["status"]) == "active", "quest prerequisite unlock", failures)
	var completed := Quest.apply_kill(quest_defs, quest_state, 1, "boss")
	_check(completed == ["silence_the_matron"] and String(quest_state["broken_watchers"]["status"]) == "active", "quest act chain", failures)
	_check(Quest.objective_text(quest_defs, quest_state, 2).contains("0/4"), "quest objective text", failures)
	var restored := Quest.normalize_state(quest_defs, quest_state.duplicate(true))
	_check(String(restored["broken_watchers"]["status"]) == "active" and int(restored["embers_at_the_gate"]["progress"]) == 5, "quest save normalization", failures)

	var set_weapon := Item.generate(rng, Item.WEAPON_BASES[0], 12, "set")
	var set_armor := Item.generate(rng, Item.ARMOR_BASES[0], 12, "set")
	_check(String(set_weapon.get("set_id", "")) == "ember_oath" and Item.display_name(set_weapon) == "Oathspark (Ember Oath)", "set item identity", failures)
	_check(Item.quality_color("set") == Color(0.2, 0.85, 0.35), "set quality color", failures)
	var set_bonus := Item.equipped_set_bonus([set_weapon, set_armor])
	_check(int(set_bonus.get("life", 0)) == 30 and int(set_bonus.get("res_all", 0)) == 12, "set completion bonus", failures)
	Item.lose_durability(set_armor, Item.durability_max(set_armor))
	_check(Item.equipped_set_bonus([set_weapon, set_armor]).is_empty(), "broken set piece disables bonus", failures)

	var waypoint_defs := Data.waypoints()
	var waypoint_state := Waypoint.new_state()
	_check(waypoint_defs.size() == 9 and Waypoint.unlock(waypoint_defs, waypoint_state, 1, 1), "waypoint initial unlock", failures)
	_check(Waypoint.adjacent(waypoint_defs, waypoint_state, 1, -1).is_empty(), "waypoint locked travel rejection", failures)
	Waypoint.unlock(waypoint_defs, waypoint_state, 1, 2)
	var previous_waypoint := Waypoint.adjacent(waypoint_defs, waypoint_state, 1, -1)
	_check(String(previous_waypoint.get("id", "")) == "cinder_gate", "waypoint backward travel", failures)
	_check(String(Waypoint.cycle(waypoint_defs, waypoint_state, 1).get("id", "")) == "cinder_gate", "waypoint mobile cycle", failures)
	_check(Waypoint.adjacent(waypoint_defs, waypoint_state, 2, -1).is_empty(), "waypoint cross-act isolation", failures)
	var restored_waypoints := Waypoint.normalize_state(waypoint_defs, waypoint_state.duplicate(true))
	_check((restored_waypoints["unlocked"] as Dictionary).size() == 2 and String(restored_waypoints["current"]) == "hollow_watch", "waypoint save normalization", failures)

	return {"ok": failures.is_empty(), "checks": 49, "failures": failures}
