extends Node2D

#region Setup & Properties

@export var map_size : Vector2i = Vector2i(100, 100)
@export_range(0.1, 10) var timer : float = 1

# Relative spreading parameters & Weather / Event multipliers
@export_range(0.01, 1.0) var growth_percentage : float = 0.05
@export_range(0.0, 5.0) var weather_growth_multiplier : float = 1.0
@export_range(0.01, 1.0) var spread_threshold : float = 1.0

var astar : AStarGrid2D = AStarGrid2D.new()
var sheep = preload("res://Sheep.tscn")
@onready var map = $map
var tile_size : int = 10

var grass : PackedInt64Array
var grass_delta : PackedInt64Array
var sheepCount : PackedInt64Array

var time : int = 0

# Active list of grass tiles that have at least 1 free neighbor
var freeGrass : Array[Vector2i] = []
var freeGrassSet : Dictionary = {} 
var freeGrassIndex : Dictionary = {}

var grass_count : int = 0

# Grass Atlas Stages (Zero-overhead TileMap stage storage)
const STAGE_SPROUT : Vector2i = Vector2i(0, 3) # Stage 1 (+5 energy)
const STAGE_MID    : Vector2i = Vector2i(4, 2) # Stage 2 (+15 energy)
const STAGE_BEST   : Vector2i = Vector2i(1, 3) # Stage 3 (+30 energy, spreads seeds)

var SURROUNDING_OFFSETS : Array[Vector2i] = [
    Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
    Vector2i(-1,  0),                  Vector2i(1,  0),
    Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1)
]

# Inspection selection state
var selected_tile: Vector2i = Vector2i(-1, -1)
var selected_sheep: Node2D = null

#endregion

#region Lifecycle & Input

func _ready() -> void:
    astar.region = Rect2i(0, 0, map_size.x + 1, map_size.y + 1)
    astar.cell_size = Vector2i(10, 10)
    astar.update()
    
    if map_size.x < 10: map_size.x = 10
    if map_size.y < 10: map_size.y = 10
            
    $Timer.wait_time = timer
    
    # Build boundary walls
    for i in range(map_size.x + 1):
        map.set_cell(Vector2i(i, 0), 0, Vector2i(0, 0))
        map.set_cell(Vector2i(i, map_size.y), 0, Vector2i(0, 0))
        astar.set_point_solid(Vector2i(i, 0), true)
        astar.set_point_solid(Vector2i(i, map_size.y), true)
        
    for i in range(map_size.y + 1):
        map.set_cell(Vector2i(0, i), 0, Vector2i(0, 0))
        map.set_cell(Vector2i(map_size.x, i), 0, Vector2i(0, 0))
        astar.set_point_solid(Vector2i(0, i), true)
        astar.set_point_solid(Vector2i(map_size.x, i), true)
    
    astar.update()
    sheepCount.append(0)
    
    rebuild_free_grass_list()
    spawn_sheep()

func _process(_delta: float) -> void:
    if Input.is_action_just_pressed("spawnSheep"):
        spawn_sheep()
    
    _update_live_inspector()
    if Input.is_action_just_pressed("e"):
        for i in range(10):
            spawn_sheep()
            
    # Keyboard shortcuts to tweak grass variables in-game
    if Input.is_action_just_pressed("ui_page_up"):
        weather_growth_multiplier = minf(3.0, weather_growth_multiplier + 0.1)
    elif Input.is_action_just_pressed("ui_page_down"):
        weather_growth_multiplier = maxf(0.0, weather_growth_multiplier - 0.1)
    elif Input.is_action_just_pressed("ui_home"):
        growth_percentage = minf(0.50, growth_percentage + 0.01)
    elif Input.is_action_just_pressed("ui_end"):
        growth_percentage = maxf(0.01, growth_percentage - 0.01)

func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var mouse_pos: Vector2 = map.get_global_mouse_position()
        inspect_position(mouse_pos)

func _on_timer_timeout() -> void:
    var total_map_area : float = (map_size.x - 1) * (map_size.y - 1)
    var is_under_cap : bool = (float(grass_count) / total_map_area) <= spread_threshold
    
    # 1. RELATIVE PERCENTAGE SPREADING BUDGET
    if not freeGrass.is_empty() and is_under_cap and weather_growth_multiplier > 0.0:
        var active_free_count : int = freeGrass.size()
        var budget : int = max(1, int(float(active_free_count) * growth_percentage * weather_growth_multiplier))
        
        for i in range(budget):
            if freeGrass.is_empty():
                break
            var source_tile : Vector2i = freeGrass.pick_random()
            var current_atlas : Vector2i = map.get_cell_atlas_coords(source_tile)
            
            # Sprouts & Mid grass mature over time; Best grass spreads seeds to neighbors
            if current_atlas == STAGE_SPROUT:
                map.set_cell(source_tile, 0, STAGE_MID)
            elif current_atlas == STAGE_MID:
                map.set_cell(source_tile, 0, STAGE_BEST)
            elif current_atlas == STAGE_BEST:
                var grow_target : Vector2i = get_random_empty_neighbor(source_tile)
                if grow_target != Vector2i(-1, -1):
                    place_sprout(grow_target)

    # 2. RANDOM SPONTANEOUS SEEDING
    if weather_growth_multiplier > 0.0:
        var random_tile : Vector2i = Vector2i(
            randi_range(1, map_size.x - 1),
            randi_range(1, map_size.y - 1)
        )
        if map.get_cell_atlas_coords(random_tile) == Vector2i(-1, -1):
            place_sprout(random_tile)

    var last_count: int = grass[-1] if not grass.is_empty() else grass_count
    var delta_val: int = grass_count - last_count
    var cur_sheep: int = get_total_sheep_count()
    
    grass.append(grass_count)
    grass_delta.append(delta_val)
    sheepCount.append(cur_sheep)

    if has_node("grassDisplay"): $grassDisplay.data = grass
    if has_node("GrassDeltaIndicator"): $GrassDeltaIndicator.data = grass_delta
    if has_node("SheepCountIndicator"): $SheepCountIndicator.data = sheepCount

#endregion

#region Live Inspector & Selection

func inspect_position(world_pos: Vector2) -> void:
    var tile_pos: Vector2i = map.local_to_map(world_pos)
    selected_tile = tile_pos
    selected_sheep = null
    
    for s in get_tree().get_nodes_in_group("sheep"):
        if s is CharacterBody2D:
            var sheep_tile: Vector2i = map.local_to_map((s as Node2D).global_position)
            if sheep_tile == tile_pos:
                selected_sheep = s
                break
                
    _update_live_inspector()

func _update_live_inspector() -> void:
    if selected_tile == Vector2i(-1, -1):
        return
        
    var tile_type: String = "Empty Tile"
    var atlas_coords: Vector2i = map.get_cell_atlas_coords(selected_tile)
    
    if not is_within_bounds(selected_tile):
        tile_type = "Outside Map Bounds"
    elif atlas_coords == STAGE_BEST:
        tile_type = "Grass (Stage 3: Best / Mature)"
    elif atlas_coords == STAGE_MID:
        tile_type = "Grass (Stage 2: Mid / Growing)"
    elif atlas_coords == STAGE_SPROUT:
        tile_type = "Grass (Stage 1: Sprout)"
    elif atlas_coords == Vector2i(0, 0):
        tile_type = "Boundary Wall"
    elif atlas_coords != Vector2i(-1, -1):
        tile_type = "Tile (%d, %d)" % [atlas_coords.x, atlas_coords.y]
        
    var is_solid: bool = astar.is_point_solid(selected_tile) if astar.is_in_boundsv(selected_tile) else true
    
    var tile_info_text: String = "Tile: (%d, %d)\nType: %s | Solid: %s" % [
        selected_tile.x, selected_tile.y, tile_type, str(is_solid)
    ]
    
    var sheep_info_text: String = "Sheep: None selected"
    
    if is_instance_valid(selected_sheep) and not selected_sheep.is_queued_for_deletion() and selected_sheep is CharacterBody2D:
        var cur_pos: Vector2i = map.local_to_map((selected_sheep as Node2D).global_position)
        var energy_val: int = selected_sheep.energy if "energy" in selected_sheep else 0
        var age_val: int = selected_sheep.age if "age" in selected_sheep else 0
        var travel_gene: int = selected_sheep.Travel_gene if "Travel_gene" in selected_sheep else 0
        var energy_gene: int = selected_sheep.energy_gene if "energy_gene" in selected_sheep else 0
        var memory_regions: int = selected_sheep.raster.size() if "raster" in selected_sheep else 0
        
        var is_preg: bool = selected_sheep.is_pregnant if "is_pregnant" in selected_sheep else false
        var g_timer: int = selected_sheep.gestation_timer if "gestation_timer" in selected_sheep else 0
        var preg_str: String = "Yes (%d turns left)" % g_timer if is_preg else "No"
        var children_val: int = selected_sheep.children_count if "children_count" in selected_sheep else 0
        var max_children: int = selected_sheep.max_offspring_count if "max_offspring_count" in selected_sheep else 10
        var salv_gene: bool = selected_sheep.salvation_gene if "salvation_gene" in selected_sheep else true
        var humb_gene: bool = selected_sheep.humble_gene if "humble_gene" in selected_sheep else false
        
        sheep_info_text = "Tracked Sheep Details:\nPos: (%d, %d) | Energy: %d | Age: %d\nPregnant: %s | Children: %d/%d\nSalvation: %s | Humble: %s | Energy Gene: %d\nTravel Gene: %d | Memory Regions: %d" % [
            cur_pos.x, cur_pos.y, energy_val, age_val, preg_str, children_val, max_children, str(salv_gene), str(humb_gene), energy_gene, travel_gene, memory_regions
        ]
    elif selected_sheep != null:
        sheep_info_text = "Tracked Sheep: Deceased / Despawned"
        
    if has_node("HUD") and $HUD.has_method("update_inspector"):
        $HUD.update_inspector(tile_info_text, sheep_info_text)

#endregion

#region Natural Grass & Grazing Helpers

## Called when grass is eaten by a sheep. Reduces stage and returns energy value gained.
func on_grass_eaten(tile_pos: Vector2i) -> int:
    var current_atlas : Vector2i = map.get_cell_atlas_coords(tile_pos)
    var energy_gained : int = 0
    
    if current_atlas == STAGE_BEST:
        map.set_cell(tile_pos, 0, STAGE_MID)
        energy_gained = 30
        update_tile_spreadability(tile_pos)
        update_neighbors_spreadability(tile_pos)
    elif current_atlas == STAGE_MID:
        map.set_cell(tile_pos, 0, STAGE_SPROUT)
        energy_gained = 15
        update_tile_spreadability(tile_pos)
        update_neighbors_spreadability(tile_pos)
    elif current_atlas == STAGE_SPROUT:
        map.erase_cell(tile_pos)
        energy_gained = 5
        grass_count -= 1
        remove_from_free_grass(tile_pos)
        update_neighbors_spreadability(tile_pos)
        
    return energy_gained

func place_sprout(tile_pos: Vector2i) -> void:
    map.set_cell(tile_pos, 0, STAGE_SPROUT)
    grass_count += 1
    update_tile_spreadability(tile_pos)
    update_neighbors_spreadability(tile_pos)

func is_any_grass(atlas: Vector2i) -> bool:
    return atlas == STAGE_SPROUT or atlas == STAGE_MID or atlas == STAGE_BEST

func update_tile_spreadability(tile_pos: Vector2i) -> void:
    var atlas : Vector2i = map.get_cell_atlas_coords(tile_pos)
    if not is_any_grass(atlas):
        remove_from_free_grass(tile_pos)
        return
        
    if has_empty_neighbor(tile_pos):
        add_to_free_grass(tile_pos)
    else:
        remove_from_free_grass(tile_pos)

func update_neighbors_spreadability(center_tile: Vector2i) -> void:
    for offset in SURROUNDING_OFFSETS:
        var n_tile : Vector2i = center_tile + offset
        if n_tile.x > 0 and n_tile.x < map_size.x and n_tile.y > 0 and n_tile.y < map_size.y:
            update_tile_spreadability(n_tile)

func has_empty_neighbor(tile_pos: Vector2i) -> bool:
    for offset in SURROUNDING_OFFSETS:
        var neighbor : Vector2i = tile_pos + offset
        if neighbor.x > 0 and neighbor.x < map_size.x and neighbor.y > 0 and neighbor.y < map_size.y:
            if map.get_cell_atlas_coords(neighbor) == Vector2i(-1, -1):
                return true
    return false

func get_random_empty_neighbor(tile_pos: Vector2i) -> Vector2i:
    var count : int = 0
    for offset in SURROUNDING_OFFSETS:
        var neighbor : Vector2i = tile_pos + offset
        if neighbor.x > 0 and neighbor.x < map_size.x and neighbor.y > 0 and neighbor.y < map_size.y:
            if map.get_cell_atlas_coords(neighbor) == Vector2i(-1, -1):
                count += 1
    
    if count == 0:
        return Vector2i(-1, -1)
    
    var pick : int = randi_range(0, count - 1)
    var current : int = 0
    for offset in SURROUNDING_OFFSETS:
        var neighbor : Vector2i = tile_pos + offset
        if neighbor.x > 0 and neighbor.x < map_size.x and neighbor.y > 0 and neighbor.y < map_size.y:
            if map.get_cell_atlas_coords(neighbor) == Vector2i(-1, -1):
                if current == pick:
                    return neighbor
                current += 1
    
    return Vector2i(-1, -1)

func get_empty_neighbors(tile_pos: Vector2i) -> Array[Vector2i]:
    var empty_list : Array[Vector2i] = []
    for offset in SURROUNDING_OFFSETS:
        var neighbor : Vector2i = tile_pos + offset
        if is_within_bounds(neighbor) and is_tile_empty(neighbor):
            empty_list.append(neighbor)
    return empty_list

func is_tile_empty(tile_pos: Vector2i) -> bool:
    return map.get_cell_atlas_coords(tile_pos) == Vector2i(-1, -1)

func is_within_bounds(tile_pos: Vector2i) -> bool:
    return tile_pos.x > 0 and tile_pos.x < map_size.x and tile_pos.y > 0 and tile_pos.y < map_size.y

func add_to_free_grass(tile: Vector2i) -> void:
    if not freeGrassSet.has(tile):
        freeGrassSet[tile] = true
        freeGrassIndex[tile] = freeGrass.size()
        freeGrass.append(tile)

func remove_from_free_grass(tile: Vector2i) -> void:
    if freeGrassSet.has(tile):
        freeGrassSet.erase(tile)
        var idx : int = freeGrassIndex[tile]
        freeGrassIndex.erase(tile)
        var last_idx : int = freeGrass.size() - 1
        if idx != last_idx:
            var last_tile : Vector2i = freeGrass[last_idx]
            freeGrass[idx] = last_tile
            freeGrassIndex[last_tile] = idx
        freeGrass.resize(last_idx)

func rebuild_free_grass_list() -> void:
    freeGrass.clear()
    freeGrassSet.clear()
    freeGrassIndex.clear()
    grass_count = 0
    
    var used_cells: Array[Vector2i] = map.get_used_cells()
    for tile_pos in used_cells:
        if is_within_bounds(tile_pos):
            var atlas: Vector2i = Vector2i(map.get_cell_atlas_coords(tile_pos))
            if is_any_grass(atlas):
                grass_count += 1
                update_tile_spreadability(tile_pos)

#endregion

#region Sheep Spawning

@export var auto_respawn_on_death : bool = false

func on_sheep_died(_dead_sheep: Node) -> void:
    if auto_respawn_on_death:
        spawn_sheep()

func spawn_sheep() -> void:
    var newSheep = sheep.instantiate()
    newSheep.map = map 
    newSheep.map_size = map_size
    newSheep.tile_size = tile_size
    newSheep.text = get_node_or_null("text")
    newSheep.astar = astar
    
    var start_x = randi_range(1, map_size.x - 1)
    var start_y = randi_range(1, map_size.y - 1)
    newSheep.position = map.map_to_local(Vector2i(start_x, start_y))
    
    add_child(newSheep)

func spawn_sheep_at(spawn_pos: Vector2) -> void:
    var newSheep = sheep.instantiate()
    newSheep.map = map 
    newSheep.map_size = map_size
    newSheep.tile_size = tile_size
    newSheep.text = get_node_or_null("text")
    newSheep.astar = astar
    newSheep.position = spawn_pos
    
    add_child(newSheep)

#endregion

#region Count & Stage Helpers

func get_total_sheep_count() -> int:
    return get_tree().get_node_count_in_group("sheep")

func get_total_grass_count() -> int:
    return grass_count

func get_playable_map_area() -> float:
    return float((map_size.x - 1) * (map_size.y - 1))

func get_grass_coverage_percent() -> float:
    var total_area := get_playable_map_area()
    return (float(grass_count) / total_area) * 100.0 if total_area > 0 else 0.0

func is_grass_spreading_active() -> bool:
    return (float(grass_count) / get_playable_map_area()) <= spread_threshold

func get_grass_stage_counts() -> Dictionary:
    var sprouts : int = 0
    var mid : int = 0
    var best : int = 0
    
    for g in freeGrass:
        var atlas : Vector2i = Vector2i(map.get_cell_atlas_coords(g))
        if atlas == STAGE_SPROUT: sprouts += 1
        elif atlas == STAGE_MID: mid += 1
        elif atlas == STAGE_BEST: best += 1
        
    return { "sprout": sprouts, "mid": mid, "best": best }

func get_camera_visible_rect(camera: Camera2D) -> Rect2:
    var viewport: Viewport = camera.get_viewport()
    if not viewport:
        return Rect2()
    var screen_size: Vector2 = viewport.get_visible_rect().size
    var camera_pos: Vector2 = camera.get_screen_center_position()
    var zoom_val: Vector2 = camera.zoom
    var vis_size: Vector2 = screen_size / zoom_val
    var top_left: Vector2 = camera_pos - vis_size * 0.5
    return Rect2(top_left, vis_size)

func get_visible_sheep_count(camera: Camera2D) -> int:
    if not camera:
        return get_total_sheep_count()
    var rect: Rect2 = get_camera_visible_rect(camera)
    
    # O(1) Shortcut: If camera view encloses entire map bounds
    var map_w: float = float(map_size.x * tile_size)
    var map_h: float = float(map_size.y * tile_size)
    if rect.position.x <= 0 and rect.position.y <= 0 and rect.end.x >= map_w and rect.end.y >= map_h:
        return get_total_sheep_count()
        
    var count: int = 0
    for s in get_tree().get_nodes_in_group("sheep"):
        if s is Node2D and rect.has_point((s as Node2D).global_position):
            count += 1
    return count

func get_visible_grass_count(camera: Camera2D) -> int:
    if not camera or not map:
        return get_total_grass_count()
    var rect: Rect2 = get_camera_visible_rect(camera)
    var top_left_tile: Vector2i = map.local_to_map(map.to_local(rect.position))
    var bottom_right_tile: Vector2i = map.local_to_map(map.to_local(rect.end))
    
    var min_x: int = clampi(mini(top_left_tile.x, bottom_right_tile.x) - 1, 0, map_size.x)
    var max_x: int = clampi(maxi(top_left_tile.x, bottom_right_tile.x) + 1, 0, map_size.x)
    var min_y: int = clampi(mini(top_left_tile.y, bottom_right_tile.y) - 1, 0, map_size.y)
    var max_y: int = clampi(maxi(top_left_tile.y, bottom_right_tile.y) + 1, 0, map_size.y)
    
    # O(1) Shortcut: If camera view covers the entire playable map grid
    if min_x <= 1 and max_x >= map_size.x - 1 and min_y <= 1 and max_y >= map_size.y - 1:
        return grass_count
    
    var count: int = 0
    for x in range(min_x, max_x + 1):
        for y in range(min_y, max_y + 1):
            if is_any_grass(map.get_cell_atlas_coords(Vector2i(x, y))):
                count += 1
    return count

#endregion


func _on_timer_2_timeout() -> void:
    time += 1
    $Label.text = "Time: " + str(time)
