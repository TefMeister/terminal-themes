// Halloween: the big trees standing in the field, the spiders that drop from their branches, and the
// purple flowers in the grass. Included by halloween.hlsl after halloween-cast.hlsli; every setting
// lives at the top of halloween.hlsl.

// where big tree i stands: its drawing's top-left corner, its scale, and the ground line under it
void treePlace(int i, float2 grid, float horizonY, out float2 at, out float sc, out float base)
{
    base = horizonY + (grid.y - horizonY) * FT_DEPTH[i];
    sc = FT_HEIGHT[i] * grid.y / BTH;
    at = float2(grid.x * FT_X[i] - BTW * sc * 0.5, base - BTH * sc);
}

float treeBase(int i, float2 grid, float horizonY) { return horizonY + (grid.y - horizonY) * FT_DEPTH[i]; }

// lantern j of big tree i: where its cord ends (the lantern's top), which way it hangs, and its flicker
void lanternAt(int i, int j, float T, float2 at, float sc, out float2 pos, out float2 down, out float fl)
{
    float2 a = BT_ANCHOR[FT_KIND[i] * 4 + LANTERN_ANCHOR[FT_KIND[i] * 2 + j]];
    if (FT_MIRROR[i] != 0) a.x = BTW - a.x;
    float k = (float)(i * 2 + j);
    float swing = LANTERN_SWING * sin(T * loopRate(0.9 + 0.35 * hash(k * 2.1)) + k * 1.7);
    down = float2(sin(swing), cos(swing));
    pos = at + a * sc + down * LANTERN_CORD * sc;
    fl = candle(20 + i * 2 + j, T);
}

// the warm light both lanterns of tree i throw on this cell
float3 lanternLight(float2 c, int i, float T, float2 at, float sc)
{
    float3 L = 0;
    [loop] for (int j = 0; j < 2; j++)
    {
        float2 pos, down; float fl;
        lanternAt(i, j, T, at, sc, pos, down, fl);
        float l = saturate(1.0 - length(c - (pos + down * 3.5 * sc)) / (LANTERN_REACH * sc));
        L += LANTERN_COLOUR * fl * l * l;
    }
    return L;
}

// one big tree: a black shape with a moonlit edge in the dark; a lightning flash shows its bark, and
// the lanterns light it warmly close by. Its few leaves keep a little of their colour even in the dark.
float3 drawBigTree(float3 col, int2 cell, float2 grid, float horizonY, int i, float flash, float T)
{
    float2 at; float sc, base;
    treePlace(i, grid, horizonY, at, sc, base);
    float3 L = lanternLight(float2(cell) + 0.5, i, T, at, sc);
    bool mirror = FT_MIRROR[i] != 0;
    int sx = FT_KIND[i] * BTW;
    float4 t = sprite(cell, at, sc, sx, BT_Y, BTW, BTH, mirror);
    if (t.w == 0) return col;
    float haze = (1.0 - FT_DEPTH[i]) * TREE_HAZE;
    float3 fogLit = FOG_COLOUR * (1.0 + flash * 2.5);
    if (abs(t.b - 5.0 / 255.0) < 0.5 / 255.0)                     // a leaf
        return lerp(t.rgb * (LEAF_AMBIENT + flash * 1.1 + L * LANTERN_BARK), fogLit, haze);
    float3 c = SILHOUETTE + t.rgb * (flash * TREE_BARK + L * LANTERN_BARK);
    // the moon catches the right-hand edge of every limb
    if (sprite(cell + int2(1, 0), at, sc, sx, BT_Y, BTW, BTH, mirror).w == 0) c += RIM_COLOUR;
    return lerp(c, fogLit, haze);
}

// the lanterns of tree i: a small metal cap and base, glowing glass between, on a short cord, with a
// soft glow in the air round each
float3 drawLanterns(float3 col, int2 cell, float2 grid, float T, int i, float horizonY, float dth)
{
    float2 at; float sc, base;
    treePlace(i, grid, horizonY, at, sc, base);
    float2 c = float2(cell) + 0.5;
    [loop] for (int j = 0; j < 2; j++)
    {
        float2 pos, down; float fl;
        lanternAt(i, j, T, at, sc, pos, down, fl);
        float2 q = c - pos;
        float2 right = float2(down.y, -down.x);
        float lx = dot(q, right) / sc, ly = dot(q, down) / sc;      // lantern pixels: across, and down from its top
        float halo = saturate(1.0 - length(q - down * 3.5 * sc) / (LANTERN_REACH * 0.55 * sc));
        col += LANTERN_COLOUR * steps(halo * halo, 4.0, dth) * LANTERN_HALO * fl;
        if (ly >= -LANTERN_CORD && ly < 0.0 && abs(lx) < 0.4) col = float3(0.06, 0.05, 0.04);           // the cord
        else if (ly >= 0.0 && ly < 1.3 && abs(lx) < 1.7) col = float3(0.10, 0.08, 0.06) + LANTERN_COLOUR * 0.15 * fl;  // cap
        else if (ly >= 1.3 && ly < 6.0 && abs(lx) < 2.3)
        {
            if (abs(lx) > 1.8 || abs(ly - 3.6) < 0.35) col = float3(0.12, 0.09, 0.06);    // the frame
            else col = lerp(LANTERN_COLOUR, float3(1.0, 0.93, 0.70), saturate(1.2 - length(float2(lx, ly - 3.6)) * 0.5)) * (1.2 + 0.4 * fl);
        }
        else if (ly >= 6.0 && ly < 7.0 && abs(lx) < 1.7) col = float3(0.10, 0.08, 0.06) + LANTERN_COLOUR * 0.2 * fl; // base
    }
    return col;
}

// spiders letting themselves down on a thread from the big trees' branches: a quick drop with a
// bounce, a slow swing, then the climb back up. Each drop picks a tree and a branch; the spider and
// its thread are as big as that tree is near, and they hang in front of it.
float3 drawTreeHangers(float3 col, int2 cell, float2 grid, float T, int tick, float flash, float horizonY, int tree)
{
    float2 c = float2(cell) + 0.5;
    float2 at; float sc, base;
    treePlace(tree, grid, horizonY, at, sc, base);
    bool mirror = FT_MIRROR[tree] != 0;
    [loop] for (int k = 0; k < HANGERS; k++)
    {
        float fk = (float)k;
        float f  = loopFreq(1.0 / (HANG_CYCLE * lerp(0.8, 1.2, hash(fk * 3.0))));
        float ph = frac(T * f + fk / HANGERS + 0.1);
        float n  = loopIndex(floor(T * f + fk / HANGERS + 0.1), f) + fk * 17.0;
        if (pmod((int)(hash(n * 1.3) * 2.99 + fk), FG_TREES) != tree) continue;
        int ai = (int)(hash(n * 4.1) * 3.99);
        float2 anchor = BT_ANCHOR[FT_KIND[tree] * 4 + ai];
        if (ai == LANTERN_ANCHOR[FT_KIND[tree] * 2] || ai == LANTERN_ANCHOR[FT_KIND[tree] * 2 + 1])
            anchor.x += 7.0;                                        // drop beside the lantern, not through it
        if (mirror) anchor.x = BTW - anchor.x;
        float2 top = at + anchor * sc;
        float t  = ph / f;
        float len = (BTH - anchor.y) * sc * lerp(0.35, 0.80, hash(n * 2.3));
        float l = 0.0;
        if (t < 3.0)        l = len * (1.0 - pow(1.0 - t / 3.0, 3.0)) * (1.0 + 0.10 * sin(t * 9.0) * (t / 3.0)); // drop, with a bounce
        else if (t < 12.0)  l = len * (1.0 + 0.04 * sin(t * 4.0) * exp(-(t - 3.0)));
        else if (t < 16.5)  l = len * (1.0 - (t - 12.0) / 4.5);                                                // climb back up
        else continue;
        float swing = 0.30 * sin(t * 1.7 + fk) * exp(-max(t - 3.0, 0.0) * 0.15) * saturate(t / 2.0);
        float2 down = float2(sin(swing), cos(swing));
        float2 body = top + down * l;
        float2 pa = c - top;
        float h = saturate(dot(pa, down) / max(l, 1.0));
        float3 L = lanternLight(c, tree, T, at, sc);
        if (length(pa - down * h * l) < 0.55 && h < 1.0) col = lerp(col, THREAD_COLOUR * (1.0 + flash + L * 2.0), 0.7);
        float4 s = spriteTurned(cell, body, down, float2(12.0, 1.0), sc * HANG_SCALE, (pmod(tick / 2 + k, 2)) * HW, H_Y, HW, HH);
        if (s.w > 0) col = s.rgb * (0.9 - flash * 0.6 + L * LANTERN_SPIDER);   // lit up passing a lantern
    }
    return col;
}

// little purple flowers in clumps on the field: the first few round the big trees and by the hut,
// the rest scattered. Nearer clumps are drawn bigger. They keep some colour in the dark.
float3 drawFlowers(float3 col, int2 cell, float2 grid, float horizonY, float flash)
{
    float2 c = float2(cell) + 0.5;
    float field = grid.y - horizonY;
    float d = (c.y - horizonY) / max(field, 1.0);
    [loop] for (int i = 0; i < FLOWER_PATCHES; i++)
    {
        float fi = (float)i;
        float px, pd;                                               // where the clump is: across, and depth
        if (i < 2 * FG_TREES)
        {
            int t = i % FG_TREES;
            px = FT_X[t] + (i < FG_TREES ? -0.05 : 0.045) * (0.6 + FT_HEIGHT[t]);
            pd = FT_DEPTH[t] + 0.01;
        }
        else if (i < 2 * FG_TREES + 2)
        {
            px = HUT_POS + (i == 2 * FG_TREES ? -0.09 : 0.12);
            pd = HUT_DEPTH + 0.02;
        }
        else
        {
            px = 0.04 + 0.92 * hash(fi * 3.1);
            pd = lerp(0.05, 0.92, hash(fi * 5.7));
        }
        float fp = lerp(0.6, 3.2, pd * pd);                          // flower pixel size here
        float2 centre = float2(px * grid.x, horizonY + field * pd);
        float2 q = c - centre;
        if (abs(q.x) > fp * 12.0 || q.y < -fp * 6.0 || q.y > fp * 3.0) continue;
        int n = 3 + (int)(hash(fi * 7.3) * 4.0);
        [loop] for (int j = 0; j < n; j++)
        {
            float fj = (float)j;
            float2 o = float2((hash(fi * 11.0 + fj) - 0.5) * 20.0, (hash(fi * 13.0 + fj) - 0.5) * 4.0);
            float stemH = 2.0 + floor(hash(fi * 17.0 + fj) * 3.0);
            float2 l = (q - o * fp) / fp + float2(0.0, stemH);        // the head's top-left at 0
            float3 petal = lerp(FLOWER_DEEP, FLOWER_LIGHT, hash(fi * 19.0 + fj));
            float lit = FLOWER_AMBIENT + flash * 1.2;
            if (l.x >= -1.0 && l.x < 1.0 && l.y >= -1.0 && l.y < 1.0)
                return ((fp > 2.0 && abs(l.x + 0.0) < 0.5 && abs(l.y) < 0.5) ? FLOWER_EYE : petal) * lit;
            if (abs(l.x) < 0.5 && l.y >= 1.0 && l.y < 1.0 + stemH)
                return STEM_COLOUR * lit;
        }
    }
    return col;
}
