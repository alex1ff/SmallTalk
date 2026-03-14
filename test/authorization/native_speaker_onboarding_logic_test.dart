import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/authorization/acquaintance_n_s/native_speaker_onboarding_logic.dart';
import 'package:small_talk/flutter_flow/uploaded_file.dart';

void main() {
  group('buildVisibleNativeSpeakerPages', () {
    test('keeps full 7-step flow when nothing is prefilled', () {
      final pages = buildVisibleNativeSpeakerPages(
        showName: true,
        showPhoto: true,
      );

      expect(pages.length, 7);
      expect(pages.first, NativeSpeakerOnboardingPage.name);
      expect(pages.last, NativeSpeakerOnboardingPage.photo);
    });

    test('hides only name when display name is prefilled', () {
      final pages = buildVisibleNativeSpeakerPages(
        showName: false,
        showPhoto: true,
      );

      expect(pages.length, 6);
      expect(pages, isNot(contains(NativeSpeakerOnboardingPage.name)));
      expect(pages.last, NativeSpeakerOnboardingPage.photo);
    });

    test('hides only photo when profile photo is prefilled', () {
      final pages = buildVisibleNativeSpeakerPages(
        showName: true,
        showPhoto: false,
      );

      expect(pages.length, 6);
      expect(pages.first, NativeSpeakerOnboardingPage.name);
      expect(pages, isNot(contains(NativeSpeakerOnboardingPage.photo)));
    });

    test('hides both name and photo when both are prefilled', () {
      final pages = buildVisibleNativeSpeakerPages(
        showName: false,
        showPhoto: false,
      );

      expect(pages.length, 5);
      expect(pages, isNot(contains(NativeSpeakerOnboardingPage.name)));
      expect(pages, isNot(contains(NativeSpeakerOnboardingPage.photo)));
    });
  });

  group('native speaker page helpers', () {
    test('maps hidden first page to the first visible raw page', () {
      final pages = buildVisibleNativeSpeakerPages(
        showName: false,
        showPhoto: true,
      );

      expect(
        resolveNativeSpeakerInitialPage(
          requestedRawIndex: 0,
          visiblePages: pages,
        ),
        NativeSpeakerOnboardingPage.languageInstruction.index,
      );
    });

    test('preserves progress counting against visible pages only', () {
      final pages = buildVisibleNativeSpeakerPages(
        showName: false,
        showPhoto: true,
      );

      expect(
        nativeSpeakerDisplayedStep(
          currentRawIndex:
              NativeSpeakerOnboardingPage.languageInstruction.index,
          visiblePages: pages,
        ),
        1,
      );
      expect(
        nativeSpeakerDisplayedStep(
          currentRawIndex: NativeSpeakerOnboardingPage.aboutMe.index,
          visiblePages: pages,
        ),
        5,
      );
    });

    test('accepts either local upload or existing remote photo', () {
      expect(
        hasNativeSpeakerCompletionPhoto(
          localPhoto: null,
          existingPhotoUrl: null,
        ),
        isFalse,
      );

      expect(
        hasNativeSpeakerCompletionPhoto(
          localPhoto: FFUploadedFile(
            bytes: Uint8List.fromList(<int>[1, 2, 3]),
          ),
          existingPhotoUrl: '',
        ),
        isTrue,
      );

      expect(
        hasNativeSpeakerCompletionPhoto(
          localPhoto: null,
          existingPhotoUrl: 'https://cdn.example.com/photo.jpg',
        ),
        isTrue,
      );
    });
  });
}
