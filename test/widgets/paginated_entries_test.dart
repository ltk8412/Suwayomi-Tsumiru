// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tsumiru/src/l10n/generated/app_localizations.dart';
import 'package:tsumiru/src/utils/entry_page_index.dart';
import 'package:tsumiru/src/widgets/paginated_entries.dart';

/// Pumps a fixed 400×800 harness around [PaginatedEntries] with a single
/// block of [total] entries, recording every `[start, end)` window the
/// page builder is asked to render into [windows].
Future<void> pumpHarness(
  WidgetTester tester, {
  required ProviderContainer container,
  required List<(int, int)> windows,
  required int total,
  bool hasNextPage = false,
  VoidCallback? onLoadMore,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: PaginatedEntries(
            pageKey: 'test',
            blocks: [(start: 0, count: total, headerExtent: 0.0)],
            columns: 2,
            rowExtent: 100,
            pageBuilder: (context, start, end) {
              windows.add((start, end));
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [for (var i = start; i < end; i++) Text('entry $i')],
              );
            },
            hasNextPage: hasNextPage,
            onLoadMore: onLoadMore,
          ),
        ),
      ),
    ),
  );
  // Frame 1: layout computes starts, publishes them + fires the eager
  // load-more post-frame at end of frame. Frame 2: bar renders from the
  // published starts. Explicit pumps — never pumpAndSettle.
  await tester.pump();
}

/// The [IconButton] that wraps the chevron [icon] in the pager bar.
Finder iconButton(IconData icon) => find.ancestor(
  of: find.byIcon(icon),
  matching: find.byType(IconButton),
);

void main() {
  group('PaginatedEntries', () {
    testWidgets('renders only the first page and shows the total label', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final windows = <(int, int)>[];
      var fetches = 0;

      await pumpHarness(
        tester,
        container: container,
        windows: windows,
        total: 40,
        onLoadMore: () => fetches++,
      );

      expect(windows, isNotEmpty);
      final cap = windows.last.$2 - windows.last.$1;
      final pages = (40 + cap - 1) ~/ cap;
      expect(cap, greaterThan(0));
      expect(pages, greaterThanOrEqualTo(2));
      // Only page 1's window was ever rendered.
      expect(windows.every((w) => w.$1 == 0 && w.$2 == cap), isTrue);

      expect(find.text('entry 0'), findsOneWidget);
      expect(find.text('entry $cap'), findsNothing);
      expect(find.text('Page 1 of $pages'), findsOneWidget);
      expect(fetches, 0);
    });

    testWidgets('buttons change the window and label, disabled at the ends', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final windows = <(int, int)>[];

      await pumpHarness(
        tester,
        container: container,
        windows: windows,
        total: 40,
      );

      final cap = windows.last.$2 - windows.last.$1;
      final pages = (40 + cap - 1) ~/ cap;
      final prev = iconButton(FluentIcons.chevron_left_24_regular);
      final next = iconButton(FluentIcons.chevron_right_24_regular);

      // Page 1: previous disabled, total shown.
      expect(tester.widget<IconButton>(prev).onPressed, isNull);
      expect(find.text('Page 1 of $pages'), findsOneWidget);

      await tester.tap(next);
      await tester.pump();
      expect(windows.last.$1, cap);
      expect(windows.last.$2, 2 * cap);
      expect(find.text('Page 2 of $pages'), findsOneWidget);
      expect(tester.widget<IconButton>(prev).onPressed, isNotNull);

      await tester.tap(prev);
      await tester.pump();
      expect(windows.last.$1, 0);
      expect(windows.last.$2, cap);
      expect(find.text('Page 1 of $pages'), findsOneWidget);
      expect(tester.widget<IconButton>(prev).onPressed, isNull);

      for (var i = 0; i < pages - 1; i++) {
        await tester.tap(next);
        await tester.pump();
      }
      expect(find.text('Page $pages of $pages'), findsOneWidget);
      expect(tester.widget<IconButton>(next).onPressed, isNull);
      expect(windows.last.$1, cap * (pages - 1));
      expect(windows.last.$2, 40);
    });

    testWidgets('horizontal swipe flips a page', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final windows = <(int, int)>[];

      await pumpHarness(
        tester,
        container: container,
        windows: windows,
        total: 40,
      );
      final cap = windows.last.$2 - windows.last.$1;
      final pages = (40 + cap - 1) ~/ cap;

      await tester.fling(find.text('entry 0'), const Offset(-300, 0), 1000);
      await tester.pump();
      expect(windows.last.$1, cap);
      expect(find.text('Page 2 of $pages'), findsOneWidget);

      // Dragging ON a text is required: PageFlipSurface defers hit-testing to
      // its child and RenderParagraph hit-tests itself.
      await tester.drag(find.text('entry $cap'), const Offset(200, 0));
      await tester.pump();
      expect(windows.last.$1, 0);
      expect(find.text('Page 1 of $pages'), findsOneWidget);
    });

    testWidgets('clamps the page when the entry count shrinks', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final windows = <(int, int)>[];

      await pumpHarness(
        tester,
        container: container,
        windows: windows,
        total: 40,
      );
      final cap = windows.last.$2 - windows.last.$1;
      final pages = (40 + cap - 1) ~/ cap;
      expect(pages, greaterThanOrEqualTo(3));

      final next = iconButton(FluentIcons.chevron_right_24_regular);
      await tester.tap(next);
      await tester.pump();
      await tester.tap(next);
      await tester.pump();
      expect(find.text('Page 3 of $pages'), findsOneWidget);

      // Same container, fewer entries: remembered page 3 of 3 -> page 2 of 2.
      windows.clear();
      await pumpHarness(
        tester,
        container: container,
        windows: windows,
        total: 20,
      );
      expect(find.text('Page 2 of 2'), findsOneWidget);
      expect(windows.last.$1, cap);
      expect(windows.last.$2, 20);
      expect(find.text('entry $cap'), findsOneWidget);
      expect(find.text('entry ${cap - 1}'), findsNothing);
      // The clamp is display-only: the page index is kept.
      expect(container.read(entryPageIndexProvider)['test'], 3);
    });

    testWidgets('hasNextPage: open-ended label, load-more once per page-show', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final windows = <(int, int)>[];
      var fetches = 0;

      // Throwaway pump to derive the per-page capacity.
      await pumpHarness(
        tester,
        container: container,
        windows: windows,
        total: 40,
      );
      final cap = windows.last.$2 - windows.last.$1;
      windows.clear();

      Future<void> pumpBuffered(int total) => pumpHarness(
        tester,
        container: container,
        windows: windows,
        total: total,
        hasNextPage: true,
        onLoadMore: () => fetches++,
      );

      // Page 1 IS the last buffered page: the eager post-frame fired once.
      await pumpBuffered(cap);
      expect(fetches, 1);
      expect(find.text('Page 1'), findsOneWidget);
      expect(find.text('Page 1 of 1'), findsNothing);
      final next = iconButton(FluentIcons.chevron_right_24_regular);
      expect(tester.widget<IconButton>(next).onPressed, isNotNull);

      await tester.pump();
      await tester.pump();
      expect(fetches, 1);

      // Already fired for this page-show: tapping next does not re-fire.
      await tester.tap(next);
      await tester.pump();
      expect(fetches, 1);

      // Items arrive: page 1 of 2 is no longer the last page; growth reset
      // the guard but there is no trigger.
      windows.clear();
      await pumpBuffered(cap + 2);
      expect(fetches, 1);

      // Flipping to the new last page fires the next fetch.
      await tester.tap(next);
      await tester.pump();
      expect(fetches, 2);
      expect(find.text('Page 2'), findsOneWidget);
      expect(windows.last.$1, cap);
      expect(windows.last.$2, cap + 2);

      await tester.pump();
      expect(fetches, 2);
    });
  });
}
