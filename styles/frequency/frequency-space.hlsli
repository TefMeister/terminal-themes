// Frequency, part 4: the zoom into a far-off grid pattern, and the flight through a gridded
// asteroid field "in the fifth dimension". Included by frequency.hlsl.

static const float  ZOOM_FROM      = 0.03;   // the pattern starts this small (screen cells per unit)...
static const float  ZOOM_TO        = 90.0;   // ...and ends this big
static const float  ZOOM_EXTENT    = 32.0;   // half the size of the pattern, in its own units

static const float  SPACE_CELL     = 8.0;    // the field is a lattice of blocks this many voxels across, each may hold a rock
static const float  SPACE_DENSITY  = 0.45;   // share of blocks with a rock in them
static const float  SPACE_R_MIN    = 1.2;    // rock radius, voxels
static const float  SPACE_R_MAX    = 3.2;
static const float  SPACE_MORPH    = 0.5;    // rocks swell and shrink by this much: the fifth dimension
static const float  SPACE_BUMP     = 0.7;    // how lumpy the rocks are
static const float  SPACE_SPEED    = 9.0;    // voxels per second, flying forward
static const float  SPACE_FOV      = 1.3;
static const int    SPACE_STEPS    = 56;     // how far each ray looks, in voxels stepped through
static const float  SPACE_FAR      = 38.0;   // fog distance
static const float  SPACE_PAN_AT   = 5.0;    // seconds in, the camera starts to look around
static const float  SPACE_PAN      = 2.4;    // how far it turns, radians
static const float  SPACE_GRID_UP  = 16.0;   // grid planes this far above and below
static const float3 SPACE_BG       = float3(0.03, 0.01, 0.07);

float3 zoomScene(float2 c, float2 grid, float t)
{
    float  k    = saturate(t / ZOOM_SEC);
    float  zoom = exp(lerp(log(ZOOM_FROM), log(ZOOM_TO), k * k));
    float2 d    = c + 0.5 - grid * 0.5;
    float2 p    = d / zoom;
    // stars streaking outwards, faster as we dive
    float  a    = atan2(d.y, d.x);
    float  ray  = floor(a * 60.0);
    float  r    = length(d) / grid.y;
    float3 col  = SPACE_BG;
    if (hash(ray) > 0.8 && frac(r * 3.0 - t * (0.3 + 2.5 * k) + hash(ray + 1.0)) < 0.02 + 0.1 * k * k) col = float3(0.8, 0.8, 1.0) * r;
    if (zoom * ZOOM_EXTENT < 2.0)                                   // still a single bright speck
        return length(d) < 1.5 ? hue(frac(t * 2.0)) : col;
    if (any(abs(p) > ZOOM_EXTENT)) return col;
    // a grid inside a grid inside a grid: each level shows up as it gets big enough to see
    col = lerp(col, float3(0.05, 0.0, 0.12), 0.8);
    for (int l = 0; l < 4; l++)
    {
        float  sp = 16.0 / pow(4.0, l);
        float2 gl = abs(frac(p / sp + 0.5) - 0.5) * sp * zoom;
        float  show = saturate((sp * zoom - 3.0) / 12.0);
        if (min(gl.x, gl.y) < 0.7 && show > 0.0) col = lerp(col, hue(frac(l * 0.27 + t * 0.4)), show);
    }
    return col;
}

// is there rock in this voxel? Each lattice block holds at most one rock, kept clear of the
// camera's own lane, swelling and shrinking a little over time
bool rockAt(float3 v, float t, out float3 id)
{
    float3 blk = floor(v / SPACE_CELL);
    id = blk;
    if (blk.x == 0.0 && blk.y == 0.0) return false;
    float3 h = hash3(blk + 0.37);
    if (h.x > SPACE_DENSITY) return false;
    float  r   = SPACE_R_MIN + (SPACE_R_MAX - SPACE_R_MIN) * h.y + SPACE_MORPH * sin(t * 0.9 + h.z * TAU);
    float3 mid = blk * SPACE_CELL + SPACE_CELL * 0.5 + (h.zxy - 0.5) * (SPACE_CELL - 2.0 * SPACE_R_MAX - 1.0);
    return length(v + 0.5 - mid) + hash3(v).x * SPACE_BUMP < r;
}

float3 spaceScene(float2 c, float2 grid, float t)
{
    float2 uv = (c + 0.5 - grid * 0.5) / grid.y;
    float3 rd = normalize(float3(uv * SPACE_FOV, 1.0));
    float  pan   = smoothstep(SPACE_PAN_AT, SPACE_SEC - 1.0, t) * SPACE_PAN;
    float  yaw   = pan + 0.15 * sin(t * 0.4);
    float  pitch = 0.25 * sin(t * 0.33) + 0.35 * sin(pan * 0.5);
    float  roll  = 0.2 * sin(t * 0.5);
    float  cr = cos(roll), sr = sin(roll), cp = cos(pitch), sp = sin(pitch), cy = cos(yaw), sy = sin(yaw);
    rd.xy = float2(rd.x * cr - rd.y * sr, rd.x * sr + rd.y * cr);
    rd.yz = float2(rd.y * cp - rd.z * sp, rd.y * sp + rd.z * cp);
    rd.xz = float2(rd.x * cy + rd.z * sy, -rd.x * sy + rd.z * cy);
    rd += 1e-5;

    float3 ro = float3(SPACE_CELL * 0.5, SPACE_CELL * 0.5, t * SPACE_SPEED);
    float3 v  = floor(ro);
    float3 st = sign(rd);
    float3 tDelta = abs(1.0 / rd);
    float3 tMax   = (st * (v - ro) + st * 0.5 + 0.5) * tDelta;
    float  tHit = -1.0, tCur = 0.0;
    int    axis = 0;
    float3 id = 0;
    [loop] for (int i = 0; i < SPACE_STEPS; i++)
    {
        if (rockAt(v, t, id)) { tHit = tCur; break; }
        if (tMax.x < tMax.y && tMax.x < tMax.z) { v.x += st.x; tCur = tMax.x; tMax.x += tDelta.x; axis = 0; }
        else if (tMax.y < tMax.z)               { v.y += st.y; tCur = tMax.y; tMax.y += tDelta.y; axis = 1; }
        else                                    { v.z += st.z; tCur = tMax.z; tMax.z += tDelta.z; axis = 2; }
    }

    // behind everything: stars and two endless grid planes
    float3 col = SPACE_BG + float3(0.03, 0.0, 0.05) * (1.0 - abs(rd.y));
    if (tHit < 0.0 && hash3(floor(rd * 140.0)).x > 0.996) col = float3(0.7, 0.7, 0.9);
    float plane = rd.y > 0.0 ? ro.y + SPACE_GRID_UP : ro.y - SPACE_GRID_UP;
    float tp = (plane - ro.y) / rd.y;
    if (tp > 0.0 && tp < 400.0)
    {
        float2 hp = (ro + rd * tp).xz;
        float2 gl = abs(frac(hp / 4.0 + 0.5) - 0.5) * 4.0;
        if (min(gl.x, gl.y) < 0.06 + tp * 0.006) col = lerp(hue(frac(hp.y * 0.004 + t * 0.05)) * 0.8, col, saturate(tp / 160.0));
    }
    if (tHit < 0.0) return col;

    // a rock: dark glassy faces with glowing edges, each rock its own shifting colour
    float3 hp = ro + rd * tHit;
    float3 f  = frac(hp);
    float2 fu = axis == 0 ? f.yz : (axis == 1 ? f.xz : f.xy);
    float  e  = min(min(fu.x, 1.0 - fu.x), min(fu.y, 1.0 - fu.y));
    float3 neon = hue(frac(hash3(id).y + t * 0.08 + tHit * 0.01));
    float  shade = axis == 0 ? 0.6 : (axis == 1 ? 1.0 : 0.8);
    float3 rock = e < 0.07 + tHit * 0.004 ? neon * 1.2 : neon * 0.2 * shade + 0.03;
    return lerp(rock, col, saturate(tHit / SPACE_FAR));
}
