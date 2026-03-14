import '/flutter_flow/uploaded_file.dart';

enum NativeSpeakerOnboardingPage {
  name,
  languageInstruction,
  nativeLanguage,
  gender,
  country,
  aboutMe,
  photo,
}

List<NativeSpeakerOnboardingPage> buildVisibleNativeSpeakerPages({
  required bool showName,
  required bool showPhoto,
}) {
  return NativeSpeakerOnboardingPage.values.where((page) {
    switch (page) {
      case NativeSpeakerOnboardingPage.name:
        return showName;
      case NativeSpeakerOnboardingPage.photo:
        return showPhoto;
      default:
        return true;
    }
  }).toList(growable: false);
}

int resolveNativeSpeakerInitialPage({
  required int requestedRawIndex,
  required List<NativeSpeakerOnboardingPage> visiblePages,
}) {
  if (visiblePages.isEmpty) {
    return 0;
  }

  final targetIndex = requestedRawIndex.clamp(
    0,
    NativeSpeakerOnboardingPage.values.length - 1,
  );

  for (final page in visiblePages) {
    if (page.index >= targetIndex) {
      return page.index;
    }
  }

  return visiblePages.last.index;
}

int? nextVisibleNativeSpeakerPage({
  required int currentRawIndex,
  required List<NativeSpeakerOnboardingPage> visiblePages,
}) {
  for (final page in visiblePages) {
    if (page.index > currentRawIndex) {
      return page.index;
    }
  }
  return null;
}

int? previousVisibleNativeSpeakerPage({
  required int currentRawIndex,
  required List<NativeSpeakerOnboardingPage> visiblePages,
}) {
  for (final page in visiblePages.reversed) {
    if (page.index < currentRawIndex) {
      return page.index;
    }
  }
  return null;
}

int nativeSpeakerDisplayedStep({
  required int currentRawIndex,
  required List<NativeSpeakerOnboardingPage> visiblePages,
}) {
  return visiblePages.where((page) => page.index <= currentRawIndex).length;
}

bool isNativeSpeakerLastVisiblePage({
  required int currentRawIndex,
  required List<NativeSpeakerOnboardingPage> visiblePages,
}) {
  return visiblePages.isNotEmpty && visiblePages.last.index == currentRawIndex;
}

bool hasNativeSpeakerCompletionPhoto({
  required FFUploadedFile? localPhoto,
  required String? existingPhotoUrl,
}) {
  return (localPhoto?.bytes?.isNotEmpty ?? false) ||
      (existingPhotoUrl?.trim().isNotEmpty ?? false);
}
