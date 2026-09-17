import type { MinuteItem } from "../lib/aggregate.ts";
import type { Bucket } from "../lib/resolve.ts";
import type { Attendee } from "../lib/types.ts";
import type { Row } from "../lib/useMeeting.ts";
import { ItemCard } from "./ItemCard.tsx";
import { BUCKET_TITLE } from "./labels.ts";

const ORDER: Bucket[] = ["actions", "decisions", "questions", "risks"];

interface Props {
  items: MinuteItem[];
  rows: Row[];
  attendees: Attendee[];
  onShown: (id: number, ms: number) => void;
  onFix: (id: number, name: string | null) => void;
}

export function Lists({ items, rows, attendees, onShown, onFix }: Props) {
  const spokenAt = new Map(rows.map((r) => [r.id, r.spokenAt]));
  return (
    <section className="lists">
      {ORDER.map((b) => {
        const list = items.filter((x) => x.bucket === b);
        return (
          <div key={b} className={`panel list ${b}`}>
            <header className="panel-head">
              <h2>{BUCKET_TITLE[b]}</h2>
              <span className="count">{list.length}</span>
            </header>
            <div className="scroll">
              {list.length === 0 && <p className="empty">—</p>}
              {list.map((x) => (
                <ItemCard
                  key={x.id}
                  item={x}
                  spokenAt={spokenAt.get(x.utteranceId) ?? performance.now()}
                  attendees={attendees}
                  onShown={onShown}
                  onFix={onFix}
                />
              ))}
            </div>
          </div>
        );
      })}
    </section>
  );
}
