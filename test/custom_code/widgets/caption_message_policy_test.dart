import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/custom_code/widgets/caption_message_policy.dart';

RemoteCaptionSnapshot _caption({
  int id = 10,
  int revision = 3,
  String text = 'Hello',
  bool isFinal = true,
  bool fading = false,
}) =>
    (
      utteranceId: id,
      revision: revision,
      text: text,
      isFinal: isFinal,
      isFadingOut: fading,
    );

RemoteCaptionUpdate _update({
  required int id,
  int revision = 1,
  String text = 'New phrase',
  bool isFinal = true,
  bool log = false,
}) =>
    (
      utteranceId: id,
      revision: revision,
      text: text,
      isFinal: isFinal,
      shouldLogLegacyFinal: log,
    );

void main() {
  const noChange = (legacyCounterUpdate: null, update: null);

  group('caption text and phase compatibility', () {
    for (final modern in [false, true]) {
      for (var index = 0; index < 3; index++) {
        final text = <Object?>[null, '', ' \t\n '][index];
        test('empty text has no effects (modern $modern, case $index)', () {
          final result = resolveRemoteCaptionMessage({
            'text': text,
            if (modern) 'utteranceId': 20,
            if (modern) 'revision': 1,
          }, current: _caption(), legacyCounter: 3);
          expect(result, noChange);
        });
      }
    }

    test('normalization preserves words/case and collapses whitespace', () {
      expect(normalizeCaptionText(' \tHello\n  мир!  '), 'Hello мир!');
      expect(
          resolveRemoteCaptionMessage({
            'text': ' \tHello\n  мир!  ',
            'utteranceId': 1,
            'revision': 1,
          }),
          (legacyCounterUpdate: 1, update: _update(id: 1, text: 'Hello мир!')));
    });

    test('payload text retains toString compatibility', () {
      expect(resolveRemoteCaptionMessage({'text': 42}), (
        legacyCounterUpdate: 1,
        update: _update(id: 1, text: '42', log: true)
      ));
    });

    final phases = <Object?>[null, 'final', ' FINAL ', '', 'unknown', true, 7];
    for (var index = 0; index < phases.length; index++) {
      test('non-interim phase defaults to final [$index]', () {
        expect(
            resolveRemoteCaptionMessage(
                {'text': 'New phrase', 'phase': phases[index]}),
            (legacyCounterUpdate: 1, update: _update(id: 1, log: true)));
      });
    }

    for (final phase in ['interim', ' INTERIM ', 'InTeRiM']) {
      test('recognizes interim phase "$phase" without legacy final log', () {
        expect(
            resolveRemoteCaptionMessage({'text': 'New phrase', 'phase': phase}),
            (legacyCounterUpdate: 1, update: _update(id: 1, isFinal: false)));
      });
    }
  });

  group('numeric and legacy metadata compatibility', () {
    final cases = <({Object? id, Object? revision, bool legacy, bool log})>[
      (id: 12, revision: 2, legacy: false, log: false),
      (id: ' 12 ', revision: ' 2 ', legacy: false, log: false),
      (id: null, revision: null, legacy: true, log: true),
      (id: 12, revision: null, legacy: true, log: false),
      (id: null, revision: 2, legacy: true, log: false),
      (id: 12.0, revision: 2, legacy: true, log: false),
      (id: 12, revision: 2.0, legacy: true, log: false),
      (id: 12.0, revision: 2.0, legacy: true, log: true),
      (id: 'bad', revision: 'bad', legacy: true, log: true),
      (id: true, revision: false, legacy: true, log: true),
    ];
    for (var index = 0; index < cases.length; index++) {
      final value = cases[index];
      test('metadata combination [$index]', () {
        final result = resolveRemoteCaptionMessage({
          'text': 'New phrase',
          'utteranceId': value.id,
          'revision': value.revision,
          'phase': 'final',
        }, current: _caption(), legacyCounter: 3);
        final id = value.legacy ? 11 : 12;
        expect(result, (
          legacyCounterUpdate: id,
          update: _update(
            id: id,
            revision: value.legacy ? 1 : 2,
            log: value.log,
          )
        ));
      });
    }

    test('zero metadata remains numeric; no new positivity rule', () {
      expect(
          resolveRemoteCaptionMessage({
            'text': 'New phrase',
            'utteranceId': '0',
            'revision': 0,
          }),
          (legacyCounterUpdate: null, update: _update(id: 0, revision: 0)));
    });

    test('legacy allocation advances beyond the higher counter or current ID',
        () {
      expect(
          resolveRemoteCaptionMessage({'text': 'New phrase'},
              current: _caption(), legacyCounter: 30),
          (legacyCounterUpdate: 31, update: _update(id: 31, log: true)));
      expect(
          resolveRemoteCaptionMessage({'text': 'New phrase'},
              current: _caption(), legacyCounter: 3),
          (legacyCounterUpdate: 11, update: _update(id: 11, log: true)));
      expect(
          resolveRemoteCaptionMessage({'text': 'New phrase'},
              legacyCounter: 30),
          (legacyCounterUpdate: 31, update: _update(id: 31, log: true)));
    });
  });

  group('ordering and counter patches', () {
    test('older utterance is rejected but still advances an older counter', () {
      expect(
          resolveRemoteCaptionMessage({
            'text': 'New phrase',
            'utteranceId': 9,
            'revision': 99,
          }, current: _caption(), legacyCounter: 3),
          (legacyCounterUpdate: 9, update: null));
    });

    for (final revision in [2, 3]) {
      test('same utterance revision $revision is rejected with counter patch',
          () {
        expect(
            resolveRemoteCaptionMessage({
              'text': 'New phrase',
              'utteranceId': 10,
              'revision': revision,
            }, current: _caption(), legacyCounter: 3),
            (legacyCounterUpdate: 10, update: null));
      });
    }

    test('counter never decreases on accepted or rejected numeric message', () {
      expect(
          resolveRemoteCaptionMessage({
            'text': 'New phrase',
            'utteranceId': 9,
            'revision': 1,
          }, current: _caption(), legacyCounter: 20),
          noChange);
      expect(
          resolveRemoteCaptionMessage({
            'text': 'New phrase',
            'utteranceId': 11,
            'revision': 1,
          }, current: _caption(), legacyCounter: 20),
          (legacyCounterUpdate: null, update: _update(id: 11)));
    });

    test('greater revision can promote interim to final', () {
      expect(
          resolveRemoteCaptionMessage({
            'text': 'New phrase',
            'utteranceId': 10,
            'revision': 4,
          }, current: _caption(isFinal: false), legacyCounter: 10),
          (legacyCounterUpdate: null, update: _update(id: 10, revision: 4)));
    });

    test('new utterance may start with a lower revision than prior utterance',
        () {
      expect(
          resolveRemoteCaptionMessage({
            'text': 'New phrase',
            'utteranceId': 11,
            'revision': 1,
            'phase': 'interim',
          }, current: _caption(revision: 50), legacyCounter: 10),
          (legacyCounterUpdate: 11, update: _update(id: 11, isFinal: false)));
    });

    for (final fading in [false, true]) {
      test('final cannot regress to interim of same utterance (fading $fading)',
          () {
        expect(
            resolveRemoteCaptionMessage({
              'text': 'New phrase',
              'utteranceId': 10,
              'revision': 4,
              'phase': 'interim',
            }, current: _caption(fading: fading), legacyCounter: 3),
            (legacyCounterUpdate: 10, update: null));
      });
    }

    test('numeric final duplicate with greater revision is still an update',
        () {
      expect(
          resolveRemoteCaptionMessage({
            'text': 'Hello',
            'utteranceId': 10,
            'revision': 4,
          }, current: _caption(), legacyCounter: 10),
          (
            legacyCounterUpdate: null,
            update: _update(id: 10, revision: 4, text: 'Hello')
          ));
    });
  });

  group('legacy duplicate suppression', () {
    for (final phase in ['final', 'interim']) {
      test('visible final duplicate has no effects even with incoming $phase',
          () {
        expect(
            resolveRemoteCaptionMessage({
              'text': ' \tHello  ',
              'phase': phase,
            }, current: _caption(), legacyCounter: 3),
            noChange);
      });
    }

    test('same text is new legacy utterance when current is fading', () {
      expect(
          resolveRemoteCaptionMessage({'text': 'Hello'},
              current: _caption(fading: true), legacyCounter: 10),
          (
            legacyCounterUpdate: 11,
            update: _update(id: 11, text: 'Hello', log: true)
          ));
    });

    test('same text is not suppressed when current is interim', () {
      expect(
          resolveRemoteCaptionMessage({'text': 'Hello'},
              current: _caption(isFinal: false), legacyCounter: 10),
          (
            legacyCounterUpdate: 11,
            update: _update(id: 11, text: 'Hello', log: true)
          ));
    });

    test('duplicate comparison stays case-sensitive', () {
      expect(
          resolveRemoteCaptionMessage({'text': 'hello'},
              current: _caption(), legacyCounter: 10),
          (
            legacyCounterUpdate: 11,
            update: _update(id: 11, text: 'hello', log: true)
          ));
    });
  });

  test('interleaved peers and caption clearing retain independent counters',
      () {
    final counters = <String, int>{};
    final captions = <String, RemoteCaptionSnapshot>{};
    RemoteCaptionDecision receive(String peer, Map<String, dynamic> payload) {
      final decision = resolveRemoteCaptionMessage(payload,
          current: captions[peer], legacyCounter: counters[peer] ?? 0);
      final counter = decision.legacyCounterUpdate;
      if (counter != null) counters[peer] = counter;
      final update = decision.update;
      if (update != null) {
        captions[peer] = (
          utteranceId: update.utteranceId,
          revision: update.revision,
          text: update.text,
          isFinal: update.isFinal,
          isFadingOut: false
        );
      }
      return decision;
    }

    expect(
        receive('a', {'text': 'First', 'utteranceId': 8, 'revision': 1})
            .update
            ?.utteranceId,
        8);
    expect(receive('b', {'text': 'Other'}).update?.utteranceId, 1);
    expect(
        receive('a', {'text': 'Old', 'utteranceId': 7, 'revision': 9}).update,
        isNull);
    captions.remove('a'); // Fade removes the visible caption, not its counter.
    expect(receive('a', {'text': 'Later'}).update?.utteranceId, 9);
    expect(receive('b', {'text': 'Other later'}).update?.utteranceId, 2);
    expect(counters, {'a': 9, 'b': 2});
  });

  test('policy does not mutate incoming payload', () {
    final payload = Map<String, dynamic>.unmodifiable({
      'text': '  New   phrase ',
      'utteranceId': '12',
      'revision': '2',
      'phase': ' INTERIM ',
    });
    expect(resolveRemoteCaptionMessage(payload), (
      legacyCounterUpdate: 12,
      update: _update(id: 12, revision: 2, isFinal: false),
    ));
    expect(payload['text'], '  New   phrase ');
    expect(payload['utteranceId'], '12');
    expect(payload['phase'], ' INTERIM ');
  });
}
