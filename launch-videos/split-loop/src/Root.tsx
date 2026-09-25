import React from 'react';
import {Composition} from 'remotion';
import {SplitLoop, DURATION} from './SplitLoop';
import {FPS, H, W} from './theme';

export const Root: React.FC = () => (
  <Composition id="SplitLoop" component={SplitLoop} durationInFrames={DURATION} fps={FPS} width={W} height={H} />
);
