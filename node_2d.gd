extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var br = Brake.new()
	br.init_brake(10, 10, 10, 10, 4, 10, 10, 10, 10, 10, 10, 10, 10, 10)
	print("FC: " + str(br.get_fc(10, 20)))
	print("EDBCP: " + str(br.get_edbcp()))
	print("BCP: " + str(br.get_bcp()))
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass 
