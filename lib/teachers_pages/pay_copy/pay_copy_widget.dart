import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/button/button_widget.dart';
import '/components/empty/empty_widget.dart';
import '/components/trans/trans_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/services/user_match_profile.dart';
import '/teachers_pages/components/add_card/add_card_widget.dart';
import '/teachers_pages/components/edit_card/edit_card_widget.dart';
import '/custom_code/actions/index.dart' as actions;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:webviewx_plus/webviewx_plus.dart';

import 'pay_copy_model.dart';
export 'pay_copy_model.dart';

class PayCopyWidget extends StatefulWidget {
  const PayCopyWidget({super.key});

  static String routeName = 'payCopy';
  static String routePath = '/payCopy';

  @override
  State<PayCopyWidget> createState() => _PayCopyWidgetState();
}

class _PayCopyWidgetState extends State<PayCopyWidget>
    with TickerProviderStateMixin {
  late PayCopyModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  final animationsMap = <String, AnimationInfo>{};

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PayCopyModel());

    animationsMap.addAll({
      'containerOnActionTriggerAnimation': AnimationInfo(
        trigger: AnimationTrigger.onActionTrigger,
        applyInitialState: true,
        effectsBuilder: () => [
          ShakeEffect(
            curve: Curves.easeInOut,
            delay: 0.0.ms,
            duration: 200.0.ms,
            hz: 5,
            offset: Offset(10.0, 0.0),
            rotation: 0,
          ),
        ],
      ),
    });
    setupAnimations(
      animationsMap.values.where((anim) =>
          anim.trigger == AnimationTrigger.onActionTrigger ||
          !anim.applyInitialState),
      this,
    );
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  void _syncSelectedCardWithCards(List<CardsRecord> cards) {
    final cardRefs = cards.map((card) => card.reference).toSet();
    var nextSelectedCard = _model.selectedCard;
    var nextShouldAutoSelect = _model.shouldAutoSelectFirstCard;

    if (cards.isEmpty) {
      nextSelectedCard = null;
      nextShouldAutoSelect = true;
    } else if (nextSelectedCard != null &&
        !cardRefs.contains(nextSelectedCard)) {
      nextSelectedCard = cards.first.reference;
      nextShouldAutoSelect = false;
    } else if (nextSelectedCard == null && nextShouldAutoSelect) {
      nextSelectedCard = cards.first.reference;
      nextShouldAutoSelect = false;
    }

    if (nextSelectedCard == _model.selectedCard &&
        nextShouldAutoSelect == _model.shouldAutoSelectFirstCard) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _model.selectedCard = nextSelectedCard;
      _model.shouldAutoSelectFirstCard = nextShouldAutoSelect;
      safeSetState(() {});
    });
  }

  void _toggleSelectedCard(DocumentReference cardRef) {
    _model.selectedCard = _model.selectedCard == cardRef ? null : cardRef;
    _model.shouldAutoSelectFirstCard = false;
    safeSetState(() {});
  }

  Widget _buildTeacherAccessPendingRedirect(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.goNamed(
        StudentsDashboardWidget.routeName,
        queryParameters: {
          'zn': serializeParam(false, ParamType.bool),
        }.withoutNulls,
      );
    });

    return Scaffold(
      backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
      body: Center(
        child: Text(
          FFLocalizations.of(context).getVariableText(
            ruText: 'Выплаты доступны после проверки заявки',
            enText: 'Payouts are available after approval',
          ),
          textAlign: TextAlign.center,
          style: FlutterFlowTheme.of(context).bodyMedium,
        ),
      ),
    );
  }

  Future<void> _submitWithdrawalRequest() async {
    final userRef = currentUserReference;
    final selectedCardRef = _model.selectedCard;
    if (userRef == null || selectedCardRef == null) {
      return;
    }

    final now = getCurrentTimestamp;
    var requestCreated = false;

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final userSnapshot = await transaction.get(userRef);
      if (!userSnapshot.exists) {
        return;
      }

      final selectedCardSnapshot = await transaction.get(selectedCardRef);
      if (!selectedCardSnapshot.exists) {
        return;
      }

      final freshUser = UsersRecord.fromSnapshot(userSnapshot);
      if (!canAccessTeacherSurfaces(freshUser)) {
        return;
      }

      final availableBalance = freshUser.balanceNS;
      if (availableBalance <= 0) {
        return;
      }

      final withdrawalRef = TransactionsRecord.collection.doc();
      transaction.set(
        withdrawalRef,
        createTransactionsRecordData(
          userId: userRef,
          createdAt: now,
          type: TypeTransactions.withdrawal,
          status: StatusTransactions.pending,
          amount: availableBalance,
          card: selectedCardRef,
        ),
      );

      transaction.update(
        userRef,
        mapToFirestore(
          {
            'balance_NS': FieldValue.delete(),
          },
        ),
      );

      requestCreated = true;
    });

    if (!mounted || !requestCreated) {
      return;
    }

    await actions.showTopNotification(
      context,
      'Заявка на вывод создана!',
      '',
      false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserDocument != null &&
        !canAccessTeacherSurfaces(currentUserDocument)) {
      return _buildTeacherAccessPendingRedirect(context);
    }

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        body: Stack(
          children: [
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(6, 0, 6, 0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StreamBuilder<List<CardsRecord>>(
                      stream: queryCardsRecord(
                        parent: currentUserReference,
                      ),
                      builder: (context, snapshot) {
                        // Customize what your widget looks like when it's loading.
                        if (!snapshot.hasData) {
                          return Center(
                            child: SizedBox(
                              width: 50,
                              height: 50,
                              child: SpinKitCircle(
                                color: FlutterFlowTheme.of(context).secondary,
                                size: 50,
                              ),
                            ),
                          );
                        }
                        List<CardsRecord> containerCardsRecordList =
                            snapshot.data!;
                        _syncSelectedCardWithCards(containerCardsRecordList);

                        return Container(
                          decoration: BoxDecoration(),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Padding(
                                padding:
                                    EdgeInsetsDirectional.fromSTEB(10, 0, 8, 0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      FFLocalizations.of(context).getText(
                                        'j9s3fbnb' /* Выберите способ вывода */,
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'Cool',
                                            fontSize: 20,
                                            letterSpacing: 0.0,
                                          ),
                                    ),
                                    if (containerCardsRecordList.isNotEmpty)
                                      FlutterFlowIconButton(
                                        borderRadius: 12,
                                        buttonSize: 40,
                                        fillColor: FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                        icon: Icon(
                                          FFIcons.kedit05,
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                          size: 18,
                                        ),
                                        onPressed: () async {
                                          await showModalBottomSheet(
                                            isScrollControlled: true,
                                            backgroundColor: Colors.transparent,
                                            context: context,
                                            builder: (context) {
                                              return WebViewAware(
                                                child: GestureDetector(
                                                  onTap: () {
                                                    FocusScope.of(context)
                                                        .unfocus();
                                                    FocusManager
                                                        .instance.primaryFocus
                                                        ?.unfocus();
                                                  },
                                                  child: Padding(
                                                    padding:
                                                        MediaQuery.viewInsetsOf(
                                                            context),
                                                    child: EditCardWidget(),
                                                  ),
                                                ),
                                              );
                                            },
                                          ).then(
                                              (value) => safeSetState(() {}));
                                        },
                                      ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding:
                                    EdgeInsetsDirectional.fromSTEB(0, 6, 0, 0),
                                child: Builder(
                                  builder: (context) {
                                    final containerVar =
                                        containerCardsRecordList.toList();

                                    return ListView.separated(
                                      padding: EdgeInsets.zero,
                                      primary: false,
                                      shrinkWrap: true,
                                      scrollDirection: Axis.vertical,
                                      itemCount: containerVar.length,
                                      separatorBuilder: (_, __) =>
                                          SizedBox(height: 6),
                                      itemBuilder:
                                          (context, containerVarIndex) {
                                        final containerVarItem =
                                            containerVar[containerVarIndex];
                                        return InkWell(
                                          splashColor: Colors.transparent,
                                          focusColor: Colors.transparent,
                                          hoverColor: Colors.transparent,
                                          highlightColor: Colors.transparent,
                                          onTap: () async {
                                            _toggleSelectedCard(
                                              containerVarItem.reference,
                                            );
                                          },
                                          child: Container(
                                            width: double.infinity,
                                            height: 60,
                                            decoration: BoxDecoration(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primaryBackground,
                                              borderRadius:
                                                  BorderRadius.circular(26),
                                            ),
                                            child: Padding(
                                              padding: EdgeInsets.all(4),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  Container(
                                                    width: 52,
                                                    height: 52,
                                                    decoration: BoxDecoration(
                                                      color: Color(0xFFF2F2F7),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              22),
                                                    ),
                                                    child: Align(
                                                      alignment:
                                                          AlignmentDirectional(
                                                              0, 0),
                                                      child: Icon(
                                                        FFIcons.kcreditCard02,
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryText,
                                                        size: 20,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Padding(
                                                      padding:
                                                          EdgeInsetsDirectional
                                                              .fromSTEB(
                                                                  12, 0, 8, 0),
                                                      child: Text(
                                                        containerVarItem.pan,
                                                        style:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .override(
                                                                  fontFamily:
                                                                      'sf pro display',
                                                                  fontSize: 16,
                                                                  letterSpacing:
                                                                      0.0,
                                                                ),
                                                      ),
                                                    ),
                                                  ),
                                                  if (containerVarItem
                                                          .reference ==
                                                      _model.selectedCard)
                                                    Padding(
                                                      padding:
                                                          EdgeInsetsDirectional
                                                              .fromSTEB(
                                                                  0, 0, 8, 0),
                                                      child: Container(
                                                        width: 30,
                                                        height: 30,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .success,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                        child: Align(
                                                          alignment:
                                                              AlignmentDirectional(
                                                                  0, 0),
                                                          child: Icon(
                                                            FFIcons.kcheck,
                                                            color: Colors.black,
                                                            size: 15,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ).animateOnActionTrigger(
                          animationsMap['containerOnActionTriggerAnimation']!,
                        );
                      },
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(0, 12, 0, 0),
                      child: InkWell(
                        splashColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: () async {
                          await showModalBottomSheet(
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            context: context,
                            builder: (context) {
                              return WebViewAware(
                                child: GestureDetector(
                                  onTap: () {
                                    FocusScope.of(context).unfocus();
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                  },
                                  child: Padding(
                                    padding: MediaQuery.viewInsetsOf(context),
                                    child: AddCardWidget(),
                                  ),
                                ),
                              );
                            },
                          ).then((value) => safeSetState(() {}));
                        },
                        child: Container(
                          width: double.infinity,
                          height: 60,
                          decoration: BoxDecoration(
                            color:
                                FlutterFlowTheme.of(context).primaryBackground,
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: FlutterFlowTheme.of(context)
                                  .secondaryBackground,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FlutterFlowIconButton(
                                  borderRadius: 12,
                                  buttonSize: 35,
                                  fillColor: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                  icon: Icon(
                                    Icons.add_sharp,
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    print('IconButton pressed ...');
                                  },
                                ),
                                Text(
                                  FFLocalizations.of(context).getText(
                                    'ljhzclav' /* Добавить карту */,
                                  ),
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        fontFamily: 'sf pro display',
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                        fontSize: 16,
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ].divide(SizedBox(width: 8)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(10, 40, 0, 0),
                      child: Text(
                        FFLocalizations.of(context).getText(
                          'qpndbc1w' /* История операций */,
                        ),
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'Cool',
                              fontSize: 20,
                              letterSpacing: 0.0,
                            ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(0, 12, 0, 0),
                      child: Container(
                        width: double.infinity,
                        height: 40,
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context).primaryBackground,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(2),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Expanded(
                                child: InkWell(
                                  splashColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  onTap: () async {
                                    _model.replenishment = 0;
                                    safeSetState(() {});
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: valueOrDefault<Color>(
                                        _model.replenishment == 0
                                            ? FlutterFlowTheme.of(context)
                                                .secondaryBackground
                                            : Colors.transparent,
                                        FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      shape: BoxShape.rectangle,
                                    ),
                                    child: Align(
                                      alignment: AlignmentDirectional(0, 0),
                                      child: Text(
                                        FFLocalizations.of(context).getText(
                                          'njy9zp1m' /* Все */,
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color: valueOrDefault<Color>(
                                                _model.replenishment == 0
                                                    ? FlutterFlowTheme.of(
                                                            context)
                                                        .primaryText
                                                    : FlutterFlowTheme.of(
                                                            context)
                                                        .secondaryText,
                                                FlutterFlowTheme.of(context)
                                                    .primaryText,
                                              ),
                                              fontSize: 15,
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  splashColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  onTap: () async {
                                    _model.replenishment = 1;
                                    safeSetState(() {});
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: valueOrDefault<Color>(
                                        _model.replenishment == 1
                                            ? FlutterFlowTheme.of(context)
                                                .secondaryBackground
                                            : Colors.transparent,
                                        Colors.transparent,
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      shape: BoxShape.rectangle,
                                    ),
                                    child: Align(
                                      alignment: AlignmentDirectional(0, 0),
                                      child: Text(
                                        FFLocalizations.of(context).getText(
                                          'hc7flvjs' /* Пополнения */,
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color: valueOrDefault<Color>(
                                                _model.replenishment == 1
                                                    ? FlutterFlowTheme.of(
                                                            context)
                                                        .primaryText
                                                    : FlutterFlowTheme.of(
                                                            context)
                                                        .secondaryText,
                                                FlutterFlowTheme.of(context)
                                                    .secondaryText,
                                              ),
                                              fontSize: 15,
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  splashColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  onTap: () async {
                                    _model.replenishment = 2;
                                    safeSetState(() {});
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: valueOrDefault<Color>(
                                        _model.replenishment == 2
                                            ? FlutterFlowTheme.of(context)
                                                .secondaryBackground
                                            : Colors.transparent,
                                        Colors.transparent,
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      shape: BoxShape.rectangle,
                                    ),
                                    child: Align(
                                      alignment: AlignmentDirectional(0, 0),
                                      child: Text(
                                        FFLocalizations.of(context).getText(
                                          'f5efiq3t' /* Списания */,
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color: valueOrDefault<Color>(
                                                _model.replenishment == 2
                                                    ? FlutterFlowTheme.of(
                                                            context)
                                                        .primaryText
                                                    : FlutterFlowTheme.of(
                                                            context)
                                                        .secondaryText,
                                                FlutterFlowTheme.of(context)
                                                    .secondaryText,
                                              ),
                                              fontSize: 15,
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(0, 12, 0, 0),
                      child: StreamBuilder<List<TransactionsRecord>>(
                        stream: queryTransactionsRecord(
                          queryBuilder: (transactionsRecord) =>
                              transactionsRecord
                                  .where(
                                    'userId',
                                    isEqualTo: currentUserReference,
                                  )
                                  .orderBy('createdAt', descending: true),
                        ),
                        builder: (context, snapshot) {
                          // Customize what your widget looks like when it's loading.
                          if (!snapshot.hasData) {
                            return Center(
                              child: SizedBox(
                                width: 50,
                                height: 50,
                                child: SpinKitCircle(
                                  color: FlutterFlowTheme.of(context).secondary,
                                  size: 50,
                                ),
                              ),
                            );
                          }
                          List<TransactionsRecord>
                              containerTransactionsRecordList = snapshot.data!;

                          return Container(
                            decoration: BoxDecoration(),
                            child: Builder(
                              builder: (context) {
                                final list = containerTransactionsRecordList
                                    .where((e) => () {
                                          if (_model.replenishment == 1) {
                                            return ((e.type ==
                                                    TypeTransactions
                                                        .purchase) ||
                                                (e.type ==
                                                    TypeTransactions.bonus));
                                          } else if (_model.replenishment ==
                                              2) {
                                            return (e.type ==
                                                TypeTransactions.call_charge);
                                          } else {
                                            return true;
                                          }
                                        }())
                                    .toList();
                                if (list.isEmpty) {
                                  return Center(
                                    child: EmptyWidget(
                                      txt:
                                          'Здесь появится история ваших операций: пополнения, списания и другие платежи. После первой операции она отобразится в этом разделе.',
                                    ),
                                  );
                                }

                                return ListView.separated(
                                  padding: EdgeInsets.zero,
                                  primary: false,
                                  shrinkWrap: true,
                                  scrollDirection: Axis.vertical,
                                  itemCount: list.length,
                                  separatorBuilder: (_, __) =>
                                      SizedBox(height: 6),
                                  itemBuilder: (context, listIndex) {
                                    final listItem = list[listIndex];
                                    return TransWidget(
                                      key: Key(
                                          'Key47o_${listIndex}_of_${list.length}'),
                                      trans: listItem,
                                    );
                                  },
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ]
                      .addToStart(SizedBox(height: 115))
                      .addToEnd(SizedBox(height: 120)),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    FlutterFlowTheme.of(context).secondaryBackground,
                    Color(0xEFF2F2F7),
                    Color(0x00F2F2F7)
                  ],
                  stops: [0, 0.8, 1],
                  begin: AlignmentDirectional(0, -1),
                  end: AlignmentDirectional(0, 1),
                ),
              ),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(12, 55, 12, 12),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 7,
                            color: Color(0x0D2C2C2C),
                            offset: Offset(
                              0,
                              2,
                            ),
                          )
                        ],
                        shape: BoxShape.circle,
                      ),
                      child: FlutterFlowIconButton(
                        borderRadius: 70,
                        buttonSize: 45,
                        fillColor: Colors.white,
                        icon: Icon(
                          FFIcons.kchevronLeft,
                          color: FlutterFlowTheme.of(context).primaryText,
                          size: 20,
                        ),
                        onPressed: () async {
                          context.safePop();
                        },
                      ),
                    ),
                    Text(
                      FFLocalizations.of(context).getText(
                        'qzktwdnl' /* Финансы */,
                      ),
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontFamily: 'Cool',
                            fontSize: 18,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.normal,
                          ),
                    ),
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: AlignmentDirectional(0, 1),
              child: AuthUserStreamWidget(
                builder: (context) {
                  final currentBalance =
                      valueOrDefault(currentUserDocument?.balanceNS, 0.0);
                  final canSubmitWithdrawal = currentUserReference != null &&
                      _model.selectedCard != null &&
                      currentBalance > 0;

                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0x00F2F2F7),
                          Color(0xACF2F2F7),
                          FlutterFlowTheme.of(context).secondaryBackground
                        ],
                        stops: [0, 0.2, 1],
                        begin: AlignmentDirectional(0, -1),
                        end: AlignmentDirectional(0, 1),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(6, 12, 6, 35),
                      child: ButtonWidget(
                        text: FFLocalizations.of(context).getText(
                          'djp5cokc' /* Вывести */,
                        ),
                        loadingText:
                            FFLocalizations.of(context).getVariableText(
                          ruText: 'Отправляем заявку...',
                          enText: 'Submitting request...',
                        ),
                        busyStyle: ButtonBusyStyle.spinner,
                        keyboardAwarePadding: false,
                        enabled: canSubmitWithdrawal,
                        padding: EdgeInsets.zero,
                        trailingContent: RichText(
                          textScaler: MediaQuery.of(context).textScaler,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: formatNumber(
                                  currentBalance,
                                  formatType: FormatType.decimal,
                                  decimalType: DecimalType.automatic,
                                ),
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      fontFamily: 'sf pro display',
                                      color: FlutterFlowTheme.of(context)
                                          .primaryBackground,
                                      fontSize: 18,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.normal,
                                    ),
                              ),
                              TextSpan(
                                text: FFLocalizations.of(context).getText(
                                  'lv5jpiff' /* ₽ */,
                                ),
                                style: TextStyle(
                                  fontFamily: 'Cool',
                                  color: FlutterFlowTheme.of(context)
                                      .primaryBackground,
                                  fontSize: 16,
                                ),
                              )
                            ],
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: 'Cool',
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  fontSize: 18,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.normal,
                                ),
                          ),
                        ),
                        action: () async {
                          await _submitWithdrawalRequest();
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
