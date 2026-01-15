import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocaleStorageKey = '__locale_key__';

class FFLocalizations {
  FFLocalizations(this.locale);

  final Locale locale;

  static FFLocalizations of(BuildContext context) =>
      Localizations.of<FFLocalizations>(context, FFLocalizations)!;

  static List<String> languages() => ['ru', 'en'];

  static late SharedPreferences _prefs;
  static Future initialize() async =>
      _prefs = await SharedPreferences.getInstance();
  static Future storeLocale(String locale) =>
      _prefs.setString(_kLocaleStorageKey, locale);
  static Locale? getStoredLocale() {
    final locale = _prefs.getString(_kLocaleStorageKey);
    return locale != null && locale.isNotEmpty ? createLocale(locale) : null;
  }

  String get languageCode => locale.toString();
  String? get languageShortCode =>
      _languagesWithShortCode.contains(locale.toString())
          ? '${locale.toString()}_short'
          : null;
  int get languageIndex => languages().contains(languageCode)
      ? languages().indexOf(languageCode)
      : 0;

  String getText(String key) =>
      (kTranslationsMap[key] ?? {})[locale.toString()] ?? '';

  String getVariableText({
    String? ruText = '',
    String? enText = '',
  }) =>
      [ruText, enText][languageIndex] ?? '';

  static const Set<String> _languagesWithShortCode = {
    'ar',
    'az',
    'ca',
    'cs',
    'da',
    'de',
    'dv',
    'en',
    'es',
    'et',
    'fi',
    'fr',
    'gr',
    'he',
    'hi',
    'hu',
    'it',
    'km',
    'ku',
    'mn',
    'ms',
    'no',
    'pt',
    'ro',
    'ru',
    'rw',
    'sv',
    'th',
    'uk',
    'vi',
  };
}

/// Used if the locale is not supported by GlobalMaterialLocalizations.
class FallbackMaterialLocalizationDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const FallbackMaterialLocalizationDelegate();

  @override
  bool isSupported(Locale locale) => _isSupportedLocale(locale);

  @override
  Future<MaterialLocalizations> load(Locale locale) async =>
      SynchronousFuture<MaterialLocalizations>(
        const DefaultMaterialLocalizations(),
      );

  @override
  bool shouldReload(FallbackMaterialLocalizationDelegate old) => false;
}

/// Used if the locale is not supported by GlobalCupertinoLocalizations.
class FallbackCupertinoLocalizationDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const FallbackCupertinoLocalizationDelegate();

  @override
  bool isSupported(Locale locale) => _isSupportedLocale(locale);

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      SynchronousFuture<CupertinoLocalizations>(
        const DefaultCupertinoLocalizations(),
      );

  @override
  bool shouldReload(FallbackCupertinoLocalizationDelegate old) => false;
}

class FFLocalizationsDelegate extends LocalizationsDelegate<FFLocalizations> {
  const FFLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => _isSupportedLocale(locale);

  @override
  Future<FFLocalizations> load(Locale locale) =>
      SynchronousFuture<FFLocalizations>(FFLocalizations(locale));

  @override
  bool shouldReload(FFLocalizationsDelegate old) => false;
}

Locale createLocale(String language) => language.contains('_')
    ? Locale.fromSubtags(
        languageCode: language.split('_').first,
        scriptCode: language.split('_').last,
      )
    : Locale(language);

bool _isSupportedLocale(Locale locale) {
  final language = locale.toString();
  return FFLocalizations.languages().contains(
    language.endsWith('_')
        ? language.substring(0, language.length - 1)
        : language,
  );
}

final kTranslationsMap = <Map<String, Map<String, String>>>[
  // Onboarding
  {
    'on7eoqhl': {
      'ru': 'Пропустить',
      'en': 'Skip',
    },
    'd3nuphz3': {
      'ru': 'Home',
      'en': 'Home',
    },
  },
  // Login
  {
    '6941br49': {
      'ru': 'Вход',
      'en': 'Login',
    },
    '0i8b54sx': {
      'ru':
          'Введи адрес электронной почты и пароль, который был использован при регистрации.',
      'en':
          'Enter the email address and password you used during registration.',
    },
    'vbj759aa': {
      'ru': 'E-mail',
      'en': 'Email',
    },
    'p6wbbfql': {
      'ru': 'Пароль',
      'en': 'Password',
    },
    'c1a5gcpy': {
      'ru': 'Забыли пароль?',
      'en': 'Forgot your password?',
    },
    '8x9f21aa': {
      'ru': 'Далее',
      'en': 'Next',
    },
    'b7eijuxv': {
      'ru': ' ',
      'en': '',
    },
    'tl1j359o': {
      'ru': 'Пользуясь приложением, вы соглашаетесь \nс ',
      'en': 'By using the app, you agree\nto ',
    },
    '7ami3ujs': {
      'ru': 'Политикой конфиденциальности ',
      'en': 'Privacy Policy',
    },
    'v2qj45ju': {
      'ru': 'Apple',
      'en': 'Apple',
    },
    'gfc8qlqz': {
      'ru': 'Google',
      'en': 'Google',
    },
    'cpw39y3y': {
      'ru': 'Нет аккаунта? ',
      'en': 'Don\'t have an account? ',
    },
    'zdm7zlic': {
      'ru': 'Зарегистрируйтесь',
      'en': 'Register',
    },
    '75ui0gn9': {
      'ru': 'Home',
      'en': 'Home',
    },
  },
  // Registration
  {
    'swn14ivc': {
      'ru': 'Регистрация',
      'en': 'Registration',
    },
    '2qzo58i1': {
      'ru':
          'Чтобы начать, нужно зарегестрироваться.\nВведите данные и начнем знакомство.',
      'en':
          'To get started, you need to register.\nEnter your information and let\'s get started.',
    },
    'omyv9gs9': {
      'ru': 'E-mail',
      'en': 'Email',
    },
    'c91xmbbf': {
      'ru': 'Пароль',
      'en': 'Password',
    },
    'gytrv60k': {
      'ru': 'Войти как Native Speaker',
      'en': 'Login as a Native Speaker',
    },
    'ohbb27ah': {
      'ru': 'Далее',
      'en': 'Next',
    },
    'p8z1gi45': {
      'ru': ' ',
      'en': '',
    },
    '8s89x4ou': {
      'ru': 'Пользуясь приложением, вы соглашаетесь \nс ',
      'en': 'By using the app, you agree\nto ',
    },
    '1r55b1dc': {
      'ru': 'Политикой конфиденциальности ',
      'en': 'Privacy Policy',
    },
    '4j9qbbqb': {
      'ru': 'Apple',
      'en': 'Apple',
    },
    '9yanqfu5': {
      'ru': 'Google',
      'en': 'Google',
    },
    '4trgnrco': {
      'ru': 'Есть аккаунт? ',
      'en': 'Do you have an account? ',
    },
    'ynyd41nj': {
      'ru': 'Войти',
      'en': 'Login',
    },
    'da74vjpj': {
      'ru': 'Home',
      'en': 'Home',
    },
  },
  // Acquaintance_STUDENT
  {
    'bqppzscm': {
      'ru': 'Пропустить',
      'en': 'Skip',
    },
    'ip2rlf3r': {
      'ru': 'Как вас зовут?',
      'en': 'What is your name?',
    },
    'f55kpaxg': {
      'ru': 'Лучше написать настоящее имя',
      'en': 'It\'s better to write your real name.',
    },
    'aty6z85z': {
      'ru': 'Ваше имя',
      'en': 'Name',
    },
    '53phc019': {
      'ru': 'Как вы себя \nидентифицируете?',
      'en': 'How do you \nidentify yourself?',
    },
    'tqqp6x5t': {
      'ru': 'Какой язык хотите практиковать?',
      'en': 'What language do you want to practice?',
    },
    '1crdpxrp': {
      'ru': 'Сможете изменить позднее',
      'en': 'You can change it later',
    },
    'gs6ylhnl': {
      'ru': 'Ваш текущий уровень',
      'en': 'Your current level',
    },
    'zst66ylu': {
      'ru': 'Начальный',
      'en': 'Elementary',
    },
    '5dx8dgam': {
      'ru': 'Знаю базовые фразы и слова\nA1-A2',
      'en': 'I know basic phrases and words\nA1-A2',
    },
    'f84pr2gx': {
      'ru': 'Базовый',
      'en': 'Base',
    },
    '9o39d1jb': {
      'ru': 'Могу поддержать простой разговор\nB1-B2',
      'en': 'I can hold a simple conversation\nB1-B2',
    },
    'yxe8e00i': {
      'ru': 'Уверенный',
      'en': 'Confident',
    },
    'b0keg79q': {
      'ru': 'Говорю свободно на большинство тем\nC1-C2',
      'en': 'I speak fluently on most topics\nC1-C2',
    },
    'pqgno6ti': {
      'ru': 'Свободно',
      'en': 'Free',
    },
    's4ycikzv': {
      'ru': 'Владею как родным\nNative',
      'en': 'I speak Native like a native.\nNative',
    },
    'sj0rn6q7': {
      'ru': 'Начальный',
      'en': 'Elementary',
    },
    'rm8zot80': {
      'ru': 'Базовый',
      'en': 'Base',
    },
    'onxzn6lu': {
      'ru': 'Уверенный',
      'en': 'Confident',
    },
    'qspamhah': {
      'ru': 'Свободно',
      'en': 'Free',
    },
    'lrja9u6c': {
      'ru': 'Отличное начало!',
      'en': 'Great start!',
    },
    '553cq9o6': {
      'ru':
          'Основная информация готова\nОсталось 4 быстрых вопроса (~2 минуты)',
      'en':
          'The basic information is ready.\n4 quick questions remain (~2 minutes).',
    },
    'aq1oqs5h': {
      'ru': 'Завершите заполнение \nпрофиля и получите',
      'en': 'Complete your profile and receive',
    },
    'dr0r3uyi': {
      'ru': 'Более точный подбор собеседников',
      'en': 'More precise selection of interlocutors',
    },
    'angeqklx': {
      'ru': 'До 10 минут бесплатного общения ',
      'en': 'Up to 10 minutes of free communication',
    },
    'pcdwhfh6': {
      'ru': 'Приоритет в поиске',
      'en': 'Search priority',
    },
    'ybk9bjx6': {
      'ru': 'Заполню позже',
      'en': 'I\'ll fill it out later',
    },
    '69cq0mzr': {
      'ru': 'Зачем вам нужен этот язык?',
      'en': 'Why do you need this language?',
    },
    '4yfkc6aa': {
      'ru': 'Можно выбрать несколько',
      'en': 'You can select several',
    },
    '45xgftn8': {
      'ru': 'Путешествия',
      'en': 'Trips',
    },
    'b81l5ck6': {
      'ru': 'Работа',
      'en': 'Job',
    },
    'nvzre0x5': {
      'ru': 'Учеба',
      'en': 'Studies',
    },
    '3bbpj9jw': {
      'ru': 'Культура',
      'en': 'Culture',
    },
    'psmff4a8': {
      'ru': 'Общение',
      'en': 'Communication',
    },
    'r19vqfh2': {
      'ru': 'Другое',
      'en': 'Other',
    },
    '4l7nhxkw': {
      'ru': 'Выберите аватар',
      'en': 'Select an avatar',
    },
    'x6szbodc': {
      'ru': 'Или загрузить своё фото',
      'en': 'Or upload your photo',
    },
    'abc33q9h': {
      'ru': 'С носителем какого языка хотите говорить?',
      'en': 'What language do you want to speak with a native speaker?',
    },
    'kpfa0ujl': {
      'ru': 'Сможете изменить позднее',
      'en': 'You can change it later',
    },
    'dvafgdbh': {
      'ru': 'Местоположение собеседника',
      'en': 'Location of the interlocutor',
    },
    '4pay67d3': {
      'ru':
          'Находите новых друзей в интересующей \nвас стране мира со Small Talk',
      'en': 'Find new friends in your chosen country with Small Talk.',
    },
    'tkv7vhn7': {
      'ru': 'Продолжить',
      'en': 'Continue',
    },
    'hpnf6xs5': {
      'ru': 'Home',
      'en': 'Home',
    },
  },
  // Loading
  {
    'g5336z2i': {
      'ru': 'Home',
      'en': 'Home',
    },
  },
  // Dashboard_NS
  {
    '1u9apwk3': {
      'ru': 'Welcome to SmallTalk',
      'en': 'Welcome to SmallTalk',
    },
    'znnn9lq2': {
      'ru': 'Текущий баланс',
      'en': 'Current balance',
    },
    'z22ks730': {
      'ru': ' р',
      'en': ' р',
    },
    '7q1ar70a': {
      'ru': '\$1,200',
      'en': '\$1,200',
    },
    'm4d0g5ub': {
      'ru': 'Вывести',
      'en': 'Withdraw',
    },
    'n1zbzn9y': {
      'ru': 'Доступен сегодня',
      'en': 'Available today',
    },
    'ws9tu06c': {
      'ru': 'Добавить интервал',
      'en': 'Add interval',
    },
    '5e7lo84r': {
      'ru': 'Статистика за сегодня',
      'en': 'Statistics for today',
    },
    'g97rtbgg': {
      'ru': 'Заработано',
      'en': 'Earned',
    },
    'hyjj1xqg': {
      'ru': 'Продолжительность звонков',
      'en': 'Call duration',
    },
    'q3rpok1f': {
      'ru': 'Звонков принято',
      'en': 'Calls received',
    },
    't1u8xuhi': {
      'ru': 'Звонков ещё не было',
      'en': 'There have been no calls yet.',
    },
    'vf0nsiuy': {
      'ru': 'Убедитесь, что вы онлайн.\nСтуденты скоро найдут вас!',
      'en': 'Make sure you\'re online.\nStudents will find you soon!',
    },
    'egtydbie': {
      'ru': 'Home',
      'en': 'Home',
    },
  },
  // Students_Dashboard
  {
    'xocrym2z': {
      'ru': 'Welcome to SmallTalk',
      'en': 'Welcome to SmallTalk',
    },
    'o7w214bz': {
      'ru': 'Текущий баланс',
      'en': 'Current balance',
    },
    'et82m26d': {
      'ru': '.small talks',
      'en': '.small talks',
    },
    'dyf7xj5v': {
      'ru': '\$1,200',
      'en': '\$1,200',
    },
    'nes89ax1': {
      'ru': 'Пополнить',
      'en': 'Top up',
    },
    'a3nqo0ec': {
      'ru': 'Диалог с носителем \nязыка в один клик',
      'en': 'Chat with a native speaker\nin one click',
    },
    'crtk35jr': {
      'ru': 'Первая минута бесплатно!',
      'en': 'The first minute is free!',
    },
    'flmz1vkr': {
      'ru': 'Начать small talk',
      'en': 'Start a small talk',
    },
    'a4u0etcs': {
      'ru': 'Избранные собеседники',
      'en': 'Selected Interlocutors',
    },
    'lffx4k7x': {
      'ru': 'Статистика за сегодня',
      'en': 'Statistics for today',
    },
    '2dq1u1yc': {
      'ru': 'Продолжительность звонков',
      'en': 'Call duration',
    },
    'f4nn7fxp': {
      'ru': 'Звонков всего',
      'en': 'Total calls',
    },
    'laxcndbb': {
      'ru': 'Звонков ещё не было',
      'en': 'There have been no calls yet.',
    },
    '0hw93aax': {
      'ru': 'Самое время это исправить.\nНачните свой первый Small Talk!',
      'en': 'It\'s time to fix that.\nStart your first Small Talk!',
    },
    'd4rmucwv': {
      'ru': 'Home',
      'en': 'Home',
    },
  },
  // Profile
  {
    'w5x0ak9h': {
      'ru': 'Мои отзывы',
      'en': 'My reviews',
    },
    'xxkubsii': {
      'ru': 'Финансы',
      'en': 'Finance',
    },
    'u9y8laa9': {
      'ru': 'Как вам приложение?',
      'en': 'How do you like the app?',
    },
    'p8bgfesg': {
      'ru': 'Статистика',
      'en': 'Statistics',
    },
    'iuym248z': {
      'ru': 'Стать носителем',
      'en': 'Become a carrier',
    },
    'dmupsasg': {
      'ru': 'Стать учеником',
      'en': 'Become a student',
    },
    '0yjewgwu': {
      'ru': 'Язык приложения',
      'en': 'Application language',
    },
    'uo96qs94': {
      'ru': 'Черный список',
      'en': 'Blacklist',
    },
    '7benyvw2': {
      'ru': 'Сообщить о проблеме',
      'en': 'Report a problem',
    },
    'ss5m5bt2': {
      'ru': 'Выйти',
      'en': 'Exit',
    },
    'g1hqddj1': {
      'ru': 'Политика конфиденциальности',
      'en': 'Privacy Policy',
    },
    'l1x4xu81': {
      'ru': '© 2025 Small Talk. Версия 1.0.0',
      'en': '© 2025 Small Talk. Version 1.0.0',
    },
    'frjfmbx0': {
      'ru': 'Home',
      'en': 'Home',
    },
  },
  // Words
  {
    'mh59o8kl': {
      'ru': '75%',
      'en': '75%',
    },
    'w44p5wo4': {
      'ru': 'Flash‑cards',
      'en': 'Flash cards',
    },
    'itgwbmq6': {
      'ru': 'Все',
      'en': 'All',
    },
    'lgijjwoy': {
      'ru': 'Существительное',
      'en': 'Noun',
    },
    'o5rmy0ju': {
      'ru': 'Глагол',
      'en': 'Verb',
    },
    'e5h653gn': {
      'ru': 'Прилагательное',
      'en': 'Adjective',
    },
    'afe30qzp': {
      'ru': 'Наречие',
      'en': 'Adverb',
    },
    'wyn9ioic': {
      'ru': 'Местоимение',
      'en': 'Pronoun',
    },
    'jeewyk0t': {
      'ru': 'Предлог',
      'en': 'Pretext',
    },
    '09jddjbc': {
      'ru': 'Союз',
      'en': 'Union',
    },
    'd8fv2zgh': {
      'ru': 'Междометие',
      'en': 'Interjection',
    },
    '6jcnedaf': {
      'ru': 'Частица',
      'en': 'Particle',
    },
    'qhknk21t': {
      'ru': 'Артикль',
      'en': 'Article',
    },
    't6bc6qig': {
      'ru': 'Числительное',
      'en': 'Numeral',
    },
    'cev0022q': {
      'ru': 'Причастие',
      'en': 'Communion',
    },
    '8dy5jwch': {
      'ru': 'Home',
      'en': 'Home',
    },
  },
  // CallSummary
  {
    'nkmvs84c': {
      'ru': 'Как прошёл звонок?',
      'en': 'How did the call go?',
    },
    'urumutat': {
      'ru': '',
      'en': '',
    },
    '2gz8zlq9': {
      'ru': 'В избранное',
      'en': 'Add to favorites',
    },
    'kth7l1fn': {
      'ru': 'Не соединять',
      'en': 'Do not connect',
    },
    'duynuhus': {
      'ru': 'Готово',
      'en': 'Done',
    },
    's918m7k5': {
      'ru': 'Пропустить',
      'en': 'Skip',
    },
    '51ipmvgk': {
      'ru': 'Home',
      'en': 'Home',
    },
  },
  // VideoCallPage
  {
    '4hy313iv': {
      'ru': 'Home',
      'en': 'Home',
    },
  },
  // WaitingForTeacherPage
  {
    'o2wt8jr9': {
      'ru': 'Отменить',
      'en': 'Cancel',
    },
    'bxqyl515': {
      'ru': 'Home',
      'en': 'Home',
    },
  },
  // Profile_edit
  {
    'hpktm3z3': {
      'ru': 'Ваше имя',
      'en': 'Name',
    },
    'qupouufi': {
      'ru': 'Пол',
      'en': 'Gender',
    },
    'ro4cvtou': {
      'ru': 'Язык изучения',
      'en': 'Language of study',
    },
    's0mfbo2b': {
      'ru': 'Язык изучения',
      'en': 'Language of study',
    },
    'bo9k12fd': {
      'ru': 'Уровень',
      'en': 'Level',
    },
    '3um2nt3q': {
      'ru': 'Цели изучения',
      'en': 'Objectives of the study',
    },
    'fjpaay9n': {
      'ru': 'Delete Account',
      'en': 'Delete Account',
    },
    'mx59qpmr': {
      'ru': 'Ваше имя',
      'en': 'your name',
    },
    '2kk34veu': {
      'ru': 'Пол',
      'en': 'Gender',
    },
    '53sloz8g': {
      'ru': 'О себе',
      'en': 'About me',
    },
    '0xkn8sut': {
      'ru': 'Язык, которому обучаю',
      'en': 'The language I teach',
    },
    '5s3nn50b': {
      'ru': 'Язык, которому обучаю',
      'en': 'The language I teach',
    },
    'vi9zv6jp': {
      'ru': 'Мой язык',
      'en': 'My language',
    },
    'sw9i9e2p': {
      'ru': 'Мой язык',
      'en': 'My language',
    },
    'kem0gdl9': {
      'ru': 'Страна',
      'en': 'Country',
    },
    'potevt0c': {
      'ru': 'Где вы сейчас находитесь?',
      'en': 'Where are you now?',
    },
    'bvffcfv7': {
      'ru': 'Delete Account',
      'en': 'Delete Account',
    },
    '8nacbzr2': {
      'ru': 'Home',
      'en': 'Home',
    },
  },
  // NativeSpeakerPage
  {
    'd7d95pj7': {
      'ru': 'О себе',
      'en': 'About me',
    },
    '2oj950e4': {
      'ru': 'Язык',
      'en': 'Language',
    },
    'clkcguct': {
      'ru': '5',
      'en': '5',
    },
    'pg86zql3': {
      'ru': '',
      'en': '',
    },
    '10vod9dp': {
      'ru': '4',
      'en': '4',
    },
    'r6w9d005': {
      'ru': '',
      'en': '',
    },
    's89a9grf': {
      'ru': '3',
      'en': '3',
    },
    'mwrjwlnh': {
      'ru': '',
      'en': '',
    },
    'n8svbjr0': {
      'ru': '2',
      'en': '2',
    },
    '5bburccy': {
      'ru': '',
      'en': '',
    },
    'g8kj6pac': {
      'ru': '1',
      'en': '1',
    },
    '54vhaxev': {
      'ru': '',
      'en': '',
    },
    'ovjwud7w': {
      'ru': 'Все',
      'en': 'All',
    },
    'h6yocea2': {
      'ru': '5',
      'en': '5',
    },
    'm2hjxtoq': {
      'ru': '4',
      'en': '4',
    },
    '19bs787g': {
      'ru': '3',
      'en': '3',
    },
    'is2w8qlp': {
      'ru': '2',
      'en': '2',
    },
    'bk4ndath': {
      'ru': '1',
      'en': '1',
    },
    '37cy62j3': {
      'ru': 'О себе',
      'en': 'About me',
    },
    'hnlgm9bc': {
      'ru': 'Отзывы',
      'en': 'Reviews',
    },
    '2sabsnp2': {
      'ru': 'Начать small talk',
      'en': 'Start a small talk',
    },
    '1b1w4r9j': {
      'ru': '',
      'en': '',
    },
    'scqhm9kb': {
      'ru': 'Home',
      'en': 'Home',
    },
  },
  // myRew
  {
    '15c59bwa': {
      'ru': 'Все',
      'en': 'All',
    },
    'q7mf0a7y': {
      'ru': '5',
      'en': '5',
    },
    'nq0k4jpp': {
      'ru': '4',
      'en': '4',
    },
    '4jivq2w2': {
      'ru': '3',
      'en': '3',
    },
    'ojmpi3dm': {
      'ru': '2',
      'en': '2',
    },
    'wn2mqzpv': {
      'ru': '1',
      'en': '1',
    },
    'r4c8ksc9': {
      'ru': 'Мои отзывы',
      'en': 'My reviews',
    },
    'i9yu4mm6': {
      'ru': 'Home',
      'en': 'Home',
    },
  },
  // pay
  {
    'd9e9ehu6': {
      'ru': 'Текущий баланс',
      'en': 'Current balance',
    },
    'vni7lmge': {
      'ru': '.small talks',
      'en': '.small talks',
    },
    'lrs28uyv': {
      'ru': '\$1,200',
      'en': '\$1,200',
    },
    '2dwkyn2f': {
      'ru': 'Промокод',
      'en': 'Promo code',
    },
    'ozmnhrl5': {
      'ru': 'Введите промокод',
      'en': 'Enter the promo code',
    },
    '1uhw3x91': {
      'ru': 'Выберите тариф',
      'en': 'Select a plan',
    },
    'd4ayjswx': {
      'ru': 'История операций',
      'en': 'Operation history',
    },
    '1owu01u1': {
      'ru': 'Все',
      'en': 'All',
    },
    'm8dxuyz4': {
      'ru': 'Пополнения',
      'en': 'Replenishments',
    },
    'xh0vamif': {
      'ru': 'Списания',
      'en': 'Write-offs',
    },
    'biuq69s8': {
      'ru': 'Финансы',
      'en': 'Finance',
    },
    '5visqusd': {
      'ru': 'Оплатить',
      'en': 'Pay',
    },
    'i4jp9pjr': {
      'ru': 'Home',
      'en': 'Home',
    },
  },
  // Acquaintance_NS
  {
    '5sad5n6l': {
      'ru': 'Как вас зовут?',
      'en': 'What is your name?',
    },
    'qkjbiyki': {
      'ru': 'Лучше написать настоящее имя',
      'en': 'It\'s better to write your real name.',
    },
    'ymvt7z18': {
      'ru': 'Ваше имя',
      'en': 'Name',
    },
    'uvh46vvg': {
      'ru': 'Язык, которому будете обучать',
      'en': 'The language you will teach',
    },
    't67xey72': {
      'ru': 'Можно выбрать несколько',
      'en': 'You can select several',
    },
    'qneb3190': {
      'ru': 'На каком языке вы говорите с детства?',
      'en': 'What language do you want to speak with a native speaker?',
    },
    'tsnjs8zf': {
      'ru': 'Как вы себя \nидентифицируете?',
      'en': 'How do you \nidentify yourself?',
    },
    'zc7cbn38': {
      'ru': 'Это поможет ученикам найти подходящего собеседника',
      'en': 'This will help students find a suitable interlocutor.',
    },
    'iaxjidcm': {
      'ru': 'Где вы сейчас находитесь?',
      'en': 'Where are you now?',
    },
    'h6cyori3': {
      'ru':
          'Находите новых друзей в интересующей \nвас стране мира со Small Talk',
      'en': 'Find new friends in your chosen country with Small Talk.',
    },
    '24v6ef7s': {
      'ru': 'Расскажите \nо себе',
      'en': 'Tell us about yourself',
    },
    '9c52d7gr': {
      'ru': 'Это поможет ученикам узнать вас и решить, с кем хотят общаться',
      'en':
          'This will help students get to know you and decide who they want to communicate with.',
    },
    '6qo3x2rg': {
      'ru': '',
      'en': '',
    },
    's8jfyxcp': {
      'ru': 'Люблю готовить, изучаю испанский для переезда в Барселону',
      'en': 'I love to cook and am learning Spanish to move to Barcelona.',
    },
    'gt8x9g31': {
      'ru': 'Добавьте фото профиля',
      'en': 'Add a profile photo',
    },
    'uijw0e1q': {
      'ru': 'Загрузить фото',
      'en': 'Upload a photo',
    },
    'w8c1q5zh': {
      'ru': 'Home',
      'en': 'Home',
    },
  },
  // Recover_pass
  {
    'hu56u2hq': {
      'ru': 'Восстановить \nпароль',
      'en': 'Recover \npassword',
    },
    '8ty2g5mk': {
      'ru':
          'Введите e-mail, указанный при регистрации - мы отправим Вам ссылку для восстановления пароля',
      'en':
          'Enter the email address you provided during registration - we will send you a link to reset your password',
    },
    'w8edaady': {
      'ru': 'E-mail',
      'en': 'Email',
    },
    '4rn5krnl': {
      'ru': 'Отправить',
      'en': 'Send',
    },
    'bzzxmn6e': {
      'ru': 'Нажимая кнопку \"Отправить\", вы принимаете условия ',
      'en': 'By clicking the \"Send\" button, you accept the terms ',
    },
    'vgscvvlj': {
      'ru': 'Политики конфиденциальности',
      'en': 'Privacy Policy',
    },
    '5judxscj': {
      'ru': 'Вспомнили пароль? ',
      'en': 'Remembered your password? ',
    },
    '7r35sif1': {
      'ru': 'Вернуться',
      'en': 'Return',
    },
    'u53j6w73': {
      'ru': 'Home',
      'en': 'Home',
    },
  },
  // policy
  {
    'xfsjdmlr': {
      'ru': 'Политика\nконфиденциальности',
      'en': 'Privacy Policy',
    },
    'czklyx18': {
      'ru': 'Дата вступления в силу: 28 ноября 2025 г.',
      'en': 'Effective Date: November 28, 2025',
    },
    '00inco2o': {
      'ru': '1. Общие положения',
      'en': '1. General Provisions',
    },
    'ttebd0yi': {
      'ru':
          'Small Talk (\"мы\", \"нас\", \"наше приложение\") уважает вашу конфиденциальность и обязуется защищать персональные данные пользователей. Настоящая Политика конфиденциальности описывает, какую информацию мы собираем, как мы её используем, храним и защищаем.\nИспользуя приложение Small Talk, вы соглашаетесь со сбором и использованием информации в соответствии с настоящей Политикой.',
      'en':
          'Small Talk (\"we,\" \"us,\" or \"our app\") respects your privacy and is committed to protecting your personal information. This Privacy Policy describes what information we collect, how we use, store, and protect it.\nBy using the Small Talk app, you consent to the collection and use of information in accordance with this Policy.',
    },
    'l9d370gj': {
      'ru': '2. Какую информацию мы собираем',
      'en': '2. What information do we collect?',
    },
    'u78z43s6': {
      'ru':
          '2.1. Информация, которую вы предоставляете\n\nРегистрационные данные: имя, адрес электронной почты, пароль, пол (по желанию)\nПрофильная информация: фото профиля, информация \"О себе\", языковые предпочтения, предпочтения по местоположению собеседника\nПлатёжная информация: данные банковской карты (обрабатываются через защищённые платёжные системы)\nКонтент общения: текстовые сообщения в чате, субтитры разговоров\n\n2.2. Информация, собираемая автоматически\n\nДанные об использовании: история разговоров, длительность звонков, время и дата сеансов\nТехническая информация: тип устройства, операционная система, версия приложения, IP-адрес\nДанные о производительности: логи ошибок, сбоев и диагностическая информация\n\n2.3. Аудио и видео\n\nВидеозвонки: видео и аудио передаются в реальном времени через Agora и не записываются и не сохраняются нами\nТранскрипция: субтитры создаются в реальном времени для улучшения обучения, но не сохраняются после завершения звонка',
      'en':
          '2.1. Information You Provide\n\nRegistration Information: Name, Email Address, Password, Gender (optional)\nProfile Information: Profile Photo, About Me, Language Preferences, Location Preferences\nPayment Information: Bank Card Details (processed through secure payment systems)\nCommunication Content: Text Messages in Chat, Conversation Captions\n\n2.2. Information Collected Automatically\n\nUsage Data: Conversation History, Call Duration, Time and Date of Sessions\nTechnical Information: Device Type, Operating System, App Version, IP Address\nPerformance Data: Error Logs, Crash Logs, and Diagnostic Information\n\n2.3. Audio and Video\n\nVideo Calls: Video and audio are transmitted in real time through Agora and are not recorded or stored by us.\nTranscription: Captions are created in real time to enhance learning, but are not stored after the call ends.',
    },
    'knl0nrpp': {
      'ru': '3. Как мы используем вашу информацию',
      'en': '3. How we use your information',
    },
    '0yy4lfbi': {
      'ru':
          'Мы используем собранную информацию для:\n\nПредоставления услуг: соединение с собеседниками, проведение видеозвонков, управление балансом\nУлучшения качества: анализ использования приложения, выявление проблем, улучшение функционала\nПерсонализации: подбор собеседников согласно вашим предпочтениям, рекомендации\nКоммуникации: отправка уведомлений о звонках, важных обновлениях, технической поддержке\nБезопасности: предотвращение мошенничества, защита пользователей, модерация контента\nБиллинга: обработка платежей, начисление вознаграждений носителям языка, формирование истории транзакций',
      'en':
          'We use the collected information for:\n\nService provision: connecting with users, conducting video calls, managing your balance\nQuality improvement: analyzing app usage, identifying issues, improving functionality\nPersonalization: matching users to your preferences, making recommendations\nCommunications: sending notifications about calls, important updates, and technical support\nSecurity: preventing fraud, protecting users, moderating content\nBilling: processing payments, awarding native speakers, generating transaction history',
    },
    'ca70uab5': {
      'ru': '4. Как мы делимся вашей информацией',
      'en': '4. How we share your information',
    },
    '41wy02qp': {
      'ru':
          '4.1. С другими пользователями\n\nВаше имя, фото профиля и информация \"О себе\" видны собеседникам во время звонков\nВаши оценки и отзывы отображаются в профилях носителей языка (если вы оставляете отзыв)\n\n4.2. С сервис-провайдерами\nМы используем сторонние сервисы для:\n\nFirebase: хранение данных, аутентификация, облачные функции\nAgora: проведение видеозвонков в реальном времени\nПлатёжные системы: обработка платежей и выплат (данные карт обрабатываются напрямую платёжными провайдерами)\nАналитика: анализ использования и улучшение приложения (анонимизированные данные)\n\n4.3. По закону\nМы можем раскрыть вашу информацию:\n\nПо требованию закона или государственных органов\nДля защиты наших прав, безопасности пользователей или расследования мошенничества\nВ случае реорганизации, слияния или продажи компании',
      'en':
          '4.1. With Other Users\n\nYour name, profile photo, and \"About Me\" information are visible to other users during calls.\nYour ratings and reviews are displayed in native speaker profiles (if you leave a review).\n\n4.2. With Service Providers\nWe use third-party services for:\n\nFirebase: data storage, authentication, cloud features\nAgora: real-time video calls\nPayment Systems: payment and payout processing (card data is processed directly by payment providers)\nAnalytics: usage analysis and app improvement (anonymized data)\n\n4.3. By Law\nWe may disclose your information:\n\nWhen required by law or government authorities\nTo protect our rights, user safety, or to investigate fraud\nIn the event of a reorganization, merger, or sale of the company',
    },
    'dt5pemdf': {
      'ru': '5. Хранение данных',
      'en': '5. Data storage',
    },
    'm9g24qvb': {
      'ru':
          'Личные данные: хранятся, пока ваш аккаунт активен или необходимо для предоставления услуг\nИстория разговоров: метаданные (длительность, дата, время) хранятся для биллинга и статистики\nУдалённые аккаунты: персональные данные удаляются в течение 30 дней после запроса на удаление аккаунта\nРезервное копирование: может храниться до 90 дней для восстановления в случае технических сбоев',
      'en':
          'Personal data: stored as long as your account is active or as needed to provide services\nCall history: metadata (duration, date, time) is stored for billing and statistics\nDeleted accounts: personal data is deleted within 30 days of the account deletion request\nBackups: may be stored for up to 90 days for recovery in case of technical failures',
    },
    'zqtodugk': {
      'ru': '6. Безопасность данных',
      'en': '6. Data security',
    },
    'f4cv0dej': {
      'ru':
          'Мы применяем современные технологии для защиты вашей информации:\n\nШифрование данных при передаче (SSL/TLS)\nЗащищённое хранение в базах данных Firebase\nОграниченный доступ к персональным данным только для авторизованного персонала\nРегулярный мониторинг безопасности и обновления систем защиты\n\nВажно: несмотря на наши усилия, ни один метод передачи данных через интернет не является абсолютно безопасным.',
      'en':
          'We use modern technologies to protect your information:\n\nData encryption during transmission (SSL/TLS)\nSecure storage in Firebase databases\nRestricted access to personal data to authorized personnel only\nRegular security monitoring and security system updates\n\nImportant: Despite our best efforts, no method of transmitting data over the internet is completely secure.',
    },
    'm4x662t6': {
      'ru': '7. Ваши права',
      'en': '7. Your rights',
    },
    'fqnb17ee': {
      'ru':
          'Вы имеете право:\n\nДоступ: запросить копию ваших персональных данных\nИсправление: обновить неточную или неполную информацию\nУдаление: запросить удаление вашего аккаунта и данных\nОграничение обработки: ограничить использование ваших данных\nПереносимость: получить ваши данные в структурированном формате\nОтзыв согласия: отозвать согласие на обработку данных (это может повлиять на возможность использования приложения)\n\nДля реализации этих прав свяжитесь с нами по адресу: [email защиты данных]',
      'en':
          'You have the right to:\n\nAccess: Request a copy of your personal data\nCorrection: Update inaccurate or incomplete information\nErasure: Request deletion of your account and data\nRestriction of processing: Restrict the use of your data\nPortability: Receive your data in a structured format\nWithdrawal of consent: Withdraw consent to data processing (this may affect your ability to use the app)\n\nTo exercise these rights, please contact us at [data protection email]',
    },
    '4de90uf9': {
      'ru': '8. Файлы cookie и технологии отслеживания',
      'en': '8. Cookies and Tracking Technologies',
    },
    'hwz018hb': {
      'ru':
          'Мы используем файлы cookie и аналогичные технологии для:\n\nСохранения ваших предпочтений и настроек\nАнализа использования приложения\nОбеспечения безопасности и предотвращения мошенничества\n\nВы можете контролировать использование файлов cookie через настройки вашего устройства.',
      'en':
          'We use cookies and similar technologies to:\n\nStoring your preferences and settings\nAnalyzing app usage\nEnsuring security and preventing fraud\n\nYou can control the use of cookies through your device settings.',
    },
    '8sdsub64': {
      'ru': '9. Уведомления',
      'en': '9. Notifications',
    },
    '9o4binxg': {
      'ru':
          'Вы можете получать:\n\nУведомления о звонках: VoIP-уведомления о входящих звонках\nСервисные уведомления: информация о балансе, транзакциях, технических обновлениях\nМаркетинговые уведомления (опционально): новости, специальные предложения\n\nВы можете управлять настройками уведомлений в разделе \"Настройки\" приложения.',
      'en':
          'You can receive:\n\nCall notifications: VoIP notifications for incoming calls\nService notifications: balance information, transactions, and technical updates\nMarketing notifications (optional): news, special offers\n\nYou can manage notification settings in the \"Settings\" section of the app.',
    },
    'va83u8gv': {
      'ru': '10. Изменения в Политике конфиденциальности',
      'en': '10. Changes to the Privacy Policy',
    },
    'c70i9skq': {
      'ru':
          'Мы можем периодически обновлять настоящую Политику конфиденциальности. О существенных изменениях мы уведомим вас через:\n\nУведомление в приложении\nЭлектронную почту (на адрес, указанный при регистрации)\nОбновление даты \"Дата вступления в силу\" в начале документа\n\nРекомендуем периодически просматривать эту страницу для ознакомления с актуальной информацией.',
      'en':
          'We may update this Privacy Policy from time to time. We will notify you of significant changes via:\n\nIn-app notification\nEmail (to the address you provided during registration)\nUpdating the \"Effective Date\" date at the top of this document\n\nWe recommend that you periodically review this page for the latest information.',
    },
    'su42pbdb': {
      'ru': '11. Контактная информация',
      'en': '11. Contact information',
    },
    'u7llfjy4': {
      'ru':
          'Если у вас есть вопросы о настоящей Политике конфиденциальности или практиках обработки данных, свяжитесь с нами:\nEmail: [ваш контактный email]\nАдрес: [юридический адрес компании]\nСлужба поддержки: [контакты поддержки в приложении]',
      'en':
          'If you have any questions about this Privacy Policy or our data processing practices, please contact us:\nEmail: [your contact email]\nAddress: [company legal address]\nSupport: [support contacts in the app]',
    },
    'dhdlspw7': {
      'ru': 'Согласие',
      'en': 'Agreement',
    },
    'cfh32zir': {
      'ru':
          'Используя Small Talk, вы подтверждаете, что прочитали, поняли и согласны с условиями настоящей Политики конфиденциальности.',
      'en':
          'By using Small Talk, you acknowledge that you have read, understood, and agree to the terms of this Privacy Policy.',
    },
    'gcd5d56f': {
      'ru': '© 2025 Small Talk. Все права защищены.',
      'en': '© 2025 Small Talk. All rights reserved.',
    },
    '3k5hrp8g': {
      'ru': 'Home',
      'en': 'Home',
    },
  },
  // payCopy
  {
    '136foxwx': {
      'ru': 'Текущий баланс',
      'en': 'Current balance',
    },
    'lv5jpiff': {
      'ru': 'Р',
      'en': 'Р',
    },
    'sivg0euc': {
      'ru': '\$1,200',
      'en': '\$1,200',
    },
    'j9s3fbnb': {
      'ru': 'Выберите способ вывода',
      'en': 'Select a withdrawal method',
    },
    'ljhzclav': {
      'ru': 'Добавить карту',
      'en': 'Add a map',
    },
    'qpndbc1w': {
      'ru': 'История операций',
      'en': 'Operation history',
    },
    'njy9zp1m': {
      'ru': 'Все',
      'en': 'All',
    },
    'hc7flvjs': {
      'ru': 'Пополнения',
      'en': 'Replenishments',
    },
    'f5efiq3t': {
      'ru': 'Списания',
      'en': 'Write-offs',
    },
    'qzktwdnl': {
      'ru': 'Финансы',
      'en': 'Finance',
    },
    'djp5cokc': {
      'ru': 'Вывести',
      'en': 'Withdraw',
    },
    'bpvnxnx6': {
      'ru': '',
      'en': '',
    },
    '7027okqs': {
      'ru': 'Home',
      'en': 'Home',
    },
  },
  // payWebWiew
  {
    'yhgsg8gy': {
      'ru': 'Оплата',
      'en': 'Payment',
    },
    '6x6ver5z': {
      'ru': 'Home',
      'en': 'Home',
    },
  },
  // blackList
  {
    'qjrrp4il': {
      'ru': 'Ченый список',
      'en': 'Blacklist',
    },
    'ktjc28ij': {
      'ru': 'Home',
      'en': 'Home',
    },
  },
  // myRewNS
  {
    'xw59o8hf': {
      'ru': '5',
      'en': '5',
    },
    'az5s0d0c': {
      'ru': '',
      'en': '',
    },
    'oyswu6kn': {
      'ru': '4',
      'en': '4',
    },
    'ikzopmv8': {
      'ru': '',
      'en': '',
    },
    '6r6bosmv': {
      'ru': '3',
      'en': '3',
    },
    '61832c59': {
      'ru': '',
      'en': '',
    },
    'v1flzexo': {
      'ru': '2',
      'en': '2',
    },
    'trns98en': {
      'ru': '',
      'en': '',
    },
    'rek4xcp6': {
      'ru': '1',
      'en': '1',
    },
    '1xe9zhqj': {
      'ru': '',
      'en': '',
    },
    'qs8nwyrv': {
      'ru': 'Все',
      'en': 'All',
    },
    'xlaf7fli': {
      'ru': '5',
      'en': '5',
    },
    'jw9lsb40': {
      'ru': '4',
      'en': '4',
    },
    'ydhuju4o': {
      'ru': '3',
      'en': '3',
    },
    'tcptiwm7': {
      'ru': '2',
      'en': '2',
    },
    'kawozwy8': {
      'ru': '1',
      'en': '1',
    },
    '6on93f38': {
      'ru': 'Мои отзывы',
      'en': 'My reviews',
    },
    '3wlx885g': {
      'ru': 'Home',
      'en': 'Home',
    },
  },
  // favorite
  {
    'hq7s4leg': {
      'ru': 'Избранное',
      'en': 'Favorites',
    },
    'svwzaze6': {
      'ru': 'Home',
      'en': 'Home',
    },
  },
  // NavBar
  {
    '2hh3j18i': {
      'ru': 'Главная',
      'en': 'Home',
    },
    'j96epnpj': {
      'ru': 'Профиль',
      'en': 'Profile',
    },
    '3ste14ts': {
      'ru': 'Главная',
      'en': 'Home',
    },
    'bhpm1ddo': {
      'ru': 'Словарь',
      'en': 'Dictionary',
    },
    '04sylp8f': {
      'ru': 'Профиль',
      'en': 'Profile',
    },
  },
  // newWord
  {
    'dciexor0': {
      'ru': '🇺🇸',
      'en': '🇺🇸',
    },
    'p23lw41o': {
      'ru': '🇷🇺',
      'en': '🇷🇺',
    },
    'wwfgr0mf': {
      'ru': ' ',
      'en': '',
    },
    'c1hnqtt4': {
      'ru': 'Примеры',
      'en': 'Examples',
    },
  },
  // edit_name
  {
    'rivukcpq': {
      'ru': 'Имя',
      'en': 'Name',
    },
    'vvf76qj0': {
      'ru': 'Ваше имя',
      'en': 'Name',
    },
    'p3ygumv3': {
      'ru': 'Сохранить',
      'en': 'Save',
    },
  },
  // edit_gendeer
  {
    '06nighy4': {
      'ru': 'Как вы себя идентифицируете?',
      'en': 'How do you identify yourself?',
    },
    'snk4d2km': {
      'ru': 'Сохранить',
      'en': 'Save',
    },
  },
  // edit_lang
  {
    'wp5usl3v': {
      'ru': 'Сохранить',
      'en': 'Save',
    },
  },
  // edit_about
  {
    'v997ihxn': {
      'ru': 'Расскажите о себе',
      'en': 'Tell us about yourself',
    },
    'hc796dq5': {
      'ru': '',
      'en': '',
    },
    'tjmgsp1u': {
      'ru': 'Люблю готовить, изучаю испанский для переезда в Барселону',
      'en': 'I love to cook and am learning Spanish to move to Barcelona.',
    },
    'bcopjm5n': {
      'ru': 'Сохранить',
      'en': 'Save',
    },
  },
  // edit_target
  {
    '2sp7ybe9': {
      'ru': 'Цели изучения языка',
      'en': 'Objectives of language learning',
    },
    'ttv2n2du': {
      'ru': 'Путешествия',
      'en': 'Trips',
    },
    'id571obg': {
      'ru': 'Работа',
      'en': 'Job',
    },
    'wc6ds33w': {
      'ru': 'Учеба',
      'en': 'Studies',
    },
    '4zdz2z83': {
      'ru': 'Культура',
      'en': 'Culture',
    },
    'iu8bnfx7': {
      'ru': 'Общение',
      'en': 'Communication',
    },
    'cc6sb20q': {
      'ru': 'Другое',
      'en': 'Other',
    },
    '6k2h1hbt': {
      'ru': 'Сохранить',
      'en': 'Save',
    },
  },
  // rate_app
  {
    'zdoma2f2': {
      'ru': 'Мне всё нравится',
      'en': 'I like everything',
    },
    'l6e566yv': {
      'ru': 'Классный дизайн',
      'en': 'Cool design',
    },
    '5ptxzwam': {
      'ru': 'В приложении сложно разобраться',
      'en': 'The app is difficult to understand',
    },
    'j8iejnb0': {
      'ru': 'Есть технические проблемы',
      'en': 'There are technical problems',
    },
    '95l4bk9r': {
      'ru': 'Не хватает некоторых функций',
      'en': 'Some features are missing',
    },
    '3cd9u8tj': {
      'ru': '',
      'en': '',
    },
    'lu693psw': {
      'ru': 'Что нравится, а что нет...',
      'en': 'What I like and what I don\'t...',
    },
    'nymvvzvm': {
      'ru':
          'Мы читаем каждое сообщение. Если нас хвалят - радуемся. Если ругают - думаем, как всё исправить. Без вас ничего бы не получилось!',
      'en':
          'We read every message. If we\'re praised, we rejoice. If we\'re criticized, we think about how to improve. Without you, none of this would have happened!',
    },
  },
  // Report
  {
    'rgjzzzot': {
      'ru': 'Telegram',
      'en': 'Telegram',
    },
    's4ea1b59': {
      'ru': 'Почта',
      'en': 'Mail',
    },
    'hm8aug9i': {
      'ru': 'Отмена',
      'en': 'Cancel',
    },
  },
  // stats
  {
    'h312ck10': {
      'ru': 'Статистика',
      'en': 'Statistics',
    },
    'gjvp0dj5': {
      'ru': 'Слов добавлено',
      'en': 'Words added',
    },
    'aqgjojma': {
      'ru': 'Заработано',
      'en': 'Earned',
    },
    'f5hs0e1o': {
      'ru': 'Звонков всего',
      'en': 'Total calls',
    },
    'abrmh1eb': {
      'ru': 'Минут в разговоре',
      'en': 'Minutes of conversation',
    },
    'wzrvlh74': {
      'ru': 'Готово',
      'en': 'Done',
    },
  },
  // uploud_photo
  {
    'iyme8lbo': {
      'ru': 'Сделать фото',
      'en': 'Take a photo',
    },
    'vccvxygt': {
      'ru': 'Выбрать из галереи',
      'en': 'Select from gallery',
    },
    '9a4q6avd': {
      'ru': 'Отмена',
      'en': 'Cancel',
    },
  },
  // send
  {
    'olh1jz6w': {
      'ru': 'Проверьте почту!',
      'en': 'Check your mail!',
    },
    '72up7lns': {
      'ru':
          'Письм с инструкцей по восстановлению пароля отправлено на указанный email',
      'en':
          'An email with password recovery instructions has been sent to the specified email address.',
    },
    '4efn2nfa': {
      'ru': 'Готово',
      'en': 'Done',
    },
  },
  // CelebrationST
  {
    'pi17owq7': {
      'ru': 'Юх-ху!',
      'en': 'Woo-hoo!',
    },
    'prix1jqc': {
      'ru': 'Поздравляем 🎉 ',
      'en': 'Congratulations 🎉',
    },
    'mwkxiv2y': {
      'ru': 'ваш профиль готов',
      'en': 'your profile is ready',
    },
    '0ejtqqi8': {
      'ru': 'Вы получили:',
      'en': 'You received:',
    },
    'mxcws2mx': {
      'ru': '10 минут бесплатного общения',
      'en': '10 minutes of free communication',
    },
    'zm25ye6b': {
      'ru': 'Более точный подбор собеседников',
      'en': 'More precise selection of interlocutors',
    },
    'a99tuqpu': {
      'ru': 'Приоритет в поиске',
      'en': 'Search priority',
    },
    'o2lqwjf0': {
      'ru': 'Всё готово для первого разговора с носителем языка!',
      'en':
          'Everything is ready for your first conversation with a native speaker!',
    },
    'mc34azc3': {
      'ru': 'Юх-ху!',
      'en': 'Woo-hoo!',
    },
    'x2jzhu8o': {
      'ru': 'Хорошее начало,',
      'en': 'Good start,',
    },
    '5s3400tx': {
      'ru': 'Завершите профиль\nв настройках и получите:',
      'en': 'Complete your profile\nin settings and receive:',
    },
    'qanvejyj': {
      'ru': '+2 минуты бесплатно',
      'en': '+2 minutes free',
    },
    'zepdvxdb': {
      'ru': 'Более точный подбор собеседников',
      'en': 'More precise selection of interlocutors',
    },
    'wswb8jsg': {
      'ru': 'Приоритет в результатах поиска',
      'en': 'Priority in search results',
    },
    'yq11lpzm': {
      'ru': 'Основная информация готова. \nМожете начинать общаться!',
      'en': 'The basic information is ready.\nYou can start chatting!',
    },
  },
  // av
  {
    'zlkfpu1u': {
      'ru': 'Какой ты сегодня',
      'en': 'What are you like today',
    },
    'v5m8e59n': {
      'ru': 'Сохранить',
      'en': 'Save',
    },
  },
  // lang
  {
    'fo4zvvcg': {
      'ru': 'Поиск',
      'en': 'Search',
    },
  },
  // edit_level
  {
    'si04kwhp': {
      'ru': 'Ваш текущий уровень',
      'en': 'Your current level',
    },
    'jdmn59oq': {
      'ru': 'Начальный',
      'en': 'Elementary',
    },
    'dtdv1d38': {
      'ru': 'Знаю базовые фразы и слова\nA1-A2',
      'en': 'I know basic phrases and words\nA1-A2',
    },
    '9h701ha8': {
      'ru': 'Базовый',
      'en': 'Base',
    },
    'nhcwv72l': {
      'ru': 'Могу поддержать простой разговор\nB1-B2',
      'en': 'I can hold a simple conversation\nB1-B2',
    },
    'dapjexca': {
      'ru': 'Уверенный',
      'en': 'Confident',
    },
    '9jdrum1l': {
      'ru': 'Говорю свободно на большинство тем\nC1-C2',
      'en': 'I speak fluently on most topics\nC1-C2',
    },
    'sr30phpi': {
      'ru': 'Свободно',
      'en': 'Free',
    },
    'bh0f4y7s': {
      'ru': 'Владею как родным\nNative',
      'en': 'I speak Native like a native.\nNative',
    },
    'qxr4lsyg': {
      'ru': 'Начальный',
      'en': 'Elementary',
    },
    'gkwtxis0': {
      'ru': 'Базовый',
      'en': 'Base',
    },
    'xiioo516': {
      'ru': 'Уверенный',
      'en': 'Confident',
    },
    'av3obfx6': {
      'ru': 'Свободно',
      'en': 'Free',
    },
    'bhanvnef': {
      'ru': 'Сохранить',
      'en': 'Save',
    },
  },
  // country
  {
    'gx50uyoo': {
      'ru': 'Поиск',
      'en': 'Search',
    },
  },
  // Acquaintance_NS_START
  {
    'zngmaqpc': {
      'ru': 'Станьте носителем языка',
      'en': 'Become a native speaker',
    },
    'fwacgl87': {
      'ru': 'Помогайте другим практиковать ваш родной язык и зарабатывайте',
      'en': 'Help others practice your native language and earn money',
    },
    'dkjkpn0t': {
      'ru': 'Гибкий график',
      'en': 'Flexible schedule',
    },
    'ieg9smx1': {
      'ru': 'Общайтесь из любой точки мира',
      'en': 'Chat from anywhere in the world',
    },
    'w2jb61uy': {
      'ru': 'Получайте оплату за разговоры',
      'en': 'Get paid for your calls',
    },
    'fzpcok5b': {
      'ru': 'Заполнить анкету',
      'en': 'Fill out the form',
    },
  },
  // CelebrationNS
  {
    'r89oxs81': {
      'ru': 'Юх-ху!',
      'en': 'Woo-hoo!',
    },
    'lnkpv25r': {
      'ru': 'Поздравляем 🎉 ',
      'en': 'Congratulations 🎉',
    },
    'wvb1ct99': {
      'ru': 'ваш профиль готов',
      'en': 'your profile is ready',
    },
    'i6itymsj': {
      'ru': 'Теперь вы можете:',
      'en': 'Now you can:',
    },
    'm3qrtm7o': {
      'ru': 'Принимать запросы от учеников',
      'en': 'Accept requests from students',
    },
    'u052xfsi': {
      'ru': 'Зарабатывать на разговорах',
      'en': 'Make money by talking',
    },
    'ig33jmve': {
      'ru': 'Получать отзывы и рейтинг',
      'en': 'Receive reviews and ratings',
    },
    'ymgeslpv': {
      'ru': 'Ученики уже могут найти вас и отправить запрос на разговор',
      'en': 'Students can now find you and send a request to chat.',
    },
  },
  // edit_country
  {
    'z2pbajmj': {
      'ru': 'Сохранить',
      'en': 'Save',
    },
  },
  // delete
  {
    '7vr6l6ry': {
      'ru': 'Удаление аккаунта',
      'en': 'Deleting an account',
    },
    'jgyobu2a': {
      'ru': 'Вы точно хотите уйти?',
      'en': 'Are you sure you want to leave?',
    },
    '2ugquugx': {
      'ru':
          'Это действие нельзя отменить, и нам придется удалить все ваши данные',
      'en':
          'This action cannot be undone and we will have to delete all your data.',
    },
    'jx33v3a7': {
      'ru': 'Удалить аккаунт',
      'en': 'Delete account',
    },
    'wxna6225': {
      'ru': 'Отменить',
      'en': 'Cancel',
    },
  },
  // logout
  {
    'zd4lq385': {
      'ru': 'Вы уверены, что хотите выйти',
      'en': 'Are you sure you want to exit?',
    },
    'j9kmlyfd': {
      'ru':
          'Это действие нельзя отменить, и нам придется удалить все ваши данные',
      'en':
          'This action cannot be undone and we will have to delete all your data.',
    },
    '8iuccsuc': {
      'ru': 'Выйти',
      'en': 'Exit',
    },
    'op5siu4w': {
      'ru': 'Отменить',
      'en': 'Cancel',
    },
  },
  // edit_avatar
  {
    'nvje9sm9': {
      'ru': 'Выберите аватар',
      'en': 'Select an avatar',
    },
    'mhdxqa8u': {
      'ru': 'Или загрузить своё фото',
      'en': 'Or upload your photo',
    },
    'noxdyq69': {
      'ru': 'Сохранить',
      'en': 'Save',
    },
  },
  // langApp
  {
    '2wr6p6ar': {
      'ru': 'Язык приложения',
      'en': 'Application language',
    },
    'lbypxcbp': {
      'ru': 'Сохранить',
      'en': 'Save',
    },
  },
  // woed
  {
    '3d0bey8j': {
      'ru': '🇺🇸',
      'en': '🇺🇸',
    },
    'scaig71z': {
      'ru': '🇷🇺',
      'en': '🇷🇺',
    },
    'lpzroxlx': {
      'ru': ' ',
      'en': '',
    },
    '7118sl5m': {
      'ru': 'Примеры',
      'en': 'Examples',
    },
  },
  // add_card
  {
    '6wfkgk3t': {
      'ru': 'Добавить способ вывода',
      'en': 'Add a withdrawal method',
    },
    '3yeveeq0': {
      'ru': 'Номер карты',
      'en': 'Card number',
    },
    'vzfl7tbq': {
      'ru': 'Поле должно содержать от 16 символов',
      'en': 'The field must contain at least 16 characters.',
    },
    'un33x35j': {
      'ru': 'Поле должно содержать от 16 символов',
      'en': 'The field must contain at least 16 characters.',
    },
    '76606mzd': {
      'ru': 'Поле должно содержать до 24 символов',
      'en': 'The field must contain up to 24 characters.',
    },
    'fugxvcj6': {
      'ru': 'Please choose an option from the dropdown',
      'en': 'Please choose an option from the dropdown',
    },
    'v2jfujr9': {
      'ru': 'Добавить карту',
      'en': 'Add card',
    },
  },
  // edit_card
  {
    'o063iu8b': {
      'ru': 'Изменение способов вывода',
      'en': 'Changing withdrawal methods',
    },
    'am3nucgj': {
      'ru': '*** 4334',
      'en': '*** 4334',
    },
    'fj7u70af': {
      'ru': 'Готово',
      'en': 'Done',
    },
  },
  // deleteCard
  {
    '8iw8rarz': {
      'ru': 'Удалить сохраненную карту?',
      'en': 'Delete saved card?',
    },
    'j3b1pdz7': {
      'ru': '*** 4334',
      'en': '*** 4334',
    },
    'ikt9ul7g': {
      'ru': 'Удалить карту',
      'en': 'Delete card',
    },
    'c3z3ihcx': {
      'ru': 'Не сейчас',
      'en': 'Not now',
    },
  },
  // filters
  {
    '507c1jln': {
      'ru': 'Фильтры',
      'en': 'Filters',
    },
    'nu210379': {
      'ru': 'Язык зучения',
      'en': 'Language of learning',
    },
    'qdxe0ygf': {
      'ru': 'Язык cобеседника',
      'en': 'Language of the interlocutor',
    },
    'dtstv5e7': {
      'ru': 'Локация cобеседника',
      'en': 'Location of the interlocutor',
    },
    'z87iidnf': {
      'ru': 'Готово',
      'en': 'Done',
    },
  },
  // add_inter
  {
    'doo4eaqe': {
      'ru': 'Добавить интервал',
      'en': 'Add interval',
    },
    'k5nqxijy': {
      'ru': 'Буду доступен с',
      'en': 'I will be available from',
    },
    '3cadl3j2': {
      'ru': 'до',
      'en': 'to',
    },
    'bzho8r5y': {
      'ru': 'Добавить интервал',
      'en': 'Add interval',
    },
  },
  // Miscellaneous
  {
    'lljq5xas': {
      'ru': '',
      'en': '',
    },
    '51jv98uy': {
      'ru': '',
      'en': '',
    },
    'g07xayx5': {
      'ru': 'Для видеозвонков и изучения иностранных языков',
      'en': 'For video calls and learning foreign languages',
    },
    'oyox2zza': {
      'ru': 'Для голосового общения и создания субтитров во время урока',
      'en': 'For voice communication and creating subtitles during the lesson',
    },
    '2j0sgrb9': {
      'ru': 'вап',
      'en': 'wap',
    },
    'r4t087i0': {
      'ru': 'укеуке',
      'en': 'ukeuke',
    },
    '0ubtjayt': {
      'ru': 'укеукеу',
      'en': 'ukeukeu',
    },
    '60fb8f43': {
      'ru': 'Ошибка',
      'en': 'Error',
    },
    '7mczn45o': {
      'ru': 'Ссылка на сборс пароля отправлена на вашу почту',
      'en': 'A link to collect your password has been sent to your email.',
    },
    'rizvdi40': {
      'ru': 'Почта не заполнена',
      'en': 'The mail is not filled',
    },
    'b7lmnf37': {
      'ru': 'Номер телефона не заполнен и должен начинаться с +',
      'en': 'The phone number is empty and must start with +',
    },
    'cosiekyi': {
      'ru': 'Пароли не совпадают',
      'en': 'The passwords don\'t match',
    },
    'hh2w7pvl': {
      'ru': 'Введите код подтверждения',
      'en': 'Enter the confirmation code',
    },
    '85lj4aua': {
      'ru':
          'Прошло много времени с последнего входа. Зайдите еще раз, чтобы удалить аккаунт',
      'en':
          'It\'s been a while since you last logged in. Please log in again to delete your account.',
    },
    'k3mw5pe7': {
      'ru':
          'Прошло много времени с последнего входа. Зайдите еще раз, чтобы обновить почту',
      'en':
          'It\'s been a while since you last logged in. Please log in again to update your email.',
    },
    'e01skyqu': {
      'ru': 'Ссылка на подтверждение почты отправлена',
      'en': 'Email confirmation link sent',
    },
    'qw84zdr4': {
      'ru': 'Эта почта уже использовалась при создании аккаунта',
      'en': 'This email has already been used to create an account.',
    },
    'euaras4g': {
      'ru':
          'Предоставленные учетные данные для авторизации неверны, введены неправильно или срок их действия истек',
      'en':
          'The provided login credentials are incorrect, entered incorrectly, or have expired.',
    },
    '56pk8mxq': {
      'ru': '',
      'en': '',
    },
    'u1mw1dsd': {
      'ru': '',
      'en': '',
    },
    '99h2f9rd': {
      'ru': '',
      'en': '',
    },
    'ct074hf5': {
      'ru': '',
      'en': '',
    },
    'dgi7kvnb': {
      'ru': '',
      'en': '',
    },
    '7jngk88z': {
      'ru': '',
      'en': '',
    },
    '5cmidyg1': {
      'ru': '',
      'en': '',
    },
    'a5dg5rhk': {
      'ru': '',
      'en': '',
    },
    'nudha118': {
      'ru': '',
      'en': '',
    },
    '13ryp37z': {
      'ru': '',
      'en': '',
    },
    'okurzn7s': {
      'ru': '',
      'en': '',
    },
    '7mgsuq3w': {
      'ru': '',
      'en': '',
    },
    's1jga4mi': {
      'ru': '',
      'en': '',
    },
    '57l15b6d': {
      'ru': '',
      'en': '',
    },
  },
].reduce((a, b) => a..addAll(b));
