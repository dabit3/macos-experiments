import { useEffect, useRef } from "react";
import type { Row } from "../lib/useMeeting.ts";
import { fmtClock, fmtMs } from "../lib/stats.ts";
import { KIND_LABEL, speakerClass } from "./labels.ts";

export function Transcript({
  rows,
  interim,
  micSpeaker,
  micError,
}: {
  rows: Row[];
  interim: string;
  micSpeaker: string;
  micError: string | null;
}) {
  const bottom = useRef<HTMLDivElement>(null);
  useEffect(() => {
    bottom.current?.scrollIntoView({ block: "end" });
  }, [rows.length, interim]);

  return (
    <section className="panel transcript">
      <header className="panel-head">
        <h2>Transcript</h2>
        <span className="muted">{rows.length} utterances</span>
      </header>
      <div className="scroll">
        {micError && <p className="empty mic-error">{micError}</p>}
        {rows.length === 0 && !interim && !micError && <p className="empty">Press <b>Start</b> to replay the standup, or switch to Live mic.</p>}
        {rows.map((r) => (
          <div key={r.id} className={`utt ${r.status}`}>
            <span className="utt-time">{fmtClock(r.endsAt)}</span>
            <span className={`utt-speaker ${speakerClass(r.speaker)}`}>{r.speaker.split(" ")[0]}</span>
            <span className="utt-text">{r.text}</span>
            <span className="utt-tag">
              {r.status === "pending" && <span className="spin" title="judging…" />}
              {r.status === "error" && <span className="tag err" title={r.error}>error</span>}
              {r.status === "done" && r.judgment && (
                <>
                  <span className={`tag k-${r.judgment.kind}`}>{KIND_LABEL[r.judgment.kind]}</span>
                  <span className="lat">{fmtMs(r.clientMs ?? 0)}</span>
                </>
              )}
            </span>
          </div>
        ))}
        {interim && (
          <div className="utt interim">
            <span className="utt-time">…</span>
            <span className={`utt-speaker ${speakerClass(micSpeaker)}`}>{micSpeaker}</span>
            <span className="utt-text">{interim}</span>
          </div>
        )}
        <div ref={bottom} />
      </div>
    </section>
  );
}
