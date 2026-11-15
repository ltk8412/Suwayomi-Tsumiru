// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../routes/router_config.dart';
import '../../../../../utils/entry_page_index.dart';
import '../../../../../utils/entry_pagination.dart';
import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../widgets/desktop/desktop_page_frame.dart';
import '../../../../../widgets/emoticons.dart';
import '../../../../../widgets/paginated_entries.dart';
import '../../../../../widgets/shell/update_banner_state.dart';
import '../../../../manga_book/data/updates/updates_repository.dart';
import '../../../../manga_book/domain/manga/manga_model.dart';
import '../../../../offline/data/server_reachability.dart';
import '../controller/category_library_options.dart';
import '../controller/library_controller.dart';
import '../controller/library_grouping.dart';
import '../controller/library_manga_list.dart';
import 'library_entry_layout.dart';
import 'library_manga_grid_view.dart';

typedef LibrarySection = ({int id, String name});

/// Section header height: the pinned `SliverPersistentHeader` extent, also
/// charged to a page's height budget (block header or running header).
const _sectionHeaderExtent = 40.0;

/// Nominal height of the empty-state `Emoticons` block (title + button) below
/// an empty section's header; charged with the header so the page budget
/// reserves space for it.
const _emptySectionEmoticonsExtent = 96.0;

/// Writes libraryVisibleSectionProvider from scroll position; never drives scrolling from it.
class LibrarySectionsView extends HookConsumerWidget {
  const LibrarySectionsView({
    super.key,
    required this.sections,
    required this.byCategory,
    this.showCounts = false,
  });

  final List<LibrarySection> sections;

  /// True uses category providers; false uses grouped-list providers.
  final bool byCategory;

  final bool showCounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Retain keys across rebuilds so section tracking follows the same elements.
    final headerKeys = useRef(<int, GlobalKey>{});
    for (final s in sections) {
      headerKeys.value.putIfAbsent(s.id, GlobalKey.new);
    }
    headerKeys.value.removeWhere((id, _) => !sections.any((s) => s.id == id));

    final scrollController = useScrollController();

    void trackVisibleSection() {
      if (!scrollController.hasClients) return;
      int? topId;
      double? topY;
      int? firstId;
      double? firstY;
      for (final entry in headerKeys.value.entries) {
        final box =
            entry.value.currentContext?.findRenderObject() as RenderBox?;
        if (box == null || !box.attached) continue;
        final viewport = RenderAbstractViewport.of(box) as RenderBox;
        final viewportTop = viewport.localToGlobal(Offset.zero).dy;
        final y = box.localToGlobal(Offset.zero).dy;
        // The closest header at or above the viewport top is the active pinned section.
        if (y <= viewportTop + 1 && (topY == null || y > topY)) {
          topY = y;
          topId = entry.key;
        }
        if (firstY == null || y < firstY) {
          firstY = y;
          firstId = entry.key;
        }
      }
      final visible = topId ?? firstId;
      if (visible != ref.read(libraryVisibleSectionProvider)) {
        ref.read(libraryVisibleSectionProvider.notifier).update(visible);
      }
    }

    useEffect(() {
      scrollController.addListener(trackVisibleSection);
      // Initial layout emits no scroll event; seed the visible section after layout.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) trackVisibleSection();
      });
      return () => scrollController.removeListener(trackVisibleSection);
      // Group changes shift the section at the current offset.
    }, [scrollController, sections.length]);

    // Resolve every section's entries once so the page blocks and the page
    // builder share one snapshot of the flattened flow.
    final useCategoryOptions = ref.watch(useCategoryLibraryOptionsProvider);
    final itemsBySection = <List<MangaDto>>[];
    final showEmptyBySection = <bool>[];
    final startsBySection = <int>[];
    final blocks = <EntryBlock>[];
    var entryCount = 0;
    for (final section in sections) {
      final listAsync = byCategory
          ? ref.watch(
              categoryMangaListWithQueryAndFilterProvider(
                categoryId: section.id,
              ),
            )
          : ref.watch(
              groupedMangaListWithQueryAndFilterProvider(tabId: section.id),
            );
      final items = listAsync.value ?? const <MangaDto>[];
      final showEmpty =
          byCategory && listAsync.value != null && useCategoryOptions;
      itemsBySection.add(items);
      showEmptyBySection.add(showEmpty);
      startsBySection.add(entryCount);
      if (items.isEmpty) {
        if (showEmpty) {
          // Empty sections render header + emoticons but no entries; the
          // nominal extents keep their space in the flow.
          blocks.add((
            start: entryCount,
            count: 0,
            headerExtent: _sectionHeaderExtent + _emptySectionEmoticonsExtent,
          ));
        }
        continue;
      }
      blocks.add((
        start: entryCount,
        count: items.length,
        headerExtent: _sectionHeaderExtent,
      ));
      entryCount += items.length;
    }

    // Reset to page 1 when the debounced query or the filter/sort options
    // change; the mount run is skipped so a remembered page survives tab
    // switches.
    final debouncedQuery = ref.watch(libraryQueryDebouncedProvider);
    final options = ref.watch(effectiveCategoryLibraryOptionsProvider(null));
    final isFirstPageReset = useRef(true);
    useEffect(() {
      if (isFirstPageReset.value) {
        isFirstPageReset.value = false;
        return;
      }
      // Effects run during build, when provider mutation is forbidden.
      Future.microtask(() {
        if (!context.mounted) return;
        final notifier = ref.read(entryPageIndexProvider.notifier);
        if (notifier.pageFor('sections') != 1) {
          notifier.setPage('sections', 1);
        }
      });
      return;
    }, [debouncedQuery, options]);

    // A page flip swaps headers without a scroll event, so re-track after the
    // new page lands.
    final currentPage = ref.watch(
      entryPageIndexProvider.select((pages) => pages['sections'] ?? 1),
    );
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) trackVisibleSection();
      });
      return;
    }, [currentPage]);

    Widget sectionHeader(LibrarySection section, int itemCount) =>
        SliverPersistentHeader(
          pinned: true,
          delegate: _SectionHeaderDelegate(
            headerKey: headerKeys.value[section.id]!,
            title: showCounts ? '${section.name} ($itemCount)' : section.name,
            // Opaque headers hide rows scrolling underneath.
            background: context.theme.colorScheme.surface,
            foreground: context.theme.colorScheme.primary,
          ),
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = libraryEntryLayout(context, ref, constraints.maxWidth);
        return PaginatedEntries(
          pageKey: 'sections',
          blocks: blocks,
          columns: layout.columns,
          rowExtent: layout.rowExtent,
          rowSpacing: layout.rowSpacing,
          runningHeaderExtent: _sectionHeaderExtent,
          pageBuilder: (context, start, end) {
            final slivers = <Widget>[];
            for (var i = 0; i < sections.length; i++) {
              final section = sections[i];
              final items = itemsBySection[i];
              final sectionStart = startsBySection[i];
              final sectionEnd = sectionStart + items.length;
              if (items.isEmpty) {
                // Empty sections occupy a zero-width point in the flow: show
                // them when that point falls inside this window (or on the
                // only page when there are no entries at all).
                final inWindow =
                    entryCount == 0 ||
                    (sectionStart >= start && sectionStart < end) ||
                    (sectionStart == entryCount && end == entryCount);
                if (showEmptyBySection[i] && inWindow) {
                  slivers.add(sectionHeader(section, items.length));
                  slivers.add(
                    SliverToBoxAdapter(
                      child: Emoticons(
                        title: context.l10n.noCategoryMangaFound,
                      ),
                    ),
                  );
                }
                continue;
              }
              if (sectionStart >= end || sectionEnd <= start) continue;
              // Every intersecting section shows exactly one header: its own
              // when it begins in this window, or again as the running
              // header at the window top when the window starts mid-section.
              slivers.add(sectionHeader(section, items.length));
              final from = start > sectionStart ? start - sectionStart : 0;
              final to = end < sectionEnd ? end - sectionStart : items.length;
              if (to > from) {
                slivers.add(
                  LibraryMangaSliver(
                    items: items.sublist(from, to),
                    onOpen: (manga) => MangaRoute(
                      mangaId: manga.id,
                      categoryId: byCategory ? section.id : null,
                    ).push(context),
                    linkLocationFor: (manga) => MangaRoute(
                      mangaId: manga.id,
                      categoryId: byCategory ? section.id : null,
                    ).location,
                  ),
                );
              }
            }
            return RefreshIndicator(
              onRefresh: () async {
                ref.read(viewOfflineNowProvider.notifier).set(false);
                ref.read(serverUnreachableProvider.notifier).set(false);
                ref.read(updateOptimisticProvider.notifier).arm();
                unawaited(
                  ref
                      .read(updatesRepositoryProvider)
                      .fetchUpdates()
                      .catchError((Object _) {}),
                );
                ref.invalidate(libraryMangaListProvider);
                await ref.read(libraryMangaListProvider.future);
              },
              // Sections that finish loading change the extent without a scroll event.
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (_) {
                  trackVisibleSection();
                  return false;
                },
                child: CustomScrollView(
                  controller: scrollController,
                  // Paginated pages fit the viewport exactly, so the scroll
                  // view must stay draggable for pull-to-refresh.
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: slivers,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SectionHeaderDelegate({
    required this.headerKey,
    required this.title,
    required this.background,
    required this.foreground,
  });

  final GlobalKey headerKey;
  final String title;
  final Color background;
  final Color foreground;

  static const _height = _sectionHeaderExtent;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      key: headerKey,
      height: _height,
      color: background,
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsets.symmetric(horizontal: 8)
          .onDesktopPageLine(context),
      child: Text(
        title,
        overflow: TextOverflow.ellipsis,
        style: context.theme.textTheme.titleSmall?.copyWith(color: foreground),
      ),
    );
  }

  @override
  bool shouldRebuild(_SectionHeaderDelegate old) =>
      old.title != title ||
      old.background != background ||
      old.foreground != foreground;
}
