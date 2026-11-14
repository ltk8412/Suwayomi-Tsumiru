import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tsumiru/src/global_providers/global_providers.dart';
import 'package:tsumiru/src/routes/router_config.dart';
import 'package:tsumiru/src/utils/motion/reduce_motion.dart';

const _nextKey = ValueKey('next');

class _Probe {
  bool? reduceMotion;
  ThemeData? theme;
  BuildContext? context;
}

Widget _app(_Probe probe) {
  return ProviderScope(
    overrides: [
      // E-ink mode's providers read shared prefs inside ReduceMotionScope.
      sharedPreferencesProvider.overrideWithValue(_prefs),
    ],
    child: MaterialApp(
      builder: (context, child) => ReduceMotionScope(child: child!),
      home: Builder(
        builder: (context) {
          probe
            ..reduceMotion = context.reduceMotion
            ..theme = Theme.of(context)
            ..context = context;
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const Scaffold(key: _nextKey, body: Text('next')),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          );
        },
      ),
    ),
  );
}

bool _hasTransitionAbove(WidgetTester tester, Finder page) {
  return tester
      .widgetList(
        find.ancestor(
          of: page,
          matching: find.byWidgetPredicate(
            (w) => w is FadeTransition || w is SlideTransition,
          ),
        ),
      )
      .isNotEmpty;
}

Future<void> _pushNext(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  // The pushed route is built on the frame after the Navigator inserts it.
  await tester.pump();
  await tester.pump();
}

Future<void> _popNext(WidgetTester tester, _Probe probe) async {
  await tester.pumpAndSettle();
  Navigator.of(probe.context!).pop();
  await tester.pump();
}

void _expectReduced(_Probe probe) {
  expect(probe.reduceMotion, isTrue);
  expect(probe.theme!.splashFactory, NoSplash.splashFactory);
  expect(
    probe.theme!.expansionTileTheme.expansionAnimationStyle,
    AnimationStyle.noAnimation,
  );
}

Future<void> _expectPageAppearsInstantly(WidgetTester tester) async {
  await _pushNext(tester);
  expect(find.byKey(_nextKey), findsOneWidget);
  expect(_hasTransitionAbove(tester, find.byKey(_nextKey)), isFalse);
  expect(tester.getTopLeft(find.byKey(_nextKey)), Offset.zero);
}

late SharedPreferences _prefs;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
  });

  testWidgets('e-ink fork always reduces motion, at runtime and on routes', (
    tester,
  ) async {
    final control = _Probe();
    await tester.pumpWidget(_app(control));
    _expectReduced(control);
    await _expectPageAppearsInstantly(tester);

    // A closing page is hidden at once.
    await tester.pumpWidget(const SizedBox.shrink());
    final probe = _Probe();
    await tester.pumpWidget(_app(probe));
    await _pushNext(tester);
    await _popNext(tester, probe);
    expect(find.byKey(_nextKey), findsNothing);
    expect(find.byKey(_nextKey, skipOffstage: false), findsOneWidget);
    expect(find.text('open'), findsOneWidget);

    // The reader route wraps in the closing-page hider.
    const route = ReaderRoute(mangaId: 1, chapterId: 1, transVertical: false);
    const page = SizedBox(key: ValueKey('page'));
    const animation = AlwaysStoppedAnimation<double>(0);
    final reduced = route.transitionsBuilder(
      probe.context!,
      animation,
      animation,
      page,
    );
    expect(
      reduced,
      isA<ReducedRouteTransition>().having((w) => w.child, 'child', same(page)),
    );
  });
}
