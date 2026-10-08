// Frequency: a pixel-art background that keeps changing station, drawn behind the text.
// One loop of nearly three minutes on two stations, then back to the very first frame:
//   fish bones crossing at 2 frames a second -> (radio swap) -> skulls flying diagonally at 30 ->
//   the picture cracks into boxes that crumble away, showing a brighter world underneath ->
//   (glitch, radio swap) -> polka dots humming on unstable electricity -> (radio swap) ->
//   an old wooden TV showing a 1930s cartoon dog in trousers jogging, the camera following ->
//   a heavy glitch tears it apart, it zooms into a distant pattern, flies into a gridded
//   asteroid field of wildly coloured, glitching cubes and pans around -> (radio swap) ->
//   the second station, where nothing is quite right: black holes tear apart three suburbs ->
//   a digital bottle pours letters that grow into earth, water and fire -> a tunnel of them
//   collapses as time warps, a hypnotic swirl spreading out of it -> glitch to black, old green
//   computer lines -> eyes opening one by one until the window is full -> laughing lips ->
//   down the last one's throat -> an ocean of made-up letters under a night city of letters ->
//   (glitch, radio swap) -> the fish bones again.
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

// --- how long each part lasts, in seconds ---
static const float  FISH_SEC       = 9.0;
static const float  RF_SEC         = 3.5;    // each radio-frequency swap
static const float  SKULL_SEC      = 8.0;
static const float  CRUMBLE_SEC    = 4.5;
static const float  BRIGHT_SEC     = 4.0;
static const float  POLKA_SEC      = 8.0;
static const float  TV_SEC         = 11.0;
static const float  TEAR_SEC       = 3.0;
static const float  ZOOM_SEC       = 3.0;
static const float  SPACE_SEC      = 10.0;
static const float  SUBURB_SEC     = 15.0;   // the second station starts here: three towns, 5 s each
static const float  BOTTLE_SEC     = 7.0;
static const float  TUNNEL_SEC     = 9.0;   // the tunnel collapsing, slowly...
static const float  SWIRL_SEC      = 4.0;    // ...and the swirl once it has taken over
static const float  PC_SEC         = 3.0;
static const float  EYES_SEC       = 7.0;
static const float  LIPS_SEC       = 6.0;
static const float  THROAT_SEC     = 4.0;
static const float  CITY_SEC       = 13.0;   // the first CITY_STATIC of it is grey static
static const float  START_AT       = 0.0;    // for trying things out: start this many seconds into the loop

// --- random glitches between the planned ones ---
static const float  GLITCH_STRENGTH = 1.0;   // 0 switches the random glitches off; planned ones stay
static const float  GLITCH_WINDOW  = 7.0;    // each window of this many seconds may hold one glitch
static const float  GLITCH_CHANCE  = 0.6;    // share of windows that do
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
static const float  BOTTLE_BLEND    = 4.0;   // seconds the bottle's heap takes to dissolve into the tunnel
static const float  BLEND_BLOCK     = 6.0;   // size of the blocks it dissolves in, cells
static const float  BLACKOUT_SEC    = 2.0;   // the swirl glitching away to black
static const float  PC_LINGER       = 2.5;   // the green computer lines linger this long among the first eyes
static const float  CITY_STATIC     = 4.5;   // long grey static between the throat and the city...
static const float  CITY_CLEAR      = 1.8;   // ...clearing over its last this-many seconds

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
static const float  LOOP_SEC = E_CITY + RF_SEC;

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
    else if (tl < E_CITY)   { id = S_CITY; t = tl - E_THROAT; }
    else                    { id = S_CITY; t = tl - E_THROAT; idB = S_FISH; tB = 0.0; rf = (tl - E_CITY) / RF_SEC; rfHeavy = 0.5; }

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
    float2 cc = g > 0.0 ? glitchCoord(c, grid, g, seed) : c;

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

    // the zoom gives way to the cubes cell by cell, in a dither, so only one picture is drawn
    if (zoomMix > 0.65 && hash2(c + floor(T * 20.0)) < smoothstep(0.65, 1.0, zoomMix)) { id = S_SPACE; t = tl - E_ZOOM; cc = c; }
    float3 col = sceneColour(id, cc, grid, t);

    if (g > 0.0) col = glitchColour(col, c, g, seed);
    if (gline) col = lerp(col * 1.2, hue(hash2(float2(lrow, lslot + 2.0))), 0.2);
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

    // between the throat and the city: a long stretch of grey static that slowly clears
    if (id == S_CITY && t < CITY_STATIC)
    {
        float n  = hash3(float3(c, floor(T * 30.0))).x;
        float gr = 0.25 + 0.6 * n;
        gr *= 0.85 + 0.15 * sin(c.y * 0.05 - T * 6.0);                           // a soft rolling band
        if (hash2(float2(floor(c.y / 3.0), floor(T * 15.0))) < 0.02) gr = 0.9;   // bright tear lines
        float strength = (1.0 - smoothstep(CITY_STATIC - CITY_CLEAR, CITY_STATIC, t)) * smoothstep(0.0, 0.4, t);
        col = lerp(col * smoothstep(CITY_STATIC - CITY_CLEAR - 0.5, CITY_STATIC, t), float3(gr, gr, gr), strength);
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
