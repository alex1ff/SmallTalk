import '/auth/firebase_auth/auth_util.dart';
import '/authorization/components/av/av_widget.dart';
import '/authorization/components/avatar_card/avatar_card_widget.dart';
import '/authorization/components/chips/chips_widget.dart';
import '/authorization/components/country/country_widget.dart';
import '/authorization/components/lang/lang_widget.dart';
import '/authorization/components/uploud_photo/uploud_photo_widget.dart';
import '/backend/backend.dart';
import '/backend/firebase_storage/storage.dart';
import '/backend/schema/enums/enums.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_swipeable_stack.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/upload_data.dart';
import 'dart:async';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import '/flutter_flow/permissions_util.dart';
import '/index.dart';
import 'dart:math' as math;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:webviewx_plus/webviewx_plus.dart';
import 'acquaintance_s_t_u_d_e_n_t_model.dart';
export 'acquaintance_s_t_u_d_e_n_t_model.dart';

class AcquaintanceSTUDENTWidget extends StatefulWidget {
  const AcquaintanceSTUDENTWidget({
    super.key,
    required this.index,
  });

  final int? index;

  static String routeName = 'Acquaintance_STUDENT';
  static String routePath = '/acquaintanceSTUDENT';

  @override
  State<AcquaintanceSTUDENTWidget> createState() =>
      _AcquaintanceSTUDENTWidgetState();
}

class _AcquaintanceSTUDENTWidgetState extends State<AcquaintanceSTUDENTWidget> {
  late AcquaintanceSTUDENTModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  late StreamSubscription<bool> _keyboardVisibilitySubscription;
  bool _isKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AcquaintanceSTUDENTModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      safeSetState(() {});
      await requestPermission(cameraPermission);
      await requestPermission(microphonePermission);
    });

    if (!isWeb) {
      _keyboardVisibilitySubscription =
          KeyboardVisibilityController().onChange.listen((bool visible) {
        safeSetState(() {
          _isKeyboardVisible = visible;
        });
      });
    }

    _model.nameTextController ??= TextEditingController();
    _model.nameFocusNode ??= FocusNode();
  }

  @override
  void dispose() {
    _model.dispose();

    if (!isWeb) {
      _keyboardVisibilitySubscription.cancel();
    }
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
              padding: EdgeInsetsDirectional.fromSTEB(0.0, 55.0, 0.0, 0.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(4.0, 0.0, 4.0, 0.0),
                    child: Container(
                      width: double.infinity,
                      height: 70.0,
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).primaryBackground,
                        borderRadius: BorderRadius.circular(100.0),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(2.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 66.0,
                              height: 66.0,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                              child: Stack(
                                alignment: AlignmentDirectional(0.0, 0.0),
                                children: [
                                  Padding(
                                    padding: EdgeInsets.all(2.0),
                                    child: Container(
                                      width: double.infinity,
                                      height: double.infinity,
                                      child: custom_widgets.ProggresBar(
                                        width: double.infinity,
                                        height: double.infinity,
                                        currentStep: () {
                                          if (_model.pageViewCurrentIndex ==
                                              4) {
                                            return 4;
                                          } else if (_model
                                                  .pageViewCurrentIndex >
                                              4) {
                                            return _model.pageViewCurrentIndex;
                                          } else {
                                            return (_model
                                                    .pageViewCurrentIndex +
                                                1);
                                          }
                                        }(),
                                        totalSteps: 8,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${() {
                                      if (_model.pageViewCurrentIndex == 4) {
                                        return '4';
                                      } else if (_model.pageViewCurrentIndex >
                                          4) {
                                        return _model.pageViewCurrentIndex
                                            .toString();
                                      } else {
                                        return (_model.pageViewCurrentIndex + 1)
                                            .toString();
                                      }
                                    }()}/8',
                                    textAlign: TextAlign.center,
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          fontFamily: 'sf pro display',
                                          color: Colors.white,
                                          fontSize: 14.0,
                                          letterSpacing: 0.0,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            if (_model.pageViewCurrentIndex > 4)
                              InkWell(
                                splashColor: Colors.transparent,
                                focusColor: Colors.transparent,
                                hoverColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                onTap: () async {
                                  if (_model.pageViewCurrentIndex == 8) {
                                    if (_model.avatarPhooto != null &&
                                        (_model.avatarPhooto?.bytes
                                                ?.isNotEmpty ??
                                            false)) {
                                      {
                                        safeSetState(() => _model
                                                .isDataUploading_uploadDataY2w2 =
                                            true);
                                        var selectedUploadedFiles =
                                            <FFUploadedFile>[];
                                        var selectedMedia = <SelectedFile>[];
                                        var downloadUrls = <String>[];
                                        try {
                                          selectedUploadedFiles = _model
                                                  .avatarPhooto!
                                                  .bytes!
                                                  .isNotEmpty
                                              ? [_model.avatarPhooto!]
                                              : <FFUploadedFile>[];
                                          selectedMedia =
                                              selectedFilesFromUploadedFiles(
                                            selectedUploadedFiles,
                                          );
                                          downloadUrls = (await Future.wait(
                                            selectedMedia.map(
                                              (m) async => await uploadData(
                                                  m.storagePath, m.bytes),
                                            ),
                                          ))
                                              .where((u) => u != null)
                                              .map((u) => u!)
                                              .toList();
                                        } finally {
                                          _model.isDataUploading_uploadDataY2w2 =
                                              false;
                                        }
                                        if (selectedUploadedFiles.length ==
                                                selectedMedia.length &&
                                            downloadUrls.length ==
                                                selectedMedia.length) {
                                          safeSetState(() {
                                            _model.uploadedLocalFile_uploadDataY2w2 =
                                                selectedUploadedFiles.first;
                                            _model.uploadedFileUrl_uploadDataY2w2 =
                                                downloadUrls.first;
                                          });
                                        } else {
                                          safeSetState(() {});
                                          return;
                                        }
                                      }

                                      unawaited(
                                        () async {
                                          await currentUserReference!.update({
                                            ...createUsersRecordData(
                                              isProfileComplete: true,
                                              preferences:
                                                  updatePreferencesStruct(
                                                PreferencesStruct(
                                                  preferredNativeLanguage:
                                                      _model.langNS,
                                                  preferredLocation:
                                                      _model.counntryNS,
                                                ),
                                                clearUnsetFields: false,
                                              ),
                                              photoUrl: _model
                                                  .uploadedFileUrl_uploadDataY2w,
                                              displayName: _model
                                                  .nameTextController.text,
                                              gender: _model.genderMALE
                                                  ? Gender.male
                                                  : Gender.female,
                                              level: _model.level,
                                              balanceST: updateBalanceStruct(
                                                BalanceStruct(
                                                  smallTalks: 1,
                                                  minutes: 10,
                                                ),
                                                clearUnsetFields: false,
                                              ),
                                              learningLanguage:
                                                  updateLanguageStruct(
                                                _model.selectedLangLearn,
                                                clearUnsetFields: false,
                                              ),
                                            ),
                                            ...mapToFirestore(
                                              {
                                                'purpose': _model.purpose,
                                              },
                                            ),
                                          });
                                        }(),
                                      );
                                    } else {
                                      unawaited(
                                        () async {
                                          await currentUserReference!.update({
                                            ...createUsersRecordData(
                                              photoUrl: _model.avatar,
                                              isProfileComplete: true,
                                              preferences:
                                                  updatePreferencesStruct(
                                                PreferencesStruct(
                                                  preferredNativeLanguage:
                                                      _model.langNS,
                                                  preferredLocation:
                                                      _model.counntryNS,
                                                ),
                                                clearUnsetFields: false,
                                              ),
                                              displayName: _model
                                                  .nameTextController.text,
                                              gender: _model.genderMALE
                                                  ? Gender.male
                                                  : Gender.female,
                                              level: _model.level,
                                              selectedAvatarDocRef:
                                                  _model.selectedAvatar,
                                              balanceST: updateBalanceStruct(
                                                BalanceStruct(
                                                  smallTalks: 1,
                                                  minutes: 10,
                                                ),
                                                clearUnsetFields: false,
                                              ),
                                              learningLanguage:
                                                  updateLanguageStruct(
                                                _model.selectedLangLearn,
                                                clearUnsetFields: false,
                                              ),
                                            ),
                                            ...mapToFirestore(
                                              {
                                                'purpose': _model.purpose,
                                              },
                                            ),
                                          });
                                        }(),
                                      );
                                    }

                                    context.pushNamed(
                                      StudentsDashboardWidget.routeName,
                                      queryParameters: {
                                        'zn': serializeParam(
                                          true,
                                          ParamType.bool,
                                        ),
                                        'done': serializeParam(
                                          true,
                                          ParamType.bool,
                                        ),
                                      }.withoutNulls,
                                    );
                                  } else {
                                    await _model.pageViewController?.nextPage(
                                      duration: Duration(milliseconds: 300),
                                      curve: Curves.ease,
                                    );
                                  }
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          12.0, 0.0, 12.0, 0.0),
                                      child: Text(
                                        FFLocalizations.of(context).getText(
                                          'bqppzscm' /* Пропустить */,
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
                                      width: 66.0,
                                      height: 66.0,
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Align(
                                        alignment:
                                            AlignmentDirectional(0.0, 0.0),
                                        child: Icon(
                                          Icons.close_rounded,
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                          size: 20.0,
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
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      child: PageView(
                        physics: const NeverScrollableScrollPhysics(),
                        controller: _model.pageViewController ??=
                            PageController(
                                initialPage: max(
                                    0,
                                    min(
                                        valueOrDefault<int>(
                                          widget.index,
                                          0,
                                        ),
                                        8))),
                        onPageChanged: (_) => safeSetState(() {}),
                        scrollDirection: Axis.horizontal,
                        children: [
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                6.0, 0.0, 6.0, 0.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      10.0, 16.0, 0.0, 0.0),
                                  child: Text(
                                    FFLocalizations.of(context).getText(
                                      'ip2rlf3r' /* Как вас зовут? */,
                                    ),
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          fontFamily: 'Cool',
                                          fontSize: 43.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.normal,
                                        ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      10.0, 4.0, 0.0, 0.0),
                                  child: Text(
                                    FFLocalizations.of(context).getText(
                                      'f55kpaxg' /* Лучше написать настоящее имя */,
                                    ),
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          fontFamily: 'sf pro display',
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryText,
                                          fontSize: 16.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.normal,
                                        ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 60.0, 0.0, 0.0),
                                  child: Container(
                                    width: double.infinity,
                                    height: 60.0,
                                    decoration: BoxDecoration(
                                      color: FlutterFlowTheme.of(context)
                                          .primaryBackground,
                                      borderRadius:
                                          BorderRadius.circular(100.0),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(2.0),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.max,
                                        children: [
                                          Container(
                                            width: 56.0,
                                            height: 56.0,
                                            decoration: BoxDecoration(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryBackground,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Align(
                                              alignment: AlignmentDirectional(
                                                  0.0, 0.0),
                                              child: Icon(
                                                FFIcons.kuser03,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                size: 20.0,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(8.0, 0.0, 8.0, 0.0),
                                              child: Container(
                                                width: double.infinity,
                                                child: TextFormField(
                                                  controller:
                                                      _model.nameTextController,
                                                  focusNode:
                                                      _model.nameFocusNode,
                                                  onFieldSubmitted: (_) async {
                                                    if (_model.nameTextController
                                                                .text !=
                                                            '') {
                                                      if (functions.isValidName(
                                                          _model
                                                              .nameTextController
                                                              .text)) {
                                                        await _model
                                                            .pageViewController
                                                            ?.nextPage(
                                                          duration: Duration(
                                                              milliseconds:
                                                                  300),
                                                          curve: Curves.ease,
                                                        );
                                                      } else {
                                                        await actions
                                                            .showTopNotification(
                                                          context,
                                                          'Неверное имя',
                                                          '',
                                                          true,
                                                        );
                                                        return;
                                                      }
                                                    } else {
                                                      await actions
                                                          .showTopNotification(
                                                        context,
                                                        'Пожалуйста, представьтесь',
                                                        '',
                                                        true,
                                                      );
                                                      return;
                                                    }
                                                  },
                                                  autofocus: true,
                                                  textCapitalization:
                                                      TextCapitalization
                                                          .sentences,
                                                  textInputAction:
                                                      TextInputAction.next,
                                                  obscureText: false,
                                                  decoration: InputDecoration(
                                                    isDense: false,
                                                    labelText:
                                                        FFLocalizations.of(
                                                                context)
                                                            .getText(
                                                      'aty6z85z' /* Ваше имя */,
                                                    ),
                                                    labelStyle: FlutterFlowTheme
                                                            .of(context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryText,
                                                          fontSize: 16.0,
                                                          letterSpacing: 0.0,
                                                        ),
                                                    enabledBorder:
                                                        InputBorder.none,
                                                    focusedBorder:
                                                        InputBorder.none,
                                                    errorBorder:
                                                        InputBorder.none,
                                                    focusedErrorBorder:
                                                        InputBorder.none,
                                                  ),
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        fontSize: 16.0,
                                                        letterSpacing: 0.0,
                                                      ),
                                                  cursorColor:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .primaryText,
                                                  enableInteractiveSelection:
                                                      true,
                                                  validator: _model
                                                      .nameTextControllerValidator
                                                      .asValidator(context),
                                                  inputFormatters: [
                                                    if (!isAndroid && !isiOS)
                                                      TextInputFormatter
                                                          .withFunction(
                                                              (oldValue,
                                                                  newValue) {
                                                        return TextEditingValue(
                                                          selection: newValue
                                                              .selection,
                                                          text: newValue.text
                                                              .toCapitalization(
                                                                  TextCapitalization
                                                                      .sentences),
                                                        );
                                                      }),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Stack(
                            children: [
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    0.0, 60.0, 0.0, 0.0),
                                child: FlutterFlowSwipeableStack(
                                  onSwipeFn: (index) async {
                                    _model.genderMALE = !_model.genderMALE;
                                    safeSetState(() {});
                                  },
                                  onLeftSwipe: (index) {},
                                  onRightSwipe: (index) {},
                                  onUpSwipe: (index) {},
                                  onDownSwipe: (index) {},
                                  itemBuilder: (context, index) {
                                    return [
                                      () => Align(
                                            alignment:
                                                AlignmentDirectional(0.0, 0.0),
                                            child: Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(
                                                      12.0, 0.0, 0.0, 0.0),
                                              child: Transform.rotate(
                                                angle: 15.0 * (math.pi / 180),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          20.0),
                                                  child: Image.network(
                                                    FFLocalizations.of(context)
                                                                .languageCode ==
                                                            'ru'
                                                        ? 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/yhizey073y1b/%D0%B0%D1%8B%D0%B04.jpg'
                                                        : 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/isq53wlqy7ir/Group_1171275311.png',
                                                    width: 280.0,
                                                    fit: BoxFit.contain,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      () => Align(
                                            alignment:
                                                AlignmentDirectional(0.0, 0.0),
                                            child: Transform.rotate(
                                              angle: 350.0 * (math.pi / 180),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(20.0),
                                                child: Image.network(
                                                  FFLocalizations.of(context)
                                                              .languageCode ==
                                                          'ru'
                                                      ? 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/k1enf0nhdqvc/33%D0%B0%D0%B0.jpg'
                                                      : 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/avw4u16n2yvl/33%D0%B0%D0%B02.jpg',
                                                  width: 280.0,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ),
                                          ),
                                    ][index]();
                                  },
                                  itemCount: 2,
                                  controller: _model.swipeableStackController,
                                  loop: true,
                                  cardDisplayCount: 2,
                                  scale: 0.9,
                                  backCardOffset: const Offset(100.0, 0.0),
                                  allowedSwipeDirection:
                                      AllowedSwipeDirection.symmetric(
                                          horizontal: true),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    16.0, 16.0, 16.0, 0.0),
                                child: AutoSizeText(
                                  FFLocalizations.of(context).getText(
                                    '53phc019' /* Как вы себя 
идентифицируете? */
                                    ,
                                  ),
                                  maxLines: 2,
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        fontFamily: 'Cool',
                                        color: Colors.black,
                                        fontSize: 43.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.normal,
                                        lineHeight: 1.1,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                6.0, 0.0, 6.0, 0.0),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        10.0, 0.0, 10.0, 0.0),
                                    child: AutoSizeText(
                                      FFLocalizations.of(context).getText(
                                        'tqqp6x5t' /* Какой язык хотите практиковать... */,
                                      ),
                                      maxLines: 2,
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'Cool',
                                            color: Colors.black,
                                            fontSize: 43.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                            lineHeight: 1.1,
                                          ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        10.0, 4.0, 0.0, 0.0),
                                    child: Text(
                                      FFLocalizations.of(context).getText(
                                        '1crdpxrp' /* Сможете изменить позднее */,
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryText,
                                            fontSize: 16.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                          ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 60.0, 0.0, 0.0),
                                    child: wrapWithModel(
                                      model: _model.langModel1,
                                      updateCallback: () => safeSetState(() {}),
                                      child: LangWidget(
                                        selected: _model.selectedLangLearn,
                                        action: (lang) async {
                                          _model.selectedLangLearn = lang;
                                          safeSetState(() {});
                                        },
                                      ),
                                    ),
                                  ),
                                ]
                                    .addToStart(SizedBox(height: 16.0))
                                    .addToEnd(SizedBox(height: 120.0)),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                6.0, 0.0, 6.0, 0.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      10.0, 16.0, 10.0, 0.0),
                                  child: AutoSizeText(
                                    FFLocalizations.of(context).getText(
                                      'gs6ylhnl' /* Ваш текущий уровень */,
                                    ),
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          fontFamily: 'Cool',
                                          color: Colors.black,
                                          fontSize: 43.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.normal,
                                          lineHeight: 1.1,
                                        ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 30.0, 0.0, 0.0),
                                  child: Stack(
                                    alignment: AlignmentDirectional(0.0, 1.0),
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        height: 350.0,
                                        child: custom_widgets.SemiCircleSlider(
                                          width: double.infinity,
                                          height: 350.0,
                                          initialLevel: _model.level,
                                          onChanged: (level) async {
                                            _model.level = level;
                                            safeSetState(() {});
                                          },
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            0.0, 0.0, 0.0, 12.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(
                                                      0.0, 0.0, 0.0, 30.0),
                                              child: Builder(
                                                builder: (context) {
                                                  if (_model.level ==
                                                      Level.Beginner) {
                                                    return Column(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              EdgeInsetsDirectional
                                                                  .fromSTEB(
                                                                      0.0,
                                                                      0.0,
                                                                      0.0,
                                                                      12.0),
                                                          child: Image.asset(
                                                            'assets/images/34kgr_.png',
                                                            width: 100.0,
                                                            height: 70.0,
                                                            fit: BoxFit.contain,
                                                          ),
                                                        ),
                                                        Text(
                                                          FFLocalizations.of(
                                                                  context)
                                                              .getText(
                                                            'zst66ylu' /* Начальный */,
                                                          ),
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                fontSize: 21.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                        Text(
                                                          FFLocalizations.of(
                                                                  context)
                                                              .getText(
                                                            '5dx8dgam' /* Знаю базовые фразы и слова
A1-... */
                                                            ,
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryText,
                                                                fontSize: 13.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                      ],
                                                    );
                                                  } else if (_model.level ==
                                                      Level.Basic) {
                                                    return Column(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              EdgeInsetsDirectional
                                                                  .fromSTEB(
                                                                      0.0,
                                                                      0.0,
                                                                      0.0,
                                                                      12.0),
                                                          child: Image.asset(
                                                            'assets/images/iom0u_.png',
                                                            width: 100.0,
                                                            height: 70.0,
                                                            fit: BoxFit.contain,
                                                          ),
                                                        ),
                                                        Text(
                                                          FFLocalizations.of(
                                                                  context)
                                                              .getText(
                                                            'f84pr2gx' /* Базовый */,
                                                          ),
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                fontSize: 21.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                        Text(
                                                          FFLocalizations.of(
                                                                  context)
                                                              .getText(
                                                            '9o39d1jb' /* Могу поддержать простой разгов... */,
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryText,
                                                                fontSize: 13.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                      ],
                                                    );
                                                  } else if (_model.level ==
                                                      Level.Intermediate) {
                                                    return Column(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              EdgeInsetsDirectional
                                                                  .fromSTEB(
                                                                      0.0,
                                                                      0.0,
                                                                      0.0,
                                                                      12.0),
                                                          child: Image.asset(
                                                            'assets/images/g08g4_.png',
                                                            width: 100.0,
                                                            height: 70.0,
                                                            fit: BoxFit.contain,
                                                          ),
                                                        ),
                                                        Text(
                                                          FFLocalizations.of(
                                                                  context)
                                                              .getText(
                                                            'yxe8e00i' /* Уверенный */,
                                                          ),
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                fontSize: 21.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                        Text(
                                                          FFLocalizations.of(
                                                                  context)
                                                              .getText(
                                                            'b0keg79q' /* Говорю свободно на большинство... */,
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryText,
                                                                fontSize: 13.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                      ],
                                                    );
                                                  } else {
                                                    return Column(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              EdgeInsetsDirectional
                                                                  .fromSTEB(
                                                                      0.0,
                                                                      0.0,
                                                                      0.0,
                                                                      12.0),
                                                          child: Image.asset(
                                                            'assets/images/e1xjd_.png',
                                                            width: 100.0,
                                                            height: 70.0,
                                                            fit: BoxFit.contain,
                                                          ),
                                                        ),
                                                        Text(
                                                          FFLocalizations.of(
                                                                  context)
                                                              .getText(
                                                            'pqgno6ti' /* Свободно */,
                                                          ),
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                fontSize: 21.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                        Text(
                                                          FFLocalizations.of(
                                                                  context)
                                                              .getText(
                                                            's4ycikzv' /* Владею как родным
Native */
                                                            ,
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryText,
                                                                fontSize: 13.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                      ],
                                                    );
                                                  }
                                                },
                                              ),
                                            ),
                                            Stack(
                                              alignment: AlignmentDirectional(
                                                  0.0, 0.0),
                                              children: [
                                                Container(
                                                  width: double.infinity,
                                                  height: 22.0,
                                                  decoration: BoxDecoration(
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primaryBackground,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            50.0),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: EdgeInsets.all(2.0),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.start,
                                                    children: [
                                                      Expanded(
                                                        child: InkWell(
                                                          splashColor: Colors
                                                              .transparent,
                                                          focusColor: Colors
                                                              .transparent,
                                                          hoverColor: Colors
                                                              .transparent,
                                                          highlightColor: Colors
                                                              .transparent,
                                                          onTap: () async {
                                                            _model.level =
                                                                Level.Beginner;
                                                            safeSetState(() {});
                                                          },
                                                          child: Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .max,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Container(
                                                                width:
                                                                    valueOrDefault<
                                                                        double>(
                                                                  _model.level ==
                                                                          Level
                                                                              .Beginner
                                                                      ? 32.0
                                                                      : 18.0,
                                                                  32.0,
                                                                ),
                                                                height:
                                                                    valueOrDefault<
                                                                        double>(
                                                                  _model.level ==
                                                                          Level
                                                                              .Beginner
                                                                      ? 32.0
                                                                      : 18.0,
                                                                  32.0,
                                                                ),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color:
                                                                      valueOrDefault<
                                                                          Color>(
                                                                    _model.level ==
                                                                            Level
                                                                                .Beginner
                                                                        ? FlutterFlowTheme.of(context)
                                                                            .primaryBackground
                                                                        : FlutterFlowTheme.of(context)
                                                                            .secondaryBackground,
                                                                    FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryBackground,
                                                                  ),
                                                                  shape: BoxShape
                                                                      .circle,
                                                                  border: Border
                                                                      .all(
                                                                    color: valueOrDefault<
                                                                        Color>(
                                                                      _model.level ==
                                                                              Level
                                                                                  .Beginner
                                                                          ? Color(
                                                                              0xFF6657E6)
                                                                          : Colors
                                                                              .transparent,
                                                                      Color(
                                                                          0xFF6657E6),
                                                                    ),
                                                                    width: 6.0,
                                                                  ),
                                                                ),
                                                                child:
                                                                    Visibility(
                                                                  visible: _model
                                                                          .level !=
                                                                      Level
                                                                          .Beginner,
                                                                  child: Align(
                                                                    alignment:
                                                                        AlignmentDirectional(
                                                                            0.0,
                                                                            0.0),
                                                                    child:
                                                                        Container(
                                                                      width:
                                                                          2.0,
                                                                      height:
                                                                          2.0,
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        color: FlutterFlowTheme.of(context)
                                                                            .primaryText,
                                                                        shape: BoxShape
                                                                            .circle,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Padding(
                                                          padding:
                                                              EdgeInsetsDirectional
                                                                  .fromSTEB(
                                                                      0.0,
                                                                      0.0,
                                                                      6.0,
                                                                      0.0),
                                                          child: InkWell(
                                                            splashColor: Colors
                                                                .transparent,
                                                            focusColor: Colors
                                                                .transparent,
                                                            hoverColor: Colors
                                                                .transparent,
                                                            highlightColor:
                                                                Colors
                                                                    .transparent,
                                                            onTap: () async {
                                                              _model.level =
                                                                  Level.Basic;
                                                              safeSetState(
                                                                  () {});
                                                            },
                                                            child: Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .center,
                                                              children: [
                                                                Container(
                                                                  width:
                                                                      valueOrDefault<
                                                                          double>(
                                                                    _model.level ==
                                                                            Level.Basic
                                                                        ? 32.0
                                                                        : 18.0,
                                                                    32.0,
                                                                  ),
                                                                  height:
                                                                      valueOrDefault<
                                                                          double>(
                                                                    _model.level ==
                                                                            Level.Basic
                                                                        ? 32.0
                                                                        : 18.0,
                                                                    32.0,
                                                                  ),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: valueOrDefault<
                                                                        Color>(
                                                                      _model.level ==
                                                                              Level
                                                                                  .Basic
                                                                          ? FlutterFlowTheme.of(context)
                                                                              .primaryBackground
                                                                          : FlutterFlowTheme.of(context)
                                                                              .secondaryBackground,
                                                                      FlutterFlowTheme.of(
                                                                              context)
                                                                          .primaryBackground,
                                                                    ),
                                                                    shape: BoxShape
                                                                        .circle,
                                                                    border:
                                                                        Border
                                                                            .all(
                                                                      color: valueOrDefault<
                                                                          Color>(
                                                                        _model.level ==
                                                                                Level.Basic
                                                                            ? Color(0xFF6657E6)
                                                                            : Colors.transparent,
                                                                        Color(
                                                                            0xFF6657E6),
                                                                      ),
                                                                      width:
                                                                          6.0,
                                                                    ),
                                                                  ),
                                                                  child:
                                                                      Visibility(
                                                                    visible: _model
                                                                            .level !=
                                                                        Level
                                                                            .Basic,
                                                                    child:
                                                                        Align(
                                                                      alignment:
                                                                          AlignmentDirectional(
                                                                              0.0,
                                                                              0.0),
                                                                      child:
                                                                          Container(
                                                                        width:
                                                                            2.0,
                                                                        height:
                                                                            2.0,
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          shape:
                                                                              BoxShape.circle,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Padding(
                                                          padding:
                                                              EdgeInsetsDirectional
                                                                  .fromSTEB(
                                                                      6.0,
                                                                      0.0,
                                                                      0.0,
                                                                      0.0),
                                                          child: InkWell(
                                                            splashColor: Colors
                                                                .transparent,
                                                            focusColor: Colors
                                                                .transparent,
                                                            hoverColor: Colors
                                                                .transparent,
                                                            highlightColor:
                                                                Colors
                                                                    .transparent,
                                                            onTap: () async {
                                                              _model.level = Level
                                                                  .Intermediate;
                                                              safeSetState(
                                                                  () {});
                                                            },
                                                            child: Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .center,
                                                              children: [
                                                                Container(
                                                                  width:
                                                                      valueOrDefault<
                                                                          double>(
                                                                    _model.level ==
                                                                            Level.Intermediate
                                                                        ? 32.0
                                                                        : 18.0,
                                                                    32.0,
                                                                  ),
                                                                  height:
                                                                      valueOrDefault<
                                                                          double>(
                                                                    _model.level ==
                                                                            Level.Intermediate
                                                                        ? 32.0
                                                                        : 18.0,
                                                                    32.0,
                                                                  ),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: valueOrDefault<
                                                                        Color>(
                                                                      _model.level ==
                                                                              Level
                                                                                  .Intermediate
                                                                          ? FlutterFlowTheme.of(context)
                                                                              .primaryBackground
                                                                          : FlutterFlowTheme.of(context)
                                                                              .secondaryBackground,
                                                                      FlutterFlowTheme.of(
                                                                              context)
                                                                          .primaryBackground,
                                                                    ),
                                                                    shape: BoxShape
                                                                        .circle,
                                                                    border:
                                                                        Border
                                                                            .all(
                                                                      color: valueOrDefault<
                                                                          Color>(
                                                                        _model.level ==
                                                                                Level.Intermediate
                                                                            ? Color(0xFF6657E6)
                                                                            : Colors.transparent,
                                                                        Color(
                                                                            0xFF6657E6),
                                                                      ),
                                                                      width:
                                                                          6.0,
                                                                    ),
                                                                  ),
                                                                  child:
                                                                      Visibility(
                                                                    visible: _model
                                                                            .level !=
                                                                        Level
                                                                            .Intermediate,
                                                                    child:
                                                                        Align(
                                                                      alignment:
                                                                          AlignmentDirectional(
                                                                              0.0,
                                                                              0.0),
                                                                      child:
                                                                          Container(
                                                                        width:
                                                                            2.0,
                                                                        height:
                                                                            2.0,
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          shape:
                                                                              BoxShape.circle,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: InkWell(
                                                          splashColor: Colors
                                                              .transparent,
                                                          focusColor: Colors
                                                              .transparent,
                                                          hoverColor: Colors
                                                              .transparent,
                                                          highlightColor: Colors
                                                              .transparent,
                                                          onTap: () async {
                                                            _model.level =
                                                                Level.Fluent;
                                                            safeSetState(() {});
                                                          },
                                                          child: Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .max,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .end,
                                                            children: [
                                                              Container(
                                                                width:
                                                                    valueOrDefault<
                                                                        double>(
                                                                  _model.level ==
                                                                          Level
                                                                              .Fluent
                                                                      ? 32.0
                                                                      : 18.0,
                                                                  32.0,
                                                                ),
                                                                height:
                                                                    valueOrDefault<
                                                                        double>(
                                                                  _model.level ==
                                                                          Level
                                                                              .Fluent
                                                                      ? 32.0
                                                                      : 18.0,
                                                                  32.0,
                                                                ),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color:
                                                                      valueOrDefault<
                                                                          Color>(
                                                                    _model.level ==
                                                                            Level
                                                                                .Fluent
                                                                        ? FlutterFlowTheme.of(context)
                                                                            .primaryBackground
                                                                        : FlutterFlowTheme.of(context)
                                                                            .secondaryBackground,
                                                                    FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryBackground,
                                                                  ),
                                                                  shape: BoxShape
                                                                      .circle,
                                                                  border: Border
                                                                      .all(
                                                                    color: valueOrDefault<
                                                                        Color>(
                                                                      _model.level ==
                                                                              Level
                                                                                  .Fluent
                                                                          ? Color(
                                                                              0xFF6657E6)
                                                                          : Colors
                                                                              .transparent,
                                                                      Color(
                                                                          0xFF6657E6),
                                                                    ),
                                                                    width: 6.0,
                                                                  ),
                                                                ),
                                                                child:
                                                                    Visibility(
                                                                  visible: _model
                                                                          .level !=
                                                                      Level
                                                                          .Fluent,
                                                                  child: Align(
                                                                    alignment:
                                                                        AlignmentDirectional(
                                                                            0.0,
                                                                            0.0),
                                                                    child:
                                                                        Container(
                                                                      width:
                                                                          2.0,
                                                                      height:
                                                                          2.0,
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        color: FlutterFlowTheme.of(context)
                                                                            .primaryText,
                                                                        shape: BoxShape
                                                                            .circle,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(0.0, 4.0, 0.0, 0.0),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          FFLocalizations.of(
                                                                  context)
                                                              .getText(
                                                            'sj0rn6q7' /* Начальный */,
                                                          ),
                                                          textAlign:
                                                              TextAlign.start,
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                color:
                                                                    valueOrDefault<
                                                                        Color>(
                                                                  _model.level ==
                                                                          Level
                                                                              .Beginner
                                                                      ? FlutterFlowTheme.of(
                                                                              context)
                                                                          .primaryText
                                                                      : FlutterFlowTheme.of(
                                                                              context)
                                                                          .secondaryText,
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                ),
                                                                fontSize: 13.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Padding(
                                                      padding:
                                                          EdgeInsetsDirectional
                                                              .fromSTEB(
                                                                  0.0,
                                                                  0.0,
                                                                  6.0,
                                                                  0.0),
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        children: [
                                                          Text(
                                                            FFLocalizations.of(
                                                                    context)
                                                                .getText(
                                                              'rm8zot80' /* Базовый */,
                                                            ),
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .bodyMedium
                                                                .override(
                                                                  fontFamily:
                                                                      'sf pro display',
                                                                  color:
                                                                      valueOrDefault<
                                                                          Color>(
                                                                    _model.level ==
                                                                            Level
                                                                                .Basic
                                                                        ? FlutterFlowTheme.of(context)
                                                                            .primaryText
                                                                        : FlutterFlowTheme.of(context)
                                                                            .secondaryText,
                                                                    FlutterFlowTheme.of(
                                                                            context)
                                                                        .secondaryText,
                                                                  ),
                                                                  fontSize:
                                                                      13.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Padding(
                                                      padding:
                                                          EdgeInsetsDirectional
                                                              .fromSTEB(
                                                                  6.0,
                                                                  0.0,
                                                                  0.0,
                                                                  0.0),
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        children: [
                                                          Text(
                                                            FFLocalizations.of(
                                                                    context)
                                                                .getText(
                                                              'onxzn6lu' /* Уверенный */,
                                                            ),
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .bodyMedium
                                                                .override(
                                                                  fontFamily:
                                                                      'sf pro display',
                                                                  color:
                                                                      valueOrDefault<
                                                                          Color>(
                                                                    _model.level ==
                                                                            Level
                                                                                .Intermediate
                                                                        ? FlutterFlowTheme.of(context)
                                                                            .primaryText
                                                                        : FlutterFlowTheme.of(context)
                                                                            .secondaryText,
                                                                    FlutterFlowTheme.of(
                                                                            context)
                                                                        .secondaryText,
                                                                  ),
                                                                  fontSize:
                                                                      13.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .end,
                                                      children: [
                                                        Text(
                                                          FFLocalizations.of(
                                                                  context)
                                                              .getText(
                                                            'qspamhah' /* Свободно */,
                                                          ),
                                                          textAlign:
                                                              TextAlign.end,
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                color:
                                                                    valueOrDefault<
                                                                        Color>(
                                                                  _model.level ==
                                                                          Level
                                                                              .Fluent
                                                                      ? FlutterFlowTheme.of(
                                                                              context)
                                                                          .primaryText
                                                                      : FlutterFlowTheme.of(
                                                                              context)
                                                                          .secondaryText,
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondaryText,
                                                                ),
                                                                fontSize: 13.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                6.0, 0.0, 6.0, 0.0),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        10.0, 0.0, 10.0, 0.0),
                                    child: AutoSizeText(
                                      FFLocalizations.of(context).getText(
                                        'lrja9u6c' /* Отличное начало! */,
                                      ),
                                      maxLines: 2,
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'Cool',
                                            color: Colors.black,
                                            fontSize: 43.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                            lineHeight: 1.1,
                                          ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        10.0, 4.0, 0.0, 0.0),
                                    child: Text(
                                      FFLocalizations.of(context).getText(
                                        '553cq9o6' /* Основная информация готова
Ост... */
                                        ,
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryText,
                                            fontSize: 16.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                          ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 100.0, 0.0, 0.0),
                                    child: Container(
                                      height: 213.21,
                                      child: Stack(
                                        children: [
                                          Container(
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primaryBackground,
                                              borderRadius:
                                                  BorderRadius.circular(38.0),
                                            ),
                                            child: Padding(
                                              padding: EdgeInsets.all(24.0),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.max,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    FFLocalizations.of(context)
                                                        .getText(
                                                      'aq1oqs5h' /* Завершите заполнение 
профиля ... */
                                                      ,
                                                    ),
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily: 'Cool',
                                                          fontSize: 20.0,
                                                          letterSpacing: 0.0,
                                                        ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(0.0, 24.0,
                                                                0.0, 0.0),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              EdgeInsetsDirectional
                                                                  .fromSTEB(
                                                                      0.0,
                                                                      0.0,
                                                                      8.0,
                                                                      0.0),
                                                          child: Container(
                                                            width: 20.0,
                                                            height: 20.0,
                                                            decoration:
                                                                BoxDecoration(
                                                              color: FlutterFlowTheme
                                                                      .of(context)
                                                                  .primary,
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                            child: Align(
                                                              alignment:
                                                                  AlignmentDirectional(
                                                                      0.0, 0.0),
                                                              child: Icon(
                                                                FFIcons.kcheck,
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryBackground,
                                                                size: 12.0,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        Text(
                                                          FFLocalizations.of(
                                                                  context)
                                                              .getText(
                                                            'dr0r3uyi' /* Более точный подбор собеседник... */,
                                                          ),
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                fontSize: 15.0,
                                                                letterSpacing:
                                                                    0.0,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(0.0, 12.0,
                                                                0.0, 0.0),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              EdgeInsetsDirectional
                                                                  .fromSTEB(
                                                                      0.0,
                                                                      0.0,
                                                                      8.0,
                                                                      0.0),
                                                          child: Container(
                                                            width: 20.0,
                                                            height: 20.0,
                                                            decoration:
                                                                BoxDecoration(
                                                              color: FlutterFlowTheme
                                                                      .of(context)
                                                                  .primary,
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                            child: Align(
                                                              alignment:
                                                                  AlignmentDirectional(
                                                                      0.0, 0.0),
                                                              child: Icon(
                                                                FFIcons.kcheck,
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryBackground,
                                                                size: 12.0,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        Text(
                                                          FFLocalizations.of(
                                                                  context)
                                                              .getText(
                                                            'angeqklx' /* До 10 минут бесплатного общени... */,
                                                          ),
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                fontSize: 15.0,
                                                                letterSpacing:
                                                                    0.0,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(0.0, 12.0,
                                                                0.0, 0.0),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              EdgeInsetsDirectional
                                                                  .fromSTEB(
                                                                      0.0,
                                                                      0.0,
                                                                      8.0,
                                                                      0.0),
                                                          child: Container(
                                                            width: 20.0,
                                                            height: 20.0,
                                                            decoration:
                                                                BoxDecoration(
                                                              color: FlutterFlowTheme
                                                                      .of(context)
                                                                  .primary,
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                            child: Align(
                                                              alignment:
                                                                  AlignmentDirectional(
                                                                      0.0, 0.0),
                                                              child: Icon(
                                                                FFIcons.kcheck,
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryBackground,
                                                                size: 12.0,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        Text(
                                                          FFLocalizations.of(
                                                                  context)
                                                              .getText(
                                                            'pcdwhfh6' /* Приоритет в поиске */,
                                                          ),
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                fontSize: 15.0,
                                                                letterSpacing:
                                                                    0.0,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Align(
                                            alignment: AlignmentDirectional(
                                                1.35, -2.66),
                                            child: Container(
                                              width: 150.0,
                                              height: 150.0,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Color(0xFFC3EFC3),
                                                    Color(0xFFA5FE72)
                                                  ],
                                                  stops: [0.0, 1.0],
                                                  begin: AlignmentDirectional(
                                                      0.0, -1.0),
                                                  end: AlignmentDirectional(
                                                      0, 1.0),
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Align(
                                                alignment: AlignmentDirectional(
                                                    0.0, 0.0),
                                                child: Image.asset(
                                                  'assets/images/sticker_8.png',
                                                  width: 130.0,
                                                  height: 130.1,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: AlignmentDirectional(0.0, -1.0),
                                    child: FFButtonWidget(
                                      onPressed: () async {
                                        if (widget.index == 4) {
                                          context.pushNamed(
                                              StudentsDashboardWidget
                                                  .routeName);
                                        } else {
                                          unawaited(
                                            () async {
                                              await currentUserReference!
                                                  .update(createUsersRecordData(
                                                level: _model.level,
                                                learningLanguage:
                                                    updateLanguageStruct(
                                                  _model.selectedLangLearn,
                                                  clearUnsetFields: false,
                                                ),
                                                acquaintance: true,
                                                displayName: _model
                                                    .nameTextController.text,
                                                gender: _model.genderMALE
                                                    ? Gender.male
                                                    : Gender.female,
                                              ));
                                            }(),
                                          );

                                          context.pushNamed(
                                            StudentsDashboardWidget.routeName,
                                            queryParameters: {
                                              'zn': serializeParam(
                                                true,
                                                ParamType.bool,
                                              ),
                                              'done': serializeParam(
                                                false,
                                                ParamType.bool,
                                              ),
                                            }.withoutNulls,
                                          );
                                        }
                                      },
                                      text: FFLocalizations.of(context).getText(
                                        'ybk9bjx6' /* Заполню позже */,
                                      ),
                                      options: FFButtonOptions(
                                        height: 40.0,
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            16.0, 0.0, 16.0, 0.0),
                                        iconPadding:
                                            EdgeInsetsDirectional.fromSTEB(
                                                0.0, 0.0, 0.0, 0.0),
                                        color: Colors.transparent,
                                        textStyle: FlutterFlowTheme.of(context)
                                            .titleSmall
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.normal,
                                            ),
                                        elevation: 0.0,
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                    ),
                                  ),
                                ]
                                    .addToStart(SizedBox(height: 16.0))
                                    .addToEnd(SizedBox(height: 120.0)),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                6.0, 0.0, 6.0, 0.0),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        10.0, 0.0, 10.0, 0.0),
                                    child: AutoSizeText(
                                      FFLocalizations.of(context).getText(
                                        '69cq0mzr' /* Зачем вам нужен этот язык? */,
                                      ),
                                      maxLines: 2,
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'Cool',
                                            color: Colors.black,
                                            fontSize: 43.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                            lineHeight: 1.1,
                                          ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        10.0, 4.0, 0.0, 0.0),
                                    child: Text(
                                      FFLocalizations.of(context).getText(
                                        '4yfkc6aa' /* Можно выбрать несколько */,
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryText,
                                            fontSize: 16.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                          ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 60.0, 0.0, 0.0),
                                    child: Container(
                                      width: double.infinity,
                                      height: 583.87,
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                      ),
                                      child: GridView(
                                        padding: EdgeInsets.zero,
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 3,
                                          crossAxisSpacing: 6.0,
                                          mainAxisSpacing: 6.0,
                                          childAspectRatio: 0.8,
                                        ),
                                        scrollDirection: Axis.vertical,
                                        children: [
                                          wrapWithModel(
                                            model: _model.chipsModel1,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: ChipsWidget(
                                              icon:
                                                  'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/5tvth2denlpx/%E2%9C%88%EF%B8%8F.png',
                                              text: FFLocalizations.of(context)
                                                  .getText(
                                                '45xgftn8' /* Путешествия */,
                                              ),
                                              selected: _model.purpose
                                                  .contains('Путешествия'),
                                              actionadd: (select) async {
                                                _model.addToPurpose(
                                                    'Путешествия');
                                                safeSetState(() {});
                                              },
                                              actiondeelete: (select) async {
                                                _model.removeFromPurpose(
                                                    'Путешествия');
                                                safeSetState(() {});
                                              },
                                            ),
                                          ),
                                          wrapWithModel(
                                            model: _model.chipsModel2,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: ChipsWidget(
                                              icon:
                                                  'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/lerjql614l6t/%F0%9F%92%BC.png',
                                              text: FFLocalizations.of(context)
                                                  .getText(
                                                'b81l5ck6' /* Работа */,
                                              ),
                                              selected: _model.purpose
                                                  .contains('Работа'),
                                              actionadd: (select) async {
                                                _model.addToPurpose('Работа');
                                                safeSetState(() {});
                                              },
                                              actiondeelete: (select) async {
                                                _model.removeFromPurpose(
                                                    'Работа');
                                                safeSetState(() {});
                                              },
                                            ),
                                          ),
                                          wrapWithModel(
                                            model: _model.chipsModel3,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: ChipsWidget(
                                              icon:
                                                  'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/aacr3gooehck/%F0%9F%93%9A.png',
                                              text: FFLocalizations.of(context)
                                                  .getText(
                                                'nvzre0x5' /* Учеба */,
                                              ),
                                              selected: _model.purpose
                                                  .contains('Учеба'),
                                              actionadd: (select) async {
                                                _model.addToPurpose('Учеба');
                                                safeSetState(() {});
                                              },
                                              actiondeelete: (select) async {
                                                _model
                                                    .removeFromPurpose('Учеба');
                                                safeSetState(() {});
                                              },
                                            ),
                                          ),
                                          wrapWithModel(
                                            model: _model.chipsModel4,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: ChipsWidget(
                                              icon:
                                                  'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/zn3jlcka2lbc/%F0%9F%92%A1.png',
                                              text: FFLocalizations.of(context)
                                                  .getText(
                                                '3bbpj9jw' /* Культура */,
                                              ),
                                              selected: _model.purpose
                                                  .contains('Культура'),
                                              actionadd: (select) async {
                                                _model.addToPurpose('Культура');
                                                safeSetState(() {});
                                              },
                                              actiondeelete: (select) async {
                                                _model.removeFromPurpose(
                                                    'Культура');
                                                safeSetState(() {});
                                              },
                                            ),
                                          ),
                                          wrapWithModel(
                                            model: _model.chipsModel5,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: ChipsWidget(
                                              icon:
                                                  'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/odie4pcem3fn/%F0%9F%92%AC.png',
                                              text: FFLocalizations.of(context)
                                                  .getText(
                                                'psmff4a8' /* Общение */,
                                              ),
                                              selected: _model.purpose
                                                  .contains('Общение'),
                                              actionadd: (select) async {
                                                _model.addToPurpose('Общение');
                                                safeSetState(() {});
                                              },
                                              actiondeelete: (select) async {
                                                _model.removeFromPurpose(
                                                    'Общение');
                                                safeSetState(() {});
                                              },
                                            ),
                                          ),
                                          wrapWithModel(
                                            model: _model.chipsModel6,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: ChipsWidget(
                                              icon:
                                                  'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/68cdtneygm0v/%F0%9F%9A%80.png',
                                              text: FFLocalizations.of(context)
                                                  .getText(
                                                'r19vqfh2' /* Другое */,
                                              ),
                                              selected: _model.purpose
                                                  .contains('Другое'),
                                              actionadd: (select) async {
                                                _model.addToPurpose('Другое');
                                                safeSetState(() {});
                                              },
                                              actiondeelete: (select) async {
                                                _model.removeFromPurpose(
                                                    'Другое');
                                                safeSetState(() {});
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ]
                                    .addToStart(SizedBox(height: 16.0))
                                    .addToEnd(SizedBox(height: 120.0)),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                6.0, 0.0, 6.0, 0.0),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        10.0, 0.0, 10.0, 0.0),
                                    child: Text(
                                      FFLocalizations.of(context).getText(
                                        '4l7nhxkw' /* Выберите аватар */,
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'Cool',
                                            fontSize: 43.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                            lineHeight: 1.1,
                                          ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 60.0, 0.0, 0.0),
                                    child: Container(
                                      height: 263.37,
                                      decoration: BoxDecoration(),
                                      child: FutureBuilder<List<AvatarsRecord>>(
                                        future: queryAvatarsRecordOnce(
                                          queryBuilder: (avatarsRecord) =>
                                              avatarsRecord.where(
                                            'gender',
                                            isEqualTo: _model.genderMALE
                                                ? Gender.male
                                                : Gender.female.serialize(),
                                          ),
                                        ),
                                        builder: (context, snapshot) {
                                          // Customize what your widget looks like when it's loading.
                                          if (!snapshot.hasData) {
                                            return Center(
                                              child: SizedBox(
                                                width: 50.0,
                                                height: 50.0,
                                                child: SpinKitCircle(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondary,
                                                  size: 50.0,
                                                ),
                                              ),
                                            );
                                          }
                                          List<AvatarsRecord>
                                              gridViewAvatarsRecordList =
                                              snapshot.data!;

                                          return GridView.builder(
                                            padding: EdgeInsets.zero,
                                            gridDelegate:
                                                SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 3,
                                              crossAxisSpacing: 6.0,
                                              mainAxisSpacing: 6.0,
                                              childAspectRatio: 1.0,
                                            ),
                                            scrollDirection: Axis.vertical,
                                            itemCount: gridViewAvatarsRecordList
                                                .length,
                                            itemBuilder:
                                                (context, gridViewIndex) {
                                              final gridViewAvatarsRecord =
                                                  gridViewAvatarsRecordList[
                                                      gridViewIndex];
                                              return AvatarCardWidget(
                                                key: Key(
                                                    'Keyvh8_${gridViewIndex}_of_${gridViewAvatarsRecordList.length}'),
                                                avatarDoc:
                                                    gridViewAvatarsRecord,
                                                selected: _model.selectedAvatar,
                                                avatar: _model.avatar,
                                                action: (doc) async {
                                                  if (_model.selectedAvatar !=
                                                      gridViewAvatarsRecord
                                                          .reference) {
                                                    _model.selectedAvatar =
                                                        gridViewAvatarsRecord
                                                            .reference;
                                                    _model.avatarPhooto = null;
                                                    _model.avatar = null;
                                                    safeSetState(() {});
                                                  }
                                                  await showModalBottomSheet(
                                                    isScrollControlled: true,
                                                    backgroundColor:
                                                        Colors.transparent,
                                                    context: context,
                                                    builder: (context) {
                                                      return WebViewAware(
                                                        child: GestureDetector(
                                                          onTap: () {
                                                            FocusScope.of(
                                                                    context)
                                                                .unfocus();
                                                            FocusManager
                                                                .instance
                                                                .primaryFocus
                                                                ?.unfocus();
                                                          },
                                                          child: Padding(
                                                            padding: MediaQuery
                                                                .viewInsetsOf(
                                                                    context),
                                                            child: AvWidget(
                                                              avatarDoc:
                                                                  gridViewAvatarsRecord,
                                                              ation:
                                                                  (img) async {
                                                                _model.avatar =
                                                                    img;
                                                                safeSetState(
                                                                    () {});
                                                              },
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ).then((value) =>
                                                      safeSetState(() {}));
                                                },
                                                actiondele: () async {
                                                  _model.selectedAvatar = null;
                                                  _model.avatar = null;
                                                  safeSetState(() {});
                                                },
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 16.0, 0.0, 0.0),
                                    child: InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        await showModalBottomSheet(
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          context: context,
                                          builder: (context) {
                                            return WebViewAware(
                                              child: GestureDetector(
                                                onTap: () {
                                                  FocusScope.of(context)
                                                      .unfocus();
                                                  FocusManager
                                                      .instance.primaryFocus
                                                      ?.unfocus();
                                                },
                                                child: Padding(
                                                  padding:
                                                      MediaQuery.viewInsetsOf(
                                                          context),
                                                  child: UploudPhotoWidget(
                                                    action: (upl) async {
                                                      _model.avatarPhooto = upl;
                                                      _model.avatar = null;
                                                      _model.selectedAvatar =
                                                          null;
                                                      safeSetState(() {});
                                                    },
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ).then((value) => safeSetState(() {}));
                                      },
                                      child: Container(
                                        width: double.infinity,
                                        height: 80.0,
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .primaryBackground,
                                          borderRadius:
                                              BorderRadius.circular(20.0),
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.all(2.0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              Builder(
                                                builder: (context) {
                                                  if (_model.avatarPhooto !=
                                                          null &&
                                                      (_model
                                                              .avatarPhooto
                                                              ?.bytes
                                                              ?.isNotEmpty ??
                                                          false)) {
                                                    return ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              18.0),
                                                      child: Image.memory(
                                                        _model.avatarPhooto
                                                                ?.bytes ??
                                                            Uint8List.fromList(
                                                                []),
                                                        width: 76.0,
                                                        height: 76.0,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    );
                                                  } else {
                                                    return Container(
                                                      width: 76.0,
                                                      height: 76.0,
                                                      decoration: BoxDecoration(
                                                        color: FlutterFlowTheme
                                                                .of(context)
                                                            .secondaryBackground,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20.0),
                                                      ),
                                                      child: Icon(
                                                        FFIcons.kcameraPlus,
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryText,
                                                        size: 20.0,
                                                      ),
                                                    );
                                                  }
                                                },
                                              ),
                                              Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        12.0, 0.0, 0.0, 0.0),
                                                child: AutoSizeText(
                                                  FFLocalizations.of(context)
                                                      .getText(
                                                    'x6szbodc' /* Или загрузить своё фото */,
                                                  ),
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryText,
                                                        fontSize: 16.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        lineHeight: 1.1,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ]
                                    .addToStart(SizedBox(height: 16.0))
                                    .addToEnd(SizedBox(height: 120.0)),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                6.0, 0.0, 6.0, 0.0),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        10.0, 16.0, 10.0, 0.0),
                                    child: AutoSizeText(
                                      FFLocalizations.of(context).getText(
                                        'abc33q9h' /* С носителем какого языка хотит... */,
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'Cool',
                                            color: Colors.black,
                                            fontSize: 43.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                            lineHeight: 1.1,
                                          ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        10.0, 4.0, 0.0, 0.0),
                                    child: Text(
                                      FFLocalizations.of(context).getText(
                                        'kpfa0ujl' /* Сможете изменить позднее */,
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryText,
                                            fontSize: 16.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                          ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 60.0, 0.0, 0.0),
                                    child: wrapWithModel(
                                      model: _model.langModel2,
                                      updateCallback: () => safeSetState(() {}),
                                      child: LangWidget(
                                        selected: _model.langNS,
                                        action: (lang) async {
                                          _model.langNS = null;
                                          safeSetState(() {});
                                          _model.langNS = lang;
                                          safeSetState(() {});
                                        },
                                      ),
                                    ),
                                  ),
                                ].addToEnd(SizedBox(height: 111.0)),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                6.0, 0.0, 6.0, 0.0),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        8.0, 16.0, 8.0, 0.0),
                                    child: AutoSizeText(
                                      FFLocalizations.of(context).getText(
                                        'dvafgdbh' /* Местоположение собеседника */,
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'Cool',
                                            color: Colors.black,
                                            fontSize: 43.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                            lineHeight: 1.1,
                                          ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        10.0, 4.0, 0.0, 0.0),
                                    child: Text(
                                      FFLocalizations.of(context).getText(
                                        '4pay67d3' /* Находите новых друзей в интере... */,
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryText,
                                            fontSize: 16.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                          ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 60.0, 0.0, 0.0),
                                    child: wrapWithModel(
                                      model: _model.countryModel,
                                      updateCallback: () => safeSetState(() {}),
                                      child: CountryWidget(
                                        selected: _model.counntryNS,
                                        action: (lang) async {
                                          _model.counntryNS = lang;
                                          safeSetState(() {});
                                        },
                                      ),
                                    ),
                                  ),
                                ].addToEnd(SizedBox(height: 111.0)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: AlignmentDirectional(0.0, 1.0),
              child: Container(
                width: double.infinity,
                height: 100.0,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0x00F2F2F7),
                      FlutterFlowTheme.of(context).secondaryBackground
                    ],
                    stops: [0.0, 1.0],
                    begin: AlignmentDirectional(0.0, -1.0),
                    end: AlignmentDirectional(0, 1.0),
                  ),
                ),
                child: Align(
                  alignment: AlignmentDirectional(0.0, 1.0),
                  child: Builder(
                    builder: (context) {
                      if (_model.pageViewCurrentIndex != 4) {
                        return Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              0.0,
                              0.0,
                              0.0,
                              valueOrDefault<double>(
                                (isWeb
                                        ? MediaQuery.viewInsetsOf(context)
                                                .bottom >
                                            0
                                        : _isKeyboardVisible)
                                    ? 8.0
                                    : 35.0,
                                0.0,
                              )),
                          child: Container(
                            height: 60.0,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(100.0),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  FlutterFlowIconButton(
                                    borderRadius: 60.0,
                                    buttonSize: 56.0,
                                    fillColor: Color(0xFF2E2E2E),
                                    icon: Icon(
                                      FFIcons.karrowLeft,
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      size: 24.0,
                                    ),
                                    onPressed: (_model.pageViewCurrentIndex ==
                                            0)
                                        ? null
                                        : () async {
                                            await _model.pageViewController
                                                ?.previousPage(
                                              duration:
                                                  Duration(milliseconds: 300),
                                              curve: Curves.ease,
                                            );
                                          },
                                  ),
                                  Builder(
                                    builder: (context) {
                                      if (_model.pageViewCurrentIndex == 8) {
                                        return FlutterFlowIconButton(
                                          borderRadius: 60.0,
                                          buttonSize: 56.0,
                                          fillColor:
                                              FlutterFlowTheme.of(context)
                                                  .success,
                                          icon: Icon(
                                            Icons.check,
                                            color: Colors.black,
                                            size: 24.0,
                                          ),
                                          onPressed: () async {
                                            if (_model.counntryNS != null) {
                                              if (_model.avatarPhooto != null &&
                                                  (_model.avatarPhooto?.bytes
                                                          ?.isNotEmpty ??
                                                      false)) {
                                                {
                                                  safeSetState(() => _model
                                                          .isDataUploading_uploadDataY2w =
                                                      true);
                                                  var selectedUploadedFiles =
                                                      <FFUploadedFile>[];
                                                  var selectedMedia =
                                                      <SelectedFile>[];
                                                  var downloadUrls = <String>[];
                                                  try {
                                                    selectedUploadedFiles =
                                                        _model
                                                                .avatarPhooto!
                                                                .bytes!
                                                                .isNotEmpty
                                                            ? [
                                                                _model
                                                                    .avatarPhooto!
                                                              ]
                                                            : <FFUploadedFile>[];
                                                    selectedMedia =
                                                        selectedFilesFromUploadedFiles(
                                                      selectedUploadedFiles,
                                                    );
                                                    downloadUrls = (await Future
                                                            .wait(
                                                      selectedMedia.map(
                                                        (m) async =>
                                                            await uploadData(
                                                                m.storagePath,
                                                                m.bytes),
                                                      ),
                                                    ))
                                                        .where((u) => u != null)
                                                        .map((u) => u!)
                                                        .toList();
                                                  } finally {
                                                    _model.isDataUploading_uploadDataY2w =
                                                        false;
                                                  }
                                                  if (selectedUploadedFiles
                                                              .length ==
                                                          selectedMedia
                                                              .length &&
                                                      downloadUrls.length ==
                                                          selectedMedia
                                                              .length) {
                                                    safeSetState(() {
                                                      _model.uploadedLocalFile_uploadDataY2w =
                                                          selectedUploadedFiles
                                                              .first;
                                                      _model.uploadedFileUrl_uploadDataY2w =
                                                          downloadUrls.first;
                                                    });
                                                  } else {
                                                    safeSetState(() {});
                                                    return;
                                                  }
                                                }

                                                unawaited(
                                                  () async {
                                                    await currentUserReference!
                                                        .update({
                                                      ...createUsersRecordData(
                                                        isProfileComplete: true,
                                                        preferences:
                                                            updatePreferencesStruct(
                                                          PreferencesStruct(
                                                            preferredNativeLanguage:
                                                                _model.langNS,
                                                            preferredLocation:
                                                                _model
                                                                    .counntryNS,
                                                          ),
                                                          clearUnsetFields:
                                                              false,
                                                        ),
                                                        photoUrl: _model
                                                            .uploadedFileUrl_uploadDataY2w,
                                                        displayName: _model
                                                            .nameTextController
                                                            .text,
                                                        gender:
                                                            _model.genderMALE
                                                                ? Gender.male
                                                                : Gender.female,
                                                        level: _model.level,
                                                        acquaintance: true,
                                                        learningLanguage:
                                                            updateLanguageStruct(
                                                          _model
                                                              .selectedLangLearn,
                                                          clearUnsetFields:
                                                              false,
                                                        ),
                                                      ),
                                                      ...mapToFirestore(
                                                        {
                                                          'purpose':
                                                              _model.purpose,
                                                        },
                                                      ),
                                                    });
                                                  }(),
                                                );
                                              } else {
                                                unawaited(
                                                  () async {
                                                    await currentUserReference!
                                                        .update({
                                                      ...createUsersRecordData(
                                                        photoUrl: _model.avatar,
                                                        isProfileComplete: true,
                                                        preferences:
                                                            updatePreferencesStruct(
                                                          PreferencesStruct(
                                                            preferredNativeLanguage:
                                                                _model.langNS,
                                                            preferredLocation:
                                                                _model
                                                                    .counntryNS,
                                                          ),
                                                          clearUnsetFields:
                                                              false,
                                                        ),
                                                        displayName: _model
                                                            .nameTextController
                                                            .text,
                                                        gender:
                                                            _model.genderMALE
                                                                ? Gender.male
                                                                : Gender.female,
                                                        level: _model.level,
                                                        selectedAvatarDocRef:
                                                            _model
                                                                .selectedAvatar,
                                                        acquaintance: true,
                                                        learningLanguage:
                                                            updateLanguageStruct(
                                                          _model
                                                              .selectedLangLearn,
                                                          clearUnsetFields:
                                                              false,
                                                        ),
                                                      ),
                                                      ...mapToFirestore(
                                                        {
                                                          'purpose':
                                                              _model.purpose,
                                                        },
                                                      ),
                                                    });
                                                  }(),
                                                );
                                              }

                                              context.pushNamed(
                                                StudentsDashboardWidget
                                                    .routeName,
                                                queryParameters: {
                                                  'zn': serializeParam(
                                                    true,
                                                    ParamType.bool,
                                                  ),
                                                  'done': serializeParam(
                                                    true,
                                                    ParamType.bool,
                                                  ),
                                                }.withoutNulls,
                                              );
                                            } else {
                                              await actions.showTopNotification(
                                                context,
                                                'Выберите страну из списка',
                                                '',
                                                true,
                                              );
                                              return;
                                            }
                                          },
                                        );
                                      } else {
                                        return FlutterFlowIconButton(
                                          borderRadius: 60.0,
                                          buttonSize: 56.0,
                                          fillColor:
                                              FlutterFlowTheme.of(context)
                                                  .primaryBackground,
                                          icon: Icon(
                                            FFIcons.karrowRight,
                                            color: Colors.black,
                                            size: 24.0,
                                          ),
                                          onPressed: () async {
                                            unawaited(
                                              () async {
                                                await actions.closeKeyboard();
                                              }(),
                                            );
                                            if (_model.pageViewCurrentIndex ==
                                                0) {
                                              if (_model.nameTextController
                                                          .text !=
                                                      '') {
                                                if (!functions.isValidName(
                                                    _model.nameTextController
                                                        .text)) {
                                                  await actions
                                                      .showTopNotification(
                                                    context,
                                                    'Неверное имя',
                                                    '',
                                                    true,
                                                  );
                                                  return;
                                                }
                                              } else {
                                                await actions
                                                    .showTopNotification(
                                                  context,
                                                  'Пожалуйста, представьтесь',
                                                  '',
                                                  true,
                                                );
                                                return;
                                              }
                                            } else if (_model
                                                    .pageViewCurrentIndex ==
                                                2) {
                                              if (!(_model.selectedLangLearn !=
                                                  null)) {
                                                await actions
                                                    .showTopNotification(
                                                  context,
                                                  'Выберите язык из списка',
                                                  '',
                                                  true,
                                                );
                                                return;
                                              }
                                            } else if (_model
                                                    .pageViewCurrentIndex ==
                                                5) {
                                              if (!(_model
                                                  .purpose.isNotEmpty)) {
                                                await actions
                                                    .showTopNotification(
                                                  context,
                                                  'Выберите минимум одну цель',
                                                  '',
                                                  true,
                                                );
                                                return;
                                              }
                                            } else if (_model
                                                    .pageViewCurrentIndex ==
                                                6) {
                                              if (!((_model.avatarPhooto !=
                                                          null &&
                                                      (_model
                                                              .avatarPhooto
                                                              ?.bytes
                                                              ?.isNotEmpty ??
                                                          false)) ||
                                                  (_model.avatar != null &&
                                                      _model.avatar != ''))) {
                                                await actions
                                                    .showTopNotification(
                                                  context,
                                                  'Выберите аватар или загрузите фото',
                                                  '',
                                                  true,
                                                );
                                                return;
                                              }
                                            } else if (_model
                                                    .pageViewCurrentIndex ==
                                                7) {
                                              if (!(_model.langNS != null)) {
                                                await actions
                                                    .showTopNotification(
                                                  context,
                                                  'Выберите язык из списка',
                                                  '',
                                                  true,
                                                );
                                                return;
                                              }
                                            }

                                            await _model.pageViewController
                                                ?.nextPage(
                                              duration:
                                                  Duration(milliseconds: 300),
                                              curve: Curves.ease,
                                            );
                                          },
                                        );
                                      }
                                    },
                                  ),
                                ].divide(SizedBox(width: 2.0)),
                              ),
                            ),
                          ),
                        );
                      } else {
                        return wrapWithModel(
                          model: _model.buttonModel,
                          updateCallback: () => safeSetState(() {}),
                          child: ButtonWidget(
                            text: FFLocalizations.of(context).getText(
                              'tkv7vhn7' /* Продолжить */,
                            ),
                            action: () async {
                              await _model.pageViewController?.nextPage(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.ease,
                              );
                            },
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
