#include <metal_stdlib>
using namespace metal;

// Must match Uniforms.swift (80 bytes).
struct Uniforms {
    float2 viewOriginWorld;
    float2 cellSize;
    float4 tint;
    float scale;
    float time;
    float speed;
    float density;
    float worldRows;
    float fade;
    uint seed;
    uint glyphCount;
    uint atlasCols;
    uint atlasRows;
    uint pad0;
    uint pad1;
};

// ---- Cell function: keep in lockstep with RainMath.swift -------------------------

constant float kTimeWrap = 1024.0;
constant uint kStreams = 2;
constant float kMinTrail = 14.0;
constant float kMaxTrail = 48.0;
constant float kNearHeadRows = 3.0;

static uint pcg(uint v) {
    uint state = v * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

static uint hash4(uint seed, uint a, uint b, uint c) {
    return pcg(seed ^ pcg(a ^ pcg(b ^ pcg(c))));
}

static float unit01(uint h) {
    return float(h >> 8) * (1.0 / 16777216.0);
}

static float lerp(float a, float b, float t) { return a + (b - a) * t; }

struct CellOut {
    float brightness;
    float head;
    uint glyph;
};

static CellOut rainCell(uint seed, uint col, uint row, float t,
                        float speed, float density, float worldRows, uint glyphCount) {
    float bright = 0.0;
    float head = 0.0;
    float nearest = INFINITY;  // rows behind the closest head
    for (uint s = 0; s < kStreams; s++) {
        if (s > 0 && unit01(hash4(seed, col, s, 4)) >= density) { continue; }
        float rSpeed = unit01(hash4(seed, col, s, 0));
        float rPhase = unit01(hash4(seed, col, s, 1));
        float rLen = unit01(hash4(seed, col, s, 2));
        float rGap = unit01(hash4(seed, col, s, 3));

        float len = lerp(kMinTrail, kMaxTrail, rLen);
        float gap = worldRows * lerp(0.1, 1.2, rGap) * max(1.2 / max(density, 0.05) - 1.0, 0.05);
        float period = worldRows + len + gap;
        float rawSpeed = speed * lerp(8.0, 22.0, rSpeed);
        float cycles = max(round(rawSpeed * kTimeWrap / period), 1.0);
        float rowsPerSec = cycles * period / kTimeWrap;

        float x = t * rowsPerSec + rPhase * period;
        float headRow = x - period * floor(x / period);
        float d = headRow - float(row);
        if (d >= 0.0 && d < len) {
            float f = 1.0 - d / len;
            float b = f * sqrt(f);
            bright = max(bright, b);
            if (d < 1.0) { head = 1.0; }
            nearest = min(nearest, d);
        }
    }
    float r = unit01(hash4(seed, col, row, 7));
    float rate = nearest < kNearHeadRows ? lerp(8.0, 14.0, r) : lerp(0.05, 0.5, r);
    uint tick = uint(floor(max(t * rate, 0.0)));
    uint glyph = hash4(seed, col, row, tick + 11u) % max(glyphCount, 1u);
    return CellOut{bright, head, glyph};
}

// ---- Full-screen triangle -----------------------------------------------------------

struct VOut {
    float4 position [[position]];
    float2 uv;
};

vertex VOut fullscreenVertex(uint vid [[vertex_id]]) {
    float2 p = float2((vid << 1) & 2, vid & 2);
    VOut o;
    o.position = float4(p * 2.0 - 1.0, 0.0, 1.0);
    o.uv = float2(p.x, 1.0 - p.y);
    return o;
}

// ---- Pass 1: rain ---------------------------------------------------------------------

// Background depth layer: smaller cells, dimmer, softly blurred, shown only where the
// foreground is empty. Gives the film's sense of streams receding into the distance.
constant float kBackScale = 0.6;      // background cell size relative to foreground
constant float kBackBrightness = 0.28;
constant float kBackBlur = 0.09;      // blur radius in cell units
constant uint kBackSeedSalt = 0x9E3779B9u;

static float glyphAlpha(texture2d<float> atlas, sampler smp, constant Uniforms &u,
                        uint glyph, float2 local, float blur) {
    float2 g = float2(glyph % u.atlasCols, glyph / u.atlasCols);
    float2 grid = float2(u.atlasCols, u.atlasRows);
    if (blur <= 0.0) { return atlas.sample(smp, (g + local) / grid).r; }
    // 5-tap cross; clamp inside the cell so neighbouring atlas glyphs don't bleed in.
    float a = 0.0;
    float2 taps[5] = { float2(0, 0), float2(blur, 0), float2(-blur, 0), float2(0, blur), float2(0, -blur) };
    for (uint i = 0; i < 5; i++) {
        a += atlas.sample(smp, (g + clamp(local + taps[i], 0.02, 0.98)) / grid).r;
    }
    return a * 0.2;
}

fragment float4 rainFragment(VOut in [[stage_in]],
                             constant Uniforms &u [[buffer(0)]],
                             texture2d<float> atlas [[texture(0)]],
                             sampler smp [[sampler(0)]]) {
    float2 world = u.viewOriginWorld + in.position.xy / u.scale;
    float2 cellF = world / u.cellSize;
    if (cellF.x < 0.0 || cellF.y < 0.0) { return float4(0.0); }
    uint col = uint(cellF.x);
    uint row = uint(cellF.y);

    CellOut c = rainCell(u.seed, col, row, u.time, u.speed, u.density, u.worldRows, u.glyphCount);
    if (c.brightness > 0.0) {
        float a = glyphAlpha(atlas, smp, u, c.glyph, fract(cellF), 0.0);
        // Heads are near-white with a green cast; the trail is the plain tint.
        float3 headColor = mix(u.tint.rgb, float3(1.0), 0.7);
        float3 color = mix(u.tint.rgb * c.brightness, headColor * 1.4, c.head) * a;
        return float4(color, 1.0);
    }

    float2 backF = world / (u.cellSize * kBackScale);
    float backRows = u.worldRows / kBackScale;
    CellOut b = rainCell(u.seed ^ kBackSeedSalt, uint(backF.x), uint(backF.y), u.time,
                         u.speed * 0.7, u.density, backRows, u.glyphCount);
    if (b.brightness <= 0.0) { return float4(0.0, 0.0, 0.0, 1.0); }
    float a = glyphAlpha(atlas, smp, u, b.glyph, fract(backF), kBackBlur);
    float3 color = u.tint.rgb * mix(b.brightness, 1.0, b.head * 0.5) * kBackBrightness * a;
    return float4(color, 1.0);
}

// ---- Pass 2: glow (downsample + separable blur) ---------------------------------------

fragment float4 downsampleFragment(VOut in [[stage_in]],
                                   texture2d<float> src [[texture(0)]],
                                   sampler smp [[sampler(0)]]) {
    float2 texel = 1.0 / float2(src.get_width(), src.get_height());
    float2 uv = in.uv;
    float4 s = src.sample(smp, uv + texel * float2(-1, -1))
             + src.sample(smp, uv + texel * float2( 1, -1))
             + src.sample(smp, uv + texel * float2(-1,  1))
             + src.sample(smp, uv + texel * float2( 1,  1));
    return s * 0.25;
}

fragment float4 blurFragment(VOut in [[stage_in]],
                             texture2d<float> src [[texture(0)]],
                             sampler smp [[sampler(0)]],
                             constant float2 &direction [[buffer(0)]]) {
    // 9-tap Gaussian via 5 linear-filtered samples.
    float2 texel = direction / float2(src.get_width(), src.get_height());
    float4 c = src.sample(smp, in.uv) * 0.2270270270;
    c += src.sample(smp, in.uv + texel * 1.3846153846) * 0.3162162162;
    c += src.sample(smp, in.uv - texel * 1.3846153846) * 0.3162162162;
    c += src.sample(smp, in.uv + texel * 3.2307692308) * 0.0702702703;
    c += src.sample(smp, in.uv - texel * 3.2307692308) * 0.0702702703;
    return c;
}

// ---- Pass 3: composite ----------------------------------------------------------------

fragment float4 compositeFragment(VOut in [[stage_in]],
                                  constant Uniforms &u [[buffer(0)]],
                                  constant float &glowStrength [[buffer(1)]],
                                  texture2d<float> scene [[texture(0)]],
                                  texture2d<float> glow [[texture(1)]],
                                  sampler smp [[sampler(0)]]) {
    float3 c = scene.sample(smp, in.uv).rgb + glow.sample(smp, in.uv).rgb * glowStrength;
    return float4(c * u.fade, 1.0);
}

// ---- Test-only: evaluate the cell function for the CPU/GPU parity test ---------------

struct ParityParams {
    float time;
    float speed;
    float density;
    float worldRows;
    uint seed;
    uint glyphCount;
};

kernel void parityKernel(constant ParityParams &p [[buffer(0)]],
                         device const uint2 *cells [[buffer(1)]],
                         device float4 *out [[buffer(2)]],
                         uint id [[thread_position_in_grid]]) {
    uint2 cr = cells[id];
    CellOut c = rainCell(p.seed, cr.x, cr.y, p.time, p.speed, p.density, p.worldRows, p.glyphCount);
    out[id] = float4(c.brightness, c.head, float(c.glyph), 0.0);
}
