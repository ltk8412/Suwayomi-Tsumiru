import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app_color_scheme.dart';
import 'brand.dart';
import 'theme_tokens.dart';

/// The [ColorScheme] the e-ink fork uses at [brightness].
ColorScheme schemeFor(Brightness brightness) =>
    schemeFromTokens(tokensFor(brightness), brightness);

/// The single flat e-ink theme: black-on-white surfaces, no shadows or
/// translucency, bordered buttons.
ThemeData buildAppTheme({required Brightness brightness}) {
  final tokens = tokensFor(brightness);
  ColorScheme scheme = schemeFor(brightness);

  final navFill = tokens.accentFill;

  final brandColors = BrandColors(
    gradient: tokens.grad ?? schemeBrandGradient(scheme),
    onGradient: tokens.onAccent ?? const Color(0xFF0B0D1A),
    success: brandSuccessColor(brightness),
    neutral: brightness == Brightness.light,
    flat: true,
    navSelectedFill: navFill,
  );

  final primary = scheme.primary;
  final outline = scheme.outlineVariant;
  final brightPrimary = brandBrightAccent(scheme);

  ButtonStyle filledLike() => ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled)
          ? scheme.surfaceContainerHighest
          : scheme.surface,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.disabled)
          ? scheme.onSurfaceVariant
          : scheme.onSurface,
    ),
    shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    elevation: const WidgetStatePropertyAll(0),
    side: WidgetStatePropertyAll(BorderSide(color: scheme.onSurface)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );

  final theme = ThemeData(
    useMaterial3: true,
    // Leave platform font fallback available for scripts Inter does not cover.
    fontFamily: 'Inter',
    colorScheme: scheme,
    extensions: [brandColors],
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      // Match system-bar icon brightness to the surface for contrast.
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: brightness == Brightness.dark
            ? Brightness.dark
            : Brightness.light,
        systemNavigationBarColor: scheme.surface,
        systemNavigationBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    ),
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (context) => Icon(
        FluentIcons.arrow_left_24_regular,
        semanticLabel: MaterialLocalizations.of(context).backButtonTooltip,
      ),
      closeButtonIconBuilder: (context) =>
          const Icon(FluentIcons.dismiss_24_regular),
    ),
    tabBarTheme: const TabBarThemeData(tabAlignment: TabAlignment.center),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      elevation: 0,
      indicatorColor: navFill ?? scheme.secondaryContainer,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? (navFill != null
                    ? scheme.onSurface
                    : scheme.onSecondaryContainer)
              : scheme.onSurfaceVariant,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith((s) {
        final selected = s.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          height: 1.33,
          letterSpacing: 0.5,
          overflow: TextOverflow.ellipsis,
          fontWeight: selected && navFill != null
              ? FontWeight.w700
              : FontWeight.w500,
          color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
        );
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: navFill ?? primary.withValues(alpha: 0.22),
      selectedIconTheme: IconThemeData(
        color: navFill != null ? scheme.onSurface : primary,
      ),
      unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      selectedLabelTextStyle: TextStyle(
        color: navFill != null ? scheme.onSurface : primary,
        fontWeight: navFill != null ? FontWeight.w700 : FontWeight.w600,
      ),
      unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: primary,
      selectedColor: primary,
      selectedTileColor: primary.withValues(alpha: 0.16),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: outline),
      ),
    ),
    dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surface,
      selectedColor: scheme.surfaceContainerHighest,
      side: WidgetStateBorderSide.resolveWith(
        (_) => BorderSide(color: scheme.onSurface),
      ),
      labelStyle: TextStyle(color: scheme.onSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? primary : scheme.outline,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? primary.withValues(alpha: 0.45)
            : scheme.surfaceContainerHighest,
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: primary,
      inactiveTrackColor: primary.withValues(alpha: 0.22),
      thumbColor: primary,
      overlayColor: primary.withValues(alpha: 0.18),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.onSurface),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(style: filledLike()),
    elevatedButtonTheme: ElevatedButtonThemeData(style: filledLike()),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(brightPrimary),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.onSurface)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: ToastColors.border, width: 1.5),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: scheme.onSurface),
      ),
    ),
    dialogTheme: DialogThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.onSurface),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? scheme.onSurface.withValues(alpha: 0.38)
              : brightPrimary,
        ),
      ),
    ),
  );

  // Toast popups (snack bars) render black on white with a clear border in every theme.
  return theme.copyWith(
    snackBarTheme: theme.snackBarTheme.copyWith(
      backgroundColor: ToastColors.surface,
      contentTextStyle: theme.textTheme.bodyMedium?.copyWith(
        color: ToastColors.onSurface,
      ),
      actionTextColor: ToastColors.onSurface,
    ),
  );
}

ScrollbarThemeData wideScreenScrollbarTheme(ColorScheme scheme) =>
    ScrollbarThemeData(
      thumbVisibility: const WidgetStatePropertyAll(true),
      trackVisibility: const WidgetStatePropertyAll(false),
      thickness: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.dragged)
            ? 10
            : 8,
      ),
      radius: const Radius.circular(4),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.dragged)
            ? scheme.primary
            : scheme.onSurface.withValues(alpha: 0.22),
      ),
    );
