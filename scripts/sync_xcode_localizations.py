#!/usr/bin/env python3
"""Register .lproj locales in CardOnCue.xcodeproj (knownRegions + Localizable.strings variant group)."""

from __future__ import annotations

import re
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PBXPROJ = ROOT / "CardOnCue.xcodeproj" / "project.pbxproj"
APP_DIR = ROOT / "CardOnCue"


def new_id() -> str:
    return uuid.uuid4().hex[:24].upper()


def discover_locales() -> list[str]:
    locales = []
    for child in sorted(APP_DIR.iterdir()):
        if child.is_dir() and child.name.endswith(".lproj"):
            loc = child.name[: -len(".lproj")]
            if (child / "Localizable.strings").exists():
                locales.append(loc)
    return locales


def main() -> None:
    text = PBXPROJ.read_text(encoding="utf-8")
    locales = discover_locales()
    if "en" not in locales:
        raise SystemExit("en locale required")

    # knownRegions
    regions_block = "knownRegions = (\n\t\t\t\tBase,\n"
    for loc in sorted(set(locales)):
        regions_block += f"\t\t\t\t{loc},\n"
    regions_block += "\t\t\t);"
    text = re.sub(
        r"knownRegions = \(\s*Base,[\s\S]*?\);",
        regions_block,
        text,
        count=1,
    )

    variant_children: list[tuple[str, str]] = []  # (id, locale)
    file_ref_lines: list[str] = []

    # Find en reference as template
    en_match = re.search(
        r'\t\t([0-9A-F]{24}) /\* en \*/ = \{isa = PBXFileReference; lastKnownFileType = text\.plist\.strings; name = en; path = en\.lproj/Localizable\.strings; sourceTree = "<group>"; \};',
        text,
    )
    if not en_match:
        raise SystemExit("Could not find en PBXFileReference")

    refs_by_locale: dict[str, str] = {}
    for m in re.finditer(
        r'\t\t([0-9A-F]{24}) /\* ([^*]+) \*/ = \{isa = PBXFileReference; lastKnownFileType = text\.plist\.strings; name = ([^;]+); path = ([^;]+\.lproj/Localizable\.strings); sourceTree = "<group>"; \};',
        text,
    ):
        refs_by_locale[m.group(3)] = m.group(1)

    for loc in sorted(locales):
        if loc in refs_by_locale:
            variant_children.append((refs_by_locale[loc], loc))
            continue
        fid = new_id()
        refs_by_locale[loc] = fid
        variant_children.append((fid, loc))
        file_ref_lines.append(
            f"\t\t{fid} /* {loc} */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.strings; name = {loc}; path = {loc}.lproj/Localizable.strings; sourceTree = \"<group>\"; }};"
        )

    if file_ref_lines:
        insert_point = en_match.end()
        text = text[:insert_point] + "\n" + "\n".join(file_ref_lines) + text[insert_point:]

    children_text = ",\n".join(
        f"\t\t\t\t{fid} /* {loc} */" for fid, loc in sorted(variant_children, key=lambda x: x[1])
    )
    text = re.sub(
        r"(470CBC9EEAD7ADD38BCF21DE /\* Localizable\.strings \*/ = \{\s*isa = PBXVariantGroup;\s*children = \()[\s\S]*?(\);\s*name = Localizable\.strings;)",
        rf"\1\n{children_text}\n\t\t\t\2",
        text,
        count=1,
    )

    PBXPROJ.write_text(text, encoding="utf-8")
    print(f"Updated {PBXPROJ.name} with {len(locales)} locales.")


if __name__ == "__main__":
    main()
