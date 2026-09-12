import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('VoIPService delegates accept lifecycle state and preserves ordering',
      () {
    final source = File('lib/services/voip_service.dart').readAsStringSync();
    final acceptStart = source.indexOf('Future<void> _handleCallAccept(');
    final acceptEnd = source.indexOf(
      'Future<void> _resolveAcceptedSession(',
      acceptStart,
    );
    final acceptSource = source.substring(acceptStart, acceptEnd);

    expect(source, contains("import '/services/voip_accept_lifecycle.dart';"));
    expect(source, contains('VoipAcceptLifecycle _acceptLifecycle'));
    expect(source, isNot(contains('final Set<String> _acceptInProgress')));
    expect(source, isNot(contains('final Set<String> _acceptedSessions')));
    expect(
        source, isNot(contains('final Set<String> _handledCallKitAcceptIds')));
    expect(source,
        isNot(contains('final Map<String, DateTime> _recentAcceptBySession')));
    expect(
      source,
      isNot(contains('static final Map<String, DateTime> '
          '_processAcceptClaimedAtBySession')),
    );

    final duplicateGate = acceptSource.indexOf('_acceptLifecycle.evaluate(');
    final payloadExpiry =
        acceptSource.indexOf('voipIncomingCallPayloadHasExpired(');
    final processClaim = acceptSource.indexOf('_acceptLifecycle.begin(');
    final permission = acceptSource.indexOf('_ensureAcceptMediaPermissions()');
    final generationGuard = acceptSource.indexOf(
      '_acceptLifecycle.isCurrent(acceptAttempt)',
      permission,
    );
    final releaseForRetry = acceptSource.indexOf(
      '_acceptLifecycle.releaseForRetry(acceptAttempt)',
      generationGuard,
    );
    expect(duplicateGate, greaterThanOrEqualTo(0));
    expect(payloadExpiry, greaterThan(duplicateGate));
    expect(processClaim, greaterThan(payloadExpiry));
    expect(permission, greaterThan(processClaim));
    expect(generationGuard, greaterThan(permission));
    expect(releaseForRetry, greaterThan(generationGuard));

    expect(
      acceptSource,
      contains('_acceptLifecycle.isCurrent(acceptAttempt)'),
    );
    expect(source, contains('_acceptLifecycle.invalidate(sessionId)'));
    expect(source, contains('_acceptLifecycle.reset()'));
    expect(source, contains('_acceptLifecycle.prune('));
    expect(
      acceptSource,
      contains('_sessionStateGenerations[sessionId]'),
    );
    expect(
      source,
      contains('expectedSessionGeneration: permissionDeniedGeneration'),
    );
  });
}
