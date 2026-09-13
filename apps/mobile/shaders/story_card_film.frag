#version 320 es

#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform sampler2D u_texture;
uniform vec2 u_origin;
uniform vec2 u_uv_scale;
uniform vec2 u_uv_offset;
uniform float u_rotation;
uniform float u_background_r;
uniform float u_background_g;
uniform float u_background_b;
uniform float u_exposure;
uniform float u_contrast;
uniform float u_saturation;
uniform float u_temperature;
uniform float u_tint;
uniform float u_fade;
uniform float u_grain;
uniform float u_softness;
uniform float u_bloom;
uniform float u_vignette;
uniform float u_shadow_teal;
uniform float u_highlight_warmth;
uniform float u_seed;

out vec4 frag_color;

float luminance(vec3 color) {
  return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

float random_noise(vec2 position) {
  vec2 seed_offset = vec2(u_seed * 127.1, u_seed * 311.7);
  return fract(sin(dot(position + seed_offset, vec2(12.9898, 78.233))) * 43758.5453);
}

bool outside_image(vec2 uv) {
  return uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0;
}

vec3 sample_image(vec2 uv, vec3 background) {
  return outside_image(uv) ? background : texture(u_texture, uv).rgb;
}

void main() {
  vec2 local_uv = (FlutterFragCoord().xy - u_origin) / u_size;
#ifdef IMPELLER_TARGET_OPENGLES
  local_uv.y = 1.0 - local_uv.y;
#endif
  vec2 pan = (vec2(0.5) * (vec2(1.0) - u_uv_scale) - u_uv_offset) /
      max(u_uv_scale, vec2(0.0001));
  vec2 centered = local_uv - vec2(0.5) - pan;
  float rotation_cos = cos(u_rotation);
  float rotation_sin = sin(u_rotation);
  vec2 unrotated = vec2(
    rotation_cos * centered.x + rotation_sin * centered.y,
    -rotation_sin * centered.x + rotation_cos * centered.y
  );
  vec2 uv = unrotated * u_uv_scale + vec2(0.5);
  vec3 background = vec3(u_background_r, u_background_g, u_background_b);
  if (outside_image(uv)) {
    frag_color = vec4(background, 1.0);
    return;
  }

  vec2 texel = u_uv_scale / max(u_size, vec2(1.0));
  vec3 center = texture(u_texture, uv).rgb;
  vec3 neighbors =
      sample_image(uv + vec2(texel.x, 0.0), background) +
      sample_image(uv - vec2(texel.x, 0.0), background) +
      sample_image(uv + vec2(0.0, texel.y), background) +
      sample_image(uv - vec2(0.0, texel.y), background);
  vec3 softened = center * 0.5 + neighbors * 0.125;
  vec3 color = mix(center, softened, u_softness);

  vec3 bloom_source = max(softened - vec3(0.62), vec3(0.0));
  color += bloom_source * u_bloom * vec3(1.12, 0.96, 0.78);
  color *= exp2(u_exposure);

  color.r += u_temperature * 0.055 + u_tint * 0.018;
  color.g += u_temperature * 0.012 - u_tint * 0.035;
  color.b -= u_temperature * 0.050 - u_tint * 0.018;

  float tone_luma = luminance(color);
  float shadow_mask = 1.0 - smoothstep(0.12, 0.62, tone_luma);
  float highlight_mask = smoothstep(0.48, 0.96, tone_luma);
  color += shadow_mask * u_shadow_teal * vec3(-0.030, 0.018, 0.035);
  color += highlight_mask * u_highlight_warmth * vec3(0.035, 0.012, -0.026);

  color = (color - vec3(0.5)) * u_contrast + vec3(0.5);
  float adjusted_luma = luminance(color);
  color = mix(vec3(adjusted_luma), color, u_saturation);
  color = mix(color, color * 0.88 + vec3(0.055), u_fade);

  float edge = smoothstep(0.35, 0.78, distance(local_uv, vec2(0.5)));
  color *= 1.0 - edge * u_vignette;

  float grain_weight = mix(1.25, 0.65, clamp(adjusted_luma, 0.0, 1.0));
  float grain = random_noise(floor(FlutterFragCoord().xy)) - 0.5;
  color += grain * u_grain * 0.14 * grain_weight;

  frag_color = vec4(clamp(color, 0.0, 1.0), 1.0);
}
