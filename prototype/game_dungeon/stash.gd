extends RefCounted

const CAPACITY := 48

static func normalize(raw) -> Array:
	var result: Array = []
	if not raw is Array:
		return result
	for entry in raw:
		if entry is Dictionary and not (entry as Dictionary).is_empty() and result.size() < CAPACITY:
			result.append((entry as Dictionary).duplicate(true))
	return result

static func deposit(item: Dictionary, inventory: Array, stash: Array) -> bool:
	if item.is_empty() or not inventory.has(item) or stash.size() >= CAPACITY:
		return false
	inventory.erase(item)
	stash.append(item)
	return true

static func withdraw(item: Dictionary, inventory: Array, stash: Array) -> bool:
	if item.is_empty() or not stash.has(item):
		return false
	stash.erase(item)
	inventory.append(item)
	return true
