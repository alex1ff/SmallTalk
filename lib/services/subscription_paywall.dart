// SubscriptionPaywall — thin wrapper around RevenueCat's pre-built paywall
// UI (`purchases_ui_flutter`). Replaces the bespoke `pay_widget.dart`
// screen — the paywall layout and copy are now configured in the RC
// dashboard and rendered by RC's native paywall components on each
// platform.
//
// Usage:
//   await SubscriptionPaywall.present(context);
//   if (SubscriptionService.instance.hasActiveEntitlement) { ... }
//
// The paywall closes itself on successful purchase, cancellation, or
// when the user dismisses it. The future resolves with the dismissal
// reason so callers can react (e.g. show a thank-you snackbar).

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import 'subscription_service.dart';

enum PaywallOutcome {
  /// User completed a purchase.
  purchased,

  /// User restored a previous purchase.
  restored,

  /// User dismissed the paywall without purchasing.
  cancelled,

  /// Purchase flow failed (e.g. payment declined, network error).
  failed,

  /// User isn't yet eligible (e.g. anonymous, offline). Used as a
  /// defensive fall-through.
  notPresented,
}

class SubscriptionPaywall {
  const SubscriptionPaywall._();

  /// Present the paywall configured in RevenueCat for the subscription offering
  /// entitlement. Returns the outcome so callers can react.
  static Future<PaywallOutcome> present({
    String? offeringIdentifier = kSubscriptionOfferingId,
  }) async {
    // Make sure RC is configured. configure() is a no-op when already done.
    await SubscriptionService.instance.configure();

    try {
      Offering? offering;
      if (offeringIdentifier != null && offeringIdentifier.isNotEmpty) {
        final offerings = await Purchases.getOfferings();
        offering = offerings.all[offeringIdentifier];
      }

      final result = offering != null
          ? await RevenueCatUI.presentPaywall(offering: offering)
          : await RevenueCatUI.presentPaywall();

      // Refresh local CustomerInfo so the rest of the app sees the new
      // entitlement state immediately (the webhook will mirror to
      // Firestore within seconds).
      await SubscriptionService.instance.refresh();

      switch (result) {
        case PaywallResult.purchased:
          return PaywallOutcome.purchased;
        case PaywallResult.restored:
          return PaywallOutcome.restored;
        case PaywallResult.cancelled:
          return PaywallOutcome.cancelled;
        case PaywallResult.error:
          return PaywallOutcome.failed;
        case PaywallResult.notPresented:
          return PaywallOutcome.notPresented;
      }
    } catch (e, st) {
      debugPrint('❌ SubscriptionPaywall.present failed: $e\n$st');
      return PaywallOutcome.failed;
    }
  }

  /// Show the paywall only if the user does NOT have the entitlement.
  /// Useful for guarding feature taps (e.g., "start call" button).
  static Future<PaywallOutcome> presentIfNeeded() async {
    await SubscriptionService.instance.configure();
    try {
      final result = await RevenueCatUI.presentPaywallIfNeeded(
        kSubscriptionProEntitlementId,
      );
      await SubscriptionService.instance.refresh();
      switch (result) {
        case PaywallResult.purchased:
          return PaywallOutcome.purchased;
        case PaywallResult.restored:
          return PaywallOutcome.restored;
        case PaywallResult.cancelled:
          return PaywallOutcome.cancelled;
        case PaywallResult.error:
          return PaywallOutcome.failed;
        case PaywallResult.notPresented:
          return PaywallOutcome.notPresented;
      }
    } catch (e, st) {
      debugPrint('❌ SubscriptionPaywall.presentIfNeeded failed: $e\n$st');
      return PaywallOutcome.failed;
    }
  }

  /// Present RevenueCat Customer Center for subscription/payment management.
  static Future<bool> presentCustomerCenter() async {
    await SubscriptionService.instance.configure();
    try {
      await RevenueCatUI.presentCustomerCenter();
      await SubscriptionService.instance.refresh();
      return true;
    } catch (e, st) {
      debugPrint('❌ SubscriptionPaywall.presentCustomerCenter failed: $e\n$st');
      return false;
    }
  }
}
