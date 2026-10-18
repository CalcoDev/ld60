
shader_type canvas_item;

uniform vec4 background_color : source_color = vec4(0.08235, 0.11373, 0.15686, 1.0); // #151d28
uniform vec4 line_color : source_color = vec4(0.12549, 0.18039, 0.21569, 1.0); // #202e37

uniform vec2 rect_size = vec2(640.0, 320.0);

uniform vec2 origin_uv = vec2(0.5, 1.0);

uniform float line_width : hint_range(1.0, 8.0, 1.0) = 1.0;

// grid
uniform bool show_grid = true;

uniform vec4 grid_color : source_color =
    vec4(0.102, 0.145, 0.188, 1.0); // #1a2530

// Cell width and height, in pixels.
uniform vec2 grid_cell_size = vec2(8.0, 8.0);

// Offset grid origin in pixels.
uniform vec2 grid_offset = vec2(0.0, 0.0);

uniform float grid_line_width :
    hint_range(1.0, 8.0, 1.0) = 1.0;


// Radial
uniform bool show_radial = true;
uniform int radial_divisions : hint_range(2, 64) = 16;

// Scrolling parallel
uniform bool show_parallel = true;
uniform float parallel_spacing : hint_range(4.0, 128.0) = 32.0;
uniform float parallel_speed : hint_range(-200.0, 200.0) = 20.0;

// circular lines
uniform bool show_arcs = false;
uniform float arc_spacing : hint_range(8.0, 128.0) = 48.0;
uniform float arc_speed : hint_range(-200.0, 200.0) = 20.0;

// vertical grid
uniform bool show_vertical = true;
uniform float vertical_spacing : hint_range(4.0, 128.0) = 32.0;
uniform float vertical_speed : hint_range(-200.0, 200.0) = 20.0;
uniform bool vertical_outward = true;


// Returns 1 when inside a repeating line.
float stripe(float position, float spacing, float thickness) {
    float d = abs(
        mod(position + spacing * 0.5, spacing)
        - spacing * 0.5
    );

    return 1.0 - step(thickness * 0.5, d);
}

void fragment() {
    // Snap samples to logical pixels.
    vec2 pixel = floor(UV * rect_size) + vec2(0.5);
    vec2 origin = origin_uv * rect_size;

    // Y points upward from the origin.
    vec2 delta = vec2(
        pixel.x - origin.x,
        origin.y - pixel.y
    );

    float radius = length(delta);
    float angle = atan(delta.y, delta.x);

    float grid_mask = 0.0;

    if (show_grid) {
        vec2 cell_size = max(
            grid_cell_size,
            vec2(1.0)
        );

        // Subtract 0.5 to align grid lines with
        // logical pixel centers at integer offsets.
        vec2 grid_pos = pixel - grid_offset - vec2(0.5);

        float gx = stripe(
            grid_pos.x,
            cell_size.x,
            grid_line_width
        );

        float gy = stripe(
            grid_pos.y,
            cell_size.y,
            grid_line_width
        );

        // Combine horizontal and vertical lines.
        grid_mask = max(gx, gy);
    }

    // Start with the background + grid.
    vec4 base_color = mix(
        background_color,
        grid_color,
        grid_mask
    );

    float mask = 0.0;

    if (show_radial) {
        float angle_step = PI / float(radial_divisions);
        float nearest_angle = round(angle / angle_step) * angle_step;

        // Perpendicular distance to nearest radial line.
        float distance_to_ray =
            abs(sin(angle - nearest_angle)) * radius;

        float rays = 1.0 - step(
            line_width * 0.5,
            distance_to_ray
        );

        mask = max(mask, rays);
    }

    if (show_parallel) {
        // NOTE(calco): Stupid no perspective just go up lines.
        //float distance_up = origin.y - pixel.y;
        //
        //float lines = stripe(
            //distance_up - TIME * parallel_speed,
            //parallel_spacing,
            //line_width
        //);
        //
        //mask = max(mask, lines);
        
        // NOTE(calco): Perspective ahhh lines?
        float distance_up = max(origin.y - pixel.y, 0.0);
        // More tightly packed near the origin.
        float perspective = 0.04;
        float depth = log(1.0 + distance_up * perspective);
        float period = log(1.0 + parallel_spacing * perspective);
        float phase = depth - TIME * parallel_speed * 0.01;
        // Convert back to pixel-space distance for consistent width.
        float nearest = round(phase / period) * period;
        float distance_to_line =
            abs(phase - nearest) *
            (1.0 + distance_up * perspective) / perspective;
        float lines = 1.0 - step(
            line_width * 0.5,
            distance_to_line
        );

        mask = max(mask, lines);
    }

    if (show_arcs) {
        float arcs = stripe(
            radius - TIME * arc_speed,
            arc_spacing,
            line_width
        );

        mask = max(mask, arcs);
    }

    if (show_vertical) {
        float distance_x = pixel.x - origin.x;

        // Mirrored outward motion from the center,
        // or uniform horizontal scrolling.
        if (vertical_outward) {
            distance_x = abs(distance_x);
        }

        float verticals = stripe(
            distance_x - TIME * vertical_speed,
            vertical_spacing,
            line_width
        );

        mask = max(mask, verticals);
    }

    COLOR = mix(base_color, line_color, mask);
}
