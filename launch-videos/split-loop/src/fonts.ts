import '@fontsource/inter/400.css';
import '@fontsource/inter/500.css';
import '@fontsource/inter/600.css';
import '@fontsource/roboto-mono/400.css';
import '@fontsource/roboto-mono/500.css';
import {continueRender, delayRender} from 'remotion';

const handle = delayRender('Loading fonts');
Promise.all(
  [
    '400 14px Inter',
    '500 14px Inter',
    '600 14px Inter',
    '400 11px "Roboto Mono"',
    '500 11px "Roboto Mono"',
  ].map((f) => document.fonts.load(f)),
).then(() => continueRender(handle));
