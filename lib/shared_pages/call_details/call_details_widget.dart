import '/auth/firebase_auth/auth_util.dart';
import '/authorization/components/language_card/language_card_widget.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/button/button_widget.dart';
import '/components/review_card/review_card_widget.dart';
import '/flutter_flow/custom_functions.dart' as functions;
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/call_history/call_history_utils.dart';
import '/shared_pages/review_flow/review_submission_helper.dart';
import '/students_pages/components/new_word/new_word_widget.dart';
import '/students_pages/components/woed/woed_widget.dart';
import '/students_pages/components/fav/fav_widget.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:webviewx_plus/webviewx_plus.dart';
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
    if (currentUserReference == null) {
      return null;
    }

    return _transactionsFuture ??= queryTransactionsRecordOnce(
      queryBuilder: (transactionsRecord) => transactionsRecord.where(
        'userId',
        isEqualTo: currentUserReference,
      ),
    );
  }

  String _normalizeLanguageCode(String? code) {
    return (code ?? '').trim().toLowerCase().replaceAll('_', '-');
  }

  LanguageStruct? _findLanguageByCode(String? code) {
    final normalizedCode = _normalizeLanguageCode(code);
    if (normalizedCode.isEmpty) {
      return null;
    }

    final fallbackCodes = <String>{
      normalizedCode,
      normalizedCode.split('-').first,
    };

    for (final language in FFAppState().languagesList) {
      final normalizedCandidates = <String>{
        _normalizeLanguageCode(language.code),
        ...language.alternateCodes.map(_normalizeLanguageCode),
      }..removeWhere((value) => value.isEmpty);

      if (normalizedCandidates.any(fallbackCodes.contains)) {
        return language;
      }
    }

    return null;
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
        color: FlutterFlowTheme.of(context).primaryBackground,
        borderRadius: BorderRadius.circular(26.0),
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
            color: FlutterFlowTheme.of(context).secondaryText,
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
        return WebViewAware(
          child: GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: Padding(
              padding: MediaQuery.viewInsetsOf(context),
              child: existingWord != null
                  ? WoedWidget(
                      word: existingWord,
                    )
                  : NewWordWidget(
                      word: selectedWord,
                      langCode: session.language,
                      sentence: log.text,
                    ),
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
    final timestampLabel = _captionLogTimestampLabel(context, log);
    final textStyle = FlutterFlowTheme.of(context)
        .bodyMedium
        .override(
          fontFamily: 'sf pro display',
          fontSize: 15.0,
          letterSpacing: 0.0,
        )
        .copyWith(height: 1.35);

    return Container(
      key: ValueKey(log.reference.path),
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
            _InteractiveCaptionLogText(
              text: log.text,
              style: textStyle,
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
    final backgroundColor = FlutterFlowTheme.of(context).primaryBackground;

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

        return _buildCaptionLogsCardShell(
          context,
          child: logs.isEmpty
              ? _buildCaptionLogsMessage(
                  context,
                  message: FFLocalizations.of(context).getVariableText(
                    ruText: 'Логи субтитров для этого звонка пока недоступны.',
                    enText:
                        'Subtitle logs for this call are not available yet.',
                  ),
                )
              : isExpanded
                  ? Column(
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
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildCaptionLogsItemsColumn(
                          context,
                          session,
                          canCollapse
                              ? logs
                                  .take(_collapsedCaptionLogsVisibleCount)
                                  .toList()
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

  DocumentReference? _tutorReference(VideoSessionsRecord session) {
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

  bool _transactionMatchesCurrentSession(
    TransactionsRecord transaction, {
    required bool preferReferenceMatch,
  }) {
    final sessionRef = widget.videoDocRef;
    if (sessionRef == null) {
      return false;
    }

    if (preferReferenceMatch) {
      return transaction.sessionDocRef?.path == sessionRef.path;
    }

    final transactionSessionId =
        (transaction.snapshotData['sessionId']?.toString() ?? '').trim();
    return transactionSessionId.isNotEmpty &&
        transactionSessionId == sessionRef.id;
  }

  TransactionsRecord? _callTransactionForSession(
    List<TransactionsRecord> transactions, {
    required bool isTeacher,
  }) {
    final targetType =
        isTeacher ? TypeTransactions.earning : TypeTransactions.call_charge;
    TransactionsRecord? fallbackMatch;

    for (final transaction in transactions) {
      if (transaction.type != targetType) {
        continue;
      }

      if (_transactionMatchesCurrentSession(
        transaction,
        preferReferenceMatch: true,
      )) {
        return transaction;
      }

      if (fallbackMatch == null &&
          _transactionMatchesCurrentSession(
            transaction,
            preferReferenceMatch: false,
          )) {
        fallbackMatch = transaction;
      }
    }

    return fallbackMatch;
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required String label,
    required Widget value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
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
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      textAlign: TextAlign.end,
      style: FlutterFlowTheme.of(context).bodyMedium.override(
            fontFamily: 'sf pro display',
            fontSize: 15.0,
            letterSpacing: 0.0,
            fontWeight: FontWeight.w500,
          ),
    );
  }

  String _formatRubTransactionAmount(double? amount) {
    if (amount == null) {
      return '-';
    }

    return '${NumberFormat('0.##').format(amount)} ₽';
  }

  String _amountLabelForTransaction(
    TransactionsRecord? transaction, {
    required bool isTeacher,
  }) {
    if (transaction == null) {
      return '-';
    }

    if (isTeacher) {
      return transaction.hasAmount()
          ? _formatRubTransactionAmount(transaction.amount)
          : '-';
    }

    return transaction.hasAmountST()
        ? formatStAmount(transaction.amountST)
        : '-';
  }

  Widget _buildAmountValue(BuildContext context, VideoSessionsRecord session) {
    final isTeacher = _isTeacherForSession(session);
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
          _amountLabelForTransaction(
            _callTransactionForSession(
              snapshot.data!,
              isTeacher: isTeacher,
            ),
            isTeacher: isTeacher,
          ),
        );
      },
    );
  }

  Widget _buildCallInfoCard(
    BuildContext context,
    VideoSessionsRecord session, {
    required String startedAtLabel,
    required String durationLabel,
  }) {
    final isTeacher = _isTeacherForSession(session);

    return Container(
      height: 177.5,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
        borderRadius: BorderRadius.circular(26.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: _buildInfoRow(
                  context,
                  label: FFLocalizations.of(context).getVariableText(
                    ruText: 'Дата и время',
                    enText: 'Date and time',
                  ),
                  value: _buildValueText(context, startedAtLabel),
                ),
              ),
            ),
            const Divider(height: 1.0),
            Expanded(
              child: Center(
                child: _buildInfoRow(
                  context,
                  label: FFLocalizations.of(context).getVariableText(
                    ruText: 'Длительность',
                    enText: 'Duration',
                  ),
                  value: _buildValueText(context, durationLabel),
                ),
              ),
            ),
            const Divider(height: 1.0),
            Expanded(
              child: Center(
                child: _buildInfoRow(
                  context,
                  label: FFLocalizations.of(context).getVariableText(
                    ruText: isTeacher ? 'Заработок' : 'Стоимость',
                    enText: isTeacher ? 'Earnings' : 'Cost',
                  ),
                  value: _buildAmountValue(context, session),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSection(
    BuildContext context, {
    required LanguageStruct language,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(10.0, 0.0, 10.0, 0.0),
          child: Text(
            FFLocalizations.of(context).getVariableText(
              ruText: 'Язык',
              enText: 'Language',
            ),
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'Cool',
                  fontSize: 24.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.normal,
                ),
          ),
        ),
        const SizedBox(height: 10.0),
        LanguageCardWidget(
          lang: language,
          currentSelected: null,
          callbackAction: (_) async {},
        ),
      ],
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
      keyboardAwarePadding: false,
      padding: EdgeInsets.zero,
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
            color: FlutterFlowTheme.of(context).primaryBackground,
            borderRadius: BorderRadius.circular(26.0),
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
            fillColor: FlutterFlowTheme.of(context).primaryBackground,
            contentPadding: const EdgeInsets.all(16.0),
            hoverColor: FlutterFlowTheme.of(context).primaryBackground,
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
              final tutorReference = _tutorReference(session);
              final sessionLanguage = _findLanguageByCode(session.language);
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (tutorReference != null) ...[
                                SizedBox(
                                  height: 177.5,
                                  child: FavWidget(
                                    nsUser: tutorReference,
                                    enableNavigation: !isTeacher,
                                  ),
                                ),
                                const SizedBox(width: 6.0),
                              ],
                              Expanded(
                                child: _buildCallInfoCard(
                                  context,
                                  session,
                                  startedAtLabel: startedAtLabel,
                                  durationLabel: durationLabel,
                                ),
                              ),
                            ],
                          ),
                          if (sessionLanguage != null) ...[
                            const SizedBox(height: 24.0),
                            _buildLanguageSection(
                              context,
                              language: sessionLanguage,
                            ),
                          ],
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

class _InteractiveCaptionLogText extends StatefulWidget {
  const _InteractiveCaptionLogText({
    required this.text,
    required this.style,
    required this.onWordTap,
  });

  final String text;
  final TextStyle style;
  final Future<void> Function(String word) onWordTap;

  @override
  State<_InteractiveCaptionLogText> createState() =>
      _InteractiveCaptionLogTextState();
}

class _InteractiveCaptionLogTextState
    extends State<_InteractiveCaptionLogText> {
  static final RegExp _wordPattern = RegExp(
    r"[A-Za-zА-Яа-яЁёÀ-ÖØ-öø-ÿ0-9]+(?:['’`-][A-Za-zА-Яа-яЁёÀ-ÖØ-öø-ÿ0-9]+)*",
  );

  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  List<InlineSpan> _buildSpans() {
    _disposeRecognizers();

    final spans = <InlineSpan>[];
    var currentIndex = 0;
    final matches = _wordPattern.allMatches(widget.text);

    for (final match in matches) {
      if (match.start > currentIndex) {
        spans.add(
          TextSpan(
            text: widget.text.substring(currentIndex, match.start),
          ),
        );
      }

      final word = match.group(0);
      if (word != null && word.isNotEmpty) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            widget.onWordTap(word);
          };
        _recognizers.add(recognizer);
        spans.add(
          TextSpan(
            text: word,
            recognizer: recognizer,
          ),
        );
      }

      currentIndex = match.end;
    }

    if (currentIndex < widget.text.length) {
      spans.add(
        TextSpan(
          text: widget.text.substring(currentIndex),
        ),
      );
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: widget.text));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: widget.style,
        children: _buildSpans(),
      ),
    );
  }
}
