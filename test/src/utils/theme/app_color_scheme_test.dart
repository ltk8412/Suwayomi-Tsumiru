// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tsumiru/src/utils/theme/app_color_scheme.dart';
import 'package:tsumiru/src/utils/theme/theme_tokens.dart';

void main() {
  test('eink dark scheme contrasts primary against onPrimary', () {
    final scheme = schemeFromTokens(
      tokensFor(Brightness.dark),
      Brightness.dark,
    );
    final contrast =
        (scheme.primary.computeLuminance() -
                scheme.onPrimary.computeLuminance())
            .abs();
    expect(contrast, greaterThan(0.3));
  });
}
