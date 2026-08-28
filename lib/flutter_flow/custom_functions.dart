import '/backend/backend.dart';

DocumentReference videoSessionsToRef(String sessionId) {
  return FirebaseFirestore.instance.collection('videoSessions').doc(sessionId);
}

List<SynonymStruct>? syn(
  String gen,
  String text,
  List<SynonymStruct> synonym,
) {
  // Создаем новый SynonymStruct с переданными значениями
  SynonymStruct newSynonym = SynonymStruct(
    gen: gen,
    text: text,
  );

  // Добавляем новый элемент в список
  synonym.add(newSynonym);

  // Возвращаем обновленный список
  return synonym;
}

bool isValidName(String name) {
  final nameRegex = RegExp(r'^[A-Za-zА-Яа-яЁё]+(?: [A-Za-zА-Яа-яЁё]+)*\s*$');
  return nameRegex.hasMatch(name.trim());
}

List<CountryStruct> countriesList() {
  final countries = [
    // Popular English-speaking countries (index 1-6)
    CountryStruct(
      code: 'US',
      nameEn: 'United States',
      nameRu: 'США',
      flag: '🇺🇸',
      isPopular: true,
      index: 1,
    ),
    CountryStruct(
      code: 'GB',
      nameEn: 'United Kingdom',
      nameRu: 'Великобритания',
      flag: '🇬🇧',
      isPopular: true,
      index: 2,
    ),
    CountryStruct(
      code: 'CA',
      nameEn: 'Canada',
      nameRu: 'Канада',
      flag: '🇨🇦',
      isPopular: true,
      index: 3,
    ),
    CountryStruct(
      code: 'AU',
      nameEn: 'Australia',
      nameRu: 'Австралия',
      flag: '🇦🇺',
      isPopular: true,
      index: 4,
    ),
    CountryStruct(
      code: 'IE',
      nameEn: 'Ireland',
      nameRu: 'Ирландия',
      flag: '🇮🇪',
      isPopular: false,
      index: 5,
    ),
    CountryStruct(
      code: 'NZ',
      nameEn: 'New Zealand',
      nameRu: 'Новая Зеландия',
      flag: '🇳🇿',
      isPopular: false,
      index: 6,
    ),
    // Russian-speaking countries (index 7-9)
    CountryStruct(
      code: 'RU',
      nameEn: 'Russia',
      nameRu: 'Россия',
      flag: '🇷🇺',
      isPopular: true,
      index: 7,
    ),
    CountryStruct(
      code: 'BY',
      nameEn: 'Belarus',
      nameRu: 'Беларусь',
      flag: '🇧🇾',
      isPopular: false,
      index: 8,
    ),
    CountryStruct(
      code: 'KZ',
      nameEn: 'Kazakhstan',
      nameRu: 'Казахстан',
      flag: '🇰🇿',
      isPopular: false,
      index: 9,
    ),
    // Spanish-speaking countries (index 10-15)
    CountryStruct(
      code: 'ES',
      nameEn: 'Spain',
      nameRu: 'Испания',
      flag: '🇪🇸',
      isPopular: true,
      index: 10,
    ),
    CountryStruct(
      code: 'MX',
      nameEn: 'Mexico',
      nameRu: 'Мексика',
      flag: '🇲🇽',
      isPopular: true,
      index: 11,
    ),
    CountryStruct(
      code: 'AR',
      nameEn: 'Argentina',
      nameRu: 'Аргентина',
      flag: '🇦🇷',
      isPopular: true,
      index: 12,
    ),
    CountryStruct(
      code: 'CO',
      nameEn: 'Colombia',
      nameRu: 'Колумбия',
      flag: '🇨🇴',
      isPopular: false,
      index: 13,
    ),
    CountryStruct(
      code: 'CL',
      nameEn: 'Chile',
      nameRu: 'Чили',
      flag: '🇨🇱',
      isPopular: false,
      index: 14,
    ),
    CountryStruct(
      code: 'PE',
      nameEn: 'Peru',
      nameRu: 'Перу',
      flag: '🇵🇪',
      isPopular: false,
      index: 15,
    ),
    // French-speaking countries (index 16-18)
    CountryStruct(
      code: 'FR',
      nameEn: 'France',
      nameRu: 'Франция',
      flag: '🇫🇷',
      isPopular: true,
      index: 16,
    ),
    CountryStruct(
      code: 'BE',
      nameEn: 'Belgium',
      nameRu: 'Бельгия',
      flag: '🇧🇪',
      isPopular: false,
      index: 17,
    ),
    CountryStruct(
      code: 'CH',
      nameEn: 'Switzerland',
      nameRu: 'Швейцария',
      flag: '🇨🇭',
      isPopular: true,
      index: 18,
    ),
    // German-speaking countries (index 19-21)
    CountryStruct(
      code: 'DE',
      nameEn: 'Germany',
      nameRu: 'Германия',
      flag: '🇩🇪',
      isPopular: true,
      index: 19,
    ),
    CountryStruct(
      code: 'AT',
      nameEn: 'Austria',
      nameRu: 'Австрия',
      flag: '🇦🇹',
      isPopular: false,
      index: 20,
    ),
    // Chinese-speaking countries (index 21-24)
    CountryStruct(
      code: 'CN',
      nameEn: 'China',
      nameRu: 'Китай',
      flag: '🇨🇳',
      isPopular: true,
      index: 21,
    ),
    CountryStruct(
      code: 'TW',
      nameEn: 'Taiwan',
      nameRu: 'Тайвань',
      flag: '🇹🇼',
      isPopular: false,
      index: 22,
    ),
    CountryStruct(
      code: 'HK',
      nameEn: 'Hong Kong',
      nameRu: 'Гонконг',
      flag: '🇭🇰',
      isPopular: false,
      index: 23,
    ),
    CountryStruct(
      code: 'SG',
      nameEn: 'Singapore',
      nameRu: 'Сингапур',
      flag: '🇸🇬',
      isPopular: true,
      index: 24,
    ),
    // Japanese-speaking countries (index 25)
    CountryStruct(
      code: 'JP',
      nameEn: 'Japan',
      nameRu: 'Япония',
      flag: '🇯🇵',
      isPopular: true,
      index: 25,
    ),
    // Korean-speaking countries (index 26)
    CountryStruct(
      code: 'KR',
      nameEn: 'South Korea',
      nameRu: 'Южная Корея',
      flag: '🇰🇷',
      isPopular: true,
      index: 26,
    ),
    // Italian-speaking countries (index 27)
    CountryStruct(
      code: 'IT',
      nameEn: 'Italy',
      nameRu: 'Италия',
      flag: '🇮🇹',
      isPopular: true,
      index: 27,
    ),
    // Portuguese-speaking countries (index 28-29)
    CountryStruct(
      code: 'PT',
      nameEn: 'Portugal',
      nameRu: 'Португалия',
      flag: '🇵🇹',
      isPopular: false,
      index: 28,
    ),
    CountryStruct(
      code: 'BR',
      nameEn: 'Brazil',
      nameRu: 'Бразилия',
      flag: '🇧🇷',
      isPopular: true,
      index: 29,
    ),
    // Hindi-speaking countries (index 30)
    CountryStruct(
      code: 'IN',
      nameEn: 'India',
      nameRu: 'Индия',
      flag: '🇮🇳',
      isPopular: true,
      index: 30,
    ),
    // Other countries (index 31+)
    CountryStruct(
      code: 'BG',
      nameEn: 'Bulgaria',
      nameRu: 'Болгария',
      flag: '🇧🇬',
      isPopular: false,
      index: 31,
    ),
    CountryStruct(
      code: 'CZ',
      nameEn: 'Czech Republic',
      nameRu: 'Чехия',
      flag: '🇨🇿',
      isPopular: false,
      index: 32,
    ),
    CountryStruct(
      code: 'DK',
      nameEn: 'Denmark',
      nameRu: 'Дания',
      flag: '🇩🇰',
      isPopular: false,
      index: 33,
    ),
    CountryStruct(
      code: 'NL',
      nameEn: 'Netherlands',
      nameRu: 'Нидерланды',
      flag: '🇳🇱',
      isPopular: false,
      index: 34,
    ),
    CountryStruct(
      code: 'FI',
      nameEn: 'Finland',
      nameRu: 'Финляндия',
      flag: '🇫🇮',
      isPopular: false,
      index: 35,
    ),
    CountryStruct(
      code: 'HU',
      nameEn: 'Hungary',
      nameRu: 'Венгрия',
      flag: '🇭🇺',
      isPopular: false,
      index: 36,
    ),
    CountryStruct(
      code: 'ID',
      nameEn: 'Indonesia',
      nameRu: 'Индонезия',
      flag: '🇮🇩',
      isPopular: false,
      index: 37,
    ),
    CountryStruct(
      code: 'NO',
      nameEn: 'Norway',
      nameRu: 'Норвегия',
      flag: '🇳🇴',
      isPopular: false,
      index: 38,
    ),
    CountryStruct(
      code: 'PL',
      nameEn: 'Poland',
      nameRu: 'Польша',
      flag: '🇵🇱',
      isPopular: false,
      index: 39,
    ),
    CountryStruct(
      code: 'SE',
      nameEn: 'Sweden',
      nameRu: 'Швеция',
      flag: '🇸🇪',
      isPopular: false,
      index: 40,
    ),
    CountryStruct(
      code: 'TR',
      nameEn: 'Turkey',
      nameRu: 'Турция',
      flag: '🇹🇷',
      isPopular: false,
      index: 41,
    ),
    CountryStruct(
      code: 'UA',
      nameEn: 'Ukraine',
      nameRu: 'Украина',
      flag: '🇺🇦',
      isPopular: false,
      index: 42,
    ),
    CountryStruct(
      code: 'VN',
      nameEn: 'Vietnam',
      nameRu: 'Вьетнам',
      flag: '🇻🇳',
      isPopular: false,
      index: 43,
    ),
    CountryStruct(
      code: 'AD',
      nameEn: 'Andorra',
      nameRu: 'Андорра',
      flag: '🇦🇩',
      isPopular: false,
      index: 44,
    ),
    CountryStruct(
      code: 'EE',
      nameEn: 'Estonia',
      nameRu: 'Эстония',
      flag: '🇪🇪',
      isPopular: false,
      index: 45,
    ),
    CountryStruct(
      code: 'GR',
      nameEn: 'Greece',
      nameRu: 'Греция',
      flag: '🇬🇷',
      isPopular: false,
      index: 46,
    ),
    CountryStruct(
      code: 'CY',
      nameEn: 'Cyprus',
      nameRu: 'Кипр',
      flag: '🇨🇾',
      isPopular: false,
      index: 47,
    ),
    CountryStruct(
      code: 'LV',
      nameEn: 'Latvia',
      nameRu: 'Латвия',
      flag: '🇱🇻',
      isPopular: false,
      index: 48,
    ),
    CountryStruct(
      code: 'LT',
      nameEn: 'Lithuania',
      nameRu: 'Литва',
      flag: '🇱🇹',
      isPopular: false,
      index: 49,
    ),
    CountryStruct(
      code: 'MY',
      nameEn: 'Malaysia',
      nameRu: 'Малайзия',
      flag: '🇲🇾',
      isPopular: false,
      index: 50,
    ),
    CountryStruct(
      code: 'RO',
      nameEn: 'Romania',
      nameRu: 'Румыния',
      flag: '🇷🇴',
      isPopular: false,
      index: 51,
    ),
    CountryStruct(
      code: 'MD',
      nameEn: 'Moldova',
      nameRu: 'Молдова',
      flag: '🇲🇩',
      isPopular: false,
      index: 52,
    ),
    CountryStruct(
      code: 'SK',
      nameEn: 'Slovakia',
      nameRu: 'Словакия',
      flag: '🇸🇰',
      isPopular: false,
      index: 53,
    ),
    CountryStruct(
      code: 'TH',
      nameEn: 'Thailand',
      nameRu: 'Таиланд',
      flag: '🇹🇭',
      isPopular: false,
      index: 54,
    ),
  ];

  const referenceCountryCodes = [
    'US',
    'DE',
    'ES',
    'FR',
    'IT',
    'PT',
    'NL',
  ];

  return [
    for (var i = 0; i < referenceCountryCodes.length; i++)
      countries
          .firstWhere((country) => country.code == referenceCountryCodes[i])
        ..index = i + 1
        ..isPopular = true,
  ];
}

double recalculateRatingWithNewReview(
  int totalReviews,
  double currentAverageRating,
  int newRating,
) {
  // Сумма всех текущих отзывов
  double totalRatingSum = currentAverageRating * totalReviews;

  // Прибавляем новый рейтинг
  totalRatingSum += newRating;

  // Пересчитываем новый средний рейтинг, увеличив количество отзывов
  double newAverageRating = totalRatingSum / (totalReviews + 1);

  return newAverageRating;
}

bool isWithinFiveMinutes(DateTime lastLoginTime) {
  final now = DateTime.now().toUtc();
  final difference = now.difference(lastLoginTime);
  return difference.inMinutes <= 5;
}

String getReviewString(String number) {
  // Преобразуем строку в число
  final int numValue = int.tryParse(number) ?? 0;

  // Определяем последние две цифры
  int lastTwoDigits = numValue % 100;
  // Определяем последнюю цифру
  int lastDigit = numValue % 10;

  String word;
  if (lastTwoDigits >= 11 && lastTwoDigits <= 19) {
    word = 'отзывов';
  } else if (lastDigit == 1) {
    word = 'отзыв';
  } else if (lastDigit >= 2 && lastDigit <= 4) {
    word = 'отзыва';
  } else {
    word = 'отзывов';
  }
  return '$numValue $word';
}

String getcallNumbString(String number) {
  // Преобразуем строку в число
  final int numValue = int.tryParse(number) ?? 0;

  int lastTwoDigits = numValue % 100;
  int lastDigit = numValue % 10;

  String word;
  if (lastTwoDigits >= 11 && lastTwoDigits <= 19) {
    word = 'звонков';
  } else if (lastDigit == 1) {
    word = 'звонок';
  } else if (lastDigit >= 2 && lastDigit <= 4) {
    word = 'звонка';
  } else {
    word = 'звонков';
  }
  return '$numValue $word';
}

bool aboutt(
  String about,
  double wit,
) {
  if (about.isEmpty) return false;

  const double fontSize = 14.0;
  final double avgCharWidth = fontSize * 0.6;
  final int charsPerLine = (wit / avgCharWidth).floor();

  if (charsPerLine <= 0) return false;

  final int lineCount = (about.length / charsPerLine).ceil();

  return lineCount > 4;
}

bool isValidEmail(String email) {
  final emailRegex =
      RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
  return emailRegex.hasMatch(email);
}

String maskCardNumber(String cardNumber) {
  // Убираем все пробелы
  String digitsOnly = cardNumber.replaceAll(' ', '');

  // Берём последние 4 цифры
  String lastFour = digitsOnly.length >= 4
      ? digitsOnly.substring(digitsOnly.length - 4)
      : digitsOnly;

  return '**** $lastFour';
}

DocumentReference stringToRef(String string) {
  return FirebaseFirestore.instance.collection('users').doc(string);
}
