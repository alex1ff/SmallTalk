import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/backend/schema/enums/enums.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/services/ux_session_cache_lifecycle.dart';
import 'package:small_talk/shared_pages/profile/profile_widget.dart';

void main() {
  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    SharedPreferences.setMockInitialValues({});
    await FFLocalizations.initialize();
  });

  setUp(() {
    UxSessionCacheLifecycle.debugResetForTesting();
    ProfileModel.debugClearSessionCache();
  });

  test('profile server confirmation rejects cache and pending writes', () {
    expect(
      profileSnapshotIsServerConfirmed(
        isFromCache: false,
        hasPendingWrites: false,
      ),
      isTrue,
    );
    expect(
      profileSnapshotIsServerConfirmed(
        isFromCache: true,
        hasPendingWrites: false,
      ),
      isFalse,
    );
    expect(
      profileSnapshotIsServerConfirmed(
        isFromCache: false,
        hasPendingWrites: true,
      ),
      isFalse,
    );
  });

  testWidgets('primary profile renders while secondary sections load',
      (tester) async {
    final harness = _ProfileHarness(
      userId: 'alice',
      user: _user('alice', name: 'Alice', totalCalls: 7),
    );
    addTearDown(harness.close);

    await tester.pumpWidget(harness.buildApp());
    await tester.pump();

    expect(find.byKey(profileInitialLoadingKey), findsNothing);
    expect(find.byKey(profileContentKey), findsOneWidget);
    expect(_text(tester, profileDisplayNameKey), 'Alice');
    expect(_text(tester, profileEmailKey), 'alice@example.com');
    expect(_text(tester, profileWordsValueKey), '—');
    expect(_text(tester, profileCallsValueKey), '7');
    expect(_text(tester, profileMinutesValueKey), '—');
    expect(find.byKey(profileProgressLoadingKey), findsOneWidget);
    expect(harness.sources.words, hasLength(1));
    expect(harness.sources.stats, hasLength(1));
  });

  testWidgets('words and stats complete independently without primary reset',
      (tester) async {
    final harness = _ProfileHarness(
      userId: 'alice',
      user: _user('alice', name: 'Alice', totalCalls: 7),
    );
    addTearDown(harness.close);
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();

    harness.sources.words.single.add(
      _result([
        _word('alice', 'one'),
        _word('alice', 'two'),
      ]),
    );
    await tester.pump();

    expect(_text(tester, profileWordsValueKey), '2');
    expect(_text(tester, profileCallsValueKey), '7');
    expect(_text(tester, profileMinutesValueKey), '—');
    expect(_text(tester, profileDisplayNameKey), 'Alice');

    harness.sources.stats.single.add(
      _result([_stats('alice', calls: '12', minutes: '48:20')]),
    );
    await tester.pump();

    expect(_text(tester, profileWordsValueKey), '2');
    expect(_text(tester, profileCallsValueKey), '12');
    expect(_text(tester, profileMinutesValueKey), '48');
    expect(find.byKey(profileProgressLoadingKey), findsNothing);
  });

  testWidgets('same-user reconnect retains primary and secondary data',
      (tester) async {
    final harness = _ProfileHarness(
      userId: 'alice',
      user: _user('alice', name: 'Alice', totalCalls: 7),
    );
    addTearDown(harness.close);
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();
    harness.sources.words.single.add(
      _result([_word('alice', 'kept')]),
    );
    harness.sources.stats.single.add(
      _result([_stats('alice', calls: '9', minutes: '21')]),
    );
    await tester.pump();

    harness.user = null;
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();

    expect(find.byKey(profileInitialLoadingKey), findsNothing);
    expect(_text(tester, profileDisplayNameKey), 'Alice');
    expect(_text(tester, profileWordsValueKey), '1');
    expect(_text(tester, profileCallsValueKey), '9');
    expect(harness.sources.words, hasLength(1));
    expect(harness.sources.stats, hasLength(1));

    harness.user = _user('alice', name: 'Alicia', totalCalls: 10);
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();

    expect(_text(tester, profileDisplayNameKey), 'Alicia');
    expect(_text(tester, profileWordsValueKey), '1');
    expect(_text(tester, profileCallsValueKey), '9');
    expect(harness.sources.words, hasLength(1));
    expect(harness.sources.stats, hasLength(1));
  });

  testWidgets('session cache restores primary and progress on remount',
      (tester) async {
    final firstHarness = _ProfileHarness(
      userId: 'alice',
      user: _user('alice', name: 'Alice', totalCalls: 7),
    );
    final secondHarness = _ProfileHarness(userId: 'alice', user: null);
    addTearDown(firstHarness.close);
    addTearDown(secondHarness.close);

    await tester.pumpWidget(firstHarness.buildApp());
    await tester.pump();
    firstHarness.sources.words.single.add(
      _result([_word('alice', 'cached')]),
    );
    firstHarness.sources.stats.single.add(
      _result([_stats('alice', calls: '9', minutes: '21')]),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await tester.pumpWidget(secondHarness.buildApp());
    await tester.pump();

    expect(find.byKey(profileInitialLoadingKey), findsNothing);
    expect(_text(tester, profileDisplayNameKey), 'Alice');
    expect(_text(tester, profileWordsValueKey), '1');
    expect(_text(tester, profileCallsValueKey), '9');
    expect(_text(tester, profileMinutesValueKey), '21');
    expect(find.byKey(profileProgressLoadingKey), findsOneWidget);
  });

  testWidgets('logout clears retained profile content', (tester) async {
    UxSessionCacheLifecycle.updateAuthenticatedUser('alice');
    final harness = _ProfileHarness(
      userId: 'alice',
      user: _user('alice', name: 'Alice', totalCalls: 7),
    );
    addTearDown(harness.close);
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();
    expect(_text(tester, profileDisplayNameKey), 'Alice');

    UxSessionCacheLifecycle.updateAuthenticatedUser(null);
    harness.isLoggedIn = false;
    harness.userId = '';
    harness.user = null;
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();

    expect(find.byKey(profileSignedOutKey), findsOneWidget);
    expect(find.byKey(profileContentKey), findsNothing);
    expect(find.text('Alice'), findsNothing);

    UxSessionCacheLifecycle.updateAuthenticatedUser('alice');
    harness.isLoggedIn = true;
    harness.userId = 'alice';
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();

    expect(find.byKey(profileInitialLoadingKey), findsOneWidget);
    expect(find.text('Alice'), findsNothing);
  });

  testWidgets('user switch hides stale primary and ignores old secondary data',
      (tester) async {
    final harness = _ProfileHarness(
      userId: 'alice',
      user: _user('alice', name: 'Alice', totalCalls: 7),
    );
    addTearDown(harness.close);
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();
    harness.sources.words.single.add(
      _result([_word('alice', 'alice-word')]),
    );
    await tester.pump();

    harness.userId = 'bob';
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();

    expect(find.byKey(profileInitialLoadingKey), findsOneWidget);
    expect(find.text('Alice'), findsNothing);
    expect(find.byKey(profileContentKey), findsNothing);
    expect(harness.sources.words, hasLength(1));
    expect(harness.sources.stats, hasLength(1));

    harness.sources.words.first.add(
      _result([_word('alice', 'late-alice-word')]),
    );
    harness.sources.words.first.addError(StateError('late Alice error'));
    await tester.pump();
    expect(find.byKey(profileContentKey), findsNothing);

    harness.user = _user('bob', name: 'Bob', totalCalls: 3);
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();

    expect(_text(tester, profileDisplayNameKey), 'Bob');
    expect(_text(tester, profileWordsValueKey), '—');
    expect(harness.sources.words, hasLength(2));
    expect(harness.sources.stats, hasLength(2));
    harness.sources.words.last.add(
      _result([_word('bob', 'bob-word')]),
    );
    await tester.pump();
    expect(_text(tester, profileWordsValueKey), '1');
  });

  testWidgets('unconfirmed empty is not shown as zero', (tester) async {
    final harness = _ProfileHarness(
      userId: 'alice',
      user: _user('alice', name: 'Alice', totalCalls: 7),
    );
    addTearDown(harness.close);
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();

    harness.sources.words.single.add(
      _result(const <UserWordsRecord>[], confirmed: false),
    );
    harness.sources.stats.single.add(
      _result(const <StatsRecord>[], confirmed: false),
    );
    await tester.pump();

    expect(_text(tester, profileWordsValueKey), '—');
    expect(_text(tester, profileMinutesValueKey), '—');

    harness.sources.words.single.add(
      _result(const <UserWordsRecord>[], confirmed: true),
    );
    harness.sources.stats.single.add(
      _result(const <StatsRecord>[], confirmed: true),
    );
    await tester.pump();

    expect(_text(tester, profileWordsValueKey), '0');
    expect(_text(tester, profileCallsValueKey), '7');
    expect(_text(tester, profileMinutesValueKey), '0');
  });

  testWidgets('teacher progress skips the dictionary source', (tester) async {
    final harness = _ProfileHarness(
      userId: 'teacher',
      user: _user(
        'teacher',
        name: 'Teacher',
        totalCalls: 14,
        role: UserRole.native_speaker,
      ),
    );
    addTearDown(harness.close);
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();

    expect(harness.sources.words, isEmpty);
    expect(harness.sources.stats, hasLength(1));
    expect(_text(tester, profileWordsValueKey), '— ₽');
    expect(_text(tester, profileCallsValueKey), '14');
    const trackedKeys = <Key>[
      profileProgressSectionKey,
      profileProgressCardKey,
      profileTariffSectionKey,
      profileSettingsSectionKey,
    ];
    final initialGeometry = _captureRects(tester, trackedKeys);

    harness.sources.stats.single.add(
      _result([
        _stats(
          'teacher',
          calls: '18',
          minutes: '90',
          earned: '125',
        ),
      ]),
    );
    await tester.pump();

    expect(_text(tester, profileWordsValueKey), '125 ₽');
    expect(_text(tester, profileCallsValueKey), '18');
    expect(_text(tester, profileMinutesValueKey), '90');
    _expectSameRects(tester, initialGeometry);

    harness.sources.stats.single.addError(StateError('stats failed'));
    await tester.pump();
    expect(find.byKey(profileProgressRetryKey), findsOneWidget);
    _expectSameRects(tester, initialGeometry);

    await tester.tap(find.byKey(profileProgressRetryKey));
    await tester.pump();
    expect(harness.sources.stats, hasLength(2));
    expect(find.byKey(profileProgressLoadingKey), findsOneWidget);
    _expectSameRects(tester, initialGeometry);
  });

  testWidgets('secondary error retains values and retry recreates sources',
      (tester) async {
    final harness = _ProfileHarness(
      userId: 'alice',
      user: _user('alice', name: 'Alice', totalCalls: 7),
    );
    addTearDown(harness.close);
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();
    harness.sources.words.single.add(
      _result([_word('alice', 'kept')]),
    );
    harness.sources.stats.single.add(
      _result([_stats('alice', calls: '9', minutes: '21')]),
    );
    await tester.pump();

    harness.sources.words.single.addError(StateError('words failed'));
    harness.sources.stats.single.addError(StateError('stats failed'));
    await tester.pump();

    expect(_text(tester, profileDisplayNameKey), 'Alice');
    expect(_text(tester, profileWordsValueKey), '1');
    expect(_text(tester, profileCallsValueKey), '9');
    expect(find.byKey(profileProgressRetryKey), findsOneWidget);

    await tester.ensureVisible(find.byKey(profileProgressRetryKey));
    await tester.tap(find.byKey(profileProgressRetryKey));
    await tester.pump();

    expect(harness.sources.words, hasLength(2));
    expect(harness.sources.stats, hasLength(2));
    expect(_text(tester, profileWordsValueKey), '1');
    expect(_text(tester, profileCallsValueKey), '9');
    expect(find.byKey(profileProgressLoadingKey), findsOneWidget);
  });

  testWidgets('cold secondary error retries and ignores the old generation',
      (tester) async {
    final harness = _ProfileHarness(
      userId: 'alice',
      user: _user('alice', name: 'Alice', totalCalls: 7),
    );
    addTearDown(harness.close);
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();

    harness.sources.words.single.addError(StateError('cold words failed'));
    harness.sources.stats.single.addError(StateError('cold stats failed'));
    await tester.pump();

    expect(_text(tester, profileDisplayNameKey), 'Alice');
    expect(_text(tester, profileWordsValueKey), '—');
    expect(_text(tester, profileCallsValueKey), '7');
    expect(_text(tester, profileMinutesValueKey), '—');
    expect(find.byKey(profileProgressRetryKey), findsOneWidget);

    await tester.ensureVisible(find.byKey(profileProgressRetryKey));
    await tester.tap(find.byKey(profileProgressRetryKey));
    await tester.pump();
    expect(harness.sources.words, hasLength(2));
    expect(harness.sources.stats, hasLength(2));

    harness.sources.words.first.add(
      _result([_word('alice', 'late-old-word')]),
    );
    harness.sources.stats.first.add(
      _result([_stats('alice', calls: '99', minutes: '99')]),
    );
    await tester.pump();

    expect(_text(tester, profileWordsValueKey), '—');
    expect(_text(tester, profileCallsValueKey), '7');
    expect(_text(tester, profileMinutesValueKey), '—');

    harness.sources.stats.last.add(
      _result([_stats('alice', calls: '11', minutes: '33')]),
    );
    await tester.pump();

    expect(_text(tester, profileWordsValueKey), '—');
    expect(_text(tester, profileCallsValueKey), '11');
    expect(_text(tester, profileMinutesValueKey), '33');

    harness.sources.words.last.add(
      _result([_word('alice', 'fresh-word')]),
    );
    await tester.pump();
    expect(_text(tester, profileWordsValueKey), '1');
  });

  testWidgets('progress geometry stays stable through load error and retry',
      (tester) async {
    final harness = _ProfileHarness(
      userId: 'alice',
      user: _user('alice', name: 'Alice', totalCalls: 7),
    );
    addTearDown(harness.close);
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();

    const trackedKeys = <Key>[
      profileProgressSectionKey,
      profileProgressCardKey,
      profileTariffSectionKey,
      profileSettingsSectionKey,
    ];
    final initialGeometry = _captureRects(tester, trackedKeys);

    harness.sources.words.single.add(
      _result([
        _word('alice', 'one'),
        _word('alice', 'two'),
      ]),
    );
    await tester.pump();
    _expectSameRects(tester, initialGeometry);

    harness.sources.stats.single.add(
      _result([_stats('alice', calls: '123456', minutes: '987654:20')]),
    );
    await tester.pump();
    _expectSameRects(tester, initialGeometry);

    harness.sources.words.single.addError(StateError('words failed'));
    harness.sources.stats.single.addError(StateError('stats failed'));
    await tester.pump();
    expect(find.byKey(profileProgressRetryKey), findsOneWidget);
    _expectSameRects(tester, initialGeometry);

    await tester.tap(find.byKey(profileProgressRetryKey));
    await tester.pump();
    expect(find.byKey(profileProgressLoadingKey), findsOneWidget);
    _expectSameRects(tester, initialGeometry);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tariff geometry stays stable as entitlement data arrives',
      (tester) async {
    final harness = _ProfileHarness(
      userId: 'alice',
      user: _user('alice', name: 'Alice', totalCalls: 7),
    );
    addTearDown(harness.close);
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();

    const trackedKeys = <Key>[
      profileTariffSectionKey,
      profileTariffCardKey,
      profileTariffInfoSlotKey,
      profileSettingsSectionKey,
    ];
    final initialGeometry = _captureRects(tester, trackedKeys);

    harness.user = _user(
      'alice',
      name: 'Alice',
      totalCalls: 7,
      giftMinutes: GiftMinutesStruct(
        minutes: 120,
        totalGranted: 120,
        expiresAt: DateTime.now().add(const Duration(days: 2)),
      ),
    );
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();
    expect(find.text('Подарочные минуты'), findsOneWidget);
    _expectSameRects(tester, initialGeometry);

    harness.user = _user(
      'alice',
      name: 'Alice',
      totalCalls: 7,
      subscription: SubscriptionStruct(
        productId: 'expatlio_1_month',
        periodMonths: 1,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      ),
    );
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();
    expect(find.text('Изменить тариф'), findsOneWidget);
    _expectSameRects(tester, initialGeometry);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tariff geometry stays stable when gift minutes expire',
      (tester) async {
    var now = DateTime.utc(2026, 1, 1, 12);
    final harness = _ProfileHarness(
      userId: 'alice',
      user: _user(
        'alice',
        name: 'Alice',
        totalCalls: 7,
        giftMinutes: GiftMinutesStruct(
          minutes: 15,
          totalGranted: 15,
          expiresAt: now.add(const Duration(hours: 1)),
        ),
      ),
      nowProvider: () => now,
    );
    addTearDown(harness.close);
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();
    expect(find.text('Подарочные минуты'), findsOneWidget);

    const trackedKeys = <Key>[
      profileTariffSectionKey,
      profileTariffCardKey,
      profileTariffInfoSlotKey,
      profileSettingsSectionKey,
    ];
    final initialGeometry = _captureRects(tester, trackedKeys);

    now = now.add(const Duration(hours: 2));
    await tester.pump(const Duration(hours: 2));
    expect(find.text('Нет подписки'), findsOneWidget);
    _expectSameRects(tester, initialGeometry);
    expect(tester.takeException(), isNull);
  });

  testWidgets('email geometry and semantics stay stable in compact RU',
      (tester) async {
    await _verifyEmailGeometryScenario(
      tester,
      locale: const Locale('ru'),
      width: 360,
      idleTitle: 'Подтвердите email',
      idleAction: 'Отправить письмо',
      sendingAction: 'Отправляем...',
      verifiedTitle: 'Email подтверждён',
    );
  });

  testWidgets('email action stays on the right at standard text scale',
      (tester) async {
    tester.view.physicalSize = const Size(360, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = _ProfileHarness(
      userId: 'alice',
      user: _user('alice', name: 'Alice', totalCalls: 7),
      exposeEmailStatus: true,
    );
    addTearDown(harness.close);
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();

    final statusRect = tester.getRect(find.byKey(profileEmailStatusSlotKey));
    final actionRect = tester.getRect(find.byKey(profileEmailActionSlotKey));

    expect(actionRect.center.dy, closeTo(statusRect.center.dy, 0.01));
    expect(actionRect.center.dx, greaterThan(statusRect.center.dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('email slot geometry stays stable when address arrives',
      (tester) async {
    final harness = _ProfileHarness(
      userId: 'alice',
      user: _user(
        'alice',
        name: 'Alice',
        totalCalls: 7,
        email: '',
      ),
      exposeEmailStatus: true,
    );
    addTearDown(harness.close);
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();
    expect(find.text('Email не указан'), findsOneWidget);
    expect(find.byKey(profileEmailActionButtonKey), findsNothing);

    const trackedKeys = <Key>[
      profileHeaderCardKey,
      profileEmailStatusSlotKey,
      profileEmailActionSlotKey,
      profileProgressSectionKey,
    ];
    final initialGeometry = _captureRects(tester, trackedKeys);

    harness.user = _user('alice', name: 'Alice', totalCalls: 7);
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();
    expect(find.text('Подтвердите email'), findsOneWidget);
    expect(find.byKey(profileEmailActionButtonKey), findsOneWidget);
    _expectSameRects(tester, initialGeometry);
    expect(tester.takeException(), isNull);
  });

  testWidgets('email geometry and semantics stay stable in compact EN',
      (tester) async {
    await _verifyEmailGeometryScenario(
      tester,
      locale: const Locale('en'),
      width: 375,
      idleTitle: 'Verify your email',
      idleAction: 'Send email',
      sendingAction: 'Sending...',
      verifiedTitle: 'Email verified',
    );
  });

  testWidgets('profile geometry is stable on compact high-text layout',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final harness = _ProfileHarness(
      userId: 'alice',
      user: _user('alice', name: 'Alice', totalCalls: 7),
      exposeEmailStatus: true,
      textScaler: const TextScaler.linear(2),
    );
    addTearDown(harness.close);
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();
    expect(tester.takeException(), isNull);

    const trackedKeys = <Key>[
      profileHeaderCardKey,
      profileEmailStatusSlotKey,
      profileProgressSectionKey,
      profileProgressCardKey,
      profileTariffSectionKey,
      profileTariffCardKey,
      profileTariffInfoSlotKey,
      profileSettingsSectionKey,
    ];
    final initialGeometry = _captureRects(tester, trackedKeys);

    harness.sources.words.single.add(
      _result([_word('alice', 'one')]),
    );
    harness.sources.stats.single.add(
      _result([
        _stats(
          'alice',
          calls: '123456789',
          minutes: '987654321',
        ),
      ]),
    );
    harness.user = _user(
      'alice',
      name: 'Alice',
      totalCalls: 7,
      subscription: SubscriptionStruct(
        productId: 'expatlio_1_month',
        periodMonths: 1,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      ),
    );
    harness.emailVerified = true;
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();

    expect(_text(tester, profileWordsValueKey), '1');
    expect(_text(tester, profileCallsValueKey), '123456789');
    expect(_text(tester, profileMinutesValueKey), '987654321');
    expect(find.byKey(profileProgressLoadingKey), findsNothing);
    expect(find.text('Изменить тариф'), findsOneWidget);
    expect(find.text('Email подтверждён'), findsOneWidget);
    _expectSameRects(tester, initialGeometry);
    expect(tester.takeException(), isNull);
  });

  testWidgets('avatar shell stays stable through real image stream transitions',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cacheManager = _prepareControlledAvatarCacheManager();
    final harness = _ProfileHarness(
      userId: 'alice',
      user: _user('alice', name: 'Alice', totalCalls: 7),
      textScaler: const TextScaler.linear(3),
      avatarCacheManager: cacheManager,
    );
    addTearDown(harness.close);
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();

    const trackedKeys = <Key>[
      profileAvatarSemanticsKey,
      profileAvatarSlotKey,
      profileAvatarEditBadgeKey,
      profileHeaderCardKey,
      profileProgressSectionKey,
    ];
    final initialGeometry = _captureRects(tester, trackedKeys);
    expect(
        tester.getSize(find.byKey(profileAvatarSlotKey)), const Size(88, 88));
    expect(
      tester.getSize(find.byKey(profileAvatarEditBadgeKey)),
      const Size(28, 28),
    );
    final initialSlot = tester.getRect(find.byKey(profileAvatarSlotKey));
    final initialBadge = tester.getRect(find.byKey(profileAvatarEditBadgeKey));
    expect(initialBadge.right, closeTo(initialSlot.right, 0.01));
    expect(initialBadge.bottom, closeTo(initialSlot.bottom, 0.01));
    expect(find.byKey(profileAvatarFallbackKey), findsOneWidget);
    expect(_avatarFallbackText(tester), 'A');
    final semanticsWidget = tester.widget<Semantics>(
      find.byKey(profileAvatarSemanticsKey),
    );
    expect(semanticsWidget.excludeSemantics, isTrue);
    expect(semanticsWidget.properties.image, isTrue);
    expect(semanticsWidget.properties.label, 'Фото профиля: Alice');
    final semanticsHandle = tester.ensureSemantics();
    final initialSemantics =
        tester.getSemantics(find.byKey(profileAvatarSemanticsKey));
    final initialSemanticsId = initialSemantics.id;
    final initialSemanticsRect = initialSemantics.rect;

    const aliceAUrl = 'https://example.invalid/alice-a.png';
    harness.user = _user(
      'alice',
      name: 'Alice',
      totalCalls: 7,
      photoUrl: '  $aliceAUrl  ',
    );
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();
    expect(cacheManager.requestedUrls.last, aliceAUrl);
    expect(find.byKey(profileAvatarFallbackKey), findsOneWidget);
    expect(_avatarFallbackText(tester), 'A');
    expect(_renderedAvatarImages(tester), isEmpty);
    final aliceImageElement = tester.element(
      find.byKey(profileAvatarImageIdentityKey('users/alice')),
    );
    _expectSameRects(tester, initialGeometry);

    await cacheManager.complete(aliceAUrl);
    await _pumpUntilAvatarFrame(tester);
    expect(find.byKey(profileAvatarFallbackKey), findsNothing);
    final aliceAImage = _renderedAvatarImages(tester).single;
    expect(
      tester.element(
        find.byKey(profileAvatarImageIdentityKey('users/alice')),
      ),
      same(aliceImageElement),
    );
    _expectSameRects(tester, initialGeometry);

    const aliceBUrl = 'https://example.invalid/alice-b.png';
    harness.user = _user(
      'alice',
      name: 'Alice',
      totalCalls: 7,
      photoUrl: aliceBUrl,
    );
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();
    expect(cacheManager.requestedUrls.last, aliceBUrl);
    expect(find.byKey(profileAvatarFallbackKey), findsNothing);
    expect(
      _renderedAvatarImages(tester).any(
        (image) => image.isCloneOf(aliceAImage),
      ),
      isTrue,
      reason: 'the loaded A image must remain while B is pending',
    );
    expect(
      tester.element(
        find.byKey(profileAvatarImageIdentityKey('users/alice')),
      ),
      same(aliceImageElement),
    );
    _expectSameRects(tester, initialGeometry);

    await cacheManager.complete(aliceBUrl);
    await _pumpUntilAvatarFrame(tester, differentFrom: aliceAImage);
    expect(find.byKey(profileAvatarFallbackKey), findsNothing);
    final aliceBImage = _renderedAvatarImages(tester).single;
    _expectSameRects(tester, initialGeometry);

    const aliceErrorUrl = 'https://example.invalid/alice-error.png';
    harness.user = _user(
      'alice',
      name: 'Alice',
      totalCalls: 7,
      photoUrl: aliceErrorUrl,
    );
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();
    expect(cacheManager.requestedUrls.last, aliceErrorUrl);
    expect(find.byKey(profileAvatarFallbackKey), findsNothing);
    expect(
      _renderedAvatarImages(tester).any(
        (image) => image.isCloneOf(aliceBImage),
      ),
      isTrue,
    );
    _expectSameRects(tester, initialGeometry);

    cacheManager.fail(aliceErrorUrl);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(profileAvatarFallbackKey), findsOneWidget);
    expect(_renderedAvatarImages(tester), isEmpty);
    _expectSameRects(tester, initialGeometry);

    const aliceCUrl = 'https://example.invalid/alice-c.png';
    harness.user = _user(
      'alice',
      name: 'Alice',
      totalCalls: 7,
      photoUrl: aliceCUrl,
    );
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.idle();
    await tester.pump();
    expect(
      tester
          .widget<CachedNetworkImage>(
            find.byKey(profileAvatarNetworkImageKey),
          )
          .imageUrl,
      aliceCUrl,
    );
    expect(cacheManager.requestedUrls, contains(aliceCUrl));
    expect(find.byKey(profileAvatarFallbackKey), findsOneWidget);
    expect(_renderedAvatarImages(tester), isEmpty);
    _expectSameRects(tester, initialGeometry);

    await cacheManager.complete(aliceCUrl);
    await _pumpUntilAvatarFrame(tester, differentFrom: aliceBImage);
    expect(find.byKey(profileAvatarFallbackKey), findsNothing);
    _expectSameRects(tester, initialGeometry);

    harness.user = null;
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();
    expect(
      tester.element(
        find.byKey(profileAvatarImageIdentityKey('users/alice')),
      ),
      same(aliceImageElement),
    );
    expect(find.byKey(profileAvatarFallbackKey), findsNothing);
    expect(_renderedAvatarImages(tester), isNotEmpty);
    _expectSameRects(tester, initialGeometry);

    expect(
      tester.getSemantics(find.byKey(profileAvatarSemanticsKey)).id,
      initialSemanticsId,
    );
    expect(
      tester.getSemantics(find.byKey(profileAvatarSemanticsKey)).rect,
      initialSemanticsRect,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();
    expect(
      find.byKey(profileAvatarImageIdentityKey('users/alice')),
      findsOneWidget,
    );
    expect(find.byKey(profileInitialLoadingKey), findsNothing);
    expect(find.byKey(profileAvatarFallbackKey), findsNothing);
    expect(_renderedAvatarImages(tester), isNotEmpty);
    _expectSameRects(tester, initialGeometry);

    const bobUrl = 'https://example.invalid/bob.png';
    harness.userId = 'bob';
    harness.user = _user(
      'bob',
      name: 'Bob',
      totalCalls: 3,
      photoUrl: bobUrl,
    );
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();
    expect(
      find.byKey(profileAvatarImageIdentityKey('users/alice')),
      findsNothing,
    );
    expect(
      find.byKey(profileAvatarImageIdentityKey('users/bob')),
      findsOneWidget,
    );
    expect(cacheManager.requestedUrls.last, bobUrl);
    expect(_avatarFallbackText(tester), 'B');
    expect(_renderedAvatarImages(tester), isEmpty);
    expect(
      tester
          .widget<Semantics>(find.byKey(profileAvatarSemanticsKey))
          .properties
          .label,
      'Фото профиля: Bob',
    );
    _expectSameRects(tester, initialGeometry);

    cacheManager.fail(bobUrl);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(profileAvatarFallbackKey), findsOneWidget);
    expect(_avatarFallbackText(tester), 'B');
    expect(_renderedAvatarImages(tester), isEmpty);
    _expectSameRects(tester, initialGeometry);

    harness.isLoggedIn = false;
    harness.userId = '';
    harness.user = null;
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();
    expect(find.byKey(profileAvatarSlotKey), findsNothing);
    expect(find.byKey(profileAvatarSemanticsKey), findsNothing);
    semanticsHandle.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('production avatar image uses stable DPR-aware configuration',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cacheManager = _prepareControlledAvatarCacheManager();
    const imageUrl = 'https://example.invalid/alice-config.png';
    final harness = _ProfileHarness(
      userId: 'alice',
      user: _user(
        'alice',
        name: 'Alice',
        totalCalls: 7,
        photoUrl: '  $imageUrl  ',
      ),
      locale: const Locale('en'),
      avatarCacheManager: cacheManager,
    );
    addTearDown(harness.close);
    await tester.pumpWidget(harness.buildApp());
    await tester.pump();

    final cachedImage = tester.widget<CachedNetworkImage>(
      find.byKey(profileAvatarNetworkImageKey),
    );
    expect(cachedImage.imageUrl, imageUrl);
    expect(cachedImage.cacheManager, same(cacheManager));
    expect(cachedImage.width, 88);
    expect(cachedImage.height, 88);
    expect(cachedImage.fit, BoxFit.cover);
    expect(cachedImage.fadeInDuration, Duration.zero);
    expect(cachedImage.fadeOutDuration, Duration.zero);
    expect(cachedImage.useOldImageOnUrlChange, isTrue);
    expect(cachedImage.memCacheWidth, 264);
    expect(cachedImage.memCacheHeight, 264);
    expect(cachedImage.placeholder, isNotNull);
    expect(cachedImage.errorWidget, isNotNull);
    expect(cacheManager.requestedUrls.last, imageUrl);
    expect(
      tester
          .widget<Semantics>(find.byKey(profileAvatarSemanticsKey))
          .properties
          .label,
      'Profile photo: Alice',
    );
    expect(find.byKey(profileAvatarFallbackKey), findsOneWidget);
    await cacheManager.complete(imageUrl);
    await _pumpUntilAvatarFrame(tester);
    expect(find.byKey(profileAvatarFallbackKey), findsNothing);
    expect(_renderedAvatarImages(tester), isNotEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _verifyEmailGeometryScenario(
  WidgetTester tester, {
  required Locale locale,
  required double width,
  required String idleTitle,
  required String idleAction,
  required String sendingAction,
  required String verifiedTitle,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  var sendCompleter = Completer<void>();
  var sendCalls = 0;
  final harness = _ProfileHarness(
    userId: 'alice',
    user: _user('alice', name: 'Alice', totalCalls: 7),
    exposeEmailStatus: true,
    textScaler: const TextScaler.linear(2),
    locale: locale,
  )..onSendEmailVerification = () {
      sendCalls += 1;
      return sendCompleter.future;
    };
  addTearDown(harness.close);
  await tester.pumpWidget(harness.buildApp());
  await tester.pump();

  const trackedKeys = <Key>[
    profileHeaderCardKey,
    profileEmailStatusSlotKey,
    profileEmailActionSlotKey,
    profileProgressSectionKey,
  ];
  final initialGeometry = _captureRects(tester, trackedKeys);
  expect(find.text(idleAction), findsOneWidget);
  final idleSemantics = tester.widget<Semantics>(
    find.byKey(profileEmailStatusSemanticsKey),
  );
  expect(idleSemantics.container, isTrue);
  expect(idleSemantics.explicitChildNodes, isTrue);
  expect(idleSemantics.properties.liveRegion, isTrue);
  expect(idleSemantics.properties.label, '$idleTitle, alice@example.com');
  _expectEmailSemantics(
    tester,
    statusLabel: '$idleTitle, alice@example.com',
    actionLabel: idleAction,
  );
  expect(
    find.descendant(
      of: find.byKey(profileEmailStatusSemanticsKey),
      matching: find.byType(ExcludeSemantics),
    ),
    findsWidgets,
  );

  await tester.tap(find.byKey(profileEmailActionButtonKey));
  await tester.pump();
  expect(sendCalls, 1);
  expect(find.text(sendingAction), findsOneWidget);
  expect(find.byKey(profileEmailSendingIndicatorKey), findsOneWidget);
  expect(
    tester
        .widget<TextButton>(find.byKey(profileEmailActionButtonKey))
        .onPressed,
    isNull,
  );
  expect(
    tester
        .widget<Semantics>(find.byKey(profileEmailStatusSemanticsKey))
        .properties
        .label,
    '$idleTitle, alice@example.com, $sendingAction',
  );
  _expectEmailSemantics(
    tester,
    statusLabel: '$idleTitle, alice@example.com, $sendingAction',
    actionLabel: sendingAction,
  );
  _expectSameRects(tester, initialGeometry);

  sendCompleter.complete();
  await tester.pump();
  await tester.pump();
  expect(find.text(idleAction), findsOneWidget);
  expect(find.byKey(profileEmailSendingIndicatorKey), findsNothing);
  expect(
    tester
        .widget<TextButton>(find.byKey(profileEmailActionButtonKey))
        .onPressed,
    isNotNull,
  );
  _expectSameRects(tester, initialGeometry);

  sendCompleter = Completer<void>();
  await tester.tap(find.byKey(profileEmailActionButtonKey));
  await tester.pump();
  expect(sendCalls, 2);
  expect(find.text(sendingAction), findsOneWidget);
  _expectSameRects(tester, initialGeometry);

  sendCompleter.completeError(StateError('verification failed'));
  await tester.pump();
  await tester.pump();
  expect(find.text(idleAction), findsOneWidget);
  expect(find.byKey(profileEmailSendingIndicatorKey), findsNothing);
  _expectSameRects(tester, initialGeometry);

  harness.emailVerified = true;
  await tester.pumpWidget(harness.buildApp());
  await tester.pump();
  expect(find.text(verifiedTitle), findsOneWidget);
  expect(find.byKey(profileEmailActionButtonKey), findsNothing);
  expect(
    tester
        .widget<Semantics>(find.byKey(profileEmailStatusSemanticsKey))
        .properties
        .label,
    '$verifiedTitle, alice@example.com',
  );
  _expectEmailSemantics(
    tester,
    statusLabel: '$verifiedTitle, alice@example.com',
  );
  _expectSameRects(tester, initialGeometry);

  await tester.pump(const Duration(seconds: 4));
  await tester.pump(const Duration(seconds: 4));
  await tester.pump(const Duration(seconds: 1));
  expect(tester.takeException(), isNull);
}

_ControlledAvatarCacheManager _prepareControlledAvatarCacheManager() {
  PaintingBinding.instance.imageCache.clear();
  PaintingBinding.instance.imageCache.clearLiveImages();
  final manager = _ControlledAvatarCacheManager();
  addTearDown(() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await manager.dispose();
  });
  return manager;
}

class _ControlledAvatarCacheManager extends CacheManager {
  _ControlledAvatarCacheManager()
      : super(
          Config(
            'profile-avatar-test-${_nextId++}',
            repo: NonStoringObjectProvider(),
            fileSystem: MemoryCacheSystem(),
            fileService: _UnusedFileService(),
          ),
        );

  static int _nextId = 0;
  final MemoryCacheSystem _files = MemoryCacheSystem();
  final Map<String, Completer<FileResponse>> _responses = {};
  final List<String> requestedUrls = [];
  int _fileId = 0;

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) {
    requestedUrls.add(url);
    return _responses
        .putIfAbsent(url, Completer<FileResponse>.new)
        .future
        .asStream();
  }

  Future<void> complete(String url) async {
    final responseCompleter = _responses[url];
    if (responseCompleter == null) {
      throw StateError('No pending avatar request for $url');
    }
    final file = await _files.createFile('avatar-${_fileId++}.png');
    final bytes = await rootBundle.load('assets/images/favicon.png');
    await file.writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      flush: true,
    );
    responseCompleter.complete(
      FileInfo(
        file,
        FileSource.Online,
        DateTime.now().add(const Duration(days: 1)),
        url,
      ),
    );
  }

  void fail(String url) {
    final responseCompleter = _responses[url];
    if (responseCompleter == null) {
      throw StateError('No pending avatar request for $url');
    }
    responseCompleter.completeError(
      StateError('Avatar failed for $url'),
      StackTrace.current,
    );
  }
}

class _UnusedFileService extends FileService {
  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) {
    throw UnsupportedError('Network is disabled in avatar tests.');
  }
}

class _ProfileHarness {
  _ProfileHarness({
    required this.userId,
    required this.user,
    this.exposeEmailStatus = false,
    this.textScaler = TextScaler.noScaling,
    this.locale = const Locale('ru'),
    this.nowProvider,
    this.avatarCacheManager,
  });

  String userId;
  UsersRecord? user;
  bool isLoggedIn = true;
  bool emailVerified = false;
  final bool exposeEmailStatus;
  final TextScaler textScaler;
  final Locale locale;
  final DateTime Function()? nowProvider;
  final BaseCacheManager? avatarCacheManager;
  Future<void> Function()? onSendEmailVerification;
  final _ProfileTestSources sources = _ProfileTestSources();

  String getUserId() => userId;
  UsersRecord? getUser() => user;
  bool getLoggedIn() => isLoggedIn;
  bool getEmailVerified() => emailVerified;

  Future<void> sendEmailVerification() async {
    await onSendEmailVerification?.call();
  }

  Widget buildApp() {
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
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: ProfileWidget(
        userIdProvider: getUserId,
        userDocumentProvider: getUser,
        loggedInProvider: getLoggedIn,
        emailVerifiedProvider: exposeEmailStatus ? getEmailVerified : null,
        emailVerificationSender:
            exposeEmailStatus ? sendEmailVerification : null,
        nowProvider: nowProvider,
        avatarCacheManager: avatarCacheManager,
        wordsStreamFactory: sources.wordsFactory,
        statsStreamFactory: sources.statsFactory,
      ),
    );
  }

  Future<void> close() => sources.close();
}

class _ProfileTestSources {
  final List<StreamController<ProfileQueryResult<UserWordsRecord>>> words = [];
  final List<StreamController<ProfileQueryResult<StatsRecord>>> stats = [];

  Stream<ProfileQueryResult<UserWordsRecord>> wordsFactory(
    DocumentReference _,
  ) {
    final controller =
        StreamController<ProfileQueryResult<UserWordsRecord>>.broadcast(
      sync: true,
    );
    words.add(controller);
    return controller.stream;
  }

  Stream<ProfileQueryResult<StatsRecord>> statsFactory(
    DocumentReference _,
  ) {
    final controller =
        StreamController<ProfileQueryResult<StatsRecord>>.broadcast(
      sync: true,
    );
    stats.add(controller);
    return controller.stream;
  }

  Future<void> close() async {
    for (final controller in [...words, ...stats]) {
      await controller.close();
    }
  }
}

String _text(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

String _avatarFallbackText(WidgetTester tester) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(profileAvatarFallbackKey),
        matching: find.byType(Text),
      ),
    )
    .data!;

List<ui.Image> _renderedAvatarImages(WidgetTester tester) => tester
    .widgetList<RawImage>(
      find.descendant(
        of: find.byKey(profileAvatarNetworkImageKey),
        matching: find.byType(RawImage),
      ),
    )
    .map((widget) => widget.image)
    .whereType<ui.Image>()
    .toList();

Future<void> _pumpUntilAvatarFrame(
  WidgetTester tester, {
  ui.Image? differentFrom,
}) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  for (var attempt = 0; attempt < 30; attempt++) {
    await tester.idle();
    await tester.pump(const Duration(milliseconds: 10));
    final images = _renderedAvatarImages(tester);
    if (images.isNotEmpty &&
        (differentFrom == null ||
            images.any((image) => !image.isCloneOf(differentFrom)))) {
      return;
    }
  }
  fail(
    'Avatar image stream did not emit the expected frame '
    '(network=${find.byKey(profileAvatarNetworkImageKey).evaluate().length}, '
    'raw=${find.byType(RawImage).evaluate().length}, '
    'avatarRaw=${find.descendant(of: find.byKey(profileAvatarNetworkImageKey), matching: find.byType(RawImage)).evaluate().length}, '
    'fallback=${find.byKey(profileAvatarFallbackKey).evaluate().length}).',
  );
}

void _expectEmailSemantics(
  WidgetTester tester, {
  required String statusLabel,
  String? actionLabel,
}) {
  final handle = tester.ensureSemantics();
  try {
    expect(
      tester.getSemantics(find.byKey(profileEmailStatusSemanticsKey)).label,
      statusLabel,
    );
    if (actionLabel != null) {
      expect(
        tester.getSemantics(find.byKey(profileEmailActionButtonKey)).label,
        actionLabel,
      );
    }
  } finally {
    handle.dispose();
  }
}

Map<Key, Rect> _captureRects(WidgetTester tester, Iterable<Key> keys) =>
    <Key, Rect>{
      for (final key in keys) key: tester.getRect(find.byKey(key)),
    };

void _expectSameRects(WidgetTester tester, Map<Key, Rect> expected) {
  for (final entry in expected.entries) {
    final actual = tester.getRect(find.byKey(entry.key));
    expect(actual.left, closeTo(entry.value.left, 0.01),
        reason: '${entry.key} x');
    expect(actual.top, closeTo(entry.value.top, 0.01),
        reason: '${entry.key} y');
    expect(
      actual.width,
      closeTo(entry.value.width, 0.01),
      reason: '${entry.key} width',
    );
    expect(
      actual.height,
      closeTo(entry.value.height, 0.01),
      reason: '${entry.key} height',
    );
  }
}

ProfileQueryResult<T> _result<T extends Object>(
  List<T> items, {
  bool confirmed = true,
}) {
  return ProfileQueryResult<T>(
    items: items,
    isServerConfirmed: confirmed,
  );
}

UsersRecord _user(
  String id, {
  required String name,
  required int totalCalls,
  String? email,
  String photoUrl = '',
  UserRole role = UserRole.student,
  SubscriptionStruct? subscription,
  GiftMinutesStruct? giftMinutes,
}) {
  return UsersRecord.getDocumentFromData(
    createUsersRecordData(
      uid: id,
      email: email ?? '$id@example.com',
      photoUrl: photoUrl,
      displayName: name,
      role: role,
      totalCalls: totalCalls,
      subscription: subscription,
      giftMinutes: giftMinutes,
      verifNS: role == UserRole.native_speaker,
      teacherAccreditationStatus: role == UserRole.native_speaker
          ? TeacherAccreditationStatus.approved
          : null,
    ),
    FirebaseFirestore.instance.doc('users/$id'),
  );
}

UserWordsRecord _word(String userId, String id) {
  return UserWordsRecord.getDocumentFromData(
    <String, dynamic>{},
    FirebaseFirestore.instance.doc('users/$userId/userWords/$id'),
  );
}

StatsRecord _stats(
  String userId, {
  required String calls,
  required String minutes,
  String earned = '0',
}) {
  return StatsRecord.getDocumentFromData(
    createStatsRecordData(
      totalCalls: calls,
      totalMinutes: minutes,
      totalEarned: earned,
      isAllTime: true,
    ),
    FirebaseFirestore.instance.doc('users/$userId/stats/all-time'),
  );
}
