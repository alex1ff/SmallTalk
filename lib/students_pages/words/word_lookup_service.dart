import '/backend/api_requests/api_calls.dart';
import '/backend/backend.dart';
import 'package:collection/collection.dart';

typedef WordEntriesFetcher = Future<List<EntryStruct>> Function(
  WordLookupRequest request,
);
typedef WordExamplesFetcher = Future<List<SentenceStruct>> Function(
  WordLookupRequest request,
);
typedef SavedWordsLoader = Future<List<UserWordsRecord>> Function(
  DocumentReference userRef,
);

class WordLookupLanguageConfig {
  const WordLookupLanguageConfig({
    required this.yandexSourceLanguageCode,
    required this.yandexTranslationLanguageCode,
    required this.tatoebaSourceLanguageCode,
    required this.tatoebaTranslationLanguageCode,
    this.sourceLanguageCode,
  });

  final String? sourceLanguageCode;
  final String yandexSourceLanguageCode;
  final String yandexTranslationLanguageCode;
  final String tatoebaSourceLanguageCode;
  final String tatoebaTranslationLanguageCode;

  String cacheKeyFor(String word) {
    return [
      _normalizeText(word),
      _normalizeLanguageCode(yandexSourceLanguageCode),
      _normalizeLanguageCode(yandexTranslationLanguageCode),
      _normalizeLanguageCode(tatoebaSourceLanguageCode),
      _normalizeLanguageCode(tatoebaTranslationLanguageCode),
    ].join('|');
  }
}

class WordLookupRequest {
  const WordLookupRequest({
    required this.word,
    required this.languageConfig,
  });

  final String word;
  final WordLookupLanguageConfig languageConfig;
}

class WordLookupSavedContent {
  const WordLookupSavedContent({
    required this.entries,
    required this.examples,
    this.record,
  });

  factory WordLookupSavedContent.fromRecord(UserWordsRecord record) {
    return WordLookupSavedContent(
      entries: record.entry.toList(),
      examples: record.sentence.toList(),
      record: record,
    );
  }

  final List<EntryStruct> entries;
  final List<SentenceStruct> examples;
  final UserWordsRecord? record;
}

class WordLookupResult {
  const WordLookupResult({
    required this.entries,
    required this.examples,
    this.savedWord,
    this.fromSavedWord = false,
    this.fromMemoryCache = false,
  });

  final List<EntryStruct> entries;
  final List<SentenceStruct> examples;
  final UserWordsRecord? savedWord;
  final bool fromSavedWord;
  final bool fromMemoryCache;
}

class WordLookupService {
  WordLookupService._();

  static final Map<String, WordLookupResult> _memoryCache =
      <String, WordLookupResult>{};

  static void clearMemoryCacheForTests() {
    _memoryCache.clear();
  }

  static Future<WordLookupResult> resolve({
    required String word,
    required WordLookupLanguageConfig languageConfig,
    Iterable<WordLookupSavedContent> savedContents =
        const <WordLookupSavedContent>[],
    DocumentReference? userRef,
    SavedWordsLoader? loadSavedWords,
    WordEntriesFetcher? fetchEntries,
    WordExamplesFetcher? fetchExamples,
  }) async {
    final normalizedWord = _normalizeText(word);
    if (normalizedWord.isEmpty) {
      return const WordLookupResult(
        entries: <EntryStruct>[],
        examples: <SentenceStruct>[],
      );
    }

    final allSavedContents = savedContents.isNotEmpty
        ? savedContents.toList()
        : await _loadSavedContents(
            userRef: userRef,
            loadSavedWords: loadSavedWords,
          );
    final savedContent = _findSavedContent(
      savedContents: allSavedContents,
      word: normalizedWord,
      sourceLanguageCode: languageConfig.sourceLanguageCode,
    );

    if (savedContent != null) {
      return WordLookupResult(
        entries: savedContent.entries,
        examples: savedContent.examples,
        savedWord: savedContent.record,
        fromSavedWord: true,
      );
    }

    final cacheKey = languageConfig.cacheKeyFor(normalizedWord);
    final cached = _memoryCache[cacheKey];
    if (cached != null) {
      return WordLookupResult(
        entries: cached.entries,
        examples: cached.examples,
        fromMemoryCache: true,
      );
    }

    final request = WordLookupRequest(
      word: normalizedWord,
      languageConfig: languageConfig,
    );
    final entriesFetcher = fetchEntries ?? _fetchEntriesFromApi;
    final examplesFetcher = fetchExamples ?? _fetchExamplesFromApi;
    var entries = const <EntryStruct>[];
    var examples = const <SentenceStruct>[];

    await Future.wait([
      Future(() async {
        try {
          entries = await entriesFetcher(request);
        } catch (_) {}
      }),
      Future(() async {
        try {
          examples = await examplesFetcher(request);
        } catch (_) {}
      }),
    ]);
    final result = WordLookupResult(
      entries: entries,
      examples: examples,
    );
    _memoryCache[cacheKey] = result;
    return result;
  }

  static Future<List<WordLookupSavedContent>> _loadSavedContents({
    required DocumentReference? userRef,
    required SavedWordsLoader? loadSavedWords,
  }) async {
    if (userRef == null) {
      return const <WordLookupSavedContent>[];
    }

    final loader = loadSavedWords ??
        (DocumentReference userRef) => queryUserWordsRecordOnce(
              parent: userRef,
            );
    final records = await loader(userRef);
    return records.map(WordLookupSavedContent.fromRecord).toList();
  }

  static WordLookupSavedContent? _findSavedContent({
    required Iterable<WordLookupSavedContent> savedContents,
    required String word,
    required String? sourceLanguageCode,
  }) {
    final textMatches = savedContents.where((content) {
      final sourceText = content.entries.firstOrNull?.text;
      return _normalizeText(sourceText) == word;
    }).toList();

    if (textMatches.isEmpty) {
      return null;
    }

    return textMatches.firstWhereOrNull(
          (content) => _matchesSourceLanguage(
            content.examples,
            sourceLanguageCode,
          ),
        ) ??
        textMatches.first;
  }

  static bool _matchesSourceLanguage(
    List<SentenceStruct> examples,
    String? sourceLanguageCode,
  ) {
    final sourceAliases = _languageAliases(sourceLanguageCode);
    if (sourceAliases.isEmpty || examples.isEmpty) {
      return true;
    }

    return examples.any((example) {
      final exampleAliases = _languageAliases(example.lang);
      return exampleAliases.any(sourceAliases.contains);
    });
  }

  static Future<List<EntryStruct>> _fetchEntriesFromApi(
    WordLookupRequest request,
  ) async {
    final response = await YandexCall.call(
      text: request.word,
      lang:
          '${request.languageConfig.yandexSourceLanguageCode}-${request.languageConfig.yandexTranslationLanguageCode}',
    );
    final jsonBody = response.jsonBody;
    if (jsonBody is! Map) {
      return const <EntryStruct>[];
    }

    return YyStruct.maybeFromMap(jsonBody)?.def.toList() ??
        const <EntryStruct>[];
  }

  static Future<List<SentenceStruct>> _fetchExamplesFromApi(
    WordLookupRequest request,
  ) async {
    final response = await TatoebaCall.call(
      lang: request.languageConfig.tatoebaSourceLanguageCode,
      q: request.word,
      showTransLang: request.languageConfig.tatoebaTranslationLanguageCode,
      transLang: request.languageConfig.tatoebaTranslationLanguageCode,
    );
    final jsonBody = response.jsonBody;
    if (jsonBody is! Map) {
      return const <SentenceStruct>[];
    }

    return DataStruct.maybeFromMap(jsonBody)?.data.toList() ??
        const <SentenceStruct>[];
  }
}

String _normalizeText(String? value) {
  return (value ?? '').trim().toLowerCase();
}

String _normalizeLanguageCode(String? code) {
  return (code ?? '').trim().toLowerCase().replaceAll('_', '-');
}

Set<String> _languageAliases(String? code) {
  final normalized = _normalizeLanguageCode(code);
  if (normalized.isEmpty) {
    return const <String>{};
  }

  final aliases = <String>{normalized};
  final baseCode = normalized.split('-').first;
  if (baseCode.isNotEmpty) {
    aliases.add(baseCode);
  }

  final yandexCode = YandexCall.normalizeLanguageCode(normalized);
  if (yandexCode != null && yandexCode.isNotEmpty) {
    aliases.add(_normalizeLanguageCode(yandexCode));
  }

  final tatoebaCode = TatoebaCall.normalizeLanguageCode(normalized);
  if (tatoebaCode != null && tatoebaCode.isNotEmpty) {
    aliases.add(_normalizeLanguageCode(tatoebaCode));
  }

  return aliases;
}
