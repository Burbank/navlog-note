# QUICKLOG for iPad

Native SwiftUI app, landscape-only, sized for the **A2903 iPad Air 11"** (1180×820 pt). The PWA in the repo root stays the web version.

## Why native

The Home Screen PWA can lose a cached shell, cannot schedule lock-screen alerts in airplane mode, and can drop data if the web app is deleted. This build stores the form and logbook as JSON in the app’s Application Support folder (survives updates) and uses **local UTC notifications** at each crew-rest end — those fire offline and when QUICKLOG is in the background.

## Open in Xcode

1. On your Mac: `ios/QUICKLOG/QUICKLOG.xcodeproj`
2. Signing & Capabilities → your Apple Development Team
3. Bundle ID is `com.burbank.quicklog` (change if that ID is taken)
4. Destination: **iPad Air 11-inch** (or your A2903)
5. Run. Rotate to landscape if the simulator starts in portrait; the app itself is locked to landscape.

iOS 17+ is required.

## What is ported

- Departure / fuel / RVSM / arrival cards and the same copy text as the PWA
- YOUR LOG (date, PF, PIC, RMK, aircraft, SIM + TOL, airports, S26, block/flight)
- Logbook, 90-day PF recency, ADD / EDIT / TABLE / CSV / CLEAR MARKED
- COPY DEPT / ARR → clipboard + `aviobook.ng.efb://`
- DSPERFO open + paste of a Take-off line
- BRIGHT / DIM / SYSTEM
- Crew rest (RRR / 2R, changeover, PF 2h, derived start/end, copy note)
- Native rest-end notifications (Allow when iPadOS asks)

## Still to polish on-device

Add a 1024×1024 App Icon in `Assets.xcassets/AppIcon`. Fine-tune spacing on the physical A2903 after the first run — this environment cannot compile SwiftUI.

The PWA remains on the other branch/PR for ongoing web maintenance.
