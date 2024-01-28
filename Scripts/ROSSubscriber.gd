extends Node

class_name ROSSubscriber

## Theory of operation:
## This is a abstract class containing basic functionality for a ROS Publisher
## For more detailed implentation, create a child class and override all the functions
## DO NOT OVERRIDE the subscribe and unsubscribe functions

var message_queue : Array
var queue_length : int = 50
var is_processing_message : bool = false

## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	## ALWAYS ADD "super()" to all the child class' ready functions
	ROSWebsocket.topics_updated.connect(Callable(self, "_on_topics_updated"))

## Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

## Function to subscribe. Do not override
func subscribe_to_topic(topic_name : String ) -> void:
	ROSWebsocket.subscribe(topic_name, self)
	
## Function to unsubscribe. Do not override
func unsubscribe(topic_name : String) -> void:
	ROSWebsocket.unsubscribe(topic_name, self)

## Parse message function that needs to be overloaded by child classes
func parse_message(message : Dictionary):
	pass

## Callback for topic change. Needs to be overlodaded by child classes
func _on_topics_updated() -> void:
	pass
	
