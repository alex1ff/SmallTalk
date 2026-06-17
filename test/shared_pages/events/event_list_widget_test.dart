import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/shared_pages/events/event_list_widget.dart';

Widget _buildTestApp() {
  return const MaterialApp(
    locale: Locale('ru'),
    supportedLocales: [
      Locale('ru'),
      Locale('en'),
    ],
    localizationsDelegates: [
      FFLocalizationsDelegate(),
      FallbackMaterialLocalizationDelegate(),
      FallbackCupertinoLocalizationDelegate(),
    ],
    home: EventListWidget(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows the events screen header title', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    final title = find.text('События');

    expect(title, findsOneWidget);

    final titleText = tester.widget<Text>(title);
    expect(titleText.style?.fontSize, 34);
    expect(titleText.style?.fontWeight, FontWeight.w700);
  });
}
