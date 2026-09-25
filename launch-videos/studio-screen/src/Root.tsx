import "@fontsource/inter/400.css";
import "@fontsource/inter/500.css";
import "@fontsource/inter/600.css";
import "@fontsource/roboto-mono/400.css";
import "@fontsource/roboto-mono/500.css";
import { Composition } from "remotion";
import { Video } from "./Video";
import { DURATION, FPS } from "./timeline";

export const Root: React.FC = () => (
  <Composition id="StudioScreen" component={Video} durationInFrames={DURATION} fps={FPS} width={1920} height={1080} />
);
