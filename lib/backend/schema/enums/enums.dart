import 'package:collection/collection.dart';

enum UserRole {
  student,
  native_speaker,
}

enum NotificationType {
  incoming_call,
  session_started,
  session_ended,
  queue_matched,
  system_message,
}

enum CallStatus {
  searching,
  connecting,
  active,
  ended,
  cancelled,
  no_tutors_available,
}

enum Gender {
  male,
  female,
  no,
}

enum Level {
  Beginner,
  Basic,
  Intermediate,
  Fluent,
}

enum TeacherAccreditationStatus {
  pending,
  approved,
  rejected,
}

enum StatusTransactions {
  completed,
  pending,
  failed,
  cancelled,
  declined,
}

enum TypeTransactions {
  purchase,
  call_charge,
  bonus,
  earning,
  withdrawal,
  promocode,
}

extension FFEnumExtensions<T extends Enum> on T {
  String serialize() => name;
}

extension FFEnumListExtensions<T extends Enum> on Iterable<T> {
  T? deserialize(String? value) =>
      firstWhereOrNull((e) => e.serialize() == value);
}

String? _enumValueAsString(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  if (value is Enum) {
    return value.name;
  }
  if (value is Map) {
    final name = value['name'] ?? value['value'] ?? value['role'];
    if (name is String) {
      return name;
    }
  }
  return value.toString();
}

String? _normalizeUserRoleValue(dynamic value) {
  final rawValue = _enumValueAsString(value);
  if (rawValue == null) {
    return null;
  }

  final normalized = rawValue
      .trim()
      .split('.')
      .last
      .toLowerCase()
      .replaceAll(RegExp(r'[\s-]+'), '_');

  switch (normalized) {
    case 'student':
      return UserRole.student.name;
    case 'native_speaker':
    case 'nativespeaker':
    case 'teacher':
    case 'tutor':
      return UserRole.native_speaker.name;
    default:
      return normalized;
  }
}

String? _normalizeTeacherAccreditationStatusValue(dynamic value) {
  final rawValue = _enumValueAsString(value);
  if (rawValue == null) {
    return null;
  }

  final normalized = rawValue
      .trim()
      .split('.')
      .last
      .toLowerCase()
      .replaceAll(RegExp(r'[\s-]+'), '_');

  switch (normalized) {
    case 'approved':
    case 'approve':
    case 'accepted':
    case 'verified':
    case 'true':
      return TeacherAccreditationStatus.approved.name;
    case 'rejected':
    case 'reject':
    case 'declined':
    case 'denied':
      return TeacherAccreditationStatus.rejected.name;
    case 'pending':
    case 'review':
    case 'in_review':
    case 'under_review':
    case 'false':
      return TeacherAccreditationStatus.pending.name;
    default:
      return normalized;
  }
}

T? deserializeEnum<T>(dynamic value) {
  switch (T) {
    case (UserRole):
      return UserRole.values.deserialize(_normalizeUserRoleValue(value)) as T?;
    case (NotificationType):
      return NotificationType.values.deserialize(_enumValueAsString(value))
          as T?;
    case (CallStatus):
      return CallStatus.values.deserialize(_enumValueAsString(value)) as T?;
    case (Gender):
      return Gender.values.deserialize(_enumValueAsString(value)) as T?;
    case (Level):
      return Level.values.deserialize(_enumValueAsString(value)) as T?;
    case (TeacherAccreditationStatus):
      return TeacherAccreditationStatus.values.deserialize(
        _normalizeTeacherAccreditationStatusValue(value),
      ) as T?;
    case (StatusTransactions):
      return StatusTransactions.values.deserialize(_enumValueAsString(value))
          as T?;
    case (TypeTransactions):
      return TypeTransactions.values.deserialize(_enumValueAsString(value))
          as T?;
    default:
      return null;
  }
}
