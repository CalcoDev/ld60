shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

uniform float progress : hint_range(0.0, 1.0) = 0.0;

uniform vec3 beam_color : source_color = vec3(0.46, 0.65, 0.26);

uniform float glow_strength : hint_range(0.0, 4.0) = 1.5;
uniform float flash_strength : hint_range(0.0, 4.0) = 1.5;
uniform float spark_strength : hint_range(0.0, 4.0) = 1.0;
uniform float distortion : hint_range(0.0, 3.0) = 1.0;

// Toggle palette quantization if wanted.
uniform bool use_apollo_quantization = true;

// Fixed virtual resolution for pixel-perfect sampling.
const vec2 PIXEL_RESOLUTION = vec2(184.0, 119.0);
const int SPARK_COUNT = 16;
const int APOLLO_COUNT = 46;


// --------------------------------------------------
// Utility
// --------------------------------------------------

float gauss(float x, float width) {
    float v = x / max(width, 0.00001);
    return exp(-v * v);
}

float hash1(float x) {
    return fract(sin(x * 127.1) * 43758.5453);
}


// --------------------------------------------------
// Apollo palette
// --------------------------------------------------

vec3 apollo_color(int i) {
    if (i == 0) return vec3(0.090196, 0.125490, 0.219608); // #172038
    if (i == 1) return vec3(0.145098, 0.227451, 0.368627); // #253a5e
    if (i == 2) return vec3(0.235294, 0.368627, 0.545098); // #3c5e8b
    if (i == 3) return vec3(0.309804, 0.560784, 0.729412); // #4f8fba
    if (i == 4) return vec3(0.450980, 0.745098, 0.827451); // #73bed3
    if (i == 5) return vec3(0.643137, 0.866667, 0.858824); // #a4dddb

    if (i == 6) return vec3(0.098039, 0.200000, 0.176471); // #19332d
    if (i == 7) return vec3(0.145098, 0.337255, 0.180392); // #25562e
    if (i == 8) return vec3(0.274510, 0.509804, 0.196078); // #468232
    if (i == 9) return vec3(0.458824, 0.654902, 0.262745); // #75a743
    if (i == 10) return vec3(0.658824, 0.792157, 0.345098); // #a8ca58
    if (i == 11) return vec3(0.815686, 0.854902, 0.568627); // #d0da91

    if (i == 12) return vec3(0.301961, 0.168627, 0.196078); // #4d2b32
    if (i == 13) return vec3(0.478431, 0.282353, 0.254902); // #7a4841
    if (i == 14) return vec3(0.678431, 0.466667, 0.341176); // #ad7757
    if (i == 15) return vec3(0.752941, 0.580392, 0.450980); // #c09473
    if (i == 16) return vec3(0.843137, 0.709804, 0.580392); // #d7b594
    if (i == 17) return vec3(0.905882, 0.835294, 0.701961); // #e7d5b3

    if (i == 18) return vec3(0.203922, 0.109804, 0.152941); // #341c27
    if (i == 19) return vec3(0.376471, 0.172549, 0.172549); // #602c2c
    if (i == 20) return vec3(0.533333, 0.294118, 0.168627); // #884b2b
    if (i == 21) return vec3(0.745098, 0.466667, 0.168627); // #be772b
    if (i == 22) return vec3(0.870588, 0.619608, 0.254902); // #de9e41
    if (i == 23) return vec3(0.909804, 0.756863, 0.439216); // #e8c170

    if (i == 24) return vec3(0.141176, 0.082353, 0.152941); // #241527
    if (i == 25) return vec3(0.254902, 0.113725, 0.192157); // #411d31
    if (i == 26) return vec3(0.458824, 0.141176, 0.219608); // #752438
    if (i == 27) return vec3(0.647059, 0.188235, 0.188235); // #a53030
    if (i == 28) return vec3(0.811765, 0.341176, 0.235294); // #cf573c
    if (i == 29) return vec3(0.854902, 0.525490, 0.243137); // #da863e

    if (i == 30) return vec3(0.117647, 0.113725, 0.223529); // #1e1d39
    if (i == 31) return vec3(0.250980, 0.152941, 0.317647); // #402751
    if (i == 32) return vec3(0.478431, 0.211765, 0.482353); // #7a367b
    if (i == 33) return vec3(0.635294, 0.243137, 0.549020); // #a23e8c
    if (i == 34) return vec3(0.776471, 0.317647, 0.592157); // #c65197
    if (i == 35) return vec3(0.874510, 0.517647, 0.647059); // #df84a5

    if (i == 36) return vec3(0.035294, 0.039216, 0.078431); // #090a14
    if (i == 37) return vec3(0.062745, 0.078431, 0.121569); // #10141f
    if (i == 38) return vec3(0.082353, 0.113725, 0.156863); // #151d28
    if (i == 39) return vec3(0.125490, 0.180392, 0.215686); // #202e37
    if (i == 40) return vec3(0.223529, 0.290196, 0.313725); // #394a50
    if (i == 41) return vec3(0.341176, 0.447059, 0.466667); // #577277

    if (i == 42) return vec3(0.505882, 0.592157, 0.588235); // #819796
    if (i == 43) return vec3(0.658824, 0.709804, 0.698039); // #a8b5b2
    if (i == 44) return vec3(0.780392, 0.811765, 0.800000); // #c7cfcc
    return vec3(0.921569, 0.929412, 0.913725); // #ebede9
}

vec3 quantize_to_apollo(vec3 color) {
    float best_dist = 1e20;
    vec3 best_color = apollo_color(0);

    for (int i = 0; i < APOLLO_COUNT; i++) {
        vec3 p = apollo_color(i);
        vec3 d = color - p;

        // Slight luminance weighting helps a bit visually.
        float dist = dot(d * vec3(1.0, 1.0, 1.0), d);

        if (dist < best_dist) {
            best_dist = dist;
            best_color = p;
        }
    }

    return best_color;
}


// --------------------------------------------------
// Main
// --------------------------------------------------

void fragment() {
    float t = clamp(progress, 0.0, 1.0);

    // Snap every fragment to the center of a
    // 184 x 119 virtual pixel cell.
    vec2 pixel_coord = floor(UV * PIXEL_RESOLUTION);
    vec2 uv = (pixel_coord + vec2(0.5)) / PIXEL_RESOLUTION;

    float aspect = PIXEL_RESOLUTION.x / PIXEL_RESOLUTION.y;
    float px = 1.0 / PIXEL_RESOLUTION.y;

    vec2 p = vec2(
        (uv.x - 0.5) * aspect,
        uv.y - 0.5
    );

    float x = uv.x * 2.0 - 1.0;

    // 0 -> fully open
    // 0.5 -> collapsed
    // 1 -> fully open
    float openness = abs(t * 2.0 - 1.0);
    float collapse = 1.0 - openness;

    // -----------------------------------------
    // 1. CRT VERTICAL COLLAPSE
    // -----------------------------------------

    float curve = 0.018 * x * x * collapse * distortion;

    float jitter_seed = floor(t * 240.0);
    float jitter = (hash1(jitter_seed) - 0.5)
        * 0.006 * collapse * collapse * distortion;

    float wobble = sin(x * 42.0 + t * 90.0)
        * 0.0018 * collapse * collapse * distortion;

    float y = p.y + curve + jitter + wobble;

    float vertical_open = smoothstep(0.06, 1.0, openness);
    float half_opening = 0.55 * vertical_open;

    float shutter = smoothstep(
        half_opening - 2.0 * px,
        half_opening + 2.0 * px,
        abs(y)
    );

    float sealed = 1.0 - smoothstep(0.0, 0.055, openness);
    shutter = max(shutter, sealed);

    // -----------------------------------------
    // 2. HORIZONTAL BEAM COLLAPSE
    // -----------------------------------------

    float beam_phase = smoothstep(0.58, 0.90, collapse);

    float line_length = smoothstep(0.0, 0.09, openness);
    float line_half = (aspect * 0.5 + 0.03) * line_length;

    float line_mask = 1.0 - smoothstep(
        line_half - 0.012,
        line_half + 0.012,
        abs(p.x)
    );

    float beam_noise = 0.78 + 0.22 * hash1(
        pixel_coord.x + floor(t * 210.0) * 13.0
    );

    float beam_base = line_mask * beam_phase * beam_noise;

    float beam_core = gauss(y, max(px * 1.3, 0.0015)) * beam_base;
    float beam_inner = gauss(y, 0.009) * beam_base;
    float beam_outer = gauss(y, 0.045) * beam_base;

    // -----------------------------------------
    // 3. PHOSPHOR FLASH
    // -----------------------------------------

    float flash = gauss(t - 0.5, 0.038);
    float afterglow = gauss(t - 0.5, 0.075);

    float center_dot = gauss(length(p), 0.030) * afterglow;

    float horizontal_flare =
        gauss(p.y, 0.007) *
        gauss(p.x, 0.32) *
        afterglow;

    float vertical_flare =
        gauss(p.x, 0.008) *
        gauss(p.y, 0.14) *
        afterglow;

    float radial_flash = gauss(length(p), 0.37) * flash;

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
            vec2 dir = vec2(cos(angle), sin(angle));

            float birth = 0.487 + hash1(seed * 9.3) * 0.055;
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

                float trail = smoothstep(
                    -trail_length,
                    -trail_length * 0.5,
                    along
                );

                trail *= 1.0 - smoothstep(0.0, 0.005, along);

                float thin = gauss(
                    across,
                    max(px * 1.2, 0.0015)
                );

                float head = gauss(
                    length(delta),
                    max(px * 2.2, 0.003)
                );

                float life = 1.0 - smoothstep(0.45, 1.0, age);

                sparks += (
                    head * 1.2 +
                    trail * thin * 0.7
                ) * life;
            }
        }
    }

    // -----------------------------------------
    // 6. COMPOSITE
    // -----------------------------------------

    vec3 color = vec3(0.0);

    color += beam_color * (
        beam_outer * 0.55 +
        beam_inner * 0.8 +
        beam_core * 1.25
    ) * glow_strength;

    color += vec3(1.0, 1.0, 0.9)
        * beam_core * 0.85 * glow_strength;

    color += beam_color
        * sparks * 1.4 * spark_strength;

    color += vec3(1.0, 1.0, 0.85)
        * sparks * 0.65 * spark_strength;

    color += beam_color
        * shockwave * 0.65 * glow_strength;

    color += beam_color
        * center_dot * 2.0 * flash_strength;

    color += vec3(1.0, 1.0, 0.9) * (
        center_dot * 1.6 +
        horizontal_flare * 0.75 +
        vertical_flare * 0.45 +
        radial_flash * 0.65 +
        flash * 0.12
    ) * flash_strength;

    float brightness = max(max(color.r, color.g), color.b);

    float alpha = max(
        shutter,
        clamp(brightness, 0.0, 1.0)
    );

    // Clamp before palette mapping.
    color = clamp(color, vec3(0.0), vec3(1.0));

    if (use_apollo_quantization && alpha > 0.0) {
        color = quantize_to_apollo(color);
    }

    // Premultiply for blend_premul_alpha.
    COLOR = vec4(color * alpha, alpha);
}