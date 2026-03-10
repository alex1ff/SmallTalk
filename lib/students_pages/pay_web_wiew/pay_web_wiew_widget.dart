import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_web_view.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'pay_web_wiew_model.dart';
export 'pay_web_wiew_model.dart';

class PayWebWiewWidget extends StatefulWidget {
  const PayWebWiewWidget({
    super.key,
    this.paymentUrl,
    this.transactionRefPath,
  });

  final String? paymentUrl;
  final String? transactionRefPath;

  static String routeName = 'payWebWiew';
  static String routePath = '/payWebWiew';

  @override
  State<PayWebWiewWidget> createState() => _PayWebWiewWidgetState();
}

class _PayWebWiewWidgetState extends State<PayWebWiewWidget> {
  late PayWebWiewModel _model;
  StreamSubscription<TransactionsRecord>? _transactionSubscription;

  TransactionsRecord? _transactionRecord;
  String? _failureMessage;
  bool _didNavigateAfterSuccess = false;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  String get _resolvedPaymentUrl => (widget.paymentUrl ?? '').trim();
  String get _resolvedTransactionRefPath =>
      (widget.transactionRefPath ?? '').trim();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PayWebWiewModel());
    _listenToTransaction();
  }

  void _listenToTransaction() {
    if (_resolvedTransactionRefPath.isEmpty) {
      _failureMessage = 'Не удалось открыть платеж. Попробуйте снова.';
      return;
    }

    final transactionRef =
        FirebaseFirestore.instance.doc(_resolvedTransactionRefPath);
    _transactionSubscription = TransactionsRecord.getDocument(transactionRef)
        .listen(_handleTransactionUpdate, onError: (_) {
      if (!mounted) {
        return;
      }
      safeSetState(() {
        _failureMessage = 'Не удалось получить статус платежа.';
      });
    });
  }

  void _handleTransactionUpdate(TransactionsRecord record) {
    if (!mounted) {
      return;
    }

    if (record.status == StatusTransactions.completed &&
        !_didNavigateAfterSuccess) {
      _didNavigateAfterSuccess = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        context.goNamed(
          StudentsDashboardWidget.routeName,
          queryParameters: {
            'zn': serializeParam(false, ParamType.bool),
            'done': serializeParam(false, ParamType.bool),
            'topUpSuccess': serializeParam(true, ParamType.bool),
          }.withoutNulls,
        );
      });
      return;
    }

    safeSetState(() {
      _transactionRecord = record;
      if (record.status == StatusTransactions.failed) {
        _failureMessage = 'Платеж не прошел. Попробуйте еще раз.';
      } else if (record.status == StatusTransactions.cancelled) {
        _failureMessage = 'Оплата была отменена.';
      } else {
        _failureMessage = null;
      }
    });
  }

  Widget _buildStateCard({
    required BuildContext context,
    required Widget child,
  }) {
    return Padding(
      padding: EdgeInsets.all(6.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.0),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).primaryBackground,
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return _buildStateCard(
      context: context,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 52.0,
              height: 52.0,
              child: SpinKitCircle(
                color: FlutterFlowTheme.of(context).secondary,
                size: 52.0,
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
              child: Text(
                'Готовим страницу оплаты...',
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'sf pro display',
                      fontSize: 15.0,
                      letterSpacing: 0.0,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailureState(BuildContext context) {
    return _buildStateCard(
      context: context,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60.0,
                height: 60.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: FlutterFlowTheme.of(context).error,
                  size: 28.0,
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
                child: Text(
                  _failureMessage ?? 'Не удалось открыть оплату.',
                  textAlign: TextAlign.center,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'sf pro display',
                        fontSize: 15.0,
                        letterSpacing: 0.0,
                      ),
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 20.0, 0.0, 0.0),
                child: FlutterFlowIconButton(
                  borderRadius: 60.0,
                  buttonSize: 52.0,
                  fillColor: FlutterFlowTheme.of(context).primaryText,
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: FlutterFlowTheme.of(context).primaryBackground,
                    size: 22.0,
                  ),
                  onPressed: () async {
                    context.safePop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentWebView(BuildContext context) {
    return _buildStateCard(
      context: context,
      child: Stack(
        children: [
          FlutterFlowWebView(
            content: _resolvedPaymentUrl,
            bypass: false,
            width: MediaQuery.sizeOf(context).width * 1.0,
            height: MediaQuery.sizeOf(context).height * 1.0,
            verticalScroll: false,
            horizontalScroll: false,
          ),
          if (_transactionRecord?.status == StatusTransactions.pending)
            Align(
              alignment: AlignmentDirectional(0.0, -0.95),
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xCC000000),
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(12.0, 8.0, 12.0, 8.0),
                    child: Text(
                      'Ожидаем подтверждение оплаты',
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontFamily: 'sf pro display',
                            color:
                                FlutterFlowTheme.of(context).primaryBackground,
                            fontSize: 13.0,
                            letterSpacing: 0.0,
                          ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _transactionSubscription?.cancel();
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        body: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(12.0, 55.0, 12.0, 12.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 45.0,
                    height: 45.0,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 7.0,
                          color: Color(0x0D2C2C2C),
                          offset: Offset(0.0, 2.0),
                        )
                      ],
                      shape: BoxShape.circle,
                    ),
                    child: FlutterFlowIconButton(
                      borderRadius: 70.0,
                      buttonSize: 45.0,
                      fillColor: Colors.white,
                      icon: Icon(
                        FFIcons.kchevronLeft,
                        color: FlutterFlowTheme.of(context).primaryText,
                        size: 20.0,
                      ),
                      onPressed: () async {
                        context.safePop();
                      },
                    ),
                  ),
                  Text(
                    FFLocalizations.of(context).getText(
                      'yhgsg8gy' /* Оплата */,
                    ),
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          fontFamily: 'Cool',
                          fontSize: 18.0,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.normal,
                        ),
                  ),
                  Container(
                    width: 45.0,
                    height: 45.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _failureMessage != null
                  ? _buildFailureState(context)
                  : _resolvedPaymentUrl.isEmpty
                      ? _buildLoadingState(context)
                      : _buildPaymentWebView(context),
            ),
          ],
        ),
      ),
    );
  }
}
