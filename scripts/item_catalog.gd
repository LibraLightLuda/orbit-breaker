class_name ItemCatalog
extends RefCounted

const IDS := ["power", "speed", "rapid", "repair", "heal", "stun", "emp", "frenzy", "insight", "bounty", "shield", "haste"]
const GRADES := ["C", "B", "A"]

static func info(id: String, grade: String = "C") -> Dictionary:
	if not id in IDS or not grade in GRADES:
		return {}
	var rank := GRADES.find(grade)
	var row: Array = {
		"power": ["출력 코어", [30, 60, 100], [10, 10, 10], "모든 무기 피해 +%d%% · %d초"],
		"speed": ["추진 연료", [20, 35, 50], [10, 10, 10], "일반 이동 속도 +%d%% · %d초"],
		"rapid": ["속사 회로", [30, 55, 90], [10, 10, 10], "자동포 공격 속도 +%d%% · %d초"],
		"repair": ["수리 나노봇", [3, 6, 10], [10, 10, 10], "초당 선체 재생 +%d · %d초"],
		"heal": ["응급 수리", [25, 45, 70], [0, 0, 0], "최대 선체의 %d%% 즉시 회복"],
		"stun": ["정지장", [1.5, 2.5, 4.0], [0, 0, 0], ""],
		"emp": ["EMP 폭탄", [100, 220, 450], [0, 0, 0], ""],
		"frenzy": ["광전 회로", [80, 150, 300], [4, 4, 5], "자동포 공격 속도 +%d%% · %d초"],
		"insight": ["학습 증폭기", [35, 60, 100], [12, 12, 12], "경험치 획득 +%d%% · %d초"],
		"bounty": ["현상금 비콘", [40, 75, 120], [12, 12, 12], "점수 획득 +%d%% · %d초"],
		"shield": ["붕괴 흡수막", [30, 60, 100], [12, 12, 12], "피해/자연 붕괴/외곽 손상 %d 흡수 · %d초"],
		"haste": ["점멸 축전지", [30, 50, 75], [10, 10, 10], "돌진 재충전 속도 +%d%% · %d초"],
	}[id]
	var radius := float(([220, 320, 440] if id == "stun" else [180, 250, 340])[rank])
	var description := ""
	if id == "heal":
		description = str(row[3]) % row[1][rank]
	elif id == "stun":
		description = "%dpx 안 적 %.1f초 마비 · 정예/보스 지속 35%%" % [radius, row[1][rank]]
	elif id == "emp":
		description = "%dpx 안 적 피해 %d · 범위 안 적 탄환 제거" % [radius, row[1][rank]]
	else:
		description = str(row[3]) % [row[1][rank], row[2][rank]]
	return {"id": id, "grade": grade, "name": row[0], "value": float(row[1][rank]), "duration": float(row[2][rank]), "radius": radius, "description": description}

static func grade_color(grade: String) -> Color:
	return {"C": Color("72dce6"), "B": Color("a798ff"), "A": Color("ffd18a")}.get(grade, Color.WHITE)

static func draw_icon(canvas: CanvasItem, at: Vector2, id: String, color: Color, scale: float = 1.0) -> void:
	var lines: Array = []
	match id:
		"insight":
			lines = [[-9,0,0,-10],[0,-10,9,0],[9,0,0,10],[0,10,-9,0],[0,-5,0,5],[-5,0,5,0]]
		"bounty":
			canvas.draw_arc(at, 10 * scale, 0, TAU, 6, color, 2 * scale, true)
			lines = [[-5,-4,5,-4],[5,-4,-5,4],[-5,4,5,4]]
		"shield":
			lines = [[-9,-8,9,-8],[9,-8,7,4],[7,4,0,11],[0,11,-7,4],[-7,4,-9,-8]]
		"haste":
			canvas.draw_arc(at, 11 * scale, 0, TAU, 24, color, 2 * scale, true)
			lines = [[0,-8,-4,1],[-4,1,3,1],[3,1,0,8]]
		"power":
			lines = [[-8,8,0,-9],[0,-9,8,8],[-5,3,5,3],[0,-4,0,7]]
		"speed":
			lines = [[-8,-8,0,0],[0,0,-8,8],[0,-8,8,0],[8,0,0,8]]
		"rapid":
			lines = [[-8,-7,8,-7],[-8,0,8,0],[-8,7,8,7]]
		"repair", "heal":
			lines = [[-8,0,8,0],[0,-8,0,8]]
			if id == "repair":
				canvas.draw_arc(at, 12 * scale, 0.3, 5.8, 24, color, 2 * scale, true)
		"stun":
			lines = [[-4,-9,-4,9],[4,-9,4,9],[-9,-4,9,-4],[-9,4,9,4]]
		"emp":
			canvas.draw_circle(at, 4 * scale, color)
			canvas.draw_arc(at, 10 * scale, 0, TAU, 24, color, 2 * scale, true)
			lines = [[-14,0,-11,0],[11,0,14,0],[0,-14,0,-11],[0,11,0,14]]
		"frenzy":
			lines = [[2,-11,-7,1],[-7,1,2,1],[2,1,-2,11],[-2,11,8,-2],[8,-2,1,-2],[1,-2,2,-11]]
	for line: Array in lines:
		canvas.draw_line(at + Vector2(line[0], line[1]) * scale, at + Vector2(line[2], line[3]) * scale, color, 2.5 * scale, true)
