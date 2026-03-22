# Phase 4 Notes — Smarter Finances

**Planned scope:** Settlement optimizer, spending trends, category drill-down, charts

## Carry-forward from Phase 3

### Responsive sizing (from Phase 3 observation)
The app uses hardcoded pixel values for font sizes, icon sizes, and padding
throughout (e.g., `fontSize: 32`, `width: 48`, padding `24`). These work on
standard phones but won't scale to small screens or tablets.

**Fix:** Add a `MediaQuery`-based scale factor utility that adjusts sizes
relative to screen width. Apply to font sizes, icon dimensions, and key
padding values across all screens. This is a cross-cutting concern that
should be done once as a utility, not per-screen.

**Files likely affected:** `lib/constants.dart` (add scale utility),
all screens and widgets that use hardcoded sizes.
