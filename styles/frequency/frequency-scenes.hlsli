// Frequency, part 2: the fish bones, the skulls, the crumbling boxes, the brighter world and the
// humming polka dots. Included by frequency.hlsl, which holds the shared helpers.

// --- fish bones: crossing in lanes, stepping along at 2 frames a second ---
static const float  FISH_FPS       = 2.0;
static const int    FISH_LAYERS    = 3;      // depth layers; the front one is drawn twice the size
static const float  FISH_SPEED     = 12.0;   // cells per second at the smallest size
static const float  FISH_DENSITY   = 0.55;   // share of places in a lane that hold a fish
static const float  FISH_RATES[9]  = { 2.0, 3.0, 5.0, 8.0, 12.0, 15.0, 24.0, 30.0, 60.0 };  // frame rates the lanes pick from
static const float  FISH_SWIM_FPS  = 4.0;    // the tail flicks at most this often, whatever the lane's rate
static const float  FISH_SWAP_SEC  = 4.0;    // roughly how often each fish glitches into another kind
static const float  FISH_SWAP_GLITCH = 0.35; // how long that glitch lasts
static const float  FISH_BONES     = 0.65;   // share of fish that are bones at any moment
static const float  FISH_FAR       = 0.45;   // brightness of the back layer (front = 1)
static const float3 FISH_WATER_TOP  = float3(0.05, 0.16, 0.20);
static const float3 FISH_WATER_DEEP = float3(0.01, 0.04, 0.07);
static const float3 FISH_CURRENT   = float3(0.03, 0.07, 0.07);
static const float3 FISH_SPECK     = float3(0.30, 0.38, 0.32);

// --- skulls: flying diagonally, smooth at 30 frames a second, with a short smear behind ---
static const float  SKULL_FPS      = 30.0;
static const float2 SKULL_DIR      = float2(1.0, 0.62);   // down and to the right
static const int    SKULL_LAYERS   = 3;
static const float  SKULL_SPEED    = 34.0;   // cells per second at the smallest size
static const float  SKULL_DENSITY  = 0.5;
static const float  SKULL_TRAIL    = 5.0;    // sprite pixels between smear copies
static const float3 SKULL_BG_A     = float3(0.07, 0.02, 0.10);
static const float3 SKULL_BG_B     = float3(0.10, 0.03, 0.13);

// --- the crumble: the skull picture cracks into boxes that fall apart into bits ---
static const float  CRUMBLE_BIT    = 4.0;    // size of one falling bit, cells (x the sprite size)
static const float  CRUMBLE_BITS   = 4.0;    // bits along each side of a box
static const float  CRUMBLE_SPREAD = 3.2;    // seconds from the first box going to the last
static const float  CRUMBLE_LOOSEN = 0.3;    // bits of one box come loose up to this far apart
static const float  CRUMBLE_GRAVITY = 140.0; // cells per second per second
static const float  CRUMBLE_LIFE   = 1.1;    // seconds a falling bit takes to crumble to nothing
static const int    CRUMBLE_REACH  = 26;     // bits above a pixel checked for one falling past it
static const float  CRACK_SEC      = 0.6;    // a box flickers this long before it goes
static const float3 CRACK_COLOUR   = float3(0.70, 1.00, 0.95);

// --- the brighter world: a hot sunrise over a glowing grid ---
static const float  BRIGHT_HORIZON = 0.62;   // share of the height down to the horizon
static const float3 BRIGHT_SKY_TOP = float3(1.00, 0.30, 0.72);
static const float3 BRIGHT_SKY_MID = float3(1.00, 0.62, 0.30);
static const float3 BRIGHT_SKY_LOW = float3(1.00, 0.95, 0.55);
static const float3 BRIGHT_SUN_TOP = float3(1.00, 1.00, 0.70);
static const float3 BRIGHT_SUN_LOW = float3(1.00, 0.35, 0.55);
static const float3 BRIGHT_HILLS   = float3(0.55, 0.12, 0.70);
static const float3 BRIGHT_FLOOR   = float3(0.45, 0.05, 0.42);
static const float3 BRIGHT_LINES   = float3(0.40, 1.00, 1.00);
static const float  BRIGHT_SPEED   = 1.6;    // how fast the floor grid rushes towards you
static const float  BRIGHT_FOG     = 26.0;   // floor distance at which it melts into the haze
static const float3 BRIGHT_HAZE    = float3(1.00, 0.55, 0.75);
static const int    BRIGHT_PYRAMIDS = 3;
static const float3 BRIGHT_PYRAMID = float3(0.30, 0.06, 0.40);

// --- polka dots on unstable electricity ---
static const float  POLKA_SPACING  = 22.0;   // cells between dots (x the sprite size)
static const float  POLKA_RADIUS   = 0.36;   // dot radius as a share of the spacing
static const float  POLKA_HUM      = 0.12;   // how strongly the dots hum
static const float  POLKA_FLOW     = 0.7;    // seconds a change in the current takes to cross the window
static const float  POLKA_FAULTY   = 0.07;   // share of dots with a bad connection
static const float  POLKA_ROLL     = 0.09;   // how fast the dark hum bar rolls up (screens per second)
static const float  POLKA_SURGE_W  = 0.08;   // the pulses of current running through the dots: how close together...
static const float  POLKA_SURGE_V  = 9.0;    // ...and how fast they run
static const float3 POLKA_BG       = float3(0.30, 0.03, 0.09);
static const float3 POLKA_DOT      = float3(1.00, 0.90, 0.68);
static const float3 POLKA_SPARK    = float3(0.70, 0.85, 1.00);


// mostly bones, sometimes a living fish
float fishKind(float h)
{
    return h < FISH_BONES ? floor(h / FISH_BONES * FISH_KINDS) : FISH_KINDS + floor((h - FISH_BONES) / (1.0 - FISH_BONES) * LIVE_KINDS);
}

float3 fishScene(float2 c, float2 grid, float t)
{
    int   step = (int)floor(t * FISH_FPS);
    float ts   = step / FISH_FPS;
    float d    = dither(c);
    float3 water = lerp(FISH_WATER_TOP, FISH_WATER_DEEP, floor(c.y / grid.y * 6.0 + d) / 6.0);
    float3 col = water;
    if (sin(c.y * 0.15 + sin(c.x * 0.02 + ts * 0.7) * 2.0) > 0.93) col += FISH_CURRENT;
    if (hash2(floor((c + float2(ts * 2.0, -ts * 3.0)) / 2.0)) > 0.9975) col = FISH_SPECK;
    if (!gSprites) return col;

    [loop] for (int L = 0; L < FISH_LAYERS; L++)
    {
        float sc    = gBase * (L == FISH_LAYERS - 1 ? 2.0 : 1.0);
        float near  = lerp(FISH_FAR, 1.0, L / (FISH_LAYERS - 1.0));
        float laneH = FISH_H * sc * 1.7;
        float yo    = L * 41.0;
        float lane  = floor((c.y + yo) / laneH);
        float seed  = lane * 7.31 + L * 113.0;
        // every lane moves at its own frame rate, from a slow 2 a second to a smooth 60
        float fps   = FISH_RATES[min(8, (int)(hash(seed + 5.0) * 9.0))];
        int   lstep = (int)floor(t * fps);
        float lts   = lstep / fps;
        float dir   = hash(seed) > 0.5 ? 1.0 : -1.0;
        float speed = FISH_SPEED * sc * (0.5 + hash(seed + 1.0));
        float tileW = FISH_W * sc * (2.0 + 3.0 * hash(seed + 2.0));
        float wx    = c.x - dir * floor(speed * lts);
        float tile  = floor(wx / tileW);
        if (hash2(float2(tile, seed)) > FISH_DENSITY) continue;
        float id    = tile * 3.7 + seed;
        float lx    = wx - tile * tileW - floor(hash2(float2(tile, seed + 3.0)) * (tileW - FISH_W * sc));
        float bob   = round(sin(lts * 1.7 + tile * 2.1) * 2.0) * sc;
        float ly    = c.y + yo - lane * laneH - floor((laneH - FISH_H * sc) * 0.5) - bob;
        int   frame = (int)wrap(floor(t * min(fps, FISH_SWIM_FPS)) + tile, 2.0);
        // now and then it glitches into another fish: bones become a living fish and back
        float swapT = t / FISH_SWAP_SEC + hash(id + 0.4) * 5.0;
        float slot  = floor(swapT);
        float kind  = fishKind(hash(id + slot * 1.7));
        bool  glitching = frac(swapT) * FISH_SWAP_SEC < FISH_SWAP_GLITCH;
        if (glitching && hash(floor(t * 30.0) + id) < 0.5) kind = fishKind(hash(id + (slot - 1.0) * 1.7));
        if (glitching) lx += floor((hash(floor(ly / (2.0 * sc)) + floor(t * 30.0)) - 0.5) * 6.0) * sc;
        int2 org = kind < FISH_KINDS ? int2(((int)kind * 2 + frame) * FISH_W, FISH_Y)
                                     : int2(LIVE_X + (((int)kind - FISH_KINDS) * 2 + frame) * FISH_W, SKULL_Y);
        float4 sp = sprite(org, int2(FISH_W, FISH_H), float2(lx, ly), sc, dir < 0.0);
        if (sp.a > 0.5)
        {
            col = lerp(water, sp.rgb, near);
            if (glitching && hash(floor(t * 20.0) + id + 3.0) < 0.4) col = hue(hash(floor(t * 20.0) + id)) * luma(sp.rgb) * 1.5;
        }
    }
    return col;
}

float3 skullScene(float2 c, float2 grid, float t)
{
    float  ts  = floor(t * SKULL_FPS) / SKULL_FPS;
    float2 dir = normalize(SKULL_DIR);
    float  band = frac((c.x - c.y * 1.6) * 0.012 + ts * 0.25);
    float3 col = band + dither(c) * 0.1 < 0.5 ? SKULL_BG_A : SKULL_BG_B;
    if (!gSprites) return col;

    [loop] for (int L = 0; L < SKULL_LAYERS; L++)
    {
        float  sc     = gBase * (L == SKULL_LAYERS - 1 ? 2.0 : 1.0);
        float  near   = (L + 1.0) / SKULL_LAYERS;
        float  S      = SKULL_S * sc * (2.8 - 0.5 * L);
        float2 q      = c - floor(dir * SKULL_SPEED * sc * (0.6 + 0.4 * L) * ts) + float2(L * 37.0, L * 91.0);
        float2 tile   = floor(q / S);
        float2 tid    = tile + L * 17.0;
        if (hash2(tid) > SKULL_DENSITY) continue;
        float2 off    = floor(float2(hash2(tid + 3.1), hash2(tid + 7.7)) * (S - SKULL_S * sc));
        float2 local  = q - tile * S - off;
        int2   org    = int2(min(SKULL_KINDS - 1, (int)(hash2(tid + 1.3) * SKULL_KINDS)) * SKULL_S, SKULL_Y);
        float3 tint   = lerp(float3(1, 1, 1), hue(hash2(tid + 5.0) + t * 0.07), 0.75) * (0.4 + 0.6 * near);
        float4 sp     = sprite(org, int2(SKULL_S, SKULL_S), local, sc, false);
        if (sp.a > 0.5) { col = sp.rgb * tint; continue; }
        for (int k = 1; k <= 2; k++)                      // the smear left behind
        {
            float4 tr = sprite(org, int2(SKULL_S, SKULL_S), local + floor(dir * k * SKULL_TRAIL * sc), sc, false);
            if (tr.a > 0.5) { col = lerp(col, tint.zxy * 0.6, 0.6 / k); break; }
        }
    }
    return col;
}

float3 brightWorld(float2 c, float2 grid, float t)
{
    float d  = dither(c);
    float hy = floor(grid.y * BRIGHT_HORIZON);
    if (c.y < hy)
    {
        float v = c.y / hy;
        float b = floor(v * 10.0 + d) / 10.0;
        float3 col = b < 0.5 ? lerp(BRIGHT_SKY_TOP, BRIGHT_SKY_MID, b * 2.0) : lerp(BRIGHT_SKY_MID, BRIGHT_SKY_LOW, b * 2.0 - 1.0);
        if (hash2(c) > 0.996 && v < 0.5 && frac(t * 1.3 + hash2(c * 1.7)) < 0.6) col = float3(1, 1, 1);
        // the sun, cut by stripes that slide down
        float2 sc = float2(grid.x * 0.5, hy - grid.y * 0.12);
        float  r  = grid.y * 0.26;
        float2 dd = c - sc;
        if (dot(dd, dd) < r * r)
        {
            float sv = (c.y - (sc.y - r)) / (2.0 * r);
            bool cut = sv > 0.5 && frac(sv * 9.0 - t * 0.6) < (sv - 0.5) * 0.9;
            if (!cut) col = lerp(BRIGHT_SUN_TOP, BRIGHT_SUN_LOW, floor(sv * 7.0 + d) / 7.0);
        }
        // two rows of jagged hills in front of the sun
        float far  = hy - grid.y * (0.07 + 0.05 * abs(sin(c.x * 0.013)) + 0.02 * abs(sin(c.x * 0.051 + 1.0)));
        float near = hy - grid.y * (0.03 + 0.04 * abs(sin(c.x * 0.021 + 2.0)));
        if (c.y > far)  col = lerp(BRIGHT_HILLS, col, 0.35);
        if (c.y > near) col = BRIGHT_HILLS * 0.8;
        // pyramids standing on the floor far off, lit on one side, with glowing edges
        for (int k = 0; k < BRIGHT_PYRAMIDS; k++)
        {
            float px = grid.x * (0.12 + 0.76 * hash(k * 3.7 + 0.2));
            float w  = grid.y * (0.05 + 0.05 * hash(k * 5.1 + 0.4));
            float dx = c.x - px;
            float top = hy - w * 0.9 * (1.0 - abs(dx) / w);
            if (abs(dx) < w && c.y > top)
            {
                col = dx < 0.0 ? BRIGHT_PYRAMID : BRIGHT_PYRAMID * 0.55;
                if (c.y - top < 1.0 || abs(dx) < 0.6) col = BRIGHT_LINES;
            }
        }
        // a bright haze sitting on the horizon
        col = lerp(col, BRIGHT_HAZE, 0.6 * saturate(1.0 - (hy - c.y) / (grid.y * 0.03)));
        return col;
    }
    // the floor: a glowing grid rushing towards you, a finer grid between, light running along the
    // lines, a few lit tiles, the sun's reflection shimmering down the middle and haze far off
    float dyf = max(c.y - hy, 0.5);
    float z   = (grid.y - hy) / dyf;
    float v2  = saturate(dyf / (grid.y - hy));          // 0 at the horizon, 1 at the bottom
    float px  = z / grid.y * 2.0;                       // floor units per cell, sideways
    float pz  = z * z / (grid.y - hy);                  // floor units per cell, in depth
    float wx  = (c.x - grid.x * 0.5) * px;
    float wz  = z + t * BRIGHT_SPEED;
    float fog = saturate(z / BRIGHT_FOG);
    float3 col = BRIGHT_FLOOR * (1.15 - 0.45 * fog);
    float2 tile = floor(float2(wx, wz));
    if (wrap(tile.x + tile.y, 2.0) > 0.5) col *= 0.86;
    if (hash2(tile) > 0.965) col = lerp(col, BRIGHT_LINES * 0.6, 0.5 * (1.0 - fog) * (0.6 + 0.4 * sin(t * 4.0 + tile.x)));
    if (hash2(c + floor(t * 6.0)) > 0.995) col += 0.12;                                   // glints in the glass
    // the sun's reflection
    float halfW = grid.y * 0.26 * (0.95 - 0.55 * v2);
    if (abs(c.x - grid.x * 0.5) < halfW && sin(wz * 5.0 + sin(c.x * 0.12 + t * 3.0) * 1.5) > 0.1 - 0.5 * (1.0 - v2))
        col = lerp(col, lerp(BRIGHT_SUN_LOW, BRIGHT_SUN_TOP, 1.0 - v2), 0.55 * (1.0 - 0.6 * v2));
    // the finer grid
    float2 fd = abs(frac(float2(wx, wz) * 4.0 + 0.5) - 0.5) * 0.25;
    if (fd.x < px * 0.5 || fd.y < pz * 0.5) col = lerp(col, BRIGHT_LINES * 0.6, 0.4 * (1.0 - fog));
    // the main lines, sharp, with a soft glow either side
    float2 md = abs(frac(float2(wx, wz) + 0.5) - 0.5);
    float  lx = md.x / px, lz = md.y / pz;
    float  ln = min(lx, lz);
    if (ln < 1.0) col = BRIGHT_LINES;
    else if (ln < 3.0) col = lerp(col, BRIGHT_LINES, 0.3 * (1.0 - fog));
    if (lx < 1.0 && frac(wz * 0.25 - t * 0.9 + hash(floor(wx + 0.5))) < 0.05) col = float3(1, 1, 1);   // pulses
    return lerp(col, BRIGHT_HAZE, pow(fog, 1.5) * 0.85);
}

float3 crumbleScene(float2 c, float2 grid, float tc)
{
    float  F   = CRUMBLE_BIT * gBase;
    float  B   = F * CRUMBLE_BITS;
    float  tSk = tc + SKULL_SEC;                 // the skulls keep flying while it breaks up
    float2 fr  = floor(c / F);
    // first find what this cell shows: a bit still in place, a bit falling past, or the world below.
    // The pictures are drawn once, after the search, which keeps the shader quick to load.
    float  dy = 0.0, mul = 1.0, add = 0.0, crack = 0.0;
    bool   skull = false;
    [loop] for (int k = 0; k < CRUMBLE_REACH; k++)
    {
        float2 bit   = float2(fr.x, fr.y - k);
        float2 box   = floor(bit / CRUMBLE_BITS);
        float2 mid   = (box + 0.5) * B;
        float  start = CRUMBLE_SPREAD * (0.6 * saturate(length((mid - grid * 0.5) / grid.y)) + 0.4 * hash2(box + 0.5));
        float  fall  = tc - start - hash2(bit * 1.7) * CRUMBLE_LOOSEN;
        if (fall <= 0.0)
        {
            if (k > 0) continue;
            skull = true;
            float warn = tc - (start - CRACK_SEC);
            if (warn > 0.0)
            {
                float2 inBox = c - box * B;
                float2 inBit = c - bit * F;
                bool   edge  = any(inBox < 1.0) || any(inBox >= B - 1.0);
                float  fl    = hash2(float2(floor(tc * 20.0), box.x + box.y * 57.0));
                if (edge && fl > 0.3) crack = 1.0;
                else if (any(inBit < 1.0) && hash2(bit + floor(tc * 15.0)) < warn / CRACK_SEC) crack = 0.6;
            }
            break;
        }
        float  d    = floor(0.5 * CRUMBLE_GRAVITY * gBase * fall * fall);
        float  side = F * saturate(1.0 - fall / CRUMBLE_LIFE);
        float2 rel  = c + 0.5 - ((bit + 0.5) * F + float2(0.0, d));
        if (all(abs(rel) < side * 0.5))
        {
            skull = true; dy = d; mul = lerp(1.1, 0.4, saturate(fall / CRUMBLE_LIFE)); add = 0.08;
            break;
        }
    }
    if (!skull) return brightWorld(c, grid, tc);
    return lerp(skullScene(c - float2(0.0, dy), grid, tSk) * mul + CRACK_COLOUR * add, CRACK_COLOUR, crack);
}

// how much current is flowing at a moment: a hum, sudden brown-outs and surges
float voltage(float t)
{
    float v = 0.82 + POLKA_HUM * (sin(t * TAU * 7.3) + 0.6 * sin(t * TAU * 13.1 + 1.0) + 0.4 * sin(t * TAU * 49.0));
    float slot = floor(t / 1.6);
    float h = hash(slot * 3.7 + 0.5);
    float x = frac(t / 1.6);
    if (h > 0.68)                                                    // brown-out, sputtering
        v *= lerp(1.0, 0.2 + 0.35 * hash(floor(t * 22.0)), bell(saturate(x * 1.6)));
    else if (h < 0.14)                                               // surge
        v *= 1.0 + 0.45 * bell(saturate(x * 2.5));
    return v;
}

float3 polkaScene(float2 c, float2 grid, float t)
{
    float S  = POLKA_SPACING * gBase;
    float rh = S * 0.866;
    float3 col = POLKA_BG * (0.6 + 0.5 * voltage(t - c.x / grid.x * POLKA_FLOW));
    float best = 1e9, bv = 0.0, bid = 0.0;
    float2 bc = 0;
    float row = floor(c.y / rh);
    [loop] for (int i = -1; i <= 1; i++)                   // the nearest dot in this row and the two beside it
    {
        float r   = row + i;
        float off = wrap(r, 2.0) * S * 0.5;
        float k   = floor((c.x - off) / S);
        float2 m  = float2(k * S + off + S * 0.5, r * rh + rh * 0.5);
        float dd  = length(c + 0.5 - m);
        if (dd < best) { best = dd; bc = m; bid = k * 131.0 + r; }
    }
    float v = voltage(t - (bc.x + bc.y * 0.4) / grid.x * POLKA_FLOW);
    v *= 0.8 + 0.3 * sin(length(bc - grid * 0.5) * POLKA_SURGE_W / gBase - t * POLKA_SURGE_V) + 0.1 * (hash(bid + 7.0) - 0.5);
    if (hash(bid) < POLKA_FAULTY) v *= step(0.35, hash(floor(t * (6.0 + 10.0 * hash(bid + 1.0))) + bid));
    float R = S * POLKA_RADIUS * (0.85 + 0.25 * v);
    if (best < R)
    {
        float core = floor((1.0 - best / R) * 3.0 + dither(c)) / 3.0;
        col = POLKA_DOT * v * (0.75 + 0.35 * core);
    }
    else if (best < R + 2.0 * gBase && v > 1.0)                      // overloaded dots spit sparks
    {
        if (hash2(c + floor(t * 24.0)) < (v - 1.0) * 0.9) col = POLKA_SPARK * v;
    }
    else if (best < R * 1.5) col += POLKA_DOT * 0.08 * v * v;        // a soft glow round each dot
    // the dark hum bar rolling up the screen
    float by = wrap(c.y / grid.y + t * POLKA_ROLL, 1.0);
    col *= 1.0 - 0.3 * bell(saturate((by - 0.4) / 0.2));
    return col;
}
