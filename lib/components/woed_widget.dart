import 'dart:async';

import 'package:flutter/material.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/draggable_word_sheet.dart';
import '/components/word_detail_content.dart';
import '/components/word_sheet_content.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/user_match_profile.dart';
import '/students_pages/flashcard/flashcard_review_repository.dart';
import '/students_pages/words/quick_translation_word_enricher.dart';
import '/students_pages/words/word_lookup_service.dart';

class WoedWidget extends StatefulWidget {
  const WoedWidget({
    super.key,
    required this.word,
  });

  final UserWordsRecord? word;

  @override
  State<WoedWidget> createState() => _WoedWidgetState();
}

class _WoedWidgetState extends State<WoedWidget> {
  bool _enrichmentStarted = false;
  bool _isTogglingSaved = false;
  String? _saveError;
  late List<EntryStruct> _entries;
  late List<SentenceStruct> _examples;
  DocumentReference? _savedWordReference;

  bool get _canManageDictionary =>
      currentUserDocument != null &&
      !canAccessTeacherSurfaces(currentUserDocument) &&
      currentUserReference != null;

  bool get _isSaved => _savedWordReference != null;

  @override
  void initState() {
    super.initState();
    _entries = widget.word?.entry.toList() ?? const <EntryStruct>[];
    _examples = widget.word?.sentence.toList() ?? const <SentenceStruct>[];
    _savedWordReference = widget.word?.reference;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_enrichmentStarted) {
      return;
    }
    _enrichmentStarted = true;
    unawaited(_enrichIfNeeded());
  }

  Future<void> _enrichIfNeeded() async {
    final word = widget.word;
    if (word == null) {
      return;
    }
    final metadata = SavedWordLookupMetadata.fromRecord(word);
    if (!metadata.canRetryRemoteLookup || !metadata.needsEnrichment(word)) {
      return;
    }
    final sourceText = _entries.firstOrNull?.text.trim() ?? '';
    final directTranslation =
        _entries.firstOrNull?.tr.firstOrNull?.text.trim() ?? '';
    if (sourceText.isEmpty || directTranslation.isEmpty) {
      return;
    }

    try {
      final remote = await WordLookupService.fetchRemote(
        word: sourceText,
        languageConfig: metadata.toLanguageConfig(),
      );
      if (remote.hasFailures) {
        debugPrint('Saved word enrichment partial failure: ${remote.failures}');
      }
      final merged = await const QuickTranslationWordEnricher().enrich(
        wordReference: word.reference,
        sourceText: sourceText,
        directTranslation: directTranslation,
        remoteResult: remote,
      );
      if (!mounted || merged == null) {
        return;
      }
      setState(() {
        _entries = merged.entries;
        _examples = merged.examples;
      });
    } catch (error) {
      debugPrint('Saved word enrichment failed: $error');
    }
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

      final reference = widget.word?.reference;
      if (reference == null || _entries.isEmpty) {
        return;
      }
      final metadata = SavedWordLookupMetadata.fromRecord(widget.word!);
      final addedAt = getCurrentTimestamp;
      await reference.set(
        mapToFirestore(<String, dynamic>{
          ...createUserWordsRecordData(addedAt: addedAt),
          'entry': getEntryListFirestoreData(_entries),
          'Sentence': getSentenceListFirestoreData(_examples),
          if (metadata.source.isNotEmpty) 'source': metadata.source,
          if (metadata.sourceLanguageCode.isNotEmpty)
            'sourceLanguage': metadata.sourceLanguageCode,
          if (metadata.targetLanguageCode.isNotEmpty)
            'targetLanguage': metadata.targetLanguageCode,
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

  @override
  Widget build(BuildContext context) {
    final content = buildWordDetailContent(
      savedEntries: _entries,
      savedExamples: _examples,
    );
    return DraggableWordSheet(
      child: WordSheetContent(
        content: content,
        isLookupLoading: false,
        isSaved: _isSaved,
        isTogglingSaved: _isTogglingSaved,
        canManageDictionary: _canManageDictionary,
        onToggleSaved: _toggleDictionaryWord,
        saveError: _saveError,
      ),
    );
  }
}
