import 'package:material_ui/material_ui.dart';

/// Named-theme values copied from theme-kit light/dark CSS blocks.
class ThemeTokens {
  const ThemeTokens({
    required this.bg,
    required this.bg2,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.accent2,
    required this.danger,
    required this.border,
    this.onAccent,
    this.accentBg,
    this.accentFill,
    this.grad,
  });

  final Color bg; // scaffold / base surface  (--bg)
  final Color bg2; // elevated panels, cards, app bars, sheets  (--bg2)
  final Color ink; // primary text  (--ink → onSurface)
  final Color muted; // secondary text  (--muted → onSurfaceVariant)
  final Color faint; // outline  (--faint)
  final Color accent; // primary  (--accent)
  final Color accent2; // secondary / tertiary  (--accent2)
  final Color danger; // error  (--danger)
  final Color border; // panel border overlay  (--panel-brd → outlineVariant)

  // Null when the mode does not supply the token.
  final Color? onAccent; // text on a filled accent  (--on-accent)
  final Color? accentBg; // tinted accent container  (--accent-bg)
  final Color? accentFill; // selected nav fill  (--accent-fill)
  final LinearGradient? grad; // brand gradient  (--grad)
}

// Paper-white e-ink: flat pure surfaces, pure black ink, no decorative hues.
// The flat single-color gradients keep Brand components solid.
const _einkPaperDark = ThemeTokens(
  bg: Color(0xFF000000),
  bg2: Color(0xFF0F0F0F),
  ink: Color(0xFFFFFFFF),
  muted: Color(0xFFB8B8B8),
  faint: Color(0xFF7A7A7A),
  accent: Color(0xFFFFFFFF),
  accent2: Color(0xFFB8B8B8),
  danger: Color(0xFFFF6B6B),
  border: Color(0x24FFFFFF),
  onAccent: Color(0xFF000000),
  accentFill: Color(0xFF3A3A3A),
  grad: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
  ),
);
const _einkPaperLight = ThemeTokens(
  bg: Color(0xFFFFFFFF),
  bg2: Color(0xFFFFFFFF),
  ink: Color(0xFF000000),
  muted: Color(0xFF333333),
  faint: Color(0xFF767676),
  accent: Color(0xFF000000),
  accent2: Color(0xFF333333),
  danger: Color(0xFFAE2F34),
  border: Color(0xFFC4C4C4),
  onAccent: Color(0xFFFFFFFF),
  accentBg: Color(0xFFE8E8E8),
  grad: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF000000), Color(0xFF000000)],
  ),
);

ThemeTokens tokensFor(Brightness brightness) =>
    brightness == Brightness.dark ? _einkPaperDark : _einkPaperLight;
