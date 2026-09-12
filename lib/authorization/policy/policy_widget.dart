import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/basic_page_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'policy_model.dart';
export 'policy_model.dart';

class PolicyWidget extends StatefulWidget {
  const PolicyWidget({super.key});

  static String routeName = 'policy';
  static String routePath = '/policy';

  @override
  State<PolicyWidget> createState() => _PolicyWidgetState();
}

class _PolicyWidgetState extends State<PolicyWidget> {
  late PolicyModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PolicyModel());
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
        backgroundColor: ExpatlioDesign.background,
        body: Stack(
          children: [
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.pagePadding,
                  ExpatlioDesign.space0,
                  ExpatlioDesign.pagePadding,
                  ExpatlioDesign.space0),
              child: SingleChildScrollView(
                primary: false,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).primaryBackground,
                        borderRadius:
                            BorderRadius.circular(ExpatlioDesign.radiusLarge),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(ExpatlioDesign.space16),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AutoSizeText(
                              FFLocalizations.of(context).getText(
                                'xfsjdmlr' /* Политика
конфиденциальности */
                                ,
                              ),
                              maxLines: 2,
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'Cool',
                                    fontSize: 22.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                  ),
                            ),
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  ExpatlioDesign.space0,
                                  ExpatlioDesign.space12,
                                  ExpatlioDesign.space0,
                                  ExpatlioDesign.space0),
                              child: Text(
                                FFLocalizations.of(context).getText(
                                  'czklyx18' /* Дата вступления в силу: 28 ноя... */,
                                ),
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      fontFamily: 'sf pro display',
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      fontSize: 15.0,
                                      letterSpacing: 0.0,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                          ExpatlioDesign.space12,
                          ExpatlioDesign.space24,
                          ExpatlioDesign.space12,
                          ExpatlioDesign.space0),
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            FFLocalizations.of(context).getText(
                              '00inco2o' /* 1. Общие положения */,
                            ),
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: 'Cool',
                                  fontSize: 22.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.normal,
                                ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space4,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Text(
                              FFLocalizations.of(context).getText(
                                'ttebd0yi' /* Expatlio ("мы", "нас", "наше ... */,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    fontSize: 16.0,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space24,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Text(
                              FFLocalizations.of(context).getText(
                                'l9d370gj' /* 2. Какую информацию мы собирае... */,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'Cool',
                                    fontSize: 22.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space4,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Text(
                              FFLocalizations.of(context).getText(
                                'u78z43s6' /* 2.1. Информация, которую вы пр... */,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    fontSize: 16.0,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space24,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Text(
                              FFLocalizations.of(context).getText(
                                'knl0nrpp' /* 3. Как мы используем вашу инфо... */,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'Cool',
                                    fontSize: 22.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space4,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Text(
                              FFLocalizations.of(context).getText(
                                '0yy4lfbi' /* Мы используем собранную информ... */,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    fontSize: 16.0,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space24,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Text(
                              FFLocalizations.of(context).getText(
                                'ca70uab5' /* 4. Как мы делимся вашей информ... */,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'Cool',
                                    fontSize: 22.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space4,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Text(
                              FFLocalizations.of(context).getText(
                                '41wy02qp' /* 4.1. С другими пользователями
... */
                                ,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    fontSize: 16.0,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space24,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Text(
                              FFLocalizations.of(context).getText(
                                'dt5pemdf' /* 5. Хранение данных */,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'Cool',
                                    fontSize: 22.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space4,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Text(
                              FFLocalizations.of(context).getText(
                                'm9g24qvb' /* Личные данные: хранятся, пока ... */,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    fontSize: 16.0,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space24,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Text(
                              FFLocalizations.of(context).getText(
                                'zqtodugk' /* 6. Безопасность данных */,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'Cool',
                                    fontSize: 22.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space4,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Text(
                              FFLocalizations.of(context).getText(
                                'f4cv0dej' /* Мы применяем современные техно... */,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    fontSize: 16.0,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space24,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Text(
                              FFLocalizations.of(context).getText(
                                'm4x662t6' /* 7. Ваши права */,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'Cool',
                                    fontSize: 22.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space4,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Text(
                              FFLocalizations.of(context).getText(
                                'fqnb17ee' /* Вы имеете право:

Доступ: запр... */
                                ,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    fontSize: 16.0,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space24,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Text(
                              FFLocalizations.of(context).getText(
                                '4de90uf9' /* 8. Файлы cookie и технологии о... */,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'Cool',
                                    fontSize: 22.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space4,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Text(
                              FFLocalizations.of(context).getText(
                                'hwz018hb' /* Мы используем файлы cookie и а... */,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    fontSize: 16.0,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space24,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Text(
                              FFLocalizations.of(context).getText(
                                '8sdsub64' /* 9. Уведомления */,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'Cool',
                                    fontSize: 22.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space4,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Text(
                              FFLocalizations.of(context).getText(
                                '9o4binxg' /* Вы можете получать:

Уведомлен... */
                                ,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    fontSize: 16.0,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space24,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Text(
                              FFLocalizations.of(context).getText(
                                'va83u8gv' /* 10. Изменения в Политике конфи... */,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'Cool',
                                    fontSize: 22.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space4,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Text(
                              FFLocalizations.of(context).getText(
                                'c70i9skq' /* Мы можем периодически обновлят... */,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    fontSize: 16.0,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space24,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Text(
                              FFLocalizations.of(context).getText(
                                'su42pbdb' /* 11. Контактная информация */,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'Cool',
                                    fontSize: 22.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space4,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Text(
                              FFLocalizations.of(context).getText(
                                'u7llfjy4' /* Если у вас есть вопросы о наст... */,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    fontSize: 16.0,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space24,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Text(
                              FFLocalizations.of(context).getText(
                                'dhdlspw7' /* Согласие */,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'Cool',
                                    fontSize: 22.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space4,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Text(
                              FFLocalizations.of(context).getText(
                                'cfh32zir' /* Используя Expatlio, вы подтве... */,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    fontSize: 16.0,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space32,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Text(
                              FFLocalizations.of(context).getText(
                                'gcd5d56f' /* © 2025 Expatlio. Все права за... */,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    fontSize: 16.0,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]
                      .addToStart(SizedBox(height: ExpatlioDesign.space136))
                      .addToEnd(SizedBox(height: ExpatlioDesign.space32)),
                ),
              ),
            ),
            BasicPageHeader(
              title: FFLocalizations.of(context)
                  .getText(
                    'xfsjdmlr' /* Политика конфиденциальности */,
                  )
                  .replaceAll('\n', ' '),
            ),
          ],
        ),
      ),
    );
  }
}
