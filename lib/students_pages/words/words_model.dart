import '/backend/backend.dart';
import '/components/word_pos_chip/word_pos_chip_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/nav_bar/nav_bar_widget.dart';
import 'words_widget.dart' show WordsWidget;
import 'package:flutter/material.dart';

class WordsModel extends FlutterFlowModel<WordsWidget> {
  ///  Local state fields for this page.

  String? pos = '';

  // Cached stream so it is not recreated on every build().
  Stream<List<UserWordsRecord>>? wordsStream;

  ///  State fields for stateful widgets in this page.

  // Model for wordPosChip component.
  late WordPosChipModel wordPosChipModel1;
  // Model for wordPosChip component.
  late WordPosChipModel wordPosChipModel2;
  // Model for wordPosChip component.
  late WordPosChipModel wordPosChipModel3;
  // Model for wordPosChip component.
  late WordPosChipModel wordPosChipModel4;
  // Model for wordPosChip component.
  late WordPosChipModel wordPosChipModel5;
  // Model for wordPosChip component.
  late WordPosChipModel wordPosChipModel6;
  // Model for wordPosChip component.
  late WordPosChipModel wordPosChipModel7;
  // Model for wordPosChip component.
  late WordPosChipModel wordPosChipModel8;
  // Model for wordPosChip component.
  late WordPosChipModel wordPosChipModel9;
  // Model for wordPosChip component.
  late WordPosChipModel wordPosChipModel10;
  // Model for wordPosChip component.
  late WordPosChipModel wordPosChipModel11;
  // Model for wordPosChip component.
  late WordPosChipModel wordPosChipModel12;
  // Model for NavBar component.
  late NavBarModel navBarModel;

  @override
  void initState(BuildContext context) {
    wordPosChipModel1 = createModel(context, () => WordPosChipModel());
    wordPosChipModel2 = createModel(context, () => WordPosChipModel());
    wordPosChipModel3 = createModel(context, () => WordPosChipModel());
    wordPosChipModel4 = createModel(context, () => WordPosChipModel());
    wordPosChipModel5 = createModel(context, () => WordPosChipModel());
    wordPosChipModel6 = createModel(context, () => WordPosChipModel());
    wordPosChipModel7 = createModel(context, () => WordPosChipModel());
    wordPosChipModel8 = createModel(context, () => WordPosChipModel());
    wordPosChipModel9 = createModel(context, () => WordPosChipModel());
    wordPosChipModel10 = createModel(context, () => WordPosChipModel());
    wordPosChipModel11 = createModel(context, () => WordPosChipModel());
    wordPosChipModel12 = createModel(context, () => WordPosChipModel());
    navBarModel = createModel(context, () => NavBarModel());
  }

  @override
  void dispose() {
    wordPosChipModel1.dispose();
    wordPosChipModel2.dispose();
    wordPosChipModel3.dispose();
    wordPosChipModel4.dispose();
    wordPosChipModel5.dispose();
    wordPosChipModel6.dispose();
    wordPosChipModel7.dispose();
    wordPosChipModel8.dispose();
    wordPosChipModel9.dispose();
    wordPosChipModel10.dispose();
    wordPosChipModel11.dispose();
    wordPosChipModel12.dispose();
    navBarModel.dispose();
  }
}
