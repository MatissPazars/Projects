extends Node2D

# an implementation of John Conway's Game of life in Godot, By Matīss Pazars. June 2026



@export var live_cell_atlas : Vector2i = Vector2i(1, 0)
@onready var tile_map = $cells

var live_cells : Dictionary = {}

func _process(_delta: float) -> void:

    if Input.is_action_just_pressed("click"):
        var mouse_pos = tile_map.local_to_map(get_global_mouse_position())
        if live_cells.has(mouse_pos):
            live_cells.erase(mouse_pos)
            tile_map.erase_cell(mouse_pos)
        else:
            live_cells[mouse_pos] = true
            tile_map.set_cell(mouse_pos, 0, live_cell_atlas)

    if Input.is_action_just_pressed("generation"):
        calculate_next_generation()

func calculate_next_generation() -> void:
    var neighbor_counts : Dictionary = {}

    for cell in live_cells:
        for x in range(-1, 2):
            for y in range(-1, 2):
                if x == 0 and y == 0: continue
                
                var neighbor = cell + Vector2i(x, y)
                neighbor_counts[neighbor] = neighbor_counts.get(neighbor, 0) + 1

    var next_generation : Dictionary = {}
    
    for cell in neighbor_counts:
        var count = neighbor_counts[cell]
        var is_alive = live_cells.has(cell)
        
        if count == 3 or (is_alive and count == 2):
            next_generation[cell] = true

    # 3. Apply changes to the board
    live_cells = next_generation
    tile_map.clear()
    for cell in live_cells:
        tile_map.set_cell(cell, 0, live_cell_atlas)
