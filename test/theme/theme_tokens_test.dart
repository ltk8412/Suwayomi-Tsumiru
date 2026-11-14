import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tsumiru/src/utils/theme/app_theme_builder.dart';
import 'package:tsumiru/src/utils/theme/theme_tokens.dart';

void main() {
  test('einkPaper tokens carry into the built theme', () {
    final light = tokensFor(Brightness.light);
    expect(light.bg, const Color(0xFFFFFFFF));
    expect(light.ink, const Color(0xFF000000));
    expect(light.accent, const Color(0xFF000000));
    expect(light.accent2, const Color(0xFF333333));
    expect(light.danger, const Color(0xFFAE2F34));

    final theme = buildAppTheme(brightness: Brightness.light);
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.surface, const Color(0xFFFFFFFF));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFFFFFFF));

    final dark = tokensFor(Brightness.dark);
    expect(dark.bg, const Color(0xFF000000));
    expect(dark.ink, const Color(0xFFFFFFFF));
  });
}
