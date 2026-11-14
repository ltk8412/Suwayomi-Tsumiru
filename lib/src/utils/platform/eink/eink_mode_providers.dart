// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../constants/db_keys.dart';
import '../../extensions/custom_extensions.dart';
import '../../mixin/shared_preferences_client_mixin.dart';
import 'epd_refresh.dart';

part 'eink_mode_providers.g.dart';

@riverpod
class EinkMode extends _$EinkMode with SharedPreferenceClientMixin<bool> {
  @override
  bool? build() => initialize(DBKeys.einkMode);
}

@riverpod
class EinkSuggestionDismissed extends _$EinkSuggestionDismissed
    with SharedPreferenceClientMixin<bool> {
  @override
  bool? build() => initialize(DBKeys.einkSuggestionDismissed);
}

/// Whether the native EPD refresh probe succeeded; persisted after the first
/// successful probe so launches never re-probe. Failures are not persisted —
/// the probe retries on the next E-Ink mode toggle, so firmware updates that
/// add the API self-heal. Null until probed.
@riverpod
class NativeRefreshAvailable extends _$NativeRefreshAvailable
    with SharedPreferenceClientMixin<bool> {
  @override
  bool? build() => initialize(DBKeys.einkNativeRefreshAvailable);
}

/// Probes (or returns the persisted success) and reports whether native EPD
/// refresh works on this device.
Future<bool> ensureNativeRefreshProbed(ProviderContainer container) async {
  final cached = container.read(nativeRefreshAvailableProvider);
  if (cached ?? false) return true;
  final available = await triggerNativeRefresh();
  if (available) {
    container.read(nativeRefreshAvailableProvider.notifier).update(true);
  } else {
    // Leave the key unset so the next E-Ink mode toggle probes again.
    container.read(nativeRefreshAvailableProvider.notifier).update(null);
  }
  return available;
}

/// The single switch: on applies the preset; off leaves applied values in place.
final einkActiveProvider = Provider<bool>(
  (ref) => ref.watch(einkModeProvider).ifNull(false),
);
