import 'package:flutter_test/flutter_test.dart';

import 'package:small_talk/custom_code/widgets/call_participant_identity.dart'
    as identity;

void main() {
  const absentNames = <String?>[null, '', ' \t\n '];

  group('remote participant name', () {
    test('trims Daily name and preserves internal spaces, case and punctuation',
        () {
      expect(
        identity.resolveRemoteParticipantName(
          username: '  Dr. Анна  Li-7! \n',
          fallback: 'unused',
        ),
        'Dr. Анна  Li-7!',
      );
    });

    test('absent Daily name returns the caller fallback verbatim', () {
      for (final username in absentNames) {
        for (final fallback in ['Собеседник', ' Custom ', '', ' \t']) {
          expect(
            identity.resolveRemoteParticipantName(
              username: username,
              fallback: fallback,
            ),
            fallback,
            reason: 'username=$username, fallback=$fallback',
          );
        }
      }
    });

    test('credential-like sentinels remain valid display names', () {
      for (final name in [' null ', '0', 'undefined', 'false']) {
        expect(
          identity.resolveRemoteParticipantName(
            username: name,
            fallback: 'unused',
          ),
          name.trim(),
        );
      }
    });
  });

  group('remote caption-log speaker ID', () {
    test('trimmed Daily user ID wins over participant session ID', () {
      expect(
        identity.resolveRemoteCaptionLogSpeakerId(
          userId: ' User-A  B:/7 ',
          participantSessionId: ' Session-C ',
          utteranceId: 42,
        ),
        'User-A  B:/7',
      );
    });

    test('absent user ID falls back to trimmed participant session ID', () {
      for (final userId in absentNames) {
        expect(
          identity.resolveRemoteCaptionLogSpeakerId(
            userId: userId,
            participantSessionId: ' Session-A  B:/7 \n',
            utteranceId: 42,
          ),
          'Session-A  B:/7',
        );
      }
    });

    test('absent IDs use the exact utterance fallback', () {
      for (final userId in absentNames) {
        for (final sessionId in ['', ' \t\n ']) {
          for (final utteranceId in [0, 42, -1]) {
            expect(
              identity.resolveRemoteCaptionLogSpeakerId(
                userId: userId,
                participantSessionId: sessionId,
                utteranceId: utteranceId,
              ),
              'remote_$utteranceId',
            );
          }
        }
      }
    });

    test('credential-like values are accepted at either priority', () {
      for (final value in [' null ', '0']) {
        expect(
          identity.resolveRemoteCaptionLogSpeakerId(
            userId: value,
            participantSessionId: 'session',
            utteranceId: 1,
          ),
          value.trim(),
        );
        expect(
          identity.resolveRemoteCaptionLogSpeakerId(
            userId: null,
            participantSessionId: value,
            utteranceId: 1,
          ),
          value.trim(),
        );
      }
    });
  });

  group('local participant name', () {
    test('trimmed Daily username wins over configured username and role', () {
      for (final isStudent in <bool?>[true, false, null]) {
        expect(
          identity.resolveLocalParticipantName(
            dailyUsername: '  Daily  Имя-A! ',
            configuredUsername: ' Configured ',
            isStudent: isStudent,
          ),
          'Daily  Имя-A!',
        );
      }
    });

    test('absent Daily username uses trimmed configured username', () {
      for (final dailyUsername in absentNames) {
        expect(
          identity.resolveLocalParticipantName(
            dailyUsername: dailyUsername,
            configuredUsername: ' Configured  Имя-A! ',
            isStudent: true,
          ),
          'Configured  Имя-A!',
        );
      }
    });

    test('absent names use student only for true and teacher otherwise', () {
      for (final dailyUsername in absentNames) {
        for (final configuredUsername in absentNames) {
          for (final isStudent in <bool?>[true, false, null]) {
            expect(
              identity.resolveLocalParticipantName(
                dailyUsername: dailyUsername,
                configuredUsername: configuredUsername,
                isStudent: isStudent,
              ),
              isStudent == true ? 'Студент' : 'Преподаватель',
            );
          }
        }
      }
    });

    test('credential-like values are valid at either name priority', () {
      for (final name in [' null ', '0']) {
        expect(
          identity.resolveLocalParticipantName(
            dailyUsername: name,
            configuredUsername: 'unused',
          ),
          name.trim(),
        );
        expect(
          identity.resolveLocalParticipantName(
            dailyUsername: ' ',
            configuredUsername: name,
          ),
          name.trim(),
        );
      }
    });
  });

  group('local participant ID', () {
    test('only null and empty ID use local fallback', () {
      expect(identity.resolveLocalParticipantId(null), 'local');
      expect(identity.resolveLocalParticipantId(''), 'local');
    });

    test('nonempty ID is returned raw, including whitespace-only values', () {
      for (final value in [' \t\n ', ' Session-A ', 'A  B:/7', ' null ', '0']) {
        expect(identity.resolveLocalParticipantId(value), value);
      }
    });
  });
}
