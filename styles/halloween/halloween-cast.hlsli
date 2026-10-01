// Halloween: the cast, drawn by halloween.hlsl, which includes this file. The ghost, the witches,
// the graveyard, pumpkins, zombies, the witch's hut and the spiders. Every setting lives at the top
// of halloween.hlsl; this file only holds the drawing.

// ---------------------------------------------------------------- the ghost

// is cell c inside the ghost's sheet? p.x across, p.y down, both in ghost heights from its crown
bool inGhost(float2 p, float T, out float lit)
{
    lit = 0.0;
    float v = p.y;
    if (v < 0.0 || v > 1.12) return false;
    float wind = WIND * (1.0 + 0.3 * sin(T * loopRate(0.7)));
    // the wind blows from the right, so the lower the cloth the further it streams to the left
    float bend = -wind * pow(max(v - 0.12, 0.0), 1.4) * 1.5 - 0.025 * sin(v * 9.0 - T * loopRate(5.0)) * v;
    float u = p.x - bend;
    bool inside;
    if (v < 0.30)
        inside = u * u + (v - 0.30) * (v - 0.30) < 0.28 * 0.28;
    else
    {
        float d = v - 0.30;
        float wR = 0.28 + 0.03 * d - 0.03 * sin(v * 13.0 - T * loopRate(6.5)) * d;      // pressed flat by the wind
        float wL = 0.28 + 0.30 * pow(d, 1.2) + 0.06 * sin(v * 8.0 - T * loopRate(5.5)) * d; // billowing out
        float hem = 0.95 + 0.05 * sin(u * 21.0 - T * loopRate(7.0)) + 0.06 * abs(sin(u * 7.0 + T * loopRate(3.0)))
                  - 0.12 * saturate(-u / 0.5) * (0.6 + 0.4 * sin(T * loopRate(4.0)));   // the windward hem lifts
        inside = u > -wL && u < wR && v < hem;
        // ragged tails torn off the leeward side, flapping out in the wind
        for (int i = 0; i < 3 && !inside; i++)
        {
            float fi = (float)i;
            float len = 0.16 + 0.07 * sin(T * loopRate(3.1) + fi * 2.0);
            float along = (-wL - u) / len;                       // 0 where it leaves the cloth, 1 at its tip
            if (along < -0.2 || along > 1.0) continue;
            float cy = 0.62 + 0.15 * fi + 0.05 * sin(along * 5.0 - T * loopRate(8.0) + fi) - along * 0.06;
            inside = abs(v - cy) < 0.035 * (1.0 - along) + 0.004;
        }
    }
    if (!inside) return false;
    // folds run down the cloth and ripple with the wind; the moon lights it from the upper right
    float fold = sin(u * 30.0 + v * 5.0 - T * loopRate(3.5) + v * v * 8.0);
    lit = 0.72 + 0.20 * fold * saturate(v * 1.4) + 0.25 * saturate(u / 0.3) - 0.20 * saturate(v - 0.6);
    return true;
}

// the ghost, its crown at `at` and `h` cells tall. `left`: it drifts to the left, so its sheet trails
// out to the right. `lift` brightens it to cancel the darkening that is applied after it is drawn.
// It is worked out once per pixel and then laid over the scene wherever its depth puts it: the
// result is how much of what is behind still shows (m), and k, the ghost's own light, so that
// the scene with the ghost on it = behind * m + k.
float ghostLayer(int2 cell, float2 grid, float T, float alpha, float flash, float dth,
                 float2 at, float h, bool left, float lift, out float3 k)
{
    k = 0;
    if (alpha <= 0.0) return 1.0;
    float2 crown = at + float2(sin(T * loopRate(0.31)) * h * GHOST_DRIFT_SWAY, sin(T * loopRate(0.9)) * h * 0.015);
    float2 p = (float2(cell) + 0.5 - crown) / h;
    if (left) p.x = -p.x;
    if (p.x < -0.75 || p.x > 0.45 || p.y < -0.05 || p.y > 1.15) return 1.0;
    // one pass over this cell and its four neighbours (to find the outline), so the shape is only
    // written out once; if the cell is outside, the last pass tests the aura instead
    float px = 1.0 / h;
    float lit = 0.0;
    bool inside = false, edge = false, aura = false;
    [loop] for (int q = 0; q < 5; q++)
    {
        float2 tap = q == 0 ? p : (inside ? p + px * float2(q == 1 ? 1 : (q == 2 ? -1 : 0), q == 3 ? 1 : (q == 4 ? -1 : 0))
                                           : float2(p.x * 0.93, (p.y - 0.5) * 0.95 + 0.5));
        float l;
        bool hit = inGhost(tap, T, l);
        if (q == 0) { inside = hit; lit = l; }
        else if (!inside) { aura = hit; break; }
        else if (!hit) { edge = true; break; }
    }
    if (!inside)
    {
        // a faint cold aura just outside the cloth
        if (aura && dth < alpha * 0.6) k = float3(0.05, 0.06, 0.10) * (1.0 + flash) * lift;
        return 1.0;
    }
    // appear and vanish as a dissolve, not a fade, to keep it pixel-art
    if (dth > alpha) return 1.0;
    float3 g = lerp(GHOST_SHADE, GHOST_LIGHT, steps(lit, 5.0, dth * 0.3));
    if (edge) g = GHOST_EDGE;
    // the two eye holes, leaning with the head
    float wind = WIND * (1.0 + 0.3 * sin(T * loopRate(0.7)));
    float2 e = p - float2(-wind * 0.05, 0.21);
    for (int side = -1; side <= 1; side += 2)
    {
        float2 q = e - float2(side * 0.095, side * 0.008);
        q.x += q.y * 0.25 * side;                     // slanted a little, for a sad, hollow look
        if ((q.x * q.x) / (0.048 * 0.048) + (q.y * q.y) / (0.075 * 0.075) < 1.0) g = GHOST_EYE;
    }
    g *= (1.0 + flash * 0.4) * lift;
    k = g * GHOST_OPACITY;
    return 1.0 - GHOST_OPACITY;
}

// ---------------------------------------------------------------- the rest of the cast

float3 drawWitches(float3 col, int2 cell, float2 grid, float T, int tick, float3 sky)
{
    [loop] for (int k = 0; k < WITCHES; k++)
    {
        float fk = (float)k;
        float trip = WITCH_TRIP * lerp(0.75, 1.35, hash(fk * 3.3));
        float cyc  = trip * lerp(1.4, 2.2, hash(fk * 4.7));
        float f    = loopFreq(1.0 / cyc);
        float ph   = frac(T * f + hash(fk * 9.1)) / f;              // seconds into this witch's cycle
        float tripL = trip * (1.0 / f) / cyc;                       // the trip, stretched to fit the loop
        if (ph > tripL) continue;
        bool right = (k & 1) == 0;
        float sc   = lerp(0.55, 1.15, hash(fk * 5.9));
        float u    = ph / tripL;
        float x    = lerp(-0.1, 1.1, right ? u : 1.0 - u) * grid.x;
        float y    = grid.y * lerp(0.05, 0.32, hash(fk * 7.7)) + sin(T * loopRate(1.3) + fk) * 2.0 + u * 6.0 * (hash(fk) - 0.5);
        int frame  = pmod(tick / 2 + k, 4);
        float4 t = sprite(cell, float2(x - WW * sc * 0.5, y), sc, frame * WW, W_Y, WW, WH, !right);
        // smaller means further away, so a little more lost in the night air
        if (t.w > 0) col = lerp(SILHOUETTE, sky, 0.45 * (1.15 - sc));
    }
    return col;
}

float hillFar(float x, float2 grid)  { return grid.y * (HORIZON - 0.13) + sin(x * 0.012 + 1.0) * 9.0 + sin(x * 0.031) * 4.0 + noise1(x * 0.2) * 1.0; }
float hillNear(float x, float2 grid) { return grid.y * (HORIZON - 0.045) + sin(x * 0.009 + 4.0) * 6.0 + sin(x * 0.023 + 2.0) * 3.0; }

float3 drawYard(float3 col, int2 cell, float2 grid, float flash)
{
    // dead trees standing on the near hill
    [loop] for (int k = 0; k < TREES; k++)
    {
        float fk = (float)k;
        float x  = grid.x * (0.06 + 0.88 * (fk + 0.15 + 0.7 * hash(fk * 2.1)) / TREES);
        if (abs(x / grid.x - HUT_POS) < 0.12) x += grid.x * 0.2;    // keep clear of the hut
        float sc = lerp(0.8, 1.25, hash(fk * 6.3));
        float4 t = sprite(cell, float2(x - TW * sc * 0.5, hillNear(x, grid) + 3.0 - TH * sc), sc, (k & 1) * TW, T_Y, TW, TH, hash(fk) > 0.5);
        if (t.w > 0) col = SILHOUETTE;
    }
    // gravestones along the brow of the hill, catching moonlight and lightning
    [loop] for (int j = 0; j < TOMBS; j++)
    {
        float fj = (float)j;
        float x  = grid.x * (fj + 0.5 + (hash(fj * 3.7) - 0.5) * 0.7) / TOMBS;
        float sc = lerp(0.8, 1.15, hash(fj * 1.3));
        float4 t = sprite(cell, float2(x - GW * sc * 0.5, hillNear(x, grid) + 4.0 + hash(fj * 8.8) * 4.0 - GH * sc), sc,
                          pmod((int)(hash(fj * 4.4) * 4.0), 4) * GW, G_Y, GW, GH, false);
        if (t.w > 0) col = t.rgb * (TOMB_LIGHT * 0.35 + flash * 0.9);
    }
    return col;
}

float candle(int k, float T)
{
    float ft = T * 12.0;
    float a = hash(floor(loopIndex(floor(ft), 12.0)) * 1.7 + k * 13.0);
    float b = hash(floor(loopIndex(floor(ft) + 1.0, 12.0)) * 1.7 + k * 13.0);
    return 0.7 + 0.3 * lerp(a, b, frac(ft));
}

// warm light round a pumpkin, on whatever is behind it: ground, hill, gravestones, porch
float3 pumpkinHalo(float3 col, int2 cell, float2 centre, float2 reach, int k, float T, float dth)
{
    float l = saturate(1.0 - length((float2(cell) - centre) / reach));
    return col + CANDLE_DEEP * steps(l * l, 5.0, dth) * 0.26 * candle(k, T);
}

// one jack-o'-lantern standing on `foot` (bottom middle); k picks its candle's flicker
// `row` is the sheet row the drawing starts on and `size` its cell; the frames run along the row
float3 drawPumpkinFrom(float3 col, int2 cell, float2 foot, float sc, int row, int2 size, int k, float T, int tick, float flash, bool mirror)
{
    int frame = pmod(tick / 2 + k * 3, 4);
    float4 t = sprite(cell, foot - float2(size.x * sc * 0.5, size.y * sc), sc, frame * size.x, row, size.x, size.y, mirror);
    if (t.w == 0) return col;
    float fl = candle(k, T);
    bool code = t.r > 0.9;
    if (code && abs(t.b - 7.0 / 255.0) < 0.5 / 255.0)        // candle light: the flame and the lit inside
    {
        if (t.g > 0.97) return float3(1.0, 0.96, 0.78) * (0.85 + 0.3 * fl) * CANDLE_GLOW;   // the flame
        return lerp(CANDLE_DEEP, CANDLE_HOT, saturate(t.g * fl * 1.05 - 0.25)) * (0.7 + 0.5 * fl) * CANDLE_GLOW;
    }
    if (code && abs(t.b - 8.0 / 255.0) < 0.5 / 255.0)        // wax and cut flesh, lit by the flame
        return float3(1.0, t.g / max(t.r, 0.01), 0.45) * t.r * (0.7 + 0.5 * fl) * 1.4;
    return t.rgb * (PUMPKIN_BODY * (0.85 + 0.3 * fl) + flash * 0.9);
}

float3 drawPumpkin(float3 col, int2 cell, float2 foot, float sc, int kind, int k, float T, int tick, float flash, bool mirror)
{
    return drawPumpkinFrom(col, cell, foot, sc, PK_Y + kind * PKH, int2(PKW, PKH), k, T, tick, flash, mirror);
}

// where foreground pumpkin k stands (bottom middle) and its scale
void pumpkinPlace(int k, float2 grid, out float2 foot, out float sc)
{
    float x = PK_INSET[k] * grid.y;
    foot = float2(PK_SIDE[k] > 0 ? grid.x - x : x, grid.y + PK_SINK[k] * grid.y);
    sc = PK_HEIGHT[k] * grid.y / BPH;
}

float3 pumpkinPools(float3 col, int2 cell, float2 grid, float T, float dth)
{
    [loop] for (int k = 0; k < PUMPKINS; k++)
    {
        float2 foot; float sc;
        pumpkinPlace(k, grid, foot, sc);
        float h = PK_HEIGHT[k] * grid.y;
        col = pumpkinHalo(col, cell, float2(foot.x, min(foot.y, grid.y) - 2.0), POOL_SIZE * h * float2(1.0, 0.32), k, T, dth);
    }
    return col;
}

float3 drawHillPumpkins(float3 col, int2 cell, float2 grid, float T, int tick, float flash, float dth)
{
    [loop] for (int k = 0; k < HILL_PUMPKINS; k++)
    {
        float x = grid.x * HILL_PK_X[k];
        float2 foot = float2(x, hillNear(x, grid) + 3.0);
        col = pumpkinHalo(col, cell, foot - float2(0, PKH * HILL_PK_SCALE * 0.4), HALO_SIZE * HILL_PK_SCALE * 3.0 * float2(1.0, 0.7), 6 + k, T, dth);
        col = drawPumpkin(col, cell, foot, HILL_PK_SCALE, k % 3, 6 + k, T, tick, flash, (k & 1) == 1);
    }
    return col;
}

float3 drawPumpkins(float3 col, int2 cell, float2 grid, float T, int tick, float flash)
{
    [loop] for (int k = 0; k < PUMPKINS; k++)
    {
        float2 foot; float sc;
        pumpkinPlace(k, grid, foot, sc);
        col = drawPumpkinFrom(col, cell, foot, sc, BIG_Y + PK_ROW[k] * BPH, int2(BPW, BPH), k, T, tick, flash, PK_SIDE[k] < 0);
    }
    return col;
}

// the zombies, always there as dark shapes shuffling towards you; the lightning shows them.
// feet: how far down the nearest drawn zombie stands (-1 if none here), for sorting against the hut
float3 drawZombies(float3 col, int2 cell, float2 grid, float T, int tick, float flash, float horizonY, out float feetOut)
{
    float best = -1.0;
    float3 z = col;
    feetOut = -1.0;
    [loop] for (int k = 0; k < ZOMBIES; k++)
    {
        float fk = (float)k;
        // how this one walks: straight at you, at 45 degrees, or side on across the field
        float kindRoll = hash(fk * 1.7);
        int view = kindRoll < ZOMBIE_FRONT ? 0 : (kindRoll < ZOMBIE_FRONT + ZOMBIE_DIAG ? 1 : 2);
        int arms = hash(fk * 2.3) < ZOMBIE_ARMS_OUT ? 0 : 1;
        bool goLeft = hash(fk * 7.0) > 0.5;
        // the stride: every zombie sways its own way, some barely, some wildly, some dragging a leg
        float stepRate = ZOMBIE_LURCH * TAU * 0.5 * lerp(0.55, 1.5, hash(fk * 5.5));
        float w  = T * loopRate(stepRate) + fk * 2.0;
        float limp = hash(fk * 3.3) > 0.5 ? 0.6 * sin(2.0 * w + fk) : 0.0;
        float swing = (sin(w) + limp) / (1.0 + abs(limp) * 0.5);
        float d, x;
        if (view < 2)
        {
            float f = loopFreq(1.0 / (ZOMBIE_TRIP * lerp(0.8, 1.25, hash(fk * 2.9))));
            d = frac(T * f + hash(fk * 6.1));                       // 0 on the horizon, 1 at the front
            float p0 = d * d;
            float drift = view == 1 ? (goLeft ? -ZOMBIE_DRIFT : ZOMBIE_DRIFT) * (p0 - 0.5) : 0.0;
            x = grid.x * (0.5 + (hash(fk * 4.3) - 0.5) * (0.45 + 1.1 * p0) + drift);
        }
        else
        {
            // side on: it keeps its distance and crosses at the pace its feet set, so they never slide
            d = lerp(0.25, 0.75, hash(fk * 6.1));
            float scS = lerp(ZOMBIE_FAR, ZOMBIE_NEAR, d * d);
            float f = loopFreq(ZOMBIE_STRIDE * scS * loopRate(stepRate) / TAU / (grid.x * 1.3));
            float u = frac(T * f + hash(fk * 4.3));
            x = grid.x * lerp(-0.15, 1.15, goLeft ? 1.0 - u : u);
        }
        float p  = d * d;                                           // perspective: slow far away, quick up close
        if (p < best) continue;
        float sc = lerp(ZOMBIE_FAR, ZOMBIE_NEAR, p);
        float feet = horizonY + 1.0 + (grid.y + ZH * ZOMBIE_NEAR * 0.6 - horizonY) * p;
        // a mindless lurch: the body swings to one side and leans into it (side on, it rocks to and fro)
        float lean = swing * ZOMBIE_LEAN * lerp(0.5, 1.4, hash(fk * 8.2)) * (view == 2 ? 0.4 : 1.0);
        x += swing * ZOMBIE_SWAY * lerp(0.5, 1.4, hash(fk * 9.4)) * sc * (view == 2 ? 0.2 : 1.0);
        float2 at = float2(x - ZW * sc * 0.5, feet - ZH * sc);
        float2 l = float2(float(cell.x) - at.x - lean * (feet - float(cell.y)), float(cell.y) - at.y) / sc;
        if (l.x < 0 || l.y < 0 || l.x >= ZW || l.y >= ZH) continue;
        int2 s = int2(l);
        if (goLeft) s.x = ZW - 1 - s.x;                             // the drawings walk to the right
        int frame = pmod((int)floor(w / TAU * ZOMBIE_FRAMES), ZOMBIE_FRAMES);
        int row = Z_Y + ((view * 2 + arms) * 2 + (k & 1)) * ZH;
        float4 t = texel(frame * ZW + s.x, row + s.y);
        if (t.w == 0) continue;
        best = p;
        feetOut = feet;
        float3 c = SILHOUETTE + t.rgb * (ZOMBIE_AMBIENT + flash * 1.1);
        int2 sr = int2(clamp(s.x + (goLeft ? -1 : 1), 0, ZW - 1), s.y);
        if (texel(frame * ZW + sr.x, row + sr.y).w == 0 || s.y == 0 ||
            texel(frame * ZW + s.x, row + max(s.y - 1, 0)).w == 0)
            c += RIM_COLOUR;
        z = lerp(c, FOG_COLOUR * (1.0 + flash * 2.5), (1.0 - d) * ZOMBIE_HAZE);
    }
    return best >= 0.0 ? z : col;
}

// the hut's place on screen: top-left corner, scale, and the line its stilts stand on
void hutPlace(float2 grid, float horizonY, out float2 at, out float sc, out float base)
{
    sc = grid.y * HUT_SIZE / HUTH;
    base = horizonY + (grid.y - horizonY) * HUT_DEPTH;
    at = float2(grid.x * HUT_POS - HUTW * sc * 0.5, base - HUTH * sc);
}

float windowFlicker(float T)
{
    return 0.85 + 0.15 * sin(T * loopRate(2.3)) * sin(T * loopRate(0.7) + 1.0);
}

// the potion brewing inside: drifting slowly from one colour to the next, bubbling as it goes
float3 brewColour(float T)
{
    float f = loopFreq(1.0 / BREW_CHANGE);
    float p = T * f;
    int i = pmod((int)floor(p), 4);
    float3 c = lerp(BREW_COLOURS[i], BREW_COLOURS[(i + 1) % 4], smoothstep(0.6, 1.0, frac(p)));
    float bubble = 0.85 + 0.15 * noise1(T * 6.0) * noise1(T * 2.3 + 4.0);
    return c * bubble * windowFlicker(T);
}

// a bang in the hut at time t: rgb its colour, a how bright it is now. `smoke` instead asks how much
// of the chimney smoke leaving at t still carries a bang's colour.
float4 burstAt(float t, bool smoke)
{
    float f = loopFreq(1.0 / BURST_GAP);
    float gap = 1.0 / f;
    float4 r = 0;
    [loop] for (int j = 0; j < 2; j++)
    {
        float slot = floor(t * f) - j;
        float id = loopIndex(slot, f);
        if (hash(id * 1.37 + 0.5) > BURST_CHANCE) continue;
        float a = t - (slot * gap + hash(id * 2.11) * gap * 0.5);   // seconds since it went off
        if (a < 0.0) continue;
        float3 c = hash(id * 3.7) < 0.5 ? BURST_PURPLE : BURST_PINK;
        float e;
        if (smoke)
            e = smoothstep(0.0, BURST_SMOKE * 0.4, a) * (1.0 - smoothstep(BURST_SMOKE * 0.4, BURST_SMOKE, a));   // fades in and out of the grey
        else
        {
            // three quick pops, each a sharp flash that dies away, the middle one strongest
            float p1 = 0.10 + 0.08 * hash(id * 5.3), p2 = 0.30 + 0.25 * hash(id * 6.1);
            e = exp(-a * 14.0) * 0.8;
            if (a > p1) e = max(e, exp(-(a - p1) * 10.0));
            if (a > p2) e = max(e, exp(-(a - p2) * 12.0) * 0.7);
            e *= 0.75 + 0.25 * step(0.5, frac(a * 23.0));          // a crackle in it
        }
        if (e > r.a) r = float4(c, e);
    }
    return r;
}

float3 drawHut(float3 col, int2 cell, float2 grid, float T, float flash, float fog, float horizonY, float zFeet, float dth)
{
    float2 at; float sc, base;
    hutPlace(grid, horizonY, at, sc, base);
    float3 brew = brewColour(T);
    float4 bang = burstAt(T, false);
    float3 light = brew + bang.rgb * bang.a * BURST_GLOW;
    // the window's light spilling onto the ground in front
    float2 win = at + float2(45.0, 71.0) * sc;
    float l = saturate(1.0 - length((float2(cell) - float2(win.x, base)) / (float2(40.0, 9.0) * sc)));
    if (cell.y > base - 2.0 * sc) col += light * steps(l * l, 4.0, dth) * 0.12;
    // a bang throws its light all round the hut, on the ground, the hills and the sky
    float lb = saturate(1.0 - length(float2(cell) - win) / (BURST_REACH * sc));
    col += bang.rgb * steps(lb * lb * bang.a, 5.0, dth) * 0.35;
    if (zFeet > base) return col;                                 // a zombie in front of the hut
    float4 t = sprite(cell, at, sc, HUT_X, 0, HUTW, HUTH, false);
    if (t.w == 0) return col;
    if (t.r > 0.9 && abs(t.b - 9.0 / 255.0) < 0.5 / 255.0)
        return light * t.g * 1.4;
    float3 h = t.rgb * (HUT_DARK + flash * 0.9) + bang.rgb * bang.a * lb * 0.5;
    return lerp(h, FOG_COLOUR * (1.0 + flash * 2.5), fog * 0.5);
}

// smoke curling out of the chimney and blown to the left by the wind
float3 drawSmoke(float3 col, int2 cell, float2 grid, float T, float flash, float horizonY, float dth)
{
    float2 at; float sc, base;
    hutPlace(grid, horizonY, at, sc, base);
    float2 top = at + float2(97.0, 14.0) * sc;
    float2 c = float2(cell) + 0.5;
    // a column of smoke that widens as it rises and bends to the left in the wind, filled with
    // drifting lumps (noise scrolling upwards), thinning out towards the top
    float h = (top.y - c.y) / (SMOKE_HEIGHT * sc);      // 0 at the chimney, 1 where it is gone
    if (h < -0.05 || h > 1.0) return col;
    // the smoke here left the chimney this long ago (the lumps climb 32 * SMOKE_RISE hut pixels a second);
    // smoke that left just after a bang carries the bang's colour, and billows out a little more
    float4 tint = burstAt(T - h * SMOKE_HEIGHT / (32.0 * SMOKE_RISE), true);
    float mid = top.x - h * h * h * 70.0 * sc;
    float halfw = (2.5 + h * 10.0) * sc * (1.0 + 0.4 * tint.a);
    float across = abs(c.x - mid) / halfw;
    if (across > 1.3) return col;
    float lumps = noise2(float2(c.x / (4.0 * sc), (c.y / (4.0 * sc)) + T * loopRate(SMOKE_RISE * TAU) / TAU * 8.0));
    float dens = ((1.0 - across) * 1.3 + (lumps - 0.5) * 1.2 - h * 0.9 + tint.a * 0.3) * (1.0 - smoothstep(0.55, 1.0, h));
    if (dens < 0.15 || dth > dens * 1.6) return col;
    float3 smoke = lerp(SMOKE_COLOUR, tint.rgb * 0.75, steps(saturate(tint.a * 1.3), 4.0, dth));
    return lerp(col, smoke * (1.0 + flash * 2.0) * (1.0 - h * 0.4), 0.85);
}

float3 drawPorchPumpkins(float3 col, int2 cell, float2 grid, float T, int tick, float flash, float horizonY, float dth)
{
    float2 at; float sc, base;
    hutPlace(grid, horizonY, at, sc, base);
    float ps = sc * PORCH_PK_SCALE;
    [loop] for (int k = 0; k < 2; k++)
    {
        float2 foot = at + float2(PORCH_PK_X[k], 100.0) * sc;
        col = pumpkinHalo(col, cell, foot - float2(0, PKH * ps * 0.4), HALO_SIZE * ps * 2.5 * float2(1.0, 0.75), 10 + k, T, dth);
        col = drawPumpkin(col, cell, foot, ps, k == 0 ? 1 : 2, 10 + k, T, tick, flash, k == 1);
    }
    return col;
}

// where spider k on the glass is at time T. Its path is a few slow waves added together, so it always
// curves gently into each new direction instead of stopping to spin round; it speeds up and slows
// down as it goes. It only visits now and then: it comes in from beyond the nearest edge, roams, and
// heads back out. `on` is false while it is away.
float2 crawlerPos(int k, float T, float2 grid, out bool on)
{
    float fk = (float)k;
    float wv = loopRate(0.36);
    float t  = T + 2.0 * sin(T * wv + fk * 2.0);                  // 2 s * 0.36 < 1, so it never runs backwards
    float2 pos = 0.5;
    [unroll] for (int i = 0; i < 3; i++)
    {
        float fi = (float)i;
        float2 rate = CRAWL_SPEED * float2(1.0 + 0.9 * fi + 0.3 * hash(fk * 3.1 + fi), 0.8 + 1.1 * fi + 0.3 * hash(fk * 4.7 + fi));
        rate = float2(loopRate(rate.x), loopRate(rate.y));
        float2 ph = float2(hash(fk * 5.9 + fi), hash(fk * 6.7 + fi)) * TAU;
        pos += CRAWL_ROAM * float2(0.55, 0.45) / (1.0 + fi * 0.8) * sin(rate * t + ph);
    }
    float f = loopFreq(1.0 / CRAWL_CYCLE);
    float a = frac(T * f + 0.5 * fk) / f;                          // seconds into its own cycle
    on = a < CRAWL_VISIT;
    float away = 1.0 - smoothstep(0.0, CRAWL_ENTER, a) + smoothstep(CRAWL_VISIT - CRAWL_ENTER, CRAWL_VISIT, a);
    float2 outward = normalize(pos - 0.5 + float2(1e-3, 0.0));
    return (pos + outward * away * 0.9) * grid;
}

float3 drawCrawlers(float3 col, int2 cell, float2 grid, float T, int tick, float flash)
{
    [loop] for (int k = 0; k < CRAWLERS; k++)
    {
        bool on = false;
        float2 pos = 0, before = 0;
        [loop] for (int w = 0; w < 2; w++)                         // now, and a moment ago (for its heading)
        {
            bool o;
            float2 q = crawlerPos(k, T - 0.1 * w, grid, o);
            if (w == 0) { pos = q; on = o; } else before = q;
        }
        if (!on) continue;
        float2 dir = normalize(pos - before + float2(0.0, -1e-4));
        int frame = pmod(tick * 2 + k, 4);                         // quick little legs
        float4 s = spriteTurned(cell, pos, -dir, float2(20.0, 22.0), CRAWL_SCALE, frame * SW, S_Y, SW, SH);
        // lit from behind by the scene, so mostly dark; a flash turns it into a black shape
        if (s.w > 0) col = s.rgb * (0.85 - flash * 0.75);
    }
    return col;
}

// a point along a curve from a through b (pulled towards, not passing) to c, and which way it heads
float2 bezier(float2 a, float2 b, float2 c, float u, out float2 dir)
{
    dir = normalize(lerp(b - a, c - b, u) + float2(1e-4, 0.0));
    return lerp(lerp(a, b, u), lerp(b, c, u), u);
}

// small spiders on the big corner pumpkins: up from the ground into a mouth, a little while inside,
// then out of an eye socket and away over the top
float3 drawPumpkinSpiders(float3 col, int2 cell, float2 grid, float T, int tick, float flash)
{
    [loop] for (int j = 0; j < PK_SPIDERS; j++)
    {
        float fj = (float)j;
        float f = loopFreq(1.0 / PKSP_CYCLE);
        float p = T * f + 0.5 * fj;
        float id = loopIndex(floor(p), f) + fj * 31.0;
        float a = frac(p) / f;                                      // seconds into this trip
        int k = (int)(hash(id * 1.9) * 2.99);                      // the three biggest pumpkins
        int row = PK_ROW[k];
        bool nearEye = hash(id * 2.7) < 0.65;
        float2 eyeMid = nearEye ? PK_EYE[row] : PK_EYE_FAR[row];
        float2 eye = nearEye ? PK_EYE_EDGE[row] : PK_EYE_FAR_EDGE[row];
        float2 mouth = PK_MOUTH_EDGE[row];
        float2 mouthIn = lerp(mouth, PK_MOUTH[row], 0.35);          // a little way in past the edge
        float2 eyeIn = lerp(eye, eyeMid, 0.35);
        // the path, in sheet pixels of the pumpkin's drawing (face looking left)
        float2 at = 0, dir = float2(0.0, -1.0);
        float size = 1.0;
        float tIn = PKSP_WALK_IN, tSq = tIn + PKSP_SQUEEZE, tOut = tSq + PKSP_INSIDE, tOut2 = tOut + PKSP_SQUEEZE;
        // in from the ground beside the pumpkin, up its side to the corner of the mouth, and in
        float2 from = float2(-14.0, 78.0), bend = float2(mouth.x - 16.0, mouth.y + 6.0);
        float2 up = float2(eye.x + 20.0, eye.y - 26.0), away = float2(112.0, 20.0);
        // each stretch is a curve p0 -> p1 -> p2 (a straight squeeze is a curve with its middle halfway)
        float2 p0 = 0, p1 = 0, p2 = 0;
        float u = 0.0;
        if (a < tIn)              { p0 = from; p1 = bend; p2 = mouth; u = smoothstep(0.0, 1.0, a / tIn) * 0.6 + a / tIn * 0.4; }
        else if (a < tSq)         { p0 = mouth; p1 = (mouth + mouthIn) * 0.5; p2 = mouthIn; u = (a - tIn) / PKSP_SQUEEZE; size = 1.0 - u; }  // squeezing in past the edge
        else if (a < tOut) continue;                                // inside the pumpkin
        else if (a < tOut2)       { p0 = eyeIn; p1 = (eyeIn + eye) * 0.5; p2 = eye; u = (a - tOut) / PKSP_SQUEEZE; size = u; }          // climbing out over the rim
        else if (a < tOut2 + PKSP_WALK_OUT) { p0 = eye; p1 = up; p2 = away; u = (a - tOut2) / PKSP_WALK_OUT; }
        else continue;
        at = bezier(p0, p1, p2, u, dir);
        // onto the screen: the left group is mirrored so their faces look right
        float2 foot; float sc;
        pumpkinPlace(k, grid, foot, sc);
        bool mirror = PK_SIDE[k] < 0;
        if (mirror) { at.x = BPW - at.x; dir.x = -dir.x; }
        float2 screen = foot - float2(BPW * sc * 0.5, BPH * sc) + at * sc;
        float s = sc * PKSP_SCALE * size;
        if (s < 0.05) continue;
        bool moving = size >= 1.0;
        int frame = moving ? pmod(tick * 2 + j, 4) : pmod(tick / 2 + j, 4);
        float4 t = spriteTurned(cell, screen, -dir, float2(20.0, 22.0), s, frame * SW, S_Y, SW, SH);
        // dark against the candle glow, its edge caught by the light from the holes
        if (t.w > 0) col = t.rgb * (0.55 + flash * 0.4) + CANDLE_DEEP * 0.06 * candle(k, T);
    }
    return col;
}
