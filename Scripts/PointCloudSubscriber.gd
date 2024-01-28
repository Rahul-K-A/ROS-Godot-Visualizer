extends ROSSubscriber

## Theory of operation: PC Subscriber subscribes to point clouds
## It recieves point cloud data from the Websocket and puts it in a queue
## For every tick, the top of the queue is processed
## The XYZ coords are obtained and are converted to Godot coordinates


## Dictionary to lookup which handler handles which topic
var handlerDict : Dictionary 

## Current handler being manipulated
var currentTopicHandler : MultiMeshInstance3D

## Current material (aka sphere color) to be applied to each point
var currentMaterial : Material

## Default point size
const defaultPointSize : float = 1.0

var multiMesh : MultiMesh = MultiMesh.new()
var defaultMesh : PointMesh = PointMesh.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# If message queue is not empty, process stuff
	if message_queue.size() != 0:
		var t1 : int = Time.get_ticks_usec()
		var current_message : Dictionary = message_queue.pop_front()
		# Set the current topic handler and material by looking up the topic name
		var topic_name : String = current_message["topic"]
		currentTopicHandler = handlerDict[topic_name][0]
		currentMaterial = handlerDict[topic_name][1]
		
		# Extract PC data from the message dictionary
		var raw_data : PackedByteArray =  current_message["msg"]["data"]
		var num_points : int = current_message["msg"]["width"]
		var base_offset : int = 0
		var step_size : int = current_message["msg"]["point_step"]
		var x : float
		var y : float
		var z : float
		currentTopicHandler.multimesh.visible_instance_count = num_points
		currentTopicHandler.multimesh.instance_count = num_points
		# For each extracted point, create sphere and add it to the scene
		for point in range(num_points):
			x = raw_data.decode_float(base_offset + 0)
			y = raw_data.decode_float(base_offset + 4)
			z = raw_data.decode_float(base_offset + 8)
			# ROS to GODOT coversion:
			# x in ROS = x in Godot
			# y in ROS = -z in Godot
			# z in ROS = y in Godot
			
			var godot_coordinate : Vector3 = Vector3(x,z,-y)
			
			# Instantiate point mesh for each point in PC. (Much better than CSGSpheres for performance)
			# TODO: Mesh instances are significantly better than using CSGSphere, but need to see how many points the application can take before it crashes
			currentTopicHandler.multimesh.set_instance_transform(point, Transform3D(Basis(),godot_coordinate))
			# Update offset so that next set of points can be parsed
			base_offset += step_size
		var t2 : int = Time.get_ticks_usec()
		print("PC process time = %d millisecs" % (t2-t1))

## Called by the websocket
func parse_message(message : Dictionary):
	if(message_queue.size() <= queue_length):
		message_queue.append(message)
	else:
		push_warning("Message queue for %s is full. Dropping messages" % self.name)

## Callback once Websocket sees that topics have changed
## TODO: This is bad way of handling topic change. We dont need to clear the entire list of topics,
## only check for changes compared to current list of Pointcloud topics
func _on_topics_updated() -> void:
	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	var topics_with_type : Dictionary = ROSWebsocket.get_all_available_topics()
	## Clear existing lookup table and free all handlers
	for topic in handlerDict:
		var handlerNode : Node = handlerDict[topic][0]
		var handlerMaterial : StandardMaterial3D = handlerDict[topic][1]
		remove_child(handlerNode)
		handlerNode.queue_free()
	handlerDict.clear()
	print(topics_with_type)
	## Create new handlers and materials add them to lookup table
	for topic in topics_with_type:
		if topics_with_type[topic] == "sensor_msgs/PointCloud2":
			subscribe_to_topic(topic)
			var newNode : MultiMeshInstance3D = MultiMeshInstance3D.new()
			var newMesh : MultiMesh = MultiMesh.new()
			newMesh.use_colors = true
			newMesh.transform_format = MultiMesh.TRANSFORM_3D
			newMesh.mesh = defaultMesh
			newNode.multimesh = newMesh
			var newMaterial : StandardMaterial3D = StandardMaterial3D.new()
			## NOTE: use_point size HAS TO BE ENABLED for point size to be manipulated in both scripts and shaders
			newMaterial.use_point_size = true
			newMaterial.point_size = defaultPointSize
			# Assign random color to each topic
			# TODO: Add color picker for each topic
			newMaterial.albedo_color = Color(rng.randf_range(0.0, 1.0), rng.randf_range(0.0, 1.0), rng.randf_range(0.0, 1.0), 1)
			newMaterial.set_shading_mode(0)
			newNode.set_material_override(newMaterial)
			add_child(newNode)
			handlerDict[topic] = [newNode, newMaterial]
