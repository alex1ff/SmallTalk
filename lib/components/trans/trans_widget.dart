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
                color: (widget.trans?.type == TypeTransactions.purchase) ||
                        (widget.trans?.type == TypeTransactions.bonus) ||
                        (widget.trans?.type == TypeTransactions.earning) ||
                        (widget.trans?.type == TypeTransactions.promocode)
                    ? Color(0x4F42FF00)
                    : Color(0x40ED5154),
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Icon(
                Icons.arrow_back,
                color: (widget.trans?.type == TypeTransactions.purchase) ||
                        (widget.trans?.type == TypeTransactions.bonus) ||
                        (widget.trans?.type == TypeTransactions.earning) ||
                        (widget.trans?.type == TypeTransactions.promocode)
                    ? Color(0xFF02D623)
                    : FlutterFlowTheme.of(context).error,
                size: 24.0,
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
                          return 'Пополнение баланса';
                        } else if (widget.trans?.type ==
                            TypeTransactions.bonus) {
                          return 'Бонус';
                        } else if (widget.trans?.type ==
                            TypeTransactions.call_charge) {
                          return 'Оплата разговора';
                        } else if (widget.trans?.type ==
                            TypeTransactions.earning) {
                          return 'Заработок за разговор';
                        } else if (widget.trans?.type ==
                            TypeTransactions.withdrawal) {
                          return 'Вывод средств';
                        } else if (widget.trans?.type ==
                            TypeTransactions.promocode) {
                          return 'Промокод';
                        } else {
                          return 'Операция';
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
                        dateTimeFormat(
                          "d MMMM",
                          widget.trans!.createdAt!,
                          locale: FFLocalizations.of(context).languageCode,
                        ),
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
                    () {
                      if ((widget.trans?.type == TypeTransactions.purchase) ||
                          (widget.trans?.type == TypeTransactions.bonus) ||
                          (widget.trans?.type == TypeTransactions.promocode)) {
                        return '+${widget.trans?.amountST.toString()} ST';
                      } else if (widget.trans?.type ==
                          TypeTransactions.call_charge) {
                        return '-${widget.trans?.amountST.toString()} ST';
                      } else if (widget.trans?.type ==
                          TypeTransactions.earning) {
                        return '+${widget.trans?.amount.toString()} ₽';
                      } else if (widget.trans?.type ==
                          TypeTransactions.withdrawal) {
                        return '-${widget.trans?.amount.toString()} ₽';
                      } else {
                        return ' ';
                      }
                    }(),
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          fontFamily: 'sf pro display',
                          color: (widget.trans?.type ==
                                      TypeTransactions.purchase) ||
                                  (widget.trans?.type ==
                                      TypeTransactions.bonus) ||
                                  (widget.trans?.type ==
                                      TypeTransactions.earning) ||
                                  (widget.trans?.type ==
                                      TypeTransactions.promocode)
                              ? Color(0xFF02D623)
                              : FlutterFlowTheme.of(context).primaryText,
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
                          return 'Оплачено:${widget.trans?.amount.toString()} ₽';
                        } else if ((widget.trans?.type ==
                                TypeTransactions.call_charge) ||
                            (widget.trans?.type == TypeTransactions.earning)) {
                          return 'Разговор${widget.trans?.callDuration.toString()} мин';
                        } else if (widget.trans?.type ==
                            TypeTransactions.bonus) {
                          return 'Спасибо за регистрацию!';
                        } else if (widget.trans?.type ==
                            TypeTransactions.withdrawal) {
                          return () {
                            if (widget.trans?.status ==
                                StatusTransactions.completed) {
                              return 'Выплачено';
                            } else if (widget.trans?.status ==
                                StatusTransactions.failed) {
                              return 'Отклонено';
                            } else {
                              return 'В обработке';
                            }
                          }();
                        } else if (widget.trans?.type ==
                            TypeTransactions.promocode) {
                          return 'Промокод ${widget.trans?.promoCode}';
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
