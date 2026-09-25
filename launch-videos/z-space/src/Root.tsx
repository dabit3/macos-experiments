import { Composition } from "remotion";
import { Compare } from "./Compare";
import { DURATION, ZSpace } from "./Video";

export const Root: React.FC = () => (
  <>
    <Composition id="ZSpace" component={ZSpace} durationInFrames={DURATION} fps={60} width={1920} height={1080} />
    <Composition id="Compare" component={Compare} durationInFrames={1} fps={60} width={1882} height={1080} defaultProps={{ which: "home" }} />
  </>
);
