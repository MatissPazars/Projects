extends CharacterBody2D

#region Setup & Variables

var map: TileMapLayer
var map_size: Vector2i
var tile_size: int
var text: Label
var astar: AStarGrid2D

var raster: Dictionary = {}
var rasterSize: int = 10 

var energy: int = 100
var Travel_gene: int = 3
var energy_gene: int = 80 # Default satiation threshold (won't eat if energy > 80)
var salvation_gene: bool = true # Seed sanctuary protection (won't eat if total grass == 1)
var humble_gene: bool = true # Energy overflow prevention (won't eat if energy + gain > 100)
var age: int = 0

# Pregnancy Mechanics
var pregnancy_gene: int = 90
var is_pregnant: bool = false
var gestation_timer: int = 0
var min_reproduction_age: int = 20
var max_offspring_count: int = 10
var children_count: int = 0

const STAGE_SPROUT : Vector2i = Vector2i(0, 3)
const STAGE_MID    : Vector2i = Vector2i(4, 2)
const STAGE_BEST   : Vector2i = Vector2i(1, 3)

func _ready() -> void:
    add_to_group("sheep")
    call_deferred("_desync_timer")

func _desync_timer() -> void:
    var t := get_node_or_null("Timer") as Timer
    if t:
        var base_wait: float = t.wait_time
        var random_offset: float = randf_range(0.01, base_wait)
        t.stop()
        await get_tree().create_timer(random_offset).timeout
        if is_instance_valid(self) and not is_queued_for_deletion():
            t.wait_time = base_wait
            t.start()

func is_grass_tile(pos: Vector2i) -> bool:
    var atlas := map.get_cell_atlas_coords(pos)
    return atlas == STAGE_BEST or atlas == STAGE_MID or atlas == STAGE_SPROUT

func get_tile_grass_stage_value(pos: Vector2i) -> int:
    var atlas := map.get_cell_atlas_coords(pos)
    if atlas == STAGE_BEST: return 3
    if atlas == STAGE_MID: return 2
    if atlas == STAGE_SPROUT: return 1
    return 0

func get_stage_energy_yield(stage_value: int) -> int:
    if stage_value == 3: return 30
    if stage_value == 2: return 15
    if stage_value == 1: return 5
    return 0

func can_eat_stage(stage_value: int) -> bool:
    if stage_value <= 0:
        return false
    if humble_gene:
        var yield_val: int = get_stage_energy_yield(stage_value)
        if (energy + yield_val) > 100:
            return false
    return true

func count_total_visible_grass(pos: Vector2i, radius: int) -> int:
    var count: int = 0
    for x in range(-radius, radius + 1):
        for y in range(-radius, radius + 1):
            var tile_pos: Vector2i = pos + Vector2i(x, y)
            if is_grass_tile(tile_pos):
                count += 1
    return count

#endregion

#region Simulation & Life Cycle

func _on_timer_timeout() -> void:
    age += 1
    @warning_ignore("integer_division")
    energy -= 2 + floor(age / 10)
    
    # Pregnancy Trigger (requires energy >= 90, age >= 20, and children_count < 10)
    if not is_pregnant and energy >= pregnancy_gene and age >= min_reproduction_age and children_count < max_offspring_count:
        is_pregnant = true
        gestation_timer = 10
        
    if is_pregnant:
        energy -= 5 # Gestation energy drain per turn
        gestation_timer -= 1
    
    # Check starvation after metabolic & pregnancy energy drain
    if energy <= 0:
        die()
        return

    # Speed reduction when pregnant (movement reduced by 1, min 1)
    var move_range: int = max(1, Travel_gene - 1) if is_pregnant else Travel_gene
    var pos: Vector2i = map.local_to_map(position)
    
    # Evaluate grazing if energy is below satiation threshold (energy_gene = 80)
    if energy <= energy_gene:
        # Check Salvation Gene (Solitary Grass Protection)
        var total_grass_around: int = count_total_visible_grass(pos, move_range)
        var is_salvation_blocked: bool = salvation_gene and (total_grass_around == 1)
        
        if not is_salvation_blocked:
            # --- SMART MOORE NEIGHBORHOOD GRAZING ---
            var cur_stage: int = get_tile_grass_stage_value(pos)
            if not can_eat_stage(cur_stage):
                cur_stage = 0 # Block eating current tile if humble_gene prevents energy overflow
            
            # Scan 8 Moore neighbors
            var best_neighbor_stage: int = 0
            var best_neighbors: Array[Vector2i] = []
            
            for offset in [
                Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
                Vector2i(-1,  0),                  Vector2i(1,  0),
                Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1)
            ]:
                var neighbor_pos: Vector2i = pos + offset
                var n_stage: int = get_tile_grass_stage_value(neighbor_pos)
                if can_eat_stage(n_stage):
                    if n_stage > best_neighbor_stage:
                        best_neighbor_stage = n_stage
                        best_neighbors.clear()
                        best_neighbors.append(neighbor_pos)
                    elif n_stage > 0 and n_stage == best_neighbor_stage:
                        best_neighbors.append(neighbor_pos)

            # 1. MOVE TO NEIGHBOR IF IT HAS STRICTLY BETTER GRASS
            if best_neighbor_stage > cur_stage and not best_neighbors.is_empty():
                var picked: Vector2i = best_neighbors.pick_random()
                position = map.map_to_local(picked)
                eat_grass(picked)
                track_raster(picked)
            # 2. OTHERWISE EAT CURRENT TILE IF IT IS GRASS AND ALLOWED
            elif cur_stage > 0:
                eat_grass(pos)
                track_raster(pos)
            # 3. SEARCH WIDER RADIUS (R = 2..move_range)
            else:
                var grass_candidates: Array[Vector2i] = []
                for i in range(2, move_range + 1):
                    for x in range(-i, i + 1):
                        for y in range(-i, i + 1):
                            if abs(x) == i or abs(y) == i:
                                var candidate: Vector2i = pos + Vector2i(x, y)
                                var c_stage: int = get_tile_grass_stage_value(candidate)
                                if can_eat_stage(c_stage):
                                    grass_candidates.append(candidate)
                    if not grass_candidates.is_empty():
                        break

                # 4. MOVE & EAT IF WIDER GRASS IS FOUND
                if not grass_candidates.is_empty():
                    var picked: Vector2i = grass_candidates.pick_random()
                    position = map.map_to_local(picked)
                    eat_grass(picked)
                    track_raster(picked)
                # 5. NO ALLOWED GRASS IN RANGE: WANDER / MEMORY
                else:
                    if energy > move_range:
                        var current_raster: Vector2i = FindRaster(pos)
                        if raster.has(current_raster):
                            _wander_randomly(pos, move_range)
                        elif not raster.is_empty():
                            _travel_to_best_raster(pos, current_raster, move_range)
                        else:
                            _wander_randomly(pos, move_range)
        else:
            # Salvation gene active & only 1 grass tile around: Wander away to preserve seed
            if energy > move_range:
                _wander_randomly(pos, move_range)

    # Give Birth when gestation completes
    if is_pregnant and gestation_timer <= 0:
        give_birth()

    # Final starvation check after movement
    if energy <= 0:
        die()
        return

    if energy > 100:
        energy = 100

func _wander_randomly(pos: Vector2i, move_range: int = Travel_gene) -> void:
    var candidate: Vector2i = pos + Vector2i(
        randi_range(-move_range, move_range),
        randi_range(-move_range, move_range)
    )
    if candidate != pos and astar.is_in_boundsv(candidate):
        var path = astar.get_id_path(pos, candidate)
        if not path.is_empty():
            var step_index: int = mini(move_range, path.size() - 1)
            position = map.map_to_local(path[step_index])
            energy -= step_index

func _travel_to_best_raster(pos: Vector2i, current_raster: Vector2i, move_range: int = Travel_gene) -> void:
    var highest: float = -1.0
    var chosen_raster: Vector2i = current_raster
    
    for region in raster.keys():
        if raster[region] > highest:
            highest = raster[region]
            chosen_raster = region
    
    var target_tile: Vector2i = Vector2i(
        chosen_raster.x * rasterSize + (rasterSize / 2),
        chosen_raster.y * rasterSize + (rasterSize / 2)
    )
    
    var path = astar.get_id_path(pos, target_tile)
    if not path.is_empty():
        var step_index: int = mini(move_range, path.size() - 1)
        position = map.map_to_local(path[step_index])
        energy -= step_index

func give_birth() -> void:
    is_pregnant = false
    gestation_timer = 0
    children_count += 1
    if get_parent() and get_parent().has_method("spawn_sheep_at"):
        get_parent().spawn_sheep_at(global_position)

## Decoupled death method
func die() -> void:
    if get_parent():
        if get_parent().has_method("on_sheep_died"):
            get_parent().on_sheep_died(self)
    queue_free()

#endregion

#region Memory & Eating Helpers

func track_raster(tile_pos: Vector2i) -> void:
    # 1. Decay all existing raster memories by 0.5 per eat action
    var keys_to_erase: Array = []
    for region in raster.keys():
        raster[region] -= 0.5
        if raster[region] <= 0.0:
            keys_to_erase.append(region)
            
    for r in keys_to_erase:
        raster.erase(r)
        
    # 2. Add +1.0 to the current feeding region
    var cur_region = FindRaster(tile_pos)
    raster[cur_region] = raster.get(cur_region, 0.0) + 1.0

func FindRaster(tile_pos: Vector2i) -> Vector2i:
    return Vector2i(
        floori(tile_pos.x / float(rasterSize)),
        floori(tile_pos.y / float(rasterSize))
    )

func eat_grass(grass_tile: Vector2i) -> void:
    if get_parent() and get_parent().has_method("on_grass_eaten"):
        var energy_gained: int = get_parent().on_grass_eaten(grass_tile)
        energy = mini(100, energy + energy_gained)

#endregion

#region Input & Selection

func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if get_parent() and get_parent().has_method("inspect_position"):
            get_parent().inspect_position(global_position)

#endregion
