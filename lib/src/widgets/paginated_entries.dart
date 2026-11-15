// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../utils/entry_page_index.dart';
import '../utils/entry_pagination.dart';
import 'entry_pager_bar.dart';
import 'page_flip_surface.dart';

/// Shared body for paginated entry displays: computes the current page window
/// from the available size and entry layout, renders that window via
/// [pageBuilder], flips pages on horizontal swipe (instantly, no animation),
/// and shows an [EntryPagerBar] below the entries area.
class PaginatedEntries extends HookConsumerWidget {
  const PaginatedEntries({
    super.key,
    required this.pageKey,
    required this.blocks,
    required this.columns,
    required this.rowExtent,
    this.rowSpacing = 0.0,
    this.runningHeaderExtent = 0.0,
    required this.pageBuilder,
    this.hasNextPage = false,
    this.onLoadMore,
  });

  /// Unique key per paginated surface, e.g. 'cat-3', 'updates'.
  final String pageKey;

  /// Blocks covering entries 0..N-1 in order.
  final List<EntryBlock> blocks;

  final int columns;
  final double rowExtent;
  final double rowSpacing;
  final double runningHeaderExtent;

  /// Renders the window of entries `[start, end)`.
  final Widget Function(BuildContext context, int start, int end) pageBuilder;

  /// True when more entries may exist beyond the buffered [blocks].
  final bool hasNextPage;

  /// Called when the last buffered page becomes visible and [hasNextPage].
  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadMore = onLoadMore;
    final remembered = ref.watch(entryPageIndexProvider)[pageKey] ?? 1;

    // Page starts from the most recent layout pass. The LayoutBuilder below
    // computes them and publishes them here post-frame: its builder runs
    // during layout, where setState is not allowed. null before first layout.
    final startsState = useState<List<int>?>(null);

    // One onLoadMore call per page-show until the buffered entry count grows.
    // Plain mutable holder: guard changes must never go through setState.
    final guard = useMemoized(_LoadMoreGuard.new);

    var entryCount = 0;
    for (final block in blocks) {
      entryCount += block.count;
    }
    if (entryCount != guard.lastEntryCount) {
      // Reset only on growth ("until more items arrive").
      if (entryCount > guard.lastEntryCount) guard.loadMoreFired = false;
      guard.lastEntryCount = entryCount;
    }

    final publishedStarts = startsState.value;
    final page = _clampPage(remembered, publishedStarts?.length);

    void flipPrevious() {
      if (page > 1) {
        ref.read(entryPageIndexProvider.notifier).setPage(pageKey, page - 1);
      }
    }

    void flipNext() {
      final starts = startsState.value;
      if (starts == null) return;
      if (page < starts.length) {
        ref.read(entryPageIndexProvider.notifier).setPage(pageKey, page + 1);
      } else if (hasNextPage && loadMore != null && !guard.loadMoreFired) {
        guard.loadMoreFired = true;
        loadMore();
      }
    }

    return Column(
      children: [
        Expanded(
          child: PageFlipSurface(
            onPrevious: flipPrevious,
            onNext: flipNext,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final starts = pageStartsForBlocks(
                  blocks: blocks,
                  columns: columns,
                  rowExtent: rowExtent,
                  availableHeight: constraints.maxHeight,
                  rowSpacing: rowSpacing,
                  runningHeaderExtent: runningHeaderExtent,
                );

                // Hand the fresh starts to the pager bar after this frame.
                if (!listEquals(starts, startsState.value)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!listEquals(starts, startsState.value)) {
                      startsState.value = starts;
                    }
                  });
                }

                final pageCount = starts.length;
                final current = _clampPage(remembered, pageCount);

                // Eagerly fetch when the last buffered page is on screen.
                if (hasNextPage &&
                    loadMore != null &&
                    !guard.loadMoreFired &&
                    current >= pageCount) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    // `loadMore` is a final local promoted by the null check
                    // above; the promotion holds inside this closure, so no
                    // re-check is needed here.
                    if (guard.loadMoreFired) return;
                    guard.loadMoreFired = true;
                    loadMore();
                  });
                }

                final start = starts[current - 1];
                final end = current == pageCount ? entryCount : starts[current];
                return SizedBox.expand(child: pageBuilder(context, start, end));
              },
            ),
          ),
        ),
        EntryPagerBar(
          page: page,
          pageCount: hasNextPage ? null : publishedStarts?.length,
          onPrevious: flipPrevious,
          onNext: flipNext,
        ),
      ],
    );
  }

  static int _clampPage(int page, int? pageCount) {
    if (pageCount == null) return page < 1 ? 1 : page;
    if (page < 1) return 1;
    return page > pageCount ? pageCount : page;
  }
}

class _LoadMoreGuard {
  bool loadMoreFired = false;
  int lastEntryCount = -1;
}
