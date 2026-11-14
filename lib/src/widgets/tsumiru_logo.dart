// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:material_ui/material_ui.dart';

/// The single flat mark used across the e-ink fork.
class TsumiruLogo extends StatelessWidget {
  const TsumiruLogo({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/icons/logo_eink.png', width: size, height: size);
  }
}
