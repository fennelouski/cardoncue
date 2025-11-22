# CardOnCue

**Location-aware digital wallet for membership cards, loyalty cards, and one-time passes.**

CardOnCue automatically surfaces the correct barcode or QR code when you arrive at a location—whether it's Costco, your local library, or an Amazon return location. Privacy-first, free-tier optimized, with intelligent workarounds for iOS platform constraints.

---

## 🎯 Project Vision

**Problem**: You're at Costco checkout, fumbling through your phone trying to find your membership card photo while people wait behind you.

**Solution**: CardOnCue monitors your location in the background and sends a notification with your card ready to scan the moment you walk in.

**Key Differentiators**:
- ✅ **Privacy-first**: No location tracking or history. Local-first storage with optional E2E encrypted sync.
- ✅ **Free-tier friendly**: Uses OpenStreetMap + curated data instead of expensive Google APIs.
- ✅ **Smart rendering**: Generates crisp barcodes from scanned data (not just photos) so store scanners work reliably.
- ✅ **iOS region limit workaround**: Dynamic region refresh algorithm monitors 20 nearest locations and swaps them as you move.

---

## 📋 Table of Contents

1. [Features](#-features)
2. [Architecture](#-architecture)
3. [Project Structure](#-project-structure)
4. [Quick Start](#-quick-start)
5. [Documentation](#-documentation)
6. [Development](#-development)
7. [Deployment](#-deployment)
8. [Contributing](#-contributing)
9. [License](#-license)

---

## ✨ Features

### Core Features

- **📷 Barcode Scanning**: Scan membership cards using AVFoundation + Vision framework
- **🎨 Barcode Rendering**: Generate crisp, scannable barcodes using CoreImage filters
- **📍 Location-Aware**: Automatically surface cards when arriving at stores (region monitoring + dynamic refresh)
- **🔒 Privacy & Security**: AES-256-GCM encryption, Keychain storage, no location tracking
- **👨‍👩‍👧‍👦 Multi-Card Support**: Store multiple cards per location (family members, different accounts)
- **⏱️ One-Time Passes**: Support for time-limited passes (Amazon returns, event tickets)
- **🌐 Optional Sync**: E2E encrypted cloud backup (server cannot decrypt)

### Platform-Specific

**iOS**:
- SwiftUI interface
- Region monitoring (up to 20 regions)
- Local notifications on region entry
- Apple Wallet export (PKPass)
- Dark mode support

**Backend**:
- Vercel Serverless Functions
- In-memory database (dev) → PostgreSQL + PostGIS (production)
- Sign in with Apple
- RESTful API (OpenAPI v3 spec)

---

## 🏗️ Architecture

### High-Level Overview

```
┌─────────────────┐
│   iOS App       │  SwiftUI + CoreLocation + AVFoundation
│  (Local-first)  │  Encrypted SQLite + Keychain
└────────┬────────┘
         │ Optional sync (E2E encrypted)
         ↓
┌─────────────────┐
│ Vercel Backend  │  Serverless Functions (Node.js)
│  (Stateless)    │  JWT auth + Region refresh API
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  Curated Data   │  OpenStreetMap + Foursquare free tier
│   + User Cards  │  PostgreSQL (production)
└─────────────────┘
```

### Key Components

1. **iOS Services**:
   - `BarcodeService`: Scanning + rendering
   - `LocationService`: Region monitoring + dynamic refresh
   - `StorageService`: Encrypted local storage
   - `APIClient`: HTTP client for backend
   - `KeychainService`: Secure key storage

2. **Backend API** (`/v1`):
   - `/auth/apple`: Sign in with Apple
   - `/cards`: Card CRUD (E2E encrypted payloads)
   - `/region-refresh`: Get top 20 nearest locations
   - `/locations/nearby`: Search for locations
   - `/networks`: List card networks (Costco, libraries, etc.)

3. **Data Model**:
   - **Card**: User's membership card (encrypted payload)
   - **Network**: Chain of locations (e.g., "Costco")
   - **Location**: Physical store/branch (lat/lon + radius)
   - **MonitoredRegion**: CLCircularRegion returned by region-refresh API

See [`docs/architecture.md`](docs/architecture.md) for detailed diagrams and algorithm explanations.

---

## 📁 Project Structure

```
CardOnCue/
├── docs/
│   ├── architecture.md         # System architecture + Mermaid diagrams
│   ├── api-spec.yaml           # OpenAPI v3 specification
│   ├── privacy-security.md     # Encryption & privacy details
│   └── testing-plan.md         # Testing strategy + QA checklist
├── ios/
│   ├── CardOnCue/
│   │   ├── Models/             # Card, Network, Location, BarcodeType
│   │   ├── Services/           # BarcodeService, LocationService, etc.
│   │   ├── Features/           # Scanner, Cards, LocationManager
│   │   └── Views/              # BarcodeView, CardSelectorView
│   └── README.md               # iOS setup instructions
├── web/
│   ├── api/
│   │   ├── utils/              # Auth, DB helpers
│   │   └── v1/                 # API endpoints
│   ├── package.json
│   └── README.md               # Backend setup instructions
├── infra/
│   └── importers/
│       ├── import.js           # CSV importer for locations
│       ├── sample-networks.csv # Sample network definitions
│       ├── costco-locations.csv
│       ├── whole-foods-locations.csv
│       ├── kohls-locations.csv
│       └── sfpl-locations.csv  # San Francisco Public Library
├── .github/
│   └── workflows/
│       └── ci.yml              # GitHub Actions CI/CD
└── README.md                   # This file
```

---

## 🚀 Quick Start

### Prerequisites

- **iOS Development**:
  - Xcode 15.0+
  - iOS 17.0+
  - Apple Developer account (for device testing)

- **Backend Development**:
  - Node.js 18+
  - Vercel CLI (optional): `npm install -g vercel`

### 1. Clone Repository

```bash
git clone https://github.com/your-username/CardOnCue.git
cd CardOnCue
```

### 2. Backend Setup

```bash
cd web
npm install
npm run dev
```

Backend runs on `http://localhost:3000`.

See [`web/README.md`](web/README.md) for details.

### 3. iOS Setup

1. Open Xcode
2. Create new iOS app project in `ios/` directory:
   - Product Name: **CardOnCue**
   - Bundle ID: `app.cardoncue.CardOnCue`
   - Interface: **SwiftUI**
3. Add all `.swift` files from `ios/CardOnCue/` to the project
4. Configure capabilities:
   - Sign in with Apple
   - Background Modes (Location updates)
   - Location permissions (Info.plist)
5. Build and run (⌘R)

See [`ios/README.md`](ios/README.md) for detailed setup instructions.

### 4. Test the Integration

```bash
# Terminal 1: Start backend
cd web && npm run dev

# Terminal 2: Import sample data
cd infra/importers
node import.js networks sample-networks.csv
node import.js costco costco-locations.csv

# Xcode: Run iOS app and test region refresh
```

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [**Architecture**](docs/architecture.md) | System design, components, dataflow, region-refresh algorithm |
| [**API Spec**](docs/api-spec.yaml) | OpenAPI v3 spec for all endpoints |
| [**Privacy & Security**](docs/privacy-security.md) | Encryption, threat model, compliance (GDPR/CCPA) |
| [**Testing Plan**](docs/testing-plan.md) | Unit/integration/E2E tests, CI/CD, QA checklist |
| [**iOS README**](ios/README.md) | iOS app setup, capabilities, usage |
| [**Backend README**](web/README.md) | Backend API setup, endpoints, deployment |

---

## 🛠️ Development

### Running Tests

**Backend**:
```bash
cd web
npm test
npm run lint
```

**iOS**:
```bash
cd ios
xcodebuild test \
  -project CardOnCue.xcodeproj \
  -scheme CardOnCue \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Code Quality

- **Linting**: ESLint (backend), SwiftLint (iOS - TODO)
- **Formatting**: Prettier (backend), swift-format (iOS - TODO)
- **Coverage**: Jest coverage (backend), Xcode coverage (iOS)

### CI/CD

GitHub Actions workflow (`.github/workflows/ci.yml`) runs on every push:
- ✅ Lint code
- ✅ Run unit tests
- ✅ Validate OpenAPI spec
- ✅ Security scan (npm audit, TruffleHog)
- 🚀 Deploy to Vercel (main branch)

See [`docs/testing-plan.md`](docs/testing-plan.md) for full details.

---

## 🚢 Deployment

### Backend (Vercel)

```bash
cd web

# Login to Vercel
vercel login

# Set environment variables
vercel env add JWT_SECRET production

# Deploy
npm run deploy
```

### iOS (App Store)

1. Archive build in Xcode (Product → Archive)
2. Upload to App Store Connect
3. Submit for TestFlight beta
4. Submit for App Review

**App Store Requirements**:
- Privacy Nutrition Labels configured
- Location usage clearly explained
- Sign in with Apple configured

---

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Workflow

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests (`npm test` / `xcodebuild test`)
5. Commit with clear message (`git commit -m 'Add amazing feature'`)
6. Push to branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Areas for Contribution

- **iOS**: SwiftUI UI improvements, Apple Wallet integration
- **Backend**: PostgreSQL migration, admin UI for data imports
- **Data**: Curated chain location datasets (Costco, libraries, etc.)
- **Docs**: Tutorials, screenshots, video demos
- **Tests**: Increase coverage, E2E tests

---

## 🔐 Security

### Responsible Disclosure

If you discover a security vulnerability, please email **security@cardoncue.app** instead of opening a public issue.

We commit to:
- Acknowledge within 24 hours
- Provide a fix timeline within 7 days
- Credit researchers in release notes (optional)

### Security Features

- AES-256-GCM encryption for all card data
- JWT with short expiry (15 min access, 7 day refresh)
- Keychain with device unlock requirement
- No location history stored
- Row-level security (PostgreSQL)
- HTTPS/TLS 1.3 enforced

See [`docs/privacy-security.md`](docs/privacy-security.md) for threat model and compliance info.

---

## 📊 Roadmap

### v1.0 (Current)
- [x] Barcode scanning + rendering
- [x] Region monitoring + dynamic refresh
- [x] Encrypted local storage
- [x] Sign in with Apple
- [x] Backend API (Vercel)

### v1.1 (Next)
- [ ] Apple Wallet export (PKPass)
- [ ] Home Screen widget
- [ ] Siri Shortcuts integration
- [ ] PostgreSQL migration (replace in-memory DB)
- [ ] Admin UI for location imports

### v1.2 (Future)
- [ ] Android app (React Native or native Kotlin)
- [ ] Web app (for card management)
- [ ] Community-curated location data
- [ ] Premium tier: Unlimited cards, priority sync

---

## 🙏 Acknowledgments

- **OpenStreetMap** for free geospatial data
- **Foursquare** for Places API free tier
- **Apple** for CoreImage barcode filters
- **Vercel** for generous free hosting

### Inspiration

This project was inspired by frustration with:
- Opening Photos app → search "Costco" → wrong card → scroll → find card → tap → pinch to zoom → scan
- Apple Wallet's lack of flexibility for non-Apple Pay cards
- Privacy concerns with cloud-only digital wallets

---

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

**TL;DR**: You can use this code commercially, modify it, distribute it. Just include the original license and don't blame us if things break.

---

## 📞 Contact

- **Email**: hello@cardoncue.app
- **Website**: https://cardoncue.app
- **Twitter**: [@CardOnCue](https://twitter.com/CardOnCue)
- **GitHub Issues**: [Report a bug](https://github.com/your-username/CardOnCue/issues)

---

## ⭐ Show Your Support

If you find CardOnCue useful, please:
- ⭐ Star this repository
- 🐦 Share on Twitter
- 📝 Write a blog post
- 💡 Contribute a feature

**Made with ❤️ by developers tired of fumbling for cards at checkout.**
