// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:material_ui/material_ui.dart';

/// Indeterminate progress fraction shown while reduced motion / e-ink is on:
/// a static partial ring reads as "busy" without animating (which forces a
/// repaint on every frame — the worst case for e-ink panels).
const double kStaticCircularProgressFraction = 0.75;

/// Static partial bar used for indeterminate progress under reduced motion.
const double kStaticLinearProgressFraction = 0.6;

/// [CircularProgressIndicator] that never animates (the fork is always in
/// reduced motion). Determinate values render unchanged.
class AppCircularProgress extends StatelessWidget {
  const AppCircularProgress({
    super.key,
    this.value,
    this.backgroundColor,
    this.color,
    this.strokeWidth = 4.0,
    this.strokeCap,
    this.semanticsLabel,
    this.semanticsValue,
  });

  final double? value;
  final Color? backgroundColor;
  final Color? color;
  final double strokeWidth;
  final StrokeCap? strokeCap;
  final String? semanticsLabel;
  final String? semanticsValue;

  @override
  Widget build(BuildContext context) {
    return CircularProgressIndicator(
      value: value ?? kStaticCircularProgressFraction,
      backgroundColor: backgroundColor,
      color: color,
      strokeWidth: strokeWidth,
      strokeCap: strokeCap,
      semanticsLabel: semanticsLabel,
      semanticsValue: semanticsValue,
    );
  }
}

/// [LinearProgressIndicator] that never animates (the fork is always in
/// reduced motion). Determinate values render unchanged.
class AppLinearProgress extends StatelessWidget {
  const AppLinearProgress({
    super.key,
    this.value,
    this.backgroundColor,
    this.color,
    this.minHeight,
    this.semanticsLabel,
    this.semanticsValue,
  });

  final double? value;
  final Color? backgroundColor;
  final Color? color;
  final double? minHeight;
  final String? semanticsLabel;
  final String? semanticsValue;

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: value ?? kStaticLinearProgressFraction,
      backgroundColor: backgroundColor,
      color: color,
      minHeight: minHeight,
      semanticsLabel: semanticsLabel,
      semanticsValue: semanticsValue,
    );
  }
}
