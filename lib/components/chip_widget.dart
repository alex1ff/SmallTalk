import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'chip_model.dart';
export 'chip_model.dart';

class ChipWidget extends StatefulWidget {
  const ChipWidget({
    super.key,
    required this.text,
    this.currentSelected,
    required this.callbackAction,
    this.img,
    this.icon,
  });

  final String? text;
  final String? currentSelected;
  final Future Function(String selected)? callbackAction;
  final String? img;
  final IconData? icon;

  @override
  State<ChipWidget> createState() => _ChipWidgetState();
}

class _ChipWidgetState extends State<ChipWidget> {
  late ChipModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ChipModel());
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
        await widget.callbackAction?.call(
          widget.text!,
        );
      },
      child: Container(
        width: double.infinity,
        height: 62.0,
        decoration: ExpatlioDesign.cardDecoration(radius: 16.0),
        child: Padding(
          padding: EdgeInsets.all(ExpatlioDesign.space4),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                width: 52.0,
                height: 52.0,
                decoration: BoxDecoration(
                  color: ExpatlioDesign.primary.withValues(alpha: 0.08),
                  borderRadius:
                      BorderRadius.circular(ExpatlioDesign.radiusMedium),
                ),
                child: Align(
                  alignment: AlignmentDirectional(0.0, 0.0),
                  child: _buildLeadingIcon(),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                      ExpatlioDesign.space12,
                      ExpatlioDesign.space0,
                      ExpatlioDesign.space8,
                      ExpatlioDesign.space0),
                  child: Text(
                    valueOrDefault<String>(
                      widget.text,
                      '-',
                    ),
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          fontFamily: 'sf pro display',
                          color: ExpatlioDesign.text,
                          fontSize: 16.0,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
              if (widget.text == widget.currentSelected)
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                      ExpatlioDesign.space0,
                      ExpatlioDesign.space0,
                      ExpatlioDesign.space8,
                      ExpatlioDesign.space0),
                  child: Container(
                    width: 30.0,
                    height: 30.0,
                    decoration: BoxDecoration(
                      color: ExpatlioDesign.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional(0.0, 0.0),
                      child: Icon(
                        FFIcons.kcheck,
                        color: Colors.white,
                        size: 15.0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingIcon() {
    if (widget.icon != null) {
      return Icon(
        widget.icon,
        size: 24.0,
        color: ExpatlioDesign.primary,
      );
    }

    final imageUrl = widget.img;
    if (imageUrl == null || imageUrl.isEmpty) {
      return Icon(
        Icons.image_not_supported_outlined,
        size: 24.0,
        color: ExpatlioDesign.primary,
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: 25.0,
      height: 25.0,
      fit: BoxFit.contain,
      memCacheWidth: 50,
      memCacheHeight: 50,
      placeholder: (context, url) => const SizedBox.shrink(),
      errorWidget: (context, url, error) => Icon(
        Icons.image_not_supported_outlined,
        size: 24.0,
        color: ExpatlioDesign.primary,
      ),
    );
  }
}
