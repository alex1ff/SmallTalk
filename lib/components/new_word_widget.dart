import 'package:flutter/material.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/draggable_word_sheet.dart';
import '/components/word_detail_content.dart';
import '/components/word_sheet_content.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/user_match_profile.dart';
import '/students_pages/flashcard/flashcard_review_repository.dart';
import '/students_pages/words/word_content_normalization.dart';
import '/students_pages/words/word_lookup_service.dart';

class NewWordWidget extends StatefulWidget {
  const NewWordWidget({
    super.key,
    required this.word,
    required this.langCode,
    this.sentence,
    this.contextText,
  });

  final String? word;
  final String? langCode;
  final String? sentence;
  final String? contextText;

  @override
  State<NewWordWidget> createState() => _NewWordWidgetState();
}

class _NewWordWidgetState extends State<NewWordWidget> {
  bool _lookupStarted = false;
  bool _isLookupLoading = true;
  bool _isTogglingSaved = false;
  String? _saveError;
  List<EntryStruct> _entries = const <EntryStruct>[];
  List<SentenceStruct> _examples = const <SentenceStruct>[];
  DocumentReference? _savedWordReference;

  bool get _canManageDictionary =>
      currentUserDocument != null &&
      !canAccessTeacherSurfaces(currentUserDocument) &&
      currentUserReference != null;

  bool get _isSaved => _savedWordReference != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lookupStarted) {
      return;
    }
    _lookupStarted = true;
    _loadWord();
  }

  Future<void> _loadWord() async {
    final sourceText = widget.word?.trim() ?? '';
    if (sourceText.isEmpty) {
      if (mounted) {
        setState(() => _isLookupLoading = false);
      }
      return;
    }

    final result = await WordLookupService.resolve(
      word: sourceText,
      userRef: currentUserReference,
      languageConfig: _languageConfig(),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _entries = result.entries;
      _examples = result.examples;
      _savedWordReference = result.savedWord?.reference;
      _isLookupLoading = false;
    });
  }

  WordLookupLanguageConfig _languageConfig() {
    final targetCode = _preferredTranslationLanguageCode();
    return WordLookupLanguageConfig(
      sourceLanguageCode: widget.langCode,
      yandexSourceLanguageCode: resolveYandexWordLookupLanguageCode(
        <String?>[widget.langCode, 'en'],
        fallback: 'en',
      ),
      yandexTranslationLanguageCode: resolveYandexWordLookupLanguageCode(
        <String?>[targetCode, 'ru'],
        fallback: 'ru',
      ),
      tatoebaSourceLanguageCode: resolveTatoebaWordLookupLanguageCode(
        <String?>[widget.langCode, 'eng'],
        fallback: 'eng',
      ),
      tatoebaTranslationLanguageCode: resolveTatoebaWordLookupLanguageCode(
        <String?>[targetCode, 'rus'],
        fallback: 'rus',
      ),
    );
  }

  String _preferredTranslationLanguageCode() {
    final currentUser = currentUserDocument;
    final candidates = <String?>[
      canAccessTeacherSurfaces(currentUser)
          ? currentUser?.nativeLanguageNS.code
          : currentUser?.preferences.preferredNativeLanguage.code,
      currentUser?.nativeLanguageNS.code,
      FFLocalizations.of(context).languageCode,
      'ru',
    ];
    return resolveNormalizedWordLookupLanguageCode(
      candidates,
      fallback: 'ru',
    );
  }

  Future<void> _toggleDictionaryWord() async {
    if (!_canManageDictionary || _isTogglingSaved) {
      return;
    }
    setState(() {
      _isTogglingSaved = true;
      _saveError = null;
    });
    try {
      final savedReference = _savedWordReference;
      if (savedReference != null) {
        await FlashcardReviewRepository.deleteReviewForWord(savedReference);
        await savedReference.delete();
        if (!mounted) {
          return;
        }
        setState(() => _savedWordReference = null);
        return;
      }

      final userReference = currentUserReference;
      final sourceText = widget.word?.trim() ?? '';
      if (userReference == null || sourceText.isEmpty) {
        return;
      }
      final reference = UserWordsRecord.createDoc(userReference);
      final addedAt = getCurrentTimestamp;
      final entries = _entries.isEmpty
          ? <EntryStruct>[EntryStruct(text: sourceText)]
          : _entries;
      await reference.set(
        mapToFirestore(<String, dynamic>{
          ...createUserWordsRecordData(addedAt: addedAt),
          'entry': getEntryListFirestoreData(entries),
          'Sentence': getSentenceListFirestoreData(_sentencesToSave()),
          'sourceLanguage': normalizeWordLookupLanguageCode(widget.langCode),
          'targetLanguage': _preferredTranslationLanguageCode(),
        }),
      );
      await FlashcardReviewRepository.ensureInitialReviewForWord(
        wordRef: reference,
        addedAt: addedAt,
      );
      if (!mounted) {
        return;
      }
      setState(() => _savedWordReference = reference);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saveError = FFLocalizations.of(context).getVariableText(
          ruText: 'Не удалось изменить словарь. Нажмите ещё раз.',
          enText: 'Could not update the dictionary. Tap again.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isTogglingSaved = false);
      }
    }
  }

  List<SentenceStruct> _sentencesToSave() {
    final result = <SentenceStruct>[];
    final seen = <String>{};
    void add(SentenceStruct sentence) {
      final key =
          '${normalizedWordLanguageCode(sentence.lang)}|${normalizeWordContentValue(sentence.text)}';
      if (key.endsWith('|') || !seen.add(key)) {
        return;
      }
      result.add(sentence);
    }

    for (final example in _examples) {
      add(example);
    }
    final sentence = widget.sentence?.trim() ?? '';
    if (sentence.isNotEmpty) {
      add(
        SentenceStruct(
          text: sentence,
          lang: normalizeWordLookupLanguageCode(widget.langCode),
        ),
      );
    }
    return result;
  }

  String? _phraseContext() {
    final value = widget.contextText?.trim() ?? '';
    if (value.isEmpty ||
        normalizeWordContentValue(value) ==
            normalizeWordContentValue(widget.word)) {
      return null;
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final sourceText = widget.word?.trim() ?? '';
    final fallbackEntries = <EntryStruct>[
      EntryStruct(text: sourceText.isEmpty ? '-' : sourceText),
    ];
    final content = buildWordDetailContent(
      savedEntries: _entries.isEmpty ? fallbackEntries : _entries,
      savedExamples: _examples,
    );
    return DraggableWordSheet(
      child: WordSheetContent(
        content: content,
        isLookupLoading: _isLookupLoading,
        isSaved: _isSaved,
        isTogglingSaved: _isTogglingSaved,
        canManageDictionary: _canManageDictionary,
        onToggleSaved: _toggleDictionaryWord,
        saveError: _saveError,
        phraseContext: _phraseContext(),
        sentenceContext: widget.sentence,
      ),
    );
  }
}
