// Aquarium: a calm pixel-art fish tank drawn behind the text.
// Everything is drawn on a coarse grid of "cells" (chunky pixels) and only changes FPS times a
// second, for a retro terminal look. Water fills the window up to a surface near the top and
// fades to black at the left and right edges. Back to front: a sea floor rolling away into the
// distance with faint far plants, far fish, the back row of plants, middle fish and the crab,
// rocks and the front row of plants, near fish, then bubbles. So fish swim behind plants too.
// Fish, plants and rocks are pixel sprites from aquarium-sheet.png (drawn by
// aquarium-sprites.py; the sheet layout constants below must match that script).
// The colour scheme's background must be pure black: anything not black counts as text.
Texture2D shaderTexture;
Texture2D image;
SamplerState samplerState;
cbuffer PixelShaderSettings { float Time; float Scale; float2 Resolution; float4 Background; };

// --- the pixel look ---
static const float  CELL_PIXELS    = 3.0;    // screen pixels per chunky pixel
static const float  FPS            = 5.0;    // how often the picture changes per second
static const float  SCENE_BRIGHT   = 0.48;   // overall tank brightness (text is not affected)

// --- sprite sheet layout (matches aquarium-sprites.py) ---
static const int    SHEET_W = 832, SHEET_H = 832;
static const int    FW = 32, FH = 24;        // fish cell
static const int    PW = 40, PH = 64;        // plant / rock cell
static const int    PLANT_FRAMES   = 16;
static const int    PLANT_KINDS    = 10;     // rows 0..9 plants
static const int    ROCK_FIRST     = 10;     // rows 10..12 rocks
static const int    ROCK_KINDS     = 3;
static const int    FISH_SPECIES   = 7;      // fish rows; the next row is the crab
static const int    FISH_X         = PW * PLANT_FRAMES;  // fish columns: 0-1 side, 2-3 head-on, 4-5 from behind

// --- water, air, sea floor ---
static const float3 AIR_COLOUR     = float3(0.015, 0.025, 0.035);
static const float3 SURFACE_COLOUR = float3(0.30, 0.55, 0.65);
static const float3 WATER_TOP      = float3(0.700, 0.920, 1.000);
static const float3 WATER_DEEP     = float3(0.350, 0.650, 0.880);
static const float  WATER_BANDS    = 7.0;    // colour steps from top to bottom (retro banding)
static const float  SURFACE_ROW    = 8.0;    // cells from the top to the water line
static const float3 RAY_COLOUR     = float3(0.05, 0.10, 0.11);
static const float3 SAND_A         = float3(0.200, 0.160, 0.100);
static const float3 SAND_B         = float3(0.165, 0.130, 0.080);
static const float3 SAND_C         = float3(0.240, 0.200, 0.130);
static const float  SAND_ROWS      = 7.0;    // near sand depth in cells
static const float  HORIZON        = 0.34;   // how high the far sea floor reaches (share of the water)
static const float  EDGE_FADE      = 0.14;   // share of the width that fades to black on each side

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
static const float  FISH_DIM       = 0.85;

// --- crab ---
static const float  CRAB_WANDER    = 0.22;   // share of the width it walks back and forth over
static const float  CRAB_SPEED     = 0.05;

// --- bubbles ---
static const int    BUBBLE_STREAMS = 5;
static const int    BUBBLES_EACH   = 4;
static const float  BUBBLE_RISE    = 0.06;   // trips per second from floor to surface
static const float3 BUBBLE_COLOUR  = float3(0.35, 0.58, 0.65);

// --- user messages (same marker the Matrix Claude theme uses) ---
static const float3 MARKER         = float3(0.0, 0.0, 3.0 / 255.0);
static const float3 USER_COLOUR    = float3(1.00, 0.78, 0.55);
static const int    ROW_SAMPLES    = 48;

static const float BAYER[16] = { 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5 };

float hash(float n) { return frac(sin(n * 127.1 + 11.7) * 43758.5453); }
float hash2(float2 p) { return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453); }
// modulo that never goes negative (Time, and so tick, can be negative)
int pmod(int a, int n) { int m = a % n; return m < 0 ? m + n : m; }

float dither(int2 c) { return (BAYER[(c.y & 3) * 4 + (c.x & 3)] + 0.5) / 16.0; }

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
    float fk   = (float)k;
    float side = SIDE_SECONDS  * lerp(0.7, 1.3, hash(fk * 1.7));
    float deep = DEPTH_SECONDS * lerp(0.7, 1.3, hash(fk * 2.3));
    float cyc  = side + deep;
    float t    = T + hash(fk * 6.1) * 500.0;
    float m    = floor(t / cyc);
    float a    = t - m * cyc;
    float step = FISH_STEP * lerp(0.6, 1.4, hash(fk * 4.3));
    float c0   = hash(fk * 8.1);
    // the sideways path bounces back and forth across the tank, so fish turn around at the ends
    float x0 = tri(c0 + m * step),                x1 = tri(c0 + (m + 1.0) * step);
    float z0 = hash(fk * 3.9 + frac(m * 0.137) * 91.0), z1 = hash(fk * 3.9 + frac((m + 1.0) * 0.137) * 91.0);
    float y0 = hash(fk * 5.3 + frac(m * 0.211) * 73.0), y1 = hash(fk * 5.3 + frac((m + 1.0) * 0.211) * 73.0);
    float x2 = tri(c0 + (m + 2.0) * step);
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
        float y      = floor(lerp(yTop, yBot, p.y) + sin(T * 0.5 + fk * 1.9) * FISH_BOB + 0.5);
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
            slot[layer] = float4(lerp(t.rgb * FISH_DIM, water, (1.0 - p.z) * FAR_FISH_HAZE), 1.0);
        }
    }
}

float3 over(float3 col, float4 f) { return f.w > 0 ? f.rgb : col; }

float3 drawCrab(float3 col, int2 cell, float2 grid, float sandTop, float T, int tick)
{
    float x = floor(grid.x * 0.4 + sin(T * CRAB_SPEED) * grid.x * CRAB_WANDER);
    bool moving = abs(cos(T * CRAB_SPEED)) > 0.25;
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
            float speed = BUBBLE_RISE * (0.8 + 0.5 * hash(fi + fj * 9.0));
            float phase = frac(T * speed + fj / BUBBLES_EACH + hash(fi * 5.0));
            float y     = floor(lerp(bottom, top + 1, phase));
            if (y <= top) continue;
            float x     = sx + floor(sin(T * 1.5 + fj * 2.9 + phase * 9.0) * 1.5 + 0.5);
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

    // water line: flat, with the odd one-cell ripple drifting along it
    float wave   = sin(cx * 0.21 + T * 1.7) + sin(cx * 0.09 - T * 1.0);
    float top    = SURFACE_ROW + (wave > 1.3 ? -1.0 : (wave < -1.3 ? 1.0 : 0.0));
    float sand   = grid.y - SAND_ROWS;
    float sandTop = sand - (hash(floor(cx / 3.0)) > 0.65 ? 1.0 : 0.0);
    float horizon = sand - (sand - SURFACE_ROW) * HORIZON;

    float3 col;
    if (cell.y < top)       col = AIR_COLOUR;
    else if (cell.y == top) col = SURFACE_COLOUR;
    else
    {
        float depth = saturate((cell.y - top) / max(sand - top, 1.0));
        float band  = floor(depth * WATER_BANDS + dth) / WATER_BANDS;
        col = lerp(WATER_TOP, WATER_DEEP, band);

        float r   = cx + cell.y * 0.45;
        float ray = sin(r * 0.05 + T * 0.10) * sin(r * 0.11 - T * 0.07);
        if (ray + dth * 0.35 > 0.6) col += RAY_COLOUR * (1.0 - depth);
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
            col = drawRow(col, cell, grid, -1.0, horizon, tick, PLANTS_FAR, 50.0, 0, PLANT_KINDS, FAR_SCALE, FAR_HAZE, water);
            col = over(col, fish[0]);
            col = drawRow(col, cell, grid, -2.0, horizon, tick, PLANTS_MID, 90.0, 0, PLANT_KINDS, MID_SCALE, MID_HAZE, water);
            col = over(col, fish[1]);
            col = drawRow(col, cell, grid, sand + 2.0, horizon, tick, PLANTS_BACK, 0.0, 0, PLANT_KINDS, 1.0, BACK_HAZE, water);
            col = over(col, fish[2]);
            col = drawCrab(col, cell, grid, sand, T, tick);
            col = drawRow(col, cell, grid, sand + 3.0, horizon, tick, ROCKS, 70.0, ROCK_FIRST, ROCK_KINDS, 1.0, 0.1, water);
            col = drawRow(col, cell, grid, sand + 3.0, horizon, tick, PLANTS_FRONT, 31.0, 0, PLANT_KINDS, 1.0, 0.0, water);
            col = over(col, fish[3]);
        }
        col = drawBubbles(col, cell, grid, top, sand, T);
    }

    // fade to black at the left and right, in dithered steps so it stays pixel-art
    float u    = (cx + 0.5) / grid.x;
    float fade = smoothstep(0.0, EDGE_FADE, u) * smoothstep(0.0, EDGE_FADE, 1.0 - u);
    col *= saturate(floor(fade * 6.0 + dth) / 6.0) * SCENE_BRIGHT;

    // letters on top, crisp; the tank fades out underneath them so they stay readable
    float3 text = readText(tex);
    return float4(text + col * (1.0 - ink(text)), 1.0);
}
