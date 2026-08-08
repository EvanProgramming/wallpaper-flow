#include <metal_stdlib>
using namespace metal;

// MARK: - Uniforms (must match Swift Uniforms struct layout)
struct Uniforms {
    float time;
    float deltaTime;
    float2 viewportSize;
    float displayScale;

    float bass;
    float mid;
    float treble;
    float beat;
    float loudness;
    float stereoBalance;

    float3 primaryColor;
    float3 secondaryColor;
    float3 accentColor;
    float3 darkBaseColor;

    float intensity;
    float motion;
    float glow;
    float particleAmount;
    float audioReactivity;

    float lyricsProgress;
    bool hasLyrics;
};

// MARK: - Vertex

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut aurora_vertex(uint vertexID [[vertex_id]]) {
    float2 positions[4] = {
        { -1.0, -1.0 },
        {  1.0, -1.0 },
        { -1.0,  1.0 },
        {  1.0,  1.0 }
    };
    float2 uvs[4] = {
        { 0.0, 1.0 },
        { 1.0, 1.0 },
        { 0.0, 0.0 },
        { 1.0, 0.0 }
    };
    VertexOut out;
    out.position = float4(positions[vertexID], 0.0, 1.0);
    out.uv = uvs[vertexID];
    return out;
}

// MARK: - Fragment — Aurora Flow

fragment float4 aurora_fragment(VertexOut in [[stage_in]],
                                constant Uniforms &u [[buffer(0)]])
{
    float2 uv = in.uv;
    float t = u.time;

    // ============================================================
    // 1. Base wave layers (organic aurora motion)
    // ============================================================
    float wave1 = sin(uv.x * 3.2 + t * 0.25 + uv.y * 2.1) * 0.5 + 0.5;
    float wave2 = sin(uv.x * 5.7 - t * 0.35 + uv.y * 3.3) * 0.5 + 0.5;
    float wave3 = sin((uv.x + uv.y * 0.8) * 4.3 + t * 0.45) * 0.5 + 0.5;
    float wave4 = sin(uv.y * 2.8 + t * 0.18 + uv.x * 1.9) * 0.5 + 0.5;

    // ============================================================
    // 2. Audio-reactive displacement
    // ============================================================
    float react = u.audioReactivity;
    float bassPulse   = u.bass * react;
    float midPulse    = u.mid * react * 0.6;
    float treblePulse = u.treble * react * 0.3;
    float beatFlash   = u.beat * react * 0.4;

    // Warp UVs with audio
    float2 warp = float2(
        bassPulse * sin(uv.y * 6.0 + t * 0.5) * 0.08,
        midPulse  * cos(uv.x * 5.0 + t * 0.4) * 0.06
    );
    float2 wuv = uv + warp;

    // Recompute waves with warped UV
    float w1 = sin(wuv.x * 3.2 + t * 0.25 + wuv.y * 2.1) * 0.5 + 0.5;
    float w2 = sin(wuv.x * 5.7 - t * 0.35 + wuv.y * 3.3) * 0.5 + 0.5;
    float w3 = sin((wuv.x + wuv.y * 0.8) * 4.3 + t * 0.45) * 0.5 + 0.5;
    float w4 = sin(wuv.y * 2.8 + t * 0.18 + wuv.x * 1.9) * 0.5 + 0.5;

    // Bass pushes wave intensity
    float bassBoost = 1.0 + bassPulse * 0.5;
    w1 = clamp(w1 * bassBoost, 0.0, 1.0);
    w2 = clamp(w2 * bassBoost, 0.0, 1.0);

    // ============================================================
    // 3. Combine into aurora mask
    // ============================================================
    float aurora = w1 * 0.35 + w2 * 0.25 + w3 * 0.2 + w4 * 0.2;
    aurora = smoothstep(0.15, 0.75, aurora);

    // Beat impulse creates a bright ripple
    float beatRipple = beatFlash * exp(-abs(wuv.y - 0.5) * 6.0) * sin(t * 30.0) * 0.5 + 0.5;
    aurora = max(aurora, beatRipple * beatFlash * 2.0);

    // ============================================================
    // 4. Color composition
    // ============================================================
    float3 c1 = u.primaryColor;
    float3 c2 = u.secondaryColor;
    float3 c3 = u.accentColor;
    float3 base = u.darkBaseColor;

    // Vertical gradient blend
    float blend = sin(wuv.y * 2.5 + t * 0.08) * 0.5 + 0.5;
    float3 sceneColor = mix(c1, c2, blend);
    sceneColor = mix(sceneColor, c3, w3 * 0.35);

    // Treble adds bright highlights
    float3 highlight = float3(1.0, 0.95, 0.9) * treblePulse * 0.3;
    sceneColor += highlight;

    // ============================================================
    // 5. Final composition
    // ============================================================
    float3 finalColor = mix(base, sceneColor, aurora * u.intensity);

    // Aurora glow (vertical band)
    float glowMask = exp(-abs(wuv.y - 0.5) * 5.0) * u.glow * 0.6;
    finalColor += sceneColor * glowMask * aurora;

    // Beat flash (white burst)
    float beatWhite = beatFlash * 0.2;
    finalColor += float3(1.0, 0.95, 0.9) * beatWhite;

    // Subtle edge vignette
    float2 center = uv - 0.5;
    float vignette = 1.0 - dot(center, center) * 0.9;
    finalColor *= vignette;

    // Tone mapping (simple Reinhard)
    finalColor = finalColor / (finalColor + float3(1.0));

    // Gamma
    finalColor = pow(finalColor, float3(1.0 / 2.2));

    return float4(finalColor, 1.0);
}

// MARK: - Fragment — Glass Wave (simpler wave-based)

fragment float4 glasswave_fragment(VertexOut in [[stage_in]],
                                   constant Uniforms &u [[buffer(0)]])
{
    float2 uv = in.uv;
    float t = u.time;

    // Glass-like refractive distortion
    float react = u.audioReactivity;
    float bassPulse = u.bass * react;
    float midPulse  = u.mid * react;

    // Distortion
    float2 offset = float2(
        sin(uv.y * 10.0 + t * 0.8) * bassPulse * 0.03,
        cos(uv.x * 8.0 + t * 0.6) * midPulse  * 0.02
    );
    float2 duv = uv + offset;

    // Iridescent bands
    float band = sin(duv.y * 15.0 + duv.x * 5.0 + t * 0.3) * 0.5 + 0.5;
    float band2 = cos(duv.x * 12.0 - duv.y * 8.0 + t * 0.4) * 0.5 + 0.5;

    // Color
    float3 c1 = u.primaryColor;
    float3 c2 = u.secondaryColor;
    float3 c3 = u.accentColor;
    float3 base = u.darkBaseColor;

    float blend = band * 0.6 + band2 * 0.4;
    float3 sceneColor = mix(c1, c2, blend);
    sceneColor = mix(sceneColor, c3, band2 * 0.3);

    // Glass edge glow
    float edge = 1.0 - abs(duv.y - 0.5) * 2.0;
    edge = pow(edge, 2.0);
    sceneColor += float3(0.8, 0.9, 1.0) * edge * 0.2 * u.glow;

    float3 finalColor = mix(base, sceneColor, 0.6 + bassPulse * 0.3);

    // Beat pulse
    float beatPulse = u.beat * react * 0.15;
    finalColor += float3(1.0, 0.95, 0.9) * beatPulse;

    // Vignette + tone map
    float2 center = uv - 0.5;
    float vignette = 1.0 - dot(center, center) * 0.7;
    finalColor *= vignette;
    finalColor = finalColor / (finalColor + float3(1.0));
    finalColor = pow(finalColor, float3(1.0 / 2.2));

    return float4(finalColor, 1.0);
}