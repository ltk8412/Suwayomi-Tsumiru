// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsumiru/src/features/browse_center/domain/source/source_model.dart';
import 'package:tsumiru/src/features/browse_center/presentation/source_manga_list/widgets/source_manga_display_view.dart';
import 'package:tsumiru/src/features/browse_center/presentation/source_manga_list/widgets/source_manga_grid_view.dart';
import 'package:tsumiru/src/features/browse_center/presentation/source_manga_list/widgets/source_manga_list_view.dart';
import 'package:tsumiru/src/features/manga_book/domain/manga/graphql/__generated__/fragment.graphql.dart';
import 'package:tsumiru/src/features/manga_book/domain/manga/manga_model.dart';
import 'package:tsumiru/src/global_providers/global_providers.dart';
import 'package:tsumiru/src/graphql/__generated__/schema.graphql.dart';
import 'package:tsumiru/src/l10n/generated/app_localizations.dart';
import 'package:tsumiru/src/utils/webui_meta/webui_settings.dart';
import 'package:tsumiru/src/widgets/custom_circular_progress_indicator.dart';
import 'package:tsumiru/src/widgets/entry_pager_bar.dart';
import 'package:tsumiru/src/widgets/inline_retry_row.dart';

Fragment$MangaDto _manga(int id) => Fragment$MangaDto(
  id: id,
  title: 'manga $id',
  thumbnailUrl: null,
  chapters: Fragment$MangaDto$chapters(totalCount: 4),
  genre: const [],
  initialized: true,
  meta: const [],
  sourceId: '1',
  status: Enum$MangaStatus.ONGOING,
  categories: Fragment$MangaDto$categories(nodes: const []),
  trackRecords: Fragment$MangaDto$trackRecords(nodes: const []),
  updateStrategy: Enum$UpdateStrategy.ALWAYS_UPDATE,
  url: '/manga/$id',
  user: Fragment$MangaDto$user(
    bookmarkCount: 0,
    downloadCount: 1,
    inLibrary: false,
    inLibraryAt: '0',
    unreadCount: 2,
  ),
);

/// Two buffered source pages of ten entries each; the fetch-ahead callback
/// never completes so a fired load-more cannot mutate the state mid-test.
PagingController<int, MangaDto> _bufferedController() {
  final controller = PagingController<int, MangaDto>(
    getNextPageKey: (state) => (state.keys?.last ?? 0) + 1,
    fetchPage: (pageKey) => Completer<List<MangaDto>>().future,
  );
  controller.value = PagingState<int, MangaDto>(
    pages: [
      [for (var i = 0; i < 10; i++) _manga(i)],
      [for (var i = 10; i < 20; i++) _manga(i)],
    ],
    keys: const [1, 2],
    hasNextPage: true,
    isLoading: false,
  );
  return controller;
}

Future<void> _pump(
  WidgetTester tester,
  PagingController<int, MangaDto> controller,
  Widget Function(PagingController<int, MangaDto> controller) build, {
  Size size = const Size(400, 800),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      webUiBoolProvider('hideLibraryEntries').overrideWithValue(false),
    ],
  );
  addTearDown(container.dispose);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: build(controller)),
      ),
    ),
  );
  // Frame 1 lays out and publishes the page starts; frame 2 renders the bar.
  await tester.pump();
}

Finder _nextButton() =>
    find.byIcon(FluentIcons.chevron_right_24_regular);

void main() {
  group('SourceMangaGridView pagination', () {
    testWidgets('renders one window of the buffer and flips to the next', (
      tester,
    ) async {
      final controller = _bufferedController();
      await _pump(
        tester,
        controller,
        (controller) => SourceMangaGridView(
          controller: controller,
          sourceId: '1',
          sourceType: SourceType.POPULAR,
          selectedIds: const {},
          selecting: false,
          onToggleSelection: (_) {},
          onAddToLibrary: (_) {},
        ),
      );

      // Open-ended label while the source still has pages.
      expect(find.byType(EntryPagerBar), findsOneWidget);
      expect(find.text('Page 1'), findsOneWidget);
      // One screen fits fewer than all 20 buffered entries.
      expect(find.text('manga 0'), findsOneWidget);
      expect(find.text('manga 19'), findsNothing);

      await tester.tap(_nextButton());
      await tester.pump();
      expect(find.text('Page 2'), findsOneWidget);
      expect(find.text('manga 0'), findsNothing);
      expect(find.text('manga 9'), findsOneWidget);
    });

    testWidgets('first page loading shows the shimmer', (tester) async {
      final controller = PagingController<int, MangaDto>(
        getNextPageKey: (_) => 1,
        fetchPage: (pageKey) => Completer<List<MangaDto>>().future,
      );
      controller.value = PagingState<int, MangaDto>(
        pages: null,
        isLoading: true,
      );
      await _pump(
        tester,
        controller,
        (controller) => SourceMangaGridView(
          controller: controller,
          sourceId: '1',
          sourceType: SourceType.POPULAR,
          selectedIds: const {},
          selecting: false,
          onToggleSelection: (_) {},
          onAddToLibrary: (_) {},
        ),
      );
      expect(find.byType(CenterTsumiruShimmerIndicator), findsOneWidget);
    });

    testWidgets('first-page error shows Emoticons with retry', (tester) async {
      final controller = PagingController<int, MangaDto>(
        getNextPageKey: (_) => 1,
        fetchPage: (pageKey) => Completer<List<MangaDto>>().future,
      );
      controller.value = PagingState<int, MangaDto>(
        pages: null,
        error: Exception('boom'),
        isLoading: false,
      );
      await _pump(
        tester,
        controller,
        (controller) => SourceMangaGridView(
          controller: controller,
          sourceId: '1',
          sourceType: SourceType.POPULAR,
          selectedIds: const {},
          selecting: false,
          onToggleSelection: (_) {},
          onAddToLibrary: (_) {},
        ),
      );
      expect(find.text('Exception: boom'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('empty result shows the no-manga state', (tester) async {
      final controller = PagingController<int, MangaDto>(
        getNextPageKey: (_) => 1,
        fetchPage: (pageKey) => Completer<List<MangaDto>>().future,
      );
      controller.value = PagingState<int, MangaDto>(
        pages: const [<MangaDto>[]],
        keys: const [1],
        hasNextPage: false,
        isLoading: false,
      );
      await _pump(
        tester,
        controller,
        (controller) => SourceMangaGridView(
          controller: controller,
          sourceId: '1',
          sourceType: SourceType.POPULAR,
          selectedIds: const {},
          selecting: false,
          onToggleSelection: (_) {},
          onAddToLibrary: (_) {},
        ),
      );
      expect(find.text('No manga found'), findsOneWidget);
    });
  });

  group('SourceMangaListView pagination', () {
    testWidgets('windows the buffer and flips; retry row sits above the bar', (
      tester,
    ) async {
      final controller = _bufferedController();
      await _pump(
        tester,
        controller,
        (controller) => SourceMangaListView(
          controller: controller,
          sourceId: '1',
          selectedIds: const {},
          selecting: false,
          onToggleSelection: (_) {},
        ),
      );

      expect(find.byType(EntryPagerBar), findsOneWidget);
      expect(find.text('Page 1'), findsOneWidget);
      expect(find.text('manga 0'), findsOneWidget);
      expect(find.text('manga 19'), findsNothing);

      await tester.tap(_nextButton());
      await tester.pump();
      expect(find.text('Page 2'), findsOneWidget);
      expect(find.text('manga 0'), findsNothing);
      expect(find.text('manga 19'), findsNothing);

      // A failed later fetch shows the inline retry at the bottom of the
      // page area, directly above the pager bar.
      controller.value = controller.value.copyWith(error: Exception('later'));
      await tester.pump();
      final retry = find.byType(InlineRetryRow);
      expect(retry, findsOneWidget);
      expect(find.text('Exception: later'), findsOneWidget);
      final barTop = tester.getRect(find.byType(EntryPagerBar)).top;
      expect(
        tester.getRect(retry).bottom,
        moreOrLessEquals(barTop, epsilon: 1),
      );

      // Filling the buffer shows the loading indicator while items are shown.
      controller.value = controller.value.copyWith(
        error: null,
        isLoading: true,
      );
      await tester.pump();
      expect(find.byType(MiniCircularProgressIndicator), findsOneWidget);
    });
  });

  group('SourceMangaDisplayView', () {
    testWidgets('pager bar sits at the bottom of the screen body', (
      tester,
    ) async {
      final controller = _bufferedController();
      await _pump(
        tester,
        controller,
        (controller) => SourceMangaDisplayView(
          controller: controller,
          sourceId: '1',
          sourceType: SourceType.POPULAR,
        ),
      );

      expect(find.text('manga 0'), findsOneWidget);
      final bar = find.byType(EntryPagerBar);
      expect(bar, findsOneWidget);
      final rect = tester.getRect(bar);
      expect(rect.bottom, moreOrLessEquals(800, epsilon: 1));
      expect(find.text('Page 1'), findsOneWidget);
    });

    testWidgets('desktop composition keeps the bar at the bottom', (
      tester,
    ) async {
      final controller = _bufferedController();
      await _pump(
        tester,
        controller,
        (controller) => SourceMangaDisplayView(
          controller: controller,
          sourceId: '1',
          sourceType: SourceType.POPULAR,
        ),
        size: const Size(1400, 980),
      );

      expect(find.text('manga 0'), findsOneWidget);
      final rect = tester.getRect(find.byType(EntryPagerBar));
      expect(rect.bottom, moreOrLessEquals(980, epsilon: 1));
      expect(find.text('Page 1'), findsOneWidget);
    });
  });
}
