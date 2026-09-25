import * as THREE from "three";
import { easeInOutCubic, easeInOutQuint, easeInOutSine, ramp } from "./ease";
import { T } from "./timeline";

export const FOV = 26;
export const SCREEN = { w: 0.597, h: 0.597 * (9 / 16), center: new THREE.Vector3(0, 0.3, 0.0101) };
const FLAT_DIST = SCREEN.h / 2 / Math.tan(THREE.MathUtils.degToRad(FOV / 2));

export type Pose = { pos: THREE.Vector3; target: THREE.Vector3 };

const v = (x: number, y: number, z: number) => new THREE.Vector3(x, y, z);
export const FLAT: Pose = { pos: SCREEN.center.clone().add(v(0, 0, FLAT_DIST)), target: SCREEN.center.clone() };

const OPEN: Pose = { pos: v(0.98, 0.47, 1.78), target: v(0.05, 0.26, 0) };
const OPEN_VIA: Pose = { pos: v(0.42, 0.37, 1.32), target: v(0.01, 0.29, 0) };
const ORBIT: Pose[] = [
  FLAT,
  { pos: v(-0.2, 0.33, 0.98), target: v(-0.01, 0.295, 0) },
  { pos: v(-0.64, 0.41, 1.2), target: v(-0.03, 0.28, 0) },
  { pos: v(-0.34, 0.36, 1.02), target: v(-0.01, 0.293, 0) },
  FLAT,
];
const CLOSE_VIA: Pose = { pos: v(0.3, 0.35, 1.2), target: v(0.01, 0.29, 0) };
const CLOSE: Pose = { pos: v(0.86, 0.5, 1.95), target: v(0.03, 0.25, 0) };
const CLOSE_DRIFT: Pose = { pos: v(0.98, 0.52, 2.08), target: v(0.03, 0.25, 0) };

const bezier = (a: THREE.Vector3, b: THREE.Vector3, c: THREE.Vector3, t: number) =>
  a.clone().multiplyScalar((1 - t) ** 2).add(b.clone().multiplyScalar(2 * (1 - t) * t)).add(c.clone().multiplyScalar(t * t));

const quad = (a: Pose, via: Pose, b: Pose, t: number): Pose => ({
  pos: bezier(a.pos, via.pos, b.pos, t),
  target: bezier(a.target, via.target, b.target, t),
});

const orbitPos = new THREE.CatmullRomCurve3(ORBIT.map((p) => p.pos), false, "centripetal");
const orbitTarget = new THREE.CatmullRomCurve3(ORBIT.map((p) => p.target), false, "centripetal");

export const cameraPose = (frame: number): Pose => {
  if (frame < T.flatIn) return quad(OPEN, OPEN_VIA, FLAT, ramp(frame, 0, T.flatIn, easeInOutCubic));
  if (frame < T.pullOut) return FLAT;
  if (frame < T.flatAgain) {
    const t = ramp(frame, T.pullOut, T.flatAgain, easeInOutSine);
    const s = easeInOutQuint(t) * 0.5 + t * 0.5;
    return { pos: orbitPos.getPoint(s), target: orbitTarget.getPoint(s) };
  }
  if (frame < T.pullBack) return FLAT;
  if (frame < T.pullBackEnd) return quad(FLAT, CLOSE_VIA, CLOSE, ramp(frame, T.pullBack, T.pullBackEnd, easeInOutCubic));
  const t = (frame - T.pullBackEnd) / 200;
  return { pos: CLOSE.pos.clone().lerp(CLOSE_DRIFT.pos, t), target: CLOSE.target.clone() };
};

const cam = new THREE.PerspectiveCamera(FOV, 16 / 9, 0.01, 50);

export const applyPose = (camera: THREE.PerspectiveCamera, pose: Pose) => {
  camera.fov = FOV;
  camera.aspect = 16 / 9;
  camera.near = 0.01;
  camera.far = 50;
  camera.position.copy(pose.pos);
  camera.up.set(0, 1, 0);
  camera.lookAt(pose.target);
  camera.updateProjectionMatrix();
  camera.updateMatrixWorld(true);
};

export const projectScreen = (pose: Pose, W = 1920, H = 1080): [number, number][] => {
  applyPose(cam, pose);
  const { w, h, center } = SCREEN;
  const corners = [v(-w / 2, h / 2, 0), v(w / 2, h / 2, 0), v(w / 2, -h / 2, 0), v(-w / 2, -h / 2, 0)];
  return corners.map((c) => {
    const p = c.add(center).project(cam);
    return [((p.x + 1) / 2) * W, ((1 - p.y) / 2) * H];
  });
};

export const flatness = (pose: Pose) => Math.min(1, pose.pos.distanceTo(FLAT.pos) / 0.35);

export const homography = (q: [number, number][], w: number, h: number): string => {
  const [[x0, y0], [x1, y1], [x2, y2], [x3, y3]] = q;
  const dx1 = x1 - x2, dx2 = x3 - x2, dx3 = x0 - x1 + x2 - x3;
  const dy1 = y1 - y2, dy2 = y3 - y2, dy3 = y0 - y1 + y2 - y3;
  const den = dx1 * dy2 - dx2 * dy1;
  const g = (dx3 * dy2 - dx2 * dy3) / den;
  const hh = (dx1 * dy3 - dx3 * dy1) / den;
  const a = x1 - x0 + g * x1, b = x3 - x0 + hh * x3, c = x0;
  const d = y1 - y0 + g * y1, e = y3 - y0 + hh * y3, f = y0;
  const m = [a / w, d / w, 0, g / w, b / h, e / h, 0, hh / h, 0, 0, 1, 0, c, f, 0, 1];
  return `matrix3d(${m.map((n) => n.toFixed(10)).join(",")})`;
};
