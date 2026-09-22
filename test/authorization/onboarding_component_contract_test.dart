import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('onboarding page composes extracted flat components', () {
    final pageSource =
        File('lib/authorization/onboarding/onboarding_widget.dart')
            .readAsStringSync();
    final cardFile = File('lib/components/onboarding_card.dart');

    expect(pageSource, contains("import '/components/onboarding_card.dart';"));
    expect(pageSource, isNot(contains('class _OnboardingCard')));
    expect(cardFile.existsSync(), isTrue);
  });
}
