# CardOnCue — App Store Connect Submission Guide

Everything needed to create the App Store Connect record and ship v1.0.
Last verified against the codebase on **2026-07-21**.

---

## 0. Read this first — known gaps

| Item | Status | Action |
|---|---|---|
| `DEVELOPMENT_TEAM` is empty | **Blocker for upload** | `project.yml` sets `DEVELOPMENT_TEAM: ""` for all four targets. Set your real 10-character Team ID (or set it in Xcode → Signing & Capabilities) or the archive cannot be signed for distribution. |
| Custom backend sync / Sign in with Apple | **Not functional** | There is no live JWT issuer route and no `/v1/cards` route, so the Vercel-backed account sync does not work. **Do not mention accounts, login, or cloud/server sync in the description.** iCloud (CloudKit) device-to-device sync *is* real — see below. |
| iCloud / CloudKit sync | Works, needs container | `CardOnCueApp.swift` uses SwiftData with `cloudKitDatabase: .automatic` and container `iCloud.com.cardoncue.app`. Enable the iCloud capability + that container on the App ID, or it silently falls back to local-only. |
| Apple Watch app | Ships embedded | Bundle ID `com.nathanfennel.CardOnCue.watchkitapp`. Watch apps do **not** get a separate App Store listing; screenshots are optional but recommended. |

---

## 1. App information

| Field | Value |
|---|---|
| **App name** | CardOnCue |
| **Subtitle** (30 char max) | `Your cards, right on cue` (24) |
| **Bundle ID** | `com.nathanfennel.CardOnCue` |
| **Watch bundle ID** | `com.nathanfennel.CardOnCue.watchkitapp` |
| **SKU** | `CARDONCUE001` (any unique string) |
| **Primary category** | Utilities |
| **Secondary category** | Finance *(or Shopping — see note)* |
| **Version** | 1.0 |
| **Build** | 1 |
| **Minimum iOS** | 17.0 |
| **Minimum watchOS** | 10.0 |
| **Devices** | iPhone + iPad (`TARGETED_DEVICE_FAMILY = 1,2`) + Apple Watch |
| **Content rights** | Does not contain, show, or access third-party content |

> **Category note:** the app stores loyalty/membership cards and gift-card balances. *Utilities* is the safest primary. Avoid *Finance* as primary — it invites extra financial-services scrutiny during review.

---

## 2. Localizations

The app ships **85 localizations** (`CardOnCue/*.lproj`). You do **not** need App Store metadata for all 85 — App Store Connect only shows languages you explicitly add.

- **Minimum:** English (U.S.) — the development language.
- **Recommended:** add metadata for your top markets only (e.g. en-GB, es-MX, es-ES, fr-FR, de-DE, it, pt-BR, ja, ko, zh-Hans, zh-Hant). Every added locale needs its own description, keywords, **and screenshots**.
- Localizations without App Store metadata still work in-app; they just show the English store listing.

---

## 3. Store listing copy

### Promotional text (170 max, editable without a new build)
```
Never fumble for a membership card again. CardOnCue surfaces the right barcode
the moment you walk into the store — private, offline, and instant.
```

### Description
```
CardOnCue is a location-aware wallet for the cards that aren't in Apple Wallet —
warehouse club memberships, library cards, gym passes, loyalty programs and
one-time passes.

WALKS YOU THROUGH CHECKOUT
Arrive at a store and CardOnCue notifies you with the right card already open and
ready to scan. No searching, no screenshots, no holding up the line.

BUILT FOR REAL SCANNERS
CardOnCue doesn't just store a photo of your card. It reads the barcode and
regenerates a crisp, high-contrast code on screen, so checkout scanners actually
read it — even from a cracked screen or a faded original.

ADD CARDS IN SECONDS
Scan a barcode with the camera, import an existing photo from your library, or
type a number in by hand. Smart text recognition fills in the card name and
details for you.

PRIVATE BY DESIGN
Your card data is encrypted on your device and your location never leaves it.
CardOnCue does not track where you go, does not keep location history, and has
no ads or trackers. Geofencing runs entirely on your iPhone.

ON YOUR WRIST
Your cards sync to Apple Watch, so you can raise your wrist and scan without
taking your phone out at all.

ALSO INCLUDED
• Organize cards with categories, icons and custom artwork
• One-time passes with expiry dates
• Gift-card balance tracking with receipt photos
• Archive cards you no longer use
• Full dark mode support
• Works completely offline
```

### Keywords (100 char max, comma-separated, no spaces)
```
loyalty,membership,barcode,card,wallet,scanner,gym,library,costco,rewards,gift,QR,pass,store
```
(93 characters.)

### URLs
| Field | URL |
|---|---|
| Support URL *(required)* | `https://cardoncue.vercel.app/support` |
| Marketing URL *(optional)* | `https://cardoncue.vercel.app` |
| Privacy Policy URL *(required)* | `https://cardoncue.vercel.app/privacy` |

All four pages (`/support`, `/privacy`, `/terms`, `/features`) exist and are public.

### What's New in This Version (1.0)
```
The first release of CardOnCue.
```

---

## 4. App Privacy ("nutrition label")

Answer these in App Store Connect → App Privacy. Based on the shipped code:

| Data type | Collected? | Notes |
|---|---|---|
| **Precise location** | **Not collected** | Used **only on-device** for region monitoring. Never transmitted, never stored as history. Declare as "not collected" — on-device-only use does not count as collection. |
| **Contact info / identifiers** | **Not collected** | There is no account system in the shipping build. |
| **Photos** | **Not collected** | Imported images stay on device (`CardImageStorageService`). |
| **Purchases / financial info** | **Not collected** | Gift-card balances are entered by the user and stored locally/iCloud. |
| **Usage data / analytics** | **Not collected** | No analytics SDK is linked. |
| **Diagnostics** | **Not collected** | No crash reporter is linked. |

**Tracking:** No. The app does not use IDFA and links no ad/attribution SDKs — do **not** add `NSUserTrackingUsageDescription` and answer "No" to tracking.

> ⚠️ **One thing to confirm before you submit.** `APIClient.discoverGiftCardBrand()` posts the **card name** (and optionally barcode + metadata) to `cardoncue.vercel.app`, which forwards it to Anthropic's API for brand identification. `matchCardTemplate()` can send an image hash and OCR text signature. If either path is reachable in the shipped build, you must disclose it — most conservatively as **"Other User Content — App Functionality — not linked to identity."** If you disable those calls for 1.0, the table above stands as written.

---

## 5. Age rating

Answer **None** to every content question → **4+**.
No user-generated content, no web browsing, no gambling, no unrestricted web access.

---

## 6. Export compliance

`Info.plist` already sets `ITSAppUsesNonExemptEncryption = false`, so App Store Connect will **not** prompt on each upload.

This is correct: the app uses AES-GCM and Keychain via Apple's own CryptoKit/Security frameworks purely to protect local user data, which falls under the standard exemption. No CCATS/ERN filing is required.

---

## 7. App Review notes

Paste into **App Review Information → Notes**:

```
CardOnCue stores membership and loyalty card barcodes locally and shows the right
card when you arrive at a saved store location.

NO ACCOUNT IS REQUIRED. There is no login, so no demo account is needed. All
features are available immediately on launch.

WHY THE APP REQUESTS "ALWAYS" LOCATION:
The core feature is a geofence reminder. The app registers CoreLocation region
monitoring for stores the user has saved to a card, and posts a LOCAL notification
when the user arrives so the card is ready to scan at checkout. This requires
Always authorization to work while the app is backgrounded. Location is processed
entirely on device — it is never uploaded, never stored as history, and there is
no location tracking of any kind.

WHY THE APP REQUESTS CAMERA:
To scan the barcode/QR code on a physical membership card (AVFoundation + Vision).

WHY THE APP REQUESTS PHOTO LIBRARY:
So the user can import an existing photo of a card instead of scanning it.

TESTING WITHOUT A PHYSICAL CARD:
Reviewers can add a card without scanning: on the card list tap "+" and choose
manual entry, then type any number (e.g. 123456789012) and pick a barcode type.
The generated barcode renders immediately. A location can be attached from the
card detail screen to exercise the geofence feature.

APPLE WATCH:
The watch app mirrors saved cards from the iPhone over WatchConnectivity and
renders the barcode on the wrist. It requires the iPhone app to have at least one
card saved.
```

---

## 8. Screenshots

### Required sizes (App Store Connect, current requirements)

You only need to upload the **largest** size per device family; App Store Connect
scales down for smaller devices.

| Device family | Required? | Simulator to use | Portrait px |
|---|---|---|---|
| iPhone 6.9" | **Required** | iPhone 17 Pro Max | 1320 × 2868 |
| iPad 13" | **Required** (app supports iPad) | iPad Pro 13-inch (M5) | 2064 × 2752 |
| Apple Watch | Optional | Apple Watch Ultra / Series 10 | 410 × 502 (Ultra: 502 × 610) |

- 3–10 screenshots per size. First 2–3 are what users actually see — lead with the value proposition.
- No device frames or transparency. No "alpha" channel.

### Suggested screenshot sequence
1. **Arrive & get notified** — the geofence notification with the card ready
2. **Card list** — several cards with icons/artwork
3. **Barcode detail** — a large, crisp, scannable barcode
4. **Scan a card** — the scanner with the confidence meter
5. **Apple Watch** — barcode on the wrist
6. **Privacy** — the "your location never leaves your device" message

### Capturing them
```bash
# boot + install + launch
xcrun simctl boot "iPhone 17 Pro Max"
xcrun simctl install booted /path/to/CardOnCue.app
xcrun simctl launch booted com.nathanfennel.CardOnCue

# capture at native resolution
xcrun simctl io booted screenshot ~/Desktop/shots/iphone-6.9-01.png
```
Use **Simulator → Device → Erase All Content and Settings** between runs to get a
clean first-launch/onboarding state.

> **Note:** screenshots are intentionally **not** committed to this repo.

---

## 9. Build, archive, upload

```bash
# 1. Set your Team ID first (project.yml → DEVELOPMENT_TEAM, all 4 targets)

# 2. Archive (Release)
xcodebuild -project CardOnCue.xcodeproj \
  -scheme CardOnCue \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/CardOnCue.xcarchive \
  archive

# 3. Export + upload
xcodebuild -exportArchive \
  -archivePath build/CardOnCue.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/export
```
Or simply **Xcode → Product → Archive → Distribute App**, which is less error-prone
for a first submission.

Requires the **watchOS platform installed** (`xcodebuild -downloadPlatform watchOS`)
because the scheme embeds the Watch app.

---

## 10. Pre-submission checklist

- [ ] `DEVELOPMENT_TEAM` set on all four targets
- [ ] App ID has **iCloud** (container `iCloud.com.cardoncue.app`) enabled
- [ ] App ID does **not** need Push Notifications (the app uses local notifications only — the unused `remote-notification` background mode and `aps-environment` entitlement were removed)
- [ ] Version 1.0 / Build 1 (bump the build for every upload)
- [ ] Screenshots uploaded for iPhone 6.9" and iPad 13"
- [ ] Privacy Policy URL reachable
- [ ] App Privacy answers completed (see §4, including the brand-discovery caveat)
- [ ] Age rating completed → 4+
- [ ] App Review notes pasted (see §7)
- [ ] Description contains **no** claim of account/cloud sync (not functional — see §0)
- [ ] Tested a fresh install: onboarding → add card manually → barcode renders

---

## 11. Build health (as of 2026-07-21)

Full clean build of the scheme (iPhone app **and** embedded Watch app), Debug,
iOS Simulator:

```
** BUILD SUCCEEDED **   0 errors   1 warning
```

The single remaining warning is
`BarcodeScannerView.swift:1335` — capture of non-Sendable `BarcodeScannerViewModel`
in a `@Sendable` closure. It is a Swift 6 readiness note, not a defect, and does
not affect submission. Fixing it properly requires isolating the AVCaptureSession
work behind an actor; marking the view model `@MainActor` was tried and cascades
into 19 new warnings because the capture session runs on its own queue.

Two `appintentsmetadataprocessor: Metadata extraction skipped` lines are emitted by
the toolchain because the app links no AppIntents framework. They are informational
and cannot be silenced without adding App Intents.
