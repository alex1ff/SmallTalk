import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('teacher finance add-card row has no nested icon tap target', () {
    final source = File('lib/teachers_pages/pay_copy/pay_copy_widget.dart')
        .readAsStringSync();

    const addCardLabel = "'ljhzclav' /* Добавить карту */";
    final labelIndex = source.indexOf(addCardLabel);
    expect(labelIndex, isNonNegative);

    final blockStart = source.lastIndexOf('child: InkWell(', labelIndex);
    final blockEnd =
        source.indexOf("'qpndbc1w' /* История операций */", labelIndex);
    expect(blockStart, isNonNegative);
    expect(blockEnd, isNonNegative);

    final addCardBlock = source.substring(blockStart, blockEnd);

    expect(addCardBlock, contains('onTap: () async {'));
    expect(addCardBlock, contains('child: AddCardWidget('));
    expect(addCardBlock, contains('owner: paymentUserReference'));
    expect(addCardBlock, contains('_isPaymentSheetCurrent('));
    expect(addCardBlock, isNot(contains('FlutterFlowIconButton(')));
    expect(addCardBlock, isNot(contains('onPressed:')));
  });

  test('teacher finance guards a missing owner before scoped queries', () {
    final source = File('lib/teachers_pages/pay_copy/pay_copy_widget.dart')
        .readAsStringSync();

    final ownerRead =
        source.indexOf('final paymentUserReference = currentUserReference;');
    final ownerGuard =
        source.indexOf('if (paymentUserReference == null)', ownerRead);
    final documentMatch = source.indexOf(
      'paymentUserDocument.reference.path != paymentOwnerKey',
      ownerGuard,
    );
    final cardsQuery =
        source.indexOf('_paymentCardsStream(paymentUserReference)', ownerGuard);
    final transactionsQuery = source.indexOf(
      '_paymentTransactionsStream(paymentUserReference)',
      ownerGuard,
    );

    expect(ownerRead, isNonNegative);
    expect(ownerGuard, greaterThan(ownerRead));
    expect(documentMatch, greaterThan(ownerGuard));
    expect(cardsQuery, greaterThan(ownerGuard));
    expect(transactionsQuery, greaterThan(ownerGuard));
    expect(cardsQuery, greaterThan(documentMatch));
    expect(transactionsQuery, greaterThan(documentMatch));
  });

  test('payment Firestore query errors reach async row state', () {
    final source = File('lib/teachers_pages/pay_copy/pay_copy_widget.dart')
        .readAsStringSync();
    final helperStart = source.indexOf('Stream<List<T>> _paymentRecordsStream');
    final helperEnd = source.indexOf(
      'Stream<List<CardsRecord>> _paymentCardsStream',
      helperStart,
    );

    expect(helperStart, isNonNegative);
    expect(helperEnd, greaterThan(helperStart));
    final helperBlock = source.substring(helperStart, helperEnd);
    expect(helperBlock, contains('query.snapshots().map'));
    expect(helperBlock, isNot(contains('handleError')));
  });

  test('card snapshots rebuild the parent withdrawal action once', () {
    final source = File('lib/teachers_pages/pay_copy/pay_copy_widget.dart')
        .readAsStringSync();
    final syncStart = source.indexOf('void _syncSelectedCardWithCards(');
    final syncEnd = source.indexOf('void _syncPaymentOwner(', syncStart);

    expect(syncStart, isNonNegative);
    expect(syncEnd, greaterThan(syncStart));
    final syncBlock = source.substring(syncStart, syncEnd);
    expect(syncBlock, contains('listEquals(_latestCards, cards)'));
    expect(syncBlock, contains('_cardsRebuildScheduled = true'));
    expect(syncBlock, contains('WidgetsBinding.instance.addPostFrameCallback'));
    expect(syncBlock, contains('safeSetState(() {})'));
  });
}
