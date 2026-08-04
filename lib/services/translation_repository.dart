import 'package:cloud_functions/cloud_functions.dart';

typedef TranslationCallableInvoker = Future<Object?> Function(
  String functionName,
  Map<String, dynamic> payload,
);

const callIntegrationsRegion = 'us-central1';

enum TranslationLanguage {
  russian('ru'),
  english('en');

  const TranslationLanguage(this.code);

  final String code;
}

class TranslationResult {
  const TranslationResult({
    required this.sourceText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.lookupId,
    required this.cacheHit,
  });

  final String sourceText;
  final String translatedText;
  final TranslationLanguage sourceLanguage;
  final TranslationLanguage targetLanguage;
  final String lookupId;
  final bool cacheHit;
}

class SavedTranslationResult {
  const SavedTranslationResult({
    required this.wordPath,
    required this.alreadyExisted,
  });

  final String wordPath;
  final bool alreadyExisted;
}

class TranslationFailure implements Exception {
  const TranslationFailure({
    required this.code,
    this.retryAfterMs,
  });

  final String code;
  final int? retryAfterMs;

  bool get isRetryable => const <String>{
        'translation_pending',
        'translation_retry_later',
        'translation_cooldown',
        'translation_provider_unavailable',
        'translation_lease_lost',
      }.contains(code);

  @override
  String toString() => 'TranslationFailure($code)';
}

class TranslationRepository {
  const TranslationRepository({this.invoker});

  final TranslationCallableInvoker? invoker;

  Future<TranslationResult> translate({
    required String sessionId,
    required String text,
    required TranslationLanguage sourceLanguage,
    required TranslationLanguage targetLanguage,
  }) async {
    try {
      final response = await _invoke('translateTerm', <String, dynamic>{
        'sessionId': sessionId,
        'text': text,
        'sourceLang': sourceLanguage.code,
        'targetLang': targetLanguage.code,
      });
      final data = _responseMap(response);
      return TranslationResult(
        sourceText: _requiredString(data, 'sourceText'),
        translatedText: _requiredString(data, 'translatedText'),
        sourceLanguage: _language(data, 'sourceLang'),
        targetLanguage: _language(data, 'targetLang'),
        lookupId: _requiredString(data, 'lookupId'),
        cacheHit: _requiredBool(data, 'cacheHit'),
      );
    } on FirebaseFunctionsException catch (error) {
      throw _failureFromFunctionsException(error);
    }
  }

  Future<SavedTranslationResult> saveToDictionary({
    required String lookupId,
    String? existingWordId,
  }) async {
    try {
      final response = await _invoke('saveTranslatedTerm', <String, dynamic>{
        'lookupId': lookupId,
        if (existingWordId != null && existingWordId.trim().isNotEmpty)
          'existingWordId': existingWordId.trim(),
      });
      final data = _responseMap(response);
      return SavedTranslationResult(
        wordPath: _requiredString(data, 'wordPath'),
        alreadyExisted: _requiredBool(data, 'alreadyExisted'),
      );
    } on FirebaseFunctionsException catch (error) {
      throw _failureFromFunctionsException(error);
    }
  }

  Future<Object?> _invoke(
    String functionName,
    Map<String, dynamic> payload,
  ) async {
    final customInvoker = invoker;
    if (customInvoker != null) {
      return customInvoker(functionName, payload);
    }
    final callable =
        FirebaseFunctions.instanceFor(region: callIntegrationsRegion)
            .httpsCallable(functionName);
    final response = await callable.call<Object?>(payload);
    return response.data;
  }
}

TranslationFailure _failureFromFunctionsException(
  FirebaseFunctionsException error,
) {
  final details = error.details;
  final detailsMap = details is Map ? details : const <Object?, Object?>{};
  final domainCode = detailsMap['domainCode'];
  final retryAfterMs = detailsMap['retryAfterMs'];
  return TranslationFailure(
    code: domainCode is String && domainCode.trim().isNotEmpty
        ? domainCode
        : error.code,
    retryAfterMs: retryAfterMs is num ? retryAfterMs.toInt() : null,
  );
}

Map<String, dynamic> _responseMap(Object? data) {
  if (data is! Map) {
    throw const FormatException('Expected callable response map.');
  }
  return Map<String, dynamic>.from(data);
}

String _requiredString(Map<String, dynamic> data, String field) {
  final value = data[field];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('Expected non-empty string field "$field".');
}

bool _requiredBool(Map<String, dynamic> data, String field) {
  final value = data[field];
  if (value is bool) return value;
  throw FormatException('Expected bool field "$field".');
}

TranslationLanguage _language(Map<String, dynamic> data, String field) {
  final code = _requiredString(data, field);
  return TranslationLanguage.values.firstWhere(
    (language) => language.code == code,
    orElse: () => throw FormatException('Unsupported language "$code".'),
  );
}
