extends RefCounted

const PROTOCOL := 2
const API_URL := "https://orbit-breaker-records.chrcra89.chatgpt.site"

static func service_url() -> String:
	if OS.has_feature("web"):
		return web_service_url(str(JavaScriptBridge.eval("location.origin")), str(JavaScriptBridge.eval("location.hostname")))
	var configured := OS.get_environment("ORBIT_API_URL").strip_edges()
	return configured.trim_suffix("/") if not configured.is_empty() else API_URL

static func web_service_url(origin: String, hostname: String) -> String:
	return API_URL if hostname.ends_with(".github.io") else origin
