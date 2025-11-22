# CardOnCue Testing Plan

## Overview

Comprehensive testing strategy for CardOnCue covering unit tests, integration tests, UI tests, and end-to-end testing.

---

## Table of Contents

1. [Testing Pyramid](#testing-pyramid)
2. [Backend Testing](#backend-testing)
3. [iOS Testing](#ios-testing)
4. [E2E Testing](#e2e-testing)
5. [Performance Testing](#performance-testing)
6. [Security Testing](#security-testing)
7. [CI/CD Pipeline](#cicd-pipeline)
8. [QA Checklist](#qa-checklist)

---

## Testing Pyramid

```
        /\
       /  \
      / E2E \          <-- 10% - End-to-end user flows
     /--------\
    /          \
   / Integration \     <-- 20% - API + service integration
  /--------------\
 /                \
/  Unit Tests      \   <-- 70% - Individual functions/classes
--------------------
```

**Target Coverage**:
- Unit tests: 80%+ code coverage
- Integration tests: Critical paths covered
- E2E tests: 5-10 key user flows

---

## Backend Testing

### Unit Tests

**Framework**: Jest

**Coverage**:
- `api/utils/auth.js`: JWT generation, verification, token extraction
- `api/utils/db.js`: Database operations (CRUD for all models)
- `api/v1/region-refresh.js`: Nearest-K algorithm logic

**Example Test** (`api/__tests__/auth.test.js`):
```javascript
const { generateTokens, verifyToken } = require('../utils/auth');

describe('Auth Utils', () => {
  test('generateTokens creates valid JWT', () => {
    const tokens = generateTokens('user_123', 'test@example.com');
    expect(tokens.access_token).toBeDefined();
    expect(tokens.refresh_token).toBeDefined();
    expect(tokens.expires_in).toBe(900);
  });

  test('verifyToken decodes valid token', () => {
    const tokens = generateTokens('user_123', 'test@example.com');
    const decoded = verifyToken(tokens.access_token);
    expect(decoded.sub).toBe('user_123');
    expect(decoded.type).toBe('access');
  });

  test('verifyToken rejects expired token', () => {
    // Mock expired token
    const expiredToken = 'eyJhbGc...'; // Expired JWT
    const decoded = verifyToken(expiredToken);
    expect(decoded).toBeNull();
  });
});
```

**Run Tests**:
```bash
cd web
npm test
```

### Integration Tests

**Coverage**:
- API endpoint responses (auth, cards, region-refresh)
- Database transactions (create → read → update → delete)
- Error handling (401, 404, 500 responses)

**Example**:
```javascript
describe('POST /v1/cards', () => {
  let authToken;

  beforeAll(async () => {
    // Create test user and get token
    const response = await request(app)
      .post('/v1/auth/apple')
      .send({ identity_token: 'test', user_identifier: 'test-user' });
    authToken = response.body.access_token;
  });

  test('creates card with valid data', async () => {
    const card = {
      name: 'Test Card',
      barcode_type: 'qr',
      payload_encrypted: 'encrypted-data',
      tags: ['test'],
      network_ids: ['costco'],
    };

    const response = await request(app)
      .post('/v1/cards')
      .set('Authorization', `Bearer ${authToken}`)
      .send(card);

    expect(response.status).toBe(201);
    expect(response.body.name).toBe('Test Card');
  });

  test('rejects card without auth token', async () => {
    const response = await request(app)
      .post('/v1/cards')
      .send({ name: 'Test' });

    expect(response.status).toBe(401);
  });
});
```

### API Contract Testing

Use OpenAPI spec (`docs/api-spec.yaml`) to validate:
- All endpoints return correct schema
- Error responses match spec

**Tool**: `openapi-validator` or Postman

---

## iOS Testing

### Unit Tests

**Framework**: XCTest

**Coverage**:
- `BarcodeService`: Rendering logic (CoreImage filters)
- `LocationService`: Region refresh decision logic
- `StorageService`: Encryption/decryption
- `KeychainService`: Key storage/retrieval
- `APIClient`: Request building, error handling

**Example Test** (`CardOnCueTests/Services/BarcodeServiceTests.swift`):
```swift
import XCTest
@testable import CardOnCue

class BarcodeServiceTests: XCTestCase {
    var barcodeService: BarcodeService!

    override func setUp() {
        super.setUp()
        barcodeService = BarcodeService()
    }

    func testRenderQRCode() throws {
        let payload = "TEST123"
        let size = CGSize(width: 300, height: 300)

        let image = try barcodeService.renderBarcode(
            payload: payload,
            type: .qr,
            size: size
        )

        XCTAssertNotNil(image)
        XCTAssertEqual(image.size.width, 300, accuracy: 10)
    }

    func testRenderCode128() throws {
        let payload = "123456789"
        let size = CGSize(width: 300, height: 150)

        let image = try barcodeService.renderBarcode(
            payload: payload,
            type: .code128,
            size: size
        )

        XCTAssertNotNil(image)
    }

    func testRenderInvalidPayload() {
        let payload = "" // Empty payload
        let size = CGSize(width: 300, height: 300)

        XCTAssertThrowsError(
            try barcodeService.renderBarcode(payload: payload, type: .qr, size: size)
        )
    }
}
```

**Run Tests**:
```bash
cd ios
xcodebuild test -project CardOnCue.xcodeproj -scheme CardOnCue -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Integration Tests

**Coverage**:
- `LocationService` + `APIClient`: Region refresh flow
- `StorageService` + `KeychainService`: Encrypted card save/load
- `BarcodeService` + `StorageService`: Scan → save → retrieve flow

**Example**:
```swift
func testRegionRefreshFlow() async throws {
    let keychainService = KeychainService()
    let apiClient = APIClient(baseURL: "http://localhost:3000/v1", keychainService: keychainService)
    let storageService = StorageService(keychainService: keychainService)

    let locationService = LocationService()
    locationService.configure(apiClient: apiClient, storageService: storageService)

    // Simulate location update
    let location = CLLocation(latitude: 37.7749, longitude: -122.4194)
    locationService.currentLocation = location

    // Trigger refresh
    try await locationService.forceRefresh()

    // Verify regions were updated
    XCTAssertGreaterThan(locationService.monitoredRegions.count, 0)
    XCTAssertLessThanOrEqual(locationService.monitoredRegions.count, 20)
}
```

### UI Tests

**Framework**: XCUITest

**Coverage**:
- Scanner flow: Open camera → scan barcode → save card
- Card list: Display cards → tap card → view barcode
- Location-based notification: Simulate region entry → verify notification

**Example** (`CardOnCueUITests/ScannerFlowTests.swift`):
```swift
func testScanAndSaveCard() throws {
    let app = XCUIApplication()
    app.launch()

    // Tap "Add Card" button
    app.buttons["Add Card"].tap()

    // Wait for camera permission alert
    addUIInterruptionMonitor(withDescription: "Camera Permission") { alert in
        alert.buttons["Allow"].tap()
        return true
    }

    // Simulate barcode scan (requires test data injection)
    // In real app, use XCTestCase's private API or mock scanner

    // Fill in card details
    app.textFields["Card Name"].tap()
    app.textFields["Card Name"].typeText("Test Costco Card")

    // Select network
    app.buttons["Select Network"].tap()
    app.cells["Costco"].tap()

    // Save
    app.buttons["Save"].tap()

    // Verify card appears in list
    XCTAssertTrue(app.cells["Test Costco Card"].exists)
}
```

---

## E2E Testing

### User Flows

1. **Onboarding → Scan → Location Trigger**
   - Launch app
   - Sign in with Apple
   - Grant location permission
   - Scan a Costco card
   - Simulate location at Costco
   - Verify notification appears
   - Tap notification → verify card shown

2. **Multi-Card Selection**
   - Save 3 library cards (family members)
   - Simulate location at library
   - Verify notification shows card selector
   - Switch between cards

3. **One-Time Pass**
   - Save Amazon return QR (one-time)
   - View card → mark as used
   - Verify card shows as "Used"

### Tools

- **iOS**: XCUITest + manual testing
- **Backend**: Postman collections + Newman (CLI runner)

---

## Performance Testing

### Backend

**Metrics**:
- Region-refresh API response time: < 200ms (p95)
- Card CRUD operations: < 100ms (p95)
- Concurrent users: 1000 simultaneous connections

**Tool**: Apache JMeter or k6

**Load Test Script** (k6):
```javascript
import http from 'k6/http';
import { check } from 'k6';

export let options = {
  vus: 100, // 100 virtual users
  duration: '30s',
};

export default function () {
  const payload = JSON.stringify({
    lat: 37.7749,
    lon: -122.4194,
    user_networks: ['costco', 'whole-foods'],
    max_regions: 20,
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      Authorization: 'Bearer test-token',
    },
  };

  const res = http.post('http://localhost:3000/v1/region-refresh', payload, params);

  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 200ms': (r) => r.timings.duration < 200,
  });
}
```

### iOS

**Metrics**:
- App launch time: < 2 seconds (cold start)
- Barcode render time: < 100ms
- Location refresh: < 500ms

**Tool**: Xcode Instruments (Time Profiler, Allocations)

---

## Security Testing

### Penetration Testing

**Scope**:
- API authentication bypass attempts
- SQL injection (parameterized queries)
- XSS attacks (API only returns JSON)
- JWT token tampering

**Checklist**:
- [ ] Test expired JWT rejection
- [ ] Test invalid JWT signature rejection
- [ ] Test SQL injection in all endpoints
- [ ] Test HTTPS enforcement (HTTP should redirect)
- [ ] Test rate limiting (>100 requests/min should 429)

### Encryption Testing

**iOS**:
- [ ] Verify master key stored in Keychain with correct access control
- [ ] Verify SQLite database uses Data Protection Class C
- [ ] Verify payloads encrypted with AES-256-GCM
- [ ] Attempt to extract plaintext from device backup (should fail)

**Tools**: Hopper Disassembler, Charles Proxy

---

## CI/CD Pipeline

### GitHub Actions Workflow

**File**: `.github/workflows/ci.yml`

```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  # Backend tests
  backend-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'

      - name: Install dependencies
        run: |
          cd web
          npm ci

      - name: Run tests
        run: |
          cd web
          npm test -- --coverage

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./web/coverage/coverage-final.json

  # iOS tests
  ios-test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: '15.0'

      - name: Run tests
        run: |
          cd ios
          xcodebuild test \
            -project CardOnCue.xcodeproj \
            -scheme CardOnCue \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            -enableCodeCoverage YES

      - name: Generate coverage report
        run: |
          xcrun xccov view --report --json ios/DerivedData/Logs/Test/*.xcresult > coverage.json

  # Lint
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Lint backend
        run: |
          cd web
          npm ci
          npm run lint

      - name: Validate OpenAPI spec
        run: |
          npx @apidevtools/swagger-cli validate docs/api-spec.yaml

  # Deploy (production only)
  deploy:
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    needs: [backend-test, ios-test, lint]
    steps:
      - uses: actions/checkout@v3

      - name: Deploy to Vercel
        env:
          VERCEL_TOKEN: ${{ secrets.VERCEL_TOKEN }}
        run: |
          cd web
          npx vercel --prod --token $VERCEL_TOKEN
```

---

## QA Checklist

### Pre-Release Checklist

**Backend**:
- [ ] All API endpoints return correct status codes
- [ ] OpenAPI spec matches implementation
- [ ] JWT tokens expire correctly
- [ ] Rate limiting works (429 on abuse)
- [ ] Database migrations tested
- [ ] Environment variables set in production

**iOS**:
- [ ] Barcode scanning works on physical device
- [ ] Barcode rendering produces crisp images
- [ ] Location permissions prompt appears
- [ ] Region monitoring triggers notifications
- [ ] Cards encrypted at rest (verify with debugger)
- [ ] App works offline (local-only mode)
- [ ] Dark mode support
- [ ] VoiceOver accessibility

**Integration**:
- [ ] Sign in with Apple works
- [ ] Card sync works (if enabled)
- [ ] Region refresh updates monitored regions
- [ ] Push notifications work (if implemented)

### Regression Testing

After major changes, re-test:
1. Core user flows (scan → save → location trigger)
2. Authentication (sign in → sign out → sign in again)
3. Encryption (save card → quit app → restart → verify card loads)

---

## Performance Benchmarks

### Backend

| Endpoint | Target (p95) | Current |
|----------|--------------|---------|
| POST /v1/auth/apple | 150ms | TBD |
| GET /v1/cards | 100ms | TBD |
| POST /v1/region-refresh | 200ms | TBD |
| GET /v1/locations/nearby | 150ms | TBD |

### iOS

| Operation | Target | Current |
|-----------|--------|---------|
| App launch (cold) | 2s | TBD |
| Barcode scan | 1s | TBD |
| Barcode render | 100ms | TBD |
| Card decrypt | 50ms | TBD |

---

## Test Data

**Test Users**:
- `test-user-1@example.com` (has 5 cards)
- `test-user-2@example.com` (has 0 cards)
- `test-admin@cardoncue.app` (admin role)

**Test Cards**:
- Costco: `123456789` (Code128)
- Library: `https://sfpl.org/card/987654321` (QR)
- Amazon Return: `AMZN-RET-001` (QR, one-time)

**Test Locations**:
- Costco SF: 37.7749, -122.4194
- Main Library: 37.7790, -122.4153

---

## Continuous Improvement

**Monthly**:
- Review test coverage reports
- Update flaky tests
- Add tests for new features

**Quarterly**:
- Full regression test suite
- Performance benchmarking
- Security audit

---

## References

- [iOS Testing Guide](https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/testing_with_xcode/)
- [Jest Documentation](https://jestjs.io/docs/getting-started)
- [k6 Performance Testing](https://k6.io/docs/)
