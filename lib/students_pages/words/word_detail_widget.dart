import 'dart:async';

import '/backend/backend.dart';
import '/components/app_loading_indicator.dart';
import '/components/word_detail_body.dart';
import '/components/word_detail_content.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/basic_page_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/students_pages/words/quick_translation_word_enricher.dart';
import '/students_pages/words/word_lookup_service.dart';
import 'package:flutter/material.dart';

class WordDetailWidget extends StatefulWidget {
  const WordDetailWidget({
    super.key,
    required this.wordRef,
    this.initialWord,
  });

  final DocumentReference wordRef;
  final UserWordsRecord? initialWord;

  @override
  State<WordDetailWidget> createState() => _WordDetailWidgetState();
}

class _WordDetailWidgetState extends State<WordDetailWidget> {
  bool _enrichmentStarted = false;

  Future<void> _enrichIfNeeded(UserWordsRecord word) async {
    final metadata = SavedWordLookupMetadata.fromRecord(word);
    if (!metadata.canRetryRemoteLookup || !metadata.needsEnrichment(word)) {
      return;
    }
    final sourceText = word.entry.firstOrNull?.text.trim() ?? '';
    final directTranslation =
        word.entry.firstOrNull?.tr.firstOrNull?.text.trim() ?? '';
    if (sourceText.isEmpty || directTranslation.isEmpty) {
      return;
    }
    try {
      final remote = await WordLookupService.fetchRemote(
        word: sourceText,
        languageConfig: metadata.toLanguageConfig(),
      );
      if (remote.hasFailures) {
        debugPrint(
            'Word detail enrichment partial failure: ${remote.failures}');
      }
      await const QuickTranslationWordEnricher().enrich(
        wordReference: word.reference,
        sourceText: sourceText,
        directTranslation: directTranslation,
        remoteResult: remote,
      );
    } catch (error) {
      debugPrint('Word detail enrichment failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExpatlioDesign.background,
      body: StreamBuilder<UserWordsRecord>(
        stream: UserWordsRecord.getDocument(widget.wordRef),
        initialData: widget.initialWord,
        builder: (context, snapshot) {
          final word = snapshot.data;
          if (word == null) {
            return const Center(
              child: AppLoadingIndicator(),
            );
          }

          if (!_enrichmentStarted) {
            _enrichmentStarted = true;
            unawaited(_enrichIfNeeded(word));
          }

          final content = buildWordDetailContent(
            savedEntries: word.entry.toList(),
            savedExamples: word.sentence.toList(),
          );

          return Column(
            children: [
              BasicPageHeader(
                title: FFLocalizations.of(context).getVariableText(
                  ruText: 'Слово',
                  enText: 'Word',
                ),
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: WordDetailBody(content: content),
              ),
            ],
          );
        },
      ),
    );
  }
}
