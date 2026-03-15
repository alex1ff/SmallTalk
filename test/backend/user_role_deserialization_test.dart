import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/schema/enums/enums.dart';

void main() {
  group('deserializeEnum<UserRole>', () {
    test('keeps canonical student role', () {
      expect(
        deserializeEnum<UserRole>('student'),
        UserRole.student,
      );
    });

    test('normalizes legacy teacher role', () {
      expect(
        deserializeEnum<UserRole>('teacher'),
        UserRole.native_speaker,
      );
    });

    test('normalizes spaced native speaker role', () {
      expect(
        deserializeEnum<UserRole>('native speaker'),
        UserRole.native_speaker,
      );
    });

    test('normalizes mixed map payloads from firestore helpers', () {
      expect(
        deserializeEnum<UserRole>({
          'role': 'tutor',
        }),
        UserRole.native_speaker,
      );
    });
  });
}
