# E-Ink Mode Plan (Android)

## Context

Tsumiru is a Flutter client for Suwayomi-Server — a manga/manhwa reader. Android
e-ink devices (Onyx Boox, Hisense, Bigme, Meebook, …) are a natural fit for manga
reading, but impose hard constraints:

- **Slow refresh** and **ghosting** — previous frames bleed through; needs full
  refreshes or white/black "flash" passes between page turns.
- **Every animation is a refresh** — spinners, slides, fades, ripples, smooth
  scrolling cause constant redraws and battery drain.
- **Reflective screens** — light, high-contrast themes read best; dark themes hurt.
- **Touch latency** — imprecise gestures; page turns via taps or volume-mapped
  physical keys (already supported via `flutter_android_volume_keydown`).

The app already has a partial E-Ink foundation (page-change flash overlay,
reduce-motion plumbing, volume-key turns, Monochrome theme). This plan adds a
**single "E-Ink mode" toggle** that owns the e-ink experience: it applies an e-ink
settings preset, forces an e-ink theme, and disables the settings it manages.

## Scope (this revision)

- **In:** Android e-ink devices only. Single `einkMode` toggle + detection +
  auto-suggestion banner. Runtime behavior gates (instant chrome, no image fades,
  static progress indicators, clamped physics, snap paged viewport). E-Ink theme +
  forced light mode. Settings-tile disabling while the mode is on. Native screen
  refresh via reflection probe for the **Meebook M103**, with the flash overlay as
  the automatic fallback everywhere else.
- **Out (deferred):** Onyx `EpdController` / Onyx SDK integration, webtoon /
  continuous-scroll page-slicing mode, hardware page-turn key mapping beyond the
  existing volume-key support, Linux e-ink monitors, A2-mode scroll toggles,
  grayscale decode.

## Design: the single toggle

`DBKeys.einkMode` (bool, default **false**) + `einkModeProvider` +
`einkActiveProvider` (= the toggle). **Toggle ON:**

1. **Applies the e-ink preset** — writes recommended values through the existing
   setting providers (one-shot, no new write paths):
   - Reader: **default reader mode → paged** (`readerModeKey` →
     `singleHorizontalLTR`; per-series mode overrides and the mode selector
     itself stay editable), `flashOnPageChange: true` (flash duration ↑ —
     the automatic fallback where native refresh is unavailable; on M103 with
     native refresh it is replaced by default and stays available as opt-in),
     `readerBackgroundColor: white`, `readerFullscreen: true`,
     `smallerTapZones: false`, `volumeTap: true`.
   - Motion: `appReduceMotion: true`.
2. **Forces theme** — `TsumiruApp` resolves theme/`themeMode` through
   `einkActiveProvider`: `einkPaper` theme + light mode, ignoring the stored
   theme/theme-mode values while ON.
3. **Disables managed settings** — while ON, the conflicting tiles render
   disabled with a "Managed by E-Ink mode" subtitle, in **both** the settings
   screens and the reader settings sheet:
   - Appearance: theme picker, theme mode, custom color.
   - Reader: background color, animate-page-transitions (already also killed by
     forced reduced motion).
4. **Gates runtime behavior** (not stored settings — live predicates):
   - `ReduceMotionScope` treats `einkActive` as reduce-motion (route transitions,
     ripples, expansion animations die app-wide).
   - Reader chrome show/hide becomes instant (no 200 ms slide).
   - Image fade-in/out durations become zero.
   - Paged-viewport page/pan/zoom animations snap instead of running.
   - Progress indicators render static.
   - Scroll physics clamp (no bounce/glow).

**Toggle OFF:** the applied values **stay in place** (decision — no snapshot/
restore mechanism); settings simply return to editable and the user's own later
changes apply again. The tile subtitle documents this.

## Current state (already in the codebase)

| Capability | Where |
|---|---|
| Page-change flash: on/off, duration (1–15 × 100 ms), every-N, black/white/white-black | `DBKeys.flashOnPageChange` (default **false**), `reader_flash_overlay.dart`, E-Ink group in `reader_settings_screen.dart` + General tab of the reader sheet |
| Reduced-motion plumbing | `lib/src/utils/motion/reduce_motion.dart` — `appReduceMotionProvider`, `ReduceMotionScope` (route transitions, splash/ripple, expansion) |
| Page-turn animation toggle, gated on `context.reduceMotion` | `multichapter_paged_reader_mode.dart:840`, `multichapter_continuous_reader_mode.dart:1042` |
| Monochrome theme | `AppTheme.monochrome` |
| Volume-key page turns | `reader_wrapper.dart:619-636` |
| Reader background color (white/black/gray/automatic) | `ReaderBackgroundColor`, `DBKeys.readerBackgroundColor` |
| Fullscreen / keep-screen-on / stepped auto-scroll | `DBKeys.readerFullscreen`, `readerKeepScreenOn`, `autoScrollIntervalSeconds` |
| Decode-size cap (low-CPU decode — good for e-ink SoCs) | `ServerImage._capDecode` |

## Gaps

1. No e-ink **device detection** (Android).
2. No **single E-Ink mode** umbrella that applies settings, forces theme, and
   disables conflicting UI.
3. No **screen-refresh control** — no native full-refresh trigger for the
   Meebook M103 (reflection-probed `View` methods); flash overlay is the only
   current ghosting countermeasure.
4. Animations that bypass `ReduceMotionScope`: 200 ms reader-chrome slide
   (`reader_chrome.dart:101`), image fades (`server_image.dart:610-611`,
   `tall_page_image.dart:327`), ~25 `CircularProgressIndicator`/
   `LinearProgressIndicator` call sites, paged-viewport
   `_pageAnimation`/`_panAnimation`/`_zoomAnimation`, gradient/glow brand
   components, bounce scroll physics.
5. No paper-white high-contrast **E-Ink theme** (Monochrome is closest).

---

## Phase 1 — Detection & the toggle

### 1.1 Android e-ink detection

- Hand-rolled `MethodChannel` (consistent with the existing draw-under-cutout
  channel; no new dependency) in `platforms/android/` returning
  `Build.MODEL` / `Build.MANUFACTURER` (+ `ro.soc.manufacturer` if cheap).
- `lib/src/utils/platform/eink/eink_device_detection.dart` — pure predicate over
  that payload: model/manufacturer contains `BOOX`, `ONYX`, `Poke`, `Leaf`, `Nova`,
  `Tab`, `Palma`, `Hisense`, `A5`, `A7`, `A9`, `Hi Reader`, `Bigme`, `Meebook`,
  `M103`, `Likebook`, or manufacturer == `onyx`. Const set + allowlist.
- `isEinkDeviceProvider` (`@riverpod`, cached) + `debugEinkOverride` flag in
  `platform_runtime.dart` style. Non-Android always false.

### 1.2 The `einkMode` toggle

- `DBKeys.einkMode` (bool, append) + `einkModeProvider`
  (`SharedPreferenceClientMixin`) + derived `einkActiveProvider` (just the toggle —
  detection only feeds the suggestion banner below).
- `einkSettingsPreset()` — pure list of `(provider notifier, value)` pairs from the
  Design section; applied once on toggle ON by a notifier action.
- `EinkModeSwitchTile` in **Appearance** settings (it manages theme + reader):
  switch + subtitle explaining what it applies/disables + "E-Ink device detected"
  dismissible banner (reuse the existing banner pattern, e.g.
  `account_storage_recovery_banner.dart`) suggesting enabling it.

**Files:** `android/app/src/main/kotlin/.../MainActivity.kt`,
`lib/src/constants/db_keys.dart`, `lib/src/constants/enum.dart` (if needed),
new `lib/src/utils/platform/eink/`,
`lib/src/features/settings/presentation/appearance/`.

**Tests:** detection predicate over fixtures (Boox/Hisense/Meebook/plain models);
preset
application writes all expected providers; toggle derivation.

---

## Phase 2 — Runtime behavior gates

Each consumer watches `einkActiveProvider`; no stored setting changes.

### 2.1 Reduce-motion + theme resolution

- `ReduceMotionScope.build` adds `ref.watch(einkActiveProvider)` to its reduce
  condition — app-wide motion dies with the toggle.
- `TsumiruApp.build` resolves `theme` / `themeMode` to `einkPaper` + light when
  `einkActive`; the Appearance theme tiles are disabled meanwhile.

**Files:** `lib/src/utils/motion/reduce_motion.dart`, `lib/src/tsumiru_app.dart`.

### 2.2 Instant reader chrome

`reader_chrome.dart` drives show/hide with one 200 ms `AnimationController`
+ `SlideTransition`/`FadeTransition`, and slaves the OS bars to the animation
status. Under `einkActive`: skip the controller — `visibility` flips drive an
instant `Visibility`-style swap (reuse the `ReducedRouteTransition` pattern) and
OS bars toggle directly. Same `visibility` source of truth; render-only.

**Files:** `reader/widgets/chrome/reader_chrome.dart`.

### 2.3 No image fades

When `einkActive`, pass `Duration.zero` fade durations in `server_image.dart`
and skip the animated `frameBuilder` branches in `tall_page_image.dart` and the
multichapter frame builder — pages pop in instantly (no partial-frame ghosting).
Render-only param change: allowed by the frozen-boundary rules.

**Files:** `lib/src/widgets/server_image.dart`,
`reader_mode/infinity_continuous/tall_page_image.dart`,
`reader_mode/infinity_continuous/multichapter_continuous_reader_mode.dart`.

### 2.4 Snap paged viewport

`paged_reader_viewport.dart` keeps `_pageAnimation`, `_panAnimation`,
`_zoomAnimation`. Under `einkActive`: page turns snap (no controller run), pan and
zoom jump directly, double-tap zoom toggles instantly — same pattern as the
existing `animatePageTransitions && !context.reduceMotion` gate in
`multichapter_paged_reader_mode.dart`.

**Files:** `reader_mode/paged_reader_viewport.dart`,
`reader_mode/multichapter_paged_reader_mode.dart`.

### 2.5 Static progress indicators

~25 `CircularProgressIndicator`/`LinearProgressIndicator` call sites animate
forever (constant refresh on e-ink). Add `lib/src/widgets/app_progress.dart` —
`AppCircularProgress`/`AppLinearProgress` that render Material indicators normally,
but under `reduceMotion || einkActive` render a static determinate-style
placeholder that only repaints on value change. Sweep the call sites (mechanical).

**Files:** new `lib/src/widgets/app_progress.dart` + ~25 call sites.

### 2.6 Scroll physics

`ScrollConfiguration` in the app shell swaps bouncing physics for clamping and
drops the overscroll glow under `einkActive` (Android already clamps; verify
desktop/web paths no-op).

**Files:** `lib/src/tsumiru_app.dart` / `lib/src/widgets/shell/`.

---

## Phase 3 — E-Ink theme

- Add `AppTheme.einkPaper` — **append to `AppTheme`** (index-persisted; appending
  after `custom` is mandatory). Pure `#FFFFFF` bg, `#000000` ink, flat surfaces,
  no gradient (`--grad` omitted), `neutral`-style brand behavior (Monochrome light
  precedent in `brand.dart`).
- Token set in `theme_tokens.dart` + theme-kit mirror
  (`~/Projects/theme-kit/themes/…`) per the curated-theme convention.
- Pass the enforced WCAG tests (`test/src/utils/theme/light_contrast_test.dart`).
- Under `einkActive`, `BrandColors.gradient` degrades to a flat surface color and
  `brandGlow` is skipped (gradients/shadows are dither noise).

### Shadows & flat chrome (e-ink only)

`BrandColors.flat` (true for `einkPaper`) is the single flag every shadow/transparency
check uses; it is set in `buildAppTheme` via `flat = theme == AppTheme.einkPaper`.

- **Theme-level** (`app_theme_builder.dart`): when `flat`, filled/elevated button
  style drops `shadowColor`/`elevation` (→ 0), FAB `elevation` → 0, and
  `snackBarTheme`/`bottomSheetTheme`/`dialogTheme` get `elevation: 0` **and a
  1px `onSurface` border** (clear borders on every box).
- **Buttons become black text on white**: when `flat`, filled/elevated buttons
  use `surface` background + `onSurface` foreground + a 1px `onSurface` outline
  (disabled = solid `surfaceContainerHighest` + `onSurfaceVariant` text, no
  alpha); outlined buttons use a solid `onSurface` border; the FAB uses `surface`
  background + `onSurface` foreground + outline; `BrandButton` and `BrandFab`
  (the gradient primary-action buttons) drop their gradient and render `surface`
  background + `onSurface` text + border; `BrandGlassButton` is opaque. Chips
  get an opaque `surface` background + solid border. Text buttons are already
  black.
- **Bars** (app bar, navigation bar/rail, top bar) are already black-on-white via
  the scheme (`surface` + `onSurface`), with `elevation: 0`; the e-ink theme only
  needs no additional changes there.
- **No transparency**: `readerNavSurface` returns fully opaque `surface` when
  `flat` (reader chrome bars drop their 0.9/0.95 alpha); `BrandGlassButton`
  becomes an opaque `surface` with a border and solid text; the cover
  read-progress bar uses an opaque `surfaceContainerHighest` track instead of the
  translucent black track (which dithers/reads as a shadow on e-ink). The reader
  seekbar (`BrandPageSeekBar`) drops its blurred marker halo
  (`MaskFilter.blur`), uses solid track/tick/marker colors, and renders an opaque
  bordered capsule.
- **Swipe transitions**: page-turn, pan/zoom, tap-zone-hint, and chapter-route
  transitions are all gated on `context.reduceMotion` (which e-ink forces). The
  preset additionally writes `animatePageTransitions: false` as belt-and-braces.
- **Call sites** gated on `BrandColors.of(context).flat` (elevation → 0, box
  shadows → null): series header gradient glow, toast shadow, chapter-grid tile
  glow, continue-reading button, desktop navigation rail, desktop library panels,
  desktop search field. Cover-art scrims (`OnImage.shadow`, `showDarkOverlay`)
  are content-legibility, not UI chrome — intentionally left alone.

**Files:** `constants/app_theme.dart`, `utils/theme/theme_tokens.dart`,
`utils/theme/brand.dart`, `utils/theme/app_theme_builder.dart`, the call-site
widgets above, theme-kit repo note.

---

## Phase 4 — Native refresh for Meebook M103 (flash fallback)

Target device: **Meebook M103** (Boyue/Likebook rebrand — Rockchip `rk3566`,
manufacturer `haoqing`, Android 11). **Mechanism found on-device:** the vendor
patches the framework with `android.os.EinkManager`, exposed through the standard
`Context.EINK_SERVICE` (`getSystemService("eink")`), plus the binder interface
`android.os.IEinkManager` (stripped at runtime by hidden-API filtering, so the
binder is not usable from apps). The service wrapper offers
`fullRefreshNoDelay()` (bumps `sys.eink.one_full_mode_timeline` + SurfaceFlinger
flush) and `sendOneFullFrame()` (property bump only — the Rockchip EPD service
watches the property and performs the full refresh). A `SystemProperties.set`
bump of `sys.eink.one_full_mode_timeline` is the fallback when neither method
reflects. Mode constants (`EPD_FULL_GC16` etc.) live in `EinkManager.EinkMode`.

- Native `probeEpdRefresh()` in MainActivity tries, in order, each guarded by
  try/catch and soft-no-op on other hardware:
  1. Boyue-style patched `View.requestEpdMode(EPD_FULL, true)` (covers firmware
     variants that patch `android.view.View`).
  2. `getSystemService("eink")` → reflect `fullRefreshNoDelay()` /
     `sendOneFullFrame()`.
  3. `SystemProperties.set` bump of `sys.eink.one_full_mode_timeline`.
- **Success is persisted** — `nativeRefreshAvailableProvider` backed by a bool
  DBKey (`einkNativeRefreshAvailable`), written once after the first successful
  probe, so launches never re-probe. Failures are NOT persisted: the next
  E-Ink mode toggle re-probes, so firmware updates self-heal.
- **Native refresh replaces the flash overlay by default** when available
  (page turns trigger native refresh every N pages, reusing
  `DBKeys.flashPageInterval`). The flash overlay remains **opt-in** via the
  existing `flashOnPageChange` setting for users who want both.
- **Fallback:** any device where the probe fails (non-Rockchip platforms, or
  firmware variants without the service) automatically falls back to the flash
  overlay — the preset enables `flashOnPageChange` for exactly this case.
- The UI hides native-refresh-related controls when `nativeRefreshAvailableProvider`
  is false (no extra controls shipped yet).

**Files:** `android/app/src/main/kotlin/.../MainActivity.kt`,
`lib/src/utils/platform/eink/epd_refresh.dart`, `reader_flash_overlay.dart`,
`lib/src/utils/platform/eink/eink_mode_providers.dart`,
`lib/src/constants/db_keys.dart`.

**Risk/notes:** verified on a Meebook **M103** over ADB (logcat:
`EinkManager.fullRefreshNoDelay() invoked`). The probe is intentionally
conservative — never switches the panel into a manual update mode, never touches
system auto-update state beyond the documented one-shot full-refresh timeline.

---

## Phase 5 — Settings UX, localization, tests, docs

### 5.1 Disabled-state wiring

- While `einkActive`: Appearance theme picker / theme mode / custom color and the
  reader background-color / animate-page-transitions tiles render disabled with an
  l10n subtitle ("Managed by E-Ink mode").
- The reader settings **sheet** applies the same disabling to its General-tab
  equivalents so the override can't be bypassed mid-read.
- Existing E-Ink group in `reader_settings_screen.dart` gets the toggle shortcut +
  a managed note; every tile keeps its `SettingsHighlightTarget` id and
  `settings_search_registry.dart` entry (pattern already at
  `settings_search_registry.dart:421-447`).

### 5.2 Localization

- New keys in `lib/src/l10n/app_en.arb` (source of truth), `flutter gen-l10n`
  (manual, synthetic-package: false); Weblate handles the other 26 locales.

### 5.3 Tests

- Unit: detection predicate, preset application, `einkActive` derivation, theme
  resolution override.
- Widget: toggle tile, disabled managed tiles, static-progress fallback, instant
  chrome swap.
- Guards: `test/theme/no_hardcoded_colors_test.dart` (tokens via `utils/theme/` —
  exempt), `light_contrast_test.dart` for `einkPaper`.
- Manual matrix: Meebook **M103** (native probe refresh), plain Android tablet
  (probe fails → flash fallback), web + desktop builds (compile, no-op, theme
  not forced).

### 5.4 Docs

Update `docs/architecture/theming-l10n.md` (new theme, forced resolution),
`docs/architecture/reader.md` (chrome/fade/snap gating, refresh control),
`docs/architecture/shared-infrastructure.md` (e-ink utils) per the
docs-architecture maintenance rule.

---

## Constraints & conventions checklist

- [ ] `DBKeys` — append only; enum-backed keys via `SharedPreferenceEnumClientMixin`.
- [ ] `AppTheme` — **append only** (index persistence); never reorder.
- [ ] Frozen reader-engine boundary — all reader changes here are render-only
      (durations, animations, image params); no scroll/position/index math.
- [ ] `flutter gen-l10n` after ARB edits; committed generated files.
- [ ] No hardcoded colors in app UI (guard test); theme colors via tokens.
- [ ] All platform calls guarded (`kIsWeb`, `Platform.isAndroid`, try/catch around
      every reflection probe in `EinkRefreshController.kt`) — web/desktop compile
      and no-op; probe failures are soft no-ops.
- [ ] New settings searchable (registry) + highlightable (targets).
- [ ] Keep the `context.reduceMotion` precedent for every new animation gate.

## Resolved decisions

1. **Toggle OFF leaves applied values in place** — no snapshot/restore; settings
   become editable again and the user's own changes apply.
2. **Default reader mode for e-ink = paged** — the preset writes
   `readerModeKey` → `singleHorizontalLTR`; per-series overrides and the mode
   selector remain free.
3. **Native refresh targets the Meebook M103 specifically** — probe the
   Boyue-style Rockchip `View` mechanism; anything else falls back to the flash
   overlay automatically (preset keeps `flashOnPageChange` enabled for that).
4. **Native refresh replaces the flash by default** — when the probe succeeds,
   page turns use native refresh; the flash overlay stays available as opt-in via
   the existing `flashOnPageChange` setting.
5. **Probe result is persisted** — `nativeRefreshAvailableProvider` is backed by a
   bool DBKey, written once after the first probe, so launches never re-probe.

## Execution order

1. Phase 1 (detection + toggle + preset) — unlocks everything, low risk.
2. Phase 2.1 / 2.2 / 2.3 / 2.4 (motion, chrome, fades, snap) — high impact, low risk.
3. Phase 3 (E-Ink theme + forced resolution).
4. Phase 2.5 / 2.6 (progress indicators, physics) — app-wide polish.
5. Phase 4 (Meebook M103 native refresh + flash fallback) — device-specific win.
6. Phase 5 (disabled-state UI, l10n, tests, docs) — ship-readiness.
