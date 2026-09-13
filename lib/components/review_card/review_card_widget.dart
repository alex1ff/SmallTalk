import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'review_card_model.dart';
export 'review_card_model.dart';

class ReviewCardWidget extends StatefulWidget {
  const ReviewCardWidget({
    super.key,
    required this.rewDoc,
    this.fullWidth = false,
  });

  final ReviewsRecord? rewDoc;
  final bool fullWidth;

  @override
  State<ReviewCardWidget> createState() => _ReviewCardWidgetState();
}

class _ReviewCardWidgetState extends State<ReviewCardWidget> {
  static const _compactWidth = 325.0;
  static const _avatarSize = 44.0;

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

  String _createdAtLabel(BuildContext context) {
    final createdAt = widget.rewDoc?.createdAt;
    if (createdAt == null) {
      return '';
    }

    return dateTimeFormat(
      "d/M/y",
      createdAt,
      locale: FFLocalizations.of(context).languageCode,
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
    final rating = widget.rewDoc?.rating.toDouble() ?? 0.0;

    return Container(
      width: widget.fullWidth ? double.infinity : _compactWidth,
      constraints: const BoxConstraints(minHeight: 76.0),
      decoration: ExpatlioDesign.cardDecoration(
        radius: ExpatlioDesign.cardRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(ExpatlioDesign.space16),
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
                      final containerUserPublicProfile = snapshot.data;
                      final authorName = _reviewAuthorName(
                        context,
                        containerUserPublicProfile,
                      );
                      final photoUrl =
                          containerUserPublicProfile?.photoUrl.trim() ?? '';

                      return Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          _ReviewAuthorAvatar(
                            photoUrl: photoUrl,
                            displayName: authorName,
                            size: _avatarSize,
                          ),
                          const SizedBox(width: ExpatlioDesign.space12),
                          Flexible(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  authorName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: ExpatlioDesign.textStyle(
                                    context,
                                    size: 15.0,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: ExpatlioDesign.space4),
                                Text(
                                  _createdAtLabel(context),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: ExpatlioDesign.textStyle(
                                    context,
                                    color: ExpatlioDesign.muted,
                                    size: 14.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: ExpatlioDesign.space12),
                RatingBarIndicator(
                  itemBuilder: (context, index) => Icon(
                    Icons.star_rounded,
                    color: ExpatlioDesign.warning,
                  ),
                  direction: Axis.horizontal,
                  rating: rating,
                  unratedColor: ExpatlioDesign.mutedSurface,
                  itemCount: 5,
                  itemSize: 18.0,
                ),
              ],
            ),
            if (reviewComment != null)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                    ExpatlioDesign.space0,
                    ExpatlioDesign.space12,
                    ExpatlioDesign.space0,
                    ExpatlioDesign.space0),
                child: Text(
                  reviewComment,
                  style: ExpatlioDesign.textStyle(
                    context,
                    size: 15.0,
                  ).copyWith(height: 1.35),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReviewAuthorAvatar extends StatelessWidget {
  const _ReviewAuthorAvatar({
    required this.photoUrl,
    required this.displayName,
    required this.size,
  });

  final String photoUrl;
  final String displayName;
  final double size;

  Widget _fallback(BuildContext context) {
    return Container(
      color: ExpatlioDesign.avatarFallbackBackground,
      alignment: Alignment.center,
      child: Text(
        ExpatlioDesign.avatarInitial(displayName),
        maxLines: 1,
        style: ExpatlioDesign.textStyle(
          context,
          color: ExpatlioDesign.avatarFallbackText,
          size: 16.0,
          weight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final normalizedPhotoUrl = photoUrl.trim();

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ),
      foregroundDecoration: const BoxDecoration(
        shape: BoxShape.circle,
        border: Border.fromBorderSide(
          BorderSide(color: ExpatlioDesign.border),
        ),
      ),
      child: normalizedPhotoUrl.isEmpty
          ? _fallback(context)
          : CachedNetworkImage(
              imageUrl: normalizedPhotoUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              memCacheWidth: (size * 2).round(),
              memCacheHeight: (size * 2).round(),
              placeholder: (context, _) => _fallback(context),
              errorWidget: (context, _, __) => _fallback(context),
            ),
    );
  }
}
