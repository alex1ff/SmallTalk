import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_talk/components/student_onboarding_bottom_bar.dart';
import 'package:small_talk/authorization/acquaintance_s_t_u_d_e_n_t/acquaintance_s_t_u_d_e_n_t_widget.dart';
import 'package:small_talk/components/student_onboarding_country_step.dart';
import 'package:small_talk/components/student_onboarding_gender_step.dart';
import 'package:small_talk/components/student_onboarding_language_step.dart';
import 'package:small_talk/components/student_onboarding_level_step.dart';
import 'package:small_talk/components/student_onboarding_name_step.dart';
import 'package:small_talk/components/country_widget.dart';
import 'package:small_talk/components/country_card_widget.dart';
import 'package:small_talk/components/lang_widget.dart';
import 'package:small_talk/components/language_card_widget.dart';
import 'package:small_talk/backend/schema/enums/enums.dart';
import 'package:small_talk/backend/schema/structs/index.dart';
import 'package:small_talk/components/button/button_widget.dart';
import 'package:small_talk/flutter_flow/flutter_flow_util.dart';
import 'package:small_talk/flutter_flow/internationalization.dart';
import 'package:small_talk/flutter_flow/custom_functions.dart' as functions;

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
    LanguageStruct(
      code: 'es',
      alternateCodes: const <String>['spa'],
      nameEn: 'Spanish',
      nameRu: 'Испанский',
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    setupFirebaseCoreMocks();
    await FFLocalizations.initialize();
    await Firebase.initializeApp();
    FirebaseAuthPlatform.instance = _TestFirebaseAuthPlatform();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders the extracted 5-step onboarding surface',
      (tester) async {
    final appState = await _buildTestAppState(
      languages: _languagesCatalog(),
    );
    final nameController = TextEditingController(text: 'Alice');
    final nameFocusNode = FocusNode();

    addTearDown(() {
      nameController.dispose();
      nameFocusNode.dispose();
    });

    await tester.pumpWidget(
      _buildTestApp(
        appState: appState,
        child: SingleChildScrollView(
          child: Column(
            children: [
              StudentOnboardingNameStep(
                controller: nameController,
                focusNode: nameFocusNode,
              ),
              StudentOnboardingGenderStep(
                genderMale: true,
                onChanged: (_) {},
              ),
              StudentOnboardingLanguageStep(
                selectedLanguage: LanguageStruct(code: 'en'),
                onChanged: (_) async {},
              ),
              StudentOnboardingCountryStep(
                selectedCountry: CountryStruct(code: 'US', nameRu: 'США'),
                onChanged: (_) async {},
              ),
              StudentOnboardingLevelStep(
                level: Level.Basic,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('student_onboarding_step_name')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('student_onboarding_step_gender')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('student_onboarding_step_language')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('student_onboarding_step_country')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('student_onboarding_step_level')),
      findsOneWidget,
    );
    expect(find.text('Как вас зовут?'), findsOneWidget);
    expect(find.text('Как вы себя\nидентифицируете?'), findsOneWidget);
    expect(find.text('Какой язык хотите практиковать?'), findsOneWidget);
    expect(find.text('Где вы сейчас находитесь?'), findsOneWidget);
    expect(find.text('Ваш текущий уровень'), findsOneWidget);
    expect(find.byType(StudentOnboardingBottomBar), findsNothing);
  });

  testWidgets('coordinator renders one-page form without slide navigation',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390.0, 1100.0));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final appState = await _buildTestAppState(
      languages: _languagesCatalog(),
    );

    await tester.pumpWidget(
      _buildTestApp(
        appState: appState,
        child: const AcquaintanceSTUDENTWidget(
          index: 0,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('student_onboarding_single_form')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('student_onboarding_step_name')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('student_onboarding_step_gender')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('student_onboarding_step_language')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('student_onboarding_step_country')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('student_onboarding_step_level')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('student_onboarding_gender_selector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('student_onboarding_progress_badge')),
      findsNothing,
    );
    expect(find.byType(StudentOnboardingBottomBar), findsNothing);
    expect(find.byType(PageView), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('student_onboarding_header')),
      findsNothing,
    );
    expect(find.text('Язык изучения'), findsOneWidget);
    expect(find.text('Ваша страна'), findsOneWidget);
    expect(find.text('Английский'), findsOneWidget);
    expect(
      tester
          .widget<ButtonWidget>(
            find.byKey(
              const ValueKey<String>('student_onboarding_finish_button'),
            ),
          )
          .enabled,
      isFalse,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('student_onboarding_language_picker')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Английский'), findsWidgets);
    await tester.tap(find.text('Английский').last);
    await tester.pumpAndSettle();
    expect(find.text('Английский'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('student_onboarding_country_picker')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Германия'), findsOneWidget);
    await tester.tap(find.text('Германия'));
    await tester.pumpAndSettle();
    expect(find.text('Германия'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('student_onboarding_name_field')),
      'Alice',
    );
    await tester.pump();
    expect(
      tester
          .widget<ButtonWidget>(
            find.byKey(
              const ValueKey<String>('student_onboarding_finish_button'),
            ),
          )
          .enabled,
      isTrue,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('student_onboarding_level_picker')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('student_onboarding_level_picker')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('A1 — Beginner'), findsOneWidget);
  });

  testWidgets('language step shows only English and Russian for new choices',
      (tester) async {
    final appState = await _buildTestAppState(
      languages: _languagesCatalog(),
    );

    await tester.pumpWidget(
      _buildTestApp(
        appState: appState,
        child: StudentOnboardingLanguageStep(
          selectedLanguage: LanguageStruct(code: 'ru'),
          onChanged: (_) async {},
          allowedCodes: const <String>['en', 'ru'],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Английский'), findsOneWidget);
    expect(find.text('Русский'), findsOneWidget);
    expect(find.text('Испанский'), findsNothing);
  });

  testWidgets('language step keeps selected legacy language visible',
      (tester) async {
    final appState = await _buildTestAppState(
      languages: _languagesCatalog(),
    );
    final selectedLegacyLanguage = LanguageStruct(
      code: 'es',
      alternateCodes: const <String>['spa'],
      nameEn: 'Spanish',
      nameRu: 'Испанский',
    );

    await tester.pumpWidget(
      _buildTestApp(
        appState: appState,
        child: StudentOnboardingLanguageStep(
          selectedLanguage: selectedLegacyLanguage,
          onChanged: (_) async {},
          allowedCodes: const <String>['en', 'ru'],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Испанский'), findsOneWidget);
    expect(find.text('Английский'), findsOneWidget);
    expect(find.text('Русский'), findsOneWidget);
  });

  testWidgets('gender step clips card swiper overflow at the page boundary',
      (tester) async {
    final appState = await _buildTestAppState(
      languages: _languagesCatalog(),
    );
    const pageClipKey = ValueKey<String>('student_onboarding_gender_page_clip');
    const stepKey = ValueKey<String>('student_onboarding_step_gender');

    await tester.pumpWidget(
      _buildTestApp(
        appState: appState,
        child: const StudentOnboardingGenderStep(
          genderMale: true,
          onChanged: _noopBoolChange,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CardSwiper), findsOneWidget);
    expect(find.byKey(pageClipKey), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byType(CardSwiper),
        matching: find.byKey(pageClipKey),
      ),
      findsOneWidget,
    );
    final swiperElement = tester.element(find.byType(CardSwiper));
    final nearestClipRenderObject =
        swiperElement.findAncestorRenderObjectOfType<RenderClipRect>();
    final pageClipRenderObject = tester.renderObject<RenderBox>(
      find.byKey(pageClipKey),
    );
    final stepRenderObject = tester.renderObject<RenderBox>(
      find.byKey(stepKey),
    );
    final swiperRenderObject = tester.renderObject<RenderBox>(
      find.byType(CardSwiper),
    );

    expect(nearestClipRenderObject, isNotNull);
    expect(nearestClipRenderObject!.size, pageClipRenderObject.size);
    expect(pageClipRenderObject.size, stepRenderObject.size);
    expect(
      pageClipRenderObject.size.width,
      greaterThan(swiperRenderObject.size.width),
    );
    expect(
      pageClipRenderObject.size.height,
      greaterThan(swiperRenderObject.size.height),
    );
  });

  testWidgets('gender selector uses one sliding indicator', (tester) async {
    final appState = await _buildTestAppState(
      languages: _languagesCatalog(),
    );
    var genderMale = true;

    await tester.pumpWidget(
      _buildTestApp(
        appState: appState,
        child: StatefulBuilder(
          builder: (context, setState) {
            return StudentOnboardingGenderStep(
              genderMale: genderMale,
              onChanged: (nextValue) {
                setState(() {
                  genderMale = nextValue;
                });
              },
            );
          },
        ),
      ),
    );
    await tester.pump();

    final indicatorFinder = find.byKey(
      const ValueKey<String>('student_onboarding_gender_selector_indicator'),
    );
    final femaleSelectorFinder = find.byKey(
      const ValueKey<String>('student_onboarding_gender_selector_female'),
    );
    expect(indicatorFinder, findsOneWidget);

    final initialIndicatorX = tester.getTopLeft(indicatorFinder).dx;

    await tester.ensureVisible(femaleSelectorFinder);
    await tester.tap(femaleSelectorFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final movedIndicatorX = tester.getTopLeft(indicatorFinder).dx;

    expect(movedIndicatorX, greaterThan(initialIndicatorX));
    expect(genderMale, isFalse);
  });

  testWidgets('lang widget search keeps a legacy selected language searchable',
      (tester) async {
    final appState = await _buildTestAppState(
      languages: _languagesCatalog(),
    );
    final selectedLegacyLanguage = LanguageStruct(
      code: 'es',
      alternateCodes: const <String>['spa'],
      nameEn: 'Spanish',
      nameRu: 'Испанский',
    );

    await tester.pumpWidget(
      _buildTestApp(
        appState: appState,
        child: LangWidget(
          selected: selectedLegacyLanguage,
          allowedCodes: const <String>['en', 'ru'],
          action: (_) async {},
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextFormField), 'Испан');
    await tester.pump();

    expect(find.text('Испанский'), findsOneWidget);
    expect(find.text('Английский'), findsNothing);
    expect(find.text('Русский'), findsNothing);
  });

  testWidgets('country widget uses reduced reference country set',
      (tester) async {
    final appState = await _buildTestAppState(
      languages: _languagesCatalog(),
    );

    expect(
      functions.countriesList().map((country) => country.nameRu).toList(),
      equals(
        const [
          'Германия',
          'Испания',
          'Франция',
          'Италия',
          'Португалия',
          'Нидерланды',
        ],
      ),
    );

    await tester.pumpWidget(
      _buildTestApp(
        appState: appState,
        child: SingleChildScrollView(
          child: CountryWidget(
            selected: null,
            action: (_) async {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Германия'), findsOneWidget);
    expect(find.text('Португалия'), findsOneWidget);
    expect(find.text('США'), findsNothing);

    await tester.enterText(find.byType(TextFormField), 'Порт');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Португалия'), findsOneWidget);
    expect(find.text('Германия'), findsNothing);
  });

  testWidgets('bottom bar adapts width and hides progress on the last page',
      (tester) async {
    final appState = await _buildTestAppState(
      languages: _languagesCatalog(),
    );

    await tester.pumpWidget(
      _buildTestApp(
        appState: appState,
        child: Column(
          children: const [
            StudentOnboardingBottomBar(
              canGoBack: false,
              currentStep: 1,
              isLastPage: false,
              isSubmitting: false,
              totalSteps: 5,
            ),
            StudentOnboardingBottomBar(
              canGoBack: true,
              currentStep: 2,
              isLastPage: false,
              isSubmitting: false,
              totalSteps: 5,
            ),
            StudentOnboardingBottomBar(
              canGoBack: true,
              currentStep: 5,
              isLastPage: true,
              isSubmitting: false,
              totalSteps: 5,
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('student_onboarding_next_button')),
      findsNWidgets(2),
    );
    expect(
      find.byKey(const ValueKey<String>('student_onboarding_finish_button')),
      findsOneWidget,
    );
    expect(
      find
          .byKey(const ValueKey<String>('student_onboarding_progress_badge'))
          .hitTestable(),
      findsNWidgets(2),
    );
    expect(find.text('5/5'), findsOneWidget);
    expect(find.text('1/5'), findsOneWidget);
    expect(find.text('2/5'), findsOneWidget);
    expect(find.text('5/5').hitTestable(), findsNothing);

    final bars =
        find.byKey(const ValueKey<String>('student_onboarding_bottom_bar'));
    final firstBarWidth = tester.getSize(bars.at(0)).width;
    final middleBarWidth = tester.getSize(bars.at(1)).width;
    final lastBarWidth = tester.getSize(bars.at(2)).width;

    expect(firstBarWidth, lessThan(middleBarWidth));
    expect(lastBarWidth, lessThan(middleBarWidth));

    final backCenter = tester.getCenter(
      find.descendant(
        of: bars.at(1),
        matching: find
            .byKey(const ValueKey<String>('student_onboarding_back_button')),
      ),
    );
    final progressCenter = tester.getCenter(
      find.descendant(of: bars.at(1), matching: find.text('2/5')),
    );
    final nextCenter = tester.getCenter(
      find.descendant(
        of: bars.at(1),
        matching: find
            .byKey(const ValueKey<String>('student_onboarding_next_button')),
      ),
    );

    expect(progressCenter.dx, greaterThan(backCenter.dx));
    expect(progressCenter.dx, lessThan(nextCenter.dx));
    expect(
      find.descendant(
        of: bars.at(2),
        matching: find
            .byKey(const ValueKey<String>('student_onboarding_progress_badge')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: bars.at(2),
        matching: find
            .byKey(const ValueKey<String>('student_onboarding_progress_badge'))
            .hitTestable(),
      ),
      findsNothing,
    );
  });

  testWidgets('bottom bar hides back button on the first page', (tester) async {
    final appState = await _buildTestAppState(
      languages: _languagesCatalog(),
    );

    await tester.pumpWidget(
      _buildTestApp(
        appState: appState,
        child: const StudentOnboardingBottomBar(
          canGoBack: false,
          currentStep: 1,
          isLastPage: false,
          isSubmitting: false,
          totalSteps: 5,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('student_onboarding_back_button')),
      findsOneWidget,
    );
    expect(
      find
          .byKey(const ValueKey<String>('student_onboarding_back_button'))
          .hitTestable(),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('student_onboarding_next_button')),
      findsOneWidget,
    );
    expect(find.text('1/5'), findsOneWidget);
  });

  testWidgets('bottom bar shows dark back button after the first page',
      (tester) async {
    final appState = await _buildTestAppState(
      languages: _languagesCatalog(),
    );

    await tester.pumpWidget(
      _buildTestApp(
        appState: appState,
        child: const StudentOnboardingBottomBar(
          canGoBack: true,
          currentStep: 2,
          isLastPage: false,
          isSubmitting: false,
          totalSteps: 5,
        ),
      ),
    );
    await tester.pump();

    final backMaterial = tester.widget<Material>(
      find.descendant(
        of: find
            .byKey(const ValueKey<String>('student_onboarding_back_button')),
        matching: find.byType(Material),
      ),
    );
    final backText = tester.widget<Text>(
      find.descendant(
        of: find
            .byKey(const ValueKey<String>('student_onboarding_back_button')),
        matching: find.text('Назад'),
      ),
    );

    expect(backMaterial.color, const Color(0xFF2E2E2E));
    expect(backText.style?.color, Colors.white);
    expect(find.text('2/5'), findsOneWidget);
  });

  testWidgets(
      'language and country cards use the same selection indicator size',
      (tester) async {
    final appState = await _buildTestAppState(
      languages: _languagesCatalog(),
    );

    await tester.pumpWidget(
      _buildTestApp(
        appState: appState,
        child: Column(
          children: [
            LanguageCardWidget(
              lang: LanguageStruct(code: 'en', nameRu: 'Английский'),
              currentSelected: LanguageStruct(code: 'en', nameRu: 'Английский'),
              callbackAction: (_) async {},
            ),
            CountryCardWidget(
              lang: CountryStruct(code: 'US', nameRu: 'США'),
              currentSelected: CountryStruct(code: 'US', nameRu: 'США'),
              callbackAction: (_) async {},
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    final languageIndicatorSize = tester.getSize(
      find.byKey(const ValueKey<String>('language_card_selected_indicator')),
    );
    final countryIndicatorSize = tester.getSize(
      find.byKey(const ValueKey<String>('country_card_selected_indicator')),
    );

    expect(
        languageIndicatorSize.width, LanguageCardWidget.selectionIndicatorSize);
    expect(
      languageIndicatorSize.height,
      LanguageCardWidget.selectionIndicatorSize,
    );
    expect(languageIndicatorSize, const Size(25.0, 25.0));
    expect(
        countryIndicatorSize.width, CountryCardWidget.selectionIndicatorSize);
    expect(
      countryIndicatorSize.height,
      CountryCardWidget.selectionIndicatorSize,
    );
    expect(countryIndicatorSize, const Size(25.0, 25.0));
    expect(countryIndicatorSize, languageIndicatorSize);
  });

  testWidgets('level step supports bottom label taps and shows CEFR captions',
      (tester) async {
    final appState = await _buildTestAppState(
      languages: _languagesCatalog(),
    );
    final selectedLevels = <Level>[];

    await tester.pumpWidget(
      _buildTestApp(
        appState: appState,
        child: StudentOnboardingLevelStep(
          level: Level.Basic,
          onChanged: (nextLevel) {
            selectedLevels.add(nextLevel);
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('A1-A2'), findsOneWidget);
    expect(find.text('A2-B1'), findsOneWidget);
    expect(find.text('B1-B2'), findsOneWidget);
    expect(find.text('C1-C2'), findsOneWidget);
    expect(find.text('Могу поддержать простой разговор'), findsOneWidget);
    expect(find.text('Могу поддержать простой разговор\nA2-B1'), findsNothing);

    await tester.tap(find.text('Уверенный'));
    await tester.pump();
    await tester.tap(find.text('C1-C2'));
    await tester.pump();

    expect(selectedLevels, <Level>[
      Level.Intermediate,
      Level.Fluent,
    ]);
  });

  testWidgets('bottom bar ignores taps while interaction is locked',
      (tester) async {
    final appState = await _buildTestAppState(
      languages: _languagesCatalog(),
    );
    var backTapCount = 0;
    var nextTapCount = 0;

    await tester.pumpWidget(
      _buildTestApp(
        appState: appState,
        child: StudentOnboardingBottomBar(
          canGoBack: true,
          currentStep: 3,
          isLastPage: false,
          isSubmitting: false,
          totalSteps: 5,
          isInteractionLocked: true,
          onBack: () => backTapCount += 1,
          onNext: () => nextTapCount += 1,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey<String>('student_onboarding_back_button')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('student_onboarding_next_button')),
    );
    await tester.pump();

    final lockedBackMaterial = tester.widget<Material>(
      find.descendant(
        of: find
            .byKey(const ValueKey<String>('student_onboarding_back_button')),
        matching: find.byType(Material),
      ),
    );

    expect(backTapCount, 0);
    expect(nextTapCount, 0);
    expect(lockedBackMaterial.color, const Color(0xFF2E2E2E));
    expect(
      find.byKey(const ValueKey<String>('student_onboarding_back_button')),
      findsOneWidget,
    );
  });

  testWidgets('bottom bar ignores back taps while submitting', (tester) async {
    final appState = await _buildTestAppState(
      languages: _languagesCatalog(),
    );
    var backTapCount = 0;

    await tester.pumpWidget(
      _buildTestApp(
        appState: appState,
        child: StudentOnboardingBottomBar(
          canGoBack: true,
          currentStep: 5,
          isLastPage: true,
          isSubmitting: true,
          totalSteps: 5,
          onBack: () => backTapCount += 1,
          onComplete: () {},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey<String>('student_onboarding_back_button')),
    );
    await tester.pump();

    final submittingBackMaterial = tester.widget<Material>(
      find.descendant(
        of: find
            .byKey(const ValueKey<String>('student_onboarding_back_button')),
        matching: find.byType(Material),
      ),
    );

    expect(backTapCount, 0);
    expect(submittingBackMaterial.color, const Color(0xFF2E2E2E));
    expect(
      find.byKey(const ValueKey<String>('student_onboarding_back_button')),
      findsOneWidget,
    );
  });
}

void _noopBoolChange(bool _) {}
