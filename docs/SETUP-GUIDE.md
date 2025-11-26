# CardOnCue Setup Guide

Complete setup instructions for unified backend with Clerk authentication.

---

## Prerequisites

- **Vercel Account**: For hosting backend and database
- **Clerk Account**: For authentication (free tier: 10K monthly active users)
- **Xcode 15+**: For iOS development
- **Node.js 18+**: For backend development
- **Apple Developer Account**: For iOS device testing and App Store

---

## Part 1: Clerk Setup

### 1.1 Create Clerk Application

1. Go to [clerk.com](https://clerk.com) and sign up
2. Create a new application:
   - Name: **CardOnCue**
   - Sign-in options: Select **Apple** and **Email**
   - Create Application

3. Configure Sign-in methods:
   - Navigate to **User & Authentication** → **Social Connections**
   - Enable **Apple**
   - Add your iOS Bundle ID and Team ID

### 1.2 Get API Keys

From the Clerk Dashboard:
1. Go to **API Keys**
2. Copy:
   - **Publishable Key** (starts with `pk_live_` or `pk_test_`)
   - **Secret Key** (starts with `sk_live_` or `sk_test_`)

### 1.3 Configure Webhooks

1. Go to **Webhooks** in Clerk Dashboard
2. Click **Add Endpoint**
3. **Endpoint URL**: `https://your-domain.vercel.app/api/webhooks/clerk`
   - For development: `https://your-preview-url.vercel.app/api/webhooks/clerk`
4. **Subscribe to events**:
   - `user.created`
   - `user.updated`
   - `user.deleted`
   - `subscription.created` (if using Clerk subscriptions)
   - `subscription.updated`
   - `subscription.deleted`
5. Copy **Signing Secret** (starts with `whsec_`)

---

## Part 2: Vercel Backend Setup

### 2.1 Create Vercel Project

```bash
# Install Vercel CLI
npm install -g vercel

# Login to Vercel
vercel login

# Link project
cd web
vercel link
```

### 2.2 Create PostgreSQL Database

```bash
# Create Vercel Postgres database
vercel postgres create cardoncue-db

# Link to project
vercel link
```

This will automatically add these environment variables:
- `POSTGRES_URL`
- `POSTGRES_PRISMA_URL`
- `POSTGRES_URL_NON_POOLING`
- `POSTGRES_USER`
- `POSTGRES_HOST`
- `POSTGRES_PASSWORD`
- `POSTGRES_DATABASE`

### 2.3 Set Environment Variables

```bash
cd web

# Set Clerk keys
vercel env add NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY production
# Paste your Clerk publishable key

vercel env add CLERK_SECRET_KEY production
# Paste your Clerk secret key

vercel env add CLERK_WEBHOOK_SECRET production
# Paste your webhook signing secret

# Also add for development
vercel env add NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY development
vercel env add CLERK_SECRET_KEY development
vercel env add CLERK_WEBHOOK_SECRET development
```

**Create local `.env.local` file**:

```bash
# Create .env.local
cat > .env.local << EOF
# Clerk
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_...
CLERK_SECRET_KEY=sk_test_...
CLERK_WEBHOOK_SECRET=whsec_...

# Database (pulled from Vercel)
POSTGRES_URL=postgres://...
POSTGRES_PRISMA_URL=postgres://...
POSTGRES_URL_NON_POOLING=postgres://...

# Node
NODE_ENV=development
EOF
```

### 2.4 Install Dependencies

```bash
cd web
npm install
```

New packages added:
- `@clerk/backend` - Clerk server SDK
- `@vercel/postgres` - Vercel Postgres client
- `svix` - Webhook verification
- `tsx` - TypeScript executor for migrations

### 2.5 Run Database Migration

```bash
# Run migration (creates tables, functions, indexes)
npm run db:migrate

# Seed curated data (networks and locations)
npm run db:seed

# Or run both
npm run db:setup
```

Expected output:
```
🚀 Starting database migration...
📄 Running schema.sql...
✅ Migration successful!
...
🌱 Starting database seed...
📍 Seeding network: Costco Wholesale
   ✅ 3 locations
...
✅ Seed complete!
```

### 2.6 Test Local Development

```bash
# Start dev server
npm run dev
```

Visit `http://localhost:3000` and test:
- Sign in with Clerk
- Check database for user entry:
  ```bash
  vercel postgres connect cardoncue-db
  SELECT * FROM users;
  ```

### 2.7 Deploy to Production

```bash
# Deploy
npm run deploy

# Or use Vercel dashboard
vercel --prod
```

After deployment:
1. Update Clerk webhook URL to production domain
2. Test webhook delivery in Clerk dashboard

---

## Part 3: iOS App Setup

### 3.1 Install Clerk iOS SDK

1. Open Xcode project
2. Go to **File** → **Add Package Dependencies**
3. Enter URL: `https://github.com/clerk/clerk-sdk-ios`
4. Select latest version
5. Add `Clerk` to your target

### 3.2 Configure Info.plist

Add Clerk publishable key to `Info.plist`:

```xml
<key>CLERK_PUBLISHABLE_KEY</key>
<string>pk_live_YOUR_KEY_HERE</string>
```

Or use build settings to inject from environment variables.

### 3.3 Add Swift Files to Project

Add these files to your Xcode project:
1. `ios/CardOnCue/Services/ClerkAuthService.swift`
2. Update `ios/CardOnCue/Services/APIClient.swift` (already created with Clerk support)

### 3.4 Update App Entry Point

**File**: `ios/CardOnCue/CardOnCueApp.swift`

```swift
import SwiftUI
import Clerk

@main
struct CardOnCueApp: App {
    @StateObject private var clerkAuth = ClerkAuthService.shared
    @StateObject private var locationService = LocationService()

    var body: some Scene {
        WindowGroup {
            if clerkAuth.isSignedIn {
                MainTabView()
                    .environmentObject(clerkAuth)
                    .environmentObject(locationService)
            } else {
                SignInView()
                    .environmentObject(clerkAuth)
            }
        }
    }
}
```

### 3.5 Create Sign-In UI

**File**: `ios/CardOnCue/Views/SignInView.swift`

```swift
import SwiftUI
import Clerk

struct SignInView: View {
    @EnvironmentObject var clerkAuth: ClerkAuthService
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Logo
            Image(systemName: "creditcard.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            Text("CardOnCue")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Your cards, right when you need them")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            // Sign in with Apple button
            Button {
                Task {
                    do {
                        try await clerkAuth.signInWithApple()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "applelogo")
                    Text("Sign in with Apple")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal)
            .disabled(clerkAuth.isLoading)

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }

            Spacer()

            Text("By signing in, you agree to our Terms of Service and Privacy Policy")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
    }
}
```

### 3.6 Update APIClient

The `APIClient.swift` file has already been updated to use Clerk tokens. Key changes:

```swift
// Initialize with ClerkAuthService
let apiClient = APIClient(
    baseURL: "https://your-domain.vercel.app/api",
    clerkAuthService: ClerkAuthService.shared
)

// Automatically adds Clerk session token to requests
private func addClerkAuthHeader(to request: inout URLRequest) async throws {
    let token = try await clerkAuthService.getSessionToken()
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
}
```

### 3.7 Configure App Capabilities

1. In Xcode, select your target
2. Go to **Signing & Capabilities**
3. Add **Sign in with Apple** capability
4. Enable **Background Modes**:
   - Location updates
   - Background fetch
   - Remote notifications (for future features)

### 3.8 Update Info.plist for Location

Add location usage descriptions:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>CardOnCue needs your location to show the right card when you arrive at stores.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>CardOnCue monitors your location in the background to automatically suggest cards. Your location is never tracked or stored.</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>Allow CardOnCue to monitor your location for automatic card suggestions.</string>
```

---

## Part 4: Testing the Integration

### 4.1 Test Web Sign-In

1. Go to `http://localhost:3000`
2. Click **Sign In**
3. Complete sign-in with Apple or Email
4. Check Clerk Dashboard → Users (should see new user)
5. Check database:
   ```sql
   SELECT * FROM users;
   ```

### 4.2 Test iOS Sign-In

1. Build and run iOS app in simulator
2. Tap **Sign in with Apple**
3. Complete authentication flow
4. App should transition to main view
5. Check that same user appears in database

### 4.3 Test API Calls

**From Web**:
```typescript
// pages/test-api.tsx
export default function TestAPI() {
  const { userId } = useAuth();

  const testAPI = async () => {
    const response = await fetch('/api/v1/cards');
    const data = await response.json();
    console.log('Cards:', data);
  };

  return <button onClick={testAPI}>Test API</button>;
}
```

**From iOS**:
```swift
// Test in any view
Task {
    let cards = try await apiClient.getCards()
    print("Cards: \(cards.count)")
}
```

### 4.4 Test Data Sync

1. **Create card on web**:
   - Sign in to web app
   - Create a test card
   - Check database: `SELECT * FROM cards;`

2. **Retrieve card on iOS**:
   - Sign in to iOS app (same user)
   - Fetch cards via API
   - Should see the card created on web

3. **Create card on iOS**:
   - Scan or create a card on iOS
   - Post to API
   - Check web app (should appear)

### 4.5 Test Webhooks

1. Go to Clerk Dashboard → Webhooks
2. Click on your endpoint
3. Click **Send Test Event**
4. Select `user.created`
5. Check logs in Vercel
6. Check database for test user

---

## Part 5: Production Checklist

### Backend (Vercel)
- [ ] PostgreSQL database created and migrated
- [ ] All environment variables set (production)
- [ ] Clerk webhook configured with production URL
- [ ] Test webhook delivery
- [ ] Domain configured (optional)
- [ ] Deployed to production
- [ ] Test sign-in flow on production URL

### iOS App
- [ ] Clerk SDK integrated
- [ ] Info.plist configured with production Clerk key
- [ ] Sign in with Apple configured
- [ ] Capabilities enabled (Sign in with Apple, Location, Background Modes)
- [ ] API client points to production URL
- [ ] Test sign-in flow on device
- [ ] Test API calls to production backend
- [ ] Location permissions tested
- [ ] Background region monitoring tested

### Database
- [ ] Row-level security enabled
- [ ] Indexes created
- [ ] Sample data seeded
- [ ] Backup strategy configured

### Security
- [ ] HTTPS enforced
- [ ] Webhook signature verification enabled
- [ ] Session tokens expire correctly
- [ ] API requires authentication
- [ ] Rate limiting configured (optional)

---

## Part 6: Common Issues & Troubleshooting

### Issue: Webhook not receiving events

**Solution**:
1. Check webhook URL is publicly accessible
2. Verify signing secret matches in environment variables
3. Check Clerk Dashboard → Webhooks → Logs for errors
4. Test with `curl`:
   ```bash
   curl -X POST https://your-domain.vercel.app/api/webhooks/clerk \
     -H "Content-Type: application/json" \
     -d '{"type":"user.created","data":{}}'
   ```

### Issue: iOS app can't sign in

**Solution**:
1. Verify `CLERK_PUBLISHABLE_KEY` in Info.plist
2. Check Clerk Dashboard → Social Connections → Apple is enabled
3. Verify Bundle ID matches in Clerk and Xcode
4. Check Apple Developer account Sign in with Apple is enabled
5. Try cleaning build folder (Cmd+Shift+K) and rebuilding

### Issue: API calls return 401 Unauthorized

**Solution**:
1. Check session token is being sent:
   ```swift
   print("Token: \(try await clerkAuth.getSessionToken())")
   ```
2. Verify backend is using Clerk middleware correctly
3. Check token expiration (access tokens expire after 1 hour by default)
4. Try signing out and back in

### Issue: Database migration fails

**Solution**:
1. Check PostgreSQL connection string is correct
2. Verify PostGIS extension is available (Vercel Postgres includes it)
3. Run migration step by step:
   ```bash
   # Connect to database
   vercel postgres connect cardoncue-db

   # Copy/paste schema.sql commands one section at a time
   ```

### Issue: Cards not syncing between web and iOS

**Solution**:
1. Verify both apps use same Clerk user ID
2. Check API calls are hitting same endpoint
3. Verify row-level security is working:
   ```sql
   SET app.current_user_id = 'user_...';
   SELECT * FROM cards; -- Should only see your cards
   ```
4. Check CORS settings if needed

---

## Part 7: Next Steps

### Immediate
- [ ] Set up staging environment
- [ ] Configure CI/CD for automatic deployments
- [ ] Add more test coverage
- [ ] Implement subscription tiers

### Short-term
- [ ] Add Apple Wallet export
- [ ] Implement push notifications
- [ ] Add analytics (privacy-friendly)
- [ ] Create admin dashboard

### Long-term
- [ ] Android app
- [ ] Web PWA for card viewing
- [ ] Community-curated location database
- [ ] API rate limiting
- [ ] Advanced subscription features

---

## Resources

- [Clerk Documentation](https://clerk.com/docs)
- [Vercel Postgres Documentation](https://vercel.com/docs/storage/vercel-postgres)
- [Next.js Documentation](https://nextjs.org/docs)
- [PostGIS Documentation](https://postgis.net/documentation/)
- [Clerk iOS SDK](https://github.com/clerk/clerk-sdk-ios)

---

## Support

If you encounter issues:
1. Check this guide's troubleshooting section
2. Review the architecture documentation (`docs/architecture.md`)
3. Check the API specification (`docs/api-spec.yaml`)
4. Open an issue on GitHub

---

**Last Updated**: 2025-11-22
**Version**: 1.0.0
