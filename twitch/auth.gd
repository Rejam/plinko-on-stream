class_name TwitchAuth extends Node
## OAuth login flow ONLY: opens the browser, runs the local redirect
## server, captures the access token, fetches the user's id/login, then
## announces the result and goes quiet.

signal login_completed(access_token: String, user_id: String, user_login: String)
signal login_failed

const LOGIN_TIMEOUT := 300.0
const HELIX_USERS_URL := "https://api.twitch.tv/helix/users"
const DONE_PAGE := "<html><body>Login complete! You can close this tab.</body></html>"
## Twitch returns the token in the URL fragment, which never reaches the
## server. This page reads the fragment and sends it back as a query param.
const FORWARD_PAGE := """<html><body><script>
var h = window.location.hash.substring(1);
var t = new URLSearchParams(h).get('access_token');
if (t) {
	fetch('/callback?token=' + encodeURIComponent(t))
		.then(function () { document.body.innerText = 'Login complete!'; });
}
</script></body></html>"""

var _client_id: String = ""
var _redirect_port: int = 0

var _server := TCPServer.new()
var _pending_client: StreamPeerTCP = null
var _recv_buffer := PackedByteArray()
var _access_token: String = ""

@onready var _login_timeout := _make_login_timer()

func start_login(client_id: String, redirect_port: int, scopes: Array) -> void:
	_client_id = client_id
	_redirect_port = redirect_port

	if _server.listen(_redirect_port, "127.0.0.1") != OK:
		push_error("TwitchAuth: could not listen on port %d (already in use?)" % _redirect_port)
		return

	OS.shell_open(_authorize_url(scopes))
	_login_timeout.start()

func _authorize_url(scopes: Array) -> String:
	const BASE := "https://id.twitch.tv/oauth2/authorize"
	var redirect_uri := "http://localhost:%d/callback" % _redirect_port
	return "%s?response_type=token&client_id=%s&redirect_uri=%s&scope=%s" % [
		BASE, _client_id, redirect_uri.uri_encode(), "+".join(scopes)
	]

func _process(_delta: float) -> void:
	_poll_oauth_server()

func _poll_oauth_server() -> void:
	_accept_pending_client()
	_read_pending_client()

func _accept_pending_client() -> void:
	if _pending_client: return
	if _server.is_listening() and _server.is_connection_available():
		_pending_client = _server.take_connection()
		
func _read_pending_client() -> void:
	if not _pending_client: return

	_pending_client.poll()
	if _pending_client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		_drop_pending_client()
		return

	var available := _pending_client.get_available_bytes()
	if available == 0: return

	_recv_buffer.append_array(_pending_client.get_data(available)[1])
	var text := _recv_buffer.get_string_from_utf8()
	if text.contains("\r\n\r\n"):
		_handle_http_request(text)

func _drop_pending_client() -> void:
	_pending_client = null
	_recv_buffer.clear()
	
func _handle_http_request(text: String) -> void:
	var path := _request_path(text)
	if not path.begins_with("/callback"): return

	if not path.contains("token="):
		_respond_and_close(FORWARD_PAGE)
		return

	_access_token = _token_from(path)
	_respond_and_close(DONE_PAGE)
	_fetch_user_info()

func _request_path(text: String) -> String:
	var parts := text.split("\n")[0].split(" ")
	return parts[1] if parts.size() > 1 else ""
	
func _token_from(path: String) -> String:
	for pair in path.get_slice("?", 1).split("&"):
		var kv := pair.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "token":
			return kv[1].uri_decode()
	return ""
		
func _respond_and_close(html: String) -> void:
	if not _pending_client: return

	var body := html.to_utf8_buffer()
	var response := "\r\n".join([
		"HTTP/1.1 200 OK",
		"Content-Type: text/html",
		"Content-Length: %d" % body.size(),
		"Connection: close",
		"",
		"",
	]).to_utf8_buffer()
	response.append_array(body)

	_pending_client.put_data(response)
	_pending_client.disconnect_from_host()
	_drop_pending_client()

func _fetch_user_info() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_result, code, _headers, body):
			http.queue_free()
			_on_user_info(code, body)
	)
	http.request(HELIX_USERS_URL, [
		"Authorization: Bearer %s" % _access_token,
		"Client-Id: %s" % _client_id,
	])

func _on_user_info(code: int, body: PackedByteArray) -> void:
	if code != 200:
		_fail("user info request failed with code %d" % code)
		return

	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null or not json.has("data") or json["data"].is_empty():
		_fail("user info response could not be read")
		return

	_stop_login()
	login_completed.emit(_access_token, json["data"][0]["id"], json["data"][0]["login"])

func _fail(reason: String) -> void:
	push_error("TwitchAuth: " + reason)
	_stop_login()
	login_failed.emit()

func _stop_login() -> void:
	_server.stop()
	_drop_pending_client()
	if _login_timeout:
		_login_timeout.stop()
		
func _make_login_timer() -> Timer:
	var timer := Timer.new()
	timer.wait_time = LOGIN_TIMEOUT
	timer.one_shot = true
	timer.timeout.connect(_on_login_timeout)
	add_child(timer)
	return timer

func _on_login_timeout() -> void:
	_fail("login timed out")
