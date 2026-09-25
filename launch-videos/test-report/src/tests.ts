export type TestCase = {
  at: string;
  title: string;
  assertion: string;
  src: number;
  dur: number;
  taps: { t: number; x: number; y: number }[];
};

export const RECORDING_LENGTH = "0:34";

export const TESTS: TestCase[] = [
  {
    at: "0:00",
    title: "It should launch to the title with the best score",
    assertion: "Otter Flap title, Tap to flap hint and Best 6 badge render on launch.",
    src: 0.1,
    dur: 2.1,
    taps: [],
  },
  {
    at: "0:02",
    title: "It should start the run and flap on first tap",
    assertion: "Tap hides the title; the otter rises and the score HUD reads 0.",
    src: 1.8,
    dur: 2.1,
    taps: [{ t: 2.12, x: 0.5, y: 0.52 }],
  },
  {
    at: "0:04",
    title: "It should score a point per driftwood log cleared",
    assertion: "Score ticks from 0 to 1 as the otter clears the first log.",
    src: 4.0,
    dur: 2.1,
    taps: [],
  },
  {
    at: "0:07",
    title: "It should pause when the app is backgrounded",
    assertion: "Home, then relaunch: Paused overlay appears with score 2 intact.",
    src: 7.3,
    dur: 2.2,
    taps: [],
  },
  {
    at: "0:10",
    title: "It should resume the same run with one tap",
    assertion: "Tap to keep paddling resumes from 2; logs keep scrolling.",
    src: 9.7,
    dur: 2.1,
    taps: [{ t: 10.42, x: 0.5, y: 0.52 }],
  },
  {
    at: "0:14",
    title: "It should keep scoring as the gaps narrow",
    assertion: "Otter clears seven logs in a row without clipping a trunk.",
    src: 14.2,
    dur: 2.1,
    taps: [],
  },
  {
    at: "0:16",
    title: "It should splash down and show the results card",
    assertion: "Splash! card shows score 7, best 7, Pebble medal and New best!",
    src: 16.3,
    dur: 2.3,
    taps: [],
  },
  {
    at: "0:29",
    title: "It should keep Best 7 after quit and relaunch",
    assertion: "Terminated and relaunched; title screen still shows Best 7.",
    src: 29.3,
    dur: 2.6,
    taps: [],
  },
];

export const SUMMARY =
  "Requested manual flow passed: title, first flap, scoring, background pause, resume, splash-down results and best-score persistence. The paused run survived a home-screen round trip with its score intact, and Best 7 persisted after terminate and relaunch. No visual issues found.";
