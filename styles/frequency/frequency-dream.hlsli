// Frequency, part 5: the second station, first half. An idyllic American suburb seen from a
// distance, with cube-shaped pockets of black hole opening over it until one swallows the view; a
// digital bottle tipping over and pouring out numbers and letters that grow into earth, rock,
// water and fire; then a tunnel built of those elements, collapsing in on itself as time warps,
// with a hypnotic colour-changing swirl spreading out of its middle.
// Included by frequency.hlsl, which holds the shared helpers.

// --- the suburb ---
static const float  SUB_HORIZON    = 0.42;   // share of the height down to the horizon
static const int    SUB_ROWS       = 6;      // rows of houses from far to near
static const float  SUB_HOUSE_W    = 44.0;   // space for one house, cells at the smallest size
static const float3 SUB_SKY_TOP    = float3(0.35, 0.60, 0.95);
static const float3 SUB_SKY_LOW    = float3(0.82, 0.92, 1.00);
static const float3 SUB_HILL       = float3(0.42, 0.62, 0.55);
static const float3 SUB_GRASS_A    = float3(0.36, 0.72, 0.30);
static const float3 SUB_GRASS_B    = float3(0.30, 0.63, 0.25);
static const float3 SUB_ROAD       = float3(0.36, 0.36, 0.40);
static const float3 SUB_TREE       = float3(0.18, 0.48, 0.20);
static const float3 SUB_WALLS[5]   = { float3(0.95, 0.88, 0.70), float3(0.70, 0.88, 0.95), float3(0.98, 0.78, 0.80),
                                       float3(0.78, 0.92, 0.75), float3(1.00, 0.96, 0.62) };
static const float3 SUB_ROOFS[3]   = { float3(0.55, 0.18, 0.15), float3(0.30, 0.30, 0.35), float3(0.25, 0.30, 0.50) };
static const int    SUB_HOLES      = 7;      // black-hole cubes, one after another
static const float  SUB_HOLE_FIRST = 1.5;    // seconds before the first one opens
static const float  SUB_HOLE_EVERY = 1.3;    // seconds between them
static const float  SUB_HOLE_SIZE  = 13.0;   // typical cube size, cells (x the sprite size)
static const float  SUB_SWALLOW    = 2.5;    // the last cube grows to swallow everything in this many seconds
static const float  SUB_LENS       = 0.9;    // how strongly the town bends round each cube
static const float3 SUB_HOLE_EDGE  = float3(0.75, 0.45, 1.00);
static const float3 SUB_HOLE_GLOW  = float3(1.00, 0.55, 0.25);

// --- the bottle ---
static const float  BOTTLE_TIP_SEC = 1.8;    // time it takes to tip over
static const float  BOTTLE_TILT    = 2.1;    // radians it ends up tipped
static const float  BOTTLE_SIZE    = 2.0;    // the bottle's size, in sprite sizes
static const float  BOTTLE_SPOUT   = 0.035;  // seconds between letters pouring out
static const int    BOTTLE_STREAM  = 48;     // letters in the air at once
static const float  BOTTLE_SPEED   = 45.0;   // how fast they leave the neck, cells per second
static const float  BOTTLE_GRAVITY = 150.0;
static const float  BOTTLE_GROW    = 2.2;    // how fast a letter grows, sprite sizes per second
static const float  BOTTLE_MATTER  = 0.45;   // seconds after leaving before a letter becomes matter
static const float3 BOTTLE_GLASS   = float3(0.40, 1.00, 0.80);
static const float3 BOTTLE_DIGITS  = float3(0.30, 1.00, 0.45);
static const float3 ELEMENTS[6]    = { float3(0.48, 0.47, 0.50), float3(0.45, 0.28, 0.14), float3(0.26, 0.62, 0.20),
                                       float3(0.20, 0.45, 0.90), float3(1.00, 0.42, 0.08), float3(0.88, 0.76, 0.45) };

// --- the tunnel and the swirl ---
static const float  WARP_TILES     = 22.0;   // element tiles round the tunnel
static const float  WARP_DEPTH     = 3.0;    // tiles per unit of depth
static const float  WARP_SPEED     = 1.3;    // flying in
static const float  WARP_TWIST     = 2.2;    // how hard the tunnel twists once time is fully warped
static const float  WARP_SWIRL_AT  = 3.0;    // seconds in, the swirl starts spreading from the middle
static const float  SWIRL_ARMS     = 5.0;
static const float  SWIRL_TIGHT    = 2.6;
static const float  SWIRL_SPIN     = 1.8;

float glyphPixel(float idx, float2 local)
{
    int2 p = int2(floor(local));
    if (!gSprites || p.x < 0 || p.y < 0 || p.x >= GLYPH_W || p.y >= GLYPH_H) return 0.0;
    int i = (int)wrap(floor(idx), (float)GLYPH_COUNT);
    return image.Load(int3(i * GLYPH_W + p.x, GLYPH_Y + p.y, 0)).a;
}

// one of six earth elements, with a pixel texture: rock, soil, grass, water, lava, sand
float3 element(float id, float2 p, float t)
{
    int e = min(5, (int)(hash(id) * 6.0));
    float n = hash2(floor(p) + id);
    float3 col = ELEMENTS[e] * (0.72 + 0.45 * n);
    if (e == 3 && frac(p.y * 0.25 + sin(p.x * 0.3 + t * 3.0) * 0.3) < 0.15) col += 0.25;   // water ripples
    if (e == 4 && n > 0.8) col = float3(1.0, 0.9, 0.4);                                     // glowing lava
    return col;
}

float2 rot2(float2 p, float a) { float c = cos(a), s = sin(a); return float2(p.x * c - p.y * s, p.x * s + p.y * c); }

float3 suburbTown(float2 c, float2 grid, float t)
{
    float hy = floor(grid.y * SUB_HORIZON);
    float d  = dither(c);
    if (c.y < hy)
    {
        float v = c.y / hy;
        float3 col = lerp(SUB_SKY_TOP, SUB_SKY_LOW, floor(v * 8.0 + d) / 8.0);
        // puffy clouds drifting
        float W = 110.0 * gBase, wx = c.x + t * 2.0 * gBase, k = floor(wx / W);
        float2 m = float2(k * W + W * (0.2 + 0.6 * hash(k)), hy * (0.18 + 0.35 * hash(k + 3.0)));
        float2 q = float2(wx, c.y) - m;
        float r = 8.0 * gBase;
        float cd = min(length(q) - r, min(length(q + float2(r, -r * 0.35)) - r * 0.7, length(q - float2(r * 1.1, -r * 0.3)) - r * 0.65));
        if (cd < 0.0) col = q.y > r * 0.25 ? float3(0.86, 0.90, 0.96) : float3(1, 1, 1);
        // hills, and a water tower on one of them
        float hill = hy - grid.y * (0.035 + 0.025 * sin(c.x * 0.017) + 0.015 * sin(c.x * 0.043 + 2.0));
        if (c.y > hill) col = SUB_HILL;
        float2 tw = c - float2(grid.x * 0.78, hy - grid.y * 0.13);
        if (length(tw / float2(9.0, 5.0) / gBase) < 1.0) col = float3(0.80, 0.86, 0.90);
        if (tw.y > 4.0 * gBase && tw.y < grid.y * 0.1 && (abs(abs(tw.x) - 6.0 * gBase) < 0.6 + tw.y * 0.05)) col = float3(0.55, 0.58, 0.62);
        return col;
    }
    // lawns with mowing stripes, then rows of houses from far to near
    float v = (c.y - hy) / (grid.y - hy);
    float3 col = wrap(floor((c.x - grid.x * 0.5) / ((1.0 + v * 10.0) * 4.0)), 2.0) < 1.0 ? SUB_GRASS_A : SUB_GRASS_B;
    [loop] for (int r = 0; r < SUB_ROWS; r++)
    {
        float rv   = pow((r + 1.0) / SUB_ROWS, 1.5);
        float base = hy + floor((grid.y - hy) * rv * 0.92);
        float s    = max(1.0, round(gBase * (0.5 + 2.2 * rv)));
        if (c.y < base - 30.0 * s || c.y > base + 9.0 * s) continue;
        if ((r & 1) == 1 && c.y > base + 3.0 * s && c.y < base + 8.0 * s)       // a road in front of every other row
        {
            col = SUB_ROAD;
            if (abs(c.y - (base + 5.5 * s)) < 0.5 * s + 0.5 && wrap(c.x, 10.0 * s) < 5.0 * s) col = float3(0.95, 0.85, 0.30);
        }
        if (c.y > base + 1.0 * s && c.y < base + 3.0 * s && (wrap(c.x, 3.0 * s) < s || abs(c.y - base - 2.0 * s) < 0.5)) col = float3(0.97, 0.97, 0.95);  // picket fence
        float tw = SUB_HOUSE_W * s;
        float wx = c.x + r * 37.0 * s;
        float k  = floor(wx / tw);
        float id = k + r * 17.0;
        float lx = wx - k * tw - 7.0 * s;
        float ly = base - c.y;                                                 // height above the lawn
        if (hash(id) < 0.18)                                                   // a tree instead of a house
        {
            if (abs(lx - 15.0 * s) < 1.5 * s && ly > 0.0 && ly < 12.0 * s) col = float3(0.40, 0.26, 0.15);
            float2 q = float2(lx - 15.0 * s, ly - 18.0 * s);
            if (length(q) < 9.0 * s) col = SUB_TREE * (hash2(floor(c / 2.0)) > 0.7 ? 0.8 : 1.0);
            continue;
        }
        float3 wall = SUB_WALLS[min(4, (int)(hash(id + 1.0) * 5.0))];
        float3 roof = SUB_ROOFS[min(2, (int)(hash(id + 2.0) * 3.0))];
        if (lx >= 0.0 && lx < 30.0 * s && ly > 0.0 && ly < 14.0 * s)
        {
            col = wall;
            if (abs(lx - 15.0 * s) < 2.0 * s && ly < 8.0 * s) col = float3(0.45, 0.25, 0.15);           // door
            float2 wq = float2(wrap(lx, 15.0 * s) - 5.0 * s, ly - 6.0 * s);
            if (abs(lx - 15.0 * s) > 4.0 * s && wq.x >= 0.0 && wq.x < 5.0 * s && wq.y >= 0.0 && wq.y < 5.0 * s)
            {
                col = hash(id + floor(lx / (15.0 * s)) + 9.0) > 0.6 ? float3(1.0, 0.88, 0.45) : float3(0.62, 0.82, 0.95);
                if (abs(wq.x - 2.5 * s) < 0.5 || abs(wq.y - 2.5 * s) < 0.5) col = float3(1, 1, 1);
            }
            if (ly > 13.0 * s) col = float3(1, 1, 1);                                               // trim
        }
        float rh = ly - 14.0 * s;
        if (rh >= 0.0 && rh < 10.0 * s && abs(lx - 15.0 * s) < 17.0 * s * (1.0 - rh / (10.0 * s))) col = roof * (lx < 15.0 * s ? 1.0 : 0.8);
        if (lx > 22.0 * s && lx < 25.0 * s && rh > 2.0 * s && rh < 11.0 * s) col = roof * 0.7;           // chimney
    }
    return col;
}

float3 suburbScene(float2 c, float2 grid, float t)
{
    // where each black-hole cube is, and how big
    float2 m[SUB_HOLES];
    float  R[SUB_HOLES];
    float2 p = c;
    [loop] for (int k = 0; k < SUB_HOLES; k++)
    {
        float appear = SUB_HOLE_FIRST + k * SUB_HOLE_EVERY;
        bool  last   = k == SUB_HOLES - 1;
        m[k] = last ? grid * 0.5 : float2(grid.x * (0.12 + 0.76 * hash(k * 7.1 + 0.3)), grid.y * (0.12 + 0.62 * hash(k * 3.3 + 0.9)));
        R[k] = SUB_HOLE_SIZE * gBase * (0.6 + 0.8 * hash(k * 1.9)) * saturate((t - appear) / 0.8) * (1.0 + 0.06 * sin(t * 7.0 + k));
        if (last) R[k] *= exp(max(0.0, t - (SUBURB_SEC - SUB_SWALLOW)) * 2.4);
        // the town bends and twists round it
        float2 dd = c - m[k];
        float  r  = length(dd);
        if (R[k] > 0.0 && r < R[k] * 4.0 && r > 0.5)
        {
            float pull = SUB_LENS * R[k] * R[k] / max(r, R[k]);
            p -= rot2(dd / r, 0.6 * R[k] / max(r, R[k])) * pull;
        }
    }
    float3 col = suburbTown(p, grid, t);
    [loop] for (int j = 0; j < SUB_HOLES; j++)
    {
        if (R[j] <= 0.0) continue;
        float2 dd = c - m[j];
        float  r  = length(dd);
        if (r > R[j] * 1.1 && r < R[j] * 1.45 && hash2(c + floor(t * 12.0)) < 0.5)   // a thin hot ring of light round it
            col = lerp(col, SUB_HOLE_GLOW, 0.6);
        float2 q = rot2(dd, t * 0.5 + j) / R[j];
        float  ax = abs(q.x);
        if (ax > 0.866 || abs(q.y) + ax * 0.577 > 1.0) continue;
        // inside the cube: pitch black, three faces meeting in the middle, edges flickering
        col = float3(0, 0, 0);
        float px = 1.0 / R[j];
        float edge = 1.0 - max(ax / 0.866, abs(q.y) + ax * 0.577);
        bool seam = (q.y < 0.0 && ax < px) || (q.y > 0.0 && abs(q.y - ax * 0.577) < px);
        float fl = 0.5 + 0.5 * hash(floor(t * 15.0) + j);
        if (edge < px * 1.2 || seam) col = SUB_HOLE_EDGE * fl;
    }
    return col;
}

float3 bottleScene(float2 c, float2 grid, float t)
{
    float s = gBase;
    // the void, with faint digits drifting down it
    float3 col = float3(0.01, 0.02, 0.04);
    float2 gc = floor(float2(c.x, c.y - t * 12.0 * s) / (float2(GLYPH_W, GLYPH_H) * s));
    if (hash2(gc) > 0.93)
    {
        float2 gl = (float2(c.x, c.y - t * 12.0 * s) - gc * float2(GLYPH_W, GLYPH_H) * s) / s;
        col += BOTTLE_DIGITS * 0.12 * glyphPixel(hash2(gc + 1.0) * GLYPH_COUNT, gl);
    }

    float  tilt  = smoothstep(0.0, BOTTLE_TIP_SEC, t) * BOTTLE_TILT;
    float2 pivot = float2(grid.x * 0.28, grid.y * 0.36);
    float  bs    = s * BOTTLE_SIZE;
    float2 tip   = pivot + rot2(float2(0.0, -32.0 * bs), tilt);
    float2 spout = rot2(float2(0.0, -1.0), tilt);

    // the heap of matter at the bottom, growing until it fills the window
    float land = tip.x + grid.y * 0.25;
    float rise = pow(saturate((t - BOTTLE_TIP_SEC) / (BOTTLE_SEC - BOTTLE_TIP_SEC)), 1.6);
    float B    = 6.0 * s;
    float bx   = floor(c.x / B);
    float top  = grid.y - grid.y * 1.15 * rise * (0.55 + 0.45 * exp(-pow((c.x - land) / (grid.x * 0.35), 2.0))) - hash(bx) * 3.0 * s;
    if (c.y > top) col = element(hash2(float2(bx, floor(c.y / B))) * 61.0, c / s, t) * (wrap(c.x, B) < 1.0 || wrap(c.y, B) < 1.0 ? 0.7 : 1.0);

    // the stream: letters leave the neck green and digital, then grow and turn into matter
    if (t > BOTTLE_TIP_SEC * 0.6)
    {
        float newest = floor(t / BOTTLE_SPOUT);
        [loop] for (int i = 0; i < BOTTLE_STREAM; i++)
        {
            float n   = newest - i;
            float age = t - n * BOTTLE_SPOUT;
            if (n * BOTTLE_SPOUT < BOTTLE_TIP_SEC * 0.6) break;
            float2 v0  = spout * BOTTLE_SPEED * s * (0.8 + 0.4 * hash(n)) + float2((hash(n + 3.0) - 0.5) * 10.0, 0.0) * s;
            float2 pos = tip + v0 * age + float2(0.0, 0.5 * BOTTLE_GRAVITY * s * age * age);
            float  g   = s * (1.0 + floor(age * BOTTLE_GROW));
            float2 box = float2(GLYPH_W, GLYPH_H) * g;
            float2 l   = c - (pos - box * 0.5);
            if (any(l < 0.0) || any(l >= box) || pos.y > top + box.y) continue;
            if (age < BOTTLE_MATTER)
            {
                if (glyphPixel(hash(n * 1.7) * GLYPH_COUNT, l / g) > 0.5) { col = lerp(BOTTLE_DIGITS, float3(1, 1, 1), hash(n + 9.0) * 0.5); break; }
            }
            else
            {
                col = element(hash(n * 2.3) * 61.0, l / s, t);
                if (any(l < s) || any(l >= box - s)) col *= 0.6;
                break;
            }
        }
    }

    // the bottle itself: glass outline, full of scrolling digits
    float2 q = rot2(c - pivot, -tilt) / bs;
    float halfW = q.y > -10.0 ? 12.0 : (q.y > -18.0 ? lerp(4.0, 12.0, (q.y + 18.0) / 8.0) : (q.y > -30.0 ? 4.0 : 5.0));
    if (q.y > -32.0 && q.y < 26.0 && abs(q.x) < halfW)
    {
        bool rim = abs(q.x) > halfW - 1.0 || q.y > 25.0 || q.y < -31.0;
        float2 gq = float2(q.x + 12.0, q.y + 32.0 - t * 20.0);
        float2 gi = floor(gq / float2(GLYPH_W, GLYPH_H));
        float lit = glyphPixel(hash2(gi + floor(t * 3.0)) * GLYPH_COUNT, gq - gi * float2(GLYPH_W, GLYPH_H));
        col = rim ? BOTTLE_GLASS : lerp(float3(0.02, 0.10, 0.08), BOTTLE_DIGITS, lit * 0.8);
        if (!rim && q.x < -halfW + 3.0 && q.y > -8.0 && q.y < 20.0) col += 0.15;              // a shine on the glass
    }
    return col;
}

float3 warpScene(float2 c, float2 grid, float t)
{
    float  collapse = saturate(t / TUNNEL_SEC);
    float2 mid = grid * 0.5 + float2(sin(t * 0.7), cos(t * 0.53)) * grid.y * 0.05 * (1.0 + collapse);
    float2 d   = (c + 0.5 - mid) / grid.y;
    float  r   = length(d) + 1e-3;
    float  a   = atan2(d.y, d.x) / TAU;
    float3 col;

    // the swirl: spreads out of the middle with a ragged spiral edge, and finally fills the window
    float reach = max(0.0, t - WARP_SWIRL_AT) / max(TUNNEL_SEC + 1.5 - WARP_SWIRL_AT, 0.1) * 1.3;
    float edge  = reach * reach + 0.04 * sin(a * TAU * 5.0 + log(r) * 8.0 - t * 4.0);
    if (r < edge)
    {
        float sw = frac(a * SWIRL_ARMS + log(r) * SWIRL_TIGHT - t * SWIRL_SPIN);
        float hu = frac(t * 0.15 + log(r) * 0.25 + floor(sw * 2.0) * 0.5);
        col = floor(sw * 6.0 + dither(c)) / 6.0 < 0.5 ? hue(hu) : hue(frac(hu + 0.33)) * 0.25;
        if (r < 0.015) col = float3(1, 1, 1);
        return col;
    }

    // the tunnel of elements, closing in and twisting harder as it goes
    float z  = 0.22 / r * (1.0 + collapse * 1.6);
    float u  = a + collapse * collapse * WARP_TWIST * z * 0.15 + t * 0.04;
    float v  = z + t * WARP_SPEED * (1.0 + collapse * 2.0);
    float2 tile = floor(float2(u * WARP_TILES, v * WARP_DEPTH));
    // tiles crumble and fall in, showing a second tunnel behind, twisted the other way
    float layer = 0.0;
    float fallAt = hash2(tile * 1.3) * TUNNEL_SEC * 1.3;
    if (t > fallAt)
    {
        layer = 1.0;
        u = a - collapse * WARP_TWIST * z * 0.1 + 0.5 / WARP_TILES;
        v += (t - fallAt) * (t - fallAt) * 0.8;
        tile = floor(float2(u * WARP_TILES, v * WARP_DEPTH));
    }
    float2 f = frac(float2(u * WARP_TILES, v * WARP_DEPTH));
    col = element(hash2(tile + layer * 7.0) * 61.0, f * 8.0 + tile * 8.0, t) * (layer > 0.0 ? 0.6 : 1.0);
    if (f.x < 0.06 || f.y < 0.08) col *= 0.45;                                   // the cracks between tiles
    if (frac(v * 0.5 - t * 0.3) < 0.025) col = float3(0.7, 0.95, 1.0);            // rings of warped time
    return col * saturate(1.3 - z * 0.09);
}
