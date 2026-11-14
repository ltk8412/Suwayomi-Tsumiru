// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Invokes the vendor-patched EPD full refresh via reflection on
/// `android.view.View` (Meebook/Boyue Rockchip: `requestEpdMode(EPD_FULL, true)`).
///
/// Returns true when a mechanism fired; false is a soft no-op — the flash
/// overlay stays the fallback on devices where the probe does not apply.
Future<bool> triggerNativeRefresh() async {
  if (kIsWeb || !Platform.isAndroid) return false;
  try {
    final fired = await const MethodChannel(
      'tsumiru/eink',
    ).invokeMethod<bool>('refreshScreen');
    return fired ?? false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}
