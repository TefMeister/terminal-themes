// Old green monitor look: sharp letters with a faint glow, green-tinted glass,
// a soft lighter band, a rolling bar, dark corners and fine scanlines.
// Also: lines drawn on the secret marker background (Claude Code's RobCo theme paints
// the user's own messages with it) get no box and a different green for the text.
Texture2D shaderTexture;
SamplerState samplerState;
cbuffer PixelShaderSettings { float Time; float Scale; float2 Resolution; float4 Background; };

static const float  LINE_PERIOD   = 3.0;    // pixels per scanline cycle
static const float  LINE_DARKEN   = 0.30;   // how dark the dark line is
static const float  GLOW_RADIUS   = 2.5;    // pixels; how far the halo spreads
static const float  GLOW_STRENGTH = 0.45;   // halo added around letters (letters stay sharp)
static const float3 GLASS_TINT    = float3(0.035, 0.125, 0.065); // green of the empty screen
static const float  BAND_X        = 0.68;   // where the lighter band sits (0 = left, 1 = right)
static const float  BAND_WIDTH    = 0.09;
static const float  BAND_STRENGTH = 0.08;
static const float  VIGNETTE      = 1.35;   // how dark the corners get
static const float  ROLL_SECONDS  = 9.0;    // time for the rolling bar to travel top to bottom
static const float  ROLL_HEIGHT   = 0.12;   // bar height (fraction of the screen)
static const float  ROLL_STRENGTH = 0.16;   // how bright the rolling bar is

static const float3 MARKER        = float3(0.0, 0.0, 3.0 / 255.0); // user-message background
static const float3 USER_GREEN    = float3(0.80, 1.00, 0.45);      // colour of the user's text
static const int    ROW_SAMPLES   = 48;     // spots checked along a row to find the marker

bool isMarker(float3 c)
{
    return all(abs(c - MARKER) < 0.5 / 255.0);
}

// Brightness of a pixel as "how much letter is here" (0 = empty, 1 = full letter).
float ink(float3 c)
{
    return saturate(max(c.r, max(c.g, c.b)));
}

float3 sampleScreen(float2 uv)
{
    float3 c = shaderTexture.Sample(samplerState, uv).rgb;
    if (isMarker(c)) return float3(0, 0, 0);
    return c;
}

float3 recolour(float2 uv)
{
    // Is this row one of the user's messages? Look for the marker anywhere along it.
    float3 c = sampleScreen(uv);
    bool userRow = false;
    for (int i = 0; i < ROW_SAMPLES; i++)
    {
        float x = (i + 0.5) / ROW_SAMPLES;
        if (isMarker(shaderTexture.Sample(samplerState, float2(x, uv.y)).rgb)) { userRow = true; break; }
    }
    if (userRow) c = USER_GREEN * ink(c);
    return c;
}

// the background fades to black in a thin strip at the left and right edges of the window, where the
// picture is cut off; the top and bottom are drawn right to the edge. The letters do not fade.
static const float  SIDE_FADE     = 0.04;   // share of the width over which each side fades to black
float screenFade(float2 tex)
{
    return smoothstep(0.0, 1.0, saturate(min(tex.x, 1.0 - tex.x) / SIDE_FADE));
}

float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET
{
    float3 color = recolour(tex);

    // halo: average of nearby pixels, added on top so the sharp letter stays underneath
    float2 px = GLOW_RADIUS * max(Scale, 1.0) / Resolution;
    float3 glow = 0;
    glow += sampleScreen(tex + float2( px.x, 0));
    glow += sampleScreen(tex + float2(-px.x, 0));
    glow += sampleScreen(tex + float2(0,  px.y));
    glow += sampleScreen(tex + float2(0, -px.y));
    glow += sampleScreen(tex + float2( px.x,  px.y) * 0.7);
    glow += sampleScreen(tex + float2(-px.x,  px.y) * 0.7);
    glow += sampleScreen(tex + float2( px.x, -px.y) * 0.7);
    glow += sampleScreen(tex + float2(-px.x, -px.y) * 0.7);
    color += glow / 8.0 * GLOW_STRENGTH;

    // green glass and the lighter band
    color += GLASS_TINT * screenFade(tex);
    float band = exp(-pow((tex.x - BAND_X) / BAND_WIDTH, 2.0));
    color += float3(0.35, 1.0, 0.55) * band * BAND_STRENGTH * screenFade(tex);

    // rolling bar, like an old monitor slowly out of sync
    float rollY = frac(Time / ROLL_SECONDS) * 1.4 - 0.2;
    float roll  = exp(-pow((tex.y - rollY) / ROLL_HEIGHT, 2.0));
    color += float3(0.35, 1.0, 0.55) * roll * ROLL_STRENGTH * screenFade(tex);

    // dark corners
    float2 d = tex - 0.5;
    color *= saturate(1.0 - dot(d, d) * VIGNETTE);

    // scanlines
    float s = max(Scale, 1.0);
    if (fmod(floor(pos.y), LINE_PERIOD * s) < s)
        color *= (1.0 - LINE_DARKEN);

    return float4(color, 1.0);
}
