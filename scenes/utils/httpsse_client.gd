class_name HTTPSSEClient extends Node

signal new_sse_event(event: Dictionary)

var http_client := HTTPClient.new()

var url_after_domain: String
var is_requested := false
var user_headers: PackedStringArray
var user_data: String
var domain_regex: RegEx


func _init():
	# Regex that separates domain from everything after in an url like https://example.com/sse
	domain_regex = RegEx.create_from_string("(\\w+://.+?)(/.*)")


func get_events_from(url: String, headers: PackedStringArray, data : String, 
						port: int = -1, tls_options: TLSOptions = null) -> Error:
	is_requested = false
	var regex = domain_regex.search(url)
	if regex:
		var domain = regex.strings[1]
		url_after_domain = regex.strings[2]
		user_headers = headers
		user_data = data
		return http_client.connect_to_host(domain, port, tls_options)
	else:
		return ERR_INVALID_PARAMETER


func close_open_connection() -> void:
	is_requested = false
	if http_client:
		http_client.close()


func _process(_delta):
	http_client.poll()
	var http_client_status = http_client.get_status()
	match http_client_status:
		HTTPClient.STATUS_CONNECTED:
			if not is_requested:
				var headers = user_headers
				headers.append("Accept: text/event-stream")
				var _err = http_client.request_raw(HTTPClient.METHOD_POST, url_after_domain, 
												headers, user_data.to_utf8_buffer())
				is_requested = true
		HTTPClient.STATUS_BODY:
			var chunk = http_client.read_response_body_chunk()
			# TODO: merge multiple chunks
			var body := chunk.get_string_from_utf8()
			if body:
				parse_message(body)


## Parse message as described in the specification
## https://html.spec.whatwg.org/multipage/server-sent-events.html#server-sent-events
func parse_message(body : String) -> void:
	var current_event := {'id': '', 'event': '', 'data': ''}
	var event_dispatched := false
	for line in body.split("\n"):
		if line == '':
			if current_event != {'id': '', 'event': '', 'data': ''}:
				new_sse_event.emit(current_event.duplicate())
				event_dispatched = true
			current_event = {'id': '', 'event': '', 'data': ''}
			continue
		if line.left(1) == ':':
			continue # skip because it's a comment
		var idx = line.find(':')
		var field = ''
		var value = ''
		if idx != -1:
			field = line.substr(0, idx)
			value = line.substr(idx+1)
			value = value.trim_prefix(' ')
		else:
			field = line
		match field:
			"event" : current_event['event'] = value
			"data" : current_event['data'] += value + "\n"
			"id" : current_event['id'] = value
			# TODO: parse retry field as described in the specification
	if not event_dispatched:
		current_event = {'id': '', 'event': '', 'data': ''}
		current_event['event'] = "ERROR"
		current_event['data'] = "Found no server-sent event in " + body
		new_sse_event.emit(current_event)
		close_open_connection()


func _exit_tree():
	close_open_connection()
