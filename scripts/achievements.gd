class_name Achievements
extends RefCounted

static func catalog() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Array in [
		["runs", "출격 일지", [1, 10, 50], [5, 15, 30]],
		["kills", "별의 사냥꾼", [100, 1000, 10000], [10, 20, 50]],
		["wins", "돌파의 증명", [1, 5, 25], [10, 25, 50]],
		["dashes", "점멸 항해사", [10, 100, 500], [5, 15, 30]],
		["overdrives", "코어 과충전", [1, 20, 100], [5, 15, 30]],
		["returns", "심우주 귀환", [1, 10, 50], [10, 20, 40]],
		["elites", "정예 추적자", [1, 10, 50], [5, 15, 30]],
		["time", "한계 생존", [180, 300, 420], [10, 25, 50]],
		["combo", "연쇄 격파", [10, 30, 60], [10, 20, 40]],
	]:
		for i: int in range(3):
			result.append({"id": "%s_%d" % [row[0], i], "name": "%s %s" % [row[1], ["I", "II", "III"][i]], "stat": row[0], "target": row[2][i], "points": row[3][i], "description": ("한 출격 최고 " if row[0] in ["time", "combo"] else "누적 ") + str(row[2][i]) + ("초 생존" if row[0] == "time" else "회 달성")})
	for ship: String in GameContent.SHIP_IDS:
		result.append({"id": "ship_" + ship, "name": GameContent.ship_info(ship).name + " 돌파", "stat": "ship_" + ship, "target": 1, "points": 25, "description": "이 기체로 5분 돌파"})
	for sector: String in GameContent.SECTOR_IDS:
		result.append({"id": "sector_" + sector, "name": GameContent.sector_info(sector).name + " 정복", "stat": "sector_" + sector, "target": 1, "points": 25, "description": "이 전장에서 5분 돌파"})
	for row: Array in [["blade", "절삭 전문가"], ["frost", "빙결 전문가"], ["missile", "유도탄 전문가"], ["chain", "번개 전문가"]]:
		result.append({"id": row[0], "name": row[1], "stat": row[0], "target": 1, "points": 20, "description": "해당 강화 3단계로 180초 생존"})
	for row: Array in [["veteran", "베테랑 돌파", 50], ["cataclysm", "대붕괴 돌파", 100], ["evolved", "진화의 시작", 20]]:
		result.append({"id": row[0], "name": row[1], "stat": row[0], "target": 1, "points": row[2], "description": "해당 난이도 돌파" if row[0] != "evolved" else "무기 진화 달성"})
	return result

static func points(unlocked: Array) -> int:
	var total := 0
	for item: Dictionary in catalog():
		if item.id in unlocked:
			total += int(item.points)
	return total
