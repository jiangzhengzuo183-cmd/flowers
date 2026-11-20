extends RefCounted
## Authoritative unlocks come from actual story events, never a maximum calendar date.
const PATH := "res://modules/visual_novel/data/report_book_catalog.json"

static func entries() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string(PATH)).entries

static func unlocked(owner: Node) -> Array[String]:
	var result: Array[String] = []
	var first = owner.get("flow")
	if first != null and (first.report_opened or first.report_completed): result.append("report1")
	var story := owner.get_parent()
	if story != null and story.get("completed_day01") != null and story.completed_day01.report_completed and "report1" not in result: result.append("report1")
	var narrative = owner.get("narrative")
	if narrative != null:
		for id: String in narrative.unlocked_reports:
			if id not in result: result.append(id)
	return result

static func request(owner: Node, current: String, review: bool) -> Dictionary:
	var ids := unlocked(owner)
	# An explicit report preview gets only its own event; it does not alter the live story ledger.
	if not review and not current.is_empty() and current not in ids: ids.append(current)
	return {"mode":"review" if review else "story","currentReport":current,"unlocked":ids}
