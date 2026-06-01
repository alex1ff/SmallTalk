import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/index.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'fav_model.dart';
export 'fav_model.dart';

class FavWidget extends StatefulWidget {
  const FavWidget({
    super.key,
    required this.nsUser,
    this.enableNavigation = true,
  });

  final DocumentReference? nsUser;
  final bool enableNavigation;

  @override
  State<FavWidget> createState() => _FavWidgetState();
}

class _FavWidgetState extends State<FavWidget> {
  late FavModel _model;
  late Future<UserPublicProfilesRecord?> _userFuture;

  Future<UserPublicProfilesRecord?> _createUserFuture() {
    final userRef = widget.nsUser;
    if (userRef == null) {
      return Future.value(null);
    }

    return UserPublicProfilesRecord.maybeGetDocumentOnce(
      UserPublicProfilesRecord.collection.doc(userRef.id),
    );
  }

  String _displayName(BuildContext context, UserPublicProfilesRecord? user) {
    final displayName = user?.displayName.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    return FFLocalizations.of(context).getVariableText(
      ruText: 'Пользователь',
      enText: 'User',
    );
  }

  String _photoUrl(UserPublicProfilesRecord? user) =>
      user?.photoUrl.trim() ?? '';

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => FavModel());
    _userFuture = _createUserFuture();
  }

  @override
  void didUpdateWidget(covariant FavWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nsUser?.path != widget.nsUser?.path) {
      _userFuture = _createUserFuture();
    }
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserPublicProfilesRecord?>(
      future: _userFuture,
      builder: (context, snapshot) {
        // Customize what your widget looks like when it's loading.
        if (snapshot.connectionState == ConnectionState.waiting) {
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

        final containerUserPublicProfile = snapshot.data;
        final profilePhotoUrl = _photoUrl(containerUserPublicProfile);
        final profileDisplayName =
            _displayName(context, containerUserPublicProfile);
        final hasReviews = (containerUserPublicProfile?.ratingCount ?? 0) > 0;

        return InkWell(
          splashColor: Colors.transparent,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: widget.enableNavigation
              ? () async {
                  final userRef = widget.nsUser;
                  if (userRef == null) {
                    return;
                  }
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => NativeSpeakerPageWidget(
                        nsUserDocRef: userRef,
                        hideDirectCallAction: true,
                      ),
                    ),
                  );
                }
              : null,
          child: Container(
            width: 140.0,
            decoration: BoxDecoration(
              color: ExpatlioDesign.card,
              borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
            ),
            child: Padding(
              padding: EdgeInsets.all(ExpatlioDesign.space12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: AlignmentDirectional(0.0, 1.0),
                    children: [
                      Container(
                        width: 125.0,
                        height: 125.0,
                        decoration: BoxDecoration(
                          color: ExpatlioDesign.background,
                          image: profilePhotoUrl.isNotEmpty
                              ? DecorationImage(
                                  fit: BoxFit.cover,
                                  image: CachedNetworkImageProvider(
                                    profilePhotoUrl,
                                    maxWidth: 250,
                                    maxHeight: 250,
                                  ),
                                )
                              : null,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                            width: 3.0,
                          ),
                        ),
                        child: profilePhotoUrl.isEmpty
                            ? Center(
                                child: Text(
                                  profileDisplayName.characters.first
                                      .toUpperCase(),
                                  style: ExpatlioDesign.textStyle(
                                    context,
                                    color: ExpatlioDesign.muted,
                                    size: 24.0,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      if (hasReviews)
                        Container(
                          width: 55.0,
                          height: 25.0,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                                ExpatlioDesign.radiusLarge),
                          ),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space8,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space8,
                                ExpatlioDesign.space0),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  FFIcons.kstar012,
                                  color: Color(0xFFFFC100),
                                  size: 13.0,
                                ),
                                Text(
                                  formatNumber(
                                    containerUserPublicProfile!.ratingAverage,
                                    formatType: FormatType.custom,
                                    format: '0.0',
                                    locale: '',
                                  ),
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        fontFamily: 'sf pro display',
                                        letterSpacing: 0.0,
                                      ),
                                ),
                              ].divide(SizedBox(width: ExpatlioDesign.space4)),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                        ExpatlioDesign.space0,
                        ExpatlioDesign.space12,
                        ExpatlioDesign.space0,
                        ExpatlioDesign.space0),
                    child: Text(
                      profileDisplayName,
                      maxLines: 1,
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontFamily: 'sf pro display',
                            fontSize: 15.0,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.w500,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
