extends RefCounted

const MIN_LOGIC_HZ := 23.75
const MAX_LOGIC_HZ := 26.25
const MAX_ACTIVE_OBJECTS := 128
const MAX_MEMORY_GROWTH_BYTES := 64 * 1024 * 1024

static func evaluate(elapsed: float, logic_ticks: int, peak_active: int, start_memory: int, peak_memory: int) -> Dictionary:
	var failures: Array = []
	var logic_hz := float(logic_ticks) / maxf(elapsed, 0.001)
	var memory_growth := maxi(peak_memory - start_memory, 0)
	if logic_hz < MIN_LOGIC_HZ or logic_hz > MAX_LOGIC_HZ:
		failures.append("logic_hz %.2f" % logic_hz)
	if peak_active > MAX_ACTIVE_OBJECTS:
		failures.append("active_objects %d" % peak_active)
	if memory_growth > MAX_MEMORY_GROWTH_BYTES:
		failures.append("memory_growth %d" % memory_growth)
	return {"ok": failures.is_empty(), "logic_hz": logic_hz, "peak_active": peak_active, "memory_growth": memory_growth, "failures": failures}

static func selftest() -> bool:
	return bool(evaluate(40.0, 1000, 64, 1000, 2000)["ok"]) and not bool(evaluate(40.0, 800, 64, 1000, 2000)["ok"])
