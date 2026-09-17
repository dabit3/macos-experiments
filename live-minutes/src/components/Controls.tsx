import type { MeetingState, Mode, Speed } from "../lib/useMeeting.ts";
import { MEETING, MEETING_TITLE, TRANSCRIPT } from "../data/transcript.ts";

interface Props {
  s: MeetingState;
  onStart: () => void;
  onStop: () => void;
  onReset: () => void;
  onMode: (m: Mode) => void;
  onSpeed: (sp: Speed) => void;
  onMicSpeaker: (n: string) => void;
}

export function Controls({ s, onStart, onStop, onReset, onMode, onSpeed, onMicSpeaker }: Props) {
  const running = s.phase === "running";
  const h = s.health;
  const source = h === null ? { cls: "bad", text: "proxy offline" } : h.mock ? { cls: "warn", text: "MOCK · recorded answers" } : h.hasKey ? { cls: "good", text: "real TypeSafe Jev · jev-latest" } : { cls: "bad", text: "no TYPESAFE_API_KEY" };

  return (
    <header className="topbar">
      <div className="brand">
        <img src="./live-minutes.svg" alt="" width={22} height={22} />
        <h1>Live Minutes</h1>
        <span className="tagline">who owns what by when — as it is said</span>
      </div>

      <div className="mode">
        <button type="button" className={s.mode === "replay" ? "on" : ""} disabled={running} onClick={() => onMode("replay")}>
          Replay
        </button>
        <button
          type="button"
          className={s.mode === "mic" ? "on" : ""}
          disabled={running || !s.micSupported}
          title={s.micSupported ? "Web Speech API (Chrome)" : "Web Speech API not available in this browser"}
          onClick={() => onMode("mic")}
        >
          Live mic{!s.micSupported && " · n/a"}
        </button>
      </div>

      {s.mode === "replay" ? (
        <div className="speed">
          {([1, 4, "instant"] as Speed[]).map((sp) => (
            <button type="button" key={String(sp)} className={s.speed === sp ? "on" : ""} disabled={running} onClick={() => onSpeed(sp)}>
              {sp === "instant" ? "all at once" : `${sp}×`}
            </button>
          ))}
          <span className="fixture muted small" title={MEETING_TITLE}>
            {MEETING_TITLE} · {TRANSCRIPT.length} utterances · {MEETING.attendees.length} people · 12 min
          </span>
        </div>
      ) : (
        <div className="speed">
          <label className="small muted">
            speaker&nbsp;
            <input value={s.micSpeaker} disabled={running} onChange={(e) => onMicSpeaker(e.target.value)} />
          </label>
        </div>
      )}

      <div className="topbar-actions">
        {!running ? (
          <button type="button" className="primary" onClick={onStart} disabled={h !== null && !h.mock && !h.hasKey}>
            ▶ Start
          </button>
        ) : (
          <button type="button" className="danger" onClick={onStop}>
            ■ Stop
          </button>
        )}
        <button type="button" onClick={onReset} disabled={s.phase === "idle"}>
          Reset
        </button>
        <span className={`source ${source.cls}`}>{source.text}</span>
      </div>
    </header>
  );
}
