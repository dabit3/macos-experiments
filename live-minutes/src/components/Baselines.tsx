import type { MinuteItem } from "../lib/aggregate.ts";
import type { Row, Phase } from "../lib/useMeeting.ts";
import { fmtClock } from "../lib/stats.ts";
import { ACTION_KEYWORDS } from "../lib/keyword.ts";
import { BUCKET_TITLE } from "./labels.ts";
import type { Bucket } from "../lib/resolve.ts";

export function PostMeetingPanel({ phase, clock, wallStart, wallEnd, items }: { phase: Phase; clock: number; wallStart: number | null; wallEnd: number | null; items: MinuteItem[] }) {
  const waited = wallStart !== null ? ((wallEnd ?? performance.now()) - wallStart) / 1000 : 0;
  const order: Bucket[] = ["actions", "decisions", "questions", "risks"];
  return (
    <div className="panel baseline post">
      <header className="panel-head">
        <h2>Post-meeting summary <span className="pill illustrative">illustrative · LLM style</span></h2>
        <span className="muted">{phase === "done" ? "delivered after the call" : "nothing until the call ends"}</span>
      </header>
      <div className="scroll">
        {phase !== "done" ? (
          <div className="waiting">
            <div className="big-timer">{fmtClock(clock)}</div>
            <p>
              {phase === "idle" ? "A summarisation prompt runs once, on the full transcript, after the meeting." : "Meeting in progress — the summariser has nothing to show yet."}
            </p>
            <p className="muted small">Live items on the right have been visible for the whole time this counter has been running.</p>
          </div>
        ) : (
          <div className="dump">
            <p className="muted small">
              Same {items.filter((x) => x.supersededBy === null).length} items, first visible {waited.toFixed(0)} s after the meeting started — all at once, when nobody can correct them in the room.
            </p>
            {order.map((b) => {
              const list = items.filter((x) => x.bucket === b && x.supersededBy === null);
              if (!list.length) return null;
              return (
                <div key={b} className="dump-group">
                  <h3>{BUCKET_TITLE[b]}</h3>
                  <ul>
                    {list.map((x) => (
                      <li key={x.id}>
                        {x.text}
                        {x.bucket === "actions" && <span className="muted"> — {x.assignee ?? "unassigned"}{x.deadline.kind !== "none" ? `, ${x.deadline.label}` : ""}</span>}
                      </li>
                    ))}
                  </ul>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}

export function KeywordPanel({ rows, hasTruth }: { rows: Row[]; hasTruth: boolean }) {
  const flagged = rows.filter((r) => r.keywordFlag);
  const trueActions = rows.filter((r) => r.truth?.kind === "action_item");
  const missed = trueActions.filter((r) => !r.keywordFlag);
  const fps = flagged.filter((r) => r.truth && r.truth.kind !== "action_item");
  const missRate = trueActions.length ? missed.length / trueActions.length : 0;
  const jevActions = rows.filter((r) => r.judgment?.kind === "action_item");
  const jevMissed = trueActions.filter((r) => r.status === "done" && r.judgment?.kind !== "action_item");

  return (
    <div className="panel baseline keyword">
      <header className="panel-head">
        <h2>Keyword heuristic <span className="pill">old way</span></h2>
        <span className="muted mono small">{ACTION_KEYWORDS.source.slice(0, 40)}…</span>
      </header>
      <div className="kw-stats">
        <div className="stat">
          <span className="v">{flagged.length}</span>
          <span className="l">flagged</span>
        </div>
        {hasTruth && (
          <>
            <div className="stat bad">
              <span className="v">{(missRate * 100).toFixed(0)}%</span>
              <span className="l">miss rate · {missed.length}/{trueActions.length} real action items</span>
            </div>
            <div className="stat bad">
              <span className="v">{fps.length}</span>
              <span className="l">false positives</span>
            </div>
            <div className="stat good">
              <span className="v">{trueActions.length ? (((trueActions.length - jevMissed.length) / trueActions.length) * 100).toFixed(0) : 0}%</span>
              <span className="l">Jev recall · {jevActions.length} flagged</span>
            </div>
          </>
        )}
      </div>
      <div className="scroll kw-list">
        {hasTruth &&
          missed.slice(-6).map((r) => (
            <div key={r.id} className="kw-miss">
              <span className="tag err">missed</span> <span className="muted">{r.speaker.split(" ")[0]}:</span> {r.text}
            </div>
          ))}
        {!hasTruth && flagged.slice(-6).map((r) => <div key={r.id} className="kw-miss">{r.text}</div>)}
      </div>
    </div>
  );
}
