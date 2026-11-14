# E-Ink Fork Cleanup Plan

Follow-up to `eink-optimization.md`. Goal: turn Tsumiru into a **dedicated
e-ink fork** — keep only the e-ink settings and the paper theme, and strip the
animation/transparency/gradient machinery that a normal-LCD app needs but e-ink
doesn't. This is a reduction pass, not new features.

## Guiding principle

The `flat` (e-ink paper) path should become the **only** path. Anything that
exists solely to serve other themes or smooth-scroll UX becomes dead weight.

## Phases

### 1. Collapse theming to a single theme

- `constants/app_theme.dart`: remove all `AppTheme` values except `einkPaper`
  (and delete `custom`). `AppTheme` is index-persisted — but the fork resets
  preferences anyway, so this is a clean break (bump the persisted enum or
  delete the key).
- `utils/theme/theme_tokens.dart`: delete every `_*Dark`/`_*Light` token block
  except `_einkPaperLight`/`_einkPaperDark`.
- `utils/theme/app_theme_builder.dart`: drop the `tokens`/`customSeed`/`amoled`
  parameters and the `theme == AppTheme.custom` branches; always build from
  `einkPaper`.
- Delete the theme picker (`app_theme_selector/`), `AppThemeModeTile`, custom
  color, and `IsTrueBlackTile`; `appearance_screen.dart` keeps only the
  E-Ink toggle + display settings.
- `tsumiru_app.dart`: theme is always `einkPaper` + light; `themeMode` fixed.
- Remove `BrandColors.gradient`/`onGradient`/`grad`/`brandGlow` — replace the
  brand components (`BrandButton`, `BrandFab`, `BrandGlassButton`) with a single
  flat `Button` (white bg, black text, 1px black border).
- `TsumiruLogo` always renders `assets/icons/logo_eink.png`; delete the old
  logo assets (`logo_*.png`, `dark_icon.png`) and the SVG gradient sources.

### 2. Settings cleanup (keep e-ink only)

- Remove: theme mode, custom color, pure-black, grid cover width, backdrop,
  recommendations, language-migration-only toggles.
- Keep the **E-Ink group**: `einkMode`, `flashOnPageChange`/duration/every/color,
  `einkNativeRefreshAvailable` (native refresh), reader background color, reader
  mode, fullscreen, keep-screen-on, volume-key page turns.
- The single `einkMode` toggle can go away too (always on) — keep it only if we
  still want a manual escape hatch; otherwise hard-code `einkActive = true` and
  delete the detection banner.
- Reader settings sheet: delete the Custom-filter tab (grayscale/invert/brightness
  overlays are pointless on e-ink) and the theme tab; keep Reading mode + General.

### 3. Reader simplification

- Default and only reader mode: **paged** (`singleHorizontalLTR`). Remove the
  continuous/webtoon/infinity engine (`infinity_continuous/`,
  `multichapter_continuous_reader_mode.dart`) and the `continuousHorizontal*`
  orphan modes.
- Remove pinch/pan/zoom animations: `paged_reader_viewport.dart` no longer needs
  `_panAnimation`/`_zoomAnimation`/`_animateZoomTo` — pan/zoom can be dropped or
  reduced to an instant toggle.
- Remove smooth auto-scroll; keep stepped auto-scroll if wanted.
- Remove custom filters (`reader_color_overlays.dart` BackdropFilter path) and
  crop/rotate/wide-page extras (keep if desired, they're render-only).
- Keep the flash overlay + `EinkManager` native refresh (`MainActivity.kt`).

### 4. App-wide flat rendering

- Keep `AppScrollBehavior` clamped + no overscroll glow.
- Keep `AppCircularProgress`/`AppLinearProgress` static under reduced motion;
  drop the animated branch.
- Sweep remaining `withValues(alpha:)`, `BoxShadow`, `MaskFilter.blur`,
  `BackdropFilter`, `Opacity(` call sites and make them opaque/removed (the
  cover-art scrims `OnImage.shadow`/`showDarkOverlay` can be removed too once
  titles no longer need legibility over art — or kept).
- Remove `reduce_motion.dart`'s runtime toggle (`appReduceMotionProvider`) —
  reduced motion is always on; keep the `ReducedRouteTransition` route behavior.

### 5. Identity & packaging

- Rename user-facing strings (app label, l10n) to the fork name if desired.
- Keep the monochrome icon/logo (generated this branch).
- Release signing: generate a local keystore + `key.properties` so `--release`
  builds work locally (CI keeps its own). Document in `CONTRIBUTING.md`.
- Regenerate `assets.gen.dart` (FlutterGen) to include `logo_eink.png` instead
  of the current literal-path reference.

## Order

1. Theming collapse (biggest, most mechanical).
2. Settings + reader simplification.
3. Flat-render sweep.
4. Identity/packaging.

## Non-goals

- Webtoon/continuous reading on e-ink (explicitly deferred).
- Frontlight control UI (the API is documented in `~/coding/m103-eink-probe`;
  wiring it in is a separate feature).
- Grayscale image decode.
