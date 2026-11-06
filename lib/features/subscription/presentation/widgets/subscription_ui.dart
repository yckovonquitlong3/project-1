import 'package:flutter/material.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/billing_cycle.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription_failure_reason.dart';

String billingCycleLabel(BillingCycle cycle) => switch (cycle) {
      BillingCycle.weekly => 'Weekly',
      BillingCycle.monthly => 'Monthly',
      BillingCycle.yearly => 'Yearly',
    };

String failureReasonText(SubscriptionFailureReason? reason) =>
    switch (reason) {
      SubscriptionFailureReason.insufficientBalance =>
        'The wallet balance was too low.',
      SubscriptionFailureReason.walletArchived => 'The wallet is archived.',
      SubscriptionFailureReason.categoryArchived => 'The category is archived.',
      SubscriptionFailureReason.manualPaymentRequired =>
        'Auto-deduct is off; payment is waiting.',
      null => 'This subscription is overdue.',
    };

IconData subscriptionIcon(BillingCycle cycle) => switch (cycle) {
      BillingCycle.weekly => Icons.event_repeat,
      BillingCycle.monthly => Icons.autorenew,
      BillingCycle.yearly => Icons.calendar_month,
    };
