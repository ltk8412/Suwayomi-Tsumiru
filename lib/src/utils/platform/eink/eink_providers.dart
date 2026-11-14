// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'eink_device_detection.dart';
import 'eink_device_info.dart';

/// Test override; null performs real platform detection.
@visibleForTesting
bool? debugEinkOverride;

/// Detected e-ink hardware; false on non-Android runtimes and unknown devices.
final isEinkDeviceProvider = FutureProvider<bool>((ref) async {
  if (debugEinkOverride != null) return debugEinkOverride!;
  final info = await fetchEinkDeviceInfo();
  if (info == null) return false;
  return detectEinkDevice(
    model: info.model,
    manufacturer: info.manufacturer,
    socManufacturer: info.socManufacturer,
  );
});
