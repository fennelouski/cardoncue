# Admin Dashboard Design Document

## Overview
A comprehensive admin dashboard for managing card templates, locations, and metadata to make the CardOnCue app feel intelligent through data curation.

## Access Control
- **Authorized Users**: Only users with `@100apps.studio` email domain
- **Authentication**: Clerk-based, check email domain on server-side
- **Route Protection**: Dashboard routes hidden and protected from unauthorized access

## Data Architecture

### Core Entities

#### 1. Brands/Companies Table (NEW)
```sql
CREATE TABLE brands (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  display_name TEXT NOT NULL,
  description TEXT,
  logo_url TEXT,
  website TEXT,
  primary_email TEXT,
  primary_phone TEXT,
  category TEXT, -- e.g., "library", "retail", "restaurant", "theme_park"
  verified BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_brands_name ON brands(name);
CREATE INDEX idx_brands_category ON brands(category);
```

**Purpose**: Central registry of all brands/companies that issue cards

#### 2. Locations Table (NEW)
```sql
CREATE TABLE locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  brand_id UUID REFERENCES brands(id) ON DELETE CASCADE,

  -- Basic Info
  name TEXT NOT NULL,
  address TEXT NOT NULL,
  city TEXT,
  state TEXT,
  zip_code TEXT,
  country TEXT DEFAULT 'US',

  -- Coordinates
  latitude DECIMAL(10, 8) NOT NULL,
  longitude DECIMAL(11, 8) NOT NULL,

  -- Contact Info
  phone TEXT,
  email TEXT,
  website TEXT,

  -- Hours (stored as JSON for flexibility)
  regular_hours JSONB, -- {monday: {open: "09:00", close: "17:00"}, ...}
  special_hours JSONB, -- [{date: "2024-12-25", status: "closed"}, ...]
  timezone TEXT DEFAULT 'America/New_York',

  -- Metadata
  place_id TEXT, -- Google Maps Place ID for integration
  verified BOOLEAN DEFAULT FALSE,
  notes TEXT, -- Admin notes

  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_locations_brand_id ON locations(brand_id);
CREATE INDEX idx_locations_coordinates ON locations(latitude, longitude);
CREATE INDEX idx_locations_city ON locations(city);
```

**Purpose**: Detailed location data with rich metadata

#### 3. Updated Card Templates Table
```sql
ALTER TABLE card_templates
  ADD COLUMN brand_id UUID REFERENCES brands(id) ON DELETE SET NULL,
  ADD COLUMN default_location_id UUID REFERENCES locations(id) ON DELETE SET NULL,
  ADD COLUMN notes TEXT;

-- Keep existing location fields for backward compatibility during migration
```

**Purpose**: Link templates to brands and optionally a default location

#### 4. Template-Location Associations (NEW)
```sql
CREATE TABLE template_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id UUID REFERENCES card_templates(id) ON DELETE CASCADE,
  location_id UUID REFERENCES locations(id) ON DELETE CASCADE,
  priority INT DEFAULT 0, -- Higher priority shown first
  created_at TIMESTAMP DEFAULT NOW(),

  UNIQUE(template_id, location_id)
);

CREATE INDEX idx_template_locations_template ON template_locations(template_id);
CREATE INDEX idx_template_locations_location ON template_locations(location_id);
```

**Purpose**: Many-to-many relationship between templates and locations

## Dashboard Features

### 1. Dashboard Home
- **Metrics Overview**
  - Total brands
  - Total locations
  - Total card templates
  - Recent submissions (unverified templates)
  - Popular templates (by usage_count)

- **Quick Actions**
  - Add new brand
  - Add new location
  - Review pending templates

### 2. Brands Management
**List View:**
- Search by name
- Filter by category, verification status
- Sort by name, created date, number of templates
- Columns: Name, Category, Locations Count, Templates Count, Verified

**Detail View:**
- Edit brand information
- Logo upload
- Contact information management
- Associated locations list
- Associated templates list
- Verification toggle

**Create/Edit Form:**
```typescript
interface BrandForm {
  name: string;
  displayName: string;
  description?: string;
  logoUrl?: string;
  website?: string;
  primaryEmail?: string;
  primaryPhone?: string;
  category?: string;
  verified: boolean;
}
```

### 3. Locations Management
**List View:**
- Search by name, address, city
- Filter by brand, verification status, has phone/email/website
- Map view showing all locations
- Columns: Name, Brand, Address, Phone, Email, Verified

**Detail View:**
- Edit all location fields
- Map preview with pin
- Hours editor (visual weekly calendar + special dates)
- Associated templates
- Verification toggle
- Admin notes

**Hours Editor:**
```typescript
interface RegularHours {
  monday: { open: string; close: string } | null;
  tuesday: { open: string; close: string } | null;
  // ... other days
}

interface SpecialHour {
  date: string; // YYYY-MM-DD
  status: 'closed' | 'modified';
  open?: string;
  close?: string;
  note?: string;
}
```

**Create/Edit Form:**
- Address autocomplete with Google Maps API
- Automatic coordinate lookup
- Timezone auto-detection based on location
- Phone number formatting
- Email validation
- URL validation

### 4. Card Templates Management
**List View:**
- Search by card name, brand
- Filter by verification status, confidence score, usage count
- Sort by usage count, created date, confidence
- Columns: Card Name, Brand, Image Hash, Locations, Usage Count, Confidence, Verified

**Detail View:**
- Template metadata
- Image hash visualization (if possible)
- Text signature
- Associated brand (editable)
- Associated locations (add/remove)
- Usage statistics
- Verification toggle
- Merge templates feature (for duplicates)

**Location Assignment:**
- Search and select from existing locations
- Create new location on the fly
- Set priority for each location
- Preview how users will see location suggestions

### 5. Review Queue
**Purpose**: Review user-submitted templates that need verification

**Features:**
- List of unverified templates
- Side-by-side comparison of similar templates (by image/text hash)
- Quick approve/reject actions
- Bulk operations
- Auto-suggest brand/location matches
- Duplicate detection

### 6. Analytics & Reports
**Metrics:**
- Template usage trends
- Popular brands/locations
- Scan success rates (if tracked)
- Geographic distribution of templates
- User contribution statistics

**Reports:**
- Missing data report (templates without brands, locations without hours, etc.)
- Verification backlog
- Duplicate candidates

## Technical Implementation

### Frontend (Next.js + React)

#### Route Structure
```
/admin
  /dashboard         - Home/metrics
  /brands
    /                - List all brands
    /[id]            - Brand detail
    /new             - Create brand
  /locations
    /                - List all locations
    /[id]            - Location detail
    /new             - Create location
  /templates
    /                - List all templates
    /[id]            - Template detail
    /review          - Review queue
  /analytics         - Analytics dashboard
```

#### Component Architecture
```typescript
// Shared Components
- DataTable (with search, filter, sort, pagination)
- SearchInput (with debounce)
- MapView (Google Maps integration)
- HoursEditor (visual calendar editor)
- ConfirmDialog
- LoadingStates

// Brand Components
- BrandList
- BrandDetail
- BrandForm
- BrandCard

// Location Components
- LocationList
- LocationDetail
- LocationForm
- LocationMap
- HoursEditor

// Template Components
- TemplateList
- TemplateDetail
- TemplateLocationManager
- TemplateReviewCard
```

#### State Management
- React Query for server state
- Zustand for client state (filters, selections)
- Form state with React Hook Form + Zod validation

### Backend (Next.js API Routes)

#### API Structure
```
/api/v1/admin
  /brands
    GET /              - List brands
    POST /             - Create brand
    GET /[id]          - Get brand details
    PATCH /[id]        - Update brand
    DELETE /[id]       - Delete brand

  /locations
    GET /              - List locations
    POST /             - Create location
    GET /[id]          - Get location details
    PATCH /[id]        - Update location
    DELETE /[id]       - Delete location
    GET /[id]/templates - Get templates for location

  /card-templates
    GET /              - List templates (enhanced with brand/location data)
    GET /[id]          - Get template details
    PATCH /[id]        - Update template (already exists)
    DELETE /[id]       - Delete template (already exists)
    POST /[id]/locations - Associate locations
    DELETE /[id]/locations/[locationId] - Remove location
    POST /[id]/verify  - Verify template

  /template-locations
    POST /             - Create association
    DELETE /[id]       - Remove association
    PATCH /[id]        - Update priority

  /analytics
    GET /metrics       - Get dashboard metrics
    GET /reports/missing-data - Missing data report
```

#### Middleware
```typescript
// adminAuth.ts
export async function requireAdminAuth(req: NextRequest) {
  const { userId } = await auth();

  if (!userId) {
    throw new Error('Unauthorized');
  }

  // Get user from Clerk
  const user = await clerkClient.users.getUser(userId);
  const email = user.emailAddresses[0]?.emailAddress;

  if (!email?.endsWith('@100apps.studio')) {
    throw new Error('Forbidden: Admin access required');
  }

  return { userId, email };
}
```

### Database Migrations

#### Migration 014: Create Brands Table
```sql
-- Create brands table
-- Associate templates with brands
-- Add indexes
```

#### Migration 015: Create Locations Table
```sql
-- Create locations table
-- Create template_locations association
-- Add indexes
```

#### Migration 016: Data Migration
```sql
-- Migrate existing location data from card_templates to locations
-- Create brands from unique card names
-- Associate templates with brands
```

## User Experience Flow

### Admin discovers duplicate templates:
1. Go to Templates → Review Queue
2. See similar templates grouped together
3. Click "Merge" → Select primary template
4. System combines usage counts, verifies primary
5. Redirects future scans to merged template

### Admin adds rich location data:
1. Go to Locations → Find location
2. Click "Edit" → Hours tab
3. Set regular hours (9 AM - 5 PM Mon-Fri)
4. Add special hours (Closed Dec 25, Early close Nov 24 at 2 PM)
5. Save → Users see accurate hours in app

### Admin creates new brand:
1. Go to Brands → "New Brand"
2. Enter: "Louisville Free Public Library"
3. Add logo, website, main phone
4. Create default location (Main Branch)
5. Associate existing templates with brand
6. Verify → Future scans auto-populate this data

## Acceptance Criteria

### Phase 1: Foundation (MVP)
- [ ] Admin auth middleware checks `@100apps.studio` domain
- [ ] Dashboard route only visible to authorized admins
- [ ] Database migrations for brands, locations, template_locations
- [ ] Basic CRUD for brands
- [ ] Basic CRUD for locations
- [ ] Link templates to brands
- [ ] View metrics on dashboard home

### Phase 2: Rich Editing
- [ ] Hours editor with visual weekly calendar
- [ ] Special hours/dates management
- [ ] Map integration for location editing
- [ ] Address autocomplete
- [ ] Logo upload for brands
- [ ] Template-location associations UI

### Phase 3: Review & Quality
- [ ] Review queue for unverified templates
- [ ] Duplicate detection and merging
- [ ] Bulk operations (verify, delete, merge)
- [ ] Missing data reports
- [ ] Verification workflow

### Phase 4: Analytics & Polish
- [ ] Analytics dashboard
- [ ] Usage trends charts
- [ ] Geographic distribution map
- [ ] Search and filtering improvements
- [ ] Performance optimizations

## Data Validation Rules

### Brands
- Name: Required, max 100 chars
- Display name: Required, max 100 chars
- Website: Valid URL format
- Email: Valid email format
- Phone: Valid phone number format (E.164)

### Locations
- Name: Required, max 200 chars
- Address: Required
- Latitude: -90 to 90
- Longitude: -180 to 180
- Phone: Valid phone format
- Email: Valid email format
- Website: Valid URL format
- Regular hours: Valid time format (HH:MM)
- Timezone: Valid IANA timezone

### Card Templates
- All existing validations
- Brand ID: Must reference existing brand (if set)
- Default location ID: Must reference existing location (if set)

## Security Considerations

1. **Email Domain Verification**
   - Check on every admin API request
   - Don't trust client-side checks
   - Cache email verification for session

2. **Rate Limiting**
   - Limit admin API calls to prevent abuse
   - Separate limits for read vs write operations

3. **Audit Logging**
   - Log all admin actions (create, update, delete)
   - Store: admin email, action, entity type, entity ID, timestamp
   - Searchable audit trail

4. **Data Validation**
   - Server-side validation for all inputs
   - Sanitize HTML in notes/description fields
   - Validate coordinates before saving

## Future Enhancements

1. **AI-Assisted Data Entry**
   - Auto-suggest brand from card name
   - Auto-fill location data from Google Maps
   - Detect duplicates using ML

2. **User Feedback Loop**
   - Allow users to report incorrect data
   - Admin review of user reports
   - Crowdsourced verification

3. **Bulk Import**
   - CSV import for locations
   - API integration with brand databases
   - Automated data syncing

4. **Advanced Analytics**
   - Prediction models for template quality
   - Geographic heat maps
   - User engagement metrics

## Questions to Resolve

1. **Brand vs Card Template Relationship**
   - Should one brand have multiple card designs? (Yes - e.g., library cards updated over years)
   - How do we handle regional card variations? (design_variant field)

2. **Location Hierarchy**
   - Do we need parent-child locations? (e.g., Starbucks Corporate → Individual stores)
   - For now: Flat structure with brand association

3. **Hours Edge Cases**
   - 24-hour locations?
   - Overnight hours (11 PM - 2 AM)?
   - Solution: Use time format that supports crossing midnight

4. **Multi-tenant Considerations**
   - Will other organizations need admin access?
   - For now: Single tenant (@100apps.studio only)

## Success Metrics

1. **Data Quality**
   - % of templates with verified brand
   - % of templates with location data
   - % of locations with complete hours
   - Average confidence score increase

2. **Admin Efficiency**
   - Time to verify template
   - Number of templates merged per week
   - Data completeness trend

3. **User Impact**
   - Scan success rate improvement
   - Auto-fill accuracy
   - User-reported data issues (decrease)

## Timeline Estimate

- Phase 1 (Foundation): 2-3 days
- Phase 2 (Rich Editing): 2-3 days
- Phase 3 (Review & Quality): 2 days
- Phase 4 (Analytics): 1-2 days

**Total**: 7-10 days for full implementation
