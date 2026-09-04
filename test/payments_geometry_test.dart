import 'dart:async';

import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/backend/schema/enums/enums.dart';
import 'package:small_talk/components/payment_transaction_row.dart';
import 'package:small_talk/components/student_pay_bottom_bar.dart';
import 'package:small_talk/components/student_pay_catalog_error.dart';
import 'package:small_talk/components/student_pay_plan.dart';
import 'package:small_talk/components/student_pay_plan_card.dart';
import 'package:small_talk/components/teacher_payment_transactions_stream_rows.dart';
import 'package:small_talk/components/teacher_payout_cards_section.dart';
import 'package:small_talk/components/trans/trans_widget.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/services/subscription_service.dart';
import 'package:small_talk/students_pages/pay/pay_widget.dart';

const _monthlyPlan = StudentPayPlan(
  kind: StudentPayPlanKind.monthly,
  productId: 'monthly',
  title: 'Basic',
  subtitle: 'Для старта изучения языка',
  periodLabel: 'мес',
  icon: Icons.wallet_outlined,
  features: [
    'До 10 звонков в месяц',
    'Базовый словарь',
    'Субтитры в звонках',
  ],
);

const _quarterlyPlan = StudentPayPlan(
  kind: StudentPayPlanKind.quarterly,
  productId: 'quarterly',
  title: 'Pro',
  subtitle: 'Полный доступ ко всем возможностям',
  periodLabel: '3 мес',
  icon: Icons.auto_awesome_rounded,
  badge: 'ПОПУЛЯРНЫЙ',
  features: [
    'Безлимитные звонки',
    'Расширенный словарь и флэшкарты',
    'Перевод в реальном времени',
    'Приоритетная поддержка',
  ],
);

const _testPlans = [_monthlyPlan, _quarterlyPlan];
const _textScaler = TextScaler.linear(1.3);

typedef _PlanGeometry = ({
  Rect card,
  Rect price,
  Rect selection,
});

typedef _BottomBarGeometry = ({
  Rect bar,
  Rect cta,
  Rect content,
});

typedef _CardSectionGeometry = ({
  Rect section,
  Rect header,
  Rect edit,
  Rect rows,
  Rect row,
  Rect leading,
  Rect text,
  Rect action,
});

typedef _TransactionGeometry = ({
  Rect row,
  Rect leading,
  Rect primary,
  Rect meta,
});

typedef _PayPageGeometry = ({
  Rect monthlyCard,
  Rect monthlyPrice,
  Rect quarterlyCard,
  Rect quarterlyPrice,
  Rect restoreButton,
  Rect bottomBar,
  Rect purchaseCta,
  Rect purchaseContent,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    SharedPreferences.setMockInitialValues({});
    await initializeDateFormatting('ru');
    await FFLocalizations.initialize();
  });

  for (final plan in _testPlans) {
    testWidgets(
      '${plan.kind.name} plan keeps price and selection slots through loading/error/price',
      (tester) async {
        _configureView(tester);

        Future<_PlanGeometry> pumpPlan({
          required String price,
          required bool priceAvailable,
          required bool selected,
        }) async {
          await tester.pumpWidget(
            _componentApp(
              StudentPayPlanCard(
                plan: plan,
                selected: selected,
                price: price,
                priceAvailable: priceAvailable,
                onTap: () {},
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 200));
          return (
            card: tester.getRect(find.byKey(studentPayPlanCardKey(plan.kind))),
            price: tester
                .getRect(find.byKey(studentPayPlanPriceSlotKey(plan.kind))),
            selection: tester.getRect(
              find.byKey(studentPayPlanSelectionSlotKey(plan.kind)),
            ),
          );
        }

        final loading = await pumpPlan(
          price: 'Загрузка...',
          priceAvailable: false,
          selected: false,
        );
        expect(find.text('Загрузка...'), findsOneWidget);

        final error = await pumpPlan(
          price: 'Недоступно',
          priceAvailable: false,
          selected: false,
        );
        expect(find.text('Недоступно'), findsOneWidget);

        final loaded = await pumpPlan(
          price: '1 299 ₽',
          priceAvailable: true,
          selected: false,
        );
        expect(
          find.textContaining('1 299 ₽', findRichText: true),
          findsOneWidget,
        );

        final selected = await pumpPlan(
          price: '1 299 ₽',
          priceAvailable: true,
          selected: true,
        );

        expect(error, loading);
        expect(loaded, loading);
        expect(selected, loading);
        expect(
          loading.price.height,
          closeTo(_textScaler.scale(28.0), 0.001),
        );
        expect(loading.selection.size, const Size.square(28.0));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('new user sees trial month and immediate quarterly purchase',
      (tester) async {
    _configureView(tester);
    String? purchasedProductId;

    await tester.pumpWidget(
      _localizedApp(
        home: PayWidget.withPaymentGateway(
          catalogLoader: () async => const {
            SubscriptionProductIds.trialMonthly: '999 ₽',
            SubscriptionProductIds.quarterly: '1 999 ₽',
          },
          trialOfferEligible: true,
          purchaseHandler: (productId) async {
            purchasedProductId = productId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        studentPayPlanCardKey(StudentPayPlanKind.trialMonthly),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(studentPayPlanCardKey(StudentPayPlanKind.monthly)),
      findsNothing,
    );
    expect(
      find.byKey(studentPayPlanCardKey(StudentPayPlanKind.quarterly)),
      findsOneWidget,
    );
    expect(find.text('Попробовать 3 дня бесплатно'), findsOneWidget);

    final quarterlyCard =
        find.byKey(studentPayPlanCardKey(StudentPayPlanKind.quarterly));
    await tester.ensureVisible(quarterlyCard);
    await tester.tap(quarterlyCard);
    await tester.pumpAndSettle();
    expect(find.textContaining('Оформить 3 месяца'), findsOneWidget);

    await tester.tap(find.byKey(studentPayPurchaseCtaKey));
    await tester.pump();
    expect(purchasedProductId, SubscriptionProductIds.quarterly);
    expect(tester.takeException(), isNull);
  });

  testWidgets('premium-only flow hides trial and defaults to 3 months',
      (tester) async {
    _configureView(tester);

    await tester.pumpWidget(
      _localizedApp(
        home: PayWidget.withPaymentGateway(
          catalogLoader: () async => const {
            SubscriptionProductIds.trialMonthly: '999 ₽',
            SubscriptionProductIds.monthly: '999 ₽',
            SubscriptionProductIds.quarterly: '1 999 ₽',
          },
          trialOfferEligible: true,
          premiumOnly: true,
          purchaseHandler: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(studentPayPlanCardKey(StudentPayPlanKind.trialMonthly)),
      findsNothing,
    );
    expect(
      find.byKey(studentPayPlanCardKey(StudentPayPlanKind.monthly)),
      findsOneWidget,
    );
    expect(
      find.byKey(studentPayPlanCardKey(StudentPayPlanKind.quarterly)),
      findsOneWidget,
    );
    expect(find.textContaining('Оформить 3 месяца'), findsOneWidget);
  });

  testWidgets('restore and purchase actions disable each other',
      (tester) async {
    _configureView(tester);
    final restoreCompleter = Completer<bool>();
    final purchaseCompleter = Completer<void>();
    var purchaseCalls = 0;

    await tester.pumpWidget(
      _localizedApp(
        home: PayWidget.withPaymentGateway(
          catalogLoader: () async => const {
            SubscriptionProductIds.monthly: '499 ₽',
            SubscriptionProductIds.quarterly: '1 299 ₽',
          },
          purchaseHandler: (_) {
            purchaseCalls += 1;
            return purchaseCompleter.future;
          },
          restoreHandler: () => restoreCompleter.future,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final restoreButton = find.text('Восстановить покупки');
    await tester.ensureVisible(restoreButton);
    await tester.tap(restoreButton);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    await tester.tap(find.byKey(studentPayPurchaseCtaKey));
    await tester.pump();
    expect(purchaseCalls, 0);

    restoreCompleter.complete(false);
    await tester.pumpAndSettle();
    expect(find.text('Восстановить покупки'), findsOneWidget);
    expect(find.textContaining('не найдено'), findsOneWidget);

    await tester.tap(find.byKey(studentPayPurchaseCtaKey));
    await tester.pump();
    expect(purchaseCalls, 1);
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNull,
    );

    purchaseCompleter.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected plan exposes selected semantics', (tester) async {
    _configureView(tester);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _componentApp(
        StudentPayPlanCard(
          plan: _monthlyPlan,
          selected: true,
          price: '499 ₽',
          priceAvailable: true,
          onTap: () {},
        ),
      ),
    );

    final semanticsFinder = find.bySemanticsLabel(
      RegExp(r'Basic, 499 ₽'),
    );
    expect(semanticsFinder, findsOneWidget);
    final node = tester.getSemantics(semanticsFinder);
    expect(node.flagsCollection.isSelected, isTrue);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    semantics.dispose();
  });

  testWidgets(
      'pay page wires package error/retry/tariff/purchase without geometry shifts',
      (tester) async {
    _configureView(tester);
    final catalog = _ControllableCatalogLoader();
    final purchaseCompleter = Completer<void>();
    String? purchasedProductId;

    await tester.pumpWidget(
      _localizedApp(
        home: PayWidget.withPaymentGateway(
          catalogLoader: catalog.load,
          purchaseHandler: (productId) {
            purchasedProductId = productId;
            return purchaseCompleter.future;
          },
        ),
      ),
    );
    await tester.pump();
    expect(catalog.requests, hasLength(1));
    final loading = _payPageGeometry(tester);
    expect(find.text('Загрузка...'), findsNWidgets(2));

    catalog.requests[0].completeError(StateError('catalog unavailable'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(studentPayCatalogErrorKey), findsOneWidget);
    expect(find.text('Недоступно'), findsNothing);
    expect(
      find.text(
          'App Store не вернул цены. Проверьте продукты для этого приложения.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(studentPayPurchaseCtaKey));
    await tester.pump();
    expect(catalog.requests, hasLength(2));
    final retryLoading = _payPageGeometry(tester);
    expect(retryLoading, loading);

    catalog.requests[1].complete({
      SubscriptionProductIds.monthly: '499 ₽',
      SubscriptionProductIds.quarterly: '1 299 ₽',
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final loaded = _payPageGeometry(tester);
    expect(
      find.descendant(
        of: find.byKey(
          studentPayPlanPriceSlotKey(StudentPayPlanKind.monthly),
        ),
        matching: find.textContaining('499 ₽', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(
          studentPayPlanPriceSlotKey(StudentPayPlanKind.quarterly),
        ),
        matching: find.textContaining('1 299 ₽', findRichText: true),
      ),
      findsOneWidget,
    );
    expect(loaded, loading);

    final monthlyCard =
        find.byKey(studentPayPlanCardKey(StudentPayPlanKind.monthly));
    await tester.ensureVisible(monthlyCard);
    await tester.pumpAndSettle();
    await tester.tap(monthlyCard);
    await tester.pump(const Duration(milliseconds: 200));
    final selectedMonthly = _payPageGeometry(tester);
    expect(find.textContaining('Оформить месяц'), findsOneWidget);
    _expectPayPageSizesEqual(selectedMonthly, loading);

    await tester.tap(find.byKey(studentPayPurchaseCtaKey));
    await tester.pump();
    final purchasing = _payPageGeometry(tester);
    expect(purchasedProductId, SubscriptionProductIds.monthly);
    expect(
      find.descendant(
        of: find.byKey(studentPayPurchaseContentSlotKey),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    _expectPayPageSizesEqual(purchasing, loading);
    expect(tester.takeException(), isNull);

    purchaseCompleter.complete();
    await tester.pump();
  });

  testWidgets('purchase bar keeps CTA slots through loading/error/purchase',
      (tester) async {
    _configureView(tester);

    Future<_BottomBarGeometry> pumpBar({
      required String price,
      required bool canPurchase,
      required bool isBusy,
      required bool isLoading,
    }) async {
      await tester.pumpWidget(
        _bottomBarApp(
          StudentPayBottomBar(
            plan: _quarterlyPlan,
            price: price,
            canPurchase: canPurchase,
            isBusy: isBusy,
            isLoading: isLoading,
            onPressed: () {},
            termsText: 'Отмена в любой момент',
            retryLabel: 'Повторить загрузку',
          ),
        ),
      );
      await tester.pump();
      return (
        bar: tester.getRect(find.byKey(studentPayBottomBarKey)),
        cta: tester.getRect(find.byKey(studentPayPurchaseCtaKey)),
        content: tester.getRect(find.byKey(studentPayPurchaseContentSlotKey)),
      );
    }

    final loading = await pumpBar(
      price: 'Загрузка...',
      canPurchase: false,
      isBusy: false,
      isLoading: true,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final error = await pumpBar(
      price: 'Недоступно',
      canPurchase: false,
      isBusy: false,
      isLoading: false,
    );
    expect(find.text('Повторить загрузку'), findsOneWidget);

    final loaded = await pumpBar(
      price: '1 299 ₽',
      canPurchase: true,
      isBusy: false,
      isLoading: false,
    );
    expect(find.textContaining('Выбрать Pro'), findsOneWidget);

    final purchasing = await pumpBar(
      price: '1 299 ₽',
      canPurchase: true,
      isBusy: true,
      isLoading: false,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    expect(error, loading);
    expect(loaded, loading);
    expect(purchasing, loading);
    expect(loading.bar.height, 136.0);
    expect(loading.cta.height, 52.0);
    expect(loading.content.height, 52.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('purchase terms are not truncated', (tester) async {
    _configureView(tester);
    const terms =
        '3 дня бесплатно, затем 999 ₽ в месяц. Автопродление, отмена в любой момент.';

    await tester.pumpWidget(
      _bottomBarApp(
        StudentPayBottomBar(
          plan: _monthlyPlan,
          price: '999 ₽',
          canPurchase: true,
          isBusy: false,
          isLoading: false,
          onPressed: () {},
          termsText: terms,
          retryLabel: 'Повторить загрузку',
        ),
      ),
    );

    final termsWidget = tester.widget<Text>(find.text(terms));
    expect(termsWidget.maxLines, isNull);
    expect(termsWidget.overflow, isNull);
  });

  testWidgets('payout card section keeps row slots across async states',
      (tester) async {
    _configureView(tester);

    Future<_CardSectionGeometry> pumpCards({
      required TeacherPayoutCardsState state,
      bool selected = false,
    }) async {
      await tester.pumpWidget(
        _componentApp(
          TeacherPayoutCardsSection(
            state: state,
            items: state == TeacherPayoutCardsState.loaded
                ? [
                    TeacherPayoutCardItem(
                      pan: '•••• 4242',
                      selected: selected,
                      onTap: () {},
                    ),
                  ]
                : const [],
            onEditPressed:
                state == TeacherPayoutCardsState.loaded ? () {} : null,
          ),
        ),
      );
      await tester.pump();
      return (
        section: tester.getRect(find.byKey(teacherPayoutCardsSectionKey)),
        header: tester.getRect(find.byKey(teacherPayoutCardsHeaderKey)),
        edit: tester.getRect(find.byKey(teacherPayoutCardsEditSlotKey)),
        rows: tester.getRect(find.byKey(teacherPayoutCardsRowsSlotKey)),
        row: tester.getRect(find.byKey(teacherPayoutCardRowKey(0))),
        leading: tester.getRect(find.byKey(teacherPayoutCardLeadingSlotKey(0))),
        text: tester.getRect(find.byKey(teacherPayoutCardTextSlotKey(0))),
        action: tester.getRect(find.byKey(teacherPayoutCardActionSlotKey(0))),
      );
    }

    final loading = await pumpCards(state: TeacherPayoutCardsState.loading);
    expect(find.byKey(teacherPayoutCardLoadingKey), findsOneWidget);

    final error = await pumpCards(state: TeacherPayoutCardsState.error);
    expect(find.byKey(teacherPayoutCardErrorKey), findsOneWidget);

    final loaded = await pumpCards(state: TeacherPayoutCardsState.loaded);
    expect(find.text('•••• 4242'), findsOneWidget);
    expect(find.byKey(teacherPayoutCardSelectedIndicatorKey(0)), findsNothing);

    final selected = await pumpCards(
      state: TeacherPayoutCardsState.loaded,
      selected: true,
    );
    expect(
      find.byKey(teacherPayoutCardSelectedIndicatorKey(0)),
      findsOneWidget,
    );

    expect(error, loading);
    expect(loaded, loading);
    expect(selected, loading);
    expect(loading.header.height, 48.0);
    expect(loading.edit.size, const Size.square(48.0));
    expect(loading.row.height, teacherPayoutCardRowHeight);
    expect(loading.leading.size, const Size.square(52.0));
    expect(loading.action.size, const Size.square(30.0));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'payout stream retains same-owner cards and clears them on owner switch',
      (tester) async {
    _configureView(tester);
    var ownerACancelCount = 0;
    final ownerA = StreamController<List<CardsRecord>>.broadcast(
      sync: true,
      onCancel: () => ownerACancelCount += 1,
    );
    final ownerARetry =
        StreamController<List<CardsRecord>>.broadcast(sync: true);
    final ownerB = StreamController<List<CardsRecord>>.broadcast(sync: true);
    addTearDown(ownerA.close);
    addTearDown(ownerARetry.close);
    addTearDown(ownerB.close);
    final cardA = _card('owner-a', 'card-a', '•••• 1111');
    final recoveredCardA = _card('owner-a', 'card-a-recovered', '•••• 2222');
    List<CardsRecord> visibleCards = const [];
    DocumentReference? tappedCard;
    var retryCount = 0;

    Future<void> pumpOwner({
      required String ownerKey,
      required Stream<List<CardsRecord>> stream,
    }) {
      return tester.pumpWidget(
        _componentApp(
          TeacherPayoutCardsStreamSection(
            ownerKey: ownerKey,
            stream: stream,
            selectedCard: null,
            shouldAutoSelectFirstCard: true,
            onCardsChanged: (cards) => visibleCards = cards,
            onCardTap: (card) => tappedCard = card,
            onEditPressed: () {},
            onRetry: () => retryCount += 1,
          ),
        ),
      );
    }

    await pumpOwner(ownerKey: 'owner-a', stream: ownerA.stream);
    final loadingA = _cardSectionGeometry(tester);
    expect(find.byKey(teacherPayoutCardLoadingKey), findsOneWidget);

    ownerA.add([cardA]);
    await tester.pump();
    final loadedA = _cardSectionGeometry(tester);
    expect(find.text('•••• 1111'), findsOneWidget);
    expect(visibleCards, [cardA]);
    expect(loadedA, loadingA);

    ownerA.addError(StateError('refresh failed'));
    await tester.pump();
    final retainedAfterError = _cardSectionGeometry(tester);
    expect(find.text('•••• 1111'), findsOneWidget);
    expect(find.byKey(teacherPayoutCardsRetryButtonKey), findsOneWidget);
    expect(retainedAfterError, loadingA);

    final semanticsHandle = tester.ensureSemantics();
    final retrySemantics =
        tester.getSemantics(find.byKey(teacherPayoutCardsRetryButtonKey));
    expect(
      tester.getRect(find.byKey(teacherPayoutCardsRetryButtonKey)).size,
      const Size.square(48.0),
    );
    expect(retrySemantics.label, 'Повторить загрузку карт');
    expect(
      retrySemantics.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    semanticsHandle.dispose();

    await tester.tap(find.byKey(teacherPayoutCardsRetryButtonKey));
    expect(retryCount, 1);

    await tester.tap(find.byKey(teacherPayoutCardRowKey(0)));
    expect(tappedCard?.path, cardA.reference.path);

    await pumpOwner(ownerKey: 'owner-a', stream: ownerARetry.stream);
    await tester.pump();
    final refreshingA = _cardSectionGeometry(tester);
    expect(ownerACancelCount, 1);
    expect(find.text('•••• 1111'), findsOneWidget);
    expect(find.byKey(teacherPayoutCardsRefreshingKey), findsOneWidget);
    expect(refreshingA, loadingA);

    ownerA.add([
      _card('owner-a', 'late-card-a', '•••• 9999'),
    ]);
    ownerA.addError(StateError('late replaced card stream'));
    await tester.pump();
    expect(find.text('•••• 9999'), findsNothing);
    expect(find.text('•••• 1111'), findsOneWidget);

    ownerARetry.add([recoveredCardA]);
    await tester.pump();
    final recoveredA = _cardSectionGeometry(tester);
    expect(find.text('•••• 2222'), findsOneWidget);
    expect(find.byKey(teacherPayoutCardsRefreshingKey), findsNothing);
    expect(recoveredA, loadingA);

    await pumpOwner(ownerKey: 'owner-b', stream: ownerB.stream);
    final loadingB = _cardSectionGeometry(tester);
    expect(find.text('•••• 1111'), findsNothing);
    expect(find.text('•••• 2222'), findsNothing);
    expect(find.byKey(teacherPayoutCardLoadingKey), findsOneWidget);
    expect(visibleCards, isEmpty);
    expect(loadingB, loadingA);

    ownerB.addError(StateError('cold error'));
    await tester.pump();
    final errorB = _cardSectionGeometry(tester);
    expect(find.byKey(teacherPayoutCardErrorKey), findsOneWidget);
    expect(find.byKey(teacherPayoutCardsRetryButtonKey), findsOneWidget);
    expect(errorB, loadingA);

    ownerB.add(const []);
    await tester.pump();
    final emptyB = _cardSectionGeometry(tester);
    expect(find.text('Нет сохранённых карт'), findsOneWidget);
    expect(emptyB, loadingA);

    ownerB.addError(StateError('refresh after confirmed empty'));
    await tester.pump();
    await tester.pump();
    final retainedEmptyError = _cardSectionGeometry(tester);
    expect(find.text('Нет сохранённых карт'), findsOneWidget);
    expect(
      tester
          .widget<TeacherPayoutCardsSection>(
            find.byType(TeacherPayoutCardsSection),
          )
          .refreshState,
      TeacherPayoutCardsRefreshState.error,
    );
    expect(find.byKey(teacherPayoutCardsRetryButtonKey), findsOneWidget);
    expect(retainedEmptyError, emptyB);
    expect(tester.takeException(), isNull);
  });

  testWidgets('transaction row slots survive loading/error/status changes',
      (tester) async {
    _configureView(tester);
    const layoutId = 'slot-0';

    Future<_TransactionGeometry> pumpTransaction(Widget row) async {
      await tester.pumpWidget(_componentApp(row));
      await tester.pump();
      return (
        row: tester.getRect(find.byKey(paymentTransactionRowKey(layoutId))),
        leading: tester
            .getRect(find.byKey(paymentTransactionLeadingSlotKey(layoutId))),
        primary: tester
            .getRect(find.byKey(paymentTransactionPrimarySlotKey(layoutId))),
        meta:
            tester.getRect(find.byKey(paymentTransactionMetaSlotKey(layoutId))),
      );
    }

    final loading = await pumpTransaction(
      const PaymentTransactionAsyncRow(
        layoutId: layoutId,
        hasError: false,
      ),
    );
    expect(find.byKey(paymentTransactionLoadingKey), findsOneWidget);

    final error = await pumpTransaction(
      const PaymentTransactionAsyncRow(
        layoutId: layoutId,
        hasError: true,
      ),
    );
    expect(find.byKey(paymentTransactionErrorKey), findsOneWidget);

    final pending = await pumpTransaction(
      TransWidget(
        trans: _transaction(StatusTransactions.pending),
        layoutId: layoutId,
      ),
    );
    expect(find.text('Ожидаем оплату'), findsOneWidget);

    final completed = await pumpTransaction(
      TransWidget(
        trans: _transaction(StatusTransactions.completed),
        layoutId: layoutId,
      ),
    );
    expect(find.textContaining('Оплачено:'), findsOneWidget);

    final failed = await pumpTransaction(
      TransWidget(
        trans: _transaction(StatusTransactions.failed),
        layoutId: layoutId,
      ),
    );
    expect(find.text('Платеж не прошел'), findsOneWidget);

    expect(error, loading);
    expect(pending, loading);
    expect(completed, loading);
    expect(failed, loading);
    expect(loading.row.height, paymentTransactionRowHeight);
    expect(loading.leading.size, const Size.square(52.0));
    expect(loading.meta.width, paymentTransactionMetaSlotWidth);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'transaction stream retains same-owner rows and clears them on owner switch',
      (tester) async {
    _configureView(tester);
    var ownerACancelCount = 0;
    final ownerA = StreamController<List<TransactionsRecord>>.broadcast(
      sync: true,
      onCancel: () => ownerACancelCount += 1,
    );
    final ownerARetry =
        StreamController<List<TransactionsRecord>>.broadcast(sync: true);
    final ownerB =
        StreamController<List<TransactionsRecord>>.broadcast(sync: true);
    addTearDown(ownerA.close);
    addTearDown(ownerARetry.close);
    addTearDown(ownerB.close);
    final transactionA = _transaction(
      StatusTransactions.pending,
      documentId: 'owner-a-transaction',
    );
    final recoveredTransactionA = _transaction(
      StatusTransactions.completed,
      documentId: 'owner-a-transaction-recovered',
    );
    var retryCount = 0;

    Future<void> pumpOwner({
      required String ownerKey,
      required Stream<List<TransactionsRecord>> stream,
    }) {
      return tester.pumpWidget(
        _componentApp(
          TeacherPaymentTransactionsStreamRows(
            ownerKey: ownerKey,
            stream: stream,
            filterIndex: 0,
            onRetry: () => retryCount += 1,
          ),
        ),
      );
    }

    await pumpOwner(ownerKey: 'owner-a', stream: ownerA.stream);
    final loadingA = _transactionGeometry(tester);
    expect(find.byKey(paymentTransactionLoadingKey), findsOneWidget);

    ownerA.add([transactionA]);
    await tester.pump();
    final loadedA = _transactionGeometry(tester);
    expect(find.text('Ожидаем оплату'), findsOneWidget);
    expect(loadedA, loadingA);

    ownerA.addError(StateError('refresh failed'));
    await tester.pump();
    final retainedAfterError = _transactionGeometry(tester);
    expect(find.text('Ожидаем оплату'), findsOneWidget);
    expect(
      find.byKey(paymentTransactionRetryButtonKey('slot-0')),
      findsOneWidget,
    );
    expect(retainedAfterError, loadingA);

    final semanticsHandle = tester.ensureSemantics();
    final retryFinder = find.byKey(paymentTransactionRetryButtonKey('slot-0'));
    final retrySemantics = tester.getSemantics(retryFinder);
    expect(tester.getRect(retryFinder).size, const Size.square(52.0));
    expect(retrySemantics.label, 'Повторить загрузку операций');
    expect(
      retrySemantics.getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    semanticsHandle.dispose();

    await tester.tap(retryFinder);
    expect(retryCount, 1);

    await pumpOwner(ownerKey: 'owner-a', stream: ownerARetry.stream);
    await tester.pump();
    final refreshingA = _transactionGeometry(tester);
    expect(ownerACancelCount, 1);
    expect(find.text('Ожидаем оплату'), findsOneWidget);
    expect(
      find.byKey(paymentTransactionRefreshingKey('slot-0')),
      findsOneWidget,
    );
    expect(refreshingA, loadingA);

    ownerA.add([
      _transaction(
        StatusTransactions.failed,
        documentId: 'late-replaced-transaction',
      ),
    ]);
    ownerA.addError(StateError('late replaced transaction stream'));
    await tester.pump();
    expect(find.text('Платеж не прошел'), findsNothing);
    expect(find.text('Ожидаем оплату'), findsOneWidget);

    ownerARetry.add([recoveredTransactionA]);
    await tester.pump();
    final recoveredA = _transactionGeometry(tester);
    expect(find.textContaining('Оплачено:'), findsOneWidget);
    expect(
      find.byKey(paymentTransactionRefreshingKey('slot-0')),
      findsNothing,
    );
    expect(recoveredA, loadingA);

    await pumpOwner(ownerKey: 'owner-b', stream: ownerB.stream);
    final loadingB = _transactionGeometry(tester);
    expect(find.text('Ожидаем оплату'), findsNothing);
    expect(find.textContaining('Оплачено:'), findsNothing);
    expect(find.byKey(paymentTransactionLoadingKey), findsOneWidget);
    expect(loadingB, loadingA);

    ownerB.addError(StateError('cold error'));
    await tester.pump();
    final errorB = _transactionGeometry(tester);
    expect(find.byKey(paymentTransactionErrorKey), findsOneWidget);
    expect(
      find.byKey(paymentTransactionRetryButtonKey('slot-0')),
      findsOneWidget,
    );
    expect(errorB, loadingA);

    ownerB.add(const []);
    await tester.pump();
    final emptyB = _transactionGeometry(tester);
    expect(find.byKey(paymentTransactionEmptyKey), findsOneWidget);
    expect(find.text('Операций пока нет'), findsOneWidget);
    expect(emptyB, loadingA);

    ownerB.addError(StateError('refresh after confirmed empty'));
    await tester.pump();
    await tester.pump();
    final retainedEmptyError = _transactionGeometry(tester);
    expect(find.text('Операций пока нет'), findsOneWidget);
    expect(
      tester
          .widget<PaymentTransactionEmptyRow>(
            find.byType(PaymentTransactionEmptyRow),
          )
          .refreshState,
      PaymentTransactionRefreshState.error,
    );
    expect(
      find.byKey(paymentTransactionRetryButtonKey('slot-0')),
      findsOneWidget,
    );
    expect(retainedEmptyError, emptyB);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact English large text keeps every payment slot stable',
      (tester) async {
    _configureView(
      tester,
      logicalSize: const Size(320.0, 844.0),
      devicePixelRatio: 3.0,
    );
    const scaler = TextScaler.linear(2.0);

    Future<_PlanGeometry> pumpPlan({
      required bool available,
      required bool selected,
    }) async {
      await tester.pumpWidget(
        _componentApp(
          StudentPayPlanCard(
            plan: _quarterlyPlan,
            selected: selected,
            price: available ? r'$12.99' : 'Unavailable',
            priceAvailable: available,
            onTap: () {},
          ),
          locale: const Locale('en'),
          textScaler: scaler,
          contentWidth: 272.0,
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      return (
        card: tester.getRect(
          find.byKey(studentPayPlanCardKey(StudentPayPlanKind.quarterly)),
        ),
        price: tester.getRect(
          find.byKey(
            studentPayPlanPriceSlotKey(StudentPayPlanKind.quarterly),
          ),
        ),
        selection: tester.getRect(
          find.byKey(
            studentPayPlanSelectionSlotKey(StudentPayPlanKind.quarterly),
          ),
        ),
      );
    }

    final unavailablePlan = await pumpPlan(
      available: false,
      selected: false,
    );
    final availablePlan = await pumpPlan(available: true, selected: true);
    expect(availablePlan, unavailablePlan);

    Future<_BottomBarGeometry> pumpBar({
      required bool loading,
      required bool available,
    }) async {
      await tester.pumpWidget(
        _bottomBarApp(
          StudentPayBottomBar(
            plan: _quarterlyPlan,
            price: available ? r'$12.99' : 'Unavailable',
            canPurchase: available,
            isBusy: false,
            isLoading: loading,
            onPressed: () {},
            termsText: 'Cancel anytime',
            retryLabel: 'Try again',
          ),
          locale: const Locale('en'),
          textScaler: scaler,
        ),
      );
      await tester.pump();
      return (
        bar: tester.getRect(find.byKey(studentPayBottomBarKey)),
        cta: tester.getRect(find.byKey(studentPayPurchaseCtaKey)),
        content: tester.getRect(find.byKey(studentPayPurchaseContentSlotKey)),
      );
    }

    final loadingBar = await pumpBar(loading: true, available: false);
    final errorBar = await pumpBar(loading: false, available: false);
    final loadedBar = await pumpBar(loading: false, available: true);
    expect(errorBar, loadingBar);
    expect(loadedBar, loadingBar);

    Future<_CardSectionGeometry> pumpCards(
      TeacherPayoutCardsState state,
    ) async {
      await tester.pumpWidget(
        _componentApp(
          TeacherPayoutCardsSection(
            state: state,
            items: state == TeacherPayoutCardsState.loaded
                ? [
                    TeacherPayoutCardItem(
                      pan: '•••• 4242',
                      selected: true,
                      onTap: () {},
                    ),
                  ]
                : const [],
            onEditPressed:
                state == TeacherPayoutCardsState.loaded ? () {} : null,
          ),
          locale: const Locale('en'),
          textScaler: scaler,
          contentWidth: 272.0,
        ),
      );
      await tester.pump();
      return _cardSectionGeometry(tester);
    }

    final loadingCards = await pumpCards(TeacherPayoutCardsState.loading);
    final errorCards = await pumpCards(TeacherPayoutCardsState.error);
    final loadedCards = await pumpCards(TeacherPayoutCardsState.loaded);
    expect(errorCards, loadingCards);
    expect(loadedCards, loadingCards);

    Future<_TransactionGeometry> pumpRow(Widget row) async {
      await tester.pumpWidget(
        _componentApp(
          row,
          locale: const Locale('en'),
          textScaler: scaler,
          contentWidth: 272.0,
        ),
      );
      await tester.pump();
      return _transactionGeometry(tester);
    }

    final loadingRow = await pumpRow(
      const PaymentTransactionAsyncRow(
        layoutId: 'slot-0',
        hasError: false,
      ),
    );
    final errorRow = await pumpRow(
      const PaymentTransactionAsyncRow(
        layoutId: 'slot-0',
        hasError: true,
      ),
    );
    final purchaseRow = await pumpRow(
      TransWidget(
        trans: _transaction(StatusTransactions.completed),
        layoutId: 'slot-0',
      ),
    );
    final withdrawalRow = await pumpRow(
      TransWidget(
        trans: _transaction(
          StatusTransactions.declined,
          type: TypeTransactions.withdrawal,
        ),
        layoutId: 'slot-0',
      ),
    );
    expect(errorRow, loadingRow);
    expect(purchaseRow, loadingRow);
    expect(withdrawalRow, loadingRow);
    expect(loadingRow.row.height, greaterThan(paymentTransactionRowHeight));
    expect(tester.takeException(), isNull);
  });
}

_PayPageGeometry _payPageGeometry(WidgetTester tester) {
  return (
    monthlyCard: tester.getRect(
      find.byKey(studentPayPlanCardKey(StudentPayPlanKind.monthly)),
    ),
    monthlyPrice: tester.getRect(
      find.byKey(studentPayPlanPriceSlotKey(StudentPayPlanKind.monthly)),
    ),
    quarterlyCard: tester.getRect(
      find.byKey(studentPayPlanCardKey(StudentPayPlanKind.quarterly)),
    ),
    quarterlyPrice: tester.getRect(
      find.byKey(studentPayPlanPriceSlotKey(StudentPayPlanKind.quarterly)),
    ),
    restoreButton: tester.getRect(find.byType(TextButton)),
    bottomBar: tester.getRect(find.byKey(studentPayBottomBarKey)),
    purchaseCta: tester.getRect(find.byKey(studentPayPurchaseCtaKey)),
    purchaseContent:
        tester.getRect(find.byKey(studentPayPurchaseContentSlotKey)),
  );
}

void _expectPayPageSizesEqual(
  _PayPageGeometry actual,
  _PayPageGeometry expected,
) {
  expect(actual.monthlyCard.size, expected.monthlyCard.size);
  expect(actual.monthlyPrice.size, expected.monthlyPrice.size);
  expect(actual.quarterlyCard.size, expected.quarterlyCard.size);
  expect(actual.quarterlyPrice.size, expected.quarterlyPrice.size);
  expect(actual.restoreButton.size, expected.restoreButton.size);
  expect(actual.bottomBar.size, expected.bottomBar.size);
  expect(actual.purchaseCta.size, expected.purchaseCta.size);
  expect(actual.purchaseContent.size, expected.purchaseContent.size);
}

_CardSectionGeometry _cardSectionGeometry(WidgetTester tester) {
  return (
    section: tester.getRect(find.byKey(teacherPayoutCardsSectionKey)),
    header: tester.getRect(find.byKey(teacherPayoutCardsHeaderKey)),
    edit: tester.getRect(find.byKey(teacherPayoutCardsEditSlotKey)),
    rows: tester.getRect(find.byKey(teacherPayoutCardsRowsSlotKey)),
    row: tester.getRect(find.byKey(teacherPayoutCardRowKey(0))),
    leading: tester.getRect(find.byKey(teacherPayoutCardLeadingSlotKey(0))),
    text: tester.getRect(find.byKey(teacherPayoutCardTextSlotKey(0))),
    action: tester.getRect(find.byKey(teacherPayoutCardActionSlotKey(0))),
  );
}

_TransactionGeometry _transactionGeometry(WidgetTester tester) {
  const layoutId = 'slot-0';
  return (
    row: tester.getRect(find.byKey(paymentTransactionRowKey(layoutId))),
    leading:
        tester.getRect(find.byKey(paymentTransactionLeadingSlotKey(layoutId))),
    primary:
        tester.getRect(find.byKey(paymentTransactionPrimarySlotKey(layoutId))),
    meta: tester.getRect(find.byKey(paymentTransactionMetaSlotKey(layoutId))),
  );
}

void _configureView(
  WidgetTester tester, {
  Size logicalSize = const Size(390.0, 844.0),
  double devicePixelRatio = 1.0,
}) {
  tester.view.physicalSize = Size(
    logicalSize.width * devicePixelRatio,
    logicalSize.height * devicePixelRatio,
  );
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _componentApp(
  Widget child, {
  Locale locale = const Locale('ru'),
  TextScaler textScaler = _textScaler,
  double contentWidth = 342.0,
}) {
  return _localizedApp(
    locale: locale,
    textScaler: textScaler,
    home: Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: SizedBox(
            width: contentWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [child],
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _bottomBarApp(
  Widget bar, {
  Locale locale = const Locale('ru'),
  TextScaler textScaler = _textScaler,
}) {
  return _localizedApp(
    locale: locale,
    textScaler: textScaler,
    bottomPadding: 34.0,
    home: Scaffold(
      body: const SizedBox.expand(),
      bottomNavigationBar: bar,
    ),
  );
}

Widget _localizedApp({
  required Widget home,
  double bottomPadding = 0.0,
  Locale locale = const Locale('ru'),
  TextScaler textScaler = _textScaler,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('ru'), Locale('en')],
    localizationsDelegates: const [
      FFLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      FallbackMaterialLocalizationDelegate(),
      FallbackCupertinoLocalizationDelegate(),
    ],
    builder: (context, child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: EdgeInsets.only(bottom: bottomPadding),
          viewPadding: EdgeInsets.only(bottom: bottomPadding),
          textScaler: textScaler,
        ),
        child: child!,
      );
    },
    home: home,
  );
}

CardsRecord _card(String ownerId, String cardId, String pan) {
  final owner = FirebaseFirestore.instance.doc('users/$ownerId');
  return CardsRecord.getDocumentFromData(
    <String, dynamic>{'pan': pan},
    CardsRecord.createDoc(owner, id: cardId),
  );
}

TransactionsRecord _transaction(
  StatusTransactions status, {
  TypeTransactions type = TypeTransactions.purchase,
  String documentId = 'geometry',
}) {
  return TransactionsRecord.getDocumentFromData(
    <String, dynamic>{
      'createdAt': DateTime(2026, 7, 14, 12),
      'type': type,
      'status': status,
      'amount_ST': 100.0,
      'amount': 1299.0,
    },
    TransactionsRecord.collection.doc(documentId),
  );
}

class _ControllableCatalogLoader {
  final List<Completer<Map<String, String>>> requests = [];

  Future<Map<String, String>> load() {
    final request = Completer<Map<String, String>>();
    requests.add(request);
    return request.future;
  }
}
