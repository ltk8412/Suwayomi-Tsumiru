// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../../constants/enum.dart';
import '../../../../../../utils/motion/reduce_motion.dart';
import '../../../../../../utils/platform/eink/eink_mode_providers.dart';
import '../../../reader/widgets/reader_general_prefs/reader_general_prefs.dart';
import '../../../reader/widgets/reader_mode_tile/reader_mode_tile.dart';
import '../../../reader/widgets/reader_paged_prefs/reader_paged_prefs.dart';
import '../../../reader/widgets/reader_volume_tap_tile/reader_volume_tap_tile.dart';

/// Applies the recommended e-ink defaults through the existing setting
/// providers. Called once when E-Ink mode is toggled on.
///
/// The page-change flash is only enabled where the native EPD refresh probe
/// fails (flash = fallback); on devices with working native refresh it stays
/// available as an opt-in via the existing [flashOnPageChangeProvider].
Future<void> applyEinkSettingsPreset(BuildContext context) async {
  final container = ProviderScope.containerOf(context, listen: false);
  container
      .read(readerModeKeyProvider.notifier)
      .update(ReaderMode.singleHorizontalLTR);
  container.read(flashDurationProvider.notifier).update(2);
  container
      .read(readerBackgroundColorKeyProvider.notifier)
      .update(ReaderBackgroundColor.white);
  container.read(readerFullscreenProvider.notifier).update(true);
  container.read(smallerTapZonesProvider.notifier).update(false);
  container.read(volumeTapProvider.notifier).update(true);
  container.read(appReduceMotionProvider.notifier).set(true);

  final nativeRefresh = await ensureNativeRefreshProbed(container);
  container.read(flashOnPageChangeProvider.notifier).update(!nativeRefresh);
}
