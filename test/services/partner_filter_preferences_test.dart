import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/schema/enums/enums.dart';
import 'package:small_talk/services/partner_filter_preferences.dart';

void main() {
  group('partner filter defaults', () {
    test('falls back to current user level when preference is unset', () {
      expect(
        resolveEffectivePreferredPartnerLevel(
          preferredPartnerLevel: null,
          currentUserLevel: Level.Intermediate,
        ),
        Level.Intermediate,
      );
      expect(
        resolveEffectivePreferredPartnerLevelName(
          preferredPartnerLevel: null,
          currentUserLevel: Level.Intermediate,
        ),
        'Intermediate',
      );
    });

    test('keeps explicit preferred partner level when present', () {
      expect(
        resolveEffectivePreferredPartnerLevel(
          preferredPartnerLevel: Level.Basic,
          currentUserLevel: Level.Fluent,
        ),
        Level.Basic,
      );
      expect(
        resolveEffectivePreferredPartnerLevelName(
          preferredPartnerLevel: Level.Basic,
          currentUserLevel: Level.Fluent,
        ),
        'Basic',
      );
    });

    test('stays null when both levels are unavailable', () {
      expect(
        resolveEffectivePreferredPartnerLevel(
          preferredPartnerLevel: null,
          currentUserLevel: null,
        ),
        isNull,
      );
      expect(
        resolveEffectivePreferredPartnerLevelName(
          preferredPartnerLevel: null,
          currentUserLevel: null,
        ),
        isNull,
      );
    });
  });
}
