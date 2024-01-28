extends Node

## A ROS/ROS2 websocket interface node
##
## The aim of the node is to provide an API to publish, subscribe and list all ROS topics

## Note: GDscript does not have access modifiers (public, private, etc). 
## The general way to denote that something is meant to be private is to add a underscore ('_') to the beginning of the member variable/function


## This section contains all global variables used by the script

## Main socket interface
var _socket : WebSocketPeer = WebSocketPeer.new()

## Timer - self explanatory
var _timerNode = Timer.new()

## Global variable which keeps track of state of the socket
var _socketState : int

## Timer countdown value
const _waitTime : float = 1.0

## Contains list of topics and their corresponding datatypes
var availableTopicsList : Dictionary = {}

## Filter for message types, add your message types here if you want it to show up in the application
var allowed_message_types = [
	"sensor_msgs/"
]

## Contains list of nodes subscribed to each topic
var subscribedNodes : Dictionary = {}

## default url constant
const defaultUrl : String = "0.0.0.0:9090"

const defaultInboundBuffSize : int = 100_00_000
## Current host URL
var currentHostUrl : String


## This section contains all the defined signals

## Emitted when new topics arrive
signal topics_updated

## This section contains the 'Private' functions

func _ready() -> void:
	print("Initialising websocket")
	currentHostUrl = defaultUrl
	# Set inbound buffer size to large value (10MB) to be able to hold image data
	_socket.set_inbound_buffer_size(defaultInboundBuffSize)
	# Connect to localhost:9090 by default
	# If connection fails, keep trying while connection succeeds
	_connect_with_attempts(currentHostUrl)
	
	# Set up timer to reload automatically upon expiry and set callbacks to query topics
	_timerNode.wait_time = _waitTime
	_timerNode.autostart = true	
	_timerNode.connect("timeout", Callable(self, "_on_timer_timeout"))
	
	#Attach the timer to current script and start
	add_child(_timerNode)
	_timerNode.start()
	print("Inititalisation done")
	
	
## Main process loop
func _process(delta) -> void:
	var _packet : PackedByteArray
	var _json_string : String
	_socket.poll()
	_socketState = _socket.get_ready_state()
	# Note: match is Godot's version of switch case
	match _socketState:
		WebSocketPeer.STATE_OPEN:
			while _socket.get_available_packet_count():
				_packet = _socket.get_packet()
				_json_string = _packet.get_string_from_utf8()
				_processData(_json_string) 
		WebSocketPeer.STATE_CLOSING:
		# Keep polling to achieve proper close.
			pass
		WebSocketPeer.STATE_CONNECTING:
		# Keep polling till socket is fully open			
			pass
		WebSocketPeer.STATE_CLOSED:
		# Print reason for closing and try and reconnect with host
			print("wtf")
			var code = _socket.get_close_code()
			var reason = _socket.get_close_reason()
			print("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
			_connect_with_attempts(currentHostUrl)
		_:
			print("Unknown state, disregarding...")
			pass

## Attempt to connect to an URL with provided number of attempts
func _connect_with_attempts(url : String , attempts : int = 5 ) -> int:
	var error_code : int = FAILED
	var num_attempts : int = attempts
	while attempts != 0:
		error_code = _socket.connect_to_url(url)
		if error_code == OK:
			return OK
		attempts -= 1
	print("Failed to connect to url %s after %d attempts" % [url, num_attempts])
	return error_code

## Processes and handles all incoming data
func _processData(json_string : String) -> void:
			# Convert json string to godot dictionary
			var parsed_data : Dictionary= JSON.parse_string(json_string)
			match parsed_data["op"]:
				"publish":
					var topic_name : String = parsed_data['topic']
					# Note: ROS Json uses Base64 encoding for byte data, so we need to decode it
					if parsed_data["msg"].has("data"):
						parsed_data["msg"]["data"] = Marshalls.base64_to_raw(parsed_data["msg"]["data"])
					
					# Make each subscriber parse the data 
					for node in subscribedNodes[topic_name]:
						node.parse_message(parsed_data)
			
				"service_response":
					# Print warning for failed service response from host
					if parsed_data["result"] == false:
						push_warning("Service request for %s failed" % parsed_data["service"])
					match parsed_data["service"]:
					# If service response is for topics, update the list of topics	
						"rosapi/topics":
							_updateTopicList(parsed_data["values"])
				# Godot allows the "default" values to be stored in a variable
				var data_type:
					push_warning("Recieved message for %s from ROS" % data_type)

## Sends service request to query all topics advertised by the host
func _query_all_topics() -> void:
	var opCode : Dictionary = { "op": "call_service", "service": "rosapi/topics"}
	var opString : String = JSON.stringify(opCode)
	_socket.send_text(opString)

## Updates list of topics if host sends topics
func _updateTopicList(recieved_topics : Dictionary) -> void:
	var num_topics : int = len(recieved_topics["topics"])
	var topics : Array = recieved_topics["topics"]
	var types : Array =  recieved_topics["types"]
	
	# Filter the list of obtained topics to remove custom messages
	var filtered_topics : Array
	var filtered_types : Array
	var new_num_topics : int = 0
	for i in range(num_topics):
		var topic_found : bool = false
		for allowed_message_type in allowed_message_types:
			if types[i].contains(allowed_message_type):
				topic_found = true
				break
		if topic_found:
			filtered_topics.push_back(topics[i])
			filtered_types.push_back(types[i])
			new_num_topics +=1
	topics = filtered_topics
	types = filtered_types
	num_topics = new_num_topics
	
	# Only update topics if theres a change compared to existing topics
	if availableTopicsList.keys() == topics:
		return
	
	# If there is change, clear current topic list and fill it again
	availableTopicsList.clear()
	for i in range(num_topics):
		availableTopicsList[topics[i]] = types[i]
	print("List of topics has been updated")
	emit_signal("topics_updated")	
	return
	
## Registers node as a subscriber so that websocket can send data
func _registerNode(topic_name : String, node_to_register : ROSSubscriber):
	if subscribedNodes.has(topic_name):
		if subscribedNodes[topic_name].has(Node):
			pass
		else:
			subscribedNodes[topic_name].append(node_to_register)
	else:
		subscribedNodes[topic_name] = [node_to_register]

## Callback function for timer
func _on_timer_timeout() -> void:
	if _socketState == WebSocketPeer.STATE_OPEN:
		_query_all_topics()
	return

## This section contains the "Public" functions

## Subscribes to a topic
func subscribe( topic_name : String , node : ROSSubscriber) -> bool:
	if _socketState != WebSocketPeer.STATE_OPEN:
		print("Socket is not open yet")
		return false
	
	_registerNode(topic_name, node)
	# Subscription opcode should contain the topic and the message type of the topic to avoid ambiguity
	var opcode : Dictionary = {"op": "subscribe", "topic" : str(topic_name)}
	var opString : String = JSON.stringify(opcode)
	_socket.send_text(opString)
	
	return true

## Stop subscribing to a node	
func unsubscribe(topic_name : String , node_to_unregister : ROSSubscriber):
	# Check if node exists in list of subscribers
	var node_index : int = subscribedNodes[topic_name].find(node_to_unregister) 
	if node_index != -1:
		subscribedNodes[topic_name].remove_at(node_index)
		if len(subscribedNodes[topic_name] == 0):
			var opcode : Dictionary = {"op": "subscribe", "topic" : str(topic_name), "type" : str(availableTopicsList[topic_name]) }
			var opString : String = JSON.stringify(opcode)
			if _socketState == OK:
				_socket.send_text(opString)
			else:
				push_error("Node was de-registered, but topic was not unsubscribed")
	else:
		push_warning("Node %s not found in list of subscribers for the given topic %s" % [self.name, topic_name])
		
		

## Public function that can be called from UI
func connect_to_host_url(url : String) -> void:
	currentHostUrl = url
	if _socketState == WebSocketPeer.STATE_OPEN or _socketState == WebSocketPeer.STATE_CONNECTING:
		_socket.close(1000,"No longer needed")
	while _socketState != WebSocketPeer.STATE_CLOSED:
		_socketState = _socket.get_ready_state()
		continue
	_connect_with_attempts(currentHostUrl)
		
## Returns all available topics with their types
func get_all_available_topics() -> Dictionary:
	return availableTopicsList

## Returns state of the socket
func get_socket_state() -> int:
	return _socketState
	
				
