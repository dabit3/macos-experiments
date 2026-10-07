import React from "react";
import { Composition } from "remotion";
import { ChooseMacOS, DURATION } from "./ChooseMacOS";
import { FPS, HEIGHT, WIDTH } from "./theme";

export const RemotionRoot: React.FC = () => (
  <Composition id="ChooseMacOS" component={ChooseMacOS} durationInFrames={DURATION} fps={FPS} width={WIDTH} height={HEIGHT} />
);
