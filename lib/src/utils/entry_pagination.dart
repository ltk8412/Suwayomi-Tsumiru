// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:math';

import '../constants/app_sizes.dart';

/// A run of consecutive display entries that share one optional full-width
/// header. Blocks are contiguous and cover entries 0..N-1 in order.
typedef EntryBlock = ({int start, int count, double headerExtent});

/// Computes the entry index where each page starts, greedily filling pages.
///
/// Pages are contiguous: the result starts with the start index of the first
/// block (or 0 when there are no blocks) and the last page ends at the total
/// entry count (the sum of all block counts).
List<int> pageStartsForBlocks({
  required List<EntryBlock> blocks,
  required int columns,
  required double rowExtent,
  required double availableHeight,
  double rowSpacing = 0.0,
  double runningHeaderExtent = 0.0,
}) {
  final starts = <int>[];
  // Height consumed on the current page.
  var used = 0.0;
  // Entries placed in the currently open row.
  var rowFill = 0;
  var rowsOnPage = 0;

  // True when [entryIndex] falls strictly inside a block, i.e. a page starting
  // there must repeat that block's header as a running section header.
  bool startsMidBlock(int entryIndex) => blocks.any(
    (b) => b.start < entryIndex && entryIndex < b.start + b.count,
  );

  void beginNewPage(int entryIndex) {
    starts.add(entryIndex);
    used = 0;
    rowFill = 0;
    rowsOnPage = 0;
    if (startsMidBlock(entryIndex)) used += runningHeaderExtent;
  }

  if (blocks.isEmpty) {
    beginNewPage(0);
    return starts;
  }
  beginNewPage(blocks.first.start);

  for (final block in blocks) {
    if (block.count <= 0) continue;
    for (var i = 0; i < block.count; i++) {
      final entryIndex = block.start + i;
      if (i == 0 && block.headerExtent > 0) {
        // The block's header is laid out before its first entry.
        if ((rowsOnPage > 0 || used > 0) &&
            used + block.headerExtent > availableHeight) {
          // The block's own header serves as the page top — no running-header
          // charge.
          beginNewPage(block.start);
        }
        used += block.headerExtent;
        // A header forces a row break; a partial row already paid its full
        // cost.
        rowFill = 0;
      }
      if (rowFill == 0) {
        if (rowsOnPage > 0 &&
            used + rowExtent + rowSpacing > availableHeight) {
          beginNewPage(entryIndex);
        }
        // A row costs its full extent as soon as it opens, regardless of how
        // many entries it ends up holding.
        used += rowExtent + rowSpacing;
        rowsOnPage += 1;
      }
      rowFill += 1;
      if (rowFill == columns) rowFill = 0;
    }
  }
  return starts;
}

/// Column count and tile height for a cover grid, mirroring the layout math of
/// `MangaCoverGridDelegate` / `_coverTileLayout` in `lib/src/constants/app_sizes.dart`.
///
/// Row spacing is NOT part of `rowExtent`; callers pass `rowSpacing`
/// separately.
({int columns, double rowExtent}) coverGridPageLayout({
  required double width,
  required double coverMinWidth,
  int fixedColumns = 0,
  double titleExtent = 0.0,
  double crossAxisSpacing = 2.0,
  double coverInset = kMangaCoverCardInset,
}) {
  final columns =
      fixedColumns > 0
          ? fixedColumns
          : max(
              1,
              ((width + crossAxisSpacing) / (coverMinWidth + crossAxisSpacing))
                  .floor(),
            );
  final usable = max(0.0, width - crossAxisSpacing * (columns - 1));
  final tileWidth = usable / columns;
  final rowExtent =
      max(0.0, tileWidth - coverInset) / kMangaCoverAspectRatio +
      coverInset +
      titleExtent;
  return (columns: columns, rowExtent: rowExtent);
}
