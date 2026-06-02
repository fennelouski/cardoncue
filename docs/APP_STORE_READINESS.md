# CardOnCue — App Store Readiness: Manual Steps

The code changes for v1 are done (persistence, multi-location grouping, geofence
notifications, full CRUD, crash/readiness fixes). The app builds clean for the
iOS Simulator and launches. The items below are things that **cannot be done in
code** — they require your Apple Developer account, Xcode signing UI, the
CloudKit/App Store Connect dashboards, hosting, and a physical device. They are
ordered roughly by dependency.

---

## 1. Signing & capabilities (Xcode → target “CardOnCue” → Signing & Capabilities)

- [ ] **Set the Development Team.** `DEVELOPMENT_TEAM` is currently empty in the
  project. Select your team so the app can be signed.
- [ ] **Confirm the bundle identifier.** The app target uses
  `com.nathanfennel.CardOnCue`. ⚠️ The (deferred) watch app’s Info.plist sets
  `WKCompanionAppBundleIdentifier = app.cardoncue.CardOnCue`, and the CloudKit
  container is `iCloud.com.cardoncue.app` — the naming is inconsistent. Pick one
  scheme and make the bundle id, container id, and app-group id consistent.
- [ ] **Add the iCloud capability** with **CloudKit** enabled and create the
  container (e.g. `iCloud.com.cardoncue.app`) in the
  [CloudKit dashboard](https://icloud.developer.apple.com/). Until this exists,
  SwiftData stays local-only (the code uses `.automatic`, so it won’t crash —
  it just won’t sync).
- [ ] **Add the Push Notifications capability** (CloudKit sync uses silent
  pushes; the app already declares the `remote-notification` background mode).
- [ ] **Add the Background Modes capability** and tick **Location updates** and
  **Remote notifications** (Info.plist already lists them; the capability must
  also be enabled for the signed build).
- [ ] **Add the App Groups capability** and create
  `group.com.cardoncue.app`. `GeofenceManager` writes the last known location to
  `UserDefaults(suiteName: "group.com.cardoncue.app")`; without the entitlement
  those writes silently fail (and any future widget can’t read them).
- [ ] Adding these capabilities generates a `CardOnCue.entitlements` file and
  wires `CODE_SIGN_ENTITLEMENTS`. Commit it.

## 2. CloudKit

- [ ] After running the app once with the iCloud entitlement (which creates the
  schema in the **Development** environment), **deploy the schema to
  Production** in the CloudKit dashboard before release. Records won’t sync for
  App Store users otherwise.
- [ ] Verify sync end-to-end across two devices on the same iCloud account.

## 3. Export compliance (encryption)

- [ ] The app encrypts card payloads with AES-GCM (CryptoKit). Add
  **`ITSAppUsesNonExemptEncryption`** to `CardOnCue/Info.plist`. For standard
  encryption like this you can typically set it to `<false/>` (exempt), but
  confirm against
  [Apple’s export-compliance guidance](https://developer.apple.com/documentation/security/complying_with_encryption_export_regulations).
  Without this key, every App Store Connect upload prompts you for it.

## 4. Assets & presentation

- [ ] **App icon:** confirm `Assets.xcassets/AppIcon` has all required sizes,
  including the 1024×1024 marketing icon. (A single 1024 “any appearance” icon
  is acceptable on recent Xcode.)
- [ ] **Launch screen:** a minimal `UILaunchScreen` (AppBackground color) was
  added. Optionally design a branded one.
- [ ] **Device family:** `TARGETED_DEVICE_FAMILY = "1,2"` (iPhone **and** iPad).
  Either test + provide iPad screenshots, or set it to `1` (iPhone only) to
  avoid iPad review requirements.

## 5. App Store Connect

- [ ] Register the bundle id and **create the app record**.
- [ ] **Privacy policy URL** (required — mandatory because the app uses
  location). Host a policy page.
- [ ] **App Privacy “nutrition labels”:** declare what’s collected. Cards are
  stored encrypted on-device and in the user’s private CloudKit DB; location is
  used on-device for geofencing. Declare location use and any backend calls
  (the Vercel API receives card images/text for brand/template matching —
  disclose that).
- [ ] **Screenshots** for required device sizes, description, keywords,
  category, support URL, age rating.
- [ ] **“Always” location justification:** background geofencing uses Always
  authorization. Be ready to explain it in App Review notes; the purpose
  strings are already in Info.plist.

## 6. Backend (Vercel)

- [ ] Confirm the production API at `https://cardoncue.vercel.app/api` is stable
  (uptime, CORS, rate limiting, error handling). The base URL is now overridable
  via the `API_BASE_URL` Info.plist key per build config if you need staging vs
  prod.
- [ ] Decide what happens when the backend is unavailable — the app degrades to
  manual entry, but verify the UX.

## 7. Device testing (cannot be validated in the simulator)

- [ ] **Geofencing & notifications on a real device:** grant Always location +
  notifications, save a card with a location, physically arrive (or use Xcode’s
  GPX location simulation) and confirm the entry notification fires, including
  after the app is backgrounded/relaunched.
- [ ] **Camera scanning** of real barcodes (QR, Code128, PDF417, Aztec, EAN/UPC).
- [ ] **Original-image persistence:** scan a card, tap Save immediately, reopen
  — the original image must be present.
- [ ] Run a **TestFlight** beta before public release.

## 8. Watch app (deferred for v1)

The watchOS target was detached from the iOS build because
`WatchBarcodeRenderer` uses **CoreImage**, which isn’t available on watchOS, so
it can never compile for the watch. Before shipping a watch app you must either:
- [ ] Replace CoreImage barcode generation with a watchOS-compatible path
  (pure-Swift generator, or render the barcode on the phone and hand the image
  to the watch via the notification payload / WatchConnectivity), then re-add
  the target dependency + “Embed Watch Content” phase; **or**
- [ ] Remove the watch target from the repo if it’s not part of the near-term
  roadmap.

## 9. Known follow-ups (code, not strictly blocking)

- [ ] `OCRExtractionTests` has pre-existing failing tests (OCR segment-detection
  accuracy) unrelated to v1 work — fix or update expectations.
- [ ] `LocationService.swift` is dormant/unused (kept because it defines
  `RegionRefreshRequest` used by `APIClient.refreshRegions`). Consider removing
  it and the unused region-refresh endpoint, or wiring it up intentionally.
- [ ] `APIClient` builds URLs with `appendingPathComponent(endpoint)` even when
  `endpoint` contains a query string (`?limit=…&near=…`), which percent-encodes
  the `?`. Verify multi-location fetches actually hit the backend correctly; if
  not, switch to `URLComponents`.
- [ ] Dead `SignInButton` view remains in `OnboardingView.swift` after Clerk
  removal — safe to delete.
