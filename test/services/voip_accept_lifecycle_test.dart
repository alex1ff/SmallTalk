import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/voip_accept_lifecycle.dart';

void main() {
  final startedAt = DateTime.utc(2026, 9, 1, 10);

  VoipAcceptIdentity identity(
    String sessionId, [
    String callKitId = 'call-a',
  ]) {
    return VoipAcceptIdentity(
      sessionId: sessionId,
      callKitId: callKitId,
    );
  }

  group('VoipAcceptLifecycle gate ordering', () {
    test('identity keeps the session and effective CallKit id together', () {
      expect(identity('session-a'), identity('session-a'));
      expect(identity('session-a'), isNot(identity('session-a', 'call-b')));
      expect(identity('session-a'), isNot(identity('session-b')));
    });

    test('local duplicate is rejected before a process claim is created', () {
      final processGate = VoipProcessAcceptGate();
      final lifecycle = VoipAcceptLifecycle(processGate: processGate);
      final first = lifecycle.begin(identity('session-a'), now: startedAt);
      expect(first.decision, VoipAcceptDecision.started);
      expect(first.token, isNotNull);

      expect(
        lifecycle.evaluate(identity('session-a'), now: startedAt),
        VoipAcceptDecision.duplicateTimeWindow,
      );
      expect(processGate.hasClaim('session-a', now: startedAt), isTrue);
    });

    test('begin re-evaluates local state after taking a process claim', () {
      final processGate = VoipProcessAcceptGate();
      final lifecycle = VoipAcceptLifecycle(processGate: processGate);
      final first = lifecycle.begin(identity('session-a'), now: startedAt);
      final firstToken = first.token!;
      expect(lifecycle.releaseProcessClaim(firstToken), isTrue);

      final duplicate = lifecycle.begin(
        identity('session-a'),
        now: startedAt,
      );

      expect(duplicate.decision, VoipAcceptDecision.duplicateTimeWindow);
      expect(duplicate.token, isNull);
      expect(processGate.hasClaim('session-a', now: startedAt), isFalse);
      expect(lifecycle.isCurrent(firstToken), isTrue);
    });

    test('gate reasons preserve time, handled, accepted, progress order', () {
      final timeLifecycle = VoipAcceptLifecycle();
      final timeStart = timeLifecycle.begin(
        identity('time-session'),
        now: startedAt,
      );
      expect(timeStart.started, isTrue);
      expect(
        timeLifecycle.evaluate(
          identity('time-session', 'other-call'),
          now: startedAt.add(const Duration(seconds: 1)),
        ),
        VoipAcceptDecision.duplicateTimeWindow,
      );

      final handledLifecycle = VoipAcceptLifecycle();
      final handledStart = handledLifecycle.begin(
        identity('handled-owner'),
        now: startedAt,
      );
      expect(handledLifecycle.finish(handledStart.token!), isTrue);
      expect(
        handledLifecycle.evaluate(
          identity('other-session'),
          now: startedAt.add(const Duration(seconds: 30)),
        ),
        VoipAcceptDecision.duplicateCallKitId,
      );

      final acceptedLifecycle = VoipAcceptLifecycle();
      final acceptedStart = acceptedLifecycle.begin(
        identity('accepted-session'),
        now: startedAt,
      );
      expect(acceptedLifecycle.markAccepted(acceptedStart.token!), isTrue);
      expect(acceptedLifecycle.finish(acceptedStart.token!), isTrue);
      expect(
        acceptedLifecycle.evaluate(
          identity('accepted-session', 'other-call'),
          now: startedAt.add(const Duration(seconds: 30)),
        ),
        VoipAcceptDecision.alreadyAccepted,
      );

      final progressLifecycle = VoipAcceptLifecycle();
      final progressStart = progressLifecycle.begin(
        identity('progress-session'),
        now: startedAt,
      );
      expect(progressStart.started, isTrue);
      expect(
        progressLifecycle.evaluate(
          identity('progress-session', 'other-call'),
          now: startedAt.add(const Duration(seconds: 30)),
        ),
        VoipAcceptDecision.acceptInProgress,
      );
    });

    test('recent accept uses the exact 30 second boundary', () {
      final lifecycle = VoipAcceptLifecycle();
      final started = lifecycle.begin(identity('session-a'), now: startedAt);
      lifecycle.finish(started.token!);

      expect(
        lifecycle.evaluate(
          identity('session-a', 'call-b'),
          now: startedAt
              .add(voipRecentAcceptWindow)
              .subtract(const Duration(microseconds: 1)),
        ),
        VoipAcceptDecision.duplicateTimeWindow,
      );
      expect(
        lifecycle.evaluate(
          identity('session-a', 'call-b'),
          now: startedAt.add(voipRecentAcceptWindow),
        ),
        VoipAcceptDecision.proceed,
      );
    });
  });

  group('VoipAcceptLifecycle process gate', () {
    test('same controller collapses a concurrent begin', () {
      final lifecycle = VoipAcceptLifecycle();
      final first = lifecycle.begin(identity('session-a'), now: startedAt);
      final second = lifecycle.begin(identity('session-a'), now: startedAt);

      expect(first.started, isTrue);
      expect(second.decision, VoipAcceptDecision.duplicateProcessClaim);
      expect(second.token, isNull);
    });

    test('two controllers collapse through an explicitly shared gate', () {
      final processGate = VoipProcessAcceptGate();
      final firstLifecycle = VoipAcceptLifecycle(processGate: processGate);
      final secondLifecycle = VoipAcceptLifecycle(processGate: processGate);

      expect(
        firstLifecycle.evaluate(identity('session-a'), now: startedAt),
        VoipAcceptDecision.proceed,
      );
      expect(
        secondLifecycle.evaluate(identity('session-a'), now: startedAt),
        VoipAcceptDecision.proceed,
      );

      final first = firstLifecycle.begin(
        identity('session-a'),
        now: startedAt,
      );
      final second = secondLifecycle.begin(
        identity('session-a'),
        now: startedAt,
      );

      expect(first.started, isTrue);
      expect(second.decision, VoipAcceptDecision.duplicateProcessClaim);
    });

    test('process claim expires at the exact two minute boundary', () {
      final processGate = VoipProcessAcceptGate();
      final firstLifecycle = VoipAcceptLifecycle(processGate: processGate);
      final secondLifecycle = VoipAcceptLifecycle(processGate: processGate);
      expect(
        firstLifecycle.begin(identity('session-a'), now: startedAt).started,
        isTrue,
      );

      expect(
        secondLifecycle
            .begin(
              identity('session-a'),
              now: startedAt
                  .add(voipProcessAcceptDedupeWindow)
                  .subtract(const Duration(microseconds: 1)),
            )
            .decision,
        VoipAcceptDecision.duplicateProcessClaim,
      );
      expect(
        secondLifecycle
            .begin(
              identity('session-a'),
              now: startedAt.add(voipProcessAcceptDedupeWindow),
            )
            .started,
        isTrue,
      );
    });

    test('permission denial can release all reservations for a retry', () {
      final processGate = VoipProcessAcceptGate();
      final lifecycle = VoipAcceptLifecycle(processGate: processGate);
      final attempt = lifecycle.begin(identity('session-a'), now: startedAt);

      expect(lifecycle.releaseForRetry(attempt.token!), isTrue);
      expect(processGate.hasClaim('session-a', now: startedAt), isFalse);
      expect(lifecycle.isAcceptInProgress('session-a'), isFalse);
      expect(lifecycle.hasHandledCallKitId('call-a'), isFalse);
      expect(
        lifecycle
            .begin(
              identity('session-a'),
              now: startedAt.add(const Duration(seconds: 1)),
            )
            .started,
        isTrue,
      );
    });
  });

  group('VoipAcceptLifecycle invalidation', () {
    test('payload expiry remains a facade decision', () {
      final lifecycle = VoipAcceptLifecycle();
      bool payloadHasExpired() => true;

      expect(
        lifecycle.evaluate(identity('session-a'), now: startedAt),
        VoipAcceptDecision.proceed,
      );
      if (!payloadHasExpired()) {
        lifecycle.begin(identity('session-a'), now: startedAt);
      }

      expect(lifecycle.hasSessionState('session-a'), isFalse);
      expect(
        lifecycle.processGate.hasClaim('session-a', now: startedAt),
        isFalse,
      );
    });

    test('invalidate during an async attempt makes its token stale', () {
      final lifecycle = VoipAcceptLifecycle();
      final attempt = lifecycle.begin(identity('session-a'), now: startedAt);
      final token = attempt.token!;

      expect(lifecycle.isCurrent(token), isTrue);
      lifecycle.invalidate('session-a');

      expect(lifecycle.isCurrent(token), isFalse);
      expect(lifecycle.markAccepted(token), isFalse);
      expect(lifecycle.finish(token), isFalse);
      expect(lifecycle.isAccepted('session-a'), isFalse);
    });

    test('reset clears local state and this controller process claims', () {
      final processGate = VoipProcessAcceptGate();
      final lifecycle = VoipAcceptLifecycle(processGate: processGate);
      final attempt = lifecycle.begin(identity('session-a'), now: startedAt);
      expect(attempt.started, isTrue);

      lifecycle.reset();

      expect(lifecycle.hasSessionState('session-a'), isFalse);
      expect(processGate.hasClaim('session-a', now: startedAt), isFalse);
    });

    test('completion from before reset cannot accept a new generation', () {
      final lifecycle = VoipAcceptLifecycle();
      final oldAttempt = lifecycle.begin(
        identity('session-a'),
        now: startedAt,
      );
      lifecycle.reset();
      final newAttempt = lifecycle.begin(
        identity('session-a'),
        now: startedAt.add(const Duration(seconds: 1)),
      );

      expect(lifecycle.markAccepted(oldAttempt.token!), isFalse);
      expect(lifecycle.isAccepted('session-a'), isFalse);
      expect(lifecycle.markAccepted(newAttempt.token!), isTrue);
      expect(lifecycle.isAccepted('session-a'), isTrue);
    });

    test('touch advances generation and invalidates an older token', () {
      final lifecycle = VoipAcceptLifecycle();
      final attempt = lifecycle.begin(identity('session-a'), now: startedAt);
      final firstGeneration = attempt.token!.generation;

      final nextGeneration = lifecycle.touch(
        'session-a',
        now: startedAt.add(const Duration(seconds: 1)),
      );

      expect(nextGeneration, greaterThan(firstGeneration));
      expect(lifecycle.isCurrent(attempt.token!), isFalse);
    });
  });

  group('VoipAcceptLifecycle pruning', () {
    test('keeps state before the 10 minute boundary and prunes at it', () {
      final processGate = VoipProcessAcceptGate();
      final lifecycle = VoipAcceptLifecycle(processGate: processGate);
      final attempt = lifecycle.begin(identity('session-a'), now: startedAt);
      lifecycle.markAccepted(attempt.token!);
      lifecycle.finish(attempt.token!);

      expect(
        lifecycle.prune(
          now: startedAt
              .add(voipAcceptSessionStateTtl)
              .subtract(const Duration(microseconds: 1)),
        ),
        isEmpty,
      );
      expect(lifecycle.isAccepted('session-a'), isTrue);

      expect(
        lifecycle.prune(
          now: startedAt.add(voipAcceptSessionStateTtl),
        ),
        {'session-a'},
      );
      expect(lifecycle.hasSessionState('session-a'), isFalse);
      expect(lifecycle.hasHandledCallKitId('call-a'), isFalse);
      expect(
        processGate.hasClaim(
          'session-a',
          now: startedAt.add(voipAcceptSessionStateTtl),
        ),
        isFalse,
      );
    });

    test('retained session is not removed by lifecycle pruning', () {
      final lifecycle = VoipAcceptLifecycle();
      final attempt = lifecycle.begin(identity('session-a'), now: startedAt);
      lifecycle.markAccepted(attempt.token!);
      lifecycle.finish(attempt.token!);

      expect(
        lifecycle.prune(
          now: startedAt.add(voipAcceptSessionStateTtl),
          retainedSessionIds: const {'session-a'},
        ),
        isEmpty,
      );
      expect(lifecycle.isAccepted('session-a'), isTrue);
    });

    test('clearing handled ids keeps accepted session state', () {
      final lifecycle = VoipAcceptLifecycle();
      final attempt = lifecycle.begin(identity('session-a'), now: startedAt);
      lifecycle.markAccepted(attempt.token!);
      lifecycle.finish(attempt.token!);

      lifecycle.clearHandledCallKitIds();

      expect(lifecycle.hasHandledCallKitId('call-a'), isFalse);
      expect(lifecycle.isAccepted('session-a'), isTrue);
      expect(lifecycle.hasAnyState, isTrue);
    });
  });
}
