import '/backend/schema/enums/enums.dart';

enum LoadingRouteDestination {
  dashboardNativeSpeaker,
  acquaintanceNativeSpeaker,
  studentsDashboard,
  acquaintanceStudentStart,
  acquaintanceStudentResume,
}

bool hasResolvedLoadingRouteState({
  required UserRole? role,
  required bool? acquaintance,
  required bool? isProfileComplete,
}) {
  switch (role) {
    case UserRole.native_speaker:
      return acquaintance != null;
    case UserRole.student:
      if (acquaintance == null) {
        return false;
      }
      if (!acquaintance) {
        return true;
      }
      return isProfileComplete != null;
    default:
      return false;
  }
}

LoadingRouteDestination? resolveLoadingRouteDestination({
  required UserRole? role,
  required bool acquaintance,
  required bool isProfileComplete,
}) {
  switch (role) {
    case UserRole.native_speaker:
      return acquaintance
          ? LoadingRouteDestination.dashboardNativeSpeaker
          : LoadingRouteDestination.acquaintanceNativeSpeaker;
    case UserRole.student:
      if (!acquaintance) {
        return LoadingRouteDestination.acquaintanceStudentStart;
      }
      return isProfileComplete
          ? LoadingRouteDestination.studentsDashboard
          : LoadingRouteDestination.acquaintanceStudentResume;
    default:
      return null;
  }
}
