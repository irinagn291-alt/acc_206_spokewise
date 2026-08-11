# Spokewise SPEC

Offline wheel building log (gmbl_34).

- SQLite via libsqlite3 (`SpokeSQLiteStore`)
- Preferences live in the SQLite settings row, never in a system preference store
- Navigation: three lenses over one polar artefact; Bench / Wheel / Workshop via the hero destination chrome; Settings via the gear
- Primary data entry: tap a spoke on the map, dial its value
- Pure geometry: `RimPolarGeometry`, `RimDeviationScale`, `RimReadoutMath`, `SpokeDialMath`, `SpokeTriangleMath`
- Killer calculator: spoke-length geometry (`SpokeMath.spokeLength`, drawn by `SpokeTriangleMath`)
- Domain graphics: rim-deviation polygon, runout trace, calibration curve, polar thumbnails, tension overlay
- Reference: 18 lacing patterns
- Export: CSV tension sheet
- Prefixes: Rim / Spoke / Wheel / Anodised
