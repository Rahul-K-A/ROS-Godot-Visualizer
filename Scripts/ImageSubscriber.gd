extends ROSSubscriber

## Variable that references the options bar
var ImageTopicOptions : OptionButton

## Variable that references the box to which image is drawn
var imageTextureBox : TextureRect
 
## Image texture created from image
var iTex : ImageTexture

## New image object
var myImage : Image = Image.new()

## List of valid image messages
const imageMessageTypes : Array = [
	"sensor_msgs/CompressedImage",
	"sensor_msgs/Image"
	]

## Var that stores current selected topic
var currentSelectedTopic : String

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super()
	ImageTopicOptions = $VBoxContainer/ImageTopicOption
	imageTextureBox = $VBoxContainer/ImageTextureBox
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if message_queue.size() != 0:
		var image_msg : Dictionary = message_queue.pop_front()
		# Dont bother parsing if the message isnt from the selected topic
		if currentSelectedTopic != image_msg["topic"]:
			return
		# TODO: Handle different types of images e.g jpgs
		var raw_image_data : PackedByteArray = image_msg["msg"]["data"]
		myImage.load_png_from_buffer(raw_image_data)
		## Create texture from image and add it to the texture box
		iTex = ImageTexture.create_from_image(myImage)
		imageTextureBox.set_texture(iTex)
		
## Once topics are updated, check for new image topics and subscribe
## TODO: Bad way of handling change. Refer to PointcloudSubscriber.gd same func for more information
func _on_topics_updated() -> void:
		var topics_with_type : Dictionary = ROSWebsocket.get_all_available_topics()
		ImageTopicOptions.clear()
		## Add a "None" option if user does not want any image topics
		ImageTopicOptions.add_item("None")
		for topic in topics_with_type:
			if topics_with_type[topic] in imageMessageTypes:
				ImageTopicOptions.add_item(topic)
				subscribe_to_topic(topic)
				print("Subbed to ", topic)

## Called by Websocket
func parse_message(message : Dictionary):
	if(message_queue.size() <= queue_length):
		message_queue.append(message)

## Callback function, that executes once an topic is selected
func _on_image_topic_option_item_selected(index: int) -> void:
	currentSelectedTopic = ImageTopicOptions.get_item_text(index)
	imageTextureBox.set_texture(null)
