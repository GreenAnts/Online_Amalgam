extends AnimatedSprite2D

var type : String

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	autoplay = type
	
func _on_animation_looped() -> void:
	remove_click_anim()
	
func remove_click_anim() -> void:
	Global.clicked_animations.erase(self)
	self.queue_free()
