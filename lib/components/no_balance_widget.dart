import '/components/button/button_widget.dart';
import '/components/wrapper.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/bottom_sheet_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/components/promo_redeem_widget.dart';
import '/students_pages/pay/pay_widget.dart';
import 'package:flutter/material.dart';
import 'no_balance_model.dart';
export 'no_balance_model.dart';

class NoBalanceWidget extends StatefulWidget {
  const NoBalanceWidget({super.key});

  @override
  State<NoBalanceWidget> createState() => _NoBalanceWidgetState();
}

class _NoBalanceWidgetState extends State<NoBalanceWidget> {
  late NoBalanceModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => NoBalanceModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: AlignmentDirectional(0.0, 1.0),
      children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(0.0, 55.0, 0.0, 0.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: ExpatlioDesign.card,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28.0)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    BottomSheetHeader(
                      title: FFLocalizations.of(context).getVariableText(
                        ruText: 'Нет активной подписки',
                        enText: 'No active subscription',
                      ),
                      showConfirm: false,
                    ),
                    Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 6.0, 0.0),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: ExpatlioDesign.card,
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 150.0,
                                height: 150.0,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      ExpatlioDesign.primary,
                                      ExpatlioDesign.primaryEnd
                                    ],
                                    stops: [0.0, 1.0],
                                    begin: AlignmentDirectional(0.0, -1.0),
                                    end: AlignmentDirectional(0, 1.0),
                                  ),
                                  borderRadius: BorderRadius.circular(36.0),
                                ),
                                child: Align(
                                  alignment: AlignmentDirectional(0.0, 0.0),
                                  child: Image.asset(
                                    'assets/images/sticker_50.png',
                                    width: 150.0,
                                    height: 135.0,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    0.0, 20.0, 0.0, 0.0),
                                child: Text(
                                  FFLocalizations.of(context).getVariableText(
                                    ruText:
                                        'Оформите подписку, чтобы начать звонок',
                                    enText:
                                        'Subscribe to start an Expatlio call',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        fontFamily: 'sf pro display',
                                        color: ExpatlioDesign.text,
                                        fontSize: 21.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.w700,
                                        lineHeight: 1.1,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // ─── SUBSCRIPTION REWORK (promo entry point) ──
                    Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 18.0, 0.0, 0.0),
                      child: TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const PromoRedeemWidget(),
                          );
                        },
                        child: Text(
                          FFLocalizations.of(context).getVariableText(
                            ruText: 'У меня есть промокод',
                            enText: 'I have a promo code',
                          ),
                          style:
                              FlutterFlowTheme.of(context).titleSmall.override(
                                    fontFamily: 'sf pro display',
                                    color: FlutterFlowTheme.of(context).primary,
                                    fontSize: 15.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ),
                    ),
                    // ──────────────────────────────────────────────
                    Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 20.0, 0.0, 0.0),
                      child: wrapWithModel(
                        model: _model.buttonModel,
                        updateCallback: () => safeSetState(() {}),
                        child: Wrapper.keyboardAware(
                          child: ButtonWidget(
                            text: FFLocalizations.of(context).getVariableText(
                              ruText: 'Оформить подписку',
                              enText: 'Subscribe',
                            ),
                            action: () async {
                              Navigator.pop(context);
                              context.pushNamed(PayWidget.routeName);
                            },
                          ),
                        ),
                      ),
                    ),
                  ].divide(SizedBox(height: 2.0)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
