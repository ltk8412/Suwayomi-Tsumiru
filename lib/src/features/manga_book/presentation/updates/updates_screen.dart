// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../constants/app_sizes.dart';
import '../../../../constants/db_keys.dart';
import '../../../../routes/router_config.dart';
import '../../../../utils/entry_page_index.dart';
import '../../../../utils/entry_pagination.dart';
import '../../../../utils/extensions/custom_extensions.dart';
import '../../../../utils/hooks/paging_controller_hook.dart';
import '../../../../utils/motion/reduce_motion.dart';
import '../../../../widgets/custom_circular_progress_indicator.dart';
import '../../../../widgets/desktop/desktop_page_frame.dart';
import '../../../../widgets/desktop/desktop_top_bar.dart';
import '../../../../widgets/emoticons.dart';
import '../../../../widgets/inline_retry_row.dart';
import '../../../../widgets/paginated_entries.dart';
import '../../../library/presentation/library/controller/library_controller.dart';
import '../../../library/presentation/library/widgets/desktop_library_panels.dart';
import '../../../library/presentation/library/widgets/desktop_library_toolbar.dart';
import '../../../quick_open/presentation/unified_search/desktop_search_field.dart';
import '../../../quick_open/presentation/unified_search/phone_search_view.dart';
import '../../../quick_open/presentation/unified_search/unified_search_providers.dart';
import '../../../settings/presentation/appearance/widgets/grid_cover_width_slider/grid_cover_width_slider.dart';
import '../../../settings/presentation/library/widgets/persistent_search_bar/persistent_search_bar.dart';
import '../../../settings/presentation/syncyomi/syncyomi_sync.dart';
import '../../data/updates/updates_repository.dart';
import '../../domain/chapter/chapter_model.dart';
import '../../domain/chapter/graphql/__generated__/fragment.graphql.dart';
import '../../domain/updates/updates_grouping.dart';
import '../../domain/updates/updates_row_patch.dart';
import '../../widgets/chapter_actions/multi_chapters_actions_bottom_app_bar.dart';
import '../../widgets/update_status_fab.dart';
import '../../widgets/update_status_popup_menu.dart';
import '../manga_details/controller/manga_details_controller.dart';
import '../manga_details/widgets/chapter_selection_header.dart';
import '../reader/controller/reader_controller.dart';
import 'controller/updates_filter_controller.dart';
import 'controller/updates_grouping_controller.dart';
import 'widgets/chapter_manga_grouped_tile.dart';
import 'widgets/chapter_manga_list_tile.dart';
import 'widgets/updates_filter.dart';
import 'widgets/updates_filter_content.dart';
import 'widgets/updates_grid_card.dart';
import 'widgets/updates_row_actions.dart';

const _kUpdatesCardSubtitleExtent = 22.0;

/// Rendered height of `_dateHeading`, charged against the page budget for
/// every date heading (including the running heading of a mid-day page).
///
/// Phone: a one-line-title `ListTile` hits its default target tile height of
/// 56 px (the `bodyLarge` title line of 24 px plus `minVerticalPadding` of
/// 8 px per side stays below it). Desktop: the same 24 px text line inside
/// the heading's 16+8 px contentPadding, i.e. 48 px. Budgeting the taller
/// phone figure keeps pages inside the viewport on both shells.
const kUpdatesDateHeadingExtent = 56.0;

/// Nominal height of one `ChapterMangaListTile` row: 8 px vertical padding
/// around the tallest common child — the 56×80 cover (a two-line title plus
/// one-line chapter name column tops out at 76 px, under the cover).
const _kUpdatesListTileExtent = 96.0;

/// Nominal height of a collapsed `ChapterMangaGroupedTile`: the list row
/// plus the head tile's "Show N more" line (2 px top padding + a 16 px label
/// row) once a two-line title pushes the text column past the cover — 94 px
/// of content plus 16 px padding.
const _kUpdatesGroupedTileExtent = 110.0;

/// Nominal height of an expanded `ChapterMangaGroupedTile`: the collapsed
/// row plus two tail rows. A tail row is 6 px padding + ~24 px of content on
/// phones and gains ~40 px of hover action buttons on the desktop shell, so
/// the budget uses the taller desktop figure (~52 px per tail). Groups with
/// more visible tails run taller; the page surface stays scrollable as the
/// safety valve.
const _kUpdatesExpandedGroupedTileExtent = 214.0;

Widget _dateHeading(BuildContext context, String label, {bool first = false}) {
  final desktop = isOnDesktopPage(context);
  return ListTile(
    contentPadding: desktop
        ? const EdgeInsetsDirectional.fromSTEB(
            16,
            16,
            24,
            8,
          ).onDesktopPageLine(context, top: first)
        : null,
    minTileHeight: desktop ? 0 : null,
    minVerticalPadding: desktop ? 0 : null,
    title: Text(label),
  );
}


Widget _lastUpdatedLine(BuildContext context, String lastUpdated) => Padding(
  padding: const EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 8,
  ).onDesktopPageLine(context, top: true),
  child: Text(
    context.l10n.libraryLastUpdated(int.parse(lastUpdated).toTimeAgo(context)),
    style: context.textTheme.bodyMedium?.copyWith(
      fontStyle: FontStyle.italic,
      color: context.theme.colorScheme.onSurfaceVariant,
    ),
  ),
);

class _UpdatesPagedList extends StatefulWidget {
  const _UpdatesPagedList({
    required this.controller,
    required this.groupingMode,
    required this.displayMode,
    required this.gridWidth,
    required this.fixedColumns,
    required this.selectedChapters,
    required this.selectionAnchor,
    required this.getGeneration,
    required this.screenContext,
    required this.resetList,
    required this.refetchChapter,
    required this.lastUpdatedAboveList,
  });

  final ServerPagingController<ChapterWithMangaDto> controller;
  final UpdatesGroupingMode groupingMode;
  final UpdatesDisplayMode displayMode;
  final double gridWidth;
  final int fixedColumns;
  final ValueNotifier<Map<int, ChapterDto>> selectedChapters;
  final ValueNotifier<int?> selectionAnchor;
  final ValueGetter<int> getGeneration;
  final BuildContext screenContext;
  final VoidCallback resetList;
  final Future<ChapterDto?> Function(int chapterId) refetchChapter;

  final bool lastUpdatedAboveList;

  @override
  State<_UpdatesPagedList> createState() => _UpdatesPagedListState();
}

class _UpdatesPagedListState extends State<_UpdatesPagedList> {
  // Cache by pages identity, not items (a fresh flattened list), to group once per page set rather than per row.
  List<List<ChapterWithMangaDto>>? _memoPages;
  List<ChapterWithMangaDto>? _memoItems;
  List<UpdatesGroupedEntry>? _memoGroups;
  Map<int, int>? _memoHeadIndex;
  Set<int>? _memoHeaderIndices;
  Map<int, UpdatesDaySection>? _memoSections;

  ({
    List<ChapterWithMangaDto> items,
    List<UpdatesGroupedEntry> groups,
    Map<int, int> headIndex,
    Set<int> headerIndices,
    Map<int, UpdatesDaySection> sections,
  })
  _groupingFor(List<List<ChapterWithMangaDto>>? pages) {
    if (_memoPages != null && identical(_memoPages, pages)) {
      return (
        items: _memoItems!,
        groups: _memoGroups!,
        headIndex: _memoHeadIndex!,
        headerIndices: _memoHeaderIndices!,
        sections: _memoSections!,
      );
    }
    final items = [
      for (final page in pages ?? <List<ChapterWithMangaDto>>[]) ...page,
    ];
    final groups = groupUpdatesForDisplay(items);
    final headIndex = headFlatIndexToDisplayIndex(items, groups);
    final headerIndices = dateHeaderIndices(items);
    final sections = {
      for (final section in groupUpdatesByDay(items, groups))
        section.headerFlatIndex: section,
    };
    _memoPages = pages;
    _memoItems = items;
    _memoGroups = groups;
    _memoHeadIndex = headIndex;
    _memoHeaderIndices = headerIndices;
    _memoSections = sections;
    return (
      items: items,
      groups: groups,
      headIndex: headIndex,
      headerIndices: headerIndices,
      sections: sections,
    );
  }

  Future<void> _updatePair(ChapterWithMangaDto item) async {
    final chapter = await widget.refetchChapter(item.id);
    if (!widget.screenContext.mounted) return;
    widget.controller.mapItems(
      (row) => row.id != item.id
          ? row
          : row.copyWith(
              user: row.user.copyWith(
                isRead: (chapter?.user.isRead ?? false) || row.user.isRead,
                isDownloaded: chapter?.user.isDownloaded,
                lastPageRead: chapter?.user.lastPageRead,
              ),
            ),
    );
  }

  Future<void> _refreshManga(int mangaId) => _refreshMangas({mangaId});

  Future<void> _refreshMangas(
    Set<int> mangaIds, {
    bool freshWins = false,
  }) async {
    final startGeneration = widget.getGeneration();
    final ids = [
      for (final row in widget.controller.items ?? <ChapterWithMangaDto>[])
        if (mangaIds.contains(row.mangaId)) row.id,
    ];
    final chapters = await fetchChaptersInBatches(
      ids: ids,
      fetch: widget.refetchChapter,
    );
    if (!widget.screenContext.mounted ||
        widget.getGeneration() != startGeneration) {
      return;
    }
    final controller = widget.controller;
    var pages = controller.pages ?? <List<ChapterWithMangaDto>>[];
    for (final mangaId in mangaIds) {
      pages = [
        for (final page in pages)
          patchRowsForManga(
            rows: page,
            mangaId: mangaId,
            chapters: chapters,
            freshWins: freshWins,
          ),
      ];
    }
    controller.value = controller.value.copyWith(pages: pages);
  }

  void _toggleSelect(ChapterDto val) {
    if ((val.id).isNull) return;
    widget.selectedChapters.value = widget.selectedChapters.value.toggleKey(
      val.id,
      val,
    );
  }

  Widget _buildItem(
    BuildContext context,
    PagingState<int, ChapterWithMangaDto> state,
    int flatIndex,
  ) {
    final grouping = _groupingFor(state.pages);
    final items = grouping.items;

    if (widget.groupingMode != UpdatesGroupingMode.disabled) {
      // A missing head index is already rendered in its group, so suppress the row.
      final displayIndex = grouping.headIndex[flatIndex];
      if (displayIndex == null) return const SizedBox.shrink();

      return _buildGroupTile(context, grouping.groups[displayIndex], items);
    }

    final item = items[flatIndex];
    return ChapterMangaListTile(
      chapterWithMangaDto: item,
      updatePair: () => _updatePair(item),
      refreshManga: () => _refreshManga(item.mangaId),
      refreshRowActions: (mangaIds) =>
          _refreshMangas(mangaIds, freshWins: true),
      isSelected: widget.selectedChapters.value.containsKey(item.id),
      canTapSelect: widget.selectedChapters.value.isNotEmpty,
      toggleSelect: (val) => _toggleSelect(val),
      selectedChapters: widget.selectedChapters,
      selectionAnchor: widget.selectionAnchor,
      orderedChapters: items,
      desktop: context.usesDesktopShell,
    );
  }

  Widget _buildGroupTile(
    BuildContext context,
    UpdatesGroupedEntry group,
    List<ChapterWithMangaDto> items,
  ) {
    return ChapterMangaGroupedTile(
      head: group.head,
      tail: group.tail,
      updatePairFor: (chapter) =>
          () => _updatePair(chapter),
      refreshManga: () => _refreshManga(group.head.mangaId),
      refreshRowActions: (mangaIds) =>
          _refreshMangas(mangaIds, freshWins: true),
      isSelectedFor: (chapter) =>
          widget.selectedChapters.value.containsKey(chapter.id),
      canTapSelect: widget.selectedChapters.value.isNotEmpty,
      toggleSelect: (val) => _toggleSelect(val),
      selectedChapters: widget.selectedChapters,
      selectionAnchor: widget.selectionAnchor,
      orderedChapters: items,
      desktop: context.usesDesktopShell,
    );
  }

  Widget _buildGridCard(
    BuildContext context,
    UpdatesGroupedEntry group,
    List<ChapterWithMangaDto> items,
  ) => UpdatesGridCard(
    group: group,
    refreshManga: () => _refreshManga(group.head.mangaId),
    refreshRowActions: (mangaIds) => _refreshMangas(mangaIds, freshWins: true),
    isSelectedFor: (chapter) =>
        widget.selectedChapters.value.containsKey(chapter.id),
    canTapSelect: widget.selectedChapters.value.isNotEmpty,
    toggleSelect: (val) => _toggleSelect(val),
    selectedChapters: widget.selectedChapters,
    selectionAnchor: widget.selectionAnchor,
    orderedChapters: items,
  );

  Widget _wrapWithDateHeader(
    BuildContext context,
    List<ChapterWithMangaDto> items,
    int flatIndex,
    Widget tile,
    Set<int> headerIndices, {
    bool first = false,
  }) {
    if (!headerIndices.contains(flatIndex)) return tile;
    final currentDate = int.tryParse(items[flatIndex].fetchedAt);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dateHeading(
          context,
          currentDate.toDaysAgoFromSeconds(context),
          first: first,
        ),
        tile,
      ],
    );
  }

  /// One block per day section: blocks split exactly where a display entry's
  /// date heading renders — the same points `groupUpdatesByDay` starts a new
  /// section — so grouped entries never split across pages and each heading
  /// (including the running heading of a mid-day page) is charged against the
  /// page height budget as [kUpdatesDateHeadingExtent].
  static List<EntryBlock> _dayBlocks({
    required List<ChapterWithMangaDto> items,
    required Set<int> headerIndices,
    required List<int> flatIndices,
  }) {
    bool hasHeading(int flat) =>
        headerIndices.contains(flat) &&
        int.tryParse(items[flat].fetchedAt) != null;
    if (flatIndices.isEmpty) return const [];
    final blocks = <EntryBlock>[];
    var start = 0;
    var header = hasHeading(flatIndices[0]) ? kUpdatesDateHeadingExtent : 0.0;
    for (var i = 1; i < flatIndices.length; i++) {
      if (!hasHeading(flatIndices[i])) continue;
      blocks.add((start: start, count: i - start, headerExtent: header));
      start = i;
      header = kUpdatesDateHeadingExtent;
    }
    blocks.add((
      start: start,
      count: flatIndices.length - start,
      headerExtent: header,
    ));
    return blocks;
  }

  /// The block strictly containing [index], or null when [index] sits on a
  /// block boundary. Blocks are contiguous and ascending.
  static EntryBlock? _blockContaining(List<EntryBlock> blocks, int index) {
    for (final block in blocks) {
      if (block.start >= index) return null;
      if (index < block.start + block.count) return block;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PagingListener(
      controller: widget.controller,
      builder: (context, state, fetchNextPage) {
        final grouping = _groupingFor(state.pages);
        final items = grouping.items;
        final error = state.error;
        if (items.isEmpty) {
          if (error != null) {
            return Emoticons(
              title: error.toString(),
              button: TextButton(
                onPressed: widget.resetList,
                child: Text(context.l10n.retry),
              ),
            );
          }
          // Nothing fetched yet (first page still loading or just reset).
          if (state.pages == null) {
            return const CenterTsumiruShimmerIndicator();
          }
          return Emoticons(
            title: context.l10n.noUpdatesFound,
            button: TextButton(
              onPressed: widget.resetList,
              child: Text(context.l10n.refresh),
            ),
          );
        }

        // The compact shell has no display-mode control and always rendered
        // the chapter list; only the desktop shell honours the setting.
        final displayMode =
            context.usesDesktopShell
                ? widget.displayMode
                : UpdatesDisplayMode.list;
        // Grid renders one card per (manga, day) group; the list renders
        // groups unless grouping is disabled.
        final grouped =
            displayMode == UpdatesDisplayMode.grid ||
            widget.groupingMode != UpdatesGroupingMode.disabled;
        final flatIndices = grouped
            ? <int>[...grouping.headIndex.keys]
            : <int>[for (var i = 0; i < items.length; i++) i];
        // One block per day section: blocks split exactly where
        // groupUpdatesByDay starts a new section — at the display entry whose
        // date heading renders — so grouped entries never split across pages
        // and every heading is charged against the page height budget.
        final blocks = _dayBlocks(
          items: items,
          headerIndices: grouping.headerIndices,
          flatIndices: flatIndices,
        );

        Widget buildPage(
          BuildContext context,
          int start,
          int end,
          int columns,
        ) {
          final builders = <WidgetBuilder>[];

          bool hasHeading(int flat) =>
              grouping.headerIndices.contains(flat) &&
              int.tryParse(items[flat].fetchedAt) != null;
          String labelFor(int flat) =>
              int.tryParse(items[flat].fetchedAt).toDaysAgoFromSeconds(context);

          // The heading at the very top of the page sits flush under the
          // desktop page line (or the fixed last-updated line above the
          // list); later headings keep their regular top padding.
          bool topHeading() => builders.isEmpty && !widget.lastUpdatedAboveList;

          // A page starting mid-day repeats that day's heading at the top.
          final midDay = _blockContaining(blocks, start);
          if (midDay != null &&
              start > midDay.start &&
              midDay.headerExtent > 0) {
            final first = topHeading();
            final headerFlat = flatIndices[midDay.start];
            builders.add(
              (context) =>
                  _dateHeading(context, labelFor(headerFlat), first: first),
            );
          }

          if (displayMode == UpdatesDisplayMode.grid) {
            // The desktop listing's grid composition, scoped to the window:
            // day headings as full-width rows, cover cards packed into rows
            // that restart after every heading.
            final gridDelegate = mangaCoverUniformGridDelegate(
              widget.gridWidth,
              widget.fixedColumns,
              titleBelow: true,
              extraTitleExtent: _kUpdatesCardSubtitleExtent,
            );
            final bleed = isOnDesktopPage(context)
                ? kMangaCoverCardInset / 2
                : 0.0;
            var row = <int>[];
            // Rows directly under a heading (or the page top) skip the
            // inter-row top padding, like a section's first row did.
            var firstRow = true;
            void flushRow({required bool endOfSection}) {
              if (row.isEmpty) return;
              final rowStart = row.first;
              final count = row.length;
              builders.add(
                (context) => DesktopBoxBleed.coverGrid(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: firstRow ? 0 : bleed,
                      bottom: endOfSection ? 0 : 2.0,
                    ),
                    child: GridView.builder(
                      padding: EdgeInsets.zero,
                      primary: false,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: gridDelegate,
                      itemCount: count,
                      itemBuilder: (context, index) => _buildGridCard(
                        context,
                        grouping.groups[grouping
                            .headIndex[flatIndices[rowStart + index]]!],
                        items,
                      ),
                    ),
                  ),
                ),
              );
              row = <int>[];
              firstRow = false;
            }

            for (var i = start; i < end; i++) {
              final flat = flatIndices[i];
              if (hasHeading(flat)) {
                flushRow(endOfSection: true);
                final first = topHeading();
                builders.add(
                  (context) =>
                      _dateHeading(context, labelFor(flat), first: first),
                );
                firstRow = true;
              }
              row.add(i);
              if (row.length >= columns) flushRow(endOfSection: false);
            }
            flushRow(endOfSection: true);
          } else {
            for (var i = start; i < end; i++) {
              final flat = flatIndices[i];
              final first = topHeading();
              builders.add(
                (context) => _wrapWithDateHeader(
                  context,
                  items,
                  flat,
                  _buildItem(context, state, flat),
                  grouping.headerIndices,
                  first: first,
                ),
              );
            }
          }

          final page = CustomScrollView(
            slivers: [
              SliverList.builder(
                itemCount: builders.length,
                itemBuilder: (context, index) => builders[index](context),
              ),
            ],
          );
          // Fetch errors and fill-in progress sit at the bottom of the page
          // area, directly above the pager bar.
          final pageError = state.error;
          final filling = state.isLoading;
          if (pageError == null && !filling) return page;
          return Stack(
            fit: StackFit.expand,
            children: [
              page,
              if (pageError != null)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: InlineRetryRow(
                    message: pageError.toString(),
                    onRetry: fetchNextPage,
                  ),
                ),
              if (filling)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Center(child: MiniCircularProgressIndicator()),
                ),
            ],
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final int columns;
            final double rowExtent;
            final double rowSpacing;
            if (displayMode == UpdatesDisplayMode.grid) {
              // Mirror the width mangaCoverUniformGridDelegate lays out at:
              // the page scroll view reserves the desktop scrollbar gutter,
              // and each grid row bleeds kMangaCoverCardInset/2 past it on
              // desktop pages. titleExtent matches titleBelow plus the card
              // subtitle extent.
              final bleed = isOnDesktopPage(context)
                  ? kMangaCoverCardInset / 2
                  : 0.0;
              final gutter = desktopScrollReservesGutter(context)
                  ? kDesktopScrollbarGutter
                  : 0.0;
              final layout = coverGridPageLayout(
                width: constraints.maxWidth - gutter + bleed * 2,
                coverMinWidth: widget.gridWidth,
                fixedColumns: widget.fixedColumns,
                titleExtent: kGridTitleExtent + _kUpdatesCardSubtitleExtent,
              );
              columns = layout.columns;
              rowExtent = layout.rowExtent;
              rowSpacing = 2.0;
            } else {
              columns = 1;
              rowExtent = switch (widget.groupingMode) {
                UpdatesGroupingMode.disabled => _kUpdatesListTileExtent,
                UpdatesGroupingMode.collapsed => _kUpdatesGroupedTileExtent,
                UpdatesGroupingMode.expanded =>
                  _kUpdatesExpandedGroupedTileExtent,
              };
              rowSpacing = 0;
            }
            return PaginatedEntries(
              pageKey: 'updates',
              blocks: blocks,
              columns: columns,
              rowExtent: rowExtent,
              rowSpacing: rowSpacing,
              runningHeaderExtent: kUpdatesDateHeadingExtent,
              hasNextPage: state.hasNextPage,
              onLoadMore: fetchNextPage,
              pageBuilder: (context, start, end) =>
                  buildPage(context, start, end, columns),
            );
          },
        );
      },
    );
  }
}

/// Hold the autoDispose provider during refresh so an unobserved request cannot tear down mid-fetch.
Future<ChapterDto?> refetchChapter(WidgetRef ref, int chapterId) async {
  final provider = chapterProvider(chapterId: chapterId);
  final keepAlive = ref.listenManual(provider, (_, _) {});
  try {
    return await ref.refresh(provider.future);
  } finally {
    keepAlive.close();
  }
}

/// Stops before the first known ID; boundaryFound lets callers stop fetching older pages.
({List<ChapterWithMangaDto> items, bool boundaryFound})
extractNewUpdatesFromPage(
  List<ChapterWithMangaDto> nodes,
  Set<int> existingIds,
) {
  final knownIndex = nodes.indexWhere((c) => existingIds.contains(c.id));
  if (knownIndex >= 0) {
    return (items: nodes.take(knownIndex).toList(), boundaryFound: true);
  }
  return (items: nodes.toList(), boundaryFound: false);
}

class UpdatesScreen extends HookConsumerWidget {
  const UpdatesScreen({super.key});

  // Drop replies after a refresh/filter reset so results from different lists cannot interleave.
  Future<ServerPage<ChapterWithMangaDto>> _fetchPage(
    UpdatesRepository repository,
    int pageKey,
    UpdatesFilter filter,
  ) async {
    final page = await repository.getRecentChaptersPage(
      pageNo: pageKey,
      filter: filter,
    );
    if (page == null) {
      return (items: <ChapterWithMangaDto>[], hasNextPage: false);
    }
    return (items: page.nodes, hasNextPage: page.hasNextPage);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use the screen context after awaits; row contexts can be recycled during scroll.
    final screenContext = context;
    final updatesRepository = ref.watch(updatesRepositoryProvider);
    final lastUpdated = ref.watch(libraryLastUpdatedProvider).value;
    final selectedChapters = useState<Map<int, ChapterDto>>({});
    final selectionAnchor = useState<int?>(null);
    final filter = ref.watch(updatesFilterProvider);
    final hasActiveFilters = ref.watch(updatesHasActiveFiltersProvider);
    final groupingMode =
        ref.watch(updatesGroupingModeProvider) ?? UpdatesGroupingMode.collapsed;
    final displayMode =
        ref.watch(updatesDisplayModeProvider) ?? UpdatesDisplayMode.grid;
    final gridWidth =
        ref.watch(gridMinWidthProvider) ??
        DBKeys.gridMangaCoverMinWidth.initial as double;
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final fixedColumns =
        (isLandscape
            ? ref.watch(libraryLandscapeColumnsProvider)
            : ref.watch(libraryPortraitColumnsProvider)) ??
        0;
    final phone = context.windowSizeClass == WindowSizeClass.compact;
    final persistentBox =
        phone && ref.watch(libraryPersistentSearchBarProvider).ifNull();
    // The fetcher is captured once; read current filters through a holder to avoid stale closures.
    final latestFilter = useRef(filter);
    latestFilter.value = filter;
    final controller = useServerPagingController<ChapterWithMangaDto>(
      firstPageKey: 0,
      // Read the repository per request because endpoint switches dispose the captured client.
      fetchPage: (pageKey) => _fetchPage(
        ref.read(updatesRepositoryProvider),
        pageKey,
        latestFilter.value,
      ),
    );
    // List resets invalidate replies from earlier generations.
    final generation = useRef(0);
    final resetList = useCallback(() {
      generation.value++;
      selectedChapters.value = ({});
      selectionAnchor.value = null;
      // Filter changes, refreshes and resyncs restart the display at page 1.
      ref.read(entryPageIndexProvider.notifier).setPage('updates', 1);
      controller.refresh();
    }, []);
    // Custom covers arrive through meta the cached rows were fetched without.
    final coverRevision = ref.watch(customCoverRevisionProvider);
    final isCoverRevisionMount = useRef(true);
    useEffect(() {
      if (isCoverRevisionMount.value) {
        isCoverRevisionMount.value = false;
        return null;
      }
      resetList();
      return null;
    }, [coverRevision]);
    // Use the running-only socket to detect completion; prepend new rows without losing scroll position.
    final lastRunningUpdates = useRef<bool>(false);
    Future<void> liveUpdate() async {
      final gen = generation.value;
      final existingIds = {
        for (final item in controller.items ?? <ChapterWithMangaDto>[]) item.id,
      };
      final newItems = <ChapterWithMangaDto>[];
      // Cap at three pages; larger backlogs reset instead of prepending many stale entries.
      const maxPages = 3;
      for (var pageNo = 0; pageNo < maxPages; pageNo++) {
        final snapshot = await AsyncValue.guard(
          () => updatesRepository.getRecentChaptersPage(
            pageNo: pageNo,
            filter: latestFilter.value,
          ),
        );
        if (generation.value != gen) return;
        final page = snapshot.asData?.value;
        if (page == null) return;
        final result = extractNewUpdatesFromPage(page.nodes, existingIds);
        newItems.addAll(result.items);
        if (result.boundaryFound) break;
        if (!page.hasNextPage) break;
        if (pageNo == maxPages - 1) {
          resetList();
          return;
        }
      }
      if (newItems.isEmpty || !screenContext.mounted) return;
      // Prepend within the first page to preserve page keys and the next fetch key.
      final pages = controller.pages;
      if (pages == null || pages.isEmpty) return;
      controller.value = controller.value.copyWith(
        pages: [
          [...newItems, ...pages.first],
          ...pages.skip(1),
        ],
      );
    }

    ref.listen(updateRunningSocketProvider, (_, next) {
      final running = next.value;
      if (running == null) return;
      if (lastRunningUpdates.value && !running) {
        liveUpdate();
      }
      lastRunningUpdates.value = running;
    });
    // Skip the mount run to avoid fetching page zero twice; later server-side filter changes reset all pages.
    final isFilterMount = useRef(true);
    useEffect(() {
      if (isFilterMount.value) {
        isFilterMount.value = false;
        return null;
      }
      resetList();
      return null;
    }, [filter]);
    final selecting = selectedChapters.value.isNotEmpty;
    final desktop = context.usesDesktopShell;
    final topBar = showsMergedTopBar(context);
    final pageScope = useMemoized(FocusScopeNode.new);
    useEffect(() => pageScope.dispose, [pageScope]);
    final wasSelecting = usePrevious(selecting);
    useEffect(() {
      if (!desktop) return null;
      if (selecting && wasSelecting != true) pageScope.requestFocus();
      if (!selecting && wasSelecting == true) selectionAnchor.value = null;
      return null;
    }, [selecting]);
    void clearSelection() {
      selectedChapters.value = ({});
      selectionAnchor.value = null;
    }

    final closeSelection = IconButton(
      onPressed: clearSelection,
      icon: const Icon(FluentIcons.dismiss_24_regular),
    );
    final selectionTitle = Text(
      context.l10n.numSelected(selectedChapters.value.length),
    );
    final search = DesktopSearchField(
      query: ref.watch(unifiedSearchQueryProvider),
      onChanged: (value) =>
          ref.read(unifiedSearchQueryProvider.notifier).state = value,
      onNavigate: () =>
          ref.read(unifiedSearchQueryProvider.notifier).state = '',
    );
    final scheme = context.theme.colorScheme;
    final filterButtonKey = useMemoized(GlobalKey.new);
    final displayButtonKey = useMemoized(GlobalKey.new);
    final selectionMoreButtonKey = useMemoized(GlobalKey.new);
    final filterFocus = useMemoized(FocusNode.new);
    final displayFocus = useMemoized(FocusNode.new);
    useEffect(() {
      return () {
        filterFocus.dispose();
        displayFocus.dispose();
      };
    }, [filterFocus, displayFocus]);
    DesktopToolbarBox buildFilterBox(bool compact) => DesktopToolbarBox(
      key: filterButtonKey,
      borderColor: hasActiveFilters ? scheme.primary : null,
      child: InkWell(
        focusNode: filterFocus,
        onTap: () => showAnchoredPanel(
          context: context,
          buttonKey: filterButtonKey,
          focusNode: filterFocus,
          panelWidth: 400,
          child: const UpdatesFilterPanel(),
        ),
        child: Padding(
          padding: compact
              ? const EdgeInsets.all(9)
              : const EdgeInsets.only(left: 12, right: 6),
          child: Row(
            spacing: 8,
            children: [
              const Icon(FluentIcons.filter_24_regular, size: 20),
              if (!compact) Text(context.l10n.filter),
              if (!compact)
                const Icon(FluentIcons.caret_down_24_filled, size: 20),
            ],
          ),
        ),
      ),
    );
    DesktopToolbarBox buildDisplayBox(bool compact) => DesktopToolbarBox(
      key: displayButtonKey,
      child: Tooltip(
        message: context.l10n.display,
        child: InkWell(
          focusNode: displayFocus,
          onTap: () => showAnchoredPanel(
            context: context,
            buttonKey: displayButtonKey,
            focusNode: displayFocus,
            panelWidth: 400,
            child: const UpdatesDisplayPanel(),
          ),
          child: Padding(
            padding: compact
                ? const EdgeInsets.all(9)
                : const EdgeInsets.only(left: 10, right: 6),
            child: Row(
              spacing: 2,
              children: [
                const Icon(FluentIcons.grid_24_regular, size: 20),
                if (!compact)
                  const Icon(FluentIcons.caret_down_24_filled, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
    final updateState = updateStatusOf(
      ref.watch(updateProgressSocketProvider),
      context.l10n.update,
    );
    DesktopToolbarBox buildUpdateBox(bool compact) => DesktopToolbarBox(
      borderColor: updateState.running ? scheme.primary : null,
      child: InkWell(
        onTap: () => toggleLibraryUpdate(ref, updateState.running),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: compact
              ? Icon(
                  updateState.running
                      ? FluentIcons.stop_24_regular
                      : FluentIcons.arrow_clockwise_24_regular,
                  size: 20,
                )
              : Row(
                  spacing: 8,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      updateState.running
                          ? FluentIcons.stop_24_regular
                          : FluentIcons.arrow_clockwise_24_regular,
                      size: 20,
                    ),
                    Text(updateState.label),
                  ],
                ),
        ),
      ),
    );
    DesktopToolbarBox buildUpcomingBox(bool compact) => DesktopToolbarBox(
      child: InkWell(
        onTap: () => const UpcomingRoute().push(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: compact
              ? const Icon(FluentIcons.calendar_month_24_regular, size: 20)
              : Row(
                  spacing: 8,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      FluentIcons.calendar_month_24_regular,
                      size: 20,
                    ),
                    Text(context.l10n.upcoming),
                  ],
                ),
        ),
      ),
    );
    List<Widget> desktopActions(bool compact) => [
      if (compact)
        Tooltip(message: updateState.label, child: buildUpdateBox(true))
      else
        buildUpdateBox(false),
      if (compact)
        Tooltip(
          message: context.l10n.upcoming,
          child: buildUpcomingBox(true),
        )
      else
        buildUpcomingBox(false),
      if (compact)
        Tooltip(message: context.l10n.filter, child: buildFilterBox(true))
      else
        buildFilterBox(false),
      buildDisplayBox(compact),
      IconTheme.merge(
        data: const IconThemeData(size: 20),
        child: SyncYomiSyncButton(onSynced: resetList),
      ),
      IconTheme.merge(
        data: const IconThemeData(size: 20),
        child: const UpdateStatusPopupMenu(),
      ),
    ];
    final actions = <Widget>[
      if (phone && !persistentBox)
        const PhoneSearchEntry(origin: PhoneSearchOrigin.plain),
      if (desktop) ...desktopActions(false) else ...[
        SyncYomiSyncButton(onSynced: resetList),
        IconButton(
          icon: const Icon(FluentIcons.filter_24_regular),
          tooltip: context.l10n.filter,
          color: hasActiveFilters ? scheme.primary : null,
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: RoundedRectangleBorder(
              borderRadius: KBorderRadius.rT16.radius,
            ),
            clipBehavior: Clip.hardEdge,
            builder: (_) => const UpdatesFilterSheet(),
            sheetAnimationStyle: context.motionStyle,
          ),
        ),
        IconButton(
          icon: const Icon(FluentIcons.calendar_month_24_regular),
          tooltip: context.l10n.upcoming,
          onPressed: () => const UpcomingRoute().push(context),
        ),
        const UpdateStatusPopupMenu(),
      ],
    ];
    final selectionHeader = selecting && desktop
        ? ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final loadedChapters = controller.items ?? const <ChapterDto>[];
              return ChapterSelectionHeader(
                selected: selectedChapters.value.values.toList(),
                ordered: loadedChapters,
                bulk: loadedChapters,
                anchorId: selectionAnchor.value,
                desktop: true,
                seriesUrl: null,
                moreButtonKey: selectionMoreButtonKey,
                onClear: clearSelection,
                onSelectAll: () => selectedChapters.value = {
                  for (final c in loadedChapters) c.id: c,
                },
                loadSeriesChapters: (mangaId) =>
                    loadSeriesChapters(ref, mangaId),
                refresh: (online) async => resetList(),
                onSelect: (next, anchorId) {
                  selectedChapters.value = next;
                  selectionAnchor.value = anchorId;
                },
              );
            },
          )
        : null;
    final showLastUpdated =
        lastUpdated != null &&
        !(desktop && selecting) &&
        (int.tryParse(lastUpdated) ?? 0) > 0;
    final scaffold = Scaffold(
      floatingActionButton: selecting || desktop
          ? null
          : const UpdateStatusFab(),
      appBar: selecting && !desktop
          ? (topBar
                ? null
                : AppBar(leading: closeSelection, title: selectionTitle))
          : topBar
          ? null
          : AppBar(
              title: context.usesDesktopShell
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: search,
                      ),
                    )
                  : Text(context.l10n.updates),
              bottom: persistentBox
                  ? const PhoneSearchBoxBottom(origin: PhoneSearchOrigin.plain)
                  : null,
              actions: actions,
            ),
      bottomSheet: selecting && !desktop
          ? MultiChaptersActionsBottomAppBar(
              selectedChapters: selectedChapters,
              afterOptionSelected: () async => resetList(),
            )
          : null,
      body: Column(
        children: [
          ?selectionHeader,
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => resetList(),
              child: Column(
                children: [
                  if (showLastUpdated) _lastUpdatedLine(context, lastUpdated),
                  Expanded(
                    child: _UpdatesPagedList(
                      controller: controller,
                      groupingMode: groupingMode,
                      displayMode: displayMode,
                      gridWidth: gridWidth,
                      fixedColumns: fixedColumns,
                      selectedChapters: selectedChapters,
                      selectionAnchor: selectionAnchor,
                      getGeneration: () => generation.value,
                      screenContext: screenContext,
                      resetList: resetList,
                      refetchChapter: (id) => refetchChapter(ref, id),
                      lastUpdatedAboveList: showLastUpdated,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    Widget content = scaffold;
    if (desktop) {
      content = FocusScope(
        node: pageScope,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape &&
              selecting) {
            clearSelection();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: content,
      );
    }
    if (!topBar) return content;
    if (selecting && !desktop) {
      return TopBarSlot(
        slotKey: 'selection',
        content: DesktopTitleSlot(
          leading: closeSelection,
          title: selectionTitle,
        ),
        minWidth: titleTopBarSlotMinWidth(0),
        child: content,
      );
    }
    return TopBarSlot(
      content: LayoutBuilder(
        builder: (context, constraints) {
          final compact = updatesToolbarIsCompact(
            context,
            constraints,
            updateLabel: updateState.label,
            upcomingLabel: context.l10n.upcoming,
            filterLabel: context.l10n.filter,
          );
          return desktopToolbarRow(
            search: search,
            actions: desktopActions(compact),
            spacedActionCount: 4,
            gap: compact ? 4 : kDesktopTopBarGap,
          );
        },
      ),
      minWidth: updatesTopBarSlotMinWidth(),
      child: content,
    );
  }
}
