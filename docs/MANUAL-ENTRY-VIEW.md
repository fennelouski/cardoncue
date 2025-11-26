# Manual Entry View Documentation

## Overview

The **ManualEntryView** is a full-screen modal form that allows users to manually add membership and loyalty cards to CardOnCue without scanning. This is useful when:
- The physical card is not available
- The barcode cannot be scanned properly
- Users want to enter card details from a digital source
- The camera is not accessible

## File Location

`CardOnCue/ManualEntryView.swift`

## User Flow

1. User taps "Add Manually" button from:
   - Empty state view (when no cards exist)
   - Plus menu in navigation bar (when cards exist)

2. A modal sheet appears with the manual entry form

3. User fills in the required and optional fields

4. User taps "Save Card" to save the card

5. The card is encrypted and saved to local storage (SwiftData with iCloud sync)

6. The modal dismisses and the new card appears in the card list

## UI Design

### Visual Hierarchy

The view uses a clean, scrollable form design with the following sections:

```
┌─────────────────────────────┐
│  [Cancel]         Manual     │ ← Navigation bar
├─────────────────────────────┤
│                              │
│     🎹 Keyboard Icon         │ ← Header section
│   Add Card Manually          │
│  Enter your card details     │
│                              │
├─────────────────────────────┤
│                              │
│  🏷️ Card Name               │ ← Required field
│  ┌─────────────────────────┐│
│  │ e.g., Costco Membership ││
│  └─────────────────────────┘│
│                              │
│  📊 Barcode Type            │ ← Picker field
│  ┌─────────────────────────┐│
│  │ QR Code            ▼    ││
│  └─────────────────────────┘│
│                              │
│  🔢 Barcode Number          │ ← Required field
│  ┌─────────────────────────┐│
│  │ Enter card number       ││
│  └─────────────────────────┘│
│                              │
│  📅 Has Expiry Date   [ ]   │ ← Toggle
│                              │
│  1️⃣ One-Time Use Card [ ]  │ ← Toggle
│                              │
│  🏷️ Tags (Optional)         │ ← Optional field
│  ┌─────────────────────────┐│
│  │ e.g., Grocery, Members. ││
│  └─────────────────────────┘│
│                              │
│  [Help text about tags]      │
│                              │
│  ┌─────────────────────────┐│
│  │   ✓ Save Card           ││ ← Action button
│  └─────────────────────────┘│
│                              │
└─────────────────────────────┘
```

### Color Scheme

- Background: `.appBackground` (cream/beige color)
- Primary text: `.appBlue` (navy blue)
- Secondary text: `.appLightGray` (light gray)
- Primary button: `.appPrimary` (accent color)
- Icons: `.appBlue`
- Input fields: White background with rounded corners

### Typography

- Header title: `.title2`, bold
- Header subtitle: `.subheadline`
- Section labels: `.subheadline`, medium weight
- Input text: System default
- Button text: `.headline`
- Help text: `.caption`

## Form Fields

### Required Fields

#### 1. Card Name
- **Type:** Text field
- **Validation:** Cannot be empty (trimmed)
- **Placeholder:** "e.g., Costco Membership"
- **Keyboard:** Automatically capitalizes words
- **Purpose:** Display name for the card in the list

#### 2. Barcode Number
- **Type:** Text field
- **Validation:** Cannot be empty (trimmed)
- **Placeholder:** "Enter card number or barcode"
- **Keyboard:** Numbers and punctuation
- **Auto-correction:** Disabled
- **Auto-capitalization:** Disabled
- **Purpose:** The actual barcode data that will be encoded and encrypted

### Barcode Type Selector

- **Type:** Menu picker
- **Default:** QR Code
- **Options:**
  - QR Code
  - Code 128
  - PDF417
  - Aztec
  - EAN-13
  - UPC-A
  - Code 39
  - ITF
- **Purpose:** Determines how the barcode will be generated when displayed

### Optional Fields

#### 3. Has Expiry Date
- **Type:** Toggle switch
- **Default:** Off
- **When enabled:** Shows a date picker for expiry date
- **Date picker:**
  - Minimum: Today
  - Maximum: None
  - Style: Compact
- **Purpose:** Track when the card expires for notifications and warnings

#### 4. One-Time Use Card
- **Type:** Toggle switch
- **Default:** Off
- **Purpose:** Mark cards that can only be used once (e.g., gift cards, vouchers)

#### 5. Tags
- **Type:** Text field
- **Format:** Comma-separated values
- **Placeholder:** "e.g., Grocery, Membership"
- **Keyboard:** Automatically capitalizes words
- **Purpose:** Categorize and organize cards
- **Help text:** "Tags help organize your cards. Separate multiple tags with commas."

## Validation

The "Save Card" button is only enabled when:
1. Card name is not empty (after trimming whitespace)
2. Barcode number is not empty (after trimming whitespace)

The button appears grayed out (`.appLightGray`) when disabled and uses the primary color (`.appPrimary`) when enabled.

## Data Processing

### Save Flow

When the user taps "Save Card":

1. **Loading State:** Button shows a loading spinner

2. **Encryption Key:**
   - Retrieves master encryption key from Keychain
   - If no key exists, generates a new 256-bit AES key
   - Stores the key securely in Keychain

3. **Tag Parsing:**
   - Splits tags by comma
   - Trims whitespace from each tag
   - Filters out empty tags

4. **Card Creation:**
   - Creates a `CardModel` using `createWithEncryptedPayload()`
   - Encrypts the barcode number using AES-GCM encryption
   - Sets user ID (currently "local", will use actual user ID when auth is implemented)
   - Includes all optional fields if provided

5. **Storage:**
   - Inserts card into SwiftData model context
   - Saves the context (triggers iCloud sync if enabled)

6. **Completion:**
   - Dismisses the modal
   - New card appears in the card list

### Error Handling

If any error occurs during the save process:
- Loading spinner stops
- Alert dialog appears with error message
- User can tap "OK" to dismiss the alert
- Modal remains open so user can retry

## Security

### Encryption

The barcode payload is encrypted using:
- **Algorithm:** AES-256-GCM
- **Key:** 256-bit symmetric key stored in Keychain
- **Key Storage:** iOS Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- **Data Protection:** Device-only (does not leave the device unencrypted)

### Encrypted Data Structure

The `payloadEncrypted` field contains:
1. Nonce (12 bytes)
2. Ciphertext (variable length)
3. Authentication tag (16 bytes)

This ensures:
- Confidentiality (data is encrypted)
- Integrity (tampering is detected)
- Authenticity (data comes from the legitimate source)

## Accessibility

- All form fields have proper labels
- Semantic icons help identify field types
- Toggle switches clearly indicate on/off states
- Help text provides additional context
- Color contrast meets WCAG guidelines

## Future Enhancements

Possible improvements for future versions:

1. **Barcode Preview:** Show a preview of the generated barcode
2. **Import from Clipboard:** Detect and auto-fill card numbers from clipboard
3. **Card Templates:** Pre-fill common card types (Costco, Starbucks, etc.)
4. **Photo Upload:** Allow users to upload a photo of their card
5. **OCR Integration:** Automatically extract card details from photos
6. **Duplicate Detection:** Warn users if a similar card already exists
7. **Custom Fields:** Allow users to add custom metadata fields
8. **Color Picker:** Let users choose a custom color for each card
9. **Card Logo:** Option to add a logo/icon for the card brand

## Technical Notes

### Dependencies

- SwiftUI for UI framework
- SwiftData for local storage with iCloud sync
- CryptoKit for AES-GCM encryption
- KeychainService for secure key storage

### Model Integration

The view integrates with:
- `CardModel`: Main data model for cards
- `BarcodeType`: Enum defining supported barcode types
- `KeychainService`: Secure storage for encryption keys

### State Management

- Uses `@State` for form field values
- Uses `@Environment(\.dismiss)` for modal dismissal
- Uses `@Environment(\.modelContext)` for SwiftData operations

## Testing Checklist

When testing the manual entry view:

- [ ] Form appears when "Add Manually" is tapped
- [ ] All required fields prevent saving when empty
- [ ] Barcode type picker shows all options
- [ ] Expiry date toggle shows/hides date picker
- [ ] Date picker only allows future dates
- [ ] Tags are properly parsed (comma-separated)
- [ ] Save button shows loading state
- [ ] Card is successfully created and appears in list
- [ ] Modal dismisses after successful save
- [ ] Error alert appears if save fails
- [ ] Cancel button dismisses modal without saving
- [ ] Keyboard appears/dismisses appropriately
- [ ] Scrolling works when keyboard is visible
- [ ] All fields retain values if save fails

## Code Location Reference

- View: `CardOnCue/ManualEntryView.swift`
- Triggered from: `CardOnCue/CardListView.swift` (lines 57-59)
- Triggered from: `CardOnCue/EmptyStateView.swift` (line 110)
- Model: `CardOnCue/CardModel.swift`
- Barcode types: `CardOnCue/BarcodeType.swift`
- Encryption: `CardOnCue/KeychainService.swift`
