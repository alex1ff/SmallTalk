import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/components/ux_error_state.dart';

const _stateKey = ValueKey<String>('error_state');
const _retryKey = ValueKey<String>('error_retry');

void main() {
  testWidgets('UxErrorState renders message and retry action', (tester) async {
    var retryCount = 0;

    await tester.pumpWidget(
      _TestShell(
        child: UxErrorState(
          stateKey: _stateKey,
          title: 'Не удалось загрузить события',
          message: 'Проверьте подключение.',
          retryLabel: 'Повторить',
          retrySemanticsLabel: 'Повторить загрузку событий',
          retryButtonKey: _retryKey,
          onRetry: () => retryCount += 1,
        ),
      ),
    );

    expect(find.text('Не удалось загрузить события'), findsOneWidget);
    expect(find.text('Проверьте подключение.'), findsOneWidget);
    expect(find.text('Повторить'), findsOneWidget);

    await tester.tap(find.byKey(_retryKey));

    expect(retryCount, 1);
  });

  testWidgets('UxErrorState exposes state and retry semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        _TestShell(
          child: UxErrorState(
            stateKey: _stateKey,
            title: 'Load failed',
            message: 'Try again.',
            retryLabel: 'Retry',
            retrySemanticsLabel: 'Retry loading data',
            retryButtonKey: _retryKey,
            onRetry: () {},
          ),
        ),
      );

      final stateSemantics = tester.widget<Semantics>(find.byKey(_stateKey));
      expect(stateSemantics.container, isTrue);
      expect(stateSemantics.explicitChildNodes, isTrue);
      expect(stateSemantics.properties.liveRegion, isTrue);
      expect(stateSemantics.properties.label, 'Load failed. Try again.');

      final retrySemantics = tester.widget<Semantics>(find.byKey(_retryKey));
      expect(retrySemantics.container, isTrue);
      expect(retrySemantics.properties.button, isTrue);
      expect(retrySemantics.properties.enabled, isTrue);
      expect(retrySemantics.properties.label, 'Retry loading data');
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('UxErrorState supports disabled retry semantics', (tester) async {
    await tester.pumpWidget(
      const _TestShell(
        child: UxErrorState(
          stateKey: _stateKey,
          title: 'Load failed',
          message: 'Try again.',
          retryLabel: 'Retry',
          retryButtonKey: _retryKey,
        ),
      ),
    );

    final retrySemantics = tester.widget<Semantics>(find.byKey(_retryKey));
    expect(retrySemantics.properties.enabled, isFalse);
  });

  testWidgets('UxErrorState supports compact contained presentation',
      (tester) async {
    await tester.pumpWidget(
      const _TestShell(
        child: UxErrorState(
          stateKey: _stateKey,
          title: 'Load failed',
          message: 'Try again.',
          retryLabel: 'Retry',
          retryButtonKey: _retryKey,
          showIcon: false,
          contained: true,
          padding: EdgeInsets.all(16),
          titleSize: 17,
          retryMinHeight: 44,
        ),
      ),
    );

    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    expect(find.text('Load failed'), findsOneWidget);

    final decoratedContainer = tester
        .widgetList<Container>(
          find.byType(Container),
        )
        .where((container) => container.decoration != null);
    expect(decoratedContainer, isNotEmpty);
  });
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
        body: Center(child: child),
      ),
    );
  }
}
