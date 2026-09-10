# Global MIR Calculator

A Flutter web application for rating the twelve Global MIR domains and deriving
the global MIR score plus the straight sum of domain ratings.

[![Deploy](https://github.com/jgfoster/GlobalMIR/actions/workflows/deploy.yml/badge.svg)](https://github.com/jgfoster/GlobalMIR/actions/workflows/deploy.yml)

### [Open the calculator → jgfoster.github.io/GlobalMIR](https://jgfoster.github.io/GlobalMIR/)

> A reference aid for qualified clinicians and researchers. Calculated scores
> must be re-checked and should not be used alone to guide patient care, nor
> should they substitute for clinical judgment. See the About tab in the
> application for the full disclaimer.

## Domains and rating levels

Each of the twelve domains is rated on the ordinal ladder:

| Rating | Meaning |
| --- | --- |
| 0 | normal / no changes |
| 0.5 | subtle / questionable |
| 1 | mild but definite |
| 2 | moderate |
| 3 | severe |

Domains: Memory; Orientation; Judgment and Problem Solving; Concentration and
Multitasking; Visuospatial Functioning; Behavior, Comportment and Personality;
Psychiatric Symptoms; Language; Motor/Other; Community Life; Home Life; Basic
Activities of Daily Living (ADLs).

## Global rating rules

1. If all domains are 0, the global MIR score is 0.
2. If the maximum domain score is 0.5, the global MIR score is 0.5.
3. If the maximum domain score is above 0.5 in any domain:
   - **3A** maximum is 1 and all other domains are 0 -> global 0.5
   - **3B** maximum is 2 or 3 and all other domains are 0 -> global 1
   - **3C** maximum occurs only once and another domain is non-zero -> global is
     one level lower than the maximum (3 -> 2, 2 -> 1, 1 -> 0.5)
   - **3D** maximum occurs in more than one domain -> global equals that maximum

The application also reports the straight sum of the twelve ratings as a
continuous measure from 0 to 36.

## Layout

- `lib/scoring.dart` - the scoring engine (domains, rules, results) and the ten
  published example scenarios. No Flutter dependency, so it is directly testable.
- `lib/main.dart` - the UI: a **Rate** tab (domain ratings plus a live result
  panel), an **Examples** tab (the published scoring table, scored live, with
  each scenario loadable into the calculator), a **Rules** tab, and an
  **About** tab carrying the intended use, medical disclaimer, privacy
  statement, licence, and references.
- `test/scoring_test.dart` - rule-by-rule tests plus all ten published scenarios.
- `test/widget_test.dart` - UI tests covering rating, resetting, scenario
  loading, the sum readout, the terms link, and the narrow-screen layout.
- `.github/workflows/deploy.yml` - analyses, tests, and deploys to GitHub Pages.

## Running

```sh
flutter pub get
flutter run -d chrome          # development
flutter test                   # 43 tests
flutter build web --release    # output in build/web
```

## Deployment

Every push to `main` triggers `.github/workflows/deploy.yml`, which runs
`flutter analyze` and `flutter test`, builds with
`--base-href /GlobalMIR/` (project pages are not served from the domain root),
and publishes `build/web` to [GitHub Pages](https://jgfoster.github.io/GlobalMIR/). A failing test blocks the deploy.
The Pages source is set to *GitHub Actions*; nothing built is committed, so the
site cannot drift from the source. A deploy can also be started by hand from
the Actions tab.

The Flutter version is pinned in the workflow. When bumping it, bump
`kAppVersion` in `lib/main.dart` too if the scoring behaviour changes, since
copied score summaries carry that version.

## Privacy

All calculation happens in the browser. Ratings are never transmitted, logged,
or stored; the application has no backend, no accounts, no cookies, and no
analytics. Ratings are discarded on reload.

## Licence

MIT, Copyright (c) 2026 James Foster. See `LICENSE`.

## Note on the published example table

The published "Global MIR Scoring Examples" table labels scenario 2 (a single
domain rated 0.5) as rule 3A. Rule 3A requires a maximum of 1, so the condition
actually met there is rule 2. Both produce a global rating of 0.5, so every
published global rating is reproduced; the application reports rule 2 for that
pattern and flags the discrepancy on the Examples tab.

*For research and educational use. Not a diagnostic device.*
