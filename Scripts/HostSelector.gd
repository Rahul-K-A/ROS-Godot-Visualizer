extends Button

## All this script does is make the host select menu available when you press the "+" at the top right
## Note: The callbacks are configured using UI, so open the script with Godot to make full sense of it
var  lineEdit : Node
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$HostSelectPanelContainer.visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
## Called once the "+" is pressed. Makes the menu visible
func _on_pressed() -> void:
	$HostSelectPanelContainer.visible = not $HostSelectPanelContainer.visible

## Called oncce the "connect" button is pressed. connects to whatever URL is written in the text box
func _on_host_select_button_pressed() -> void:
	ROSWebsocket.connect_to_host_url($HostSelectPanelContainer/HostSelectorHBox/HostURLText.text)
