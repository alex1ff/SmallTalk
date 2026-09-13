import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'chips_model.dart';
export 'chips_model.dart';

class ChipsWidget extends StatefulWidget {
  const ChipsWidget({
    super.key,
    required this.icon,
    required this.text,
    bool? selected,
    required this.actionadd,
    required this.actiondeelete,
  }) : this.selected = selected ?? false;

  final String? icon;
  final String? text;
  final bool selected;
  final Future Function(String select)? actionadd;
  final Future Function(String select)? actiondeelete;

  @override
  State<ChipsWidget> createState() => _ChipsWidgetState();
}

class _ChipsWidgetState extends State<ChipsWidget> {
  late ChipsModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ChipsModel());
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
        if (widget.selected) {
          await widget.actiondeelete?.call(
            widget.text!,
          );
        } else {
          await widget.actionadd?.call(
            widget.text!,
          );
        }
      },
      child: Container(
        width: double.infinity,
        height: 118.74,
        decoration: BoxDecoration(
          color: widget.selected
              ? ExpatlioDesign.primary.withValues(alpha: 0.10)
              : ExpatlioDesign.card,
          borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
          border: Border.all(color: ExpatlioDesign.border),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space16,
              ExpatlioDesign.space0,
              ExpatlioDesign.space16,
              ExpatlioDesign.space0),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60.0,
                height: 60.0,
                decoration: BoxDecoration(
                  color: widget.selected
                      ? ExpatlioDesign.primary
                      : ExpatlioDesign.mutedSurface,
                  borderRadius:
                      BorderRadius.circular(ExpatlioDesign.radiusLarge),
                  border: Border.all(color: ExpatlioDesign.border, width: 1.0),
                ),
                child: Align(
                  alignment: AlignmentDirectional(0.0, 0.0),
                  child: CachedNetworkImage(
                    fadeInDuration: Duration(milliseconds: 0),
                    fadeOutDuration: Duration(milliseconds: 0),
                    imageUrl: widget.icon!,
                    width: 20.0,
                    height: 20.0,
                    fit: BoxFit.contain,
                    memCacheWidth: 40,
                    memCacheHeight: 40,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                    ExpatlioDesign.space0,
                    ExpatlioDesign.space12,
                    ExpatlioDesign.space0,
                    ExpatlioDesign.space0),
                child: AutoSizeText(
                  valueOrDefault<String>(
                    widget.text,
                    '-',
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'sf pro display',
                        color: widget.selected
                            ? ExpatlioDesign.primary
                            : ExpatlioDesign.text,
                        fontSize: 15.0,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
