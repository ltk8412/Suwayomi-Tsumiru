// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:async';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../../constants/db_keys.dart';
import '../../../../../../constants/enum.dart';
import '../../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../../utils/platform/eink/eink_mode_providers.dart';
import '../../../../../../utils/platform/eink/epd_refresh.dart';
import '../../../../../settings/presentation/reader/widgets/reader_general_prefs/reader_general_prefs.dart';

/// Every Nth page change: on devices with a working native EPD refresh the
/// panel is refreshed directly; the visual flash stays opt-in via
/// [flashOnPageChangeProvider] and is the fallback everywhere else.
class ReaderFlashOverlay extends HookConsumerWidget {
  const ReaderFlashOverlay({super.key, required this.currentIndex});

  final int currentIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(flashOnPageChangeProvider).ifNull(false);
    final durationTicks =
        ref.watch(flashDurationProvider) ?? DBKeys.flashDuration.initial as int;
    final interval =
        ref.watch(flashPageIntervalProvider) ??
        DBKeys.flashPageInterval.initial as int;
    final flashColor =
        ref.watch(flashColorKeyProvider) ??
        DBKeys.flashColor.initial as FlashColor;
    final nativeRefresh = ref
        .watch(nativeRefreshAvailableProvider)
        .ifNull(false);

    final color = useState<Color?>(null);
    final prevIndex = useRef<int?>(null);
    final timesCalled = useRef(0);
    final halfTimer = useRef<Timer?>(null);
    final endTimer = useRef<Timer?>(null);

    useEffect(
      () => () {
        halfTimer.value?.cancel();
        endTimer.value?.cancel();
      },
      const [],
    );

    useEffect(() {
      final prev = prevIndex.value;
      prevIndex.value = currentIndex;
      // Initial mount isn't a page change.
      if (prev == null || prev == currentIndex) return null;
      final flashNow = timesCalled.value % interval.clamp(1, 10) == 0;
      timesCalled.value++;
      if (!flashNow) return null;

      // Native refresh replaces the flash by default where it is available.
      if (nativeRefresh) {
        unawaited(triggerNativeRefresh());
      }
      if (!enabled) return null;

      halfTimer.value?.cancel();
      endTimer.value?.cancel();
      color.value = flashColor == FlashColor.black
          ? Colors.black
          : Colors.white;
      final half = Duration(milliseconds: durationTicks * kFlashMsPerTick ~/ 2);
      if (flashColor == FlashColor.whiteBlack) {
        halfTimer.value = Timer(half, () => color.value = Colors.black);
      }
      endTimer.value = Timer(half * 2, () => color.value = null);
      return null;
    }, [currentIndex]);

    if (color.value == null) return const SizedBox.shrink();
    return IgnorePointer(child: ColoredBox(color: color.value!));
  }
}
