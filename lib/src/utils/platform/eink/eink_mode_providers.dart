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

/// The single switch: on applies the preset; off leaves applied values in place.
final einkActiveProvider = Provider<bool>(
  (ref) => ref.watch(einkModeProvider).ifNull(false),
);
