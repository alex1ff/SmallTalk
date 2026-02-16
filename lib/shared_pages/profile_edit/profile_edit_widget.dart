import '/auth/firebase_auth/auth_util.dart';
import '/authorization/components/uploud_photo/uploud_photo_widget.dart';
import '/backend/backend.dart';
import '/backend/firebase_storage/storage.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/upload_data.dart';
import '/shared_pages/edit_components/edit_about/edit_about_widget.dart';
import '/shared_pages/edit_components/edit_avatar/edit_avatar_widget.dart';
import '/shared_pages/edit_components/edit_country/edit_country_widget.dart';
import '/shared_pages/edit_components/edit_gendeer/edit_gendeer_widget.dart';
import '/shared_pages/edit_components/edit_lang/edit_lang_widget.dart';
import '/shared_pages/edit_components/edit_level/edit_level_widget.dart';
import '/shared_pages/edit_components/edit_name/edit_name_widget.dart';
import '/shared_pages/edit_components/edit_target/edit_target_widget.dart';
import '/shared_pages/nav_bar/nav_bar_widget.dart';
import '/shared_pages/profile_components/delete/delete_widget.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webviewx_plus/webviewx_plus.dart';
import 'profile_edit_model.dart';
export 'profile_edit_model.dart';

class ProfileEditWidget extends StatefulWidget {
  const ProfileEditWidget({super.key});

  static String routeName = 'Profile_edit';
  static String routePath = '/profileEdit';

  @override
  State<ProfileEditWidget> createState() => _ProfileEditWidgetState();
}

class _ProfileEditWidgetState extends State<ProfileEditWidget> {
  late ProfileEditModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ProfileEditModel());

    _model.nameTextController1 ??=
        TextEditingController(text: currentUserDisplayName);
    _model.nameFocusNode1 ??= FocusNode();

    _model.genderTextController1 ??= TextEditingController();
    _model.genderFocusNode1 ??= FocusNode();

    _model.langLTextController ??= TextEditingController();
    _model.langLFocusNode ??= FocusNode();

    _model.levelLTextController ??= TextEditingController();
    _model.levelLFocusNode ??= FocusNode();

    _model.targTextController ??= TextEditingController(
        text: (currentUserDocument?.purpose.toList() ?? []).length <= 1
            ? (currentUserDocument?.purpose.toList() ?? []).firstOrNull
            : '${(currentUserDocument?.purpose.toList() ?? []).firstOrNull}, +${((currentUserDocument?.purpose.toList() ?? []).length - 1).toString()}');
    _model.targFocusNode ??= FocusNode();

    _model.nameTextController2 ??=
        TextEditingController(text: currentUserDisplayName);
    _model.nameFocusNode2 ??= FocusNode();

    _model.genderTextController2 ??= TextEditingController();
    _model.genderFocusNode2 ??= FocusNode();

    _model.aboutTextController ??= TextEditingController(
        text: valueOrDefault(currentUserDocument?.aboutMe, ''));
    _model.aboutFocusNode ??= FocusNode();

    _model.nSLangTextController ??= TextEditingController();
    _model.nSLangFocusNode ??= FocusNode();

    _model.nSLang2TextController ??= TextEditingController();
    _model.nSLang2FocusNode ??= FocusNode();

    _model.countryNSTextController ??= TextEditingController();
    _model.countryNSFocusNode ??= FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {
          _model.genderTextController1?.text =
              FFLocalizations.of(context).getVariableText(
            ruText: currentUserDocument?.gender == Gender.male
                ? 'Мужской'
                : 'Женский',
            enText: currentUserDocument?.gender?.name,
          );
          _model.langLTextController?.text =
              FFLocalizations.of(context).getVariableText(
            ruText: currentUserDocument?.learningLanguage.nameRu,
            enText: currentUserDocument?.learningLanguage.nameEn,
          );
          _model.levelLTextController?.text =
              FFLocalizations.of(context).getVariableText(
            ruText: () {
              if (currentUserDocument?.level == Level.Beginner) {
                return 'Начальный';
              } else if (currentUserDocument?.level == Level.Basic) {
                return 'Базовый';
              } else if (currentUserDocument?.level == Level.Intermediate) {
                return 'Уверенный';
              } else {
                return 'Свободно';
              }
            }(),
            enText: currentUserDocument?.level?.name,
          );
          _model.genderTextController2?.text =
              FFLocalizations.of(context).getVariableText(
            ruText: currentUserDocument?.gender == Gender.male
                ? 'Мужской'
                : 'Женский',
            enText: currentUserDocument?.gender?.name,
          );
          _model.nSLangTextController?.text =
              FFLocalizations.of(context).getVariableText(
            ruText: currentUserDocument?.languageInstructionNS.nameRu,
            enText: currentUserDocument?.languageInstructionNS.nameEn,
          );
          _model.nSLang2TextController?.text =
              FFLocalizations.of(context).getVariableText(
            ruText: currentUserDocument?.nativeLanguageNS.nameRu,
            enText: currentUserDocument?.nativeLanguageNS.nameEn,
          );
          _model.countryNSTextController?.text =
              FFLocalizations.of(context).getVariableText(
            ruText: currentUserDocument?.countryNS.nameRu,
            enText: currentUserDocument?.countryNS.nameEn,
          );
        }));
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
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        body: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Container(
                  height: 272.28,
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color:
                              FlutterFlowTheme.of(context).secondaryBackground,
                          image: DecorationImage(
                            fit: BoxFit.cover,
                            alignment: AlignmentDirectional(0.0, -0.5),
                            image: Image.asset(
                              'assets/images/Frame_1321318897.jpg',
                            ).image,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 55.0, 0.0, 20.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Align(
                                alignment: AlignmentDirectional(-1.0, -1.0),
                                child: Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      12.0, 0.0, 0.0, 0.0),
                                  child: FlutterFlowIconButton(
                                    borderRadius: 70.0,
                                    buttonSize: 45.0,
                                    fillColor: Color(0x3CFFFFFF),
                                    icon: Icon(
                                      FFIcons.kchevronLeft,
                                      color: FlutterFlowTheme.of(context).info,
                                      size: 18.0,
                                    ),
                                    onPressed: () async {
                                      context.safePop();
                                    },
                                  ),
                                ),
                              ),
                              InkWell(
                                splashColor: Colors.transparent,
                                focusColor: Colors.transparent,
                                hoverColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                onTap: () async {
                                  if (currentUserDocument?.role ==
                                      UserRole.student) {
                                    await showModalBottomSheet(
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      context: context,
                                      builder: (context) {
                                        return WebViewAware(
                                          child: GestureDetector(
                                            onTap: () {
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child: EditAvatarWidget(
                                                action: () async {
                                                  safeSetState(() {});
                                                },
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ).then((value) => safeSetState(() {}));
                                  } else {
                                    await showModalBottomSheet(
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      context: context,
                                      builder: (context) {
                                        return WebViewAware(
                                          child: GestureDetector(
                                            onTap: () {
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child: UploudPhotoWidget(
                                                action: (upl) async {
                                                  {
                                                    safeSetState(() => _model
                                                            .isDataUploading_uploadData4bs =
                                                        true);
                                                    var selectedUploadedFiles =
                                                        <FFUploadedFile>[];
                                                    var selectedMedia =
                                                        <SelectedFile>[];
                                                    var downloadUrls =
                                                        <String>[];
                                                    try {
                                                      selectedUploadedFiles = upl
                                                              .bytes!.isNotEmpty
                                                          ? [upl]
                                                          : <FFUploadedFile>[];
                                                      selectedMedia =
                                                          selectedFilesFromUploadedFiles(
                                                        selectedUploadedFiles,
                                                      );
                                                      downloadUrls =
                                                          (await Future.wait(
                                                        selectedMedia.map(
                                                          (m) async =>
                                                              await uploadData(
                                                                  m.storagePath,
                                                                  m.bytes),
                                                        ),
                                                      ))
                                                              .where((u) =>
                                                                  u != null)
                                                              .map((u) => u!)
                                                              .toList();
                                                    } finally {
                                                      _model.isDataUploading_uploadData4bs =
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
                                                        _model.uploadedLocalFile_uploadData4bs =
                                                            selectedUploadedFiles
                                                                .first;
                                                        _model.uploadedFileUrl_uploadData4bs =
                                                            downloadUrls.first;
                                                      });
                                                    } else {
                                                      safeSetState(() {});
                                                      return;
                                                    }
                                                  }

                                                  await currentUserReference!
                                                      .update(
                                                          createUsersRecordData(
                                                    photoUrl: _model
                                                        .uploadedFileUrl_uploadData4bs,
                                                  ));
                                                  safeSetState(() {});
                                                },
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ).then((value) => safeSetState(() {}));
                                  }
                                },
                                child: Stack(
                                  children: [
                                    AuthUserStreamWidget(
                                      builder: (context) => ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(100.0),
                                        child: CachedNetworkImage(
                                          imageUrl: currentUserPhoto,
                                          width: 130.0,
                                          height: 130.0,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              const SizedBox.shrink(),
                                          errorWidget: (context, url, error) =>
                                              Icon(Icons.person,
                                                  size: 24,
                                                  color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 130.0,
                                      height: 130.0,
                                      decoration: BoxDecoration(
                                        color: Color(0x5A000000),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                        ),
                                      ),
                                      child: Icon(
                                        FFIcons.kcameraPlus,
                                        color: Colors.white,
                                        size: 24.0,
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
                        alignment: AlignmentDirectional(0.0, 1.0),
                        child: Container(
                          width: double.infinity,
                          height: 20.0,
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(0.0),
                              bottomRight: Radius.circular(0.0),
                              topLeft: Radius.circular(20.0),
                              topRight: Radius.circular(20.0),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (currentUserDocument?.role == UserRole.student) {
                        return Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              6.0, 0.0, 6.0, 0.0),
                          child: SingleChildScrollView(
                            primary: false,
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                InkWell(
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
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child: EditNameWidget(
                                                action: (name) async {
                                                  safeSetState(() {
                                                    _model.nameTextController1
                                                        ?.text = name;
                                                  });
                                                },
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ).then((value) => safeSetState(() {}));
                                  },
                                  child: Stack(
                                    children: [
                                      Container(
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
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryBackground,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Align(
                                                  alignment:
                                                      AlignmentDirectional(
                                                          0.0, 0.0),
                                                  child: Icon(
                                                    FFIcons.kuser03,
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primaryText,
                                                    size: 20.0,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Padding(
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(
                                                          8.0, 0.0, 8.0, 0.0),
                                                  child: Container(
                                                    width: double.infinity,
                                                    child: TextFormField(
                                                      controller: _model
                                                          .nameTextController1,
                                                      focusNode:
                                                          _model.nameFocusNode1,
                                                      autofocus: false,
                                                      textCapitalization:
                                                          TextCapitalization
                                                              .none,
                                                      obscureText: false,
                                                      decoration:
                                                          InputDecoration(
                                                        isDense: false,
                                                        labelText:
                                                            FFLocalizations.of(
                                                                    context)
                                                                .getText(
                                                          'hpktm3z3' /* Ваше имя */,
                                                        ),
                                                        labelStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .override(
                                                                  fontFamily:
                                                                      'sf pro display',
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondaryText,
                                                                  fontSize:
                                                                      16.0,
                                                                  letterSpacing:
                                                                      0.0,
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
                                                      style: FlutterFlowTheme
                                                              .of(context)
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
                                                          .nameTextController1Validator
                                                          .asValidator(context),
                                                      inputFormatters: [
                                                        if (!isAndroid &&
                                                            !isiOS)
                                                          TextInputFormatter
                                                              .withFunction(
                                                                  (oldValue,
                                                                      newValue) {
                                                            return TextEditingValue(
                                                              selection: newValue
                                                                  .selection,
                                                              text: newValue
                                                                  .text
                                                                  .toCapitalization(
                                                                      TextCapitalization
                                                                          .none),
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
                                      Container(
                                        width: double.infinity,
                                        height: 60.0,
                                        decoration: BoxDecoration(),
                                      ),
                                    ],
                                  ),
                                ),
                                InkWell(
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
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child: EditGendeerWidget(
                                                action: (gender) async {
                                                  safeSetState(() {
                                                    _model.genderTextController1
                                                            ?.text =
                                                        FFLocalizations.of(
                                                                context)
                                                            .getVariableText(
                                                      ruText:
                                                          gender == Gender.male
                                                              ? 'Мужской'
                                                              : 'Женский',
                                                      enText: gender.name,
                                                    );
                                                  });
                                                },
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ).then((value) => safeSetState(() {}));
                                  },
                                  child: Stack(
                                    children: [
                                      Container(
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
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryBackground,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Align(
                                                  alignment:
                                                      AlignmentDirectional(
                                                          0.0, 0.0),
                                                  child: Icon(
                                                    FFIcons.kusers02,
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primaryText,
                                                    size: 20.0,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Padding(
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(
                                                          8.0, 0.0, 8.0, 0.0),
                                                  child: Container(
                                                    width: double.infinity,
                                                    child: TextFormField(
                                                      controller: _model
                                                          .genderTextController1,
                                                      focusNode: _model
                                                          .genderFocusNode1,
                                                      autofocus: false,
                                                      textCapitalization:
                                                          TextCapitalization
                                                              .none,
                                                      obscureText: false,
                                                      decoration:
                                                          InputDecoration(
                                                        isDense: false,
                                                        labelText:
                                                            FFLocalizations.of(
                                                                    context)
                                                                .getText(
                                                          'qupouufi' /* Пол */,
                                                        ),
                                                        labelStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .override(
                                                                  fontFamily:
                                                                      'sf pro display',
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondaryText,
                                                                  fontSize:
                                                                      16.0,
                                                                  letterSpacing:
                                                                      0.0,
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
                                                      style: FlutterFlowTheme
                                                              .of(context)
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
                                                          .genderTextController1Validator
                                                          .asValidator(context),
                                                      inputFormatters: [
                                                        if (!isAndroid &&
                                                            !isiOS)
                                                          TextInputFormatter
                                                              .withFunction(
                                                                  (oldValue,
                                                                      newValue) {
                                                            return TextEditingValue(
                                                              selection: newValue
                                                                  .selection,
                                                              text: newValue
                                                                  .text
                                                                  .toCapitalization(
                                                                      TextCapitalization
                                                                          .none),
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
                                      Container(
                                        width: double.infinity,
                                        height: 60.0,
                                        decoration: BoxDecoration(),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Expanded(
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
                                                    child: EditLangWidget(
                                                      selected:
                                                          currentUserDocument!
                                                              .learningLanguage,
                                                      title: FFLocalizations.of(
                                                              context)
                                                          .getText(
                                                        's0mfbo2b' /* Язык изучения */,
                                                      ),
                                                      action: (lang) async {
                                                        unawaited(
                                                          () async {
                                                            await currentUserReference!
                                                                .update(
                                                                    createUsersRecordData(
                                                              learningLanguage:
                                                                  updateLanguageStruct(
                                                                lang,
                                                                clearUnsetFields:
                                                                    false,
                                                              ),
                                                            ));
                                                          }(),
                                                        );
                                                        safeSetState(() {
                                                          _model.langLTextController
                                                                  ?.text =
                                                              FFLocalizations.of(
                                                                      context)
                                                                  .getVariableText(
                                                            ruText: lang.nameRu,
                                                            enText: lang.nameEn,
                                                          );
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ).then(
                                              (value) => safeSetState(() {}));
                                        },
                                        child: Stack(
                                          children: [
                                            Container(
                                              width: double.infinity,
                                              height: 60.0,
                                              decoration: BoxDecoration(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryBackground,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        100.0),
                                              ),
                                              child: Padding(
                                                padding: EdgeInsets.all(2.0),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  children: [
                                                    Container(
                                                      width: 56.0,
                                                      height: 56.0,
                                                      decoration: BoxDecoration(
                                                        color: FlutterFlowTheme
                                                                .of(context)
                                                            .secondaryBackground,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Align(
                                                        alignment:
                                                            AlignmentDirectional(
                                                                0.0, 0.0),
                                                        child: Icon(
                                                          FFIcons.ktranslate01,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryText,
                                                          size: 20.0,
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Padding(
                                                        padding:
                                                            EdgeInsetsDirectional
                                                                .fromSTEB(
                                                                    8.0,
                                                                    0.0,
                                                                    0.0,
                                                                    0.0),
                                                        child: Container(
                                                          width:
                                                              double.infinity,
                                                          child: TextFormField(
                                                            controller: _model
                                                                .langLTextController,
                                                            focusNode: _model
                                                                .langLFocusNode,
                                                            autofocus: false,
                                                            textCapitalization:
                                                                TextCapitalization
                                                                    .none,
                                                            obscureText: false,
                                                            decoration:
                                                                InputDecoration(
                                                              isDense: false,
                                                              labelText:
                                                                  FFLocalizations.of(
                                                                          context)
                                                                      .getText(
                                                                'ro4cvtou' /* Язык изучения */,
                                                              ),
                                                              labelStyle:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .override(
                                                                        fontFamily:
                                                                            'sf pro display',
                                                                        color: FlutterFlowTheme.of(context)
                                                                            .secondaryText,
                                                                        fontSize:
                                                                            16.0,
                                                                        letterSpacing:
                                                                            0.0,
                                                                      ),
                                                              enabledBorder:
                                                                  InputBorder
                                                                      .none,
                                                              focusedBorder:
                                                                  InputBorder
                                                                      .none,
                                                              errorBorder:
                                                                  InputBorder
                                                                      .none,
                                                              focusedErrorBorder:
                                                                  InputBorder
                                                                      .none,
                                                            ),
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .bodyMedium
                                                                .override(
                                                                  fontFamily:
                                                                      'sf pro display',
                                                                  fontSize:
                                                                      16.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                ),
                                                            cursorColor:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryText,
                                                            enableInteractiveSelection:
                                                                true,
                                                            validator: _model
                                                                .langLTextControllerValidator
                                                                .asValidator(
                                                                    context),
                                                            inputFormatters: [
                                                              if (!isAndroid &&
                                                                  !isiOS)
                                                                TextInputFormatter
                                                                    .withFunction(
                                                                        (oldValue,
                                                                            newValue) {
                                                                  return TextEditingValue(
                                                                    selection:
                                                                        newValue
                                                                            .selection,
                                                                    text: newValue
                                                                        .text
                                                                        .toCapitalization(
                                                                            TextCapitalization.none),
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
                                            Container(
                                              width: double.infinity,
                                              height: 60.0,
                                              decoration: BoxDecoration(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Expanded(
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
                                                    child: EditLevelWidget(
                                                      action: (lang) async {
                                                        safeSetState(() {
                                                          _model.levelLTextController
                                                                  ?.text =
                                                              FFLocalizations.of(
                                                                      context)
                                                                  .getVariableText(
                                                            ruText: () {
                                                              if (lang ==
                                                                  Level
                                                                      .Beginner) {
                                                                return 'Начальный';
                                                              } else if (lang ==
                                                                  Level.Basic) {
                                                                return 'Базовый';
                                                              } else if (lang ==
                                                                  Level
                                                                      .Intermediate) {
                                                                return 'Уверенный';
                                                              } else {
                                                                return 'Свободно';
                                                              }
                                                            }(),
                                                            enText: lang.name,
                                                          );
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ).then(
                                              (value) => safeSetState(() {}));
                                        },
                                        child: Stack(
                                          children: [
                                            Container(
                                              width: double.infinity,
                                              height: 60.0,
                                              decoration: BoxDecoration(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryBackground,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        100.0),
                                              ),
                                              child: Padding(
                                                padding: EdgeInsets.all(2.0),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  children: [
                                                    Container(
                                                      width: 56.0,
                                                      height: 56.0,
                                                      decoration: BoxDecoration(
                                                        color: FlutterFlowTheme
                                                                .of(context)
                                                            .secondaryBackground,
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Align(
                                                        alignment:
                                                            AlignmentDirectional(
                                                                0.0, 0.0),
                                                        child: Icon(
                                                          FFIcons
                                                              .kgraduationHat02,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryText,
                                                          size: 20.0,
                                                        ),
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Padding(
                                                        padding:
                                                            EdgeInsetsDirectional
                                                                .fromSTEB(
                                                                    8.0,
                                                                    0.0,
                                                                    8.0,
                                                                    0.0),
                                                        child: Container(
                                                          width:
                                                              double.infinity,
                                                          child: TextFormField(
                                                            controller: _model
                                                                .levelLTextController,
                                                            focusNode: _model
                                                                .levelLFocusNode,
                                                            autofocus: false,
                                                            textCapitalization:
                                                                TextCapitalization
                                                                    .none,
                                                            obscureText: false,
                                                            decoration:
                                                                InputDecoration(
                                                              isDense: false,
                                                              labelText:
                                                                  FFLocalizations.of(
                                                                          context)
                                                                      .getText(
                                                                'bo9k12fd' /* Уровень */,
                                                              ),
                                                              labelStyle:
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .override(
                                                                        fontFamily:
                                                                            'sf pro display',
                                                                        color: FlutterFlowTheme.of(context)
                                                                            .secondaryText,
                                                                        fontSize:
                                                                            16.0,
                                                                        letterSpacing:
                                                                            0.0,
                                                                      ),
                                                              enabledBorder:
                                                                  InputBorder
                                                                      .none,
                                                              focusedBorder:
                                                                  InputBorder
                                                                      .none,
                                                              errorBorder:
                                                                  InputBorder
                                                                      .none,
                                                              focusedErrorBorder:
                                                                  InputBorder
                                                                      .none,
                                                            ),
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .bodyMedium
                                                                .override(
                                                                  fontFamily:
                                                                      'sf pro display',
                                                                  fontSize:
                                                                      16.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                ),
                                                            cursorColor:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryText,
                                                            enableInteractiveSelection:
                                                                true,
                                                            validator: _model
                                                                .levelLTextControllerValidator
                                                                .asValidator(
                                                                    context),
                                                            inputFormatters: [
                                                              if (!isAndroid &&
                                                                  !isiOS)
                                                                TextInputFormatter
                                                                    .withFunction(
                                                                        (oldValue,
                                                                            newValue) {
                                                                  return TextEditingValue(
                                                                    selection:
                                                                        newValue
                                                                            .selection,
                                                                    text: newValue
                                                                        .text
                                                                        .toCapitalization(
                                                                            TextCapitalization.none),
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
                                            Container(
                                              width: double.infinity,
                                              height: 60.0,
                                              decoration: BoxDecoration(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ].divide(SizedBox(width: 4.0)),
                                ),
                                InkWell(
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
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child: EditTargetWidget(
                                                action: (targ) async {
                                                  safeSetState(() {
                                                    _model.targTextController
                                                        ?.text = targ;
                                                  });
                                                },
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ).then((value) => safeSetState(() {}));
                                  },
                                  child: Stack(
                                    children: [
                                      Container(
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
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryBackground,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Align(
                                                  alignment:
                                                      AlignmentDirectional(
                                                          0.0, 0.0),
                                                  child: Icon(
                                                    FFIcons.ktarget04,
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primaryText,
                                                    size: 20.0,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Padding(
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(
                                                          8.0, 0.0, 8.0, 0.0),
                                                  child: Container(
                                                    width: double.infinity,
                                                    child: TextFormField(
                                                      controller: _model
                                                          .targTextController,
                                                      focusNode:
                                                          _model.targFocusNode,
                                                      autofocus: false,
                                                      textCapitalization:
                                                          TextCapitalization
                                                              .none,
                                                      obscureText: false,
                                                      decoration:
                                                          InputDecoration(
                                                        isDense: false,
                                                        labelText:
                                                            FFLocalizations.of(
                                                                    context)
                                                                .getText(
                                                          '3um2nt3q' /* Цели изучения */,
                                                        ),
                                                        labelStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .override(
                                                                  fontFamily:
                                                                      'sf pro display',
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondaryText,
                                                                  fontSize:
                                                                      16.0,
                                                                  letterSpacing:
                                                                      0.0,
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
                                                      style: FlutterFlowTheme
                                                              .of(context)
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
                                                          .targTextControllerValidator
                                                          .asValidator(context),
                                                      inputFormatters: [
                                                        if (!isAndroid &&
                                                            !isiOS)
                                                          TextInputFormatter
                                                              .withFunction(
                                                                  (oldValue,
                                                                      newValue) {
                                                            return TextEditingValue(
                                                              selection: newValue
                                                                  .selection,
                                                              text: newValue
                                                                  .text
                                                                  .toCapitalization(
                                                                      TextCapitalization
                                                                          .none),
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
                                      Container(
                                        width: double.infinity,
                                        height: 60.0,
                                        decoration: BoxDecoration(),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 16.0, 0.0, 0.0),
                                  child: FFButtonWidget(
                                    onPressed: () async {
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
                                                child: DeleteWidget(),
                                              ),
                                            ),
                                          );
                                        },
                                      ).then((value) => safeSetState(() {}));
                                    },
                                    text: FFLocalizations.of(context).getText(
                                      'fjpaay9n' /* Delete Account */,
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
                                            color: FlutterFlowTheme.of(context)
                                                .error,
                                            fontSize: 15.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.w500,
                                          ),
                                      elevation: 0.0,
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    showLoadingIndicator: false,
                                  ),
                                ),
                              ]
                                  .divide(SizedBox(height: 6.0))
                                  .addToEnd(SizedBox(height: 100.0)),
                            ),
                          ),
                        );
                      } else {
                        return Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              6.0, 0.0, 6.0, 0.0),
                          child: SingleChildScrollView(
                            primary: false,
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                InkWell(
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
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child: EditNameWidget(
                                                action: (name) async {
                                                  safeSetState(() {
                                                    _model.nameTextController2
                                                        ?.text = name;
                                                  });
                                                },
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ).then((value) => safeSetState(() {}));
                                  },
                                  child: Stack(
                                    children: [
                                      Container(
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
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryBackground,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Align(
                                                  alignment:
                                                      AlignmentDirectional(
                                                          0.0, 0.0),
                                                  child: Icon(
                                                    FFIcons.kuser03,
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primaryText,
                                                    size: 20.0,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Padding(
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(
                                                          8.0, 0.0, 8.0, 0.0),
                                                  child: AuthUserStreamWidget(
                                                    builder: (context) =>
                                                        Container(
                                                      width: double.infinity,
                                                      child: TextFormField(
                                                        controller: _model
                                                            .nameTextController2,
                                                        focusNode: _model
                                                            .nameFocusNode2,
                                                        autofocus: false,
                                                        textCapitalization:
                                                            TextCapitalization
                                                                .none,
                                                        obscureText: false,
                                                        decoration:
                                                            InputDecoration(
                                                          isDense: false,
                                                          labelText:
                                                              FFLocalizations.of(
                                                                      context)
                                                                  .getText(
                                                            'mx59qpmr' /* Ваше имя */,
                                                          ),
                                                          labelStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .override(
                                                                    fontFamily:
                                                                        'sf pro display',
                                                                    color: FlutterFlowTheme.of(
                                                                            context)
                                                                        .secondaryText,
                                                                    fontSize:
                                                                        16.0,
                                                                    letterSpacing:
                                                                        0.0,
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
                                                        style: FlutterFlowTheme
                                                                .of(context)
                                                            .bodyMedium
                                                            .override(
                                                              fontFamily:
                                                                  'sf pro display',
                                                              fontSize: 16.0,
                                                              letterSpacing:
                                                                  0.0,
                                                            ),
                                                        cursorColor:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryText,
                                                        enableInteractiveSelection:
                                                            true,
                                                        validator: _model
                                                            .nameTextController2Validator
                                                            .asValidator(
                                                                context),
                                                        inputFormatters: [
                                                          if (!isAndroid &&
                                                              !isiOS)
                                                            TextInputFormatter
                                                                .withFunction(
                                                                    (oldValue,
                                                                        newValue) {
                                                              return TextEditingValue(
                                                                selection: newValue
                                                                    .selection,
                                                                text: newValue
                                                                    .text
                                                                    .toCapitalization(
                                                                        TextCapitalization
                                                                            .none),
                                                              );
                                                            }),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: double.infinity,
                                        height: 60.0,
                                        decoration: BoxDecoration(),
                                      ),
                                    ],
                                  ),
                                ),
                                InkWell(
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
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child: EditGendeerWidget(
                                                action: (gender) async {
                                                  safeSetState(() {
                                                    _model.genderTextController2
                                                            ?.text =
                                                        FFLocalizations.of(
                                                                context)
                                                            .getVariableText(
                                                      ruText:
                                                          gender == Gender.male
                                                              ? 'Мужской'
                                                              : 'Женский',
                                                      enText: gender.name,
                                                    );
                                                  });
                                                },
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ).then((value) => safeSetState(() {}));
                                  },
                                  child: Stack(
                                    children: [
                                      Container(
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
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryBackground,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Align(
                                                  alignment:
                                                      AlignmentDirectional(
                                                          0.0, 0.0),
                                                  child: Icon(
                                                    FFIcons.kusers02,
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primaryText,
                                                    size: 20.0,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Padding(
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(
                                                          8.0, 0.0, 8.0, 0.0),
                                                  child: AuthUserStreamWidget(
                                                    builder: (context) =>
                                                        Container(
                                                      width: double.infinity,
                                                      child: TextFormField(
                                                        controller: _model
                                                            .genderTextController2,
                                                        focusNode: _model
                                                            .genderFocusNode2,
                                                        autofocus: false,
                                                        textCapitalization:
                                                            TextCapitalization
                                                                .none,
                                                        obscureText: false,
                                                        decoration:
                                                            InputDecoration(
                                                          isDense: false,
                                                          labelText:
                                                              FFLocalizations.of(
                                                                      context)
                                                                  .getText(
                                                            '2kk34veu' /* Пол */,
                                                          ),
                                                          labelStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .override(
                                                                    fontFamily:
                                                                        'sf pro display',
                                                                    color: FlutterFlowTheme.of(
                                                                            context)
                                                                        .secondaryText,
                                                                    fontSize:
                                                                        16.0,
                                                                    letterSpacing:
                                                                        0.0,
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
                                                        style: FlutterFlowTheme
                                                                .of(context)
                                                            .bodyMedium
                                                            .override(
                                                              fontFamily:
                                                                  'sf pro display',
                                                              fontSize: 16.0,
                                                              letterSpacing:
                                                                  0.0,
                                                            ),
                                                        cursorColor:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryText,
                                                        enableInteractiveSelection:
                                                            true,
                                                        validator: _model
                                                            .genderTextController2Validator
                                                            .asValidator(
                                                                context),
                                                        inputFormatters: [
                                                          if (!isAndroid &&
                                                              !isiOS)
                                                            TextInputFormatter
                                                                .withFunction(
                                                                    (oldValue,
                                                                        newValue) {
                                                              return TextEditingValue(
                                                                selection: newValue
                                                                    .selection,
                                                                text: newValue
                                                                    .text
                                                                    .toCapitalization(
                                                                        TextCapitalization
                                                                            .none),
                                                              );
                                                            }),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: double.infinity,
                                        height: 60.0,
                                        decoration: BoxDecoration(),
                                      ),
                                    ],
                                  ),
                                ),
                                InkWell(
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
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child: EditAboutWidget(
                                                action: (name) async {
                                                  safeSetState(() {
                                                    _model.aboutTextController
                                                        ?.text = name;
                                                  });
                                                },
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ).then((value) => safeSetState(() {}));
                                  },
                                  child: Stack(
                                    children: [
                                      Container(
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
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryBackground,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Align(
                                                  alignment:
                                                      AlignmentDirectional(
                                                          0.0, 0.0),
                                                  child: Icon(
                                                    FFIcons.kfile02,
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primaryText,
                                                    size: 20.0,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Padding(
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(
                                                          8.0, 0.0, 8.0, 0.0),
                                                  child: AuthUserStreamWidget(
                                                    builder: (context) =>
                                                        Container(
                                                      width: double.infinity,
                                                      child: TextFormField(
                                                        controller: _model
                                                            .aboutTextController,
                                                        focusNode: _model
                                                            .aboutFocusNode,
                                                        autofocus: false,
                                                        textCapitalization:
                                                            TextCapitalization
                                                                .none,
                                                        obscureText: false,
                                                        decoration:
                                                            InputDecoration(
                                                          isDense: false,
                                                          labelText:
                                                              FFLocalizations.of(
                                                                      context)
                                                                  .getText(
                                                            '53sloz8g' /* О себе */,
                                                          ),
                                                          labelStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .override(
                                                                    fontFamily:
                                                                        'sf pro display',
                                                                    color: FlutterFlowTheme.of(
                                                                            context)
                                                                        .secondaryText,
                                                                    fontSize:
                                                                        16.0,
                                                                    letterSpacing:
                                                                        0.0,
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
                                                        style: FlutterFlowTheme
                                                                .of(context)
                                                            .bodyMedium
                                                            .override(
                                                              fontFamily:
                                                                  'sf pro display',
                                                              fontSize: 16.0,
                                                              letterSpacing:
                                                                  0.0,
                                                            ),
                                                        cursorColor:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryText,
                                                        enableInteractiveSelection:
                                                            true,
                                                        validator: _model
                                                            .aboutTextControllerValidator
                                                            .asValidator(
                                                                context),
                                                        inputFormatters: [
                                                          if (!isAndroid &&
                                                              !isiOS)
                                                            TextInputFormatter
                                                                .withFunction(
                                                                    (oldValue,
                                                                        newValue) {
                                                              return TextEditingValue(
                                                                selection: newValue
                                                                    .selection,
                                                                text: newValue
                                                                    .text
                                                                    .toCapitalization(
                                                                        TextCapitalization
                                                                            .none),
                                                              );
                                                            }),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: double.infinity,
                                        height: 60.0,
                                        decoration: BoxDecoration(),
                                      ),
                                    ],
                                  ),
                                ),
                                InkWell(
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
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child: EditLangWidget(
                                                selected: currentUserDocument!
                                                    .languageInstructionNS,
                                                title:
                                                    FFLocalizations.of(context)
                                                        .getText(
                                                  '5s3nn50b' /* Язык, которому обучаю */,
                                                ),
                                                action: (lang) async {
                                                  unawaited(
                                                    () async {
                                                      await currentUserReference!
                                                          .update(
                                                              createUsersRecordData(
                                                        languageInstructionNS:
                                                            updateLanguageStruct(
                                                          lang,
                                                          clearUnsetFields:
                                                              false,
                                                        ),
                                                      ));
                                                    }(),
                                                  );
                                                  safeSetState(() {
                                                    _model.nSLangTextController
                                                            ?.text =
                                                        FFLocalizations.of(
                                                                context)
                                                            .getVariableText(
                                                      ruText: lang.nameRu,
                                                      enText: lang.nameEn,
                                                    );
                                                  });
                                                },
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ).then((value) => safeSetState(() {}));
                                  },
                                  child: Stack(
                                    children: [
                                      Container(
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
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryBackground,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Align(
                                                  alignment:
                                                      AlignmentDirectional(
                                                          0.0, 0.0),
                                                  child: Icon(
                                                    FFIcons.ktranslate01,
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primaryText,
                                                    size: 20.0,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Padding(
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(
                                                          8.0, 0.0, 0.0, 0.0),
                                                  child: AuthUserStreamWidget(
                                                    builder: (context) =>
                                                        Container(
                                                      width: double.infinity,
                                                      child: TextFormField(
                                                        controller: _model
                                                            .nSLangTextController,
                                                        focusNode: _model
                                                            .nSLangFocusNode,
                                                        autofocus: false,
                                                        textCapitalization:
                                                            TextCapitalization
                                                                .none,
                                                        obscureText: false,
                                                        decoration:
                                                            InputDecoration(
                                                          isDense: false,
                                                          labelText:
                                                              FFLocalizations.of(
                                                                      context)
                                                                  .getText(
                                                            '0xkn8sut' /* Язык, которому обучаю */,
                                                          ),
                                                          labelStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .override(
                                                                    fontFamily:
                                                                        'sf pro display',
                                                                    color: FlutterFlowTheme.of(
                                                                            context)
                                                                        .secondaryText,
                                                                    fontSize:
                                                                        16.0,
                                                                    letterSpacing:
                                                                        0.0,
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
                                                        style: FlutterFlowTheme
                                                                .of(context)
                                                            .bodyMedium
                                                            .override(
                                                              fontFamily:
                                                                  'sf pro display',
                                                              fontSize: 16.0,
                                                              letterSpacing:
                                                                  0.0,
                                                            ),
                                                        cursorColor:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryText,
                                                        enableInteractiveSelection:
                                                            true,
                                                        validator: _model
                                                            .nSLangTextControllerValidator
                                                            .asValidator(
                                                                context),
                                                        inputFormatters: [
                                                          if (!isAndroid &&
                                                              !isiOS)
                                                            TextInputFormatter
                                                                .withFunction(
                                                                    (oldValue,
                                                                        newValue) {
                                                              return TextEditingValue(
                                                                selection: newValue
                                                                    .selection,
                                                                text: newValue
                                                                    .text
                                                                    .toCapitalization(
                                                                        TextCapitalization
                                                                            .none),
                                                              );
                                                            }),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: double.infinity,
                                        height: 60.0,
                                        decoration: BoxDecoration(),
                                      ),
                                    ],
                                  ),
                                ),
                                InkWell(
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
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child: EditLangWidget(
                                                selected: currentUserDocument!
                                                    .languageInstructionNS,
                                                title:
                                                    FFLocalizations.of(context)
                                                        .getText(
                                                  'sw9i9e2p' /* Мой язык */,
                                                ),
                                                action: (lang) async {
                                                  unawaited(
                                                    () async {
                                                      await currentUserReference!
                                                          .update(
                                                              createUsersRecordData(
                                                        nativeLanguageNS:
                                                            updateLanguageStruct(
                                                          lang,
                                                          clearUnsetFields:
                                                              false,
                                                        ),
                                                      ));
                                                    }(),
                                                  );
                                                  safeSetState(() {
                                                    _model.nSLang2TextController
                                                            ?.text =
                                                        FFLocalizations.of(
                                                                context)
                                                            .getVariableText(
                                                      ruText: lang.nameRu,
                                                      enText: lang.nameEn,
                                                    );
                                                  });
                                                },
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ).then((value) => safeSetState(() {}));
                                  },
                                  child: Stack(
                                    children: [
                                      Container(
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
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryBackground,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Align(
                                                  alignment:
                                                      AlignmentDirectional(
                                                          0.0, 0.0),
                                                  child: Icon(
                                                    FFIcons.ktranslate01,
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primaryText,
                                                    size: 20.0,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Padding(
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(
                                                          8.0, 0.0, 0.0, 0.0),
                                                  child: AuthUserStreamWidget(
                                                    builder: (context) =>
                                                        Container(
                                                      width: double.infinity,
                                                      child: TextFormField(
                                                        controller: _model
                                                            .nSLang2TextController,
                                                        focusNode: _model
                                                            .nSLang2FocusNode,
                                                        autofocus: false,
                                                        textCapitalization:
                                                            TextCapitalization
                                                                .none,
                                                        obscureText: false,
                                                        decoration:
                                                            InputDecoration(
                                                          isDense: false,
                                                          labelText:
                                                              FFLocalizations.of(
                                                                      context)
                                                                  .getText(
                                                            'vi9zv6jp' /* Мой язык */,
                                                          ),
                                                          labelStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .override(
                                                                    fontFamily:
                                                                        'sf pro display',
                                                                    color: FlutterFlowTheme.of(
                                                                            context)
                                                                        .secondaryText,
                                                                    fontSize:
                                                                        16.0,
                                                                    letterSpacing:
                                                                        0.0,
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
                                                        style: FlutterFlowTheme
                                                                .of(context)
                                                            .bodyMedium
                                                            .override(
                                                              fontFamily:
                                                                  'sf pro display',
                                                              fontSize: 16.0,
                                                              letterSpacing:
                                                                  0.0,
                                                            ),
                                                        cursorColor:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryText,
                                                        enableInteractiveSelection:
                                                            true,
                                                        validator: _model
                                                            .nSLang2TextControllerValidator
                                                            .asValidator(
                                                                context),
                                                        inputFormatters: [
                                                          if (!isAndroid &&
                                                              !isiOS)
                                                            TextInputFormatter
                                                                .withFunction(
                                                                    (oldValue,
                                                                        newValue) {
                                                              return TextEditingValue(
                                                                selection: newValue
                                                                    .selection,
                                                                text: newValue
                                                                    .text
                                                                    .toCapitalization(
                                                                        TextCapitalization
                                                                            .none),
                                                              );
                                                            }),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: double.infinity,
                                        height: 60.0,
                                        decoration: BoxDecoration(),
                                      ),
                                    ],
                                  ),
                                ),
                                InkWell(
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
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child: EditCountryWidget(
                                                title:
                                                    FFLocalizations.of(context)
                                                        .getText(
                                                  'potevt0c' /* Где вы сейчас находитесь? */,
                                                ),
                                                selecte: currentUserDocument!
                                                    .countryNS,
                                                action: (lang) async {
                                                  safeSetState(() {
                                                    _model
                                                        .countryNSTextController
                                                        ?.text = FFLocalizations
                                                            .of(context)
                                                        .getVariableText(
                                                      ruText: lang.nameRu,
                                                      enText: lang.nameEn,
                                                    );
                                                  });
                                                },
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ).then((value) => safeSetState(() {}));
                                  },
                                  child: Stack(
                                    children: [
                                      Container(
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
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryBackground,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Align(
                                                  alignment:
                                                      AlignmentDirectional(
                                                          0.0, 0.0),
                                                  child: Icon(
                                                    FFIcons.kglobe01,
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primaryText,
                                                    size: 20.0,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Padding(
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(
                                                          8.0, 0.0, 8.0, 0.0),
                                                  child: AuthUserStreamWidget(
                                                    builder: (context) =>
                                                        Container(
                                                      width: double.infinity,
                                                      child: TextFormField(
                                                        controller: _model
                                                            .countryNSTextController,
                                                        focusNode: _model
                                                            .countryNSFocusNode,
                                                        autofocus: false,
                                                        textCapitalization:
                                                            TextCapitalization
                                                                .none,
                                                        obscureText: false,
                                                        decoration:
                                                            InputDecoration(
                                                          isDense: false,
                                                          labelText:
                                                              FFLocalizations.of(
                                                                      context)
                                                                  .getText(
                                                            'kem0gdl9' /* Страна */,
                                                          ),
                                                          labelStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .override(
                                                                    fontFamily:
                                                                        'sf pro display',
                                                                    color: FlutterFlowTheme.of(
                                                                            context)
                                                                        .secondaryText,
                                                                    fontSize:
                                                                        16.0,
                                                                    letterSpacing:
                                                                        0.0,
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
                                                        style: FlutterFlowTheme
                                                                .of(context)
                                                            .bodyMedium
                                                            .override(
                                                              fontFamily:
                                                                  'sf pro display',
                                                              fontSize: 16.0,
                                                              letterSpacing:
                                                                  0.0,
                                                            ),
                                                        cursorColor:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryText,
                                                        enableInteractiveSelection:
                                                            true,
                                                        validator: _model
                                                            .countryNSTextControllerValidator
                                                            .asValidator(
                                                                context),
                                                        inputFormatters: [
                                                          if (!isAndroid &&
                                                              !isiOS)
                                                            TextInputFormatter
                                                                .withFunction(
                                                                    (oldValue,
                                                                        newValue) {
                                                              return TextEditingValue(
                                                                selection: newValue
                                                                    .selection,
                                                                text: newValue
                                                                    .text
                                                                    .toCapitalization(
                                                                        TextCapitalization
                                                                            .none),
                                                              );
                                                            }),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: double.infinity,
                                        height: 60.0,
                                        decoration: BoxDecoration(),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 16.0, 0.0, 0.0),
                                  child: FFButtonWidget(
                                    onPressed: () async {
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
                                                child: DeleteWidget(),
                                              ),
                                            ),
                                          );
                                        },
                                      ).then((value) => safeSetState(() {}));
                                    },
                                    text: FFLocalizations.of(context).getText(
                                      'bvffcfv7' /* Delete Account */,
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
                                            color: FlutterFlowTheme.of(context)
                                                .error,
                                            fontSize: 15.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.w500,
                                          ),
                                      elevation: 0.0,
                                      borderRadius: BorderRadius.circular(8.0),
                                    ),
                                    showLoadingIndicator: false,
                                  ),
                                ),
                              ]
                                  .divide(SizedBox(height: 6.0))
                                  .addToEnd(SizedBox(height: 100.0)),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional(0.0, 1.0),
              child: wrapWithModel(
                model: _model.navBarModel,
                updateCallback: () => safeSetState(() {}),
                child: NavBarWidget(
                  indexCurrentPage: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
