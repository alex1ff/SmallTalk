import '/auth/firebase_auth/auth_util.dart';
import '/components/country_widget.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/bottom_sheet_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/services/supported_location_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'edit_country_model.dart';
export 'edit_country_model.dart';

class EditCountryWidget extends StatefulWidget {
  const EditCountryWidget({
    super.key,
    required this.action,
    required this.title,
    required this.selecte,
    this.persistSelectedCountryToUserCountry = true,
    this.allowClear = false,
    this.clearAction,
  });

  final Future Function(CountryStruct lang)? action;
  final String? title;
  final CountryStruct? selecte;
  final bool persistSelectedCountryToUserCountry;
  final bool allowClear;
  final Future Function()? clearAction;

  @override
  State<EditCountryWidget> createState() => _EditCountryWidgetState();
}

class _EditCountryWidgetState extends State<EditCountryWidget> {
  late EditCountryModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EditCountryModel());

    // On component load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.selected = widget.selecte;
      safeSetState(() {});
    });
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  Future<void> _saveCountry() async {
    if (_model.selected != widget.selecte) {
      if (widget.persistSelectedCountryToUserCountry &&
          _model.selected != currentUserDocument?.countryNS) {
        await currentUserReference!.update(createUsersRecordData(
          countryNS: updateCountryStruct(
            _model.selected,
            clearUnsetFields: false,
          ),
          profileCity: resolveSupportedCountryStruct(_model.selected)
              ?.toProfileCityStruct(serverTimestamp: true),
        ));
      }
      if (_model.selected != null) {
        await widget.action?.call(
          _model.selected!,
        );
      } else if (widget.allowClear) {
        await widget.clearAction?.call();
      }
    }
    if (mounted) {
      Navigator.pop(context, _model.selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(ExpatlioDesign.space0,
          ExpatlioDesign.space0, ExpatlioDesign.space0, ExpatlioDesign.space0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.9,
            ),
            decoration: ExpatlioDesign.sheetDecoration(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                BottomSheetHeader(
                  title: valueOrDefault<String>(
                    widget.title,
                    FFLocalizations.of(context).getVariableText(
                      ruText: 'Локация',
                      enText: 'Location',
                    ),
                  ),
                ),
                Flexible(
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                        ExpatlioDesign.pagePadding,
                        ExpatlioDesign.space0,
                        ExpatlioDesign.pagePadding,
                        ExpatlioDesign.space0),
                    child: SingleChildScrollView(
                      primary: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          wrapWithModel(
                            model: _model.countryModel,
                            updateCallback: () => safeSetState(() {}),
                            child: CountryWidget(
                              selected: _model.selected,
                              action: (lang) async {
                                _model.selected = lang;
                                safeSetState(() {});
                              },
                            ),
                          ),
                          if (widget.allowClear) ...[
                            SizedBox(height: ExpatlioDesign.space12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () {
                                  _model.selected = null;
                                  safeSetState(() {});
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: ExpatlioDesign.text,
                                  side: const BorderSide(
                                    color: ExpatlioDesign.border,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      ExpatlioDesign.controlRadius,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  FFLocalizations.of(context).getVariableText(
                                    ruText: 'Любая локация',
                                    enText: 'Any location',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ].addToEnd(SizedBox(height: ExpatlioDesign.space32)),
                      ),
                    ),
                  ),
                ),
                BottomSheetPrimaryButton(
                  text: FFLocalizations.of(context).getVariableText(
                    ruText: 'Сохранить',
                    enText: 'Save',
                  ),
                  onPressed: _saveCountry,
                ),
              ].divide(SizedBox(height: ExpatlioDesign.space16)),
            ),
          ),
        ],
      ),
    );
  }
}
