#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform sampler2D u_backdrop;
uniform float u_strength;

out vec4 frag_color;

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif

  // Refract toward the center with a subtle lens field and fine optical ripple.
  vec2 centered = uv - vec2(0.5);
  float radial = dot(centered, centered);
  float edge = smoothstep(0.12, 0.48, radial);
  // Keep the lens close to its source pixel. Large offsets turn nearby text
  // into visible ghost trails instead of a subtle glass highlight.
  float ripple = sin(uv.y * 18.0) * cos(uv.x * 14.0) * 0.003;
  vec2 lens = centered * (radial * 0.08 + 0.004) + vec2(ripple, -ripple);
  vec2 sample_uv = clamp(uv + lens * u_strength * (0.24 + edge * 0.16), vec2(0.0), vec2(1.0));

  // Keep the centre readable and add only a small edge frost. Three taps are
  // enough to soften the curved rim without creating a second backdrop pass.
  vec4 centre = texture(u_backdrop, sample_uv);
  vec2 texel = 1.0 / u_size;
  float blur = edge * 1.35;
  vec4 side_a = texture(u_backdrop, clamp(sample_uv + vec2(texel.x * blur, 0.0), vec2(0.0), vec2(1.0)));
  vec4 side_b = texture(u_backdrop, clamp(sample_uv - vec2(texel.x * blur, 0.0), vec2(0.0), vec2(1.0)));
  frag_color = mix(centre, (centre * 0.52 + side_a * 0.24 + side_b * 0.24), edge * 0.62);
}
