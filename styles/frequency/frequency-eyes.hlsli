// Frequency, part 6: the second station, second half. Black, with old green computer lines
// flickering; single eyes opening one after another, near and far, each looking its own way, until
// the window is full of them; each glitching in its own way into laughing lips in different
// lipsticks; the middle mouth coming last, from far back, growing until it swallows everything,
// and down its throat; and out over an endless ocean of made-up letters with a night city of letters far off.
// Included by frequency.hlsl after frequency-dream.hlsli (it uses glyphPixel and rot2 from there).

// --- old computer lines ---
static const float3 PC_GREEN       = float3(0.25, 1.00, 0.40);
static const float  PC_ROW_ON      = 0.5;    // share of text rows lit at any moment
static const float  PC_FLICKER     = 9.0;    // how often a row decides again, per second

// --- eyes and mouths: scattered at different depths, near ones big and bright, far ones small and dim ---
static const int    FACE_COUNT     = 30;
static const float  FACE_MIN       = 0.07;   // eye width far back, share of the window height...
static const float  FACE_MAX       = 0.34;   // ...and right in front
static const float  FACE_FAR_DIM   = 0.35;   // brightness of the furthest ones
static const float  EYE_FILL       = 0.85;   // share of EYES_SEC by which every eye has opened
static const float  EYE_OPEN_SEC   = 0.25;
static const float  FACE_SWAP      = 0.6;    // share of LIPS_SEC over which the eyes glitch into mouths
static const float  FACE_GLITCH_SEC = 0.45;  // how long each one's glitch lasts
static const float  MOUTH_LAST_AT  = 0.65;   // share of LIPS_SEC when the middle mouth appears
static const float  MOUTH_START    = 0.05;   // its first size, share of the window height
static const float  MOUTH_GROW     = 0.8;    // how fast it grows (it doubles about every 0.9 s)
static const float  MOUTH_PIXELS   = 18.0;   // a mouth is this many big pixels across, whatever its size
static const float  MIDDLE_PIXELS  = 26.0;   // the middle mouth, a little finer
static const float3 IRISES[6]      = { float3(0.25, 0.55, 0.95), float3(0.30, 0.70, 0.30), float3(0.45, 0.28, 0.12),
                                       float3(0.60, 0.55, 0.20), float3(0.55, 0.30, 0.85), float3(0.85, 0.15, 0.15) };
static const float3 LIPSTICKS[8]   = { float3(0.85, 0.05, 0.12), float3(1.00, 0.20, 0.60), float3(0.45, 0.05, 0.30),
                                       float3(0.10, 0.06, 0.10), float3(1.00, 0.45, 0.35), float3(0.15, 0.35, 1.00),
                                       float3(0.60, 0.15, 0.90), float3(1.00, 0.50, 0.05) };

// --- the night city ---
static const float  CITY_HORIZON   = 0.48;
static const float  CITY_REPEAT    = 0.37;   // the skyline repeats itself exactly this often (share of the width)
static const float  CITY_FLOW      = 0.6;    // how fast the letter ocean rolls towards you
static const float2 CITY_TILE      = float2(0.22, 0.30);   // one letter on the ocean, in floor units
static const float3 CITY_SEA       = float3(0.10, 0.60, 0.70);
static const float3 CITY_LIGHTS    = float3(1.00, 0.75, 0.30);
static const float3 CITY_SKY_TOP   = float3(0.01, 0.01, 0.06);
static const float3 CITY_SKY_LOW   = float3(0.14, 0.05, 0.20);

float3 pcScene(float2 c, float2 grid, float t)
{
    float  s   = gBase;
    float  rh  = (GLYPH_H + 2.0) * s;
    float  row = floor(c.y / rh);
    float  ts  = floor(t * PC_FLICKER);
    float3 col = float3(0, 0, 0);
    float  len = hash(row * 3.1 + floor(t * 0.7)) * grid.x * 0.8;
    float  jit = hash(row + ts * 1.3) > 0.85 ? floor((hash(row + ts) - 0.5) * 8.0) * s : 0.0;
    float  x   = c.x - 4.0 * s - jit;
    if (hash(row * 1.7 + ts) < PC_ROW_ON && x > 0.0 && x < len)
    {
        float  gx = floor(x / (GLYPH_W * s));
        float2 gl = float2(x - gx * GLYPH_W * s, c.y - row * rh) / s;
        col = PC_GREEN * (0.5 + 0.5 * hash(row + 0.3)) * glyphPixel(hash2(float2(gx, row) + floor(t * 2.0)) * GLYPH_COUNT, gl);
    }
    if (hash(row * 5.3 + ts) > 0.97 && wrap(c.y, rh) < 1.0) col = PC_GREEN * 0.6;           // a stray scan line
    float cur = floor(hash(floor(t * 1.5)) * grid.y / rh);                                    // a blinking cursor
    if (row == cur && c.x > 4.0 * s && c.x < (4.0 + GLYPH_W) * s && frac(t * 2.0) < 0.5 && wrap(c.y, rh) < GLYPH_H * s) col = PC_GREEN;
    if (((int)c.y & 1) == 1) col *= 0.6;                                                       // phosphor rows
    col *= 1.0 + 0.6 * bell(saturate((frac(-t * 0.4) - c.y / grid.y) * 8.0));                 // a bright bar rolling up
    return col * saturate(t / 0.4);
}

// one eye, q measured in eye widths from its middle; alpha 0 outside
float4 eyeAt(float2 q, float id, float t, float open)
{
    if (frac((t + hash(id + 4.0) * 9.0) / (3.0 + hash(id + 6.0) * 4.0)) < 0.04) open *= 0.1;   // a blink
    float ax  = abs(q.x);
    if (ax > 0.5) return float4(0, 0, 0, 0);
    float lid = 0.32 * open * (1.0 - 4.0 * q.x * q.x);
    float e   = abs(q.y) - lid;
    if (q.y < 0.0 && e > 0.0 && e < 0.08 && ax < 0.4 && frac(q.x * 14.0) < 0.3) return float4(0.05, 0.02, 0.02, 1);   // lashes
    if (e > 0.03) return float4(0, 0, 0, 0);
    if (e > 0.0) return float4(0.12, 0.04, 0.04, 1);                                          // lid line
    float3 col = float3(0.93, 0.91, 0.86) * (1.0 - 1.2 * q.x * q.x);
    if (ax > 0.18 && abs(sin(q.x * 40.0 + sin(q.y * 30.0 + id) * 2.0)) < 0.07) col = float3(0.80, 0.25, 0.25);   // veins
    // the iris looks somewhere new every so often, each eye on its own
    float  look = floor((t + hash(id) * 3.0) / (0.5 + hash(id + 5.0) * 1.5));
    float  ang  = hash(id + look * 1.3) * TAU;
    float2 io   = float2(cos(ang), sin(ang)) * (0.6 + 0.4 * hash(id + look * 2.1)) * float2(0.18, 0.09);
    float2 dd   = q - io;
    float  rr   = length(dd);
    if (rr < 0.15)
    {
        col = IRISES[min(5, (int)(hash(id + 8.0) * 6.0))] * (0.7 + 0.4 * hash(floor(atan2(dd.y, dd.x) * 6.0) + id));
        if (rr > 0.13) col *= 0.45;
        if (rr < 0.06 * (1.0 + 0.3 * sin(t * 2.0 + id))) col = float3(0.01, 0.01, 0.01);
        if (length(dd + float2(0.04, 0.04)) < 0.022) col = float3(1, 1, 1);
    }
    return float4(col, 1);
}

// how wide a mouth is open: five ways of laughing, picked per mouth
float laughOf(float id, float t, inout float2 q)
{
    int   kind = min(4, (int)(hash(id + 13.0) * 5.0));
    float ph   = hash(id) * 6.0;
    if (kind == 0) { q.y += 0.015 * sin(t * 28.0 + ph); return 0.2 + 0.7 * abs(sin(t * 14.0 + ph)); }   // cackle
    if (kind == 1) { q.y += 0.03 * sin(t * 5.0 + ph);   return 0.55 + 0.45 * sin(t * 2.5 + ph); }       // slow guffaw
    if (kind == 2) { q.x += 0.03 * sin(t * 7.0 + ph);   return 0.25 + 0.2 * abs(sin(t * 9.0 + ph)); }   // giggle, head shaking
    if (kind == 3)                                                                                        // maniacal: wide, hold, snap shut
    {
        float x = frac(t / 1.6 + ph);
        return x < 0.15 ? x / 0.15 : (x < 0.75 ? 1.0 - 0.08 * abs(sin(t * 30.0)) : 0.05);
    }
    return 0.12 + 0.05 * sin(t * 40.0 + ph);                                                             // trembling smile
}

// one laughing mouth, q measured in mouth widths; wide forces it open (for the throat).
// Alpha 2 means inside the mouth.
float4 lipsAt(float2 q, float id, float t, float wide)
{
    float laugh = max(laughOf(id, t, q), wide);
    float o     = 0.05 + 0.17 * laugh;
    float ax = abs(q.x);
    if (ax > 0.5) return float4(0, 0, 0, 0);
    float w     = saturate(1.0 - 4.0 * q.x * q.x);
    float top   = -(o + 0.11) * sqrt(w) + 0.035 * exp(-pow(q.x / 0.06, 2.0));
    float bot   = (o + 0.14) * pow(w, 0.6);
    float wi    = saturate(1.0 - 4.8 * q.x * q.x);
    float itop  = -o * pow(wi, 0.7);
    float ibot  = o * 0.9 * pow(wi, 0.8);
    if (q.y < top || q.y > bot) return float4(0, 0, 0, 0);
    float3 lip = LIPSTICKS[min(7, (int)(hash(id + 12.0) * 8.0))];
    if (wi > 0.0 && q.y > itop && q.y < ibot)
    {
        float3 col = float3(0.16, 0.02, 0.04);
        if (q.y < itop + 0.07 && ax < 0.3) col = frac(q.x / 0.055 + 0.5) < 0.12 ? float3(0.6, 0.58, 0.55) : float3(0.96, 0.94, 0.88);
        if (q.y > ibot - 0.05 && ax < 0.24) col = frac(q.x / 0.05 + 0.5) < 0.12 ? float3(0.6, 0.58, 0.55) : float3(0.92, 0.9, 0.84);
        if (length((q - float2(0.0, ibot - 0.03)) / float2(0.16, 0.06)) < 1.0 && q.y > ibot - 0.05) col = float3(0.85, 0.32, 0.40);
        return float4(col, 2);
    }
    float3 col = lip * (q.y < 0.0 ? 0.8 : 1.0);
    if (q.y > 0.0 && length((q - float2(0.06, (ibot + bot) * 0.5)) / float2(0.12, 0.025)) < 1.0) col = lerp(col, float3(1, 1, 1), 0.45);  // gloss
    if (q.y < top + 0.012 || q.y > bot - 0.012) col *= 0.5;                                   // the outline
    return float4(col, 1);
}

// eyes, then mouths, then the dive down the throat. tf counts from the first eye opening.
float3 facesScene(float2 c, float2 grid, float tf)
{
    float  lipsFrom   = EYES_SEC;
    float  throatFrom = EYES_SEC + LIPS_SEC;
    float  others     = 1.0 - saturate((tf - throatFrom) / (THROAT_SEC * 0.5));
    float  end        = 1.0 - smoothstep(throatFrom + THROAT_SEC * 0.85, throatFrom + THROAT_SEC, tf);
    float3 col = float3(0, 0, 0);

    // the middle mouth: appears last, small and far back, and grows until it swallows everything
    float mAt = lipsFrom + LIPS_SEC * MOUTH_LAST_AT;
    if (tf > mAt)
    {
        float  gt    = tf - mAt;
        float  size  = grid.y * MOUTH_START * exp(gt * MOUTH_GROW);
        float2 q     = (c - grid * 0.5) / size;
        float  wide  = saturate((tf - throatFrom) / 1.0);
        float4 r     = lipsAt((floor(q * MIDDLE_PIXELS) + 0.5) / MIDDLE_PIXELS, 777.0, tf, wide);
        bool   front = size > grid.y * 0.6;                    // once it is big, it is in front of everything
        if (r.a > 1.5 && tf > throatFrom)
        {
            // down the throat: fleshy rings rushing past, dark in the middle
            float  rr = length(q / float2(0.42, 0.2));
            float  dp = 0.25 / (rr + 0.03) + tf * 3.0;
            float3 fl = frac(dp) < 0.5 ? float3(0.42, 0.04, 0.07) : float3(0.62, 0.10, 0.12);
            r.rgb = lerp(r.rgb, fl * (0.8 + 0.3 * hash2(floor(c / 3.0))) * saturate(rr * 1.6), saturate(wide * 2.0));
        }
        if (r.a > 0.0) col = r.rgb * lerp(FACE_FAR_DIM, 1.0, saturate(gt / 2.0));
        if (front && r.a > 0.0) return col * end;
        if (front) others = min(others, 0.4);
    }

    // the others, back to front: eyes opening one by one, then each glitching into a mouth
    [loop] for (int i = 0; i < FACE_COUNT; i++)
    {
        float depth = (i + 0.5) / FACE_COUNT;
        float size  = lerp(FACE_MIN, FACE_MAX, depth * depth) * grid.y;
        float id    = i * 13.1 + 1.0;
        float2 pos  = (float2(hash(id + 0.1), hash(id + 0.3)) * 1.1 - 0.05) * grid + float2(sin(tf * 0.3 + id), cos(tf * 0.23 + id)) * size * 0.1;
        float2 q    = (c - pos) / size;
        if (abs(q.x) > 0.6 || abs(q.y) > 0.5) continue;
        float appear = EYES_SEC * EYE_FILL * hash(id + 0.7);
        if (tf < appear) continue;
        float swap  = lipsFrom + LIPS_SEC * FACE_SWAP * hash(id + 0.9);
        bool  mouth = tf >= swap;
        float gw    = (tf - swap) / FACE_GLITCH_SEC;
        bool  invert = false;
        float3 tint = float3(1, 1, 1);
        if (gw > -0.5 && gw < 1.0)
        {
            // each one glitches across in its own style
            int   style = min(4, (int)(hash(id + 21.0) * 5.0));
            float k     = saturate(gw);
            float tick  = floor(tf * 24.0);
            float b     = bell(saturate(gw * 0.67 + 0.33));
            if (style == 0) { q.x += (hash(floor(q.y * 14.0) + tick + id) - 0.5) * 0.5 * b; mouth = hash(tick + id) < k; }   // slices
            if (style == 1) { mouth = hash(tick * 1.3 + id) < k; invert = hash(tick + id * 0.3) < 0.5; }                    // flicker
            if (style == 2) { float n = lerp(40.0, 3.0, b); q = (floor(q * n) + 0.5) / n; mouth = gw > 0.5; }               // pixelate
            if (style == 3) { q.y /= 1.0 + 3.0 * b; q.x *= 1.0 + 0.6 * b; mouth = gw > 0.5; }                              // stretch
            if (style == 4) { mouth = gw > 0.5; tint = lerp(float3(1, 1, 1), hue(hash(tick + id)) * 1.6, b); }             // colours
        }
        float4 r = mouth ? lipsAt((floor(q * MOUTH_PIXELS) + 0.5) / MOUTH_PIXELS, id, tf, 0.0)
                         : eyeAt(q, id, tf, saturate((tf - appear) / EYE_OPEN_SEC));
        if (r.a > 0.0)
        {
            float3 rc = invert ? 1.0 - r.rgb : r.rgb;
            col = rc * tint * lerp(FACE_FAR_DIM, 1.0, depth) * others;
        }
    }
    return col * end;
}

// the night skyline, built of letters; returns how lit the building at this x is (for reflections)
float3 skyline(float2 c, float2 grid, float hy, float t, out float lit)
{
    float  s  = gBase;
    float  x  = wrap(c.x, grid.x * CITY_REPEAT);
    float  bw = GLYPH_W * s * 4.0;
    float  b  = floor(x / bw);
    float  h  = floor(3.0 + 16.0 * pow(hash(b * 2.3 + 0.1), 2.0));
    bool   pop = hash(b * 7.7) > 0.88 && frac(t * 0.3 + hash(b)) < 0.25;                 // a building that fails to load
    lit = pop ? 0.0 : hash(b + 4.0);
    float top = hy - h * GLYPH_H * s;
    if (pop || c.y < top) return float3(-1, -1, -1);
    float2 g  = floor(float2(x, hy - c.y) / (float2(GLYPH_W, GLYPH_H) * s));
    float2 gl = float2(x - g.x * GLYPH_W * s, (hy - c.y) - g.y * GLYPH_H * s) / s;
    gl.y = GLYPH_H - 1.0 - gl.y;
    bool on = hash2(g + b) > 0.55;
    float px = glyphPixel(hash2(g + floor(t * 0.4 + hash(b))) * GLYPH_COUNT, gl);
    float3 col = float3(0.03, 0.03, 0.07);
    if (px > 0.5) col = on ? CITY_LIGHTS * (0.8 + 0.2 * sin(t * 3.0 + g.y)) : float3(0.15, 0.2, 0.35);
    if (h > 14.0 && c.y < top + 2.0 * s && abs(wrap(x, bw) - bw * 0.5) < s && frac(t * 0.8) < 0.3) col = float3(1, 0.1, 0.1);
    return col;
}

float3 cityScene(float2 c, float2 grid, float t)
{
    float s  = gBase;
    float hy = floor(grid.y * CITY_HORIZON);
    float lit;
    if (c.y < hy)
    {
        float3 col = lerp(CITY_SKY_TOP, CITY_SKY_LOW, floor(c.y / hy * 6.0 + dither(c)) / 6.0);
        float2 g = floor(c / (float2(GLYPH_W, GLYPH_H) * s));
        if (hash2(g + 3.0) > 0.975)                                                           // letter stars
            col += float3(0.5, 0.6, 0.9) * (0.4 + 0.4 * sin(t * 2.0 + hash2(g) * TAU)) * glyphPixel(hash2(g) * GLYPH_COUNT, (c - g * float2(GLYPH_W, GLYPH_H) * s) / s);
        float2 mq = abs(c - float2(grid.x * 0.8, hy * 0.35));                                // the moon is a perfect square
        if (max(mq.x, mq.y) < 9.0 * s) col = float3(0.95, 0.92, 0.75) * (hash2(floor(c / (3.0 * s))) > 0.85 ? 0.85 : 1.0);
        float3 b = skyline(c, grid, hy, t, lit);
        if (b.x >= 0.0) col = b;
        return col;
    }
    // the ocean of letters, in perspective, rolling towards you
    float dyf = max(c.y - hy, 0.5);
    float z   = (grid.y - hy) / dyf;
    float v2  = saturate(dyf / (grid.y - hy));
    float px  = z / grid.y * 2.0;
    float wx  = (c.x - grid.x * 0.5) * px;
    float wz  = z + t * CITY_FLOW;
    float row = floor(wz / CITY_TILE.y);
    float sx  = wx + sin(row * 0.7 + t) * 0.08;
    float col = floor(sx / CITY_TILE.x);
    float2 f  = frac(float2(sx / CITY_TILE.x, wz / CITY_TILE.y));
    float wave = 0.5 + 0.5 * sin(row * 0.9 - t * 2.0 + col * 0.3);
    float on;
    if (px * 6.0 > CITY_TILE.x) on = 0.3;                                                    // too far to read: a shimmer
    else on = glyphPixel(hash2(float2(col, row) + floor(t * (1.0 + hash(col)))) * GLYPH_COUNT, f * float2(GLYPH_W, GLYPH_H));
    float3 sea = CITY_SEA * on * (0.35 + 0.75 * wave) + float3(0.0, 0.02, 0.05);
    skyline(float2(c.x, hy - 1.0), grid, hy, t, lit);                                         // city lights reflected
    if (lit > 0.5 && on > 0.2 && hash(row + col * 0.1) > 0.5) sea = lerp(sea, CITY_LIGHTS, 0.5 * (1.0 - v2));
    return lerp(sea, CITY_SKY_LOW, pow(saturate(z / 30.0), 1.5) * 0.9);
}
