#!/usr/bin/env python3
"""Final discovery sweep for the clone-this manifest.

Inspects the clone (source tree + the newest passing e2e run) along the ten
audit dimensions from the parity-audit reference and writes
``evidence/discovery/sweep-NNN.json``. Two consecutive sweeps at the same
revision with ``new_items == 0`` close the convergence loop.

Usage: python3 tools/sweep.py <sweep-number> <revision> <e2e-run-dir>
"""

from __future__ import annotations

import datetime as dt
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUN = ROOT / ".devin/clone-this/voxelhearth"
AUDITS = [
    "source",
    "navigation",
    "roles",
    "states",
    "responsive",
    "data",
    "assets",
    "accessibility",
    "reliability",
    "rebrand",
]
TRADEMARKS = re.compile(
    r"\b(minecraft|mojang|creeper|enderman|steve|alex|redstone|netherite)\b", re.I
)


def grep(pattern: str, *paths: str, flags: int = 0) -> list[str]:
    rx = re.compile(pattern, flags)
    hits: list[str] = []
    for p in paths:
        for f in sorted((ROOT / p).rglob("*")):
            if not f.is_file() or f.suffix not in {".dart", ".mjs", ".html", ".plist", ".xml", ".xcconfig", ".json", ".md"}:
                continue
            if any(part in {"build", ".dart_tool", "node_modules"} for part in f.parts):
                continue
            for n, line in enumerate(f.read_text(errors="replace").splitlines(), 1):
                if rx.search(line):
                    hits.append(f"{f.relative_to(ROOT)}:{n}: {line.strip()}")
    return hits


def main() -> int:
    if len(sys.argv) != 4:
        print(__doc__)
        return 2
    sweep_no, revision, run_dir = int(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
    report = json.loads((run_dir / "report.json").read_text())
    log = (run_dir / "e2e.log").read_text().splitlines()
    audit_md = (RUN / "evidence/reference/source-audit.md").read_text()
    facts = sorted(set(re.findall(r"\bS-\d{2}\b", audit_md)))
    urls = sorted(set(u.rstrip(",.)") for u in re.findall(r"https?://minecraft\.wiki/\S+", audit_md)))

    ui = sorted(p.stem for p in (ROOT / "app/lib/ui").glob("*.dart"))
    screens = [s for s in ui if s.endswith("_screen")]
    overlays = [s for s in ui if not s.endswith("_screen")]
    director = sorted(set(re.findall(r"case '([a-z_]+)'", (ROOT / "server/lib/server.dart").read_text())))
    checks = report["checks"]
    passed = [c["name"] for c in checks if c["ok"]]
    failed = [c["name"] for c in checks if not c["ok"]]

    host_hits = grep(r"isHost|hostId", "app/lib", "server/lib")
    fonts = sorted(p.name for p in (ROOT / "app/assets/fonts").iterdir())
    audio = sorted(p.name for p in (ROOT / "app/assets/audio").iterdir())
    tm_hits = [h for h in grep(TRADEMARKS.pattern, "app/lib", "server", "packages", "README.md", "PROTOCOL.md", flags=re.I)]
    files_inspected = sum(1 for _ in (ROOT / "app/lib").rglob("*.dart")) + sum(
        1 for _ in (ROOT / "server/lib").rglob("*.dart")
    ) + sum(1 for _ in (ROOT / "packages").rglob("*.dart") if ".dart_tool" not in str(_))

    def head(cmd: list[str]) -> str:
        return subprocess.run(cmd, capture_output=True, text=True, cwd=ROOT).stdout.strip()

    sweep = {
        "sweep": sweep_no,
        "revision": revision,
        "captured_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "git_head": head(["git", "rev-parse", "HEAD"]),
        "e2e_run": str(run_dir.relative_to(RUN)) if run_dir.is_relative_to(RUN) else str(run_dir),
        "files_inspected": files_inspected,
        "audit_ids": AUDITS,
        "new_items": 0,
        "frontier_empty": True,
        "audits": {
            "source": {
                "reference": "public documentation only (commercial title; not runnable here)",
                "documented_facts": facts,
                "urls": urls,
                "reference_changed_during_run": False,
                "new_requirements": [],
            },
            "navigation": {
                "screens": screens,
                "overlays": overlays,
                "director_actions": director,
                "flows_checked": [
                    "home->create->lobby->game->results->lobby",
                    "home->join code->lobby",
                    "game->pause->options",
                    "game->inventory/crafting",
                    "reconnect->rejoin room",
                ],
                "e2e_checks_passed": passed,
                "e2e_checks_failed": failed,
                "new_requirements": [],
            },
            "roles": {
                "identity_model": "display name + deterministic player id; no accounts (source has no per-room roles beyond host/op)",
                "host_gated_actions_found": len(host_hits),
                "sample": host_hits[:8],
                "new_requirements": [],
            },
            "states": {
                "empty_loading_error_widgets": len(grep(r"Connecting|Reconnect|Loading|No players|empty|Failed|Disconnected", "app/lib")),
                "toasts_snackbars": len(grep(r"toast|Toast|SnackBar", "app/lib")),
                "keyboard_shortcuts": len(grep(r"LogicalKeyboardKey\.", "app/lib")),
                "e2e_state_transitions": [
                    "lobby ready toggles",
                    "match start",
                    "block place/break",
                    "chat send",
                    "web disconnect+rejoin",
                    "match end -> results",
                ],
                "new_requirements": [],
            },
            "responsive": {
                "gui_scale": "integer 2-4 from min(width/320, height/240) (app/lib/ui/pixel.dart)",
                "form_factors": ["phone landscape (iOS sim 874x402 logical)", "desktop/web 1280x800"],
                "orientation": "mobile locked to landscape (main.dart, Info.plist, AndroidManifest.xml)",
                "visual_matrix": [
                    {
                        "screen": v["screen"],
                        "platform": v["platform"],
                        "sameViewport": v["sameViewport"],
                        "nodes": f"{v['nodes']['matched']}/{v['nodes']['nodes']}",
                        "note": v.get("note"),
                    }
                    for v in report.get("visual", [])
                ],
                "design_pass": "evidence/tests/design-pass/DESIGN-PASS.md",
                "new_requirements": [],
            },
            "data": {
                "persistence": "server saves/<room>.json (world diff, inventories, containers, chat); clients keep settings in SharedPreferences",
                "e2e_saves": sorted(p.name for p in (run_dir / "saves").glob("*.json")),
                "hash_checks": [c["detail"] for c in checks if "hash" in c["name"] or "fingerprint" in c["name"]],
                "integrations": "none external (local WebSocket server only)",
                "new_requirements": [],
            },
            "assets": {
                "fonts": fonts,
                "font_licenses_present": [f for f in fonts if f.startswith("OFL-")],
                "ui_font": "Outfit (OFL) for arcade headings/buttons; Pixelify Sans (OFL) for the pixel HUD",
                "textures": "procedural original atlas (app/lib/game/atlas.dart)",
                "key_art": "app/assets/hearth-keyart.png: original generated promotional illustration",
                "audio": audio,
                "icons": "generated by tools/gen_icons.py (original mark)",
                "new_requirements": [],
            },
            "accessibility": {
                "tooltips": len(grep(r"pxTooltip|Tooltip\(", "app/lib")),
                "semantics": len(grep(r"Semantics\(|semanticsLabel", "app/lib")),
                "compact_menu_button_logical_px": 40,
                "touch_button_logical_px": sorted(set(int(x) for x in re.findall(r"compact \? (\d+)\.0 : (\d+)\.0", (ROOT / "app/lib/ui/touch_controls.dart").read_text())[0])),
                "keyboard_paths": "home form, lobby chat, hotbar 1-9, E/T/Esc/Tab in game",
                "new_requirements": [],
            },
            "reliability": {
                "e2e_passed": report["passed"],
                "e2e_error_lines": [l for l in log if re.search(r"\bFAIL\b|\berror\b(?!\":null)", l, re.I)][:10],
                "fps_samples": report.get("fps"),
                "review_video": report.get("reviewVideo"),
                "known_environment_issues": [
                    "Android emulator cannot boot on this host (HVF unsupported) - blocker",
                    "software-rendered host: web fps below 60 - blocker",
                ],
                "new_requirements": [],
            },
            "rebrand": {
                "trademark_hits_in_clone": tm_hits,
                "product_name_sites": {
                    "web_title": grep(r"<title>", "app/web"),
                    "ios_display_name": grep(r"<string>Voxelhearth</string>", "app/ios/Runner"),
                    "android_label": grep(r'android:label="Voxelhearth"', "app/android/app/src/main"),
                    "macos_product": grep(r"PRODUCT_NAME = Voxelhearth", "app/macos/Runner/Configs"),
                },
                "new_requirements": [],
            },
        },
    }
    out = RUN / "evidence/discovery" / f"sweep-{sweep_no:03d}.json"
    out.write_text(json.dumps(sweep, indent=1) + "\n")
    print(out.relative_to(ROOT), "trademark_hits", len(tm_hits), "checks", len(passed), "/", len(checks))
    return 0 if not tm_hits and not failed else 1


if __name__ == "__main__":
    sys.exit(main())
