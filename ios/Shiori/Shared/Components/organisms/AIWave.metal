#include <metal_stdlib>
using namespace metal;

// The iOS 27 Siri wave, ported to a SwiftUI colour effect from
// https://github.com/WillSuo-Github/Siri27SiriAnimation (MIT), itself a Metal
// translation of https://aaaa-zhen.github.io/glsl-playground/siri-wave.html.
// Four spectral lines offset in phase draw the chromatic fringes; a band fills
// between them and the main line; Lorentzian falloffs give the glow. The
// original draws light on black, so the colour is returned premultiplied with
// its brightest channel as alpha, letting the wave sit on any background.

constant float W_PI = 3.14159265359;
constant float W_AMPLITUDE = 0.32;
constant float W_FREQ = 1.1;
constant float W_ABER_FREQ = 1.0;
constant float W_SPEED = 2.4;
constant float W_WAVE_SCALE = 0.6;
constant float W_ABERRATION = 2.6;
constant float W_THICKNESS = 3.0;
constant float W_INTENSITY = 2.0;
constant float W_FALLOFF = 1.7;
constant float W_EDGE_MASK = 0.4;
constant float W_BAND_FILL = 30000.0;
constant float W_BAND_THICK = 0.08;
constant float W_SOFTNESS = 2.5;
constant float W_LOW_AMP = 6.0;
constant float W_LOW_INT = 1.5;
constant float W_MID_ABER = 0.8;
constant float W_MID_ABAMP = 0.05;
constant float W_MID_SOFT = 0.4;
constant float W_HIGH_ABER = 0.5;
constant float W_HIGH_ABAMP = 0.06;

static float3 waveSpectral(int s) {
    float x = float(s);
    return clamp(float3(abs(x - 3.0) - 1.0, 2.0 - abs(x - 2.0), 2.0 - abs(x - 4.0)), 0.0, 1.0);
}

[[ stitchable ]] half4 aiWave(float2 position, half4 color, float2 size, float time) {
    float aspect = size.x / size.y;
    float2 p = float2(position.x, size.y - position.y) * 2.0 / size - 1.0;
    p.x *= aspect;
    float yScreen = p.y;
    p /= W_WAVE_SCALE;

    // Three slow, uncorrelated "levels" stand in for the voice bands Siri
    // listens to, so the wave keeps breathing without a microphone.
    float t = time;
    float low = clamp(0.45 + 0.45 * sin(t * 0.8) * sin(t * 0.37 + 1.0), 0.0, 1.0);
    float mid = clamp(0.40 + 0.40 * sin(t * 1.7 + 2.0) * sin(t * 0.53), 0.0, 1.0);
    float high = clamp(0.30 + 0.30 * sin(t * 2.9 + 4.0) * sin(t * 0.71 + 2.0), 0.0, 1.0);
    float drift = fmod(t, 20.0 * W_PI) * W_SPEED;

    float xN = p.x / max(aspect, 1.0);
    float env = cos(W_PI * 0.5 * min(abs(0.9 * xN), 1.0));
    env *= env;

    float a1 = W_AMPLITUDE + 0.01 * low * W_LOW_AMP;
    float a2 = a1 + mid * W_MID_ABAMP + high * W_HIGH_ABAMP;
    float ab = W_ABERRATION + mid * W_MID_ABER + high * W_HIGH_ABER;
    float th = 0.01 * W_THICKNESS;
    float inten = 0.01 * (W_INTENSITY + low * W_LOW_INT);
    float soft = 0.01 * max(0.0, W_SOFTNESS + mid * W_MID_SOFT);
    float yMain = a1 * env * sin(p.x * W_FREQ + drift);
    float bandAmt = 1e-4 * W_BAND_FILL * inten;

    float3 num = 0.0;
    float3 den = 0.0;
    for (int s = 0; s < 4; s++) {
        float3 hue = waveSpectral(s);
        den += hue;
        float chroma = mix(-ab, ab, float(s) / 3.0);
        float yL = a2 * env * sin(p.x * W_ABER_FREQ + drift + chroma);
        float d = abs(p.y - yL);
        float line = inten / (sqrt(d * d + soft * soft) + th);
        float dBand = max(0.0, max(p.y - max(yMain, yL), min(yMain, yL) - p.y));
        float band = bandAmt / (dBand + W_BAND_THICK);
        num += hue * (line + band);
    }
    float3 col = num / den;

    float dM = abs(p.y - yMain);
    col += 0.5 * inten / (sqrt(dM * dM + soft * soft) + th);
    col = pow(max(col, 0.0), 1.5);

    float emT = clamp((abs(yScreen) - 1.0) / -W_EDGE_MASK, 0.0, 1.0);
    float em = emT * emT * (3.0 - 2.0 * emT);
    col *= em * exp(-pow(xN * W_FALLOFF, 2.0));

    col = min(col, 1.0);
    float alpha = max(col.r, max(col.g, col.b));
    return half4(half3(col), half(alpha));
}
