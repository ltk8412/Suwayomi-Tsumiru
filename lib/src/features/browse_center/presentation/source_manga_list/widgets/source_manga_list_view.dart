// Copyright (c) 2022 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../constants/app_sizes.dart';
import '../../../../../routes/router_config.dart';
import '../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../utils/webui_meta/webui_settings.dart';
import '../../../../../widgets/custom_circular_progress_indicator.dart';
import '../../../../../widgets/desktop/desktop_page_frame.dart';
import '../../../../../widgets/emoticons.dart';
import '../../../../../widgets/inline_retry_row.dart';
import '../../../../../widgets/manga_cover/list/manga_cover_list_tile.dart';
import '../../../../../widgets/paginated_entries.dart';
import '../../../../manga_book/domain/manga/manga_model.dart';
import '../../../domain/source/source_model.dart';
import '../controller/source_manga_controller.dart';

/// Nominal rendered height of [MangaCoverListTile] at scale 1.0, derived the
/// same way as `kCompactTileExtent` in `app_sizes.dart`: the compact 60 px
/// cover at 2:3 (no card inset) plus the tile's `KEdgeInsets.a8` padding on
/// both vertical edges (`kListTilePadding * 2`).
final kSourceMangaListTileExtent =
    mangaCoverBoxHeight(kCompactCoverWidth, coverInset: 0) +
        kListTilePadding * 2;

class SourceMangaListView extends ConsumerWidget {
  const SourceMangaListView({
    super.key,
    required this.controller,
    required this.sourceId,
    required this.selectedIds,
    required this.selecting,
    required this.onToggleSelection,
    this.source,
  });
  final PagingController<int, MangaDto> controller;
  final SourceDto? source;
  final String sourceId;
  final Set<int> selectedIds;
  final bool selecting;
  final void Function(int mangaId) onToggleSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = PagingListener(
      controller: controller,
      builder: (context, state, fetchNextPage) {
        // Filter per page exactly like the old list did so hidden library
        // entries never count toward the display window.
        final hideLibraryEntries = ref.watch(
          webUiBoolProvider('hideLibraryEntries'),
        );
        final items = [
          for (final page in state.pages ?? const <List<MangaDto>>[])
            ...visibleSourceMangas(page, hideLibraryEntries: hideLibraryEntries),
        ];
        final error = state.error;
        if (items.isEmpty) {
          if (error != null) {
            return Emoticons(
              title: error.toString(),
              button: TextButton(
                onPressed: () => controller.refresh(),
                child: Text(context.l10n.retry),
              ),
            );
          }
          // Nothing fetched yet (first page still loading or just reset).
          if (state.pages == null) {
            return const CenterTsumiruShimmerIndicator();
          }
          return Emoticons(
            title: context.l10n.noMangaFound,
            button: TextButton(
              onPressed: () => controller.refresh(),
              child: Text(context.l10n.refresh),
            ),
          );
        }
        // The server page size is fixed; display pages are windows over the
        // buffered entries sized to fit this surface.
        return PaginatedEntries(
          pageKey: 'browse-$sourceId',
          blocks: [(start: 0, count: items.length, headerExtent: 0.0)],
          columns: 1,
          rowExtent: kSourceMangaListTileExtent,
          rowSpacing: 0,
          hasNextPage: state.hasNextPage,
          onLoadMore: fetchNextPage,
          pageBuilder: (context, start, end) {
            final list = CustomScrollView(
              slivers: [
                SliverFixedExtentList(
                  itemExtent: kSourceMangaListTileExtent,
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = items[start + index];
                      return MangaCoverListTile(
                        manga: item,
                        selected: selectedIds.contains(item.id),
                        linkLocation: MangaRoute(mangaId: item.id).location,
                        onLongPress: () => onToggleSelection(item.id),
                        onPressed: () => selecting
                            ? onToggleSelection(item.id)
                            : MangaRoute(mangaId: item.id).push(context),
                      );
                    },
                    childCount: end - start,
                  ),
                ),
              ],
            );
            // Overlays sit at the bottom of the page area, directly above the
            // pager bar, without disturbing the window layout.
            final pageError = state.error;
            final filling = state.isLoading;
            if (pageError == null && !filling) return list;
            return Stack(
              fit: StackFit.expand,
              children: [
                list,
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
          },
        );
      },
    );
    return DesktopBoxBleed(start: kListTilePadding, child: view);
  }
}
