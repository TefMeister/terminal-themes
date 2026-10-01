// Halloween: a pixel-art graveyard night drawn behind the text.
// Back to front: a banded night sky with stars, a big moon and drifting clouds; witches on brooms
// flying across in the distance; two rows of hills with dead trees and gravestones; a foggy field
// rolling towards you, with zombies walking out of the dark (seen only when lightning lights them);
// the witch's hut on the left, potions brewing behind its window (now and then one goes bang in purple
// or pink, and the chimney smoke takes the colour); the sheet ghost, which turns up in a different
// spot each visit, near or far, drifting across; turned pumpkins in the bottom corners; then,
// nearest of all, spiders dangling from the top and crawling on the inside of the glass (so you see
// their undersides).
// Every GHOST_PERIOD seconds the top of the sky slowly darkens, then the ghost appears: three
// lightning strikes light the whole picture up, and more keep striking at uneven times for as long as
// it stays, with smaller bolts flashing far off. Each flash swells, flickers and fades rather than
// blinking. The zombies are always there as black shapes; only the lightning shows what they are.
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
static const float  EDGE_FADE      = 0.04;   // share of the width over which the left and right sides fade to black

// --- sprite sheet layout (matches halloween-sprites.py) ---
static const int    SHEET_W = 384, SHEET_H = 1278;
static const int    PKW = 48, PKH = 40, PK_Y = 0;     // pumpkins: 3 kinds (rows) x 4 candle-flame frames
static const int    HUTW = 128, HUTH = 120, HUT_X = 192;  // the witch's hut
static const int    ZW = 32, ZH = 44, Z_Y = 120;      // zombies: 12 rows x 8 walk frames, row = (view * 2 + arms) * 2 + outfit
static const int    WW = 40, WH = 24, W_Y = 648;      // witch: 4 frames
static const int    SW = 40, SH = 40, S_Y = 672;      // spider from underneath: 4 frames
static const int    HW = 24, HH = 24, H_Y = 712;      // hanging spider: 2 frames
static const int    TW = 64, TH = 80, T_Y = 736;      // dead trees: 2 kinds
static const int    GW = 16, GH = 22, G_Y = 816;      // gravestones: 4 kinds
static const int    BPW = 96, BPH = 80, BIG_Y = 838;  // big turned pumpkins: 3 rows x 4 flame frames, drawn twice as fine
static const int    BTW = 160, BTH = 200, BT_Y = 1078; // big trees: 2 kinds
// branch points spiders hang from, 4 per big tree drawing (sheet pixels; printed by halloween-sprites.py)
static const float2 BT_ANCHOR[8]   = { float2(75.3, 168.7), float2(46.5, 151.4), float2(111.5, 145.6), float2(130.9, 99.5),
                                       float2(68.2, 131.5), float2(112.8, 167.6), float2(48.3, 164.5), float2(88.5, 172.2) };

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
static const int    STRIKES        = 12;     // most strikes in one visit; they stop when the ghost leaves
static const float  STRIKE_GAP_MIN = 1.0;    // seconds between strikes after the first three...
static const float  STRIKE_GAP_MAX = 4.5;    // ...picked at random in this range, so never regular
static const int    DISTANT_EACH   = 2;      // small far-off bolts that follow each strike
static const float3 STORM_PURPLE   = float3(0.74, 0.62, 1.00);   // storm clouds as a flash lights them...
static const float3 STORM_BLUE     = float3(0.52, 0.66, 1.00);   // ...drifting between these two colours
static const float  STORM_SPEED    = 0.55;   // how fast they race across (cloud widths per second, roughly)
static const float  STORM_GLOW     = 1.3;    // how strongly a flash lights them
static const float  STORM_WASH     = 0.35;   // plain light spread over the whole sky in a flash
static const float  DIM_LEAD       = 6.0;    // seconds the sky darkens before the ghost comes
static const float  DIM_RELEASE    = 4.0;    // seconds it takes to clear after the ghost has gone
static const float  DIM_AMOUNT     = 0.65;   // how dark the top of the picture gets
static const float  DIM_REACH      = 0.85;   // how far down the darkening reaches (share of the height)

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

// --- big trees standing in the field, between you and the hut ---
// listed by depth; zombies, the ghost and the hut pass behind or in front of each one
static const int    FG_TREES       = 3;
static const float  FT_X[3]        = { 0.45, 0.71, 0.27 };   // trunk, across the width
static const float  FT_DEPTH[3]    = { 0.16, 0.36, 0.55 };   // where it stands in the field (0 horizon, 1 bottom)
static const float  FT_HEIGHT[3]   = { 0.62, 0.82, 1.02 };   // drawing height, as a share of the window
static const int    FT_KIND[3]     = { 0, 1, 0 };
static const int    FT_MIRROR[3]   = { 0, 0, 1 };
static const float  TREE_HAZE      = 0.35;   // further trees melt a little into the fog
static const float  TREE_BARK      = 1.0;    // how much bark a lightning flash shows
static const float  LEAF_AMBIENT   = 0.35;   // the few leaves keep a little colour in the dark

// --- purple flowers in the grass ---
static const int    FLOWER_PATCHES = 18;     // the first ones grow round the big trees and the hut
static const float3 FLOWER_DEEP    = float3(0.45, 0.16, 0.62);
static const float3 FLOWER_LIGHT   = float3(0.78, 0.40, 0.95);
static const float3 FLOWER_EYE     = float3(0.95, 0.85, 0.35);
static const float3 STEM_COLOUR    = float3(0.10, 0.22, 0.08);
static const float  FLOWER_AMBIENT = 0.45;   // how much of their colour shows in the dark

// --- zombies ---
static const int    ZOMBIES        = 14;
static const float  ZOMBIE_TRIP    = 190.0;  // typical seconds to shuffle from the horizon to you
static const float  ZOMBIE_FAR     = 0.22;   // size on the horizon
static const float  ZOMBIE_NEAR    = 3.2;    // size when they reach the front
static const float  ZOMBIE_LURCH   = 0.60;   // lurches per second (one step to each side), varies per zombie
static const float  ZOMBIE_LEAN    = 0.07;   // how far the body leans into each lurch (subtle)
static const float  ZOMBIE_SWAY    = 1.0;    // how far, in sprite pixels, the body swings side to side
static const float  ZOMBIE_HAZE    = 0.30;   // far zombies melt a little into the fog
static const float  ZOMBIE_AMBIENT = 0.10;   // moonlight on them between flashes, so they read as solid
static const int    ZOMBIE_FRAMES  = 8;      // drawings per stride (two steps)
static const float  ZOMBIE_FRONT   = 0.45;   // share walking straight at you...
static const float  ZOMBIE_DIAG    = 0.27;   // ...at 45 degrees (the rest walk side on, across the field)
static const float  ZOMBIE_DRIFT   = 0.40;   // how far a 45-degree walker drifts across (share of the width)
static const float  ZOMBIE_STRIDE  = 14.0;   // sprite pixels covered per stride, so side-on feet do not slide
static const float  ZOMBIE_ARMS_OUT= 0.5;    // share holding their arms out in front

// --- the ghost ---
// Each visit uses the next of these spots. X0 -> X1 is where it drifts across the window (shares of
// the width, crown middle), Y its crown and SIZE its height (shares of the height). DEPTH places it in
// the scene: -1 = far off, behind the trees and gravestones on the hill; otherwise a share of the field
// (0 horizon, 1 bottom), so the hut (at HUT_DEPTH) and nearer zombies can stand in front of it.
static const int    GHOST_SPOTS    = 10;
static const float  GHOST_X0[10]   = { 0.70, 0.28, 0.12, 0.86, 0.22, 0.80, 0.40, 0.45, 0.64, 0.30 };
static const float  GHOST_X1[10]   = { 0.38, 0.60, 0.42, 0.52, 0.58, 0.48, 0.82, 0.06, 0.30, 0.66 };
static const float  GHOST_Y[10]    = { 0.08, 0.40, 0.32, 0.43, 0.04, 0.26, 0.45, 0.30, 0.15, 0.22 };
static const float  GHOST_SIZE[10] = { 0.58, 0.20, 0.30, 0.16, 0.66, 0.38, 0.13, 0.27, 0.48, 0.42 };
static const float  GHOST_DEPTH[10]= { 0.95, -1.0, 0.05, -1.0, 0.95, 0.35, -1.0, 0.05, 0.60, 0.30 };
static const float  GHOST_DRIFT_SWAY = 0.04; // side-to-side drift while it hovers, per unit of its size
static const float3 GHOST_LIGHT    = float3(0.93, 0.95, 1.00);
static const float3 GHOST_SHADE    = float3(0.48, 0.50, 0.66);
static const float3 GHOST_EDGE     = float3(0.30, 0.30, 0.45);
static const float3 GHOST_EYE      = float3(0.010, 0.005, 0.020);
static const float  GHOST_OPACITY  = 0.80;
static const float  WIND           = 0.13;   // how far the wind pushes the sheet to the left

// --- pumpkins (listed back to front) ---
// The pumpkins at the bottom, listed back to front. Each is turned so it looks towards the middle:
// the ones on the right look left, the ones on the left look right. Sizes and places are shares of the
// window height, so they keep their shape in any window. A big one stands at the back of each group,
// partly past the edge of the window, where it fades into the black.
static const int    PUMPKINS       = 5;
static const float  PK_SIDE[5]     = { 1, -1, 1, -1, 1 };              // 1 = right group, -1 = left group
static const float  PK_INSET[5]    = { 0.06, 0.11, 0.30, 0.30, 0.17 }; // middle's distance from that edge
static const float  PK_SINK[5]     = { 0.04, 0.05, 0.02, 0.02, 0.03 }; // how far the bottom sits below the window
static const float  PK_HEIGHT[5]   = { 0.42, 0.26, 0.17, 0.14, 0.13 };
static const int    PK_ROW[5]      = { 0, 2, 1, 0, 2 };                // which turned pumpkin drawing
static const float3 CANDLE_DEEP    = float3(1.00, 0.30, 0.02);
static const float3 CANDLE_HOT     = float3(1.00, 0.92, 0.50);
static const float  CANDLE_GLOW    = 1.9;    // pumpkin faces are brighter than the rest of the picture
static const float  PUMPKIN_BODY   = 0.60;   // pumpkin skin brightness in the dark
static const float  POOL_SIZE      = 1.1;    // reach of the orange light on the ground, per unit of size
static const float  HALO_SIZE      = 26.0;   // reach of the light round a small pumpkin, per unit of its size
static const int    HILL_PUMPKINS  = 4;      // small ones among the gravestones
static const float  HILL_PK_X[4]   = { 0.33, 0.49, 0.70, 0.90 };
static const float  HILL_PK_SCALE  = 0.21;

// --- the witch's hut ---
static const float  HUT_POS        = 0.14;   // across the width, of its middle
static const float  HUT_SIZE       = 0.42;   // height, as a share of the window
static const float  HUT_DEPTH      = 0.10;   // how far in front of the horizon it stands (share of the field)
static const float  HUT_DARK       = 0.85;   // how much the moon shows of it
// potions brewing inside: the window light drifts between these colours, bubbling...
static const float3 BREW_COLOURS[4]= { float3(0.62, 1.00, 0.38), float3(0.70, 0.35, 1.00), float3(1.00, 0.40, 0.80), float3(0.35, 0.95, 0.85) };
static const float  BREW_CHANGE    = 7.0;    // seconds per colour
// ...and every so often something goes bang: quick flashes of purple or pink, and the smoke that
// leaves the chimney straight after carries the same colour up into the sky
static const float3 BURST_PURPLE   = float3(0.75, 0.30, 1.00);
static const float3 BURST_PINK     = float3(1.00, 0.35, 0.78);
static const float  BURST_GAP      = 4.5;    // typical seconds between bangs
static const float  BURST_CHANCE   = 0.65;   // share of those chances that actually go bang
static const float  BURST_GLOW     = 2.4;    // how bright a bang lights the window
static const float  BURST_REACH    = 60.0;   // reach of the light thrown round the hut, in hut pixels
static const float  BURST_SMOKE    = 2.0;    // seconds of smoke after a bang that carry its colour
static const float  PORCH_PK_X[2]  = { 24.0, 104.0 };           // pumpkins on the porch, in hut pixels
static const float  PORCH_PK_SCALE = 0.24;   // their size, relative to the hut's
static const float  SMOKE_RISE     = 0.25;   // how fast the smoke climbs
static const float  SMOKE_HEIGHT   = 80.0;   // how high the column reaches, in hut pixels
static const float3 SMOKE_COLOUR   = float3(0.34, 0.31, 0.38);
static const float3 RIM_COLOUR     = float3(0.06, 0.06, 0.10);   // moonlight on the zombies' edges

// --- witches ---
static const int    WITCHES        = 4;
static const float  WITCH_TRIP     = 22.0;   // typical seconds to cross the sky

// --- spiders ---
static const int    CRAWLERS       = 2;
static const float  CRAWL_SCALE    = 0.9;    // on the glass, but small and quick
static const float  CRAWL_SPEED    = 0.28;   // how quickly they wander (radians of their curvy path per second)
static const float  CRAWL_ROAM     = 0.62;   // how far from the middle they roam
static const float  CRAWL_CYCLE    = 50.0;   // each one only turns up now and then: once in this many seconds...
static const float  CRAWL_VISIT    = 14.0;   // ...for this long, scuttling in from beyond the edge and out again
static const float  CRAWL_ENTER    = 2.5;    // seconds it takes to come in from (or go back out past) the edge
// small spiders on the big pumpkins in the bottom corners: one climbs up into a mouth, and a little
// later comes crawling out of an eye socket and away over the top
static const int    PK_SPIDERS     = 2;
static const float  PKSP_CYCLE     = 22.0;   // seconds between one spider's trips
static const float  PKSP_SCALE     = 0.30;   // spider size, relative to its pumpkin's
static const float  PKSP_WALK_IN   = 5.0;    // seconds to climb to the mouth
static const float  PKSP_SQUEEZE   = 0.6;    // seconds to squeeze in (or out)
static const float  PKSP_INSIDE    = 2.8;    // seconds spent inside the pumpkin
static const float  PKSP_WALK_OUT  = 4.0;    // seconds to crawl from the eye over the top and away
// where the holes are in the big turned pumpkins (sheet pixels, face looking left, one per drawing):
// the middle of each, and the edge a spider uses (the mouth's side corner, the eyes' upper outer rim)
static const float2 PK_MOUTH[3]    = { float2(27.9, 59.5), float2(29.7, 55.1), float2(25.4, 60.3) };
static const float2 PK_EYE[3]      = { float2(33.9, 37.5), float2(38.7, 30.2), float2(28.3, 37.2) };
static const float2 PK_EYE_FAR[3]  = { float2(6.7, 39.1),  float2(14.4, 32.9), float2(5.1, 39.3) };
static const float2 PK_MOUTH_EDGE[3]   = { float2(7.5, 57.5),  float2(11.5, 50.5), float2(4.5, 56.5) };
static const float2 PK_EYE_EDGE[3]     = { float2(49.5, 29.5), float2(53.5, 22.5), float2(44.5, 33.5) };
static const float2 PK_EYE_FAR_EDGE[3] = { float2(8.5, 35.5),  float2(14.5, 26.5), float2(8.5, 32.5) };
static const int    HANGERS        = 3;      // spiders dropping from the big trees' branches
static const float  HANG_SCALE     = 0.45;   // spider size, relative to its tree's
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

// the ghost's visit: n is which visit, t the seconds into it, s1 when it appears (with the first strike)
void ghostTimes(float T, out float n, out float t, out float s1)
{
    float f = loopFreq(1.0 / GHOST_PERIOD);
    float p = T * f;
    n = loopIndex(floor(p), f);
    t = frac(p) / f;
    s1 = DIM_LEAD + hash(n * 3.1) * 0.8;
}

// strike i of visit n: when it lands (after the one before it, at `prev`) and how strong it is.
// The first three come close together, the rest at random gaps until the ghost leaves.
float nextStrike(float n, int i, float prev)
{
    float h = hash(n * 7.3 + i * 1.91);
    if (i == 0) return prev;
    if (i == 1) return prev + 0.6 + h * 1.9;
    if (i == 2) return prev + 0.35 + h * 1.5;
    return prev + STRIKE_GAP_MIN + h * (STRIKE_GAP_MAX - STRIKE_GAP_MIN);
}
float strikeStrength(float n, int i) { return i < 3 ? 0.85 + 0.15 * hash(n + i) : 0.35 + 0.6 * hash(n * 2.7 + i); }

float flashAt(float t, float n, float s1)
{
    float f = 0.0, st = s1;
    [loop] for (int i = 0; i < STRIKES; i++)
    {
        st = nextStrike(n, i, st);
        if (st > s1 + GHOST_STAY) break;
        f = max(f, strikeLight(t - st) * strikeStrength(n, i));
    }
    return f;
}

// a jagged line from `top` down to `bottom` at around x0, with a branch part way down
float boltLine(float2 c, float x0, float top, float bottom, float seed, float wobble, float width)
{
    if (c.y < top || c.y > bottom) return 0.0;
    float x = x0 + noise1(c.y * 0.07 + seed) * wobble + noise1(c.y * 0.31 + seed * 2.0) * wobble * 0.25;
    if (abs(c.x - x) < (c.y < lerp(top, bottom, 0.5) ? width : width * 0.66)) return 1.0;
    float by = lerp(top, bottom, 0.30 + 0.25 * hash(seed + 1.0));
    float dir = hash(seed + 2.0) < 0.5 ? -1.0 : 1.0;
    if (c.y > by && c.y < by + (bottom - top) * 0.35)
    {
        float bx0 = x0 + noise1(by * 0.07 + seed) * wobble + noise1(by * 0.31 + seed * 2.0) * wobble * 0.25;
        float bx = bx0 + dir * (c.y - by) * 0.8 + noise1(c.y * 0.4 + seed * 3.0) * wobble * 0.2;
        if (abs(c.x - bx) < width * 0.5) return 0.75;
    }
    return 0.0;
}

// the bolts: big ones from the top of the sky for each strike, small ones far off near the horizon.
// Returns how much bolt light is on this cell (x) and how much far-off glow lights the sky here (y).
float2 bolts(float2 c, float t, float n, float s1, float2 grid, float horizonY, out float distant)
{
    float b = 0.0, glow = 0.0, st = s1;
    distant = 0.0;
    [loop] for (int i = 0; i < STRIKES; i++)
    {
        st = nextStrike(n, i, st);
        if (st > s1 + GHOST_STAY) break;
        float seed = n * 17.0 + i * 5.3;
        float a = t - st;
        if (a >= 0.0 && a < 0.32)
        {
            float x0 = grid.x * (0.06 + 0.88 * hash(seed));
            float bottom = horizonY - grid.y * 0.12;
            float on = strikeLight(a) > 0.45 ? 1.0 : 0.55;
            b = max(b, boltLine(c, x0, 0.0, bottom, seed, 16.0, 1.5) * on * min(1.0, strikeStrength(n, i) + 0.3));
            glow = max(glow, saturate(1.0 - abs(c.x - x0) / 30.0) * 0.18 * strikeLight(a) * step(c.y, bottom));
        }
        [loop] for (int j = 0; j < DISTANT_EACH; j++)
        {
            float ds = seed * 1.7 + j * 11.0;
            float da = a - (0.15 + hash(ds) * 2.2);              // they follow at uneven delays
            if (da < 0.0 || da > 0.8) continue;
            float e = strikeLight(da) * (0.4 + 0.4 * hash(ds + 4.0));
            distant = max(distant, e);
            float x0 = grid.x * hash(ds + 1.0);
            float foot = horizonY - grid.y * (0.10 + 0.04 * hash(ds + 3.0));
            float top = foot - grid.y * (0.10 + 0.14 * hash(ds + 2.0));
            if (da < 0.25) b = max(b, boltLine(c, x0, top, foot, ds, 5.0, 0.55) * 0.55 * (e > 0.2 ? 1.0 : 0.5));
            glow = max(glow, saturate(1.0 - length((c - float2(x0, foot)) / float2(55.0, 30.0))) * e * 0.35);
        }
    }
    return float2(b, glow);
}

// the ghost and everyone else in the picture
#include "halloween-cast.hlsli"

// the big trees, the flowers and the spiders that hang from the branches
#include "halloween-trees.hlsli"

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

    // --- the ghost's visit: darkening first, then the strikes for as long as it stays ---
    float n, gt, s1;
    ghostTimes(Tf, n, gt, s1);
    float distant;
    float2 bl = bolts(c, gt, n, s1, grid, horizonY, distant);
    float flash = steps(max(flashAt(gt, n, s1), distant * 0.18), FLASH_STEPS, dth * 0.6);
    float ghostEnd = s1 + GHOST_STAY + GHOST_FADE_OUT;
    float ghostA = saturate((gt - s1 + 0.1) / GHOST_FADE_IN) * saturate((ghostEnd - gt) / GHOST_FADE_OUT);
    float dim = smoothstep(s1 - DIM_LEAD, s1, gt) * (1.0 - smoothstep(ghostEnd, ghostEnd + DIM_RELEASE, gt));
    // the darkening of the upper night, worked out now: the ghost is drawn among the scenery but must
    // not darken with it, so it is drawn brighter by the same amount (exact, as both are just multiplies)
    float reach = steps(saturate(1.0 - c.y / (grid.y * DIM_REACH)), 6.0, dth);
    float dimMul = 1.0 - DIM_AMOUNT * dim * reach * (1.0 - 0.85 * flash);
    float lift = 1.0 / max(dimMul, 0.05);
    // this visit's spot: where it drifts, how big, and how deep in the scene
    int   spot = pmod((int)n, GHOST_SPOTS);
    float gDepth = GHOST_DEPTH[spot];
    float gBase = horizonY + (grid.y - horizonY) * gDepth;          // the ground line it hovers over
    float gu = saturate((gt - s1 + 0.1) / (GHOST_STAY + GHOST_FADE_OUT));
    float2 gCrown = float2(lerp(GHOST_X0[spot], GHOST_X1[spot], lerp(gu, smoothstep(0.0, 1.0, gu), 0.5)) * grid.x,
                           GHOST_Y[spot] * grid.y);
    float gSize = GHOST_SIZE[spot] * grid.y;
    bool gLeft = GHOST_X1[spot] < GHOST_X0[spot];

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
    float cloud = cl * saturate(1.0 - abs(v - 0.30) / 0.24);
    if (cloud > 0.55)
    {
        float rim = saturate(1.0 - md / (mr * 3.0));
        float edge = saturate((0.62 - cloud) / 0.07);
        col = lerp(CLOUD_COLOUR, CLOUD_RIM, steps(rim * (0.35 + 0.65 * edge), 4.0, dth));
        if (md < mr) col = lerp(col, MOON_COLOUR * 0.55, 0.35);
        col += FLASH_SKY * flash * 0.45;
    }
    col = lerp(col, FLASH_SKY, flash * STORM_WASH * (1.0 - v * 0.3));
    // storm clouds racing across: unseen in the dark, lit light purple and blue by each flash, and
    // fading out towards the horizon so they melt into the distance
    float2 sp = c * float2(0.007, 0.028) + float2(Tf * loopRate(STORM_SPEED * TAU) / TAU, Tf * loopRate(STORM_SPEED * 0.15 * TAU) / TAU);
    float storm = noise2(sp) * 0.6 + noise2(sp * 2.3 + 7.0) * 0.4;
    float stormLit = smoothstep(0.40, 0.78, storm) * (1.0 - smoothstep(0.30, 0.92, v)) * (flash + bl.y * 2.0);
    float3 stormCol = lerp(STORM_PURPLE, STORM_BLUE, noise2(sp * 0.6 + 3.0));
    col = lerp(col, stormCol, steps(saturate(stormLit * STORM_GLOW), 6.0, dth));
    col += FLASH_SKY * steps(bl.y, 5.0, dth) * step(c.y, horizonY);   // far-off lightning glowing in the sky
    float3 sky = col;
    col = lerp(col, BOLT_COLOUR, bl.x);
    [branch] if (sprites) col = drawWitches(col, cell, grid, T, tick, sky);

    // --- hills: the far row lights up in a flash, the near row stays almost black ---
    float hf = hillFar(c.x, grid), hn = hillNear(c.x, grid);
    if (c.y >= hf) col = HILL_FAR * (1.0 + steps(saturate((c.y - hf) / 20.0), 3.0, dth) * -0.3) + FLASH_SKY * flash * HILL_FAR_FLASH * 0.5;
    // a far-off ghost: the trees, gravestones and near hill all stand in front of it
    if (gDepth < 0.0) col = drawGhost(col, cell, grid, T, ghostA, flash, dth, gCrown, gSize, gLeft, lift);
    [branch] if (sprites) col = drawYard(col, cell, grid, flash);
    if (c.y >= hn && c.y < horizonY) col = HILL_NEAR + FLASH_SKY * flash * HILL_NEAR_FLASH * 0.4;
    [branch] if (sprites) col = drawHillPumpkins(col, cell, grid, T, tick, flash, dth);

    // --- the field rolling towards you ---
    [branch] if (c.y >= horizonY)
    {
        float d = saturate((c.y - horizonY) / max(grid.y - horizonY, 1.0));
        float3 g = lerp(GROUND_FAR, GROUND_NEAR, steps(d, 6.0, dth));
        float tuft = hash2(floor(float2(c.x / (1.0 + d * 3.0), c.y)));
        if (tuft > 0.93) g *= 1.5;
        float rows = frac(1.0 / (d + 0.08) * 1.3);                  // furrows bunching up into the distance
        if (rows < 0.12) g *= 0.75;
        col = g * (1.0 + flash * 2.2 * (1.0 - d * 0.6));
        [branch] if (sprites) col = pumpkinPools(col, cell, grid, T, dth);
        col = drawFlowers(col, cell, grid, horizonY, flash);
    }
    // --- ground fog drifting across, thick at the horizon and thinning towards you ---
    float fy = (c.y - (horizonY - 10.0)) / max(grid.y - horizonY, 1.0);
    float fog = 0.0;
    [branch] if (fy > -0.2)
    {
        float fd = saturate(1.0 - abs(fy - 0.12) / 0.55);
        float drift = 0.55 + 0.45 * sin(c.x * 0.025 + T * loopRate(0.25) + c.y * 0.2) * sin(c.x * 0.011 - T * loopRate(0.13));
        fog = steps(fd * fd * drift * FOG_AMOUNT, 5.0, dth);
        col = lerp(col, FOG_COLOUR * (1.0 + flash * 2.5), fog);
    }

    [branch] if (sprites)
    {
        // everything standing in the field, drawn back to front by where it meets the ground:
        // 0 the hut, 1 the ghost, 2 the nearest zombie here, 3.. the big trees (with their spiders)
        float zFeet;
        float3 zCol = drawZombies(col, cell, grid, T, tick, flash, horizonY, zFeet);
        float2 hAt; float hSc, hBase;
        hutPlace(grid, horizonY, hAt, hSc, hBase);
        float lastBase = -1e9;
        int lastId = -1;
        [loop] for (int step = 0; step < 3 + FG_TREES; step++)
        {
            int id = -1;
            float base = 1e9;
            [loop] for (int i = 0; i < 3 + FG_TREES; i++)
            {
                float b = i == 0 ? hBase : (i == 1 ? (gDepth >= 0.0 && ghostA > 0.0 ? gBase : -2e9)
                        : (i == 2 ? (zFeet >= 0.0 ? zFeet : -2e9) : treeBase(max(i - 3, 0), grid, horizonY)));
                bool later = b > lastBase || (b == lastBase && i > lastId);
                if (b > -1e9 && later && (b < base || (b == base && i < id))) { base = b; id = i; }
            }
            if (id < 0) break;
            lastBase = base; lastId = id;
            if (id == 0)
            {
                col = drawHut(col, cell, grid, T, flash, fog, horizonY, -1.0, dth);
                col = drawSmoke(col, cell, grid, T, flash, horizonY, dth);
                col = drawPorchPumpkins(col, cell, grid, T, tick, flash, horizonY, dth);
            }
            else if (id == 1) col = drawGhost(col, cell, grid, T, ghostA, flash, dth, gCrown, gSize, gLeft, lift);
            else if (id == 2) col = zCol;
            else
            {
                col = drawBigTree(col, cell, grid, horizonY, id - 3, flash);
                col = drawTreeHangers(col, cell, grid, T, tick, flash, horizonY, id - 3);
            }
        }
    }
    else if (gDepth >= 0.0) col = drawGhost(col, cell, grid, T, ghostA, flash, dth, gCrown, gSize, gLeft, lift);

    // --- before and during the ghost's visit the upper part of the night darkens ---
    col *= dimMul;

    [branch] if (sprites)
    {
        col = drawPumpkins(col, cell, grid, T, tick, flash);
        col = drawPumpkinSpiders(col, cell, grid, T, tick, flash);
        col = drawCrawlers(col, cell, grid, T, tick, flash);
    }

    // the picture fades to black in a thin strip at the left and right, where the window cuts it off,
    // in dithered steps so it stays pixel-art; the top and bottom are drawn right to the edge
    float ux = c.x / grid.x;
    col *= steps(smoothstep(0.0, 1.0, saturate(min(ux, 1.0 - ux) / EDGE_FADE)), 8.0, dth);
    col = saturate(col * SCENE_BRIGHT);

    // letters on top, crisp; the picture fades out underneath them so they stay readable
    float3 text = readText(tex);
    return float4(text + col * (1.0 - ink(text)), 1.0);
}
