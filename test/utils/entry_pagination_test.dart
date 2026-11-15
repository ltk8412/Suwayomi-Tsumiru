// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter_test/flutter_test.dart';
import 'package:tsumiru/src/utils/entry_pagination.dart';

void main() {
  group('pageStartsForBlocks', () {
    test('uniform case fills two rows per page', () {
      // 10 items, 2 columns, 100 px rows in a 250 px budget: two rows (four
      // entries) fit per page.
      final starts = pageStartsForBlocks(
        blocks: [const (start: 0, count: 10, headerExtent: 0.0)],
        columns: 2,
        rowExtent: 100,
        availableHeight: 250,
      );
      expect(starts, [0, 4, 8]);
    });

    test('uniform case: rows fit while the budget lasts', () {
      // 300 px / 100 px rows divides evenly: three rows (six entries) per page
      // under the strict `used + rowExtent + rowSpacing > availableHeight` rule.
      final starts = pageStartsForBlocks(
        blocks: [const (start: 0, count: 10, headerExtent: 0.0)],
        columns: 2,
        rowExtent: 100,
        availableHeight: 300,
      );
      expect(starts, [0, 6]);
    });

    test('block header consumes height and forces a row break', () {
      // Page height fits exactly three rows without a header. The 80 px header
      // fits on the first page but leaves room for only two rows there, and it
      // breaks the partial second row (its entry 2 continues into a fresh row
      // on the next page).
      final withHeader = pageStartsForBlocks(
        blocks: [
          const (start: 0, count: 3, headerExtent: 0.0),
          const (start: 3, count: 6, headerExtent: 80.0),
        ],
        columns: 2,
        rowExtent: 100,
        availableHeight: 300,
      );
      final withoutHeader = pageStartsForBlocks(
        blocks: [
          const (start: 0, count: 3, headerExtent: 0.0),
          const (start: 3, count: 6, headerExtent: 0.0),
        ],
        columns: 2,
        rowExtent: 100,
        availableHeight: 300,
      );
      // With the header the first page holds entries 0..2 (two rows); without
      // it the first page holds entries 0..5 (three rows).
      expect(withHeader, [0, 3]);
      expect(withoutHeader, [0, 6]);
    });

    test('page starting mid-block charges the running header', () {
      // One12-entry block, three two-entry rows of 100 px fit per 300 px page.
      // A page starting mid-block must repeat the section header, which costs
      // one row on that page.
      final withoutRunning = pageStartsForBlocks(
        blocks: [const (start: 0, count: 12, headerExtent: 0.0)],
        columns: 2,
        rowExtent: 100,
        availableHeight: 300,
      );
      final withRunning = pageStartsForBlocks(
        blocks: [const (start: 0, count: 12, headerExtent: 0.0)],
        columns: 2,
        rowExtent: 100,
        availableHeight: 300,
        runningHeaderExtent: 100,
      );
      // Without the running header page two holds six entries (three rows);
      // with it, only four (two rows, after the 100 px repeated header).
      expect(withoutRunning, [0, 6]);
      expect(withRunning, [0, 6, 10]);
    });

    test('a page always holds at least one row', () {
      // A single 500 px row does not fit the 100 px budget, but every page
      // still gets one row (one entry with a single column).
      final starts = pageStartsForBlocks(
        blocks: [const (start: 0, count: 3, headerExtent: 0.0)],
        columns: 1,
        rowExtent: 500,
        availableHeight: 100,
      );
      expect(starts, [0, 1, 2]);
    });

    test('appending entries does not move earlier page starts', () {
      final short = pageStartsForBlocks(
        blocks: [const (start: 0, count: 10, headerExtent: 0.0)],
        columns: 2,
        rowExtent: 100,
        availableHeight: 250,
      );
      final long = pageStartsForBlocks(
        blocks: [const (start: 0, count: 20, headerExtent: 0.0)],
        columns: 2,
        rowExtent: 100,
        availableHeight: 250,
      );
      expect(short, [0, 4, 8]);
      expect(long, [0, 4, 8, 12, 16]);
      expect(long.take(short.length), short);
    });

    test('empty input yields one page starting at 0', () {
      final starts = pageStartsForBlocks(
        blocks: const [],
        columns: 2,
        rowExtent: 100,
        availableHeight: 300,
      );
      expect(starts, [0]);
    });
  });

  group('coverGridPageLayout', () {
    test('derives automatic columns and row extent from the width', () {
      // Mirrors _automaticCoverColumns: floor((400 + 2) / (100 + 2)) == 3.
      final layout = coverGridPageLayout(width: 400, coverMinWidth: 100);
      expect(layout.columns, 3);
      // usable = 400 - 2 * 2 = 396; tile = 132; cover = 132 - 8 = 124;
      // 124 / (2 / 3) + 8 = 194.
      expect(layout.rowExtent, closeTo(194.0, 1e-9));
    });

    test('fixed columns override the automatic count', () {
      final layout = coverGridPageLayout(
        width: 400,
        coverMinWidth: 100,
        fixedColumns: 5,
      );
      expect(layout.columns, 5);
      // usable = 400 - 2 * 4 = 392; tile = 78.4; cover = 70.4;
      // 70.4 / (2 / 3) + 8 = 113.6.
      expect(layout.rowExtent, closeTo(113.6, 1e-9));
    });

    test('row extent matches _coverTileLayout with a title extent', () {
      // Mirrors _coverTileLayout: floor((300 + 2) / (60 + 2)) == 4 columns;
      // usable = 300 - 2 * 3 = 294; tile = 73.5; cover = 65.5;
      // 65.5 / (2 / 3) + 8 + 44 = 150.25.
      final layout = coverGridPageLayout(
        width: 300,
        coverMinWidth: 60,
        titleExtent: 44,
      );
      expect(layout.columns, 4);
      expect(layout.rowExtent, closeTo(150.25, 1e-9));
    });
  });
}
