import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/students_pages/words/words_model.dart';

void main() {
  group('WordsModel', () {
    test('does not cache StreamBuilder initialData snapshots', () {
      final initialSnapshot = AsyncSnapshot<List<String>>.withData(
        ConnectionState.waiting,
        const <String>['cached'],
      );

      expect(
        WordsModel.shouldCacheStreamSnapshot(initialSnapshot),
        isFalse,
      );
    });

    test('caches real stream data snapshots', () {
      final activeSnapshot = AsyncSnapshot<List<String>>.withData(
        ConnectionState.active,
        const <String>['fresh'],
      );

      expect(
        WordsModel.shouldCacheStreamSnapshot(activeSnapshot),
        isTrue,
      );
    });
  });
}
