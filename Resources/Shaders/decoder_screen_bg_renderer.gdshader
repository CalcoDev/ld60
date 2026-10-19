
shader_type canvas_item;
render_mode unshaded;

uniform vec4 background_color : source_color = vec4(0.145098, 0.227451, 0.368627, 1.0); // #253a5e
uniform vec4 line_color : source_color = vec4(0.090196, 0.125490, 0.219608, 1.0); // #172038

uniform vec2 graph_size = vec2(41.0, 31.0);

// Animation
uniform float bpm : hint_range(0.0, 300.0, 1.0) = 120.0;

// Lines
uniform float line_spacing_px : hint_range(1.0, 32.0, 1.0) = 6.0;
uniform float line_thickness_px : hint_range(1.0, 16.0, 1.0) = 2.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    // Snap to pixel grid
    vec2 cell = floor(UV * graph_size);
    cell = clamp(cell, vec2(0.0), graph_size - vec2(1.0));

    // Each beat advances by one line spacing.
    float beats = TIME * bpm / 60.0;
    float scroll_px = floor(beats * line_spacing_px);

    // Repeating horizontal stripes, moving downward
    float spacing = max(line_spacing_px, 1.0);
    float stripe = mod(cell.y - scroll_px, spacing);

    float line = 1.0 - step(line_thickness_px, stripe);

    vec3 color = mix(
        background_color.rgb,
        line_color.rgb,
        line
    );

    // Preserve original texture alpha
    COLOR = vec4(color, tex.a);
}
