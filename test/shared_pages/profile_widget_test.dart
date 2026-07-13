import 'dart:async';

import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
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
}

class _ProfileHarness {
  _ProfileHarness({required this.userId, required this.user});

  String userId;
  UsersRecord? user;
  bool isLoggedIn = true;
  final _ProfileTestSources sources = _ProfileTestSources();

  String getUserId() => userId;
  UsersRecord? getUser() => user;
  bool getLoggedIn() => isLoggedIn;

  Widget buildApp() {
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
      home: ProfileWidget(
        userIdProvider: getUserId,
        userDocumentProvider: getUser,
        loggedInProvider: getLoggedIn,
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
  UserRole role = UserRole.student,
}) {
  return UsersRecord.getDocumentFromData(
    createUsersRecordData(
      uid: id,
      email: '$id@example.com',
      displayName: name,
      role: role,
      totalCalls: totalCalls,
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
