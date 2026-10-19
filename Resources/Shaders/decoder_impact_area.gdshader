shader_type canvas_item;
render_mode unshaded;

// Pixel grid
uniform vec2 graph_size = vec2(14.0, 24.0);

// Bar placement
uniform float bar_width_px : hint_range(1.0, 64.0, 1.0) = 6.0;
uniform float bar_center_x_px : hint_range(0.0, 64.0, 1.0) = 7.0;

// Colors
uniform vec4 bottom_color : source_color = vec4(0.921569, 0.929412, 0.913725, 1.0); // #ebede9
uniform vec4 top_color : source_color = vec4(1.0, 0.713725, 0.117647, 1.0); // #ffb61e
uniform vec4 background_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);

// Gradient
// 0.5 = linear
// < 0.5 = transition happens closer to bottom
// > 0.5 = transition happens closer to top
uniform float gradient_midpoint : hint_range(0.01, 0.99, 0.01) = 0.5;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    // Snap to pixel grid
    vec2 cell = floor(UV * graph_size);
    cell = clamp(cell, vec2(0.0), graph_size - vec2(1.0));

    float px = cell.x;
    float py = cell.y;

    // Bar bounds
    float left_x = floor(bar_center_x_px - floor(bar_width_px * 0.5));
    float right_x = left_x + bar_width_px - 1.0;

    float inside_bar = step(left_x, px) * step(px, right_x);

    // Normalized vertical position: bottom = 0, top = 1
    float t = 1.0 - py / max(graph_size.y - 1.0, 1.0);

    // Nonlinear gradient with adjustable midpoint
    float midpoint = clamp(gradient_midpoint, 0.01, 0.99);
    float exponent = log(0.5) / log(midpoint);
    t = pow(t, exponent);

    // Final color
    vec4 bar_color = mix(bottom_color, top_color, t);
    vec4 final_color = mix(background_color, bar_color, inside_bar);

    // Preserve original texture transparency
    COLOR = vec4(final_color.rgb, final_color.a * tex.a);
}
