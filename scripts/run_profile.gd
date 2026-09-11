class_name RunProfile
extends RefCounted

const SAVE_PATH := "user://run_profile.json"


static func record_extraction(gold: int, district: int) -> Dictionary:
	var profile := load_profile()
	profile["total_extracted_gold"] = int(profile["total_extracted_gold"]) + max(0, gold)
	profile["best_district"] = max(int(profile["best_district"]), district)
	profile["successful_extractions"] = int(profile["successful_extractions"]) + 1
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(profile))
		file.close()
	else:
		push_warning("[RunProfile] Could not save extraction profile")
	return profile


static func load_profile() -> Dictionary:
	var fallback := {
		"total_extracted_gold": 0,
		"best_district": 0,
		"successful_extractions": 0,
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
