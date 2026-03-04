import 'api_manager.dart';

export 'api_manager.dart' show ApiCallResponse;

class YandexCall {
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
  static Future<ApiCallResponse> call({
    String? lang = '',
    String? q = '',
  }) async {
    return ApiManager.instance.makeApiCall(
      callName: 'tatoeba',
      apiUrl: 'https://api.dev.tatoeba.org/unstable/sentences',
      callType: ApiCallType.GET,
      headers: {
        'Accept': 'application/json',
      },
      params: {
        'q': q,
        'lang': lang,
        'limit': "10",
        'sort': "relevance",
        'word_count': "10",
        'showtrans:lang': "rus",
        'trans:1:lang': "rus",
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
