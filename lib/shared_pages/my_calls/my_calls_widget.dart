import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/app_loading_indicator.dart';
import '/components/call_history_card.dart';
import '/components/empty/empty_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/user_match_profile.dart';
import '/shared_pages/call_history/call_history_utils.dart';
import '/components/basic_page_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';
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
    return const Center(
      child: AppLoadingIndicator(),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return BasicPageHeader(
      title: FFLocalizations.of(context).getVariableText(
        ruText: 'Мои звонки',
        enText: 'My calls',
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
        backgroundColor: ExpatlioDesign.background,
        body: AuthUserStreamWidget(
          builder: (context) {
            if (currentUserUid.isEmpty || currentUserDocument == null) {
              return _buildLoadingState(context);
            }

            final userField = _isTeacher ? 'tutorId' : 'studentId';
            final contentTopPadding = MediaQuery.paddingOf(context).top +
                BasicPageHeader.height +
                ExpatlioDesign.sectionSpacing;

            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    ExpatlioDesign.pagePadding,
                    ExpatlioDesign.space0,
                    ExpatlioDesign.pagePadding,
                    ExpatlioDesign.space0,
                  ),
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
                        padding: EdgeInsets.fromLTRB(
                          ExpatlioDesign.space0,
                          contentTopPadding,
                          ExpatlioDesign.space0,
                          ExpatlioDesign.pageBottomSpacing,
                        ),
                        itemCount: sessions.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: ExpatlioDesign.space0),
                        itemBuilder: (context, index) {
                          return CallHistoryCard(
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
