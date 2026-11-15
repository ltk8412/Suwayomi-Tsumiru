// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'entry_page_index.g.dart';

/// Remembers the current 1-based page per paginated surface so it survives
/// navigation between tabs.
@riverpod
class EntryPageIndex extends _$EntryPageIndex {
  @override
  Map<String, int> build() => const {};

  void setPage(String key, int page) => state = {...state, key: page};

  int pageFor(String key) => state[key] ?? 1;
}
