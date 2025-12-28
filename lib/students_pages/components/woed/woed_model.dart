import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'woed_widget.dart' show WoedWidget;
import 'package:flutter/material.dart';

class WoedModel extends FlutterFlowModel<WoedWidget> {
  ///  Local state fields for this component.

  List<EntryStruct> entry = [];
  void addToEntry(EntryStruct item) => entry.add(item);
  void removeFromEntry(EntryStruct item) => entry.remove(item);
  void removeAtIndexFromEntry(int index) => entry.removeAt(index);
  void insertAtIndexInEntry(int index, EntryStruct item) =>
      entry.insert(index, item);
  void updateEntryAtIndex(int index, Function(EntryStruct) updateFn) =>
      entry[index] = updateFn(entry[index]);

  List<SentenceStruct> sentence = [];
  void addToSentence(SentenceStruct item) => sentence.add(item);
  void removeFromSentence(SentenceStruct item) => sentence.remove(item);
  void removeAtIndexFromSentence(int index) => sentence.removeAt(index);
  void insertAtIndexInSentence(int index, SentenceStruct item) =>
      sentence.insert(index, item);
  void updateSentenceAtIndex(int index, Function(SentenceStruct) updateFn) =>
      sentence[index] = updateFn(sentence[index]);

  ///  State fields for stateful widgets in this component.

  // Stores action output result for [Backend Call - Create Document] action in IconButton widget.
  UserWordsRecord? erweerw;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
