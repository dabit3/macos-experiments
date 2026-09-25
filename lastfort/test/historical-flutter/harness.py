#!/usr/bin/env python3
"""Helpers for multiplayer-e2e.sh: poll the Lastfort server and compare the
match reports every platform sent back. Standard library only, Python 3.9+.

  harness.py wait-room   BASE CODE --members N [--timeout S]
  harness.py wait-phase  BASE CODE PHASE      [--timeout S]
  harness.py wait-reports BASE CODE --count N [--timeout S]
  harness.py compare     BASE CODE OUT_DIR --platforms web,ios,android,macos
"""
import argparse
import json
import sys
import time
import urllib.request


def fetch(url):
    with urllib.request.urlopen(url, timeout=5) as resp:
        return json.loads(resp.read().decode("utf-8"))


def room_state(base, code):
    for room in fetch(base + "/rooms").get("rooms", []):
        if room.get("code") == code:
            return room
    return None


def wait(pred, timeout, label):
    deadline = time.time() + timeout
    last = None
    while time.time() < deadline:
        try:
            value = pred()
        except Exception as exc:  # server not up yet / transient
            value = None
            last = str(exc)
        if value:
            return value
        time.sleep(0.5)
    print("timeout waiting for %s (%s)" % (label, last), file=sys.stderr)
    sys.exit(1)


def cmd_wait_room(a):
    def ready():
        room = room_state(a.base, a.code)
        if room is None:
            return None
        players = room.get("players", [])
        if len(players) >= a.members:
            return room
        return None

    room = wait(ready, a.timeout, "%d members in %s" % (a.members, a.code))
    print(json.dumps([(p["name"], p["platform"]) for p in room["players"]]))


def cmd_wait_phase(a):
    wanted = set(a.phase.split(","))

    def ready():
        room = room_state(a.base, a.code)
        return room if room and room.get("phase") in wanted else None

    room = wait(ready, a.timeout, "phase %s in %s" % (a.phase, a.code))
    print(room.get("phase"))


def cmd_wait_reports(a):
    def ready():
        reports = fetch("%s/rooms/%s/reports" % (a.base, a.code)).get("reports", {})
        return reports if len(reports) >= a.count else None

    reports = wait(ready, a.timeout, "%d reports for %s" % (a.count, a.code))
    print(",".join(sorted(reports)))


def canonical(summary):
    if isinstance(summary, str):
        summary = json.loads(summary)
    return json.dumps(summary, sort_keys=True, separators=(",", ":"))


def cmd_compare(a):
    platforms = a.platforms.split(",")
    reports = fetch("%s/rooms/%s/reports" % (a.base, a.code)).get("reports", {})
    server = fetch("%s/rooms/%s/summary" % (a.base, a.code))
    server_summary = server.get("summary")
    failures = []
    rows = {}
    for platform in platforms:
        report = reports.get(platform)
        if report is None:
            failures.append("no report from %s" % platform)
            continue
        rows[platform] = {
            "name": report.get("name"),
            "playerId": report.get("playerId"),
            "digest": report.get("digest"),
            "snapshots": report.get("snapshots"),
            "summary": canonical(report.get("summary")),
        }
    digests = {r["digest"] for r in rows.values()}
    summaries = {r["summary"] for r in rows.values()}
    if len(rows) == len(platforms):
        if len(digests) != 1:
            failures.append("digests differ: %s" % {k: v["digest"] for k, v in rows.items()})
        if len(summaries) != 1:
            failures.append("summaries differ across platforms")
        if server_summary is not None and canonical(server_summary) not in summaries:
            failures.append("client summaries differ from the server summary")
    summary = json.loads(next(iter(summaries))) if summaries else {}
    players = summary.get("players", [])
    humans = [p for p in players if not p.get("bot")]
    human_platforms = sorted(p.get("platform") for p in humans)
    if human_platforms != sorted(platforms):
        failures.append("human platforms in summary: %s" % human_platforms)
    teams = {p.get("team") for p in humans}
    if len(teams) != 1:
        failures.append("humans were not one squad: teams %s" % sorted(teams))
    if summary.get("winnerTeam") is None:
        failures.append("match has no winner")
    for p in humans:
        if not p.get("harvested"):
            failures.append("%s harvested nothing" % p.get("platform"))
        if not p.get("built"):
            failures.append("%s built nothing" % p.get("platform"))
    if summary.get("stormPhase", 0) < 1:
        failures.append("no storm phase reached")
    result = {
        "code": a.code,
        "passed": not failures,
        "failures": failures,
        "digest": next(iter(digests)) if len(digests) == 1 else None,
        "platforms": rows,
        "summary": summary,
        "server_phase": server.get("phase"),
    }
    with open(a.out + "/result.json", "w") as f:
        json.dump(result, f, indent=2, sort_keys=True)
    lines = ["# Lastfort %d-client multiplayer match" % len(platforms), ""]
    lines.append("Room `%s` — %s" % (a.code, "PASS" if not failures else "FAIL"))
    lines.append("")
    lines.append("| platform | player | digest | snapshots |")
    lines.append("|---|---|---|---|")
    for platform in platforms:
        r = rows.get(platform)
        if r:
            lines.append("| %s | %s (#%s) | `%s` | %s |" % (
                platform, r["name"], r["playerId"], r["digest"], r["snapshots"]))
        else:
            lines.append("| %s | — | missing | — |" % platform)
    lines.append("")
    lines.append("| placement | name | platform | team | elims | dmg | harvested | built | chests | survived s |")
    lines.append("|---|---|---|---|---|---|---|---|---|---|")
    for p in sorted(players, key=lambda p: (p.get("placement") or 99, p.get("id", 0))):
        lines.append("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (
            p.get("placement"), p.get("name"), p.get("platform"), p.get("team"),
            p.get("kills"), p.get("damage"), p.get("harvested"), p.get("built"),
            p.get("chests"), p.get("survived")))
    if failures:
        lines.append("")
        lines.append("## Failures")
        lines.extend("- " + f for f in failures)
    with open(a.out + "/report.md", "w") as f:
        f.write("\n".join(lines) + "\n")
    print("\n".join(lines))
    sys.exit(0 if not failures else 1)


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("wait-room")
    p.add_argument("base")
    p.add_argument("code")
    p.add_argument("--members", type=int, required=True)
    p.add_argument("--timeout", type=float, default=180)
    p.set_defaults(fn=cmd_wait_room)
    p = sub.add_parser("wait-phase")
    p.add_argument("base")
    p.add_argument("code")
    p.add_argument("phase")
    p.add_argument("--timeout", type=float, default=180)
    p.set_defaults(fn=cmd_wait_phase)
    p = sub.add_parser("wait-reports")
    p.add_argument("base")
    p.add_argument("code")
    p.add_argument("--count", type=int, required=True)
    p.add_argument("--timeout", type=float, default=600)
    p.set_defaults(fn=cmd_wait_reports)
    p = sub.add_parser("compare")
    p.add_argument("base")
    p.add_argument("code")
    p.add_argument("out")
    p.add_argument("--platforms", default="web,ios,android,macos")
    p.set_defaults(fn=cmd_compare)
    a = ap.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
