extends RefCounted
# Guards project-owned display data against accidental reintroduction of reference-game names.

const FORBIDDEN := ["andariel", "rixot's keen", "the gnasher", "crushflange", "greyform",
	"iceblink", "silks of the victor", "fallen shaman", "diablo clone"]
const CONTENT_PATHS := ["res://data/monsters.json", "res://data/affixes.json", "res://item.gd",
	"res://craft.gd", "res://project.godot"]
const MONSTER_IDS := ["ash_imp", "ash_caller", "thorn_beast", "rotwalker", "bone_guard",
	"bone_marksman", "horned_marauder", "crimson_raptor", "blighted_ranger", "grave_stalker",
	"venom_husk", "brood_matron"]

static func selftest(data_script: GDScript) -> Dictionary:
	var failures: Array = []
	for path in CONTENT_PATHS:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			failures.append("missing " + path)
			continue
		var content := file.get_as_text().to_lower()
		for forbidden in FORBIDDEN:
			if forbidden in content:
				failures.append("forbidden name '%s' in %s" % [forbidden, path])
	var found: Array = []
	for monster in data_script.monsters():
		found.append(String(monster.get("id", "")))
	found.sort()
	var expected := MONSTER_IDS.duplicate()
	expected.sort()
	if found != expected:
		failures.append("monster identity set mismatch")
	return {"ok": failures.is_empty(), "failures": failures, "monster_ids": found.size()}
