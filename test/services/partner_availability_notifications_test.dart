import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/services/partner_availability_notifications.dart';
import 'package:small_talk/services/passive_search_service.dart';
import 'package:small_talk/services/match_coordinator.dart';

void main() {
  final now = DateTime.utc(2026, 9, 5, 12);
  Map<String, dynamic> payload(
          {String recipient = 'user', DateTime? expires}) =>
      {
        'type': 'partner_available',
        'recipientId': recipient,
        'requestId': 'consent',
        'activeUserId': 'partner',
        'activeRequestId': 'active',
        'expiresAt':
            (expires ?? now.add(const Duration(minutes: 2))).toIso8601String(),
      };

  Future<BuildContext> mount(
    WidgetTester tester, {
    ValueNotifier<Locale>? locale,
  }) async {
    late BuildContext context;
    final localeListenable = locale ?? ValueNotifier(const Locale('en'));
    if (locale == null) addTearDown(localeListenable.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<Locale>(
        valueListenable: localeListenable,
        builder: (_, currentLocale, __) => MaterialApp(
          locale: currentLocale,
          supportedLocales: const [Locale('ru'), Locale('en')],
          localizationsDelegates: const [
            FFLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FallbackMaterialLocalizationDelegate(),
            FallbackCupertinoLocalizationDelegate(),
          ],
          home: Scaffold(body: Builder(builder: (value) {
            context = value;
            return const Text('Dashboard');
          })),
        ),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    return context;
  }

  test('normal invitation parser rejects malformed, call and self payloads',
      () {
    expect(PartnerAvailabilityInvitation.fromData(payload()), isNotNull);
    expect(
        PartnerAvailabilityInvitation.fromData({
          ...payload(),
          'type': 'incoming_call',
        }),
        isNull);
    for (final key in [
      'recipientId',
      'requestId',
      'activeUserId',
      'activeRequestId',
      'expiresAt'
    ]) {
      expect(
          PartnerAvailabilityInvitation.fromData({...payload()}..remove(key)),
          isNull);
    }
    expect(
        PartnerAvailabilityInvitation.fromData(
            {...payload(), 'activeUserId': 'user'}),
        isNull);
  });

  testWidgets(
      'cold tap waits for auth and duplicate taps create one connection',
      (tester) async {
    final context = await mount(tester);
    final response = Completer<Map<String, dynamic>>();
    final calls = <Map<String, dynamic>>[];
    var permissions = 0;
    var connections = 0;
    final handler = PartnerAvailabilityNotifications(
      contextReader: () => context,
      clock: () => now,
      mediaPermissions: () async {
        permissions++;
        return true;
      },
      onConnected: (_) async => connections++,
      service: PassiveSearchService(invoke: (name, data) {
        expectSync(name, 'connectPassiveSearch');
        calls.add(data);
        return response.future;
      }),
    );
    handler.handleTap(payload());
    await tester.pump();
    expect(calls, isEmpty);
    expect(permissions, 0);
    handler.setUser('user');
    handler.handleTap(payload());
    await tester.pump();
    expect(calls, [
      {
        'requestId': 'consent',
        'activeUserId': 'partner',
        'activeRequestId': 'active'
      }
    ]);
    response.complete({'status': 'matched', 'sessionId': 'session'});
    await tester.pump();
    handler.handleTap(payload());
    await tester.pump();
    expect(calls, hasLength(1));
    expect(connections, 1);
    await handler.dispose();
  });

  testWidgets('foreground invitation received before auth is shown after auth',
      (tester) async {
    final locale = ValueNotifier(const Locale('ru'));
    addTearDown(locale.dispose);
    final context = await mount(tester, locale: locale);
    var connections = 0;
    final handler = PartnerAvailabilityNotifications(
      contextReader: () => context,
      clock: () => now,
      mediaPermissions: () async => true,
      onConnected: (_) async => connections++,
      service: PassiveSearchService(
          invoke: (_, __) => throw StateError('must wait for a tap')),
    );
    handler.handleForeground({
      ...payload(),
      'bodyRu': 'Маша ждёт собеседника',
      'bodyEn': 'Masha is waiting',
    });
    await tester.pump();
    expect(find.text('Masha is waiting'), findsNothing);

    locale.value = const Locale('en');
    await tester.pump();
    handler.setUser('user');
    await tester.pump();
    expect(find.text('Masha is waiting'), findsOneWidget);
    expect(connections, 0);
    await handler.dispose();
  });

  testWidgets('foreign and stale taps do not request media or call backend',
      (tester) async {
    final context = await mount(tester);
    var permissions = 0;
    final handler = PartnerAvailabilityNotifications(
      contextReader: () => context,
      clock: () => now,
      mediaPermissions: () async {
        permissions++;
        return true;
      },
      service: PassiveSearchService(
          invoke: (_, __) => throw StateError('must not connect')),
    )..setUser('user');
    handler.handleTap(payload(recipient: 'someone-else'));
    handler.handleTap(payload(expires: now));
    await tester.pump();
    expect(permissions, 0);
    expect(
        find.textContaining('busy or has stopped searching'), findsOneWidget);
    await handler.dispose();
  });

  testWidgets('unresolved Stop prevents a notification from reserving a pair',
      (tester) async {
    final context = await mount(tester);
    MatchCoordinator.instance.noteLocalSearchCancellation('stopped-consent');
    var connects = 0;
    var permissions = 0;
    final handler = PartnerAvailabilityNotifications(
      contextReader: () => context,
      clock: () => now,
      mediaPermissions: () async {
        permissions++;
        return true;
      },
      service: PassiveSearchService(invoke: (_, __) async {
        connects++;
        return {};
      }),
    )..setUser('user');
    handler.handleTap({...payload(), 'requestId': 'stopped-consent'});
    await tester.pump();
    expect(connects, 0);
    expect(permissions, 0);
    expect(find.textContaining('Finish stopping your search'), findsOneWidget);
    await handler.dispose();
  });

  testWidgets(
      'permission refusal and account change during permission cannot connect',
      (tester) async {
    final context = await mount(tester);
    final permission = Completer<bool>();
    var calls = 0;
    final handler = PartnerAvailabilityNotifications(
      contextReader: () => context,
      clock: () => now,
      mediaPermissions: () => permission.future,
      service: PassiveSearchService(invoke: (_, __) async {
        calls++;
        return {};
      }),
    )..setUser('user');
    handler.handleTap(payload());
    handler.setUser(null);
    handler.setUser('someone-else');
    permission.complete(true);
    await tester.pump();
    expect(calls, 0);
    await handler.dispose();
  });

  testWidgets(
      'busy partner keeps queue and network failure offers explicit retry',
      (tester) async {
    final context = await mount(tester);
    var calls = 0;
    final handler = PartnerAvailabilityNotifications(
      contextReader: () => context,
      clock: () => now,
      mediaPermissions: () async => true,
      service: PassiveSearchService(invoke: (name, data) async {
        expectSync(name, 'connectPassiveSearch');
        if (++calls == 1) throw StateError('offline');
        return {'status': 'unavailable'};
      }),
    )..setUser('user');
    handler.handleTap(payload());
    await tester.pump();
    expect(calls, 1);
    expect(find.text('Join'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Join'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 2);
    expect(find.textContaining('remain on the waiting list'), findsOneWidget);
    await handler.dispose();
  });
}
