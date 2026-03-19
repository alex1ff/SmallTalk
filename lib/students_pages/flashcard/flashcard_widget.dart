import '/auth/firebase_auth/auth_util.dart';
import '/components/empty/empty_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
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
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12.0, 115.0, 12.0, 24.0),
              child: FutureBuilder<List<FlashcardSessionEntry>>(
                future: _model.sessionFuture,
                builder: (context, snapshot) {
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

                  final entries = snapshot.data ?? const <FlashcardSessionEntry>[];
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
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    FlutterFlowTheme.of(context).secondaryBackground,
                    const Color(0xEFF2F2F7),
                    const Color(0x00F2F2F7),
                  ],
                  stops: const [0.0, 0.8, 1.0],
                  begin: const AlignmentDirectional(0.0, -1.0),
                  end: const AlignmentDirectional(0.0, 1.0),
                ),
              ),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12.0, 55.0, 12.0, 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 45.0,
                      height: 45.0,
                      decoration: const BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 7.0,
                            color: Color(0x0D2C2C2C),
                            offset: Offset(0.0, 2.0),
                          ),
                        ],
                        shape: BoxShape.circle,
                      ),
                      child: FlutterFlowIconButton(
                        borderRadius: 70.0,
                        buttonSize: 45.0,
                        fillColor: Colors.white,
                        icon: Icon(
                          FFIcons.kchevronLeft,
                          color: FlutterFlowTheme.of(context).primaryText,
                          size: 20.0,
                        ),
                        onPressed: () async {
                          context.safePop();
                        },
                      ),
                    ),
                    Text(
                      FFLocalizations.of(context).getVariableText(
                        ruText: 'Flashcards',
                        enText: 'Flashcards',
                      ),
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontFamily: 'Cool',
                            fontSize: 18.0,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.normal,
                          ),
                    ),
                    const SizedBox(
                      width: 45.0,
                      height: 45.0,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
