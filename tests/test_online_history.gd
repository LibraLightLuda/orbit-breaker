extends SceneTree

func _init() -> void:
	var path := "user://online-history-test-%d.json" % OS.get_process_id()
	var store := SaveStore.new()
	store.load_data(path)
	var value := {"id": "a".repeat(32), "score": 12, "ticks": 60, "mode": "coop", "difficulty": "normal", "sector": "ring", "nickname": "익명", "finished_at": "2026-10-16T00:00:00Z"}
	assert(store.record_online(value))
	assert(store.record_online(value))
	assert(store.data.online_records.size() == 1)
	assert(store.data.runs == 0 and store.data.best_score == 0)
	var reloaded := SaveStore.new()
	reloaded.load_data(path)
	assert(reloaded.data.online_records[0].id == value.id)
	assert(reloaded.data.online_records[0].nickname == "익명")
	assert(not reloaded.record_online({"id": "../../invalid"}))
	assert(reloaded.data.online_records.size() == 1)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): assert(DirAccess.remove_absolute(path + suffix) == OK)
	print("ONLINE HISTORY SELF-CHECK: 8 assertions passed")
	quit()
