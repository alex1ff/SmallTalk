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
  return role != null;
}

LoadingRouteDestination? resolveLoadingRouteDestination({
  required UserRole? role,
  required bool? acquaintance,
  required bool? isProfileComplete,
  required bool hasInferredStudentProfileCompletion,
}) {
  switch (role) {
    case UserRole.native_speaker:
      return (acquaintance ?? false)
          ? LoadingRouteDestination.dashboardNativeSpeaker
          : LoadingRouteDestination.acquaintanceNativeSpeaker;
    case UserRole.student:
      if (!(acquaintance ?? false)) {
        return LoadingRouteDestination.acquaintanceStudentStart;
      }
      return (isProfileComplete ?? hasInferredStudentProfileCompletion)
          ? LoadingRouteDestination.studentsDashboard
          : LoadingRouteDestination.acquaintanceStudentResume;
    default:
      return null;
  }
}
