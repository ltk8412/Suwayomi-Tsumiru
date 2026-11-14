// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../../constants/enum.dart';
import '../../../../../../utils/motion/reduce_motion.dart';
import '../../../reader/widgets/reader_general_prefs/reader_general_prefs.dart';
import '../../../reader/widgets/reader_mode_tile/reader_mode_tile.dart';
import '../../../reader/widgets/reader_paged_prefs/reader_paged_prefs.dart';
import '../../../reader/widgets/reader_volume_tap_tile/reader_volume_tap_tile.dart';

/// Applies the recommended e-ink defaults through the existing setting
/// providers. Called once when E-Ink mode is toggled on.
void applyEinkSettingsPreset(WidgetRef ref) {
  ref
      .read(readerModeKeyProvider.notifier)
      .update(ReaderMode.singleHorizontalLTR);
  ref.read(flashOnPageChangeProvider.notifier).update(true);
  ref.read(flashDurationProvider.notifier).update(2);
  ref
      .read(readerBackgroundColorKeyProvider.notifier)
      .update(ReaderBackgroundColor.white);
  ref.read(readerFullscreenProvider.notifier).update(true);
  ref.read(smallerTapZonesProvider.notifier).update(false);
  ref.read(volumeTapProvider.notifier).update(true);
  ref.read(appReduceMotionProvider.notifier).set(true);
}
