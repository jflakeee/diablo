extends RefCounted

const PATH := "res://data/coverage.json"

static func _read_spec() -> Dictionary:
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null: return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK: return {}
	return json.data if json.data is Dictionary else {}

static func _has_all(actual: Array, required: Array) -> bool:
	for value in required:
		if not actual.has(value): return false
	return true

static func validate(data_script: GDScript, skills_script: GDScript, item_script: GDScript, craft_script: GDScript) -> Dictionary:
	var spec := _read_spec()
	var failures: Array = []
	var checks := 0
	if spec.is_empty():
		return {"ok": false, "checks": 1, "failures": ["coverage spec missing"]}

	var classes: Dictionary = spec["classes"]
	checks += 2
	if int(classes["minimum"]) > 2: failures.append("class count")
	if not _has_all(["warden", "arcanist"], classes["required_ids"]): failures.append("class roles")

	var skill_spec: Dictionary = spec["skills"]
	var skill_defs: Dictionary = skills_script.DEFS
	var skill_types: Array = []
	var elements: Array = []
	var prerequisite_skills := 0
	for definition in skill_defs.values():
		skill_types.append(String(definition.get("type", "")))
		elements.append(String(definition.get("element", "")))
		if not (definition.get("requires", []) as Array).is_empty(): prerequisite_skills += 1
	var synergy_links := 0
	var synergy_integrity := true
	for target in skills_script.SYNERGIES:
		if not skill_defs.has(target): synergy_integrity = false
		for contributor in (skills_script.SYNERGIES[target] as Dictionary):
			synergy_links += 1
			if not skill_defs.has(contributor): synergy_integrity = false
	checks += 5
	if skill_defs.size() < int(skill_spec["minimum"]): failures.append("skill count")
	if not _has_all(skill_types, skill_spec["required_types"]): failures.append("skill types")
	if not _has_all(elements, skill_spec["required_elements"]): failures.append("skill elements")
	if synergy_links < int(skill_spec["minimum_synergy_links"]) or not synergy_integrity: failures.append("skill synergies")
	if prerequisite_skills < int(skill_spec["minimum_prerequisite_skills"]): failures.append("skill prerequisites")

	var monsters: Array = data_script.monsters()
	var monster_kinds: Array = []
	var immune := false
	var resistant := false
	var vulnerable := false
	for monster in monsters:
		monster_kinds.append(String(monster.get("kind", "")))
		for key in ["res_fire", "res_cold", "res_light", "res_poison"]:
			var resistance := int(monster.get(key, 0))
			immune = immune or resistance >= 100
			resistant = resistant or (resistance > 0 and resistance < 100)
			vulnerable = vulnerable or resistance < 0
	var monster_spec: Dictionary = spec["monsters"]
	checks += 3
	if monsters.size() < int(monster_spec["minimum"]): failures.append("monster count")
	if not _has_all(monster_kinds, monster_spec["required_kinds"]): failures.append("monster kinds")
	if not (immune and resistant and vulnerable): failures.append("monster resistance roles")

	var bases: Dictionary = data_script.item_bases()
	var affixes: Dictionary = data_script.affixes()
	var slots: Array = []
	var base_count := 0
	for group in ["weapons", "armor", "accessories"]:
		for base in bases.get(group, []):
			base_count += 1
			slots.append(String(base.get("slot", "")))
	var stats: Array = []
	for group in ["prefixes", "suffixes"]:
		for affix in affixes.get(group, []): stats.append(String(affix.get("stat", "")))
	# Runtime item tables include elemental affixes in addition to the compact JSON import sample.
	for affix in item_script.PREFIXES: stats.append(String(affix.get("stat", "")))
	for affix in item_script.SUFFIXES: stats.append(String(affix.get("stat", "")))
	var item_spec: Dictionary = spec["items"]
	checks += 9
	if base_count < int(item_spec["minimum_bases"]): failures.append("item bases")
	if item_script.UNIQUES.size() < int(item_spec["minimum_uniques"]): failures.append("unique count")
	var set_ids := {}
	for set_piece in item_script.SETS.values():
		set_ids[String(set_piece.get("set_id", ""))] = true
	if set_ids.size() < int(item_spec["minimum_sets"]): failures.append("set count")
	if item_script.SETS.size() < int(item_spec["minimum_set_items"]): failures.append("set item count")
	if not _has_all(slots, item_spec["required_slots"]): failures.append("item slots")
	if not _has_all(stats, item_spec["required_affix_stats"]): failures.append("affix roles")

	var craft_spec: Dictionary = spec["crafting"]
	checks += 3
	if craft_script.RUNE_ORDER.size() < int(craft_spec["minimum_sigils"]): failures.append("sigil count")
	if craft_script.GEM_STATS.size() < int(craft_spec["minimum_gems"]): failures.append("gem count")
	if craft_script.RUNEWORDS.size() < int(craft_spec["minimum_words"]): failures.append("word count")

	var progression: Dictionary = spec["progression"]
	checks += 6
	if int(progression["difficulties"]) != 3: failures.append("difficulty tiers")
	if int(progression["levels_per_act"]) != 3: failures.append("act structure")
	var quests: Array = data_script.quests()
	var quest_ids := {}
	var quest_acts := {}
	var quest_targets: Array = []
	var quest_integrity := true
	for raw in quests:
		var quest: Dictionary = raw
		var quest_id := String(quest.get("id", ""))
		if quest_id.is_empty() or quest_ids.has(quest_id):
			quest_integrity = false
		quest_ids[quest_id] = true
		quest_acts[int(quest.get("act", 0))] = true
		var objective: Dictionary = quest.get("objective", {})
		quest_targets.append(String(objective.get("target", "")))
	for raw in quests:
		for required_id in (raw as Dictionary).get("requires", []):
			if not quest_ids.has(String(required_id)):
				quest_integrity = false
	if quests.size() < int(progression["minimum_quests"]): failures.append("quest count")
	if quest_acts.size() < int(progression["minimum_acts"]): failures.append("quest acts")
	if not _has_all(quest_targets, progression["required_quest_targets"]): failures.append("quest target roles")
	if not quest_integrity: failures.append("quest integrity")
	var waypoints: Array = data_script.waypoints()
	var waypoint_ids := {}
	var waypoint_pairs := {}
	var waypoint_per_act := {}
	var waypoint_integrity := true
	for raw in waypoints:
		var waypoint: Dictionary = raw
		var waypoint_id := String(waypoint.get("id", ""))
		var waypoint_act := int(waypoint.get("act", 0))
		var waypoint_floor := int(waypoint.get("floor", 0))
		var pair := "%d:%d" % [waypoint_act, waypoint_floor]
		if waypoint_id.is_empty() or waypoint_ids.has(waypoint_id) or waypoint_pairs.has(pair):
			waypoint_integrity = false
		waypoint_ids[waypoint_id] = true
		waypoint_pairs[pair] = true
		waypoint_per_act[waypoint_act] = int(waypoint_per_act.get(waypoint_act, 0)) + 1
	if waypoints.size() < int(progression["minimum_waypoints"]): failures.append("waypoint count")
	for waypoint_act in range(1, int(progression["minimum_acts"]) + 1):
		if int(waypoint_per_act.get(waypoint_act, 0)) < int(progression["waypoints_per_act"]):
			waypoint_integrity = false
	if waypoint_per_act.size() < int(progression["minimum_acts"]): failures.append("waypoint acts")
	if not waypoint_integrity: failures.append("waypoint integrity")
	return {"ok": failures.is_empty(), "checks": checks, "failures": failures, "monsters": monsters.size(), "skills": skill_defs.size(), "bases": base_count, "quests": quests.size(), "waypoints": waypoints.size()}
