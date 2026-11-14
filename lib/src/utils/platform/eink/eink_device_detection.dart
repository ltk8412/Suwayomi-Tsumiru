// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

/// Model tokens from vendors that ship e-ink panels. Deliberately narrow to
/// avoid false positives (no standalone `NOVA`/`TAB`/`A5` tokens).
const _kEinkModelTokens = <String>[
  'POKE',
  'LEAF',
  'PALMA',
  'BIGME',
  'MEEBOOK',
  'M103',
  'LIKEBOOK',
  'BOYUE',
  'HI READER',
];

/// True when the device identifiers match a known e-ink vendor.
bool detectEinkDevice({
  required String model,
  required String manufacturer,
  String? socManufacturer,
}) {
  final haystack = '$model $manufacturer ${socManufacturer ?? ''}'
      .toUpperCase();
  final m = manufacturer.toUpperCase();
  final soc = (socManufacturer ?? '').toUpperCase();
  if (m == 'ONYX' || m == 'BOOX' || soc == 'ONYX' || soc == 'BOOX') {
    return true;
  }
  // Hisense e-readers are A5/A7/A9 models.
  if (m.contains('HISENSE')) {
    return const ['A5', 'A7', 'A9'].any(haystack.contains);
  }
  return _kEinkModelTokens.any(haystack.contains);
}
