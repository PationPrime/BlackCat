// The lava lamp of the app background: soft blobs that merge where they
// meet. The blob field is drawn into a small offscreen image, so the
// fragment coordinates are its pixels on every graphics backend
#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

// Size of the image in pixels
uniform vec2 uSize;

// Seconds of motion: the lava wobbles and changes its tint with them
uniform float uTime;

// Blobs: x and y in heights of the image, radius in heights, weight
uniform vec4 uBlob0;
uniform vec4 uBlob1;
uniform vec4 uBlob2;
uniform vec4 uBlob3;
uniform vec4 uBlob4;
uniform vec4 uBlob5;

// Background, the glow around the lava, its body, its thick middle
// and the thickest places
uniform vec3 uBase;
uniform vec3 uHaze;
uniform vec3 uBody;
uniform vec3 uCore;
uniform vec3 uDeep;

out vec4 fragColor;

float blob(vec2 point, vec4 blob) {
  vec2 delta = point - blob.xy;

  return blob.w * exp(-dot(delta, delta) / (blob.z * blob.z));
}

float field(vec2 point) {
  return blob(point, uBlob0) + blob(point, uBlob1) + blob(point, uBlob2) +
      blob(point, uBlob3) + blob(point, uBlob4) + blob(point, uBlob5);
}

// Slow waves bend the space the blobs lie in: round blobs turn into
// the beans and arms of real lava. The glow is bent harder and finer,
// so it trails off the lava in wisps
vec2 warp(vec2 point, float amount, float scale, float shift) {
  vec2 wave = point * scale;

  return point +
      amount * vec2(sin(wave.y * 3.1 + uTime * 0.21 + shift) +
                        0.5 * sin(wave.x * 4.7 - uTime * 0.17),
                    cos(wave.x * 2.7 - uTime * 0.19 + shift) +
                        0.5 * cos(wave.y * 4.3 + uTime * 0.23));
}

// Where the lava turns blue drifts on its own, wider than a single blob
float tint(vec2 point) {
  return 0.5 + 0.5 * sin(point.x * 2.3 + uTime * 0.11) *
                   cos(point.y * 1.9 - uTime * 0.09 + point.x * 0.7);
}

// A hash without sine: the same on every GPU
float hash(vec2 point) {
  vec3 p = fract(vec3(point.xyx) * 0.1031);

  p += dot(p, p.yzx + 33.33);

  return fract((p.x + p.y) * p.z);
}

void main() {
  vec2 pixel = FlutterFragCoord().xy;
  vec2 uv = pixel / uSize.y;
  vec2 point = warp(uv, 0.09, 1.0, 0.0);
  float lavaField = field(point);
  float glowField = field(warp(uv, 0.13, 2.4, 1.7));

  // A soft halo right around the lava and wisps trailing further off it
  float haze = max(0.7 * smoothstep(0.02, 0.5, lavaField),
                   0.6 * smoothstep(0.06, 0.6, glowField));
  float body = smoothstep(0.4, 0.62, lavaField);

  // Thick lava is blue, and more of it where the tint drifts
  float thickness = lavaField * (0.7 + 0.75 * tint(point));
  float core = smoothstep(1.1, 1.75, thickness);
  float deep = smoothstep(2.15, 3.0, thickness);

  vec3 lava = mix(uBody, uCore, core);

  lava = mix(lava, uDeep, deep);

  vec3 color = mix(uBase, uHaze, haze);

  color = mix(color, lava, body);

  // Dithering keeps the dark gradients from banding
  color += (hash(pixel) - 0.5) / 255.0;

  fragColor = vec4(color, 1.0);
}
