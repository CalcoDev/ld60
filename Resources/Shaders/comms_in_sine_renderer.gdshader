shader_type canvas_item;
render_mode unshaded;

// mask + graph colors
uniform vec4 background_color : source_color = vec4(0.145098, 0.337255, 0.180392, 1.0); // #25562e
uniform vec4 wave1_color      : source_color = vec4(0.458824, 0.654902, 0.262745, 1.0); // #75a743
uniform vec4 wave2_color      : source_color = vec4(0.098039, 0.200000, 0.176471, 1.0); // #19332d

// size of the pixel graph area
uniform vec2 graph_size = vec2(41.0, 31.0);

// shared motion
uniform float scroll_speed : hint_range(-10.0, 10.0, 0.01) = 1.0;
uniform float phase_offset : hint_range(0.0, 6.28318, 0.01) = 0.0;

// vertical center of the graph, in pixel rows
uniform float center_y_px : hint_range(0.0, 31.0, 1.0) = 15.0;

// wave 1 (bright green)
uniform float wave1_frequency : hint_range(0.1, 20.0, 0.1) = 2.0;
uniform float wave1_amplitude_px : hint_range(0.0, 15.0, 0.1) = 5.0;
uniform float wave1_thickness_px : hint_range(1.0, 10.0, 1.0) = 3.0;

// wave 2 (dark green)
uniform float wave2_frequency : hint_range(0.1, 20.0, 0.1) = 4.0;
uniform float wave2_amplitude_px : hint_range(0.0, 15.0, 0.1) = 3.0;
uniform float wave2_thickness_px : hint_range(1.0, 10.0, 1.0) = 3.0;

float pixel_line(float py, float target_y, float thickness_px) {
    float half_w = max(0.0, (thickness_px - 1.0) * 0.5);
    return step(abs(py - target_y), half_w + 0.001);
}

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    // only render where texture is visible
    if (tex.a <= 0.0) {
        COLOR = vec4(0.0);
    } else {
        // snap to a 41x31 pixel grid
        vec2 cell = floor(UV * graph_size);

        // clamp so we stay inside valid pixel indices
        cell.x = clamp(cell.x, 0.0, graph_size.x - 1.0);
        cell.y = clamp(cell.y, 0.0, graph_size.y - 1.0);

        float px = cell.x;
        float py = cell.y;

        // normalized x across the graph
        float x = px / max(1.0, graph_size.x - 1.0);

        // shared phase -> both waves move together
        // positive speed here scrolls left visually
        float phase = TIME * scroll_speed * TAU + phase_offset;

        // wave positions in pixel-space
        float wave1_y = center_y_px - sin(x * wave1_frequency * TAU + phase) * wave1_amplitude_px;
        float wave2_y = center_y_px - sin(x * wave2_frequency * TAU + phase) * wave2_amplitude_px;

        // crisp pixel lines
        float line2 = pixel_line(py, wave2_y, wave2_thickness_px);
        float line1 = pixel_line(py, wave1_y, wave1_thickness_px);

        vec3 color = background_color.rgb;
        color = mix(color, wave2_color.rgb, line2);
        color = mix(color, wave1_color.rgb, line1);

        COLOR = vec4(color, tex.a) * COLOR;
    }
}