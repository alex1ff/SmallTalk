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
import '/students_pages/components/tarif_loader/tarif_loader_widget.dart';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'package:collection/collection.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'pay_model.dart';
export 'pay_model.dart';

class _PromoActivationException implements Exception {
  const _PromoActivationException(this.message);

  final String message;
}

class PayWidget extends StatefulWidget {
  const PayWidget({super.key});

  static String routeName = 'pay';
  static String routePath = '/pay';

  @override
  State<PayWidget> createState() => _PayWidgetState();
}

class _PayWidgetState extends State<PayWidget> with TickerProviderStateMixin {
  late PayModel _model;
  late Future<List<PackagesRecord>> _packagesFuture;
  bool _isCreatingPaymentSession = false;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  final animationsMap = <String, AnimationInfo>{};

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PayModel());
    _packagesFuture = queryPackagesRecordOnce();
    _packagesFuture.then((packages) {
      if (!mounted || packages.isEmpty || _model.tarifDoc != null) {
        return;
      }
      safeSetState(() => _model.tarifDoc = packages.first);
    });

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

  String? _normalizeVisibleErrorMessage(String? rawMessage) {
    final normalized = rawMessage?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    final lowerCased = normalized.toLowerCase();
    const genericMessages = {
      'internal',
      'internal error',
      'unknown',
      'failed-precondition',
      'firebase_functions/internal',
    };

    if (genericMessages.contains(lowerCased)) {
      return null;
    }

    return normalized;
  }

  String? _extractMessageFromFunctionsDetails(dynamic details) {
    if (details is String) {
      return _normalizeVisibleErrorMessage(details);
    }

    if (details is Map) {
      for (final key in const [
        'userMessage',
        'message',
        'providerMessage',
        'details',
        'error',
      ]) {
        final candidate = _normalizeVisibleErrorMessage(
          details[key]?.toString(),
        );
        if (candidate != null) {
          return candidate;
        }
      }
    }

    return null;
  }

  String _resolvePaymentErrorMessage(FirebaseFunctionsException error) {
    final detailsMessage = _extractMessageFromFunctionsDetails(error.details);
    if (detailsMessage != null) {
      return detailsMessage;
    }

    final directMessage = _normalizeVisibleErrorMessage(error.message);
    if (directMessage != null) {
      return directMessage;
    }

    switch (error.code) {
      case 'failed-precondition':
        return 'Не удалось создать платеж. Проверьте настройки оплаты и попробуйте еще раз.';
      case 'unauthenticated':
        return 'Нужно заново войти в аккаунт, чтобы создать платеж.';
      default:
        return 'Не удалось создать платеж. Попробуйте еще раз.';
    }
  }

  Future<PromoCodesRecord?> _findPromoCode(String promoCode) async {
    final candidates = <String>{
      promoCode,
      promoCode.toUpperCase(),
    }.where((candidate) => candidate.isNotEmpty);

    for (final candidate in candidates) {
      final promoCodeRecord = await queryPromoCodesRecordOnce(
        queryBuilder: (promoCodesRecord) => promoCodesRecord.where(
          'code',
          isEqualTo: candidate,
        ),
        singleRecord: true,
      ).then((records) => records.firstOrNull);

      if (promoCodeRecord != null) {
        return promoCodeRecord;
      }
    }

    return null;
  }

  Future<void> _showPromoCodeNotification(
    String header, {
    String text = '',
    bool isError = true,
  }) async {
    if (!mounted) {
      return;
    }

    await actions.showTopNotification(
      context,
      header,
      text,
      isError,
    );
  }

  Future<void> _handleApplyPromoCode() async {
    final enteredPromoCode = _model.nameTextController.text.trim();
    if (enteredPromoCode.isEmpty) {
      return;
    }

    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    try {
      final promoCodeRecord = await _findPromoCode(enteredPromoCode);
      if (promoCodeRecord == null) {
        await _showPromoCodeNotification('Промокод не найден');
        return;
      }

      final userRef = currentUserReference;
      if (userRef == null) {
        throw const _PromoActivationException(
          'Нужно заново войти в аккаунт, чтобы активировать промокод.',
        );
      }

      final now = getCurrentTimestamp;
      PromoCodesRecord? activatedPromoCode;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final promoSnapshot = await transaction.get(promoCodeRecord.reference);
        if (!promoSnapshot.exists) {
          throw const _PromoActivationException('Промокод не найден');
        }

        final freshPromoCode = PromoCodesRecord.fromSnapshot(promoSnapshot);
        if (!freshPromoCode.isActive) {
          throw const _PromoActivationException('Промокод неактивен');
        }

        final expiredDate = freshPromoCode.expiredDate;
        if (expiredDate == null || !expiredDate.isAfter(now)) {
          throw const _PromoActivationException('Промокод истёк');
        }

        final alreadyUsed =
            freshPromoCode.usedBy.any((entry) => entry.user == userRef);
        if (alreadyUsed) {
          throw const _PromoActivationException(
            'Вы уже использовали этот промокод',
          );
        }

        if (freshPromoCode.usageCount >= freshPromoCode.usageLimit) {
          throw const _PromoActivationException('Промокод исчерпан');
        }

        final promoValue = freshPromoCode.valueSamllTalk.toDouble();
        if (promoValue <= 0) {
          throw const _PromoActivationException('Промокод недоступен');
        }

        transaction.update(freshPromoCode.reference, {
          'usedBy': FieldValue.arrayUnion([
            getPromoUsedByFirestoreData(
              updatePromoUsedByStruct(
                PromoUsedByStruct(
                  user: userRef,
                  data: now,
                ),
                clearUnsetFields: false,
              ),
              true,
            ),
          ]),
          'usageCount': FieldValue.increment(1),
        });

        transaction.update(userRef, {
          'balanceST.smallTalks': FieldValue.increment(promoValue),
          'balanceST.minutes': FieldValue.increment(promoValue * 10),
        });

        final transactionDoc = TransactionsRecord.collection.doc();
        transaction.set(
          transactionDoc,
          createTransactionsRecordData(
            userId: userRef,
            createdAt: now,
            type: TypeTransactions.promocode,
            amountST: promoValue,
            promoCodeDocRef: freshPromoCode.reference,
            promoCode: freshPromoCode.code,
          ),
        );

        activatedPromoCode = freshPromoCode;
      });

      if (!mounted || activatedPromoCode == null) {
        return;
      }

      safeSetState(() {
        _model.codeCopy = activatedPromoCode;
        _model.nameTextController?.clear();
      });

      await _showPromoCodeNotification(
        'Промокод активирован',
        text:
            'Вы получили ${activatedPromoCode!.valueSamllTalk.toString()} Small Talk!',
        isError: false,
      );
    } on _PromoActivationException catch (error) {
      await _showPromoCodeNotification(error.message);
    } catch (error, stackTrace) {
      debugPrint('Failed to apply promo code: $error');
      debugPrintStack(stackTrace: stackTrace);
      await _showPromoCodeNotification(
        'Не удалось активировать промокод',
        text: 'Попробуйте еще раз.',
      );
    } finally {
      if (mounted) {
        safeSetState(() {});
      }
    }
  }

  Future<void> _handlePayPressed() async {
    if (_isCreatingPaymentSession) {
      return;
    }

    final selectedPackage = _model.tarifDoc;
    if (selectedPackage == null) {
      if (animationsMap['columnOnActionTriggerAnimation'] != null) {
        animationsMap['columnOnActionTriggerAnimation']!
            .controller
            .forward(from: 0.0);
      }
      HapticFeedback.mediumImpact();
      return;
    }

    safeSetState(() => _isCreatingPaymentSession = true);

    var paymentUrl = '';
    var transactionRefPath = '';

    try {
      final response = await FirebaseFunctions.instance
          .httpsCallable('createPaymentSession')
          .call({
        'packageId': selectedPackage.reference.id,
      });
      final responseData =
          Map<String, dynamic>.from((response.data as Map?) ?? const {});

      paymentUrl = (responseData['paymentUrl']?.toString() ?? '').trim();
      transactionRefPath =
          (responseData['transactionRefPath']?.toString() ?? '').trim();

      if (paymentUrl.isEmpty || transactionRefPath.isEmpty) {
        throw Exception('Payment session response is incomplete');
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        showSnackbar(
          context,
          _resolvePaymentErrorMessage(error),
        );
      }
    } catch (_) {
      if (mounted) {
        showSnackbar(
          context,
          'Не удалось создать платеж. Попробуйте еще раз.',
        );
      }
    } finally {
      if (mounted) {
        safeSetState(() => _isCreatingPaymentSession = false);
      }
    }

    if (!mounted || paymentUrl.isEmpty || transactionRefPath.isEmpty) {
      return;
    }

    context.pushNamed(
      PayWebWiewWidget.routeName,
      queryParameters: {
        'paymentUrl': serializeParam(paymentUrl, ParamType.String),
        'transactionRefPath':
            serializeParam(transactionRefPath, ParamType.String),
      }.withoutNulls,
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final promoCodeFieldFocused = _model.nameFocusNode?.hasFocus ?? false;

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
              alignment: AlignmentDirectional(0, 0),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(6, 0, 6, 0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding:
                                EdgeInsetsDirectional.fromSTEB(10, 0, 0, 0),
                            child: Text(
                              FFLocalizations.of(context).getText(
                                '1uhw3x91' /* Выберите тариф */,
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
                            padding:
                                EdgeInsetsDirectional.fromSTEB(0, 12, 0, 0),
                            child: FutureBuilder<List<PackagesRecord>>(
                              future: _packagesFuture,
                              builder: (context, snapshot) {
                                // Customize what your widget looks like when it's loading.
                                if (!snapshot.hasData) {
                                  return TarifLoaderWidget();
                                }
                                List<PackagesRecord>
                                    listViewPackagesRecordList = snapshot.data!;

                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(
                                      listViewPackagesRecordList.length,
                                      (listViewIndex) {
                                    final listViewPackagesRecord =
                                        listViewPackagesRecordList[
                                            listViewIndex];
                                    return Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0,
                                        listViewIndex == 0 ? 0.0 : 6.0,
                                        0.0,
                                        0.0,
                                      ),
                                      child: InkWell(
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
                                              AlignmentDirectional(1, -1.4),
                                          children: [
                                            Container(
                                              width: double.infinity,
                                              height: 90,
                                              decoration: BoxDecoration(
                                                color: listViewPackagesRecord
                                                            .reference ==
                                                        _model
                                                            .tarifDoc?.reference
                                                    ? FlutterFlowTheme.of(
                                                            context)
                                                        .primary
                                                    : FlutterFlowTheme.of(
                                                            context)
                                                        .primaryBackground,
                                                borderRadius:
                                                    BorderRadius.circular(26),
                                                border: Border.all(
                                                  color:
                                                      listViewPackagesRecord
                                                                  .reference ==
                                                              _model.tarifDoc
                                                                  ?.reference
                                                          ? FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryText
                                                          : Colors.transparent,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(20, 16, 20, 16),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
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
                                                                        _model.tarifDoc
                                                                            ?.reference
                                                                    ? FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryBackground
                                                                    : FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryText,
                                                                fontSize: 24,
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
                                                                        _model.tarifDoc
                                                                            ?.reference
                                                                    ? FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryBackground
                                                                    : FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryText,
                                                                fontSize: 24,
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
                                                                          _model
                                                                              .tarifDoc
                                                                              ?.reference
                                                                      ? FlutterFlowTheme.of(
                                                                              context)
                                                                          .success
                                                                      : FlutterFlowTheme.of(
                                                                              context)
                                                                          .error,
                                                                  fontSize: 15,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .normal,
                                                                  lineHeight:
                                                                      1.5,
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
                                                                          _model
                                                                              .tarifDoc
                                                                              ?.reference
                                                                      ? FlutterFlowTheme.of(
                                                                              context)
                                                                          .primaryBackground
                                                                      : FlutterFlowTheme.of(
                                                                              context)
                                                                          .secondaryText,
                                                                  fontSize: 15,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .normal,
                                                                  decoration:
                                                                      TextDecoration
                                                                          .lineThrough,
                                                                  lineHeight:
                                                                      1.5,
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
                                                    .fromSTEB(0, 0, 2, 0),
                                                child: Container(
                                                  width: 24,
                                                  height: 24,
                                                  decoration: BoxDecoration(
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .success,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Align(
                                                    alignment:
                                                        AlignmentDirectional(
                                                            0, 0),
                                                    child: Icon(
                                                      Icons.done,
                                                      color: Colors.black,
                                                      size: 13,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                );
                              },
                            ),
                          ),
                        ],
                      ).animateOnActionTrigger(
                        animationsMap['columnOnActionTriggerAnimation']!,
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(10, 40, 0, 0),
                        child: Text(
                          FFLocalizations.of(context).getText(
                            '2dwkyn2f' /* Промокод */,
                          ),
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
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
                          height: 60,
                          decoration: BoxDecoration(
                            color:
                                FlutterFlowTheme.of(context).primaryBackground,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(2),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Align(
                                    alignment: AlignmentDirectional(0, 0),
                                    child: Icon(
                                      FFIcons.kgift02,
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        8, 0, 0, 0),
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
                                                fontSize: 16,
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
                                                    size: 18,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              fontSize: 16,
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
                                    borderRadius: 70,
                                    buttonSize: 56,
                                    fillColor:
                                        FlutterFlowTheme.of(context).primary,
                                    icon: Icon(
                                      FFIcons.kchevronRight,
                                      color: FlutterFlowTheme.of(context)
                                          .primaryBackground,
                                      size: 20,
                                    ),
                                    onPressed: () async {
                                      await _handleApplyPromoCode();
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(10, 40, 0, 0),
                        child: Text(
                          FFLocalizations.of(context).getText(
                            'd4ayjswx' /* История операций */,
                          ),
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
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
                            color:
                                FlutterFlowTheme.of(context).primaryBackground,
                            borderRadius: BorderRadius.circular(100),
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
                                    color:
                                        FlutterFlowTheme.of(context).secondary,
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
                                            'По выбранному типу операций пока ничего нет. Попробуйте другой фильтр.',
                                      ),
                                    );
                                  }

                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children:
                                        List.generate(list.length, (listIndex) {
                                      final listItem = list[listIndex];
                                      return Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                          0.0,
                                          listIndex == 0 ? 0.0 : 6.0,
                                          0.0,
                                          0.0,
                                        ),
                                        child: TransWidget(
                                          key: Key(
                                              'Keya8r_${listIndex}_of_${list.length}'),
                                          trans: listItem,
                                        ),
                                      );
                                    }),
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
                        'biuq69s8' /* Финансы */,
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
            if (!keyboardVisible && !promoCodeFieldFocused)
              Align(
                alignment: AlignmentDirectional(0, 1),
                child: Container(
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
                        '5visqusd' /* Оплатить */,
                      ),
                      loadingText: FFLocalizations.of(context).getVariableText(
                        ruText: 'Создаем оплату...',
                        enText: 'Creating payment...',
                      ),
                      busyStyle: ButtonBusyStyle.spinner,
                      keyboardAwarePadding: false,
                      padding: EdgeInsets.zero,
                      trailingContent: _model.tarifDoc != null
                          ? Text(
                              '${_model.tarifDoc!.price.toString()}₽',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    fontSize: 15,
                                    letterSpacing: 0.0,
                                  ),
                            )
                          : null,
                      action: () async {
                        await _handlePayPressed();
                      },
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
