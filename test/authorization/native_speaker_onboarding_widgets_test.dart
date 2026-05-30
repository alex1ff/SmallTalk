import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/auth/base_auth_user_provider.dart';
import 'package:small_talk/authorization/acquaintance_n_s/acquaintance_n_s_widget.dart';
import 'package:small_talk/authorization/acquaintance_n_s/native_speaker_onboarding_logic.dart';
import 'package:small_talk/components/native_speaker_onboarding_accreditation_step.dart';
import 'package:small_talk/components/student_onboarding_bottom_bar.dart';
import 'package:small_talk/backend/schema/structs/index.dart';
import 'package:small_talk/flutter_flow/flutter_flow_util.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';

const MethodChannel _permissionsChannel =
    MethodChannel('flutter.baseflow.com/permissions/methods');

Future<FFAppState> _buildTestAppState({
  required List<LanguageStruct> languages,
}) async {
  FFAppState.reset();
  final appState = FFAppState();
  appState.prefs = await SharedPreferences.getInstance();
  appState.languagesList = languages;
  return appState;
}

Widget _buildTestApp({
  required FFAppState appState,
  required Widget child,
}) {
  return ChangeNotifierProvider<FFAppState>.value(
    value: appState,
    child: MaterialApp(
      locale: const Locale('ru'),
      supportedLocales: const [
        Locale('ru'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        FFLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FallbackMaterialLocalizationDelegate(),
        FallbackCupertinoLocalizationDelegate(),
      ],
      home: Scaffold(body: child),
    ),
  );
}

List<LanguageStruct> _languagesCatalog() {
  return <LanguageStruct>[
    LanguageStruct(
      code: 'en',
      alternateCodes: const <String>['eng'],
      nameEn: 'English',
      nameRu: 'Английский',
    ),
    LanguageStruct(
      code: 'ru',
      alternateCodes: const <String>['rus'],
      nameEn: 'Russian',
      nameRu: 'Русский',
    ),
  ];
}

class _TestFirebaseAuthPlatform extends FirebaseAuthPlatform {
  _TestFirebaseAuthPlatform({FirebaseApp? app}) : super(appInstance: app);

  UserPlatform? _currentUser;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) {
    return _TestFirebaseAuthPlatform(app: app).._currentUser = _currentUser;
  }

  @override
  FirebaseAuthPlatform setInitialValues({
    PigeonUserDetails? currentUser,
    String? languageCode,
  }) {
    this.languageCode = languageCode;
    return this;
  }

  @override
  UserPlatform? get currentUser => _currentUser;

  @override
  set currentUser(UserPlatform? userPlatform) {
    _currentUser = userPlatform;
  }

  @override
  String? languageCode;

  @override
  Stream<UserPlatform?> authStateChanges() =>
      const Stream<UserPlatform?>.empty();

  @override
  Stream<UserPlatform?> idTokenChanges() => const Stream<UserPlatform?>.empty();

  @override
  Stream<UserPlatform?> userChanges() => const Stream<UserPlatform?>.empty();
}

class _TestAuthUser extends BaseAuthUser {
  _TestAuthUser({
    required this.isLoggedIn,
    this.userId,
  });

  final bool isLoggedIn;
  final String? userId;

  @override
  bool get loggedIn => isLoggedIn;

  @override
  bool get emailVerified => true;

  @override
  AuthUserInfo get authUserInfo => AuthUserInfo(uid: userId);

  @override
  Future<void> delete() async {}

  @override
  Future<void> updateEmail(String email) async {}

  @override
  Future<void> updatePassword(String newPassword) async {}

  @override
  Future<void> sendEmailVerification() async {}
}

class _RouterHarness {
  const _RouterHarness({
    required this.router,
    required this.notifier,
  });

  final GoRouter router;
  final AppStateNotifier notifier;
}

Future<void> _pumpForRouting(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<_RouterHarness> _pumpRouterHarness(
  WidgetTester tester, {
  required FFAppState appState,
}) async {
  final notifier = AppStateNotifier.instance;
  notifier.initialUser = null;
  notifier.clearRedirectLocation();
  notifier.showSplashImage = true;

  final user = _TestAuthUser(
    isLoggedIn: true,
    userId: 'native-speaker-test',
  );
  currentUser = user;
  notifier.update(user);
  notifier.stopShowingSplashImage();

  final router = createRouter(notifier);
  await tester.pumpWidget(
    ChangeNotifierProvider<FFAppState>.value(
      value: appState,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await _pumpForRouting(tester);

  return _RouterHarness(router: router, notifier: notifier);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    setupFirebaseCoreMocks();
    await FFLocalizations.initialize();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _TestFirebaseAuthPlatform();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissionsChannel, (call) async {
      switch (call.method) {
        case 'requestPermissions':
          final permissions = (call.arguments as List<dynamic>).cast<int>();
          return <int, int>{
            for (final permission in permissions) permission: 1,
          };
        case 'checkPermissionStatus':
        case 'checkServiceStatus':
          return 1;
        case 'openAppSettings':
          return true;
      }
      return null;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_permissionsChannel, null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    currentUser = null;
  });

  tearDown(() {
    currentUser = null;
    final notifier = AppStateNotifier.instance;
    notifier.clearRedirectLocation();
  });

  testWidgets('accreditation step only renders the reduced contract surface',
      (tester) async {
    final appState = await _buildTestAppState(
      languages: _languagesCatalog(),
    );

    await tester.pumpWidget(
      _buildTestApp(
        appState: appState,
        child: const NativeSpeakerOnboardingAccreditationStep(
          teachingExperience: '1_3_years',
          qualificationProofs: <String>['degree'],
          localQualificationFiles: <FFUploadedFile>[],
          existingQualificationFiles: <NativeSpeakerEvidenceFile>[],
          isPickingFiles: false,
          isUploadingFiles: false,
          onTeachingExperienceChanged: _noopStringCallback,
          onQualificationProofsChanged: _noopStringsCallback,
          onPickFiles: _noopVoidCallback,
          onRemoveLocalFile: _noopIndexCallback,
          onRemoveExistingFile: _noopIndexCallback,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Опыт преподавания'), findsOneWidget);
    expect(find.text('Подтверждение квалификации'), findsOneWidget);
    expect(find.text('Формат практики'), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.textContaining('правилами учителя'), findsNothing);
    expect(
      find.byKey(
        const ValueKey<String>('native_speaker_accreditation_upload_button'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('accreditation step hides upload CTA for experience-only proof',
      (tester) async {
    final appState = await _buildTestAppState(
      languages: _languagesCatalog(),
    );

    await tester.pumpWidget(
      _buildTestApp(
        appState: appState,
        child: const NativeSpeakerOnboardingAccreditationStep(
          teachingExperience: '1_3_years',
          qualificationProofs: <String>['experience_only'],
          localQualificationFiles: <FFUploadedFile>[],
          existingQualificationFiles: <NativeSpeakerEvidenceFile>[],
          isPickingFiles: false,
          isUploadingFiles: false,
          onTeachingExperienceChanged: _noopStringCallback,
          onQualificationProofsChanged: _noopStringsCallback,
          onPickFiles: _noopVoidCallback,
          onRemoveLocalFile: _noopIndexCallback,
          onRemoveExistingFile: _noopIndexCallback,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(
        const ValueKey<String>('native_speaker_accreditation_upload_button'),
      ),
      findsNothing,
    );
  });

  testWidgets('coordinator uses bottom bar and hides back on first auth step',
      (tester) async {
    final appState = await _buildTestAppState(
      languages: _languagesCatalog(),
    );

    await tester.pumpWidget(
      _buildTestApp(
        appState: appState,
        child: const AcquaintanceNSWidget(
          index: 0,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final bottomBar = find.byType(StudentOnboardingBottomBar);

    expect(bottomBar, findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    expect(
      find.descendant(of: bottomBar, matching: find.text('1/3')),
      findsOneWidget,
    );
    expect(
      find
          .byKey(const ValueKey<String>('student_onboarding_back_button'))
          .hitTestable(),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('student_onboarding_step_name')),
      findsOneWidget,
    );
  });

  testWidgets('profile entry exposes back on the first visible step',
      (tester) async {
    final appState = await _buildTestAppState(
      languages: _languagesCatalog(),
    );

    await tester.pumpWidget(
      _buildTestApp(
        appState: appState,
        child: const AcquaintanceNSWidget(
          index: 0,
          entrySource: 'profile',
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find
          .byKey(const ValueKey<String>('student_onboarding_back_button'))
          .hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('router parses entrySource=profile for Acquaintance_NS',
      (tester) async {
    final appState = await _buildTestAppState(
      languages: _languagesCatalog(),
    );
    final harness = await _pumpRouterHarness(
      tester,
      appState: appState,
    );

    harness.router.go('/acquaintanceNS?index=0&entrySource=profile');
    await _pumpForRouting(tester);

    expect(
      harness.router.getCurrentLocation(),
      contains('entrySource=profile'),
    );
    expect(
      find
          .byKey(const ValueKey<String>('student_onboarding_back_button'))
          .hitTestable(),
      findsOneWidget,
    );
    expect(harness.notifier.hasRedirect(), isFalse);
  });

  testWidgets('gender page reuses the student gender surface', (tester) async {
    final appState = await _buildTestAppState(
      languages: _languagesCatalog(),
    );

    await tester.pumpWidget(
      _buildTestApp(
        appState: appState,
        child: const AcquaintanceNSWidget(
          index: 3,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('student_onboarding_step_gender')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('student_onboarding_gender_selector')),
      findsOneWidget,
    );
  });

  testWidgets('last grouped page hides the progress badge in the bottom bar',
      (tester) async {
    final appState = await _buildTestAppState(
      languages: _languagesCatalog(),
    );

    await tester.pumpWidget(
      _buildTestApp(
        appState: appState,
        child: const AcquaintanceNSWidget(
          index: 6,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(
        const ValueKey<String>('native_speaker_onboarding_step_accreditation'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('student_onboarding_finish_button')),
      findsOneWidget,
    );
    expect(
      find
          .byKey(const ValueKey<String>('student_onboarding_progress_badge'))
          .hitTestable(),
      findsNothing,
    );
    expect(find.text('3/3').hitTestable(), findsNothing);
  });

  testWidgets('system back returns to the previous visible onboarding page',
      (tester) async {
    final appState = await _buildTestAppState(
      languages: _languagesCatalog(),
    );

    await tester.pumpWidget(
      _buildTestApp(
        appState: appState,
        child: const AcquaintanceNSWidget(
          index: 1,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>(
        'native_speaker_onboarding_step_language_instruction',
      )),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const ValueKey<String>('student_onboarding_step_name')),
      findsOneWidget,
    );
  });

  testWidgets('coordinator hydrates legacy accreditation request data',
      (tester) async {
    final appState = await _buildTestAppState(
      languages: _languagesCatalog(),
    );

    await tester.pumpWidget(
      _buildTestApp(
        appState: appState,
        child: AcquaintanceNSWidget(
          index: 6,
          teacherVerificationRequestLoader: () async => <String, dynamic>{
            'accreditation': <String, dynamic>{
              'teachingExperience': '1_3_years',
              'qualificationProof': 'certificate',
              'qualificationProofFiles': const <Map<String, dynamic>>[
                <String, dynamic>{
                  'name': 'Certificate.pdf',
                  'url':
                      'https://firebasestorage.googleapis.com/v0/b/demo/o/users%2Fnative-speaker-test%2Fteacher_verification%2Fqualification_proofs%2FCertificate.pdf?alt=media&token=secret',
                },
              ],
            },
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>(
        'native_speaker_onboarding_step_accreditation',
      )),
      findsOneWidget,
    );
    expect(find.text('Certificate.pdf'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('native_speaker_accreditation_upload_button'),
      ),
      findsOneWidget,
    );
  });
}

void _noopStringCallback(String _) {}
void _noopStringsCallback(List<String> _) {}
void _noopVoidCallback() {}
void _noopIndexCallback(int _) {}
