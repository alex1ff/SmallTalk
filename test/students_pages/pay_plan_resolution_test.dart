import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:small_talk/services/subscription_service.dart';
import 'package:small_talk/students_pages/pay/pay_widget.dart';

void main() {
  const allProducts = <String>{
    SubscriptionProductIds.monthly,
    SubscriptionProductIds.quarterly,
    SubscriptionProductIds.trialMonthly,
  };

  test('new eligible user sees trial month and immediate 3 month purchase', () {
    final plans = resolveStudentPayPlans(
      paidOnly: false,
      catalogLoaded: true,
      trialOfferEligible: true,
      availableProductIds: allProducts,
    );

    expect(
      plans.map((plan) => plan.productId),
      [
        SubscriptionProductIds.trialMonthly,
        SubscriptionProductIds.quarterly,
      ],
    );
    expect(plans.first.badge, '3 ДНЯ БЕСПЛАТНО');
  });

  test('unknown or ineligible trial falls back to paid monthly product', () {
    final plans = resolveStudentPayPlans(
      paidOnly: false,
      catalogLoaded: true,
      trialOfferEligible: false,
      availableProductIds: allProducts,
    );

    expect(
      plans.map((plan) => plan.productId),
      [
        SubscriptionProductIds.monthly,
        SubscriptionProductIds.quarterly,
      ],
    );
    expect(plans.first.badge, isNull);
  });

  test('paid flow never offers the dedicated trial product', () {
    final plans = resolveStudentPayPlans(
      paidOnly: true,
      catalogLoaded: true,
      trialOfferEligible: true,
      availableProductIds: allProducts,
    );

    expect(
      plans.map((plan) => plan.productId),
      [
        SubscriptionProductIds.monthly,
        SubscriptionProductIds.quarterly,
      ],
    );
  });

  test('partial catalog keeps available product and uses safe monthly copy',
      () {
    final plans = resolveStudentPayPlans(
      paidOnly: false,
      catalogLoaded: true,
      trialOfferEligible: false,
      availableProductIds: const {
        SubscriptionProductIds.trialMonthly,
        SubscriptionProductIds.quarterly,
      },
    );

    expect(plans, hasLength(2));
    expect(plans.first.productId, SubscriptionProductIds.trialMonthly);
    expect(plans.first.badge, isNull);
    expect(plans.last.productId, SubscriptionProductIds.quarterly);
  });

  test('empty loaded catalog has no selectable plans', () {
    expect(
      resolveStudentPayPlans(
        paidOnly: false,
        catalogLoaded: true,
        trialOfferEligible: true,
        availableProductIds: const {},
      ),
      isEmpty,
    );
  });

  test('trial promise requires eligible status and matching store metadata',
      () {
    const trialProduct = StoreProduct(
      SubscriptionProductIds.trialMonthly,
      'Description',
      'Title',
      10,
      r'$10.00',
      'USD',
      introductoryPrice: IntroductoryPrice(
        0,
        r'$0.00',
        'P3D',
        1,
        PeriodUnit.day,
        3,
      ),
    );

    expect(
      hasVerifiedThreeDayTrialOffer(
        eligibility: SubscriptionIntroEligibility.eligible,
        product: trialProduct,
      ),
      isTrue,
    );
    expect(
      hasVerifiedThreeDayTrialOffer(
        eligibility: SubscriptionIntroEligibility.unknown,
        product: trialProduct,
      ),
      isFalse,
    );
    expect(
      hasVerifiedThreeDayTrialOffer(
        eligibility: SubscriptionIntroEligibility.eligible,
        product: null,
      ),
      isFalse,
    );
  });

  test('active trial and premium-only flows prefer the quarterly plan', () {
    final paidPlans = resolveStudentPayPlans(
      paidOnly: true,
      catalogLoaded: true,
      trialOfferEligible: false,
      availableProductIds: allProducts,
    );

    expect(
      resolveDefaultStudentPayProductId(
        plans: paidPlans,
        preferQuarterly: true,
        currentProductId: SubscriptionProductIds.trialMonthly,
      ),
      SubscriptionProductIds.quarterly,
    );
    expect(
      resolveDefaultStudentPayProductId(
        plans: paidPlans,
        preferQuarterly: true,
        currentProductId: SubscriptionProductIds.monthly,
      ),
      SubscriptionProductIds.quarterly,
    );
  });

  test('renewed trial product maps to ordinary monthly paid selection', () {
    final paidPlans = resolveStudentPayPlans(
      paidOnly: true,
      catalogLoaded: true,
      trialOfferEligible: false,
      availableProductIds: allProducts,
    );

    expect(
      resolveDefaultStudentPayProductId(
        plans: paidPlans,
        preferQuarterly: false,
        currentProductId: SubscriptionProductIds.trialMonthly,
      ),
      SubscriptionProductIds.monthly,
    );
  });

  test('RevenueCat package takes priority over direct StoreKit fallback', () {
    const product = StoreProduct(
      SubscriptionProductIds.monthly,
      'Description',
      'Title',
      10,
      r'$10.00',
      'USD',
    );
    const package = Package(
      r'$rc_monthly',
      PackageType.monthly,
      product,
      PresentedOfferingContext('subscriptions', null, null),
    );

    final target = resolveStudentPayPurchaseTarget(
      productId: SubscriptionProductIds.monthly,
      packagesByProductId: const {SubscriptionProductIds.monthly: package},
      storeProductsByProductId: const {
        SubscriptionProductIds.monthly: product,
      },
    );

    expect(target.package, same(package));
    expect(target.storeProduct, isNull);
  });
}
