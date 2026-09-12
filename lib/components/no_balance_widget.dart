import '/components/button/button_widget.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/components/wrapper.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/bottom_sheet_header.dart';
import '/components/promo_redeem_widget.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/students_pages/pay/pay_widget.dart';
import '/utils/subscription_utils.dart';
import 'package:flutter/material.dart';
import 'no_balance_model.dart';
export 'no_balance_model.dart';

const ValueKey<String> noBalancePromoCodeButtonKey =
    ValueKey<String>('no_balance_promo_code_button');

class NoBalanceWidget extends StatefulWidget {
  const NoBalanceWidget({
    super.key,
    this.promoRedeemOverride,
  });

  final PromoRedeemOverride? promoRedeemOverride;

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

  Future<void> _openPromoRedeem() async {
    final redeemed = await showPromoRedeemSheet(
      context: context,
      redeemOverride: widget.promoRedeemOverride,
    );
    if (!mounted || redeemed != true) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final hasTrial = isTrialSubscription(currentUserDocument);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Stack(
          alignment: AlignmentDirectional(0.0, 1.0),
          children: [
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.space0,
                  ExpatlioDesign.space0,
                  ExpatlioDesign.space0,
                  ExpatlioDesign.space0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    decoration: ExpatlioDesign.sheetDecoration(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        BottomSheetHeader(
                          title: FFLocalizations.of(context).getVariableText(
                            ruText: hasTrial
                                ? 'Пробный звонок завершён'
                                : 'Нет активной подписки',
                            enText: hasTrial
                                ? 'Trial call completed'
                                : 'No active subscription',
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              ExpatlioDesign.pagePadding,
                              ExpatlioDesign.space0,
                              ExpatlioDesign.pagePadding,
                              ExpatlioDesign.space0),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: ExpatlioDesign.card,
                              borderRadius: BorderRadius.circular(
                                  ExpatlioDesign.radiusExtraLarge),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(ExpatlioDesign.space24),
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
                                      borderRadius: BorderRadius.circular(
                                          ExpatlioDesign.cardRadius),
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
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space20,
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space0),
                                    child: Text(
                                      FFLocalizations.of(context)
                                          .getVariableText(
                                        ruText: hasTrial
                                            ? 'Получите Premium, чтобы продолжить звонки'
                                            : 'Оформите пробную подписку, чтобы начать звонок',
                                        enText: hasTrial
                                            ? 'Get Premium to continue calling'
                                            : 'Start a trial subscription to make a call',
                                      ),
                                      textAlign: TextAlign.center,
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            color: ExpatlioDesign.text,
                                            fontSize: 22.0,
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
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              ExpatlioDesign.space0,
                              ExpatlioDesign.space20,
                              ExpatlioDesign.space0,
                              ExpatlioDesign.space0),
                          child: wrapWithModel(
                            model: _model.buttonModel,
                            updateCallback: () => safeSetState(() {}),
                            child: Wrapper.keyboardAware(
                              child: ButtonWidget(
                                text:
                                    FFLocalizations.of(context).getVariableText(
                                  ruText: hasTrial
                                      ? 'Получить Premium сейчас'
                                      : 'Начать 3 дня бесплатно',
                                  enText: hasTrial
                                      ? 'Start Premium now'
                                      : 'Start 3 days free',
                                ),
                                action: () async {
                                  Navigator.pop(context);
                                  context.pushNamed(PayWidget.routeName);
                                },
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                            ExpatlioDesign.pagePadding,
                            ExpatlioDesign.space0,
                            ExpatlioDesign.pagePadding,
                            ExpatlioDesign.space16,
                          ),
                          child: TextButton(
                            key: noBalancePromoCodeButtonKey,
                            onPressed: _openPromoRedeem,
                            child: Text(
                              FFLocalizations.of(context).getVariableText(
                                ruText: 'У меня есть промокод',
                                enText: 'I have a promo code',
                              ),
                              style: ExpatlioDesign.buttonTextStyle(
                                context,
                                color: FlutterFlowTheme.of(context).primary,
                              ),
                            ),
                          ),
                        ),
                      ].divide(SizedBox(height: ExpatlioDesign.space16)),
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
