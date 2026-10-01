// Halloween: a pixel-art graveyard night drawn behind the text.
// Back to front: a banded night sky with stars, a big moon and drifting clouds; witches on brooms
// flying across in the distance; two rows of hills with dead trees and gravestones; a foggy field
// rolling towards you, with zombies walking out of the dark (seen only when lightning lights them);
// the big sheet ghost that rises in the middle; glowing evil-eyed pumpkins along the bottom; then,
// nearest of all, spiders dangling from the top and crawling on the inside of the glass (so you see
// their undersides).
// Every GHOST_PERIOD seconds the ghost appears, and three lightning strikes, at uneven times, light
// the whole picture up. Each flash swells, flickers and fades rather than blinking.
// Everything is drawn on a grid of chunky pixels (CELL_PIXELS) and moves FPS times a second; the
// flashes run at FLASH_FPS so they look animated.
// Sprites come from halloween-sheet.png (drawn by halloween-sprites.py; the layout constants below
// must match that script). The colour scheme's background must be pure black: anything not black
// counts as text.
Texture2D shaderTexture;
Texture2D image;
SamplerState samplerState;
cbuffer PixelShaderSettings { float Time; float Scale; float2 Resolution; float4 Background; };

// --- the pixel look ---
static const float  CELL_PIXELS    = 3.0;    // screen pixels per chunky pixel
static const float  FPS            = 10.0;   // how often things move per second
static const float  FLASH_FPS      = 30.0;   // how often the lightning light changes per second
static const float  SCENE_BRIGHT   = 0.62;   // overall picture brightness (text is not affected)
static const float  EDGE_DARK      = 0.45;   // how much the corners darken

// --- sprite sheet layout (matches halloween-sprites.py) ---
static const int    SHEET_W = 256, SHEET_H = 318;
static const int    PKW = 48, PKH = 40, PK_Y = 0;     // pumpkins: 3 kinds
static const int    ZW = 24, ZH = 44, Z_Y = 40;       // zombies: 2 kinds x 4 frames
static const int    WW = 40, WH = 24, W_Y = 128;      // witch: 4 frames
static const int    SW = 40, SH = 40, S_Y = 152;      // spider from underneath: 4 frames
static const int    HW = 24, HH = 24, H_Y = 192;      // hanging spider: 2 frames
static const int    TW = 64, TH = 80, T_Y = 216;      // dead trees: 2 kinds
static const int    GW = 16, GH = 22, G_Y = 296;      // gravestones: 4 kinds

// --- sky ---
static const float3 SKY_TOP        = float3(0.035, 0.015, 0.075);
static const float3 SKY_LOW        = float3(0.150, 0.060, 0.170);
static const float  SKY_BANDS      = 9.0;
static const float  HORIZON        = 0.60;   // where the field starts (share of the height)
static const float2 MOON_POS       = float2(0.80, 0.20);
static const float  MOON_SIZE      = 0.12;   // radius, as a share of the height
static const float3 MOON_COLOUR    = float3(1.00, 0.93, 0.72);
static const float3 MOON_HALO      = float3(0.20, 0.12, 0.18);
static const float3 CLOUD_COLOUR   = float3(0.055, 0.035, 0.085);
static const float3 CLOUD_RIM      = float3(0.40, 0.33, 0.38);

// --- lightning ---
static const float  GHOST_PERIOD   = 45.0;   // seconds between ghost visits
static const float  GHOST_STAY     = 15.0;   // seconds the ghost stays (after it has appeared)
static const float  GHOST_FADE_IN  = 1.8;
static const float  GHOST_FADE_OUT = 3.0;
static const float3 FLASH_SKY      = float3(0.80, 0.82, 1.00);
static const float  FLASH_STEPS    = 12.0;   // brightness steps of a flash (pixel-art banding)
static const float3 BOLT_COLOUR    = float3(1.00, 0.97, 1.00);

// --- hills, trees, gravestones ---
static const float3 HILL_FAR       = float3(0.090, 0.055, 0.120);
static const float3 HILL_NEAR      = float3(0.040, 0.025, 0.060);
static const float  HILL_FAR_FLASH = 0.55;   // far things light up more in a flash (haze), near ones stay dark
static const float  HILL_NEAR_FLASH= 0.20;
static const float3 SILHOUETTE     = float3(0.012, 0.008, 0.020);
static const int    TREES          = 4;
static const int    TOMBS          = 14;
static const float  TOMB_LIGHT     = 0.32;   // gravestones catch a little moonlight

// --- the field ---
static const float3 GROUND_FAR     = float3(0.060, 0.040, 0.070);
static const float3 GROUND_NEAR    = float3(0.030, 0.026, 0.024);
static const float3 FOG_COLOUR     = float3(0.170, 0.130, 0.210);
static const float  FOG_AMOUNT     = 0.85;

// --- zombies ---
static const int    ZOMBIES        = 14;
static const float  ZOMBIE_TRIP    = 50.0;   // typical seconds to walk from the horizon to you
static const float  ZOMBIE_FAR     = 0.22;   // size on the horizon
static const float  ZOMBIE_NEAR    = 3.2;    // size when they reach the front
static const float  ZOMBIE_DARK    = 0.035;  // how much of them shows without lightning (almost nothing)

// --- the ghost ---
static const float  GHOST_HEIGHT   = 0.58;   // share of the height
static const float  GHOST_TOP      = 0.10;
static const float3 GHOST_LIGHT    = float3(0.93, 0.95, 1.00);
static const float3 GHOST_SHADE    = float3(0.48, 0.50, 0.66);
static const float3 GHOST_EDGE     = float3(0.30, 0.30, 0.45);
static const float3 GHOST_EYE      = float3(0.010, 0.005, 0.020);
static const float  GHOST_OPACITY  = 0.80;
static const float  WIND           = 0.13;   // how far the wind pushes the sheet to the left

// --- pumpkins (listed back to front) ---
static const int    PUMPKINS       = 6;
static const float  PK_X[6]        = { 0.37, 0.64, 0.23, 0.80, 0.95, 0.07 };
static const float  PK_SCALE[6]    = { 0.85, 1.00, 1.30, 1.55, 2.10, 2.40 };
static const float  PK_BOTTOM[6]   = { -30, -26, -17, -10, 9, 10 };   // cells below the bottom edge
static const int    PK_KIND[6]     = { 2, 1, 1, 2, 0, 0 };
static const float3 CANDLE_DEEP    = float3(1.00, 0.30, 0.02);
static const float3 CANDLE_HOT     = float3(1.00, 0.92, 0.50);
static const float  CANDLE_GLOW    = 1.9;    // pumpkin faces are brighter than the rest of the picture
static const float  PUMPKIN_BODY   = 0.38;   // pumpkin skin brightness in the dark
static const float  POOL_SIZE      = 34.0;   // reach of the orange light on the ground, in cells

// --- witches ---
static const int    WITCHES        = 4;
static const float  WITCH_TRIP     = 22.0;   // typical seconds to cross the sky

// --- spiders ---
static const int    CRAWLERS       = 3;
static const float  CRAWL_SCALE    = 1.7;    // big: they are right on the glass
static const float  CRAWL_STEP     = 6.0;    // seconds per walk-and-rest stretch
static const int    HANGERS        = 2;
static const float  HANG_SCALE     = 1.6;
static const float  HANG_CYCLE     = 26.0;   // seconds between drops of the same spider
static const float3 THREAD_COLOUR  = float3(0.40, 0.40, 0.46);

// --- looping, for recording a clip ---
// 0 = off: the picture runs freely, as it should in the terminal. Set it to a number of seconds and
// everything repeats exactly that often, so a recording of that length loops without a seam.
// Use a multiple of 6 that fits one ghost visit (for example 48).
static const float  LOOP_SECONDS   = 0.0;
static const float  TAU            = 6.28318530718;

// --- user messages (same marker the Matrix Claude theme uses) ---
static const float3 MARKER         = float3(0.0, 0.0, 3.0 / 255.0);
static const float3 USER_COLOUR    = float3(1.00, 0.62, 0.22);
static const int    ROW_SAMPLES    = 48;

static const float BAYER[16] = { 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5 };

float hash(float n) { return frac(sin(n * 127.1 + 11.7) * 43758.5453); }
float hash2(float2 p) { return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453); }
int pmod(int a, int n) { int m = a % n; return m < 0 ? m + n : m; }
float dither(int2 c) { return (BAYER[(c.y & 3) * 4 + (c.x & 3)] + 0.5) / 16.0; }
float noise1(float x) { float i = floor(x); float f = frac(x); return lerp(hash(i), hash(i + 1.0), f * f * (3.0 - 2.0 * f)) * 2.0 - 1.0; }
float noise2(float2 p)
{
    float2 i = floor(p), f = frac(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash2(i), b = hash2(i + float2(1, 0)), c = hash2(i + float2(0, 1)), d = hash2(i + float2(1, 1));
    return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
}
float steps(float v, float n, float d) { return saturate(floor(v * n + d) / n); }

// in loop mode, snap a rate (radians per second) or a frequency (trips per second) to the nearest
// one that fits the loop exactly; otherwise leave it alone
float loopRate(float w) { return LOOP_SECONDS > 0.0 ? max(1.0, round(w * LOOP_SECONDS / TAU)) * TAU / max(LOOP_SECONDS, 1.0) : w; }
float loopFreq(float f) { return LOOP_SECONDS > 0.0 ? max(1.0, round(f * LOOP_SECONDS)) / max(LOOP_SECONDS, 1.0) : f; }
// a counter that, in loop mode, wraps after the number of steps that fit the loop
float loopIndex(float i, float perSecond) { return LOOP_SECONDS > 0.0 ? (float)pmod((int)i, max(1, (int)round(LOOP_SECONDS * perSecond))) : i; }

bool isMarker(float3 c) { return all(abs(c - MARKER) < 0.5 / 255.0); }
float ink(float3 c) { return saturate(max(c.r, max(c.g, c.b))); }

float3 readText(float2 uv)
{
    float3 c = shaderTexture.Sample(samplerState, uv).rgb;
    if (isMarker(c)) c = float3(0, 0, 0);
    bool userRow = false;
    for (int i = 0; i < ROW_SAMPLES; i++)
    {
        float x = (i + 0.5) / ROW_SAMPLES;
        if (isMarker(shaderTexture.Sample(samplerState, float2(x, uv.y)).rgb)) { userRow = true; break; }
    }
    if (userRow) c = USER_COLOUR * ink(c);
    return c;
}

// one sprite texel; w = 0 where the sheet is magenta (empty) or not loaded yet
float4 texel(int x, int y)
{
    float3 c = image.Load(int3(x, y, 0)).rgb;
    bool empty = (c.r > 0.9 && c.g < 0.1 && c.b > 0.9) || max(c.r, max(c.g, c.b)) < 0.02;
    return float4(c, empty ? 0.0 : 1.0);
}

// a sprite cell drawn with its top-left at `at`, `scale` cells per texel, optionally mirrored
float4 sprite(int2 cell, float2 at, float scale, int sx, int sy, int w, int h, bool mirror)
{
    float2 l = (float2(cell) - at) / scale;
    if (l.x < 0 || l.y < 0 || l.x >= w || l.y >= h) return 0;
    int2 s = int2(l);
    if (mirror) s.x = w - 1 - s.x;
    return texel(sx + s.x, sy + s.y);
}

// the same, turned: `down` is the screen direction the sprite's bottom points to, `pivot` the
// sprite pixel that sits on `at`
float4 spriteTurned(int2 cell, float2 at, float2 down, float2 pivot, float scale, int sx, int sy, int w, int h)
{
    float2 q = float2(cell) + 0.5 - at;
    float2 right = float2(-down.y, down.x);
    float2 l = float2(dot(q, right), dot(q, down)) / scale + pivot;
    if (l.x < 0 || l.y < 0 || l.x >= w || l.y >= h) return 0;
    return texel(sx + (int)l.x, sy + (int)l.y);
}

// ---------------------------------------------------------------- lightning

// one strike's light over time: swells in, flickers, flares again, then dies away slowly
float strikeLight(float a)
{
    if (a < 0.0 || a > 2.5) return 0.0;
    float e;
    if (a < 0.07)       e = a / 0.07;
    else if (a < 0.12)  e = 1.0;
    else if (a < 0.18)  e = lerp(1.0, 0.30, (a - 0.12) / 0.06);
    else if (a < 0.25)  e = lerp(0.30, 0.90, (a - 0.18) / 0.07);
    else                e = 0.90 * exp(-(a - 0.25) * 2.6);
    if (a > 0.3 && a < 0.9) e *= 0.82 + 0.18 * step(0.5, frac(a * 11.0));   // crackle as it fades
    return e;
}

// the ghost's visit: n is which visit, t the seconds into it; s holds the three strike times
void ghostTimes(float T, out float n, out float t, out float3 s)
{
    float f = loopFreq(1.0 / GHOST_PERIOD);
    float p = T * f;
    n = loopIndex(floor(p), f);
    t = frac(p) / f;
    s.x = 1.0 + hash(n * 3.1) * 0.8;
    s.y = s.x + 0.6 + hash(n * 5.7) * 1.9;      // uneven gaps
    s.z = s.y + 0.35 + hash(n * 8.3) * 1.5;
}

float flashAt(float t, float n, float3 s)
{
    float f = strikeLight(t - s.x) * (0.85 + 0.15 * hash(n + 1.0));
    f = max(f, strikeLight(t - s.y) * (0.65 + 0.35 * hash(n + 2.0)));
    f = max(f, strikeLight(t - s.z) * (0.80 + 0.20 * hash(n + 3.0)));
    return f;
}

// the bolt itself, while a strike is young: a jagged line from the top down to the hills
float bolt(float2 c, float t, float n, float3 s, float bottom, float2 grid)
{
    float b = 0.0;
    for (int i = 0; i < 3; i++)
    {
        float a = t - s[i];
        if (a < 0.0 || a > 0.32) continue;
        float seed = n * 17.0 + i * 5.3;
        float x0 = grid.x * (0.08 + 0.84 * hash(seed));
        float x  = x0 + noise1(c.y * 0.07 + seed) * 16.0 + noise1(c.y * 0.31 + seed * 2.0) * 4.0;
        float on = strikeLight(a) > 0.45 ? 1.0 : 0.55;
        if (c.y <= bottom && abs(c.x - x) < (c.y < bottom * 0.5 ? 1.5 : 1.0)) b = max(b, on);
        // a branch splitting off part way down
        float by = bottom * (0.30 + 0.25 * hash(seed + 1.0));
        float dir = hash(seed + 2.0) < 0.5 ? -1.0 : 1.0;
        if (c.y > by && c.y < by + bottom * 0.35)
        {
            float bx0 = x0 + noise1(by * 0.07 + seed) * 16.0 + noise1(by * 0.31 + seed * 2.0) * 4.0;
            float bx = bx0 + dir * (c.y - by) * 0.8 + noise1(c.y * 0.4 + seed * 3.0) * 3.0;
            if (abs(c.x - bx) < 0.8) b = max(b, on * 0.75);
        }
        // glow round the bolt lights the clouds near it
        b = max(b, saturate(1.0 - abs(c.x - x) / 30.0) * 0.18 * strikeLight(a) * step(c.y, bottom));
    }
    return b;
}

// ---------------------------------------------------------------- the ghost

// is cell c inside the ghost's sheet? p.x across, p.y down, both in ghost heights from its crown
bool inGhost(float2 p, float T, out float lit)
{
    lit = 0.0;
    float v = p.y;
    if (v < 0.0 || v > 1.12) return false;
    float wind = WIND * (1.0 + 0.3 * sin(T * loopRate(0.7)));
    // the wind blows from the right, so the lower the cloth the further it streams to the left
    float bend = -wind * pow(max(v - 0.12, 0.0), 1.4) * 1.5 - 0.025 * sin(v * 9.0 - T * loopRate(5.0)) * v;
    float u = p.x - bend;
    bool inside;
    if (v < 0.30)
        inside = u * u + (v - 0.30) * (v - 0.30) < 0.28 * 0.28;
    else
    {
        float d = v - 0.30;
        float wR = 0.28 + 0.03 * d - 0.03 * sin(v * 13.0 - T * loopRate(6.5)) * d;      // pressed flat by the wind
        float wL = 0.28 + 0.30 * pow(d, 1.2) + 0.06 * sin(v * 8.0 - T * loopRate(5.5)) * d; // billowing out
        float hem = 0.95 + 0.05 * sin(u * 21.0 - T * loopRate(7.0)) + 0.06 * abs(sin(u * 7.0 + T * loopRate(3.0)))
                  - 0.12 * saturate(-u / 0.5) * (0.6 + 0.4 * sin(T * loopRate(4.0)));   // the windward hem lifts
        inside = u > -wL && u < wR && v < hem;
        // ragged tails torn off the leeward side, flapping out in the wind
        for (int i = 0; i < 3 && !inside; i++)
        {
            float fi = (float)i;
            float len = 0.16 + 0.07 * sin(T * loopRate(3.1) + fi * 2.0);
            float along = (-wL - u) / len;                       // 0 where it leaves the cloth, 1 at its tip
            if (along < -0.2 || along > 1.0) continue;
            float cy = 0.62 + 0.15 * fi + 0.05 * sin(along * 5.0 - T * loopRate(8.0) + fi) - along * 0.06;
            inside = abs(v - cy) < 0.035 * (1.0 - along) + 0.004;
        }
    }
    if (!inside) return false;
    // folds run down the cloth and ripple with the wind; the moon lights it from the upper right
    float fold = sin(u * 30.0 + v * 5.0 - T * loopRate(3.5) + v * v * 8.0);
    lit = 0.72 + 0.20 * fold * saturate(v * 1.4) + 0.25 * saturate(u / 0.3) - 0.20 * saturate(v - 0.6);
    return true;
}

float3 drawGhost(float3 col, int2 cell, float2 grid, float T, float alpha, float flash, float dth)
{
    if (alpha <= 0.0) return col;
    float h = grid.y * GHOST_HEIGHT;
    float2 crown = float2(grid.x * 0.5 + sin(T * loopRate(0.31)) * grid.x * 0.025,
                          grid.y * GHOST_TOP + sin(T * loopRate(0.9)) * 2.5);
    float2 p = (float2(cell) + 0.5 - crown) / h;
    if (p.x < -0.75 || p.x > 0.45 || p.y < -0.05 || p.y > 1.15) return col;
    float lit;
    bool inside = inGhost(p, T, lit);
    if (!inside)
    {
        // a faint cold aura just outside the cloth
        float l2;
        if (inGhost(float2(p.x * 0.93, (p.y - 0.5) * 0.95 + 0.5), T, l2) && dth < alpha * 0.6)
            col += float3(0.05, 0.06, 0.10) * (1.0 + flash);
        return col;
    }
    // appear and vanish as a dissolve, not a fade, to keep it pixel-art
    if (dth > alpha) return col;
    float l0, l1, l2, l3;
    float px = 1.0 / h;
    bool edge = !inGhost(p + float2(px, 0), T, l0) || !inGhost(p - float2(px, 0), T, l1)
             || !inGhost(p + float2(0, px), T, l2) || !inGhost(p - float2(0, px), T, l3);
    float3 g = lerp(GHOST_SHADE, GHOST_LIGHT, steps(lit, 5.0, dth * 0.3));
    if (edge) g = GHOST_EDGE;
    // the two eye holes, leaning with the head
    float wind = WIND * (1.0 + 0.3 * sin(T * loopRate(0.7)));
    float2 e = p - float2(-wind * 0.05, 0.21);
    for (int side = -1; side <= 1; side += 2)
    {
        float2 q = e - float2(side * 0.095, side * 0.008);
        q.x += q.y * 0.25 * side;                     // slanted a little, for a sad, hollow look
        if ((q.x * q.x) / (0.048 * 0.048) + (q.y * q.y) / (0.075 * 0.075) < 1.0) g = GHOST_EYE;
    }
    g *= 1.0 + flash * 0.4;
    return lerp(col, g, GHOST_OPACITY);
}

// ---------------------------------------------------------------- the rest of the cast

float3 drawWitches(float3 col, int2 cell, float2 grid, float T, int tick, float3 sky)
{
    for (int k = 0; k < WITCHES; k++)
    {
        float fk = (float)k;
        float trip = WITCH_TRIP * lerp(0.75, 1.35, hash(fk * 3.3));
        float cyc  = trip * lerp(1.4, 2.2, hash(fk * 4.7));
        float f    = loopFreq(1.0 / cyc);
        float ph   = frac(T * f + hash(fk * 9.1)) / f;              // seconds into this witch's cycle
        float tripL = trip * (1.0 / f) / cyc;                       // the trip, stretched to fit the loop
        if (ph > tripL) continue;
        bool right = (k & 1) == 0;
        float sc   = lerp(0.55, 1.15, hash(fk * 5.9));
        float u    = ph / tripL;
        float x    = lerp(-0.1, 1.1, right ? u : 1.0 - u) * grid.x;
        float y    = grid.y * lerp(0.05, 0.32, hash(fk * 7.7)) + sin(T * loopRate(1.3) + fk) * 2.0 + u * 6.0 * (hash(fk) - 0.5);
        int frame  = pmod(tick / 2 + k, 4);
        float4 t = sprite(cell, float2(x - WW * sc * 0.5, y), sc, frame * WW, W_Y, WW, WH, !right);
        // smaller means further away, so a little more lost in the night air
        if (t.w > 0) col = lerp(SILHOUETTE, sky, 0.45 * (1.15 - sc));
    }
    return col;
}

float hillFar(float x, float2 grid)  { return grid.y * (HORIZON - 0.13) + sin(x * 0.012 + 1.0) * 9.0 + sin(x * 0.031) * 4.0 + noise1(x * 0.2) * 1.0; }
float hillNear(float x, float2 grid) { return grid.y * (HORIZON - 0.045) + sin(x * 0.009 + 4.0) * 6.0 + sin(x * 0.023 + 2.0) * 3.0; }

float3 drawYard(float3 col, int2 cell, float2 grid, float flash)
{
    // dead trees standing on the near hill
    for (int k = 0; k < TREES; k++)
    {
        float fk = (float)k;
        float x  = grid.x * (0.06 + 0.88 * (fk + 0.15 + 0.7 * hash(fk * 2.1)) / TREES);
        float sc = lerp(0.8, 1.25, hash(fk * 6.3));
        float4 t = sprite(cell, float2(x - TW * sc * 0.5, hillNear(x, grid) + 3.0 - TH * sc), sc, (k & 1) * TW, T_Y, TW, TH, hash(fk) > 0.5);
        if (t.w > 0) col = SILHOUETTE;
    }
    // gravestones along the brow of the hill, catching moonlight and lightning
    for (int j = 0; j < TOMBS; j++)
    {
        float fj = (float)j;
        float x  = grid.x * (fj + 0.5 + (hash(fj * 3.7) - 0.5) * 0.7) / TOMBS;
        float sc = lerp(0.8, 1.15, hash(fj * 1.3));
        float4 t = sprite(cell, float2(x - GW * sc * 0.5, hillNear(x, grid) + 4.0 + hash(fj * 8.8) * 4.0 - GH * sc), sc,
                          pmod((int)(hash(fj * 4.4) * 4.0), 4) * GW, G_Y, GW, GH, false);
        if (t.w > 0) col = t.rgb * (TOMB_LIGHT * 0.35 + flash * 0.9);
    }
    return col;
}

float3 drawZombies(float3 col, int2 cell, float2 grid, float T, int tick, float flash, float horizonY)
{
    float best = -1.0;
    float3 z = col;
    for (int k = 0; k < ZOMBIES; k++)
    {
        float fk = (float)k;
        float f  = loopFreq(1.0 / (ZOMBIE_TRIP * lerp(0.75, 1.3, hash(fk * 2.9))));
        float d  = frac(T * f + hash(fk * 6.1));                    // 0 on the horizon, 1 at the front
        float p  = d * d;                                           // perspective: slow far away, quick up close
        float sc = lerp(ZOMBIE_FAR, ZOMBIE_NEAR, p);
        float feet = horizonY + 1.0 + (grid.y + ZH * ZOMBIE_NEAR * 0.6 - horizonY) * p;
        float x  = grid.x * (0.5 + (hash(fk * 4.3) - 0.5) * (0.45 + 1.1 * p)) + sin(T * loopRate(0.4) + fk * 2.0) * 1.5 * sc;
        if (p < best) continue;
        int frame = pmod(tick / 3 + k * 3, 4);
        float4 t = sprite(cell, float2(x - ZW * sc * 0.5, feet - ZH * sc), sc, frame * ZW, Z_Y + (k & 1) * ZH, ZW, ZH, hash(fk * 7.0) > 0.5);
        if (t.w == 0) continue;
        best = p;
        // only the lightning shows them; near ones a touch more, as they come into the pumpkin light
        z = t.rgb * (ZOMBIE_DARK + flash * 1.1 + p * 0.06);
    }
    return best >= 0.0 ? z : col;
}

float candle(int k, float T)
{
    float ft = T * 12.0;
    float a = hash(floor(loopIndex(floor(ft), 12.0)) * 1.7 + k * 13.0);
    float b = hash(floor(loopIndex(floor(ft) + 1.0, 12.0)) * 1.7 + k * 13.0);
    return 0.7 + 0.3 * lerp(a, b, frac(ft));
}

float3 pumpkinPools(float3 col, int2 cell, float2 grid, float T, float dth)
{
    for (int k = 0; k < PUMPKINS; k++)
    {
        float2 base = float2(grid.x * PK_X[k], grid.y + PK_BOTTOM[k] - 2.0);
        float2 d = (float2(cell) - base) / (POOL_SIZE * PK_SCALE[k] * float2(1.0, 0.38));
        float l = saturate(1.0 - length(d));
        col += CANDLE_DEEP * steps(l * l, 5.0, dth) * 0.22 * candle(k, T);
    }
    return col;
}

float3 drawPumpkins(float3 col, int2 cell, float2 grid, float T, float flash)
{
    for (int k = 0; k < PUMPKINS; k++)
    {
        float sc = PK_SCALE[k];
        float2 at = float2(grid.x * PK_X[k] - PKW * sc * 0.5, grid.y + PK_BOTTOM[k] - PKH * sc);
        float4 t = sprite(cell, at, sc, PK_KIND[k] * PKW, PK_Y, PKW, PKH, (k & 1) == 1);
        if (t.w == 0) continue;
        float fl = candle(k, T);
        if (abs(t.b - 7.0 / 255.0) < 0.5 / 255.0 && t.r > 0.9)
            col = lerp(CANDLE_DEEP, CANDLE_HOT, saturate(t.g * fl * 1.1 - 0.15)) * (0.75 + 0.5 * fl) * CANDLE_GLOW;
        else
            col = t.rgb * (PUMPKIN_BODY * (0.85 + 0.3 * fl) + flash * 0.9);
    }
    return col;
}

float3 drawHangers(float3 col, int2 cell, float2 grid, float T, int tick, float flash)
{
    float2 c = float2(cell) + 0.5;
    for (int k = 0; k < HANGERS; k++)
    {
        float fk = (float)k;
        float f  = loopFreq(1.0 / (HANG_CYCLE * lerp(0.8, 1.2, hash(fk * 3.0))));
        float ph = frac(T * f + 0.5 * fk + 0.1);
        float n  = loopIndex(floor(T * f + 0.5 * fk + 0.1), f);
        float cyc = 1.0 / f;
        float t  = ph * cyc;
        float len = grid.y * lerp(0.22, 0.48, hash(n * 2.3 + fk));
        float l = 0.0;
        if (t < 3.0)        l = len * (1.0 - pow(1.0 - t / 3.0, 3.0)) * (1.0 + 0.10 * sin(t * 9.0) * (t / 3.0)); // drop, with a bounce
        else if (t < 12.0)  l = len * (1.0 + 0.04 * sin(t * 4.0) * exp(-(t - 3.0)));
        else if (t < 16.5)  l = len * (1.0 - (t - 12.0) / 4.5);                                                // climb back up
        else continue;
        float swing = 0.30 * sin(t * 1.7 + fk) * exp(-max(t - 3.0, 0.0) * 0.15) * saturate(t / 2.0);
        float2 anchor = float2(grid.x * (0.12 + 0.76 * hash(n * 5.1 + fk * 11.0)), -1.0);
        float2 down = float2(sin(swing), cos(swing));
        float2 body = anchor + down * l;
        // the thread
        float2 pa = c - anchor;
        float h = saturate(dot(pa, down) / max(l, 1.0));
        if (length(pa - down * h * l) < 0.55 && h < 1.0) col = lerp(col, THREAD_COLOUR * (1.0 + flash), 0.7);
        float4 s = spriteTurned(cell, body, down, float2(12.0, 1.0), HANG_SCALE, (pmod(tick / 2 + k, 2)) * HW, H_Y, HW, HH);
        if (s.w > 0) col = s.rgb * (0.9 - flash * 0.6);
    }
    return col;
}

// a spider walking about on the inside of the glass: walk a stretch, stop, turn, walk again
float3 drawCrawlers(float3 col, int2 cell, float2 grid, float T, int tick, float flash)
{
    for (int k = 0; k < CRAWLERS; k++)
    {
        float fk = (float)k;
        float f  = loopFreq(1.0 / (CRAWL_STEP * lerp(0.85, 1.25, hash(fk * 1.1))));
        float span = T * f + hash(fk * 2.2);
        float m  = floor(span);
        float a  = frac(span);
        float m0 = loopIndex(m, f), m1 = loopIndex(m + 1.0, f), m2 = loopIndex(m + 2.0, f);
        // waypoints scattered over the window and a little past its edges, so spiders come and go
        float2 w0 = float2(hash(m0 * 1.3 + fk * 7.0), hash(m0 * 2.9 + fk * 3.0)) * 1.4 - 0.2;
        float2 w1 = float2(hash(m1 * 1.3 + fk * 7.0), hash(m1 * 2.9 + fk * 3.0)) * 1.4 - 0.2;
        float2 w2 = float2(hash(m2 * 1.3 + fk * 7.0), hash(m2 * 2.9 + fk * 3.0)) * 1.4 - 0.2;
        float walk = 0.55;
        float2 pos = lerp(w0, w1, smoothstep(0.0, 1.0, saturate(a / walk))) * grid;
        float2 d0 = normalize((w1 - w0) * grid + 1e-4);
        float2 d1 = normalize((w2 - w1) * grid + 1e-4);
        // turn towards the next stretch at the end of the rest
        float turn = smoothstep(0.80, 1.0, a);
        float2 dir = normalize(lerp(d0, d1, turn) + 1e-4);
        bool moving = a < walk || turn > 0.0;
        int frame = moving ? pmod(tick + k, 4) : 0;
        float4 s = spriteTurned(cell, pos, -dir, float2(20.0, 22.0), CRAWL_SCALE, frame * SW, S_Y, SW, SH);
        // lit from behind by the scene, so mostly dark; a flash turns it into a black shape
        if (s.w > 0) col = s.rgb * (0.85 - flash * 0.75);
    }
    return col;
}

// ---------------------------------------------------------------- the whole picture

float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET
{
    float  s     = max(Scale, 1.0);
    float  size  = CELL_PIXELS * s;
    int2   cell  = int2(floor(pos.xy / size));
    float2 grid  = floor(Resolution / size);
    int    tick  = (int)floor(Time * FPS);
    float  T     = tick / FPS;
    float  Tf    = floor(Time * FLASH_FPS) / FLASH_FPS;
    float  dth   = dither(cell);
    float2 c     = float2(cell) + 0.5;
    float  horizonY = floor(grid.y * HORIZON);

    uint iw, ih;
    image.GetDimensions(iw, ih);
    bool sprites = iw == SHEET_W && ih == SHEET_H;

    float n, gt; float3 strikes;
    ghostTimes(Tf, n, gt, strikes);
    float flash = steps(flashAt(gt, n, strikes), FLASH_STEPS, dth * 0.6);
    float ghostA = saturate((gt - strikes.x + 0.1) / GHOST_FADE_IN) * saturate((strikes.x + GHOST_STAY + GHOST_FADE_OUT - gt) / GHOST_FADE_OUT);

    // --- sky ---
    float v = c.y / max(horizonY, 1.0);
    float3 col = lerp(SKY_TOP, SKY_LOW, steps(v, SKY_BANDS, dth));
    float star = hash2(float2(cell));
    if (star > 0.9965 && v < 0.75) col += (0.25 + 0.35 * hash(star * 91.0 + loopIndex(floor(T * 1.5), 1.5))) * float3(0.9, 0.85, 1.0);
    float2 moon = MOON_POS * grid;
    float mr = MOON_SIZE * grid.y;
    float md = length(c - moon);
    col += MOON_HALO * steps(saturate(1.0 - (md - mr) / (mr * 1.6)), 4.0, dth) * 0.7;
    if (md < mr)
    {
        float crater = hash2(floor((c - moon) / 4.0) + 3.0);
        float3 m = MOON_COLOUR * (0.86 + 0.14 * steps(1.0 - md / mr, 3.0, dth));
        if (crater > 0.78) m *= 0.84;
        if (length(c - moon - float2(-0.3, -0.2) * mr) < mr * 0.22) m *= 0.85;
        if (length(c - moon - float2(0.25, 0.35) * mr) < mr * 0.15) m *= 0.88;
        col = m;
    }
    // drifting clouds, lit at the rim near the moon
    float2 cp = c * float2(0.010, 0.045) + float2(T * loopRate(0.05) / TAU * 6.0, 0.0);
    float cl = noise2(cp) * 0.65 + noise2(cp * 2.7 + 5.0) * 0.35;
    float band = saturate(1.0 - abs(v - 0.30) / 0.24);
    float cloud = cl * band;
    if (cloud > 0.55)
    {
        // the moon lights the clouds' undersides near it
        float rim = saturate(1.0 - md / (mr * 3.0));
        float edge = saturate((0.62 - cloud) / 0.07);
        col = lerp(CLOUD_COLOUR, CLOUD_RIM, steps(rim * (0.35 + 0.65 * edge), 4.0, dth));
        if (md < mr) col = lerp(col, MOON_COLOUR * 0.55, 0.35);     // thin cloud over the moon
        col += FLASH_SKY * flash * 0.45;
    }
    col = lerp(col, FLASH_SKY, flash * 0.55 * (1.0 - v * 0.3));
    float3 sky = col;
    col = lerp(col, BOLT_COLOUR, bolt(c, gt, n, strikes, hillFar(c.x, grid) + 2.0, grid));
    if (sprites) col = drawWitches(col, cell, grid, T, tick, sky);

    // --- hills: the far row lights up in a flash, the near row stays almost black ---
    float hf = hillFar(c.x, grid), hn = hillNear(c.x, grid);
    if (c.y >= hf) col = HILL_FAR * (1.0 + steps(saturate((c.y - hf) / 20.0), 3.0, dth) * -0.3) + FLASH_SKY * flash * HILL_FAR_FLASH * 0.5;
    if (sprites) col = drawYard(col, cell, grid, flash);
    if (c.y >= hn && c.y < horizonY) col = HILL_NEAR + FLASH_SKY * flash * HILL_NEAR_FLASH * 0.4;

    // --- the field rolling towards you, foggy far away ---
    if (c.y >= horizonY)
    {
        float d = saturate((c.y - horizonY) / max(grid.y - horizonY, 1.0));
        float3 g = lerp(GROUND_FAR, GROUND_NEAR, steps(d, 6.0, dth));
        float tuft = hash2(floor(float2(c.x / (1.0 + d * 3.0), c.y)));
        if (tuft > 0.93) g *= 1.5;
        float rows = frac(1.0 / (d + 0.08) * 1.3);                  // furrows bunching up into the distance
        if (rows < 0.12) g *= 0.75;
        col = g * (1.0 + flash * 2.2 * (1.0 - d * 0.6));
        if (sprites) col = pumpkinPools(col, cell, grid, T, dth);
        if (sprites) col = drawZombies(col, cell, grid, T, tick, flash, horizonY);
    }
    // --- ground fog drifting across, thick at the horizon and thinning towards you ---
    float fy = (c.y - (horizonY - 10.0)) / max(grid.y - horizonY, 1.0);
    if (fy > -0.2)
    {
        float fd = saturate(1.0 - abs(fy - 0.12) / 0.55);
        float drift = 0.55 + 0.45 * sin(c.x * 0.025 + T * loopRate(0.25) + c.y * 0.2) * sin(c.x * 0.011 - T * loopRate(0.13));
        col = lerp(col, FOG_COLOUR * (1.0 + flash * 2.5), steps(fd * fd * drift * FOG_AMOUNT, 5.0, dth));
    }

    if (sprites)
    {
        col = drawGhost(col, cell, grid, T, ghostA, flash, dth);
        col = drawPumpkins(col, cell, grid, T, flash);
        col = drawHangers(col, cell, grid, T, tick, flash);
        col = drawCrawlers(col, cell, grid, T, tick, flash);
    }
    else col = drawGhost(col, cell, grid, T, ghostA, flash, dth);

    // dark corners, in dithered steps so it stays pixel-art
    float2 e = c / grid - 0.5;
    col *= 1.0 - EDGE_DARK * steps(saturate(dot(e, e) * 2.2), 5.0, dth);
    col = saturate(col * SCENE_BRIGHT);

    // letters on top, crisp; the picture fades out underneath them so they stay readable
    float3 text = readText(tex);
    return float4(text + col * (1.0 - ink(text)), 1.0);
}
