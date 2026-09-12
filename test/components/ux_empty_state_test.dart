import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/components/empty/empty_widget.dart';
import 'package:small_talk/components/ux_empty_state.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _supportedLocales = [
  Locale('ru'),
  Locale('en'),
];

const List<LocalizationsDelegate<dynamic>> _localizationsDelegates = [
  FFLocalizationsDelegate(),
  FallbackMaterialLocalizationDelegate(),
  FallbackCupertinoLocalizationDelegate(),
];

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await FFLocalizations.initialize();
  });

  testWidgets('UxEmptyState renders shared title and message', (tester) async {
    await tester.pumpWidget(
      const _TestShell(
        child: UxEmptyState(
          title: 'Здесь пока пусто',
          message: 'Данные появятся позже.',
          showImage: false,
          shrinkWrap: true,
          topPadding: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Здесь пока пусто'), findsOneWidget);
    expect(find.text('Данные появятся позже.'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('UxEmptyState exposes optional semantic label', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const _TestShell(
          child: UxEmptyState(
            title: 'Hidden title',
            message: 'Hidden message',
            semanticsLabel: 'Empty list state',
            liveRegion: true,
            showImage: false,
            shrinkWrap: true,
            topPadding: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Empty list state'), findsOneWidget);
      expect(find.bySemanticsLabel('Hidden title'), findsNothing);
      final stateSemantics = tester
          .getSemantics(find.bySemanticsLabel('Empty list state'))
          .getSemanticsData();
      expect(stateSemantics.flagsCollection.isLiveRegion, isTrue);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('UxEmptyState ignores blank semantic label', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const _TestShell(
          child: UxEmptyState(
            title: 'Visible title',
            message: 'Visible message',
            semanticsLabel: '   ',
            showImage: false,
            shrinkWrap: true,
            topPadding: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Visible title'), findsOneWidget);
      expect(find.bySemanticsLabel('Visible message'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('UxEmptyState keeps action semantics available', (tester) async {
    var tapCount = 0;
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        _TestShell(
          child: UxEmptyState(
            title: 'Hidden title',
            message: 'Hidden message',
            semanticsLabel: 'Empty list state',
            showImage: false,
            shrinkWrap: true,
            topPadding: 0,
            action: TextButton(
              onPressed: () => tapCount += 1,
              child: const Text('Повторить'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Empty list state'), findsOneWidget);
      expect(find.bySemanticsLabel('Повторить'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Повторить'));

      expect(tapCount, 1);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('UxEmptyState image is decorative for semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const _TestShell(
          child: UxEmptyState(
            title: 'Здесь пока пусто',
            message: 'Данные появятся позже.',
            shrinkWrap: true,
            topPadding: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.excludeFromSemantics, isTrue);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('EmptyWidget keeps legacy API on top of UxEmptyState',
      (tester) async {
    await tester.pumpWidget(
      const _TestShell(
        child: EmptyWidget(
          txt: 'Старое сообщение',
          shrinkWrap: true,
          topPadding: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(UxEmptyState), findsOneWidget);
    expect(find.text('Здесь пока пусто'), findsOneWidget);
    expect(find.text('Старое сообщение'), findsOneWidget);
  });

  testWidgets('EmptyWidget keeps legacy fallback message', (tester) async {
    await tester.pumpWidget(
      const _TestShell(
        child: EmptyWidget(
          txt: null,
          shrinkWrap: true,
          topPadding: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(UxEmptyState), findsOneWidget);
    expect(find.text('-'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
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
      locale: const Locale('ru'),
      supportedLocales: _supportedLocales,
      localizationsDelegates: _localizationsDelegates,
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }
}
