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
  float ripple = sin(uv.y * 18.0) * cos(uv.x * 14.0) * 0.012;
  vec2 lens = centered * (radial * 0.18 + 0.01) + vec2(ripple, -ripple);
  vec2 sample_uv = clamp(uv + lens * u_strength * (0.55 + edge), vec2(0.0), vec2(1.0));

  // A single linearly interpolated texture lookup keeps the live lens cheap;
  // hardware sampling softens the refracted image slightly without extra taps.
  frag_color = texture(u_backdrop, sample_uv);
}
