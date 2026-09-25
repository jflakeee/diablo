extends RefCounted

const RESPAWN_DELAY := 2.0

static func experience_loss(difficulty: int, next_level_requirement: int) -> int:
	var percent := 0.0 if difficulty <= 0 else (0.05 if difficulty == 1 else 0.10)
	return maxi(0, floori(float(maxi(0, next_level_requirement)) * percent))

static func gold_loss(carried_gold: int) -> int:
	return clampi(floori(float(maxi(0, carried_gold)) * 0.20), 0, maxi(0, carried_gold))

static func create_corpse(gx: float, gy: float, held_gold: int) -> Dictionary:
	return {"active": true, "gx": gx, "gy": gy, "held_gold": maxi(0, held_gold)}

static func normalize_corpse(raw) -> Dictionary:
	if not raw is Dictionary or not bool(raw.get("active", false)):
		return {}
	return create_corpse(float(raw.get("gx", 0.0)), float(raw.get("gy", 0.0)), int(raw.get("held_gold", 0)))

static func can_recover(corpse: Dictionary, gx: float, gy: float, radius: float = 1.2) -> bool:
	if corpse.is_empty() or not bool(corpse.get("active", false)):
		return false
	return Vector2(gx, gy).distance_to(Vector2(float(corpse["gx"]), float(corpse["gy"]))) <= radius
