import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/schema/enums/enums.dart';
import 'package:small_talk/services/user_match_profile.dart';

void main() {
  test('partner level choices define inclusive minimum thresholds', () {
    expect(partnerLevelsAtOrAbove(Level.Beginner), Level.values);
    expect(partnerLevelsAtOrAbove(Level.Basic), [
      Level.Basic,
      Level.Intermediate,
      Level.Fluent,
    ]);
    expect(partnerLevelsAtOrAbove(Level.Intermediate), [
      Level.Intermediate,
      Level.Fluent,
    ]);
    expect(partnerLevelsAtOrAbove(Level.Fluent), [Level.Fluent]);
  });
}
