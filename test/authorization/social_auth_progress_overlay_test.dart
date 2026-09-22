import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/authorization/shared/social_auth_progress_overlay.dart';

void main() {
  testWidgets('social auth overlay explains the pending redirect',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                SocialAuthProgressOverlay(
                  title: 'Завершаем вход…',
                  message: 'Загружаем ваш профиль.',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byKey(socialAuthProgressOverlayKey), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Завершаем вход…'), findsOneWidget);
      expect(find.text('Загружаем ваш профиль.'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Завершаем вход…. Загружаем ваш профиль.',
        ),
        findsOneWidget,
      );

      final barrier = tester.widget<ModalBarrier>(
        find.byWidgetPredicate(
          (widget) => widget is ModalBarrier && widget.color != null,
        ),
      );
      expect(barrier.dismissible, isFalse);
    } finally {
      semantics.dispose();
    }
  });
}
