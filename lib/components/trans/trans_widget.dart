import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/payment_transaction_row.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';
import 'trans_model.dart';
export 'trans_model.dart';

class TransWidget extends StatefulWidget {
  const TransWidget({
    super.key,
    required this.trans,
    this.layoutId,
    this.refreshState = PaymentTransactionRefreshState.idle,
    this.onRetry,
  });

  final TransactionsRecord? trans;
  final String? layoutId;
  final PaymentTransactionRefreshState refreshState;
  final VoidCallback? onRetry;

  @override
  State<TransWidget> createState() => _TransWidgetState();
}

class _TransWidgetState extends State<TransWidget> {
  late TransModel _model;
  Future<VideoSessionsRecord>? _sessionFuture;

  bool get _isPurchase => widget.trans?.type == TypeTransactions.purchase;
  String get _layoutId =>
      widget.layoutId ?? widget.trans?.reference.path ?? 'empty';
  bool get _isWithdrawal => widget.trans?.type == TypeTransactions.withdrawal;

  bool get _isCallTransaction =>
      (widget.trans?.type == TypeTransactions.call_charge) ||
      (widget.trans?.type == TypeTransactions.earning);

  bool get _isDeclinedWithdrawal =>
      _isWithdrawal &&
      ((widget.trans?.status == StatusTransactions.declined) ||
          (widget.trans?.status == StatusTransactions.failed) ||
          (widget.trans?.status == StatusTransactions.cancelled));

  bool get _isPositiveTransaction {
    if (_isPurchase) {
      return widget.trans?.status == StatusTransactions.completed;
    }

    return (widget.trans?.type == TypeTransactions.bonus) ||
        (widget.trans?.type == TypeTransactions.earning) ||
        (widget.trans?.type == TypeTransactions.promocode);
  }

  bool get _isPendingPurchase =>
      _isPurchase && widget.trans?.status == StatusTransactions.pending;

  Color _leadingBackgroundColor(BuildContext context) {
    if (_isPositiveTransaction) {
      return Color(0x4F42FF00);
    }
    if (_isDeclinedWithdrawal) {
      return Color(0x40ED5154);
    }
    if (_isPendingPurchase) {
      return ExpatlioDesign.background;
    }
    return Color(0x40ED5154);
  }

  Color _leadingIconColor(BuildContext context) {
    if (_isPositiveTransaction) {
      return Color(0xFF02D623);
    }
    if (_isDeclinedWithdrawal) {
      return FlutterFlowTheme.of(context).error;
    }
    if (_isPendingPurchase) {
      return ExpatlioDesign.muted;
    }
    return FlutterFlowTheme.of(context).error;
  }

  Color _amountColor(BuildContext context) {
    if (_isPositiveTransaction) {
      return Color(0xFF02D623);
    }
    if (_isDeclinedWithdrawal) {
      return FlutterFlowTheme.of(context).error;
    }
    if (_isPendingPurchase) {
      return ExpatlioDesign.muted;
    }
    return ExpatlioDesign.text;
  }

  Color _titleColor(BuildContext context) {
    if (_isDeclinedWithdrawal) {
      return FlutterFlowTheme.of(context).error;
    }
    return ExpatlioDesign.text;
  }

  Color _subtitleColor(BuildContext context) {
    if (_isDeclinedWithdrawal) {
      return FlutterFlowTheme.of(context).error;
    }
    return ExpatlioDesign.muted;
  }

  String _formatCompactNumber(num value) {
    final doubleValue = value.toDouble();
    if (doubleValue == doubleValue.roundToDouble()) {
      return doubleValue.toStringAsFixed(0);
    }
    return doubleValue.toStringAsFixed(1);
  }

  String _amountLabel(BuildContext context) {
    final giftMinutes = widget.trans?.minutesPurchased ?? 0;
    final isGiftMinutesTransaction =
        widget.trans?.type == TypeTransactions.promocode ||
            (widget.trans?.type == TypeTransactions.bonus && giftMinutes > 0);
    if (isGiftMinutesTransaction) {
      final minutes = widget.trans?.minutesPurchased ?? 0;
      return '+${_formatCompactNumber(minutes)} ${FFLocalizations.of(context).getVariableText(
        ruText: 'мин',
        enText: 'min',
      )}';
    }
    if ((widget.trans?.type == TypeTransactions.purchase) ||
        (widget.trans?.type == TypeTransactions.bonus)) {
      return '+${widget.trans?.amountST.toString()} ST';
    } else if (widget.trans?.type == TypeTransactions.call_charge) {
      return '-${widget.trans?.amountST.toString()} ST';
    } else if (widget.trans?.type == TypeTransactions.earning) {
      return '+${widget.trans?.amount.toString()} ₽';
    } else if (widget.trans?.type == TypeTransactions.withdrawal) {
      return '-${widget.trans?.amount.toString()} ₽';
    } else {
      return ' ';
    }
  }

  String _purchaseSubtitle(BuildContext context) {
    if (widget.trans?.status == StatusTransactions.completed) {
      return '${FFLocalizations.of(context).getVariableText(
        ruText: 'Оплачено:',
        enText: 'Paid:',
      )}${widget.trans?.amount.toString()} ₽';
    }

    if (widget.trans?.status == StatusTransactions.failed) {
      return FFLocalizations.of(context).getVariableText(
        ruText: 'Платеж не прошел',
        enText: 'Payment failed',
      );
    }

    if (widget.trans?.status == StatusTransactions.cancelled) {
      return FFLocalizations.of(context).getVariableText(
        ruText: 'Оплата отменена',
        enText: 'Payment cancelled',
      );
    }

    return FFLocalizations.of(context).getVariableText(
      ruText: 'Ожидаем оплату',
      enText: 'Waiting for payment',
    );
  }

  String _withdrawalSubtitle(BuildContext context) {
    if (widget.trans?.status == StatusTransactions.completed) {
      return FFLocalizations.of(context).getVariableText(
        ruText: 'Выплачено',
        enText: 'Paid out',
      );
    }

    if (_isDeclinedWithdrawal) {
      return FFLocalizations.of(context).getVariableText(
        ruText: 'Вывод отклонен',
        enText: 'Withdrawal declined',
      );
    }

    return FFLocalizations.of(context).getVariableText(
      ruText: 'В обработке',
      enText: 'Processing',
    );
  }

  Future<VideoSessionsRecord>? _createSessionFuture() {
    final sessionRef = widget.trans?.sessionDocRef;
    if (!_isCallTransaction || sessionRef == null) {
      return null;
    }

    return VideoSessionsRecord.getDocumentOnce(sessionRef);
  }

  DateTime? _callStartedAt(VideoSessionsRecord? session) {
    if (session == null) {
      return null;
    }

    final sessionMetadata = session.snapshotData['sessionMetadata'];
    final connectedAt =
        sessionMetadata is Map ? sessionMetadata['callConnectedAt'] : null;

    if (connectedAt is DateTime) {
      return connectedAt;
    }

    return session.startedAt;
  }

  String _dateLabel(BuildContext context, {VideoSessionsRecord? session}) {
    final locale = FFLocalizations.of(context).languageCode;
    final callStartedAt = _callStartedAt(session);
    final dateValue = callStartedAt ?? widget.trans?.createdAt;

    if (dateValue == null) {
      return '...';
    }

    final dateLabel = dateTimeFormat(
      "d MMMM",
      dateValue,
      locale: locale,
    );

    if (callStartedAt == null) {
      return dateLabel;
    }

    final timeLabel = dateTimeFormat(
      "Hm",
      callStartedAt,
      locale: locale,
    );

    return '$dateLabel, $timeLabel';
  }

  Widget _buildDateText(BuildContext context) {
    final textStyle = FlutterFlowTheme.of(context).bodyMedium.override(
          fontFamily: 'sf pro display',
          color: ExpatlioDesign.muted,
          fontSize: 12.0,
          letterSpacing: 0.0,
          lineHeight: 1.2,
        );

    if (_sessionFuture == null) {
      return Text(
        _dateLabel(context),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textStyle,
      );
    }

    return FutureBuilder<VideoSessionsRecord>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        return Text(
          _dateLabel(context, session: snapshot.data),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textStyle,
        );
      },
    );
  }

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => TransModel());
    _sessionFuture = _createSessionFuture();
  }

  @override
  void didUpdateWidget(covariant TransWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trans?.sessionDocRef != widget.trans?.sessionDocRef ||
        oldWidget.trans?.type != widget.trans?.type) {
      _sessionFuture = _createSessionFuture();
    }
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  String _titleLabel(BuildContext context) {
    return switch (widget.trans?.type) {
      TypeTransactions.purchase => FFLocalizations.of(context).getVariableText(
          ruText: 'Пополнение баланса',
          enText: 'Top up balance',
        ),
      TypeTransactions.bonus => FFLocalizations.of(context).getVariableText(
          ruText: 'Бонус',
          enText: 'Bonus',
        ),
      TypeTransactions.call_charge =>
        FFLocalizations.of(context).getVariableText(
          ruText: 'Оплата разговора',
          enText: 'Call payment',
        ),
      TypeTransactions.earning => FFLocalizations.of(context).getVariableText(
          ruText: 'Заработок за разговор',
          enText: 'Call earnings',
        ),
      TypeTransactions.withdrawal =>
        FFLocalizations.of(context).getVariableText(
          ruText: 'Вывод средств',
          enText: 'Withdrawal',
        ),
      TypeTransactions.promocode => FFLocalizations.of(context).getVariableText(
          ruText: 'Промокод',
          enText: 'Promo code',
        ),
      _ => FFLocalizations.of(context).getVariableText(
          ruText: 'Операция',
          enText: 'Transaction',
        ),
    };
  }

  String _statusLabel(BuildContext context) {
    if (widget.trans?.type == TypeTransactions.purchase) {
      return _purchaseSubtitle(context);
    }
    if ((widget.trans?.type == TypeTransactions.call_charge) ||
        (widget.trans?.type == TypeTransactions.earning)) {
      return '${FFLocalizations.of(context).getVariableText(
        ruText: 'Разговор ',
        enText: 'Call ',
      )}${widget.trans?.callDuration}${FFLocalizations.of(context).getVariableText(
        ruText: ' мин',
        enText: ' min',
      )}';
    }
    if (widget.trans?.type == TypeTransactions.bonus) {
      return FFLocalizations.of(context).getVariableText(
        ruText: 'Спасибо за регистрацию!',
        enText: 'Thanks for registering!',
      );
    }
    if (widget.trans?.type == TypeTransactions.withdrawal) {
      return _withdrawalSubtitle(context);
    }
    if (widget.trans?.type == TypeTransactions.promocode) {
      return '${FFLocalizations.of(context).getVariableText(
        ruText: 'Промокод ',
        enText: 'Promo code ',
      )}${widget.trans?.promoCode}';
    }
    return ' -';
  }

  @override
  Widget build(BuildContext context) {
    return PaymentTransactionRowFrame(
      layoutId: _layoutId,
      refreshState: widget.refreshState,
      onRetry: widget.onRetry,
      leading: Container(
        decoration: BoxDecoration(
          color: _leadingBackgroundColor(context),
          borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
        ),
        child: Icon(
          FFIcons.kcoinsStacked01,
          color: _leadingIconColor(context),
          size: 20.0,
        ),
      ),
      primary: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _titleLabel(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'sf pro display',
                  color: _titleColor(context),
                  fontSize: 15.0,
                  letterSpacing: 0.0,
                  lineHeight: 1.2,
                ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: ExpatlioDesign.space4,
            ),
            child: _buildDateText(context),
          ),
        ],
      ),
      meta: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _amountLabel(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'sf pro display',
                  color: _amountColor(context),
                  fontSize: 15.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.normal,
                  lineHeight: 1.2,
                ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: ExpatlioDesign.space4,
            ),
            child: Text(
              _statusLabel(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'sf pro display',
                    color: _subtitleColor(context),
                    fontSize: 12.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.normal,
                    lineHeight: 1.2,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
