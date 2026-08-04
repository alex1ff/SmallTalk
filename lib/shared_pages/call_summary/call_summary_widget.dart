import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/button/button_widget.dart';
import '/components/pair_review_content.dart';
import '/components/review_card/review_card_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'call_feedback_card.dart';
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

  String _formattedCallDuration() {
    final totalSeconds = widget.dur < 0 ? 0 : widget.dur;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return [
        hours.toString().padLeft(2, '0'),
        minutes.toString().padLeft(2, '0'),
        seconds.toString().padLeft(2, '0'),
      ].join(':');
    }

    return [
      minutes.toString().padLeft(2, '0'),
      seconds.toString().padLeft(2, '0'),
    ].join(':');
  }

  TextStyle _summaryTextStyle(
    BuildContext context, {
    required double fontSize,
    required Color color,
    FontWeight fontWeight = FontWeight.w400,
    double lineHeight = 1.2,
  }) =>
      FlutterFlowTheme.of(context).bodyMedium.override(
            fontFamily: 'sf pro display',
            color: color,
            fontSize: fontSize,
            letterSpacing: 0.0,
            fontWeight: fontWeight,
            lineHeight: lineHeight,
          );

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
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
      ),
      alignment: Alignment.center,
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: ExpatlioDesign.space32),
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
              fullWidth: true,
            ),
          ),
        );
      },
    );
  }

  Color _ratingColor(BuildContext context) {
    if (_model.rait <= 0) {
      return const Color(0xFFD8D8DE);
    }
    if (_model.rait <= 2) {
      return FlutterFlowTheme.of(context).error;
    }
    if (_model.rait == 3) {
      return const Color(0xFFFF8A00);
    }
    return const Color(0xFFFFC600);
  }

  Widget _buildRatingStar(BuildContext context, int rating) {
    final isSelected = _model.rait >= rating;
    return Expanded(
      child: FlutterFlowIconButton(
        borderColor: Colors.transparent,
        borderRadius: ExpatlioDesign.radiusMedium,
        buttonSize: 48.0,
        icon: Icon(
          Icons.star_rounded,
          color: isSelected ? _ratingColor(context) : const Color(0xFFD8D8DE),
          size: 38.0,
        ),
        onPressed: () async {
          _model.rait = rating;
          safeSetState(() {});
        },
      ),
    );
  }

  Widget _buildReviewForm(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
        border: Border.all(
          color: ExpatlioDesign.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
            ExpatlioDesign.space16,
            ExpatlioDesign.space16,
            ExpatlioDesign.space16,
            ExpatlioDesign.space20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Оставить отзыв',
                enText: 'Leave feedback',
              ),
              style: _summaryTextStyle(
                context,
                fontSize: 17.0,
                color: ExpatlioDesign.text,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: ExpatlioDesign.space4),
            Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Оцените разговор и напишите пару слов о собеседнике.',
                enText:
                    'Rate the call and write a few words about your partner.',
              ),
              style: _summaryTextStyle(
                context,
                fontSize: 13.0,
                color: ExpatlioDesign.muted,
              ),
            ),
            const SizedBox(height: ExpatlioDesign.space16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var rating = 1; rating <= 5; rating++)
                  _buildRatingStar(context, rating),
              ],
            ),
            const SizedBox(height: ExpatlioDesign.space12),
            TextFormField(
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
                maxLines: 5,
              ),
              style: ExpatlioDesign.formTextStyle(context),
              maxLines: 5,
              minLines: 3,
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
          ],
        ),
      ),
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
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color activeBackgroundColor,
    required Color activeIconColor,
    Color activeBorderColor = ExpatlioDesign.primary,
  }) {
    return InkWell(
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60.0),
        decoration: BoxDecoration(
          color: isActive
              ? activeBackgroundColor
              : FlutterFlowTheme.of(context).primaryBackground,
          borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
          border: Border.all(
            color: isActive ? activeBorderColor : ExpatlioDesign.border,
          ),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space12,
              ExpatlioDesign.space12,
              ExpatlioDesign.space16,
              ExpatlioDesign.space12),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40.0,
                height: 40.0,
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white
                      : FlutterFlowTheme.of(context).secondaryBackground,
                  borderRadius:
                      BorderRadius.circular(ExpatlioDesign.radiusMedium),
                ),
                child: Icon(
                  icon,
                  color: isActive ? activeIconColor : ExpatlioDesign.text,
                  size: 20.0,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                      ExpatlioDesign.space12,
                      ExpatlioDesign.space0,
                      ExpatlioDesign.space0,
                      ExpatlioDesign.space0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _summaryTextStyle(
                          context,
                          fontSize: 15.0,
                          color: ExpatlioDesign.text,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: ExpatlioDesign.space4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: _summaryTextStyle(
                          context,
                          fontSize: 12.0,
                          color: ExpatlioDesign.muted,
                          lineHeight: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return SizedBox(
      height: 44.0,
      child: Center(
        child: Text(
          FFLocalizations.of(context).getVariableText(
            ruText: 'Звонок завершён · ${_formattedCallDuration()}',
            enText: 'Call ended · ${_formattedCallDuration()}',
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _summaryTextStyle(
            context,
            fontSize: 15.0,
            color: ExpatlioDesign.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryAvatar(
    BuildContext context, {
    required String photoUrl,
    required String displayName,
  }) {
    return Container(
      width: 78.0,
      height: 78.0,
      decoration: BoxDecoration(
        color: ExpatlioDesign.avatarFallbackBackground,
        shape: BoxShape.circle,
        border: Border.all(color: ExpatlioDesign.border),
        image: photoUrl.isNotEmpty
            ? DecorationImage(
                fit: BoxFit.cover,
                image: CachedNetworkImageProvider(
                  photoUrl,
                  maxWidth: 240,
                  maxHeight: 240,
                ),
              )
            : null,
      ),
      child: photoUrl.isEmpty
          ? Center(
              child: Text(
                ExpatlioDesign.avatarInitial(displayName),
                maxLines: 1,
                style: ExpatlioDesign.textStyle(
                  context,
                  color: ExpatlioDesign.avatarFallbackText,
                  size: 24.0,
                  weight: FontWeight.w700,
                ),
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final isComposerActive =
        (_model.aboutMeFocusNode?.hasFocus ?? false) || isKeyboardVisible;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
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
                final effectiveSkipToday = _model.skipToday;

                Future<void> finishSummary() async {
                  if (_model.rait != 0) {
                    final sessionRef = widget.sessionID;
                    final toUserRef = widget.userRef;
                    if (sessionRef == null || toUserRef == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            FFLocalizations.of(context).getVariableText(
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
                      final result = await submitSessionReview(
                        sessionRef: sessionRef,
                        toUserRef: toUserRef,
                        rating: _model.rait,
                        isTeacher: currentUserDocument?.role ==
                            UserRole.native_speaker,
                        comment: _model.aboutMeTextController.text,
                      );
                      _model.reviewRefOverride = result.reviewRef;
                      _model.rait = 0;
                      _model.aboutMeTextController?.clear();
                      FocusScope.of(context).unfocus();
                      safeSetState(() {});
                    } on FirebaseFunctionsException catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(reviewErrorMessage(context, e)),
                        ),
                      );
                      return;
                    } catch (_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(unexpectedReviewErrorMessage(context)),
                        ),
                      );
                      return;
                    }
                  }

                  if (targetUserRef != null && signedInUserRef != null) {
                    final relationshipUpdate = <String, dynamic>{};
                    if (effectiveBlack) {
                      relationshipUpdate.addAll(
                        buildBlockAndRemoveFriendUpdateData(targetUserRef),
                      );
                    } else {
                      if (initiallyBlocked) {
                        relationshipUpdate.addAll(
                          buildUnblockUserUpdateData(targetUserRef),
                        );
                      }
                      if (effectiveFav) {
                        relationshipUpdate.addAll(
                          buildAddFriendUpdateData(targetUserRef),
                        );
                      } else if (initiallyFavorite) {
                        relationshipUpdate.addAll(
                          buildRemoveFriendUpdateData(targetUserRef),
                        );
                      }
                    }

                    if (relationshipUpdate.isNotEmpty) {
                      await signedInUserRef.update(relationshipUpdate);
                    }
                  }

                  _navigateToHome();
                }

                final canShowRelationshipActions =
                    targetUserRef != null && signedInUserRef != null;
                final displayName = _summaryUserDisplayName(
                  context,
                  stackUserPublicProfile,
                );

                return SafeArea(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            ExpatlioDesign.space24,
                            ExpatlioDesign.space12,
                            ExpatlioDesign.space24,
                            ExpatlioDesign.space136,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxWidth: 390.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _buildTopBar(context),
                                  const SizedBox(
                                      height: ExpatlioDesign.space24),
                                  _buildSummaryAvatar(
                                    context,
                                    photoUrl: stackUserPhotoUrl,
                                    displayName: displayName,
                                  ),
                                  const SizedBox(
                                      height: ExpatlioDesign.space12),
                                  Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: _summaryTextStyle(
                                      context,
                                      fontSize: 20.0,
                                      color: ExpatlioDesign.text,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: ExpatlioDesign.space4),
                                  Text(
                                    FFLocalizations.of(context).getVariableText(
                                      ruText: 'Как прошёл разговор?',
                                      enText: 'How did the conversation go?',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: _summaryTextStyle(
                                      context,
                                      fontSize: 17.0,
                                      color: ExpatlioDesign.text,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (canShowRelationshipActions) ...[
                                    const SizedBox(
                                        height: ExpatlioDesign.space20),
                                    _buildSummaryActionButton(
                                      context,
                                      isActive: effectiveFav,
                                      icon: effectiveFav
                                          ? Icons.person_remove_alt_1_rounded
                                          : Icons.person_add_alt_1_rounded,
                                      title: FFLocalizations.of(context)
                                          .getVariableText(
                                        ruText: effectiveFav
                                            ? 'Убрать из друзей'
                                            : 'В друзья',
                                        enText: effectiveFav
                                            ? 'Remove from friends'
                                            : 'Add to friends',
                                      ),
                                      subtitle: FFLocalizations.of(context)
                                          .getVariableText(
                                        ruText: effectiveFav
                                            ? 'Будет удалён из списка друзей'
                                            : 'Появится в вашем списке друзей',
                                        enText: effectiveFav
                                            ? 'Will be removed from your friends list'
                                            : 'Will appear in your friends list',
                                      ),
                                      activeBackgroundColor:
                                          const Color(0xFFF5F0FF),
                                      activeIconColor:
                                          FlutterFlowTheme.of(context).primary,
                                      onTap: () {
                                        _model.favTouched = true;
                                        _model.fav = !effectiveFav;
                                        if (_model.fav) {
                                          _model.blackTouched = true;
                                          _model.black = false;
                                        }
                                        safeSetState(() {});
                                      },
                                    ),
                                    const SizedBox(
                                        height: ExpatlioDesign.space12),
                                    _buildSummaryActionButton(
                                      context,
                                      isActive: effectiveSkipToday,
                                      icon: Icons.access_time_rounded,
                                      title: FFLocalizations.of(context)
                                          .getVariableText(
                                        ruText: 'Больше не соединять сегодня',
                                        enText: 'Do not connect again today',
                                      ),
                                      subtitle: FFLocalizations.of(context)
                                          .getVariableText(
                                        ruText:
                                            'Не будем предлагать его до завтра',
                                        enText:
                                            'We will not suggest them until tomorrow',
                                      ),
                                      activeBackgroundColor:
                                          const Color(0xFFFFF1F1),
                                      activeIconColor:
                                          FlutterFlowTheme.of(context).error,
                                      activeBorderColor:
                                          const Color(0xFFFF8A8A),
                                      onTap: () {
                                        _model.skipToday = !_model.skipToday;
                                        safeSetState(() {});
                                      },
                                    ),
                                    const SizedBox(
                                        height: ExpatlioDesign.space12),
                                    _buildSummaryActionButton(
                                      context,
                                      isActive: effectiveBlack,
                                      icon: Icons.person_off_rounded,
                                      title: FFLocalizations.of(context)
                                          .getVariableText(
                                        ruText: 'Добавить в чёрный список',
                                        enText: 'Add to blacklist',
                                      ),
                                      subtitle: FFLocalizations.of(context)
                                          .getVariableText(
                                        ruText: 'Больше не сможет вам звонить',
                                        enText:
                                            'They will no longer be able to call you',
                                      ),
                                      activeBackgroundColor:
                                          const Color(0xFFFFF6F6),
                                      activeIconColor:
                                          FlutterFlowTheme.of(context).error,
                                      activeBorderColor:
                                          const Color(0xFFFF8A8A),
                                      onTap: () {
                                        _model.blackTouched = true;
                                        _model.black = !effectiveBlack;
                                        if (_model.black) {
                                          _model.favTouched = true;
                                          _model.fav = false;
                                        }
                                        safeSetState(() {});
                                      },
                                    ),
                                  ],
                                  const SizedBox(
                                      height: ExpatlioDesign.space20),
                                  if (widget.sessionID != null) ...[
                                    CallFeedbackCard(
                                      sessionRef: widget.sessionID!,
                                    ),
                                    const SizedBox(
                                      height: ExpatlioDesign.space20,
                                    ),
                                  ],
                                  _buildReviewSection(context),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: AlignmentDirectional.bottomCenter,
                        child: Container(
                          height: 142.0,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0x00FAFAFB),
                                const Color(0xEEFAFAFB),
                                const Color(0xFFFAFAFB),
                              ],
                              stops: const [0.0, 0.22, 0.62],
                              begin: AlignmentDirectional.topCenter,
                              end: AlignmentDirectional.bottomCenter,
                            ),
                          ),
                          child: AnimatedPadding(
                            duration: _ctaAnimationDuration,
                            curve: Curves.easeOutCubic,
                            padding: EdgeInsetsDirectional.fromSTEB(
                              ExpatlioDesign.space24,
                              ExpatlioDesign.space24,
                              ExpatlioDesign.space24,
                              isComposerActive
                                  ? ExpatlioDesign.space24
                                  : ExpatlioDesign.space12,
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
                                          maxWidth: 390.0,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            ButtonWidget(
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
                                              busyStyle:
                                                  ButtonBusyStyle.spinner,
                                              action: finishSummary,
                                            ),
                                            const SizedBox(
                                                height: ExpatlioDesign.space12),
                                            InkWell(
                                              splashColor: Colors.transparent,
                                              focusColor: Colors.transparent,
                                              hoverColor: Colors.transparent,
                                              highlightColor:
                                                  Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      ExpatlioDesign
                                                          .radiusLarge),
                                              onTap: _navigateToHome,
                                              child: Padding(
                                                padding:
                                                    const EdgeInsetsDirectional
                                                        .fromSTEB(
                                                  12.0,
                                                  4.0,
                                                  12.0,
                                                  4.0,
                                                ),
                                                child: Text(
                                                  FFLocalizations.of(context)
                                                      .getText(
                                                    's918m7k5' /* Пропустить */,
                                                  ),
                                                  style: _summaryTextStyle(
                                                    context,
                                                    fontSize: 15.0,
                                                    color: ExpatlioDesign.muted,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
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
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
