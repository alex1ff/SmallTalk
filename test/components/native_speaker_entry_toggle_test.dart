import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/components/native_speaker_entry_toggle.dart';

void main() {
  testWidgets('native speaker entry toggle renders and changes value',
      (tester) async {
    bool? changedValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NativeSpeakerEntryToggle(
            value: false,
            onChanged: (value) => changedValue = value,
          ),
        ),
      ),
    );

    expect(find.text('Войти как Native Speaker'), findsOneWidget);
    expect(find.byType(AdaptiveSwitch), findsNothing);
    expect(find.byType(Switch), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(changedValue, isTrue);
  });
}
