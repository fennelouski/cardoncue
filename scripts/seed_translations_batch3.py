# ruff: noqa: E501
"""Additional language packs (batch 3)."""

from __future__ import annotations

from typing import Callable


_KEYS = [
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


_EN = {
    "welcome_title": "Welcome to CardOnCue",
    "welcome_subtitle": "Your digital wallet for membership cards",
    "welcome_description": "Never forget your membership cards again. CardOnCue keeps all your loyalty cards in one secure, private place.",
    "scan_store_title": "Scan & Store",
    "scan_store_subtitle": "Add your cards with ease",
    "scan_store_description": "Use your camera to scan barcodes from physical cards or enter them manually. All data is encrypted and stored securely on your device.",
    "location_aware_title": "Location Aware",
    "location_aware_subtitle": "Automatic card suggestions",
    "location_aware_description": "When you arrive at a store, CardOnCue automatically shows the relevant membership card. No more digging through your wallet!",
    "privacy_first_title": "Privacy First",
    "privacy_first_subtitle": "Your data stays yours",
    "privacy_first_description": "Cards are encrypted locally on your device. Location data is never stored or tracked. You stay in control.",
    "sign_in_title": "Sign In",
    "email_placeholder": "Enter your email",
    "send_code_button": "Send sign in code",
    "verification_title": "Enter verification code",
    "code_placeholder": "Enter 6-digit code",
    "verify_button": "Verify",
    "back_button": "Back",
    "no_cards_title": "No cards yet",
    "no_cards_subtitle": "Start by scanning your first membership card",
    "scan_camera_title": "Scan with camera",
    "scan_camera_description": "Point camera at any barcode or QR code",
    "enter_manually_title": "Enter manually",
    "enter_manually_description": "Type card number if scanning does not work",
    "secure_private_title": "Secure & private",
    "secure_private_description": "Your cards are encrypted and stored locally",
    "scan_first_card": "Scan your first card",
    "add_first_card": "Add your first card",
    "camera_permission_required": "Camera permission is required to scan cards",
    "my_cards": "My Cards",
    "scan_card": "Scan Card",
    "import_photo": "Import from Photos",
    "import_photo_title": "Import from Photos",
    "import_photo_description": "Select an existing photo containing a barcode",
    "next_button": "Next",
    "skip_button": "Skip",
    "get_started": "Get Started",
}


def _v(overrides: dict[str, str]) -> dict[str, str]:
    values = dict(_EN)
    values.update(overrides)
    return {k: values[k] for k in _KEYS}


def register_batch3(p: Callable[[str, dict[str, str], list[str]], None]) -> None:
    p("am", _v({}), ["Enter Card Manually", "Add Manually"])
    p("az", _v({}), ["Enter Card Manually", "Add Manually"])
    p("be", _v({}), ["Enter Card Manually", "Add Manually"])
    p("bg", _v({}), ["Enter Card Manually", "Add Manually"])
    p("bn", _v({}), ["Enter Card Manually", "Add Manually"])
    p("bs", _v({}), ["Enter Card Manually", "Add Manually"])
    p("ca", _v({}), ["Enter Card Manually", "Add Manually"])
    p("cs", _v({}), ["Enter Card Manually", "Add Manually"])
    p("da", _v({}), ["Enter Card Manually", "Add Manually"])
    p("el", _v({}), ["Enter Card Manually", "Add Manually"])
    p("et", _v({}), ["Sisesta kaart käsitsi", "Lisa käsitsi"])
    p("eu", _v({}), ["Txartela eskuz sartu", "Gehitu eskuz"])
    p("fa", _v({}), ["ورود دستی کارت", "افزودن دستی"])
    p("fi", _v({}), ["Syötä kortti käsin", "Lisää käsin"])
    p("gl", _v({}), ["Introducir tarxeta manualmente", "Engadir manualmente"])
    p("gu", _v({}), ["કાર્ડ હાથેથી દાખલ કરો", "હાથેથી ઉમેરો"])
    p("hi-Latn", _v({
        "welcome_title": "CardOnCue mein aapka swagat hai",
        "welcome_subtitle": "Membership cards ke liye aapka digital wallet",
        "welcome_description": "Apne membership cards kabhi mat bhooliye. CardOnCue aapke saare loyalty cards ko ek secure, private jagah par rakhta hai.",
        "scan_store_title": "Scan aur Save",
        "scan_store_subtitle": "Cards asaani se add karein",
        "scan_store_description": "Physical cards ke barcode ko camera se scan karein ya manually enter karein. Saara data encrypted hota hai aur device par secure store hota hai.",
        "location_aware_title": "Location aware",
        "location_aware_subtitle": "Automatic card suggestions",
        "location_aware_description": "Jab aap store par pahunchte hain, CardOnCue relevant membership card automatically dikhaata hai.",
        "privacy_first_title": "Privacy pehle",
        "privacy_first_subtitle": "Aapka data sirf aapka",
        "privacy_first_description": "Cards aapke device par locally encrypted rehte hain. Location data kabhi store ya track nahin hota.",
        "sign_in_title": "Sign in",
        "email_placeholder": "Apna email daalein",
        "send_code_button": "Sign in code bhejein",
        "verification_title": "Verification code daalein",
        "code_placeholder": "6-digit code daalein",
        "verify_button": "Verify",
        "back_button": "Back",
        "no_cards_title": "Abhi koi card nahin",
        "no_cards_subtitle": "Shuru karne ke liye apna pehla membership card scan karein",
        "scan_camera_title": "Camera se scan karein",
        "scan_camera_description": "Camera ko barcode ya QR code par point karein",
        "enter_manually_title": "Manually enter karein",
        "enter_manually_description": "Agar scan kaam na kare to card number type karein",
        "secure_private_title": "Secure aur private",
        "secure_private_description": "Aapke cards encrypted hote hain aur local store hote hain",
        "scan_first_card": "Apna pehla card scan karein",
        "add_first_card": "Apna pehla card add karein",
        "camera_permission_required": "Cards scan karne ke liye camera permission zaroori hai",
        "my_cards": "Mere Cards",
        "scan_card": "Card Scan Karein",
        "import_photo": "Photos se import karein",
        "import_photo_title": "Photos se import karein",
        "import_photo_description": "Barcode wali photo select karein",
        "next_button": "Next",
        "skip_button": "Skip",
        "get_started": "Shuru karein",
    }), ["Card manually enter karein", "Manually add karein"])
    p("hr", _v({}), ["Unesi karticu ručno", "Dodaj ručno"])
    p("hu", _v({}), ["Kártya kézi megadása", "Hozzáadás kézzel"])
    p("hy", _v({}), ["Մուտքագրել քարտը ձեռքով", "Ավելացնել ձեռքով"])
    p("id", _v({}), ["Masukkan kartu secara manual", "Tambah manual"])
    p("is", _v({}), ["Slá kort inn handvirkt", "Bæta við handvirkt"])
    p("ka", _v({}), ["ბარათის ხელით შეყვანა", "ხელით დამატება"])
    p("kk", _v({}), ["Картаны қолмен енгізу", "Қолмен қосу"])
    p("km", _v({}), ["បញ្ចូលកាតដោយដៃ", "បន្ថែមដោយដៃ"])
    p("kn", _v({}), ["ಕಾರ್ಡ್ ಅನ್ನು ಕೈಯಾರೆ ನಮೂದಿಸಿ", "ಕೈಯಾರೆ ಸೇರಿಸಿ"])
    p("lo", _v({}), ["ປ້ອນບັດດ້ວຍຕົນເອງ", "ເພີ່ມແບບດ້ວຍຕົນເອງ"])
    p("lt", _v({}), ["Įvesti kortelę rankiniu būdu", "Pridėti rankiniu būdu"])
    p("lv", _v({}), ["Ievadīt karti manuāli", "Pievienot manuāli"])
    p("mk", _v({}), ["Внеси картичка рачно", "Додај рачно"])
    p("ml", _v({}), ["കാർഡ് കൈയോടെ നൽകുക", "കൈയോടെ ചേർക്കുക"])
    p("mn", _v({}), ["Карт гараар оруулах", "Гараар нэмэх"])
    p("mr", _v({}), ["कार्ड हाताने टाका", "हाताने जोडा"])
    p("ms", _v({}), ["Masukkan kad secara manual", "Tambah secara manual"])
    p("my", _v({}), ["ကတ်ကို ကိုယ်တိုင်ထည့်ပါ", "ကိုယ်တိုင်ထည့်ပါ"])
    p("ne", _v({}), ["कार्ड हातले प्रविष्ट गर्नुहोस्", "हातले थप्नुहोस्"])
    p("no", _v({}), ["Skriv inn kort manuelt", "Legg til manuelt"])
    p("pa", _v({}), ["ਕਾਰਡ ਹੱਥੋਂ ਦਰਜ ਕਰੋ", "ਹੱਥੋਂ ਸ਼ਾਮਲ ਕਰੋ"])
    p("ro", _v({}), ["Introdu cardul manual", "Adaugă manual"])
    p("si", _v({}), ["කාඩ්පත අතින් ඇතුල් කරන්න", "අතින් එකතු කරන්න"])
    p("sk", _v({}), ["Zadať kartu ručne", "Pridať ručne"])
    p("sl", _v({}), ["Vnesi kartico ročno", "Dodaj ročno"])
    p("sq", _v({}), ["Fut kartën manualisht", "Shto manualisht"])
    p("sr", _v({}), ["Унесите картицу ручно", "Додај ручно"])
    p("sw", _v({}), ["Weka kadi mwenyewe", "Ongeza mwenyewe"])
    p("ta", _v({}), ["அட்டையை கையால் உள்ளிடவும்", "கையால் சேர்க்கவும்"])
    p("te", _v({}), ["కార్డును చేతితో నమోదు చేయండి", "చేతితో జోడించండి"])
    p("th", _v({}), ["กรอกบัตรด้วยตนเอง", "เพิ่มด้วยตนเอง"])
    p("tl", _v({
        "welcome_title": "Maligayang pagdating sa CardOnCue",
        "welcome_subtitle": "Iyong digital wallet para sa membership cards",
        "welcome_description": "Hindi mo na makakalimutan ang iyong membership cards. Pinapanatili ng CardOnCue ang lahat ng loyalty cards mo sa isang ligtas at pribadong lugar.",
        "scan_store_title": "I-scan at I-save",
        "scan_store_subtitle": "Madaling idagdag ang iyong cards",
        "scan_store_description": "Gamitin ang camera para i-scan ang barcode ng physical cards o i-enter nang mano-mano. Lahat ng data ay encrypted at ligtas na naka-save sa device mo.",
        "location_aware_title": "May location awareness",
        "location_aware_subtitle": "Awtomatikong mungkahi ng card",
        "location_aware_description": "Pagdating mo sa store, awtomatikong ipapakita ng CardOnCue ang tamang membership card.",
        "privacy_first_title": "Privacy muna",
        "privacy_first_subtitle": "Sa iyo ang data mo",
        "privacy_first_description": "Encrypted nang lokal sa device mo ang cards. Hindi sine-save o tina-track ang location data.",
        "sign_in_title": "Mag-sign in",
        "email_placeholder": "Ilagay ang email mo",
        "send_code_button": "Ipadala ang sign in code",
        "verification_title": "Ilagay ang verification code",
        "code_placeholder": "Ilagay ang 6-digit code",
        "verify_button": "I-verify",
        "back_button": "Bumalik",
        "no_cards_title": "Wala pang cards",
        "no_cards_subtitle": "Magsimula sa pag-scan ng una mong membership card",
        "scan_camera_title": "I-scan gamit ang camera",
        "scan_camera_description": "Itutok ang camera sa barcode o QR code",
        "enter_manually_title": "Ilagay nang mano-mano",
        "enter_manually_description": "I-type ang card number kung hindi gumana ang scan",
        "secure_private_title": "Ligtas at pribado",
        "secure_private_description": "Encrypted at lokal na naka-save ang cards mo",
        "scan_first_card": "I-scan ang una mong card",
        "add_first_card": "Idagdag ang una mong card",
        "camera_permission_required": "Kailangan ang camera permission para mag-scan ng cards",
        "my_cards": "Aking Cards",
        "scan_card": "I-scan ang Card",
        "import_photo": "Mag-import mula sa Photos",
        "import_photo_title": "Mag-import mula sa Photos",
        "import_photo_description": "Pumili ng existing photo na may barcode",
        "next_button": "Susunod",
        "skip_button": "Laktawan",
        "get_started": "Magsimula",
    }), ["Ilagay ang card nang mano-mano", "Magdagdag nang mano-mano"])
    p("ug", _v({}), ["كارتىنى قولدا كىرگۈزۈش", "قولدا قوشۇش"])
    p("ur", _v({}), ["کارڈ دستی طور پر درج کریں", "دستی شامل کریں"])
    p("uz", _v({}), ["Kartani qo'lda kiriting", "Qo'lda qo'shish"])
    p("zh-CN", _v({
        "welcome_title": "欢迎使用 CardOnCue",
        "welcome_subtitle": "您的会员卡数字钱包",
        "welcome_description": "再也不用忘记会员卡。CardOnCue 将您的所有会员卡安全私密地保存在一个地方。",
        "scan_store_title": "扫码保存",
        "scan_store_subtitle": "轻松添加卡片",
        "scan_store_description": "使用相机扫描实体卡条码，或手动输入。所有数据都会加密并安全保存在您的设备上。",
        "location_aware_title": "位置感知",
        "location_aware_subtitle": "自动推荐卡片",
        "location_aware_description": "到店后，CardOnCue 会自动显示对应会员卡，无需翻找钱包。",
        "privacy_first_title": "隐私优先",
        "privacy_first_subtitle": "您的数据归您所有",
        "privacy_first_description": "卡片仅在本地加密存储，位置数据不会被保存或追踪。",
        "sign_in_title": "登录",
        "email_placeholder": "输入邮箱",
        "send_code_button": "发送登录验证码",
        "verification_title": "输入验证码",
        "code_placeholder": "输入 6 位验证码",
        "verify_button": "验证",
        "back_button": "返回",
        "no_cards_title": "暂无卡片",
        "no_cards_subtitle": "先扫描您的第一张会员卡",
        "scan_camera_title": "相机扫描",
        "scan_camera_description": "将相机对准条码或二维码",
        "enter_manually_title": "手动输入",
        "enter_manually_description": "若扫描失败，请输入卡号",
        "secure_private_title": "安全且私密",
        "secure_private_description": "您的卡片已加密并保存在本地",
        "scan_first_card": "扫描第一张卡",
        "add_first_card": "添加第一张卡",
        "camera_permission_required": "需要相机权限才能扫描卡片",
        "my_cards": "我的卡片",
        "scan_card": "扫描卡片",
        "import_photo": "从照片导入",
        "import_photo_title": "从照片导入",
        "import_photo_description": "选择包含条码的现有照片",
        "next_button": "下一步",
        "skip_button": "跳过",
        "get_started": "开始使用",
    }), ["手动输入卡片", "手动添加"])
    p("zh-TW", _v({
        "welcome_title": "歡迎使用 CardOnCue",
        "welcome_subtitle": "您的會員卡數位錢包",
        "welcome_description": "不再忘記您的會員卡。CardOnCue 將所有會員卡安全且私密地集中保存。",
        "scan_store_title": "掃描與儲存",
        "scan_store_subtitle": "輕鬆新增卡片",
        "scan_store_description": "使用相機掃描實體卡條碼，或手動輸入。所有資料都會加密並安全儲存在您的裝置上。",
        "location_aware_title": "位置感知",
        "location_aware_subtitle": "自動卡片建議",
        "location_aware_description": "到店時，CardOnCue 會自動顯示對應會員卡，不必再翻找錢包。",
        "privacy_first_title": "隱私優先",
        "privacy_first_subtitle": "您的資料由您掌控",
        "privacy_first_description": "卡片只在您的裝置上本機加密。位置資料不會被儲存或追蹤。",
        "sign_in_title": "登入",
        "email_placeholder": "輸入電子郵件",
        "send_code_button": "傳送登入碼",
        "verification_title": "輸入驗證碼",
        "code_placeholder": "輸入 6 碼驗證碼",
        "verify_button": "驗證",
        "back_button": "返回",
        "no_cards_title": "尚無卡片",
        "no_cards_subtitle": "先掃描您的第一張會員卡",
        "scan_camera_title": "使用相機掃描",
        "scan_camera_description": "將相機對準條碼或 QR Code",
        "enter_manually_title": "手動輸入",
        "enter_manually_description": "若掃描失敗，請輸入卡號",
        "secure_private_title": "安全且私密",
        "secure_private_description": "您的卡片會加密並儲存在本機",
        "scan_first_card": "掃描第一張卡",
        "add_first_card": "新增第一張卡",
        "camera_permission_required": "需要相機權限才能掃描卡片",
        "my_cards": "我的卡片",
        "scan_card": "掃描卡片",
        "import_photo": "從照片匯入",
        "import_photo_title": "從照片匯入",
        "import_photo_description": "選擇包含條碼的照片",
        "next_button": "下一步",
        "skip_button": "略過",
        "get_started": "開始使用",
    }), ["手動輸入卡片", "手動新增"])
    p("zh-HK", _v({
        "welcome_title": "歡迎使用 CardOnCue",
        "welcome_subtitle": "你嘅會員卡數碼銀包",
        "welcome_description": "唔使再怕唔記得帶會員卡。CardOnCue 會將你所有會員卡安全又私密咁集中儲存。",
        "scan_store_title": "掃描及儲存",
        "scan_store_subtitle": "輕鬆加入卡片",
        "scan_store_description": "用相機掃描實體卡條碼，或手動輸入。所有資料都會加密並安全儲存在你嘅裝置。",
        "location_aware_title": "位置感知",
        "location_aware_subtitle": "自動建議卡片",
        "location_aware_description": "你去到店舖時，CardOnCue 會自動顯示相關會員卡，唔使再喺銀包搵。",
        "privacy_first_title": "私隱優先",
        "privacy_first_subtitle": "你嘅資料屬於你",
        "privacy_first_description": "卡片只會喺你裝置本地加密。位置資料唔會被儲存或追蹤。",
        "sign_in_title": "登入",
        "email_placeholder": "輸入電郵",
        "send_code_button": "發送登入碼",
        "verification_title": "輸入驗證碼",
        "code_placeholder": "輸入 6 位驗證碼",
        "verify_button": "驗證",
        "back_button": "返回",
        "no_cards_title": "未有卡片",
        "no_cards_subtitle": "先掃描你第一張會員卡",
        "scan_camera_title": "用相機掃描",
        "scan_camera_description": "將相機對準條碼或 QR Code",
        "enter_manually_title": "手動輸入",
        "enter_manually_description": "如果掃描失敗，請輸入卡號",
        "secure_private_title": "安全又私密",
        "secure_private_description": "你嘅卡片會加密並儲存喺本機",
        "scan_first_card": "掃描你第一張卡",
        "add_first_card": "加入你第一張卡",
        "camera_permission_required": "掃描卡片需要相機權限",
        "my_cards": "我嘅卡片",
        "scan_card": "掃描卡片",
        "import_photo": "由相簿匯入",
        "import_photo_title": "由相簿匯入",
        "import_photo_description": "揀一張包含條碼嘅相片",
        "next_button": "下一步",
        "skip_button": "略過",
        "get_started": "開始使用",
    }), ["手動輸入卡片", "手動加入"])
    p("zu", _v({}), ["Faka ikhadi mathupha", "Engeza mathupha"])
