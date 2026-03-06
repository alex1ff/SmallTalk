import 'api_manager.dart';

export 'api_manager.dart' show ApiCallResponse;

class YandexCall {
  static const Map<String, String> _languageCodeMap = {
    'eng': 'en',
    'rus': 'ru',
    'spa': 'es',
    'fra': 'fr',
    'deu': 'de',
    'cmn': 'zh',
    'yue': 'zh',
    'jpn': 'ja',
    'kor': 'ko',
    'ita': 'it',
    'por': 'pt',
    'hin': 'hi',
    'bul': 'bg',
    'ces': 'cs',
    'dan': 'da',
    'nld': 'nl',
    'fin': 'fi',
    'hun': 'hu',
    'ind': 'id',
    'nor': 'no',
    'pol': 'pl',
    'swe': 'sv',
    'tur': 'tr',
    'ukr': 'uk',
    'vie': 'vi',
    'cat': 'ca',
    'est': 'et',
    'ell': 'el',
    'lav': 'lv',
    'lit': 'lt',
    'msa': 'ms',
    'ron': 'ro',
    'slk': 'sk',
    'tha': 'th',
  };

  static String? normalizeLanguageCode(String? code) {
    final normalizedCode =
        (code ?? '').trim().toLowerCase().replaceAll('_', '-');
    if (normalizedCode.isEmpty) {
      return null;
    }

    if (normalizedCode.length == 2 && !normalizedCode.contains('-')) {
      return normalizedCode;
    }

    if (normalizedCode.length == 3 && !normalizedCode.contains('-')) {
      return _languageCodeMap[normalizedCode] ?? normalizedCode;
    }

    final baseCode = normalizedCode.split('-').first;
    return _languageCodeMap[baseCode] ?? baseCode;
  }

  static Future<ApiCallResponse> call({
    String? text = '',
    String? lang = '',
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'yandex',
      apiUrl: 'https://dictionary.yandex.net/api/v1/dicservice.json/lookup',
      callType: ApiCallType.GET,
      headers: {
        'Content-Type': 'application/json',
      },
      params: {
        'key':
            "dict.1.1.20250926T091633Z.b5809993b07721d9.64d687a03e4465c33361e64a1244ef2da38eb7d4",
        'lang': lang,
        'text': text,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class TatoebaCall {
  static const Map<String, String> _languageCodeMap = {
    'en': 'eng',
    'ru': 'rus',
    'es': 'spa',
    'fr': 'fra',
    'de': 'deu',
    'zh': 'cmn',
    'zh-cn': 'cmn',
    'zh-hans': 'cmn',
    'zh-tw': 'cmn',
    'zh-hk': 'yue',
    'ja': 'jpn',
    'ko': 'kor',
    'ko-kr': 'kor',
    'it': 'ita',
    'pt': 'por',
    'pt-br': 'por',
    'pt-pt': 'por',
    'hi': 'hin',
    'bg': 'bul',
    'cs': 'ces',
    'da': 'dan',
    'nl': 'nld',
    'nl-be': 'nld',
    'fi': 'fin',
    'hu': 'hun',
    'id': 'ind',
    'no': 'nor',
    'pl': 'pol',
    'sv': 'swe',
    'tr': 'tur',
    'uk': 'ukr',
    'vi': 'vie',
    'ca': 'cat',
    'et': 'est',
    'de-ch': 'deu',
    'el': 'ell',
    'lv': 'lav',
    'lt': 'lit',
    'ms': 'msa',
    'ro': 'ron',
    'sk': 'slk',
    'th': 'tha',
  };

  static String? normalizeLanguageCode(String? code) {
    final normalizedCode =
        (code ?? '').trim().toLowerCase().replaceAll('_', '-');
    if (normalizedCode.isEmpty) {
      return null;
    }

    if (normalizedCode.length == 3 && !normalizedCode.contains('-')) {
      return normalizedCode;
    }

    final mappedCode = _languageCodeMap[normalizedCode];
    if (mappedCode != null) {
      return mappedCode;
    }

    final baseCode = normalizedCode.split('-').first;
    return _languageCodeMap[baseCode];
  }

  static Future<ApiCallResponse> call({
    String? lang = '',
    String? q = '',
    String? showTransLang = '',
    String? transLang = '',
  }) async {
    final normalizedLang = normalizeLanguageCode(lang);
    final normalizedShowTransLang = normalizeLanguageCode(showTransLang);
    final normalizedTransLang = normalizeLanguageCode(transLang);

    return ApiManager.instance.makeApiCall(
      callName: 'tatoeba',
      apiUrl: 'https://api.dev.tatoeba.org/unstable/sentences',
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
      },
      params: {
        'q': q,
        if (normalizedLang != null) 'lang': normalizedLang,
        'limit': "10",
        'sort': "relevance",
        'word_count': "10",
        if (normalizedShowTransLang != null)
          'showtrans:lang': normalizedShowTransLang,
        if (normalizedTransLang != null) 'trans:1:lang': normalizedTransLang,
      },
      returnBody: true,
      encodeBodyUtf8: false,
      decodeUtf8: false,
      cache: false,
      isStreamingApi: false,
      alwaysAllowBody: false,
    );
  }
}

class ApiPagingParams {
  int nextPageNumber = 0;
  int numItems = 0;
  dynamic lastResponse;

  ApiPagingParams({
    required this.nextPageNumber,
    required this.numItems,
    required this.lastResponse,
  });

  @override
  String toString() =>
      'PagingParams(nextPageNumber: $nextPageNumber, numItems: $numItems, lastResponse: $lastResponse,)';
}
