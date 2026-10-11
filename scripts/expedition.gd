class_name Expedition
extends RefCounted

const PART_IDS := ["core", "drive", "shell"]
const RECIPE_IDS := ["lancer", "battery", "aegis", "trinity"]
const MISSION_IDS := ["chaser", "runner", "tank", "shooter", "survive", "outer", "outer_kills", "returns", "dash_hits", "overdrive"]

static func part(id: String) -> Dictionary:
	return {
		"core": {"name": "화력 파츠", "symbol": "▲", "color": Color("ff7185"), "effect": "1개당 모든 피해 +6%"},
		"drive": {"name": "추진 파츠", "symbol": "»", "color": Color("72dce6"), "effect": "1개당 기본 추진 +8px/s"},
		"shell": {"name": "장갑 파츠", "symbol": "⬡", "color": Color("ffd18a"), "effect": "1개당 전투 피해 -4%"},
	}.get(id, {})

static func recipe(id: String) -> Dictionary:
	return {
		"lancer": {"name": "돌격 창기병", "needs": ["core", "drive"], "effect": "돌진 시작 시 115px 충격파 / II: 145px·피해 증가"},
		"battery": {"name": "쌍열 포대", "needs": ["core", "shell"], "effect": "자동포 2발 분산 / II: 3발·추가 관통"},
		"aegis": {"name": "기동 방벽", "needs": ["drive", "shell"], "effect": "5초마다 110px 적탄 제거 / II: 3.5초·150px"},
		"trinity": {"name": "삼위일체", "needs": ["core", "drive", "shell"], "effect": "세 조합 동시 가동·전체 피해 +12% / II: +24%"},
	}.get(id, {})

static func mission(id: String, grade: String) -> Dictionary:
	var rank: int = ["C", "B", "A"].find(grade)
	if rank < 0 or not id in MISSION_IDS:
		return {}
	var row: Array = {
		"chaser": ["추적체 요격", [12, 20, 30], "추적체 %d기 처치"],
		"runner": ["질주체 차단", [6, 10, 15], "질주체 %d기 처치"],
		"tank": ["중장체 해체", [3, 5, 8], "중장체 %d기 처치"],
		"shooter": ["포격수 사냥", [3, 5, 8], "포격수 %d기 처치"],
		"survive": ["정밀 회피", [4, 3, 2], "50초 생존 · 피격 %d회 미만"],
		"outer": ["외곽 정찰", [3, 5, 7], "외곽 누적 %d초 탐색 후 활동영역 복귀"],
		"outer_kills": ["전진 요격", [3, 5, 8], "기체가 외곽에 있을 때 적 %d기 처치"],
		"returns": ["경계 왕복", [1, 2, 3], "외곽 진입 후 안전 귀환 %d회"],
		"dash_hits": ["돌파 타격", [2, 4, 6], "돌진으로 적 %d회 타격"],
		"overdrive": ["코어 가동", [1, 1, 2], "오버드라이브 %d회 가동"],
	}[id]
	return {"id": id, "grade": grade, "name": row[0], "target": row[1][rank], "hint": str(row[2]) % row[1][rank], "upgrades": rank + 1, "parts": 1 if rank == 2 else 0}

static func valid_snapshot(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 4 or not value.get("parts") is Array or value.parts.size() != 3:
		return false
	for count: Variant in value.parts:
		if not count is int and not count is float:
			return false
		if not is_finite(float(count)) or float(count) < 0 or float(count) > 6:
			return false
	if not value.get("drops") is Array or value.drops.size() > 9:
		return false
	for row: Variant in value.drops:
		if not row is Array or row.size() != 6 or not row[0] in PART_IDS or not row[4] is bool or not row[5] in ["explore", "mission", "elite", "boss"]:
			return false
		for n: Variant in row.slice(1, 4):
			if not (n is int or n is float) or not is_finite(float(n)) or absf(float(n)) > 10000:
				return false
	if not value.get("mission") is Array or not value.get("result") is Array:
		return false
	var m: Array = value.mission
	if not m.is_empty():
		if m.size() != 5 or not m[0] in MISSION_IDS or not m[1] in ["C", "B", "A"] or not m[4] in ["preview", "active", "success", "failed"]:
			return false
		for n: Variant in m.slice(2, 4):
			if not (n is int or n is float) or not is_finite(float(n)) or float(n) < 0 or float(n) > 10000:
				return false
	return value.result.is_empty() or (value.result.size() == 3 and value.result[0] in MISSION_IDS and value.result[1] in ["C", "B", "A"] and value.result[2] is bool)
