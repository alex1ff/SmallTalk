import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/payment_transaction_row.dart';
import '/components/retained_payment_stream_builder.dart';
import '/components/trans/trans_widget.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

class TeacherPaymentTransactionsStreamRows extends StatelessWidget {
  const TeacherPaymentTransactionsStreamRows({
    super.key,
    required this.ownerKey,
    required this.stream,
    required this.filterIndex,
    this.onRetry,
  });

  final String ownerKey;
  final Stream<List<TransactionsRecord>> stream;
  final int filterIndex;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return RetainedPaymentStreamBuilder<TransactionsRecord>(
      ownerKey: ownerKey,
      stream: stream,
      builder: (context, view) {
        final refreshState = switch (view.phase) {
          RetainedPaymentStreamPhase.refreshing =>
            PaymentTransactionRefreshState.refreshing,
          RetainedPaymentStreamPhase.errorWithData ||
          RetainedPaymentStreamPhase.errorWithoutData =>
            PaymentTransactionRefreshState.error,
          _ => PaymentTransactionRefreshState.idle,
        };

        if (view.phase == RetainedPaymentStreamPhase.initialLoading ||
            view.phase == RetainedPaymentStreamPhase.errorWithoutData) {
          return Container(
            key: teacherPaymentTransactionsRowsSlotKey,
            child: PaymentTransactionAsyncRow(
              layoutId: 'slot-0',
              hasError:
                  view.phase == RetainedPaymentStreamPhase.errorWithoutData,
              refreshState: refreshState,
              onRetry: onRetry,
            ),
          );
        }

        final visibleTransactions = view.data.where((transaction) {
          if (filterIndex == 1) {
            return transaction.type == TypeTransactions.purchase ||
                transaction.type == TypeTransactions.bonus;
          }
          if (filterIndex == 2) {
            return transaction.type == TypeTransactions.call_charge;
          }
          return true;
        }).toList();

        if (visibleTransactions.isEmpty) {
          return Container(
            key: teacherPaymentTransactionsRowsSlotKey,
            child: PaymentTransactionEmptyRow(
              layoutId: 'slot-0',
              refreshState: refreshState,
              onRetry: onRetry,
            ),
          );
        }

        return Container(
          key: teacherPaymentTransactionsRowsSlotKey,
          child: ListView.separated(
            padding: EdgeInsets.zero,
            primary: false,
            shrinkWrap: true,
            scrollDirection: Axis.vertical,
            itemCount: visibleTransactions.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: ExpatlioDesign.space8),
            itemBuilder: (context, index) {
              final transaction = visibleTransactions[index];
              return TransWidget(
                key: ValueKey<String>(
                  'payment_transaction_${transaction.reference.path}',
                ),
                trans: transaction,
                layoutId: 'slot-$index',
                refreshState: index == 0
                    ? refreshState
                    : PaymentTransactionRefreshState.idle,
                onRetry: index == 0 ? onRetry : null,
              );
            },
          ),
        );
      },
    );
  }
}
