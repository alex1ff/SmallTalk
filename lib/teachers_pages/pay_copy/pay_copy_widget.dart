import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/button/button_widget.dart';
import '/components/segmented_tab_bar.dart';
import '/components/teacher_payment_transactions_stream_rows.dart';
import '/components/teacher_payout_cards_section.dart';
import '/components/wrapper.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/basic_page_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/index.dart';
import '/services/user_match_profile.dart';
import '/components/add_card_widget.dart';
import '/components/delete_card_widget.dart';
import '/components/edit_card_widget.dart';
import '/custom_code/actions/index.dart' as actions;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show listEquals, visibleForTesting;
import 'package:flutter/material.dart';

import 'pay_copy_model.dart';
export 'pay_copy_model.dart';

const payCopyPaymentLoadingKey = ValueKey<String>('pay_copy_payment_loading');
const payCopyPaymentReadyKey = ValueKey<String>('pay_copy_payment_ready');
const payCopyPaymentSheetRevokedKey =
    ValueKey<String>('pay_copy_payment_sheet_revoked');

typedef PayCopyCardsStreamFactory = Stream<List<CardsRecord>> Function(
  DocumentReference owner,
);

typedef PayCopyTransactionsStreamFactory = Stream<List<TransactionsRecord>>
    Function(DocumentReference owner);

typedef PayCopyWithdrawalRequester = Future<void> Function(String cardId);

typedef PayCopyNotificationPresenter = Future<void> Function({
  required BuildContext context,
  required String message,
  required bool isError,
});

@visibleForTesting
Stream<List<T>> decodePaymentRecordBatches<D, T>(
  Stream<Iterable<D>> batches,
  T Function(D document) decode,
) {
  return batches.map(
    (documents) => List<T>.unmodifiable(documents.map(decode)),
  );
}

Stream<List<T>> _paymentRecordsStream<T>(
  Query<Object?> query,
  T Function(DocumentSnapshot snapshot) recordBuilder,
) {
  return decodePaymentRecordBatches<DocumentSnapshot, T>(
    query.snapshots().map((snapshot) => snapshot.docs),
    recordBuilder,
  );
}

Stream<List<CardsRecord>> _paymentCardsStream(DocumentReference owner) {
  return _paymentRecordsStream(
    CardsRecord.collection(owner),
    CardsRecord.fromSnapshot,
  );
}

Stream<List<TransactionsRecord>> _paymentTransactionsStream(
  DocumentReference owner,
) {
  return _paymentRecordsStream(
    TransactionsRecord.collection
        .where('userId', isEqualTo: owner)
        .orderBy('createdAt', descending: true),
    TransactionsRecord.fromSnapshot,
  );
}

class _PaymentAuthEvent {
  const _PaymentAuthEvent({required this.uid, required this.epoch});

  final String? uid;
  final int epoch;
}

class _PaymentSheetSession {
  _PaymentSheetSession({
    required this.ownerKey,
    required this.authEpoch,
  });

  final String ownerKey;
  final int authEpoch;
  final ValueNotifier<bool> revoked = ValueNotifier<bool>(false);
  final List<Route<dynamic>> routes = <Route<dynamic>>[];
  bool revocationScheduled = false;

  void registerRoute(Route<dynamic>? route) {
    if (route != null && !routes.contains(route)) {
      routes.add(route);
      if (revocationScheduled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final navigator = route.navigator;
          if (navigator != null && navigator.mounted && route.isActive) {
            navigator.removeRoute(route);
          }
        });
      }
    }
  }
}

class PayCopyWidget extends StatefulWidget {
  const PayCopyWidget({super.key})
      : _cardsStreamFactory = null,
        _transactionsStreamFactory = null,
        _editCardsStreamFactory = null,
        _addCardWriter = null,
        _deleteCard = null,
        _withdrawalRequester = null,
        _notificationPresenter = null,
        _authUidStream = null;

  @visibleForTesting
  const PayCopyWidget.withPaymentStreams({
    super.key,
    required PayCopyCardsStreamFactory cardsStreamFactory,
    required PayCopyTransactionsStreamFactory transactionsStreamFactory,
    PayCopyCardsStreamFactory? editCardsStreamFactory,
    AddCardWriter? addCardWriter,
    DeleteCardHandler? deleteCard,
    PayCopyWithdrawalRequester? withdrawalRequester,
    PayCopyNotificationPresenter? notificationPresenter,
    Stream<String?>? authUidStream,
  })  : _cardsStreamFactory = cardsStreamFactory,
        _transactionsStreamFactory = transactionsStreamFactory,
        _editCardsStreamFactory = editCardsStreamFactory,
        _addCardWriter = addCardWriter,
        _deleteCard = deleteCard,
        _withdrawalRequester = withdrawalRequester,
        _notificationPresenter = notificationPresenter,
        _authUidStream = authUidStream;

  final PayCopyCardsStreamFactory? _cardsStreamFactory;
  final PayCopyTransactionsStreamFactory? _transactionsStreamFactory;
  final PayCopyCardsStreamFactory? _editCardsStreamFactory;
  final AddCardWriter? _addCardWriter;
  final DeleteCardHandler? _deleteCard;
  final PayCopyWithdrawalRequester? _withdrawalRequester;
  final PayCopyNotificationPresenter? _notificationPresenter;
  final Stream<String?>? _authUidStream;

  static String routeName = 'payCopy';
  static String routePath = '/payCopy';

  @override
  State<PayCopyWidget> createState() => _PayCopyWidgetState();
}

class _PayCopyWidgetState extends State<PayCopyWidget> {
  late PayCopyModel _model;
  List<CardsRecord> _latestCards = const [];
  String? _paymentOwnerKey;
  String? _confirmedPaymentOwnerKey;
  int? _confirmedPaymentOwnerEpoch;
  String? _latestAuthUid;
  int _latestAuthEpoch = 0;
  bool _cardsRebuildScheduled = false;
  late final _PaymentAuthEvent _initialAuthEvent;
  late final Stream<_PaymentAuthEvent> _authEventsStream;
  _PaymentSheetSession? _paymentSheetSession;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PayCopyModel());
    _latestAuthUid = widget._authUidStream == null
        ? _normalizeAuthUid(FirebaseAuth.instance.currentUser?.uid)
        : null;
    if (_latestAuthUid != null) {
      _latestAuthEpoch = 1;
    }
    _initialAuthEvent = _PaymentAuthEvent(
      uid: _latestAuthUid,
      epoch: _latestAuthEpoch,
    );
    final authUidStream = widget._authUidStream ??
        FirebaseAuth.instance.authStateChanges().map((user) => user?.uid);
    _authEventsStream = authUidStream.map(_trackAuthUid);
  }

  @override
  void dispose() {
    _revokePaymentSheets();
    _model.dispose();

    super.dispose();
  }

  void _syncSelectedCardWithCards(List<CardsRecord> cards) {
    if (listEquals(_latestCards, cards)) {
      return;
    }

    _latestCards = List.unmodifiable(cards);
    if (_cardsRebuildScheduled) {
      return;
    }
    _cardsRebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cardsRebuildScheduled = false;
      if (mounted) {
        safeSetState(() {});
      }
    });
  }

  void _syncPaymentOwner(String ownerKey) {
    if (_paymentOwnerKey == ownerKey) {
      return;
    }
    _revokePaymentSheets();
    _paymentOwnerKey = ownerKey;
    _confirmedPaymentOwnerKey = null;
    _confirmedPaymentOwnerEpoch = null;
    _resetPaymentData();
  }

  void _resetPaymentData() {
    _latestCards = const [];
    _model.selectedCard = null;
    _model.shouldAutoSelectFirstCard = true;
    _model.cardsStream = null;
    _model.transactionsStream = null;
  }

  void _invalidateConfirmedPaymentOwner() {
    _revokePaymentSheets();
    _confirmedPaymentOwnerKey = null;
    _confirmedPaymentOwnerEpoch = null;
    _resetPaymentData();
  }

  _PaymentSheetSession? _beginPaymentSheet(String ownerKey) {
    final existingSession = _paymentSheetSession;
    if (existingSession != null) {
      _revokePaymentSheets();
      return null;
    }

    final session = _PaymentSheetSession(
      ownerKey: ownerKey,
      authEpoch: _latestAuthEpoch,
    );
    _paymentSheetSession = session;
    return session;
  }

  void _finishPaymentSheet(_PaymentSheetSession session) {
    if (identical(_paymentSheetSession, session)) {
      _paymentSheetSession = null;
    }
    session.revoked.dispose();
  }

  void _revokePaymentSheets() {
    final session = _paymentSheetSession;
    if (session == null || session.revocationScheduled) {
      return;
    }
    session.revocationScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!identical(_paymentSheetSession, session)) {
        return;
      }
      session.revoked.value = true;

      for (final route in session.routes.reversed.toList(growable: false)) {
        final navigator = route.navigator;
        if (navigator != null && navigator.mounted && route.isActive) {
          navigator.removeRoute(route);
        }
      }
    });
  }

  String? _normalizeAuthUid(String? authUid) {
    final normalizedUid = authUid?.trim();
    return normalizedUid == null || normalizedUid.isEmpty
        ? null
        : normalizedUid;
  }

  _PaymentAuthEvent _trackAuthUid(String? authUid) {
    final nextUid = _normalizeAuthUid(authUid);
    if (_latestAuthUid != nextUid) {
      _latestAuthUid = nextUid;
      _latestAuthEpoch += 1;
      _invalidateConfirmedPaymentOwner();
    }
    return _PaymentAuthEvent(uid: nextUid, epoch: _latestAuthEpoch);
  }

  bool _isPaymentSheetCurrent(_PaymentSheetSession session) {
    return mounted &&
        identical(_paymentSheetSession, session) &&
        !session.revocationScheduled &&
        !session.revoked.value &&
        session.authEpoch == _latestAuthEpoch &&
        _confirmedPaymentOwnerEpoch == session.authEpoch &&
        _isPaymentOwnerConfirmed(session.ownerKey);
  }

  bool _isPaymentOwnerConfirmed([String? expectedOwnerKey]) {
    if (!mounted) {
      return false;
    }
    final confirmedOwnerKey = _confirmedPaymentOwnerKey;
    final authoritativeUid = widget._authUidStream != null
        ? _latestAuthUid
        : FirebaseAuth.instance.currentUser?.uid;
    final paymentUserDocument = currentUserDocument;
    if (confirmedOwnerKey == null ||
        _confirmedPaymentOwnerEpoch != _latestAuthEpoch ||
        authoritativeUid == null ||
        authoritativeUid.isEmpty ||
        paymentUserDocument == null ||
        !canAccessTeacherSurfaces(paymentUserDocument)) {
      return false;
    }

    final authoritativeOwnerKey =
        UsersRecord.collection.doc(authoritativeUid).path;
    return confirmedOwnerKey == authoritativeOwnerKey &&
        _paymentOwnerKey == confirmedOwnerKey &&
        (expectedOwnerKey == null || expectedOwnerKey == confirmedOwnerKey) &&
        currentUserReference?.path == confirmedOwnerKey &&
        paymentUserDocument.reference.path == confirmedOwnerKey;
  }

  bool _isPaymentLeaseCurrent(String ownerKey, int authEpoch) {
    return _confirmedPaymentOwnerKey == ownerKey &&
        _confirmedPaymentOwnerEpoch == authEpoch &&
        _latestAuthEpoch == authEpoch &&
        _isPaymentOwnerConfirmed(ownerKey);
  }

  void _retryCards(DocumentReference owner) {
    if (owner.path != _paymentOwnerKey ||
        !_isPaymentOwnerConfirmed(owner.path)) {
      return;
    }
    final stream =
        widget._cardsStreamFactory?.call(owner) ?? _paymentCardsStream(owner);
    safeSetState(() {
      _model.cardsStream = stream;
    });
  }

  void _retryTransactions(DocumentReference owner) {
    if (owner.path != _paymentOwnerKey ||
        !_isPaymentOwnerConfirmed(owner.path)) {
      return;
    }
    final stream = widget._transactionsStreamFactory?.call(owner) ??
        _paymentTransactionsStream(owner);
    safeSetState(() {
      _model.transactionsStream = stream;
    });
  }

  DocumentReference? _effectiveSelectedCardRef([
    List<CardsRecord>? cards,
  ]) {
    return resolveTeacherPayoutSelectedCard(
      cards: cards ?? _latestCards,
      selectedCard: _model.selectedCard,
      shouldAutoSelectFirstCard: _model.shouldAutoSelectFirstCard,
    );
  }

  void _toggleSelectedCard(DocumentReference cardRef) {
    if (!_isPaymentOwnerConfirmed()) {
      return;
    }
    _model.selectedCard = _model.selectedCard == cardRef ? null : cardRef;
    _model.shouldAutoSelectFirstCard = false;
    safeSetState(() {});
  }

  Future<void> _openEditCards() async {
    final owner = currentUserReference;
    final ownerKey = owner?.path;
    if (owner == null ||
        ownerKey == null ||
        !_isPaymentOwnerConfirmed(ownerKey)) {
      return;
    }
    final session = _beginPaymentSheet(ownerKey);
    if (session == null) {
      return;
    }
    final editCardsStream = widget._editCardsStreamFactory?.call(owner);
    try {
      await showModalBottomSheet<void>(
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        context: context,
        builder: (context) {
          session.registerRoute(ModalRoute.of(context));
          return ValueListenableBuilder<bool>(
            valueListenable: session.revoked,
            builder: (context, revoked, _) {
              if (revoked || session.revocationScheduled) {
                return const SizedBox.shrink(
                  key: payCopyPaymentSheetRevokedKey,
                );
              }
              return GestureDetector(
                onTap: () {
                  FocusScope.of(context).unfocus();
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                child: Padding(
                  padding: MediaQuery.viewInsetsOf(context),
                  child: EditCardWidget(
                    owner: owner,
                    ownerIsCurrent: () => _isPaymentSheetCurrent(session),
                    cardsStream: editCardsStream,
                    deleteCard: widget._deleteCard,
                    revocation: session.revoked,
                    onPaymentRouteBuilt: session.registerRoute,
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      _finishPaymentSheet(session);
    }
    if (mounted) {
      safeSetState(() {});
    }
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
    final ownerKey = _confirmedPaymentOwnerKey;
    final authEpoch = _confirmedPaymentOwnerEpoch;
    if (ownerKey == null ||
        authEpoch == null ||
        !_isPaymentLeaseCurrent(ownerKey, authEpoch)) {
      return;
    }
    final selectedCardRef = _effectiveSelectedCardRef();
    if (selectedCardRef == null) {
      return;
    }

    try {
      final withdrawalRequester = widget._withdrawalRequester;
      if (withdrawalRequester != null) {
        await withdrawalRequester(selectedCardRef.id);
      } else {
        await FirebaseFunctions.instance
            .httpsCallable('requestWithdrawal')
            .call({
          'cardId': selectedCardRef.id,
        });
      }
    } on FirebaseFunctionsException catch (error) {
      if (!_isPaymentLeaseCurrent(ownerKey, authEpoch)) {
        return;
      }
      await _showPaymentNotification(
        _withdrawalErrorMessage(error.code),
        isError: true,
      );
      return;
    }

    if (!_isPaymentLeaseCurrent(ownerKey, authEpoch)) {
      return;
    }

    await _showPaymentNotification(
      FFLocalizations.of(context).getVariableText(
        ruText: 'Заявка на вывод создана!',
        enText: 'Withdrawal request created!',
      ),
      isError: false,
    );
  }

  String _withdrawalErrorMessage(String code) {
    final localizations = FFLocalizations.of(context);
    return switch (code) {
      'failed-precondition' => localizations.getVariableText(
          ruText: 'Проверьте реквизиты и доступный баланс.',
          enText: 'Check your payment details and available balance.',
        ),
      'unauthenticated' => localizations.getVariableText(
          ruText: 'Войдите в аккаунт и попробуйте снова.',
          enText: 'Sign in and try again.',
        ),
      _ => localizations.getVariableText(
          ruText: 'Не удалось создать заявку на вывод. Попробуйте позже.',
          enText:
              'Could not create the withdrawal request. Please try again later.',
        ),
    };
  }

  Future<void> _showPaymentNotification(
    String message, {
    required bool isError,
  }) async {
    final notificationPresenter = widget._notificationPresenter;
    if (notificationPresenter != null) {
      await notificationPresenter(
        context: context,
        message: message,
        isError: isError,
      );
      return;
    }
    await actions.showTopNotification(context, message, '', isError);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<_PaymentAuthEvent>(
      stream: _authEventsStream,
      initialData: _initialAuthEvent,
      builder: (context, authSnapshot) {
        final authEvent = authSnapshot.data ?? _initialAuthEvent;
        final authenticatedUid = authEvent.uid;
        if (authEvent.epoch != _latestAuthEpoch ||
            authenticatedUid != _latestAuthUid) {
          return Scaffold(
            backgroundColor: ExpatlioDesign.background,
            body: const Center(
              key: payCopyPaymentLoadingKey,
              child: CircularProgressIndicator.adaptive(),
            ),
          );
        }

        return AuthUserStreamWidget(
          builder: (context) {
            final paymentUserReference = currentUserReference;
            if (paymentUserReference == null) {
              _syncPaymentOwner('signed-out-payment-owner');
              return Scaffold(
                backgroundColor: ExpatlioDesign.background,
                body: const Center(
                  key: payCopyPaymentLoadingKey,
                  child: CircularProgressIndicator.adaptive(),
                ),
              );
            }

            if (authenticatedUid == null ||
                paymentUserReference.id != authenticatedUid) {
              _syncPaymentOwner(
                authenticatedUid == null
                    ? 'signed-out-payment-owner'
                    : 'auth-transition-$authenticatedUid',
              );
              return Scaffold(
                backgroundColor: ExpatlioDesign.background,
                body: const Center(
                  key: payCopyPaymentLoadingKey,
                  child: CircularProgressIndicator.adaptive(),
                ),
              );
            }

            if (loggedIn && currentUserDocument == null) {
              _invalidateConfirmedPaymentOwner();
              return Scaffold(
                backgroundColor: ExpatlioDesign.background,
                body: const Center(
                  key: payCopyPaymentLoadingKey,
                  child: CircularProgressIndicator.adaptive(),
                ),
              );
            }

            final paymentOwnerKey = paymentUserReference.path;
            _syncPaymentOwner(paymentOwnerKey);
            final paymentUserDocument = currentUserDocument;
            if (paymentUserDocument == null ||
                paymentUserDocument.reference.path != paymentOwnerKey) {
              _invalidateConfirmedPaymentOwner();
              return Scaffold(
                backgroundColor: ExpatlioDesign.background,
                body: const Center(
                  key: payCopyPaymentLoadingKey,
                  child: CircularProgressIndicator.adaptive(),
                ),
              );
            }

            if (currentUserDocument != null &&
                !canAccessTeacherSurfaces(currentUserDocument)) {
              _invalidateConfirmedPaymentOwner();
              return _buildTeacherAccessPendingRedirect(context);
            }

            _confirmedPaymentOwnerKey = paymentOwnerKey;
            _confirmedPaymentOwnerEpoch = authEvent.epoch;

            final cardsStream = _model.cardsStream ??=
                widget._cardsStreamFactory?.call(paymentUserReference) ??
                    _paymentCardsStream(paymentUserReference);
            final transactionsStream = _model.transactionsStream ??=
                widget._transactionsStreamFactory?.call(paymentUserReference) ??
                    _paymentTransactionsStream(paymentUserReference);

            return GestureDetector(
              key: payCopyPaymentReadyKey,
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
                            TeacherPayoutCardsStreamSection(
                              key: ValueKey<String>(
                                'teacher_payout_cards_$paymentOwnerKey',
                              ),
                              ownerKey: paymentOwnerKey,
                              stream: cardsStream,
                              selectedCard: _model.selectedCard,
                              shouldAutoSelectFirstCard:
                                  _model.shouldAutoSelectFirstCard,
                              onCardsChanged: (cards) {
                                if (_isPaymentOwnerConfirmed(paymentOwnerKey)) {
                                  _syncSelectedCardWithCards(cards);
                                }
                              },
                              onCardTap: _toggleSelectedCard,
                              onEditPressed: _openEditCards,
                              onRetry: () => _retryCards(paymentUserReference),
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
                                  if (!_isPaymentOwnerConfirmed(
                                      paymentOwnerKey)) {
                                    return;
                                  }
                                  final session =
                                      _beginPaymentSheet(paymentOwnerKey);
                                  if (session == null) {
                                    return;
                                  }
                                  try {
                                    await showModalBottomSheet<void>(
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      context: context,
                                      builder: (context) {
                                        session.registerRoute(
                                          ModalRoute.of(context),
                                        );
                                        return ValueListenableBuilder<bool>(
                                          valueListenable: session.revoked,
                                          builder: (context, revoked, _) {
                                            if (revoked ||
                                                session.revocationScheduled) {
                                              return const SizedBox.shrink(
                                                key:
                                                    payCopyPaymentSheetRevokedKey,
                                              );
                                            }
                                            return GestureDetector(
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
                                                child: AddCardWidget(
                                                  owner: paymentUserReference,
                                                  ownerIsCurrent: () =>
                                                      _isPaymentSheetCurrent(
                                                    session,
                                                  ),
                                                  cardWriter:
                                                      widget._addCardWriter,
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    );
                                  } finally {
                                    _finishPaymentSheet(session);
                                  }
                                  if (mounted) {
                                    safeSetState(() {});
                                  }
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
                                      color: ExpatlioDesign.border,
                                    ),
                                  ),
                                  child: Padding(
                                    padding:
                                        EdgeInsets.all(ExpatlioDesign.space4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                fontSize: 16,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ].divide(SizedBox(
                                          width: ExpatlioDesign.space8)),
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
                              child: TeacherPaymentTransactionsStreamRows(
                                key: ValueKey<String>(
                                  'teacher_payment_transactions_$paymentOwnerKey',
                                ),
                                ownerKey: paymentOwnerKey,
                                stream: transactionsStream,
                                filterIndex: _model.replenishment,
                                onRetry: () =>
                                    _retryTransactions(paymentUserReference),
                              ),
                            ),
                          ]
                              .addToStart(SizedBox(
                                height: MediaQuery.paddingOf(context).top +
                                    BasicPageHeader.height +
                                    ExpatlioDesign.space16,
                              ))
                              .addToEnd(
                                  SizedBox(height: ExpatlioDesign.space112)),
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
                          final currentBalance = valueOrDefault(
                              currentUserDocument?.balanceNS, 0.0);
                          final effectiveSelectedCardRef =
                              _effectiveSelectedCardRef();
                          final canSubmitWithdrawal =
                              _isPaymentOwnerConfirmed(paymentOwnerKey) &&
                                  currentUserReference != null &&
                                  effectiveSelectedCardRef != null &&
                                  currentBalance > 0;

                          return Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0x00F2F2F7),
                                  Color(0xACF2F2F7),
                                  FlutterFlowTheme.of(context)
                                      .secondaryBackground
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
                                        text:
                                            FFLocalizations.of(context).getText(
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
      },
    );
  }
}
