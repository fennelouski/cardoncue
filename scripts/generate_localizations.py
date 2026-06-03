#!/usr/bin/env python3
"""Generate Localizable.strings for target locales from en source + per-locale JSON packs."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP_DIR = ROOT / "CardOnCue"
LOCALES_DIR = Path(__file__).resolve().parent / "locales"
SOURCE_LOCALE = "en"
STRINGS_NAME = "Localizable.strings"

ENTRY_RE = re.compile(
    r'^(\s*)"(?P<key>(?:\\.|[^"\\])*)"\s*=\s*"(?P<value>(?:\\.|[^"\\])*)"\s*;\s*$'
)


def escape_strings_value(s: str) -> str:
    return (
        s.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\r", "\\r")
        .replace("\t", "\\t")
    )


def load_locale_pack(locale: str) -> dict:
    path = LOCALES_DIR / f"{locale}.json"
    if not path.exists():
        raise FileNotFoundError(path)
    data = json.loads(path.read_text(encoding="utf-8"))
    if "values" not in data:
        raise ValueError(f"{path}: expected top-level 'values' object")
    return data


def main() -> int:
    source_path = APP_DIR / f"{SOURCE_LOCALE}.lproj" / STRINGS_NAME
    source_text = source_path.read_text(encoding="utf-8")

    locale_files = sorted(LOCALES_DIR.glob("*.json"))
    if not locale_files:
        print("No locale JSON files found in scripts/locales/", file=sys.stderr)
        return 1

    written = 0
    for json_path in locale_files:
        locale = json_path.stem
        data = load_locale_pack(locale)
        values: dict[str, str] = data["values"]
        add_manually: list[str] | None = data.get("add_manually")

        lproj = APP_DIR / f"{locale}.lproj"
        lproj.mkdir(parents=True, exist_ok=True)
        out_path = lproj / STRINGS_NAME

        out_lines: list[str] = []
        add_idx = 0
        for line in source_text.splitlines():
            m = ENTRY_RE.match(line)
            if not m:
                out_lines.append(line)
                continue
            key = bytes(m.group("key"), "utf-8").decode("unicode_escape")
            if key == "add_manually" and add_manually and len(add_manually) == 2:
                val = add_manually[add_idx]
                add_idx += 1
            elif key in values:
                val = values[key]
            else:
                raise KeyError(f"{locale}: missing key {key!r}")
            esc = escape_strings_value(val)
            out_lines.append(f'{m.group(1)}"{m.group("key")}" = "{esc}";')

        out_path.write_text("\n".join(out_lines) + "\n", encoding="utf-8")
        written += 1
        print(f"Wrote {out_path}")

    print(f"Generated {written} locale files.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
