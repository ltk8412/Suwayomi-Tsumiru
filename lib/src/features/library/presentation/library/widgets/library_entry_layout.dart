// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../constants/app_sizes.dart';
import '../../../../../constants/db_keys.dart';
import '../../../../../constants/enum.dart';
import '../../../../../utils/entry_pagination.dart';
import '../../../../../widgets/manga_cover/providers/manga_cover_providers.dart';
import '../../../../settings/presentation/appearance/widgets/grid_cover_width_slider/grid_cover_width_slider.dart';
import '../controller/library_controller.dart';

/// Resolves columns, tile height and row spacing for the current library
/// display settings; must mirror the delegate `LibraryMangaSliver` builds so
/// the pagination window matches the rendered tiles. [width] is the
/// entries-area width (the constraints of the paginated surface, passed in
/// by the call site).
({int columns, double rowExtent, double rowSpacing}) libraryEntryLayout(
  BuildContext context,
  WidgetRef ref,
  double width,
) {
  final displayMode = ref.watch(libraryDisplayModeProvider);
  final gridStyle =
      ref.watch(libraryGridStyleKeyProvider) ?? LibraryGridStyle.uniform;
  // Watched for parity with `LibraryMangaSliver`; it only changes how
  // variable the list rows are, not the extents computed below.
  ref.watch(limitTitleLinesProvider);
  final listScale =
      ref.watch(libraryListScaleProvider) ??
      DBKeys.listScale.initial as double;
  final gridWidth =
      ref.watch(gridMinWidthProvider) ??
      DBKeys.gridMangaCoverMinWidth.initial as double;
  final isLandscape =
      MediaQuery.orientationOf(context) == Orientation.landscape;
  final fixedCols =
      (isLandscape
          ? ref.watch(libraryLandscapeColumnsProvider)
          : ref.watch(libraryPortraitColumnsProvider)) ??
      0;

  if (displayMode != null && displayMode.isGrid) {
    final layout = coverGridPageLayout(
      width: width,
      coverMinWidth: gridWidth,
      fixedColumns: fixedCols,
      // `grid`/`coverOnly` draw the title inside the cover card overlay, so
      // only `comfortableGrid` pays the title-below extent (mirrors
      // `mangaCoverUniformGridDelegate(..., titleBelow: ...)`).
      titleExtent:
          displayMode == DisplayMode.comfortableGrid ? kGridTitleExtent : 0,
    );
    return (
      columns: layout.columns,
      rowExtent: switch (gridStyle) {
        // Variable-height tiles: the uniform row plus a title band is a
        // conservative nominal extent so the page always fits; the surface
        // stays scrollable as a safety valve.
        LibraryGridStyle.nonUniform || LibraryGridStyle.staggered =>
          layout.rowExtent + kGridTitleExtent,
        LibraryGridStyle.uniform => layout.rowExtent,
      },
      // Every grid delegate lays rows out with a 2.0 main-axis gap.
      rowSpacing: 2.0,
    );
  }

  // Row extents 96/176 are calibrated at scale 1.0; rowScale is the same
  // expression `LibraryMangaSliver` uses.
  final rowScale =
      listScale * (MediaQuery.textScalerOf(context).scale(14) / 14);
  // With uncapped titles (`limitTitleLines` off) rows are not fixed-extent,
  // so these nominal extents are only an estimate of the row cost.
  final rowExtent = displayMode == DisplayMode.descriptiveList
      ? 176.0 * rowScale
      : 96.0 * rowScale;
  // List rows hold one entry each; the list delegates add no row gap.
  return (columns: 1, rowExtent: rowExtent, rowSpacing: 0.0);
}
