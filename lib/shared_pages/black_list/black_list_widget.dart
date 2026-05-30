import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/empty/empty_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/basic_page_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/index.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'black_list_model.dart';
export 'black_list_model.dart';

class BlackListWidget extends StatefulWidget {
  const BlackListWidget({super.key});

  static String routeName = 'blackList';
  static String routePath = '/blackList';

  @override
  State<BlackListWidget> createState() => _BlackListWidgetState();
}

class _BlackListWidgetState extends State<BlackListWidget> {
  late BlackListModel _model;
  final _userFutureCache = <String, Future<UserPublicProfilesRecord?>>{};

  final scaffoldKey = GlobalKey<ScaffoldState>();

  Future<UserPublicProfilesRecord?> _getUserFuture(DocumentReference ref) {
    return _userFutureCache.putIfAbsent(
      ref.path,
      () => UserPublicProfilesRecord.maybeGetDocumentOnce(
        UserPublicProfilesRecord.collection.doc(ref.id),
      ),
    );
  }

  String _publicProfileDisplayName(
    BuildContext context,
    UserPublicProfilesRecord? profile,
  ) {
    final displayName = profile?.displayName.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    return FFLocalizations.of(context).getVariableText(
      ruText: 'Пользователь',
      enText: 'User',
    );
  }

  String _publicProfilePhotoUrl(UserPublicProfilesRecord? profile) =>
      profile?.photoUrl.trim() ?? '';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => BlackListModel());
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
              padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
              child: AuthUserStreamWidget(
                builder: (context) => Builder(
                  builder: (context) {
                    final list =
                        (currentUserDocument?.blockedUsers.toList() ?? [])
                            .toList();
                    if (list.isEmpty) {
                      return Center(
                        child: Container(
                          height: 500.0,
                          child: EmptyWidget(
                            txt:
                                'В этом разделе будут отображаться собеседники, которых вы добавили в чёрный список. Если список пуст, все пользователи доступны для подбора звонков.',
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        0,
                        115.0,
                        0,
                        120.0,
                      ),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => SizedBox(height: 6.0),
                      itemBuilder: (context, listIndex) {
                        final listItem = list[listIndex];
                        return FutureBuilder<UserPublicProfilesRecord?>(
                          future: _getUserFuture(listItem),
                          builder: (context, snapshot) {
                            // Customize what your widget looks like when it's loading.
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(
                                child: SizedBox(
                                  width: 50.0,
                                  height: 50.0,
                                  child: SpinKitCircle(
                                    color:
                                        FlutterFlowTheme.of(context).secondary,
                                    size: 50.0,
                                  ),
                                ),
                              );
                            }

                            final containerUserPublicProfile = snapshot.data;
                            final profileDisplayName =
                                _publicProfileDisplayName(
                              context,
                              containerUserPublicProfile,
                            );
                            final profilePhotoUrl = _publicProfilePhotoUrl(
                              containerUserPublicProfile,
                            );

                            return InkWell(
                              splashColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () async {
                                if (containerUserPublicProfile?.role ==
                                        UserRole.native_speaker &&
                                    (containerUserPublicProfile
                                            ?.approvedTeacher ??
                                        false)) {
                                  context.pushNamed(
                                    NativeSpeakerPageWidget.routeName,
                                    queryParameters: {
                                      'nsUserDocRef': serializeParam(
                                        listItem,
                                        ParamType.DocumentReference,
                                      ),
                                    }.withoutNulls,
                                  );
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                height: 72.0,
                                decoration: BoxDecoration(
                                  color: ExpatlioDesign.background,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: ExpatlioDesign.border,
                                    ),
                                  ),
                                ),
                                child: Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 8.0, 0.0, 8.0),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Container(
                                        width: 52.0,
                                        height: 52.0,
                                        decoration: BoxDecoration(
                                          color: ExpatlioDesign.mutedSurface,
                                          image: profilePhotoUrl.isNotEmpty
                                              ? DecorationImage(
                                                  fit: BoxFit.cover,
                                                  image:
                                                      CachedNetworkImageProvider(
                                                    profilePhotoUrl,
                                                    maxWidth: 104,
                                                    maxHeight: 104,
                                                  ),
                                                )
                                              : null,
                                          borderRadius:
                                              BorderRadius.circular(26.0),
                                        ),
                                        child: profilePhotoUrl.isEmpty
                                            ? Center(
                                                child: Text(
                                                  profileDisplayName
                                                      .characters.first
                                                      .toUpperCase(),
                                                  style:
                                                      ExpatlioDesign.textStyle(
                                                    context,
                                                    color: ExpatlioDesign.muted,
                                                    size: 16.0,
                                                    weight: FontWeight.w700,
                                                  ),
                                                ),
                                              )
                                            : null,
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  12.0, 0.0, 0.0, 0.0),
                                          child: Text(
                                            profileDisplayName,
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  fontFamily: 'sf pro display',
                                                  color: ExpatlioDesign.text,
                                                  fontSize: 16.0,
                                                  letterSpacing: 0.0,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      FlutterFlowIconButton(
                                        borderRadius: 12.0,
                                        buttonSize: 52.0,
                                        icon: Icon(
                                          FFIcons.ktrash03,
                                          color: FlutterFlowTheme.of(context)
                                              .error,
                                          size: 18.0,
                                        ),
                                        onPressed: () async {
                                          final signedInUserRef =
                                              currentUserReference;
                                          if (signedInUserRef == null) {
                                            return;
                                          }
                                          await signedInUserRef.update({
                                            ...mapToFirestore(
                                              {
                                                'blockedUsers':
                                                    FieldValue.arrayRemove([
                                                  listItem,
                                                ]),
                                              },
                                            ),
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            BasicPageHeader(
              title: FFLocalizations.of(context).getText(
                'qjrrp4il' /* Ченый список */,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
