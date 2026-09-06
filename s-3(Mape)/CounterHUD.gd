extends CanvasLayer

#region UI References & Variables

@onready var sheep_label: Label = $PanelContainer/MarginContainer/VBoxContainer/SheepLabel
@onready var grass_label: Label = $PanelContainer/MarginContainer/VBoxContainer/GrassLabel

var tile_info_label: Label = null
var sheep_info_label: Label = null

var growth_slider: HSlider = null
var growth_val_label: Label = null
var weather_slider: HSlider = null
var weather_val_label: Label = null

var main_node: Node = null
var camera_node: Camera2D = null
var left_sidebar_vbox: VBoxContainer = null

#endregion

#region Lifecycle & UI Setup

func _ready() -> void:
    main_node = get_parent()
    if main_node:
        camera_node = main_node.get_node_or_null("MapCamera2D")
        
    _setup_left_sidebar_ui()

func _setup_left_sidebar_ui() -> void:
    var sidebar := get_node_or_null("LeftSidebarVBox") as VBoxContainer
    if not sidebar:
        sidebar = VBoxContainer.new()
        sidebar.name = "LeftSidebarVBox"
        sidebar.position = Vector2(16, 90)
        sidebar.add_theme_constant_override("separation", 10)
        add_child(sidebar)
    left_sidebar_vbox = sidebar
    
    _setup_inspector_ui(left_sidebar_vbox)
    _setup_controls_ui(left_sidebar_vbox)

func _setup_inspector_ui(parent: Container) -> void:
    var inspector := parent.get_node_or_null("InspectorPanel") as PanelContainer
    if not inspector:
        inspector = PanelContainer.new()
        inspector.name = "InspectorPanel"
        inspector.custom_minimum_size = Vector2(360, 130)
        
        var margin := MarginContainer.new()
        margin.name = "MarginContainer"
        margin.add_theme_constant_override("margin_left", 10)
        margin.add_theme_constant_override("margin_top", 8)
        margin.add_theme_constant_override("margin_right", 10)
        margin.add_theme_constant_override("margin_bottom", 8)
        inspector.add_child(margin)
        
        var vbox := VBoxContainer.new()
        vbox.name = "VBoxContainer"
        margin.add_child(vbox)
        
        tile_info_label = Label.new()
        tile_info_label.name = "TileInfoLabel"
        tile_info_label.text = "Tile: Click any tile to inspect"
        vbox.add_child(tile_info_label)
        
        sheep_info_label = Label.new()
        sheep_info_label.name = "SheepInfoLabel"
        sheep_info_label.text = "Sheep: None selected"
        vbox.add_child(sheep_info_label)
        
        parent.add_child(inspector)
    else:
        tile_info_label = inspector.get_node_or_null("MarginContainer/VBoxContainer/TileInfoLabel")
        sheep_info_label = inspector.get_node_or_null("MarginContainer/VBoxContainer/SheepInfoLabel")

func _setup_controls_ui(parent: Container) -> void:
    var controls := parent.get_node_or_null("ControlsPanel") as PanelContainer
    if not controls:
        controls = PanelContainer.new()
        controls.name = "ControlsPanel"
        controls.custom_minimum_size = Vector2(360, 110)
        
        var margin := MarginContainer.new()
        margin.name = "MarginContainer"
        margin.add_theme_constant_override("margin_left", 10)
        margin.add_theme_constant_override("margin_top", 8)
        margin.add_theme_constant_override("margin_right", 10)
        margin.add_theme_constant_override("margin_bottom", 8)
        controls.add_child(margin)
        
        var vbox := VBoxContainer.new()
        vbox.name = "VBoxContainer"
        margin.add_child(vbox)
        
        var title := Label.new()
        title.text = "Grass Spreading Controls"
        vbox.add_child(title)
        
        # --- Row 1: Growth Rate ---
        var hbox_growth := HBoxContainer.new()
        vbox.add_child(hbox_growth)
        
        growth_val_label = Label.new()
        growth_val_label.text = "Growth Rate: 5%"
        growth_val_label.custom_minimum_size = Vector2(150, 0)
        hbox_growth.add_child(growth_val_label)
        
        growth_slider = HSlider.new()
        growth_slider.min_value = 0.01
        growth_slider.max_value = 0.50
        growth_slider.step = 0.01
        growth_slider.value = main_node.growth_percentage if main_node and "growth_percentage" in main_node else 0.05
        growth_slider.custom_minimum_size = Vector2(160, 0)
        growth_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        growth_slider.value_changed.connect(_on_growth_slider_changed)
        hbox_growth.add_child(growth_slider)
        
        # --- Row 2: Weather Multiplier ---
        var hbox_weather := HBoxContainer.new()
        vbox.add_child(hbox_weather)
        
        weather_val_label = Label.new()
        weather_val_label.text = "Weather: 1.0x"
        weather_val_label.custom_minimum_size = Vector2(150, 0)
        hbox_weather.add_child(weather_val_label)
        
        weather_slider = HSlider.new()
        weather_slider.min_value = 0.0
        weather_slider.max_value = 3.0
        weather_slider.step = 0.1
        weather_slider.value = main_node.weather_growth_multiplier if main_node and "weather_growth_multiplier" in main_node else 1.0
        weather_slider.custom_minimum_size = Vector2(160, 0)
        weather_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        weather_slider.value_changed.connect(_on_weather_slider_changed)
        hbox_weather.add_child(weather_slider)
        
        parent.add_child(controls)

func _on_growth_slider_changed(val: float) -> void:
    if main_node and "growth_percentage" in main_node:
        main_node.growth_percentage = val
    if growth_val_label:
        growth_val_label.text = "Growth Rate: %d%%" % int(val * 100.0)

func _on_weather_slider_changed(val: float) -> void:
    if main_node and "weather_growth_multiplier" in main_node:
        main_node.weather_growth_multiplier = val
    if weather_val_label:
        if val == 0.0:
            weather_val_label.text = "Weather: 0.0x (Drought)"
        else:
            weather_val_label.text = "Weather: %.1fx" % val

var hud_update_timer: float = 0.0
const HUD_INTERVAL: float = 0.1

#endregion

#region Process & Live Updates

func _process(delta: float) -> void:
    if not main_node:
        return
        
    hud_update_timer += delta
    if hud_update_timer < HUD_INTERVAL:
        return
    hud_update_timer = 0.0
    
    var total_sheep: int = 0
    var visible_sheep: int = 0
    var total_grass: int = 0
    var visible_grass: int = 0
    var grass_coverage_pct: float = 0.0
    var spreading_active: bool = true
    var weather_mult: float = 1.0
    var growth_pct: float = 0.05
    
    if main_node.has_method("get_total_sheep_count"):
        total_sheep = main_node.get_total_sheep_count()
    else:
        total_sheep = get_tree().get_node_count_in_group("sheep")
        
    if camera_node and main_node.has_method("get_visible_sheep_count"):
        visible_sheep = main_node.get_visible_sheep_count(camera_node)
    else:
        visible_sheep = total_sheep
        
    if main_node.has_method("get_total_grass_count"):
        total_grass = main_node.get_total_grass_count()
    elif "grass_count" in main_node:
        total_grass = main_node.grass_count
        
    if camera_node and main_node.has_method("get_visible_grass_count"):
        visible_grass = main_node.get_visible_grass_count(camera_node)
    else:
        visible_grass = total_grass

    if main_node.has_method("get_grass_coverage_percent"):
        grass_coverage_pct = main_node.get_grass_coverage_percent()
        
    if main_node.has_method("is_grass_spreading_active"):
        spreading_active = main_node.is_grass_spreading_active()

    if "weather_growth_multiplier" in main_node:
        weather_mult = main_node.weather_growth_multiplier
        if weather_slider and not weather_slider.has_focus():
            weather_slider.value = weather_mult
            if weather_val_label:
                weather_val_label.text = "Weather: %.1fx%s" % [weather_mult, " (Drought)" if weather_mult == 0.0 else ""]
        
    if "growth_percentage" in main_node:
        growth_pct = main_node.growth_percentage
        if growth_slider and not growth_slider.has_focus():
            growth_slider.value = growth_pct
            if growth_val_label:
                growth_val_label.text = "Growth Rate: %d%%" % int(growth_pct * 100.0)

    var target_thresh_pct: float = main_node.spread_threshold * 100.0 if "spread_threshold" in main_node else 100.0

    if sheep_label:
        sheep_label.text = "Sheep: %d (Visible: %d)" % [total_sheep, visible_sheep]
        
    if grass_label:
        var status_str: String = "Spreading" if spreading_active else ("Cap Reached (>%.0f%%)" % target_thresh_pct)
        if weather_mult == 0.0:
            status_str = "Drought/Dormant"
            
        grass_label.text = "Grass: %d (Vis: %d) | Cover: %.1f%% / %.0f%% | Rate: %.0f%% (Weather: %.1fx - %s)" % [
            total_grass, visible_grass, grass_coverage_pct, target_thresh_pct, growth_pct * 100.0, weather_mult, status_str
        ]

#endregion

#region Inspector Interface

func update_inspector(tile_info: String, sheep_info: String) -> void:
    if tile_info_label:
        tile_info_label.text = tile_info
    if sheep_info_label:
        sheep_info_label.text = sheep_info

#endregion
