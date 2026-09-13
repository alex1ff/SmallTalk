import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:small_talk/services/subscription_service.dart';

String _source(String path) => File(path).readAsStringSync();

void main() {
  test('all five non-fatal boundaries keep their typed error codes', () {
    final mainSource = _source('lib/main.dart');
    final subscriptionSource =
        _source('lib/services/subscription_service.dart');
    final translationSource =
        _source('lib/shared_pages/translation/in_call_translation_sheet.dart');
    final feedbackSource =
        _source('lib/shared_pages/call_summary/call_feedback_card.dart');

    expect(mainSource, contains('AppErrorCode.voipInitializeFailed'));
    expect(mainSource, contains('AppErrorCode.authRefreshFailed'));
    expect(subscriptionSource, contains('AppErrorCode.purchaseFailed'));
    expect(
        translationSource, contains('AppErrorCode.translationInvalidResponse'));
    expect(translationSource, contains('AppErrorCode.translationUnexpected'));
    expect(feedbackSource, contains('AppErrorCode.aiFeedbackInvalidResponse'));
    expect(feedbackSource, contains('AppErrorCode.aiFeedbackUnexpected'));
  });

  test('purchase reporting excludes the five expected RevenueCat states', () {
    for (final code in <PurchasesErrorCode>[
      PurchasesErrorCode.purchaseCancelledError,
      PurchasesErrorCode.paymentPendingError,
      PurchasesErrorCode.operationAlreadyInProgressError,
      PurchasesErrorCode.purchaseNotAllowedError,
      PurchasesErrorCode.productAlreadyPurchasedError,
    ]) {
      expect(shouldReportPurchaseError(code), isFalse);
    }
    expect(shouldReportPurchaseError(PurchasesErrorCode.networkError), isTrue);
  });

  test('mobile symbol upload phase is checked in and uses the Firebase plist',
      () {
    final project = _source('ios/Runner.xcodeproj/project.pbxproj');

    expect(
        project, contains('[firebase_crashlytics] Crashlytics Upload Symbols'));
    expect(project, contains('FirebaseCrashlytics/upload-symbols'));
    expect(project, contains('Runner/GoogleService-Info.plist'));
    expect(project, contains(' -p ios '));
  });
}
