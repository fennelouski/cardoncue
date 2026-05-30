# iOS Snapshot Testing Setup Guide

## Overview
I've created comprehensive snapshot tests for your iOS app, but we need to add the `swift-snapshot-testing` package dependency first.

## Files Created
- ✅ `CardOnCueUITests/SnapshotTests.swift` - Complete snapshot test suite
- ✅ This setup guide

## Step 1: Add swift-snapshot-testing Package

In Xcode (which should already be open):

1. Click on the **CardOnCue** project in the Project Navigator (the blue icon at the top)
2. In the main editor, you'll see the project settings
3. Click on the **Package Dependencies** tab (at the top, next to "Info", "Build Settings", etc.)
4. Click the **"+" button** at the bottom left
5. In the search field at the top right, paste: `https://github.com/pointfreeco/swift-snapshot-testing`
6. Click **"Add Package"**
7. When asked which target to add it to, select **"CardOnCueUITests"** (make sure it's checked)
8. Click **"Add Package"** again

The package will download and be added to your project.

## Step 2: Build the Project

After adding the package:
```bash
cd "/Users/nathanfennel/Library/Mobile Documents/com~apple~CloudDocs/Xcode Projects/CardOnCue"
xcodebuild build -scheme CardOnCue -destination 'platform=iOS Simulator,id=72C3870A-8AF8-4838-83AE-A2DBA6F9BC00'
```

## Step 3: Generate Golden Images (First Run)

The first time you run snapshot tests, they'll generate the "golden images" that future tests will compare against.

To record snapshots:
1. Open `CardOnCueUITests/SnapshotTests.swift`
2. Uncomment the line in `setUp()`:
   ```swift
   isRecording = true  // Change to true for first run
   ```
3. Run the tests:
   ```bash
   xcodebuild test -scheme CardOnCue \
     -destination 'platform=iOS Simulator,id=72C3870A-8AF8-4838-83AE-A2DBA6F9BC00' \
     -only-testing:CardOnCueUITests/SnapshotTests
   ```

## Step 4: View the Snapshots

After running the tests, golden images will be saved in:
```
CardOnCueUITests/__Snapshots__/SnapshotTests/
```

You can open this folder with:
```bash
open "CardOnCueUITests/__Snapshots__"
```

## Step 5: Run Comparison Tests

After generating golden images:
1. Set `isRecording = false` in `SnapshotTests.swift`
2. Run the tests again - they'll now compare against the golden images
3. Any UI changes will cause test failures with diff images showing what changed

## What's Tested

The snapshot tests cover:

### Screens:
- Card List View (empty and with cards)
- Onboarding View
- Location Permission View
- Notification Education View
- Manual Entry View
- Empty State View

### Device Sizes:
- iPhone 13 Pro (default)
- iPhone SE (small)
- iPad Pro 12.9" (large)

### Themes:
- Light mode
- Dark mode

## Maintaining Snapshots

When you intentionally change UI:
1. Set `isRecording = true` to update golden images
2. Run tests to regenerate snapshots
3. Review the new images
4. Set `isRecording = false` and commit the new snapshots to git
5. Add the `__Snapshots__` folder to git:
   ```bash
   git add CardOnCueUITests/__Snapshots__
   ```

## Troubleshooting

### "SnapshotTesting package not installed" error
- Make sure you completed Step 1 above
- Build the project (Cmd+B in Xcode)
- Clean build folder (Cmd+Shift+K) and rebuild

### Tests failing immediately
- Make sure `isRecording = true` for the first run
- Check that the simulator can launch

### Snapshots look different on CI
- Ensure CI uses the same OS version and device
- Commit snapshot images to version control
- Use precise device configurations in tests

## Quick Reference Commands

```bash
# Open project in Xcode
xed "/Users/nathanfennel/Library/Mobile Documents/com~apple~CloudDocs/Xcode Projects/CardOnCue"

# Run all snapshot tests
xcodebuild test -scheme CardOnCue \
  -destination 'platform=iOS Simulator,id=72C3870A-8AF8-4838-83AE-A2DBA6F9BC00' \
  -only-testing:CardOnCueUITests/SnapshotTests

# Run specific test
xcodebuild test -scheme CardOnCue \
  -destination 'platform=iOS Simulator,id=72C3870A-8AF8-4838-83AE-A2DBA6F9BC00' \
  -only-testing:CardOnCueUITests/SnapshotTests/testCardListView_Empty

# Open snapshots folder
open "CardOnCueUITests/__Snapshots__"
```
