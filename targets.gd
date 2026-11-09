extends RefCounted
## Target definitions are independent of the presentation and response clocks.
const SHAPES := ["abstract_01", "abstract_02", "abstract_03", "abstract_04", "abstract_05", "abstract_06", "abstract_07", "abstract_08", "abstract_09", "abstract_10", "abstract_11", "abstract_12"]
const COLOR_NAMES := ["Blue", "Yellow", "Pink", "Green"]
const DEFAULT_TARGET := [{"shape": "abstract_01", "color": 0}]

static func same(a: Dictionary, b: Dictionary) -> bool:
	return a.shape == b.shape and a.color == b.color

static func matches(item: Dictionary, active: Array) -> bool:
	for target in active:
		if same(item, target): return true
	return false

static func combinations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for shape in SHAPES:
		for color in COLOR_NAMES.size(): result.append({"shape": shape, "color": color})
	return result

static func generate(previous: Array, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for item in combinations():
		if not matches(item, previous): available.append(item)
	var result: Array[Dictionary] = []
	for i in 1:
		var index := rng.randi_range(0, available.size() - 1)
		result.append(available.pop_at(index))
	return result

static func describe(item: Dictionary) -> String:
	return "%s %s" % [COLOR_NAMES[item.color], item.shape]

