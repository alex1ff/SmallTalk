import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'words_widget.dart' show WordsWidget;
import 'package:flutter/material.dart';

class WordsModel extends FlutterFlowModel<WordsWidget> {
  // Cached stream so it is not recreated on every build().
  Stream<List<UserWordsRecord>>? wordsStream;
  Stream<List<WordReviewsRecord>>? wordReviewsStream;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
