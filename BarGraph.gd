class_name BarGraph
extends Control

#region Properties & Exports

@export var title: String = "Population History"

# Uses PackedInt64Array for memory efficiency
@export var data: PackedInt64Array = [] :
    set(value):
        data = value
        _update_historical_min_max(value)
        queue_redraw()

var historical_max: int = 0
var historical_min: int = 0

@export var max_visible_points: int = 50 :
    set(value):
        max_visible_points = max(0, value)
        queue_redraw()

@export var use_local_visible_max: bool = false

@export var bar_color: Color = Color(0.18, 0.8, 0.36) :
    set(value):
        bar_color = value
        queue_redraw()

@export var negative_bar_color: Color = Color(0.92, 0.35, 0.35) :
    set(value):
        negative_bar_color = value
        queue_redraw()

@export var is_bidirectional: bool = false :
    set(value):
        is_bidirectional = value
        queue_redraw()

@export var spacing: float = 3.0 :
    set(value):
        spacing = max(0.0, value)
        queue_redraw()

@export var show_background: bool = true
@export var bg_color: Color = Color(0.08, 0.09, 0.12, 0.88)
@export var border_color: Color = Color(0.22, 0.25, 0.32, 0.9)
@export var grid_color: Color = Color(0.3, 0.35, 0.45, 0.25)

#endregion

#region Core Drawing Logic

func _update_historical_min_max(new_data: PackedInt64Array) -> void:
    for val in new_data:
        if val > historical_max:
            historical_max = val
        if val < historical_min:
            historical_min = val

func _draw() -> void:
    var rect := Rect2(Vector2.ZERO, size)
    
    # 1. Background Panel & Outer Border
    if show_background:
        draw_rect(rect, bg_color)
        draw_rect(rect, border_color, false, 1.5)

    var margin_top: float = 32.0
    var margin_bottom: float = 14.0
    var margin_left: float = 12.0
    var margin_right: float = 12.0
    
    var font := ThemeDB.fallback_font
    var font_size := ThemeDB.fallback_font_size
    
    # 2. Header Title & Historical Peak Readouts
    var latest_val: int = data[-1] if not data.is_empty() else 0
    var header_text: String = ""
    
    var auto_bidirectional: bool = is_bidirectional or historical_min < 0
    
    if auto_bidirectional:
        var cur_str: String = ("+" if latest_val > 0 else "") + str(latest_val)
        header_text = "%s  |  Current: %s  |  Peak: +%d  |  Min: %d" % [title, cur_str, historical_max, historical_min]
    else:
        header_text = "%s  |  Current: %d  |  Peak: %d" % [title, latest_val, historical_max]
        
    draw_string(font, Vector2(margin_left, 22), header_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.9, 0.92, 0.96))

    # 3. Plot Area Geometry
    var plot_x: float = margin_left
    var plot_y: float = margin_top
    var plot_w: float = max(10.0, size.x - margin_left - margin_right)
    var plot_h: float = max(10.0, size.y - margin_top - margin_bottom)
    var plot_rect := Rect2(plot_x, plot_y, plot_w, plot_h)
    
    draw_rect(plot_rect, Color(0.04, 0.05, 0.07, 0.45))
    
    # 4. Slice Recent Points
    var display_data: PackedInt64Array = data
    if max_visible_points > 0 and data.size() > max_visible_points:
        display_data = data.slice(data.size() - max_visible_points)

    var total_bars: int = display_data.size()

    # Compute Highest Local Absolute Value across currently visible points
    var local_abs_max: int = 0
    for val in display_data:
        var a: int = abs(val)
        if a > local_abs_max:
            local_abs_max = a

    # 5. Handle Bidirectional / Zero-Centered Plot vs Standard Plot
    if auto_bidirectional:
        var zero_y: float = plot_y + (plot_h * 0.5)
        
        # Draw Zero Baseline
        draw_line(Vector2(plot_x, zero_y), Vector2(plot_x + plot_w, zero_y), Color(0.5, 0.55, 0.65, 0.6), 1.5)
        
        # Grid lines above and below zero
        draw_line(Vector2(plot_x, plot_y + plot_h * 0.25), Vector2(plot_x + plot_w, plot_y + plot_h * 0.25), grid_color, 1.0)
        draw_line(Vector2(plot_x, plot_y + plot_h * 0.75), Vector2(plot_x + plot_w, plot_y + plot_h * 0.75), grid_color, 1.0)

        if total_bars == 0:
            return

        # Scale height relative to the highest local absolute value
        var target_abs: int = local_abs_max if (use_local_visible_max and local_abs_max > 0) else max(abs(historical_max), abs(historical_min))
        var abs_scale: float = float(max(1, target_abs))
        
        var half_h: float = plot_h * 0.5
        var total_spacing: float = spacing * (total_bars - 1)
        var bar_w: float = max(1.0, (plot_w - total_spacing) / float(total_bars))
        
        for i in range(total_bars):
            var val: float = float(display_data[i])
            if val == 0.0:
                continue # Fix: Do not draw any bar for zero growth!
                
            var norm_h: float = clampf(abs(val) / abs_scale, 0.0, 1.0)
            var bar_h: float = max(2.0, norm_h * half_h)
            
            var bx: float = plot_x + i * (bar_w + spacing)
            var by: float = 0.0
            var c: Color = bar_color
            
            if val > 0:
                by = zero_y - bar_h
                c = bar_color
            else:
                by = zero_y
                c = negative_bar_color
                
            var bar_rect := Rect2(bx, by, bar_w, bar_h)
            draw_rect(bar_rect, c)
            
            var cap_y: float = by if val > 0 else by + bar_h
            draw_line(Vector2(bx, cap_y), Vector2(bx + bar_w, cap_y), c.lightened(0.35), 1.5)
    else:
        # Standard 0-to-Max Plot
        for step in [0.25, 0.50, 0.75]:
            var grid_y: float = plot_y + plot_h * (1.0 - step)
            draw_line(Vector2(plot_x, grid_y), Vector2(plot_x + plot_w, grid_y), grid_color, 1.0)

        if total_bars == 0:
            return

        var total_spacing: float = spacing * (total_bars - 1)
        var bar_w: float = max(1.0, (plot_w - total_spacing) / float(total_bars))
        var norm_max: float = float(max(1, local_abs_max if (use_local_visible_max and local_abs_max > 0) else historical_max))
        var highlight_color := bar_color.lightened(0.35)
        
        for i in range(total_bars):
            var val: float = float(display_data[i])
            if val <= 0.0:
                continue # Do not draw bars for 0 or negative values in standard plot
                
            var norm_h: float = clampf(val / norm_max, 0.0, 1.0)
            var bar_h: float = max(2.0, norm_h * plot_h)
            
            var bx: float = plot_x + i * (bar_w + spacing)
            var by: float = plot_y + plot_h - bar_h
            var bar_rect := Rect2(bx, by, bar_w, bar_h)
            
            draw_rect(bar_rect, bar_color)
            
            if bar_h > 3.0:
                draw_line(Vector2(bx, by), Vector2(bx + bar_w, by), highlight_color, 1.5)

#endregion
