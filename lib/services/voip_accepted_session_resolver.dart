typedef VoipAcceptedSessionLoader = Future<VoipAcceptedSession?> Function();

class VoipAcceptedSession {
  const VoipAcceptedSession({
    required this.isTutor,
    this.roomUrl,
    this.meetingToken,
    this.roomName,
  });

  final bool isTutor;
  final String? roomUrl;
  final String? meetingToken;
  final String? roomName;

  @override
  String toString() => 'VoipAcceptedSession(isTutor: $isTutor)';
}

class VoipAcceptedSessionAttempt {
  const VoipAcceptedSessionAttempt._({
    required this.sessionId,
    required this.userId,
    required this.generation,
    required this.resetGeneration,
  });

  final String sessionId;
  final String userId;
  final int generation;
  final int resetGeneration;
}

enum VoipAcceptedSessionResolutionState { resolved, unresolved, stale }

class VoipAcceptedSessionResolution {
  const VoipAcceptedSessionResolution._(
    this.state, {
    this.session,
    this.recovered = false,
  });

  const VoipAcceptedSessionResolution.resolved(
    VoipAcceptedSession session, {
    bool recovered = false,
  }) : this._(
          VoipAcceptedSessionResolutionState.resolved,
          session: session,
          recovered: recovered,
        );

  const VoipAcceptedSessionResolution.unresolved()
      : this._(VoipAcceptedSessionResolutionState.unresolved);

  const VoipAcceptedSessionResolution.stale()
      : this._(VoipAcceptedSessionResolutionState.stale);

  final VoipAcceptedSessionResolutionState state;
  final VoipAcceptedSession? session;
  final bool recovered;

  @override
  String toString() =>
      'VoipAcceptedSessionResolution(state: $state, recovered: $recovered)';
}

/// Resolves legacy accepted sessions while invalidating every late completion
/// after session clear, retry replacement, logout or Firebase user switch.
class VoipAcceptedSessionResolver {
  VoipAcceptedSessionResolver({required String? Function() currentUserId})
      : _currentUserId = currentUserId;

  final String? Function() _currentUserId;
  final Map<String, int> _sessionGenerations = <String, int>{};
  int _resetGeneration = 0;

  VoipAcceptedSessionAttempt begin({
    required String sessionId,
    required String userId,
  }) {
    final normalizedSession = sessionId.trim();
    final normalizedUser = userId.trim();
    final generation = (_sessionGenerations[normalizedSession] ?? 0) + 1;
    _sessionGenerations[normalizedSession] = generation;
    return VoipAcceptedSessionAttempt._(
      sessionId: normalizedSession,
      userId: normalizedUser,
      generation: generation,
      resetGeneration: _resetGeneration,
    );
  }

  bool isCurrent(VoipAcceptedSessionAttempt attempt) =>
      attempt.sessionId.isNotEmpty &&
      attempt.userId.isNotEmpty &&
      attempt.resetGeneration == _resetGeneration &&
      _sessionGenerations[attempt.sessionId] == attempt.generation &&
      _currentUserId()?.trim() == attempt.userId;

  Future<VoipAcceptedSessionResolution> resolve({
    required VoipAcceptedSessionAttempt attempt,
    VoipAcceptedSession? alreadyAccepted,
    required VoipAcceptedSessionLoader accept,
    required VoipAcceptedSessionLoader recover,
  }) async {
    if (!isCurrent(attempt)) {
      return const VoipAcceptedSessionResolution.stale();
    }
    if (alreadyAccepted != null) {
      return VoipAcceptedSessionResolution.resolved(alreadyAccepted);
    }

    try {
      final accepted = await accept();
      if (!isCurrent(attempt)) {
        return const VoipAcceptedSessionResolution.stale();
      }
      if (accepted != null) {
        return VoipAcceptedSessionResolution.resolved(accepted);
      }
    } catch (_) {
      if (!isCurrent(attempt)) {
        return const VoipAcceptedSessionResolution.stale();
      }
      try {
        final recovered = await recover();
        if (!isCurrent(attempt)) {
          return const VoipAcceptedSessionResolution.stale();
        }
        if (recovered != null) {
          return VoipAcceptedSessionResolution.resolved(
            recovered,
            recovered: true,
          );
        }
      } catch (_) {
        if (!isCurrent(attempt)) {
          return const VoipAcceptedSessionResolution.stale();
        }
      }
    }
    return const VoipAcceptedSessionResolution.unresolved();
  }

  void invalidateSession(String sessionId) {
    final normalized = sessionId.trim();
    _sessionGenerations[normalized] =
        (_sessionGenerations[normalized] ?? 0) + 1;
  }

  void reset() {
    _resetGeneration++;
    _sessionGenerations.clear();
  }
}
