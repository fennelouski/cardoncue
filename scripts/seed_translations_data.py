# ruff: noqa: E501
"""Non-English translation packs for seed_locale_packs.py"""

from __future__ import annotations

from typing import Callable

Pack = tuple[dict[str, str], list[str]]
LANG: dict[str, Pack] = {}


def _p(
    code: str,
    values: dict[str, str],
    add_manually: list[str],
) -> None:
    LANG[code] = (values, add_manually)


def _build_languages() -> None:
    _p(
        "af",
        {
            "welcome_title": "Welkom by CardOnCue",
            "welcome_subtitle": "Jou digitale beursie vir lidmaatskapkaarte",
            "welcome_description": "Moet nooit weer jou lidmaatskapkaarte vergeet nie. CardOnCue hou al jou lojaliteitskaarte op een veilige, private plek.",
            "scan_store_title": "Skandeer en stoor",
            "scan_store_subtitle": "Voeg jou kaarte maklik by",
            "scan_store_description": "Gebruik jou kamera om strepieskodes van fisiese kaarte te skandeer, of voer hulle handmatig in. Alle data word geïnkripteer en veilig op jou toestel gestoor.",
            "location_aware_title": "Liggingbewus",
            "location_aware_subtitle": "Outomatiese kaartvoorstelle",
            "location_aware_description": "Wanneer jy by 'n winkel aankom, wys CardOnCue outomaties die relevante lidmaatskapkaart. Nie meer in jou beursie soek nie!",
            "privacy_first_title": "Privaatheid eerst",
            "privacy_first_subtitle": "Jou data bly joune",
            "privacy_first_description": "Kaarte word plaaslik op jou toestel geïnkripteer. Liggingdata word nooit gestoor of dopgehou nie. Jy het volle beheer.",
            "sign_in_title": "Meld aan",
            "email_placeholder": "Voer jou e-pos in",
            "send_code_button": "Stuur aanmeldkode",
            "verification_title": "Voer verifikasiekode in",
            "code_placeholder": "Voer 6-syfer kode in",
            "verify_button": "Verifieer",
            "back_button": "Terug",
            "no_cards_title": "Nog geen kaarte nie",
            "no_cards_subtitle": "Begin deur jou eerste lidmaatskapkaart te skandeer",
            "scan_camera_title": "Skandeer met kamera",
            "scan_camera_description": "Rig jou kamera op enige strepieskode of QR-kode",
            "enter_manually_title": "Voer handmatig in",
            "enter_manually_description": "Tik die kaartnommer as skandering nie werk nie",
            "secure_private_title": "Veilig en privaat",
            "secure_private_description": "Jou kaarte word geïnkripteer en plaaslik gestoor",
            "scan_first_card": "Skandeer jou eerste kaart",
            "add_first_card": "Voeg jou eerste kaart by",
            "camera_permission_required": "Kameratoestemming word benodig om kaarte te skandeer",
            "my_cards": "My kaarte",
            "scan_card": "Skandeer kaart",
            "import_photo": "Voer in uit Foto's",
            "import_photo_title": "Voer in uit Foto's",
            "import_photo_description": "Kies 'n bestaande foto met 'n strepieskode",
            "next_button": "Volgende",
            "skip_button": "Slaan oor",
            "get_started": "Begin",
        },
        ["Voer kaart handmatig in", "Voeg handmatig by"],
    )

    # Remaining languages filled by seed_translations_batch2.py import
    from seed_translations_batch2 import register_batch2  # noqa: WPS433

    register_batch2(_p)


def apply(write: Callable[[str, dict[str, str], list[str]], None]) -> None:
    if not LANG:
        _build_languages()

    locale_map = {
        "de-AT": "de",
        "de-CH": "de",
        "fr-BE": "fr",
        "fr-CH": "fr",
        "it-CH": "it",
        "es-419": "es",
        "es-MX": "es",
        "es-US": "es",
        "nl-BE": "nl",
        "nb": "no",
        "nn": "no",
        "fil": "tl",
        "zh": "zh-CN",
        "zh-Hant": "zh-TW",
        "zh-HK": "zh-TW",
        "yue-CN": "zh-HK",
    }

    for code, (values, add) in LANG.items():
        write(code, values, add)

    for locale, base in locale_map.items():
        if base in LANG:
            values, add = LANG[base]
            write(locale, values, add)
