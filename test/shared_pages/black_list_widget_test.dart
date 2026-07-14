import 'dart:async';

import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/auth/firebase_auth/auth_util.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/backend/schema/enums/enums.dart';
import 'package:small_talk/components/basic_page_header.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/shared_pages/black_list/black_list_widget.dart';

const _supportedLocales = [
  Locale('ru'),
  Locale('en'),
];

const List<LocalizationsDelegate<dynamic>> _localizationsDelegates = [
  FFLocalizationsDelegate(),
  FallbackMaterialLocalizationDelegate(),
  FallbackCupertinoLocalizationDelegate(),
];

Widget _buildTestApp({
  Stream<BlackListOwnerState>? ownerStateStream,
  Stream<String>? authUidStream,
  BlackListOwnerStateStreamFactory? ownerStateStreamFactory,
  required String Function() currentUidProvider,
  required BlackListProfileLoader profileLoader,
  BlackListBlockedUserRemover? blockedUserRemover,
  Locale locale = const Locale('ru'),
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: _supportedLocales,
    localizationsDelegates: _localizationsDelegates,
    home: BlackListWidget(
      ownerStateStream: ownerStateStream,
      authUidStream: authUidStream,
      ownerStateStreamFactory: ownerStateStreamFactory,
      currentUidProvider: currentUidProvider,
      profileLoader: profileLoader,
      blockedUserRemover: blockedUserRemover,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    await FFLocalizations.initialize();
  });

  tearDown(() {
    currentUser = null;
    currentUserDocument = null;
  });

  group('blacklist owner snapshot resolver', () {
    test('withholds empty cache and pending writes until server confirmation',
        () {
      final blockedUser = UsersRecord.collection.doc('blocked-a');

      final cachedEmpty = resolveBlackListOwnerDocumentSnapshot(
        expectedOwnerUid: 'user-a',
        snapshot: _ownerSnapshot(
          ownerUid: 'user-a',
          isFromCache: true,
        ),
      );
      final pendingEmpty = resolveBlackListOwnerDocumentSnapshot(
        expectedOwnerUid: 'user-a',
        snapshot: _ownerSnapshot(
          ownerUid: 'user-a',
          hasPendingWrites: true,
        ),
      );
      final cachedData = resolveBlackListOwnerDocumentSnapshot(
        expectedOwnerUid: 'user-a',
        snapshot: _ownerSnapshot(
          ownerUid: 'user-a',
          blockedUsers: [blockedUser],
          isFromCache: true,
        ),
      );
      final serverEmpty = resolveBlackListOwnerDocumentSnapshot(
        expectedOwnerUid: 'user-a',
        snapshot: _ownerSnapshot(ownerUid: 'user-a'),
      );

      expect(cachedEmpty, isA<BlackListOwnerLoading>());
      expect(pendingEmpty, isA<BlackListOwnerLoading>());
      expect(cachedData, isA<BlackListOwnerData>());
      expect(
        (cachedData as BlackListOwnerData).isServerConfirmed,
        isFalse,
      );
      expect(serverEmpty, isA<BlackListOwnerData>());
      expect(
        (serverEmpty as BlackListOwnerData).isServerConfirmed,
        isTrue,
      );
      expect(serverEmpty.blockedUsers, isEmpty);
    });

    test('adapter rejects another owner and propagates source errors',
        () async {
      final blockedByA = UsersRecord.collection.doc('blocked-by-a');
      final sourceError = StateError('owner source failed');
      final snapshots = Stream<BlackListOwnerDocumentSnapshot>.multi(
        (controller) {
          controller.add(
            _ownerSnapshot(
              ownerUid: 'user-a',
              blockedUsers: [blockedByA],
            ),
          );
          controller.addError(sourceError);
          controller.close();
        },
      );

      await expectLater(
        adaptBlackListOwnerDocumentSnapshots(
          expectedOwnerUid: 'user-b',
          snapshots: snapshots,
        ),
        emitsInOrder(<Object>[
          isA<BlackListOwnerLoading>()
              .having((state) => state.ownerUid, 'ownerUid', 'user-b'),
          emitsError(same(sourceError)),
        ]),
      );
    });

    test('server-confirmed missing owner is an error, never empty', () {
      expect(
        () => resolveBlackListOwnerDocumentSnapshot(
          expectedOwnerUid: 'user-a',
          snapshot: _ownerSnapshot(
            ownerUid: 'user-a',
            documentExists: false,
          ),
        ),
        throwsStateError,
      );

      expect(
        resolveBlackListOwnerDocumentSnapshot(
          expectedOwnerUid: 'user-a',
          snapshot: _ownerSnapshot(
            ownerUid: 'user-a',
            documentExists: false,
            isFromCache: true,
          ),
        ),
        isA<BlackListOwnerLoading>(),
      );
    });
  });

  testWidgets(
      'retains owner rows through pending empty until server confirms empty',
      (tester) async {
    final controller =
        StreamController<BlackListOwnerDocumentSnapshot>(sync: true);
    final blockedUser = UsersRecord.collection.doc('blocked-a');
    addTearDown(() => unawaited(controller.close()));

    await tester.pumpWidget(
      _buildTestApp(
        ownerStateStream: adaptBlackListOwnerDocumentSnapshots(
          expectedOwnerUid: 'user-a',
          snapshots: controller.stream,
        ),
        currentUidProvider: () => 'user-a',
        profileLoader: (reference) async => _profile(
          reference.id,
          displayName: 'Анна',
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(blackListLoadingKey), findsOneWidget);
    expect(find.byKey(blackListEmptyKey), findsNothing);
    expect(find.byType(BasicPageHeader), findsOneWidget);

    controller.add(
      _ownerSnapshot(
        ownerUid: 'user-a',
        isFromCache: true,
      ),
    );
    await tester.pump();

    expect(find.byKey(blackListLoadingKey), findsOneWidget);
    expect(find.byKey(blackListEmptyKey), findsNothing);

    controller.add(
      _ownerSnapshot(
        ownerUid: 'user-a',
        blockedUsers: [blockedUser],
        isFromCache: true,
      ),
    );
    await tester.pump();

    expect(find.byKey(blackListListKey), findsOneWidget);
    expect(find.byKey(blackListUserRowKey(blockedUser)), findsOneWidget);
    expect(find.byKey(blackListEmptyKey), findsNothing);

    controller.add(
      _ownerSnapshot(
        ownerUid: 'user-a',
        hasPendingWrites: true,
      ),
    );
    await tester.pump();

    expect(find.byKey(blackListLoadingKey), findsNothing);
    expect(find.byKey(blackListEmptyKey), findsNothing);
    expect(find.byKey(blackListListKey), findsOneWidget);
    expect(find.byKey(blackListUserRowKey(blockedUser)), findsOneWidget);

    controller.add(_ownerSnapshot(ownerUid: 'user-a'));
    await tester.pump();

    expect(find.byKey(blackListEmptyKey), findsOneWidget);
    expect(find.byKey(blackListLoadingKey), findsNothing);
    expect(find.byKey(blackListListKey), findsNothing);
    expect(find.byType(BasicPageHeader), findsOneWidget);
  });

  testWidgets('shows source error instead of authoritative empty',
      (tester) async {
    final controller =
        StreamController<BlackListOwnerDocumentSnapshot>(sync: true);
    addTearDown(() => unawaited(controller.close()));

    await tester.pumpWidget(
      _buildTestApp(
        ownerStateStream: adaptBlackListOwnerDocumentSnapshots(
          expectedOwnerUid: 'user-a',
          snapshots: controller.stream,
        ),
        currentUidProvider: () => 'user-a',
        profileLoader: (_) async => null,
      ),
    );
    await tester.pump();

    expect(find.byKey(blackListLoadingKey), findsOneWidget);
    expect(find.byKey(blackListEmptyKey), findsNothing);

    controller.addError(StateError('owner stream failed'));
    await tester.pump();

    expect(find.byKey(blackListErrorKey), findsOneWidget);
    expect(find.byKey(blackListEmptyKey), findsNothing);
    expect(find.byKey(blackListListKey), findsNothing);
    expect(find.byType(BasicPageHeader), findsOneWidget);
  });

  testWidgets('cold error retry resubscribes and can recover', (tester) async {
    final source = _ReopenableOwnerStateSource();

    await tester.pumpWidget(
      _buildTestApp(
        ownerStateStream: source.stream,
        currentUidProvider: () => 'user-a',
        profileLoader: (_) async => null,
      ),
    );
    await tester.pump();

    expect(source.listenCount, 1);
    source.addError(StateError('owner stream failed'));
    await tester.pump();
    expect(find.byKey(blackListErrorKey), findsOneWidget);

    await tester.tap(find.byKey(blackListRetryButtonKey));
    await tester.pump();
    await tester.pump();

    expect(source.listenCount, greaterThan(1));
    expect(find.byKey(blackListLoadingKey), findsOneWidget);
    expect(find.byKey(blackListErrorKey), findsNothing);

    source.add(
      BlackListOwnerData(
        ownerUid: 'user-a',
        blockedUsers: const [],
        isServerConfirmed: true,
      ),
    );
    await tester.pump();

    expect(find.byKey(blackListEmptyKey), findsOneWidget);
    expect(find.byKey(blackListErrorKey), findsNothing);
  });

  testWidgets('data error keeps rows and exposes compact retry',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    final source = _ReopenableOwnerStateSource();
    final blockedUser = UsersRecord.collection.doc('blocked-refresh');

    try {
      await tester.pumpWidget(
        _buildTestApp(
          ownerStateStream: source.stream,
          currentUidProvider: () => 'user-a',
          profileLoader: (reference) async => _profile(
            reference.id,
            displayName: 'Анна',
          ),
        ),
      );
      await tester.pump();
      source.add(
        BlackListOwnerData(
          ownerUid: 'user-a',
          blockedUsers: [blockedUser],
          isServerConfirmed: true,
        ),
      );
      await tester.pump();
      final rowTopBeforeError = tester.getTopLeft(
        find.byKey(blackListUserRowKey(blockedUser)),
      );

      source.addError(StateError('refresh failed'));
      await tester.pump();

      final refreshError = tester.widget<Semantics>(
        find.byKey(blackListRefreshErrorKey),
      );
      expect(find.byKey(blackListListKey), findsOneWidget);
      expect(find.byKey(blackListUserRowKey(blockedUser)), findsOneWidget);
      expect(find.byKey(blackListErrorKey), findsNothing);
      expect(
        tester.getTopLeft(find.byKey(blackListUserRowKey(blockedUser))),
        rowTopBeforeError,
      );
      expect(refreshError.properties.liveRegion, isTrue);
      expect(refreshError.properties.button, isTrue);
      expect(
        refreshError.properties.label,
        'Не удалось обновить чёрный список. Повторить',
      );

      await tester.tap(find.byKey(blackListRefreshErrorKey));
      await tester.pump();
      await tester.pump();

      expect(source.listenCount, greaterThan(1));
      expect(find.byKey(blackListRefreshErrorKey), findsNothing);
      expect(find.byKey(blackListUserRowKey(blockedUser)), findsOneWidget);

      source.add(const BlackListOwnerLoading(ownerUid: 'user-a'));
      await tester.pump();
      expect(find.byKey(blackListUserRowKey(blockedUser)), findsOneWidget);
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('partial cold rows keep compact error and retry resubscribes',
      (tester) async {
    final source = _ReopenableOwnerStateSource();
    final blockedUser = UsersRecord.collection.doc('blocked-partial-cold');

    await tester.pumpWidget(
      _buildTestApp(
        ownerStateStream: source.stream,
        currentUidProvider: () => 'user-a',
        profileLoader: (reference) async => _profile(
          reference.id,
          displayName: 'Частично загруженный пользователь',
        ),
      ),
    );
    await tester.pump();
    source.add(
      BlackListOwnerData(
        ownerUid: 'user-a',
        blockedUsers: [blockedUser],
        isServerConfirmed: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(blackListUserRowKey(blockedUser)), findsOneWidget);
    expect(find.byKey(blackListRefreshErrorKey), findsNothing);
    expect(source.listenCount, 1);

    source.addError(StateError('partial source failed'));
    await tester.pump();
    await tester.pump();

    final retry = find.byKey(blackListRefreshErrorKey);
    expect(find.byKey(blackListUserRowKey(blockedUser)), findsOneWidget);
    expect(find.text('Частично загруженный пользователь'), findsOneWidget);
    expect(retry, findsOneWidget);
    expect(retry.hitTestable(), findsOneWidget);
    expect(find.byKey(blackListErrorKey), findsNothing);
    expect(find.byKey(blackListLoadingKey), findsNothing);

    await tester.tap(retry);
    await tester.pump();

    expect(source.listenCount, 2);
    expect(find.byKey(blackListUserRowKey(blockedUser)), findsOneWidget);
    expect(find.byKey(blackListRefreshingKey), findsOneWidget);
    expect(find.byKey(blackListRefreshErrorKey), findsNothing);
  });

  testWidgets('confirmed empty stays visible while refresh and retry fail',
      (tester) async {
    final source = _ReopenableOwnerStateSource();

    await tester.pumpWidget(
      _buildTestApp(
        ownerStateStream: source.stream,
        currentUidProvider: () => 'user-a',
        profileLoader: (_) async => null,
      ),
    );
    await tester.pump();
    source.add(
      BlackListOwnerData(
        ownerUid: 'user-a',
        blockedUsers: const [],
        isServerConfirmed: true,
      ),
    );
    await tester.pump();
    expect(find.byKey(blackListEmptyKey), findsOneWidget);

    source.add(const BlackListOwnerLoading(ownerUid: 'user-a'));
    await tester.pump();

    expect(find.byKey(blackListEmptyKey), findsOneWidget);
    expect(find.byKey(blackListRefreshingKey), findsOneWidget);
    expect(find.byKey(blackListLoadingKey), findsNothing);
    expect(find.byKey(blackListErrorKey), findsNothing);

    source.addError(StateError('refresh failed'));
    await tester.pump();

    expect(find.byKey(blackListEmptyKey), findsOneWidget);
    expect(find.byKey(blackListRefreshErrorKey), findsOneWidget);
    expect(find.byKey(blackListLoadingKey), findsNothing);
    expect(find.byKey(blackListErrorKey), findsNothing);

    await tester.tap(find.byKey(blackListRefreshErrorKey));
    await tester.pump();

    expect(source.listenCount, greaterThan(1));
    expect(find.byKey(blackListEmptyKey), findsOneWidget);
    expect(find.byKey(blackListRefreshingKey), findsOneWidget);
    expect(find.byKey(blackListRefreshErrorKey), findsNothing);
    expect(find.byKey(blackListLoadingKey), findsNothing);

    source.addError(StateError('retry failed'));
    await tester.pump();

    expect(find.byKey(blackListEmptyKey), findsOneWidget);
    expect(find.byKey(blackListRefreshErrorKey), findsOneWidget);
    expect(find.byKey(blackListLoadingKey), findsNothing);
    expect(find.byKey(blackListErrorKey), findsNothing);
  });

  testWidgets('initial loading is localized, live, and hides spinner semantics',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    try {
      for (final (locale, label, title) in <(Locale, String, String)>[
        (
          const Locale('ru'),
          'Загрузка чёрного списка',
          'Черный список',
        ),
        (
          const Locale('en'),
          'Loading blocked list',
          'Blacklist',
        ),
      ]) {
        await tester.pumpWidget(
          _buildTestApp(
            locale: locale,
            ownerStateStream: const Stream<BlackListOwnerState>.empty(),
            currentUidProvider: () => 'user-a',
            profileLoader: (_) async => null,
          ),
        );
        await tester.pump();

        final loadingState = tester.widget<Semantics>(
          find.byKey(blackListLoadingKey),
        );
        expect(loadingState.properties.liveRegion, isTrue);
        expect(loadingState.properties.label, label);
        expect(
          find.descendant(
            of: find.byKey(blackListLoadingKey),
            matching: find.byType(ExcludeSemantics),
          ),
          findsOneWidget,
        );
        expect(find.text(title), findsOneWidget);
        expect(find.text('Ченый список'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('error state is localized and announced without empty copy',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    try {
      for (final (locale, title, message, retryLabel, retrySemanticsLabel)
          in <(Locale, String, String, String, String)>[
        (
          const Locale('ru'),
          'Не удалось загрузить чёрный список',
          'Попробуйте позже.',
          'Повторить',
          'Повторить загрузку чёрного списка',
        ),
        (
          const Locale('en'),
          'Unable to load blocked list',
          'Please try again later.',
          'Try again',
          'Retry loading blocked list',
        ),
      ]) {
        await tester.pumpWidget(
          _buildTestApp(
            locale: locale,
            ownerStateStream: Stream<BlackListOwnerState>.error(
              StateError('owner stream failed'),
            ),
            currentUidProvider: () => 'user-a',
            profileLoader: (_) async => null,
          ),
        );
        await tester.pumpAndSettle();

        final errorState = tester.widget<Semantics>(
          find.byKey(blackListErrorKey),
        );
        expect(find.text(title), findsOneWidget);
        expect(find.text(message), findsOneWidget);
        expect(find.text(retryLabel), findsOneWidget);
        expect(find.text('Здесь пока пусто'), findsNothing);
        expect(find.text('Nothing here yet'), findsNothing);
        expect(errorState.properties.liveRegion, isTrue);
        expect(errorState.properties.label, '$title. $message');
        expect(
          tester.getSemantics(find.byKey(blackListRetryButtonKey)).label,
          retrySemanticsLabel,
        );
        expect(find.byType(BasicPageHeader), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('rejects mismatched owner data and clears rows on uid or logout',
      (tester) async {
    final controller = StreamController<BlackListOwnerState>(sync: true);
    final userAReference = UsersRecord.collection.doc('blocked-by-a');
    final userBReference = UsersRecord.collection.doc('blocked-by-b');
    var currentUid = 'user-a';
    addTearDown(() => unawaited(controller.close()));

    await tester.pumpWidget(
      _buildTestApp(
        ownerStateStream: controller.stream,
        currentUidProvider: () => currentUid,
        profileLoader: (reference) async => _profile(
          reference.id,
          displayName: reference.id,
        ),
      ),
    );
    await tester.pump();

    controller.add(
      BlackListOwnerData(
        ownerUid: 'user-a',
        blockedUsers: [userAReference],
        isServerConfirmed: true,
      ),
    );
    await tester.pump();
    expect(find.byKey(blackListUserRowKey(userAReference)), findsOneWidget);

    currentUid = 'user-b';
    controller.add(
      BlackListOwnerData(
        ownerUid: 'user-a',
        blockedUsers: [userAReference],
        isServerConfirmed: true,
      ),
    );
    await tester.pump();

    expect(find.byKey(blackListLoadingKey), findsOneWidget);
    expect(find.byKey(blackListUserRowKey(userAReference)), findsNothing);
    expect(find.byKey(blackListEmptyKey), findsNothing);

    controller.add(
      BlackListOwnerData(
        ownerUid: 'user-b',
        blockedUsers: [userBReference],
        isServerConfirmed: true,
      ),
    );
    await tester.pump();
    expect(find.byKey(blackListUserRowKey(userBReference)), findsOneWidget);

    controller.add(
      BlackListOwnerData(
        ownerUid: 'user-a',
        blockedUsers: [userAReference],
        isServerConfirmed: true,
      ),
    );
    await tester.pump();
    expect(find.byKey(blackListLoadingKey), findsNothing);
    expect(find.byKey(blackListUserRowKey(userAReference)), findsNothing);
    expect(find.byKey(blackListUserRowKey(userBReference)), findsOneWidget);

    currentUid = '';
    controller.add(
      BlackListOwnerData(
        ownerUid: 'user-b',
        blockedUsers: [],
        isServerConfirmed: true,
      ),
    );
    await tester.pump();

    expect(find.byKey(blackListLoadingKey), findsOneWidget);
    expect(find.byKey(blackListEmptyKey), findsNothing);
    expect(find.byKey(blackListListKey), findsNothing);
  });

  testWidgets(
      'ignores an old-owner error before auth stream confirms the new uid',
      (tester) async {
    final controller = StreamController<BlackListOwnerState>(sync: true);
    final userAReference = UsersRecord.collection.doc('blocked-by-stale-a');
    final userBReference = UsersRecord.collection.doc('blocked-by-current-b');
    var currentUid = 'user-a';
    addTearDown(() => unawaited(controller.close()));

    await tester.pumpWidget(
      _buildTestApp(
        ownerStateStream: controller.stream,
        currentUidProvider: () => currentUid,
        profileLoader: (reference) async => _profile(
          reference.id,
          displayName: reference.id,
        ),
      ),
    );
    await tester.pump();

    controller.add(
      BlackListOwnerData(
        ownerUid: 'user-a',
        blockedUsers: [userAReference],
        isServerConfirmed: true,
      ),
    );
    await tester.pump();
    expect(find.byKey(blackListUserRowKey(userAReference)), findsOneWidget);

    currentUid = 'user-b';
    controller.addError(StateError('late user-a failure'));
    await tester.pump();

    expect(find.byKey(blackListUserRowKey(userAReference)), findsNothing);
    expect(find.byKey(blackListLoadingKey), findsOneWidget);
    expect(find.byKey(blackListErrorKey), findsNothing);
    expect(find.byKey(blackListEmptyKey), findsNothing);

    controller.add(const BlackListOwnerLoading(ownerUid: 'user-b'));
    await tester.pump();
    expect(find.byKey(blackListLoadingKey), findsOneWidget);
    expect(find.byKey(blackListErrorKey), findsNothing);

    controller.add(
      BlackListOwnerData(
        ownerUid: 'user-b',
        blockedUsers: [userBReference],
        isServerConfirmed: true,
      ),
    );
    await tester.pump();

    expect(find.byKey(blackListUserRowKey(userBReference)), findsOneWidget);
    expect(find.byKey(blackListLoadingKey), findsNothing);
    expect(find.byKey(blackListErrorKey), findsNothing);
  });

  testWidgets(
      'late A profile cannot render after direct uid changes before owner event',
      (tester) async {
    final controller = StreamController<BlackListOwnerState>(sync: true);
    final profileCompleter = Completer<UserPublicProfilesRecord?>();
    final blockedUser = UsersRecord.collection.doc('late-profile-a');
    var currentUid = 'user-a';
    addTearDown(() => unawaited(controller.close()));
    addTearDown(() {
      if (!profileCompleter.isCompleted) {
        profileCompleter.complete(null);
      }
    });

    await tester.pumpWidget(
      _buildTestApp(
        ownerStateStream: controller.stream,
        currentUidProvider: () => currentUid,
        profileLoader: (_) => profileCompleter.future,
      ),
    );
    await tester.pump();
    controller.add(
      BlackListOwnerData(
        ownerUid: 'user-a',
        blockedUsers: [blockedUser],
        isServerConfirmed: true,
      ),
    );
    await tester.pump();
    expect(find.byKey(blackListUserRowKey(blockedUser)), findsOneWidget);

    currentUid = 'user-b';
    profileCompleter.complete(
      _profile(
        blockedUser.id,
        displayName: 'Поздний профиль A',
        approvedNativeSpeaker: true,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Поздний профиль A'), findsNothing);
    expect(find.byKey(blackListLoadingKey), findsOneWidget);
    expect(find.byKey(blackListListKey), findsNothing);
    expect(find.byKey(blackListEmptyKey), findsNothing);
    expect(find.byKey(blackListErrorKey), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loaded A row refuses navigation after a direct uid change',
      (tester) async {
    final controller = StreamController<BlackListOwnerState>(sync: true);
    final blockedUser = UsersRecord.collection.doc('guarded-profile-a');
    var currentUid = 'user-a';
    addTearDown(() => unawaited(controller.close()));

    await tester.pumpWidget(
      _buildTestApp(
        ownerStateStream: controller.stream,
        currentUidProvider: () => currentUid,
        profileLoader: (_) async => _profile(
          blockedUser.id,
          displayName: 'Открываемый профиль A',
          approvedNativeSpeaker: true,
        ),
      ),
    );
    await tester.pump();
    controller.add(
      BlackListOwnerData(
        ownerUid: 'user-a',
        blockedUsers: [blockedUser],
        isServerConfirmed: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Открываемый профиль A'), findsOneWidget);

    currentUid = 'user-b';
    await tester.tap(find.byKey(blackListUserRowKey(blockedUser)));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Открываемый профиль A'), findsNothing);
    expect(find.byKey(blackListLoadingKey), findsOneWidget);
  });

  testWidgets(
      'raw B to A without a frame creates fresh A2 source and profile epoch',
      (tester) async {
    for (final lateA1Fails in <bool>[false, true]) {
      final authUidController = StreamController<String>(sync: true);
      final ownerSources = _OwnerStateSourceFactory();
      final a1Profile = Completer<UserPublicProfilesRecord?>();
      final a2Profile = Completer<UserPublicProfilesRecord?>();
      final sharedAReference = UsersRecord.collection
          .doc('shared-a-${lateA1Fails ? 'error' : 'ok'}');
      var currentUid = 'user-a';
      var aRequestCount = 0;

      Future<UserPublicProfilesRecord?> loadProfile(
        DocumentReference reference,
      ) {
        expect(reference, sharedAReference);
        aRequestCount += 1;
        return aRequestCount == 1 ? a1Profile.future : a2Profile.future;
      }

      await tester.pumpWidget(
        _buildTestApp(
          authUidStream: authUidController.stream,
          ownerStateStreamFactory: ownerSources.create,
          currentUidProvider: () => currentUid,
          profileLoader: loadProfile,
        ),
      );
      await tester.pump();
      authUidController.add('user-a');
      expect(ownerSources.listenCount('user-a'), 1);
      final a1Source = ownerSources.latest('user-a');
      a1Source.add(
        BlackListOwnerData(
          ownerUid: 'user-a',
          blockedUsers: [sharedAReference],
          isServerConfirmed: true,
        ),
      );
      await tester.pump();
      expect(aRequestCount, 1);

      currentUid = 'user-b';
      authUidController.add('user-b');
      currentUid = 'user-a';
      authUidController.add('user-a');

      expect(ownerSources.listenCount('user-b'), 1);
      expect(ownerSources.listenCount('user-a'), 2);
      final a2Source = ownerSources.latest('user-a');
      a2Source.add(
        BlackListOwnerData(
          ownerUid: 'user-a',
          blockedUsers: [sharedAReference],
          isServerConfirmed: true,
        ),
      );
      await tester.pump();
      expect(aRequestCount, 2);
      expect(find.byKey(blackListLoadingKey), findsNothing);

      a2Profile.complete(
        _profile(sharedAReference.id, displayName: 'Актуальный профиль A2'),
      );
      await tester.pump();
      expect(find.text('Актуальный профиль A2'), findsOneWidget);

      if (lateA1Fails) {
        a1Profile.completeError(StateError('late A1 profile error'));
      } else {
        a1Profile.complete(
          _profile(sharedAReference.id, displayName: 'Устаревший профиль A1'),
        );
      }
      a1Source.addError(StateError('late A1 owner source error'));
      await tester.pump();

      expect(find.text('Актуальный профиль A2'), findsOneWidget);
      expect(find.text('Устаревший профиль A1'), findsNothing);
      expect(find.byKey(blackListLoadingKey), findsNothing);
      expect(find.byKey(blackListErrorKey), findsNothing);
      expect(find.byKey(blackListRefreshErrorKey), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      unawaited(authUidController.close());
      ownerSources.close();
    }
  });

  testWidgets('profile loading, data, and error keep keyed rows at 72px',
      (tester) async {
    final controller = StreamController<BlackListOwnerState>(sync: true);
    final pendingProfile = Completer<UserPublicProfilesRecord?>();
    final pendingReference = UsersRecord.collection.doc('pending-profile');
    final dataReference = UsersRecord.collection.doc('data-profile');
    final errorReference = UsersRecord.collection.doc('error-profile');
    addTearDown(() => unawaited(controller.close()));
    addTearDown(() {
      if (!pendingProfile.isCompleted) {
        pendingProfile.complete(null);
      }
    });

    Future<UserPublicProfilesRecord?> loadProfile(
      DocumentReference reference,
    ) {
      if (reference == pendingReference) {
        return pendingProfile.future;
      }
      if (reference == dataReference) {
        return Future.value(
          _profile(reference.id, displayName: 'Загруженный профиль'),
        );
      }
      return Future.error(StateError('profile unavailable'));
    }

    await tester.pumpWidget(
      _buildTestApp(
        ownerStateStream: controller.stream,
        currentUidProvider: () => 'user-a',
        profileLoader: loadProfile,
      ),
    );
    await tester.pump();
    controller.add(
      BlackListOwnerData(
        ownerUid: 'user-a',
        blockedUsers: [
          pendingReference,
          dataReference,
          errorReference,
        ],
        isServerConfirmed: true,
      ),
    );
    await tester.pump();

    _expectRowHeight(tester, pendingReference);
    _expectRowHeight(tester, dataReference);
    _expectRowHeight(tester, errorReference);

    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Загруженный профиль'), findsOneWidget);
    expect(find.text('Пользователь'), findsWidgets);
    _expectRowHeight(tester, pendingReference);
    _expectRowHeight(tester, dataReference);
    _expectRowHeight(tester, errorReference);

    pendingProfile.complete(
      _profile(pendingReference.id, displayName: 'Поздний профиль'),
    );
    await tester.pump();

    expect(find.text('Поздний профиль'), findsOneWidget);
    _expectRowHeight(tester, pendingReference);
    _expectRowHeight(tester, dataReference);
    _expectRowHeight(tester, errorReference);
  });

  testWidgets('delete action has localized semantics and stable geometry',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();
    final blockedUser = UsersRecord.collection.doc('blocked-a11y');

    try {
      for (final (locale, expectedLabel) in <(Locale, String)>[
        (
          const Locale('ru'),
          'Удалить пользователя Анна из чёрного списка',
        ),
        (
          const Locale('en'),
          'Remove Анна from blocked list',
        ),
      ]) {
        await tester.pumpWidget(
          _buildTestApp(
            locale: locale,
            ownerStateStream: Stream<BlackListOwnerState>.value(
              BlackListOwnerData(
                ownerUid: 'user-a',
                blockedUsers: [blockedUser],
                isServerConfirmed: true,
              ),
            ),
            currentUidProvider: () => 'user-a',
            profileLoader: (reference) async => _profile(
              reference.id,
              displayName: 'Анна',
            ),
          ),
        );
        await tester.pumpAndSettle();

        final deleteFinder = find.byKey(
          blackListDeleteButtonKey(blockedUser),
        );
        final tooltip = tester.widget<Tooltip>(
          find.descendant(
            of: deleteFinder,
            matching: find.byType(Tooltip),
          ),
        );
        final semantics = tester.getSemantics(deleteFinder);

        expect(tester.getSize(deleteFinder), const Size.square(52.0));
        _expectRowHeight(tester, blockedUser);
        expect(tooltip.message, expectedLabel);
        expect(semantics.label, expectedLabel);
        expect(
          semantics.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      }
    } finally {
      semanticsHandle.dispose();
    }
  });

  testWidgets('delete writer is blocked after direct uid changes',
      (tester) async {
    final controller = StreamController<BlackListOwnerState>(sync: true);
    final blockedUser = UsersRecord.collection.doc('guarded-delete-a');
    final removals = <(String, DocumentReference)>[];
    var currentUid = 'user-a';
    addTearDown(controller.close);

    await tester.pumpWidget(
      _buildTestApp(
        ownerStateStream: controller.stream,
        currentUidProvider: () => currentUid,
        profileLoader: (_) async => _profile(
          blockedUser.id,
          displayName: 'Анна',
        ),
        blockedUserRemover: (ownerUid, userReference) async {
          removals.add((ownerUid, userReference));
        },
      ),
    );
    await tester.pump();
    controller.add(
      BlackListOwnerData(
        ownerUid: 'user-a',
        blockedUsers: [blockedUser],
        isServerConfirmed: true,
      ),
    );
    await tester.pumpAndSettle();

    final deleteButton = find.byKey(blackListDeleteButtonKey(blockedUser));
    await tester.tap(deleteButton);
    await tester.pump();
    expect(removals, <(String, DocumentReference)>[
      ('user-a', blockedUser),
    ]);

    currentUid = 'user-b';
    await tester.tap(deleteButton);
    await tester.pump();

    expect(removals, <(String, DocumentReference)>[
      ('user-a', blockedUser),
    ]);
    expect(find.byKey(blackListUserRowKey(blockedUser)), findsNothing);
    expect(find.byKey(blackListLoadingKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _expectRowHeight(
  WidgetTester tester,
  DocumentReference userReference,
) {
  expect(
    tester.getSize(find.byKey(blackListUserRowKey(userReference))).height,
    72.0,
  );
}

BlackListOwnerDocumentSnapshot _ownerSnapshot({
  required String ownerUid,
  List<DocumentReference> blockedUsers = const <DocumentReference>[],
  bool documentExists = true,
  bool isFromCache = false,
  bool hasPendingWrites = false,
}) {
  return BlackListOwnerDocumentSnapshot(
    ownerUid: ownerUid,
    blockedUsers: blockedUsers,
    documentExists: documentExists,
    isFromCache: isFromCache,
    hasPendingWrites: hasPendingWrites,
  );
}

UserPublicProfilesRecord _profile(
  String userId, {
  required String displayName,
  bool approvedNativeSpeaker = false,
}) {
  return UserPublicProfilesRecord.getDocumentFromData(
    {
      'userId': userId,
      'display_name': displayName,
      if (approvedNativeSpeaker) ...{
        'role': UserRole.native_speaker.name,
        'approvedTeacher': true,
      },
    },
    UserPublicProfilesRecord.collection.doc(userId),
  );
}

class _ReopenableOwnerStateSource {
  _ReopenableOwnerStateSource() {
    stream = Stream<BlackListOwnerState>.multi(
      (controller) {
        listenCount += 1;
        _activeController = controller;
      },
      isBroadcast: true,
    );
  }

  late final Stream<BlackListOwnerState> stream;
  MultiStreamController<BlackListOwnerState>? _activeController;
  int listenCount = 0;

  void add(BlackListOwnerState state) => _activeController!.add(state);

  void addError(Object error) => _activeController!.addError(error);
}

class _OwnerStateSourceFactory {
  final Map<String, List<StreamController<BlackListOwnerState>>> _sources = {};

  Stream<BlackListOwnerState> create(String ownerUid) {
    final controller = StreamController<BlackListOwnerState>(sync: true);
    _sources.putIfAbsent(ownerUid, () => []).add(controller);
    return controller.stream;
  }

  int listenCount(String ownerUid) => _sources[ownerUid]?.length ?? 0;

  StreamController<BlackListOwnerState> latest(String ownerUid) =>
      _sources[ownerUid]!.last;

  void close() {
    for (final controllers in _sources.values) {
      for (final controller in controllers) {
        unawaited(controller.close());
      }
    }
  }
}
