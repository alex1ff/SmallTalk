import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/schema/structs/index.dart';
import 'package:small_talk/shared_pages/call_history/call_language_utils.dart';

void main() {
  group('call language utils', () {
    test('normalizes session language codes without dropping regional tags',
        () {
      expect(normalizeSessionLanguageCode(' EN_us '), 'en-us');
      expect(normalizeSessionLanguageCode(null), isEmpty);
    });

    test('matches by primary code, regional fallback, and alternate code', () {
      final languages = <LanguageStruct>[
        LanguageStruct(
          code: 'en',
          nameEn: 'English',
          nameRu: 'Английский',
        ),
        LanguageStruct(
          code: 'zh',
          alternateCodes: <String>['cmn-Hans'],
          nameEn: 'Chinese',
          nameRu: 'Китайский',
        ),
      ];

      expect(
        findSessionLanguageByCode(languages: languages, code: 'en-US')?.code,
        'en',
      );
      expect(
        findSessionLanguageByCode(languages: languages, code: 'cmn_hans')?.code,
        'zh',
      );
      expect(
        findSessionLanguageByCode(languages: languages, code: 'de'),
        isNull,
      );
    });

    test('resolves localized names with raw-code and dash fallbacks', () {
      final languages = <LanguageStruct>[
        LanguageStruct(
          code: 'en',
          nameEn: 'English',
          nameRu: 'Английский',
        ),
        LanguageStruct(
          code: 'kk',
          nameEn: 'Kazakh',
        ),
      ];

      expect(
        resolveSessionLanguageName(
          languages: languages,
          code: 'en-US',
          useRussian: true,
        ),
        'Английский',
      );
      expect(
        resolveSessionLanguageName(
          languages: languages,
          code: 'kk',
          useRussian: true,
        ),
        'Kazakh',
      );
      expect(
        resolveSessionLanguageName(
          languages: languages,
          code: 'de',
          useRussian: false,
        ),
        'de',
      );
      expect(
        resolveSessionLanguageName(
          languages: languages,
          code: '',
          useRussian: false,
        ),
        '-',
      );
    });
  });
}
