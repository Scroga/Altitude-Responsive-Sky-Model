extends Node2D

func _ready() -> void:
	test_plugin_functionality()

func test_plugin_functionality()->void:
	var my_class:Test = Test.new()
	
	my_class.print_hello()
	
	print(my_class.text)
	my_class.text = "New Text"
	print(my_class.text)
	
	
	
	
	
