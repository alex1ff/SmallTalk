import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/translation_repository.dart';

void main() {
  test('classifies unauthenticated integration failures by local auth state',
      () {
    expect(
      classifyCallIntegrationFailure(
        'unauthenticated',
        isAuthenticated: false,
      ),
      'auth_required',
    );
    expect(
      classifyCallIntegrationFailure(
        'unauthenticated',
        isAuthenticated: true,
      ),
      'app_check_required',
    );
    expect(
      classifyCallIntegrationFailure(
        'translation_daily_limit',
        isAuthenticated: true,
      ),
      'translation_daily_limit',
    );
  });

  test('translate calls the regional backend contract and decodes result',
      () async {
    String? calledFunction;
    Map<String, dynamic>? calledPayload;
    final repository = TranslationRepository(
      invoker: (functionName, payload) async {
        calledFunction = functionName;
        calledPayload = payload;
        return <String, dynamic>{
          'sourceText': 'Привет',
          'translatedText': 'Hello',
          'sourceLang': 'ru',
          'targetLang': 'en',
          'lookupId': 'lookup-a',
          'cacheHit': false,
        };
      },
    );

    final result = await repository.translate(
      sessionId: 'session-a',
      text: 'Привет',
      sourceLanguage: TranslationLanguage.russian,
      targetLanguage: TranslationLanguage.english,
    );

    expect(calledFunction, 'translateTerm');
    expect(calledPayload, <String, dynamic>{
      'sessionId': 'session-a',
      'text': 'Привет',
      'sourceLang': 'ru',
      'targetLang': 'en',
    });
    expect(result.translatedText, 'Hello');
    expect(result.lookupId, 'lookup-a');
    expect(result.cacheHit, isFalse);
  });

  test('save uses only the trusted lookup identifier', () async {
    Map<String, dynamic>? calledPayload;
    final repository = TranslationRepository(
      invoker: (_, payload) async {
        calledPayload = payload;
        return <String, dynamic>{
          'wordPath': 'users/user-a/userWords/translation-a',
          'alreadyExisted': true,
        };
      },
    );

    final result = await repository.saveToDictionary(lookupId: 'lookup-a');

    expect(calledPayload, <String, dynamic>{'lookupId': 'lookup-a'});
    expect(result.alreadyExisted, isTrue);
  });

  test('callable domain errors are mapped without provider details', () async {
    final repository = TranslationRepository(
      invoker: (_, __) async => throw FirebaseFunctionsException(
        code: 'resource-exhausted',
        message: 'hidden provider message',
        details: <String, dynamic>{
          'domainCode': 'translation_daily_limit',
          'retryAfterMs': 5000,
        },
      ),
    );

    await expectLater(
      repository.translate(
        sessionId: 'session-a',
        text: 'Привет',
        sourceLanguage: TranslationLanguage.russian,
        targetLanguage: TranslationLanguage.english,
      ),
      throwsA(
        isA<TranslationFailure>()
            .having(
                (failure) => failure.code, 'code', 'translation_daily_limit')
            .having((failure) => failure.retryAfterMs, 'retryAfterMs', 5000),
      ),
    );
  });

  test('malformed callable output is rejected', () async {
    final repository = TranslationRepository(
      invoker: (_, __) async => <String, dynamic>{'translatedText': 'Hello'},
    );

    await expectLater(
      repository.translate(
        sessionId: 'session-a',
        text: 'Привет',
        sourceLanguage: TranslationLanguage.russian,
        targetLanguage: TranslationLanguage.english,
      ),
      throwsFormatException,
    );
  });
}
