import { LLM_BASELINE_S_PER_CELL, summarize, type RunStats, type Totals } from "../lib/jevClient.ts";
import { fmtDuration, fmtMs } from "./format.ts";

type Props = {
  run: RunStats;
  totals: Totals;
  now: number;
  lastError: string | null;
  flash: string | null;
  health: { mode: string; ok: boolean; concurrency: number };
};

function Tile({ label, value, unit, className }: { label: string; value: string; unit?: string; className?: string }) {
  return (
    <div className={`tile${className ? ` ${className}` : ""}`}>
      <div className="tilevalue">
        {value}
        {unit && <span className="tileunit">{unit}</span>}
      </div>
      <div className="tilelabel">{label}</div>
    </div>
  );
}

export function StatusBar({ run, totals, now, lastError, flash, health }: Props) {
  const elapsed = run.active ? now - run.startedAt : run.elapsedMs;
  const { p50, p95 } = summarize(run.latencies);
  const rate = elapsed > 0 ? run.cellsDone / (elapsed / 1000) : 0;
  const baselineS = run.cells * LLM_BASELINE_S_PER_CELL;
  const speedup = elapsed > 0 ? (baselineS * 1000) / elapsed : 0;
  const progress = run.requests > 0 ? run.requestsDone / run.requests : 0;
  const recent = run.latencies.slice(-80);
  const maxLat = Math.max(1, ...recent);
  const hasRun = run.requests > 0;
  const dash = "—";

  return (
    <div className={`statusbar${run.active ? " running" : ""}`}>
      <div className="progress" style={{ width: `${(run.active ? progress : 0) * 100}%` }} />
      <div className="hudtitle">
        <div className="hudname">{run.active ? "Judging…" : hasRun ? "Last run" : "Ready"}</div>
        <div className="hudsub">
          {flash ?? (hasRun ? `${run.requests} requests · ${health.concurrency} in parallel` : "edit a rubric, then Fill column ↓")}
        </div>
      </div>
      <Tile label="cells re-judged" value={hasRun ? String(run.cellsDone) : dash} className="cells" />
      <Tile label="total time" value={hasRun ? fmtMs(elapsed) : dash} className="time" />
      <Tile label="median latency" value={hasRun ? fmtMs(p50) : dash} />
      <Tile label="p95 latency" value={hasRun ? fmtMs(p95) : dash} />
      <Tile label="cells / second" value={hasRun ? rate.toFixed(0) : dash} />
      <div className="spark" title="latency of the last requests (ms)">
        {recent.map((ms, i) => (
          <i key={i} style={{ height: `${Math.max(8, (ms / maxLat) * 100)}%` }} />
        ))}
      </div>
      <div className="tile baseline" title={`simulated per-cell LLM call at ${LLM_BASELINE_S_PER_CELL} s per cell, ${run.cells} cells`}>
        <div className="tilevalue">
          {hasRun ? fmtDuration(baselineS) : dash}
          {hasRun && speedup > 1 && (
            <span className="speedup">{speedup >= 100 ? speedup.toFixed(0) : speedup.toFixed(1)}× faster</span>
          )}
        </div>
        <div className="tilelabel">per-cell LLM @ {LLM_BASELINE_S_PER_CELL} s / cell</div>
      </div>
      <div className="totals dim" title="cumulative for this page load">
        session {totals.cells} cells · {totals.requests} req
        {run.retries > 0 && ` · ${run.retries} retries`}
        {run.errors > 0 && <span className="err"> · {run.errors} errors</span>}
        {lastError && <span className="err"> · {lastError}</span>}
      </div>
    </div>
  );
}
