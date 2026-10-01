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

float3 drawGhost(float3 col, int2 cell, float2 grid, float T, float alpha, float flash, float dth)
{
    if (alpha <= 0.0) return col;
    float h = grid.y * GHOST_HEIGHT;
    float2 crown = float2(grid.x * 0.5 + sin(T * loopRate(0.31)) * grid.x * 0.025,
                          grid.y * GHOST_TOP + sin(T * loopRate(0.9)) * 2.5);
    float2 p = (float2(cell) + 0.5 - crown) / h;
    if (p.x < -0.75 || p.x > 0.45 || p.y < -0.05 || p.y > 1.15) return col;
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
        if (aura && dth < alpha * 0.6) col += float3(0.05, 0.06, 0.10) * (1.0 + flash);
        return col;
    }
    // appear and vanish as a dissolve, not a fade, to keep it pixel-art
    if (dth > alpha) return col;
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
    g *= 1.0 + flash * 0.4;
    return lerp(col, g, GHOST_OPACITY);
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
        float f  = loopFreq(1.0 / (ZOMBIE_TRIP * lerp(0.8, 1.25, hash(fk * 2.9))));
        float d  = frac(T * f + hash(fk * 6.1));                    // 0 on the horizon, 1 at the front
        float p  = d * d;                                           // perspective: slow far away, quick up close
        if (p < best) continue;
        float sc = lerp(ZOMBIE_FAR, ZOMBIE_NEAR, p);
        float feet = horizonY + 1.0 + (grid.y + ZH * ZOMBIE_NEAR * 0.6 - horizonY) * p;
        // a mindless lurch: the body swings to one side and leans into it, then to the other
        // every zombie sways its own way: some barely, some wildly, some dragging a leg (a lopsided lurch)
        float w  = T * loopRate(ZOMBIE_LURCH * TAU * 0.5 * lerp(0.55, 1.5, hash(fk * 5.5))) + fk * 2.0;
        float limp = hash(fk * 3.3) > 0.5 ? 0.6 * sin(2.0 * w + fk) : 0.0;
        float swing = (sin(w) + limp) / (1.0 + abs(limp) * 0.5);
        float lean = swing * ZOMBIE_LEAN * lerp(0.3, 1.9, hash(fk * 8.2));
        float x  = grid.x * (0.5 + (hash(fk * 4.3) - 0.5) * (0.45 + 1.1 * p)) + swing * ZOMBIE_SWAY * lerp(0.2, 2.2, hash(fk * 9.4)) * sc;
        float bob = abs(cos(w)) * 1.2 * sc;
        float2 at = float2(x - ZW * sc * 0.5, feet - ZH * sc + bob);
        float2 l = float2(float(cell.x) - at.x - lean * (feet - float(cell.y)), float(cell.y) - at.y) / sc;
        if (l.x < 0 || l.y < 0 || l.x >= ZW || l.y >= ZH) continue;
        int2 s = int2(l);
        if (hash(fk * 7.0) > 0.5) s.x = ZW - 1 - s.x;
        int frame = pmod(tick / 5 + k * 3, 4);
        float4 t = texel(frame * ZW + s.x, Z_Y + (k & 1) * ZH + s.y);
        if (t.w == 0) continue;
        best = p;
        feetOut = feet;
        float3 c = SILHOUETTE + t.rgb * flash * 1.1;
        int2 sr = int2(clamp(s.x + (hash(fk * 7.0) > 0.5 ? -1 : 1), 0, ZW - 1), s.y);
        if (texel(frame * ZW + sr.x, Z_Y + (k & 1) * ZH + sr.y).w == 0 || s.y == 0 ||
            texel(frame * ZW + s.x, Z_Y + (k & 1) * ZH + max(s.y - 1, 0)).w == 0)
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

float3 drawHut(float3 col, int2 cell, float2 grid, float T, float flash, float fog, float horizonY, float zFeet, float dth)
{
    float2 at; float sc, base;
    hutPlace(grid, horizonY, at, sc, base);
    // the window's green light spilling onto the ground in front
    float2 win = at + float2(45.0, 71.0) * sc;
    float l = saturate(1.0 - length((float2(cell) - float2(win.x, base)) / (float2(40.0, 9.0) * sc)));
    if (cell.y > base - 2.0 * sc) col += WINDOW_COLOUR * steps(l * l, 4.0, dth) * 0.12 * windowFlicker(T);
    if (zFeet > base) return col;                                 // a zombie in front of the hut
    float4 t = sprite(cell, at, sc, HUT_X, 0, HUTW, HUTH, false);
    if (t.w == 0) return col;
    if (t.r > 0.9 && abs(t.b - 9.0 / 255.0) < 0.5 / 255.0)
        return WINDOW_COLOUR * t.g * windowFlicker(T) * 1.4;
    float3 h = t.rgb * (HUT_DARK + flash * 0.9);
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
    float h = (top.y - c.y) / (80.0 * sc);              // 0 at the chimney, 1 where it is gone
    if (h < -0.05 || h > 1.0) return col;
    float mid = top.x - h * h * h * 70.0 * sc;
    float halfw = (2.5 + h * 10.0) * sc;
    float across = abs(c.x - mid) / halfw;
    if (across > 1.3) return col;
    float lumps = noise2(float2(c.x / (4.0 * sc), (c.y / (4.0 * sc)) + T * loopRate(SMOKE_RISE * TAU) / TAU * 8.0));
    float dens = (1.0 - across) * 1.3 + (lumps - 0.5) * 1.2 - h * 0.9;
    if (dens < 0.15 || dth > dens * 1.6) return col;
    return lerp(col, SMOKE_COLOUR * (1.0 + flash * 2.0) * (1.0 - h * 0.4), 0.85);
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

float3 drawHangers(float3 col, int2 cell, float2 grid, float T, int tick, float flash)
{
    float2 c = float2(cell) + 0.5;
    [loop] for (int k = 0; k < HANGERS; k++)
    {
        float fk = (float)k;
        float f  = loopFreq(1.0 / (HANG_CYCLE * lerp(0.8, 1.2, hash(fk * 3.0))));
        float ph = frac(T * f + 0.5 * fk + 0.1);
        float n  = loopIndex(floor(T * f + 0.5 * fk + 0.1), f);
        float cyc = 1.0 / f;
        float t  = ph * cyc;
        float len = grid.y * lerp(0.22, 0.48, hash(n * 2.3 + fk));
        float l = 0.0;
        if (t < 3.0)        l = len * (1.0 - pow(1.0 - t / 3.0, 3.0)) * (1.0 + 0.10 * sin(t * 9.0) * (t / 3.0)); // drop, with a bounce
        else if (t < 12.0)  l = len * (1.0 + 0.04 * sin(t * 4.0) * exp(-(t - 3.0)));
        else if (t < 16.5)  l = len * (1.0 - (t - 12.0) / 4.5);                                                // climb back up
        else continue;
        float swing = 0.30 * sin(t * 1.7 + fk) * exp(-max(t - 3.0, 0.0) * 0.15) * saturate(t / 2.0);
        float2 anchor = float2(grid.x * (0.12 + 0.76 * hash(n * 5.1 + fk * 11.0)), -1.0);
        float2 down = float2(sin(swing), cos(swing));
        float2 body = anchor + down * l;
        // the thread
        float2 pa = c - anchor;
        float h = saturate(dot(pa, down) / max(l, 1.0));
        if (length(pa - down * h * l) < 0.55 && h < 1.0) col = lerp(col, THREAD_COLOUR * (1.0 + flash), 0.7);
        float4 s = spriteTurned(cell, body, down, float2(12.0, 1.0), HANG_SCALE, (pmod(tick / 2 + k, 2)) * HW, H_Y, HW, HH);
        if (s.w > 0) col = s.rgb * (0.9 - flash * 0.6);
    }
    return col;
}

// a spider walking about on the inside of the glass: walk a stretch, stop, turn, walk again
float3 drawCrawlers(float3 col, int2 cell, float2 grid, float T, int tick, float flash)
{
    [loop] for (int k = 0; k < CRAWLERS; k++)
    {
        float fk = (float)k;
        float f  = loopFreq(1.0 / (CRAWL_STEP * lerp(0.85, 1.25, hash(fk * 1.1))));
        float span = T * f + hash(fk * 2.2);
        float m  = floor(span);
        float a  = frac(span);
        float m0 = loopIndex(m, f), m1 = loopIndex(m + 1.0, f), m2 = loopIndex(m + 2.0, f);
        // waypoints scattered over the window and a little past its edges, so spiders come and go
        float2 w0 = float2(hash(m0 * 1.3 + fk * 7.0), hash(m0 * 2.9 + fk * 3.0)) * 1.4 - 0.2;
        float2 w1 = float2(hash(m1 * 1.3 + fk * 7.0), hash(m1 * 2.9 + fk * 3.0)) * 1.4 - 0.2;
        float2 w2 = float2(hash(m2 * 1.3 + fk * 7.0), hash(m2 * 2.9 + fk * 3.0)) * 1.4 - 0.2;
        float walk = 0.55;
        float2 pos = lerp(w0, w1, smoothstep(0.0, 1.0, saturate(a / walk))) * grid;
        float2 d0 = normalize((w1 - w0) * grid + 1e-4);
        float2 d1 = normalize((w2 - w1) * grid + 1e-4);
        // turn towards the next stretch at the end of the rest
        float turn = smoothstep(0.80, 1.0, a);
        float2 dir = normalize(lerp(d0, d1, turn) + 1e-4);
        bool moving = a < walk || turn > 0.0;
        int frame = moving ? pmod(tick + k, 4) : 0;
        float4 s = spriteTurned(cell, pos, -dir, float2(20.0, 22.0), CRAWL_SCALE, frame * SW, S_Y, SW, SH);
        // lit from behind by the scene, so mostly dark; a flash turns it into a black shape
        if (s.w > 0) col = s.rgb * (0.85 - flash * 0.75);
    }
    return col;
}

