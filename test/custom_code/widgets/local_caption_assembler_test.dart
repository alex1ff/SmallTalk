import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/custom_code/widgets/local_caption_assembler.dart';

class _Clock {
  final base = DateTime.utc(2026, 8, 30);
  int calls = 0;
  DateTime tick() => at(calls++);
  DateTime at(int tick) => base.add(Duration(microseconds: tick));
}

LocalCaptionEmission _accept(
  LocalCaptionAssembler assembler,
  String text, {
  bool segmentFinal = false,
  bool speechFinal = false,
  double? confidence,
}) =>
    assembler.acceptTranscript(
      transcript: text,
      isFinalSegment: segmentFinal,
      speechFinal: speechFinal,
      confidence: confidence,
    );

void main() {
  test('empty assembler has no final emission and does not read clock', () {
    final clock = _Clock();
    final assembler = LocalCaptionAssembler(now: clock.tick);
    expect(assembler.isOpen, isFalse);
    expect(assembler.utteranceId, 0);
    expect(assembler.revision, 0);
    expect(assembler.currentText, '');
    expect(assembler.confidence, isNull);
    expect(assembler.prepareFinalUpdate(), isNull);
    expect(clock.calls, 0);
  });

  test('first transcript reads start then update time; later ones retain start',
      () {
    final clock = _Clock();
    final assembler = LocalCaptionAssembler(now: clock.tick);
    final first = _accept(assembler, 'Hello');
    expect(first, (
      utteranceId: 1,
      revision: 1,
      text: 'Hello',
      isFinal: false,
      startedAt: clock.at(0),
      lastUpdateAt: clock.at(1),
    ));
    final second = _accept(assembler, 'Hello there');
    expect(second.utteranceId, 1);
    expect(second.revision, 2);
    expect(second.startedAt, clock.at(0));
    expect(second.lastUpdateAt, clock.at(2));
    expect(assembler.isOpen, isTrue);
    expect(clock.calls, 3);
  });

  test('uncommitted interim text is replaced instead of accumulated', () {
    final assembler = LocalCaptionAssembler();
    _accept(assembler, 'I think');
    expect(_accept(assembler, 'I thought').text, 'I thought');
    expect(_accept(assembler, '  I\nthink again ').text, 'I think again');
    expect(assembler.currentText, 'I think again');
  });

  test('committed segment survives changing interim tails', () {
    final assembler = LocalCaptionAssembler();
    _accept(assembler, 'I like', segmentFinal: true);
    expect(_accept(assembler, 'red').text, 'I like red');
    expect(_accept(assembler, 'green').text, 'I like green');
    expect(_accept(assembler, 'green tea', segmentFinal: true).text,
        'I like green tea');
    expect(_accept(assembler, 'today').text, 'I like green tea today');
  });

  final mergeCases = <({String committed, String incoming, String expected})>[
    (committed: 'Hello', incoming: 'Hello', expected: 'Hello'),
    (committed: 'Hello', incoming: 'Hello world', expected: 'Hello world'),
    (committed: 'Hello world', incoming: 'world', expected: 'Hello world'),
    (
      committed: 'Hello world',
      incoming: 'world today',
      expected: 'Hello world today'
    ),
    (
      committed: 'one two three',
      incoming: 'two three four',
      expected: 'one two three four'
    ),
    (
      committed: 'one two one two',
      incoming: 'one two three',
      expected: 'one two one two three'
    ),
    (
      committed: 'Hello world',
      incoming: 'WORLD today',
      expected: 'Hello world today'
    ),
    (committed: 'Hello', incoming: 'hello world', expected: 'Hello world'),
    (committed: 'I am', incoming: 'ready now', expected: 'I am ready now'),
    (committed: '  I\n am ', incoming: '\t am  ready ', expected: 'I am ready'),
    (
      committed: 'Привет мир',
      incoming: 'МИР снова',
      expected: 'Привет мир снова'
    ),
    (
      committed: 'Hello,',
      incoming: 'hello world',
      expected: 'Hello, hello world'
    ),
    (committed: 'cat', incoming: 'catalog', expected: 'catalog'),
    (committed: 'call', incoming: 'all', expected: 'call'),
    (
      committed: 'short',
      incoming: 'longer unrelated phrase',
      expected: 'short longer unrelated phrase'
    ),
  ];
  for (var index = 0; index < mergeCases.length; index++) {
    final value = mergeCases[index];
    test('segment merging preserves existing overlap rules [$index]', () {
      final assembler = LocalCaptionAssembler();
      _accept(assembler, value.committed, segmentFinal: true);
      expect(_accept(assembler, value.incoming, segmentFinal: true).text,
          value.expected);
    });
  }

  for (final segmentFinal in [false, true]) {
    for (final speechFinal in [false, true]) {
      test('independent flags: segment=$segmentFinal speech=$speechFinal', () {
        final assembler = LocalCaptionAssembler();
        final first = _accept(assembler, 'first',
            segmentFinal: segmentFinal,
            speechFinal: speechFinal,
            confidence: 0.7);
        expect(first.isFinal, speechFinal);
        expect(
            assembler.isOpen, isTrue); // Caller dispatches/logs before closing.
        expect(assembler.confidence, segmentFinal || speechFinal ? 0.7 : null);
        final second = _accept(assembler, 'next');
        expect(second.utteranceId, first.utteranceId);
        expect(second.revision, 2);
        expect(second.text, segmentFinal ? 'first next' : 'next');
      });
    }
  }

  test('confidence ignores interim, preserves null and accepts zero', () {
    final assembler = LocalCaptionAssembler();
    _accept(assembler, 'one', confidence: 0.9);
    expect(assembler.confidence, isNull);
    _accept(assembler, 'one', segmentFinal: true, confidence: 0.7);
    _accept(assembler, 'two', confidence: 0.1);
    expect(assembler.confidence, 0.7);
    _accept(assembler, 'two', segmentFinal: true);
    expect(assembler.confidence, 0.7);
    _accept(assembler, 'three', speechFinal: true, confidence: 0);
    expect(assembler.confidence, 0);
  });

  test('explicit final preparation advances revision without closing', () {
    final clock = _Clock();
    final assembler = LocalCaptionAssembler(now: clock.tick);
    _accept(assembler, '  short phrase ', segmentFinal: true, confidence: 0.8);
    final prepared = assembler.prepareFinalUpdate()!;
    expect(prepared, (
      utteranceId: 1,
      revision: 2,
      text: 'short phrase',
      isFinal: true,
      startedAt: clock.at(0),
      lastUpdateAt: clock.at(2),
    ));
    expect(assembler.isOpen, isTrue);
    expect(assembler.currentText, 'short phrase');
    expect(assembler.confidence, 0.8);
    final repeated = assembler.prepareFinalUpdate()!;
    expect(repeated.revision, 3);
    expect(repeated.lastUpdateAt, clock.at(3));
    expect(assembler.isOpen, isTrue);
  });

  test('short unfinished interim is preserved for final dispatch before close',
      () {
    final assembler = LocalCaptionAssembler();
    _accept(assembler, 'Bye');
    final finalUpdate = assembler.prepareFinalUpdate()!;
    expect(finalUpdate.text, 'Bye');
    expect(finalUpdate.isFinal, isTrue);
    expect(assembler.isOpen, isTrue);
    assembler.closeUtterance(finalUpdate.text);
    expect(assembler.isOpen, isFalse);
    expect(assembler.currentText, 'Bye');
    expect(assembler.prepareFinalUpdate(), isNull);
  });

  test('close preserves final state until next utterance and consumes no time',
      () {
    final clock = _Clock();
    final assembler = LocalCaptionAssembler(now: clock.tick);
    final first = _accept(assembler, 'first',
        segmentFinal: true, speechFinal: true, confidence: 0.8);
    assembler.closeUtterance('  final\ntext ');
    expect(assembler.isOpen, isFalse);
    expect(assembler.utteranceId, 1);
    expect(assembler.revision, 1);
    expect(assembler.currentText, 'final text');
    expect(assembler.confidence, 0.8);
    expect(assembler.prepareFinalUpdate(), isNull);
    expect(clock.calls, 2);

    final next = _accept(assembler, 'new', confidence: 0.9);
    expect(next.utteranceId, 2);
    expect(next.revision, 1);
    expect(next.text, 'new');
    expect(next.startedAt, clock.at(2));
    expect(next.lastUpdateAt, clock.at(3));
    expect(assembler.confidence, isNull);
    expect(
        first.text, 'first'); // Previously emitted snapshots remain immutable.
  });

  test('empty close is a no-op, not cancellation', () {
    final clock = _Clock();
    final assembler = LocalCaptionAssembler(now: clock.tick);
    _accept(assembler, 'unfinished', segmentFinal: true, confidence: 0.5);
    assembler.closeUtterance(' \n ');
    expect(assembler.isOpen, isTrue);
    expect(assembler.currentText, 'unfinished');
    expect(assembler.confidence, 0.5);
    expect(assembler.revision, 1);
    expect(clock.calls, 2);
    expect(_accept(assembler, 'tail').text, 'unfinished tail');
  });

  test('clear resets utterance state but retains monotonically increasing ID',
      () {
    final clock = _Clock();
    final assembler = LocalCaptionAssembler(now: clock.tick);
    final first =
        _accept(assembler, 'old', segmentFinal: true, confidence: 0.7);
    assembler.clear();
    assembler.clear();
    expect(assembler.utteranceId, first.utteranceId);
    expect(assembler.revision, 0);
    expect(assembler.isOpen, isFalse);
    expect(assembler.currentText, '');
    expect(assembler.confidence, isNull);
    expect(assembler.prepareFinalUpdate(), isNull);
    expect(clock.calls, 2);
    final second = _accept(assembler, 'fresh');
    expect(second.utteranceId, first.utteranceId + 1);
    expect(second.revision, 1);
    expect(second.text, 'fresh');
    expect(second.startedAt, clock.at(2));
  });

  test('instances do not share utterance state', () {
    final first = LocalCaptionAssembler();
    final second = LocalCaptionAssembler();
    _accept(first, 'first', segmentFinal: true);
    _accept(second, 'second', segmentFinal: true, confidence: 0.8);
    first.clear();
    expect(second.isOpen, isTrue);
    expect(second.utteranceId, 1);
    expect(second.currentText, 'second');
    expect(second.confidence, 0.8);
    expect(_accept(first, 'again').utteranceId, 2);
    expect(_accept(second, 'tail').text, 'second tail');
  });
}
