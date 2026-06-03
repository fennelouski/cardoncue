#!/usr/bin/env python3
# ruff: noqa: E501
"""Generate scripts/lang_packs.json with native translations for all 57 locales."""

from __future__ import annotations

import json
import sys
from pathlib import Path

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

# locale -> (values list in KEYS order, add_manually)
from _lang_pack_fill_data import FILL_DATA

DATA: dict[str, tuple[list[str], list[str]]] = dict(FILL_DATA)


def _L(*values: str) -> list[str]:
    if len(values) != 38:
        raise ValueError(f"expected 38 values, got {len(values)}")
    return list(values)


def _A(a: str, b: str) -> list[str]:
    return [a, b]


def _load_preserved() -> dict[str, dict]:
    import json
    import seed_translations_batch3 as b3

    preserved: dict[str, dict] = {}

    def capture(code: str, values: dict[str, str], add: list[str]) -> None:
        if code in {"hi-Latn", "tl", "zh-CN", "zh-TW"}:
            preserved[code] = {"values": {k: values[k] for k in KEYS}, "add_manually": add}

    b3.register_batch3(capture)
    yue_path = Path(__file__).resolve().parent / "locales" / "yue-CN.json"
    preserved["yue-CN"] = json.loads(yue_path.read_text(encoding="utf-8"))
    return preserved


def _build_output() -> dict[str, dict]:
    out: dict[str, dict] = {}
    for locale, (values, add) in DATA.items():
        out[locale] = {"values": dict(zip(KEYS, values, strict=True)), "add_manually": add}
    out.update(_load_preserved())
    if "yue-CN" not in out:
        raise KeyError("yue-CN missing from preserved packs")
    out["zh-HK"] = {
        "values": dict(out["yue-CN"]["values"]),
        "add_manually": list(out["yue-CN"]["add_manually"]),
    }
    return out


def verify(data: dict) -> tuple[bool, str]:
    lines: list[str] = []
    ok = True
    lines.append(f"Locale count: {len(data)}")
    if len(data) != 57:
        ok = False
        lines.append("Schema: FAIL (expected 57 locales)")
    else:
        key_errors = []
        for locale, pack in sorted(data.items()):
            values = pack.get("values", {})
            if len(values) != 38 or set(values) != set(KEYS):
                key_errors.append(locale)
            if len(pack.get("add_manually", [])) != 2:
                key_errors.append(f"{locale}:add")
        if key_errors:
            ok = False
            lines.append(f"Schema: FAIL ({', '.join(key_errors[:8])})")
        else:
            lines.append("Schema: PASS (57 locales, 38 keys each, add_manually length 2)")
    en_fb = [
        loc
        for loc, pack in sorted(data.items())
        if pack["values"].get("welcome_subtitle") == EN_WELCOME_SUBTITLE
    ]
    lines.append(f"English welcome_subtitle fallback count: {len(en_fb)}")
    if en_fb:
        lines.append(f"  locales: {', '.join(en_fb)}")
        ok = False
    return ok, "\n".join(lines)


def main() -> int:
    out_path = Path(__file__).resolve().parent / "lang_packs.json"
    data = _build_output()
    out_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    ok, report = verify(data)
    print(report)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
