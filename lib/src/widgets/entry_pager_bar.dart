// Copyright (c) 2026 Contributors to the Suwayomi project
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../utils/extensions/custom_extensions.dart';

/// Bottom navigation bar for a paginated entry surface: previous button, a
/// centered "Page X (of Y)" label, and a next button.
///
/// Styled like the Upcoming screen pager (Fluent chevrons,
/// `MaterialLocalizations` prev/next tooltips).
class EntryPagerBar extends StatelessWidget {
  const EntryPagerBar({
    super.key,
    required this.page,
    required this.pageCount,
    required this.onPrevious,
    required this.onNext,
  });

  /// 1-based current page.
  final int page;

  /// Total pages, or null when not yet known.
  final int? pageCount;

  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final total = pageCount;
    final canGoPrevious = page > 1;
    final canGoNext = total == null || page < total;
    final label = total == null
        ? context.l10n.pageX(page)
        : context.l10n.pageXofY(page, total);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: MaterialLocalizations.of(context).previousPageTooltip,
            onPressed: canGoPrevious ? onPrevious : null,
            icon: const Icon(FluentIcons.chevron_left_24_regular),
          ),
          Expanded(
            child: Text(
              label,
              style: context.textTheme.titleLarge,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).nextPageTooltip,
            onPressed: canGoNext ? onNext : null,
            icon: const Icon(FluentIcons.chevron_right_24_regular),
          ),
        ],
      ),
    );
  }
}
