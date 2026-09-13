import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/custom_code/widgets/deepgram_stream_gate.dart';

void main() {
  test('new start issues monotonic token and clears previous stop state', () {
    final gate = DeepgramStreamGate();
    expect(gate.generation, 0);
    expect(gate.stopRequested, isFalse);
    expect(gate.finalizing, isFalse);
    expect(gate.startInProgress, isFalse);

    final first = gate.beginStart();
    expect(first, 1);
    expect(gate.isCurrent(first), isTrue);
    expect(gate.startInProgress, isTrue);
    expect(gate.stopRequested, isFalse);

    gate.requestStop(finalizing: true);
    expect(gate.stopRequested, isTrue);
    final second = gate.beginStart();
    expect(second, 3);
    expect(gate.isCurrent(first), isFalse);
    expect(gate.isCurrent(second), isTrue);
    expect(gate.stopRequested, isFalse);
    expect(gate.startInProgress, isTrue);
    expect(gate.finalizing, isTrue);
  });

  test('finishStart only clears the current start token', () {
    final gate = DeepgramStreamGate();
    final first = gate.beginStart();
    final second = gate.beginStart();
    gate.finishStart(first);
    expect(gate.startInProgress, isTrue);
    gate.finishStart(second);
    expect(gate.startInProgress, isFalse);
  });

  test('each non-empty stop invalidates even when stop already requested', () {
    final gate = DeepgramStreamGate();
    final start = gate.beginStart();
    gate.requestStop(finalizing: true);
    expect(gate.generation, start + 1);
    gate.requestStop(finalizing: false);
    expect(gate.generation, start + 2);
    expect(gate.stopRequested, isTrue);
    expect(gate.finalizing, isFalse);
  });

  test('no-op stop remains owned by caller and leaves gate untouched', () {
    final gate = DeepgramStreamGate();
    final before = gate.generation;
    expect(gate.generation, before);
    expect(gate.stopRequested, isFalse);
    expect(gate.startInProgress, isFalse);
  });

  test('sink failure stop is idempotent before regular stop', () {
    final gate = DeepgramStreamGate();
    final start = gate.beginStart();
    expect(gate.requestSinkFailureStop(), isTrue);
    expect(gate.generation, start + 1);
    expect(gate.stopRequested, isTrue);
    expect(gate.requestSinkFailureStop(), isFalse);
    expect(gate.generation, start + 1);

    gate.requestStop(finalizing: true);
    expect(gate.generation, start + 2);
  });

  test('current callbacks require token while finalizing messages bypass it',
      () {
    final gate = DeepgramStreamGate();
    final current = gate.beginStart();
    expect(
      gate.canHandleMessage(generation: current, shouldRun: () => true),
      isTrue,
    );
    expect(
      gate.canHandleMessage(generation: current, shouldRun: () => false),
      isFalse,
    );
    expect(
      gate.canHandleMessage(generation: current - 1, shouldRun: () => true),
      isFalse,
    );

    gate.requestStop(finalizing: true);
    var shouldRunCalls = 0;
    expect(
      gate.canHandleMessage(
        generation: current,
        shouldRun: () {
          shouldRunCalls++;
          return false;
        },
      ),
      isTrue,
    );
    expect(
      gate.canHandleMessage(generation: -100, shouldRun: () => false),
      isTrue,
    );
    expect(shouldRunCalls, 0);

    gate.finishFinalization();
    expect(
      gate.canHandleMessage(generation: current, shouldRun: () => true),
      isFalse,
    );
  });

  test('finalization and full stop have separate completion moments', () {
    final gate = DeepgramStreamGate();
    gate.beginStart();
    gate.requestStop(finalizing: true);
    expect(gate.finalizing, isTrue);
    expect(gate.startInProgress, isTrue);

    gate.finishFinalization();
    expect(gate.finalizing, isFalse);
    expect(gate.startInProgress, isTrue);
    expect(gate.stopRequested, isTrue);

    gate.finishStop();
    expect(gate.startInProgress, isFalse);
    expect(gate.stopRequested, isTrue);
  });

  test('stopRequested persists until the next beginStart', () {
    final gate = DeepgramStreamGate();
    gate.beginStart();
    gate.requestStop(finalizing: false);
    gate.finishFinalization();
    gate.finishStop();
    expect(gate.stopRequested, isTrue);
    expect(
      gate.canHandleMessage(
        generation: gate.generation,
        shouldRun: () => true,
      ),
      isFalse,
    );

    gate.beginStart();
    expect(gate.stopRequested, isFalse);
  });

  test('instances do not share lifecycle state', () {
    final first = DeepgramStreamGate();
    final second = DeepgramStreamGate();
    first.beginStart();
    first.requestStop(finalizing: true);
    expect(second.generation, 0);
    expect(second.stopRequested, isFalse);
    expect(second.finalizing, isFalse);
    expect(second.startInProgress, isFalse);
  });
}
