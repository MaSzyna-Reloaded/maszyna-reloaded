extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    var br = $MaszynaTBrake
    #br.init_brake(10, 10, 10, 10, 4, 10, 10, 10, 10, 10, 10, 10, 10, 10)
    print("FC: " + str(br.GetFC(10, 20)))
    print("EDBCP: " + str(br.GetEDBCP()))
    print("BCP: " + str(br.GetBCP()))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass
