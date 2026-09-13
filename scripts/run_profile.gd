class_name RunProfile
extends RefCounted

const SAVE_PATH := "user://run_profile.json"


static func record_extraction(gold: int, district: int, kills := 0) -> Dictionary:
	var profile := load_profile()
	profile["total_extracted_gold"] = int(profile["total_extracted_gold"]) + max(0, gold)
	profile["best_district"] = max(int(profile["best_district"]), district)
	profile["successful_extractions"] = int(profile["successful_extractions"]) + 1
	profile["research"] = int(profile["research"]) + _research_earned(gold, district, kills, true)
	_save(profile)
	return profile


static func record_defeat(gold: int, district: int, kills: int) -> Dictionary:
	var profile := load_profile()
	profile["research"] = int(profile["research"]) + _research_earned(gold, district, kills, false)
	_save(profile)
	return profile


static func research_earned(gold: int, district: int, kills: int, extracted: bool) -> int:
	return _research_earned(gold, district, kills, extracted)


static func training_cost(profile: Dictionary) -> int:
	return 10 + 10 * int(profile.get("training_level", 0))


static func purchase_training() -> bool:
	var profile := load_profile()
	var cost := training_cost(profile)
	if int(profile["research"]) < cost:
		return false
	profile["research"] = int(profile["research"]) - cost
	profile["training_level"] = int(profile["training_level"]) + 1
	_save(profile)
	return true


static func _research_earned(gold: int, district: int, kills: int, extracted: bool) -> int:
	var base: int = max(1, floori(float(max(0, kills)) / 4.0) + max(0, district - 1) * 5 + floori(float(max(0, gold)) / 25.0))
	return base * (2 if extracted else 1)


static func _save(profile: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(profile))
		file.close()
	else:
		push_warning("[RunProfile] Could not save extraction profile")


static func load_profile() -> Dictionary:
	var fallback := {
		"total_extracted_gold": 0,
		"best_district": 0,
		"successful_extractions": 0,
		"research": 0,
		"training_level": 0,
	}
	if not FileAccess.file_exists(SAVE_PATH):
		return fallback
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return fallback
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is not Dictionary:
		return fallback
	for key in fallback:
		if not parsed.has(key):
			parsed[key] = fallback[key]
	return parsed
