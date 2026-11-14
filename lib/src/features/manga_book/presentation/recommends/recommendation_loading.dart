import 'package:material_ui/material_ui.dart';

import '../../../../utils/extensions/custom_extensions.dart';
import '../../../../widgets/app_progress.dart';

class RecommendationLoading extends StatelessWidget {
  const RecommendationLoading({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppCircularProgress(),
        const SizedBox(height: 8),
        Text(
          context.l10n.suggestionsFetching,
          textAlign: TextAlign.center,
          style: context.textTheme.bodyMedium,
        ),
      ],
    ),
  );
}
