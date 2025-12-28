import '/backend/backend.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:async';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'av_model.dart';
export 'av_model.dart';

class AvWidget extends StatefulWidget {
  const AvWidget({
    super.key,
    required this.ation,
    required this.avatarDoc,
  });

  final Future Function(String img)? ation;
  final AvatarsRecord? avatarDoc;

  @override
  State<AvWidget> createState() => _AvWidgetState();
}

class _AvWidgetState extends State<AvWidget> {
  late AvModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AvModel());
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(8.0, 0.0, 8.0, 0.0),
                      child: Text(
                        FFLocalizations.of(context).getText(
                          'zlkfpu1u' /* какой ты сегодня */,
                        ),
                        textAlign: TextAlign.start,
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'Cool',
                              fontSize: 21.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.normal,
                            ),
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final imm = widget.avatarDoc?.images.toList() ?? [];

                        return Container(
                          width: double.infinity,
                          height: 275.0,
                          child: CarouselSlider.builder(
                            itemCount: imm.length,
                            itemBuilder: (context, immIndex, _) {
                              final immItem = imm[immIndex];
                              return Container(
                                width: 275.0,
                                height: 275.0,
                                decoration: BoxDecoration(
                                  color: valueOrDefault<Color>(
                                    _model.carouselCurrentIndex == immIndex
                                        ? Color(0xFFEC97DA)
                                        : FlutterFlowTheme.of(context)
                                            .primaryBackground,
                                    FlutterFlowTheme.of(context)
                                        .primaryBackground,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Align(
                                  alignment: AlignmentDirectional(0.0, 0.0),
                                  child: Image.network(
                                    immItem,
                                    width: 150.0,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              );
                            },
                            carouselController: _model.carouselController ??=
                                CarouselSliderController(),
                            options: CarouselOptions(
                              initialPage: max(0, min(0, imm.length - 1)),
                              viewportFraction: 0.55,
                              disableCenter: false,
                              enlargeCenterPage: true,
                              enlargeFactor: 0.3,
                              enableInfiniteScroll: true,
                              scrollDirection: Axis.horizontal,
                              autoPlay: false,
                              onPageChanged: (index, _) async {
                                _model.carouselCurrentIndex = index;
                                safeSetState(() {});
                              },
                            ),
                          ),
                        );
                      },
                    ),
                    wrapWithModel(
                      model: _model.buttonModel,
                      updateCallback: () => safeSetState(() {}),
                      child: ButtonWidget(
                        text: 'Сохранить',
                        action: () async {
                          unawaited(
                            () async {
                              await widget.ation?.call(
                                widget.avatarDoc!.images.elementAtOrNull(
                                    _model.carouselCurrentIndex)!,
                              );
                            }(),
                          );
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ]
                      .divide(SizedBox(height: 24.0))
                      .addToStart(SizedBox(height: 16.0)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
