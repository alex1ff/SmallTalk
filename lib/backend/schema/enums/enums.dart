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

enum StatusTransactions {
  completed,
  pending,
  failed,
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

T? deserializeEnum<T>(String? value) {
  switch (T) {
    case (UserRole):
      return UserRole.values.deserialize(value) as T?;
    case (NotificationType):
      return NotificationType.values.deserialize(value) as T?;
    case (CallStatus):
      return CallStatus.values.deserialize(value) as T?;
    case (Gender):
      return Gender.values.deserialize(value) as T?;
    case (Level):
      return Level.values.deserialize(value) as T?;
    case (StatusTransactions):
      return StatusTransactions.values.deserialize(value) as T?;
    case (TypeTransactions):
      return TypeTransactions.values.deserialize(value) as T?;
    default:
      return null;
  }
}
