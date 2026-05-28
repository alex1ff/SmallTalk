import '/auth/firebase_auth/auth_util.dart';
import '/authorization/components/country/country_widget.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/bottom_sheet_header.dart';
import '/shared_pages/design/expatlio_design.dart';
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
  });

  final Future Function(CountryStruct lang)? action;
  final String? title;
  final CountryStruct? selecte;
  final bool persistSelectedCountryToUserCountry;

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
        ));
      }
      if (_model.selected != null) {
        await widget.action?.call(
          _model.selected!,
        );
      }
    }
    if (mounted) {
      Navigator.pop(context, _model.selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 55.0, 0.0, 0.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.9,
            ),
            decoration: BoxDecoration(
              color: ExpatlioDesign.card,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                BottomSheetHeader(
                  title: valueOrDefault<String>(
                    widget.title,
                    'Страна',
                  ),
                  onConfirm: _saveCountry,
                ),
                Flexible(
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 6.0, 0.0),
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
                        ].addToEnd(SizedBox(height: 35.0)),
                      ),
                    ),
                  ),
                ),
              ].divide(SizedBox(height: 16.0)),
            ),
          ),
        ],
      ),
    );
  }
}
