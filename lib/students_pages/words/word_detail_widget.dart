import '/backend/backend.dart';
import '/components/app_loading_indicator.dart';
import '/components/word_detail_body.dart';
import '/components/word_detail_content.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/basic_page_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

class WordDetailWidget extends StatelessWidget {
  const WordDetailWidget({
    super.key,
    required this.wordRef,
    this.initialWord,
  });

  final DocumentReference wordRef;
  final UserWordsRecord? initialWord;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExpatlioDesign.background,
      body: StreamBuilder<UserWordsRecord>(
        stream: UserWordsRecord.getDocument(wordRef),
        initialData: initialWord,
        builder: (context, snapshot) {
          final word = snapshot.data;
          if (word == null) {
            return const Center(
              child: AppLoadingIndicator(),
            );
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
