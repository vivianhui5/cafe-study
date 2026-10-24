# Cozy Café 🍵

A native SwiftUI iPhone focus app with a minimalist Japanese matcha café feel: warm cream, muted sage, generous space, serif headings, and flat geometric cups drawn entirely in SwiftUI. No cartoon assets, external packages, accounts, ads, or network calls.

## Open and run

Requires Xcode 15 or later and iOS 17 or later. Open `CozyCafe.xcodeproj`, select the shared **CozyCafe** scheme and an iPhone Simulator, then Run. For a physical iPhone, choose your development team under Signing & Capabilities and use a unique bundle identifier. No signing team is embedded in this repository.

## Features

- **Focus:** select an unlocked drink, set 1–120 minutes, and start a brew. The cup fills as time passes. Reduced Motion is respected.
- **Collection:** see all six drinks, owned drinks, per-drink brew counts, total completed minutes, and cups.
- **Shop:** unlock drinks with earned coins; purchases deduct the displayed cost once.
- One coin per configured minute, paid only when the entire session completes while the app is active. A 25-minute completed brew earns 25 coins.
- Inactive/background transitions (including phone lock, app switcher, and interruptions) immediately cancel the current brew with **zero rewards**, even if some full minutes elapsed. Returning never resumes it. Switching the app’s tabs is allowed.
- Progress, selected drink, timer duration, unlocks, and counts persist locally in UserDefaults. Running sessions are never persisted. The screen stays awake during a brew, and normal auto-lock returns after completion or cancellation.
- Timer calculations use monotonic system uptime rather than the wall clock.

## Architecture

`Sources/CozyCafeCore/Cafe.swift` is a Foundation-only state machine, compiled directly into the iOS app and exposed separately as a Swift Package for tests. `CozyCafe/CozyCafeApp.swift` contains the observable persistence adapter, lifecycle handling, artwork, and screens. No third-party dependencies are required.

## Verification

Run `swift test` on a Mac with Xcode installed. The XCTest suite covers exactly-once completion rewards, cancellation, purchase limits, persistence round-trips, duration bounds, and immutable running-session settings.

For Command Line Tools installations without XCTest, run `Scripts/verify.sh`. This compiles and runs equivalent core assertions, parses the SwiftUI source, and validates the Xcode project plist. Parsing is not an iOS type-check or simulator build.

Build with:

```sh
xcodebuild -project CozyCafe.xcodeproj -scheme CozyCafe -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

GitHub Actions runs the XCTest suite and an unsigned iPhone Simulator build on pushes and pull requests.

### Verification on the authoring Mac

- Standalone Swift core assertions: passed.
- SwiftUI source syntax parsing: passed.
- Xcode project plist validation: passed.
- iOS build / simulator / XCTest: unavailable because this Mac has Command Line Tools only, without full Xcode or XCTest. No successful iOS build is claimed.

### Manual iPhone QA

1. Complete a one-minute brew: verify gradual fill, one coin, and one additional cup; wait longer and verify no duplicate reward.
2. Start again; open Control Center, lock the phone, or switch apps. Return and verify cancellation and unchanged coins/counts.
3. Cancel manually and verify no reward. Relaunch mid-session and verify no resumed session or reward.
4. Earn 30 coins, unlock Hojicha, select it, and relaunch; verify balance and selection persist. Verify unaffordable drinks cannot be purchased.
5. Check all tabs at larger text sizes, with VoiceOver, and with Reduced Motion enabled.

## Shipping notes

This is a source-complete starter app. Full iOS compilation and device QA remain required. An App Store icon, signing, distribution configuration, and App Store metadata are not included.
