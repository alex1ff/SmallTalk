import '/auth/firebase_auth/auth_util.dart';
import '/authorization/components/av/av_widget.dart';
import '/authorization/components/avatar_card/avatar_card_widget.dart';
import '/authorization/components/uploud_photo/uploud_photo_widget.dart';
import '/backend/backend.dart';
import '/backend/firebase_storage/storage.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/upload_data.dart';
import 'dart:async';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:webviewx_plus/webviewx_plus.dart';
import 'edit_avatar_model.dart';
export 'edit_avatar_model.dart';

class EditAvatarWidget extends StatefulWidget {
  const EditAvatarWidget({
    super.key,
    required this.action,
  });

  final Future Function()? action;

  @override
  State<EditAvatarWidget> createState() => _EditAvatarWidgetState();
}

class _EditAvatarWidgetState extends State<EditAvatarWidget> {
  late EditAvatarModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EditAvatarModel());

    // On component load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.selectedavatar = currentUserDocument?.selectedAvatarDocRef;
      _model.avatar = currentUserPhoto;
      safeSetState(() {});
    });
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: AlignmentDirectional(0.0, 1.0),
      children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(0.0, 55.0, 0.0, 0.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 16.0,
                child: custom_widgets.NotchedClipper(
                  width: double.infinity,
                  height: 16.0,
                ),
              ),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                ),
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 6.0, 0.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Align(
                        alignment: AlignmentDirectional(0.0, -1.0),
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              8.0, 16.0, 8.0, 0.0),
                          child: AutoSizeText(
                            FFLocalizations.of(context).getText(
                              'nvje9sm9' /* Выберите аватар */,
                            ),
                            textAlign: TextAlign.center,
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: 'Cool',
                                  color: Colors.black,
                                  fontSize: 26.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.normal,
                                  lineHeight: 1.1,
                                ),
                          ),
                        ),
                      ),
                      Padding(
                        padding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 60.0, 0.0, 0.0),
                        child: Container(
                          height: 268.63,
                          decoration: BoxDecoration(),
                          child: AuthUserStreamWidget(
                            builder: (context) =>
                                FutureBuilder<List<AvatarsRecord>>(
                              future: queryAvatarsRecordOnce(
                                queryBuilder: (avatarsRecord) =>
                                    avatarsRecord.where(
                                  'gender',
                                  isEqualTo:
                                      currentUserDocument?.gender?.serialize(),
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
                                        color: FlutterFlowTheme.of(context)
                                            .secondary,
                                        size: 50.0,
                                      ),
                                    ),
                                  );
                                }
                                List<AvatarsRecord> gridViewAvatarsRecordList =
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
                                  itemCount: gridViewAvatarsRecordList.length,
                                  itemBuilder: (context, gridViewIndex) {
                                    final gridViewAvatarsRecord =
                                        gridViewAvatarsRecordList[
                                            gridViewIndex];
                                    return AvatarCardWidget(
                                      key: Key(
                                          'Keyl9g_${gridViewIndex}_of_${gridViewAvatarsRecordList.length}'),
                                      avatarDoc: gridViewAvatarsRecord,
                                      selected: _model.selectedavatar,
                                      avatar: _model.avatar,
                                      action: (doc) async {
                                        if (_model.selectedavatar !=
                                            gridViewAvatarsRecord.reference) {
                                          _model.selectedavatar = doc.reference;
                                          _model.image = null;
                                          _model.avatar = null;
                                          safeSetState(() {});
                                        }
                                        await showModalBottomSheet(
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          context: context,
                                          builder: (context) {
                                            return WebViewAware(
                                              child: Padding(
                                                padding:
                                                    MediaQuery.viewInsetsOf(
                                                        context),
                                                child: AvWidget(
                                                  avatarDoc:
                                                      gridViewAvatarsRecord,
                                                  ation: (img) async {
                                                    _model.avatar = img;
                                                    safeSetState(() {});
                                                  },
                                                ),
                                              ),
                                            );
                                          },
                                        ).then((value) => safeSetState(() {}));
                                      },
                                      actiondele: () async {
                                        _model.selectedavatar = null;
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
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                            0.0, 16.0, 0.0, 100.0),
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
                                  child: Padding(
                                    padding: MediaQuery.viewInsetsOf(context),
                                    child: UploudPhotoWidget(
                                      action: (upl) async {
                                        _model.selectedavatar = null;
                                        _model.image = upl;
                                        _model.avatar = null;
                                        safeSetState(() {});
                                      },
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
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Builder(
                                    builder: (context) {
                                      if (_model.image != null &&
                                          (_model.image?.bytes?.isNotEmpty ??
                                              false)) {
                                        return ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(18.0),
                                          child: Image.memory(
                                            _model.image?.bytes ??
                                                Uint8List.fromList([]),
                                            width: 76.0,
                                            height: 76.0,
                                            fit: BoxFit.cover,
                                          ),
                                        );
                                      } else if (_model.selectedavatar ==
                                          null) {
                                        return AuthUserStreamWidget(
                                          builder: (context) => ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(18.0),
                                            child: Image.network(
                                              currentUserPhoto,
                                              width: 76.0,
                                              height: 76.0,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        );
                                      } else {
                                        return Container(
                                          width: 76.0,
                                          height: 76.0,
                                          decoration: BoxDecoration(
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryBackground,
                                            borderRadius:
                                                BorderRadius.circular(20.0),
                                          ),
                                          child: Icon(
                                            FFIcons.kuserCircle,
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            size: 20.0,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        12.0, 0.0, 0.0, 0.0),
                                    child: AutoSizeText(
                                      FFLocalizations.of(context).getText(
                                        'mhdxqa8u' /* Или загрузить своё фото */,
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            fontSize: 16.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
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
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        wrapWithModel(
          model: _model.buttonModel,
          updateCallback: () => safeSetState(() {}),
          child: ButtonWidget(
            text: 'Сохранить',
            action: () async {
              if (_model.image != null &&
                  (_model.image?.bytes?.isNotEmpty ?? false)) {
                {
                  safeSetState(
                      () => _model.isDataUploading_uploadDataJlx = true);
                  var selectedUploadedFiles = <FFUploadedFile>[];
                  var selectedMedia = <SelectedFile>[];
                  var downloadUrls = <String>[];
                  try {
                    selectedUploadedFiles = _model.image!.bytes!.isNotEmpty
                        ? [_model.image!]
                        : <FFUploadedFile>[];
                    selectedMedia = selectedFilesFromUploadedFiles(
                      selectedUploadedFiles,
                    );
                    downloadUrls = (await Future.wait(
                      selectedMedia.map(
                        (m) async => await uploadData(m.storagePath, m.bytes),
                      ),
                    ))
                        .where((u) => u != null)
                        .map((u) => u!)
                        .toList();
                  } finally {
                    _model.isDataUploading_uploadDataJlx = false;
                  }
                  if (selectedUploadedFiles.length == selectedMedia.length &&
                      downloadUrls.length == selectedMedia.length) {
                    safeSetState(() {
                      _model.uploadedLocalFile_uploadDataJlx =
                          selectedUploadedFiles.first;
                      _model.uploadedFileUrl_uploadDataJlx = downloadUrls.first;
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
                        photoUrl: _model.uploadedFileUrl_uploadDataJlx,
                      ),
                      ...mapToFirestore(
                        {
                          'selectedAvatarDocRef': FieldValue.delete(),
                        },
                      ),
                    });
                  }(),
                );
              } else {
                unawaited(
                  () async {
                    await currentUserReference!.update(createUsersRecordData(
                      photoUrl: _model.avatar,
                      selectedAvatarDocRef: _model.selectedavatar,
                    ));
                  }(),
                );
              }

              Navigator.pop(context);
            },
          ),
        ),
      ],
    );
  }
}
