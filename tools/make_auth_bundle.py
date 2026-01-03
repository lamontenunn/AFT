#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
from datetime import datetime

FILES = [
    "lib/main.dart",
    "lib/firebase_options.dart",
    "lib/features/auth/auth_gate.dart",
    "lib/features/auth/auth_side_effects.dart",
    "lib/features/auth/providers.dart",
    "lib/features/auth/auth_state.dart",
    "lib/features/auth/sign_in_page.dart",
    "lib/features/saves/guest_migration.dart",
    "lib/data/aft_repository.dart",
    "lib/data/aft_repository_local.dart",
    "lib/data/repository_providers.dart",
]

OUT = "auth_bundle.md"

def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")

def with_line_numbers(text: str) -> str:
    lines = text.splitlines()
    return "\n".join(f"{i+1:4d} | {line}" for i, line in enumerate(lines)) + ("\n" if text.endswith("\n") else "")

def main() -> None:
    root = Path.cwd()
    missing = [p for p in FILES if not (root / p).exists()]

    out_path = root / OUT
    parts: list[str] = []
    parts.append(f"# Auth bundle\n")
    parts.append(f"- Generated: {datetime.now().isoformat(timespec='seconds')}\n")
    parts.append(f"- Project root: `{root}`\n")
    if missing:
        parts.append(f"\n## Missing files (skipped)\n")
        for m in missing:
            parts.append(f"- `{m}`\n")
        parts.append("\n---\n")

    for rel in FILES:
        path = root / rel
        if not path.exists():
            continue
        parts.append(f"\n---\n\n## `{rel}`\n")
        parts.append("```dart\n")
        parts.append(with_line_numbers(read_text(path)))
        parts.append("```\n")

    out_path.write_text("".join(parts), encoding="utf-8")
    print(f"Wrote {out_path}")

if __name__ == "__main__":
    main()
