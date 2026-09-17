import { useEffect, useState } from "react";
import { useMeeting } from "./lib/useMeeting.ts";
import { MEETING } from "./data/transcript.ts";
import { Controls } from "./components/Controls.tsx";
import { Transcript } from "./components/Transcript.tsx";
import { Lists } from "./components/Lists.tsx";
import { KeywordPanel, PostMeetingPanel } from "./components/Baselines.tsx";
import { Hud } from "./components/Hud.tsx";

export default function App() {
  const m = useMeeting();
  const s = m.state;
  const [, force] = useState(0);

  // The HUD's wall clock and the post-meeting timer need a heartbeat while running.
  useEffect(() => {
    if (s.phase !== "running") return;
    const id = window.setInterval(() => force((n) => n + 1), 100);
    return () => window.clearInterval(id);
  }, [s.phase]);

  const attendees = s.mode === "mic" ? [{ name: s.micSpeaker || "You", role: "speaker" }, ...MEETING.attendees] : MEETING.attendees;

  return (
    <div className={`app ${s.health?.mock ? "mock" : ""}`}>
      {s.health?.mock && <div className="mock-banner">MOCK MODE — answers replayed from server/mock-answers.json, no TypeSafe calls are being made</div>}
      <Controls s={s} onStart={m.start} onStop={m.stop} onReset={m.reset} onMode={m.setMode} onSpeed={m.setSpeed} onMicSpeaker={m.setMicSpeaker} />
      <main className="grid">
        <Transcript rows={s.rows} interim={s.micInterim} micSpeaker={s.micSpeaker} />
        <Lists items={s.agg.items} rows={s.rows} attendees={attendees} onShown={m.shown} onFix={m.fixAssignee} />
        <aside className="baselines">
          <PostMeetingPanel phase={s.phase} clock={s.clock} wallStart={s.wallStart} wallEnd={s.wallEnd} items={s.agg.items} />
          <KeywordPanel rows={s.rows} hasTruth={s.mode === "replay"} />
        </aside>
      </main>
      <Hud s={s} />
    </div>
  );
}
