
shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

uniform float progress : hint_range(0.0, 1.0) = 0.0;

uniform vec3 beam_color : source_color = vec3(0.46, 0.65, 0.26);

uniform float glow_strength : hint_range(0.0, 4.0) = 1.5;
uniform float flash_strength : hint_range(0.0, 4.0) = 1.5;
uniform float spark_strength : hint_range(0.0, 4.0) = 1.0;
uniform float distortion : hint_range(0.0, 3.0) = 1.0;

const int SPARK_COUNT = 16;


// Utility functions

float gauss(float x, float width) {
    float v = x / max(width, 0.00001);
    return exp(-v * v);
}

float hash1(float x) {
    return fract(sin(x * 127.1) * 43758.5453);
}


void fragment() {
    float t = clamp(progress, 0.0, 1.0);

    // 0 -> fully open
    // 0.5 -> collapsed
    // 1 -> fully open

    float openness = abs(t * 2.0 - 1.0);
    float collapse = 1.0 - openness;

    float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
    float px = SCREEN_PIXEL_SIZE.y;

    vec2 p = vec2(
        (UV.x - 0.5) * aspect,
        UV.y - 0.5
    );

    float x = UV.x * 2.0 - 1.0;

    // -----------------------------------------
    // 1. CRT VERTICAL COLLAPSE
    // -----------------------------------------

    // Curvature, increasing as the screen shuts down.
    float curve = 0.018 * x * x * collapse * distortion;

    // Small electrical jitter.
    float jitter_seed = floor(t * 240.0);
    float jitter = (hash1(jitter_seed) - 0.5)
        * 0.006 * collapse * collapse * distortion;

    float wobble = sin(x * 42.0 + t * 90.0)
        * 0.0018 * collapse * collapse * distortion;

    float y = p.y + curve + jitter + wobble;

    // Shutter closes before the beam contracts horizontally.
    float vertical_open = smoothstep(0.06, 1.0, openness);
    float half_opening = 0.55 * vertical_open;

    float shutter = smoothstep(
        half_opening - 2.0 * px,
        half_opening + 2.0 * px,
        abs(y)
    );

    // Guarantee a completely opaque screen at midpoint.
    float sealed = 1.0 - smoothstep(0.0, 0.055, openness);
    shutter = max(shutter, sealed);


    // -----------------------------------------
    // 2. HORIZONTAL BEAM COLLAPSE
    // -----------------------------------------

    float beam_phase = smoothstep(0.58, 0.90, collapse);

    // As the center approaches, the horizontal
    // beam shrinks into a single bright point.
    float line_length = smoothstep(0.0, 0.09, openness);
    float line_half = (aspect * 0.5 + 0.03) * line_length;

    float line_mask = 1.0 - smoothstep(
        line_half - 0.012,
        line_half + 0.012,
        abs(p.x)
    );

    float beam_noise = 0.78 + 0.22 * hash1(
        floor(UV.x * 320.0) + floor(t * 210.0) * 13.0
    );

    float beam_base = line_mask * beam_phase * beam_noise;

    // Multiple layers of fake bloom.
    float beam_core = gauss(y, max(px * 1.3, 0.0015))
        * beam_base;

    float beam_inner = gauss(y, 0.009)
        * beam_base;

    float beam_outer = gauss(y, 0.045)
        * beam_base;


    // -----------------------------------------
    // 3. PHOSPHOR FLASH
    // -----------------------------------------

    float flash = gauss(t - 0.5, 0.038);
    float afterglow = gauss(t - 0.5, 0.075);

    // Central bright point.
    float center_dot = gauss(length(p), 0.030)
        * afterglow;

    // Horizontal lens flare.
    float horizontal_flare =
        gauss(p.y, 0.007) *
        gauss(p.x, 0.32) *
        afterglow;

    // Vertical glint.
    float vertical_flare =
        gauss(p.x, 0.008) *
        gauss(p.y, 0.14) *
        afterglow;

    // Large soft illumination.
    float radial_flash =
        gauss(length(p), 0.37) * flash;


    // -----------------------------------------
    // 4. EXPANDING SHOCKWAVE
    // -----------------------------------------

    float shockwave = 0.0;
    float shock_age = (t - 0.5) / 0.22;

    if (shock_age >= 0.0 && shock_age <= 1.0) {
        float radius = 0.025 + shock_age * 0.75;

        shockwave = gauss(
            length(p) - radius,
            0.012 + shock_age * 0.008
        );

        shockwave *= (1.0 - shock_age);
    }


    // -----------------------------------------
    // 5. PROCEDURAL ELECTRICAL SPARKS
    // -----------------------------------------

    float sparks = 0.0;

    if (t > 0.48 && t < 0.76) {
        for (int i = 0; i < SPARK_COUNT; i++) {
            float seed = float(i) + 1.0;

            float angle = hash1(seed * 2.17) * TAU;

            vec2 dir = vec2(
                cos(angle),
                sin(angle)
            );

            // Stagger individual spark births.
            float birth = 0.487
                + hash1(seed * 9.3) * 0.055;

            float age = (t - birth) / 0.17;

            if (age >= 0.0 && age < 1.0) {
                float speed = mix(
                    0.15,
                    0.8,
                    hash1(seed * 3.47)
                );

                vec2 spark_pos = dir * age * speed;
                vec2 delta = p - spark_pos;

                vec2 tangent = vec2(-dir.y, dir.x);

                float along = dot(delta, dir);
                float across = dot(delta, tangent);

                float trail_length = mix(
                    0.015,
                    0.075,
                    hash1(seed * 5.12)
                );

                // Tapered trail behind moving spark.
                float trail = smoothstep(
                    -trail_length,
                    -trail_length * 0.5,
                    along
                );

                trail *= 1.0 - smoothstep(
                    0.0, 0.005, along
                );

                float thin = gauss(
                    across,
                    max(px * 1.2, 0.0015)
                );

                // Bright leading particle.
                float head = gauss(
                    length(delta),
                    max(px * 2.2, 0.003)
                );

                float life = 1.0 - smoothstep(
                    0.45, 1.0, age
                );

                sparks += (
                    head * 1.2 +
                    trail * thin * 0.7
                ) * life;
            }
        }
    }


    // -----------------------------------------
    // 6. COMPOSITE EVERYTHING
    // -----------------------------------------

    vec3 color = vec3(0.0);

    // Green phosphor glow.
    color += beam_color * (
        beam_outer * 0.55 +
        beam_inner * 0.8 +
        beam_core * 1.25
    ) * glow_strength;

    // Hot, nearly white core.
    color += vec3(1.0, 1.0, 0.9)
        * beam_core * 0.85 * glow_strength;

    // Sparks.
    color += beam_color
        * sparks * 1.4 * spark_strength;

    color += vec3(1.0, 1.0, 0.85)
        * sparks * 0.65 * spark_strength;

    // Shockwave.
    color += beam_color
        * shockwave * 0.65 * glow_strength;

    // Central flash.
    color += beam_color
        * center_dot * 2.0 * flash_strength;

    color += vec3(1.0, 1.0, 0.9) * (
        center_dot * 1.6 +
        horizontal_flare * 0.75 +
        vertical_flare * 0.45 +
        radial_flash * 0.65 +
        flash * 0.12
    ) * flash_strength;

    // Premultiplied-alpha composition allows
    // bright additive emission over a black shutter.
    float brightness = max(
        max(color.r, color.g),
        color.b
    );

    float alpha = max(
        shutter,
        clamp(brightness, 0.0, 1.0)
    );

    COLOR = vec4(color, alpha);
}
