@tool
extends Node
class_name BetterAuth

@export var base_url: String = "http://localhost:3000/api/auth"
var session_token: String = ""

signal login_success(user: Dictionary)
signal login_failed(error: Dictionary)
signal signup_success(user: Dictionary)
signal signup_failed(error: Dictionary)

func _ready() -> void:
	if Engine.is_editor_hint():
		# Skip runtime logic in the editor
		return

	# Ensure all nodes are fully in scene tree
	await get_tree().process_frame

	# Add to group for tracking multiple instances
	add_to_group("BetterAuth")

	# Auto-connect default handlers
	connect("signup_success", Callable(self, "_default_signup_success"))
	connect("signup_failed", Callable(self, "_default_signup_failed"))
	connect("login_success", Callable(self, "_default_login_success"))
	connect("login_failed", Callable(self, "_default_login_failed"))

	# Wait one frame to ensure all nodes are in the scene tree
	await get_tree().process_frame

	# Runtime check for multiple instances
	var count := get_tree().get_nodes_in_group("BetterAuth").size()
	if count > 1:
		var msg := "ERROR: Multiple BetterAuth nodes detected! Only one is allowed per scene."
		# Push error to console
		push_error(msg)
		printerr(msg)
		# Stop the game immediately
		get_tree().quit()

# --- Signup ---
func signup(email: String, password: String) -> Dictionary:
	var response: Dictionary = await _http_post("/signup", {"email": email, "password": password})
	if response.has("user"):
		emit_signal("signup_success", response["user"])
	else:
		emit_signal("signup_failed", {"error": response.get("error", "Unknown signup error")})
	return response

# --- Login ---
func login(email: String, password: String) -> Dictionary:
	var response: Dictionary = await _http_post("/login", {"email": email, "password": password})
	if response.has("sessionToken"):
		session_token = response["sessionToken"]
		emit_signal("login_success", response)
	else:
		emit_signal("login_failed", {"error": response.get("error", "Unknown login error")})
	return response

# --- Get Session ---
func get_session() -> Dictionary:
	if session_token.is_empty():
		return {"error": "No session"}
	return await _http_get("/session")

# --- Internal HTTP helpers ---
func _http_post(endpoint: String, data: Dictionary) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)

	var headers := ["Content-Type: application/json"]
	if session_token != "":
		headers.append("Authorization: Bearer %s" % session_token)

	var err := http.request(base_url + endpoint, headers, HTTPClient.METHOD_POST, JSON.stringify(data))
	if err != OK:
		http.queue_free()
		return {"error": "Request failed to start"}

	var result: Array = await http.request_completed
	http.queue_free()

	if result.size() >= 4 and typeof(result[3]) == TYPE_STRING and result[3] != "":
		var parsed := JSON.parse_string(result[3])
		if parsed.error == OK and typeof(parsed.result) == TYPE_DICTIONARY:
			return parsed.result
		else:
			return {"error": "Invalid JSON response"}
	return {"error": "Empty response"}

func _http_get(endpoint: String) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)

	var headers := []
	if session_token != "":
		headers.append("Authorization: Bearer %s" % session_token)

	var err := http.request(base_url + endpoint, headers, HTTPClient.METHOD_GET)
	if err != OK:
		http.queue_free()
		return {"error": "Request failed to start"}

	var result: Array = await http.request_completed
	http.queue_free()

	if result.size() >= 4 and typeof(result[3]) == TYPE_STRING and result[3] != "":
		var parsed := JSON.parse_string(result[3])
		if parsed.error == OK and typeof(parsed.result) == TYPE_DICTIONARY:
			return parsed.result
		else:
			return {"error": "Invalid JSON response"}
	return {"error": "Empty response"}

# --- Default signal handlers ---
func _default_signup_success(user: Dictionary) -> void:
	print("[%s] Signup succeeded:" % name, user)

func _default_signup_failed(error: Dictionary) -> void:
	print("[%s] Signup failed:" % name, error)

func _default_login_success(data: Dictionary) -> void:
	print("[%s] Login succeeded:" % name, data)

func _default_login_failed(error: Dictionary) -> void:
	print("[%s] Login failed:" % name, error)
