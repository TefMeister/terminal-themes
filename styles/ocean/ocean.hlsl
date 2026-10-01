// Ocean: a calm pixel-art view under the sea, drawn behind the text.
// Everything is drawn on a coarse grid of "cells" (chunky pixels) and only changes FPS times a
// second, for a retro terminal look. Above a still, barely swaying surface near the top is daylight
// sky with a few slow clouds; below it the water, fading to black at the sides. Back to front: a sea
// floor rolling away into the distance with faint far plants, far fish (and the whale, when it passes
// far off), the back row of plants, middle fish (and the whale, when it passes nearer), the crab,
// rocks and the front row of plants, near fish, then bubbles. A school of small silver fish wanders
// through at its own depth, turning almost together. So fish swim behind plants too.
// Fish, plants, rocks, the whale and the school fish are pixel sprites from ocean-sheet.png (drawn by
// ocean-sprites.py and ocean-creatures.py; the sheet layout constants below must match).
// The colour scheme's background must be pure black: anything not black counts as text.
Texture2D shaderTexture;
Texture2D image;
SamplerState samplerState;
cbuffer PixelShaderSettings { float Time; float Scale; float2 Resolution; float4 Background; };

// --- the pixel look ---
static const float  CELL_PIXELS    = 3.0;    // screen pixels per chunky pixel
static const float  FPS            = 5.0;    // how often the picture changes per second
static const float  SCENE_BRIGHT   = 0.48;   // overall tank brightness (text is not affected)

// --- sprite sheet layout (matches ocean-sprites.py) ---
static const int    SHEET_W = 832, SHEET_H = 832;
static const int    FW = 32, FH = 24;        // fish cell
static const int    PW = 40, PH = 64;        // plant / rock cell
static const int    PLANT_FRAMES   = 16;
static const int    PLANT_KINDS    = 10;     // rows 0..9 plants
static const int    ROCK_FIRST     = 10;     // rows 10..12 rocks
static const int    ROCK_KINDS     = 3;
static const int    FISH_SPECIES   = 7;      // fish rows; the next row is the crab
static const int    FISH_X         = PW * PLANT_FRAMES;  // fish columns: 0-1 side, 2-3 head-on, 4-5 from behind
static const int    WHALE_W = 128, WHALE_H = 40, WHALE_Y = 192, WHALE_FRAMES = 4;  // under the fish, one frame per row
static const int    SCHOOL_W = 16, SCHOOL_H = 8, SCHOOL_Y = 352;                   // school fish: 2 frames side by side

// --- daylight sky above the water ---
static const float  SKY_SHARE      = 0.15;   // share of the height above the water line
static const float3 SKY_TOP        = float3(0.42, 0.68, 0.96);
static const float3 SKY_LOW        = float3(0.86, 0.94, 1.00);   // paler near the sea
static const float  SKY_BANDS      = 6.0;
static const float3 CLOUD_COLOUR   = float3(1.00, 1.00, 1.00);
static const float  CLOUD_DRIFT    = 0.012;  // how fast the clouds drift (cloud widths per second)
static const float  SURFACE_SWAY   = 0.25;   // how quickly the still surface rises and falls a cell here and there
static const float3 SURFACE_COLOUR = float3(0.78, 0.92, 0.98);
static const float3 GLINT_COLOUR   = float3(1.00, 1.00, 0.95);   // sunlight glinting on the surface

// --- water, sea floor ---
static const float3 WATER_TOP      = float3(0.700, 0.920, 1.000);
static const float3 WATER_DEEP     = float3(0.350, 0.650, 0.880);
static const float  WATER_BANDS    = 7.0;    // colour steps from top to bottom (retro banding)
static const float3 RAY_COLOUR     = float3(0.05, 0.10, 0.11);
static const float  RAY_LEVEL      = 0.82;   // higher = fewer light rays from the surface
static const float3 SAND_A         = float3(0.200, 0.160, 0.100);
static const float3 SAND_B         = float3(0.165, 0.130, 0.080);
static const float3 SAND_C         = float3(0.240, 0.200, 0.130);
static const float  SAND_ROWS      = 7.0;    // near sand depth in cells
static const float  HORIZON        = 0.34;   // how high the far sea floor reaches (share of the water)

// --- plants and rocks ---
static const int    PLANTS_FAR     = 12;     // small, hazy, on the distant floor
static const int    PLANTS_MID     = 14;     // between the far floor and the tank front
static const int    PLANTS_BACK    = 10;      // behind the middle fish
static const int    ROCKS          = 5;
static const int    PLANTS_FRONT   = 5;      // in front of the middle fish
static const float  FAR_SCALE      = 0.5;
static const float  FAR_HAZE       = 0.65;   // how much far things melt into the water
static const float  BACK_HAZE      = 0.35;
static const float  MID_SCALE      = 0.75;
static const float  MID_HAZE       = 0.5;
static const float  MID_DEPTH      = 0.45;   // where the middle row stands, from far ridge (0) to front sand (1)
// plant kinds picked for rows, weighted towards green: 0 seagrass, 6 bubble anemone, 8 fern, 9 cabomba
static const int    PLANT_PICK[16] = { 0, 0, 0, 6, 6, 8, 8, 8, 9, 9, 9, 1, 2, 3, 5, 7 };

// --- fish ---
static const int    FISH_COUNT     = 14;     // two of each of the 7 kinds
// Each fish repeats a two-part routine: swim sideways a stretch, then swim nearer or further
// (seen head-on when coming closer, from behind when going away), drifting up and down throughout.
static const float  SIDE_SECONDS   = 9.0;    // typical time for a sideways stretch
static const float  DEPTH_SECONDS  = 6.0;    // typical time to swim nearer or further
static const float  FISH_STEP      = 0.05;   // how far a sideways stretch goes (about 2.2x this share of the width)
static const float  FISH_MIN_SCALE = 0.35;   // size when furthest away
static const float  FISH_MAX_SCALE = 1.30;   // size when closest
static const float  END_ON_DEPTH   = 0.22;
static const float  TURN_SECONDS   = 1.2;    // time spent turning between side-on and head-on / from behind
static const float  TURN_THIN      = 0.25;   // how thin the side view gets at the middle of a turn   // depth change needed before we see a fish head-on or from behind
static const float  FAR_FISH_HAZE  = 0.6;    // how much the furthest fish melt into the water
static const float  FISH_BOB       = 1.5;    // cells of gentle up and down bobbing
static const float  FISH_DIM       = 0.85;   // the crab's brightness
// fish brightness and colour strength by distance: dim and washed out far away, bright and vivid close up
static const float  FISH_FAR_BRIGHT  = 0.50;
static const float  FISH_NEAR_BRIGHT = 1.20;
static const float  FISH_FAR_SAT     = 0.70;  // 1 = the sprite's own colours, below 1 = greyer
static const float  FISH_NEAR_SAT    = 1.30;  // above 1 = more vivid

// --- the whale: now and then it swims across, far off or a little nearer, never close ---
static const float  WHALE_CYCLE    = 75.0;   // seconds from one crossing to the next
static const float  WHALE_TRIP     = 0.70;   // share of that spent crossing
static const float  WHALE_FAR      = 0.85;   // size far off (it passes behind the middle plants)...
static const float  WHALE_MID      = 1.55;   // ...and nearer (behind the back row of plants)
static const float  WHALE_FAR_HAZE = 0.60;
static const float  WHALE_MID_HAZE = 0.35;

// --- the school: small silver fish moving as one, each a little out of step ---
static const int    SCHOOL_COUNT   = 22;
static const float  SCHOOL_SPEED   = 0.05;   // how quickly the school wanders (radians of its path per second)
static const float  SCHOOL_SPREAD  = 16.0;   // how far the fish spread from the middle, in cells (at full size)
static const float  SCHOOL_LAG     = 0.9;    // the most seconds a fish trails the others in a turn
static const float  SCHOOL_HAZE    = 0.45;   // how much the school melts into the water when far

// --- crab ---
static const float  CRAB_WANDER    = 0.22;   // share of the width it walks back and forth over
static const float  CRAB_SPEED     = 0.05;

// --- bubbles ---
static const int    BUBBLE_STREAMS = 5;
static const int    BUBBLES_EACH   = 4;
static const float  BUBBLE_RISE    = 0.06;   // trips per second from floor to surface
static const float3 BUBBLE_COLOUR  = float3(0.35, 0.58, 0.65);

// --- looping, for recording a clip ---
// 0 = off: the tank runs freely, as it should in the terminal. Set it to a number of seconds and
// everything that moves repeats exactly that often, so a recording of that length loops without a
// seam: fish swim there and back, and every rate is snapped to one that fits the loop. Use a
// multiple of PLANT_FRAMES / FPS (3.2 s); 32 works well.
static const float  LOOP_SECONDS   = 0.0;
static const float  TAU            = 6.28318530718;

// --- user messages (same marker the Matrix Claude theme uses) ---
static const float3 MARKER         = float3(0.0, 0.0, 3.0 / 255.0);
static const float3 USER_COLOUR    = float3(1.00, 0.78, 0.55);
static const int    ROW_SAMPLES    = 48;

static const float BAYER[16] = { 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5 };

float hash(float n) { return frac(sin(n * 127.1 + 11.7) * 43758.5453); }
float hash2(float2 p) { return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453); }
// modulo that never goes negative (Time, and so tick, can be negative)
int pmod(int a, int n) { int m = a % n; return m < 0 ? m + n : m; }

float noise2(float2 p)
{
    float2 i = floor(p), f = frac(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash2(i), b = hash2(i + float2(1, 0)), c = hash2(i + float2(0, 1)), d = hash2(i + float2(1, 1));
    return lerp(lerp(a, b, f.x), lerp(c, d, f.x), f.y);
}

float dither(int2 c) { return (BAYER[(c.y & 3) * 4 + (c.x & 3)] + 0.5) / 16.0; }

// in loop mode, snap a rate (radians per second) or a frequency (trips per second) to the nearest
// one that fits the loop exactly; otherwise leave it alone
float loopRate(float w) { return LOOP_SECONDS > 0.0 ? max(1.0, round(w * LOOP_SECONDS / TAU)) * TAU / max(LOOP_SECONDS, 1.0) : w; }
float loopFreq(float f) { return LOOP_SECONDS > 0.0 ? max(1.0, round(f * LOOP_SECONDS)) / max(LOOP_SECONDS, 1.0) : f; }

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

// one sprite texel; w = 0 where the sheet is magenta (empty)
float4 texel(int x, int y)
{
    float3 c = image.Load(int3(x, y, 0)).rgb;
    // magenta = empty in the sheet; pure black never appears in the art, so it means the
    // picture is not (fully) loaded yet or we read past its edge: treat it as empty too
    bool empty = (c.r > 0.9 && c.g < 0.1 && c.b > 0.9) || max(c.r, max(c.g, c.b)) < 0.02;
    return float4(c, empty ? 0.0 : 1.0);
}

// the distant sea floor's top edge: gentle hills
float ridgeAt(float cx, float horizon)
{
    return floor(horizon + sin(cx * 0.031) * 3.0 + sin(cx * 0.011 + 2.0) * 5.0 + hash(floor(cx / 5.0)) * 1.5);
}

// a row of plants or rocks. kinds come from rows [first, first + kinds) of the sheet.
// bottom < 0 means "stand on the distant ridge".
float3 drawRow(float3 col, int2 cell, float2 grid, float bottom, float horizon, int tick,
               int count, float seed, int first, int kinds, float scale, float haze, float3 water)
{
    int w = (int)(PW * scale), h = (int)(PH * scale);
    for (int k = 0; k < count; k++)
    {
        float fk   = (float)k + seed;
        float slot = grid.x / count;
        float cx   = floor(slot * (k + 0.5) + (hash(fk * 3.1) - 0.5) * slot * 0.8);
        float ridge = ridgeAt(cx, horizon);
        float b    = bottom >= 0 ? bottom : (bottom > -1.5 ? ridge + 3.0 : floor(lerp(ridge, grid.y - SAND_ROWS, MID_DEPTH)) + 2.0);
        int2  loc  = cell - int2((int)cx - w / 2, (int)b - h);
        if (loc.x < 0 || loc.y < 0 || loc.x >= w || loc.y >= h) continue;
        int pick  = min((int)(hash(fk * 5.7 + 2.0) * 16.0), 15);
        int kind  = first == 0 ? PLANT_PICK[pick] : first + min((int)(hash(fk * 5.7 + 2.0) * kinds), kinds - 1);
        int2 src  = min(int2(float2(loc) / scale), int2(PW - 1, PH - 1));
        if (hash(fk * 1.9) > 0.5) src.x = PW - 1 - src.x;
        int frame = pmod(tick + k * 5, PLANT_FRAMES);
        float4 t  = texel(frame * PW + src.x, kind * PH + src.y);
        if (t.w > 0) col = lerp(t.rgb, water, haze);
    }
    return col;
}

float tri(float p) { return 1.0 - abs(2.0 * frac(p) - 1.0); }

// where fish k is at time T. p = (x across the width, height in the water 0 top..1 bottom,
// depth 0 far..1 near). view: 0 side, 1 head-on, 2 from behind. right: faces right when seen side-on.
// squeeze: how wide the side view is drawn (1 = normal); narrowing it reads as the fish turning.
void fishPose(int k, float T, out float3 p, out int view, out bool right, out float squeeze)
{
    float fk = (float)k;
    float side, deep, cyc, a, x0, x1, x2, z0, z1, y0, y1;
    if (LOOP_SECONDS > 0.0)
    {
        // loop mode: there and back between two spots. A slow fish makes 2 legs per loop, a quick
        // one 4, so every fish is exactly where it started when the loop comes round.
        float legs = hash(fk * 2.3) < 0.5 ? 2.0 : 4.0;
        cyc  = LOOP_SECONDS / legs;
        side = cyc * SIDE_SECONDS / (SIDE_SECONDS + DEPTH_SECONDS);
        deep = cyc - side;
        float t  = T + hash(fk * 6.1) * LOOP_SECONDS;
        float m  = floor(t / cyc);
        a        = t - m * cyc;
        bool going = m - 2.0 * floor(m * 0.5) < 0.5;             // even legs go out, odd legs come back
        float xA = hash(fk * 8.1);
        float xB = saturate(xA + (hash(fk * 4.3) < 0.5 ? -2.2 : 2.2) * FISH_STEP * lerp(0.6, 1.4, hash(fk * 1.7)));
        float zA = hash(fk * 3.9), zB = hash(fk * 3.9 + 12.5);
        float yA = hash(fk * 5.3), yB = hash(fk * 5.3 + 9.1);
        x0 = going ? xA : xB;  x1 = going ? xB : xA;  x2 = x0;
        z0 = going ? zA : zB;  z1 = going ? zB : zA;
        y0 = going ? yA : yB;  y1 = going ? yB : yA;
    }
    else
    {
        side = SIDE_SECONDS  * lerp(0.7, 1.3, hash(fk * 1.7));
        deep = DEPTH_SECONDS * lerp(0.7, 1.3, hash(fk * 2.3));
        cyc  = side + deep;
        float t    = T + hash(fk * 6.1) * 500.0;
        float m    = floor(t / cyc);
        a          = t - m * cyc;
        float step = FISH_STEP * lerp(0.6, 1.4, hash(fk * 4.3));
        float c0   = hash(fk * 8.1);
        // the sideways path bounces back and forth across the tank, so fish turn around at the ends
        x0 = tri(c0 + m * step);                x1 = tri(c0 + (m + 1.0) * step);
        z0 = hash(fk * 3.9 + frac(m * 0.137) * 91.0); z1 = hash(fk * 3.9 + frac((m + 1.0) * 0.137) * 91.0);
        y0 = hash(fk * 5.3 + frac(m * 0.211) * 73.0); y1 = hash(fk * 5.3 + frac((m + 1.0) * 0.211) * 73.0);
        x2 = tri(c0 + (m + 2.0) * step);
    }
    right = x1 >= x0;
    bool nextRight = x2 >= x1;
    view  = 0;
    squeeze = 1.0;
    float x, z;
    if (a < side)
    {
        x = lerp(x0, x1, smoothstep(0.0, 1.0, a / side));
        z = z0;
    }
    else
    {
        x = x1;
        float q = (a - side) / deep;
        z = lerp(z0, z1, smoothstep(0.0, 1.0, q));
        if (abs(z1 - z0) > END_ON_DEPTH)
        {
            // turn in (side view narrowing), swim end-on, turn out towards the next direction
            float qa = min(0.3, TURN_SECONDS / deep);
            if (q < qa)             squeeze = lerp(1.0, TURN_THIN, q / qa);
            else if (q > 1.0 - qa) { squeeze = lerp(TURN_THIN, 1.0, (q - (1.0 - qa)) / qa); right = nextRight; }
            else                    view = z1 > z0 ? 1 : 2;
        }
        else if (nextRight != right)
        {
            // turning round on the spot: narrow, flip, widen again
            float qt = min(0.5, 0.5 * TURN_SECONDS / deep);
            squeeze = lerp(TURN_THIN, 1.0, saturate(abs(q - 0.5) / qt));
            if (q > 0.5) right = nextRight;
        }
    }
    p = float3(-0.05 + 1.1 * x, lerp(y0, y1, smoothstep(0.0, 1.0, a / cyc)), z);
}

// every fish, sorted into four depth slots that get layered between the plant rows:
// 0 behind the middle plants, 1 behind the back row, 2 behind the front row, 3 in front of everything
void gatherFish(int2 cell, float2 grid, float top, float sand, float horizon, float T, int tick,
                float3 water, out float4 slot[4])
{
    float best[4] = { -1, -1, -1, -1 };
    slot[0] = 0; slot[1] = 0; slot[2] = 0; slot[3] = 0;
    for (int k = 0; k < FISH_COUNT; k++)
    {
        float3 p; int view; bool right; float squeeze;
        fishPose(k, T, p, view, right, squeeze);
        float fk = (float)k;
        float sc = lerp(FISH_MIN_SCALE, FISH_MAX_SCALE, p.z);
        float sx = sc * squeeze;                                 // horizontal scale (narrower mid-turn)
        int   w  = max(1, (int)(FW * sx)), h = (int)(FH * sc);
        float floorY = lerp(horizon, sand, p.z);                  // far fish stay above the far floor
        float yTop   = top + 2.0;
        float yBot   = max(yTop, floorY - h - 1.0);
        float y      = floor(lerp(yTop, yBot, p.y) + sin(T * loopRate(0.5) + fk * 1.9) * FISH_BOB + 0.5);
        float left   = floor(p.x * grid.x - w * 0.5);
        int2  loc    = cell - int2((int)left, (int)y);
        if (loc.x < 0 || loc.y < 0 || loc.x >= w || loc.y >= h) continue;

        int2 src = min(int2(float(loc.x) / sx, float(loc.y) / sc), int2(FW - 1, FH - 1));
        if (view == 0 && !right) src.x = FW - 1 - src.x;
        int frame   = view == 2 ? pmod(tick + k, 2) : pmod(tick / 2 + k, 2);
        int species = min(k / 2, FISH_SPECIES - 1);
        float4 t = texel(FISH_X + (view * 2 + frame) * FW + src.x, species * FH + src.y);
        if (t.w == 0) continue;
        int layer = p.z < 0.3 ? 0 : (p.z < 0.6 ? 1 : (p.z < 0.85 ? 2 : 3));
        if (p.z > best[layer])
        {
            best[layer] = p.z;
            // near fish: brighter and more vivid; far fish: darker, greyer, then melted into the water
            float3 c    = t.rgb;
            float  grey = dot(c, float3(0.299, 0.587, 0.114));
            c = lerp(grey.xxx, c, lerp(FISH_FAR_SAT, FISH_NEAR_SAT, p.z));
            c = saturate(c * lerp(FISH_FAR_BRIGHT, FISH_NEAR_BRIGHT, p.z));
            slot[layer] = float4(lerp(c, water, (1.0 - p.z) * FAR_FISH_HAZE), 1.0);
        }
    }
}

float3 over(float3 col, float4 f) { return f.w > 0 ? f.rgb : col; }

float3 drawCrab(float3 col, int2 cell, float2 grid, float sandTop, float T, int tick)
{
    float x = floor(grid.x * 0.4 + sin(T * loopRate(CRAB_SPEED)) * grid.x * CRAB_WANDER);
    bool moving = abs(cos(T * loopRate(CRAB_SPEED))) > 0.25;
    int2 loc = cell - int2((int)x - FW / 2, (int)sandTop + 2 - FH);
    if (loc.x < 0 || loc.y < 0 || loc.x >= FW || loc.y >= FH) return col;
    int frame = moving ? pmod(tick, 2) : 0;
    float4 t = texel(FISH_X + frame * FW + loc.x, FISH_SPECIES * FH + loc.y);
    return t.w > 0 ? t.rgb * FISH_DIM : col;
}

float3 drawBubbles(float3 col, int2 cell, float2 grid, float top, float bottom, float T)
{
    float2 c = float2(cell);
    for (int i = 0; i < BUBBLE_STREAMS; i++)
    {
        float fi = (float)i;
        float sx = floor(grid.x * (0.12 + 0.76 * hash(fi * 3.7 + 1.0)));
        for (int j = 0; j < BUBBLES_EACH; j++)
        {
            float fj    = (float)j;
            float speed = loopFreq(BUBBLE_RISE * (0.8 + 0.5 * hash(fi + fj * 9.0)));
            float phase = frac(T * speed + fj / BUBBLES_EACH + hash(fi * 5.0));
            float y     = floor(lerp(bottom, top + 1, phase));
            if (y <= top) continue;
            float x     = sx + floor(sin(T * loopRate(1.5) + fj * 2.9 + phase * 9.0) * 1.5 + 0.5);
            float r     = lerp(0.6, 2.2, hash(fi * 7.0 + fj)) * (0.6 + 0.5 * phase);
            float d     = length(c - float2(x, y));
            if (r < 1.0)
            {
                if (d < 0.5) col += BUBBLE_COLOUR;
            }
            else
            {
                if (abs(d - r) < 0.5) col += BUBBLE_COLOUR * 0.8;
                if (all(cell == int2((int)(x - floor(r * 0.5)), (int)(y - floor(r * 0.5))))) col += BUBBLE_COLOUR;
            }
        }
    }
    return col;
}

// the whale, when this crossing is at `layer` (0 far, 1 nearer); otherwise col unchanged
float3 drawWhale(float3 col, int2 cell, float2 grid, float top, float horizon, float T, int tick, float3 water, int layer)
{
    float f = loopFreq(1.0 / WHALE_CYCLE);
    float p = T * f + 0.3;
    float n = floor(p);
    if (LOOP_SECONDS > 0.0) n = 0.0;
    float u = frac(p) / WHALE_TRIP;
    if (u > 1.0) return col;
    int route = hash(n * 3.7) < 0.5 ? 0 : 1;
    if (route != layer) return col;
    bool left = hash(n * 5.1) < 0.5;
    float sc = route == 0 ? WHALE_FAR : WHALE_MID;
    float w = WHALE_W * sc, h = WHALE_H * sc;
    float x = lerp(-0.25 * grid.x - w * 0.5, 1.25 * grid.x + w * 0.5, left ? 1.0 - u : u);
    float yMid = route == 0 ? lerp(top, horizon, 0.62) : lerp(top, horizon, 0.40 + 0.2 * hash(n * 2.2));
    float y = yMid + sin(T * loopRate(0.3)) * 1.5 * sc;
    float2 l = (float2(cell) - float2(x - w * 0.5, y - h * 0.5)) / sc;
    if (l.x < 0 || l.y < 0 || l.x >= WHALE_W || l.y >= WHALE_H) return col;
    int sx = left ? WHALE_W - 1 - (int)l.x : (int)l.x;
    int frame = pmod(tick / 2, WHALE_FRAMES);
    float4 t = texel(FISH_X + sx, WHALE_Y + frame * WHALE_H + (int)l.y);
    if (t.w == 0) return col;
    return lerp(t.rgb, water, route == 0 ? WHALE_FAR_HAZE : WHALE_MID_HAZE);
}

// the school's middle at time t: (x share of the width, height share of the water, depth 0..1)
float3 schoolCentre(float t)
{
    float w = loopRate(SCHOOL_SPEED);
    return float3(0.5 + 0.30 * sin(t * w * 1.0 + 1.0) + 0.10 * sin(t * w * 3.0 + 4.0),
                  0.45 + 0.20 * sin(t * w * 2.0 + 2.0) + 0.06 * sin(t * w * 4.0),
                  0.50 + 0.25 * sin(t * w * 1.0 + 3.0));
}

// the small fish of the school nearest the viewer at this cell. Each follows the school's path a
// little behind the others (its own lag), so a turn ripples through the school instead of the whole
// school flipping at once; each also keeps its own place in the group and wobbles a little.
// Returns the colour (w = 1 if a fish is here) and, in `layer`, which depth slot it belongs in.
float4 drawSchool(int2 cell, float2 grid, float top, float horizon, float T, int tick, float3 water, out int layer)
{
    float3 mid = schoolCentre(T);
    layer = mid.z < 0.3 ? 0 : (mid.z < 0.6 ? 1 : (mid.z < 0.85 ? 2 : 3));
    float sc = lerp(0.55, 1.15, mid.z);
    float2 midXY = float2(mid.x * grid.x, lerp(top + 4.0, horizon, mid.y));
    float2 c = float2(cell) + 0.5;
    if (length((c - midXY) / float2(2.2, 1.0)) > (SCHOOL_SPREAD + 30.0) * sc) return 0;
    float4 r = 0;
    [loop] for (int i = 0; i < SCHOOL_COUNT; i++)
    {
        float fi = (float)i;
        float lag = hash(fi * 3.3) * SCHOOL_LAG;
        float3 a = schoolCentre(T - lag), b = schoolCentre(T - lag - 0.4);
        float2 at = float2(a.x * grid.x, lerp(top + 4.0, horizon, a.y));
        float2 prev = float2(b.x * grid.x, lerp(top + 4.0, horizon, b.y));
        float ang = hash(fi * 7.1) * TAU, rad = sqrt(hash(fi * 5.3));
        at += float2(cos(ang) * 2.2, sin(ang)) * rad * SCHOOL_SPREAD * sc
            + float2(sin(T * loopRate(1.1) + fi), cos(T * loopRate(0.9) + fi * 1.7)) * 1.2;
        float2 v = at - prev;
        float sp = length(v) + 1e-4;
        float squeeze = max(0.3, abs(v.x) / sp);               // narrow while heading up or down: turning
        float sx = sc * squeeze;
        float2 l = float2((c.x - at.x) / sx + SCHOOL_W * 0.5, (c.y - at.y) / sc + SCHOOL_H * 0.5);
        if (l.x < 0 || l.y < 0 || l.x >= SCHOOL_W || l.y >= SCHOOL_H) continue;
        int px = v.x < 0.0 ? SCHOOL_W - 1 - (int)l.x : (int)l.x;
        int frame = pmod(tick + i, 2);
        float4 t = texel(FISH_X + frame * SCHOOL_W + px, SCHOOL_Y + (int)l.y);
        if (t.w == 0) continue;
        float3 fc = saturate(t.rgb * lerp(FISH_FAR_BRIGHT, FISH_NEAR_BRIGHT, mid.z));
        r = float4(lerp(fc, water, (1.0 - mid.z) * SCHOOL_HAZE), 1.0);
    }
    return r;
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
    float  s     = max(Scale, 1.0);
    float  size  = CELL_PIXELS * s;
    int2   cell  = int2(floor(pos.xy / size));
    float2 grid  = floor(Resolution / size);
    int    tick  = (int)floor(Time * FPS);
    float  T     = tick / FPS;
    float  dth   = dither(cell);
    float  cx    = (float)cell.x;

    // if the sprite sheet is missing or still loading, draw only the water (never black boxes)
    uint iw, ih;
    image.GetDimensions(iw, ih);
    bool sprites = iw == SHEET_W && ih == SHEET_H;

    // water line: still, rising or dipping a cell here and there, slowly
    float surfaceRow = floor(grid.y * SKY_SHARE);
    float wave   = sin(cx * 0.13 + T * loopRate(SURFACE_SWAY)) + sin(cx * 0.05 - T * loopRate(SURFACE_SWAY * 0.6));
    float top    = surfaceRow + (wave > 1.6 ? -1.0 : (wave < -1.6 ? 1.0 : 0.0));
    float sand   = grid.y - SAND_ROWS;
    float sandTop = sand - (hash(floor(cx / 3.0)) > 0.65 ? 1.0 : 0.0);
    float horizon = sand - (sand - surfaceRow) * HORIZON;

    float3 col;
    if (cell.y < top)
    {
        // daylight: a banded blue sky, paler near the sea, with a few soft clouds drifting by
        float v = cell.y / max(top, 1.0);
        col = lerp(SKY_TOP, SKY_LOW, floor(v * SKY_BANDS + dth) / SKY_BANDS);
        float2 cp = float2(cx * 0.012 + (LOOP_SECONDS > 0.0 ? 0.0 : T * CLOUD_DRIFT), cell.y * 0.06);
        float cl = noise2(cp) * 0.7 + noise2(cp * 2.5 + 3.0) * 0.3;
        cl *= saturate(1.0 - abs(v - 0.4) / 0.45);
        if (cl > 0.55) col = lerp(col, CLOUD_COLOUR, floor(saturate((cl - 0.55) / 0.15) * 3.0 + dth) / 3.0 * 0.8);
    }
    else if (cell.y == top)
    {
        // the surface line, with sunlight glinting on it here and there
        col = SURFACE_COLOUR;
        float glint = floor(T * 0.75);
        if (LOOP_SECONDS > 0.0) glint = (float)pmod((int)glint, max(1, (int)round(LOOP_SECONDS * 0.75)));
        if (hash2(float2(floor(cx / 2.0), glint)) > 0.93) col = GLINT_COLOUR;
    }
    else
    {
        float depth = saturate((cell.y - top) / max(sand - top, 1.0));
        float band  = floor(depth * WATER_BANDS + dth) / WATER_BANDS;
        col = lerp(WATER_TOP, WATER_DEEP, band);

        float r   = cx + cell.y * 0.45;
        float ray = sin(r * 0.035 + T * loopRate(0.10)) * sin(r * 0.11 - T * loopRate(0.07));
        if (ray + dth * 0.35 > RAY_LEVEL) col += RAY_COLOUR * (1.0 - depth);
        float3 water = col;

        // the far sea floor: hazy at the ridge, turning into sand as it comes closer
        float ridge = ridgeAt(cx, horizon);
        if (cell.y >= ridge)
        {
            float t  = saturate((cell.y - ridge) / max(sand - ridge, 1.0));
            float3 f = lerp(water, SAND_B * 0.9, floor(t * 0.9 * 6.0 + dth) / 6.0);
            float z  = 1.0 / (t + 0.12);                            // ripples bunch up far away
            if (frac(z * 0.9 + sin(cx * 0.05) * 0.3) < 0.16) f *= 1.15;
            col = f;
        }
        if (cell.y >= sandTop)
        {
            float h = hash2(float2(cell));
            col = h < 0.33 ? SAND_A : (h < 0.66 ? SAND_B : SAND_C);
            if (h > 0.985) col = float3(0.30, 0.28, 0.26);          // a pebble
        }
        if (sprites)
        {
            float4 fish[4];
            gatherFish(cell, grid, top, sand, horizon, T, tick, water, fish);
            int schoolLayer;
            float4 school = drawSchool(cell, grid, top, horizon, T, tick, water, schoolLayer);
            col = drawRow(col, cell, grid, -1.0, horizon, tick, PLANTS_FAR, 50.0, 0, PLANT_KINDS, FAR_SCALE, FAR_HAZE, water);
            col = drawWhale(col, cell, grid, top, horizon, T, tick, water, 0);
            col = over(col, fish[0]);
            if (schoolLayer == 0) col = over(col, school);
            col = drawRow(col, cell, grid, -2.0, horizon, tick, PLANTS_MID, 90.0, 0, PLANT_KINDS, MID_SCALE, MID_HAZE, water);
            col = drawWhale(col, cell, grid, top, horizon, T, tick, water, 1);
            col = over(col, fish[1]);
            if (schoolLayer == 1) col = over(col, school);
            col = drawRow(col, cell, grid, sand + 2.0, horizon, tick, PLANTS_BACK, 0.0, 0, PLANT_KINDS, 1.0, BACK_HAZE, water);
            col = over(col, fish[2]);
            if (schoolLayer == 2) col = over(col, school);
            col = drawCrab(col, cell, grid, sand, T, tick);
            col = drawRow(col, cell, grid, sand + 3.0, horizon, tick, ROCKS, 70.0, ROCK_FIRST, ROCK_KINDS, 1.0, 0.1, water);
            col = drawRow(col, cell, grid, sand + 3.0, horizon, tick, PLANTS_FRONT, 31.0, 0, PLANT_KINDS, 1.0, 0.0, water);
            col = over(col, fish[3]);
            if (schoolLayer == 3) col = over(col, school);
        }
        col = drawBubbles(col, cell, grid, top, sand, T);
    }

    // fade to black at the left and right, in dithered steps so it stays pixel-art
    float fade = screenFade(tex);
    col *= saturate(floor(fade * 6.0 + dth) / 6.0) * SCENE_BRIGHT;

    // letters on top, crisp; the tank fades out underneath them so they stay readable
    float3 text = readText(tex);
    return float4(text + col * (1.0 - ink(text)), 1.0);
}
