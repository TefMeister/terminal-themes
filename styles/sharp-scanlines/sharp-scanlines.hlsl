// Scanlines over the text with NO blur (the built-in retro effect blurs the letters).
Texture2D shaderTexture;
SamplerState samplerState;
cbuffer PixelShaderSettings { float Time; float Scale; float2 Resolution; float4 Background; };

static const float LINE_PERIOD = 3.0;   // pixels per scanline cycle
static const float LINE_DARKEN = 0.35;  // how dark the dark line is (0 = invisible, 1 = black)

float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET
{
    float4 color = shaderTexture.Sample(samplerState, tex);
    float period = LINE_PERIOD * max(Scale, 1.0);
    if (fmod(floor(pos.y), period) < max(Scale, 1.0))
        color.rgb *= (1.0 - LINE_DARKEN);
    return color;
}
