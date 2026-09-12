import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/custom_code/widgets/call_limit_decision_tracker.dart';

void main() {
  test('checkpoints are returned once and preserve configured order', () {
    final tracker = CallLimitDecisionTracker();

    expect(
      tracker.takeDueCheckpointMinutes(
        totalSeconds: 11 * 60,
        checkpointMinutes: const [5, 10],
      ),
      [5, 10],
    );
    expect(
      tracker.takeDueCheckpointMinutes(
        totalSeconds: 12 * 60,
        checkpointMinutes: const [5, 10],
      ),
      isEmpty,
    );
  });

  test('five and ten minute checkpoints become due independently', () {
    final tracker = CallLimitDecisionTracker();

    expect(
      tracker.takeDueCheckpointMinutes(
        totalSeconds: 5 * 60,
        checkpointMinutes: const [5, 10],
      ),
      [5],
    );
    expect(
      tracker.takeDueCheckpointMinutes(
        totalSeconds: 5 * 60,
        checkpointMinutes: const [5, 10],
      ),
      isEmpty,
    );
    expect(
      tracker.takeDueCheckpointMinutes(
        totalSeconds: 10 * 60,
        checkpointMinutes: const [5, 10],
      ),
      [10],
    );
  });

  test('checkpoint history clears only when explicitly requested', () {
    final tracker = CallLimitDecisionTracker();
    tracker.takeDueCheckpointMinutes(
      totalSeconds: 10 * 60,
      checkpointMinutes: const [5, 10],
    );

    tracker.resetLimitMarkers();
    expect(
      tracker.takeDueCheckpointMinutes(
        totalSeconds: 10 * 60,
        checkpointMinutes: const [5, 10],
      ),
      isEmpty,
    );

    tracker.clearCheckpointHistory();
    expect(
      tracker.takeDueCheckpointMinutes(
        totalSeconds: 10 * 60,
        checkpointMinutes: const [5, 10],
      ),
      [5, 10],
    );
  });

  test('warning is taken once per exact expiry', () {
    final tracker = CallLimitDecisionTracker();
    final firstExpiry = DateTime.utc(2026, 8, 31, 12);
    final secondExpiry = firstExpiry.add(const Duration(minutes: 5));

    expect(
      tracker.takeSessionLimitWarning(
        expiresAt: firstExpiry,
        now: firstExpiry.subtract(const Duration(seconds: 30)),
        warningLeadSeconds: 60,
      ),
      isTrue,
    );
    expect(
      tracker.takeSessionLimitWarning(
        expiresAt: firstExpiry.toLocal(),
        now: firstExpiry.subtract(const Duration(seconds: 20)),
        warningLeadSeconds: 60,
      ),
      isFalse,
    );
    expect(
      tracker.takeSessionLimitWarning(
        expiresAt: secondExpiry,
        now: secondExpiry.subtract(const Duration(seconds: 30)),
        warningLeadSeconds: 60,
      ),
      isTrue,
    );
  });

  test('auto-end request is taken once per exact expiry', () {
    final tracker = CallLimitDecisionTracker();
    final firstExpiry = DateTime.utc(2026, 8, 31, 12);
    final secondExpiry = firstExpiry.add(const Duration(minutes: 5));

    expect(
      tracker.takeAutoEndRequest(
        expiresAt: firstExpiry,
        now: firstExpiry.add(const Duration(seconds: 2)),
        graceSeconds: 2,
      ),
      isTrue,
    );
    expect(
      tracker.takeAutoEndRequest(
        expiresAt: firstExpiry.toLocal(),
        now: firstExpiry.add(const Duration(seconds: 3)),
        graceSeconds: 2,
      ),
      isFalse,
    );
    expect(
      tracker.takeAutoEndRequest(
        expiresAt: secondExpiry,
        now: secondExpiry.add(const Duration(seconds: 2)),
        graceSeconds: 2,
      ),
      isTrue,
    );
  });

  test('matching clear allows retry while stale clear preserves newer marker',
      () {
    final tracker = CallLimitDecisionTracker();
    final firstExpiry = DateTime.utc(2026, 8, 31, 12);
    final secondExpiry = firstExpiry.add(const Duration(minutes: 5));

    tracker.takeAutoEndRequest(
      expiresAt: firstExpiry,
      now: firstExpiry.add(const Duration(seconds: 2)),
      graceSeconds: 2,
    );
    tracker.takeAutoEndRequest(
      expiresAt: secondExpiry,
      now: secondExpiry.add(const Duration(seconds: 2)),
      graceSeconds: 2,
    );

    tracker.clearAutoEndRequest(firstExpiry);
    expect(
      tracker.takeAutoEndRequest(
        expiresAt: secondExpiry,
        now: secondExpiry.add(const Duration(seconds: 3)),
        graceSeconds: 2,
      ),
      isFalse,
    );

    tracker.clearAutoEndRequest(secondExpiry.toLocal());
    expect(
      tracker.takeAutoEndRequest(
        expiresAt: secondExpiry,
        now: secondExpiry.add(const Duration(seconds: 3)),
        graceSeconds: 2,
      ),
      isTrue,
    );
  });

  test('null clear removes the active auto-end marker', () {
    final tracker = CallLimitDecisionTracker();
    final expiry = DateTime.utc(2026, 8, 31, 12);
    tracker.takeAutoEndRequest(
      expiresAt: expiry,
      now: expiry.add(const Duration(seconds: 2)),
      graceSeconds: 2,
    );

    tracker.clearAutoEndRequest(null);

    expect(
      tracker.takeAutoEndRequest(
        expiresAt: expiry,
        now: expiry.add(const Duration(seconds: 3)),
        graceSeconds: 2,
      ),
      isTrue,
    );
  });

  test('limit reset enables new decisions without clearing checkpoints', () {
    final tracker = CallLimitDecisionTracker();
    final expiry = DateTime.utc(2026, 8, 31, 12);
    tracker.takeDueCheckpointMinutes(
      totalSeconds: 10 * 60,
      checkpointMinutes: const [5, 10],
    );
    tracker.takeSessionLimitWarning(
      expiresAt: expiry,
      now: expiry.subtract(const Duration(seconds: 30)),
      warningLeadSeconds: 60,
    );
    tracker.takeAutoEndRequest(
      expiresAt: expiry,
      now: expiry.add(const Duration(seconds: 2)),
      graceSeconds: 2,
    );

    tracker.resetLimitMarkers();

    expect(
      tracker.takeDueCheckpointMinutes(
        totalSeconds: 10 * 60,
        checkpointMinutes: const [5, 10],
      ),
      isEmpty,
    );
    expect(
      tracker.takeSessionLimitWarning(
        expiresAt: expiry,
        now: expiry.subtract(const Duration(seconds: 20)),
        warningLeadSeconds: 60,
      ),
      isTrue,
    );
    expect(
      tracker.takeAutoEndRequest(
        expiresAt: expiry,
        now: expiry.add(const Duration(seconds: 3)),
        graceSeconds: 2,
      ),
      isTrue,
    );
  });

  test('decisions remain false before their thresholds', () {
    final tracker = CallLimitDecisionTracker();
    final expiry = DateTime.utc(2026, 8, 31, 12);

    expect(
      tracker.takeDueCheckpointMinutes(
        totalSeconds: 299,
        checkpointMinutes: const [5, 10],
      ),
      isEmpty,
    );
    expect(
      tracker.takeSessionLimitWarning(
        expiresAt: expiry,
        now: expiry.subtract(const Duration(seconds: 61)),
        warningLeadSeconds: 60,
      ),
      isFalse,
    );
    expect(
      tracker.takeAutoEndRequest(
        expiresAt: expiry,
        now: expiry.add(const Duration(seconds: 1)),
        graceSeconds: 2,
      ),
      isFalse,
    );
  });

  test('instances do not share checkpoint or limit state', () {
    final first = CallLimitDecisionTracker();
    final second = CallLimitDecisionTracker();
    final expiry = DateTime.utc(2026, 8, 31, 12);

    first.takeDueCheckpointMinutes(
      totalSeconds: 10 * 60,
      checkpointMinutes: const [5, 10],
    );
    first.takeSessionLimitWarning(
      expiresAt: expiry,
      now: expiry.subtract(const Duration(seconds: 30)),
      warningLeadSeconds: 60,
    );

    expect(
      second.takeDueCheckpointMinutes(
        totalSeconds: 10 * 60,
        checkpointMinutes: const [5, 10],
      ),
      [5, 10],
    );
    expect(
      second.takeSessionLimitWarning(
        expiresAt: expiry,
        now: expiry.subtract(const Duration(seconds: 30)),
        warningLeadSeconds: 60,
      ),
      isTrue,
    );
  });
}
