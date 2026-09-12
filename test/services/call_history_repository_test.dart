import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/call_history_repository.dart';

void main() {
  group('call history repository', () {
    test('normalizes bounded history limit', () {
      expect(normalizeCallHistoryLimit(1), 1);
      expect(
          normalizeCallHistoryLimit(callHistoryMaxLimit), callHistoryMaxLimit);
      expect(() => normalizeCallHistoryLimit(0), throwsArgumentError);
      expect(
        () => normalizeCallHistoryLimit(callHistoryMaxLimit + 1),
        throwsArgumentError,
      );
    });

    test('parses only video session document paths', () {
      expect(
        parseCallHistoryPathsResponse({
          'paths': ['videoSessions/session-a', 'videoSessions/session-b'],
        }),
        ['videoSessions/session-a', 'videoSessions/session-b'],
      );
      expect(
        () => parseCallHistoryPathsResponse({
          'paths': ['users/user-a']
        }),
        throwsFormatException,
      );
      expect(
        () => parseCallHistoryPathsResponse({
          'paths': ['videoSessions/a/b']
        }),
        throwsFormatException,
      );
      expect(
        () => parseCallHistoryPathsResponse({'items': []}),
        throwsFormatException,
      );
    });

    test('empty callable result does not read Firestore', () async {
      final sessions = await CallHistoryRepository.loadCallHistorySessions(
        userId: 'current-user',
        invoker: (functionName, payload) async {
          expect(functionName, getCallHistoryFunctionName);
          expect(payload, {'limit': callHistoryDefaultLimit});
          return {'paths': <String>[]};
        },
      );

      expect(sessions, isEmpty);
    });

    test('uses deployed call history function region', () {
      expect(getCallHistoryFunctionRegion, 'europe-west1');
    });
  });
}
