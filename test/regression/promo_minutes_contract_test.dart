import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _source(String path) => File(path).readAsStringSync();

void main() {
  test('promo codes use gift minutes instead of legacy SmallTalk value', () {
    final redeemSource =
        _source('firebase/custom_cloud_functions/redeem_promo_code.js');
    final promoRecordSource =
        _source('lib/backend/schema/promo_codes_record.dart');

    expect(redeemSource, contains('minutesGifted'));
    expect(redeemSource, contains('validForDays'));
    expect(redeemSource, isNot(contains('value_samll_talk')));
    expect(redeemSource, isNot(contains('amount_ST: 0')));

    expect(promoRecordSource, contains('int get minutesGifted'));
    expect(promoRecordSource, contains('int get validForDays'));
    expect(promoRecordSource, isNot(contains('value_samll_talk')));
    expect(promoRecordSource, isNot(contains('valueSamllTalk')));
  });

  test('gift-minute transactions display minutes instead of ST', () {
    final registrationGiftSource =
        _source('firebase/custom_cloud_functions/claim_registration_gift.js');
    final transactionWidgetSource =
        _source('lib/components/trans/trans_widget.dart');

    expect(registrationGiftSource, contains('minutesPurchased'));
    expect(registrationGiftSource, isNot(contains('amount_ST: 0')));

    expect(transactionWidgetSource, contains('isGiftMinutesTransaction'));
    expect(transactionWidgetSource, contains('TypeTransactions.promocode'));
    expect(
      transactionWidgetSource,
      contains('TypeTransactions.bonus && giftMinutes > 0'),
    );
    expect(transactionWidgetSource, contains("ruText: 'мин'"));
  });
}
