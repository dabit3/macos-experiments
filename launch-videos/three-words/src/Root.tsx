import { Composition } from "remotion";
import { ThreeWords } from "./ThreeWords";
import { DURATION, FPS } from "./timeline";

export const Root: React.FC = () => (
  <Composition id="ThreeWords" component={ThreeWords} durationInFrames={DURATION} fps={FPS} width={1920} height={1080} />
);
