const Duration voipRecentAcceptWindow = Duration(seconds: 30);
const Duration voipProcessAcceptDedupeWindow = Duration(minutes: 2);
const Duration voipAcceptSessionStateTtl = Duration(minutes: 10);

enum VoipAcceptDecision {
  proceed,
  started,
  duplicateTimeWindow,
  duplicateCallKitId,
  alreadyAccepted,
  acceptInProgress,
  duplicateProcessClaim,
}

class VoipAcceptIdentity {
  const VoipAcceptIdentity({
    required this.sessionId,
    required this.callKitId,
  })  : assert(sessionId != ''),
        assert(callKitId != '');

  final String sessionId;
  final String callKitId;

  @override
  bool operator ==(Object other) {
    return other is VoipAcceptIdentity &&
        other.sessionId == sessionId &&
        other.callKitId == callKitId;
  }

  @override
  int get hashCode => Object.hash(sessionId, callKitId);
}

class VoipAcceptAttemptToken {
  const VoipAcceptAttemptToken._({
    required this.identity,
    required this.generation,
    required int resetGeneration,
    required Object owner,
    required _VoipProcessAcceptClaim processClaim,
  })  : _resetGeneration = resetGeneration,
        _owner = owner,
        _processClaim = processClaim;

  final VoipAcceptIdentity identity;
  final int generation;
  final int _resetGeneration;
  final Object _owner;
  final _VoipProcessAcceptClaim _processClaim;
}

class VoipAcceptStartResult {
  const VoipAcceptStartResult._({
    required this.decision,
    this.token,
  });

  const VoipAcceptStartResult.started(VoipAcceptAttemptToken token)
      : this._(
          decision: VoipAcceptDecision.started,
          token: token,
        );

  const VoipAcceptStartResult.blocked(this.decision)
      : assert(decision != VoipAcceptDecision.proceed),
        assert(decision != VoipAcceptDecision.started),
        token = null;

  final VoipAcceptDecision decision;
  final VoipAcceptAttemptToken? token;

  bool get started => decision == VoipAcceptDecision.started;
}

class _VoipProcessAcceptClaim {
  const _VoipProcessAcceptClaim({
    required this.sessionId,
    required this.claimedAt,
    required this.owner,
  });

  final String sessionId;
  final DateTime claimedAt;
  final Object owner;
}

/// Explicitly shared gate for process-wide accept deduplication.
class VoipProcessAcceptGate {
  VoipProcessAcceptGate({
    this.dedupeWindow = voipProcessAcceptDedupeWindow,
  }) : assert(!dedupeWindow.isNegative);

  final Duration dedupeWindow;
  final Map<String, _VoipProcessAcceptClaim> _claims =
      <String, _VoipProcessAcceptClaim>{};

  _VoipProcessAcceptClaim? _tryClaim({
    required String sessionId,
    required DateTime now,
    required Object owner,
  }) {
    prune(now: now);
    if (_claims.containsKey(sessionId)) return null;

    final claim = _VoipProcessAcceptClaim(
      sessionId: sessionId,
      claimedAt: now,
      owner: owner,
    );
    _claims[sessionId] = claim;
    return claim;
  }

  bool _release(_VoipProcessAcceptClaim claim) {
    if (!identical(_claims[claim.sessionId], claim)) return false;
    _claims.remove(claim.sessionId);
    return true;
  }

  void _releaseSessionOwnedBy(String sessionId, Object owner) {
    final claim = _claims[sessionId];
    if (claim != null && identical(claim.owner, owner)) {
      _claims.remove(sessionId);
    }
  }

  void _releaseOwnedBy(Object owner) {
    _claims.removeWhere((_, claim) => identical(claim.owner, owner));
  }

  bool hasClaim(String sessionId, {required DateTime now}) {
    prune(now: now);
    return _claims.containsKey(sessionId);
  }

  int prune({required DateTime now}) {
    final previousCount = _claims.length;
    _claims.removeWhere(
      (_, claim) => now.difference(claim.claimedAt) >= dedupeWindow,
    );
    return previousCount - _claims.length;
  }
}

/// Owns local accept reservations and coordinates them with a process gate.
///
/// Payload identity and expiry validation remain facade responsibilities. The
/// facade first calls [evaluate], handles expiry, then calls [begin], which
/// claims the process gate and repeats the local gate before reserving state.
class VoipAcceptLifecycle {
  VoipAcceptLifecycle({
    VoipProcessAcceptGate? processGate,
    this.recentAcceptWindow = voipRecentAcceptWindow,
    this.sessionStateTtl = voipAcceptSessionStateTtl,
  })  : assert(!recentAcceptWindow.isNegative),
        assert(!sessionStateTtl.isNegative),
        processGate = processGate ?? VoipProcessAcceptGate();

  final VoipProcessAcceptGate processGate;
  final Duration recentAcceptWindow;
  final Duration sessionStateTtl;

  final Object _processClaimOwner = Object();
  final Map<String, DateTime> _recentAcceptBySession = <String, DateTime>{};
  final Set<String> _acceptInProgress = <String>{};
  final Set<String> _acceptedSessions = <String>{};
  final Set<String> _handledCallKitIds = <String>{};
  final Map<String, Set<String>> _handledCallKitIdsBySession =
      <String, Set<String>>{};
  final Map<String, Set<String>> _handledCallKitIdOwners =
      <String, Set<String>>{};
  final Map<String, DateTime> _sessionStateTouchedAt = <String, DateTime>{};
  final Map<String, int> _sessionGenerations = <String, int>{};
  final Map<String, VoipAcceptAttemptToken> _activeAttempts =
      <String, VoipAcceptAttemptToken>{};

  int _nextGeneration = 0;
  int _resetGeneration = 0;

  VoipAcceptDecision evaluate(
    VoipAcceptIdentity identity, {
    required DateTime now,
  }) {
    final lastAcceptAt = _recentAcceptBySession[identity.sessionId];
    if (lastAcceptAt != null &&
        now.difference(lastAcceptAt) < recentAcceptWindow) {
      return VoipAcceptDecision.duplicateTimeWindow;
    }
    if (_handledCallKitIds.contains(identity.callKitId)) {
      return VoipAcceptDecision.duplicateCallKitId;
    }
    if (_acceptedSessions.contains(identity.sessionId)) {
      return VoipAcceptDecision.alreadyAccepted;
    }
    if (_acceptInProgress.contains(identity.sessionId)) {
      return VoipAcceptDecision.acceptInProgress;
    }
    return VoipAcceptDecision.proceed;
  }

  VoipAcceptStartResult begin(
    VoipAcceptIdentity identity, {
    required DateTime now,
  }) {
    final processClaim = processGate._tryClaim(
      sessionId: identity.sessionId,
      now: now,
      owner: _processClaimOwner,
    );
    if (processClaim == null) {
      return const VoipAcceptStartResult.blocked(
        VoipAcceptDecision.duplicateProcessClaim,
      );
    }

    final decision = evaluate(identity, now: now);
    if (decision != VoipAcceptDecision.proceed) {
      processGate._release(processClaim);
      return VoipAcceptStartResult.blocked(decision);
    }

    final generation = touch(identity.sessionId, now: now);
    _recentAcceptBySession[identity.sessionId] = now;
    _markCallKitIdHandled(identity);
    _acceptInProgress.add(identity.sessionId);

    final token = VoipAcceptAttemptToken._(
      identity: identity,
      generation: generation,
      resetGeneration: _resetGeneration,
      owner: this,
      processClaim: processClaim,
    );
    _activeAttempts[identity.sessionId] = token;
    return VoipAcceptStartResult.started(token);
  }

  int touch(String sessionId, {required DateTime now}) {
    assert(sessionId != '');
    final generation = ++_nextGeneration;
    _sessionStateTouchedAt[sessionId] = now;
    _sessionGenerations[sessionId] = generation;
    return generation;
  }

  bool isCurrent(VoipAcceptAttemptToken token) {
    return identical(token._owner, this) &&
        token._resetGeneration == _resetGeneration &&
        _sessionGenerations[token.identity.sessionId] == token.generation &&
        identical(_activeAttempts[token.identity.sessionId], token) &&
        _acceptInProgress.contains(token.identity.sessionId);
  }

  bool markAccepted(VoipAcceptAttemptToken token) {
    if (!isCurrent(token)) return false;
    _acceptedSessions.add(token.identity.sessionId);
    return true;
  }

  bool finish(VoipAcceptAttemptToken token) {
    if (!isCurrent(token)) return false;
    final sessionId = token.identity.sessionId;
    _activeAttempts.remove(sessionId);
    _acceptInProgress.remove(sessionId);
    return true;
  }

  bool releaseProcessClaim(VoipAcceptAttemptToken token) {
    if (!identical(token._owner, this)) return false;
    return processGate._release(token._processClaim);
  }

  bool releaseForRetry(VoipAcceptAttemptToken token) {
    if (!isCurrent(token)) return false;
    processGate._release(token._processClaim);
    _clearSessionState(token.identity.sessionId, releaseProcessClaim: false);
    return true;
  }

  void invalidate(String sessionId) {
    _clearSessionState(sessionId);
  }

  void reset() {
    _resetGeneration++;
    processGate._releaseOwnedBy(_processClaimOwner);
    _recentAcceptBySession.clear();
    _acceptInProgress.clear();
    _acceptedSessions.clear();
    _handledCallKitIds.clear();
    _handledCallKitIdsBySession.clear();
    _handledCallKitIdOwners.clear();
    _sessionStateTouchedAt.clear();
    _sessionGenerations.clear();
    _activeAttempts.clear();
  }

  Set<String> prune({
    required DateTime now,
    Set<String> retainedSessionIds = const <String>{},
  }) {
    processGate.prune(now: now);
    final knownSessionIds = <String>{
      ..._sessionStateTouchedAt.keys,
      ..._recentAcceptBySession.keys,
      ..._acceptedSessions,
      ..._acceptInProgress,
      ..._handledCallKitIdsBySession.keys,
    };
    final staleSessionIds = <String>{};
    for (final sessionId in knownSessionIds) {
      if (retainedSessionIds.contains(sessionId)) continue;
      final touchedAt = _sessionStateTouchedAt[sessionId];
      final recentAcceptAt = _recentAcceptBySession[sessionId];
      final touchedIsStale =
          touchedAt != null && now.difference(touchedAt) >= sessionStateTtl;
      final recentAcceptIsStale = recentAcceptAt != null &&
          now.difference(recentAcceptAt) >= sessionStateTtl;
      final requiresFreshTouch = _acceptedSessions.contains(sessionId) ||
          _acceptInProgress.contains(sessionId) ||
          _handledCallKitIdsBySession.containsKey(sessionId);
      if (touchedIsStale ||
          recentAcceptIsStale ||
          (requiresFreshTouch && touchedAt == null)) {
        staleSessionIds.add(sessionId);
      }
    }

    for (final sessionId in staleSessionIds) {
      _clearSessionState(sessionId);
    }
    return Set<String>.unmodifiable(staleSessionIds);
  }

  bool isAcceptInProgress(String sessionId) {
    return _acceptInProgress.contains(sessionId);
  }

  bool isAccepted(String sessionId) {
    return _acceptedSessions.contains(sessionId);
  }

  bool hasHandledCallKitId(String callKitId) {
    return _handledCallKitIds.contains(callKitId);
  }

  bool hasSessionState(String sessionId) {
    return _sessionStateTouchedAt.containsKey(sessionId) ||
        _recentAcceptBySession.containsKey(sessionId) ||
        _acceptedSessions.contains(sessionId) ||
        _acceptInProgress.contains(sessionId) ||
        _handledCallKitIdsBySession.containsKey(sessionId);
  }

  bool get hasAnyState =>
      _sessionStateTouchedAt.isNotEmpty ||
      _recentAcceptBySession.isNotEmpty ||
      _acceptedSessions.isNotEmpty ||
      _acceptInProgress.isNotEmpty ||
      _handledCallKitIdsBySession.isNotEmpty;

  void clearHandledCallKitIds() {
    _handledCallKitIds.clear();
    _handledCallKitIdsBySession.clear();
    _handledCallKitIdOwners.clear();
  }

  void _markCallKitIdHandled(VoipAcceptIdentity identity) {
    _handledCallKitIds.add(identity.callKitId);
    _handledCallKitIdsBySession
        .putIfAbsent(identity.sessionId, () => <String>{})
        .add(identity.callKitId);
    _handledCallKitIdOwners
        .putIfAbsent(identity.callKitId, () => <String>{})
        .add(identity.sessionId);
  }

  void _clearSessionState(
    String sessionId, {
    bool releaseProcessClaim = true,
  }) {
    _sessionStateTouchedAt.remove(sessionId);
    _sessionGenerations.remove(sessionId);
    _recentAcceptBySession.remove(sessionId);
    _acceptInProgress.remove(sessionId);
    _acceptedSessions.remove(sessionId);
    _activeAttempts.remove(sessionId);
    if (releaseProcessClaim) {
      processGate._releaseSessionOwnedBy(sessionId, _processClaimOwner);
    }

    final handledIds = _handledCallKitIdsBySession.remove(sessionId);
    if (handledIds == null) return;
    for (final callKitId in handledIds) {
      final owners = _handledCallKitIdOwners[callKitId];
      owners?.remove(sessionId);
      if (owners == null || owners.isEmpty) {
        _handledCallKitIdOwners.remove(callKitId);
        _handledCallKitIds.remove(callKitId);
      }
    }
  }
}
