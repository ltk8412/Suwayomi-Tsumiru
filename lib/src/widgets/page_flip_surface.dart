// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/widgets.dart';

/// Horizontal drag distance (px) required to flip a page.
const kPageSwipeMinDistance = 64.0;

/// Horizontal drag velocity (px/s) required to flip a page.
const kPageSwipeMinVelocity = 300.0;

/// Horizontal swipe flips pages instantly (no animation) instead of scrolling.
///
/// Only horizontal drag handlers are attached, so taps, long-presses and
/// vertical scrolling are unaffected. At most one flip happens per gesture.
class PageFlipSurface extends StatelessWidget {
  const PageFlipSurface({
    super.key,
    required this.onPrevious,
    required this.onNext,
    required this.child,
  });

  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Captured by the drag callbacks below for the lifetime of the gesture.
    var delta = 0.0;
    var flipped = false;

    void flip(DragEndDetails? end) {
      if (flipped) return;
      final velocity = end?.primaryVelocity ?? 0.0;
      final passedDistance = delta.abs() >= kPageSwipeMinDistance;
      final passedVelocity = velocity.abs() >= kPageSwipeMinVelocity;
      if (!passedDistance && !passedVelocity) return;
      flipped = true;
      // The drag went left when the distance threshold judged it (delta < 0),
      // otherwise the velocity threshold judged it (negative velocity).
      final wentLeft = passedDistance ? delta < 0 : velocity < 0;
      if (wentLeft) {
        onNext();
      } else {
        onPrevious();
      }
    }

    return GestureDetector(
      onHorizontalDragStart: (_) {
        delta = 0;
        flipped = false;
      },
      onHorizontalDragUpdate: (details) {
        delta += details.primaryDelta ?? 0;
      },
      onHorizontalDragEnd: flip,
      onHorizontalDragCancel: () => flip(null),
      child: child,
    );
  }
}
