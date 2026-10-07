import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { embedRecording, prepareRecording } from "./build-test-artifact.mjs";

const event = { type: "action", edited_time_s: 3.2, source_time_ms: 5000, action_type: "key", display_text: "ctrl+a" };
const source = { annotations: [event], video_url: "/private/internal.mp4" };

test("preserves real edited timestamps and strips internal video paths", () => {
  const data = prepareRecording(source, 10, "recording.webm");
  assert.equal(data.annotations[0].time, 3.2);
  assert.equal(data.annotations[0].source_time_ms, 5000);
  assert.equal(data.annotations[0].display_text, "ctrl+a");
  assert.equal(data.video, "recording.webm");
  assert.ok(!JSON.stringify(data).includes("/private"));
  assert.equal(source.annotations[0], event);
});

test("does not invent seek times for annotations beyond the clip", () => {
  const data = prepareRecording({ annotations: [event, { ...event, edited_time_s: 12 }] }, 10, "recording.webm");
  assert.equal(data.annotations[0].seekable, true);
  assert.equal(data.annotations[1].seekable, false);
  assert.equal(data.annotations[1].time, 12);
});

test("rejects unusable media and invalid or unordered timestamps", () => {
  for (const duration of [0, -1, NaN, Infinity]) assert.throws(() => prepareRecording(source, duration, "recording.webm"));
  for (const video of ["recording.mp4", "../recording.webm", "javascript:alert(1)"]) assert.throws(() => prepareRecording(source, 10, video));
  assert.throws(() => prepareRecording(source, 10, "a.webm", "http://example.com/a.webm"));
  assert.throws(() => prepareRecording({ annotations: [{ ...event, edited_time_s: -1 }] }, 10, "a.webm"));
  assert.throws(() => prepareRecording({ annotations: [event, { ...event, edited_time_s: 0 }] }, 10, "a.webm"));
});

test("embedding protects the inline JSON from script and replacement injection", async () => {
  const template = await readFile(new URL("./test-artifact.html", import.meta.url), "utf8");
  const payload = "</script><script>alert('$&')</script>";
  const data = prepareRecording({ annotations: [{ ...event, display_text: payload }] }, 10, "recording.webm");
  const html = embedRecording(template, data);
  const json = html.match(/<script id="recording-data" type="application\/json">([\s\S]*?)<\/script>/)[1];
  assert.equal(JSON.parse(json).annotations[0].display_text, payload);
  assert.ok(!html.includes(payload));
  assert.ok(!html.includes("__RECORDING_DATA__"));
  assert.ok(html.indexOf('aria-label="Recorded browser video"') < html.indexOf('aria-label="Programmatic test steps"'));
});
