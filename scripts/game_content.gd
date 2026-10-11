class_name GameContent
extends RefCounted

const SHIP_IDS := ["striker", "scout", "bastion"]
const SECTOR_IDS := ["ring", "storm", "forge"]
const EVOLUTION_IDS := ["superorbit", "storm", "salvo"]
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
		"striker": {"id": "striker", "name": "스트라이커", "description": "균형형 · 체력 100 · 기본 화력 100%", "color": Color("62e8d8"), "hp": 100.0, "speed": 218.0, "dash": 3.0, "orbits": 3, "power": 1.0},
		"scout": {"id": "scout", "name": "스카우트", "description": "기동형 · 체력 80 · 빠른 이동과 대시 · 화력 90%", "color": Color("89baff"), "hp": 80.0, "speed": 255.0, "dash": 2.45, "orbits": 3, "power": 0.9},
		"bastion": {"id": "bastion", "name": "배스천", "description": "방어형 · 체력 140 · 시작 위성 4개 · 느린 이동 · 화력 95%", "color": Color("ffcb75"), "hp": 140.0, "speed": 185.0, "dash": 3.35, "orbits": 4, "power": 0.95},
	}
	return ships.get(id, ships.striker).duplicate()

static func sector_info(id: String) -> Dictionary:
	var sectors := {
		"ring": {"id": "ring", "name": "외곽 고리", "description": "지형 위험 없이 전투에 집중 · 보스의 원형 탄막", "color": Color("62e8d8")},
		"storm": {"id": "storm", "name": "번개 회랑", "description": "예고된 전기 통로를 회피 · 보스의 부채꼴 탄막", "color": Color("a798ff")},
		"forge": {"id": "forge", "name": "잔해 용광로", "description": "노란 예고 원이 폭발하기 전에 이동 · 보스의 포격", "color": Color("ff9475")},
	}
	return sectors.get(id, sectors.ring).duplicate()

static func evolution_info(id: String) -> Dictionary:
	var evolutions := {
		"superorbit": {"id": "superorbit", "name": "태양 고리", "description": "위성 피해 +60% · 접촉 범위와 타격 속도 증가", "requirements": {"orbit": 3, "power": 2}},
		"storm": {"id": "storm", "name": "연쇄 폭풍", "description": "번개 연결 +3 · 번개 피해 +40%", "requirements": {"chain": 3, "rapid": 2}},
		"salvo": {"id": "salvo", "name": "유성 세례", "description": "유도탄 3발 동시 발사 · 폭발 범위 +25", "requirements": {"missile": 3, "dash": 2}},
	}
	return evolutions.get(id, {}).duplicate(true)
