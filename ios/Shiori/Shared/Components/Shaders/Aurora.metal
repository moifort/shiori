#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// The AI at work, as Apple Intelligence shows it: a soft aurora in its
// colours — pink, orange, purple, blue — drifting slowly through a dark
// ground, lit from within, never a hard edge. Drawn as a SwiftUI colour
// effect over a plain fill: `position` in points, `size` the view's, `time`
// in seconds since the view appeared.

static float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

/// Value noise, smooth between lattice points.
static float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + float2(1.0, 0.0));
    float c = hash21(i + float2(0.0, 1.0));
    float d = hash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

/// Four octaves of noise: the slow, cloudy drift the aurora moves with.
static float fbm(float2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p);
        p = p * 2.03 + 17.1;
        amplitude *= 0.5;
    }
    return value;
}

[[ stitchable ]] half4 aurora(float2 position, half4 color, float2 size, float time) {
    float2 uv = position / size;
    // The field, stretched to the card's shape so the drift reads the same
    // across and down.
    float2 p = uv * float2(2.0, 2.0 * size.y / max(size.x, 1.0));
    float t = time * 0.11;
    float n1 = fbm(p + float2(t, -t * 0.7));
    float n2 = fbm(p * 1.7 - float2(t * 0.6, t * 0.9) + 3.0);
    // A broad wave rolling up the card, bent by the noise.
    float band = sin((uv.y * 2.2 + n1 * 1.6 - t * 1.4) * 3.14159);

    half3 pink = half3(1.0, 0.42, 0.68);
    half3 orange = half3(1.0, 0.62, 0.30);
    half3 purple = half3(0.60, 0.42, 1.0);
    half3 blue = half3(0.32, 0.68, 1.0);
    half3 cool = mix(purple, blue, half(n1));
    half3 warm = mix(pink, orange, half(n2));
    half3 light = mix(cool, warm, half(0.5 + 0.5 * band));

    // How much light reaches each point: most where the clouds thicken.
    float glow = smoothstep(0.2, 0.95, n1 * 0.6 + n2 * 0.6);
    half3 ground = half3(0.05, 0.06, 0.09);
    half3 out = mix(ground, light, half(0.28 + 0.72 * glow));

    // Darker toward the edges, so the card keeps a body of its own.
    float vignette = smoothstep(0.0, 0.45, uv.x) * smoothstep(1.0, 0.55, uv.x)
        * smoothstep(0.0, 0.35, uv.y) * smoothstep(1.0, 0.65, uv.y);
    out = mix(ground, out, half(0.5 + 0.5 * vignette));

    return half4(out * color.a, color.a);
}
