// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../../../utils/extensions/custom_extensions.dart';
import '../../../../../../utils/platform/eink/eink_mode_providers.dart';
import '../../../../../../widgets/compact_switch.dart';
import 'eink_settings_preset.dart';

class EinkModeSwitchTile extends HookConsumerWidget {
  const EinkModeSwitchTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CompactSwitchListTile(
      controlAffinity: ListTileControlAffinity.trailing,
      title: Text(context.l10n.einkMode),
      subtitle: Text(context.l10n.einkModeSubtitle),
      onChanged: (value) {
        ref.read(einkModeProvider.notifier).update(value);
        if (value) applyEinkSettingsPreset(ref);
      },
      value: ref.watch(einkModeProvider).ifNull(false),
    );
  }
}
