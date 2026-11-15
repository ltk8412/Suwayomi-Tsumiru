# Plan: Paginated entry display

Branch: `feat/paginated-entries-display`

## Goal

Replace continuous / infinite-scroll entry displays with explicit pagination on the
**Library**, **Browse (source catalogue)**, and **Updates** screens. The number of
entries per page is computed from the visible screen area and the existing
entry-size settings. Each page fits the viewport — no scrolling inside a page.

## Confirmed requirements

1. Scope: Library + Browse (source catalogue) + Updates.
2. Entry size: reuse existing settings — "Manga grid size" (cover min width),
   fixed-columns setting, and list-size slider. **No new settings.**
3. Navigation: prev/next bar with a page indicator, plus horizontal swipe to flip
   pages. Swipe flips pages *instead of* switching library categories. Page flips
   have **no transition effect** (instant swap; e-ink friendly).

## Out of scope (unless requested later)

Global-search per-source preview rows, recommends screen, duplicates screen,
migration screen, downloads queue, reader (already paginated), OPDS.

## Behaviour spec

- **One page per screen.** The entries surface renders exactly one page, sized to
  fit the available height. Pull-to-refresh stays (vertical gesture).
- **Page capacity** (pure function of viewport + entry-size settings):
  - Grid modes (`grid`, `comfortableGrid`, `coverOnly`):
    - columns = fixed-columns setting when > 0, else auto from width via the
      existing `_automaticCoverColumns` formula (`app_sizes.dart`) using
      `gridMangaCoverMinWidth`.
    - row height = resolved tile height from `MangaCoverGridDelegate` layout
      (2:3 cover + title extent for the display mode).
    - `rows = floor(availableHeight / (rowHeight + spacing))`, capacity =
      `columns × rows`, minimum 1.
  - List modes: `rows = floor(availableHeight / rowExtent)` where rowExtent is
    `96 × listScale` (list) or `176 × listScale` (descriptiveList).
  - Available height is measured from the actual list viewport
    (LayoutBuilder), after app bars, tab strips, the pager bar, bottom
    navigation and safe areas.
  - Section / date headers consume height from the same budget: pages are
    filled greedily (rows while budget remains; each header costs its height).
- **Pager bar** (new shared widget): prev button, "Page X / Y" indicator, next
  button, styled like the Upcoming screen pager (Fluent chevrons,
  `MaterialLocalizations` prev/next tooltips). Disabled at the ends. Bottom of
  the entries surface, above the bottom navigation.
  - Total `Y` is always known on Library. On Browse/Updates the total is
    unknown until the end is reached; show "Page X" while unknown, switch to
    "Page X / Y" once exhausted.
- **Swipe**: horizontal drag (fling velocity ≥ threshold, or drag distance
  ≥ ~64 px) flips to the next/previous page instantly. No slide animation —
  pages are rendered as slices, so a flip is a plain state change. In the
  Library, category tabs switch by tapping only (TabBarView swipe disabled
  there).
- **Resize/rotation**: capacity is recomputed; the current page index is kept
  and clamped to the new last page.
- **Reset to page 1** when the search query, filters, sort, or the active
  category/tab changes. Page index is remembered per category/tab when
  switching tabs and back.
- Loading, empty (`Emoticons`), and error (`InlineRetryRow`) states are kept.

## Architecture

### New shared pieces

| Piece | Location | Notes |
|---|---|---|
| Page-capacity math + windowing | `lib/src/utils/entry_pagination.dart` | Pure, unit-testable: `gridPageCapacity(...)`, `listPageCapacity(...)`, greedy `computePageStarts(items, costFn)` supporting header costs, `PageWindow` slicing + clamping |
| Pager bar widget | `lib/src/widgets/entry_pager_bar.dart` | `EntryPagerBar({page, pageCount?, onPrevious, onNext})` |
| l10n keys | `lib/src/l10n/app_en.arb` | `pageXofY` ("Page {current} of {total}"), `pageX` ("Page {current}"); regenerate with `flutter gen-l10n` |
| Tab swipe opt-out | `lib/src/widgets/touch_tab_pager.dart` | Add `swipeable` flag (default keeps current behaviour); Library passes `false` so horizontal swipes flip pages |

### Library (in-memory lists, sliced per page)

Files: `category_manga_list.dart`, `library_sections_view.dart`,
`library_screen.dart` (`_GroupedMangaList`), `library_manga_grid_view.dart`.

- Compute capacity from the surface constraints; pass only the current page's
  slice to `LibraryMangaSliver` (unchanged rendering below it).
- Page index in Riverpod state keyed per (surface, category/tab id) so it
  survives tab switches; clamped on items/capacity change; reset on query,
  filter, or sort change.
- **Sections view**: pages follow the natural section order as a flattened
  flow — a page shows section headers plus entries, continuing across section
  boundaries; when a page starts mid-section the section header is repeated as
  a running header. Total pages always known.
- Staggered/non-uniform grid styles: capacity uses the tallest tile height so
  the page always fits (slightly fewer entries on staggered layouts).

### Browse (source catalogue, server pages → display pages)

Files: `source_manga_list_screen.dart`, `source_manga_display_view.dart`,
`source_manga_grid_view.dart`, `source_manga_list_view.dart`,
`source_page_sequence.dart`, `paging_controller_hook.dart`.

- Keep `useServerPagingController` / `SourcePageSequence` to fetch source pages
  into a buffer (source page size is server-defined and cannot change).
- Render display pages of computed capacity as windows over the buffer:
  forward flips beyond the buffer trigger background fetches (existing loading
  indicator while filling); backward flips are instant from the buffer.
- Replace the auto-fetch footer with the pager bar. `InlineRetryRow` stays for
  fetch errors.
- Applies to both grid and list display modes.

### Updates (offset/limit batches → display pages)

Files: `updates_screen.dart`, `updates_repository.dart`, updates controllers.

- Replace the fixed `updatesPageSize = 50` with batches sized from the computed
  capacity; buffer fetched batches exactly like Browse.
- Date headers are laid out with the greedy height budget (same as Library
  sections) using the existing `groupUpdatesForDisplay` / `dateHeaderIndices`
  grouping.
- Replace the auto-fetch footer with the pager bar. Selection mode and row
  actions are unaffected; row swipe actions take precedence over page-flip
  swipe.

## Testing & verification

- Unit: capacity math (width/height/settings → columns/rows/capacity), greedy
  page-start computation with header costs, window slicing and clamping.
- Unit: buffer windowing with a fake fetcher — forward flip fetches, backward
  doesn't, end detection reveals total pages.
- Widget: pager bar disabled states and labels; swipe flips a page without
  animation.
- All existing tests stay green (no new settings → `settings_registry_drift_test`
  untouched); `flutter analyze` and `flutter test` pass.

## Implementation chunks

1. **Core** — `entry_pagination.dart` + tests, `EntryPagerBar` + l10n strings,
   `TouchTabPager.swipeable`. (foundation)
2. **Library** — capacity integration, per-page slicing, sections flattened
   flow, page state, swipe flip. (depends on 1)
3. **Browse** — buffer windowing for source grid/list, fetch-on-demand,
   pager bar. (depends on 1)
4. **Updates** — batch buffering, date-header windowing, pager bar. (depends on 1)
5. **Verification** — full analyze/test pass, resize/clamp audit, no-animation
   audit. (depends on 2–4)

Chunks 2–4 are independent and can proceed in parallel after chunk 1.

## As-built implementation notes

- Fetch batches on Updates stay at 50 rows (`updates_repository.dart`
  unchanged); display pages are computed-size windows over the fetched buffer,
  same as Browse. The display limit requirement holds at the display layer.
- Shared machinery landed as `lib/src/utils/entry_pagination.dart`
  (`EntryBlock`, `pageStartsForBlocks`, `coverGridPageLayout`),
  `lib/src/utils/entry_page_index.dart` (`EntryPageIndex`),
  `lib/src/widgets/paginated_entries.dart` (`PaginatedEntries`),
  `lib/src/widgets/entry_pager_bar.dart`, `lib/src/widgets/page_flip_surface.dart`.
- Library adds `library_entry_layout.dart` (columns / row extent / row spacing
  mirroring the grid delegates); sections view paginates as a flattened flow
  with repeated running headers, exactly as planned.
- Behaviour preserved on the compact shell: Updates honours
  `UpdatesDisplayMode` only on the desktop shell (its control is desktop-only),
  so phones keep the chapter list.
- Rows with variable heights (uncapped titles, staggered grids, expanded
  grouped updates tiles) use conservative nominal extents; the surface stays
  scrollable as a safety valve.

## Risks / notes

- Staggered grid capacity is approximate (bounded by the tallest tile).
- On Browse, crossing a source-page boundary during a forward flip may show a
  brief loading state (source page size is server-defined).
- "Page X / Y" is unavailable until the end has been reached on Browse/Updates.
- Sections view uses a running-header flow; per-section independent paging was
  rejected as heavier UI with wasted space at section boundaries.
