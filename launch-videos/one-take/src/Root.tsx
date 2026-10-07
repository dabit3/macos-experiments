import React from "react";
import { Composition } from "remotion";
import { Compare, Main } from "./Main";
import { DURATION_S, FPS, HEIGHT, WIDTH } from "./tokens";

export const Root: React.FC = () => (
  <>
    <Composition id="Main" component={Main} durationInFrames={DURATION_S * FPS} fps={FPS} width={WIDTH} height={HEIGHT} />
    <Composition id="Compare" component={Compare} durationInFrames={1} fps={FPS} width={1882} height={1080} defaultProps={{ t: 1 }} />
  </>
);
