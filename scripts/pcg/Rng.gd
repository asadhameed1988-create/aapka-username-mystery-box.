extends RefCounted
## Deterministic random helpers.
## Same seed -> same puzzle on every device (needed for replay, debugging, server delivery).


static func make(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


## Derive an independent 31-bit sub-seed from a seed and two indices.
static func derive(seed_value: int, a: int, b: int = 0) -> int:
	var s: int = seed_value & 0x7FFFFFFF
	return (s * 1103515245 + 12345 + a * 7919 + b * 104729) & 0x7FFFFFFF


## Fisher-Yates shuffle driven by the given rng (Array.shuffle() is NOT seed-safe).
static func shuffled(items: Array, rng: RandomNumberGenerator) -> Array:
	var out: Array = items.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


static func coin(rng: RandomNumberGenerator) -> int:
	if rng.randi_range(0, 1) == 0:
		return 1
	return -1


static func pick(items: Array, rng: RandomNumberGenerator):
	return items[rng.randi_range(0, items.size() - 1)]
