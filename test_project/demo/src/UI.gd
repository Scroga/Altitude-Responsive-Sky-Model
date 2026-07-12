extends Control


var player: Node
var visible_mode: int = 1

const SCREENSHOT_DIR := "res://screenshots/"

func _init() -> void:
	RenderingServer.set_debug_generate_wireframes(true)


func _process(_delta) -> void:
	$Label.text = "FPS: %d\n" % Engine.get_frames_per_second()
	if(visible_mode == 1):
		$Label.text += "Move Speed: %.1f\n" % player.MOVE_SPEED if player else ""
		$Label.text += "Position: %.1v\n" % player.global_position if player else ""
		$Label.text += """
			Player
			Move: WASDEQ,Space,Mouse
			Move speed: Wheel,+/-,Shift
			Camera View: V
			Gravity toggle: G
			

			Window
			Screenshot: F7
			Quit: F8
			UI toggle: F9
			Render mode: F10
			Full screen: F11
			Mouse toggle: Escape / F12
			"""


func _unhandled_key_input(p_event: InputEvent) -> void:
	if p_event is InputEventKey and p_event.pressed:
		match p_event.keycode:
			KEY_F7:
				take_screenshot()
			KEY_F8:
				get_tree().quit()
			KEY_F9:
				visible_mode = (visible_mode + 1 ) % 3
				$Label/Panel.visible = (visible_mode == 1)
				visible = visible_mode > 0
			KEY_F10:
				var vp = get_viewport()
				vp.debug_draw = (vp.debug_draw + 1 ) % 6
				get_viewport().set_input_as_handled()
			KEY_F11:
				toggle_fullscreen()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE, KEY_F12:
				if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
					Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				else:
					Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				get_viewport().set_input_as_handled()
		
		
func toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN or \
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2(1280, 720))
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func take_screenshot() -> void:
	await RenderingServer.frame_post_draw

	var screenshot_directory := SCREENSHOT_DIR
	DirAccess.make_dir_recursive_absolute(screenshot_directory)

	var image := get_viewport().get_texture().get_image()

	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var filename := "screenshot_%s.png" % timestamp
	var path := screenshot_directory.path_join(filename)

	var error := image.save_png(path)

	if error == OK:
		print("Screenshot saved to: ", ProjectSettings.globalize_path(path))
	else:
		push_error("Failed to save screenshot. Error: %s" % error)
