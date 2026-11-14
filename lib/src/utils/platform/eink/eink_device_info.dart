// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// Device identifiers read from the `tsumiru/eink` platform channel.
class EinkDeviceInfo {
  const EinkDeviceInfo({
    required this.model,
    required this.manufacturer,
    this.socManufacturer,
  });

  final String model;
  final String manufacturer;
  final String? socManufacturer;
}

/// Returns null on non-Android runtimes or when the channel is unavailable.
Future<EinkDeviceInfo?> fetchEinkDeviceInfo() async {
  if (kIsWeb || !Platform.isAndroid) return null;
  try {
    final map = await const MethodChannel(
      'tsumiru/eink',
    ).invokeMapMethod<String, dynamic>('deviceInfo');
    final model = map?['model'];
    final manufacturer = map?['manufacturer'];
    if (model is! String || manufacturer is! String) return null;
    return EinkDeviceInfo(
      model: model,
      manufacturer: manufacturer,
      socManufacturer: map?['socManufacturer'] is String
          ? map!['socManufacturer'] as String
          : null,
    );
  } on PlatformException {
    return null;
  } on MissingPluginException {
    return null;
  }
}
