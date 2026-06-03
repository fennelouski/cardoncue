#!/usr/bin/env python3
# ruff: noqa: E501
"""Fill native translations in lang_packs.json for locales with English fallback."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

LANG_PACKS_PATH = Path(__file__).resolve().parent / "lang_packs.json"

KEYS = [
    "welcome_title",
    "welcome_subtitle",
    "welcome_description",
    "scan_store_title",
    "scan_store_subtitle",
    "scan_store_description",
    "location_aware_title",
    "location_aware_subtitle",
    "location_aware_description",
    "privacy_first_title",
    "privacy_first_subtitle",
    "privacy_first_description",
    "sign_in_title",
    "email_placeholder",
    "send_code_button",
    "verification_title",
    "code_placeholder",
    "verify_button",
    "back_button",
    "no_cards_title",
    "no_cards_subtitle",
    "scan_camera_title",
    "scan_camera_description",
    "enter_manually_title",
    "enter_manually_description",
    "secure_private_title",
    "secure_private_description",
    "scan_first_card",
    "add_first_card",
    "camera_permission_required",
    "my_cards",
    "scan_card",
    "import_photo",
    "import_photo_title",
    "import_photo_description",
    "next_button",
    "skip_button",
    "get_started",
]

EN_WELCOME_SUBTITLE = "Your digital wallet for membership cards"

FILL_LOCALES = [
    "am",
    "az",
    "be",
    "bg",
    "bn",
    "bs",
    "ca",
    "cs",
    "da",
    "el",
    "et",
    "eu",
    "fa",
    "fi",
    "gl",
    "gu",
    "hr",
    "hu",
    "hy",
    "id",
    "is",
    "ka",
    "kk",
    "km",
    "kn",
    "lo",
    "lt",
    "lv",
    "mk",
    "ml",
    "mn",
    "mr",
    "ms",
    "my",
    "ne",
    "no",
    "pa",
    "ro",
    "si",
    "sk",
    "sl",
    "sq",
    "sr",
    "sw",
    "ta",
    "te",
    "th",
    "ug",
    "ur",
    "uz",
    "zu",
]

PRESERVE_LOCALES = frozenset({"hi-Latn", "tl", "zh-CN", "zh-TW", "yue-CN"})


def _build_translations() -> dict[str, dict[str, Any]]:
    from _fill_lang_packs_data import TRANSLATIONS as raw

    packs: dict[str, dict[str, Any]] = {}
    for locale in FILL_LOCALES:
        if locale not in raw:
            raise KeyError(f"Missing translation pack for {locale}")
        pack = raw[locale]
        values = pack["values"]
        add_manually = pack["add_manually"]
        missing = [k for k in KEYS if k not in values]
        if missing:
            raise ValueError(f"{locale}: missing keys {missing}")
        if len(add_manually) != 2:
            raise ValueError(f"{locale}: add_manually must have length 2")
        packs[locale] = {
            "values": {k: values[k] for k in KEYS},
            "add_manually": list(add_manually),
        }
    return packs


TRANSLATIONS = _build_translations()

def main() -> int:
    with LANG_PACKS_PATH.open(encoding="utf-8") as fh:
        data: dict[str, dict[str, Any]] = json.load(fh)

    for locale in FILL_LOCALES:
        if locale not in TRANSLATIONS:
            raise KeyError(f"Missing translation pack for {locale}")
        data[locale] = TRANSLATIONS[locale]

    if "yue-CN" not in data:
        raise KeyError("yue-CN must exist in lang_packs.json")
    data["zh-HK"] = {
        "values": dict(data["yue-CN"]["values"]),
        "add_manually": list(data["yue-CN"]["add_manually"]),
    }

    for locale in PRESERVE_LOCALES:
        if locale not in data:
            raise KeyError(f"Expected preserved locale missing: {locale}")

    LANG_PACKS_PATH.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    ok, report = verify(data)
    print("Script ran successfully.")
    print(report)
    return 0 if ok else 1


def verify(data: dict[str, dict[str, Any]]) -> tuple[bool, str]:
    lines: list[str] = []
    ok = True

    locale_count = len(data)
    lines.append(f"Locale count: {locale_count}")

    key_errors: list[str] = []
    add_errors: list[str] = []
    for locale, pack in sorted(data.items()):
        values = pack.get("values", {})
        if len(values) != 38:
            key_errors.append(f"{locale}: {len(values)} keys")
        elif set(values) != set(KEYS):
            key_errors.append(f"{locale}: key mismatch")
        add = pack.get("add_manually", [])
        if len(add) != 2:
            add_errors.append(f"{locale}: add_manually length {len(add)}")

    if locale_count != 57:
        ok = False
        lines.append("Schema: FAIL (expected 57 locales)")
    elif key_errors or add_errors:
        ok = False
        lines.append("Schema: FAIL")
        lines.extend(key_errors[:5])
        lines.extend(add_errors[:5])
    else:
        lines.append("Schema: PASS (57 locales, 38 keys each, add_manually length 2)")

    en_fallback = [
        loc
        for loc, pack in sorted(data.items())
        if pack["values"].get("welcome_subtitle") == EN_WELCOME_SUBTITLE
    ]
    lines.append(f"English welcome_subtitle fallback count: {len(en_fallback)}")
    if en_fallback:
        lines.append(f"  locales: {', '.join(en_fallback)}")
        ok = False

    return ok, "\n".join(lines)


if __name__ == "__main__":
    sys.exit(main())
