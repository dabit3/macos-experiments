import { Composition } from "remotion";
import { TestReport } from "./TestReport";
import { FPS, TOTAL } from "./timeline";

export const Root: React.FC = () => (
  <Composition
    id="TestReport"
    component={TestReport}
    durationInFrames={TOTAL}
    fps={FPS}
    width={1920}
    height={1080}
  />
);
