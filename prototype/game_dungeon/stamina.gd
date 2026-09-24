extends RefCounted

const RUN_SPEED_MULTIPLIER := 1.6
const RECOVERY_DELAY := 1.0

static func maximum(level: int, vitality: int) -> float:
	return float(80 + maxi(1, level) + maxi(0, vitality) * 2)

static func drain_per_second(armor_speed_penalty: int = 0, slower_drain_pct: int = 0) -> float:
	var scaled := 40.0 * (1.0 + float(armor_speed_penalty) / 10.0) * (100.0 - clampi(slower_drain_pct, 0, 95)) / 100.0
	return 25.0 * maxf(scaled, 1.0) / 256.0

static func armor_speed_penalty(armor: Dictionary) -> int:
	if armor.is_empty():
		return 0
	var defense := int(armor.get("defense", 0))
	return 10 if defense >= 24 else (5 if defense >= 12 else 0)

static func update(current: float, maximum_value: float, moving: bool, wants_run: bool, delta: float, recovery_delay: float, armor_penalty: int = 0) -> Dictionary:
	var stamina := clampf(current, 0.0, maximum_value)
	var delay := maxf(0.0, recovery_delay)
	var running := moving and wants_run and stamina > 0.0
	if running:
		stamina = maxf(0.0, stamina - drain_per_second(armor_penalty) * delta)
		delay = RECOVERY_DELAY
	elif moving:
		delay = RECOVERY_DELAY
	else:
		delay = maxf(0.0, delay - delta)
		if delay <= 0.0:
			stamina = minf(maximum_value, stamina + maxf(4.0, maximum_value * 0.08) * delta)
	return {"stamina": stamina, "recovery_delay": delay, "running": running}
