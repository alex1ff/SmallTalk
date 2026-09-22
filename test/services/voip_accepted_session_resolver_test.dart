import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/voip_accepted_session_resolver.dart';

void main() {
  test('already accepted candidate skips callable and resolves immediately',
      () async {
    var calls = 0;
    final resolver = VoipAcceptedSessionResolver(currentUserId: () => 'user-a');
    final attempt = resolver.begin(sessionId: 'session', userId: 'user-a');
    final result = await resolver.resolve(
      attempt: attempt,
      alreadyAccepted: const VoipAcceptedSession(
        isTutor: false,
        roomUrl: 'https://daily.test/room',
        roomName: 'room',
      ),
      accept: () async {
        calls++;
        return null;
      },
      recover: () async => null,
    );
    expect(result.state, VoipAcceptedSessionResolutionState.resolved);
    expect(result.session?.isTutor, isFalse);
    expect(calls, 0);
  });

  test('accept result wins and recovery is not called', () async {
    var recoveryCalls = 0;
    final resolver = VoipAcceptedSessionResolver(currentUserId: () => 'u');
    final result = await resolver.resolve(
      attempt: resolver.begin(sessionId: 's', userId: 'u'),
      accept: () async => const VoipAcceptedSession(
        isTutor: true,
        roomUrl: 'https://daily.test/accepted',
        meetingToken: 'secret-token',
      ),
      recover: () async {
        recoveryCalls++;
        return null;
      },
    );
    expect(result.state, VoipAcceptedSessionResolutionState.resolved);
    expect(result.session?.isTutor, isTrue);
    expect(recoveryCalls, 0);
    expect(result.toString(), isNot(contains('secret-token')));
  });

  test('accept error recovers active session without exposing error', () async {
    final resolver = VoipAcceptedSessionResolver(currentUserId: () => 'u');
    final result = await resolver.resolve(
      attempt: resolver.begin(sessionId: 's', userId: 'u'),
      accept: () async => throw StateError('private-token'),
      recover: () async => const VoipAcceptedSession(
        isTutor: true,
        roomUrl: 'https://daily.test/recovered',
      ),
    );
    expect(result.state, VoipAcceptedSessionResolutionState.resolved);
    expect(result.recovered, isTrue);
    expect(result.toString(), isNot(contains('private')));
  });

  test('clear makes late accept completion stale and skips recovery', () async {
    final pending = Completer<VoipAcceptedSession?>();
    var recoveryCalls = 0;
    final resolver = VoipAcceptedSessionResolver(currentUserId: () => 'u');
    final attempt = resolver.begin(sessionId: 's', userId: 'u');
    final resolution = resolver.resolve(
      attempt: attempt,
      accept: () => pending.future,
      recover: () async {
        recoveryCalls++;
        return null;
      },
    );
    resolver.invalidateSession('s');
    pending.complete(const VoipAcceptedSession(isTutor: true));
    final result = await resolution;
    expect(result.state, VoipAcceptedSessionResolutionState.stale);
    expect(recoveryCalls, 0);
  });

  test('logout and user switch make recovery completion stale', () async {
    var user = 'u';
    final recovery = Completer<VoipAcceptedSession?>();
    final resolver = VoipAcceptedSessionResolver(currentUserId: () => user);
    final attempt = resolver.begin(sessionId: 's', userId: 'u');
    final resolution = resolver.resolve(
      attempt: attempt,
      accept: () async => throw StateError('offline'),
      recover: () => recovery.future,
    );
    await Future<void>.value();
    user = 'other';
    recovery.complete(const VoipAcceptedSession(isTutor: true));
    expect(
      (await resolution).state,
      VoipAcceptedSessionResolutionState.stale,
    );
  });

  test('new attempt for same session invalidates old completion only',
      () async {
    final old = Completer<VoipAcceptedSession?>();
    final resolver = VoipAcceptedSessionResolver(currentUserId: () => 'u');
    final first = resolver.begin(sessionId: 's', userId: 'u');
    final firstResult = resolver.resolve(
      attempt: first,
      accept: () => old.future,
      recover: () async => null,
    );
    final second = resolver.begin(sessionId: 's', userId: 'u');
    final secondResult = await resolver.resolve(
      attempt: second,
      accept: () async => const VoipAcceptedSession(isTutor: true),
      recover: () async => null,
    );
    old.complete(const VoipAcceptedSession(isTutor: true));
    expect(secondResult.state, VoipAcceptedSessionResolutionState.resolved);
    expect((await firstResult).state, VoipAcceptedSessionResolutionState.stale);
  });

  test('unresolved result is distinct from stale and reset invalidates all',
      () async {
    final resolver = VoipAcceptedSessionResolver(currentUserId: () => 'u');
    final attempt = resolver.begin(sessionId: 's', userId: 'u');
    final unresolved = await resolver.resolve(
      attempt: attempt,
      accept: () async => null,
      recover: () async => null,
    );
    expect(unresolved.state, VoipAcceptedSessionResolutionState.unresolved);
    expect(resolver.isCurrent(attempt), isTrue);
    resolver.reset();
    expect(resolver.isCurrent(attempt), isFalse);
  });
}
