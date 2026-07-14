import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/auth/firebase_auth/auth_util.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/backend/schema/enums/enums.dart';
import 'package:small_talk/components/add_card_widget.dart';
import 'package:small_talk/components/bottom_sheet_header.dart';
import 'package:small_talk/components/delete_card_widget.dart';
import 'package:small_talk/components/edit_card_widget.dart';
import 'package:small_talk/components/payment_transaction_row.dart';
import 'package:small_talk/components/teacher_payout_cards_section.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/flutter_flow/flutter_flow_widgets.dart';
import 'package:small_talk/teachers_pages/pay_copy/pay_copy_widget.dart';

class _TestAuthState {
  final controller = StreamController<UserPlatform?>.broadcast(sync: true);
  UserPlatform? currentUser;
}

class _TestFirebaseAuthPlatform extends FirebaseAuthPlatform {
  _TestFirebaseAuthPlatform({FirebaseApp? app, _TestAuthState? state})
      : _state = state ?? _TestAuthState(),
        super(appInstance: app);

  final _TestAuthState _state;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) =>
      _TestFirebaseAuthPlatform(app: app, state: _state);

  @override
  FirebaseAuthPlatform setInitialValues({
    PigeonUserDetails? currentUser,
    String? languageCode,
  }) {
    this.languageCode = languageCode;
    return this;
  }

  @override
  UserPlatform? get currentUser => _state.currentUser;

  @override
  set currentUser(UserPlatform? userPlatform) {
    _state.currentUser = userPlatform;
  }

  @override
  String? languageCode;

  @override
  Stream<UserPlatform?> authStateChanges() => _state.controller.stream;

  @override
  Stream<UserPlatform?> idTokenChanges() => const Stream<UserPlatform?>.empty();

  @override
  Stream<UserPlatform?> userChanges() => const Stream<UserPlatform?>.empty();

  void emitUid(String? uid) {
    final user = uid == null
        ? null
        : _TestUserPlatform(
            this,
            _TestMultiFactorPlatform(this),
            PigeonUserDetails(
              userInfo: PigeonUserInfo(
                uid: uid,
                isAnonymous: false,
                isEmailVerified: true,
              ),
              providerData: const [],
            ),
          );
    _state.currentUser = user;
    _state.controller.add(user);
  }

  Future<void> close() => _state.controller.close();
}

class _TestUserPlatform extends UserPlatform {
  _TestUserPlatform(
    super.auth,
    super.multiFactor,
    super.user,
  );
}

class _TestMultiFactorPlatform extends MultiFactorPlatform {
  _TestMultiFactorPlatform(super.auth);
}

class _TestFirebaseFunctionsException extends FirebaseFunctionsException {
  _TestFirebaseFunctionsException({
    required super.code,
    required super.message,
  });
}

late _TestFirebaseAuthPlatform _authPlatform;

class _TestAuthUser extends BaseAuthUser {
  _TestAuthUser(this.userId);

  final String userId;

  @override
  bool get loggedIn => true;

  @override
  bool get emailVerified => true;

  @override
  AuthUserInfo get authUserInfo => AuthUserInfo(uid: userId);

  @override
  Future<void> delete() async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> updateEmail(String email) async {}

  @override
  Future<void> updatePassword(String newPassword) async {}
}

class _PaymentStreamCall<T> {
  _PaymentStreamCall(this.ownerPath) {
    controller = StreamController<List<T>>.broadcast(
      sync: true,
      onCancel: () => cancelCount += 1,
    );
  }

  final String ownerPath;
  late final StreamController<List<T>> controller;
  int cancelCount = 0;
}

class _PaymentStreamQueue<T> {
  final calls = <_PaymentStreamCall<T>>[];

  Stream<List<T>> load(DocumentReference owner) {
    final call = _PaymentStreamCall<T>(owner.path);
    calls.add(call);
    return call.controller.stream;
  }

  Future<void> close() async {
    for (final call in calls) {
      if (!call.controller.isClosed) {
        await call.controller.close();
      }
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    _authPlatform = _TestFirebaseAuthPlatform();
    FirebaseAuthPlatform.instance = _authPlatform;
    await FFLocalizations.initialize();
  });

  tearDownAll(() async {
    await _authPlatform.close();
  });

  setUp(() {
    _authPlatform.emitUid(null);
    currentUser = null;
    currentUserDocument = null;
  });

  tearDown(() {
    _authPlatform.emitUid(null);
    currentUser = null;
    currentUserDocument = null;
  });

  test('payment decoder emits errors instead of partial or false empty data',
      () async {
    final batches = StreamController<Iterable<String>>(sync: true);
    final values = <List<int>>[];
    final errors = <Object>[];
    final done = Completer<void>();

    decodePaymentRecordBatches<String, int>(
      batches.stream,
      (value) => int.parse(value),
    ).listen(
      values.add,
      onError: errors.add,
      onDone: done.complete,
    );

    batches.add(const ['1', '2']);
    batches.add(const ['broken']);
    batches.add(const ['3']);
    await batches.close();
    await done.future;

    expect(values, const [
      [1, 2],
      [3],
    ]);
    expect(errors, hasLength(1));
    expect(errors.single, isA<FormatException>());
  });

  testWidgets(
      'PayCopy scopes auth streams, retries retained errors, and rejects late owners',
      (tester) async {
    final cards = _PaymentStreamQueue<CardsRecord>();
    final editCards = _PaymentStreamQueue<CardsRecord>();
    final transactions = _PaymentStreamQueue<TransactionsRecord>();
    final authUids = StreamController<String?>.broadcast(sync: true);
    final deletedCards = <String>[];
    addTearDown(cards.close);
    addTearDown(editCards.close);
    addTearDown(transactions.close);
    addTearDown(authUids.close);

    Widget page() => PayCopyWidget.withPaymentStreams(
          key: const ValueKey<String>('pay-copy-under-test'),
          cardsStreamFactory: cards.load,
          transactionsStreamFactory: transactions.load,
          editCardsStreamFactory: editCards.load,
          deleteCard: (card) async => deletedCards.add(card.reference.path),
          authUidStream: authUids.stream,
        );

    Future<void> pumpPage() async {
      await tester.pumpWidget(_testApp(page()));
      await tester.pump();
      await tester.pump();
    }

    await pumpPage();
    expect(find.byKey(payCopyPaymentLoadingKey), findsOneWidget);
    expect(cards.calls, isEmpty);
    expect(transactions.calls, isEmpty);

    currentUser = _TestAuthUser('owner-a');
    currentUserDocument = _approvedTeacher('owner-a');
    authUids.add('owner-a');
    await tester.pump();
    await tester.pump();
    expect(find.byKey(payCopyPaymentReadyKey), findsOneWidget);
    expect(cards.calls.map((call) => call.ownerPath), ['users/owner-a']);
    expect(
      transactions.calls.map((call) => call.ownerPath),
      ['users/owner-a'],
    );
    expect(find.byKey(teacherPayoutCardLoadingKey), findsOneWidget);
    expect(find.byKey(paymentTransactionLoadingKey), findsOneWidget);

    cards.calls[0].controller.add([
      _card('owner-a', 'card-a', '•••• 1111'),
    ]);
    transactions.calls[0].controller.add([
      _transaction(
        'transaction-a',
        type: TypeTransactions.purchase,
        status: StatusTransactions.pending,
      ),
    ]);
    await tester.pump();
    await tester.pump();
    expect(find.text('•••• 1111'), findsOneWidget);
    expect(find.text('Ожидаем оплату'), findsOneWidget);

    cards.calls[0].controller.addError(
      FirebaseException(plugin: 'cloud_firestore', message: 'offline'),
    );
    transactions.calls[0].controller.addError(
      const FormatException('invalid transaction payload'),
    );
    await tester.pump();
    expect(find.text('•••• 1111'), findsOneWidget);
    expect(find.text('Ожидаем оплату'), findsOneWidget);
    expect(find.byKey(teacherPayoutCardsRetryButtonKey), findsOneWidget);
    expect(
      find.byKey(paymentTransactionRetryButtonKey('slot-0')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(teacherPayoutCardsRetryButtonKey));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(paymentTransactionRetryButtonKey('slot-0')),
    );
    await tester.tap(find.byKey(paymentTransactionRetryButtonKey('slot-0')));
    await tester.pump();
    expect(cards.calls, hasLength(2));
    expect(transactions.calls, hasLength(2));
    expect(find.text('•••• 1111'), findsOneWidget);
    expect(find.text('Ожидаем оплату'), findsOneWidget);
    expect(find.byKey(teacherPayoutCardsRefreshingKey), findsOneWidget);
    expect(
      find.byKey(paymentTransactionRefreshingKey('slot-0')),
      findsOneWidget,
    );

    cards.calls[1].controller.add([
      _card('owner-a', 'card-a-recovered', '•••• 2222'),
    ]);
    transactions.calls[1].controller.add([
      _transaction(
        'transaction-a-recovered',
        type: TypeTransactions.bonus,
        status: StatusTransactions.completed,
      ),
    ]);
    await tester.pump();
    await tester.pump();
    expect(find.text('•••• 2222'), findsOneWidget);
    expect(find.text('Бонус'), findsOneWidget);
    expect(find.byKey(teacherPayoutCardsRetryButtonKey), findsNothing);

    await tester.tap(find.byKey(teacherPayoutCardsEditSlotKey));
    await tester.pump();
    expect(editCards.calls, hasLength(1));
    expect(editCards.calls.single.ownerPath, 'users/owner-a');
    editCards.calls.single.controller.add([
      _card('owner-a', 'edit-card-a', '•••• 4444'),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(EditCardWidget), findsOneWidget);
    expect(find.text('•••• 4444'), findsOneWidget);

    await tester.tap(
      find.byKey(
        editCardDeleteButtonKey('users/owner-a/cards/edit-card-a'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(DeleteCardWidget), findsOneWidget);
    final staleDelete = tester
        .widget<FFButtonWidget>(find.byKey(deleteCardConfirmButtonKey))
        .onPressed!;

    currentUser = _TestAuthUser('owner-b');
    authUids.add('owner-b');
    await Future<void>.sync(staleDelete);
    expect(deletedCards, isEmpty);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(payCopyPaymentLoadingKey), findsOneWidget);
    expect(find.byType(EditCardWidget), findsNothing);
    expect(find.byType(DeleteCardWidget), findsNothing);
    expect(find.text('•••• 4444'), findsNothing);
    expect(find.text('•••• 2222'), findsNothing);
    expect(find.text('Бонус'), findsNothing);
    expect(find.text('Добавить карту'), findsNothing);
    expect(find.text('Вывести'), findsNothing);
    expect(cards.calls, hasLength(2));
    expect(transactions.calls, hasLength(2));
    expect(cards.calls[1].cancelCount, 1);
    expect(editCards.calls.single.cancelCount, 1);
    expect(transactions.calls[1].cancelCount, 1);

    editCards.calls.single.controller.add([
      _card('owner-a', 'late-edit-card-a', '•••• 8888'),
    ]);

    cards.calls[1].controller.add([
      _card('owner-a', 'late-card-a', '•••• 9999'),
    ]);
    cards.calls[1].controller.addError(StateError('late owner A error'));
    transactions.calls[1].controller.add([
      _transaction(
        'late-transaction-a',
        type: TypeTransactions.promocode,
        status: StatusTransactions.completed,
      ),
    ]);
    transactions.calls[1].controller.addError(
      StateError('late owner A transaction error'),
    );
    await tester.pump();
    expect(find.text('•••• 8888'), findsNothing);
    expect(find.text('•••• 9999'), findsNothing);
    expect(find.text('Промокод'), findsNothing);

    currentUserDocument = _approvedTeacher('owner-b');
    authUids.add('owner-b');
    await tester.pump();
    await tester.pump();
    expect(find.byKey(payCopyPaymentReadyKey), findsOneWidget);
    expect(cards.calls, hasLength(3));
    expect(transactions.calls, hasLength(3));
    expect(cards.calls.last.ownerPath, 'users/owner-b');
    expect(transactions.calls.last.ownerPath, 'users/owner-b');
    expect(find.byKey(teacherPayoutCardLoadingKey), findsOneWidget);
    expect(find.byKey(paymentTransactionLoadingKey), findsOneWidget);

    cards.calls[2].controller.addError(
      FirebaseException(plugin: 'cloud_firestore', message: 'permission'),
    );
    transactions.calls[2].controller.addError(
      const FormatException('decode failed'),
    );
    await tester.pump();
    expect(find.byKey(teacherPayoutCardErrorKey), findsOneWidget);
    expect(find.byKey(paymentTransactionErrorKey), findsOneWidget);
    expect(find.text('Нет сохранённых карт'), findsNothing);
    expect(find.text('Операций пока нет'), findsNothing);
    expect(find.byKey(teacherPayoutCardsRetryButtonKey), findsOneWidget);
    expect(
      find.byKey(paymentTransactionRetryButtonKey('slot-0')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(teacherPayoutCardsRetryButtonKey));
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(paymentTransactionRetryButtonKey('slot-0')),
    );
    await tester.tap(find.byKey(paymentTransactionRetryButtonKey('slot-0')));
    await tester.pump();
    expect(cards.calls, hasLength(4));
    expect(transactions.calls, hasLength(4));
    expect(cards.calls.last.ownerPath, 'users/owner-b');
    expect(transactions.calls.last.ownerPath, 'users/owner-b');

    cards.calls[3].controller.add([
      _card('owner-b', 'card-b', '•••• 3333'),
    ]);
    transactions.calls[3].controller.add([
      _transaction(
        'transaction-b',
        type: TypeTransactions.withdrawal,
        status: StatusTransactions.pending,
      ),
    ]);
    await tester.pump();
    await tester.pump();
    expect(find.text('•••• 3333'), findsOneWidget);
    expect(find.text('Вывод средств'), findsOneWidget);
    expect(find.text('•••• 9999'), findsNothing);
    expect(find.text('Промокод'), findsNothing);

    currentUser = null;
    currentUserDocument = null;
    authUids.add(null);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(payCopyPaymentLoadingKey), findsOneWidget);
    expect(find.text('•••• 3333'), findsNothing);
    expect(find.text('Вывод средств'), findsNothing);
    expect(cards.calls, hasLength(4));
    expect(transactions.calls, hasLength(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'production auth sign-out revokes AddCard before a stale save can write',
      (tester) async {
    final cards = _PaymentStreamQueue<CardsRecord>();
    final transactions = _PaymentStreamQueue<TransactionsRecord>();
    final writes = <String>[];
    addTearDown(cards.close);
    addTearDown(transactions.close);

    currentUser = _TestAuthUser('owner-a');
    currentUserDocument = _approvedTeacher('owner-a');
    _authPlatform.emitUid('owner-a');

    await tester.pumpWidget(
      _testApp(
        PayCopyWidget.withPaymentStreams(
          cardsStreamFactory: cards.load,
          transactionsStreamFactory: transactions.load,
          addCardWriter: (
              {required owner, required number, required pan}) async {
            writes.add(owner.path);
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(payCopyPaymentReadyKey), findsOneWidget);

    await tester.tap(find.text('Добавить карту'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AddCardWidget), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField),
      '1111 2222 3333 4444',
    );
    await tester.pump();
    final staleSave = tester
        .widget<BottomSheetPrimaryButton>(find.byKey(addCardSaveButtonKey))
        .onPressed!;

    currentUser = null;
    currentUserDocument = null;
    _authPlatform.emitUid(null);
    await Future<void>.sync(staleSave);
    expect(writes, isEmpty);

    await tester.pump();
    await tester.pump();
    expect(find.byKey(payCopyPaymentLoadingKey), findsOneWidget);
    expect(find.byType(AddCardWidget), findsNothing);
    expect(find.text('Добавить способ вывода'), findsNothing);
    expect(cards.calls.single.cancelCount, 1);
    expect(transactions.calls.single.cancelCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale withdrawal success is silent after an owner transition',
      (tester) async {
    final cards = _PaymentStreamQueue<CardsRecord>();
    final transactions = _PaymentStreamQueue<TransactionsRecord>();
    final authUids = StreamController<String?>.broadcast(sync: true);
    final request = Completer<void>();
    final requestedCards = <String>[];
    final notifications = <({String message, bool isError})>[];
    addTearDown(cards.close);
    addTearDown(transactions.close);
    addTearDown(authUids.close);

    await _pumpWithdrawalPage(
      tester,
      cards: cards,
      transactions: transactions,
      authUids: authUids,
      withdrawalRequester: (cardId) {
        requestedCards.add(cardId);
        return request.future;
      },
      notificationPresenter: ({
        required context,
        required message,
        required isError,
      }) async {
        notifications.add((message: message, isError: isError));
      },
    );

    await tester.tap(find.text('Вывести'));
    await tester.pump();
    expect(requestedCards, ['card-a']);

    currentUser = _TestAuthUser('owner-b');
    authUids.add('owner-b');
    request.complete();
    await tester.pump();
    await tester.pump();

    expect(notifications, isEmpty);
    expect(find.byKey(payCopyPaymentLoadingKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('current withdrawal lease reports success and callable errors',
      (tester) async {
    final cards = _PaymentStreamQueue<CardsRecord>();
    final transactions = _PaymentStreamQueue<TransactionsRecord>();
    final authUids = StreamController<String?>.broadcast(sync: true);
    final notifications = <({String message, bool isError})>[];
    var requestCount = 0;
    addTearDown(cards.close);
    addTearDown(transactions.close);
    addTearDown(authUids.close);

    await _pumpWithdrawalPage(
      tester,
      cards: cards,
      transactions: transactions,
      authUids: authUids,
      withdrawalRequester: (_) async {
        requestCount += 1;
        if (requestCount == 2) {
          throw _TestFirebaseFunctionsException(
            code: 'unavailable',
            message: 'offline',
          );
        }
      },
      notificationPresenter: ({
        required context,
        required message,
        required isError,
      }) async {
        notifications.add((message: message, isError: isError));
      },
    );

    await tester.tap(find.text('Вывести'));
    await tester.pump();
    await tester.pump();
    expect(notifications, [
      (message: 'Заявка на вывод создана!', isError: false),
    ]);

    await tester.tap(find.text('Вывести'));
    await tester.pump();
    await tester.pump();
    expect(notifications, [
      (message: 'Заявка на вывод создана!', isError: false),
      (message: 'offline', isError: true),
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale withdrawal error is silent after A-B-A auth churn',
      (tester) async {
    final cards = _PaymentStreamQueue<CardsRecord>();
    final transactions = _PaymentStreamQueue<TransactionsRecord>();
    final authUids = StreamController<String?>.broadcast(sync: true);
    final request = Completer<void>();
    final notifications = <({String message, bool isError})>[];
    addTearDown(cards.close);
    addTearDown(transactions.close);
    addTearDown(authUids.close);

    await _pumpWithdrawalPage(
      tester,
      cards: cards,
      transactions: transactions,
      authUids: authUids,
      withdrawalRequester: (_) => request.future,
      notificationPresenter: ({
        required context,
        required message,
        required isError,
      }) async {
        notifications.add((message: message, isError: isError));
      },
    );

    await tester.tap(find.text('Вывести'));
    await tester.pump();
    currentUser = _TestAuthUser('owner-b');
    currentUserDocument = _approvedTeacher('owner-b');
    authUids.add('owner-b');
    currentUser = _TestAuthUser('owner-a');
    currentUserDocument = _approvedTeacher('owner-a');
    authUids.add('owner-a');
    request.completeError(
      _TestFirebaseFunctionsException(
        code: 'unavailable',
        message: 'offline',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(notifications, isEmpty);
    expect(find.byKey(payCopyPaymentReadyKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'disposing PayCopy revokes nested payment sheets without removing foreign routes',
      (tester) async {
    const foreignRouteKey = ValueKey<String>('foreign-route');
    final cards = _PaymentStreamQueue<CardsRecord>();
    final editCards = _PaymentStreamQueue<CardsRecord>();
    final transactions = _PaymentStreamQueue<TransactionsRecord>();
    final authUids = StreamController<String?>.broadcast(sync: true);
    final deletedCards = <String>[];
    addTearDown(cards.close);
    addTearDown(editCards.close);
    addTearDown(transactions.close);
    addTearDown(authUids.close);

    await tester.pumpWidget(
      _testApp(
        PayCopyWidget.withPaymentStreams(
          cardsStreamFactory: cards.load,
          transactionsStreamFactory: transactions.load,
          editCardsStreamFactory: editCards.load,
          deleteCard: (card) async => deletedCards.add(card.reference.path),
          authUidStream: authUids.stream,
        ),
      ),
    );
    currentUser = _TestAuthUser('owner-a');
    currentUserDocument = _approvedTeacher('owner-a');
    authUids.add('owner-a');
    await tester.pump();
    await tester.pump();
    cards.calls.single.controller.add([
      _card('owner-a', 'card-a', '•••• 1111'),
    ]);
    await tester.pump();
    await tester.pump();

    final payCopyContext = tester.element(find.byKey(payCopyPaymentReadyKey));
    final payCopyRoute = ModalRoute.of(payCopyContext)!;
    final navigator = Navigator.of(payCopyContext);
    await tester.tap(find.byKey(teacherPayoutCardsEditSlotKey));
    await tester.pump();
    editCards.calls.single.controller.add([
      _card('owner-a', 'edit-card-a', '•••• 4444'),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.byKey(
        editCardDeleteButtonKey('users/owner-a/cards/edit-card-a'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final staleDelete = tester
        .widget<FFButtonWidget>(find.byKey(deleteCardConfirmButtonKey))
        .onPressed!;

    unawaited(
      navigator.push<void>(
        PageRouteBuilder<void>(
          opaque: false,
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (context, animation, secondaryAnimation) =>
              const Material(
            key: foreignRouteKey,
            color: Colors.transparent,
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(foreignRouteKey), findsOneWidget);

    navigator.removeRoute(payCopyRoute);
    await tester.pump();
    await Future<void>.sync(staleDelete);
    expect(deletedCards, isEmpty);
    await tester.pump();

    expect(find.byKey(foreignRouteKey), findsOneWidget);
    expect(find.byType(EditCardWidget), findsNothing);
    expect(find.byType(DeleteCardWidget), findsNothing);
    expect(find.text('•••• 4444'), findsNothing);
    expect(editCards.calls.single.cancelCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an A-B-A auth transition revokes the old A payment sheet',
      (tester) async {
    final cards = _PaymentStreamQueue<CardsRecord>();
    final transactions = _PaymentStreamQueue<TransactionsRecord>();
    final authUids = StreamController<String?>.broadcast(sync: true);
    final writes = <String>[];
    addTearDown(cards.close);
    addTearDown(transactions.close);
    addTearDown(authUids.close);

    await tester.pumpWidget(
      _testApp(
        PayCopyWidget.withPaymentStreams(
          cardsStreamFactory: cards.load,
          transactionsStreamFactory: transactions.load,
          authUidStream: authUids.stream,
          addCardWriter: (
              {required owner, required number, required pan}) async {
            writes.add(owner.path);
          },
        ),
      ),
    );
    currentUser = _TestAuthUser('owner-a');
    currentUserDocument = _approvedTeacher('owner-a');
    authUids.add('owner-a');
    await tester.pump();
    await tester.pump();
    expect(find.byKey(payCopyPaymentReadyKey), findsOneWidget);

    await tester.tap(find.text('Добавить карту'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
      find.byType(TextFormField),
      '5555 6666 7777 8888',
    );
    await tester.pump();
    final staleSave = tester
        .widget<BottomSheetPrimaryButton>(find.byKey(addCardSaveButtonKey))
        .onPressed!;

    currentUser = _TestAuthUser('owner-b');
    currentUserDocument = _approvedTeacher('owner-b');
    authUids.add('owner-b');
    currentUser = _TestAuthUser('owner-a');
    currentUserDocument = _approvedTeacher('owner-a');
    authUids.add('owner-a');
    await Future<void>.sync(staleSave);
    expect(writes, isEmpty);

    await tester.pump();
    await tester.pump();
    expect(find.byType(AddCardWidget), findsNothing);
    expect(find.byKey(payCopyPaymentReadyKey), findsOneWidget);
    expect(cards.calls, hasLength(2));
    expect(transactions.calls, hasLength(2));
    expect(cards.calls.first.cancelCount, 1);
    expect(transactions.calls.first.cancelCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AddCard and DeleteCard recheck owner at mutation time',
      (tester) async {
    final owner = UsersRecord.collection.doc('owner-a');
    var ownerIsCurrent = true;
    final writes = <String>[];

    await tester.pumpWidget(
      _testApp(
        Scaffold(
          body: AddCardWidget(
            owner: owner,
            ownerIsCurrent: () => ownerIsCurrent,
            cardWriter: (
                {required owner, required number, required pan}) async {
              writes.add(owner.path);
            },
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField),
      '1234 5678 9012 3456',
    );
    await tester.pump();
    final save = tester
        .widget<BottomSheetPrimaryButton>(find.byKey(addCardSaveButtonKey))
        .onPressed!;
    ownerIsCurrent = false;
    await Future<void>.sync(save);
    expect(writes, isEmpty);

    ownerIsCurrent = true;
    final card = _card('owner-a', 'card-a', '•••• 3456');
    final deletes = <String>[];
    await tester.pumpWidget(
      _testApp(
        Scaffold(
          body: DeleteCardWidget(
            doc: card,
            owner: owner,
            ownerIsCurrent: () => ownerIsCurrent,
            deleteCard: (card) async => deletes.add(card.reference.path),
          ),
        ),
      ),
    );
    final delete = tester
        .widget<FFButtonWidget>(find.byKey(deleteCardConfirmButtonKey))
        .onPressed!;
    ownerIsCurrent = false;
    await Future<void>.sync(delete);
    expect(deletes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DeleteCard blocks repeated deletion while one is pending',
      (tester) async {
    final owner = UsersRecord.collection.doc('owner-a');
    final card = _card('owner-a', 'card-a', '•••• 3456');
    final pendingDelete = Completer<void>();
    var deleteCalls = 0;
    var ownerIsCurrent = true;

    await tester.pumpWidget(
      _testApp(
        Scaffold(
          body: DeleteCardWidget(
            doc: card,
            owner: owner,
            ownerIsCurrent: () => ownerIsCurrent,
            deleteCard: (_) {
              deleteCalls += 1;
              return pendingDelete.future;
            },
          ),
        ),
      ),
    );
    final firstDelete = tester
        .widget<FFButtonWidget>(find.byKey(deleteCardConfirmButtonKey))
        .onPressed!;
    final firstResult = Future<void>.sync(firstDelete);
    await tester.pump();
    expect(deleteCalls, 1);
    expect(
      tester
          .widget<FFButtonWidget>(find.byKey(deleteCardConfirmButtonKey))
          .onPressed,
      isNull,
    );

    await Future<void>.sync(firstDelete);
    expect(deleteCalls, 1);
    ownerIsCurrent = false;
    pendingDelete.complete();
    await firstResult;
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpWithdrawalPage(
  WidgetTester tester, {
  required _PaymentStreamQueue<CardsRecord> cards,
  required _PaymentStreamQueue<TransactionsRecord> transactions,
  required StreamController<String?> authUids,
  required PayCopyWithdrawalRequester withdrawalRequester,
  required PayCopyNotificationPresenter notificationPresenter,
}) async {
  await tester.pumpWidget(
    _testApp(
      PayCopyWidget.withPaymentStreams(
        cardsStreamFactory: cards.load,
        transactionsStreamFactory: transactions.load,
        authUidStream: authUids.stream,
        withdrawalRequester: withdrawalRequester,
        notificationPresenter: notificationPresenter,
      ),
    ),
  );
  currentUser = _TestAuthUser('owner-a');
  currentUserDocument = _approvedTeacher('owner-a');
  authUids.add('owner-a');
  await tester.pump();
  await tester.pump();
  cards.calls.single.controller.add([
    _card('owner-a', 'card-a', '•••• 1111'),
  ]);
  await tester.pump();
  await tester.pump();
  expect(find.byKey(payCopyPaymentReadyKey), findsOneWidget);
}

Widget _testApp(Widget home) {
  return MaterialApp(
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru'), Locale('en')],
    localizationsDelegates: const [
      FFLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      FallbackMaterialLocalizationDelegate(),
      FallbackCupertinoLocalizationDelegate(),
    ],
    home: home,
  );
}

UsersRecord _approvedTeacher(String uid) {
  return UsersRecord.getDocumentFromData(
    <String, dynamic>{
      'uid': uid,
      'role': UserRole.native_speaker,
      'teacherAccreditationStatus': TeacherAccreditationStatus.approved,
      'verif_NS': true,
      'balance_NS': 2500.0,
    },
    UsersRecord.collection.doc(uid),
  );
}

CardsRecord _card(String ownerId, String cardId, String pan) {
  final owner = UsersRecord.collection.doc(ownerId);
  return CardsRecord.getDocumentFromData(
    <String, dynamic>{'pan': pan},
    CardsRecord.createDoc(owner, id: cardId),
  );
}

TransactionsRecord _transaction(
  String id, {
  required TypeTransactions type,
  required StatusTransactions status,
}) {
  return TransactionsRecord.getDocumentFromData(
    <String, dynamic>{
      'createdAt': DateTime(2026, 7, 14, 12),
      'type': type,
      'status': status,
      'amount_ST': 100.0,
      'amount': 1299.0,
      'promoCode': 'LATE-A',
    },
    TransactionsRecord.collection.doc(id),
  );
}
