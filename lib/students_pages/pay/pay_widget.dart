import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/trans/trans_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:async';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'package:collection/collection.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'pay_model.dart';
export 'pay_model.dart';

class PayWidget extends StatefulWidget {
  const PayWidget({super.key});

  static String routeName = 'pay';
  static String routePath = '/pay';

  @override
  State<PayWidget> createState() => _PayWidgetState();
}

class _PayWidgetState extends State<PayWidget> with TickerProviderStateMixin {
  late PayModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  final animationsMap = <String, AnimationInfo>{};

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PayModel());
    _model.packagesFuture = queryPackagesRecordOnce();
    _model.transactionsStream = queryTransactionsRecord(
      queryBuilder: (transactionsRecord) => transactionsRecord
          .where('userId', isEqualTo: currentUserReference)
          .orderBy('createdAt', descending: true),
    );

    _model.nameTextController ??= TextEditingController();
    _model.nameFocusNode ??= FocusNode();
    _model.nameFocusNode!.addListener(() => safeSetState(() {}));
    animationsMap.addAll({
      'columnOnActionTriggerAnimation': AnimationInfo(
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
        body: Stack(
          children: [
            Align(
              alignment: AlignmentDirectional(0.0, 0.0),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 6.0, 0.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context).primaryBackground,
                          borderRadius: BorderRadius.circular(24.0),
                          border: Border.all(
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    FFLocalizations.of(context).getText(
                                      'd9e9ehu6' /* Текущий баланс */,
                                    ),
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          fontFamily: 'sf pro display',
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryText,
                                          fontSize: 15.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.normal,
                                        ),
                                  ),
                                  AuthUserStreamWidget(
                                    builder: (context) => Text(
                                      '~ ${currentUserDocument?.balanceST.minutes.toInt()} минут',
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryText,
                                            fontSize: 15.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    0.0, 24.0, 0.0, 0.0),
                                child: RichText(
                                  textScaler: MediaQuery.of(context).textScaler,
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: valueOrDefault<String>(
                                          currentUserDocument
                                              ?.balanceST.smallTalks
                                              .toInt()
                                              .toString(),
                                          '0',
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primaryText,
                                              fontSize: 40.0,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.normal,
                                            ),
                                      ),
                                      TextSpan(
                                        text:
                                            FFLocalizations.of(context).getText(
                                          'vni7lmge' /* .small talks */,
                                        ),
                                        style: TextStyle(
                                          fontFamily: 'Cool',
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryText,
                                          fontSize: 24.0,
                                        ),
                                      )
                                    ],
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          fontFamily: 'Cool',
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                          fontSize: 40.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.normal,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                            10.0, 40.0, 0.0, 0.0),
                        child: Text(
                          FFLocalizations.of(context).getText(
                            '2dwkyn2f' /* Промокод */,
                          ),
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    fontFamily: 'Cool',
                                    fontSize: 20.0,
                                    letterSpacing: 0.0,
                                  ),
                        ),
                      ),
                      Padding(
                        padding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 12.0, 0.0, 0.0),
                        child: Container(
                          width: double.infinity,
                          height: 60.0,
                          decoration: BoxDecoration(
                            color:
                                FlutterFlowTheme.of(context).primaryBackground,
                            borderRadius: BorderRadius.circular(100.0),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(2.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Container(
                                  width: 56.0,
                                  height: 56.0,
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Align(
                                    alignment: AlignmentDirectional(0.0, 0.0),
                                    child: Icon(
                                      FFIcons.kgift02,
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      size: 20.0,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        8.0, 0.0, 0.0, 0.0),
                                    child: Container(
                                      width: double.infinity,
                                      child: TextFormField(
                                        controller: _model.nameTextController,
                                        focusNode: _model.nameFocusNode,
                                        onChanged: (_) => EasyDebounce.debounce(
                                          '_model.nameTextController',
                                          Duration(milliseconds: 0),
                                          () => safeSetState(() {}),
                                        ),
                                        autofocus: false,
                                        textCapitalization:
                                            TextCapitalization.characters,
                                        textInputAction: TextInputAction.done,
                                        obscureText: false,
                                        decoration: InputDecoration(
                                          isDense: false,
                                          labelText: FFLocalizations.of(context)
                                              .getText(
                                            'ozmnhrl5' /* Введите промокод */,
                                          ),
                                          labelStyle: FlutterFlowTheme.of(
                                                  context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                fontSize: 16.0,
                                                letterSpacing: 0.0,
                                              ),
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          errorBorder: InputBorder.none,
                                          focusedErrorBorder: InputBorder.none,
                                          suffixIcon: _model.nameTextController!
                                                  .text.isNotEmpty
                                              ? InkWell(
                                                  onTap: () async {
                                                    _model.nameTextController
                                                        ?.clear();
                                                    safeSetState(() {});
                                                  },
                                                  child: Icon(
                                                    Icons.clear,
                                                    size: 18.0,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              fontSize: 16.0,
                                              letterSpacing: 0.0,
                                            ),
                                        cursorColor:
                                            FlutterFlowTheme.of(context)
                                                .primaryText,
                                        enableInteractiveSelection: true,
                                        validator: _model
                                            .nameTextControllerValidator
                                            .asValidator(context),
                                        inputFormatters: [
                                          if (!isAndroid && !isiOS)
                                            TextInputFormatter.withFunction(
                                                (oldValue, newValue) {
                                              return TextEditingValue(
                                                selection: newValue.selection,
                                                text: newValue.text
                                                    .toCapitalization(
                                                        TextCapitalization
                                                            .characters),
                                              );
                                            }),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                if (_model.nameTextController.text != '')
                                  FlutterFlowIconButton(
                                    borderRadius: 70.0,
                                    buttonSize: 56.0,
                                    fillColor:
                                        FlutterFlowTheme.of(context).primary,
                                    icon: Icon(
                                      FFIcons.kchevronRight,
                                      color: FlutterFlowTheme.of(context)
                                          .primaryBackground,
                                      size: 20.0,
                                    ),
                                    onPressed: () async {
                                      var _shouldSetState = false;
                                      _model.codeCopy =
                                          await queryPromoCodesRecordOnce(
                                        queryBuilder: (promoCodesRecord) =>
                                            promoCodesRecord.where(
                                          'code',
                                          isEqualTo:
                                              _model.nameTextController.text,
                                        ),
                                        singleRecord: true,
                                      ).then((s) => s.firstOrNull);
                                      _shouldSetState = true;
                                      if (_model.codeCopy != null) {
                                        if (_model.codeCopy!.isActive) {
                                          if (_model.codeCopy!.expiredDate! >
                                              getCurrentTimestamp) {
                                            if (!(_model.codeCopy!.usedBy
                                                .where((e) =>
                                                    e.user ==
                                                    currentUserReference)
                                                .toList()
                                                .isNotEmpty)) {
                                              if (_model.codeCopy!.usageLimit >
                                                  _model.codeCopy!.usageCount) {
                                                await _model.codeCopy!.reference
                                                    .update({
                                                  ...mapToFirestore(
                                                    {
                                                      'usedBy': FieldValue
                                                          .arrayUnion([
                                                        getPromoUsedByFirestoreData(
                                                          updatePromoUsedByStruct(
                                                            PromoUsedByStruct(
                                                              user:
                                                                  currentUserReference,
                                                              data:
                                                                  getCurrentTimestamp,
                                                            ),
                                                            clearUnsetFields:
                                                                false,
                                                          ),
                                                          true,
                                                        )
                                                      ]),
                                                      'usageCount':
                                                          FieldValue.increment(
                                                              1),
                                                    },
                                                  ),
                                                });

                                                await currentUserReference!
                                                    .update(
                                                        createUsersRecordData(
                                                  balanceST:
                                                      createBalanceStruct(
                                                    fieldValues: {
                                                      'smallTalks': FieldValue
                                                          .increment(_model
                                                              .codeCopy!
                                                              .valueSamllTalk),
                                                      'minutes': FieldValue
                                                          .increment(_model
                                                                  .codeCopy!
                                                                  .valueSamllTalk *
                                                              10),
                                                    },
                                                    clearUnsetFields: false,
                                                  ),
                                                ));
                                                unawaited(
                                                  () async {
                                                    await TransactionsRecord
                                                        .collection
                                                        .doc()
                                                        .set(
                                                            createTransactionsRecordData(
                                                          userId:
                                                              currentUserReference,
                                                          createdAt:
                                                              getCurrentTimestamp,
                                                          type: TypeTransactions
                                                              .promocode,
                                                          amountST: _model
                                                              .codeCopy
                                                              ?.valueSamllTalk
                                                              .toDouble(),
                                                          promoCodeDocRef:
                                                              _model.codeCopy
                                                                  ?.reference,
                                                          promoCode: _model
                                                              .codeCopy?.code,
                                                        ));
                                                  }(),
                                                );
                                                unawaited(
                                                  () async {
                                                    await actions
                                                        .showTopNotification(
                                                      context,
                                                      'Промокод активирован',
                                                      'Вы получили ${_model.codeCopy?.valueSamllTalk.toString()} Small Talk!',
                                                      false,
                                                    );
                                                  }(),
                                                );
                                                safeSetState(() {
                                                  _model.nameTextController
                                                      ?.clear();
                                                });
                                              } else {
                                                await actions
                                                    .showTopNotification(
                                                  context,
                                                  'Промокод исчерпан',
                                                  '',
                                                  true,
                                                );
                                                if (_shouldSetState)
                                                  safeSetState(() {});
                                                return;
                                              }
                                            } else {
                                              await actions.showTopNotification(
                                                context,
                                                'Вы уже использовали этот промокод',
                                                '',
                                                true,
                                              );
                                              if (_shouldSetState)
                                                safeSetState(() {});
                                              return;
                                            }
                                          } else {
                                            await actions.showTopNotification(
                                              context,
                                              'Промокод истёк',
                                              '',
                                              true,
                                            );
                                            if (_shouldSetState)
                                              safeSetState(() {});
                                            return;
                                          }
                                        } else {
                                          await actions.showTopNotification(
                                            context,
                                            'Промокод неактивен',
                                            '',
                                            true,
                                          );
                                          if (_shouldSetState)
                                            safeSetState(() {});
                                          return;
                                        }
                                      } else {
                                        await actions.showTopNotification(
                                          context,
                                          'Промокод не найден',
                                          '',
                                          true,
                                        );
                                        if (_shouldSetState)
                                          safeSetState(() {});
                                        return;
                                      }

                                      if (_shouldSetState) safeSetState(() {});
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                10.0, 40.0, 0.0, 0.0),
                            child: Text(
                              FFLocalizations.of(context).getText(
                                '1uhw3x91' /* Выберите тариф */,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'Cool',
                                    fontSize: 20.0,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 12.0, 0.0, 0.0),
                            child: FutureBuilder<List<PackagesRecord>>(
                              future: _model.packagesFuture,
                              builder: (context, snapshot) {
                                List<PackagesRecord>
                                    listViewPackagesRecordList =
                                    snapshot.data ?? [];

                                return ListView.separated(
                                  padding: EdgeInsets.zero,
                                  primary: false,
                                  shrinkWrap: true,
                                  scrollDirection: Axis.vertical,
                                  itemCount: listViewPackagesRecordList.length,
                                  separatorBuilder: (_, __) =>
                                      SizedBox(height: 6.0),
                                  itemBuilder: (context, listViewIndex) {
                                    final listViewPackagesRecord =
                                        listViewPackagesRecordList[
                                            listViewIndex];
                                    return InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        _model.tarifDoc =
                                            listViewPackagesRecord;
                                        safeSetState(() {});
                                        HapticFeedback.mediumImpact();
                                      },
                                      child: Stack(
                                        alignment:
                                            AlignmentDirectional(1.0, -1.4),
                                        children: [
                                          Container(
                                            width: double.infinity,
                                            height: 90.0,
                                            decoration: BoxDecoration(
                                              color: listViewPackagesRecord
                                                          .reference ==
                                                      _model.tarifDoc?.reference
                                                  ? FlutterFlowTheme.of(context)
                                                      .primary
                                                  : FlutterFlowTheme.of(context)
                                                      .primaryBackground,
                                              borderRadius:
                                                  BorderRadius.circular(24.0),
                                              border: Border.all(
                                                color: listViewPackagesRecord
                                                            .reference ==
                                                        _model
                                                            .tarifDoc?.reference
                                                    ? FlutterFlowTheme.of(
                                                            context)
                                                        .primaryText
                                                    : Colors.transparent,
                                                width: 1.0,
                                              ),
                                            ),
                                            child: Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(
                                                      20.0, 16.0, 20.0, 16.0),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.max,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        listViewPackagesRecord
                                                            .name,
                                                        style: FlutterFlowTheme
                                                                .of(context)
                                                            .bodyMedium
                                                            .override(
                                                              fontFamily:
                                                                  'Cool',
                                                              color: listViewPackagesRecord
                                                                          .reference ==
                                                                      _model
                                                                          .tarifDoc
                                                                          ?.reference
                                                                  ? FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryBackground
                                                                  : FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                              fontSize: 24.0,
                                                              letterSpacing:
                                                                  0.0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .normal,
                                                            ),
                                                      ),
                                                      Text(
                                                        '${listViewPackagesRecord.price.toString()}₽',
                                                        style: FlutterFlowTheme
                                                                .of(context)
                                                            .bodyMedium
                                                            .override(
                                                              fontFamily:
                                                                  'Cool',
                                                              color: listViewPackagesRecord
                                                                          .reference ==
                                                                      _model
                                                                          .tarifDoc
                                                                          ?.reference
                                                                  ? FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryBackground
                                                                  : FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                              fontSize: 24.0,
                                                              letterSpacing:
                                                                  0.0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .normal,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      if (listViewPackagesRecord
                                                                  .description !=
                                                              '')
                                                        Text(
                                                          listViewPackagesRecord
                                                              .description,
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                color: listViewPackagesRecord
                                                                            .reference ==
                                                                        _model.tarifDoc
                                                                            ?.reference
                                                                    ? FlutterFlowTheme.of(
                                                                            context)
                                                                        .success
                                                                    : FlutterFlowTheme.of(
                                                                            context)
                                                                        .error,
                                                                fontSize: 15.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .normal,
                                                                lineHeight: 1.5,
                                                              ),
                                                        ),
                                                      if (listViewPackagesRecord
                                                              .oldPrice !=
                                                          0)
                                                        Text(
                                                          ' ${listViewPackagesRecord.oldPrice.toString()}₽ ',
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                color: listViewPackagesRecord
                                                                            .reference ==
                                                                        _model.tarifDoc
                                                                            ?.reference
                                                                    ? FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryBackground
                                                                    : FlutterFlowTheme.of(
                                                                            context)
                                                                        .secondaryText,
                                                                fontSize: 15.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .normal,
                                                                decoration:
                                                                    TextDecoration
                                                                        .lineThrough,
                                                                lineHeight: 1.5,
                                                              ),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          if (listViewPackagesRecord
                                                  .reference ==
                                              _model.tarifDoc?.reference)
                                            Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(0.0, 0.0, 2.0, 0.0),
                                              child: Container(
                                                width: 24.0,
                                                height: 24.0,
                                                decoration: BoxDecoration(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .success,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Align(
                                                  alignment:
                                                      AlignmentDirectional(
                                                          0.0, 0.0),
                                                  child: Icon(
                                                    Icons.done,
                                                    color: Colors.black,
                                                    size: 13.0,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ).animateOnActionTrigger(
                        animationsMap['columnOnActionTriggerAnimation']!,
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                            10.0, 40.0, 0.0, 0.0),
                        child: Text(
                          FFLocalizations.of(context).getText(
                            'd4ayjswx' /* История операций */,
                          ),
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    fontFamily: 'Cool',
                                    fontSize: 20.0,
                                    letterSpacing: 0.0,
                                  ),
                        ),
                      ),
                      Padding(
                        padding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 12.0, 0.0, 0.0),
                        child: Container(
                          width: double.infinity,
                          height: 40.0,
                          decoration: BoxDecoration(
                            color:
                                FlutterFlowTheme.of(context).primaryBackground,
                            borderRadius: BorderRadius.circular(100.0),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(2.0),
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
                                      height: 100.0,
                                      decoration: BoxDecoration(
                                        color: valueOrDefault<Color>(
                                          _model.replenishment == 0
                                              ? FlutterFlowTheme.of(context)
                                                  .secondaryBackground
                                              : Colors.transparent,
                                          FlutterFlowTheme.of(context)
                                              .secondaryBackground,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(24.0),
                                        shape: BoxShape.rectangle,
                                      ),
                                      child: Align(
                                        alignment:
                                            AlignmentDirectional(0.0, 0.0),
                                        child: Text(
                                          FFLocalizations.of(context).getText(
                                            '1owu01u1' /* Все */,
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
                                      height: 100.0,
                                      decoration: BoxDecoration(
                                        color: valueOrDefault<Color>(
                                          _model.replenishment == 1
                                              ? FlutterFlowTheme.of(context)
                                                  .secondaryBackground
                                              : Colors.transparent,
                                          Colors.transparent,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(24.0),
                                        shape: BoxShape.rectangle,
                                      ),
                                      child: Align(
                                        alignment:
                                            AlignmentDirectional(0.0, 0.0),
                                        child: Text(
                                          FFLocalizations.of(context).getText(
                                            'm8dxuyz4' /* Пополнения */,
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
                                      height: 100.0,
                                      decoration: BoxDecoration(
                                        color: valueOrDefault<Color>(
                                          _model.replenishment == 2
                                              ? FlutterFlowTheme.of(context)
                                                  .secondaryBackground
                                              : Colors.transparent,
                                          Colors.transparent,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(24.0),
                                        shape: BoxShape.rectangle,
                                      ),
                                      child: Align(
                                        alignment:
                                            AlignmentDirectional(0.0, 0.0),
                                        child: Text(
                                          FFLocalizations.of(context).getText(
                                            'xh0vamif' /* Списания */,
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
                        padding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 12.0, 0.0, 0.0),
                        child: StreamBuilder<List<TransactionsRecord>>(
                          stream: _model.transactionsStream,
                          builder: (context, snapshot) {
                            List<TransactionsRecord>
                                containerTransactionsRecordList =
                                snapshot.data ?? [];

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

                                  return ListView.separated(
                                    padding: EdgeInsets.zero,
                                    primary: false,
                                    shrinkWrap: true,
                                    scrollDirection: Axis.vertical,
                                    itemCount: list.length,
                                    separatorBuilder: (_, __) =>
                                        SizedBox(height: 6.0),
                                    itemBuilder: (context, listIndex) {
                                      final listItem = list[listIndex];
                                      return TransWidget(
                                        key: Key(
                                            'Keya8r_${listIndex}_of_${list.length}'),
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
                        .addToStart(SizedBox(height: 115.0))
                        .addToEnd(SizedBox(height: 120.0)),
                  ),
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
                  stops: [0.0, 0.8, 1.0],
                  begin: AlignmentDirectional(0.0, -1.0),
                  end: AlignmentDirectional(0, 1.0),
                ),
              ),
              child: Padding(
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
                            offset: Offset(
                              0.0,
                              2.0,
                            ),
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
                        'biuq69s8' /* Финансы */,
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
            ),
            Align(
              alignment: AlignmentDirectional(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0x00F2F2F7),
                      Color(0xACF2F2F7),
                      FlutterFlowTheme.of(context).secondaryBackground
                    ],
                    stops: [0.0, 0.2, 1.0],
                    begin: AlignmentDirectional(0.0, -1.0),
                    end: AlignmentDirectional(0, 1.0),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(6.0, 12.0, 6.0, 35.0),
                  child: InkWell(
                    splashColor: Colors.transparent,
                    focusColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    onTap: () async {
                      if (_model.tarifDoc != null) {
                        context.pushNamed(PayWebWiewWidget.routeName);
                      } else {
                        if (animationsMap['columnOnActionTriggerAnimation'] !=
                            null) {
                          animationsMap['columnOnActionTriggerAnimation']!
                              .controller
                              .forward(from: 0.0);
                        }
                        HapticFeedback.mediumImpact();
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: 60.0,
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).primaryText,
                        borderRadius: BorderRadius.circular(50.0),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(2.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    16.0, 0.0, 0.0, 0.0),
                                child: Text(
                                  FFLocalizations.of(context).getText(
                                    '5visqusd' /* Оплатить */,
                                  ),
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        fontFamily: 'Cool',
                                        color: FlutterFlowTheme.of(context)
                                            .primaryBackground,
                                        fontSize: 20.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.normal,
                                      ),
                                ),
                              ),
                            ),
                            if (_model.tarifDoc != null)
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    0.0, 0.0, 12.0, 0.0),
                                child: Text(
                                  '${_model.tarifDoc?.price.toString()}₽',
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        fontFamily: 'sf pro display',
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText,
                                        fontSize: 15.0,
                                        letterSpacing: 0.0,
                                      ),
                                ),
                              ),
                            Container(
                              width: 56.0,
                              height: 56.0,
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .primaryBackground,
                                shape: BoxShape.circle,
                              ),
                              child: Align(
                                alignment: AlignmentDirectional(0.0, 0.0),
                                child: Icon(
                                  FFIcons.karrowRight,
                                  color: Colors.black,
                                  size: 20.0,
                                ),
                              ),
                            ),
                          ],
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
    );
  }
}
