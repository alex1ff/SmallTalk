import '/backend/schema/enums/enums.dart';

Level? resolveEffectivePreferredPartnerLevel({
  required Level? preferredPartnerLevel,
  required Level? currentUserLevel,
}) {
  return preferredPartnerLevel ?? currentUserLevel;
}

String? resolveEffectivePreferredPartnerLevelName({
  required Level? preferredPartnerLevel,
  required Level? currentUserLevel,
}) {
  return resolveEffectivePreferredPartnerLevel(
    preferredPartnerLevel: preferredPartnerLevel,
    currentUserLevel: currentUserLevel,
  )?.name;
}
