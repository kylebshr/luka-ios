# CLAUDE.md - Luka iOS Development Guide

## Overview

Luka is an iOS companion app for Dexcom continuous glucose monitors (CGM). It provides Lock Screen, Home Screen, and Apple Watch widgets displaying real-time Dexcom glucose readings. The app uses the [dexcom-swift](https://github.com/kylebshr/dexcom-swift) library and supports iOS Live Activities with Dynamic Island.

**App Store ID:** 6499279663

## Quick Commands

```bash
# Open in Xcode
open Luka.xcodeproj

# Build from command line
xcodebuild -project Luka.xcodeproj -scheme Luka -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Project Structure

```
/Luka                    # Main iOS app target
  /Views                 # SwiftUI views (MainView, SignInView, SettingsView)
  /Views/Form            # Reusable form components
  /Intents               # App Intents for Live Activities & Shortcuts
  /Models                # App-specific models (Banners)
  LukaApp.swift          # @main entry point

/Watch                   # watchOS app target
  LukaApp.swift          # Watch entry point
  MainView.swift         # Watch glucose display
  RootView.swift         # Watch navigation

/Shared                  # Code shared across all targets
  /Views                 # Shared UI (ReadingView, LineChart, GraphView)
  /View Models           # LiveViewModel for glucose data
  /Models                # Core models (GlucoseReading extensions, LiveActivityState)
  /Intents               # Widget intents (GraphRange, WidgetTapAction)
  /Widgets               # Widget implementations & timeline providers
  /Utilities             # Extensions, Keychain, Defaults, Constants
  /Style                 # Visual modifiers (CardModifier)
  /Modifiers             # Custom SwiftUI modifiers

/LukaWidget              # iOS widget extension
  ReadingActivityConfiguration.swift  # Live Activity UI

/WatchWidget             # watchOS widget extension (uses Shared/Widgets)
```

## Key Targets & Schemes

| Target | Description |
|--------|-------------|
| Luka | Main iPhone app |
| Watch | Apple Watch app |
| LukaWidget | iOS widgets + Live Activity |
| WatchWidget | watchOS complications & widgets |

## Architecture

### Pattern: SwiftUI + MVVM with @Observable

The app uses modern SwiftUI with the `@Observable` macro:

```swift
@Observable @MainActor class RootViewModel {
    var username: String?
    var password: String?
    // ...
    func signIn(...) async throws
}

@MainActor @Observable class LiveViewModel {
    enum State {
        case initial
        case loaded([GlucoseReading], latest: GlucoseReading)
        case noRecentReading
        case error(Error)
    }
    private(set) var state: State = .initial
}
```

### Key Patterns

- **@Observable ViewModels** - Replace Combine-based ObservableObject
- **@MainActor isolation** - All view models are MainActor isolated
- **Protocol-based services** - `DexcomClientService` protocol for real/mock implementations
- **Timeline Providers** - Widget updates via `AppIntentTimelineProvider`
- **Environment injection** - ViewModels passed via `.environment(viewModel)`

## Important Files

| File | Purpose |
|------|---------|
| `Luka/LukaApp.swift` | App entry, TelemetryDeck init, widget refresh on background |
| `Luka/Views/RootViewModel.swift` | Auth state, banner loading, force upgrade logic |
| `Shared/View Models/LiveViewModel.swift` | Glucose data refresh scheduling |
| `Shared/Models/DexcomHelper.swift` | Factory for real/mock Dexcom clients |
| `Shared/Utilities/Defaults.swift` | UserDefaults keys, session history |
| `Shared/Utilities/Keychain.swift` | Secure credential storage |
| `Shared/Utilities/Constants.swift` | Spacing, corner radius, keychain keys |
| `Shared/Widgets/ReadingTimelineProvider.swift` | Widget timeline logic |
| `LukaWidget/ReadingActivityConfiguration.swift` | Live Activity UI |

## Dependencies

| Package | Purpose |
|---------|---------|
| [dexcom-swift](https://github.com/kylebshr/dexcom-swift) | Dexcom API client |
| [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) | Secure credential storage |
| [Defaults](https://github.com/sindresorhus/Defaults) | UserDefaults wrapper with iCloud sync |
| [TelemetryDeck](https://telemetrydeck.com) | Privacy-first analytics |

## Coding Conventions

### Spacing Constants

Use constants from `CGFloat` extensions instead of magic numbers:

```swift
.padding(.horizontal, .spacing8)     // 16pt
.padding(.vertical, .spacing6)       // 12pt
.cornerRadius(.defaultCornerRadius)  // 24pt
```

| Constant | Value |
|----------|-------|
| `.spacing1` | 2pt |
| `.spacing3` | 6pt |
| `.spacing4` | 8pt |
| `.spacing6` | 12pt |
| `.spacing8` | 16pt |
| `.spacing10` | 20pt |
| `.spacing12` | 24pt |
| `.defaultCornerRadius` | 24pt |
| `.smallCornerRadius` | 10pt |

### File Header Format

```swift
//
//  FileName.swift
//  Luka
//
//  Created by Name on MM/DD/YY.
//
```

### State Management

**Keychain** - Credentials (synced via iCloud Keychain):
- `username`, `password`, `accountID`, `sessionID`

**UserDefaults (shared suite)** - Preferences:
```swift
Defaults[.targetRangeLowerBound]  // Double, default: 70
Defaults[.targetRangeUpperBound]  // Double, default: 180
Defaults[.graphUpperBound]        // Double, default: 300
Defaults[.unit]                   // GlucoseFormatter.Unit (.mgdl/.mmolL)
Defaults[.showChartLiveActivity]  // Bool, default: true
Defaults[.selectedRange]          // GraphRange (1h-24h)
```

**App Groups** - Suite name: `group.com.kylebashour.Glimpse`

### Color Coding

Glucose values are color-coded based on target range:
- `.lowColor` - Below lower bound (pink/red)
- `.inRangeColor` - Within target (mint/green)
- `.highColor` - Above upper bound (yellow)

### Mock/Demo Mode

Username `demo@pitou.tech` triggers MockDexcomClient for testing.

## Widget Development

### Widget Types

1. **ReadingWidget** - Current glucose value + trend
   - Supports: systemSmall, systemMedium, systemLarge, accessoryInline, accessoryCircular, accessoryRectangular

2. **GraphWidget** - Glucose graph with configurable range
   - Supports: systemSmall, systemMedium, systemLarge, accessoryRectangular

### Timeline Refresh Strategy

```swift
// Refresh ~15 seconds after next expected reading
let refreshDate = latestReading.date + (5 * 60) + 15

// Minimum 10-minute refresh on errors
// Stale data (>25 min) gets redaction applied
```

### Widget Configuration Intents

```swift
struct ReadingWidgetConfiguration: WidgetConfigurationIntent {
    @Parameter var tapAction: WidgetTapAction  // refresh/launch
    @Parameter var app: LaunchableApp
}

struct GraphWidgetConfiguration: WidgetConfigurationIntent {
    @Parameter var graphRange: GraphRange      // 1h to 24h
    @Parameter var app: LaunchableApp
}
```

## Live Activity

### Flow

1. User taps "Start Live Activity"
2. `StartLiveActivityIntent.perform()` creates Activity with `ReadingAttributes`
3. Push token sent to backend (`https://a1c.dev/start-live-activity`)
4. Backend sends push updates with new readings
5. On end, signal sent to `https://a1c.dev/end-live-activity`

### Dynamic Island Regions

- **Expanded**: Leading (value), Trailing (arrow), Center (timestamp), Bottom (optional graph)
- **Compact**: Leading (value) + Trailing (arrow)
- **Minimal**: Compressed glucose display

## API Integration

### Dexcom API

Via dexcom-swift library:
```swift
let client = DexcomClient(
    username: username,
    password: password,
    existingAccountID: accountID,
    existingSessionID: sessionID,
    accountLocation: .us  // or .apac, .worldwide
)
let readings = try await client.getGlucoseReadings()
```

### Remote Config (Banners)

Fetched from: `https://raw.githubusercontent.com/kylebshr/luka-meta/refs/heads/main/meta.json`

```swift
struct Banners: Codable {
    var banners: [Banner]
    var minVersion: String?      // Force upgrade threshold
    var requiresForceUpgrade: Bool
}
```

## Telemetry

Analytics via TelemetryDeck (privacy-first):

```swift
TelemetryDeck.signal("LiveActivity.started", parameters: ["source": "App"])
TelemetryDeck.signal("Banner.dismissed", parameters: ["id": banner.id])
TelemetryDeck.signal("ForceUpgrade.viewed")
```

## Testing Tips

- Use `demo@pitou.tech` as username for mock data
- Mock client returns realistic 24h glucose data (288 readings)
- DEBUG builds reset dismissed banners on launch
- Session history visible in Settings on TestFlight builds

## Common Tasks

### Adding a New Widget

1. Add widget struct to `Shared/Widgets/`
2. Create timeline provider implementing `AppIntentTimelineProvider`
3. Register in `LukaWidgetBundle.swift`
4. Add configuration intent if needed in `Shared/Intents/`

### Adding a New Setting

1. Add key to `Defaults.Keys` in `Shared/Utilities/Defaults.swift`
2. Add UI in `SettingsView.swift`
3. If widget needs it, ensure it uses shared suite

### Adding a New View

1. Create in appropriate `/Views` directory
2. Use `.card()` modifier for glass morphism styling
3. Use `.withReadableWidth()` for constrained layouts
4. Follow existing spacing constants

## Build Notes

- iOS 17.0+ deployment target (for @Observable)
- Requires Xcode 15+
- Swift Package Manager for dependencies
- TelemetryDeck requires app ID: `7C1E8E40-73DE-4BC4-BDBF-705218647D91`
