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
static const float  VANISH_FROM    = 0.6;    // seconds after the middle mouth appears, the other mouths start glitching out of existence...
static const float  VANISH_BY      = 0.55;   // ...the last one gone by this share of THROAT_SEC
static const float  VANISH_SEC     = 0.6;    // how long each one takes to glitch away
static const float  MOUTH_START    = 0.05;   // its first size, share of the window height
static const float  MOUTH_GROW     = FREQ_LONG ? 0.5 : 0.8;    // how fast it grows (at 0.8 it doubles about every 0.9 s)
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
static const float3 DAWN_SKY_TOP   = float3(0.22, 0.16, 0.42);
static const float3 DAWN_SKY_LOW   = float3(1.00, 0.52, 0.32);
static const float3 DAY_SKY_TOP    = float3(0.22, 0.50, 0.92);
static const float3 DAY_SKY_LOW    = float3(0.72, 0.86, 1.00);
static const float  SKY_TURN_FROM  = FREQ_LONG ? 5.0 : 3.0;    // seconds in, the sky starts turning from night to day...
static const float  SKY_TURN_TO    = CITY_SEC + 1.5;   // ...and has turned this far by here (into the join)
static const float  SKY_TURN       = 1.75;   // radians the whole sky turns round a point below the horizon
static const float  SKY_PIVOT      = 0.15;   // that point, share of the height below the horizon
static const float  SKY_RADIUS     = 0.50;   // how far the moon and the sun are from it, share of the height
static const float  MOON_AT        = 0.30;   // the moon starts this far right of the top, radians...
static const float  SUN_AT         = -1.85;  // ...and the sun this far left, below the horizon
static const float  MOON_R         = 8.0;    // the moon's radius, cells at the smallest size
static const float  SUN_R          = 11.0;
static const float  STAR_CELL      = 7.0;    // the stars sit on a turning grid this many cells across...
static const float  STAR_SHARE     = 0.05;   // ...this share of whose squares hold one: sparse

static float gDay;                           // how far into the day the city is, 0..1, set by cityScene
static const float  WAVE_CALM      = 0.08;   // how high the ocean's waves are at first, against the eye height...
static const float  WAVE_SWELL     = 0.32;   // ...and how much higher they have grown by the time the glitch takes over
static const float  WAVE_GROW_SEC  = FREQ_LONG ? 14.0 : 8.0;   // the waves grow over this many seconds, up to the middle of the join
static const float  WAVE_LIGHT     = 3.0;    // how strongly a wave's near slope is lit and its far slope shaded

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
    float  end        = 1.0;                       // no fade to black: the grey static takes over from the throat
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
    }

    // the others, back to front: eyes opening one by one, then each glitching into a mouth, and at the
    // end each mouth glitching out of existence in a way of its own
    float vanishFrom = mAt + VANISH_FROM;
    float vanishTo   = throatFrom + THROAT_SEC * VANISH_BY - VANISH_SEC;
    [loop] for (int i = 0; i < FACE_COUNT; i++)
    {
        float depth = (i + 0.5) / FACE_COUNT;
        float size  = lerp(FACE_MIN, FACE_MAX, depth * depth) * grid.y;
        float id    = i * 13.1 + 1.0;
        float vw    = (tf - lerp(vanishFrom, vanishTo, hash(id + 1.7))) / VANISH_SEC;
        if (vw >= 1.0) continue;                                         // glitched away
        float2 pos  = (float2(hash(id + 0.1), hash(id + 0.3)) * 1.1 - 0.05) * grid + float2(sin(tf * 0.3 + id), cos(tf * 0.23 + id)) * size * 0.1;
        float2 q    = (c - pos) / size;
        if (abs(q.x) > 1.0 || abs(q.y) > 2.0) continue;                  // the widest a glitch below can stretch or shift it
        float swap  = lipsFrom + LIPS_SEC * FACE_SWAP * hash(id + 0.9);
        float gw    = (tf - swap) / FACE_GLITCH_SEC;
        if ((gw <= -0.5 || gw >= 1.0) && vw <= 0.0 && (abs(q.x) > 0.6 || abs(q.y) > 0.5)) continue;   // not glitching: its own box is enough
        float appear = EYES_SEC * EYE_FILL * hash(id + 0.7);
        if (tf < appear) continue;
        bool  mouth = tf >= swap;
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
        if (vw > 0.0)
        {
            // and at the end each mouth glitches out of existence, in a way of its own
            int   style = min(5, (int)(hash(id + 31.0) * 6.0));
            float k     = saturate(vw);
            float tick  = floor(tf * 24.0);
            bool  gone  = false;
            if (style == 0) { float sl = floor(q.y * 12.0); q.x += (hash(sl + tick + id) - 0.5) * 0.7 * k; gone = hash(sl * 1.7 + id) < k; }   // slices tear off
            if (style == 1) { gone = hash(tick * 1.3 + id) < k * 1.1; invert = hash(tick + id * 0.7) < 0.5; }                              // flickers out
            if (style == 2) { float n = lerp(MOUTH_PIXELS, 2.0, k); q = (floor(q * n) + 0.5) / n; gone = hash2(floor(q * n) + id) < k; }   // pixels crumble away
            if (style == 3) { q.y /= max(1.0 - k * 1.4, 0.02); q.x /= max(1.0 - smoothstep(0.6, 1.0, k), 0.02); tint *= 1.0 + 1.5 * k; }  // an old TV switching off
            if (style == 4) { tint = lerp(tint, hue(hash(tick + id)) * 1.6, bell(k)); gone = hash2(floor(c / (2.0 * gBase)) + id) < k; }   // colours, dissolving
            if (style == 5) { float cl = floor(q.x * 10.0); q.x += sin(q.y * 25.0 + tf * 20.0) * 0.1 * k; q.y -= k * k * 0.5 * hash(cl + id); gone = hash(cl + id + 2.0) < k * k; }   // melts and drips
            if (gone) continue;
        }
        if (abs(q.x) > 0.6 || abs(q.y) > 0.5) continue;                  // the real box, checked after the glitch so nothing is cut off
        float4 r = mouth ? lipsAt((floor(q * MOUTH_PIXELS) + 0.5) / MOUTH_PIXELS, id, tf, 0.0)
                         : eyeAt(q, id, tf, saturate((tf - appear) / EYE_OPEN_SEC));
        if (r.a > 0.0)
        {
            float3 rc = invert ? 1.0 - r.rgb : r.rgb;
            col = rc * tint * lerp(FACE_FAR_DIM, 1.0, depth);
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
    float3 col = lerp(float3(0.03, 0.03, 0.07), float3(0.26, 0.30, 0.42), gDay);              // by day the buildings show grey-blue
    if (px > 0.5) col = on ? lerp(CITY_LIGHTS * (0.8 + 0.2 * sin(t * 3.0 + g.y)), float3(0.62, 0.66, 0.74), gDay * 0.8)
                           : lerp(float3(0.15, 0.2, 0.35), float3(0.42, 0.47, 0.58), gDay);
    if (h > 14.0 && c.y < top + 2.0 * s && abs(wrap(x, bw) - bw * 0.5) < s && frac(t * 0.8) < 0.3) col = float3(1, 0.1, 0.1);
    return col;
}

// the height of the ocean at a point, -1..1, before it is scaled by how big the waves are now
float waveHeight(float wx, float wz, float t)
{
    return 0.55 * sin(wz * 1.5 - t * 2.2) + 0.3 * sin(wz * 0.8 + wx * 0.9 - t * 1.4) + 0.15 * sin(wx * 2.3 + wz * 0.5 + t * 3.1);
}

float3 cityScene(float2 c, float2 grid, float t)
{
    float s  = gBase;
    float hy = floor(grid.y * CITY_HORIZON);
    float lit;

    // the sky turns round a point below the horizon, from night to day: the stars wheel over and fade, the
    // moon sets on the right and the sun comes up on the left
    float  turn  = SKY_TURN * smoothstep(0.0, 1.0, (t - SKY_TURN_FROM) / (SKY_TURN_TO - SKY_TURN_FROM));
    float2 pivot = float2(grid.x * 0.5, hy + grid.y * SKY_PIVOT);
    float  sunA  = SUN_AT + turn;
    float2 sunP  = pivot + rot2(float2(0.0, -grid.y * SKY_RADIUS), sunA);
    float  sunUp = (hy - sunP.y) / (grid.y * SKY_RADIUS);                                    // the sun's height over the horizon
    gDay = smoothstep(-0.05, 0.45, sunUp);
    float  dawn  = bell(saturate((sunUp + 0.30) / 0.75)) * (1.0 - gDay * 0.6);
    float3 skyTop = lerp(lerp(CITY_SKY_TOP, DAWN_SKY_TOP, dawn), DAY_SKY_TOP, gDay);
    float3 skyLow = lerp(lerp(CITY_SKY_LOW, DAWN_SKY_LOW, dawn), DAY_SKY_LOW, gDay);
    if (c.y < hy)
    {
        float3 col = lerp(skyTop, skyLow, floor(c.y / hy * 6.0 + dither(c)) / 6.0);
        // sparse stars on the turning sky, twinkling, fading as the day comes
        float2 sp = rot2(c - pivot, -turn);
        float  cs = STAR_CELL * s;
        float2 sk = floor(sp / cs);
        float  stars = 1.0 - smoothstep(-0.25, 0.1, sunUp);
        if (stars > 0.0 && hash2(sk + 3.0) < STAR_SHARE)
        {
            float2 so = sp - (sk + 0.2 + 0.6 * float2(hash2(sk + 1.0), hash2(sk + 2.0))) * cs;
            float  big = hash2(sk + 4.0) > 0.85 ? 1.0 : 0.0;                                    // a few bright ones, with a cross
            float  tw  = 0.55 + 0.45 * sin(t * (1.5 + 3.0 * hash2(sk + 5.0)) + hash2(sk) * TAU);
            float  d   = max(abs(so.x), abs(so.y)), dc = min(abs(so.x), abs(so.y));
            if (d < 0.75 * s || (big > 0.0 && dc < 0.5 * s && d < 2.5 * s))
                col = lerp(col, float3(0.85, 0.90, 1.00) * (d < 0.75 * s ? 1.0 : 0.6), tw * stars);
        }
        // the sun, low and orange, white and bright once it is up, with a glow round it
        float  ds = length(c - sunP);
        col += lerp(float3(1.0, 0.45, 0.2), float3(1.0, 0.9, 0.7), gDay) * 0.35 * saturate(1.0 - ds / (grid.y * 0.35)) * saturate(sunUp + 0.3);
        if (ds < SUN_R * s) col = lerp(float3(1.0, 0.55, 0.25), float3(1.0, 0.98, 0.85), gDay) * (ds > (SUN_R - 1.0) * s ? 0.9 : 1.0);
        // the moon, round, with a few craters, paling by day
        float2 moonP = pivot + rot2(float2(0.0, -grid.y * SKY_RADIUS), MOON_AT + turn);
        float2 mq    = (c - moonP) / s;
        if (length(mq) < MOON_R)
        {
            float  dark = length(mq - float2(-2.5, -1.5)) < 2.2 || length(mq - float2(3.0, 2.0)) < 1.6 || length(mq - float2(0.5, 4.5)) < 1.2 ? 0.8 : 1.0;
            float3 mc   = float3(0.95, 0.92, 0.75) * dark * (length(mq) > MOON_R - 1.0 ? 0.85 : 1.0);
            col = lerp(mc, lerp(col, float3(1, 1, 1), 0.35), gDay * 0.6);
        }
        float3 b = skyline(c, grid, hy, t, lit);
        if (b.x >= 0.0) col = b;
        return col;
    }
    // the ocean of letters, in perspective, rolling towards you and heaving like water: its surface rises
    // and falls, so crests stand up on the screen and troughs sink, the slope facing you lit and the slope
    // behind in shade. The waves grow and grow over the city's last seconds, into the join
    float focal = grid.y - hy;
    float swell = WAVE_CALM + WAVE_SWELL * pow(saturate((t - (CITY_SEC + JOIN_OUT * 0.5 - WAVE_GROW_SEC)) / WAVE_GROW_SEC), 1.5);
    float yy = c.y - hy, z = focal / max(yy, 0.5), h = 0.0;
    [unroll] for (int it = 0; it < 3; it++)                                                  // find the water this row looks at
    {
        h  = waveHeight((c.x - grid.x * 0.5) * z / grid.y * 2.0, z + t * CITY_FLOW, t);
        z  = focal / max(yy + focal * swell * h / z, 0.5);
    }
    float hAhead = waveHeight((c.x - grid.x * 0.5) * z / grid.y * 2.0, z + 0.35 + t * CITY_FLOW, t);
    float light = saturate(0.55 + (h - hAhead) * WAVE_LIGHT);                                 // facing us: bright; falling away: dark
    float dyf = focal / z;
    float v2  = saturate(dyf / focal);
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
    sea *= (0.45 + 1.0 * light) * (1.0 + 0.6 * gDay);                                        // brighter as the day comes
    if (light > 0.8 && h > 0.55 && swell > 0.08 && hash2(floor(c / (2.0 * s)) + floor(t * 8.0)) > 0.6) sea = lerp(sea, float3(0.8, 0.95, 1.0), 0.5);   // foam on the crests
    skyline(float2(c.x, hy - 1.0), grid, hy, t, lit);                                         // city lights reflected, by night
    if (lit > 0.5 && on > 0.2 && hash(row + col * 0.1) > 0.5) sea = lerp(sea, CITY_LIGHTS, 0.5 * (1.0 - v2) * light * (1.0 - gDay));
    return lerp(sea, skyLow, pow(saturate(z / 30.0), 1.5) * 0.9);
}
