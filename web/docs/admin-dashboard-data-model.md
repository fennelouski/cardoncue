# Admin Dashboard Data Model

## Entity Relationship Diagram

```
┌─────────────────┐
│     BRANDS      │
├─────────────────┤
│ id (PK)         │
│ name            │
│ display_name    │
│ description     │
│ logo_url        │
│ website         │
│ primary_email   │
│ primary_phone   │
│ category        │
│ verified        │
│ created_at      │
│ updated_at      │
└────────┬────────┘
         │
         │ 1:N
         │
         ▼
┌─────────────────┐          ┌──────────────────────┐
│   LOCATIONS     │◄─────────│ TEMPLATE_LOCATIONS   │
├─────────────────┤   N:M    ├──────────────────────┤
│ id (PK)         │          │ id (PK)              │
│ brand_id (FK)   │          │ template_id (FK)     │
│ name            │          │ location_id (FK)     │
│ address         │          │ priority             │
│ city            │          │ created_at           │
│ state           │          └──────────┬───────────┘
│ zip_code        │                     │
│ country         │                     │ N:M
│ latitude        │                     │
│ longitude       │                     ▼
│ phone           │          ┌─────────────────────┐
│ email           │          │   CARD_TEMPLATES    │
│ website         │          ├─────────────────────┤
│ regular_hours   │──────────│ id (PK)             │
│ special_hours   │    1:N   │ brand_id (FK)       │
│ timezone        │          │ default_location_id │
│ place_id        │          │ image_hash          │
│ verified        │          │ text_signature      │
│ notes           │          │ card_name           │
│ created_at      │          │ card_type           │
│ updated_at      │          │ location_name       │
└─────────────────┘          │ location_address    │
                             │ location_lat        │
                             │ location_lng        │
                             │ confidence_score    │
                             │ usage_count         │
                             │ verified            │
                             │ notes               │
                             │ created_by          │
                             │ created_at          │
                             │ updated_at          │
                             └─────────────────────┘
```

## Relationships

### Brands → Locations (1:N)
- One brand can have many locations (e.g., Starbucks has thousands of stores)
- Each location belongs to exactly one brand
- Cascade delete: Deleting a brand deletes all its locations

### Brands → Card Templates (1:N)
- One brand can have multiple card template designs
- Example: Louisville Library might have old design and new design
- Set NULL on delete: Deleting a brand doesn't delete templates

### Card Templates ↔ Locations (N:M via template_locations)
- One template can suggest multiple locations
- One location can be associated with multiple templates
- Priority field determines order shown to users
- Example: "Louisville Public Library" template shows Main Branch (priority 1), Eastern Branch (priority 2)

### Locations → Card Templates (1:N via default_location_id)
- Optional: A template can have one default/primary location
- Example: "Main Branch Member Card" always defaults to Main Branch location

## Hours Data Structure

### Regular Hours (JSONB)
```json
{
  "monday": { "open": "09:00", "close": "17:00" },
  "tuesday": { "open": "09:00", "close": "17:00" },
  "wednesday": { "open": "09:00", "close": "17:00" },
  "thursday": { "open": "09:00", "close": "20:00" },
  "friday": { "open": "09:00", "close": "17:00" },
  "saturday": { "open": "10:00", "close": "14:00" },
  "sunday": null
}
```

### Special Hours (JSONB Array)
```json
[
  {
    "date": "2024-12-25",
    "status": "closed",
    "note": "Christmas Day"
  },
  {
    "date": "2024-11-24",
    "status": "modified",
    "open": "09:00",
    "close": "14:00",
    "note": "Thanksgiving Eve - Early Close"
  },
  {
    "date": "2024-07-04",
    "status": "closed",
    "note": "Independence Day"
  }
]
```

## Data Flow Examples

### Example 1: User Scans Louisville Library Card

1. **Card Scan**
   - Image hash computed: `A3F8C9D2...`
   - Text signature: `louisvillefree...`

2. **Template Match**
   - Finds template: "Louisville Free Public Library"
   - Template has `brand_id` → "Louisville Free Public Library" brand

3. **Location Lookup**
   - Query `template_locations` for this template
   - Returns 3 locations ordered by priority:
     1. Main Branch (301 York St)
     2. Crescent Hill Branch
     3. Highlands-Shelby Park Branch

4. **Data Pre-fill**
   - Card name: "Louisville Free Public Library"
   - Locations: All 3 with addresses, phones, websites
   - Hours: From location's `regular_hours` and `special_hours`

### Example 2: Admin Creates New Brand

1. **Create Brand**
   ```sql
   INSERT INTO brands (name, display_name, category, website, primary_phone)
   VALUES (
     'Kroger',
     'Kroger',
     'retail',
     'https://www.kroger.com',
     '1-800-KROGERS'
   );
   ```

2. **Add Locations**
   ```sql
   INSERT INTO locations (brand_id, name, address, ...)
   VALUES
     (brand_id, 'Kroger - Middletown', '12905 Shelbyville Rd', ...),
     (brand_id, 'Kroger - Highlands', '2440 Bardstown Rd', ...);
   ```

3. **Associate Templates**
   ```sql
   UPDATE card_templates
   SET brand_id = brand_id
   WHERE card_name ILIKE '%kroger%';

   INSERT INTO template_locations (template_id, location_id, priority)
   SELECT ct.id, l.id, 1
   FROM card_templates ct, locations l
   WHERE ct.brand_id = l.brand_id;
   ```

### Example 3: Admin Updates Hours for Holiday

1. **Edit Location**
   - Admin goes to "Main Library" location
   - Clicks "Hours" → "Add Special Date"

2. **Add Special Hours**
   ```json
   {
     "date": "2024-12-24",
     "status": "modified",
     "open": "09:00",
     "close": "13:00",
     "note": "Christmas Eve - Early Close"
   }
   ```

3. **User Impact**
   - Next time user views this card in app
   - Shows: "Open today 9 AM - 1 PM (Early close for Christmas Eve)"

## Query Patterns

### Get all templates with brand and location data
```sql
SELECT
  ct.*,
  b.name as brand_name,
  b.display_name,
  b.logo_url,
  json_agg(
    json_build_object(
      'id', l.id,
      'name', l.name,
      'address', l.address,
      'phone', l.phone,
      'priority', tl.priority
    ) ORDER BY tl.priority
  ) as locations
FROM card_templates ct
LEFT JOIN brands b ON ct.brand_id = b.id
LEFT JOIN template_locations tl ON ct.id = tl.template_id
LEFT JOIN locations l ON tl.location_id = l.id
GROUP BY ct.id, b.id;
```

### Get locations near user with hours
```sql
SELECT
  l.*,
  b.name as brand_name,
  calculate_distance(l.latitude, l.longitude, $user_lat, $user_lng) as distance,
  get_current_hours(l.regular_hours, l.special_hours, l.timezone, NOW()) as hours_today
FROM locations l
JOIN brands b ON l.brand_id = b.id
WHERE calculate_distance(l.latitude, l.longitude, $user_lat, $user_lng) < 10000
ORDER BY distance;
```

### Find templates needing verification
```sql
SELECT
  ct.*,
  ct.usage_count,
  COALESCE(b.name, 'No Brand') as brand_name,
  COUNT(tl.location_id) as location_count
FROM card_templates ct
LEFT JOIN brands b ON ct.brand_id = b.id
LEFT JOIN template_locations tl ON ct.id = tl.template_id
WHERE ct.verified = FALSE
GROUP BY ct.id, b.name
ORDER BY ct.usage_count DESC;
```

## Migration Strategy

### Phase 1: Add New Tables
1. Create `brands` table
2. Create `locations` table
3. Create `template_locations` table
4. Add new columns to `card_templates`

### Phase 2: Migrate Data
1. Extract unique card names → Create brands
2. Migrate location data from templates → Create locations
3. Link templates to brands (by name matching)
4. Create template-location associations

### Phase 3: Gradual Transition
1. Keep old location fields for backward compatibility
2. New scans use brand/location data
3. Old scans still work with legacy fields
4. Eventually deprecate old fields

## Indexing Strategy

### High-Performance Indexes
```sql
-- Brands
CREATE INDEX idx_brands_name ON brands(name);
CREATE INDEX idx_brands_category ON brands(category);
CREATE INDEX idx_brands_verified ON brands(verified) WHERE verified = TRUE;

-- Locations
CREATE INDEX idx_locations_brand_id ON locations(brand_id);
CREATE INDEX idx_locations_coordinates ON locations USING gist(ll_to_earth(latitude, longitude));
CREATE INDEX idx_locations_city_state ON locations(city, state);
CREATE INDEX idx_locations_verified ON locations(verified) WHERE verified = TRUE;

-- Template-Locations
CREATE INDEX idx_template_locations_template ON template_locations(template_id);
CREATE INDEX idx_template_locations_location ON template_locations(location_id);
CREATE INDEX idx_template_locations_priority ON template_locations(priority);

-- Card Templates
CREATE INDEX idx_card_templates_brand ON card_templates(brand_id);
CREATE INDEX idx_card_templates_verified ON card_templates(verified) WHERE verified = FALSE;
```

## Data Validation Rules

### Brands
- `name`: Unique, trimmed, max 100 chars
- `display_name`: Required, max 100 chars
- `website`: Valid URL or NULL
- `primary_email`: Valid email or NULL
- `category`: Enum-like values (library, retail, restaurant, etc.)

### Locations
- `name`: Required, max 200 chars
- `address`: Required
- `latitude/longitude`: Valid coordinates within range
- `phone`: E.164 format validation
- `email`: Valid email or NULL
- `regular_hours`: Valid JSON structure with time format HH:MM
- `special_hours`: Valid JSON array with date format YYYY-MM-DD
- `timezone`: Valid IANA timezone identifier

### Template-Locations
- `priority`: Integer >= 0 (lower = higher priority)
- Unique constraint on (template_id, location_id)
