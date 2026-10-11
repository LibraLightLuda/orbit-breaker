class_name GameContent
extends RefCounted

const SHIP_IDS := ["striker", "scout", "bastion"]
const SECTOR_IDS := ["ring", "storm", "forge"]
const EVOLUTION_IDS := ["superorbit", "storm", "salvo", "rail", "blizzard", "nova", "sentry", "wake", "citadel", "ellipse", "hatchet", "minefield"]
const MODE_IDS := ["normal", "relaxed", "veteran", "cataclysm"]

static func mode_info(id: String) -> Dictionary:
	return {
		"normal": {"name": "표준", "score": 1.0, "health": 1.0, "speed": 1.0, "spawn": 1.0, "damage": 1.0},
		"relaxed": {"name": "여유롭게", "score": 0.75, "health": 1.0, "speed": 1.0, "spawn": 1.0, "damage": 1.0},
		"veteran": {"name": "베테랑", "score": 1.5, "health": 1.35, "speed": 1.12, "spawn": 1.2, "damage": 1.2},
		"cataclysm": {"name": "대붕괴", "score": 2.0, "health": 1.75, "speed": 1.22, "spawn": 1.4, "damage": 1.45},
	}.get(id, {"name": "표준", "score": 1.0, "health": 1.0, "speed": 1.0, "spawn": 1.0, "damage": 1.0})

static func ship_info(id: String) -> Dictionary:
	var ships := {
		"striker": {"id": "striker", "name": "스트라이커", "description": "관성 조준: 자동포 +8~45% · 이동 중 낮은 증폭 유지\n빠른 이동/급선회 시 빠르게 감소 · 전용 파츠로 강화", "color": Color("62e8d8"), "hp": 100.0, "speed": 218.0, "dash": 3.0, "orbits": 3, "power": 1.0},
		"scout": {"id": "scout", "name": "스카우트", "description": "돌파형 · 돌진 피해 ×1.75\n대시 후 1.4초 가속 +35% · 치고 빠지기", "color": Color("89baff"), "hp": 80.0, "speed": 255.0, "dash": 2.45, "orbits": 3, "power": 0.9},
		"bastion": {"id": "bastion", "name": "배스천", "description": "요새형 · 8초마다 방벽: 피격 피해 -60%\n방벽 피격 시 근거리 반격 · 시작 위성 4기", "color": Color("ffcb75"), "hp": 140.0, "speed": 185.0, "dash": 3.35, "orbits": 4, "power": 0.95},
	}
	return ships.get(id, ships.striker).duplicate()

static func sector_info(id: String) -> Dictionary:
	var sectors := {
		"ring": {"id": "ring", "name": "외곽 고리", "description": "고속 우회 편대가 포위 · 스트라이커 화력/설치 포대 유리", "color": Color("62e8d8")},
		"storm": {"id": "storm", "name": "번개 회랑", "description": "전역 교차 번개가 점점 빈번 · 스카우트 기동/돌진 무적 유리", "color": Color("a798ff")},
		"forge": {"id": "forge", "name": "잔해 용광로", "description": "시간에 따라 붕괴 가속 · 배스천 선체/축적 방벽 유리", "color": Color("ff9475")},
	}
	return sectors.get(id, sectors.ring).duplicate()

static func evolution_info(id: String) -> Dictionary:
	var evolutions := {
		"superorbit": {"id": "superorbit", "name": "태양 고리", "description": "위성 피해 +60% · 접촉 범위/주기 강화\n숙련: 코어 Lv.3~5마다 위성 피해 +15%", "requirements": {"orbit": 3, "power": 2}, "mastery": "power"},
		"storm": {"id": "storm", "name": "연쇄 폭풍", "description": "번개 연결 +3 · 번개 피해 +40%\n숙련: 번개 Lv.4~5마다 연결 +1 / 주기 -12%", "requirements": {"chain": 3, "rapid": 2}, "mastery": "chain"},
		"salvo": {"id": "salvo", "name": "유성 세례", "description": "유도탄 3발 · 폭발 범위 +25\n숙련: 유도탄 Lv.4~5마다 주기 -12% / 범위 +8", "requirements": {"missile": 3, "dash": 2}, "mastery": "missile"},
		"rail": {"id": "rail", "name": "관통 성창", "description": "자동포가 최대 3기 관통 · 피해 +35%\n숙련: 속사 Lv.4~5마다 관통 +1 / 피해 +15%", "requirements": {"rapid": 3, "power": 3}, "mastery": "rapid"},
		"blizzard": {"id": "blizzard", "name": "절대 영도", "description": "빙결 위성 피해 +40% · 감속 +15%p\n숙련: 빙결 Lv.4~5마다 피해 +15% / 지속 +0.3초", "requirements": {"frost": 3, "orbit_range": 2}, "mastery": "frost"},
		"nova": {"id": "nova", "name": "중력 신성", "description": "충격파 범위 +55 · 피해 ×2 · 적탄 제거\n숙련: 충격파 Lv.4~5마다 주기 -12% / 범위 +15", "requirements": {"pulse": 3, "magnet": 2}, "mastery": "pulse"},
		"sentry": {"id": "sentry", "name": "고정 성좌", "description": "스트라이커 · 5분 이후 설치 포대 3기\n5초마다 설치 / 14초 유지 · 조준 증폭 공유", "requirements": {"rapid": 4, "power": 3}, "mastery": "rapid", "ship": "striker", "after": 300.0},
		"wake": {"id": "wake", "name": "섬광 항적", "description": "스카우트 · 5분 이후 돌진 경로에 잔상\n2.4초간 반복 타격 · 돌진 강화로 피해 증가", "requirements": {"dash": 3, "speed": 3}, "mastery": "dash", "ship": "scout", "after": 300.0},
		"citadel": {"id": "citadel", "name": "반격 성채", "description": "배스천 · 5분 이후 방벽 반격 범위 +70\n반격 피해 ×2 · 근거리 적탄 제거", "requirements": {"pulse": 3, "vitality": 3}, "mastery": "pulse", "ship": "bastion", "after": 300.0},
		"ellipse": {"id": "ellipse", "name": "혜성 타원궤도", "description": "4분 이후 · 장축 1.8배/단축 0.7배 위성\n회전하는 타원으로 넓게 요격 · 위성 피해 +20%", "requirements": {"orbit_range": 3, "orbit": 3}, "mastery": "orbit", "after": 240.0},
		"hatchet": {"id": "hatchet", "name": "귀환 도끼", "description": "4분 이후 · 발사 후 돌아오는 도끼를 회수\n받을 때마다 피해 +15% / 최대8회 · 놓치면 초기화", "requirements": {"blade": 3, "magnet": 2}, "mastery": "power", "after": 240.0},
		"minefield": {"id": "minefield", "name": "성운 지뢰밭", "description": "4분 이후 · 2초마다 지뢰 설치 / 최대8개\n0.6초 후 접근 감지 · 145px 폭발 · 18초 수명", "requirements": {"missile": 3, "pulse": 2}, "mastery": "missile", "after": 240.0},
	}
	return evolutions.get(id, {}).duplicate(true)
