# Validation Fixtures

Fixture files live under `Data/ValidationFixtures`.

Each JSON file uses this shape:

```json
{
  "sourceName": "Historical Malayalam Calendar Archive - Thrissur",
  "timezoneIdentifier": "Asia/Kolkata",
  "rows": [
    {
      "locationName": "Thrissur",
      "date": "2026-04-14",
      "sunrise": "06:14",
      "sunset": "18:35",
      "nakshatra": "uthrattathi",
      "nakshatraTransition": "11:42",
      "malayalamMonth": "medam",
      "malayalamDay": 1,
      "rahuKalam": { "start": "15:29", "end": "17:02" },
      "yamagandam": { "start": "09:19", "end": "10:52" },
      "gulikaKalam": { "start": "12:24", "end": "13:57" }
    }
  ]
}
```

Times are local to the document timezone and use `HH:mm` 24-hour format. Enum values use Swift raw names, such as `medam`, `dhanu`, `makam`, and `uthrattathi`.

The current `thrissur-sample.json` file is a workflow sample, not an authoritative archive transcription. Replace sample values with confirmed historical source values before using them for production confidence claims.
