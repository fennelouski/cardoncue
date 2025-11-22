# CardOnCue Website

A modern, responsive marketing website and user portal for CardOnCue, built with Next.js and deployed on Vercel.

## Tech Stack

- **Framework**: Next.js 14+ with App Router
- **Runtime**: Node.js 18+
- **Platform**: Vercel Serverless Functions
- **Styling**: TailwindCSS with custom design system
- **Animation**: Framer Motion
- **Authentication**: Clerk
- **Database**: Vercel KV (production) / In-memory (dev)
- **Deployment**: Vercel

## Project Structure

```
web/
├── app/
│   ├── api/                 # API routes
│   │   ├── search/          # Location/business search
│   │   ├── contact/         # Contact form handling
│   │   ├── android-request/ # Android waitlist
│   │   └── user/            # Protected user endpoints
│   ├── components/          # Reusable UI components
│   ├── styles/              # Global styles
│   ├── account/             # User dashboard pages
│   ├── features/            # Features page
│   ├── search/              # Location search page
│   ├── support/             # Support & FAQ
│   ├── contact/             # Contact page
│   ├── android/             # Android waitlist
│   ├── privacy/             # Privacy policy
│   ├── terms/               # Terms of use
│   ├── layout.tsx           # Root layout
│   └── page.tsx             # Homepage
├── public/                  # Static assets
├── tailwind.config.js       # Tailwind configuration
├── next.config.js          # Next.js configuration
├── tsconfig.json           # TypeScript configuration
├── package.json
├── vercel.json             # Vercel configuration
└── README.md
```

## Getting Started

### Prerequisites

- Node.js 18+ installed
- Vercel CLI installed (optional): `npm install -g vercel`

### Installation

```bash
# Navigate to web directory
cd web

# Install dependencies
npm install

# Start development server
npm run dev
```

The development server will start on `http://localhost:3000`.

## Environment Variables

Create a `.env.local` file in the `web/` directory:

```env
# Clerk Authentication (get from https://clerk.com)
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_...
CLERK_SECRET_KEY=sk_test_...

# Node environment
NODE_ENV=development

# Optional: Vercel KV for production data storage
# KV_URL=redis://...
# KV_REST_API_URL=https://...
# KV_REST_API_TOKEN=...
```

### Setting up Clerk

1. Create a Clerk application at [clerk.com](https://clerk.com)
2. Copy your publishable key and secret key
3. Add them to your environment variables
4. Configure your Clerk application settings for your domain

### Production Environment Variables

For production deployment on Vercel:

```bash
# Set Clerk keys
vercel env add NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY production
vercel env add CLERK_SECRET_KEY production

# Optional: Set up Vercel KV for persistent storage
vercel kv:add
```

## API Endpoints

### Public Endpoints

#### Search Locations
```http
GET /api/search?query=costco
```

**Response**:
```json
{
  "results": [
    {
      "id": "1",
      "name": "Costco Wholesale",
      "type": "grocery",
      "city": "San Francisco",
      "state": "CA",
      "supported": true
    }
  ],
  "total": 1,
  "query": "costco"
}
```

#### Contact Form
```http
POST /api/contact
Content-Type: application/json

{
  "name": "John Doe",
  "email": "john@example.com",
  "message": "Help with my cards"
}
```

#### Android Request
```http
POST /api/android-request
Content-Type: application/json

{
  "name": "John Doe",
  "email": "john@example.com",
  "message": "Excited for Android version!"
}
```

### Protected Endpoints (Require Clerk Authentication)

#### User Cards
```http
GET /api/user/cards
POST /api/user/cards
```

#### User Subscription
```http
GET /api/user/subscription
```

## Development Commands

```bash
# Development server
npm run dev

# Build for production
npm run build

# Start production server
npm run start

# Type checking
npm run type-check

# Linting
npm run lint
```

## Testing API Endpoints

### Test Search API
```bash
curl "http://localhost:3000/api/search?query=costco"
```

### Test Contact Form
```bash
curl -X POST http://localhost:3000/api/contact \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "email": "test@example.com",
    "message": "Test message"
  }'
```

### Test Android Request
```bash
curl -X POST http://localhost:3000/api/android-request \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test User",
    "email": "test@example.com",
    "message": "Want Android version!"
  }'
```

## Deployment

### Deploy to Vercel

```bash
# Login to Vercel
vercel login

# Link to existing project or create new one
vercel link

# Deploy to production
npm run deploy
```

### Vercel Configuration

The `vercel.json` file configures:
- Build settings for Next.js
- API route handling
- Static asset optimization

### Custom Domain (Optional)

```bash
# Add custom domain
vercel domains add cardoncue.com

# Set up DNS records as instructed by Vercel
```

## Pages Overview

### Public Pages
- `/` - Homepage with product overview
- `/features` - Detailed feature explanations
- `/search` - Location/business search
- `/support` - FAQ and support resources
- `/contact` - Contact form
- `/android` - Android version request
- `/privacy` - Privacy policy
- `/terms` - Terms of use

### Authenticated Pages (Require Clerk)
- `/account` - User dashboard
- `/account/cards` - Card management
- `/account/subscriptions` - Billing management
- `/account/settings` - Account settings

## Security Features

- **Authentication**: Clerk handles secure user authentication
- **Data Encryption**: Card data is end-to-end encrypted
- **Location Privacy**: Location data processed locally on device
- **HTTPS**: Enforced on all production deployments
- **Input Validation**: Client and server-side validation
- **Rate Limiting**: Built into Vercel platform

## Performance Optimization

- **Next.js App Router**: Optimized routing and loading
- **Static Generation**: Marketing pages pre-rendered
- **Image Optimization**: Built-in Next.js image optimization
- **Code Splitting**: Automatic code splitting for faster loads
- **Caching**: Intelligent caching strategies

## Contributing

1. Follow the existing code style and structure
2. Add TypeScript types for new components
3. Test API endpoints with the provided curl commands
4. Ensure responsive design on mobile and desktop
5. Update this README for any new features

## Troubleshooting

### Build Issues
- Ensure Node.js 18+ is installed
- Clear `.next` cache: `rm -rf .next`
- Reinstall dependencies: `rm -rf node_modules && npm install`

### Clerk Issues
- Verify environment variables are set correctly
- Check Clerk dashboard for application settings
- Ensure domain is configured in Clerk

### API Issues
- Check Vercel function logs in dashboard
- Verify environment variables in production
- Test locally with `npm run dev`

## License

MIT
