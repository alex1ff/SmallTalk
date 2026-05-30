import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/button/button_widget.dart';
import '/components/pair_review_content.dart';
import '/components/review_card/review_card_widget.dart';
import '/components/wrapper.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/shared_pages/call_history/call_language_utils.dart';
import '/index.dart';
import '/services/user_match_profile.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '/shared_pages/review_flow/review_submission_helper.dart';

import 'call_summary_model.dart';
export 'call_summary_model.dart';

class CallSummaryWidget extends StatefulWidget {
  const CallSummaryWidget({
    super.key,
    required this.userRef,
    required this.sessionID,
    String? lang,
    int? dur,
  })  : this.lang = lang ?? '-',
        this.dur = dur ?? 0;

  final DocumentReference? userRef;
  final DocumentReference? sessionID;
  final String lang;
  final int dur;

  static String routeName = 'CallSummary';
  static String routePath = '/callSummary';

  @override
  State<CallSummaryWidget> createState() => _CallSummaryWidgetState();
}

class _CallSummaryWidgetState extends State<CallSummaryWidget> {
  static const _ctaAnimationDuration = Duration(milliseconds: 180);

  late CallSummaryModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CallSummaryModel());
    _model.userFuture = _createUserFuture();

    _model.aboutMeTextController ??= TextEditingController();
    _model.aboutMeFocusNode ??= FocusNode();
    _model.aboutMeFocusNode!.addListener(() => safeSetState(() {}));
  }

  @override
  void didUpdateWidget(covariant CallSummaryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userRef?.path != widget.userRef?.path) {
      _model.userFuture = _createUserFuture();
    }
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  String _resolvedSessionLanguageName(BuildContext context) {
    return resolveSessionLanguageName(
      languages: FFAppState().languagesList,
      code: widget.lang,
      useRussian: FFLocalizations.of(context).languageCode == 'ru',
    );
  }

  Future<UserPublicProfilesRecord?> _createUserFuture() {
    final userRef = widget.userRef;
    if (userRef == null) {
      return Future.value(null);
    }

    return UserPublicProfilesRecord.maybeGetDocumentOnce(
      UserPublicProfilesRecord.collection.doc(userRef.id),
    );
  }

  String _summaryUserDisplayName(
    BuildContext context,
    UserPublicProfilesRecord? user,
  ) {
    final displayName = user?.displayName.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    return FFLocalizations.of(context).getVariableText(
      ruText: 'Пользователь',
      enText: 'User',
    );
  }

  String _summaryUserPhotoUrl(UserPublicProfilesRecord? user) =>
      user?.photoUrl.trim() ?? '';

  bool _referenceListContains(
    Iterable<DocumentReference>? references,
    DocumentReference? target,
  ) {
    if (target == null) {
      return false;
    }

    for (final reference in references ?? const <DocumentReference>[]) {
      if (reference.path == target.path) {
        return true;
      }
    }

    return false;
  }

  void _navigateToHome() {
    if (!mounted) {
      return;
    }

    if (canAccessTeacherSurfaces(currentUserDocument)) {
      context.goNamed(DashboardNSWidget.routeName);
      return;
    }

    context.goNamed(
      StudentsDashboardWidget.routeName,
      queryParameters: {
        'zn': serializeParam(
          false,
          ParamType.bool,
        ),
      }.withoutNulls,
    );
  }

  Future<PairReviewState> _ensurePairReviewFuture() {
    final targetUserRef = widget.userRef;
    if (currentUserReference == null || targetUserRef == null) {
      return Future.value(const PairReviewState(hasReviewed: false));
    }

    final targetUserPath = targetUserRef.path;
    final cachedFuture = _model.pairReviewFuture;
    if (cachedFuture != null && _model.pairReviewTargetPath == targetUserPath) {
      return cachedFuture;
    }

    final pairReviewFuture = resolveCurrentUserPairReview(
      currentUserRef: currentUserReference!,
      targetUserRef: targetUserRef,
    );
    _model.pairReviewFuture = pairReviewFuture;
    _model.pairReviewTargetPath = targetUserPath;
    return pairReviewFuture;
  }

  Widget _buildReviewLoadingState(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ExpatlioDesign.card,
        borderRadius: BorderRadius.circular(16.0),
      ),
      alignment: Alignment.center,
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 32.0),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildStoredReview(
    BuildContext context, {
    required DocumentReference reviewRef,
  }) {
    return StreamBuilder<DocumentSnapshot<Object?>>(
      stream: reviewRef.snapshots(),
      builder: (context, reviewSnapshot) {
        if (!reviewSnapshot.hasData) {
          return _buildReviewLoadingState(context);
        }

        final reviewDoc = reviewSnapshot.data;
        if (reviewDoc == null ||
            !reviewDoc.exists ||
            reviewDoc.data() == null) {
          return PairReviewContent(
            hasReviewed: true,
            formContent: const SizedBox.shrink(),
            reviewFallbackText: reviewAlreadyLeftMessage(context),
          );
        }

        final reviewRecord = ReviewsRecord.fromSnapshot(reviewDoc);
        return SizedBox(
          width: double.infinity,
          child: Align(
            alignment: Alignment.centerLeft,
            child: ReviewCardWidget(
              rewDoc: reviewRecord,
            ),
          ),
        );
      },
    );
  }

  Widget _buildOpenChatCta(BuildContext context) {
    final currentRef = currentUserReference;
    final targetRef = widget.userRef;
    if (currentRef == null ||
        targetRef == null ||
        currentUserUid.isEmpty ||
        targetRef.id.isEmpty) {
      return const SizedBox.shrink();
    }

    final conversationRef = conversationReferenceForPairId(
      canonicalConversationPairId(currentUserUid, targetRef.id),
    );

    return StreamBuilder<List<ConversationsRecord>>(
      stream: queryConversationsRecord(
        queryBuilder: (query) => query.where(
          FieldPath(['participantMap', currentUserUid]),
          isEqualTo: true,
        ),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        ConversationsRecord? conversation;
        for (final candidate in snapshot.data!) {
          if (candidate.pairId == conversationRef.id) {
            conversation = candidate;
            break;
          }
        }

        if (conversation == null || !conversation.isUnlocked) {
          return const SizedBox.shrink();
        }

        return Wrapper(
          padding: const EdgeInsetsDirectional.fromSTEB(6.0, 28.0, 6.0, 0.0),
          child: ButtonWidget(
            text: FFLocalizations.of(context).getVariableText(
              ruText: 'Открыть чат',
              enText: 'Open chat',
            ),
            loadingText: FFLocalizations.of(context).getVariableText(
              ruText: 'Открываем...',
              enText: 'Opening...',
            ),
            busyStyle: ButtonBusyStyle.spinner,
            action: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) =>
                      ChatThreadWidget(conversationRef: conversationRef),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildReviewForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: ExpatlioDesign.card,
            borderRadius: BorderRadius.circular(16.0),
          ),
          alignment: const AlignmentDirectional(0.0, 0.0),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8.0, 35.0, 8.0, 35.0),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: FlutterFlowIconButton(
                    borderColor: Colors.transparent,
                    borderRadius: 8,
                    buttonSize: 55,
                    icon: Icon(
                      FFIcons.kstar012,
                      color: valueOrDefault<Color>(
                        () {
                          if (_model.rait == 1) {
                            return Color(0xFF850000);
                          } else if (_model.rait == 2) {
                            return Color(0xFFFF0000);
                          } else if (_model.rait == 3) {
                            return Color(0xFFFF3D00);
                          } else if (_model.rait == 4) {
                            return Color(0xFFFF7000);
                          } else if (_model.rait == 5) {
                            return Color(0xFFFFC600);
                          } else {
                            return FlutterFlowTheme.of(context)
                                .secondaryBackground;
                          }
                        }(),
                        FlutterFlowTheme.of(context).secondaryBackground,
                      ),
                      size: 40,
                    ),
                    onPressed: () async {
                      _model.rait = 1;
                      safeSetState(() {});
                    },
                  ),
                ),
                Expanded(
                  child: FlutterFlowIconButton(
                    borderColor: Colors.transparent,
                    borderRadius: 8,
                    buttonSize: 55,
                    icon: Icon(
                      FFIcons.kstar012,
                      color: valueOrDefault<Color>(
                        () {
                          if (_model.rait == 2) {
                            return Color(0xFFFF0000);
                          } else if (_model.rait == 3) {
                            return Color(0xFFFF3D00);
                          } else if (_model.rait == 4) {
                            return Color(0xFFFF7000);
                          } else if (_model.rait == 5) {
                            return Color(0xFFFFC600);
                          } else {
                            return FlutterFlowTheme.of(context)
                                .secondaryBackground;
                          }
                        }(),
                        FlutterFlowTheme.of(context).secondaryBackground,
                      ),
                      size: 40,
                    ),
                    onPressed: () async {
                      _model.rait = 2;
                      safeSetState(() {});
                    },
                  ),
                ),
                Expanded(
                  child: FlutterFlowIconButton(
                    borderColor: Colors.transparent,
                    borderRadius: 8,
                    buttonSize: 55,
                    icon: Icon(
                      FFIcons.kstar012,
                      color: valueOrDefault<Color>(
                        () {
                          if (_model.rait == 3) {
                            return Color(0xFFFF3D00);
                          } else if (_model.rait == 4) {
                            return Color(0xFFFF7000);
                          } else if (_model.rait == 5) {
                            return Color(0xFFFFC600);
                          } else {
                            return FlutterFlowTheme.of(context)
                                .secondaryBackground;
                          }
                        }(),
                        FlutterFlowTheme.of(context).secondaryBackground,
                      ),
                      size: 40,
                    ),
                    onPressed: () async {
                      _model.rait = 3;
                      safeSetState(() {});
                    },
                  ),
                ),
                Expanded(
                  child: FlutterFlowIconButton(
                    borderColor: Colors.transparent,
                    borderRadius: 8,
                    buttonSize: 55,
                    icon: Icon(
                      FFIcons.kstar012,
                      color: valueOrDefault<Color>(
                        () {
                          if (_model.rait == 4) {
                            return Color(0xFFFF7000);
                          } else if (_model.rait == 5) {
                            return Color(0xFFFFC600);
                          } else {
                            return FlutterFlowTheme.of(context)
                                .secondaryBackground;
                          }
                        }(),
                        FlutterFlowTheme.of(context).secondaryBackground,
                      ),
                      size: 40,
                    ),
                    onPressed: () async {
                      _model.rait = 4;
                      safeSetState(() {});
                    },
                  ),
                ),
                Expanded(
                  child: FlutterFlowIconButton(
                    borderColor: Colors.transparent,
                    borderRadius: 8,
                    buttonSize: 55,
                    icon: Icon(
                      FFIcons.kstar012,
                      color: valueOrDefault<Color>(
                        _model.rait == 5
                            ? Color(0xFFFFC600)
                            : FlutterFlowTheme.of(context).secondaryBackground,
                        FlutterFlowTheme.of(context).secondaryBackground,
                      ),
                      size: 40,
                    ),
                    onPressed: () async {
                      _model.rait = 5;
                      safeSetState(() {});
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(0, 12, 0, 0),
          child: SizedBox(
            width: double.infinity,
            child: TextFormField(
              controller: _model.aboutMeTextController,
              focusNode: _model.aboutMeFocusNode,
              onChanged: (_) => EasyDebounce.debounce(
                '_model.aboutMeTextController',
                Duration.zero,
                () => safeSetState(() {}),
              ),
              autofocus: false,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              obscureText: false,
              decoration: ExpatlioDesign.formFieldDecoration(
                context,
                hintText: valueOrDefault<String>(
                  reviewCommentHintText(
                    context,
                    _model.rait,
                  ),
                  reviewCommentHintText(context, 0),
                ),
                maxLines: 12,
              ),
              style: ExpatlioDesign.formTextStyle(context),
              maxLines: 12,
              minLines: 2,
              cursorColor: ExpatlioDesign.primary,
              enableInteractiveSelection: true,
              validator:
                  _model.aboutMeTextControllerValidator.asValidator(context),
              inputFormatters: [
                if (!isAndroid && !isiOS)
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    return TextEditingValue(
                      selection: newValue.selection,
                      text: newValue.text
                          .toCapitalization(TextCapitalization.sentences),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewSection(BuildContext context) {
    return FutureBuilder<PairReviewState>(
      future: _ensurePairReviewFuture(),
      builder: (context, snapshot) {
        final resolvedReviewRef =
            _model.reviewRefOverride ?? snapshot.data?.reviewRef;
        final hasReviewed =
            resolvedReviewRef != null || (snapshot.data?.hasReviewed ?? false);

        if (!snapshot.hasData && _model.reviewRefOverride == null) {
          return _buildReviewLoadingState(context);
        }

        return PairReviewContent(
          hasReviewed: hasReviewed,
          reviewContent: resolvedReviewRef != null
              ? _buildStoredReview(context, reviewRef: resolvedReviewRef)
              : null,
          reviewNoteText: FFLocalizations.of(context).getVariableText(
            ruText: 'Отзыв на собеседника уже оставлен',
            enText: 'A review for your partner has already been submitted',
          ),
          reviewFallbackText: reviewAlreadyLeftMessage(context),
          formContent: _buildReviewForm(context),
        );
      },
    );
  }

  Widget _buildSummaryActionButton(
    BuildContext context, {
    required bool isActive,
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    required Color activeBackgroundColor,
    required Color activeIconColor,
  }) {
    return InkWell(
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: valueOrDefault<Color>(
            isActive
                ? activeBackgroundColor
                : FlutterFlowTheme.of(context).primaryBackground,
            FlutterFlowTheme.of(context).primaryBackground,
          ),
          borderRadius: BorderRadius.circular(55),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: valueOrDefault<Color>(
                    isActive
                        ? FlutterFlowTheme.of(context).primaryBackground
                        : FlutterFlowTheme.of(context).secondaryBackground,
                    FlutterFlowTheme.of(context).secondaryBackground,
                  ),
                  borderRadius: BorderRadius.circular(55),
                ),
                child: Icon(
                  icon,
                  color: valueOrDefault<Color>(
                    isActive ? activeIconColor : ExpatlioDesign.muted,
                    ExpatlioDesign.muted,
                  ),
                  size: 20,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 16, 0),
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          fontFamily: 'sf pro display',
                          color: valueOrDefault<Color>(
                            isActive
                                ? FlutterFlowTheme.of(context).primaryBackground
                                : ExpatlioDesign.text,
                            ExpatlioDesign.text,
                          ),
                          fontSize: 15,
                          letterSpacing: 0.0,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final isComposerActive =
        (_model.aboutMeFocusNode?.hasFocus ?? false) || isKeyboardVisible;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: ExpatlioDesign.background,
        body: FutureBuilder<UserPublicProfilesRecord?>(
          future: _model.userFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox.shrink();
            }

            final stackUserPublicProfile = snapshot.data;
            final stackUserPhotoUrl =
                _summaryUserPhotoUrl(stackUserPublicProfile);

            return AuthUserStreamWidget(
              builder: (context) {
                final targetUserRef = widget.userRef;
                final signedInUserRef = currentUserReference;
                final initiallyFavorite =
                    userHasFriend(currentUserDocument, targetUserRef);
                final initiallyBlocked = _referenceListContains(
                  currentUserDocument?.blockedUsers,
                  targetUserRef,
                );
                final effectiveBlack =
                    _model.blackTouched ? _model.black : initiallyBlocked;
                final effectiveFav = effectiveBlack
                    ? false
                    : (_model.favTouched ? _model.fav : initiallyFavorite);

                return Stack(
                  children: [
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(6, 0, 6, 0),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  EdgeInsetsDirectional.fromSTEB(10, 16, 10, 0),
                              child: Text(
                                FFLocalizations.of(context).getText(
                                  'nkmvs84c' /* Как прошёл звонок? */,
                                ),
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      fontFamily: 'Cool',
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      fontSize: 43,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.normal,
                                      lineHeight: 1.1,
                                    ),
                              ),
                            ),
                            Padding(
                              padding:
                                  EdgeInsetsDirectional.fromSTEB(10, 4, 10, 0),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Text(
                                    () {
                                      final totalSeconds = widget.dur;
                                      final minutes = totalSeconds ~/ 60;
                                      final seconds = totalSeconds % 60;
                                      return '$minutes:${seconds.toString().padLeft(2, '0')} мин';
                                    }(),
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          fontFamily: 'sf pro display',
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryText,
                                          fontSize: 15,
                                          letterSpacing: 0.0,
                                        ),
                                  ),
                                  SizedBox(
                                    height: 10,
                                    child: VerticalDivider(
                                      thickness: 1,
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      _resolvedSessionLanguageName(context),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryText,
                                            fontSize: 15,
                                            letterSpacing: 0.0,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding:
                                  EdgeInsetsDirectional.fromSTEB(0, 40, 0, 0),
                              child: _buildReviewSection(context),
                            ),
                            _buildOpenChatCta(context),
                            if (targetUserRef != null &&
                                signedInUserRef != null)
                              Padding(
                                padding:
                                    EdgeInsetsDirectional.fromSTEB(0, 40, 0, 0),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final showsFriendAction =
                                        (currentUserDocument?.role ==
                                                UserRole.student) &&
                                            !effectiveBlack;
                                    final useVerticalActions =
                                        showsFriendAction &&
                                            constraints.maxWidth < 430.0;
                                    final friendAction =
                                        _buildSummaryActionButton(
                                      context,
                                      isActive: effectiveFav,
                                      icon: FFIcons.kheart,
                                      text: FFLocalizations.of(context)
                                          .getVariableText(
                                        ruText: effectiveFav
                                            ? 'Убрать из друзей'
                                            : 'Добавить в друзья',
                                        enText: effectiveFav
                                            ? 'Remove from friends'
                                            : 'Add to friends',
                                      ),
                                      activeBackgroundColor:
                                          FlutterFlowTheme.of(context).primary,
                                      activeIconColor:
                                          FlutterFlowTheme.of(context).error,
                                      onTap: () {
                                        _model.favTouched = true;
                                        _model.fav = !effectiveFav;
                                        safeSetState(() {});
                                      },
                                    );
                                    final blockAction =
                                        _buildSummaryActionButton(
                                      context,
                                      isActive: effectiveBlack,
                                      icon: FFIcons.kthumbsDown,
                                      text: FFLocalizations.of(context).getText(
                                        'kth7l1fn' /* Не соединять */,
                                      ),
                                      activeBackgroundColor:
                                          FlutterFlowTheme.of(context).error,
                                      activeIconColor:
                                          FlutterFlowTheme.of(context).error,
                                      onTap: () {
                                        _model.blackTouched = true;
                                        _model.black = !effectiveBlack;
                                        if (_model.black) {
                                          _model.favTouched = true;
                                          _model.fav = false;
                                        }
                                        safeSetState(() {});
                                      },
                                    );

                                    if (useVerticalActions) {
                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (showsFriendAction) friendAction,
                                          if (showsFriendAction)
                                            const SizedBox(height: 12.0),
                                          blockAction,
                                        ],
                                      );
                                    }

                                    return Row(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        if (showsFriendAction)
                                          Expanded(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsetsDirectional
                                                      .only(end: 6.0),
                                              child: friendAction,
                                            ),
                                          ),
                                        if (showsFriendAction)
                                          const SizedBox(width: 6.0),
                                        Expanded(child: blockAction),
                                      ],
                                    );
                                  },
                                ),
                              ),
                          ].addToStart(SizedBox(height: 115)).addToEnd(
                                const SizedBox(height: 120),
                              ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional(0, 1),
                      child: SizedBox(
                        height: 120.0,
                        child: AnimatedPadding(
                          duration: _ctaAnimationDuration,
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsetsDirectional.fromSTEB(
                            0.0,
                            0.0,
                            0.0,
                            isComposerActive ? 24.0 : 0.0,
                          ),
                          child: IgnorePointer(
                            ignoring: isComposerActive,
                            child: AnimatedOpacity(
                              duration: _ctaAnimationDuration,
                              curve: Curves.easeOutCubic,
                              opacity: isComposerActive ? 0.0 : 1.0,
                              child: AnimatedSlide(
                                duration: _ctaAnimationDuration,
                                curve: Curves.easeOutCubic,
                                offset: isComposerActive
                                    ? const Offset(0.0, 0.24)
                                    : Offset.zero,
                                child: wrapWithModel(
                                  model: _model.buttonModel,
                                  updateCallback: () => safeSetState(() {}),
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 360.0,
                                      ),
                                      child: Wrapper(
                                        padding: const EdgeInsetsDirectional
                                            .fromSTEB(6.0, 0.0, 6.0, 35.0),
                                        child: ButtonWidget(
                                          text: FFLocalizations.of(context)
                                              .getText(
                                            'duynuhus' /* Готово */,
                                          ),
                                          loadingText:
                                              FFLocalizations.of(context)
                                                  .getVariableText(
                                            ruText: 'Сохраняем...',
                                            enText: 'Saving...',
                                          ),
                                          busyStyle: ButtonBusyStyle.spinner,
                                          action: () async {
                                            if (_model.rait != 0) {
                                              final sessionRef =
                                                  widget.sessionID;
                                              final toUserRef = widget.userRef;
                                              if (sessionRef == null ||
                                                  toUserRef == null) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      FFLocalizations.of(
                                                              context)
                                                          .getVariableText(
                                                        ruText:
                                                            'Не удалось отправить отзыв: отсутствуют данные сессии.',
                                                        enText:
                                                            'Unable to submit review: missing session data.',
                                                      ),
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }

                                              try {
                                                final result =
                                                    await submitSessionReview(
                                                  sessionRef: sessionRef,
                                                  toUserRef: toUserRef,
                                                  rating: _model.rait,
                                                  isTeacher: currentUserDocument
                                                          ?.role ==
                                                      UserRole.native_speaker,
                                                  comment: _model
                                                      .aboutMeTextController
                                                      .text,
                                                );
                                                _model.reviewRefOverride =
                                                    result.reviewRef;
                                                _model.rait = 0;
                                                _model.aboutMeTextController
                                                    ?.clear();
                                                FocusScope.of(context)
                                                    .unfocus();
                                                safeSetState(() {});
                                              } on FirebaseFunctionsException catch (e) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      reviewErrorMessage(
                                                          context, e),
                                                    ),
                                                  ),
                                                );
                                                return;
                                              } catch (_) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      unexpectedReviewErrorMessage(
                                                          context),
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }
                                            }
                                            if (targetUserRef != null &&
                                                signedInUserRef != null) {
                                              if (effectiveBlack) {
                                                await signedInUserRef.update({
                                                  ...buildBlockAndRemoveFriendUpdateData(
                                                    targetUserRef,
                                                  ),
                                                });
                                              } else if (effectiveFav) {
                                                await signedInUserRef.update({
                                                  ...buildAddFriendUpdateData(
                                                    targetUserRef,
                                                  ),
                                                });
                                              } else if (initiallyFavorite) {
                                                await signedInUserRef.update({
                                                  ...buildRemoveFriendUpdateData(
                                                    targetUserRef,
                                                  ),
                                                });
                                              }
                                            }

                                            _navigateToHome();
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            FlutterFlowTheme.of(context).secondaryBackground,
                            Color(0xEFF2F2F7),
                            Color(0x00F2F2F7)
                          ],
                          stops: [0, 0.8, 1],
                          begin: AlignmentDirectional(0, -1),
                          end: AlignmentDirectional(0, 1),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(6, 55, 6, 6),
                        child: Container(
                          height: 70,
                          decoration: BoxDecoration(
                            color:
                                FlutterFlowTheme.of(context).primaryBackground,
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: FlutterFlowTheme.of(context)
                                  .secondaryBackground,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(2),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Container(
                                  width: 66,
                                  height: 66,
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    image: stackUserPhotoUrl.isNotEmpty
                                        ? DecorationImage(
                                            fit: BoxFit.cover,
                                            image: CachedNetworkImageProvider(
                                              stackUserPhotoUrl,
                                              maxWidth: 200,
                                              maxHeight: 200,
                                            ),
                                          )
                                        : null,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        12, 0, 0, 0),
                                    child: Text(
                                      _summaryUserDisplayName(
                                        context,
                                        stackUserPublicProfile,
                                      ),
                                      maxLines: 2,
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            fontSize: 16,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.w600,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  splashColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  onTap: () async {
                                    _navigateToHome();
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            12, 0, 12, 0),
                                        child: Text(
                                          FFLocalizations.of(context).getText(
                                            's918m7k5' /* Пропустить */,
                                          ),
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                      ),
                                      Container(
                                        width: 66,
                                        height: 66,
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryBackground,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Align(
                                          alignment: AlignmentDirectional(0, 0),
                                          child: Icon(
                                            Icons.close_rounded,
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
