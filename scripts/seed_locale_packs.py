#!/usr/bin/env python3
"""Write scripts/locales/<locale>.json translation packs."""

from __future__ import annotations

import json
from pathlib import Path

OUT = Path(__file__).resolve().parent / "locales"


def write(locale: str, values: dict[str, str], add_manually: list[str]) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{locale}.json"
    path.write_text(
        json.dumps({"values": values, "add_manually": add_manually}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def en_values(**overrides: str) -> dict[str, str]:
    base = {
        "welcome_title": "Welcome to CardOnCue",
        "welcome_subtitle": "Your digital wallet for membership cards",
        "welcome_description": "Never forget your membership cards again. CardOnCue keeps all your loyalty cards in one secure, private place.",
        "scan_store_title": "Scan & Store",
        "scan_store_subtitle": "Easily add your cards",
        "scan_store_description": "Use your camera to scan barcodes from your physical cards, or enter them manually. All data is encrypted and stored securely on your device.",
        "location_aware_title": "Location Aware",
        "location_aware_subtitle": "Automatic card suggestions",
        "location_aware_description": "When you arrive at a store, CardOnCue will automatically show you the relevant membership card. No more digging through your wallet!",
        "privacy_first_title": "Privacy First",
        "privacy_first_subtitle": "Your data stays yours",
        "privacy_first_description": "Cards are encrypted locally on your device. Location data is never stored or tracked. You control your data completely.",
        "sign_in_title": "Sign In",
        "email_placeholder": "Enter your email",
        "send_code_button": "Send Sign In Code",
        "verification_title": "Enter Verification Code",
        "code_placeholder": "Enter 6-digit code",
        "verify_button": "Verify",
        "back_button": "Back",
        "no_cards_title": "No Cards Yet",
        "no_cards_subtitle": "Get started by scanning your first membership card",
        "scan_camera_title": "Scan with Camera",
        "scan_camera_description": "Point your camera at any barcode or QR code",
        "enter_manually_title": "Enter Manually",
        "enter_manually_description": "Type the card number if scanning doesn't work",
        "secure_private_title": "Secure & Private",
        "secure_private_description": "Your cards are encrypted and stored locally",
        "scan_first_card": "Scan Your First Card",
        "add_first_card": "Add Your First Card",
        "camera_permission_required": "Camera permission is required to scan cards",
        "my_cards": "My Cards",
        "scan_card": "Scan Card",
        "import_photo": "Import from Photos",
        "import_photo_title": "Import from Photos",
        "import_photo_description": "Select an existing photo with a barcode",
        "next_button": "Next",
        "skip_button": "Skip",
        "get_started": "Get Started",
    }
    base.update(overrides)
    return base


EN_ADD = ["Enter Card Manually", "Add Manually"]


def seed_english_variants() -> None:
    for loc in ("en", "en-AU", "en-CA", "en-GB", "en-IN", "en-NZ", "en-SG", "en-US"):
        overrides = {}
        if loc == "en-GB":
            overrides = {}  # intentionally same; UI strings already neutral
        write(loc, en_values(**overrides), EN_ADD)


def seed_all() -> None:
    seed_english_variants()
    # Additional languages seeded via seed_translations_data.py
    import seed_translations_data  # noqa: WPS433

    seed_translations_data.apply(write)


if __name__ == "__main__":
    seed_all()
    print(f"Seeded locale packs in {OUT}")
