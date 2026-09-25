#include <metal_stdlib>
using namespace metal;
constant float PI = 3.14159265;
constant int MAX_STEPS = 220;
constexpr sampler nearestSampler(coord::normalized, address::clamp_to_edge, filter::nearest);
float mod(float x, float y) { return x - y * floor(x / y); }
struct Uniforms {
    float4 res, cam, forward, right, up, fov, origin, time, target;
};
struct Trace {
    constant Uniforms& u;
    texture2d<float> uVox0;
    texture2d<float> uVox1;
    texture2d<float> uVox2;
    texture2d<float> uVox3;
    texture2d<float> uTiles;
    texture2d<float> uAtlas;
    texture2d<float> uEntities;
float4 vox(float3 p) {
  if (p.y < 0.0) return float4(14.0 / 255.0, 0.0, 0.0, 1.0);
  if (p.y > 63.0 || p.x < 0.0 || p.x > 127.0 || p.z < 0.0 || p.z > 127.0) {
    return float4(0.0, 1.0, 0.0, 1.0);
  }
  float qx = step(64.0, p.x);
  float qz = step(64.0, p.z);
  float2 local = float2(p.x - 64.0 * qx, p.z - 64.0 * qz);
  float sx = mod(p.y, 8.0);
  float sy = floor(p.y / 8.0);
  float2 uv = (float2(sx * 64.0, sy * 64.0) + local + 0.5) / 512.0;
  if (qx < 0.5) {
    if (qz < 0.5) return uVox0.sample(nearestSampler, uv);
    return uVox1.sample(nearestSampler, uv);
  }
  if (qz < 0.5) return uVox2.sample(nearestSampler, uv);
  return uVox3.sample(nearestSampler, uv);
}

float voxId(float3 p) { return floor(vox(p).r * 255.0 + 0.5); }

float4 tileInfo(float id) {
  float u = (id + 0.5) / 256.0;
  float4 t = uTiles.sample(nearestSampler, float2(u, 0.25));
  float flag = uTiles.sample(nearestSampler, float2(u, 0.75)).r;
  return float4(t.rgb, flag);
}

float4 atlas(float tile, float2 uv) {
  uv = clamp(uv, 0.0, 0.999);
  float2 tileOrigin = float2(mod(tile, 16.0), floor(tile / 16.0)) * 16.0;
  float2 px = tileOrigin + floor(uv * 16.0) + 0.5;
  return uAtlas.sample(nearestSampler, px / float2(256.0, 80.0));
}

float lightAt(float3 p, float dayLight) {
  float4 v = vox(p);
  float sky = v.g;
  float blk = v.b;
  float l = max(sky * dayLight, blk);
  return l;
}

float hash12(float2 p) {
  float3 p3 = fract(float3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float vnoise(float2 p) {
  float2 i = floor(p);
  float2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float a = hash12(i);
  float b = hash12(i + float2(1.0, 0.0));
  float c = hash12(i + float2(0.0, 1.0));
  float d = hash12(i + float2(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float3 sunDir() {
  float a = u.time.x * 2.0 * PI;
  return normalize(float3(cos(a) * 0.55, sin(a), 0.35));
}

float dayLightAmount() {
  float e = sin(u.time.x * 2.0 * PI);
  return clamp(e * 2.4 + 0.25, 0.06, 1.0);
}

float3 skyColor(float3 d, float dayLight) {
  float e = sin(u.time.x * 2.0 * PI);
  float3 dayZenith = float3(0.18, 0.52, 0.67);
  float3 dayHorizon = float3(0.80, 0.89, 0.85);
  float3 nightZenith = float3(0.015, 0.025, 0.06);
  float3 nightHorizon = float3(0.05, 0.07, 0.13);
  float t = clamp(e * 2.4 + 0.25, 0.0, 1.0);
  float3 zenith = mix(nightZenith, dayZenith, t);
  float3 horizon = mix(nightHorizon, dayHorizon, t);
  float h = clamp(d.y, 0.0, 1.0);
  float3 col = mix(horizon, zenith, pow(h, 0.6));

  float3 s = sunDir();
  float twilight = exp(-abs(e) * 9.0);
  float towardSun = pow(max(dot(normalize(float2(d.x, d.z)), normalize(float2(s.x, s.z))), 0.0), 3.0);
  col += float3(0.95, 0.45, 0.15) * twilight * (1.0 - h) * (0.35 + 0.65 * towardSun);

  float sd = dot(d, s);
  col += float3(1.0, 0.93, 0.75) * smoothstep(0.9985, 0.9995, sd) * t;
  col += float3(1.0, 0.85, 0.55) * pow(max(sd, 0.0), 180.0) * 0.35 * t;
  float md = dot(d, -s);
  col += float3(0.85, 0.9, 1.0) * smoothstep(0.9988, 0.9996, md) * (1.0 - t) * 0.9;

  if (t < 0.6 && d.y > 0.0) {
    float3 sp = floor(d * 160.0);
    float star = hash12(sp.xy + sp.z * 7.1);
    float twinkle = 0.7 + 0.3 * sin(u.time.y * 2.0 + star * 40.0);
    col += float3(0.9, 0.95, 1.0) * step(0.9965, star) * (1.0 - t / 0.6) * twinkle;
  }

  if (d.y > 0.015) {
    float2 cp = (u.cam.xyz.xz + d.xz * (90.0 - u.cam.xyz.y) / d.y) * 0.012 + float2(u.time.y * 0.004, 0.0);
    float n = vnoise(cp) * 0.6 + vnoise(cp * 2.3 + 5.0) * 0.3 + vnoise(cp * 5.1 + 9.0) * 0.1;
    float cov = smoothstep(0.52, 0.72, n);
    float3 cloudCol = mix(float3(0.08, 0.09, 0.14), float3(1.0, 0.98, 0.95), t);
    cloudCol += float3(0.9, 0.4, 0.15) * twilight * 0.5;
    col = mix(col, cloudCol, cov * smoothstep(0.015, 0.12, d.y) * 0.9);
  }
  return col;
}

float2 boxHit(float3 ro, float3 rd, float3 bmin, float3 bmax, thread float3& n) {
  float3 inv = 1.0 / rd;
  float3 t0 = (bmin - ro) * inv;
  float3 t1 = (bmax - ro) * inv;
  float3 tmin = min(t0, t1);
  float3 tmax = max(t0, t1);
  float tn = max(max(tmin.x, tmin.y), tmin.z);
  float tf = min(min(tmax.x, tmax.y), tmax.z);
  n = float3(0.0);
  if (tn == tmin.x) n = float3(-sign(rd.x), 0.0, 0.0);
  else if (tn == tmin.y) n = float3(0.0, -sign(rd.y), 0.0);
  else n = float3(0.0, 0.0, -sign(rd.z));
  return float2(tn, tf);
}

float2 faceUv(float3 hp, float3 n) {
  float3 f = fract(hp);
  if (abs(n.y) > 0.5) return float2(f.x, f.z);
  if (abs(n.x) > 0.5) return float2(n.x > 0.0 ? 1.0 - f.z : f.z, 1.0 - f.y);
  return float2(n.z > 0.0 ? f.x : 1.0 - f.x, 1.0 - f.y);
}

float faceShade(float3 n, float3 s, float dayLight) {
  float base = n.y > 0.5 ? 1.0 : (n.y < -0.5 ? 0.55 : (abs(n.x) > 0.5 ? 0.82 : 0.72));
  float sun = max(dot(n, s), 0.0) * 0.18 * dayLight;
  return base + sun;
}

float smoothLight(float3 cell, float3 n, float3 hp, float dayLight) {
  float3 front = cell + n;
  float3 f = hp - cell;
  float3 u, v;
  float fu, fv;
  if (abs(n.y) > 0.5) { u = float3(1.0, 0.0, 0.0); v = float3(0.0, 0.0, 1.0); fu = f.x; fv = f.z; }
  else if (abs(n.x) > 0.5) { u = float3(0.0, 0.0, 1.0); v = float3(0.0, 1.0, 0.0); fu = f.z; fv = f.y; }
  else { u = float3(1.0, 0.0, 0.0); v = float3(0.0, 1.0, 0.0); fu = f.x; fv = f.y; }
  float su = fu < 0.5 ? -1.0 : 1.0;
  float sv = fv < 0.5 ? -1.0 : 1.0;
  float wu = abs(fu - 0.5);
  float wv = abs(fv - 0.5);
  float l00 = lightAt(front, dayLight);
  float l10 = lightAt(front + u * su, dayLight);
  float l01 = lightAt(front + v * sv, dayLight);
  float l11 = lightAt(front + u * su + v * sv, dayLight);

  float solid10 = voxId(front + u * su) > 0.5 && vox(front + u * su).g + vox(front + u * su).b < 0.001 ? 1.0 : 0.0;
  float solid01 = voxId(front + v * sv) > 0.5 && vox(front + v * sv).g + vox(front + v * sv).b < 0.001 ? 1.0 : 0.0;
  if (solid10 > 0.5 && solid01 > 0.5) l11 = 0.0;
  float a = mix(l00, l10, wu);
  float b = mix(l01, l11, wu);
  return mix(a, b, wv);
}

float4 entityTexel(float i) {
  return uEntities.sample(nearestSampler, float2((i + 0.5) / 128.0, 0.5));
}

float3 hashColor(float seed) {
  return float3(0.45 + 0.5 * fract(sin(seed * 12.9898) * 43758.5453),
              0.4 + 0.5 * fract(sin(seed * 78.233) * 43758.5453),
              0.45 + 0.5 * fract(sin(seed * 39.425) * 43758.5453));
}

float entityHit(float3 ro, float3 rd, float idx, thread float3& col, thread float3& nrm) {
  float4 a = entityTexel(idx * 3.0);
  float4 b = entityTexel(idx * 3.0 + 1.0);
  float4 k = entityTexel(idx * 3.0 + 2.0);
  float ex = (a.r * 255.0 * 256.0 + a.g * 255.0) / 256.0 - 16.0;
  float ez = (a.b * 255.0 * 256.0 + b.r * 255.0) / 256.0 - 16.0;
  float ey = (b.g * 255.0 * 256.0 + b.b * 255.0) / 256.0 - 16.0;
  float kind = floor(k.r * 255.0 + 0.5);
  float yaw = k.g * 2.0 * PI;
  float hurt = k.b;
  float3 pos = float3(ex, ey, ez);
  float seed = floor(kind / 10.0);
  kind = mod(kind, 10.0);

  float c = cos(yaw), s = sin(yaw);
  float3 lo = ro - pos;
  lo = float3(c * lo.x - s * lo.z, lo.y, s * lo.x + c * lo.z);
  float3 ld = float3(c * rd.x - s * rd.z, rd.y, s * rd.x + c * rd.z);

  float best = 1e9;
  float3 bestN = float3(0.0);
  float3 bestCol = float3(1.0);
  float3 n;
  float2 h;
  float bob = sin(u.time.y * 6.0 + seed) * 0.03;

  if (kind < 0.5) {

    float3 tunic = hashColor(seed + 1.0);
    float3 skin = float3(0.93, 0.78, 0.62);
    float3 trousers = tunic * 0.45;
    h = boxHit(lo, ld, float3(-0.25, 1.35, -0.25), float3(0.25, 1.85, 0.25), n);
    if (h.x < h.y && h.y > 0.0 && h.x < best) {
      best = h.x; bestN = n;
      float3 hp = lo + ld * h.x;
      bestCol = skin;

      if (hp.y > 1.72) bestCol = tunic * 0.35;
      if (n.z < -0.5 && hp.y > 1.55 && hp.y < 1.63 && (abs(hp.x - 0.1) < 0.045 || abs(hp.x + 0.1) < 0.045)) bestCol = float3(0.08, 0.1, 0.14);
    }
    h = boxHit(lo, ld, float3(-0.25, 0.75, -0.15), float3(0.25, 1.35, 0.15), n);
    if (h.x < h.y && h.y > 0.0 && h.x < best) {
      best = h.x; bestN = n; bestCol = tunic;
      float3 hp = lo + ld * h.x;
      if (abs(hp.x) < 0.05 && n.z < -0.5) bestCol = tunic * 0.7;
    }
    h = boxHit(lo, ld, float3(-0.25, 0.0, -0.13), float3(0.25, 0.75, 0.13), n);
    if (h.x < h.y && h.y > 0.0 && h.x < best) {
      best = h.x; bestN = n; bestCol = trousers;
      float3 hp = lo + ld * h.x;
      if (hp.y < 0.12) bestCol = float3(0.2, 0.14, 0.1);
      if (abs(hp.x) < 0.02) bestCol = trousers * 0.6;
    }
    h = boxHit(lo, ld, float3(-0.4, 0.75, -0.12), float3(-0.25, 1.32, 0.12), n);
    if (h.x < h.y && h.y > 0.0 && h.x < best) { best = h.x; bestN = n; bestCol = (lo + ld * h.x).y < 0.98 ? skin : tunic; }
    h = boxHit(lo, ld, float3(0.25, 0.75, -0.12), float3(0.4, 1.32, 0.12), n);
    if (h.x < h.y && h.y > 0.0 && h.x < best) { best = h.x; bestN = n; bestCol = (lo + ld * h.x).y < 0.98 ? skin : tunic; }
  } else if (kind < 1.5) {

    float3 moss = float3(0.36, 0.55, 0.25);
    float3 shell = float3(0.32, 0.27, 0.2);
    h = boxHit(lo, ld, float3(-0.45, 0.25 + bob, -0.5), float3(0.45, 1.0 + bob, 0.5), n);
    if (h.x < h.y && h.y > 0.0 && h.x < best) {
      best = h.x; bestN = n;
      float3 hp = lo + ld * h.x;
      bestCol = hp.y > 0.72 + bob ? moss : shell;
      if (hp.y > 0.72 + bob && fract(hp.x * 3.0 + hp.z * 2.0) > 0.7) bestCol = moss * 1.25;
    }
    h = boxHit(lo, ld, float3(-0.22, 0.35 + bob, -0.85), float3(0.22, 0.75 + bob, -0.45), n);
    if (h.x < h.y && h.y > 0.0 && h.x < best) {
      best = h.x; bestN = n; bestCol = shell * 1.15;
      float3 hp = lo + ld * h.x;
      if (n.z < -0.5 && hp.y > 0.58 + bob && hp.y < 0.66 + bob && abs(abs(hp.x) - 0.11) < 0.035) bestCol = float3(0.05);
    }
    h = boxHit(lo, ld, float3(-0.4, 0.0, -0.4), float3(0.4, 0.3, 0.4), n);
    if (h.x < h.y && h.y > 0.0 && h.x < best) { best = h.x; bestN = n; bestCol = shell * 0.75; }
  } else if (kind < 2.5) {

    float3 ash = float3(0.12, 0.11, 0.14);
    h = boxHit(lo, ld, float3(-0.22, 1.4, -0.22), float3(0.22, 1.9, 0.22), n);
    if (h.x < h.y && h.y > 0.0 && h.x < best) {
      best = h.x; bestN = n; bestCol = ash;
      float3 hp = lo + ld * h.x;
      if (n.z < -0.5 && hp.y > 1.6 && hp.y < 1.7 && abs(abs(hp.x) - 0.09) < 0.05) bestCol = float3(2.2, 0.9, 0.3);
    }
    h = boxHit(lo, ld, float3(-0.22, 0.6, -0.14), float3(0.22, 1.4, 0.14), n);
    if (h.x < h.y && h.y > 0.0 && h.x < best) {
      best = h.x; bestN = n; bestCol = ash * 1.2;
      float3 hp = lo + ld * h.x;
      if (fract(hp.y * 4.0) < 0.15) bestCol = float3(0.5, 0.2, 0.08);
    }
    h = boxHit(lo, ld, float3(-0.2, 0.0, -0.12), float3(0.2, 0.6, 0.12), n);
    if (h.x < h.y && h.y > 0.0 && h.x < best) { best = h.x; bestN = n; bestCol = ash * 0.8; }
  } else {

    float3 ember = float3(0.95, 0.35, 0.08);
    float hop = abs(sin(u.time.y * 5.0 + seed)) * 0.3;
    h = boxHit(lo, ld, float3(-0.25, hop, -0.25), float3(0.25, 0.7 + hop, 0.25), n);
    if (h.x < h.y && h.y > 0.0 && h.x < best) {
      best = h.x; bestN = n;
      float3 hp = lo + ld * h.x;
      float crack = step(0.75, fract(hp.x * 5.0 + hp.y * 3.0) + fract(hp.z * 4.0) * 0.5);
      bestCol = mix(float3(0.15, 0.08, 0.06), ember * 1.6, crack);
      if (n.z < -0.5 && hp.y > 0.4 + hop && hp.y < 0.5 + hop && abs(abs(hp.x) - 0.1) < 0.04) bestCol = float3(2.5, 2.0, 0.6);
    }
  }
  if (best > 1e8) return -1.0;

  nrm = float3(c * bestN.x + s * bestN.z, bestN.y, -s * bestN.x + c * bestN.z);
  col = mix(bestCol, float3(1.0, 0.3, 0.3), hurt * 0.6);
  return best;
}

float4 render(float2 frag) {
  float2 ndc = (frag / u.res.xy) * 2.0 - 1.0;
  float3 rd = normalize(u.forward.xyz + u.right.xyz * ndc.x * u.fov.xy.x - u.up.xyz * ndc.y * u.fov.xy.y);
  float3 ro = u.cam.xyz - u.origin.xyz;

  float dayLight = dayLightAmount();
  float3 sun = sunDir();

  float entT = 1e9;
  float3 entCol = float3(0.0);
  float3 entN = float3(0.0);
  for (int i = 0; i < 24; i++) {
    if (float(i) >= u.res.z) break;
    float3 c, n;
    float t = entityHit(ro, rd, float(i), c, n);
    if (t > 0.0 && t < entT) { entT = t; entCol = c; entN = n; }
  }

  float3 cell = floor(ro);
  float3 stepDir = sign(rd);
  float3 safeRd = float3(abs(rd.x) < 1e-6 ? 1e-6 : rd.x, abs(rd.y) < 1e-6 ? 1e-6 : rd.y, abs(rd.z) < 1e-6 ? 1e-6 : rd.z);
  float3 tDelta = abs(1.0 / safeRd);
  float3 tMax = ((stepDir * (cell - ro)) + (stepDir * 0.5) + 0.5) * tDelta;
  float3 n = float3(0.0);
  float t = 0.0;

  bool hit = false;
  float3 hitCell = cell;
  float3 hitN = float3(0.0, 1.0, 0.0);
  float hitT = 0.0;
  float hitId = 0.0;
  float2 hitUv = float2(0.0);
  float hitTile = 0.0;
  bool startInWater = u.time.w > 0.5;
  float waterT = -1.0;
  float3 waterN = float3(0.0);
  float3 waterP = float3(0.0);
  float glassT = -1.0;
  float4 glassCol = float4(0.0);

  float startId = voxId(cell);
  float4 startInfo = tileInfo(startId);
  float startFlag = floor(startInfo.a * 255.0 + 0.5);
  if (startId > 0.5 && startFlag == 0.0) {
    return float4(0.03, 0.03, 0.035, 1.0);
  }

  for (int i = 0; i < MAX_STEPS; i++) {

    if (tMax.x < tMax.y && tMax.x < tMax.z) {
      cell.x += stepDir.x; t = tMax.x; tMax.x += tDelta.x; n = float3(-stepDir.x, 0.0, 0.0);
    } else if (tMax.y < tMax.z) {
      cell.y += stepDir.y; t = tMax.y; tMax.y += tDelta.y; n = float3(0.0, -stepDir.y, 0.0);
    } else {
      cell.z += stepDir.z; t = tMax.z; tMax.z += tDelta.z; n = float3(0.0, 0.0, -stepDir.z);
    }
    if (t > u.time.z || t > entT) break;
    if (cell.y < 0.0 || cell.y > 63.0) {
      if (cell.y > 63.0 && rd.y > 0.0) break;
      if (cell.y < 0.0) break;
    }
    float id = voxId(cell);
    if (id < 0.5) continue;
    float4 info = tileInfo(id);
    float flag = floor(info.a * 255.0 + 0.5);
    float3 hp = ro + rd * t;

    if (flag == 2.0) {

      if (waterT < 0.0 && !startInWater) { waterT = t; waterN = n; waterP = hp; }
      continue;
    }
    if (flag == 3.0) {

      if (glassT < 0.0) {
        float2 uv = faceUv(hp, n);
        glassT = t;
        glassCol = atlas(info.g * 255.0, uv);
      }
      continue;
    }
    float tile = abs(n.y) > 0.5 ? (n.y > 0.0 ? info.r : info.b) * 255.0 : info.g * 255.0;
    if (flag == 1.0) {

      float2 uv = faceUv(hp, n);
      float4 tex = atlas(tile, uv);
      if (tex.a < 0.5) continue;
      hit = true; hitCell = cell; hitN = n; hitT = t; hitId = id; hitUv = uv; hitTile = tile;
      break;
    }
    if (flag >= 4.0) {

      float3 bmin, bmax;
      if (flag == 4.0) { bmin = float3(0.43, 0.0, 0.43); bmax = float3(0.57, 0.6, 0.57); }
      else if (flag == 5.0) { bmin = float3(0.12, 0.0, 0.12); bmax = float3(0.88, 0.8, 0.88); }
      else if (flag == 7.0) { bmin = float3(0.0, 0.0, 0.0); bmax = float3(1.0, 0.56, 1.0); }
      else if (flag == 8.0) { bmin = float3(0.3, 0.0, 0.3); bmax = float3(0.7, 0.55, 0.7); }
      else { bmin = float3(0.06, 0.0, 0.06); bmax = float3(0.94, 1.0, 0.94); }
      float3 bn;
      float2 bh = boxHit(ro, rd, cell + bmin, cell + bmax, bn);
      if (bh.x < bh.y && bh.y > 0.0 && bh.x < u.time.z && bh.x < entT) {
        float bt = max(bh.x, 0.0);
        float3 bp = ro + rd * bt;
        float3 local = (bp - cell - bmin) / (bmax - bmin);
        float2 uv;
        if (abs(bn.y) > 0.5) uv = float2(local.x, local.z);
        else if (abs(bn.x) > 0.5) uv = float2(bn.x > 0.0 ? 1.0 - local.z : local.z, 1.0 - local.y);
        else uv = float2(bn.z > 0.0 ? local.x : 1.0 - local.x, 1.0 - local.y);
        float btile = abs(bn.y) > 0.5 ? (bn.y > 0.0 ? info.r : info.b) * 255.0 : info.g * 255.0;
        if (flag == 4.0) {

          if (abs(bn.y) > 0.5) uv = float2(mix(0.375, 0.625, uv.x), mix(0.1875, 0.375, uv.y));
          else uv = float2(mix(0.375, 0.625, uv.x), mix(0.125, 1.0, uv.y));
        }
        if (flag == 5.0) {

          if (abs(bn.y) > 0.5) continue;
          float4 tex = atlas(btile, uv);
          if (tex.a < 0.5) {

            float3 bp2 = ro + rd * bh.y;
            float3 l2 = (bp2 - cell - bmin) / (bmax - bmin);

            if (l2.y < 0.002 || l2.y > 0.998) continue;
            bool exitX = l2.x < 0.002 || l2.x > 0.998;
            float2 uv2 = exitX ? float2(l2.z, 1.0 - l2.y) : float2(l2.x, 1.0 - l2.y);
            float4 tex2 = atlas(btile, uv2);
            if (tex2.a < 0.5) continue;
            bt = bh.y; bn = -bn; uv = uv2;
          }
        }
        hit = true; hitCell = cell; hitN = bn; hitT = bt; hitId = id; hitUv = uv; hitTile = btile;

        break;
      }
      continue;
    }

    hit = true; hitCell = cell; hitN = n; hitT = t; hitId = id; hitUv = faceUv(hp, n); hitTile = tile;
    break;
  }

  float3 color;
  float finalT;
  if (entT < 1e8 && (!hit || entT < hitT)) {

    float3 ep = ro + rd * entT;
    float3 ecell = floor(ep + entN * 0.01);
    float l = lightAt(ecell, dayLight);
    float shade = faceShade(entN, sun, dayLight);
    float bright = mix(0.05, 1.0, pow(l, 1.6));
    color = entCol * shade * bright;

    if (entCol.r > 1.5) color = entCol;
    finalT = entT;
  } else if (hit) {
    float4 tex = atlas(hitTile, hitUv);
    float3 hp = ro + rd * hitT;
    float4 info = tileInfo(hitId);
    float flag = floor(info.a * 255.0 + 0.5);

    float l = flag >= 4.0 ? lightAt(hitCell, dayLight) : smoothLight(hitCell, hitN, hp, dayLight);
    if (flag == 4.0 || flag == 8.0 || hitId == 13.0) l = max(l, 0.95);
    float bright = mix(0.035, 1.0, pow(l, 1.5));
    float shade = faceShade(hitN, sun, dayLight);
    color = tex.rgb * shade * bright;
    color *= mix(float3(0.87, 0.98, 1.05), float3(1.07, 1.02, 0.89), max(dot(hitN, sun), 0.0) * dayLight);

    if (flag == 4.0 && hitUv.y < 0.35) color = tex.rgb * (1.3 + 0.3 * sin(u.time.y * 14.0 + hp.x * 7.0));
    if (flag == 8.0) color = tex.rgb * 1.25;
    if (hitId == 13.0 && tex.r > tex.b * 1.6) color = tex.rgb * (1.4 + 0.2 * sin(u.time.y * 3.0));

    if (all(abs(hitCell - u.target.xyz) < float3(0.5))) {
      float2 e = min(hitUv, 1.0 - hitUv);
      float edge = min(e.x, e.y);
      float lineW = 0.012 * max(1.0, hitT * 0.9);
      if (edge < lineW) color = mix(color, float3(1.0, 0.80, 0.46), 0.85);
      if (u.target.w > 0.0) {
        float2 cu = hitUv * 16.0;
        float cr = hash12(floor(cu) + floor(hitCell.xy) * 3.0);
        float cr2 = hash12(floor(cu * 0.5 + 3.0) + hitCell.z);
        float cracks = step(1.0 - u.target.w * 0.85, cr * 0.7 + cr2 * 0.3);
        color = mix(color, float3(0.08, 0.07, 0.06), cracks * 0.85);
      }
    }
    finalT = hitT;
  } else {
    color = skyColor(rd, dayLight);
    finalT = u.time.z;
  }

  if (glassT >= 0.0 && glassT < finalT) {
    float3 glassTint = float3(0.78, 0.9, 1.0);
    if (glassCol.a > 0.5) color = mix(color, glassCol.rgb, 0.85);
    else color = mix(color, glassTint, 0.18) * 1.02;
  }

  if (waterT >= 0.0 && waterT < finalT) {
    float depth = finalT - waterT;
    float3 deep = float3(0.04, 0.25, 0.31);
    float3 shallow = float3(0.20, 0.65, 0.60);
    float absorb = 1.0 - exp(-depth * 0.32);
    float3 wcol = mix(shallow, deep, clamp(depth * 0.12, 0.0, 1.0));
    float wl = lightAt(floor(waterP + waterN * 0.01), dayLight);
    wcol *= mix(0.08, 1.0, wl);
    color = mix(color, wcol, 0.45 + 0.5 * absorb);

    if (waterN.y > 0.5) {
      float wave = vnoise(waterP.xz * 3.0 + float2(u.time.y * 0.8, u.time.y * 0.55)) + vnoise(waterP.xz * 6.0 - u.time.y * 0.6) * 0.5;
      float3 wn = normalize(float3((wave - 0.75) * 0.25, 1.0, (vnoise(waterP.zx * 3.0 - u.time.y * 0.7) - 0.5) * 0.25));
      float3 refl = reflect(rd, wn);
      float spec = pow(max(dot(refl, sun), 0.0), 90.0) * dayLight;
      color += float3(1.0, 0.95, 0.8) * spec * 0.9;
      color += skyColor(refl, dayLight) * 0.12;
    }
  }

  float3 fogCol = skyColor(normalize(float3(rd.x, max(rd.y, 0.02), rd.z)), dayLight);
  float fog = 1.0 - exp(-pow(finalT / u.time.z, 2.6) * 3.5);
  if (!hit && entT > 1e8) fog = 0.0;
  color = mix(color, fogCol, fog);

  if (u.time.w > 0.5) {
    color = mix(color, float3(0.08, 0.28, 0.5), clamp(0.35 + finalT * 0.05, 0.0, 0.9));
  }

  color = mix(color, float3(0.7, 0.05, 0.05), u.res.w * 0.45);

  color = color / (color + 0.65) * 1.55;
  float2 vc = frag / u.res.xy - 0.5;
  color *= 1.0 - dot(vc, vc) * 0.35;
  return float4(clamp(color, 0.0, 1.0), 1.0);
}
};
vertex float4 hearthVertex(uint index [[vertex_id]]) {
    const float2 positions[] = {float2(-1,-1), float2(3,-1), float2(-1,3)};
    return float4(positions[index], 0, 1);
}
fragment float4 hearthFragment(float4 position [[position]], constant Uniforms& u [[buffer(0)]],
texture2d<float> uVox0 [[texture(0)]],
texture2d<float> uVox1 [[texture(1)]],
texture2d<float> uVox2 [[texture(2)]],
texture2d<float> uVox3 [[texture(3)]],
texture2d<float> uTiles [[texture(4)]],
texture2d<float> uAtlas [[texture(5)]],
texture2d<float> uEntities [[texture(6)]]) {
    Trace trace {u, uVox0, uVox1, uVox2, uVox3, uTiles, uAtlas, uEntities};
    return trace.render(position.xy);
}
