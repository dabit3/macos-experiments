import { readFile, writeFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";

export function prepareRecording(source, duration, video, fallback = "") {
  if (!Number.isFinite(duration) || duration <= 0) {
    throw new Error("A positive ffprobe duration is required.");
  }
  if (!/^[\w.-]+\.webm$/i.test(video)) {
    throw new Error("Video must be a sibling .webm filename.");
  }
  if (fallback && !/^https:\/\/[^<>\s]+\.webm$/i.test(fallback)) {
    throw new Error("Fallback must be an HTTPS WebM attachment URL.");
  }
  if (!source || !Array.isArray(source.annotations) || !source.annotations.length) {
    throw new Error("The recording must contain real annotations.");
  }
  const fields = ["test", "test_result", "assertion", "description", "display_text", "action_type"];
  const annotations = source.annotations.map((event, index) => {
    if (!["setup", "test_start", "assertion", "action"].includes(event.type)) {
      throw new Error(`Unsupported annotation at ${index}.`);
    }
    if (!Number.isFinite(event.edited_time_s) || event.edited_time_s < 0) {
      throw new Error(`Invalid edited timeline timestamp at ${index}.`);
    }
    const clean = {
      type: event.type,
      time: event.edited_time_s,
      seekable: event.edited_time_s < duration,
    };
    for (const field of fields) {
      if (typeof event[field] === "string") clean[field] = event[field];
    }
    for (const field of ["x", "y", "source_time_ms"]) {
      if (Number.isFinite(event[field])) clean[field] = event[field];
    }
    return clean;
  });
  for (let i = 1; i < annotations.length; i++) {
    if (annotations[i].time < annotations[i - 1].time) {
      throw new Error("Edited timeline must be ordered.");
    }
  }
  return { title: "Havik · Computer-use demo", duration, video, fallback, annotations };
}

export function embedRecording(template, recording) {
  if (!template.includes("__RECORDING_DATA__")) throw new Error("Template marker missing.");
  const json = JSON.stringify(recording).replaceAll("<", "\\u003c");
  return template.replace("__RECORDING_DATA__", () => json);
}

async function main() {
  const [annotations, duration, video, output, fallback] = process.argv.slice(2);
  if (!output) {
    throw new Error("Usage: node tools/build-test-artifact.mjs ANNOTATIONS DURATION VIDEO.webm OUTPUT.html [HTTPS_WEBM_URL]");
  }
  const source = JSON.parse(await readFile(annotations, "utf8"));
  const data = prepareRecording(source, Number(duration), video, fallback);
  const template = await readFile(new URL("./test-artifact.html", import.meta.url), "utf8");
  await writeFile(output, embedRecording(template, data));
  console.log(`${data.annotations.length} recorded events; ${data.annotations.filter((event) => !event.seekable).length} outside clip; ${output}`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}
