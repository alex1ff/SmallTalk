import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('onboarding step components live in flat components directory', () {
    const componentFiles = [
      'native_speaker_onboarding_about_me_step.dart',
      'native_speaker_onboarding_accreditation_step.dart',
      'native_speaker_onboarding_country_step.dart',
      'native_speaker_onboarding_language_instruction_step.dart',
      'native_speaker_onboarding_name_step.dart',
      'native_speaker_onboarding_native_language_step.dart',
      'native_speaker_onboarding_photo_step.dart',
      'student_onboarding_country_step.dart',
      'student_onboarding_gender_step.dart',
      'student_onboarding_language_step.dart',
      'student_onboarding_level_step.dart',
      'student_onboarding_name_step.dart',
    ];

    for (final fileName in componentFiles) {
      expect(File('lib/components/$fileName').existsSync(), isTrue);
    }

    const legacyDirectories = [
      'lib/authorization/acquaintance_s_t_u_d_e_n_t/widgets',
      'lib/authorization/acquaintance_n_s/widgets',
    ];

    for (final directoryPath in legacyDirectories) {
      final directory = Directory(directoryPath);
      if (!directory.existsSync()) {
        continue;
      }

      final dartFiles = directory
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList();

      expect(dartFiles, isEmpty);
    }
  });
}
