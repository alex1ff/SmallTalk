import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/review_card/review_card_widget.dart';
import '/flutter_flow/custom_functions.dart' as functions;
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/shared_pages/call_history/call_history_utils.dart';
import '/shared_pages/review_flow/review_submission_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'call_details_model.dart';
export 'call_details_model.dart';

class CallDetailsWidget extends StatefulWidget {
  const CallDetailsWidget({
    super.key,
    required this.videoDocRef,
  });

  final DocumentReference? videoDocRef;

  static String routeName = 'callDetails';
  static String routePath = '/callDetails';

  @override
  State<CallDetailsWidget> createState() => _CallDetailsWidgetState();
}

class _CallDetailsWidgetState extends State<CallDetailsWidget> {
  late CallDetailsModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  Future<List<TransactionsRecord>>? _transactionsFuture;

  bool get _isTeacher => currentUserDocument?.role == UserRole.native_speaker;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CallDetailsModel());
    _model.reviewCommentTextController ??= TextEditingController();
    _model.reviewCommentFocusNode ??= FocusNode();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  bool _isTeacherForSession(VideoSessionsRecord session) {
    final tutorId = session.tutorId.trim();
    if (tutorId.isNotEmpty && tutorId == currentUserUid) {
      return true;
    }

    final studentId = session.studentId.trim();
    if (studentId.isNotEmpty && studentId == currentUserUid) {
      return false;
    }

    return _isTeacher;
  }

  Future<List<TransactionsRecord>>? _ensureTransactionsFuture() {
    if (_isTeacher || currentUserReference == null) {
      return null;
    }

    return _transactionsFuture ??= queryTransactionsRecordOnce(
      queryBuilder: (transactionsRecord) => transactionsRecord.where(
        'userId',
        isEqualTo: currentUserReference,
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
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

  List<CaptionLogsRecord> _sortedCaptionLogs(List<CaptionLogsRecord> logs) {
    final sortedLogs = List<CaptionLogsRecord>.from(logs);
    sortedLogs.sort((left, right) {
      final leftTime = left.capturedAtClient ??
          left.createdAtServer ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final rightTime = right.capturedAtClient ??
          right.createdAtServer ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final byTime = leftTime.compareTo(rightTime);
      if (byTime != 0) {
        return byTime;
      }

      final byUtterance = left.utteranceId.compareTo(right.utteranceId);
      if (byUtterance != 0) {
        return byUtterance;
      }

      return left.reference.id.compareTo(right.reference.id);
    });
    return sortedLogs;
  }

  DateTime? _captionLogTimestamp(CaptionLogsRecord log) {
    return log.capturedAtClient ?? log.createdAtServer;
  }

  String _captionLogSpeakerFallback(
    BuildContext context,
    CaptionLogsRecord log,
  ) {
    switch (log.speakerRole.trim().toLowerCase()) {
      case 'student':
        return FFLocalizations.of(context).getVariableText(
          ruText: 'Студент',
          enText: 'Student',
        );
      case 'tutor':
        return FFLocalizations.of(context).getVariableText(
          ruText: 'Преподаватель',
          enText: 'Tutor',
        );
      default:
        return FFLocalizations.of(context).getVariableText(
          ruText: 'Участник',
          enText: 'Participant',
        );
    }
  }

  String _captionLogSpeakerLabel(
    BuildContext context,
    CaptionLogsRecord log,
  ) {
    if (log.speakerId.trim().isNotEmpty &&
        log.speakerId.trim() == currentUserUid) {
      return FFLocalizations.of(context).getVariableText(
        ruText: 'Вы',
        enText: 'You',
      );
    }

    final speakerName = log.speakerName.trim();
    if (speakerName.isNotEmpty) {
      return speakerName;
    }

    return _captionLogSpeakerFallback(context, log);
  }

  Color _captionLogSpeakerColor(BuildContext context, CaptionLogsRecord log) {
    switch (log.speakerRole.trim().toLowerCase()) {
      case 'student':
        return const Color(0xFFE2EDFF);
      case 'tutor':
        return const Color(0xFFFFE4F3);
      default:
        return FlutterFlowTheme.of(context).secondaryBackground;
    }
  }

  String _captionLogTimestampLabel(
    BuildContext context,
    CaptionLogsRecord log,
  ) {
    final timestamp = _captionLogTimestamp(log);
    if (timestamp == null) {
      return '';
    }

    return dateTimeFormat(
      'Hm',
      timestamp,
      locale: FFLocalizations.of(context).languageCode,
    );
  }

  Widget _buildCaptionLogItem(
    BuildContext context,
    CaptionLogsRecord log,
  ) {
    final timestampLabel = _captionLogTimestampLabel(context, log);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: FlutterFlowTheme.of(context).primaryText.withValues(
                alpha: 0.06,
              ),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: _captionLogSpeakerColor(context, log),
                    borderRadius: BorderRadius.circular(999.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10.0,
                      vertical: 6.0,
                    ),
                    child: Text(
                      _captionLogSpeakerLabel(context, log),
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontFamily: 'sf pro display',
                            fontSize: 12.0,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      timestampLabel,
                      textAlign: TextAlign.end,
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontFamily: 'sf pro display',
                            color: FlutterFlowTheme.of(context)
                                .secondaryText
                                .withValues(alpha: 0.85),
                            fontSize: 12.0,
                            letterSpacing: 0.0,
                          ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10.0),
            Text(
              log.text,
              style: FlutterFlowTheme.of(context)
                  .bodyMedium
                  .override(
                    fontFamily: 'sf pro display',
                    fontSize: 15.0,
                    letterSpacing: 0.0,
                  )
                  .copyWith(height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptionLogsSection(
    BuildContext context,
    VideoSessionsRecord session,
  ) {
    return StreamBuilder<List<CaptionLogsRecord>>(
      stream: queryCaptionLogsRecord(parent: session.reference),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).primaryBackground,
              borderRadius: BorderRadius.circular(26.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: _buildLoadingState(context),
            ),
          );
        }

        final logs = _sortedCaptionLogs(snapshot.data!);

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).primaryBackground,
            borderRadius: BorderRadius.circular(26.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: logs.isEmpty
                ? Text(
                    FFLocalizations.of(context).getVariableText(
                      ruText:
                          'Логи субтитров для этого звонка пока недоступны.',
                      enText:
                          'Subtitle logs for this call are not available yet.',
                    ),
                    style: FlutterFlowTheme.of(context)
                        .bodyMedium
                        .override(
                          fontFamily: 'sf pro display',
                          color: FlutterFlowTheme.of(context).secondaryText,
                          fontSize: 14.0,
                          letterSpacing: 0.0,
                        )
                        .copyWith(height: 1.4),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12.0),
                    itemBuilder: (context, index) =>
                        _buildCaptionLogItem(context, logs[index]),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
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
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 45.0,
              height: 45.0,
              decoration: BoxDecoration(
                boxShadow: const [
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
                ruText: 'Детали звонка',
                enText: 'Call details',
              ),
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'Cool',
                    fontSize: 18.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.normal,
                  ),
            ),
            Container(
              width: 45.0,
              height: 45.0,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _companionName(BuildContext context, VideoSessionsRecord session) {
    final isTeacher = _isTeacherForSession(session);
    final rawName =
        (isTeacher ? session.studentInfo.name : session.tutorInfo.name).trim();
    if (rawName.isNotEmpty) {
      return rawName;
    }

    return FFLocalizations.of(context).getVariableText(
      ruText: isTeacher ? 'Студент' : 'Преподаватель',
      enText: isTeacher ? 'Student' : 'Tutor',
    );
  }

  String _companionPhoto(VideoSessionsRecord session) {
    final isTeacher = _isTeacherForSession(session);
    return (isTeacher ? session.studentInfo.photo : session.tutorInfo.photo)
        .trim();
  }

  DocumentReference? _tutorReference(VideoSessionsRecord session) {
    if (_isTeacherForSession(session)) {
      return null;
    }

    final tutorId = session.tutorId.trim();
    if (tutorId.isEmpty) {
      return null;
    }

    return functions.stringToRef(tutorId);
  }

  DocumentReference? _reviewTargetReference(VideoSessionsRecord session) {
    final targetId =
        (_isTeacherForSession(session) ? session.studentId : session.tutorId)
            .trim();
    if (targetId.isEmpty) {
      return null;
    }

    return functions.stringToRef(targetId);
  }

  Widget _buildAvatar(BuildContext context, VideoSessionsRecord session) {
    final photoUrl = _companionPhoto(session);
    final displayName = _companionName(context, session);

    return Container(
      width: 52.0,
      height: 52.0,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(22.0),
      ),
      child: photoUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(22.0),
              child: CachedNetworkImage(
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                imageUrl: photoUrl,
                width: 52.0,
                height: 52.0,
                fit: BoxFit.cover,
                memCacheWidth: 104,
                memCacheHeight: 104,
              ),
            )
          : Center(
              child: Text(
                displayName.characters.first.toUpperCase(),
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'Cool',
                      fontSize: 20.0,
                      letterSpacing: 0.0,
                    ),
              ),
            ),
    );
  }

  Widget _buildParticipantCard(
    BuildContext context,
    VideoSessionsRecord session,
  ) {
    final tutorReference = _tutorReference(session);
    final canNavigate = tutorReference != null;

    final card = Container(
      width: double.infinity,
      height: 60.0,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
        borderRadius: BorderRadius.circular(26.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            _buildAvatar(context, session),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(12.0, 0.0, 0.0, 0.0),
                child: Text(
                  _companionName(context, session),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'sf pro display',
                        fontSize: 16.0,
                        letterSpacing: 0.0,
                      ),
                ),
              ),
            ),
            if (canNavigate)
              Container(
                width: 52.0,
                height: 52.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: Icon(
                  FFIcons.kchevronRight,
                  color: FlutterFlowTheme.of(context).primaryText,
                  size: 18.0,
                ),
              ),
          ],
        ),
      ),
    );

    if (!canNavigate) {
      return card;
    }

    return InkWell(
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () async {
        context.pushNamed(
          NativeSpeakerPageWidget.routeName,
          queryParameters: {
            'nsUserDocRef': serializeParam(
              tutorReference,
              ParamType.DocumentReference,
            ),
          }.withoutNulls,
        );
      },
      child: card,
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required String label,
    required Widget value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'sf pro display',
                  color: FlutterFlowTheme.of(context).secondaryText,
                  fontSize: 14.0,
                  letterSpacing: 0.0,
                ),
          ),
        ),
        const SizedBox(width: 16.0),
        Flexible(child: value),
      ],
    );
  }

  Widget _buildValueText(BuildContext context, String value) {
    return Text(
      value,
      textAlign: TextAlign.end,
      style: FlutterFlowTheme.of(context).bodyMedium.override(
            fontFamily: 'sf pro display',
            fontSize: 15.0,
            letterSpacing: 0.0,
            fontWeight: FontWeight.w500,
          ),
    );
  }

  String _studentCostLabel(List<TransactionsRecord> transactions) {
    if (widget.videoDocRef == null) {
      return '-';
    }

    TransactionsRecord? match;
    for (final transaction in transactions) {
      if (transaction.type == TypeTransactions.call_charge &&
          transaction.sessionDocRef?.path == widget.videoDocRef!.path) {
        match = transaction;
        break;
      }
    }

    if (match == null || !match.hasAmountST()) {
      return '-';
    }

    return formatStAmount(match.amountST);
  }

  Widget _buildAmountValue(BuildContext context, VideoSessionsRecord session) {
    if (_isTeacherForSession(session)) {
      return _buildValueText(
        context,
        session.hasEarnings() ? formatRubAmount(session.earnings) : '-',
      );
    }

    final transactionsFuture = _ensureTransactionsFuture();
    if (transactionsFuture == null) {
      return _buildValueText(context, '-');
    }

    return FutureBuilder<List<TransactionsRecord>>(
      future: transactionsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildValueText(context, '...');
        }

        return _buildValueText(
          context,
          _studentCostLabel(snapshot.data!),
        );
      },
    );
  }

  Color _selectedReviewColor(BuildContext context, int rating) {
    switch (rating) {
      case 1:
        return const Color(0xFF850000);
      case 2:
        return const Color(0xFFFF0000);
      case 3:
        return const Color(0xFFFF3D00);
      case 4:
        return const Color(0xFFFF7000);
      case 5:
        return const Color(0xFFFFC600);
      default:
        return FlutterFlowTheme.of(context).secondaryBackground;
    }
  }

  Widget _buildReviewStarButton(BuildContext context, int value) {
    final currentRating = _model.rating;
    return Expanded(
      child: FlutterFlowIconButton(
        borderColor: Colors.transparent,
        borderRadius: 8.0,
        buttonSize: 55.0,
        icon: Icon(
          FFIcons.kstar012,
          color: currentRating >= value
              ? _selectedReviewColor(context, currentRating)
              : FlutterFlowTheme.of(context).secondaryBackground,
          size: 40.0,
        ),
        onPressed: _model.isSubmittingReview
            ? null
            : () async {
                _model.rating = value;
                safeSetState(() {});
              },
      ),
    );
  }

  Future<void> _submitReview(
    BuildContext context,
    VideoSessionsRecord session,
  ) async {
    final sessionRef = widget.videoDocRef;
    final targetUserRef = _reviewTargetReference(session);
    final isTeacher = _isTeacherForSession(session);

    if (_model.rating == 0) {
      _showSnackBar(
        context,
        FFLocalizations.of(context).getVariableText(
          ruText: 'Поставьте оценку, чтобы отправить отзыв.',
          enText: 'Select a rating before sending the review.',
        ),
      );
      return;
    }

    if (sessionRef == null || targetUserRef == null) {
      _showSnackBar(
        context,
        FFLocalizations.of(context).getVariableText(
          ruText: 'Не удалось отправить отзыв: отсутствуют данные звонка.',
          enText: 'Unable to submit review: missing call data.',
        ),
      );
      return;
    }

    _model.isSubmittingReview = true;
    safeSetState(() {});

    try {
      final result = await submitSessionReview(
        sessionRef: sessionRef,
        toUserRef: targetUserRef,
        rating: _model.rating,
        isTeacher: isTeacher,
        comment: _model.reviewCommentTextController.text,
      );

      _model.hasReviewedOverride = true;
      _model.reviewRefOverride = result.reviewRef;
      _model.rating = 0;
      _model.reviewCommentTextController?.clear();
      FocusScope.of(context).unfocus();
    } on FirebaseFunctionsException catch (error) {
      _showSnackBar(context, reviewErrorMessage(context, error));
    } catch (_) {
      _showSnackBar(context, unexpectedReviewErrorMessage(context));
    } finally {
      _model.isSubmittingReview = false;
      safeSetState(() {});
    }
  }

  Widget _buildReviewSubmitButton(
    BuildContext context,
    VideoSessionsRecord session,
  ) {
    return Opacity(
      opacity: _model.isSubmittingReview ? 0.75 : 1.0,
      child: InkWell(
        splashColor: Colors.transparent,
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: _model.isSubmittingReview
            ? null
            : () async {
                await _submitReview(context, session);
              },
        child: Container(
          height: 60.0,
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).primaryText,
            borderRadius: BorderRadius.circular(50.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2.0),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                        16.0, 0.0, 0.0, 0.0),
                    child: Text(
                      FFLocalizations.of(context).getVariableText(
                        ruText: _model.isSubmittingReview
                            ? 'Отправляем отзыв...'
                            : 'Оставить отзыв',
                        enText: _model.isSubmittingReview
                            ? 'Sending review...'
                            : 'Submit review',
                      ),
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontFamily: 'Cool',
                            color:
                                FlutterFlowTheme.of(context).primaryBackground,
                            fontSize: 20.0,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.normal,
                          ),
                    ),
                  ),
                ),
                Container(
                  width: 56.0,
                  height: 56.0,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).primaryBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Align(
                    alignment: const AlignmentDirectional(0.0, 0.0),
                    child: _model.isSubmittingReview
                        ? SizedBox(
                            width: 20.0,
                            height: 20.0,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                FlutterFlowTheme.of(context).primaryText,
                              ),
                            ),
                          )
                        : const Icon(
                            FFIcons.karrowRight,
                            color: Colors.black,
                            size: 20.0,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewForm(BuildContext context, VideoSessionsRecord session) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
        borderRadius: BorderRadius.circular(26.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                borderRadius: BorderRadius.circular(26.0),
              ),
              alignment: const AlignmentDirectional(0.0, 0.0),
              child: Padding(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(8.0, 28.0, 8.0, 28.0),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (index) => _buildReviewStarButton(context, index + 1),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12.0),
            TextFormField(
              controller: _model.reviewCommentTextController,
              focusNode: _model.reviewCommentFocusNode,
              onChanged: (_) => EasyDebounce.debounce(
                '_model.reviewCommentTextController',
                Duration.zero,
                () => safeSetState(() {}),
              ),
              autofocus: false,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              obscureText: false,
              decoration: InputDecoration(
                isDense: false,
                hintText: reviewCommentHintText(context, _model.rating),
                hintStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'sf pro display',
                      color: FlutterFlowTheme.of(context).secondaryText,
                      fontSize: 16.0,
                      letterSpacing: 0.0,
                    ),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                    color: Color(0x00000000),
                    width: 1.0,
                  ),
                  borderRadius: BorderRadius.circular(26.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                    color: Color(0x00000000),
                    width: 1.0,
                  ),
                  borderRadius: BorderRadius.circular(26.0),
                ),
                errorBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: FlutterFlowTheme.of(context).error,
                    width: 1.0,
                  ),
                  borderRadius: BorderRadius.circular(26.0),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: FlutterFlowTheme.of(context).error,
                    width: 1.0,
                  ),
                  borderRadius: BorderRadius.circular(26.0),
                ),
                filled: true,
                fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                contentPadding: const EdgeInsets.all(16.0),
                hoverColor: FlutterFlowTheme.of(context).secondaryBackground,
              ),
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'sf pro display',
                    fontSize: 16.0,
                    letterSpacing: 0.0,
                  ),
              maxLines: 12,
              minLines: 2,
              cursorColor: FlutterFlowTheme.of(context).primaryText,
              enableInteractiveSelection: true,
              validator: _model.reviewCommentTextControllerValidator
                  .asValidator(context),
              inputFormatters: [
                if (!isAndroid && !isiOS)
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    return TextEditingValue(
                      selection: newValue.selection,
                      text: newValue.text.toCapitalization(
                        TextCapitalization.sentences,
                      ),
                    );
                  }),
              ],
            ),
            const SizedBox(height: 14.0),
            _buildReviewSubmitButton(context, session),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmittedReviewFallback(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
        borderRadius: BorderRadius.circular(26.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          FFLocalizations.of(context).getVariableText(
            ruText: 'Отзыв уже сохранен для этого звонка.',
            enText: 'A review has already been saved for this call.',
          ),
          style: FlutterFlowTheme.of(context).bodyMedium.override(
                fontFamily: 'sf pro display',
                fontSize: 15.0,
                letterSpacing: 0.0,
              ),
        ),
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
          return _buildLoadingState(context);
        }

        final reviewDoc = reviewSnapshot.data;
        if (reviewDoc == null ||
            !reviewDoc.exists ||
            reviewDoc.data() == null) {
          return _buildSubmittedReviewFallback(context);
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

  Widget _buildReviewSection(
    BuildContext context,
    VideoSessionsRecord session,
  ) {
    final isTeacher = _isTeacherForSession(session);
    final sessionReviewState = currentUserReviewState(
      session,
      isTeacher: isTeacher,
    );
    final hasReviewed =
        _model.hasReviewedOverride ?? sessionReviewState.hasReviewed;
    final reviewRef = _model.reviewRefOverride ?? sessionReviewState.reviewRef;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(10.0, 0.0, 10.0, 0.0),
          child: Text(
            FFLocalizations.of(context).getVariableText(
              ruText: hasReviewed ? 'Отзыв оставлен' : 'Оставить отзыв',
              enText: hasReviewed ? 'Review submitted' : 'Leave feedback',
            ),
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'Cool',
                  fontSize: 24.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.normal,
                ),
          ),
        ),
        const SizedBox(height: 12.0),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(10.0, 0.0, 10.0, 0.0),
          child: hasReviewed
              ? (reviewRef != null
                  ? _buildStoredReview(context, reviewRef: reviewRef)
                  : _buildSubmittedReviewFallback(context))
              : _buildReviewForm(context, session),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videoDocRef == null) {
      return Scaffold(
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        body: Center(
          child: Text(
            FFLocalizations.of(context).getVariableText(
              ruText: 'Не удалось открыть звонок',
              enText: 'Unable to open call',
            ),
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'sf pro display',
                  fontSize: 16.0,
                  letterSpacing: 0.0,
                ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        body: AuthUserStreamWidget(
          builder: (context) => StreamBuilder<VideoSessionsRecord>(
            stream: VideoSessionsRecord.getDocument(widget.videoDocRef!),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return _buildLoadingState(context);
              }

              final session = snapshot.data!;
              final isTeacher = _isTeacherForSession(session);
              final startedAtLabel = formatSessionStartedAt(context, session);
              final durationLabel = formatDurationLabel(
                context,
                resolveSessionDurationSeconds(session),
              );

              return Stack(
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                        6.0, 0.0, 6.0, 0.0),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 115.0),
                          _buildParticipantCard(context, session),
                          const SizedBox(height: 12.0),
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context)
                                  .primaryBackground,
                              borderRadius: BorderRadius.circular(26.0),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildInfoRow(
                                    context,
                                    label: FFLocalizations.of(context)
                                        .getVariableText(
                                      ruText: 'Дата и время',
                                      enText: 'Date and time',
                                    ),
                                    value: _buildValueText(
                                        context, startedAtLabel),
                                  ),
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 12.0),
                                    child: Divider(height: 1.0),
                                  ),
                                  _buildInfoRow(
                                    context,
                                    label: FFLocalizations.of(context)
                                        .getVariableText(
                                      ruText: 'Длительность',
                                      enText: 'Duration',
                                    ),
                                    value:
                                        _buildValueText(context, durationLabel),
                                  ),
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 12.0),
                                    child: Divider(height: 1.0),
                                  ),
                                  _buildInfoRow(
                                    context,
                                    label: FFLocalizations.of(context)
                                        .getVariableText(
                                      ruText:
                                          isTeacher ? 'Заработок' : 'Стоимость',
                                      enText: isTeacher ? 'Earnings' : 'Cost',
                                    ),
                                    value: _buildAmountValue(context, session),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24.0),
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                10.0, 0.0, 10.0, 0.0),
                            child: Text(
                              FFLocalizations.of(context).getVariableText(
                                ruText: 'Логи',
                                enText: 'Logs',
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'Cool',
                                    fontSize: 24.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 12.0),
                          _buildCaptionLogsSection(context, session),
                          const SizedBox(height: 20.0),
                          _buildReviewSection(context, session),
                          const SizedBox(height: 120.0),
                        ],
                      ),
                    ),
                  ),
                  _buildHeader(context),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
