import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/custom_code/widgets/call_controls_bar.dart';

Widget _buildSubject({
  bool isVisible = true,
  bool cameraEnabled = true,
  bool microphoneEnabled = true,
  bool isChatOpen = false,
  int unreadChatCount = 0,
  VoidCallback? onTranslationPressed,
  VoidCallback? onCameraPressed,
  VoidCallback? onMicrophonePressed,
  VoidCallback? onChatPressed,
  VoidCallback? onEndCallPressed,
  Locale locale = const Locale('ru'),
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('ru'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CallControlsBar(
          isVisible: isVisible,
          cameraEnabled: cameraEnabled,
          microphoneEnabled: microphoneEnabled,
          isChatOpen: isChatOpen,
          unreadChatCount: unreadChatCount,
          onCameraPressed: onCameraPressed ?? () {},
          onMicrophonePressed: onMicrophonePressed ?? () {},
          onChatPressed: onChatPressed ?? () {},
          onTranslationPressed: onTranslationPressed,
          onEndCallPressed: onEndCallPressed ?? () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('preserves control actions, sizes, and optional translation',
      (tester) async {
    var cameraCalls = 0;
    var microphoneCalls = 0;
    var chatCalls = 0;
    var translationCalls = 0;
    var endCallCalls = 0;

    await tester.pumpWidget(
      _buildSubject(
        onCameraPressed: () => cameraCalls += 1,
        onMicrophonePressed: () => microphoneCalls += 1,
        onChatPressed: () => chatCalls += 1,
        onTranslationPressed: () => translationCalls += 1,
        onEndCallPressed: () => endCallCalls += 1,
      ),
    );

    expect(find.byKey(callTranslationControlKey), findsOneWidget);
    for (final key in <Key>[
      callCameraControlKey,
      callMicrophoneControlKey,
      callChatControlKey,
      callTranslationControlKey,
      callEndControlKey,
    ]) {
      expect(tester.getSize(find.byKey(key)), const Size.square(60));
      await tester.tap(find.byKey(key));
    }

    expect(cameraCalls, 1);
    expect(microphoneCalls, 1);
    expect(chatCalls, 1);
    expect(translationCalls, 1);
    expect(endCallCalls, 1);

    await tester.pumpWidget(_buildSubject());
    expect(find.byKey(callTranslationControlKey), findsNothing);
  });

  testWidgets('exposes Russian toggle semantics and capped unread badge',
      (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _buildSubject(
        cameraEnabled: false,
        microphoneEnabled: false,
        unreadChatCount: 120,
      ),
    );

    final camera = tester.getSemantics(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Камера выключена. Включить камеру',
      ),
    );
    expect(camera.label, 'Камера выключена. Включить камеру');
    expect(camera.hint, 'Переключает камеру в звонке');
    expect(camera.flagsCollection.isButton, isTrue);
    expect(camera.flagsCollection.isToggled, isFalse);

    final microphone = tester.getSemantics(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Микрофон выключен. Включить микрофон',
      ),
    );
    expect(microphone.label, 'Микрофон выключен. Включить микрофон');
    expect(microphone.flagsCollection.isToggled, isFalse);

    final chat = tester.getSemantics(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label ==
                'Чат закрыт. Открыть чат. '
                    'Больше 99 непрочитанных сообщений',
      ),
    );
    expect(
      chat.label,
      'Чат закрыт. Открыть чат. Больше 99 непрочитанных сообщений',
    );
    expect(chat.hint, 'Открывает или скрывает чат звонка');
    expect(find.text('99+'), findsOneWidget);

    final tooltip = tester.widget<Tooltip>(
      find.descendant(
        of: find.byKey(callChatControlKey),
        matching: find.byType(Tooltip),
      ),
    );
    expect(tooltip.message, 'Открыть чат, Больше 99 непрочитанных сообщений');
    semantics.dispose();
  });

  testWidgets('exposes English labels hints and tooltips', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _buildSubject(
        locale: const Locale('en'),
        cameraEnabled: false,
        microphoneEnabled: false,
        unreadChatCount: 120,
        onTranslationPressed: () {},
      ),
    );

    final camera = tester.getSemantics(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Camera off. Turn camera on',
      ),
    );
    expect(camera.hint, 'Toggles the camera during the call');
    expect(camera.flagsCollection.isToggled, isFalse);

    final chat = tester.getSemantics(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label ==
                'Chat closed. Open chat. More than 99 unread messages',
      ),
    );
    expect(chat.hint, 'Opens or closes the call chat');

    final translationTooltip = tester.widget<Tooltip>(
      find.descendant(
        of: find.byKey(callTranslationControlKey),
        matching: find.byType(Tooltip),
      ),
    );
    expect(translationTooltip.message, 'Quick translation');

    final endCall = tester.getSemantics(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'End call',
      ),
    );
    expect(endCall.hint, 'Ends the current video call');
    semantics.dispose();
  });

  testWidgets('preserves active, inactive, and end-call surface colors',
      (tester) async {
    await tester.pumpWidget(
      _buildSubject(
        cameraEnabled: true,
        microphoneEnabled: false,
      ),
    );

    BoxDecoration decorationFor(Key key) {
      final surface = find.descendant(
        of: find.byKey(key),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.constraints ==
                  const BoxConstraints.tightFor(
                    width: 60,
                    height: 60,
                  ),
        ),
      );
      return tester.widget<Container>(surface).decoration! as BoxDecoration;
    }

    final active = decorationFor(callCameraControlKey);
    expect(active.color, Colors.black.withValues(alpha: 0.76));
    expect((active.border! as Border).top.width, 0.8);
    expect(
      (active.border! as Border).top.color,
      Colors.white.withValues(alpha: 0.18),
    );

    final inactive = decorationFor(callMicrophoneControlKey);
    expect(inactive.color, Colors.black.withValues(alpha: 0.6));
    expect(
      (inactive.border! as Border).top.color,
      Colors.white.withValues(alpha: 0.08),
    );

    final endCall = decorationFor(callEndControlKey);
    expect(endCall.color, Colors.red.withValues(alpha: 0.9));
    expect(endCall.border, isNull);
  });

  testWidgets('renders no controls when hidden', (tester) async {
    await tester.pumpWidget(_buildSubject(isVisible: false));

    expect(find.byKey(callControlsBarKey), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });
}
