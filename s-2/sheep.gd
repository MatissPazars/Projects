extends CharacterBody2D

var astar_ref : AStarGrid2D
var move_speed : float = 100.0
var move_interval : float = 2.0 # The 'gene' - how often to move
var timer : float = 0.0
var path : Array[Vector2i] = []

func _physics_process(delta: float) -> void:
    timer += delta
    if timer >= move_interval:
        timer = 0
        
    
    # Movement logic here: follow the 'path' array
    if path.size() > 0:
        # Move toward path[0] and remove it when reached
        pass
