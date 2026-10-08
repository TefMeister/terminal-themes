// Frequency, part 5: the second station, first half. An idyllic American suburb seen from a
// distance, a black hole growing in the middle of it and swallowing it, debris flying in, the town
// glitching twice into bleaker, more broken versions of itself, until the camera dives in; a
// digital bottle tipping over and pouring out numbers and letters that grow into earth, rock,
// water and fire; then a tunnel built of those elements, collapsing in on itself as time warps,
// with a hypnotic colour-changing swirl spreading out of its middle.
// Included by frequency.hlsl, which holds the shared helpers.

// --- the suburb: three towns in turn, each swallowed by a black hole, more broken each time ---
static const float  SUB_PHASE_SEC  = 6.0;    // each town lasts this long (three of them fill SUBURB_SEC)
static const float  SUB_HORIZON    = 0.42;   // share of the height down to the horizon
static const int    SUB_ROWS       = 6;      // rows of houses from far to near
static const float  SUB_HOUSE_W    = 48.0;   // space for one house, cells at the smallest size
static const float3 SUB_SKY_TOP[3] = { float3(0.35, 0.60, 0.95), float3(0.95, 0.50, 0.35), float3(0.30, 0.30, 0.40) };
static const float3 SUB_SKY_LOW[3] = { float3(0.82, 0.92, 1.00), float3(1.00, 0.85, 0.55), float3(0.58, 0.58, 0.64) };
static const float3 SUB_LIGHT[3]   = { float3(1.00, 1.00, 1.00), float3(1.10, 0.88, 0.70), float3(0.62, 0.64, 0.72) };  // how each town is lit
static const float3 SUB_HILL       = float3(0.42, 0.62, 0.55);
static const float3 SUB_GRASS_A    = float3(0.36, 0.72, 0.30);
static const float3 SUB_GRASS_B    = float3(0.30, 0.63, 0.25);
static const float3 SUB_ROAD       = float3(0.36, 0.36, 0.40);
static const float3 SUB_TREE       = float3(0.18, 0.48, 0.20);
static const float3 SUB_PINE       = float3(0.10, 0.36, 0.22);
static const float3 SUB_WALLS[8]   = { float3(0.95, 0.88, 0.70), float3(0.70, 0.88, 0.95), float3(0.98, 0.78, 0.80), float3(0.78, 0.92, 0.75),
                                       float3(1.00, 0.96, 0.62), float3(0.92, 0.92, 0.92), float3(0.80, 0.62, 0.48), float3(0.75, 0.78, 0.95) };
static const float3 SUB_ROOFS[5]   = { float3(0.55, 0.18, 0.15), float3(0.30, 0.30, 0.35), float3(0.25, 0.30, 0.50),
                                       float3(0.40, 0.28, 0.18), float3(0.22, 0.42, 0.30) };
static const float3 SUB_DOORS[4]   = { float3(0.70, 0.12, 0.12), float3(0.15, 0.25, 0.55), float3(0.45, 0.25, 0.15), float3(0.10, 0.10, 0.10) };
static const float2 SUB_HOLE_AT    = float2(0.5, 0.42);   // the black hole sits in the middle, on the horizon
static const float  SUB_BH_START   = 0.015;  // its size as it emerges, share of the window height...
static const float  SUB_BH_END     = 0.30;   // ...and by the time the camera dives in
static const float  SUB_DIVE       = 2.0;    // seconds the camera takes to dive into it
static const float  SUB_DIVE_ZOOM  = 3.2;    // how far the dive zooms in
static const int    SUB_DEBRIS     = 48;     // bits of the town flying into it
static const float  SUB_WARP       = 7.0;    // how far the picture warps by the end, cells
static const float  SUB_VIVID      = 1.6;    // how over-vibrant the colours are at first
static const float3 SUB_BLEAK      = float3(0.95, 0.80, 0.50);   // the bleak brown-yellow they drain to
static const float  SUB_LENS       = 1.2;    // how strongly the town bends round the hole
static const float  SUB_SPIN       = 2.5;    // how hard the town swirls into it
static const float  SUB_DISK_FLAT  = 3.5;    // how flat the glowing disk round it looks
static const float3 SUB_DISK_HOT   = float3(1.00, 0.95, 0.80);
static const float3 SUB_DISK_COOL  = float3(1.00, 0.45, 0.10);
static const float  SUB_FRAG       = 0.35;   // share of the picture broken into displaced blocks by the third town
static const float  SUB_FRAG_BLOCK = 10.0;   // size of those blocks, cells

// --- the bottle ---
static const float  BOTTLE_TIP_SEC = 1.0;    // it starts pouring this many seconds in
static const float  BOTTLE_TILT_FROM = 0.25; // radians it leans to the right at first...
static const float  BOTTLE_TILT    = 1.35;   // ...and at the end
static const float  BOTTLE_BIG     = 0.95;   // its height at the start, share of the window
static const float  BOTTLE_SIZE    = 2.0;    // its size at the end, in sprite sizes
static const float2 BOTTLE_AT      = float2(0.18, 0.62);   // where it stands, share of the window
static const float  BOTTLE_THROW   = 0.75;   // how fast the letters leave the neck, window widths per second
static const float  BOTTLE_DROP    = 1.1;    // how fast they fall, window widths per second per second
static const float  BOTTLE_SPOUT   = 0.035;  // seconds between letters pouring out
static const int    BOTTLE_STREAM  = 48;     // letters in the air at once
static const float  BOTTLE_GROW    = 2.2;    // how fast a letter grows, sprite sizes per second
static const float  BOTTLE_MATTER  = 0.45;   // seconds after leaving before a letter becomes matter
static const float3 BOTTLE_GLASS   = float3(0.40, 1.00, 0.80);
static const float3 BOTTLE_DIGITS  = float3(0.30, 1.00, 0.45);
static const float3 ELEMENTS[6]    = { float3(0.48, 0.47, 0.50), float3(0.45, 0.28, 0.14), float3(0.26, 0.62, 0.20),
                                       float3(0.20, 0.45, 0.90), float3(1.00, 0.42, 0.08), float3(0.88, 0.76, 0.45) };

// --- the tunnel and the swirl ---
static const float  WARP_TILES     = 22.0;   // element tiles round the tunnel
static const float  WARP_DEPTH     = 3.0;    // tiles per unit of depth
static const float  WARP_SPEED     = 0.2;    // flying in, slowly
static const float  WARP_DRIFT     = 0.3;    // how quickly everything else in the tunnel moves (1 = the old pace)
static const float  WARP_TWIST     = 2.2;    // how hard the tunnel twists once time is fully warped
static const float  WARP_SWIRL_AT  = 3.0;    // seconds in, the swirl starts spreading from the middle
static const float  SWIRL_ARMS     = 5.0;
static const float  SWIRL_TIGHT    = 2.6;
static const float  SWIRL_SPIN     = 0.45;   // slow: a long, hypnotic descent
static const float  SWIRL_HUE      = 0.05;   // how quickly its colours change

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

// one house of one of six kinds: plain gable, two storeys, low ranch, hipped roof, with a garage,
// steep A-frame. lx runs from its left edge, ly is the height above the lawn, s the size step.
float4 houseAt(float lx, float ly, float s, float id)
{
    int    type = min(5, (int)(hash(id + 3.0) * 6.0));
    float  W     = (type == 2 ? 38.0 : (type == 5 ? 24.0 : 30.0)) * s;
    float  wallH = (type == 1 ? 22.0 : (type == 2 ? 10.0 : (type == 5 ? 6.0 : 14.0))) * s;
    float  roofH = (type == 2 ? 6.0 : (type == 5 ? 22.0 : (type == 3 ? 8.0 : 10.0))) * s;
    float3 wall  = SUB_WALLS[min(7, (int)(hash(id + 1.0) * 8.0))];
    float3 roof  = SUB_ROOFS[min(4, (int)(hash(id + 2.0) * 5.0))];
    float3 door  = SUB_DOORS[min(3, (int)(hash(id + 4.0) * 4.0))];
    float  cx    = W * 0.5;
    float4 r     = float4(0, 0, 0, 0);
    if (type == 4 && lx >= W && lx < W + 14.0 * s && ly > 0.0 && ly < 12.0 * s)          // the garage
    {
        r = float4(ly > 10.0 * s ? roof : wall, 1);
        if (lx > W + 2.0 * s && lx < W + 12.0 * s && ly < 8.0 * s) r.rgb = wrap(ly, 2.0 * s) < 0.6 * s ? float3(0.6, 0.6, 0.62) : float3(0.86, 0.86, 0.88);
    }
    if (lx >= 0.0 && lx < W && ly > 0.0 && ly < wallH)
    {
        r = float4(wall, 1);
        if (abs(lx - cx) < 2.0 * s && ly < 8.0 * s) r.rgb = door;
        float floors = type == 1 ? 2.0 : 1.0;
        float slotW  = 10.0 * s;
        float wx = wrap(lx, slotW) - (slotW - 5.0 * s) * 0.5;
        float level = floor(ly / (11.0 * s));
        float wy = ly - level * 11.0 * s - (type == 2 ? 3.0 : 4.0) * s;
        bool  doorSlot = abs(floor(lx / slotW) * slotW + slotW * 0.5 - cx) < slotW * 0.5 && level == 0.0;
        if (!doorSlot && level < floors && wx >= 0.0 && wx < 5.0 * s && wy >= 0.0 && wy < 5.0 * s)
        {
            r.rgb = hash(id + floor(lx / slotW) * 3.1 + level * 7.3) > 0.55 ? float3(1.0, 0.88, 0.45) : float3(0.62, 0.82, 0.95);
            if (abs(wx - 2.5 * s) < 0.5 || abs(wy - 2.5 * s) < 0.5) r.rgb = float3(1, 1, 1);
        }
        if (!doorSlot && level < floors && hash(id + 6.0) > 0.5 && (abs(wx + 0.7 * s) < 0.7 * s || abs(wx - 5.7 * s) < 0.7 * s) && wy >= 0.0 && wy < 5.0 * s)
            r.rgb = door * 0.8;                                                             // shutters
        if (ly > wallH - s) r.rgb = float3(1, 1, 1);                                        // trim
    }
    float rh = ly - wallH;
    float reach = cx + 2.0 * s;
    bool inRoof = type == 3 ? abs(lx - cx) < reach - rh * 1.4 : abs(lx - cx) < reach * (1.0 - rh / roofH);
    if (rh >= 0.0 && rh < roofH && inRoof) r = float4(roof * (lx < cx ? 1.0 : 0.8), 1);
    if (hash(id + 7.0) > 0.4 && lx > W * 0.72 && lx < W * 0.72 + 3.0 * s && rh > 2.0 * s && rh < roofH + 1.0 * s && type != 5)
        r = float4(roof * 0.7, 1);                                                          // chimney
    return r;
}

float3 suburbTown(float2 c, float2 grid, float t, int set)
{
    float hy = floor(grid.y * SUB_HORIZON);
    float d  = dither(c);
    float3 light = SUB_LIGHT[set];
    if (c.y < hy)
    {
        float v = c.y / hy;
        float3 col = lerp(SUB_SKY_TOP[set], SUB_SKY_LOW[set], floor(v * 8.0 + d) / 8.0);
        float W = 110.0 * gBase, wx = c.x + t * 2.0 * gBase + set * 300.0, k = floor(wx / W);
        float2 m = float2(k * W + W * (0.2 + 0.6 * hash(k)), hy * (0.18 + 0.35 * hash(k + 3.0)));
        float2 q = float2(wx, c.y) - m;
        float r = 8.0 * gBase;
        float cd = min(length(q) - r, min(length(q + float2(r, -r * 0.35)) - r * 0.7, length(q - float2(r * 1.1, -r * 0.3)) - r * 0.65));
        if (cd < 0.0) col = (q.y > r * 0.25 ? float3(0.86, 0.90, 0.96) : float3(1, 1, 1)) * light;
        float hill = hy - grid.y * (0.035 + 0.025 * sin(c.x * 0.017 + set) + 0.015 * sin(c.x * 0.043 + 2.0));
        if (c.y > hill) col = SUB_HILL * light;
        float2 tw = c - float2(grid.x * (0.78 - 0.5 * set * (set - 1) * 0.5), hy - grid.y * 0.13);
        if (length(tw / float2(9.0, 5.0) / gBase) < 1.0) col = float3(0.80, 0.86, 0.90) * light;
        if (tw.y > 4.0 * gBase && tw.y < grid.y * 0.1 && (abs(abs(tw.x) - 6.0 * gBase) < 0.6 + tw.y * 0.05)) col = float3(0.55, 0.58, 0.62) * light;
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
        if (c.y < base - 34.0 * s || c.y > base + 9.0 * s) continue;
        if ((r & 1) == 1 && c.y > base + 3.0 * s && c.y < base + 8.0 * s)       // a road in front of every other row
        {
            col = SUB_ROAD;
            if (abs(c.y - (base + 5.5 * s)) < 0.5 * s + 0.5 && wrap(c.x, 10.0 * s) < 5.0 * s) col = float3(0.95, 0.85, 0.30);
        }
        float tw = SUB_HOUSE_W * s;
        float wx = c.x + r * 37.0 * s + set * 211.0 * s;
        float k  = floor(wx / tw);
        float id = k + r * 17.0 + set * 101.0;
        float lx = wx - k * tw - 4.0 * s;
        float ly = base - c.y;                                                 // height above the lawn
        if (hash(id + 9.0) > 0.4 && c.y > base + 1.0 * s && c.y < base + 3.0 * s && (wrap(c.x, 3.0 * s) < s || abs(c.y - base - 2.0 * s) < 0.5))
            col = float3(0.97, 0.97, 0.95);                                    // picket fence in front of some
        float kind = hash(id);
        if (kind < 0.12)                                                       // a round tree instead of a house
        {
            if (abs(lx - 15.0 * s) < 1.5 * s && ly > 0.0 && ly < 12.0 * s) col = float3(0.40, 0.26, 0.15);
            if (length(float2(lx - 15.0 * s, ly - 18.0 * s)) < 9.0 * s) col = SUB_TREE * (hash2(floor(c / 2.0)) > 0.7 ? 0.8 : 1.0);
            continue;
        }
        if (kind < 0.2)                                                        // or two pines
        {
            float px = wrap(lx, 15.0 * s) - 7.5 * s;
            if (ly > 0.0 && ly < 26.0 * s && abs(px) < (26.0 * s - ly) * 0.25) col = SUB_PINE * (wrap(ly, 4.0 * s) < s ? 0.75 : 1.0);
            continue;
        }
        float4 h = houseAt(lx, ly, s, id);
        if (h.a > 0.0) col = h.rgb;
        if (ly > 0.0 && ly < 3.0 * s && wrap(lx + 3.0 * s, 9.0 * s) < 5.0 * s && hash(id + 11.0) > 0.4 && length(float2(wrap(lx + 3.0 * s, 9.0 * s) - 2.5 * s, ly) / float2(2.5, 3.0) / s) < 1.0)
            col = SUB_TREE * 0.85;                                             // bushes along the front
        if (lx > -3.0 * s && lx < -1.0 * s && ly > 0.0 && ly < 5.0 * s)        // a mailbox on a post
            col = ly > 3.0 * s ? float3(0.25, 0.35, 0.65) : float3(0.45, 0.32, 0.2);
    }
    return col * light;
}

float3 suburbScene(float2 c, float2 grid, float t)
{
    int    set  = min(2, (int)floor(t / SUB_PHASE_SEC));
    float2 m    = grid * SUB_HOLE_AT;
    float  life = SUBURB_SEC - SUB_DIVE;
    float  b    = saturate(t / life);                                  // how far gone: 0 bright and whole, 1 bleak and broken
    // the camera dives into the hole at the end
    float  dk   = saturate((t - life) / SUB_DIVE);
    float  zoom = exp(dk * dk * SUB_DIVE_ZOOM);
    float2 pz   = m + (c - m) / zoom;
    float  R    = grid.y * lerp(SUB_BH_START, SUB_BH_END, pow(b, 1.5)) * smoothstep(0.5, 2.0, t);

    // the picture warps, then breaks into blocks knocked out of place, more after every glitch
    float2 p = pz;
    p.x += sin(p.y * 0.08 + t * 2.0) * b * SUB_WARP * gBase;
    p.y += sin(p.x * 0.05 + t * 1.3) * b * SUB_WARP * 0.5 * gBase;
    float  frag = (set + 0.4 * saturate((t - set * SUB_PHASE_SEC) / SUB_PHASE_SEC)) / 2.4;   // whole until the first glitch
    float  B    = SUB_FRAG_BLOCK * gBase;
    float2 blk  = floor(pz / B);
    float  hb   = hash2(blk + set * 17.3 + floor(t * 3.0) * 0.07);
    if (set > 0 && hb < frag * SUB_FRAG) p += floor((float2(hash2(blk + 1.3 + set), hash2(blk + 2.9 + set)) - 0.5) * B * 3.0);
    bool missing = set > 0 && hb < frag * SUB_FRAG * 0.3;

    // the hole bends the town round it and drags it in, swirling
    float2 d = p - m;
    float  r = length(d) + 1e-3;
    if (R > 0.0)
    {
        float pr  = max(0.0, r - R * R * SUB_LENS / max(r, R * 0.5));
        float ang = SUB_SPIN * R * R / (r * r + R * R) + t * 0.4 * R / (r + R);
        p = m + rot2(d / r, ang) * pr;
    }
    float3 col = missing ? float3(1, 1, 1) * hash2(c + floor(t * 20.0)) * 0.2 : suburbTown(p, grid, t, set);

    // colours drain as it goes: far too vibrant at first, then bleak browns and yellows
    float  l     = luma(col);
    float3 vivid = saturate(l + (col - l) * SUB_VIVID) * 1.08;
    float3 bleak = l * SUB_BLEAK * (1.0 - 0.3 * b);
    col = lerp(vivid, bleak, smoothstep(0.0, 1.0, b));
    if (R <= 0.0) return col;

    // debris: bits of house, roof, lawn and window spiralling in
    [loop] for (int i = 0; i < SUB_DEBRIS; i++)
    {
        float id = i * 7.13 + 0.5;
        if (hash(id + 2.2) > 0.25 + 0.75 * b) continue;                  // more of it as the hole grows
        float per = 1.4 + 2.0 * hash(id);
        float ph  = frac(t / per + hash(id + 0.3));
        float r0  = grid.y * (0.3 + 0.5 * hash(id + 0.7));
        float rr  = R + (r0 - R) * (1.0 - ph) * (1.0 - ph);
        float a   = hash(id + 0.9) * TAU + ph * ph * 5.0;
        float2 pos = m + float2(cos(a), sin(a) * 0.55) * rr;
        float  sz  = (3.0 + 9.0 * hash(id + 1.1)) * gBase * (1.0 - 0.7 * ph);
        float2 dq  = rot2(pz - pos, ph * 6.0 + id);
        if (abs(dq.x) < sz * 0.5 && abs(dq.y) < sz * 0.5)
        {
            float pick = hash(id + 1.7);
            float3 bit = pick < 0.4 ? SUB_WALLS[min(7, (int)(hash(id + 3.3) * 8.0))] : (pick < 0.65 ? SUB_ROOFS[min(4, (int)(hash(id + 3.9) * 5.0))]
                       : (pick < 0.85 ? SUB_GRASS_A : float3(1.0, 0.88, 0.45)));
            col = lerp(bit * 1.1, luma(bit) * SUB_BLEAK, b) * (dq.y < 0.0 ? 1.0 : 0.75);
        }
    }

    // the glowing disk, the black hole and its bright rim, all seen through the dive
    float2 q  = rot2(pz - m, 0.35);
    q.y *= SUB_DISK_FLAT;
    float  rd = length(q) / R;
    float  sw = sin(atan2(q.y, q.x) * 6.0 - t * 6.0 + rd * 3.0);
    float3 disk = lerp(SUB_DISK_COOL, SUB_DISK_HOT, saturate(2.2 - rd)) * (0.75 + 0.25 * sw);
    bool   band = rd > 1.3 && rd < 2.8 && hash2(c + floor(t * 10.0)) < 1.2 - (rd - 1.3) * 0.6;
    if (band && q.y < 0.0) col = lerp(col, disk, 0.85);
    float rc = length(pz - m);
    if (rc < R) col = float3(0, 0, 0);
    else if (rc < R * 1.08 + 1.0 / zoom) col = lerp(SUB_DISK_HOT, col, 0.3);
    if (band && q.y >= 0.0) col = lerp(col, disk, 0.9);
    return col * (1.0 - smoothstep(0.85, 1.0, dk));                     // and everything goes black
}

// where the bottle is at a moment: it starts huge and shrinks, leaning further to the right
void bottlePose(float t, float2 grid, out float2 pivot, out float tilt, out float bs, out float2 tip, out float2 spout)
{
    float k = smoothstep(0.0, BOTTLE_SEC, t);
    bs    = lerp(grid.y * BOTTLE_BIG / 58.0, gBase * BOTTLE_SIZE, k);
    tilt  = lerp(BOTTLE_TILT_FROM, BOTTLE_TILT, smoothstep(0.0, BOTTLE_SEC * 0.6, t));
    pivot = grid * BOTTLE_AT;
    tip   = pivot + rot2(float2(0.0, -32.0 * bs), tilt);
    spout = rot2(float2(0.0, -1.0), tilt);
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

    float2 pivot, tip, spout; float tilt, bs;
    bottlePose(t, grid, pivot, tilt, bs, tip, spout);
    float  speed = grid.x * BOTTLE_THROW, drop = grid.x * BOTTLE_DROP;

    // the heap of matter at the bottom, growing until it fills the window
    float land = clamp(tip.x + spout.x * speed * (-2.0 * spout.y * speed / drop) + grid.x * 0.08, grid.x * 0.35, grid.x * 0.95);
    float rise = pow(saturate((t - BOTTLE_TIP_SEC) / (BOTTLE_SEC - BOTTLE_TIP_SEC)), 1.6);
    float B    = 6.0 * s;
    float bx   = floor(c.x / B);
    float top  = grid.y - grid.y * 1.15 * rise * lerp(0.55 + 0.45 * exp(-pow((c.x - land) / (grid.x * 0.35), 2.0)), 1.0, rise * rise) - hash(bx) * 3.0 * s;
    if (c.y > top) col = element(hash2(float2(bx, floor(c.y / B))) * 61.0, c / s, t) * (wrap(c.x, B) < 1.0 || wrap(c.y, B) < 1.0 ? 0.7 : 1.0);

    // the stream: letters leave the neck green and digital, then grow and turn into matter
    if (t > BOTTLE_TIP_SEC)
    {
        float newest = floor(t / BOTTLE_SPOUT);
        [loop] for (int i = 0; i < BOTTLE_STREAM; i++)
        {
            float n   = newest - i;
            float age = t - n * BOTTLE_SPOUT;
            if (n * BOTTLE_SPOUT < BOTTLE_TIP_SEC) break;
            float2 ep, et, es; float etl, ebs;                              // where the bottle was when it left
            bottlePose(n * BOTTLE_SPOUT, grid, ep, etl, ebs, et, es);
            float2 v0  = es * speed * (0.85 + 0.3 * hash(n)) + float2(0.0, (hash(n + 3.0) - 0.5) * 0.1 * speed);
            float2 pos = et + v0 * age + float2(0.0, 0.5 * drop * age * age);
            float  g   = max(s, floor(ebs * 0.4)) * (1.0 + floor(age * BOTTLE_GROW));
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
    float2 mid = grid * 0.5 + float2(sin(t * 0.7 * WARP_DRIFT), cos(t * 0.53 * WARP_DRIFT)) * grid.y * 0.05 * (1.0 + collapse);
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
        float hu = frac(t * SWIRL_HUE + log(r) * 0.25 + floor(sw * 2.0) * 0.5);
        col = floor(sw * 6.0 + dither(c)) / 6.0 < 0.5 ? hue(hu) : hue(frac(hu + 0.33)) * 0.25;
        if (r < 0.015) col = float3(1, 1, 1);
        return col;
    }

    // the tunnel of elements, closing in and twisting harder as it goes
    float z  = 0.22 / r * (1.0 + collapse * 1.6);
    float u  = a + collapse * collapse * WARP_TWIST * z * 0.15 + t * 0.04 * WARP_DRIFT;
    float v  = z + t * WARP_SPEED * (1.0 + collapse * 2.0);
    float2 tile = floor(float2(u * WARP_TILES, v * WARP_DEPTH));
    // tiles crumble and fall in, showing a second tunnel behind, twisted the other way
    float layer = 0.0;
    float fallAt = hash2(tile * 1.3) * TUNNEL_SEC * 1.3;
    if (t > fallAt)
    {
        layer = 1.0;
        u = a - collapse * WARP_TWIST * z * 0.1 + 0.5 / WARP_TILES;
        v += (t - fallAt) * (t - fallAt) * 0.8 * WARP_DRIFT;
        tile = floor(float2(u * WARP_TILES, v * WARP_DEPTH));
    }
    float2 f = frac(float2(u * WARP_TILES, v * WARP_DEPTH));
    col = element(hash2(tile + layer * 7.0) * 61.0, f * 8.0 + tile * 8.0, t) * (layer > 0.0 ? 0.6 : 1.0);
    if (f.x < 0.06 || f.y < 0.08) col *= 0.45;                                   // the cracks between tiles
    if (frac(v * 0.5 - t * 0.3 * WARP_DRIFT) < 0.025) col = float3(0.7, 0.95, 1.0);            // rings of warped time
    return col * saturate(1.3 - z * 0.09);
}
