import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'review_card_model.dart';
export 'review_card_model.dart';

class ReviewCardWidget extends StatefulWidget {
  const ReviewCardWidget({
    super.key,
    required this.rewDoc,
    this.width = 325.0,
  });

  final ReviewsRecord? rewDoc;
  final double width;

  @override
  State<ReviewCardWidget> createState() => _ReviewCardWidgetState();
}

class _ReviewCardWidgetState extends State<ReviewCardWidget> {
  late ReviewCardModel _model;
  late Future<UserPublicProfilesRecord?> _userFuture;

  String? _normalizedComment() {
    final normalizedComment = widget.rewDoc?.comment.trim();
    if (normalizedComment == null ||
        normalizedComment.isEmpty ||
        normalizedComment == '-') {
      return null;
    }

    return normalizedComment;
  }

  Future<UserPublicProfilesRecord?> _createUserFuture() async {
    final authorRef = widget.rewDoc?.fromUserId;
    if (authorRef == null) {
      return null;
    }

    return UserPublicProfilesRecord.maybeGetDocumentOnce(
      UserPublicProfilesRecord.collection.doc(authorRef.id),
    );
  }

  String _reviewAuthorName(
    BuildContext context,
    UserPublicProfilesRecord? user,
  ) {
    final displayName = user?.displayName.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    return FFLocalizations.of(context).getVariableText(
      ruText: 'Пользователь',
      enText: 'User',
    );
  }

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ReviewCardModel());
    _userFuture = _createUserFuture();
  }

  @override
  void didUpdateWidget(covariant ReviewCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rewDoc?.fromUserId != widget.rewDoc?.fromUserId) {
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
    final reviewComment = _normalizedComment();

    return Container(
      width: widget.width,
      decoration: ExpatlioDesign.cardDecoration(radius: 20.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FutureBuilder<UserPublicProfilesRecord?>(
                    future: _userFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
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

                      return Container(
                        decoration: BoxDecoration(),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Container(
                              width: 45.0,
                              height: 45.0,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                              ),
                              child: CachedNetworkImage(
                                imageUrl:
                                    containerUserPublicProfile?.photoUrl ?? '',
                                fit: BoxFit.cover,
                                memCacheWidth: 90,
                                memCacheHeight: 90,
                              ),
                            ),
                            Flexible(
                              child: Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    12.0, 0.0, 0.0, 0.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _reviewAuthorName(
                                        context,
                                        containerUserPublicProfile,
                                      ),
                                      maxLines: 1,
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            color: ExpatlioDesign.text,
                                            fontSize: 15.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.w600,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      dateTimeFormat(
                                        "d/M/y",
                                        widget.rewDoc!.createdAt!,
                                        locale: FFLocalizations.of(context)
                                            .languageCode,
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryText,
                                            fontSize: 14.0,
                                            letterSpacing: 0.0,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                RatingBarIndicator(
                  itemBuilder: (context, index) => Icon(
                    Icons.star_rounded,
                    color: FlutterFlowTheme.of(context).warning,
                  ),
                  direction: Axis.horizontal,
                  rating: widget.rewDoc!.rating.toDouble(),
                  unratedColor: ExpatlioDesign.mutedSurface,
                  itemCount: 5,
                  itemSize: 18.0,
                ),
              ],
            ),
            if (reviewComment != null)
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 10.0, 0.0, 0.0),
                child: Text(
                  reviewComment,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'sf pro display',
                        letterSpacing: 0.0,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
