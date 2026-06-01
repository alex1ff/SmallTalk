import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'avatar_card_model.dart';
export 'avatar_card_model.dart';

class AvatarCardWidget extends StatefulWidget {
  const AvatarCardWidget({
    super.key,
    required this.avatarDoc,
    this.selected,
    required this.action,
    this.avatar,
    required this.actiondele,
  });

  final AvatarsRecord? avatarDoc;
  final DocumentReference? selected;
  final Future Function(AvatarsRecord doc)? action;
  final String? avatar;
  final Future Function()? actiondele;

  @override
  State<AvatarCardWidget> createState() => _AvatarCardWidgetState();
}

class _AvatarCardWidgetState extends State<AvatarCardWidget> {
  late AvatarCardModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AvatarCardModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () async {
        await widget.action?.call(
          widget.avatarDoc!,
        );
      },
      child: Container(
        width: 100.0,
        height: 110.0,
        decoration: BoxDecoration(
          color: ExpatlioDesign.card,
          borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
        ),
        child: Stack(
          alignment: AlignmentDirectional(0.0, 0.0),
          children: [
            CachedNetworkImage(
              imageUrl: (widget.selected == widget.avatarDoc?.reference) &&
                      (widget.avatar != null && widget.avatar != '')
                  ? widget.avatar!
                  : widget.avatarDoc!.images.firstOrNull!,
              width: 90.0,
              height: 200.0,
              fit: BoxFit.contain,
              memCacheWidth: 180,
              memCacheHeight: 400,
            ),
            Align(
              alignment: AlignmentDirectional(1.0, -1.0),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                    ExpatlioDesign.space0,
                    ExpatlioDesign.space4,
                    ExpatlioDesign.space4,
                    ExpatlioDesign.space0),
                child: InkWell(
                  splashColor: Colors.transparent,
                  focusColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  onTap: () async {
                    if (widget.avatarDoc?.reference == widget.selected) {
                      await widget.actiondele?.call();
                    } else {
                      await widget.action?.call(
                        widget.avatarDoc!,
                      );
                    }
                  },
                  child: Container(
                    width: 25.0,
                    height: 25.0,
                    decoration: BoxDecoration(
                      color: valueOrDefault<Color>(
                        widget.avatarDoc?.reference == widget.selected
                            ? FlutterFlowTheme.of(context).primaryText
                            : FlutterFlowTheme.of(context).secondaryBackground,
                        FlutterFlowTheme.of(context).secondaryBackground,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Visibility(
                      visible: widget.avatarDoc?.reference == widget.selected,
                      child: Align(
                        alignment: AlignmentDirectional(0.0, 0.0),
                        child: Icon(
                          FFIcons.kcheck,
                          color: ExpatlioDesign.card,
                          size: 14.0,
                        ),
                      ),
                    ),
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
