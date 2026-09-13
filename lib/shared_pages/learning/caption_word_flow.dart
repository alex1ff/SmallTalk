import '/backend/backend.dart';
import '/components/new_word_widget.dart';
import '/components/woed_widget.dart';
import 'package:flutter/material.dart';

Widget buildLiveCaptionWordSheet({
  required String word,
  required String languageCode,
  required String sentence,
  required String contextText,
}) {
  return NewWordWidget(
    word: word,
    langCode: languageCode,
    sentence: sentence,
    contextText: contextText,
  );
}

Widget buildSavedCaptionWordSheet({
  required UserWordsRecord? existingWord,
  required String word,
  required String languageCode,
  required String sentence,
}) {
  if (existingWord != null) {
    return WoedWidget(word: existingWord);
  }

  return NewWordWidget(
    word: word,
    langCode: languageCode,
    sentence: sentence,
  );
}
