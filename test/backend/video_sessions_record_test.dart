import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/schema/video_sessions_record.dart';

void main() {
  test('createVideoSessionsRecordData includes participantIds when provided', () {
    final data = createVideoSessionsRecordData(
      studentId: 'student-1',
      tutorId: 'tutor-1',
      participantIds: const ['student-1', 'tutor-1'],
      status: 'active',
    );

    expect(data['participantIds'], const ['student-1', 'tutor-1']);
  });

  test('createVideoSessionsRecordData omits participantIds when absent', () {
    final data = createVideoSessionsRecordData(
      studentId: 'student-1',
      status: 'searching',
    );

    expect(data.containsKey('participantIds'), isFalse);
  });
}
