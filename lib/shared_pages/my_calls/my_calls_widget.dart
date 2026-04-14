import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/empty/empty_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/user_match_profile.dart';
import '/shared_pages/call_details/call_details_widget.dart';
import '/shared_pages/call_history/call_history_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'my_calls_model.dart';
export 'my_calls_model.dart';

class MyCallsWidget extends StatefulWidget {
  const MyCallsWidget({super.key});

  static String routeName = 'myCalls';
  static String routePath = '/myCalls';

  @override
  State<MyCallsWidget> createState() => _MyCallsWidgetState();
}

class _MyCallsWidgetState extends State<MyCallsWidget> {
  late MyCallsModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  bool get _isTeacher => canAccessTeacherSurfaces(currentUserDocument);

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MyCallsModel());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
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
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
              ),
            ),
            Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Мои звонки',
                enText: 'My calls',
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
        body: AuthUserStreamWidget(
          builder: (context) {
            if (currentUserUid.isEmpty || currentUserDocument == null) {
              return _buildLoadingState(context);
            }

            final userField = _isTeacher ? 'tutorId' : 'studentId';

            return Stack(
              children: [
                Padding(
                  padding:
                      const EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 6.0, 0.0),
                  child: StreamBuilder<List<VideoSessionsRecord>>(
                    stream: queryVideoSessionsRecord(
                      queryBuilder: (videoSessionsRecord) =>
                          videoSessionsRecord.where(
                        userField,
                        isEqualTo: currentUserUid,
                      ),
                    ),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return _buildLoadingState(context);
                      }

                      final sessions = snapshot.data!
                          .where((session) => session.status == 'ended')
                          .toList()
                        ..sort(compareSessionsByStartedAtDesc);

                      if (sessions.isEmpty) {
                        return Center(
                          child: SizedBox(
                            height: 500.0,
                            child: EmptyWidget(
                              txt: FFLocalizations.of(context).getVariableText(
                                ruText:
                                    'Здесь появится история ваших завершенных звонков. После первого разговора вы сможете быстро вернуться к нему из этого раздела.',
                                enText:
                                    'Your completed call history will appear here. After your first conversation, you will be able to return to it from this section.',
                              ),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          0.0,
                          115.0,
                          0.0,
                          120.0,
                        ),
                        itemCount: sessions.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 6.0),
                        itemBuilder: (context, index) {
                          return _CallHistoryCard(
                            session: sessions[index],
                            isTeacher: _isTeacher,
                          );
                        },
                      );
                    },
                  ),
                ),
                _buildHeader(context),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CallHistoryCard extends StatelessWidget {
  const _CallHistoryCard({
    required this.session,
    required this.isTeacher,
  });

  final VideoSessionsRecord session;
  final bool isTeacher;

  String _formatStartedAtForCard(BuildContext context) {
    return formatSessionStartedAtForCard(context, session);
  }

  String _displayName(BuildContext context) {
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

  String _photoUrl() =>
      (isTeacher ? session.studentInfo.photo : session.tutorInfo.photo).trim();

  Widget _buildAvatar(BuildContext context) {
    final photoUrl = _photoUrl();
    final displayName = _displayName(context);

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

  @override
  Widget build(BuildContext context) {
    final durationLabel = formatDurationLabel(
      context,
      resolveSessionDurationSeconds(session),
    );
    final startedAtLabel = _formatStartedAtForCard(context);

    return InkWell(
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () async {
        context.pushNamed(
          CallDetailsWidget.routeName,
          queryParameters: {
            'videoDocRef': serializeParam(
              session.reference,
              ParamType.DocumentReference,
            ),
          }.withoutNulls,
        );
      },
      child: Container(
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
              _buildAvatar(context),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsetsDirectional.fromSTEB(12.0, 0.0, 0.0, 0.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayName(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'sf pro display',
                              fontSize: 16.0,
                              letterSpacing: 0.0,
                            ),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            0.0, 2.0, 0.0, 0.0),
                        child: Text(
                          '$startedAtLabel • $durationLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                fontFamily: 'sf pro display',
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                fontSize: 12.0,
                                letterSpacing: 0.0,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(8.0, 0.0, 8.0, 0.0),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: FlutterFlowTheme.of(context).secondaryText,
                  size: 20.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
