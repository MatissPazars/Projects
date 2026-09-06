extends Node2D

class_name ParticleSimulator

# Chebyshev Distance & Vector Utility Functions
static func chebyshev_norm(v: Vector2) -> float:
	return maxf(absf(v.x), absf(v.y))

static func chebyshev_distance(a: Vector2, b: Vector2) -> float:
	return chebyshev_norm(a - b)

static func clamp_chebyshev_speed(v: Vector2, max_speed: float = 1.0) -> Vector2:
	var norm = chebyshev_norm(v)
	if norm > max_speed and norm > 0.00001:
		return (v / norm) * max_speed
	return v

# Particle Data Class
class SimulationParticle:
	var pos: Vector2         # Grid position in tiles
	var vel: Vector2         # Velocity in tiles per tick
	var force: Vector2       # Applied force vector
	var mass: float = 1.0    # Mass
	var color: Color = Color(1.0, 0.85, 0.2)
	var trail: Array[Vector2] = []
	var max_trail_len: int = 25
	
	func _init(p_pos: Vector2, p_force: Vector2 = Vector2(1, 1), p_vel: Vector2 = Vector2.ZERO):
		pos = p_pos
		force = p_force
		vel = p_vel

# Simulator Config & State
@export var grid_size: Vector2i = Vector2i(55, 35)
@export var tile_size_px: float = 20.0
@export var tick_interval: float = 0.15 # seconds per tick
@export var speed_of_light: float = 1.0 # 1 tile per tick max Chebyshev speed

var particles: Array[SimulationParticle] = []
var default_force: Vector2 = Vector2(1.0, 1.0)
var is_paused: bool = false
var tick_count: int = 0
var tick_timer: float = 0.0

# Selected particle for inspection
var selected_particle: SimulationParticle = null

# Visual offset to center grid
var grid_origin: Vector2 = Vector2(40, 40)

# References
@onready var hud_label: Label = $HUD/PanelContainer/MarginContainer/VBoxContainer/StatusLabel
@onready var inspector_label: Label = $HUD/PanelContainer/MarginContainer/VBoxContainer/InspectorLabel

func _ready() -> void:
	# Add a default demonstration particle near center
	var center = Vector2(grid_size.x / 4.0, grid_size.y / 2.0)
	spawn_particle(center, default_force)
	
	# Add a second particle with different force for comparison
	var p2 = spawn_particle(center + Vector2(0, -8), Vector2(1, 0.5))
	p2.color = Color(0.3, 0.9, 1.0)

func spawn_particle(p_pos: Vector2, p_force: Vector2 = default_force) -> SimulationParticle:
	var p = SimulationParticle.new(p_pos, p_force)
	p.trail.append(p_pos)
	particles.append(p)
	selected_particle = p
	queue_redraw()
	return p

func _process(delta: float) -> void:
	_handle_input()
	
	if not is_paused:
		tick_timer += delta
		if tick_timer >= tick_interval:
			tick_timer -= tick_interval
			_simulation_tick()
	
	_update_hud()
	queue_redraw()

func _simulation_tick() -> void:
	tick_count += 1
	
	for p in particles:
		# Apply force (F = m * a  =>  a = F / m)
		var accel = p.force / p.mass
		p.vel += accel
		
		# Clamp speed using Chebyshev norm to speed of light (1 tile/tick)
		p.vel = clamp_chebyshev_speed(p.vel, speed_of_light)
		
		# Integrate position
		p.pos += p.vel
		
		# Wrap around grid boundaries
		if p.pos.x < 0:
			p.pos.x += grid_size.x
			p.trail.clear()
		elif p.pos.x >= grid_size.x:
			p.pos.x -= grid_size.x
			p.trail.clear()
			
		if p.pos.y < 0:
			p.pos.y += grid_size.y
			p.trail.clear()
		elif p.pos.y >= grid_size.y:
			p.pos.y -= grid_size.y
			p.trail.clear()
			
		p.trail.append(p.pos)
		if p.trail.size() > p.max_trail_len:
			p.trail.pop_front()

func _handle_input() -> void:
	if Input.is_action_just_pressed("ui_accept"): # Spacebar
		is_paused = not is_paused
		
	if Input.is_physical_key_pressed(KEY_C) and Input.is_action_just_pressed("ui_text_submit"):
		particles.clear()
		selected_particle = null
		
	if Input.is_physical_key_pressed(KEY_R):
		particles.clear()
		tick_count = 0
		_ready()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mouse_pos = get_local_mouse_position()
		var grid_pos = (mouse_pos - grid_origin) / tile_size_px
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			if grid_pos.x >= 0 and grid_pos.x < grid_size.x and grid_pos.y >= 0 and grid_pos.y < grid_size.y:
				var new_p = spawn_particle(grid_pos, default_force)
				# Give random vibrant color
				new_p.color = Color.from_hsv(randf(), 0.85, 1.0)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Select or remove particle closest to click
			var min_dist = 999999.0
			var closest: SimulationParticle = null
			for p in particles:
				var dist = chebyshev_distance(p.pos, grid_pos)
				if dist < min_dist:
					min_dist = dist
					closest = p
			if closest and min_dist < 3.0:
				selected_particle = closest

func _draw() -> void:
	# 1. Draw Grid Background & Tile Borders
	var grid_width_px = grid_size.x * tile_size_px
	var grid_height_px = grid_size.y * tile_size_px
	
	draw_rect(Rect2(grid_origin, Vector2(grid_width_px, grid_height_px)), Color(0.08, 0.09, 0.13, 1.0), true)
	
	# Grid Lines
	var line_color = Color(0.2, 0.22, 0.3, 0.4)
	for x in range(grid_size.x + 1):
		var p1 = grid_origin + Vector2(x * tile_size_px, 0)
		var p2 = grid_origin + Vector2(x * tile_size_px, grid_height_px)
		draw_line(p1, p2, line_color, 1.0)
		
	for y in range(grid_size.y + 1):
		var p1 = grid_origin + Vector2(0, y * tile_size_px)
		var p2 = grid_origin + Vector2(grid_width_px, y * tile_size_px)
		draw_line(p1, p2, line_color, 1.0)
	
	# Draw Outer Boundary
	draw_rect(Rect2(grid_origin, Vector2(grid_width_px, grid_height_px)), Color(0.4, 0.6, 1.0, 0.8), false, 2.0)
	
	# 2. Draw Particles, Trails, and Vectors
	for p in particles:
		var center_px = grid_origin + (p.pos + Vector2(0.5, 0.5)) * tile_size_px
		
		# Draw Chebyshev Reachable Box (Light Cone step per tick: 1 tile in Chebyshev distance)
		var reach_min_px = grid_origin + (p.pos.floor() - Vector2(1, 1)) * tile_size_px
		var reach_size_px = Vector2(3, 3) * tile_size_px
		draw_rect(Rect2(reach_min_px, reach_size_px), Color(p.color.r, p.color.g, p.color.b, 0.1), true)
		draw_rect(Rect2(reach_min_px, reach_size_px), Color(p.color.r, p.color.g, p.color.b, 0.3), false, 1.0)
		
		# Draw Trail
		if p.trail.size() > 1:
			for i in range(p.trail.size() - 1):
				var pt1 = grid_origin + (p.trail[i] + Vector2(0.5, 0.5)) * tile_size_px
				var pt2 = grid_origin + (p.trail[i + 1] + Vector2(0.5, 0.5)) * tile_size_px
				var alpha = float(i) / float(p.trail.size())
				draw_line(pt1, pt2, Color(p.color.r, p.color.g, p.color.b, alpha * 0.7), 2.0)
		
		# Draw Particle Body
		draw_circle(center_px, tile_size_px * 0.4, p.color)
		draw_circle(center_px, tile_size_px * 0.4, Color.WHITE, false, 1.5)
		
		# Draw Velocity Vector (Green Arrow)
		var vel_end_px = center_px + p.vel * tile_size_px * 2.0
		draw_line(center_px, vel_end_px, Color(0.2, 1.0, 0.3, 0.9), 2.0)
		
		# Draw Force Vector (Orange Arrow)
		var force_end_px = center_px + p.force * tile_size_px * 1.5
		draw_line(center_px, force_end_px, Color(1.0, 0.5, 0.2, 0.8), 1.5)
		
		# Draw Selection Indicator
		if p == selected_particle:
			draw_circle(center_px, tile_size_px * 0.6, Color(1.0, 1.0, 1.0, 0.4), false, 2.0)

func _update_hud() -> void:
	if hud_label:
		var status_text = "Ticks: %d | Particles: %d | Status: %s\n" % [
			tick_count,
			particles.size(),
			"PAUSED" if is_paused else "RUNNING"
		]
		status_text += "Speed Limit (c): 1.0 tile/tick (Chebyshev norm: max(|vx|, |vy|) <= 1.0)\n"
		status_text += "Force Vector: (%.1f, %.1f) | Controls: [LMB] Spawn Particle | [RMB] Select | [Space] Pause" % [
			default_force.x, default_force.y
		]
		hud_label.text = status_text
		
	if inspector_label:
		if selected_particle:
			var cheb_v = chebyshev_norm(selected_particle.vel)
			var cheb_f = chebyshev_norm(selected_particle.force)
			var insp = "--- Selected Particle ---\n"
			insp += "Pos: (%.2f, %.2f) tile\n" % [selected_particle.pos.x, selected_particle.pos.y]
			insp += "Vel: (%.3f, %.3f) | ||V||_∞ = %.3f / 1.0 (tile/tick)\n" % [selected_particle.vel.x, selected_particle.vel.y, cheb_v]
			insp += "Force: (%.2f, %.2f) | ||F||_∞ = %.2f" % [selected_particle.force.x, selected_particle.force.y, cheb_f]
			inspector_label.text = insp
		else:
			inspector_label.text = "Click a particle to inspect"
