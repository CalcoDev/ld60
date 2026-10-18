
shader_type canvas_item;

varying vec4 canvas_modulate;

uniform vec2 drag_grab_uv = vec2(0.5);
uniform vec2 drag_skew = vec2(0.0);
uniform vec2 drag_perspective = vec2(0.0);
uniform vec2 drag_vertex_origin = vec2(0.0);
uniform vec2 drag_module_size = vec2(1.0);


void vertex() {
    vec2 module_uv =
        (VERTEX + drag_vertex_origin) / max(drag_module_size, vec2(1.0));
    vec2 from_grab = module_uv - drag_grab_uv;
    vec2 skew_offset = vec2(
        from_grab.y * drag_skew.x,
        from_grab.x * drag_skew.y
    );
    vec2 corner_offset =
        drag_perspective * from_grab.x * from_grab.y;

    VERTEX += skew_offset + corner_offset;
    canvas_modulate = COLOR;
}

// colors
uniform vec4 shadow_near : source_color =
    vec4(0.08235, 0.11373, 0.15686, 1.0); // #151d28

uniform vec4 shadow_middle : source_color =
    vec4(0.06275, 0.07843, 0.12157, 1.0); // #10141f

uniform vec4 shadow_outer : source_color =
    vec4(0.0, 0.0, 0.0, 1.0);

uniform vec4 outline_color : source_color =
    vec4(0.0, 0.0, 0.0, 1.0);


// outline
uniform bool enable_outline = true;
uniform bool outline_diagonals = true;


// shadows
uniform bool enable_shadow = true;

// Horizontal shadow grows towards screen edges.
uniform int min_shadow_x : hint_range(0, 8, 1) = 0;
uniform int max_shadow_x : hint_range(0, 8, 1) = 5;

// Vertical shadow grows towards screen bottom.
uniform int min_shadow_y : hint_range(0, 8, 1) = 2;
uniform int max_shadow_y : hint_range(0, 8, 1) = 5;

// If true, horizontal shadow points away from center.
// Otherwise, it always points right.
uniform bool horizontal_outward = true;


// position through gdscript
uniform vec2 screen_center_uv = vec2(0.5, 0.5);
uniform vec2 object_size_uv = vec2(0.2, 0.2);


// noise
uniform float alpha_threshold :
    hint_range(0.0, 1.0) = 0.1;

uniform float noise_amount :
    hint_range(0.0, 1.0) = 1.0;

uniform float noise_scale :
    hint_range(0.01, 1.0) = 0.08;

uniform float shadow_opacity :
    hint_range(0.0, 1.0) = 1.0;


const int MAX_RADIUS = 8;


// noise funcs
float hash(vec2 p) {
    return fract(
        sin(dot(p, vec2(127.1, 311.7)))
        * 43758.5453123
    );
}

float value_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(
        mix(a, b, u.x),
        mix(c, d, u.x),
        u.y
    );
}


// shadow ramp

// 0: no shadow
// 1: near color
// 2: middle color
// 3: outer black
// outermost pixel is grade 3.
int ramp_grade(int distance, int extent, int near_width) {
    if (distance <= 0 || extent <= 0) {
        return 0;
    }

    if (distance >= extent) {
        return 3;
    }

    if (distance <= near_width) {
        return 1;
    }

    return 2;
}


void fragment() {
    // Pixel-aligned UV.
    vec2 pixel = floor(UV / TEXTURE_PIXEL_SIZE);
    vec2 pixel_uv =
        (pixel + vec2(0.5)) * TEXTURE_PIXEL_SIZE;

    vec4 original = texture(TEXTURE, pixel_uv);

    // Original sprite always takes priority.
    if (original.a > alpha_threshold) {
        COLOR = original;
    } else {
        // normal always outline
        bool is_outline = false;

        if (enable_outline) {
            for (int oy = -1; oy <= 1; oy++) {
                for (int ox = -1; ox <= 1; ox++) {
                    if (ox == 0 && oy == 0) {
                        continue;
                    }

                    if (!outline_diagonals &&
                        abs(ox) + abs(oy) != 1) {
                        continue;
                    }

                    vec2 sample_uv = pixel_uv
                        + vec2(float(ox), float(oy))
                        * TEXTURE_PIXEL_SIZE;

                    if (
                        sample_uv.x < 0.0 ||
                        sample_uv.y < 0.0 ||
                        sample_uv.x >= 1.0 ||
                        sample_uv.y >= 1.0
                    ) {
                        continue;
                    }

                    if (texture(TEXTURE, sample_uv).a
                        > alpha_threshold) {
                        is_outline = true;
                    }
                }
            }
        }

        // pos based shadow size
        float available_x = max(
            0.0001,
            1.0 - object_size_uv.x
        );

        float available_y = max(
            0.0001,
            1.0 - object_size_uv.y
        );

        float x_strength = clamp(
            abs(screen_center_uv.x - 0.5)
            * 2.0 / available_x,
            0.0, 1.0
        );

        float y_strength = clamp(
            (screen_center_uv.y
            - object_size_uv.y * 0.5)
            / available_y,
            0.0, 1.0
        );

        int sx = clamp(
            int(round(mix(
                float(min_shadow_x),
                float(max_shadow_x),
                x_strength
            ))),
            0, MAX_RADIUS
        );

        int sy = clamp(
            int(round(mix(
                float(min_shadow_y),
                float(max_shadow_y),
                y_strength
            ))),
            0, MAX_RADIUS
        );

        float direction_x = 1.0;

        if (horizontal_outward) {
            direction_x =
                screen_center_uv.x < 0.5 ? -1.0 : 1.0;
        }

        // noise band ditribution
        float n = value_noise(
            pixel * noise_scale
        );

        int variation = int(round(
            (n - 0.5) * 2.0 * noise_amount
        ));

        int near_x = 1;
        int near_y = 1;

        if (sx >= 3) {
            near_x = clamp(
                int(round(float(sx - 1) * 0.5))
                + variation,
                1,
                sx - 2
            );
        }

        if (sy >= 3) {
            near_y = clamp(
                int(round(float(sy - 1) * 0.5))
                + variation,
                1,
                sy - 2
            );
        }

        // shadow silhoutte
        int shadow_grade = 0;
        float closest_distance = 1e20;

        // Skip shadow work for outline pixels.
        // This ensures the black outline is
        // NEVER drawn twice.
        if (enable_shadow && !is_outline) {

            // Sample original sprite in the
            // opposite direction of the shadow.
            for (int y = 0; y <= MAX_RADIUS; y++) {
                if (y > sy) {
                    break;
                }

                for (int x = 0; x <= MAX_RADIUS; x++) {
                    if (x > sx) {
                        break;
                    }

                    if (x == 0 && y == 0) {
                        continue;
                    }

                    vec2 offset = vec2(
                        direction_x * float(x),
                        float(y)
                    );

                    vec2 sample_uv = pixel_uv
                        - offset * TEXTURE_PIXEL_SIZE;

                    if (
                        sample_uv.x < 0.0 ||
                        sample_uv.y < 0.0 ||
                        sample_uv.x >= 1.0 ||
                        sample_uv.y >= 1.0
                    ) {
                        continue;
                    }

                    float a =
                        texture(TEXTURE, sample_uv).a;

                    if (a <= alpha_threshold) {
                        continue;
                    }

                    // Select nearest opaque source
                    // to prevent farther source
                    // pixels overriding the ramp.
                    float dist = float(x*x + y*y);

                    if (dist < closest_distance) {
                        closest_distance = dist;

                        int gx = ramp_grade(
                            x, sx, near_x
                        );

                        int gy = ramp_grade(
                            y, sy, near_y
                        );

                        shadow_grade = max(gx, gy);
                    }
                }
            }
        }

        // COMPOSE FINAL!!!!
        // One outline pixel, always black.
        if (is_outline) {
            COLOR = outline_color;

        } else if (shadow_grade == 1) {
            COLOR = vec4(
                shadow_near.rgb,
                shadow_near.a * shadow_opacity
            );

        } else if (shadow_grade == 2) {
            COLOR = vec4(
                shadow_middle.rgb,
                shadow_middle.a * shadow_opacity
            );

        } else if (shadow_grade == 3) {
            COLOR = vec4(
                shadow_outer.rgb,
                shadow_outer.a * shadow_opacity
            );

        } else {
            COLOR = vec4(0.0);
        }
    }

    COLOR *= canvas_modulate;
}
