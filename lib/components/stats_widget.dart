import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/bottom_sheet_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';
import 'stats_model.dart';
export 'stats_model.dart';

class StatsWidget extends StatefulWidget {
  const StatsWidget({super.key});

  @override
  State<StatsWidget> createState() => _StatsWidgetState();
}

class _StatsWidgetState extends State<StatsWidget> {
  late StatsModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => StatsModel());
    _model.statsStream = queryStatsRecord(
      parent: currentUserReference,
      queryBuilder: (statsRecord) => statsRecord.where(
        'isAllTime',
        isEqualTo: true,
      ),
      singleRecord: true,
    );
    _model.wordsCountFuture = queryUserWordsRecordCount(
      parent: currentUserReference,
    );
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(ExpatlioDesign.space0,
          ExpatlioDesign.space0, ExpatlioDesign.space0, ExpatlioDesign.space0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            decoration: ExpatlioDesign.sheetDecoration(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                BottomSheetHeader(
                  title: FFLocalizations.of(context).getText(
                    'h312ck10' /* Статистика */,
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                      ExpatlioDesign.space8,
                      ExpatlioDesign.space16,
                      ExpatlioDesign.space8,
                      ExpatlioDesign.space0),
                  child: StreamBuilder<List<StatsRecord>>(
                    stream: _model.statsStream,
                    builder: (context, snapshot) {
                      List<StatsRecord> containerStatsRecordList =
                          snapshot.data ?? [];
                      final containerStatsRecord =
                          containerStatsRecordList.isNotEmpty
                              ? containerStatsRecordList.first
                              : null;

                      return Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: ExpatlioDesign.card,
                          borderRadius: BorderRadius.circular(
                              ExpatlioDesign.radiusExtraLarge),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(ExpatlioDesign.space16),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Builder(
                                    builder: (context) {
                                      if (currentUserDocument?.role ==
                                          UserRole.student) {
                                        return FutureBuilder<int>(
                                          future: _model.wordsCountFuture,
                                          builder: (context, snapshot) {
                                            int containerCount =
                                                snapshot.data ?? 0;

                                            return Container(
                                              decoration: BoxDecoration(),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.max,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    valueOrDefault<String>(
                                                      containerCount.toString(),
                                                      '0',
                                                    ),
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily: 'Cool',
                                                          fontSize: 34.0,
                                                          letterSpacing: 0.0,
                                                        ),
                                                  ),
                                                  Text(
                                                    FFLocalizations.of(context)
                                                        .getText(
                                                      'gjvp0dj5' /* Слов добавлено */,
                                                    ),
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryText,
                                                          fontSize: 15.0,
                                                          letterSpacing: 0.0,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        );
                                      } else {
                                        return Column(
                                          mainAxisSize: MainAxisSize.max,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              valueOrDefault<String>(
                                                containerStatsRecord
                                                    ?.totalEarned
                                                    .toString(),
                                                '0',
                                              ),
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily: 'Cool',
                                                        fontSize: 34.0,
                                                        letterSpacing: 0.0,
                                                      ),
                                            ),
                                            Text(
                                              FFLocalizations.of(context)
                                                  .getText(
                                                'aqgjojma' /* Заработано */,
                                              ),
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        fontSize: 15.0,
                                                        letterSpacing: 0.0,
                                                      ),
                                            ),
                                          ],
                                        );
                                      }
                                    },
                                  ),
                                  Container(
                                    width: 64.0,
                                    height: 64.0,
                                    decoration: BoxDecoration(
                                      image: DecorationImage(
                                        fit: BoxFit.cover,
                                        image: Image.asset(
                                          'assets/images/Frame_22.png',
                                        ).image,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                          ExpatlioDesign.radiusMedium),
                                      border: Border.all(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    mainAxisSize: MainAxisSize.max,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        valueOrDefault<String>(
                                          containerStatsRecord?.totalCalls
                                              .toString(),
                                          '0',
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'Cool',
                                              fontSize: 34.0,
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                      Text(
                                        FFLocalizations.of(context).getText(
                                          'f5hs0e1o' /* Звонков всего */,
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                              fontSize: 15.0,
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    width: 64.0,
                                    height: 64.0,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                          ExpatlioDesign.radiusMedium),
                                      border: Border.all(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                      ),
                                    ),
                                    child: Icon(
                                      FFIcons.kphone,
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      size: 20.0,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    mainAxisSize: MainAxisSize.max,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        valueOrDefault<String>(
                                          containerStatsRecord?.totalMinutes
                                              .toString(),
                                          '0',
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'Cool',
                                              fontSize: 34.0,
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                      Text(
                                        FFLocalizations.of(context).getText(
                                          'abrmh1eb' /* Минут в разговоре */,
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                              fontSize: 15.0,
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    width: 64.0,
                                    height: 64.0,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                          ExpatlioDesign.radiusMedium),
                                      border: Border.all(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                      ),
                                    ),
                                    child: Icon(
                                      FFIcons.kclock,
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      size: 20.0,
                                    ),
                                  ),
                                ],
                              ),
                            ].divide(SizedBox(height: ExpatlioDesign.space16)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                BottomSheetPrimaryButton(
                  text: FFLocalizations.of(context).getVariableText(
                    ruText: 'Готово',
                    enText: 'Done',
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
