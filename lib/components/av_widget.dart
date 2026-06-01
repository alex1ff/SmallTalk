import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/bottom_sheet_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

  Future<void> _saveAvatar() async {
    await widget.ation?.call(
      widget.avatarDoc!.images.elementAtOrNull(_model.carouselCurrentIndex)!,
    );
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: AlignmentDirectional(0.0, 1.0),
      children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space0,
              ExpatlioDesign.space0,
              ExpatlioDesign.space0,
              ExpatlioDesign.space0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                decoration: ExpatlioDesign.sheetDecoration(
                    color: ExpatlioDesign.background),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    BottomSheetHeader(
                      title: FFLocalizations.of(context).getText(
                        'zlkfpu1u' /* Какой ты сегодня */,
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
                                  child: CachedNetworkImage(
                                    imageUrl: immItem,
                                    width: 150.0,
                                    fit: BoxFit.contain,
                                    memCacheWidth: 300,
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
                    BottomSheetPrimaryButton(
                      text: FFLocalizations.of(context).getVariableText(
                        ruText: 'Сохранить',
                        enText: 'Save',
                      ),
                      onPressed: _saveAvatar,
                    ),
                    const SizedBox(height: ExpatlioDesign.space32),
                  ].divide(SizedBox(height: ExpatlioDesign.space24)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
