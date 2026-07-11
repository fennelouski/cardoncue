# ruff: noqa: E501
"""Photo import and add-card tab strings (batch 4)."""

from __future__ import annotations

from typing import Callable

NEW_KEYS = [
    "photo_import_multi_description",
    "choose_photos",
    "enter_manually_instead",
    "photo_import_loading",
    "photo_import_processing",
    "photo_import_preparing_review",
    "photo_import_review_progress",
    "photo_import_summary_title",
    "photo_import_summary_auto_saved",
    "photo_import_summary_reviewed",
    "photo_import_summary_failed",
    "photo_import_import_more",
    "photo_import_enter_failed_manually",
    "photo_import_done",
    "add_card_tab_camera",
    "add_card_tab_photos",
    "add_card_tab_manual",
]

_EN = {
    "photo_import_multi_description": "Select one or more photos of your membership cards. We'll detect barcodes and import them for you.",
    "choose_photos": "Choose Photos",
    "enter_manually_instead": "Enter Manually Instead",
    "photo_import_loading": "Loading selected photos...",
    "photo_import_processing": "Processing %d of %d...",
    "photo_import_preparing_review": "Preparing cards for review...",
    "photo_import_review_progress": "Review %d of %d",
    "photo_import_summary_title": "Import Complete",
    "photo_import_summary_auto_saved": "Saved automatically",
    "photo_import_summary_reviewed": "Reviewed manually",
    "photo_import_summary_failed": "No barcode found",
    "photo_import_import_more": "Import More Photos",
    "photo_import_enter_failed_manually": "Enter Failed Cards Manually",
    "photo_import_done": "Done",
    "add_card_tab_camera": "Camera",
    "add_card_tab_photos": "Photos",
    "add_card_tab_manual": "Manual",
}

_PACKS: dict[str, dict[str, str]] = {
    "af": {
        "photo_import_multi_description": "Kies een of meer foto's van jou lidmaatskapkaarte. Ons sal strepieskodes opspoor en dit vir jou invoer.",
        "choose_photos": "Kies Foto's",
        "enter_manually_instead": "Voer liewer handmatig in",
        "photo_import_loading": "Laai gekose foto's...",
        "photo_import_processing": "Verwerk %d van %d...",
        "photo_import_preparing_review": "Berei kaarte vir hersiening voor...",
        "photo_import_review_progress": "Hersien %d van %d",
        "photo_import_summary_title": "Invoer voltooi",
        "photo_import_summary_auto_saved": "Outomaties gestoor",
        "photo_import_summary_reviewed": "Handmatig hersien",
        "photo_import_summary_failed": "Geen strepieskode gevind nie",
        "photo_import_import_more": "Voer meer foto's in",
        "photo_import_enter_failed_manually": "Voer mislukte kaarte handmatig in",
        "photo_import_done": "Klaar",
        "add_card_tab_camera": "Kamera",
        "add_card_tab_photos": "Foto's",
        "add_card_tab_manual": "Handmatig",
    },
    "de": {
        "photo_import_multi_description": "Wählen Sie ein oder mehrere Fotos Ihrer Mitgliedskarten. Wir erkennen Barcodes und importieren sie für Sie.",
        "choose_photos": "Fotos auswählen",
        "enter_manually_instead": "Stattdessen manuell eingeben",
        "photo_import_loading": "Ausgewählte Fotos werden geladen...",
        "photo_import_processing": "Verarbeite %d von %d...",
        "photo_import_preparing_review": "Karten werden für die Überprüfung vorbereitet...",
        "photo_import_review_progress": "Überprüfung %d von %d",
        "photo_import_summary_title": "Import abgeschlossen",
        "photo_import_summary_auto_saved": "Automatisch gespeichert",
        "photo_import_summary_reviewed": "Manuell überprüft",
        "photo_import_summary_failed": "Kein Barcode gefunden",
        "photo_import_import_more": "Weitere Fotos importieren",
        "photo_import_enter_failed_manually": "Fehlgeschlagene Karten manuell eingeben",
        "photo_import_done": "Fertig",
        "add_card_tab_camera": "Kamera",
        "add_card_tab_photos": "Fotos",
        "add_card_tab_manual": "Manuell",
    },
    "es": {
        "photo_import_multi_description": "Selecciona una o más fotos de tus tarjetas de membresía. Detectaremos los códigos de barras e importaremos las tarjetas por ti.",
        "choose_photos": "Elegir fotos",
        "enter_manually_instead": "Introducir manualmente",
        "photo_import_loading": "Cargando fotos seleccionadas...",
        "photo_import_processing": "Procesando %d de %d...",
        "photo_import_preparing_review": "Preparando tarjetas para revisión...",
        "photo_import_review_progress": "Revisión %d de %d",
        "photo_import_summary_title": "Importación completada",
        "photo_import_summary_auto_saved": "Guardadas automáticamente",
        "photo_import_summary_reviewed": "Revisadas manualmente",
        "photo_import_summary_failed": "No se encontró código de barras",
        "photo_import_import_more": "Importar más fotos",
        "photo_import_enter_failed_manually": "Introducir tarjetas fallidas manualmente",
        "photo_import_done": "Listo",
        "add_card_tab_camera": "Cámara",
        "add_card_tab_photos": "Fotos",
        "add_card_tab_manual": "Manual",
    },
    "fr": {
        "photo_import_multi_description": "Sélectionnez une ou plusieurs photos de vos cartes de membre. Nous détecterons les codes-barres et les importerons pour vous.",
        "choose_photos": "Choisir des photos",
        "enter_manually_instead": "Saisir manuellement",
        "photo_import_loading": "Chargement des photos sélectionnées...",
        "photo_import_processing": "Traitement %d sur %d...",
        "photo_import_preparing_review": "Préparation des cartes pour révision...",
        "photo_import_review_progress": "Révision %d sur %d",
        "photo_import_summary_title": "Importation terminée",
        "photo_import_summary_auto_saved": "Enregistrées automatiquement",
        "photo_import_summary_reviewed": "Révisées manuellement",
        "photo_import_summary_failed": "Aucun code-barres trouvé",
        "photo_import_import_more": "Importer d'autres photos",
        "photo_import_enter_failed_manually": "Saisir manuellement les cartes échouées",
        "photo_import_done": "Terminé",
        "add_card_tab_camera": "Appareil photo",
        "add_card_tab_photos": "Photos",
        "add_card_tab_manual": "Manuel",
    },
    "it": {
        "photo_import_multi_description": "Seleziona una o più foto delle tue tessere. Rileveremo i codici a barre e le importeremo per te.",
        "choose_photos": "Scegli foto",
        "enter_manually_instead": "Inserisci manualmente",
        "photo_import_loading": "Caricamento foto selezionate...",
        "photo_import_processing": "Elaborazione %d di %d...",
        "photo_import_preparing_review": "Preparazione tessere per la revisione...",
        "photo_import_review_progress": "Revisione %d di %d",
        "photo_import_summary_title": "Importazione completata",
        "photo_import_summary_auto_saved": "Salvate automaticamente",
        "photo_import_summary_reviewed": "Revisionate manualmente",
        "photo_import_summary_failed": "Nessun codice a barre trovato",
        "photo_import_import_more": "Importa altre foto",
        "photo_import_enter_failed_manually": "Inserisci manualmente le tessere non riuscite",
        "photo_import_done": "Fine",
        "add_card_tab_camera": "Fotocamera",
        "add_card_tab_photos": "Foto",
        "add_card_tab_manual": "Manuale",
    },
    "nl": {
        "photo_import_multi_description": "Selecteer een of meer foto's van je lidmaatschapskaarten. We detecteren barcodes en importeren ze voor je.",
        "choose_photos": "Kies foto's",
        "enter_manually_instead": "Handmatig invoeren",
        "photo_import_loading": "Geselecteerde foto's laden...",
        "photo_import_processing": "Verwerken %d van %d...",
        "photo_import_preparing_review": "Kaarten voorbereiden voor controle...",
        "photo_import_review_progress": "Controle %d van %d",
        "photo_import_summary_title": "Import voltooid",
        "photo_import_summary_auto_saved": "Automatisch opgeslagen",
        "photo_import_summary_reviewed": "Handmatig gecontroleerd",
        "photo_import_summary_failed": "Geen barcode gevonden",
        "photo_import_import_more": "Meer foto's importeren",
        "photo_import_enter_failed_manually": "Mislukte kaarten handmatig invoeren",
        "photo_import_done": "Klaar",
        "add_card_tab_camera": "Camera",
        "add_card_tab_photos": "Foto's",
        "add_card_tab_manual": "Handmatig",
    },
    "no": {
        "photo_import_multi_description": "Velg ett eller flere bilder av medlemskortene dine. Vi finner strekkoder og importerer dem for deg.",
        "choose_photos": "Velg bilder",
        "enter_manually_instead": "Skriv inn manuelt i stedet",
        "photo_import_loading": "Laster valgte bilder...",
        "photo_import_processing": "Behandler %d av %d...",
        "photo_import_preparing_review": "Forbereder kort for gjennomgang...",
        "photo_import_review_progress": "Gjennomgang %d av %d",
        "photo_import_summary_title": "Import fullført",
        "photo_import_summary_auto_saved": "Lagret automatisk",
        "photo_import_summary_reviewed": "Gjennomgått manuelt",
        "photo_import_summary_failed": "Ingen strekkode funnet",
        "photo_import_import_more": "Importer flere bilder",
        "photo_import_enter_failed_manually": "Skriv inn mislykkede kort manuelt",
        "photo_import_done": "Ferdig",
        "add_card_tab_camera": "Kamera",
        "add_card_tab_photos": "Bilder",
        "add_card_tab_manual": "Manuelt",
    },
    "tl": {
        "photo_import_multi_description": "Pumili ng isa o higit pang larawan ng iyong mga membership card. Matutukoy namin ang mga barcode at ia-import ang mga ito para sa iyo.",
        "choose_photos": "Pumili ng mga Larawan",
        "enter_manually_instead": "Ilagay nang Manu-mano",
        "photo_import_loading": "Nilo-load ang mga napiling larawan...",
        "photo_import_processing": "Pinoproseso %d ng %d...",
        "photo_import_preparing_review": "Inihahanda ang mga card para sa pagsusuri...",
        "photo_import_review_progress": "Pagsusuri %d ng %d",
        "photo_import_summary_title": "Kumpleto ang Import",
        "photo_import_summary_auto_saved": "Awtomatikong na-save",
        "photo_import_summary_reviewed": "Manu-manong sinuri",
        "photo_import_summary_failed": "Walang nahanap na barcode",
        "photo_import_import_more": "Mag-import ng Higit pang Larawan",
        "photo_import_enter_failed_manually": "Ilagay nang Manu-mano ang mga Nabigong Card",
        "photo_import_done": "Tapos na",
        "add_card_tab_camera": "Camera",
        "add_card_tab_photos": "Mga Larawan",
        "add_card_tab_manual": "Manu-mano",
    },
    "zh-CN": {
        "photo_import_multi_description": "选择一张或多张会员卡照片。我们将检测条形码并为您导入。",
        "choose_photos": "选择照片",
        "enter_manually_instead": "改为手动输入",
        "photo_import_loading": "正在加载所选照片...",
        "photo_import_processing": "正在处理 %d / %d...",
        "photo_import_preparing_review": "正在准备待审核的卡片...",
        "photo_import_review_progress": "审核 %d / %d",
        "photo_import_summary_title": "导入完成",
        "photo_import_summary_auto_saved": "已自动保存",
        "photo_import_summary_reviewed": "已手动审核",
        "photo_import_summary_failed": "未找到条形码",
        "photo_import_import_more": "导入更多照片",
        "photo_import_enter_failed_manually": "手动输入失败的卡片",
        "photo_import_done": "完成",
        "add_card_tab_camera": "相机",
        "add_card_tab_photos": "照片",
        "add_card_tab_manual": "手动",
    },
    "zh-TW": {
        "photo_import_multi_description": "選擇一張或多張會員卡照片。我們將偵測條碼並為您匯入。",
        "choose_photos": "選擇照片",
        "enter_manually_instead": "改為手動輸入",
        "photo_import_loading": "正在載入所選照片...",
        "photo_import_processing": "正在處理 %d / %d...",
        "photo_import_preparing_review": "正在準備待審核的卡片...",
        "photo_import_review_progress": "審核 %d / %d",
        "photo_import_summary_title": "匯入完成",
        "photo_import_summary_auto_saved": "已自動儲存",
        "photo_import_summary_reviewed": "已手動審核",
        "photo_import_summary_failed": "找不到條碼",
        "photo_import_import_more": "匯入更多照片",
        "photo_import_enter_failed_manually": "手動輸入失敗的卡片",
        "photo_import_done": "完成",
        "add_card_tab_camera": "相機",
        "add_card_tab_photos": "照片",
        "add_card_tab_manual": "手動",
    },
    "hi-Latn": {
        "photo_import_multi_description": "Apne membership cards ki ek ya zyada photos chunein. Hum barcodes detect karke unhe import karenge.",
        "choose_photos": "Photos Chunein",
        "enter_manually_instead": "Manual Entry Karen",
        "photo_import_loading": "Chuni hui photos load ho rahi hain...",
        "photo_import_processing": "Process ho raha hai %d of %d...",
        "photo_import_preparing_review": "Cards review ke liye taiyar ho rahe hain...",
        "photo_import_review_progress": "Review %d of %d",
        "photo_import_summary_title": "Import Complete",
        "photo_import_summary_auto_saved": "Automatically save ho gaya",
        "photo_import_summary_reviewed": "Manually review kiya gaya",
        "photo_import_summary_failed": "Koi barcode nahi mila",
        "photo_import_import_more": "Aur Photos Import Karen",
        "photo_import_enter_failed_manually": "Failed Cards Manually Enter Karen",
        "photo_import_done": "Ho gaya",
        "add_card_tab_camera": "Camera",
        "add_card_tab_photos": "Photos",
        "add_card_tab_manual": "Manual",
    },
}

# Locales that inherit from a base pack (see seed_translations_data.locale_map).
_LOCALE_BASE = {
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
    "yue-CN": "zh-TW",
}

# English variants use the source English strings.
_ENGLISH_LOCALES = frozenset(
    {"en", "en-AU", "en-CA", "en-GB", "en-IN", "en-NZ", "en-SG", "en-US"}
)


def values_for_locale(locale: str) -> dict[str, str]:
    if locale in _ENGLISH_LOCALES:
        return dict(_EN)
    base = _LOCALE_BASE.get(locale, locale)
    if base in _PACKS:
        return dict(_PACKS[base])
    if locale in _PACKS:
        return dict(_PACKS[locale])
    return dict(_EN)


def register_batch4(register: Callable[[str, dict[str, str], list[str]], None]) -> None:
    """No-op for seed pipeline; use patch_locale_packs instead."""
    del register


def patch_locale_packs(locales_dir) -> int:
    import json
    from pathlib import Path

    locales_dir = Path(locales_dir)
    updated = 0
    for path in sorted(locales_dir.glob("*.json")):
        locale = path.stem
        data = json.loads(path.read_text(encoding="utf-8"))
        new_values = values_for_locale(locale)
        values: dict[str, str] = data.setdefault("values", {})
        changed = False
        for key in NEW_KEYS:
            if key not in values:
                values[key] = new_values[key]
                changed = True
        if changed:
            path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            updated += 1
    return updated


if __name__ == "__main__":
    from pathlib import Path

    count = patch_locale_packs(Path(__file__).resolve().parent / "locales")
    print(f"Patched {count} locale packs.")
