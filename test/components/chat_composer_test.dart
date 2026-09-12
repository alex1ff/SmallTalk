import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/components/chat_composer.dart';
import 'package:small_talk/shared_pages/design/expatlio_design.dart';

const _composerKey = ValueKey<String>('test_chat_composer');
const _inputKey = ValueKey<String>('test_chat_composer_input');
const _sendButtonKey = ValueKey<String>('test_chat_composer_send');

Widget _buildComposer({
  required TextEditingController controller,
  required FocusNode focusNode,
  required VoidCallback onSendPressed,
  bool enabled = true,
  bool isSending = false,
  bool keyboardOpen = false,
}) {
  return MaterialApp(
    theme: ExpatlioDesign.lightTheme(),
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        viewPadding: const EdgeInsets.only(bottom: 34),
        padding: EdgeInsets.only(bottom: keyboardOpen ? 0 : 34),
        viewInsets: EdgeInsets.only(bottom: keyboardOpen ? 320 : 0),
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Align(
          alignment: Alignment.bottomCenter,
          child: ChatComposer(
            key: _composerKey,
            controller: controller,
            focusNode: focusNode,
            onSendPressed: onSendPressed,
            hintText: 'Написать сообщение',
            sendButtonSemanticLabel: 'Отправить сообщение',
            enabled: enabled,
            isSending: isSending,
            inputKey: _inputKey,
            sendButtonKey: _sendButtonKey,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders iMessage capsule and activates purple send button',
      (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    var sendCalls = 0;

    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        focusNode: focusNode,
        onSendPressed: () => sendCalls += 1,
      ),
    );

    expect(tester.getSize(find.byKey(chatComposerCapsuleKey)).height, 44);
    expect(
      tester.getSize(find.byKey(chatComposerSendCircleKey)),
      const Size.square(36),
    );
    expect(
      tester.widget<Material>(find.byKey(chatComposerSendCircleKey)).color,
      ExpatlioDesign.secondarySystemFill,
    );

    await tester.tap(find.byKey(_sendButtonKey));
    expect(sendCalls, 0);

    await tester.enterText(find.byKey(_inputKey), 'Привет');
    await tester.pump();

    expect(
      tester.widget<Material>(find.byKey(chatComposerSendCircleKey)).color,
      ExpatlioDesign.primary,
    );
    await tester.tap(find.byKey(_sendButtonKey));
    expect(sendCalls, 1);
  });

  testWidgets('submits from keyboard and blocks send while pending',
      (tester) async {
    final controller = TextEditingController(text: 'Сообщение');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    var sendCalls = 0;

    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        focusNode: focusNode,
        onSendPressed: () => sendCalls += 1,
      ),
    );
    await tester.tap(find.byKey(_inputKey));
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(sendCalls, 1);

    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        focusNode: focusNode,
        onSendPressed: () => sendCalls += 1,
        isSending: true,
      ),
    );
    await tester.tap(find.byKey(_sendButtonKey));
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();

    expect(sendCalls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<TextFormField>(find.byKey(_inputKey)).enabled, isTrue);
  });

  testWidgets('grows to four lines and disables editing when unavailable',
      (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        focusNode: focusNode,
        onSendPressed: () {},
      ),
    );
    final textField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(_inputKey),
        matching: find.byType(TextField),
      ),
    );
    expect(textField.minLines, 1);
    expect(textField.maxLines, 4);
    final initialHeight =
        tester.getSize(find.byKey(chatComposerCapsuleKey)).height;

    await tester.enterText(
      find.byKey(_inputKey),
      List<String>.filled(30, 'Длинное сообщение').join(' '),
    );
    await tester.pump();

    final expandedHeight =
        tester.getSize(find.byKey(chatComposerCapsuleKey)).height;
    expect(expandedHeight, greaterThan(initialHeight));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        focusNode: focusNode,
        onSendPressed: () {},
        enabled: false,
      ),
    );
    expect(
        tester.widget<TextFormField>(find.byKey(_inputKey)).enabled, isFalse);
  });

  testWidgets('consumes home indicator inset only while keyboard is closed',
      (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        focusNode: focusNode,
        onSendPressed: () {},
      ),
    );
    final closedHeight = tester.getSize(find.byKey(_composerKey)).height;

    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        focusNode: focusNode,
        onSendPressed: () {},
        keyboardOpen: true,
      ),
    );
    final openHeight = tester.getSize(find.byKey(_composerKey)).height;

    expect(closedHeight - openHeight, 34);
    expect(openHeight, 60);
  });

  testWidgets('exposes localized send semantics and enabled state',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = TextEditingController(text: 'Привет');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        focusNode: focusNode,
        onSendPressed: () {},
      ),
    );

    final node = tester.getSemantics(find.byKey(_sendButtonKey));
    expect(node.label, 'Отправить сообщение');
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isEnabled, isTrue);
    semantics.dispose();
  });
}
