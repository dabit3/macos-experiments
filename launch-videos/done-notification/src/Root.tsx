import { Composition } from "remotion";
import { DoneNotification } from "./DoneNotification";
import { FPS, TOTAL } from "./timeline";

export const Root: React.FC = () => (
  <Composition
    id="DoneNotification"
    component={DoneNotification}
    durationInFrames={TOTAL}
    fps={FPS}
    width={1920}
    height={1080}
  />
);
