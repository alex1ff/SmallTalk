import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/button/button_widget.dart';
import '/components/empty/empty_widget.dart';
import '/components/segmented_tab_bar.dart';
import '/components/trans/trans_widget.dart';
import '/components/wrapper.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/basic_page_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/index.dart';
import '/services/user_match_profile.dart';
import '/components/add_card_widget.dart';
import '/components/edit_card_widget.dart';
import '/custom_code/actions/index.dart' as actions;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

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
  List<CardsRecord> _latestCards = const [];

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
    _latestCards = cards;
  }

  DocumentReference? _effectiveSelectedCardRef([
    List<CardsRecord>? cards,
  ]) {
    final availableCards = cards ?? _latestCards;
    if (availableCards.isEmpty) {
      return null;
    }

    final selectedCard = _model.selectedCard;
    if (selectedCard != null) {
      final hasSelectedCard = availableCards.any(
        (card) => card.reference.path == selectedCard.path,
      );
      return hasSelectedCard ? selectedCard : availableCards.first.reference;
    }

    if (_model.shouldAutoSelectFirstCard) {
      return availableCards.first.reference;
    }

    return null;
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
      backgroundColor: ExpatlioDesign.background,
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
    final selectedCardRef = _effectiveSelectedCardRef();
    if (selectedCardRef == null) {
      return;
    }

    try {
      await FirebaseFunctions.instance.httpsCallable('requestWithdrawal').call({
        'cardId': selectedCardRef.id,
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) {
        return;
      }
      await actions.showTopNotification(
        context,
        error.message ?? 'Не удалось создать заявку на вывод',
        '',
        true,
      );
      return;
    }

    if (!mounted) {
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
    return AuthUserStreamWidget(
      builder: (context) {
        if (loggedIn && currentUserDocument == null) {
          return Scaffold(
            backgroundColor: ExpatlioDesign.background,
            body: const Center(
              child: CircularProgressIndicator.adaptive(),
            ),
          );
        }

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
            backgroundColor: ExpatlioDesign.background,
            body: Stack(
              children: [
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                      ExpatlioDesign.pagePadding,
                      ExpatlioDesign.space0,
                      ExpatlioDesign.pagePadding,
                      ExpatlioDesign.space0),
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
                                    color:
                                        FlutterFlowTheme.of(context).secondary,
                                    size: 50,
                                  ),
                                ),
                              );
                            }
                            List<CardsRecord> containerCardsRecordList =
                                snapshot.data!;
                            _syncSelectedCardWithCards(
                                containerCardsRecordList);
                            final effectiveSelectedCardRef =
                                _effectiveSelectedCardRef(
                              containerCardsRecordList,
                            );

                            return Container(
                              decoration: BoxDecoration(),
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space0),
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
                                            borderRadius:
                                                ExpatlioDesign.radiusMedium,
                                            buttonSize: 40,
                                            fillColor:
                                                FlutterFlowTheme.of(context)
                                                    .secondaryBackground,
                                            icon: Icon(
                                              FFIcons.kedit05,
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primaryText,
                                              size: 18,
                                            ),
                                            onPressed: () async {
                                              await showModalBottomSheet(
                                                isScrollControlled: true,
                                                backgroundColor:
                                                    Colors.transparent,
                                                context: context,
                                                builder: (context) {
                                                  return GestureDetector(
                                                    onTap: () {
                                                      FocusScope.of(context)
                                                          .unfocus();
                                                      FocusManager
                                                          .instance.primaryFocus
                                                          ?.unfocus();
                                                    },
                                                    child: Padding(
                                                      padding: MediaQuery
                                                          .viewInsetsOf(
                                                              context),
                                                      child: EditCardWidget(),
                                                    ),
                                                  );
                                                },
                                              ).then((value) =>
                                                  safeSetState(() {}));
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space8,
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space0),
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
                                          separatorBuilder: (_, __) => SizedBox(
                                              height: ExpatlioDesign.space8),
                                          itemBuilder:
                                              (context, containerVarIndex) {
                                            final containerVarItem =
                                                containerVar[containerVarIndex];
                                            return InkWell(
                                              splashColor: Colors.transparent,
                                              focusColor: Colors.transparent,
                                              hoverColor: Colors.transparent,
                                              highlightColor:
                                                  Colors.transparent,
                                              onTap: () async {
                                                _toggleSelectedCard(
                                                  containerVarItem.reference,
                                                );
                                              },
                                              child: Container(
                                                width: double.infinity,
                                                height: 60,
                                                decoration: BoxDecoration(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryBackground,
                                                  borderRadius: BorderRadius
                                                      .circular(ExpatlioDesign
                                                          .radiusExtraLarge),
                                                ),
                                                child: Padding(
                                                  padding: EdgeInsets.all(
                                                      ExpatlioDesign.space4),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    children: [
                                                      Container(
                                                        width: 52,
                                                        height: 52,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: ExpatlioDesign
                                                              .mutedSurface,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(22),
                                                        ),
                                                        child: Align(
                                                          alignment:
                                                              AlignmentDirectional(
                                                                  0, 0),
                                                          child: Icon(
                                                            FFIcons
                                                                .kcreditCard02,
                                                            color: FlutterFlowTheme
                                                                    .of(context)
                                                                .primaryText,
                                                            size: 20,
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Padding(
                                                          padding:
                                                              EdgeInsetsDirectional
                                                                  .fromSTEB(12,
                                                                      0, 8, 0),
                                                          child: Text(
                                                            containerVarItem
                                                                .pan,
                                                            style: FlutterFlowTheme
                                                                    .of(context)
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
                                                              .reference.path ==
                                                          effectiveSelectedCardRef
                                                              ?.path)
                                                        Padding(
                                                          padding:
                                                              EdgeInsetsDirectional
                                                                  .fromSTEB(0,
                                                                      0, 8, 0),
                                                          child: Container(
                                                            width: 30,
                                                            height: 30,
                                                            decoration:
                                                                BoxDecoration(
                                                              color: FlutterFlowTheme
                                                                      .of(context)
                                                                  .success,
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                            child: Align(
                                                              alignment:
                                                                  AlignmentDirectional(
                                                                      0, 0),
                                                              child: Icon(
                                                                FFIcons.kcheck,
                                                                color: Colors
                                                                    .black,
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
                              animationsMap[
                                  'containerOnActionTriggerAnimation']!,
                            );
                          },
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              ExpatlioDesign.space0,
                              ExpatlioDesign.space12,
                              ExpatlioDesign.space0,
                              ExpatlioDesign.space0),
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
                                  return GestureDetector(
                                    onTap: () {
                                      FocusScope.of(context).unfocus();
                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
                                    },
                                    child: Padding(
                                      padding: MediaQuery.viewInsetsOf(context),
                                      child: AddCardWidget(),
                                    ),
                                  );
                                },
                              ).then((value) => safeSetState(() {}));
                            },
                            child: Container(
                              width: double.infinity,
                              height: 60,
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .primaryBackground,
                                borderRadius: BorderRadius.circular(
                                    ExpatlioDesign.radiusExtraLarge),
                                border: Border.all(
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(ExpatlioDesign.space4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 35,
                                      height: 35,
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                        borderRadius: BorderRadius.circular(
                                          ExpatlioDesign.radiusMedium,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.add_sharp,
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                        size: 18,
                                      ),
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
                                  ].divide(
                                      SizedBox(width: ExpatlioDesign.space8)),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              ExpatlioDesign.space0,
                              ExpatlioDesign.space40,
                              ExpatlioDesign.space0,
                              ExpatlioDesign.space0),
                          child: Text(
                            FFLocalizations.of(context).getText(
                              'qpndbc1w' /* История операций */,
                            ),
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: 'Cool',
                                  fontSize: 20,
                                  letterSpacing: 0.0,
                                ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              ExpatlioDesign.space0,
                              ExpatlioDesign.space12,
                              ExpatlioDesign.space0,
                              ExpatlioDesign.space0),
                          child: ExpatlioSegmentedTabBar(
                            labels: [
                              FFLocalizations.of(context).getText(
                                'njy9zp1m' /* Все */,
                              ),
                              FFLocalizations.of(context).getText(
                                'hc7flvjs' /* Пополнения */,
                              ),
                              FFLocalizations.of(context).getText(
                                'f5efiq3t' /* Списания */,
                              ),
                            ],
                            selectedIndex: _model.replenishment,
                            onChanged: (index) {
                              _model.replenishment = index;
                              safeSetState(() {});
                            },
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              ExpatlioDesign.space0,
                              ExpatlioDesign.space12,
                              ExpatlioDesign.space0,
                              ExpatlioDesign.space0),
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
                                      color: FlutterFlowTheme.of(context)
                                          .secondary,
                                      size: 50,
                                    ),
                                  ),
                                );
                              }
                              List<TransactionsRecord>
                                  containerTransactionsRecordList =
                                  snapshot.data!;

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
                                                        TypeTransactions
                                                            .bonus));
                                              } else if (_model.replenishment ==
                                                  2) {
                                                return (e.type ==
                                                    TypeTransactions
                                                        .call_charge);
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
                                      separatorBuilder: (_, __) => SizedBox(
                                          height: ExpatlioDesign.space8),
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
                          .addToStart(SizedBox(
                            height: MediaQuery.paddingOf(context).top +
                                BasicPageHeader.height +
                                ExpatlioDesign.space16,
                          ))
                          .addToEnd(SizedBox(height: ExpatlioDesign.space112)),
                    ),
                  ),
                ),
                BasicPageHeader(
                  title: FFLocalizations.of(context).getText(
                    'qzktwdnl' /* Финансы */,
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional(0, 1),
                  child: AuthUserStreamWidget(
                    builder: (context) {
                      final currentBalance =
                          valueOrDefault(currentUserDocument?.balanceNS, 0.0);
                      final effectiveSelectedCardRef =
                          _effectiveSelectedCardRef();
                      final canSubmitWithdrawal =
                          currentUserReference != null &&
                              effectiveSelectedCardRef != null &&
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
                        child: Wrapper(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                              ExpatlioDesign.pagePadding,
                              ExpatlioDesign.space12,
                              ExpatlioDesign.pagePadding,
                              ExpatlioDesign.space32),
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
                            enabled: canSubmitWithdrawal,
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
                                    style: ExpatlioDesign.buttonTextStyle(
                                      context,
                                      color: FlutterFlowTheme.of(context)
                                          .primaryBackground,
                                    ),
                                  ),
                                  TextSpan(
                                    text: FFLocalizations.of(context).getText(
                                      'lv5jpiff' /* ₽ */,
                                    ),
                                    style: ExpatlioDesign.buttonTextStyle(
                                      context,
                                      color: FlutterFlowTheme.of(context)
                                          .primaryBackground,
                                    ),
                                  )
                                ],
                                style: ExpatlioDesign.buttonTextStyle(
                                  context,
                                  color: FlutterFlowTheme.of(context)
                                      .primaryBackground,
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
      },
    );
  }
}
