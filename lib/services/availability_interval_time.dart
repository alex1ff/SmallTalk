const int kAvailabilityIntervalMinuteStep = 5;
const int kAvailabilityIntervalDefaultDurationMinutes = 60;
const int kAvailabilityIntervalLastMinuteOfDay =
    (24 * 60) - kAvailabilityIntervalMinuteStep;
const int kAvailabilityIntervalLatestStartMinute =
    kAvailabilityIntervalLastMinuteOfDay - kAvailabilityIntervalMinuteStep;

enum AvailabilityIntervalField {
  start,
  end,
}

class AvailabilityIntervalDraft {
  const AvailabilityIntervalDraft({
    required this.startMinutes,
    required this.endMinutes,
  });

  final int startMinutes;
  final int endMinutes;
}

DateTime availabilityIntervalDay(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

int availabilityIntervalMinutesOfDay(DateTime value) {
  return value.hour * 60 + value.minute;
}

DateTime availabilityIntervalDateTimeFromMinutes({
  required DateTime day,
  required int minutes,
}) {
  return availabilityIntervalDay(day).add(Duration(minutes: minutes));
}

int roundAvailabilityIntervalMinutesUpToStep(int minutes) {
  final remainder = minutes % kAvailabilityIntervalMinuteStep;
  if (remainder == 0) {
    return minutes;
  }
  return minutes + (kAvailabilityIntervalMinuteStep - remainder);
}

int clampAvailabilityIntervalMinutes(
  int value, {
  required int min,
  required int max,
}) {
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}

DateTime buildInitialAvailabilityIntervalStartTime(DateTime now) {
  final roundedMinutes = roundAvailabilityIntervalMinutesUpToStep(
    availabilityIntervalMinutesOfDay(now),
  );
  return availabilityIntervalDateTimeFromMinutes(
    day: now,
    minutes: clampAvailabilityIntervalMinutes(
      roundedMinutes,
      min: 0,
      max: kAvailabilityIntervalLatestStartMinute,
    ),
  );
}

DateTime buildInitialAvailabilityIntervalEndTime(DateTime start) {
  final startMinutes = availabilityIntervalMinutesOfDay(start);
  return availabilityIntervalDateTimeFromMinutes(
    day: start,
    minutes: clampAvailabilityIntervalMinutes(
      startMinutes + kAvailabilityIntervalDefaultDurationMinutes,
      min: startMinutes + kAvailabilityIntervalMinuteStep,
      max: kAvailabilityIntervalLastMinuteOfDay,
    ),
  );
}

DateTime parseAvailabilityIntervalTime(
  String? rawValue, {
  required DateTime fallback,
}) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(rawValue ?? '');
  if (match == null) {
    return fallback;
  }

  final hours = int.tryParse(match.group(1)!);
  final minutes = int.tryParse(match.group(2)!);
  if (hours == null ||
      minutes == null ||
      hours < 0 ||
      hours > 23 ||
      minutes < 0 ||
      minutes > 59) {
    return fallback;
  }

  return availabilityIntervalDateTimeFromMinutes(
    day: fallback,
    minutes: hours * 60 + minutes,
  );
}

String formatAvailabilityIntervalTime(DateTime value) {
  final hours = value.hour.toString().padLeft(2, '0');
  final minutes = value.minute.toString().padLeft(2, '0');
  return '$hours:$minutes';
}

AvailabilityIntervalDraft updateAvailabilityIntervalDraft({
  required AvailabilityIntervalField field,
  required int selectedMinutes,
  required int currentStartMinutes,
  required int currentEndMinutes,
}) {
  final newMinutes = roundAvailabilityIntervalMinutesUpToStep(selectedMinutes);

  if (field == AvailabilityIntervalField.start) {
    final validStartMinutes = clampAvailabilityIntervalMinutes(
      newMinutes,
      min: 0,
      max: kAvailabilityIntervalLatestStartMinute,
    );
    final nextEndMinutes = currentEndMinutes <= validStartMinutes
        ? clampAvailabilityIntervalMinutes(
            validStartMinutes + kAvailabilityIntervalMinuteStep,
            min: validStartMinutes + kAvailabilityIntervalMinuteStep,
            max: kAvailabilityIntervalLastMinuteOfDay,
          )
        : currentEndMinutes;
    return AvailabilityIntervalDraft(
      startMinutes: validStartMinutes,
      endMinutes: nextEndMinutes,
    );
  }

  final minEnd = currentStartMinutes + kAvailabilityIntervalMinuteStep;
  final validEndMinutes = clampAvailabilityIntervalMinutes(
    newMinutes,
    min: minEnd,
    max: kAvailabilityIntervalLastMinuteOfDay,
  );
  return AvailabilityIntervalDraft(
    startMinutes: currentStartMinutes,
    endMinutes: validEndMinutes,
  );
}
