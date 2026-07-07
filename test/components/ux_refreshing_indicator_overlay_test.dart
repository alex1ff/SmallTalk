import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/components/ux_refreshing_indicator_overlay.dart';
import 'package:small_talk/services/ux_loading_state.dart';
import 'package:small_talk/shared_pages/design/expatlio_design.dart';

void main() {
  group('UxPreviousDataRefreshLayer', () {
    testWidgets('keeps child visible and shows indicator while refreshing',
        (tester) async {
      final state = UxLoadingState<List<String>>.resolve(
        activeDataKey: 'events',
        isLoading: true,
        lastSuccessfulResult: UxLoadedResult<List<String>>.data(
          dataKey: 'events',
          data: const <String>['club'],
        ),
      );

      await tester.pumpWidget(
        _TestShell(
          child: UxPreviousDataRefreshLayer<List<String>>(
            state: state,
            duration: Duration.zero,
            child: const Text('previous content'),
          ),
        ),
      );

      expect(find.text('previous content'), findsOneWidget);
      expect(find.byType(UxRefreshingIndicatorPill), findsOneWidget);
    });

    testWidgets('keeps indicator hidden when state is not refreshing',
        (tester) async {
      final state = UxLoadingState<List<String>>.resolve(
        activeDataKey: 'events',
        isLoading: false,
        newResult: UxLoadedResult<List<String>>.data(
          dataKey: 'events',
          data: const <String>['club'],
        ),
      );

      await tester.pumpWidget(
        _TestShell(
          child: UxPreviousDataRefreshLayer<List<String>>(
            state: state,
            duration: Duration.zero,
            child: const Text('loaded content'),
          ),
        ),
      );

      expect(find.text('loaded content'), findsOneWidget);
      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(opacity.opacity, 0.0);
      expect(find.byType(UxRefreshingIndicatorPill), findsNothing);
    });
  });

  group('UxRefreshingIndicatorOverlay', () {
    testWidgets('does not change child layout size', (tester) async {
      const rootKey = Key('refresh-root');
      const childKey = Key('refresh-child');

      await tester.pumpWidget(
        const _TestShell(
          child: SizedBox(
            key: rootKey,
            width: 220.0,
            height: 120.0,
            child: UxRefreshingIndicatorOverlay(
              isRefreshing: true,
              duration: Duration.zero,
              child: SizedBox.expand(key: childKey),
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byKey(rootKey)), const Size(220.0, 120.0));
      expect(tester.getSize(find.byKey(childKey)), const Size(220.0, 120.0));
    });

    testWidgets('passes parent constraints through to the child',
        (tester) async {
      await tester.pumpWidget(
        const _TestShell(
          child: SizedBox(
            width: 220.0,
            height: 120.0,
            child: UxRefreshingIndicatorOverlay(
              isRefreshing: true,
              duration: Duration.zero,
              child: _ConstraintProbe(),
            ),
          ),
        ),
      );

      expect(find.text('220x220/120x120'), findsOneWidget);
    });

    testWidgets('does not intercept taps intended for content', (tester) async {
      var tapCount = 0;

      await tester.pumpWidget(
        _TestShell(
          child: SizedBox(
            width: 220.0,
            height: 120.0,
            child: UxRefreshingIndicatorOverlay(
              isRefreshing: true,
              duration: Duration.zero,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => tapCount += 1,
                child: const SizedBox.expand(
                  child: Center(child: Text('Tap me')),
                ),
              ),
            ),
          ),
        ),
      );

      await tester
          .tapAt(tester.getCenter(find.byType(UxRefreshingIndicatorPill)));

      expect(tapCount, 1);
    });

    testWidgets('keeps overlay mounted across refresh visibility changes',
        (tester) async {
      await tester.pumpWidget(
        const _TestShell(
          child: SizedBox(
            width: 220.0,
            height: 120.0,
            child: UxRefreshingIndicatorOverlay(
              isRefreshing: true,
              duration: Duration(milliseconds: 180),
              child: SizedBox.expand(),
            ),
          ),
        ),
      );

      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1.0,
      );

      await tester.pumpWidget(
        const _TestShell(
          child: SizedBox(
            width: 220.0,
            height: 120.0,
            child: UxRefreshingIndicatorOverlay(
              isRefreshing: false,
              duration: Duration(milliseconds: 180),
              child: SizedBox.expand(),
            ),
          ),
        ),
      );

      expect(find.byType(UxRefreshingIndicatorPill), findsNothing);

      await tester.pump(const Duration(milliseconds: 90));
      final fadeTransitionFinder = find.descendant(
        of: find.byType(UxRefreshingIndicatorOverlay),
        matching: find.byType(FadeTransition),
      );
      final midpointOpacity =
          tester.widget<FadeTransition>(fadeTransitionFinder).opacity.value;
      expect(midpointOpacity, greaterThan(0.0));
      expect(midpointOpacity, lessThan(1.0));

      await tester.pump(const Duration(milliseconds: 180));
      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0.0,
      );

      await tester.pumpWidget(
        const _TestShell(
          child: SizedBox(
            width: 220.0,
            height: 120.0,
            child: UxRefreshingIndicatorOverlay(
              isRefreshing: true,
              duration: Duration(milliseconds: 180),
              child: SizedBox.expand(),
            ),
          ),
        ),
      );

      expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1.0,
      );
      expect(find.byType(UxRefreshingIndicatorPill), findsOneWidget);
    });

    testWidgets('exposes refreshing semantics only while visible',
        (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          const _TestShell(
            child: UxRefreshingIndicatorOverlay(
              isRefreshing: true,
              duration: Duration.zero,
              child: Text('content'),
            ),
          ),
        );

        expect(find.bySemanticsLabel('Обновление'), findsOneWidget);

        await tester.pumpWidget(
          const _TestShell(
            child: UxRefreshingIndicatorOverlay(
              isRefreshing: false,
              duration: Duration.zero,
              child: Text('content'),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(UxRefreshingIndicatorPill), findsNothing);
        expect(find.bySemanticsLabel('Обновление'), findsNothing);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('applies semantics label to a custom indicator',
        (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          const _TestShell(
            child: UxRefreshingIndicatorOverlay(
              isRefreshing: true,
              semanticsLabel: 'Custom refresh',
              duration: Duration.zero,
              indicator: Text('custom indicator'),
              child: Text('content'),
            ),
          ),
        );

        final semanticsData = tester
            .getSemantics(find.text('custom indicator'))
            .getSemanticsData();

        expect(
          semanticsData.label,
          contains('Custom refresh'),
        );
        expect(semanticsData.flagsCollection.isLiveRegion, isTrue);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('disables indicator ticker while hidden', (tester) async {
      await tester.pumpWidget(
        const _TestShell(
          child: UxRefreshingIndicatorOverlay(
            isRefreshing: false,
            duration: Duration.zero,
            child: Text('content'),
          ),
        ),
      );

      final indicatorTicker = tester.widget<TickerMode>(
        find.descendant(
          of: find.byType(UxRefreshingIndicatorOverlay),
          matching: find.byType(TickerMode),
        ),
      );

      expect(indicatorTicker.enabled, isFalse);
    });

    testWidgets('places the indicator at the top by default', (tester) async {
      const parentKey = Key('refresh-parent');
      await tester.pumpWidget(
        const _TestShell(
          child: SizedBox(
            key: parentKey,
            width: 220.0,
            height: 120.0,
            child: UxRefreshingIndicatorOverlay(
              isRefreshing: true,
              duration: Duration.zero,
              child: SizedBox.expand(),
            ),
          ),
        ),
      );

      final parentTop = tester.getTopLeft(find.byKey(parentKey)).dy;
      final overlayTop =
          tester.getTopLeft(find.byType(UxRefreshingIndicatorPill)).dy;

      expect(overlayTop, greaterThan(parentTop));
      expect(overlayTop - parentTop, ExpatlioDesign.space8);
    });

    testWidgets('can place the indicator at the bottom', (tester) async {
      const parentKey = Key('refresh-parent');
      await tester.pumpWidget(
        const _TestShell(
          child: SizedBox(
            key: parentKey,
            width: 220.0,
            height: 120.0,
            child: UxRefreshingIndicatorOverlay(
              isRefreshing: true,
              position: UxRefreshIndicatorPosition.bottom,
              duration: Duration.zero,
              child: SizedBox.expand(),
            ),
          ),
        ),
      );

      final parentBottom = tester.getBottomLeft(find.byKey(parentKey)).dy;
      final overlayBottom =
          tester.getBottomLeft(find.byType(UxRefreshingIndicatorPill)).dy;

      expect(overlayBottom, lessThan(parentBottom));
      expect(parentBottom - overlayBottom, ExpatlioDesign.space8);
    });
  });
}

class _ConstraintProbe extends StatelessWidget {
  const _ConstraintProbe();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Text(
          '${constraints.minWidth.toInt()}x${constraints.maxWidth.toInt()}/'
          '${constraints.minHeight.toInt()}x${constraints.maxHeight.toInt()}',
        );
      },
    );
  }
}

class _TestShell extends StatelessWidget {
  const _TestShell({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: child,
        ),
      ),
    );
  }
}
