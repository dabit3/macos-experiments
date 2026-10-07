import React from "react";
import { Composition } from "remotion";
import { MACRO_LEN, Macro, Screens } from "./Macro";

export const Root: React.FC = () => (
  <>
    <Composition id="Macro" component={Macro} durationInFrames={MACRO_LEN} fps={60} width={1920} height={1080} />
    {(["home", "menu", "session", "player"] as const).map((w) => (
      <Composition key={w} id={`Screen-${w}`} component={Screens} defaultProps={{ which: w }} durationInFrames={1} fps={60} width={1920} height={1080} />
    ))}
  </>
);
