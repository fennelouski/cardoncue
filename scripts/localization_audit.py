#!/usr/bin/env python3
"""Audit Localizable.strings locales against the source (en) file."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP_DIR = ROOT / "CardOnCue"
SOURCE_LOCALE = "en"
STRINGS_NAME = "Localizable.strings"

ENTRY_RE = re.compile(
    r'^\s*"(?P<key>(?:\\.|[^"\\])*)"\s*=\s*"(?P<value>(?:\\.|[^"\\])*)"\s*;\s*$'
)
PLACEHOLDER_RE = re.compile(
    r"%(?:\d+\$)?[@dflds%]|%%|\\n|\\t|\\r|\\\"|\\\\"
)


def parse_strings(path: Path) -> tuple[list[str], dict[str, str], list[str]]:
    """Return (key_order, key->value, parse_errors). Duplicate keys keep last value but order lists all."""
    text = path.read_text(encoding="utf-8")
    key_order: list[str] = []
    values: dict[str, str] = {}
    errors: list[str] = []
    for i, line in enumerate(text.splitlines(), 1):
        stripped = line.strip()
        if not stripped or stripped.startswith("/*") or stripped.startswith("//"):
            continue
        m = ENTRY_RE.match(line)
        if not m:
            errors.append(f"{path}:{i}: unparseable line: {line!r}")
            continue
        key = bytes(m.group("key"), "utf-8").decode("unicode_escape")
        value = bytes(m.group("value"), "utf-8").decode("unicode_escape")
        key_order.append(key)
        values[key] = value
    return key_order, values, errors


def extract_placeholders(value: str) -> list[str]:
    return PLACEHOLDER_RE.findall(value)


def audit_locale(
    source_keys: list[str],
    source_values: dict[str, str],
    locale: str,
    path: Path,
) -> dict:
    key_order, values, errors = parse_strings(path)
    source_set = list(dict.fromkeys(source_keys))
    locale_set = list(dict.fromkeys(key_order))

    missing = [k for k in source_set if k not in values]
    extra = [k for k in locale_set if k not in source_values]

    placeholder_issues: list[str] = []
    identical_to_source: list[str] = []
    for key in source_set:
        if key not in values:
            continue
        sv = source_values[key]
        lv = values[key]
        if sv == lv:
            identical_to_source.append(key)
        sp = extract_placeholders(sv)
        lp = extract_placeholders(lv)
        if sp != lp:
            placeholder_issues.append(
                f"{locale}:{key}: source {sp!r} vs locale {lp!r}"
            )

    return {
        "locale": locale,
        "path": str(path),
        "key_count": len(locale_set),
        "source_key_count": len(source_set),
        "missing": missing,
        "extra": extra,
        "parse_errors": errors,
        "placeholder_issues": placeholder_issues,
        "identical_values": identical_to_source,
        "fully_identical": set(source_values.values()) == set(values.get(k, "") for k in source_set)
            and not missing
            and not extra,
    }


def discover_locales() -> list[str]:
    locales = []
    for child in sorted(APP_DIR.iterdir()):
        if child.is_dir() and child.name.endswith(".lproj"):
            locales.append(child.name[: -len(".lproj")])
    return locales


def main() -> int:
    source_path = APP_DIR / f"{SOURCE_LOCALE}.lproj" / STRINGS_NAME
    if not source_path.exists():
        print(f"ERROR: source not found: {source_path}", file=sys.stderr)
        return 1

    source_keys, source_values, source_errors = parse_strings(source_path)
    if source_errors:
        print("Source parse errors:")
        for e in source_errors:
            print(f"  {e}")
        return 1

    locales = [l for l in discover_locales() if l != SOURCE_LOCALE]
    if not locales:
        print("No target locales found (only source).")
        return 0

    failures = 0
    identical_locales: list[str] = []
    translated_locales: list[str] = []

    print(f"Source: {SOURCE_LOCALE} ({len(dict.fromkeys(source_keys))} unique keys)")
    print("-" * 72)

    for locale in locales:
        path = APP_DIR / f"{locale}.lproj" / STRINGS_NAME
        if not path.exists():
            print(f"{locale}: MISSING FILE")
            failures += 1
            continue
        r = audit_locale(source_keys, source_values, locale, path)
        ok = (
            not r["missing"]
            and not r["extra"]
            and not r["parse_errors"]
            and not r["placeholder_issues"]
            and r["key_count"] == r["source_key_count"]
        )
        status = "OK" if ok else "FAIL"
        if r["fully_identical"]:
            identical_locales.append(locale)
        else:
            translated_locales.append(locale)
        if not ok:
            failures += 1
        print(
            f"{locale}: {status} keys={r['key_count']}/{r['source_key_count']} "
            f"identical_values={len(r['identical_values'])}"
        )
        if r["missing"]:
            print(f"  missing: {r['missing']}")
        if r["extra"]:
            print(f"  extra: {r['extra']}")
        if r["parse_errors"]:
            for e in r["parse_errors"][:5]:
                print(f"  parse: {e}")
        if r["placeholder_issues"]:
            for e in r["placeholder_issues"][:5]:
                print(f"  placeholder: {e}")

    print("-" * 72)
    print(f"Locales audited: {len(locales)}")
    print(f"Translated (not fully identical): {len(translated_locales)}")
    print(f"Fully identical to source: {len(identical_locales)}")
    if identical_locales:
        print(f"  {', '.join(identical_locales)}")
    print(f"Failures: {failures}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
