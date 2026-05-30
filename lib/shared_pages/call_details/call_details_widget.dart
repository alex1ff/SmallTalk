import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/button/button_widget.dart';
import '/components/pair_review_content.dart';
import '/components/participant_avatar.dart';
import '/components/review_card/review_card_widget.dart';
import '/flutter_flow/custom_functions.dart' as functions;
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/shared_pages/call_history/call_language_utils.dart';
import '/shared_pages/call_history/call_history_utils.dart';
import '/shared_pages/learning/caption_word_flow.dart';
import '/components/interactive_caption_text.dart';
import '/shared_pages/review_flow/review_submission_helper.dart';
import '/services/user_match_profile.dart';
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
  static const int _collapsedCaptionLogsVisibleCount = 5;
  static const double _collapsedCaptionLogPeekFactor = 0.6;
  static const double _headerHeight = 58.0;

  late CallDetailsModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  bool get _isTeacher => canAccessTeacherSurfaces(currentUserDocument);

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

  SessionReviewParticipantResolution _participantResolution(
    VideoSessionsRecord session,
  ) {
    return resolveSessionReviewParticipant(
      sessionData: session.snapshotData,
      currentUserId: currentUserUid,
    );
  }

  Map<String, dynamic> _sessionMatchContext(VideoSessionsRecord session) {
    final rawMatchContext = session.snapshotData['matchContext'];
    if (rawMatchContext is Map) {
      return rawMatchContext.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }

    return const <String, dynamic>{};
  }

  String _acceptedResponderName(VideoSessionsRecord session) {
    final matchContext = _sessionMatchContext(session);
    final acceptedResponderInfo = matchContext['acceptedResponderInfo'];
    if (acceptedResponderInfo is! Map) {
      return '';
    }

    return (acceptedResponderInfo['name'] as String? ?? '').trim();
  }

  String _acceptedResponderPhotoUrl(VideoSessionsRecord session) {
    final matchContext = _sessionMatchContext(session);
    final acceptedResponderInfo = matchContext['acceptedResponderInfo'];
    if (acceptedResponderInfo is! Map) {
      return '';
    }

    return (acceptedResponderInfo['photo'] as String? ?? '').trim();
  }

  bool _isTeacherForSession(VideoSessionsRecord session) {
    final resolution = _participantResolution(session);
    if (resolution.isResponder) {
      return true;
    }
    if (resolution.isRequester) {
      return false;
    }

    return _isTeacher;
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

  Widget _buildUnavailableCallContent(BuildContext context) {
    return Center(
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
    );
  }

  Widget _buildUnavailableCallState(BuildContext context) {
    return Scaffold(
      backgroundColor: ExpatlioDesign.background,
      body: _buildUnavailableCallContent(context),
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

  Stream<QuerySnapshot<Map<String, dynamic>>> _captionLogsStream(
    VideoSessionsRecord session,
  ) {
    return session.reference.collection('captionLogs').snapshots();
  }

  List<CaptionLogsRecord> _captionLogsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final logs = <CaptionLogsRecord>[];
    for (final doc in snapshot.docs) {
      try {
        logs.add(
          CaptionLogsRecord.getDocumentFromData(
            doc.data(),
            doc.reference,
          ),
        );
      } catch (error) {
        debugPrint(
          'Failed to parse caption log ${doc.reference.path}: $error',
        );
      }
    }
    return logs;
  }

  Widget _buildCaptionLogsCardShell(
    BuildContext context, {
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ExpatlioDesign.card,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: child,
      ),
    );
  }

  Widget _buildCaptionLogsMessage(
    BuildContext context, {
    required String message,
  }) {
    return Text(
      message,
      style: FlutterFlowTheme.of(context)
          .bodyMedium
          .override(
            fontFamily: 'sf pro display',
            color: ExpatlioDesign.muted,
            fontSize: 14.0,
            letterSpacing: 0.0,
          )
          .copyWith(height: 1.4),
    );
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

  bool _isCurrentUserCaptionLog(CaptionLogsRecord log) =>
      log.speakerId.trim().isNotEmpty && log.speakerId.trim() == currentUserUid;

  String _captionLogTimestampLabel(
    BuildContext context,
    VideoSessionsRecord session,
    CaptionLogsRecord log,
  ) {
    final timestamp = _captionLogTimestamp(log);
    if (timestamp == null) {
      return '';
    }

    final startedAt = resolveSessionStartedAt(session);
    if (startedAt != null && !timestamp.isBefore(startedAt)) {
      final elapsedSeconds = timestamp.difference(startedAt).inSeconds;
      final minutes = elapsedSeconds ~/ 60;
      final seconds = elapsedSeconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return dateTimeFormat(
      'Hm',
      timestamp,
      locale: FFLocalizations.of(context).languageCode,
    );
  }

  String? _normalizeDictionaryLookupText(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  Future<UserWordsRecord?> _existingDictionaryWord(String word) async {
    final userRef = currentUserReference;
    final normalizedWord = _normalizeDictionaryLookupText(word);
    if (userRef == null || normalizedWord == null) {
      return null;
    }

    final userWords = await queryUserWordsRecordOnce(parent: userRef);
    for (final userWord in userWords) {
      final entryText = _normalizeDictionaryLookupText(
        userWord.entry.firstOrNull?.text,
      );
      if (entryText == normalizedWord) {
        return userWord;
      }
    }

    return null;
  }

  Future<void> _openCaptionLogWordSheet(
    BuildContext context, {
    required VideoSessionsRecord session,
    required CaptionLogsRecord log,
    required String word,
  }) async {
    final selectedWord = word.trim();
    if (selectedWord.isEmpty) {
      return;
    }

    final existingWord = await _existingDictionaryWord(selectedWord);
    if (!mounted) {
      return;
    }

    await showModalBottomSheet(
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) {
        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Padding(
            padding: MediaQuery.viewInsetsOf(context),
            child: buildSavedCaptionWordSheet(
              existingWord: existingWord,
              word: selectedWord,
              languageCode: session.language,
              sentence: log.text,
            ),
          ),
        );
      },
    ).then((value) => safeSetState(() {}));
  }

  Widget _buildCaptionLogItem(
    BuildContext context,
    VideoSessionsRecord session,
    CaptionLogsRecord log,
  ) {
    final timestampLabel = _captionLogTimestampLabel(context, session, log);
    final isCurrentUser = _isCurrentUserCaptionLog(log);
    final speakerLabel = _captionLogSpeakerLabel(context, log);
    final bubbleColor = isCurrentUser
        ? ExpatlioDesign.primary.withValues(alpha: 0.12)
        : ExpatlioDesign.card;
    final speakerColor =
        isCurrentUser ? ExpatlioDesign.primary : ExpatlioDesign.text;

    return Align(
      key: ValueKey(log.reference.path),
      alignment: isCurrentUser
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: FractionallySizedBox(
        widthFactor: 0.82,
        child: Container(
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadiusDirectional.only(
              topStart: const Radius.circular(14.0),
              topEnd: const Radius.circular(14.0),
              bottomStart: Radius.circular(isCurrentUser ? 14.0 : 4.0),
              bottomEnd: Radius.circular(isCurrentUser ? 4.0 : 14.0),
            ),
          ),
          child: Padding(
            padding:
                const EdgeInsetsDirectional.fromSTEB(14.0, 10.0, 14.0, 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        speakerLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'sf pro display',
                              color: speakerColor,
                              fontSize: 12.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    if (timestampLabel.isNotEmpty) ...[
                      const SizedBox(width: 8.0),
                      Text(
                        timestampLabel,
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'sf pro display',
                              color: ExpatlioDesign.muted,
                              fontSize: 12.0,
                              letterSpacing: 0.0,
                            ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6.0),
                InteractiveCaptionText(
                  text: log.text,
                  mode: InteractiveCaptionTextMode.wordScan,
                  onWordTap: (word) => _openCaptionLogWordSheet(
                    context,
                    session: session,
                    log: log,
                    word: word,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _setCaptionLogsExpanded(bool isExpanded) {
    if (_model.areCaptionLogsExpanded == isExpanded) {
      return;
    }

    _model.areCaptionLogsExpanded = isExpanded;
    safeSetState(() {});
  }

  String _captionLogsToggleLabel(
    BuildContext context, {
    required bool isExpanded,
  }) {
    return FFLocalizations.of(context).getVariableText(
      ruText: isExpanded ? 'Скрыть все' : 'Показать все',
      enText: isExpanded ? 'Hide all' : 'Show all',
    );
  }

  Widget _buildCaptionLogsToggleButton(
    BuildContext context, {
    required bool isExpanded,
  }) {
    final theme = FlutterFlowTheme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999.0),
        onTap: () => _setCaptionLogsExpanded(!isExpanded),
        child: Ink(
          decoration: BoxDecoration(
            color: theme.primaryBackground.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(999.0),
            border: Border.all(
              color: theme.primaryText.withValues(alpha: 0.08),
              width: 1.0,
            ),
            boxShadow: const [
              BoxShadow(
                blurRadius: 16.0,
                color: Color(0x1A000000),
                offset: Offset(0.0, 6.0),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 10.0,
            ),
            child: Text(
              _captionLogsToggleLabel(
                context,
                isExpanded: isExpanded,
              ),
              style: theme.bodyMedium.override(
                fontFamily: 'sf pro display',
                fontSize: 14.0,
                letterSpacing: 0.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCaptionLogsItemsColumn(
    BuildContext context,
    VideoSessionsRecord session,
    List<CaptionLogsRecord> logs,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < logs.length; index++) ...[
          _buildCaptionLogItem(context, session, logs[index]),
          if (index < logs.length - 1) const SizedBox(height: 12.0),
        ],
      ],
    );
  }

  Widget _buildCollapsedCaptionLogPeek(
    BuildContext context,
    VideoSessionsRecord session,
    CaptionLogsRecord log,
  ) {
    const backgroundColor = ExpatlioDesign.background;

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: _collapsedCaptionLogPeekFactor,
            child: _buildCaptionLogItem(context, session, log),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    backgroundColor.withValues(alpha: 0.0),
                    backgroundColor.withValues(alpha: 0.76),
                    backgroundColor,
                  ],
                  stops: const [0.0, 0.68, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 12.0,
          child: _buildCaptionLogsToggleButton(
            context,
            isExpanded: false,
          ),
        ),
      ],
    );
  }

  Widget _buildCaptionLogsSection(
    BuildContext context,
    VideoSessionsRecord session,
  ) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _captionLogsStream(session),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint(
            'Caption logs stream failed for ${session.reference.path}: ${snapshot.error}',
          );
          return _buildCaptionLogsCardShell(
            context,
            child: _buildCaptionLogsMessage(
              context,
              message: FFLocalizations.of(context).getVariableText(
                ruText:
                    'Не удалось загрузить логи субтитров. Попробуйте открыть страницу еще раз.',
                enText:
                    'Unable to load subtitle logs right now. Please try opening the page again.',
              ),
            ),
          );
        }

        final querySnapshot = snapshot.data;
        if (querySnapshot == null) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildCaptionLogsCardShell(
              context,
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: _buildLoadingState(context),
              ),
            );
          }

          return _buildCaptionLogsCardShell(
            context,
            child: _buildCaptionLogsMessage(
              context,
              message: FFLocalizations.of(context).getVariableText(
                ruText: 'Логи субтитров для этого звонка пока недоступны.',
                enText: 'Subtitle logs for this call are not available yet.',
              ),
            ),
          );
        }

        final logs = _sortedCaptionLogs(
          _captionLogsFromSnapshot(querySnapshot),
        );
        final canCollapse = logs.length > _collapsedCaptionLogsVisibleCount;
        final isExpanded = canCollapse && _model.areCaptionLogsExpanded;

        if (logs.isEmpty) {
          return _buildCaptionLogsCardShell(
            context,
            child: _buildCaptionLogsMessage(
              context,
              message: FFLocalizations.of(context).getVariableText(
                ruText: 'Логи субтитров для этого звонка пока недоступны.',
                enText: 'Subtitle logs for this call are not available yet.',
              ),
            ),
          );
        }

        if (isExpanded) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCaptionLogsItemsColumn(
                context,
                session,
                logs,
              ),
              if (canCollapse) ...[
                const SizedBox(height: 12.0),
                Align(
                  alignment: Alignment.center,
                  child: _buildCaptionLogsToggleButton(
                    context,
                    isExpanded: true,
                  ),
                ),
              ],
            ],
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCaptionLogsItemsColumn(
              context,
              session,
              canCollapse
                  ? logs.take(_collapsedCaptionLogsVisibleCount).toList()
                  : logs,
            ),
            if (canCollapse) ...[
              const SizedBox(height: 12.0),
              _buildCollapsedCaptionLogPeek(
                context,
                session,
                logs[_collapsedCaptionLogsVisibleCount],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, {required String subtitle}) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: ExpatlioDesign.background,
        border: Border(
          bottom: BorderSide(color: ExpatlioDesign.border, width: 1.0),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: _headerHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: ExpatlioDesign.compactSpacing,
                  ),
                  child: IconButton(
                    onPressed: () => context.safePop(),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: ExpatlioDesign.text,
                      size: 24.0,
                    ),
                    splashRadius: 22.0,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  72.0,
                  0.0,
                  72.0,
                  0.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      FFLocalizations.of(context).getVariableText(
                        ruText: 'Информация о звонке',
                        enText: 'Call information',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: ExpatlioDesign.pageHeaderTitleStyle(context),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: ExpatlioDesign.textStyle(
                        context,
                        color: ExpatlioDesign.muted,
                        size: 12.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DocumentReference? _counterpartReference(VideoSessionsRecord session) {
    final counterpartId = _participantResolution(session).counterpartUserId;
    if (counterpartId == null || counterpartId.isEmpty) {
      return null;
    }

    return functions.stringToRef(counterpartId);
  }

  DocumentReference? _reviewTargetReference(VideoSessionsRecord session) {
    return _counterpartReference(session);
  }

  String _counterpartName(BuildContext context, VideoSessionsRecord session) {
    final resolution = _participantResolution(session);
    final counterpartId = resolution.counterpartUserId;

    String rawName = '';
    if (resolution.isResponder ||
        (counterpartId != null && counterpartId == session.studentId.trim())) {
      rawName = session.studentInfo.name.trim();
    } else if (resolution.isRequester ||
        (counterpartId != null &&
            {
              session.tutorId.trim(),
              session.currentTutorId.trim(),
              resolveSessionResponderId(session.snapshotData) ?? '',
            }.contains(counterpartId))) {
      rawName = session.tutorInfo.name.trim();
      if (rawName.isEmpty) {
        rawName = _acceptedResponderName(session);
      }
    }

    if (rawName.isNotEmpty) {
      return rawName;
    }

    if (counterpartId != null && counterpartId.isNotEmpty) {
      return FFLocalizations.of(context).getVariableText(
        ruText: 'Собеседник',
        enText: 'Partner',
      );
    }

    return FFLocalizations.of(context).getVariableText(
      ruText: _isTeacherForSession(session) ? 'Студент' : 'Преподаватель',
      enText: _isTeacherForSession(session) ? 'Student' : 'Tutor',
    );
  }

  String _counterpartPhotoUrl(VideoSessionsRecord session) {
    final resolution = _participantResolution(session);
    final counterpartId = resolution.counterpartUserId;

    if (resolution.isResponder ||
        (counterpartId != null && counterpartId == session.studentId.trim())) {
      return session.studentInfo.photo.trim();
    }

    if (resolution.isRequester ||
        (counterpartId != null &&
            {
              session.tutorId.trim(),
              session.currentTutorId.trim(),
              resolveSessionResponderId(session.snapshotData) ?? '',
            }.contains(counterpartId))) {
      final tutorPhotoUrl = session.tutorInfo.photo.trim();
      return tutorPhotoUrl.isNotEmpty
          ? tutorPhotoUrl
          : _acceptedResponderPhotoUrl(session);
    }

    return '';
  }

  String _callDateLabel(BuildContext context, VideoSessionsRecord session) {
    final startedAt = resolveSessionStartedAt(session);
    if (startedAt == null) {
      return '-';
    }

    final localStartedAt = startedAt.toLocal();
    final today = DateTime.now();
    final startedDay = DateTime(
      localStartedAt.year,
      localStartedAt.month,
      localStartedAt.day,
    );
    final todayDay = DateTime(today.year, today.month, today.day);
    final differenceInDays = todayDay.difference(startedDay).inDays;

    if (differenceInDays == 0) {
      return FFLocalizations.of(context).getVariableText(
        ruText: 'Сегодня',
        enText: 'Today',
      );
    }
    if (differenceInDays == 1) {
      return FFLocalizations.of(context).getVariableText(
        ruText: 'Вчера',
        enText: 'Yesterday',
      );
    }

    return DateFormat('d MMM', FFLocalizations.of(context).languageCode)
        .format(localStartedAt);
  }

  String _callTimeLabel(BuildContext context, VideoSessionsRecord session) {
    final startedAt = resolveSessionStartedAt(session);
    if (startedAt == null) {
      return '-';
    }

    return dateTimeFormat(
      'Hm',
      startedAt,
      locale: FFLocalizations.of(context).languageCode,
    );
  }

  String _callDirectionLabel(
      BuildContext context, VideoSessionsRecord session) {
    final isOutgoing = session.studentId.trim() == currentUserUid;
    return FFLocalizations.of(context).getVariableText(
      ruText: isOutgoing ? 'Исходящий звонок' : 'Входящий звонок',
      enText: isOutgoing ? 'Outgoing call' : 'Incoming call',
    );
  }

  String _transcriptLanguageLabel(LanguageStruct? language) {
    final code = language?.code.trim();
    if (code != null && code.isNotEmpty) {
      return code.toUpperCase();
    }
    return 'EN';
  }

  Widget _buildCallMetricCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        height: 74.0,
        decoration: BoxDecoration(
          color: ExpatlioDesign.card,
          borderRadius: BorderRadius.circular(10.0),
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(8.0, 8.0, 8.0, 8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16.0,
              color: ExpatlioDesign.muted,
            ),
            const SizedBox(height: 4.0),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ExpatlioDesign.textStyle(
                context,
                color: ExpatlioDesign.muted,
                size: 11.0,
              ),
            ),
            const SizedBox(height: 2.0),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ExpatlioDesign.textStyle(
                context,
                size: 13.0,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallHero(
    BuildContext context,
    VideoSessionsRecord session, {
    required String counterpartName,
    required String counterpartPhotoUrl,
    required String durationLabel,
    required bool hasReviews,
    double? ratingAverage,
  }) {
    final semanticLabel = hasReviews && ratingAverage != null
        ? '$counterpartName, ${formatNumber(
            ratingAverage,
            formatType: FormatType.custom,
            format: '0.0',
            locale: '',
          )}'
        : counterpartName;

    return Semantics(
      label: semanticLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ParticipantAvatar(
            photoUrl: counterpartPhotoUrl,
            displayName: counterpartName,
          ),
          const SizedBox(height: 14.0),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 30.0),
            child: Text(
              counterpartName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: ExpatlioDesign.textStyle(
                context,
                size: 20.0,
                weight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 10.0),
          Container(
            decoration: BoxDecoration(
              color: ExpatlioDesign.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999.0),
            ),
            padding: const EdgeInsetsDirectional.fromSTEB(10.0, 5.0, 12.0, 5.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.phone_in_talk_outlined,
                  color: ExpatlioDesign.primary,
                  size: 14.0,
                ),
                const SizedBox(width: 5.0),
                Text(
                  _callDirectionLabel(context, session),
                  style: ExpatlioDesign.textStyle(
                    context,
                    color: ExpatlioDesign.primary,
                    size: 12.0,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22.0),
          Row(
            children: [
              _buildCallMetricCard(
                context,
                icon: Icons.calendar_today_outlined,
                label: FFLocalizations.of(context).getVariableText(
                  ruText: 'Дата',
                  enText: 'Date',
                ),
                value: _callDateLabel(context, session),
              ),
              const SizedBox(width: 12.0),
              _buildCallMetricCard(
                context,
                icon: Icons.access_time_rounded,
                label: FFLocalizations.of(context).getVariableText(
                  ruText: 'Время',
                  enText: 'Time',
                ),
                value: _callTimeLabel(context, session),
              ),
              const SizedBox(width: 12.0),
              _buildCallMetricCard(
                context,
                icon: Icons.schedule_rounded,
                label: FFLocalizations.of(context).getVariableText(
                  ruText: 'Длит.',
                  enText: 'Dur.',
                ),
                value: durationLabel,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCallHeroWithProfile(
    BuildContext context,
    VideoSessionsRecord session, {
    required String fallbackName,
    required String fallbackPhotoUrl,
    required String durationLabel,
  }) {
    final participantRef = _counterpartReference(session);
    if (participantRef == null) {
      return _buildCallHero(
        context,
        session,
        counterpartName: fallbackName,
        counterpartPhotoUrl: fallbackPhotoUrl,
        durationLabel: durationLabel,
        hasReviews: false,
      );
    }

    return StreamBuilder<DocumentSnapshot<Object?>>(
      stream: UserPublicProfilesRecord.collection
          .doc(participantRef.id)
          .snapshots(),
      builder: (context, snapshot) {
        final participantSnapshot = snapshot.data;
        final participant = participantSnapshot != null &&
                participantSnapshot.exists &&
                participantSnapshot.data() != null
            ? UserPublicProfilesRecord.fromSnapshot(participantSnapshot)
            : null;
        final profileName = participant?.displayName.trim() ?? '';
        final profilePhotoUrl = participant?.photoUrl.trim() ?? '';

        return _buildCallHero(
          context,
          session,
          counterpartName: profileName.isNotEmpty ? profileName : fallbackName,
          counterpartPhotoUrl:
              profilePhotoUrl.isNotEmpty ? profilePhotoUrl : fallbackPhotoUrl,
          durationLabel: durationLabel,
          hasReviews: (participant?.ratingCount ?? 0) > 0,
          ratingAverage: participant?.ratingAverage,
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

  Future<PairReviewState> _ensurePairReviewFuture(
    DocumentReference? targetUserRef,
  ) {
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
    return ButtonWidget(
      text: FFLocalizations.of(context).getVariableText(
        ruText: 'Оставить отзыв',
        enText: 'Submit review',
      ),
      loadingText: FFLocalizations.of(context).getVariableText(
        ruText: 'Отправляем отзыв...',
        enText: 'Sending review...',
      ),
      busyStyle: ButtonBusyStyle.spinner,
      action: () async {
        await _submitReview(context, session);
      },
    );
  }

  Widget _buildReviewForm(BuildContext context, VideoSessionsRecord session) {
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
            padding: const EdgeInsetsDirectional.fromSTEB(8.0, 28.0, 8.0, 28.0),
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
          decoration: ExpatlioDesign.formFieldDecoration(
            context,
            hintText: reviewCommentHintText(context, _model.rating),
            maxLines: 12,
          ),
          style: ExpatlioDesign.formTextStyle(context),
          maxLines: 12,
          minLines: 2,
          cursorColor: ExpatlioDesign.primary,
          enableInteractiveSelection: true,
          validator:
              _model.reviewCommentTextControllerValidator.asValidator(context),
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

  Widget _buildReviewSection(
    BuildContext context,
    VideoSessionsRecord session,
  ) {
    final targetUserRef = _reviewTargetReference(session);

    return FutureBuilder<PairReviewState>(
      future: _ensurePairReviewFuture(targetUserRef),
      builder: (context, snapshot) {
        final resolvedReviewRef =
            _model.reviewRefOverride ?? snapshot.data?.reviewRef;
        final hasReviewed =
            resolvedReviewRef != null || (snapshot.data?.hasReviewed ?? false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsetsDirectional.fromSTEB(10.0, 0.0, 10.0, 0.0),
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
              padding:
                  const EdgeInsetsDirectional.fromSTEB(10.0, 0.0, 10.0, 0.0),
              child: !snapshot.hasData && _model.reviewRefOverride == null
                  ? _buildLoadingState(context)
                  : PairReviewContent(
                      hasReviewed: hasReviewed,
                      reviewContent: resolvedReviewRef != null
                          ? _buildStoredReview(
                              context,
                              reviewRef: resolvedReviewRef,
                            )
                          : null,
                      reviewFallbackText: reviewAlreadyLeftMessage(context),
                      formContent: _buildReviewForm(context, session),
                    ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videoDocRef == null) {
      return _buildUnavailableCallState(context);
    }

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: ExpatlioDesign.background,
        body: AuthUserStreamWidget(
          builder: (context) => StreamBuilder<DocumentSnapshot<Object?>>(
            stream: widget.videoDocRef!.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint(
                  'CallDetailsWidget: failed to load ${widget.videoDocRef!.path}: ${snapshot.error}',
                );
                return _buildUnavailableCallContent(context);
              }

              if (!snapshot.hasData) {
                return _buildLoadingState(context);
              }

              final sessionDoc = snapshot.data!;
              if (!sessionDoc.exists || sessionDoc.data() == null) {
                return _buildUnavailableCallContent(context);
              }

              final session = VideoSessionsRecord.fromSnapshot(sessionDoc);
              final counterpartName = _counterpartName(context, session);
              final counterpartPhotoUrl = _counterpartPhotoUrl(session);
              final sessionLanguage = findSessionLanguageByCode(
                languages: FFAppState().languagesList,
                code: session.language,
              );
              final durationLabel = formatDurationLabel(
                context,
                resolveSessionDurationSeconds(session),
              );
              final contentTopPadding = MediaQuery.paddingOf(context).top +
                  _headerHeight +
                  ExpatlioDesign.sectionGap;

              return Stack(
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      ExpatlioDesign.pagePadding,
                      0.0,
                      ExpatlioDesign.pagePadding,
                      0.0,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: contentTopPadding),
                          _buildCallHeroWithProfile(
                            context,
                            session,
                            fallbackName: counterpartName,
                            fallbackPhotoUrl: counterpartPhotoUrl,
                            durationLabel: durationLabel,
                          ),
                          const SizedBox(height: 28.0),
                          Padding(
                            padding:
                                const EdgeInsetsDirectional.only(bottom: 14.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    FFLocalizations.of(context).getVariableText(
                                      ruText: 'Расшифровка разговора',
                                      enText: 'Conversation transcript',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: ExpatlioDesign.textStyle(
                                      context,
                                      size: 16.0,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  _transcriptLanguageLabel(sessionLanguage),
                                  style: ExpatlioDesign.textStyle(
                                    context,
                                    color: ExpatlioDesign.muted,
                                    size: 12.0,
                                    weight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildCaptionLogsSection(context, session),
                          const SizedBox(height: 22.0),
                          _buildReviewSection(context, session),
                          const SizedBox(height: 120.0),
                        ],
                      ),
                    ),
                  ),
                  _buildHeader(
                    context,
                    subtitle: counterpartName,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
