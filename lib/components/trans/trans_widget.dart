import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'trans_model.dart';
export 'trans_model.dart';

class TransWidget extends StatefulWidget {
  const TransWidget({
    super.key,
    required this.trans,
  });

  final TransactionsRecord? trans;

  @override
  State<TransWidget> createState() => _TransWidgetState();
}

class _TransWidgetState extends State<TransWidget> {
  late TransModel _model;

  bool get _isPurchase => widget.trans?.type == TypeTransactions.purchase;

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
    if (_isPendingPurchase) {
      return FlutterFlowTheme.of(context).secondaryBackground;
    }
    return Color(0x40ED5154);
  }

  Color _leadingIconColor(BuildContext context) {
    if (_isPositiveTransaction) {
      return Color(0xFF02D623);
    }
    if (_isPendingPurchase) {
      return FlutterFlowTheme.of(context).secondaryText;
    }
    return FlutterFlowTheme.of(context).error;
  }

  Color _amountColor(BuildContext context) {
    if (_isPositiveTransaction) {
      return Color(0xFF02D623);
    }
    if (_isPendingPurchase) {
      return FlutterFlowTheme.of(context).secondaryText;
    }
    return FlutterFlowTheme.of(context).primaryText;
  }

  String _amountLabel() {
    if ((widget.trans?.type == TypeTransactions.purchase) ||
        (widget.trans?.type == TypeTransactions.bonus) ||
        (widget.trans?.type == TypeTransactions.promocode)) {
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

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => TransModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 60.0,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: FlutterFlowTheme.of(context).secondaryBackground,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(4.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52.0,
              height: 52.0,
              decoration: BoxDecoration(
                color: _leadingBackgroundColor(context),
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Icon(
                FFIcons.kcoinsStacked01,
                color: _leadingIconColor(context),
                size: 20.0,
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(12.0, 0.0, 0.0, 0.0),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      () {
                        if (widget.trans?.type == TypeTransactions.purchase) {
                          return FFLocalizations.of(context).getVariableText(
                            ruText: 'Пополнение баланса',
                            enText: 'Top up balance',
                          );
                        } else if (widget.trans?.type ==
                            TypeTransactions.bonus) {
                          return FFLocalizations.of(context).getVariableText(
                            ruText: 'Бонус',
                            enText: 'Bonus',
                          );
                        } else if (widget.trans?.type ==
                            TypeTransactions.call_charge) {
                          return FFLocalizations.of(context).getVariableText(
                            ruText: 'Оплата разговора',
                            enText: 'Call payment',
                          );
                        } else if (widget.trans?.type ==
                            TypeTransactions.earning) {
                          return FFLocalizations.of(context).getVariableText(
                            ruText: 'Заработок за разговор',
                            enText: 'Call earnings',
                          );
                        } else if (widget.trans?.type ==
                            TypeTransactions.withdrawal) {
                          return FFLocalizations.of(context).getVariableText(
                            ruText: 'Вывод средств',
                            enText: 'Withdrawal',
                          );
                        } else if (widget.trans?.type ==
                            TypeTransactions.promocode) {
                          return FFLocalizations.of(context).getVariableText(
                            ruText: 'Промокод',
                            enText: 'Promo code',
                          );
                        } else {
                          return FFLocalizations.of(context).getVariableText(
                            ruText: 'Операция',
                            enText: 'Transaction',
                          );
                        }
                      }(),
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontFamily: 'sf pro display',
                            color: FlutterFlowTheme.of(context).primaryText,
                            fontSize: 15.0,
                            letterSpacing: 0.0,
                          ),
                    ),
                    Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 4.0, 0.0, 0.0),
                      child: Text(
                        widget.trans?.createdAt != null
                            ? dateTimeFormat(
                                "d MMMM",
                                widget.trans!.createdAt!,
                                locale:
                                    FFLocalizations.of(context).languageCode,
                              )
                            : '...',
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'sf pro display',
                              color: FlutterFlowTheme.of(context).secondaryText,
                              fontSize: 12.0,
                              letterSpacing: 0.0,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 12.0, 0.0),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _amountLabel(),
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          fontFamily: 'sf pro display',
                          color: _amountColor(context),
                          fontSize: 15.0,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.normal,
                        ),
                  ),
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(0.0, 4.0, 0.0, 0.0),
                    child: Text(
                      () {
                        if (widget.trans?.type == TypeTransactions.purchase) {
                          return _purchaseSubtitle(context);
                        } else if ((widget.trans?.type ==
                                TypeTransactions.call_charge) ||
                            (widget.trans?.type == TypeTransactions.earning)) {
                          return '${FFLocalizations.of(context).getVariableText(
                            ruText: 'Разговор ',
                            enText: 'Call ',
                          )}${widget.trans?.callDuration}${FFLocalizations.of(context).getVariableText(
                            ruText: ' мин',
                            enText: ' min',
                          )}';
                        } else if (widget.trans?.type ==
                            TypeTransactions.bonus) {
                          return FFLocalizations.of(context).getVariableText(
                            ruText: 'Спасибо за регистрацию!',
                            enText: 'Thanks for registering!',
                          );
                        } else if (widget.trans?.type ==
                            TypeTransactions.withdrawal) {
                          return () {
                            if (widget.trans?.status ==
                                StatusTransactions.completed) {
                              return FFLocalizations.of(context)
                                  .getVariableText(
                                ruText: 'Выплачено',
                                enText: 'Paid out',
                              );
                            } else if ((widget.trans?.status ==
                                    StatusTransactions.failed) ||
                                (widget.trans?.status ==
                                    StatusTransactions.cancelled)) {
                              return FFLocalizations.of(context)
                                  .getVariableText(
                                ruText: 'Отклонено',
                                enText: 'Declined',
                              );
                            } else {
                              return FFLocalizations.of(context)
                                  .getVariableText(
                                ruText: 'В обработке',
                                enText: 'Processing',
                              );
                            }
                          }();
                        } else if (widget.trans?.type ==
                            TypeTransactions.promocode) {
                          return '${FFLocalizations.of(context).getVariableText(
                            ruText: 'Промокод ',
                            enText: 'Promo code ',
                          )}${widget.trans?.promoCode}';
                        } else {
                          return ' -';
                        }
                      }(),
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontFamily: 'sf pro display',
                            color: FlutterFlowTheme.of(context).secondaryText,
                            fontSize: 12.0,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.normal,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
