# Malayalam Panchangam Day Widget

The widget source lives in:

`WidgetExtension/MalayalamPanchangamDayWidget`

It displays:

- Gregorian date
- Malayalam month and date
- Kollavarsham year
- Nakshatram
- Rahu Kalam
- Location

## Xcode Integration

The repository now includes `MalayalamPanchangamCalendar.xcodeproj` with:

- `Malayalam Panchangam Calendar` macOS app target
- `MalayalamPanchangamDayWidget` WidgetKit extension target
- an Embed App Extensions build phase
- shared App Group entitlements on both targets

Both targets use this App Group:

   `group.com.malayalampanchangam.calendar`

The main app writes `WidgetDaySnapshot.json` through `WidgetSnapshotStore`. The widget reads the same JSON file from the shared App Group container.

## Current Behavior

The app publishes a snapshot whenever:

- a year is generated and a selected day exists
- the user selects a different calendar day

If the widget cannot read a snapshot yet, it shows the built-in placeholder.

## Production Notes

Before App Store distribution:

- Replace the App Group identifier with the final team-qualified bundle group if needed.
- Set the Apple Developer Team on both Xcode targets.
- Ensure the App Group is enabled in the Apple Developer portal for both bundle identifiers.
- Trigger `WidgetCenter.shared.reloadTimelines(ofKind:)` from the app after saving a snapshot if the app target links WidgetKit directly.
