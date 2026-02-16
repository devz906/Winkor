#include <metal_stdlib>
using namespace metal;

// Winkor Metal Shaders
// These are the final rendering shaders that display the Wine/DXVK framebuffer on screen
// The pipeline is: Game → DXVK/VirGL → Framebuffer texture → These shaders → Screen

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Full-screen quad vertex shader - passes through Wine's framebuffer
vertex VertexOut vertex_passthrough(
    uint vertexID [[vertex_id]],
    constant float4 *vertices [[buffer(0)]]
) {
    VertexOut out;
    float4 v = vertices[vertexID];
    out.position = float4(v.xy, 0.0, 1.0);
    out.texCoord = v.zw;
    return out;
}

// Samples the Wine framebuffer texture and displays it
fragment float4 fragment_texture_sample(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    sampler smp [[sampler(0)]]
) {
    return tex.sample(smp, in.texCoord);
}

// Gamma-corrected output for proper color display
fragment float4 fragment_gamma_correct(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    sampler smp [[sampler(0)]],
    constant float &gamma [[buffer(0)]]
) {
    float4 color = tex.sample(smp, in.texCoord);
    float3 corrected = pow(color.rgb, float3(1.0 / gamma));
    return float4(corrected, color.a);
}

// Bilinear upscaling for rendering at lower resolution
fragment float4 fragment_bilinear_upscale(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    sampler smp [[sampler(0)]]
) {
    constexpr sampler bilinearSampler(
        mag_filter::linear,
        min_filter::linear,
        mip_filter::linear
    );
    return tex.sample(bilinearSampler, in.texCoord);
}

// CRT scanline effect (optional retro look)
fragment float4 fragment_crt_scanlines(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    sampler smp [[sampler(0)]],
    constant float2 &resolution [[buffer(0)]]
) {
    float4 color = tex.sample(smp, in.texCoord);
    
    float scanline = sin(in.texCoord.y * resolution.y * 3.14159) * 0.04;
    color.rgb -= scanline;
    
    float vignette = 1.0 - length((in.texCoord - 0.5) * 1.2);
    vignette = clamp(vignette, 0.0, 1.0);
    color.rgb *= vignette;
    
    return color;
}

// FXAA anti-aliasing pass
fragment float4 fragment_fxaa(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    constant float2 &texelSize [[buffer(0)]]
) {
    constexpr sampler smp(mag_filter::linear, min_filter::linear);
    
    float3 rgbNW = tex.sample(smp, in.texCoord + float2(-1.0, -1.0) * texelSize).rgb;
    float3 rgbNE = tex.sample(smp, in.texCoord + float2( 1.0, -1.0) * texelSize).rgb;
    float3 rgbSW = tex.sample(smp, in.texCoord + float2(-1.0,  1.0) * texelSize).rgb;
    float3 rgbSE = tex.sample(smp, in.texCoord + float2( 1.0,  1.0) * texelSize).rgb;
    float3 rgbM  = tex.sample(smp, in.texCoord).rgb;
    
    float3 luma = float3(0.299, 0.587, 0.114);
    float lumaNW = dot(rgbNW, luma);
    float lumaNE = dot(rgbNE, luma);
    float lumaSW = dot(rgbSW, luma);
    float lumaSE = dot(rgbSE, luma);
    float lumaM  = dot(rgbM,  luma);
    
    float lumaMin = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));
    float lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));
    
    float2 dir;
    dir.x = -((lumaNW + lumaNE) - (lumaSW + lumaSE));
    dir.y =  ((lumaNW + lumaSW) - (lumaNE + lumaSE));
    
    float dirReduce = max((lumaNW + lumaNE + lumaSW + lumaSE) * 0.25 * 0.125, 1.0/128.0);
    float rcpDirMin = 1.0 / (min(abs(dir.x), abs(dir.y)) + dirReduce);
    dir = min(float2(8.0), max(float2(-8.0), dir * rcpDirMin)) * texelSize;
    
    float3 rgbA = 0.5 * (
        tex.sample(smp, in.texCoord + dir * (1.0/3.0 - 0.5)).rgb +
        tex.sample(smp, in.texCoord + dir * (2.0/3.0 - 0.5)).rgb
    );
    float3 rgbB = rgbA * 0.5 + 0.25 * (
        tex.sample(smp, in.texCoord + dir * -0.5).rgb +
        tex.sample(smp, in.texCoord + dir *  0.5).rgb
    );
    
    float lumaB = dot(rgbB, luma);
    
    if (lumaB < lumaMin || lumaB > lumaMax) {
        return float4(rgbA, 1.0);
    }
    return float4(rgbB, 1.0);
}
