extends Node2D


@export var Map_size : Vector2i
var waterNoise = FastNoiseLite.new()
var water2Noise = FastNoiseLite.new()
var tempNoise = FastNoiseLite.new()
var terrainNoise = FastNoiseLite.new()


@export var seed : int = -1
@export_range(-1,1) var water_level : float = 0


# Preload the scene for performance
var sheepScene = preload("res://sheep.tscn")


var astar = AStarGrid2D.new()
        




func _ready():

    astar.size = Map_size
    astar.cell_size = Vector2(16, 16)
    astar.offset = Vector2(8, 8)      # Center of tile
    astar.update()

    if seed == -1:
        waterNoise.seed = randi()
        water2Noise.seed = randi()
        tempNoise.seed = randi()
        terrainNoise.seed = randi()
    else:
        waterNoise.seed = seed
        water2Noise.seed = seed
        tempNoise.seed = seed
        terrainNoise.seed = seed
    
    waterNoise.frequency = 0.0005
    
    
    water2Noise.frequency = 0.025
    
    
    tempNoise.frequency = 0.001
    
    
    terrainNoise.frequency = 0.005
    
    for x in range(0,Map_size.x):
        for y in range(0,Map_size.y):
            if x == 0 or y == 0 or x == Map_size.x -1 or y == Map_size.y -1:
                $terrain.set_cell(Vector2i(x,y), 1, Vector2i(0,0))
                continue
            var temp : float = tempNoise.get_noise_2dv(Vector2(x,y))
            var water : float = waterNoise.get_noise_2dv(Vector2(x,y)) - water_level
            var ter : float = terrainNoise.get_noise_2dv(Vector2(x,y))
            var water2 : float = waterNoise.get_noise_2dv(Vector2(x,y))
            
            var tile : Vector2i = Vector2i(x,y)
            
            if water < 0:
                astar.set_point_solid(tile)
                if water2 + water <= -0.5:
                    $terrain.set_cell(tile, 1, Vector2i(0,4))
                elif water2 + water<= -0.25:
                    $terrain.set_cell(tile, 1, Vector2i(4,3))
                elif water2 + water <= -0.15:
                    $terrain.set_cell(tile, 1, Vector2i(3,3))
                else:
                    $terrain.set_cell(tile, 1, Vector2i(2,3))
            
            
            elif water < 0.05 and ter <= 0:
                $terrain.set_cell(tile, 1, Vector2i(1, 2))
            elif water >= 0.5 and temp >= 0.5:
                $terrain.set_cell(tile, 1, Vector2i(1, 2))
            elif water + temp - ter >= 0.2 and temp >= -0.55 and temp <= 0.5 and temp - water > -0.35:
                $terrain.set_cell(tile, 1, Vector2i(1, 3))
                
            else:
                $terrain.set_cell(tile, 1, Vector2i(4,2))
            

func spawn_npc(spawn_position: Vector2):
    var newSheep = sheepScene.instantiate()
    newSheep.position = spawn_position
    
    newSheep.add_to_group("Sheep")
    
    get_parent().add_child(newSheep)
    
    
func sheep_focus():
    for x in randi_range(-1,1):
        for y in randi_range(-1,1):
            pass
    
    
func _process(_delta: float) -> void:
    if Input.is_action_just_pressed("input"):
        print($terrain.local_to_map(get_global_mouse_position()))
    if Input.is_action_just_pressed("spawn"):
        spawn_npc(get_global_mouse_position())
