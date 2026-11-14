// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../../utils/platform/eink/eink_mode_providers.dart';
import '../../../../../../utils/platform/eink/eink_providers.dart';
import 'eink_settings_preset.dart';

/// Suggests enabling E-Ink mode on detected e-ink hardware; dismissible.
class EinkDeviceSuggestionBanner extends ConsumerWidget {
  const EinkDeviceSuggestionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detected = ref.watch(isEinkDeviceProvider).value ?? false;
    final enabled = ref.watch(einkModeProvider).ifNull(false);
    final dismissed = ref.watch(einkSuggestionDismissedProvider).ifNull(false);
    if (!detected || enabled || dismissed) return const SizedBox.shrink();
    return MaterialBanner(
      leading: const Icon(FluentIcons.ink_stroke_24_regular),
      content: Text(context.l10n.einkDetectedBanner),
      actions: [
        TextButton(
          onPressed: () {
            ref.read(einkModeProvider.notifier).update(true);
            unawaited(applyEinkSettingsPreset(context));
          },
          child: Text(context.l10n.einkEnable),
        ),
        TextButton(
          onPressed: () =>
              ref.read(einkSuggestionDismissedProvider.notifier).update(true),
          child: Text(context.l10n.einkDismiss),
        ),
      ],
    );
  }
}
