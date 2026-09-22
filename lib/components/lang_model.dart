import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:text_search/text_search.dart';
import 'lang_widget.dart' show LangWidget;
import 'package:flutter/material.dart';

class LangModel extends FlutterFlowModel<LangWidget> {
  ///  State fields for stateful widgets in this component.

  // State field(s) for SearchL2 widget.
  FocusNode? searchL2FocusNode;
  TextEditingController? searchL2TextController;
  String? Function(BuildContext, String?)? searchL2TextControllerValidator;

  _LanguageSelectorCache? _cache;
  String? _cachedSearchQuery;
  String? _cachedSearchSelectedSignature;
  List<LanguageStruct>? _cachedSearchResults;
  static final Map<_LanguageSelectorCacheKey, _LanguageSelectorCache>
      _sharedCaches = <_LanguageSelectorCacheKey, _LanguageSelectorCache>{};

  static void prewarmSharedCache({
    required List<LanguageStruct> sourceLanguages,
    int? sourceSignature,
    List<String>? allowedCodes,
    required String localeCode,
  }) {
    final model = LangModel();
    model._ensureCache(
      sourceLanguages: sourceLanguages,
      sourceSignature: sourceSignature,
      allowedCodes: allowedCodes,
      localeCode: localeCode,
    );
  }

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    searchL2FocusNode?.dispose();
    searchL2TextController?.dispose();
  }

  List<LanguageStruct> availableLanguages({
    required List<LanguageStruct> sourceLanguages,
    int? sourceSignature,
    List<String>? allowedCodes,
    LanguageStruct? selected,
    required String localeCode,
  }) {
    final availableLanguages = _ensureCache(
      sourceLanguages: sourceLanguages,
      sourceSignature: sourceSignature,
      allowedCodes: allowedCodes,
      localeCode: localeCode,
    ).availableLanguages;
    if (!_hasMeaningfulLanguageData(selected)) {
      return availableLanguages;
    }

    final resolvedSelected = selected!;
    final alreadyIncluded = availableLanguages.any(
      (language) => _isSameLanguageSelection(language, resolvedSelected),
    );
    if (alreadyIncluded) {
      return availableLanguages;
    }

    return <LanguageStruct>[
      resolvedSelected,
      ...availableLanguages,
    ];
  }

  List<LanguageStruct> searchLanguages({
    required List<LanguageStruct> sourceLanguages,
    int? sourceSignature,
    List<String>? allowedCodes,
    LanguageStruct? selected,
    required String localeCode,
    required String query,
  }) {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const [];
    }

    final cache = _ensureCache(
      sourceLanguages: sourceLanguages,
      sourceSignature: sourceSignature,
      allowedCodes: allowedCodes,
      localeCode: localeCode,
    );
    final selectedSignature = _hasMeaningfulLanguageData(selected)
        ? _languageSelectionSignature(selected!)
        : '';
    if (_cachedSearchQuery == normalizedQuery &&
        _cachedSearchSelectedSignature == selectedSignature &&
        _cachedSearchResults != null) {
      return _cachedSearchResults!;
    }

    final results = cache.searchIndex
        .search(normalizedQuery)
        .map((result) => result.object)
        .take(10)
        .toList(growable: true);
    if (_hasMeaningfulLanguageData(selected) &&
        !results
            .any((language) => _isSameLanguageSelection(language, selected)) &&
        _matchesSearchQuery(selected!, localeCode, normalizedQuery)) {
      results.insert(0, selected);
    }
    _cachedSearchQuery = normalizedQuery;
    _cachedSearchSelectedSignature = selectedSignature;
    _cachedSearchResults = results;
    return results;
  }

  LanguageStruct? resolveSelectedLanguage({
    required List<LanguageStruct> languages,
    LanguageStruct? selected,
  }) {
    if (!_hasMeaningfulLanguageData(selected)) {
      return null;
    }

    for (final language in languages) {
      if (_isSameLanguageSelection(language, selected)) {
        return language;
      }
    }

    return selected;
  }

  _LanguageSelectorCache _ensureCache({
    required List<LanguageStruct> sourceLanguages,
    int? sourceSignature,
    List<String>? allowedCodes,
    required String localeCode,
  }) {
    final normalizedAllowedCodes = _normalizeAllowedCodes(allowedCodes);
    final resolvedSourceSignature =
        sourceSignature ?? _computeSourceSignature(sourceLanguages);
    final allowedCodesSignature = normalizedAllowedCodes.join('\u001f');
    final cacheKey = _LanguageSelectorCacheKey(
      sourceSignature: resolvedSourceSignature,
      allowedCodesSignature: allowedCodesSignature,
      localeCode: localeCode,
    );

    final cache = _cache;
    if (cache != null &&
        cache.sourceSignature == resolvedSourceSignature &&
        cache.allowedCodesSignature == allowedCodesSignature &&
        cache.localeCode == localeCode) {
      return cache;
    }

    final sharedCache = _sharedCaches[cacheKey];
    if (sharedCache != null) {
      _cache = sharedCache;
      _cachedSearchQuery = null;
      _cachedSearchSelectedSignature = null;
      _cachedSearchResults = null;
      return sharedCache;
    }

    final availableLanguages = _buildAvailableLanguages(
      sourceLanguages: sourceLanguages,
      allowedCodes: normalizedAllowedCodes,
    );
    final searchIndex = TextSearch<LanguageStruct>(
      availableLanguages
          .map(
            (language) => TextSearchItem.fromTerms(
              language,
              _searchTerms(language, localeCode),
            ),
          )
          .toList(growable: false),
    );

    final updatedCache = _LanguageSelectorCache(
      sourceSignature: resolvedSourceSignature,
      allowedCodesSignature: allowedCodesSignature,
      localeCode: localeCode,
      availableLanguages: availableLanguages,
      searchIndex: searchIndex,
    );
    _sharedCaches[cacheKey] = updatedCache;
    _cache = updatedCache;
    _cachedSearchQuery = null;
    _cachedSearchSelectedSignature = null;
    _cachedSearchResults = null;
    return updatedCache;
  }

  List<String> _normalizeAllowedCodes(List<String>? allowedCodes) {
    if (allowedCodes == null) {
      return const [];
    }

    return allowedCodes
        .map(_normalizeLanguageCode)
        .where((code) => code.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort();
  }

  int _computeSourceSignature(List<LanguageStruct> sourceLanguages) {
    var signature = sourceLanguages.length;
    for (final language in sourceLanguages) {
      signature = Object.hash(
        signature,
        _normalizeLanguageCode(language.code),
        _normalizeText(language.nameEn),
        _normalizeText(language.nameRu),
        _normalizeText(language.model),
        _normalizeText(language.ss),
        Object.hashAll(
          language.alternateCodes.map(_normalizeLanguageCode),
        ),
      );
    }
    return signature;
  }

  List<LanguageStruct> _buildAvailableLanguages({
    required List<LanguageStruct> sourceLanguages,
    required List<String> allowedCodes,
  }) {
    if (allowedCodes.isEmpty) {
      return sourceLanguages;
    }

    final normalizedAllowedCodes = allowedCodes.toSet();
    return sourceLanguages
        .where(
          (language) =>
              _languageCodes(language).any(normalizedAllowedCodes.contains),
        )
        .toList(growable: false);
  }

  bool _hasMeaningfulLanguageData(LanguageStruct? language) {
    if (language == null) {
      return false;
    }

    return language.code.trim().isNotEmpty ||
        language.nameEn.trim().isNotEmpty ||
        language.nameRu.trim().isNotEmpty ||
        language.model.trim().isNotEmpty ||
        language.ss.trim().isNotEmpty ||
        language.alternateCodes.isNotEmpty;
  }

  Iterable<String> _languageCodes(LanguageStruct language) sync* {
    final normalizedPrimaryCode = _normalizeLanguageCode(language.code);
    if (normalizedPrimaryCode.isNotEmpty) {
      yield normalizedPrimaryCode;
    }

    for (final alternateCode in language.alternateCodes) {
      final normalizedAlternateCode = _normalizeLanguageCode(alternateCode);
      if (normalizedAlternateCode.isNotEmpty) {
        yield normalizedAlternateCode;
      }
    }
  }

  String _normalizeLanguageCode(String code) => code.trim().toLowerCase();

  String _languageSelectionSignature(LanguageStruct language) {
    return <String>[
      _normalizeLanguageCode(language.code),
      _normalizeText(language.nameEn),
      _normalizeText(language.nameRu),
      _normalizeText(language.model),
      _normalizeText(language.ss),
      ...language.alternateCodes.map(_normalizeLanguageCode),
    ].join('\u001f');
  }

  bool _isSameLanguageSelection(
    LanguageStruct? left,
    LanguageStruct? right,
  ) {
    if (!_hasMeaningfulLanguageData(left) ||
        !_hasMeaningfulLanguageData(right)) {
      return false;
    }

    final leftLanguage = left!;
    final rightLanguage = right!;
    final leftCodes = _languageCodes(leftLanguage).toSet();
    final rightCodes = _languageCodes(rightLanguage).toSet();
    if (leftCodes.isNotEmpty &&
        rightCodes.isNotEmpty &&
        leftCodes.intersection(rightCodes).isNotEmpty) {
      return true;
    }

    return _normalizeText(leftLanguage.nameEn).isNotEmpty &&
        _normalizeText(leftLanguage.nameEn) ==
            _normalizeText(rightLanguage.nameEn) &&
        _normalizeText(leftLanguage.nameRu).isNotEmpty &&
        _normalizeText(leftLanguage.nameRu) ==
            _normalizeText(rightLanguage.nameRu);
  }

  String _normalizeText(String value) => value.trim().toLowerCase();

  bool _matchesSearchQuery(
    LanguageStruct language,
    String localeCode,
    String query,
  ) {
    final normalizedQuery = _normalizeText(query);
    if (normalizedQuery.isEmpty) {
      return false;
    }

    return _searchTerms(language, localeCode).any(
      (term) => _normalizeText(term).contains(normalizedQuery),
    );
  }

  List<String> _searchTerms(LanguageStruct language, String localeCode) {
    final localizedName =
        localeCode == 'ru' ? language.nameRu : language.nameEn;
    final fallbackName = localeCode == 'ru' ? language.nameEn : language.nameRu;

    final terms = <String>{
      if (localizedName.isNotEmpty) localizedName,
      if (fallbackName.isNotEmpty) fallbackName,
      language.code,
      ...language.alternateCodes,
    }..removeWhere((term) => term.trim().isEmpty);

    if (terms.isEmpty) {
      terms.add(language.toString());
    }

    return terms.toList(growable: false);
  }
}

class _LanguageSelectorCache {
  const _LanguageSelectorCache({
    required this.sourceSignature,
    required this.allowedCodesSignature,
    required this.localeCode,
    required this.availableLanguages,
    required this.searchIndex,
  });

  final int sourceSignature;
  final String allowedCodesSignature;
  final String localeCode;
  final List<LanguageStruct> availableLanguages;
  final TextSearch<LanguageStruct> searchIndex;
}

class _LanguageSelectorCacheKey {
  const _LanguageSelectorCacheKey({
    required this.sourceSignature,
    required this.allowedCodesSignature,
    required this.localeCode,
  });

  final int sourceSignature;
  final String allowedCodesSignature;
  final String localeCode;

  @override
  bool operator ==(Object other) {
    return other is _LanguageSelectorCacheKey &&
        other.sourceSignature == sourceSignature &&
        other.allowedCodesSignature == allowedCodesSignature &&
        other.localeCode == localeCode;
  }

  @override
  int get hashCode =>
      Object.hash(sourceSignature, allowedCodesSignature, localeCode);
}
