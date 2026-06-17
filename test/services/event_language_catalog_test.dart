import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/event_language_catalog.dart';

void main() {
  late EventLanguageCatalog catalog;

  setUpAll(() {
    catalog = EventLanguageCatalog.fromJsonString(
      File(eventLanguageCatalogAssetPath).readAsStringSync(),
    );
  });

  test('loads static event language catalog schema from app asset', () {
    expect(catalog.languages, hasLength(37));
    expect(
        catalog.primaryCodes,
        containsAll(<String>[
          'en',
          'ru',
          'it',
          'zh',
          'zh-TW',
          'nl-BE',
          'de-CH',
        ]));

    final normalizedAliases = <String, String>{};
    for (final language in catalog.languages) {
      expect(language.code, isNotEmpty);
      expect(language.nameEn, isNotEmpty);
      expect(language.nameRu, isNotEmpty);
      expect(language.alternateCodes, contains(language.code));
      expect(language.model, isNotEmpty);
      expect(language.iconUrl, startsWith('https://'));

      for (final alias in language.alternateCodes) {
        final normalizedAlias = alias.trim().toLowerCase();
        final previousPrimaryCode = normalizedAliases[normalizedAlias];
        expect(
          previousPrimaryCode == null || previousPrimaryCode == language.code,
          isTrue,
          reason: '$alias is shared by $previousPrimaryCode and '
              '${language.code}.',
        );
        normalizedAliases[normalizedAlias] = language.code;
      }
    }
  });

  test('looks up primary language codes without using alternates', () {
    expect(catalog.languageByPrimaryCode(' en ')?.nameRu, 'Английский');
    expect(catalog.languageByPrimaryCode('zh-TW')?.nameEn,
        'Chinese (Traditional)');
    expect(catalog.languageByPrimaryCode('EN-us'), isNull);
    expect(catalog.languageByPrimaryCode('unknown'), isNull);
    expect(catalog.languageByPrimaryCode('   '), isNull);
  });

  test('exposes immutable language lists', () {
    expect(
      () => catalog.languages.add(catalog.languages.first),
      throwsUnsupportedError,
    );
    expect(
      () => catalog.languages.first.alternateCodes.add('fake'),
      throwsUnsupportedError,
    );
  });

  test('public factories enforce catalog invariants', () {
    expect(
      () => EventLanguageCatalog(languages: const []),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => EventLanguage(
        code: 'en',
        alternateCodes: const ['eng'],
        nameEn: 'English',
        nameRu: 'Английский',
        model: 'nova-3',
        isPopular: true,
        iconUrl: 'https://example.com/en.png',
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => EventLanguageCatalog(
        languages: [
          eventLanguageFixture(code: 'en', alternateCodes: ['en']),
          eventLanguageFixture(code: 'en', alternateCodes: ['en']),
        ],
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => EventLanguageCatalog(
        languages: [
          eventLanguageFixture(
            code: 'en',
            alternateCodes: ['en', 'shared'],
          ),
          eventLanguageFixture(
            code: 'ru',
            alternateCodes: ['ru', 'shared'],
          ),
        ],
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('returns popular languages in catalog order with optional limit', () {
    final popular = catalog.popularLanguages();

    expect(popular.map((language) => language.code), [
      'en',
      'ru',
      'es',
      'fr',
      'de',
      'zh',
      'ja',
      'ko',
      'it',
      'pt',
      'hi',
    ]);
    expect(
      catalog.popularLanguages(limit: 3).map((language) => language.code),
      ['en', 'ru', 'es'],
    );
    expect(catalog.popularLanguages(limit: 0), isEmpty);
  });

  test('rejects malformed language catalog entries', () {
    expect(
      () => EventLanguageCatalog.fromJsonString('{"languages":[]}'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => EventLanguageCatalog.fromJsonString(
        '[{"code":"en","alternateCodes":["en"],"nameEn":"","nameRu":"A"}]',
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => EventLanguageCatalog.fromList([
        languageFixture(code: 'en', alternateCodes: ['en']),
        languageFixture(code: 'en', alternateCodes: ['en']),
      ]),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => EventLanguageCatalog.fromList([
        languageFixture(code: 'en', alternateCodes: ['en', 'shared']),
        languageFixture(code: 'ru', alternateCodes: ['ru', 'shared']),
      ]),
      throwsA(isA<FormatException>()),
    );
  });
}

EventLanguage eventLanguageFixture({
  required String code,
  required List<String> alternateCodes,
  String nameEn = 'English',
  String nameRu = 'Английский',
  String model = 'nova-3',
  bool isPopular = true,
  String iconUrl = 'https://example.com/language.png',
}) =>
    EventLanguage(
      code: code,
      alternateCodes: alternateCodes,
      nameEn: nameEn,
      nameRu: nameRu,
      model: model,
      isPopular: isPopular,
      iconUrl: iconUrl,
    );

Map<String, dynamic> languageFixture({
  required String code,
  required List<String> alternateCodes,
  String nameEn = 'English',
  String nameRu = 'Английский',
  String model = 'nova-3',
  bool isPopular = true,
  String ss = 'https://example.com/language.png',
}) =>
    <String, dynamic>{
      'code': code,
      'alternateCodes': alternateCodes,
      'nameEn': nameEn,
      'nameRu': nameRu,
      'model': model,
      'isPopular': isPopular,
      'ss': ss,
    };
