import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/shared_pages/chat_local_message_status.dart';
import 'package:small_talk/shared_pages/chat_thread/chat_thread_widget.dart';

const List<LocalizationsDelegate<dynamic>> _localizationsDelegates = [
  FFLocalizationsDelegate(),
  FallbackMaterialLocalizationDelegate(),
  FallbackCupertinoLocalizationDelegate(),
];

const String _previousMessageKey = 'messages/previous';
const String _targetMessageKey = 'messages/target';
const String _nextMessageKey = 'messages/next';

typedef _BubbleGeometry = ({
  Rect previousItem,
  Rect previousBubble,
  Rect targetItem,
  Rect targetBubble,
  Rect timestampSlot,
  Rect statusSlot,
  Rect retrySlot,
  Rect nextItem,
  Rect nextBubble,
});

class _BubbleGeometryHarness extends StatefulWidget {
  const _BubbleGeometryHarness({
    super.key,
    required this.timestampText,
  });

  final String timestampText;

  @override
  State<_BubbleGeometryHarness> createState() => _BubbleGeometryHarnessState();
}

class _BubbleGeometryHarnessState extends State<_BubbleGeometryHarness> {
  ChatLocalMessageStatus? _status = ChatLocalMessageStatus.sending;
  String? _timestampText;
  var retryCount = 0;

  @override
  void initState() {
    super.initState();
    _timestampText = widget.timestampText;
  }

  void showStatus(ChatLocalMessageStatus status) {
    setState(() {
      _status = status;
      _timestampText = widget.timestampText;
    });
  }

  void showConfirmed({required bool withTimestamp}) {
    setState(() {
      _status = null;
      _timestampText = withTimestamp ? widget.timestampText : null;
    });
  }

  void _retry() {
    setState(() {
      retryCount += 1;
      _status = ChatLocalMessageStatus.sending;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        _messageItem(
          messageKey: _previousMessageKey,
          child: ChatThreadMessageBubble(
            messageKey: _previousMessageKey,
            text: 'Previous message',
            timestampText: widget.timestampText,
            isCurrentUser: false,
            isReadByPartner: false,
          ),
        ),
        _messageItem(
          messageKey: _targetMessageKey,
          child: ChatThreadMessageBubble(
            messageKey: _targetMessageKey,
            text: 'OK',
            timestampText: _timestampText,
            isCurrentUser: true,
            isReadByPartner: false,
            localStatus: _status,
            onRetry: _status == ChatLocalMessageStatus.failed ? _retry : null,
          ),
        ),
        _messageItem(
          messageKey: _nextMessageKey,
          child: ChatThreadMessageBubble(
            messageKey: _nextMessageKey,
            text: 'Next message',
            timestampText: widget.timestampText,
            isCurrentUser: false,
            isReadByPartner: false,
          ),
        ),
      ],
    );
  }
}

Widget _messageItem({
  required String messageKey,
  required Widget child,
}) {
  return Column(
    key: chatThreadMessageItemKey(messageKey),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [child],
  );
}

Widget _buildTestApp({
  required Locale locale,
  required TextScaler textScaler,
  required GlobalKey<_BubbleGeometryHarnessState> harnessKey,
  required String timestampText,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('ru'), Locale('en')],
    localizationsDelegates: _localizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: child!,
    ),
    home: Scaffold(
      body: _BubbleGeometryHarness(
        key: harnessKey,
        timestampText: timestampText,
      ),
    ),
  );
}

_BubbleGeometry _captureGeometry(WidgetTester tester) {
  return (
    previousItem: tester
        .getRect(find.byKey(chatThreadMessageItemKey(_previousMessageKey))),
    previousBubble: tester
        .getRect(find.byKey(chatThreadMessageBubbleKey(_previousMessageKey))),
    targetItem:
        tester.getRect(find.byKey(chatThreadMessageItemKey(_targetMessageKey))),
    targetBubble: tester
        .getRect(find.byKey(chatThreadMessageBubbleKey(_targetMessageKey))),
    timestampSlot: tester.getRect(
      find.byKey(chatThreadMessageTimestampSlotKey(_targetMessageKey)),
    ),
    statusSlot: tester.getRect(
      find.byKey(chatThreadMessageStatusSlotKey(_targetMessageKey)),
    ),
    retrySlot: tester.getRect(
      find.byKey(chatThreadMessageRetrySlotKey(_targetMessageKey)),
    ),
    nextItem:
        tester.getRect(find.byKey(chatThreadMessageItemKey(_nextMessageKey))),
    nextBubble:
        tester.getRect(find.byKey(chatThreadMessageBubbleKey(_nextMessageKey))),
  );
}

void _expectGeometry(
  WidgetTester tester,
  _BubbleGeometry expected,
) {
  expect(_captureGeometry(tester), expected);
  expect(tester.takeException(), isNull);
}

void main() {
  for (final configuration in const <({
    Locale locale,
    double devicePixelRatio,
    double textScale,
    String timestampText,
    String retryLabel,
    String name,
  })>[
    (
      locale: Locale('ru'),
      devicePixelRatio: 1,
      textScale: 1,
      timestampText: '12:34',
      retryLabel: 'Повторить',
      name: 'RU/DPR1',
    ),
    (
      locale: Locale('en'),
      devicePixelRatio: 3,
      textScale: 1,
      timestampText: '12:34 PM',
      retryLabel: 'Retry',
      name: 'EN/DPR3',
    ),
    (
      locale: Locale('ru'),
      devicePixelRatio: 2,
      textScale: 2,
      timestampText: '12:34',
      retryLabel: 'Повторить',
      name: 'RU/DPR2/text-scale-2',
    ),
  ]) {
    testWidgets(
      'message bubble and neighbors stay fixed across optimistic states '
      '(${configuration.name})',
      (tester) async {
        tester.view.devicePixelRatio = configuration.devicePixelRatio;
        tester.view.physicalSize = Size(
          320 * configuration.devicePixelRatio,
          900 * configuration.devicePixelRatio,
        );
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        final semantics = tester.ensureSemantics();
        try {
          final harnessKey = GlobalKey<_BubbleGeometryHarnessState>();
          await tester.pumpWidget(
            _buildTestApp(
              locale: configuration.locale,
              textScaler: TextScaler.linear(configuration.textScale),
              harnessKey: harnessKey,
              timestampText: configuration.timestampText,
            ),
          );
          await tester.pump();

          final retryButton = find.byKey(
            chatThreadMessageRetryButtonKey(_targetMessageKey),
          );
          final targetStatusSlot = find.byKey(
            chatThreadMessageStatusSlotKey(_targetMessageKey),
          );
          final timestampText = find.byKey(
            chatThreadMessageTimestampTextKey(_targetMessageKey),
          );
          expect(retryButton, findsOneWidget);
          expect(timestampText, findsOneWidget);
          expect(
            tester
                .renderObject<RenderParagraph>(timestampText)
                .didExceedMaxLines,
            isFalse,
          );
          expect(retryButton.hitTestable(), findsNothing);
          expect(find.bySemanticsLabel(configuration.retryLabel), findsNothing);
          expect(
            find.descendant(
              of: targetStatusSlot,
              matching: find.byIcon(Icons.schedule_rounded),
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);

          final baseline = _captureGeometry(tester);
          expect(baseline.statusSlot.size, const Size.square(14));
          expect(
            baseline.timestampSlot.width,
            configuration.locale.languageCode == 'en' ? 92 : 60,
          );
          expect(baseline.retrySlot.width, greaterThan(0));

          harnessKey.currentState!.showStatus(ChatLocalMessageStatus.sent);
          await tester.pump();
          expect(retryButton.hitTestable(), findsNothing);
          expect(
            find.descendant(
              of: targetStatusSlot,
              matching: find.byIcon(Icons.done_rounded),
            ),
            findsOneWidget,
          );
          _expectGeometry(tester, baseline);

          harnessKey.currentState!.showStatus(ChatLocalMessageStatus.failed);
          await tester.pump();
          expect(retryButton.hitTestable(), findsOneWidget);
          expect(
            find.bySemanticsLabel(configuration.retryLabel),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: targetStatusSlot,
              matching: find.byIcon(Icons.error_outline_rounded),
            ),
            findsOneWidget,
          );
          _expectGeometry(tester, baseline);

          await tester.tap(retryButton);
          await tester.pump();
          expect(harnessKey.currentState!.retryCount, 1);
          expect(retryButton.hitTestable(), findsNothing);
          expect(
            find.descendant(
              of: targetStatusSlot,
              matching: find.byIcon(Icons.schedule_rounded),
            ),
            findsOneWidget,
          );
          _expectGeometry(tester, baseline);

          harnessKey.currentState!.showConfirmed(withTimestamp: true);
          await tester.pump();
          expect(retryButton.hitTestable(), findsNothing);
          expect(
            find.descendant(
              of: targetStatusSlot,
              matching: find.byIcon(Icons.done_rounded),
            ),
            findsOneWidget,
          );
          _expectGeometry(tester, baseline);

          harnessKey.currentState!.showConfirmed(withTimestamp: false);
          await tester.pump();
          expect(retryButton.hitTestable(), findsNothing);
          _expectGeometry(tester, baseline);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
