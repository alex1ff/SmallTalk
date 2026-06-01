import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/components/woed_widget.dart';
import '/students_pages/flashcard/flashcard_review_repository.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'word_card_model.dart';
export 'word_card_model.dart';

class WordCardWidget extends StatefulWidget {
  const WordCardWidget({
    super.key,
    required this.wordDoc,
  });

  final UserWordsRecord? wordDoc;

  @override
  State<WordCardWidget> createState() => _WordCardWidgetState();
}

class _WordCardWidgetState extends State<WordCardWidget> {
  late WordCardModel _model;

  Future<void> _openWordSheet() async {
    await showModalBottomSheet(
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) {
        return Padding(
          padding: MediaQuery.viewInsetsOf(context),
          child: WoedWidget(
            word: widget.wordDoc!,
          ),
        );
      },
    ).then((value) => safeSetState(() {}));
  }

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => WordCardModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
        onTap: _openWordSheet,
        child: Container(
          width: double.infinity,
          height: 169.0,
          decoration: BoxDecoration(
            color: ExpatlioDesign.card,
            borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
          ),
          child: Padding(
            padding: EdgeInsets.all(ExpatlioDesign.space16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        valueOrDefault<String>(
                          widget.wordDoc?.entry.firstOrNull?.text,
                          '-',
                        ),
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'Cool',
                              color: ExpatlioDesign.text,
                              fontSize: 22.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.normal,
                            ),
                      ),
                    ),
                    Container(
                      width: 40.0,
                      height: 40.0,
                      decoration: BoxDecoration(
                        color: ExpatlioDesign.background,
                        borderRadius:
                            BorderRadius.circular(ExpatlioDesign.radiusCapsule),
                      ),
                      child: Icon(
                        FFIcons.kexpand01,
                        color: ExpatlioDesign.text,
                        size: 14.0,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                      ExpatlioDesign.space20,
                      ExpatlioDesign.space4,
                      ExpatlioDesign.space0,
                      ExpatlioDesign.space4),
                  child: Container(
                    width: 1.0,
                    height: 12.0,
                    decoration: BoxDecoration(
                      color: ExpatlioDesign.muted,
                    ),
                  ),
                ),
                Text(
                  valueOrDefault<String>(
                    widget.wordDoc?.entry.firstOrNull?.tr.firstOrNull?.text,
                    '-',
                  ),
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'Cool',
                        color: ExpatlioDesign.text,
                        fontSize: 22.0,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.normal,
                      ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                      ExpatlioDesign.space0,
                      ExpatlioDesign.space16,
                      ExpatlioDesign.space0,
                      ExpatlioDesign.space0),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FlutterFlowIconButton(
                        borderRadius: ExpatlioDesign.radiusCapsule,
                        buttonSize: 40.0,
                        fillColor: ExpatlioDesign.background,
                        icon: Icon(
                          FFIcons.kstar012,
                          color: FlutterFlowTheme.of(context).primary,
                          size: 16.0,
                        ),
                        onPressed: () async {
                          unawaited(
                            () async {
                              await FlashcardReviewRepository
                                  .deleteReviewForWord(
                                widget.wordDoc!.reference,
                              );
                              await widget.wordDoc!.reference.delete();
                            }(),
                          );
                        },
                      ),
                      Container(
                        height: 24.0,
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(ExpatlioDesign.radiusSmall),
                          border: Border.all(
                            color: ExpatlioDesign.muted,
                            width: 1.0,
                          ),
                        ),
                        child: Align(
                          alignment: AlignmentDirectional(0.0, 0.0),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space8,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space8,
                                ExpatlioDesign.space0),
                            child: Text(
                              valueOrDefault<String>(
                                widget.wordDoc?.entry.firstOrNull?.pos,
                                '-',
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    fontSize: 12.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w500,
                                    lineHeight: 1.0,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ].divide(SizedBox(width: ExpatlioDesign.space12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
