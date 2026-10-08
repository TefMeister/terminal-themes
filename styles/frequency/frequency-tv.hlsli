// Frequency, part 3: an old wooden TV set on a wallpapered wall, showing a 1930s black-and-white
// cartoon of a dog in trousers jogging from left to right, the camera following him.
// Included by frequency.hlsl, which holds the shared helpers.

static const float  TV_HEIGHT      = 0.86;   // cabinet height, share of the window
static const float  TV_ASPECT      = 1.55;   // cabinet width / height (screen plus knob panel)
static const float3 TV_WOOD        = float3(0.36, 0.19, 0.09);
static const float3 TV_WOOD_DARK   = float3(0.22, 0.11, 0.05);
static const float3 TV_BRASS       = float3(0.80, 0.62, 0.30);
static const float3 TV_WALL_A      = float3(0.10, 0.13, 0.09);
static const float3 TV_WALL_B      = float3(0.13, 0.16, 0.11);
static const float3 TV_WALL_DOT    = float3(0.20, 0.20, 0.13);
static const float  TV_STRIPE      = 14.0;   // wallpaper stripe width, cells
static const float  TV_CURVE       = 0.14;   // how much the glass bulges
static const float3 TV_PHOSPHOR    = float3(0.92, 0.97, 1.00);  // the slightly blue white of the tube

static const float  TOON_FPS       = 12.0;   // the cartoon runs "on twos", like the old ones
static const float  TOON_RUN       = 42.0;   // how fast the world scrolls past, sprite pixels per second
static const float  TOON_DOG_SHARE = 0.34;   // dog height as a share of the picture
static const float  TOON_IRIS_SEC  = 0.9;    // the iris opening at the start
static const float  TOON_SPLIT_AT  = 5.0;    // seconds in, the dog glitches into himself and a mirror image
static const float  TOON_SPLIT_SEC = 0.8;    // how long the split glitches
static const float  TOON_SEP_MIN   = 0.04;   // the two dogs' distance from the middle, share of the picture...
static const float  TOON_SEP_MAX   = 0.22;   // ...swinging between these
static const float  TOON_SEP_RATE  = 0.9;    // how quickly they drift together and apart
static const float3 INK            = float3(0.06, 0.06, 0.06);
static const float3 PAPER          = float3(0.96, 0.96, 0.93);

// signed distance to a rounded box centred on the origin (negative inside)
float roundBox(float2 p, float2 half, float r)
{
    float2 d = abs(p) - (half - r);
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}

// fill a shape with a black ink outline w thick: the cartoon look
float3 inked(float3 col, float d, float3 fill, float w)
{
    if (d < 0.0) col = d > -w ? INK : fill;
    return col;
}

float3 cartoon(float2 p, float2 size, float t)
{
    float tick = floor(t * TOON_FPS);
    float ts   = tick / TOON_FPS;
    float sc   = max(1.0, round(size.y * TOON_DOG_SHARE / DOG_S));
    float bounce = sin(ts * TAU * 1.5);             // everything bobs to the beat, rubber-hose style
    p.y += round((hash(tick * 1.3) - 0.5) * 2.0);   // gate weave
    float cam    = ts * TOON_RUN * sc;
    float ground = floor(size.y * 0.80);

    float3 col = lerp(float3(0.86, 0.86, 0.84), float3(0.74, 0.74, 0.72), floor(p.y / ground * 4.0) / 4.0);
    // clouds
    {
        float W = 130.0 * sc, wx = p.x + cam * 0.15, k = floor(wx / W);
        float2 m = float2(k * W + W * (0.2 + 0.6 * hash(k)), size.y * (0.14 + 0.1 * hash(k + 3.0)));
        float r = 9.0 * sc * (1.0 + 0.04 * bounce);
        float2 q = float2(wx, p.y) - m;
        float d = min(length(q) - r, min(length(q + float2(r, -r * 0.3)) - r * 0.7, length(q - float2(r, r * 0.3)) - r * 0.75));
        col = inked(col, d, PAPER, sc);
    }
    // far hills
    {
        float wx = p.x + cam * 0.35;
        float h  = ground - size.y * (0.16 + 0.06 * sin(wx * 0.019 / sc) + 0.035 * sin(wx * 0.047 / sc + 1.0));
        col = inked(col, h - p.y, float3(0.55, 0.55, 0.53), sc);
    }
    // lollipop trees that squash and stretch to the beat
    {
        float W = 95.0 * sc, wx = p.x + cam * 0.6, k = floor(wx / W);
        float tx = k * W + W * (0.2 + 0.6 * hash(k * 1.9));
        float th = (24.0 + 10.0 * hash(k + 0.5)) * sc;
        if (abs(wx - tx) < 2.5 * sc && p.y > ground - th && p.y < ground) col = abs(wx - tx) < 1.5 * sc ? float3(0.32, 0.32, 0.31) : INK;
        float2 q = float2(wx - tx, p.y - (ground - th - 10.0 * sc));
        q.y /= 1.0 + 0.1 * bounce;
        q.x /= 1.0 - 0.06 * bounce;
        float d = length(q) - 12.0 * sc;
        col = inked(col, d, float3(0.30, 0.30, 0.29), sc);
        if (d < 0.0 && hash2(floor(float2(wx, p.y) / (3.0 * sc))) > 0.85) col = float3(0.5, 0.5, 0.48);
    }
    // the ground, a picket fence along the path, and tufts going by
    {
        float wx = p.x + cam;
        if (p.y >= ground) col = p.y < ground + sc ? INK : float3(0.70, 0.70, 0.67);
        float fx = wrap(wx * 0.85, 16.0 * sc) - 8.0 * sc;
        float fh = 20.0 * sc;
        if (p.y < ground && p.y > ground - fh)
        {
            float top = ground - fh + abs(fx) * 0.8;                   // pointed tops
            if (abs(fx) < 3.0 * sc && p.y > top) col = abs(fx) > 2.0 * sc || p.y < top + sc ? INK : PAPER;
            float ry = ground - p.y;
            if (abs(fx) >= 3.0 * sc && (abs(ry - 6.0 * sc) < sc || abs(ry - 14.0 * sc) < sc)) col = ry < 6.0 * sc + 0.5 * sc ? INK : float3(0.6, 0.6, 0.58);
        }
        if (p.y > ground + 3.0 * sc && wrap(wx, 23.0 * sc) < sc && hash(floor(wx / (23.0 * sc))) > 0.4 && p.y < ground + 6.0 * sc) col = INK;
    }
    // the dog, and his shadow. Partway in he glitches into two: himself and his mirror image,
    // copying each other step for step, drifting closer together and further apart
    {
        float dogX  = size.x * 0.38 + sin(ts * 0.45) * size.x * 0.07;   // the camera keeps up, a little loosely
        float split = saturate((t - TOON_SPLIT_AT) / TOON_SPLIT_SEC);
        bool  glitch = t > TOON_SPLIT_AT && t < TOON_SPLIT_AT + TOON_SPLIT_SEC;
        float mid   = lerp(dogX, size.x * 0.5, split);
        float sep   = split * size.x * (TOON_SEP_MIN + (TOON_SEP_MAX - TOON_SEP_MIN) * (0.5 + 0.5 * sin(ts * TOON_SEP_RATE)));
        int   dogs  = t > TOON_SPLIT_AT ? 2 : 1;
        if (glitch && hash(tick * 2.3) < 0.4) dogs = 1;                    // the split stutters in
        float slice = glitch ? floor((hash(floor(p.y / (4.0 * sc)) + tick) - 0.5) * 10.0) * sc : 0.0;
        int   frame = (int)wrap(tick, DOG_FRAMES);
        [loop] for (int k = 0; k < dogs; k++)
        {
            float x = dogs == 1 ? mid : mid + (k == 0 ? -sep : sep);
            float2 org = float2(floor(x - DOG_S * 0.5 * sc), ground + 4.0 * sc - DOG_S * sc);
            float2 sh  = (p - float2(x, ground + 3.0 * sc)) / float2(18.0 * sc, 2.5 * sc);
            if (dot(sh, sh) < 1.0) col *= 0.6;
            if (gSprites)
            {
                float4 sp = sprite(int2(frame * DOG_S, DOG_Y), int2(DOG_S, DOG_S), p - org + float2(slice, 0.0), sc, k == 1);
                if (sp.a > 0.5) col = glitch && k == 1 && hash(tick * 1.7) < 0.5 ? 1.0 - sp.rgb : sp.rgb;
            }
        }
    }
    // old film: flicker, grain, scratches and dust, in a handful of greys
    float g = luma(col) * (0.9 + 0.1 * hash(tick * 0.77));
    g += (hash2(floor(p) + tick * 13.1) - 0.5) * 0.12;
    for (int j = 0; j < 2; j++)
    {
        float sx = hash(tick * 3.1 + j) * size.x;
        if (abs(p.x - sx) < 0.5 && hash(tick * 5.3 + j) > 0.45) g = j == 0 ? 0.95 : 0.15;
    }
    if (hash2(floor(p / 2.0) + tick) > 0.9985) g = 0.05;
    g = floor(saturate(g) * 6.0 + dither(p) * 0.8) / 6.0;
    // iris opening at the start
    float iris = saturate(t / TOON_IRIS_SEC) * length(size) * 0.6;
    if (length(p - size * 0.5) > iris) g = 0.0;
    return g * TV_PHOSPHOR;
}

float3 wallpaper(float2 c)
{
    float3 col = wrap(c.x, TV_STRIPE * 2.0) < TV_STRIPE ? TV_WALL_A : TV_WALL_B;
    float2 m = abs(float2(wrap(c.x, TV_STRIPE * 2.0), wrap(c.y, TV_STRIPE * 3.0)) - float2(TV_STRIPE * 0.5, TV_STRIPE * 1.5));
    if (m.x + m.y < 3.0) col = TV_WALL_DOT;
    return col;
}

float3 tvScene(float2 c, float2 grid, float t)
{
    float H = floor(grid.y * TV_HEIGHT);
    float W = floor(H * TV_ASPECT);
    if (W > grid.x * 0.94) { W = floor(grid.x * 0.94); H = floor(W / TV_ASPECT); }
    float2 org  = floor((grid - float2(W, H)) * float2(0.5, 0.4));
    float2 q    = c - org;
    float  flick = 0.85 + 0.15 * hash(floor(t * TOON_FPS));

    float3 col = wallpaper(c) * (0.6 + 0.4 * flick * saturate(1.0 - roundBox(q - float2(W, H) * 0.5, float2(W, H) * 0.5, 8.0) / (grid.y * 0.4)));
    // short legs under the cabinet
    if (q.y >= H && q.y < H + grid.y * 0.05 && (abs(q.x - W * 0.12) < 3.0 + (H + grid.y * 0.05 - q.y) * 0.1 || abs(q.x - W * 0.88) < 3.0 + (H + grid.y * 0.05 - q.y) * 0.1))
        col = TV_WOOD_DARK;

    float dc = roundBox(q - float2(W, H) * 0.5, float2(W, H) * 0.5, 8.0);
    if (dc >= 0.0) return col;

    // the wooden cabinet: grain, and a lighter top-left / darker bottom-right bevel
    float grain = sin(q.y * 0.8 + sin(q.x * 0.04 + q.y * 0.02) * 3.0 + hash(floor(q.y / 3.0)) * 2.0);
    col = lerp(TV_WOOD, TV_WOOD_DARK, step(0.6, grain) * 0.6 + dither(c) * 0.15);
    if (dc > -3.0) col *= (q.x + q.y < (W + H) * 0.5) ? 1.35 : 0.65;

    float  m   = floor(H * 0.08);
    float  sh  = H - 2.0 * m;
    float  sw  = floor(sh * 4.0 / 3.0);
    float2 sm  = float2(m + sw * 0.5, m + sh * 0.5);
    // the knob panel: two brass knobs and a speaker grille
    float px = (m + sw + W - m) * 0.5;
    for (int k = 0; k < 2; k++)
    {
        float2 kc = float2(px, H * (0.22 + 0.2 * k));
        float  kr = H * 0.07;
        float2 kd = q - kc;
        if (dot(kd, kd) < kr * kr)
        {
            col = TV_BRASS * (0.7 + 0.3 * saturate(-(kd.x + kd.y) / kr));
            float a = k == 0 ? 0.6 + t * 0.4 : 2.4;                  // the tuning knob turns slowly
            float2 dir = float2(cos(a), sin(a));
            if (abs(kd.x * dir.y - kd.y * dir.x) < 1.0 && dot(kd, dir) > 0.0) col = TV_WOOD_DARK;
        }
    }
    if (abs(q.x - px) < (W - sw - 3.0 * m) * 0.4 && q.y > H * 0.62 && q.y < H * 0.9 && wrap(q.y, 4.0) < 1.5) col = TV_WOOD_DARK * 0.6;

    // the screen: a dark bezel round a bulging glass tube
    float2 sq = q - sm;
    float bez = roundBox(sq, float2(sw, sh) * 0.5 + 3.0, 14.0);
    if (bez >= 0.0) return col;
    col = float3(0.03, 0.03, 0.03);
    float2 uv = sq / float2(sw, sh);
    uv *= 1.0 + TV_CURVE * dot(uv, uv);
    if (roundBox(uv * float2(sw, sh), float2(sw, sh) * 0.5, 12.0) >= 0.0) return col;
    float2 p = (uv + 0.5) * float2(sw, sh);
    float3 pic = cartoon(floor(p), float2(sw, sh), t);
    if (((int)c.y & 1) == 1) pic *= 0.82;                            // scanlines
    pic *= 1.0 - 0.7 * pow(saturate(length(uv) * 1.25), 3.0);         // the tube darkens at its edges
    float2 gl = uv - float2(-0.28, -0.3);                              // a faint reflection on the glass
    if (gl.x < 0.0 && gl.y < 0.0 && abs(length(gl / float2(1.6, 1.0)) - 0.12) < 0.012) pic += 0.07;
    return pic;
}
