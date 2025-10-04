#version 330

uniform float time;
uniform vec2 size;

in vec2 fragTexCoord;
out vec4 finalColor;

#define  PI 3.141592

float hue2rgb(float hue, float saturation, float luminosity) {
  if (luminosity < 0.0) luminosity += 1.0;
  if (luminosity > 1.0) luminosity -= 1.0;
  if (luminosity < 1.0 / 6.0) return hue + (saturation - hue) * 6.0 * luminosity;
  if (luminosity < 1.0 / 2.0) return saturation;
  if (luminosity < 2.0 / 3.0) return hue + (saturation - hue) * (2.0 / 3.0 - luminosity) * 6.0;
  return hue;
}

vec3 hsl2rgb(vec3 color) {
  float hue = color.x;
  float saturation = color.y;
  float luminosity = color.z;

  float r, g, b;

  if (saturation == 0.0) {
    r = g = b = luminosity; // achromatic
  } else {
    float q = luminosity < 0.5 ? luminosity * (1.0 + saturation) : luminosity + saturation - luminosity * saturation;
    float p = 2.0 * luminosity - q;
    r = hue2rgb(p, q, hue + 1.0 / 3.0);
    g = hue2rgb(p, q, hue);
    b = hue2rgb(p, q, hue - 1.0 / 3.0);
  }
  return vec3(r, g, b);
}

#define SPEED .5

void main() {
  vec2 uv = fragTexCoord * size / 300.;

  vec2 pos = uv + time * SPEED;
  finalColor = vec4(hsl2rgb(vec3(fract(pos.x + pos.y), 1.0, 0.5)), .6);
}
