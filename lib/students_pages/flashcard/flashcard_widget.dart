import '/auth/firebase_auth/auth_util.dart';
import '/components/empty/empty_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/basic_page_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'flashcard_model.dart';
import 'flashcard_review_logic.dart';
import 'flashcard_review_repository.dart';
import 'flashcard_review_widget.dart';
export 'flashcard_model.dart';

class FlashcardWidget extends StatefulWidget {
  const FlashcardWidget({super.key});

  static String routeName = 'Flashcards';
  static String routePath = '/flashcards';

  @override
  State<FlashcardWidget> createState() => _FlashcardWidgetState();
}

class _FlashcardWidgetState extends State<FlashcardWidget> {
  late FlashcardModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => FlashcardModel());
    _refreshSession();
  }

  void _refreshSession() {
    final userRef = currentUserReference;
    if (userRef == null) {
      _model.sessionFuture = Future<List<FlashcardSessionEntry>>.value(
        const <FlashcardSessionEntry>[],
      );
      return;
    }

    _model.sessionFuture = FlashcardReviewRepository.loadDueSession(
      userRef: userRef,
    );
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafePadding = MediaQuery.of(context).viewPadding.bottom + 16.0;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: ExpatlioDesign.background,
        body: Stack(
          children: [
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                ExpatlioDesign.space4,
                ExpatlioDesign.space112,
                ExpatlioDesign.space4,
                bottomSafePadding,
              ),
              child: FutureBuilder<List<FlashcardSessionEntry>>(
                future: _model.sessionFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: ExpatlioDesign.space24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: FlutterFlowTheme.of(context).error,
                              size: 42.0,
                            ),
                            const SizedBox(height: ExpatlioDesign.space16),
                            Text(
                              FFLocalizations.of(context).getVariableText(
                                ruText:
                                    'Не удалось загрузить карточки. Проверьте доступ к данным и попробуйте снова.',
                                enText:
                                    'Failed to load flashcards. Please check data access and try again.',
                              ),
                              textAlign: TextAlign.center,
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    fontSize: 16.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: ExpatlioDesign.space16),
                            FFButtonWidget(
                              onPressed: () {
                                safeSetState(_refreshSession);
                              },
                              text: FFLocalizations.of(context).getVariableText(
                                ruText: 'Повторить',
                                enText: 'Retry',
                              ),
                              options: FFButtonOptions(
                                height: ExpatlioDesign.buttonHeight,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: ExpatlioDesign.space20),
                                color: FlutterFlowTheme.of(context).secondary,
                                textStyle: FlutterFlowTheme.of(context)
                                    .titleSmall
                                    .override(
                                      fontFamily: 'sf pro display',
                                      color: Colors.white,
                                      fontSize: 15.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                                borderRadius: BorderRadius.circular(
                                    ExpatlioDesign.radiusMedium),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return Center(
                      child: SizedBox(
                        width: 50.0,
                        height: 50.0,
                        child: SpinKitCircle(
                          color: FlutterFlowTheme.of(context).secondary,
                          size: 50.0,
                        ),
                      ),
                    );
                  }

                  final entries =
                      snapshot.data ?? const <FlashcardSessionEntry>[];
                  if (entries.isEmpty) {
                    return Center(
                      child: SizedBox(
                        height: 500.0,
                        child: EmptyWidget(
                          txt: FFLocalizations.of(context).getVariableText(
                            ruText:
                                'Сейчас нет слов, готовых к повторению. Когда подойдут новые интервалы, они появятся здесь.',
                            enText:
                                'There are no words ready for review right now. New cards will appear here when their interval comes due.',
                          ),
                        ),
                      ),
                    );
                  }

                  return FlashcardReviewWidget(
                    entries: entries,
                    onRemembered: (entry, {required hadAnyMiss}) async {
                      await FlashcardReviewRepository.persistCompletedReview(
                        entry: entry,
                        hadAnyMiss: hadAnyMiss,
                      );
                    },
                    onCompleted: () {
                      safeSetState(_refreshSession);
                    },
                  );
                },
              ),
            ),
            BasicPageHeader(
              title: FFLocalizations.of(context).getVariableText(
                ruText: 'Flashcards',
                enText: 'Flashcards',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
