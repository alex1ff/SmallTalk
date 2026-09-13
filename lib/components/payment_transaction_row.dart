import 'dart:math' as math;

import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

const double paymentTransactionRowHeight = 60.0;
const double paymentTransactionLeadingSize = 52.0;
const double paymentTransactionMetaSlotWidth = 120.0;

double paymentTransactionRowHeightFor(BuildContext context) {
  final textScaler = MediaQuery.textScalerOf(context);
  final contentHeight = textScaler.scale(15.0) * 1.2 +
      ExpatlioDesign.space4 +
      textScaler.scale(12.0) * 1.2;
  return math.max(
    paymentTransactionRowHeight,
    contentHeight.ceilToDouble() + (ExpatlioDesign.space4 * 2),
  );
}

const teacherPaymentTransactionsRowsSlotKey =
    ValueKey<String>('teacher_payment_transactions_rows_slot');
const paymentTransactionLoadingKey =
    ValueKey<String>('payment_transaction_loading');
const paymentTransactionErrorKey =
    ValueKey<String>('payment_transaction_error');
const paymentTransactionEmptyKey =
    ValueKey<String>('payment_transaction_empty');

enum PaymentTransactionRefreshState { idle, refreshing, error }

ValueKey<String> paymentTransactionRowKey(String layoutId) =>
    ValueKey<String>('payment_transaction_row_$layoutId');

ValueKey<String> paymentTransactionLeadingSlotKey(String layoutId) =>
    ValueKey<String>('payment_transaction_leading_slot_$layoutId');

ValueKey<String> paymentTransactionPrimarySlotKey(String layoutId) =>
    ValueKey<String>('payment_transaction_primary_slot_$layoutId');

ValueKey<String> paymentTransactionMetaSlotKey(String layoutId) =>
    ValueKey<String>('payment_transaction_meta_slot_$layoutId');

ValueKey<String> paymentTransactionRetryButtonKey(String layoutId) =>
    ValueKey<String>('payment_transaction_retry_$layoutId');

ValueKey<String> paymentTransactionRefreshingKey(String layoutId) =>
    ValueKey<String>('payment_transaction_refreshing_$layoutId');

class PaymentTransactionRowFrame extends StatelessWidget {
  const PaymentTransactionRowFrame({
    super.key,
    required this.layoutId,
    required this.leading,
    required this.primary,
    required this.meta,
    this.refreshState = PaymentTransactionRefreshState.idle,
    this.onRetry,
  });

  final String layoutId;
  final Widget leading;
  final Widget primary;
  final Widget meta;
  final PaymentTransactionRefreshState refreshState;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final rowHeight = paymentTransactionRowHeightFor(context);
    final contentHeight = rowHeight - (ExpatlioDesign.space4 * 2);
    return Container(
      key: paymentTransactionRowKey(layoutId),
      width: double.infinity,
      height: rowHeight,
      decoration: BoxDecoration(
        color: ExpatlioDesign.card,
        borderRadius: BorderRadius.circular(ExpatlioDesign.cardRadius),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ExpatlioDesign.cardRadius),
        border: Border.all(color: ExpatlioDesign.border),
      ),
      padding: const EdgeInsets.all(ExpatlioDesign.space4),
      child: Row(
        children: [
          SizedBox(
            key: paymentTransactionLeadingSlotKey(layoutId),
            width: paymentTransactionLeadingSize,
            height: paymentTransactionLeadingSize,
            child: Stack(
              fit: StackFit.expand,
              children: [
                leading,
                if (refreshState == PaymentTransactionRefreshState.refreshing)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: ExpatlioDesign.mutedSurface,
                      borderRadius:
                          BorderRadius.circular(ExpatlioDesign.radiusLarge),
                    ),
                    child: Center(
                      child: SizedBox(
                        key: paymentTransactionRefreshingKey(layoutId),
                        width: 20.0,
                        height: 20.0,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2.0,
                        ),
                      ),
                    ),
                  ),
                if (refreshState == PaymentTransactionRefreshState.error)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: ExpatlioDesign.mutedSurface,
                      borderRadius:
                          BorderRadius.circular(ExpatlioDesign.radiusLarge),
                    ),
                    child: Semantics(
                      key: paymentTransactionRetryButtonKey(layoutId),
                      container: true,
                      button: true,
                      label: FFLocalizations.of(context).getVariableText(
                        ruText: 'Повторить загрузку операций',
                        enText: 'Retry loading transactions',
                      ),
                      child: Tooltip(
                        message: FFLocalizations.of(context).getVariableText(
                          ruText: 'Повторить загрузку операций',
                          enText: 'Retry loading transactions',
                        ),
                        excludeFromSemantics: true,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              ExpatlioDesign.radiusLarge,
                            ),
                            onTap: onRetry,
                            child: Center(
                              child: Icon(
                                Icons.refresh_rounded,
                                color: FlutterFlowTheme.of(context).error,
                                size: 20.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SizedBox(
              key: paymentTransactionPrimarySlotKey(layoutId),
              height: contentHeight,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: ExpatlioDesign.space12,
                ),
                child: primary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(
              end: ExpatlioDesign.space12,
            ),
            child: SizedBox(
              key: paymentTransactionMetaSlotKey(layoutId),
              width: paymentTransactionMetaSlotWidth,
              height: contentHeight,
              child: meta,
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentTransactionAsyncRow extends StatelessWidget {
  const PaymentTransactionAsyncRow({
    super.key,
    required this.layoutId,
    required this.hasError,
    this.refreshState = PaymentTransactionRefreshState.idle,
    this.onRetry,
  });

  final String layoutId;
  final bool hasError;
  final PaymentTransactionRefreshState refreshState;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final label = FFLocalizations.of(context).getVariableText(
      ruText: hasError ? 'Не удалось загрузить операции' : 'Загрузка операций',
      enText: hasError ? 'Could not load transactions' : 'Loading transactions',
    );
    final hint = FFLocalizations.of(context).getVariableText(
      ruText: hasError ? 'Данные появятся после переподключения' : 'Подождите',
      enText: hasError ? 'Data will appear after reconnecting' : 'Please wait',
    );

    return PaymentTransactionRowFrame(
      layoutId: layoutId,
      refreshState: refreshState,
      onRetry: onRetry,
      leading: DecoratedBox(
        decoration: BoxDecoration(
          color: ExpatlioDesign.mutedSurface,
          borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
        ),
        child: Center(
          child: hasError
              ? Icon(
                  Icons.error_outline_rounded,
                  key: paymentTransactionErrorKey,
                  color: FlutterFlowTheme.of(context).error,
                  size: 20.0,
                )
              : const SizedBox(
                  key: paymentTransactionLoadingKey,
                  width: 20.0,
                  height: 20.0,
                  child: CircularProgressIndicator(strokeWidth: 2.0),
                ),
        ),
      ),
      primary: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'sf pro display',
                  color: hasError
                      ? FlutterFlowTheme.of(context).error
                      : ExpatlioDesign.text,
                  fontSize: 15.0,
                  letterSpacing: 0.0,
                  lineHeight: 1.2,
                ),
          ),
          const SizedBox(height: ExpatlioDesign.space4),
          Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'sf pro display',
                  color: ExpatlioDesign.muted,
                  fontSize: 12.0,
                  letterSpacing: 0.0,
                  lineHeight: 1.2,
                ),
          ),
        ],
      ),
      meta: const SizedBox.expand(),
    );
  }
}

class PaymentTransactionEmptyRow extends StatelessWidget {
  const PaymentTransactionEmptyRow({
    super.key,
    required this.layoutId,
    this.refreshState = PaymentTransactionRefreshState.idle,
    this.onRetry,
  });

  final String layoutId;
  final PaymentTransactionRefreshState refreshState;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return PaymentTransactionRowFrame(
      layoutId: layoutId,
      refreshState: refreshState,
      onRetry: onRetry,
      leading: DecoratedBox(
        decoration: BoxDecoration(
          color: ExpatlioDesign.mutedSurface,
          borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
        ),
        child: const Center(
          child: Icon(
            Icons.receipt_long_outlined,
            key: paymentTransactionEmptyKey,
            color: ExpatlioDesign.muted,
            size: 20.0,
          ),
        ),
      ),
      primary: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            FFLocalizations.of(context).getVariableText(
              ruText: 'Операций пока нет',
              enText: 'No transactions yet',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'sf pro display',
                  color: ExpatlioDesign.text,
                  fontSize: 15.0,
                  letterSpacing: 0.0,
                  lineHeight: 1.2,
                ),
          ),
          const SizedBox(height: ExpatlioDesign.space4),
          Text(
            FFLocalizations.of(context).getVariableText(
              ruText: 'История появится после первой операции',
              enText: 'History appears after your first transaction',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'sf pro display',
                  color: ExpatlioDesign.muted,
                  fontSize: 12.0,
                  letterSpacing: 0.0,
                  lineHeight: 1.2,
                ),
          ),
        ],
      ),
      meta: const SizedBox.expand(),
    );
  }
}
