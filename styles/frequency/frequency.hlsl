// Frequency: a pixel-art background that keeps changing station, drawn behind the text.
// One loop of nearly two and a half minutes on two stations, ending where it began:
//   fish bones crossing at 2 frames a second -> (radio swap) -> skulls flying diagonally at 30 ->
//   the picture cracks into boxes that crumble away, showing a brighter world underneath ->
//   (glitch, radio swap) -> polka dots humming on unstable electricity -> (radio swap) ->
//   an old wooden TV showing a 1930s cartoon dog in trousers jogging, the camera following ->
//   a heavy glitch tears it apart, it zooms into a distant pattern, flies into a gridded
//   asteroid field of wildly coloured, glitching cubes and pans around -> (radio swap) ->
//   the second station, where nothing is quite right: black holes tear apart three suburbs ->
//   a digital bottle pours fine coloured sand over a turning swirl -> a tunnel of elements
//   collapses as time warps, a hypnotic swirl spreading out of it -> glitch to black, old green
//   computer lines -> eyes opening one by one until the window is full -> laughing lips ->
//   down the last one's throat -> swaying grey static, the throat crossfading into an ocean of
//   made-up letters under a city of letters, the sky turning from night to day -> its waves grow
//   and grow and rise over the window, sinking us under the sea; the loop ends with the water line
//   halfway up, and the next one starts on that same moment, among the fish bones again, so a
//   recording of one loop joins without a seam.
// On top of that, random glitches in psychedelic colours come and go at random times.
// The scenes are in frequency-scenes.hlsli, frequency-tv.hlsli, frequency-space.hlsli,
// frequency-dream.hlsli and frequency-eyes.hlsli, which must stay next to this file. Sprites come from frequency-sheet.png (drawn by frequency-sprites.py;
// the sheet constants below must match). The colour scheme's background must be pure black.
Texture2D shaderTexture;
Texture2D image;
SamplerState samplerState;
cbuffer PixelShaderSettings { float Time; float Scale; float2 Resolution; float4 Background; };

// --- the pixel look ---
static const float  CELL_PIXELS    = 2.0;    // screen pixels per pixel-art pixel (small = finer)
static const float  SCENE_BRIGHT   = 0.50;   // overall picture brightness (text is not affected)
static const float  SIDE_FADE      = 0.04;   // share of the width over which each side fades to black
static const float  BASE_ROWS      = 330.0;  // sprites grow one size step for every this many pixel-art rows of window height

// --- the long cut: frequency-long.hlsl sets FREQ_LONG to 1 and includes this file. Every part then lasts
// longer, so one loop is exactly 6 minutes (two make a 12-minute video), and the whole-window glitches
// come less often, leaving more to the glitches in patches. Each pair below is: long cut : as a theme ---
#ifndef FREQ_LONG
#define FREQ_LONG 0
#endif

// --- how long each part lasts, in seconds ---
static const float  FISH_SEC       = FREQ_LONG ? 30.0 : 9.0;
static const float  RF_SEC         = FREQ_LONG ? 4.5 : 3.5;     // each radio-frequency swap
static const float  SKULL_SEC      = FREQ_LONG ? 26.0 : 8.0;
static const float  CRUMBLE_SEC    = FREQ_LONG ? 9.0 : 4.5;
static const float  BRIGHT_SEC     = FREQ_LONG ? 18.0 : 4.0;
static const float  POLKA_SEC      = FREQ_LONG ? 24.0 : 8.0;
static const float  TV_SEC         = FREQ_LONG ? 30.0 : 11.0;
static const float  TEAR_SEC       = FREQ_LONG ? 4.0 : 3.0;
static const float  ZOOM_SEC       = FREQ_LONG ? 5.0 : 3.0;
static const float  SPACE_SEC      = FREQ_LONG ? 32.0 : 10.0;
static const float  SUBURB_SEC     = FREQ_LONG ? 37.5 : 15.0;   // the second station starts here: three towns, (SUBURB_SEC + RF_SEC) / 3 each
static const float  BOTTLE_SEC     = FREQ_LONG ? 18.0 : 7.0;
static const float  TUNNEL_SEC     = FREQ_LONG ? 18.0 : 9.0;    // the tunnel collapsing, slowly...
static const float  SWIRL_SEC      = FREQ_LONG ? 10.0 : 4.0;    // ...and the swirl once it has taken over
static const float  PC_SEC         = FREQ_LONG ? 6.0 : 3.0;
static const float  EYES_SEC       = FREQ_LONG ? 17.0 : 7.0;
static const float  LIPS_SEC       = FREQ_LONG ? 13.0 : 6.0;
static const float  THROAT_SEC     = FREQ_LONG ? 6.0 : 4.0;
static const float  CITY_SEC       = FREQ_LONG ? 36.0 : 13.0;   // the first CITY_STATIC of it is grey static
static const float  START_AT       = 0.0;    // for trying things out: start this many seconds into the loop

// --- random glitches between the planned ones ---
static const float  GLITCH_STRENGTH = 1.0;   // 0 switches the random glitches off; planned ones stay
static const float  GLITCH_WINDOW  = FREQ_LONG ? 7.5 : 7.0;    // each window of this many seconds may hold one glitch (7.5 fits 12 minutes exactly)
static const float  GLITCH_CHANCE  = FREQ_LONG ? 0.3 : 0.6;    // share of windows that do

// --- glitches in patches: several at once, each in its own part of the window and in its own way:
// turning chunky, rows sliding, mirrored, a piece from somewhere else, magnified, stuck on one moment,
// tiles shuffled, or another station showing through; most also change the colours inside ---
static const int    PATCH_SLOTS    = FREQ_LONG ? 8 : 5;         // how many can be going at once
static const float  PATCH_WINDOW   = 4.0;    // each slot may hold one glitch in every window of about this many seconds
static const float  PATCH_CHANCE   = 0.7;    // share of windows that do
static const float  PATCH_MIN      = 0.25;   // shortest, seconds
static const float  PATCH_MAX      = 2.6;    // longest
static const float2 PATCH_SIZE_MIN = float2(0.05, 0.04);   // smallest patch, share of the window
static const float2 PATCH_SIZE_MAX = float2(0.45, 0.35);   // largest
static const float  PATCH_RATE     = 8.0;    // a patch jumps and stutters this many times a second
static const float  GLITCH_MIN     = 0.15;   // shortest glitch, seconds
static const float  GLITCH_MAX     = 2.2;    // longest glitch, seconds
static const float  GLITCH_RATE_LO = 6.0;    // a glitch changes its look this many times a second...
static const float  GLITCH_RATE_HI = 18.0;   // ...up to this many (kept low, so it never strobes hard)

// --- radio-frequency swaps ---
static const float  RF_BLEND       = 0.45;   // the band where the old picture dissolves into the new, share of the height
static const float  RF_BLOCK       = 4.0;    // the dissolve works in blocks this many cells across
static const float  RF_ROLL        = 0.5;    // how fast the old picture rolls up and away, against the band
static const float  RF_SNOW        = 0.45;   // how much static snow in the dissolving band
static const float  RF_WOBBLE      = 6.0;    // cells the picture wobbles sideways in the band

// --- sprite sheet layout (matches frequency-sprites.py) ---
static const int    FISH_W = 48, FISH_H = 24, FISH_KINDS = 3, FISH_Y = 0;
static const int    SKULL_S = 24, SKULL_KINDS = 4, SKULL_Y = 24;
static const int    LIVE_X = 96, LIVE_KINDS = 3;     // living fish, to the right of the skulls
static const int    DOG_S = 64, DOG_FRAMES = 8, DOG_Y = 48;
static const int    GLYPH_W = 6, GLYPH_H = 8, GLYPH_Y = 112, GLYPH_COUNT = 64;   // 32 real letters, 32 made-up
static const int    SHEET_W = 512, SHEET_H = 128;

// --- joins inside the second station ---
static const float  BANG_SEC        = 2.4;   // the tube of pixelated big bangs that opens the bottle scene
static const float  BANG_BLOCK      = 6.0;   // their pixel size, cells
static const int    BANG_RINGS      = 12;    // big bangs, one after another
static const float  BANG_GAP        = 0.08;  // seconds between them
static const float  BANG_GROW       = 3.4;   // how fast each blast front flies out (it grows e times this often a second)
static const float  BANG_REVEAL     = 1.1;   // seconds in, the bottle starts to open up in the middle
static const float  BOTTLE_BLEND    = FREQ_LONG ? 7.0 : 4.0;   // seconds the bottle's heap takes to dissolve into the tunnel
static const float  BLEND_BLOCK     = 6.0;   // size of the blocks it dissolves in, cells
static const float  BLACKOUT_SEC    = 2.0;   // the swirl glitching away to black
static const float  PC_LINGER       = FREQ_LONG ? 4.0 : 2.5;   // the green computer lines linger this long among the first eyes
static const float  CITY_STATIC     = FREQ_LONG ? 7.0 : 4.5;   // long grey static between the throat and the city...
static const float  CITY_CLEAR      = FREQ_LONG ? 2.5 : 1.8;   // ...clearing over its last this-many seconds
static const float  STATIC_OPACITY  = 0.70;  // how thick the static is: the throat and then the city show faintly through it
static const float  STATIC_XFADE    = 0.6;   // seconds in, the throat starts crossfading into the city under the static
static const float  STATIC_SWAY     = 0.06;  // the static sways from side to side this far, share of the width...
static const float  STATIC_SWAY_HZ  = 0.35;  // ...this many times a second...
static const float  STATIC_BEND     = 0.015; // ...bending a little down its height as it goes
static const float  STATIC_GRAIN_HZ = 3.0;   // the static's grain changes this often, so the sway can be seen
static const float  STRIP_SEC       = 1.6;   // a strip sweeps from left to right across the static this often
static const float  STRIP_W         = 0.07;  // its half-width, share of the width
static const float  STRIP_CLEAR     = 0.6;   // how much clearer the pictures show inside it

// --- the loop's join: the city's growing waves rise up over the window and we sink under the sea, among
// the fish. The water line is halfway up the window where the loop ends, and the next loop starts on that
// same moment, so a recording joins without a seam ---
static const float  JOIN_OUT        = 2.5;   // seconds of the sea rising, at the end of the loop...
static const float  JOIN_IN         = 2.5;   // ...and of it rising on over the top, at the start
static const float  JOIN_BLOCK      = 6.0;   // the soft glitch along the water line works in blocks this many cells across
static const float  JOIN_RATE       = 8.0;   // it changes this many times a second
static const float  JOIN_GLITCH     = 0.25;  // how strong it is, right on the water line
static const float  JOIN_BAND       = 14.0;  // and how far either side of the line it reaches, cells

// --- the sunrise keeps glitching, a different way each time ---
static const float  SUN_FX_SEC      = 0.9;   // each glitch effect lasts this long, swelling and fading into the next
static const int    SUN_FX_KINDS    = 8;
static const float  SUN_FX_STRENGTH = 0.8;

// --- thin glitch lines, all the way through ---
static const float  LINE_RATE       = 12.0;  // the glitch blocks change this many times a second
static const float  LINE_SHARE      = 0.006; // share of block rows hit at any moment
static const float  LINE_BURST      = 0.03;  // ...rising to this in rare short bursts
static const float  LINE_BLOCK_W    = 8.0;   // one glitch block, cells wide...
static const float  LINE_BLOCK_H    = 5.0;   // ...and tall
static const float  LINE_RUN        = 6.0;   // a run is up to this many blocks long
static const float  LINE_PIXEL      = 3.0;   // inside a block the picture turns this chunky, cells

// --- the second station's feeling that something is not quite right ---
static const float  UNCANNY_WINDOW  = 5.0;   // each window of this many seconds...
static const float  UNCANNY_DEJAVU  = 0.4;   // ...has this chance of a moment replaying itself
static const float  UNCANNY_REPLAY  = 0.6;   // seconds replayed
static const float  UNCANNY_SEAM    = 0.35;  // chance, every 3 seconds, of a seam running down the picture
static const float  UNCANNY_LOADING = 0.02;  // share of patches that render coarse, as if still loading
static const float  UNCANNY_PATCH   = 32.0;  // patch size, cells

// --- user messages (same marker the other styles use) ---
static const float3 MARKER         = float3(0.0, 0.0, 3.0 / 255.0);
static const float3 USER_COLOUR    = float3(1.00, 0.86, 0.55);
static const int    ROW_SAMPLES    = 48;

static const float  TAU            = 6.28318530718;
static const float  BAYER[16] = { 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5 };

// the timeline: where each part ends
static const float  E_FISH   = FISH_SEC;
static const float  E_RF1    = E_FISH + RF_SEC;
static const float  E_SKULL  = E_RF1 + SKULL_SEC;
static const float  E_CRUMB  = E_SKULL + CRUMBLE_SEC;
static const float  E_BRIGHT = E_CRUMB + BRIGHT_SEC;
static const float  E_RF2    = E_BRIGHT + RF_SEC;
static const float  E_POLKA  = E_RF2 + POLKA_SEC;
static const float  E_RF3    = E_POLKA + RF_SEC;
static const float  E_TV     = E_RF3 + TV_SEC;
static const float  E_TEAR   = E_TV + TEAR_SEC;
static const float  E_ZOOM   = E_TEAR + ZOOM_SEC;
static const float  E_SPACE  = E_ZOOM + SPACE_SEC;
static const float  E_RF4    = E_SPACE + RF_SEC;
static const float  E_SUB    = E_RF4 + SUBURB_SEC;
static const float  E_BOTTLE = E_SUB + BOTTLE_SEC;
static const float  E_WARP   = E_BOTTLE + TUNNEL_SEC + SWIRL_SEC;
static const float  E_PC     = E_WARP + PC_SEC;
static const float  E_EYES   = E_PC + EYES_SEC;
static const float  E_LIPS   = E_EYES + LIPS_SEC;
static const float  E_THROAT = E_LIPS + THROAT_SEC;
static const float  E_CITY   = E_THROAT + CITY_SEC;
static const float  LOOP_SEC = E_CITY + JOIN_OUT;

// scene numbers
static const int    S_FISH = 0, S_SKULL = 1, S_CRUMBLE = 2, S_BRIGHT = 3, S_POLKA = 4, S_TV = 5, S_ZOOM = 6, S_SPACE = 7, S_BLANK = 8,
                    S_SUBURB = 9, S_BOTTLE = 10, S_WARP = 11, S_PC = 12, S_EYES = 13, S_LIPS = 14, S_THROAT = 15, S_CITY = 16;

// set once per pixel in main()
static bool  gSprites;
static float gBase;

float hash(float n) { return frac(sin(n * 127.1 + 11.7) * 43758.5453); }
float hash2(float2 p) { return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453); }
float3 hash3(float3 p)
{
    p = frac(p * float3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return frac((p.xxy + p.yxx) * p.zyx);
}
float dither(float2 c) { int2 i = int2(c); return (BAYER[(i.y & 3) * 4 + (i.x & 3)] + 0.5) / 16.0; }
float wrap(float x, float m) { return x - m * floor(x / m); }
float3 hue(float h) { return saturate(abs(frac(h + float3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0); }
float luma(float3 c) { return dot(c, float3(0.299, 0.587, 0.114)); }
float3 hueRotate(float3 c, float a)
{
    const float3 k = 0.57735;
    float ca = cos(a);
    return c * ca + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - ca);
}
// a smooth bump: 0 at both ends of 0..1, 1 in the middle
float bell(float p) { return sin(saturate(p) * 3.14159265); }

// one sprite pixel, scaled up by a whole number and optionally mirrored; alpha 0 outside the sprite
float4 sprite(int2 origin, int2 size, float2 local, float sc, bool flip)
{
    int2 p = int2(floor(local / sc));
    if (p.x < 0 || p.y < 0 || p.x >= size.x || p.y >= size.y) return float4(0, 0, 0, 0);
    if (flip) p.x = size.x - 1 - p.x;
    return image.Load(int3(origin + p, 0));
}

#include "frequency-scenes.hlsli"
#include "frequency-tv.hlsli"
#include "frequency-space.hlsli"
#include "frequency-dream.hlsli"
#include "frequency-eyes.hlsli"

// a short glitch each time the skulls change direction
float skullTurnGlitch(float t)
{
    float x = wrap(t, SKULL_TURN_SEC);
    return t > 1.0 && (x < 0.25 || x > SKULL_TURN_SEC - 0.1) ? 0.7 : 0.0;
}

float3 sceneColour(int id, float2 c, float2 grid, float t)
{
    [branch] if (id == S_FISH)    return fishScene(c, grid, t);
    [branch] if (id == S_SKULL)   return skullScene(c, grid, t);
    [branch] if (id == S_CRUMBLE) return crumbleScene(c, grid, t);
    [branch] if (id == S_BRIGHT)  return brightWorld(c, grid, t);
    [branch] if (id == S_POLKA)   return polkaScene(c, grid, t);
    [branch] if (id == S_TV)      return tvScene(c, grid, t);
    [branch] if (id == S_ZOOM)    return zoomScene(c, grid, t);
    [branch] if (id == S_SPACE)   return spaceScene(c, grid, t);
    [branch] if (id == S_SUBURB)  return suburbScene(c, grid, t);
    [branch] if (id == S_BOTTLE)  return bottleScene(c, grid, t);
    [branch] if (id == S_WARP)    return warpScene(c, grid, t);
    [branch] if (id == S_PC)      return pcScene(c, grid, t);
    [branch] if (id >= S_EYES && id <= S_THROAT)                  // one scene in three parts, built once
        return facesScene(c, grid, t + (id >= S_LIPS ? EYES_SEC : 0.0) + (id == S_THROAT ? LIPS_SEC : 0.0));
    [branch] if (id == S_CITY)    return cityScene(c, grid, t);
    return float3(0, 0, 0);
}

// --- random glitches: 0 most of the time, then a burst of random length at a random moment ---
float randomGlitch(float T, out float seed)
{
    float w = floor(T / GLITCH_WINDOW);
    seed = w * 31.7;
    if (hash(w * 1.73 + 0.3) > GLITCH_CHANCE) return 0.0;
    float len   = lerp(GLITCH_MIN, GLITCH_MAX, pow(hash(w * 3.3 + 1.1), 2.0));
    float start = hash(w * 7.1 + 2.9) * (GLITCH_WINDOW - len);
    float x     = T - w * GLITCH_WINDOW - start;
    if (x < 0.0 || x > len) return 0.0;
    float rate  = lerp(GLITCH_RATE_LO, GLITCH_RATE_HI, hash(w * 5.9 + 4.2));
    float slot  = floor(x * rate);
    seed = w * 31.7 + slot;
    float s = hash(seed * 1.31 + 0.7);
    return (s < 0.2 ? 0.1 : s) * GLITCH_STRENGTH;
}

// rows and blocks of the picture slide sideways
float2 glitchCoord(float2 c, float2 grid, float g, float seed)
{
    float bandH = floor(lerp(2.0, 26.0, hash(seed * 1.1 + 0.2)));
    float band  = floor(c.y / bandH);
    if (hash2(float2(band, seed)) < 0.5 * g)
        c.x += floor((hash2(float2(band, seed + 5.0)) - 0.5) * grid.x * 0.35 * g);
    float2 blk = floor(c / float2(28.0, 9.0));
    if (hash2(blk + seed * 3.1) < 0.1 * g)
        c += floor((float2(hash2(blk + seed), hash2(blk - seed)) - 0.5) * float2(40.0, 12.0));
    return c;
}

// psychedelic recolouring: a different trick each time the glitch changes
float3 glitchColour(float3 col, float2 c, float g, float seed)
{
    float3 orig = col;
    float  mode = hash(seed * 2.3 + 0.1);
    float3 tint = hue(hash(seed * 9.7 + 0.4));
    if (mode < 0.25)      col = frac(col * 3.0 + tint);                          // rainbow contour bands
    else if (mode < 0.5)  col = saturate(hueRotate(col, hash(seed * 4.4) * TAU) * 1.4);
    else if (mode < 0.65) col = (1.0 - col) * tint;                              // negative, tinted
    else if (mode < 0.85) col = lerp(hue(hash(seed * 6.1)), tint, luma(col)) * (0.3 + luma(col) * 1.4);  // two-tone
    else                  col = floor(col * 3.0) / 2.0 * tint.zxy;              // crushed palette
    // solid blocks and bright streak lines
    if (hash2(floor(c / float2(18.0, 6.0)) + seed * 1.7) < 0.06 * g) col = hue(hash2(floor(c / 18.0) + seed));
    if (hash2(float2(c.y, seed * 0.37)) < 0.025 * g) col = tint * 1.3;
    return lerp(orig, col, saturate(g * 1.6));
}

// scenes another station can show through a patch
static const int    PATCH_OTHERS[9] = { S_FISH, S_SKULL, S_BRIGHT, S_POLKA, S_TV, S_SPACE, S_SUBURB, S_WARP, S_CITY };

// the topmost patch glitch over this cell, if any. Counted on the loop's own clock, in windows that fit
// the loop exactly, so every loop has the same ones and a recording still joins without a seam
bool patchAt(float2 c, float2 grid, float tl, out float4 box, out float seed, out float age, out float tick)
{
    bool hit = false;
    box = 0; seed = 0; age = 0; tick = 0;
    [loop] for (int k = 0; k < PATCH_SLOTS; k++)
    {
        float win = LOOP_SEC / max(1.0, round(LOOP_SEC / (PATCH_WINDOW * (1.0 + 0.23 * k))));
        float w   = floor(tl / win);
        float s0  = w * 13.7 + k * 101.3;
        if (hash(s0 + 0.5) > PATCH_CHANCE) continue;
        float len   = lerp(PATCH_MIN, PATCH_MAX, pow(hash(s0 + 1.5), 2.0));
        float start = hash(s0 + 2.5) * (win - len);
        float x     = tl - w * win - start;
        if (x < 0.0 || x > len) continue;
        float tk = floor(x * PATCH_RATE);
        if (hash(s0 + tk * 0.91) < 0.12) continue;                                          // it stutters off now and then
        float2 sz  = floor(lerp(PATCH_SIZE_MIN, PATCH_SIZE_MAX, pow(float2(hash(s0 + 3.5), hash(s0 + 4.5)), 1.6)) * grid);
        float2 mid = floor(float2(hash(s0 + 5.5), hash(s0 + 6.5)) * grid);
        mid += floor((float2(hash(s0 + tk * 1.3), hash(s0 + tk * 1.7)) - 0.5) * 6.0) * gBase * step(0.7, hash(s0 + tk * 2.1));   // jumps a little now and then
        // torn edges: the sides jag row by row, the top and bottom column by column
        float2 jag = floor((float2(hash2(float2(floor(c.y / (3.0 * gBase)), s0 + tk)), hash2(float2(floor(c.x / (5.0 * gBase)), s0 - tk))) - 0.5) * 6.0 * gBase);
        float2 lo  = mid - sz * 0.5 + jag;
        if (any(c < lo) || any(c >= lo + sz)) continue;
        hit = true; box = float4(mid - sz * 0.5, mid + sz * 0.5); seed = s0; age = x; tick = tk;
    }
    return hit;
}

// the colourful glitch the loop ends and begins on: bands of rows sliding sideways, full of blocks of
// wild colour, contour rainbows and bright streaks, changing many times a second
float3 joinGlitch(float2 c, float2 grid, float tl)
{
    float tick  = floor(tl * JOIN_RATE);
    float bandH = floor(lerp(3.0, 24.0, hash(floor(c.y / 24.0) + tick * 0.37)));
    float band  = floor(c.y / bandH);
    float x     = c.x + floor((hash2(float2(band, tick)) - 0.5) * grid.x * 0.6);
    float bw    = floor(lerp(4.0, 40.0, hash2(float2(band, tick + 2.0)))) * gBase;
    float2 bk   = float2(floor(x / bw), band);
    float  h    = hash2(bk + tick * 0.13);
    float3 col  = hue(frac(h + tl * 0.2)) * (0.5 + 0.6 * hash2(bk + 9.0));
    if (h > 0.7) col = frac(float3(x, c.y, x + c.y) * 0.02 + tl * 0.5);                   // contour rainbows
    if (h < 0.08) col = float3(0, 0, 0);                                                  // holes
    if (hash2(float2(c.y, tick * 0.7)) < 0.03) col = float3(1, 1, 1) * 1.2;               // bright streak lines
    return col;
}

// --- text ---
bool isMarker(float3 c) { return all(abs(c - MARKER) < 0.5 / 255.0); }
float ink(float3 c) { return saturate(max(c.r, max(c.g, c.b))); }
float3 readText(float2 uv)
{
    float3 c = shaderTexture.Sample(samplerState, uv).rgb;
    if (isMarker(c)) c = float3(0, 0, 0);
    bool userRow = false;
    [loop] for (int i = 0; i < ROW_SAMPLES; i++)
    {
        float x = (i + 0.5) / ROW_SAMPLES;
        if (isMarker(shaderTexture.SampleLevel(samplerState, float2(x, uv.y), 0).rgb)) { userRow = true; break; }
    }
    if (userRow) c = USER_COLOUR * ink(c);
    return c;
}
float screenFade(float2 tex) { return smoothstep(0.0, 1.0, saturate(min(tex.x, 1.0 - tex.x) / SIDE_FADE)); }

float4 main(float4 pos : SV_POSITION, float2 tex : TEXCOORD) : SV_TARGET
{
    float  s    = max(Scale, 1.0);
    float  size = CELL_PIXELS * s;
    float2 c    = floor(pos.xy / size);
    float2 grid = floor(Resolution / size);
    float  T    = Time;
    float  tl   = wrap(T + START_AT, LOOP_SEC);

    uint iw, ih;
    image.GetDimensions(iw, ih);
    gSprites = (int)iw == SHEET_W && (int)ih == SHEET_H;
    gBase    = max(1.0, floor(grid.y / BASE_ROWS + 0.5));

    // which part of the loop we are in
    int   id = S_FISH, idB = S_FISH;
    float t = tl, tB = 0.0, rf = -1.0, rfHeavy = 0.0, tear = -1.0, zoomMix = -1.0, forced = 0.0, blackout = 0.0;
    if      (tl < E_FISH)   { id = S_FISH; t = tl; }
    else if (tl < E_RF1)    { id = S_FISH; t = tl; idB = S_SKULL; tB = tl - E_FISH; rf = (tl - E_FISH) / RF_SEC; rfHeavy = 0.3; }
    else if (tl < E_SKULL)  { id = S_SKULL; t = tl - E_FISH; forced = skullTurnGlitch(t); }
    else if (tl < E_CRUMB)  { id = S_CRUMBLE; t = tl - E_SKULL; forced = skullTurnGlitch(t + SKULL_SEC + RF_SEC); }
    else if (tl < E_BRIGHT) { id = S_BRIGHT; t = tl - E_SKULL; forced = 0.8 * saturate((tl - (E_BRIGHT - 1.5)) / 1.5); }
    else if (tl < E_RF2)    { id = S_BRIGHT; t = tl - E_SKULL; idB = S_POLKA; tB = tl - E_BRIGHT; rf = (tl - E_BRIGHT) / RF_SEC; rfHeavy = 0.5; }
    else if (tl < E_POLKA)  { id = S_POLKA; t = tl - E_BRIGHT; }
    else if (tl < E_RF3)    { id = S_POLKA; t = tl - E_BRIGHT; idB = S_TV; tB = tl - E_POLKA; rf = (tl - E_POLKA) / RF_SEC; rfHeavy = 0.3; }
    else if (tl < E_TV)     { id = S_TV; t = tl - E_POLKA; }
    else if (tl < E_TEAR)   { id = S_TV; t = tl - E_POLKA; tear = (tl - E_TV) / TEAR_SEC; }
    else if (tl < E_ZOOM)   { id = S_ZOOM; t = tl - E_TEAR; zoomMix = (tl - E_TEAR) / ZOOM_SEC; }
    else if (tl < E_SPACE)  { id = S_SPACE; t = tl - E_ZOOM; forced = 0.6 * saturate((tl - (E_SPACE - 1.0)) / 1.0); }
    else if (tl < E_RF4)    { id = S_SPACE; t = tl - E_ZOOM; idB = S_SUBURB; tB = tl - E_SPACE; rf = (tl - E_SPACE) / RF_SEC; rfHeavy = 0.5; }
    else if (tl < E_SUB)    { id = S_SUBURB; t = tl - E_SPACE; float pb = wrap(t, SUB_PHASE_SEC);
                              forced = t > 1.0 && t < SUB_SPAN - SUB_DIVE && (pb < 0.4 || pb > SUB_PHASE_SEC - 0.5) ? 0.75 : 0.0; }
    else if (tl < E_BOTTLE) { id = S_BOTTLE; t = tl - E_SUB; }
    else if (tl < E_WARP)   { id = S_WARP; t = tl - E_BOTTLE; forced = 0.7 * saturate((tl - (E_WARP - BLACKOUT_SEC)) / BLACKOUT_SEC); blackout = saturate((tl - (E_WARP - BLACKOUT_SEC)) / BLACKOUT_SEC); }
    else if (tl < E_PC)     { id = S_PC; t = tl - E_WARP; forced = 0.5 * saturate(1.0 - (tl - E_WARP) / 1.0); }
    else if (tl < E_EYES)   { id = S_EYES; t = tl - E_PC; }
    else if (tl < E_LIPS)   { id = S_LIPS; t = tl - E_EYES; }
    else if (tl < E_THROAT) { id = S_THROAT; t = tl - E_LIPS; }
    else                    { id = S_CITY; t = tl - E_THROAT; }      // runs on past E_CITY into the join

    // the join round the end of the loop: 0 to 1 across both ends, 0.5 right where the loop ends and
    // starts; -1 outside it. A wavy water line rises from the bottom of the window to the top: above it
    // the city, below it the fish under the sea
    float join = -1.0, jt = 0.0, yw = 0.0;
    if (tl > E_CITY)  join = (tl - E_CITY) / (JOIN_OUT + JOIN_IN);
    if (tl < JOIN_IN) join = (tl + JOIN_OUT) / (JOIN_OUT + JOIN_IN);
    if (join >= 0.0)
    {
        jt = join * (JOIN_OUT + JOIN_IN);                                   // the join's own clock, the same at both ends
        yw = lerp(grid.y * 1.12, -grid.y * 0.12, smoothstep(0.0, 1.0, join))
           + (sin(c.x * 0.031 + jt * 2.0) * 0.035 + sin(c.x * 0.073 - jt * 3.3) * 0.015) * grid.y;
        bool under = c.y > yw;
        if (under && id == S_CITY)  { id = S_FISH; t = tl - LOOP_SEC; }
        if (!under && id == S_FISH) { id = S_CITY; t = tl + LOOP_SEC - E_THROAT; }
    }
    bool sunrise = id == S_BRIGHT;

    // glitch strength now: the random kind outside the planned changes, the planned kind inside them
    float seed;
    float g = (rf < 0.0 && tear < 0.0 && zoomMix < 0.0) ? randomGlitch(T, seed) : 0.0;
    if (rf >= 0.0 || forced > 0.0 || tear >= 0.0)
    {
        float rate = 12.0;
        seed = floor(T * rate) + 977.0;
        g = max(forced, rf >= 0.0 ? rfHeavy * bell(rf) : 0.0);
        if (tear >= 0.0) g = 0.4 + 0.5 * tear;
        g *= 0.4 + 0.6 * hash(seed * 0.71);
    }
    if (join >= 0.0)
    {
        seed = floor(jt * JOIN_RATE) + 501.0;                       // counted on the join's own clock, so both ends match
        g = JOIN_GLITCH * saturate(1.0 - abs(c.y - yw) / (JOIN_BAND * gBase)) * (0.5 + 0.5 * hash(seed * 0.71));
    }
    float2 cc = g > 0.0 ? glitchCoord(c, grid, g, seed) : c;
    // under the water line the picture wobbles a little, as seen through water
    if (join >= 0.0 && c.y > yw) cc.x += floor(sin(c.y * 0.12 + jt * 5.0) * 2.0 * gBase * saturate(1.0 - (c.y - yw) / (grid.y * 0.3)));

    // glitch blocks: now and then a short run of chunky blocks tears along the block grid, the
    // picture inside them sliding a block or two sideways and turning coarse, so whatever object
    // sits there glitches out
    float lslot = floor(T * LINE_RATE);
    float bw    = LINE_BLOCK_W * gBase, bh = LINE_BLOCK_H * gBase;
    float lrow  = floor(c.y / bh);
    float lrate = hash(floor(T * 1.5) * 0.77) < 0.06 ? LINE_BURST : LINE_SHARE;
    float lb0   = floor(hash2(float2(lrow, lslot + 3.0)) * grid.x / bw);
    float lbx   = floor(c.x / bw);
    bool  gline = hash2(float2(lrow, lslot)) < lrate && lbx >= lb0 && lbx < lb0 + 1.0 + floor(hash2(float2(lrow, lslot + 4.0)) * LINE_RUN);
    if (gline)
    {
        float px = LINE_PIXEL * gBase;
        cc = floor((cc + float2((floor(hash2(float2(lrow, lslot + 1.0)) * 5.0) - 2.0) * bw, 0.0)) / px) * px + px * 0.5;
    }

    // after the dive into the black hole: a tube of pixelated big bangs, one after another, their
    // blast fronts flying out past us, until the bottle opens up in the middle
    float bang = -1.0, bangD = 0.0, bangR = 0.0;
    float2 bangB = 0;
    if (id == S_BOTTLE && t < BANG_SEC)
    {
        float  B = BANG_BLOCK * gBase;
        bangB = floor(c / B);
        bangD = length((bangB + 0.5) * B - grid * SUB_HOLE_AT) / grid.y;
        bangR = t < BANG_REVEAL ? 0.0 : pow((t - BANG_REVEAL) / (BANG_SEC - BANG_REVEAL), 1.5) * 1.5;
        bang  = t / BANG_SEC;
        if (bangD > bangR) id = S_BLANK;
    }

    // the green computer lines linger among the first eyes, fewer and fewer blocks of them
    if (id == S_EYES && t < PC_LINGER && hash2(floor(c / (BLEND_BLOCK * gBase)) + 7.5) > smoothstep(0.0, 1.0, t / PC_LINGER))
    {
        id = S_PC;
        t  = PC_SEC + t;
    }

    // the bottle's heap dissolves into the tunnel block by block
    if (id == S_WARP && t < BOTTLE_BLEND && hash2(floor(c / (BLEND_BLOCK * gBase)) + 0.5) > smoothstep(0.0, 1.0, t / BOTTLE_BLEND))
    {
        id = S_BOTTLE;
        t  = tl - E_SUB;
    }

    // the second station never feels quite right: a moment replays itself now and then, a seam
    // runs down the picture, and patches render coarse as if they had not finished loading
    if (id >= S_SUBURB && rf < 0.0)
    {
        float w  = floor(T / UNCANNY_WINDOW);
        float s0 = w * UNCANNY_WINDOW + hash(w * 4.1 + 0.2) * (UNCANNY_WINDOW - UNCANNY_REPLAY);
        if (hash(w * 1.9 + 0.7) < UNCANNY_DEJAVU && T > s0 && T < s0 + UNCANNY_REPLAY) t -= UNCANNY_REPLAY;
        float sw = floor(T / 3.0);
        if (hash(sw * 2.7 + 0.1) < UNCANNY_SEAM && c.x > floor(hash(sw * 5.3) * grid.x)) cc.y += 1.0;
        if (hash2(floor(c / UNCANNY_PATCH) + floor(T * 2.0) * 0.37) < UNCANNY_LOADING) cc = floor(cc / 8.0) * 8.0 + 4.0;
    }

    // the heavy tear: bands of the TV picture fly apart, and the gaps open onto a far-off pattern
    if (tear >= 0.0)
    {
        float tick  = floor(T * 12.0);
        float bandH = floor(lerp(3.0, 20.0, hash(tick * 0.37 + 0.5)));
        float band  = floor(c.y / bandH);
        float k     = tear * tear;
        cc.x += floor((hash2(float2(band, tick)) - 0.5) * grid.x * 0.9 * k);
        cc.y += floor((hash2(float2(band, tick + 1.0)) - 0.5) * grid.y * 0.25 * k);
        if (hash2(float2(band, 7.0)) < tear * 0.9) { id = S_ZOOM; t = 0.0; cc = c; }
    }

    // a radio-frequency swap: a band rises up the screen; below it the new station is already
    // playing, above it the old one is rolling away, and inside it the two dissolve into each
    // other block by block through the static, so one picture rolls over into the next
    float rfBell = rf >= 0.0 ? bell(rf) : 0.0;
    float rfBand = 0.0;
    if (rf >= 0.0)
    {
        float band = floor(grid.y * RF_BLEND);
        float roll = smoothstep(0.0, 1.0, rf) * (grid.y + band);
        float u    = saturate((c.y - (grid.y - roll - band)) / band);      // 0 above the band, 1 below it
        rfBand = bell(u);
        cc.x += floor(sin(c.y * 0.09 + T * 37.0) * RF_WOBBLE * rfBand * rfBell);
        if (hash2(floor(c / (RF_BLOCK * gBase)) + floor(T * 12.0) * 0.37) < u) { id = idB; t = tB; }
        else cc.y += floor(roll * RF_ROLL);
    }

    // the sunrise never sits still: one glitch effect after another swells up and fades into the next
    int   sunFx = -1;
    float sunK  = 0.0;
    float sunTick = floor(T * 12.0);
    [branch] if (sunrise && id == S_BRIGHT)
    {
        float slot = floor(t / SUN_FX_SEC);
        sunFx = (int)wrap(slot * 3.0, (float)SUN_FX_KINDS);          // steps through every kind before repeating
        sunK  = bell(frac(t / SUN_FX_SEC)) * SUN_FX_STRENGTH;
        if (sunFx == 0)                                              // bands of rows slide sideways
        {
            float band = floor(c.y / floor(lerp(3.0, 18.0, hash(sunTick * 0.3))));
            cc.x += floor((hash2(float2(band, sunTick)) - 0.5) * grid.x * 0.25 * sunK);
        }
        else if (sunFx == 1) { float p = 1.0 + floor(sunK * 10.0); cc = floor(cc / p) * p; }                    // pixelates
        else if (sunFx == 2) cc.x += floor(sin(cc.y * 0.15 + T * 18.0) * 10.0 * sunK);                         // ripples
        else if (sunFx == 3 && hash2(float2(floor(c.y / 12.0), sunTick)) < sunK) cc.x = grid.x - 1.0 - cc.x;   // mirrored bands
        else if (sunFx == 4) cc.y = wrap(cc.y + floor(hash(sunTick) * grid.y * 0.3 * sunK), grid.y);          // the picture rolls
        else if (sunFx == 7)                                                                                    // blocks swap places
        {
            float2 bk = floor(cc / 16.0);
            if (hash2(bk + sunTick) < sunK * 0.6) cc += (floor(float2(hash2(bk + 1.0 + sunTick), hash2(bk - 1.0)) * 5.0) - 2.0) * 16.0;
        }
    }

    // the grey static between the throat and the city sways from side to side, and the pictures under it
    // sway with it: the throat still rushing past, crossfading into the city
    float  statK = 0.0, sway = 0.0, xfade = 1.0;
    float3 throatImg = float3(0, 0, 0);
    [branch] if (id == S_CITY && t < CITY_STATIC)
    {
        statK = 1.0 - smoothstep(CITY_STATIC - CITY_CLEAR, CITY_STATIC, t);
        sway  = floor(sin(T * TAU * STATIC_SWAY_HZ) * grid.x * STATIC_SWAY + sin(c.y * 0.02 + T * 1.7) * grid.x * STATIC_BEND);
        cc.x += floor(sway * statK);
        xfade = smoothstep(STATIC_XFADE, CITY_STATIC - CITY_CLEAR * 0.5, t);
        [branch] if (xfade < 1.0) throatImg = facesScene(cc, grid, EYES_SEC + LIPS_SEC + THROAT_SEC + t * 0.6);
    }

    // the zoom gives way to the cubes cell by cell, in a dither, so only one picture is drawn
    if (zoomMix > 0.65 && hash2(c + floor(T * 20.0)) < smoothstep(0.65, 1.0, zoomMix)) { id = S_SPACE; t = tl - E_ZOOM; cc = c; }

    // glitches in patches: each picks a way of bending the picture, and most a way of colouring it.
    // They draw from their own copy of the scene and its clock, so everything else still sees the real ones
    int    sid = id, pCol = -1;
    float  st  = t;
    float4 pBox; float pSeed, pAge, pTick;
    [branch] if (PATCH_SLOTS > 0 && patchAt(c, grid, tl, pBox, pSeed, pAge, pTick))
    {
        float2 pm  = floor((pBox.xy + pBox.zw) * 0.5);
        int    how = min(7, (int)(hash(pSeed + 7.5) * 8.0));
        if (how == 0)      { float p = floor(lerp(3.0, 10.0, hash(pSeed + 8.5))) * gBase; cc = floor(cc / p) * p + p * 0.5; }   // turns chunky
        else if (how == 1) cc.x += floor((hash2(float2(floor(c.y / (2.0 * gBase)), pSeed + pTick)) - 0.5) * (pBox.z - pBox.x) * 0.6);   // rows slide
        else if (how == 2) cc.x = 2.0 * pm.x - cc.x;                                                                          // mirrored
        else if (how == 3) cc += floor((float2(hash(pSeed + 9.5), hash(pSeed + 10.5)) - 0.5) * grid * 0.6);                   // a piece from somewhere else
        else if (how == 4) cc = pm + floor((cc - pm) * 0.5);                                                                  // magnified
        else if (how == 5) st = t - pAge;                                                                                     // stuck on the moment it began
        else if (how == 6)                                                                                                    // tiles shuffled
        {
            float  B  = 6.0 * gBase;
            float2 tb = floor((cc - pBox.xy) / B);
            cc += (floor(float2(hash2(tb + pSeed + pTick), hash2(tb - pSeed - pTick)) * 3.0) - 1.0) * B;
        }
        else { sid = PATCH_OTHERS[min(8, (int)(hash(pSeed + 12.5) * 9.0))]; st = 3.0 + hash(pSeed + 13.5) * 10.0 + pAge; }   // another station shows through
        pCol = min(6, (int)(hash(pSeed + 11.5) * 7.0));                                                                       // 6 leaves the colours alone
    }
    float3 col = sceneColour(sid, cc, grid, st);
    [branch] if (sunFx == 5 && sid == S_BRIGHT)                                                                          // colours split apart
    {
        float2 off = float2(floor(6.0 * sunK) + 1.0, 0.0);
        col.r = brightWorld(cc + off, grid, st).r;
        col.b = brightWorld(cc - off, grid, st).b;
    }
    if (sunFx == 6 && sid == S_BRIGHT) col = lerp(col, floor(saturate(hueRotate(col, sunK * TAU * frac(T * 0.7)) * 1.3) * 4.0) / 3.0, sunK);   // colour cycling

    if (g > 0.0) col = glitchColour(col, c, g, seed);
    if (gline) col = lerp(col * 1.2, hue(hash2(float2(lrow, lslot + 2.0))), 0.2);
    if (pCol >= 0 && pCol < 6)
    {
        float3 tint = hue(hash(pSeed + 14.5 + pTick * 0.07));
        if (pCol == 0)      col = 1.0 - saturate(col);                                      // negative
        else if (pCol == 1) col = col.gbr;                                                  // colours swapped round
        else if (pCol == 2) col = floor(saturate(col) * 3.0 + dither(c) * 0.5) / 2.0 * tint;   // crushed palette
        else if (pCol == 3) col = lerp(tint * 0.15, tint * 1.3, luma(col));                 // all one colour
        else if (pCol == 4) col = frac(col * 3.0 + tint);                                   // rainbow contours
        else                col = lerp(col, hash2(c + floor(T * 30.0) * 7.31).xxx, 0.5);    // snowy
    }
    [branch] if (join >= 0.0)
    {
        float dy   = c.y - yw;                                                                   // above 0: under the water
        float near = saturate(1.0 - abs(dy) / (JOIN_BAND * gBase));
        if (dy > 0.0) col = lerp(col, float3(0.25, 0.55, 0.60), 0.35 * saturate(1.0 - dy / (grid.y * 0.25)));   // lit from the surface
        if (abs(dy) < 1.5 * gBase || (abs(dy) < 3.0 * gBase && hash2(floor(c / (2.0 * gBase)) + floor(jt * 10.0)) > 0.5))
            col = lerp(col, float3(0.75, 0.95, 1.00), 0.7);                                      // the shimmering surface
        float2 jb = floor(c / (JOIN_BLOCK * gBase));
        if (hash2(jb + floor(jt * JOIN_RATE) * 0.37) < 0.25 * near) col = lerp(col, joinGlitch(c, grid, jt), 0.35);   // a few soft blocks of colour along it
    }
    if (bang >= 0.0)
    {
        float tb = t;
        col = lerp(col, float3(1, 1, 1), saturate(1.0 - tb * 5.0));                              // the first flash, at once
        if (bangD > bangR && hash2(bangB + floor(T * 20.0)) > 0.97) col = hue(hash2(bangB * 1.3)) * 0.6;   // sparks in the void
        [loop] for (int k = 0; k < BANG_RINGS; k++)
        {
            float age = tb - k * BANG_GAP;
            if (age < 0.0) break;
            float r = 0.06 * exp(age * BANG_GROW);
            float w = max(0.015, r * 0.1);
            if (abs(bangD - r) < w)
            {
                float edge = saturate((bangD - r + w) / (2.0 * w));
                col = lerp(hue(frac(k * 0.17 + hash2(bangB) * 0.15 + T * 0.3)) * 1.5, float3(1, 1, 0.9), pow(edge, 3.0));
                break;
            }
        }
    }

    // between the throat and the city: a long stretch of grey static that slowly clears. It sways from side
    // to side, a strip sweeps across it from left to right, and through it the throat crossfades into the city
    [branch] if (id == S_CITY && t < CITY_STATIC)
    {
        float3 img = lerp(throatImg, col, xfade);
        float2 sp  = float2(c.x + sway, c.y);
        float2 gk  = floor(sp / gBase);
        float  gs  = T * STATIC_GRAIN_HZ;
        float  n   = lerp(hash2(gk + floor(gs) * 0.71), hash2(gk + (floor(gs) + 1.0) * 0.71), frac(gs));   // a slow grain that moves with the sway
        float  gr  = 0.18 + 0.45 * n + 0.25 * hash3(float3(c, floor(T * 30.0))).x;                       // with a fine fast sparkle on top
        gr *= 0.82 + 0.18 * sin(sp.x * 0.05);                                                            // soft upright bands, swaying
        gr *= 0.85 + 0.15 * sin(c.y * 0.05 - T * 6.0);                                                   // a soft rolling band
        if (hash2(float2(floor(c.y / 3.0), floor(T * 15.0))) < 0.02) gr = 0.9;                           // bright tear lines
        // the strip sweeping from left to right: streaky, brighter at its edges, the pictures clearer inside it
        float sx = wrap(T / STRIP_SEC, 1.0) * grid.x * (1.0 + 4.0 * STRIP_W) - grid.x * 2.0 * STRIP_W;
        float su = (c.x - sx) / (grid.x * STRIP_W);
        float sb = abs(su) < 1.0 ? bell(su * 0.5 + 0.5) : 0.0;
        if (sb > 0.0)
        {
            gr = lerp(gr, 0.3 + 0.6 * hash2(float2(floor(c.x / (12.0 * gBase)), floor(c.y / gBase) + floor(T * 20.0))), sb);
            if (abs(abs(su) - 0.95) < 0.05) gr = 0.95;
        }
        float strength = statK * smoothstep(0.0, 0.5, t) * STATIC_OPACITY * (1.0 - STRIP_CLEAR * sb);
        col = lerp(img, float3(gr, gr, gr), strength);
    }
    // everything glitches to black: bands of rows go out, more and more of them
    if (blackout > 0.0 && hash2(float2(floor(c.y / 4.0), floor(T * 15.0))) < blackout * 1.2) col = float3(0, 0, 0);

    // the radio part of the swap: static snow and interference bars sweeping through the frequencies
    if (rf >= 0.0)
    {
        float n    = hash2(c + floor(T * 30.0) * 17.31);
        float f    = lerp(0.04, 0.6, rf);
        float bars = sin(c.y * f + sin(c.x * 0.03 + T * 9.0) * 4.0);
        if (bars > 0.55) col = lerp(col, hue(frac(c.y * 0.01 + T * 1.7)) * (0.6 + 0.4 * bars), 0.45 * rfBand);
        col = lerp(col, float3(n, n, n), RF_SNOW * rfBand);
    }

    // fade to black at the left and right, in dithered steps so it stays pixel-art
    float fade = screenFade(tex);
    col = saturate(col) * saturate(floor(fade * 6.0 + dither(c)) / 6.0) * SCENE_BRIGHT;

    // letters on top, crisp; the picture fades out underneath them so they stay readable
    float3 text = readText(tex);
    return float4(text + col * (1.0 - ink(text)), 1.0);
}
