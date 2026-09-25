import { ContactShadows, Environment, Lightformer, RoundedBox } from "@react-three/drei";
import { useThree } from "@react-three/fiber";
import { ThreeCanvas } from "@remotion/three";
import { useLayoutEffect, useMemo } from "react";
import * as THREE from "three";
import { applyPose, FOV, Pose, SCREEN } from "../camera";

const roundedRect = (w: number, h: number, r: number) => {
  const s = new THREE.Shape();
  const x = -w / 2, y = -h / 2;
  s.moveTo(x + r, y);
  s.lineTo(x + w - r, y);
  s.quadraticCurveTo(x + w, y, x + w, y + r);
  s.lineTo(x + w, y + h - r);
  s.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  s.lineTo(x + r, y + h);
  s.quadraticCurveTo(x, y + h, x, y + h - r);
  s.lineTo(x, y + r);
  s.quadraticCurveTo(x, y, x + r, y);
  return s;
};

const Rig: React.FC<{ pose: Pose }> = ({ pose }) => {
  const { camera, gl } = useThree();
  useLayoutEffect(() => {
    gl.toneMapping = THREE.NeutralToneMapping;
    gl.toneMappingExposure = 1.0;
  }, [gl]);
  applyPose(camera as THREE.PerspectiveCamera, pose);
  return null;
};

const aluminum = { color: "#d4d5d8", metalness: 1, roughness: 0.34, envMapIntensity: 1 } as const;

const Monitor: React.FC = () => {
  const glass = useMemo(() => new THREE.ShapeGeometry(roundedRect(0.619, 0.358, 0.0075), 8), []);
  const { center } = SCREEN;
  return (
    <group>
      <RoundedBox args={[0.623, 0.362, 0.02]} radius={0.009} smoothness={6} position={[0, center.y, -0.0001]} castShadow receiveShadow>
        <meshStandardMaterial {...aluminum} />
      </RoundedBox>
      <mesh geometry={glass} position={[0, center.y, 0.01]}>
        <meshPhysicalMaterial color="#060607" roughness={0.12} metalness={0} clearcoat={1} clearcoatRoughness={0.06} />
      </mesh>
      <RoundedBox args={[0.15, 0.33, 0.011]} radius={0.004} smoothness={4} position={[0, 0.158, -0.086]} rotation={[0.43, 0, 0]} castShadow receiveShadow>
        <meshStandardMaterial {...aluminum} />
      </RoundedBox>
      <RoundedBox args={[0.15, 0.007, 0.2]} radius={0.003} smoothness={4} position={[0, 0.0035, -0.085]} castShadow receiveShadow>
        <meshStandardMaterial {...aluminum} />
      </RoundedBox>
    </group>
  );
};

const KEY = 0.0158;
const PITCH = 0.0188;

const Keyboard: React.FC = () => {
  const keys = useMemo(() => {
    const out: { x: number; z: number; w: number; d: number }[] = [];
    const cols = 14;
    const width = cols * PITCH;
    for (let c = 0; c < cols; c++) out.push({ x: -width / 2 + PITCH * (c + 0.5), z: -2.62 * PITCH, w: KEY, d: KEY * 0.55 });
    const rows: number[][] = [
      [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.5],
      [1.5, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
      [1.8, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.75],
      [2.3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2.3],
      [1, 1, 1, 1.25, 5.1, 1.25, 1, 1, 1, 1],
    ];
    rows.forEach((row, r) => {
      const total = row.reduce((a, b) => a + b, 0);
      const scale = (width - 0.0002) / (total * PITCH);
      let x = -width / 2;
      row.forEach((u) => {
        const w = u * PITCH * scale;
        out.push({ x: x + w / 2, z: (r - 1.55) * PITCH, w: w - (PITCH - KEY), d: KEY });
        x += w;
      });
    });
    return out;
  }, []);
  return (
    <group position={[-0.03, 0, 0.34]} rotation={[0, 0.015, 0]}>
      <RoundedBox args={[0.279, 0.006, 0.117]} radius={0.0028} smoothness={4} position={[0, 0.003, 0]} castShadow receiveShadow>
        <meshStandardMaterial color="#dcdde0" metalness={0.9} roughness={0.3} />
      </RoundedBox>
      {keys.map((k, i) => (
        <RoundedBox key={i} args={[k.w, 0.0022, k.d]} radius={0.0009} smoothness={2} position={[k.x, 0.0065, k.z + 0.004]}>
          <meshStandardMaterial color="#fbfbfb" roughness={0.55} />
        </RoundedBox>
      ))}
    </group>
  );
};

const Mouse: React.FC = () => (
  <mesh position={[0.235, 0.0, 0.35]} scale={[0.029, 0.011, 0.057]} rotation={[0, -0.08, 0]} castShadow>
    <sphereGeometry args={[1, 48, 32, 0, Math.PI * 2, 0, Math.PI / 2]} />
    <meshPhysicalMaterial color="#fafafa" roughness={0.28} clearcoat={0.6} />
  </mesh>
);

export const Studio: React.FC<{ pose: Pose }> = ({ pose }) => (
  <ThreeCanvas
    width={1920}
    height={1080}
    shadows={{ type: THREE.VSMShadowMap }}
    gl={{ antialias: true, preserveDrawingBuffer: true }}
    camera={{ fov: FOV, near: 0.01, far: 50 }}
    style={{ position: "absolute", inset: 0 }}
  >
    <Rig pose={pose} />
    <color attach="background" args={["#f1f0ed"]} />
    <hemisphereLight args={["#ffffff", "#e4e0da", 1.6]} />
    <directionalLight
      position={[-1.2, 3.6, 2.2]}
      intensity={1.5}
      color="#fff7ee"
      castShadow
      shadow-mapSize={[2048, 2048]}
      shadow-radius={22}
      shadow-blurSamples={32}
      shadow-bias={-0.0008}
      shadow-camera-left={-1.4}
      shadow-camera-right={1.4}
      shadow-camera-top={1.4}
      shadow-camera-bottom={-1.4}
      shadow-camera-near={0.5}
      shadow-camera-far={8}
    />
    <directionalLight position={[2.2, 1.2, 1.6]} intensity={0.35} color="#eef2ff" />
    <Environment resolution={256} frames={1}>
      <color attach="background" args={["#bdbab5"]} />
      <Lightformer form="rect" intensity={2.4} position={[-3, 2, 2]} scale={[3, 2.2, 1]} target={[0, 0.3, 0]} />
      <Lightformer form="rect" intensity={1.2} position={[0, 3, 1]} scale={[4, 1.2, 1]} target={[0, 0, 0]} />
      <Lightformer form="rect" intensity={0.6} position={[3, 1, 2]} scale={[2, 2, 1]} target={[0, 0.3, 0]} />
      <Lightformer form="rect" intensity={0.25} color="#f1efe9" position={[0, 0.5, -3]} scale={[8, 3, 1]} target={[0, 0.3, 0]} />
    </Environment>
    <mesh position={[0, 1.2, -0.55]} receiveShadow>
      <planeGeometry args={[10, 4]} />
      <meshStandardMaterial color="#f4f3f0" roughness={1} />
    </mesh>
    <mesh position={[0, -0.02, 1.2]} receiveShadow>
      <boxGeometry args={[10, 0.04, 3.5]} />
      <meshStandardMaterial color="#f8f7f4" roughness={0.8} />
    </mesh>
    <Monitor />
    <Keyboard />
    <Mouse />
    <ContactShadows position={[0, 0.0005, 0.05]} scale={2.2} resolution={1024} blur={2.6} opacity={0.5} far={0.35} color="#3a342c" />
  </ThreeCanvas>
);
