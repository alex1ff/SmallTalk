import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/components/pair_review_content.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/shared_pages/review_flow/review_submission_helper.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    locale: const Locale('ru'),
    supportedLocales: const [
      Locale('ru'),
      Locale('en'),
    ],
    localizationsDelegates: const [
      FFLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      FallbackMaterialLocalizationDelegate(),
      FallbackCupertinoLocalizationDelegate(),
    ],
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await FFLocalizations.initialize();
  });

  group('pair review path resolution', () {
    test('returns canonical path when canonical review exists', () {
      final resolution = resolvePairReviewPaths(
        fromUserId: 'student_1',
        toUserId: 'tutor_2',
        canonicalExists: true,
      );

      expect(
        resolution.canonicalPath,
        'reviews/student%5F1__tutor%5F2',
      );
      expect(
        resolution.resolvedPath,
        'reviews/student%5F1__tutor%5F2',
      );
      expect(resolution.hasReviewed, isTrue);
    });

    test('falls back to latest legacy review for the target pair', () {
      final resolution = resolvePairReviewPaths(
        fromUserId: 'student',
        toUserId: 'tutor',
        canonicalExists: false,
        legacyCandidates: [
          LegacyReviewCandidate(
            reviewPath: 'reviews/old-review',
            toUserPath: 'users/tutor',
            createdAt: DateTime(2025, 1, 1),
          ),
          LegacyReviewCandidate(
            reviewPath: 'reviews/new-review',
            toUserPath: 'users/tutor',
            createdAt: DateTime(2025, 2, 1),
          ),
          LegacyReviewCandidate(
            reviewPath: 'reviews/other-target',
            toUserPath: 'users/someone-else',
            createdAt: DateTime(2025, 3, 1),
          ),
        ],
      );

      expect(resolution.resolvedPath, 'reviews/new-review');
      expect(resolution.hasReviewed, isTrue);
    });

    test('returns no review when canonical and legacy reviews are absent', () {
      final resolution = resolvePairReviewPaths(
        fromUserId: 'student',
        toUserId: 'tutor',
        canonicalExists: false,
      );

      expect(resolution.canonicalPath, 'reviews/student__tutor');
      expect(resolution.resolvedPath, isNull);
      expect(resolution.hasReviewed, isFalse);
    });

    test('canonical review id escapes underscores without collisions', () {
      expect(
        buildCanonicalPairReviewId(
          fromUserId: 'alice_bob',
          toUserId: 'carol',
        ),
        'alice%5Fbob__carol',
      );
      expect(
        buildCanonicalPairReviewId(
          fromUserId: 'alice',
          toUserId: 'bob__carol',
        ),
        'alice__bob%5F%5Fcarol',
      );
    });
  });

  group('session review participant resolution', () {
    test('prefers participantIds plus generalized requester/responder fields',
        () {
      final resolution = resolveSessionReviewParticipant(
        sessionData: {
          'participantIds': ['user-a'],
          'matchContext': {
            'requesterId': 'user-a',
            'acceptedResponderId': 'user-b',
          },
        },
        currentUserId: 'user-a',
      );

      expect(resolution.isParticipant, isTrue);
      expect(resolution.isRequester, isTrue);
      expect(resolution.isResponder, isFalse);
      expect(resolution.counterpartUserId, 'user-b');
    });

    test('resolves neutral responder fields without legacy tutor mirrors', () {
      final resolution = resolveSessionReviewParticipant(
        sessionData: {
          'requesterId': 'user-a',
          'currentResponderId': 'user-b',
        },
        currentUserId: 'user-a',
      );

      expect(resolution.isParticipant, isTrue);
      expect(resolution.isRequester, isTrue);
      expect(resolution.isResponder, isFalse);
      expect(resolution.counterpartUserId, 'user-b');
    });

    test('neutral requester wins over stale legacy student id', () {
      final requesterResolution = resolveSessionReviewParticipant(
        sessionData: {
          'studentId': 'legacy-student',
          'requesterId': 'neutral-requester',
          'currentResponderId': 'neutral-responder',
        },
        currentUserId: 'neutral-requester',
      );

      expect(requesterResolution.isParticipant, isTrue);
      expect(requesterResolution.isRequester, isTrue);
      expect(requesterResolution.counterpartUserId, 'neutral-responder');

      final legacyStudentResolution = resolveSessionReviewParticipant(
        sessionData: {
          'studentId': 'legacy-student',
          'requesterId': 'neutral-requester',
          'currentResponderId': 'neutral-responder',
        },
        currentUserId: 'legacy-student',
      );

      expect(legacyStudentResolution.isParticipant, isFalse);
      expect(legacyStudentResolution.isRequester, isFalse);
      expect(legacyStudentResolution.counterpartUserId, isNull);
    });

    test('neutral responder wins over stale legacy tutor id', () {
      final responderResolution = resolveSessionReviewParticipant(
        sessionData: {
          'requesterId': 'neutral-requester',
          'tutorId': 'legacy-tutor',
          'responderId': 'neutral-responder',
        },
        currentUserId: 'neutral-responder',
      );

      expect(responderResolution.isParticipant, isTrue);
      expect(responderResolution.isResponder, isTrue);
      expect(responderResolution.counterpartUserId, 'neutral-requester');

      final legacyTutorResolution = resolveSessionReviewParticipant(
        sessionData: {
          'requesterId': 'neutral-requester',
          'tutorId': 'legacy-tutor',
          'responderId': 'neutral-responder',
        },
        currentUserId: 'legacy-tutor',
      );

      expect(legacyTutorResolution.isParticipant, isFalse);
      expect(legacyTutorResolution.isResponder, isFalse);
      expect(legacyTutorResolution.counterpartUserId, isNull);
    });

    test('skips empty legacy responder fields before neutral responder fields',
        () {
      final resolution = resolveSessionReviewParticipant(
        sessionData: {
          'studentId': '',
          'requesterId': 'user-a',
          'tutorId': '   ',
          'currentTutorId': '',
          'responderId': 'user-b',
        },
        currentUserId: 'user-a',
      );

      expect(resolution.isParticipant, isTrue);
      expect(resolution.counterpartUserId, 'user-b');
    });

    test('falls back to unique counterpart from participantIds', () {
      final resolution = resolveSessionReviewParticipant(
        sessionData: {
          'participantIds': ['user-a', 'user-b'],
        },
        currentUserId: 'user-b',
      );

      expect(resolution.isParticipant, isTrue);
      expect(resolution.counterpartUserId, 'user-a');
      expect(resolution.isRequester, isFalse);
      expect(resolution.isResponder, isFalse);
    });

    test('fails closed when current user is not a session participant', () {
      final resolution = resolveSessionReviewParticipant(
        sessionData: {
          'participantIds': ['user-a', 'user-b'],
          'studentId': 'user-a',
          'currentTutorId': 'user-b',
        },
        currentUserId: 'user-c',
      );

      expect(resolution.isParticipant, isFalse);
      expect(resolution.counterpartUserId, isNull);
    });

    test(
        'review sync update marks requester side independently from profile role',
        () {
      expect(
        buildSessionReviewUpdate(
          isTeacher: true,
          reviewedAsRequester: true,
        ),
        {'studentHasReviewed': true},
      );
      expect(
        buildSessionReviewUpdate(
          isTeacher: false,
          reviewedAsRequester: false,
        ),
        {'tutorHasReviewed': true},
      );
    });

    test('Call Details wires counterpart resolution through the shared helper',
        () {
      final source = File(
        'lib/shared_pages/call_details/call_details_widget.dart',
      ).readAsStringSync();
      final participantDisplaySource = File(
        'lib/shared_pages/call_history/call_participant_display_utils.dart',
      ).readAsStringSync();

      expect(source, contains('resolveSessionReviewParticipant('));
      expect(source,
          contains('_participantResolution(session).counterpartUserId'));
      expect(source, contains('resolveSessionParticipantDisplayInfo('));
      expect(participantDisplaySource, contains('participantInfos'));
      expect(participantDisplaySource, contains('requesterInfo'));
      expect(participantDisplaySource, contains('acceptedResponderInfo'));
    });

    test('Call Details resolves call direction from requester identity', () {
      final source = File(
        'lib/shared_pages/call_details/call_details_widget.dart',
      ).readAsStringSync();

      expect(source, contains('_currentUserWasCaller('));
      expect(
          source, contains('resolveSessionRequesterId(session.snapshotData)'));
      expect(source,
          contains('final isOutgoing = _currentUserWasCaller(session)'));
    });

    test('Video Call summary routing uses the shared counterpart resolution',
        () {
      final source = File(
        'lib/shared_pages/video_call_page/video_call_page_widget.dart',
      ).readAsStringSync();

      expect(source, contains('resolveSessionReviewParticipant('));
      expect(source, contains("participantResolution?.counterpartUserId"));
    });
  });

  testWidgets(
    'CallSummary review state shows stored review and note when pair review exists',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const PairReviewContent(
            hasReviewed: true,
            reviewNoteText: 'Отзыв на собеседника уже оставлен',
            reviewContent: Text('stored review'),
            formContent: Text('review form'),
          ),
        ),
      );

      expect(find.text('Отзыв на собеседника уже оставлен'), findsOneWidget);
      expect(find.text('stored review'), findsOneWidget);
      expect(find.text('review form'), findsNothing);
    },
  );

  testWidgets(
    'CallDetails review state shows form when pair review does not exist',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          const PairReviewContent(
            hasReviewed: false,
            reviewContent: Text('stored review'),
            formContent: Text('review form'),
          ),
        ),
      );

      expect(find.text('review form'), findsOneWidget);
      expect(find.text('stored review'), findsNothing);
    },
  );
}
