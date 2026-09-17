import type { MeetingState } from "../lib/useMeeting.ts";
import { CONCURRENCY } from "../lib/useMeeting.ts";
import { fmtClock, fmtMs, summarize } from "../lib/stats.ts";

function Stat({ label, value, sub, tone }: { label: string; value: string; sub?: string; tone?: string }) {
  return (
    <div className={`hud-stat${tone ? ` ${tone}` : ""}`}>
      <span className="hud-v">{value}</span>
      <span className="hud-l">{label}</span>
      {sub && <span className="hud-s">{sub}</span>}
    </div>
  );
}

export function Hud({ s }: { s: MeetingState }) {
  const screen = summarize(s.screenLatencies);
  const api = summarize(s.apiLatencies);
  const client = summarize(s.clientLatencies);
  const wallElapsed = s.wallStart !== null ? ((s.wallEnd ?? performance.now()) - s.wallStart) / 1000 : 0;
  const judged = s.rows.filter((r) => r.status === "done").length;
  const items = s.agg.items.length;
  const rate = wallElapsed > 0 ? judged / wallElapsed : 0;
  const last = s.rows.filter((r) => r.status === "done").at(-1);

  return (
    <footer className="hud">
      <Stat label="meeting clock" value={fmtClock(s.clock)} sub={s.mode === "replay" && s.speed !== "instant" ? `${s.speed}× replay` : s.mode === "replay" ? "all at once" : "live mic"} />
      <Stat label="wall elapsed" value={`${wallElapsed.toFixed(1)} s`} />
      <div className="hud-sep" />
      <Stat label="judged" value={`${judged}/${s.rows.length}`} sub={`${s.inFlight} in flight · limit ${CONCURRENCY}`} />
      <Stat label="items surfaced" value={String(items)} sub={`${rate.toFixed(1)} utt/s`} />
      <div className="hud-sep" />
      <Stat label="last call" value={last?.clientMs ? fmtMs(last.clientMs) : "—"} sub={last?.apiMs ? `api ${fmtMs(last.apiMs)}` : undefined} tone="accent" />
      <Stat label="p50 → screen" value={screen.n ? fmtMs(screen.p50) : "—"} sub={client.n ? `round trip ${fmtMs(client.p50)}` : undefined} tone="accent" />
      <Stat label="p95 → screen" value={screen.n ? fmtMs(screen.p95) : "—"} sub={client.n ? `round trip ${fmtMs(client.p95)}` : undefined} tone="accent" />
      <Stat label="Jev api p50" value={api.n ? fmtMs(api.p50) : "—"} sub={api.n ? `max ${fmtMs(api.max)}` : undefined} />
      <div className="hud-sep" />
      <Stat label="errors" value={String(s.errors)} tone={s.errors ? "bad" : undefined} sub={s.lastError ?? undefined} />
    </footer>
  );
}
