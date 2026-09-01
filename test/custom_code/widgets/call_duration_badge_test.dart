import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/custom_code/widgets/call_duration_badge.dart';

Widget _buildSubject({
  required int displaySeconds,
  bool hasCountdown = false,
  bool isWarning = false,
}) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CallDurationBadge(
          displaySeconds: displaySeconds,
          hasCountdown: hasCountdown,
          isWarning: isWarning,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders elapsed duration without countdown decoration',
      (tester) async {
    await tester.pumpWidget(_buildSubject(displaySeconds: 125));

    expect(find.text('2:05'), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsNothing);
    expect(find.text('до лимита'), findsNothing);

    final decoration = tester
        .widget<Container>(find.byKey(callDurationBadgeKey))
        .decoration! as BoxDecoration;
    expect(decoration.color, Colors.black.withValues(alpha: 0.45));
    expect(decoration.border, isNull);
  });

  testWidgets(
      'renders countdown warning with preserved Russian label and color',
      (tester) async {
    await tester.pumpWidget(
      _buildSubject(
        displaySeconds: 59,
        hasCountdown: true,
        isWarning: true,
      ),
    );

    expect(find.text('0:59'), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    expect(find.text('Осталась 1 минута до лимита'), findsOneWidget);

    final durationText = tester.widget<Text>(find.text('0:59'));
    expect(durationText.style?.color, const Color(0xFFFFB020));

    final decoration = tester
        .widget<Container>(find.byKey(callDurationBadgeKey))
        .decoration! as BoxDecoration;
    expect(decoration.color, Colors.black.withValues(alpha: 0.68));
    expect(
      (decoration.border! as Border).top.color,
      const Color(0xFFFFB020).withValues(alpha: 0.44),
    );
  });

  testWidgets('renders regular countdown label', (tester) async {
    await tester.pumpWidget(
      _buildSubject(
        displaySeconds: 296,
        hasCountdown: true,
      ),
    );

    expect(find.text('4:56'), findsOneWidget);
    expect(find.text('до лимита'), findsOneWidget);
  });
}
