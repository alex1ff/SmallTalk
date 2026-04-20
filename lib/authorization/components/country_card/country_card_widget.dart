import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
export 'country_card_model.dart';

class CountryCardWidget extends StatelessWidget {
  static const double selectionIndicatorSize = 25.0;

  const CountryCardWidget({
    super.key,
    required this.lang,
    this.currentSelected,
    required this.callbackAction,
  });

  final CountryStruct? lang;
  final CountryStruct? currentSelected;
  final Future Function(CountryStruct selectedLangData)? callbackAction;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final lang = this.lang;
    final isSelected = lang == currentSelected;
    final hasFlag = (lang?.flag ?? '').trim().isNotEmpty;
    final localization = FFLocalizations.of(context);

    return InkWell(
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () async {
        await callbackAction?.call(
          lang!,
        );
      },
      child: Container(
        width: double.infinity,
        height: 60.0,
        decoration: BoxDecoration(
          color: theme.primaryBackground,
          borderRadius: BorderRadius.circular(26.0),
        ),
        child: Padding(
          padding: EdgeInsets.all(4.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                width: 52.0,
                height: 52.0,
                decoration: BoxDecoration(
                  color: theme.secondaryBackground,
                  borderRadius: BorderRadius.circular(22.0),
                ),
                child: Align(
                  alignment: AlignmentDirectional(0.0, 0.0),
                  child: hasFlag
                      ? Text(
                          lang!.flag,
                          textAlign: TextAlign.center,
                          style: theme.bodyMedium.override(
                            fontFamily: 'sf pro display',
                            fontSize: 22.0,
                            letterSpacing: 0.0,
                          ),
                        )
                      : Icon(
                          Icons.public_outlined,
                          color: theme.secondaryText,
                          size: 24.0,
                        ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(12.0, 0.0, 8.0, 0.0),
                  child: Text(
                    localization.getVariableText(
                      ruText: lang?.nameRu,
                      enText: lang?.nameEn,
                    ),
                    style: theme.bodyMedium.override(
                      fontFamily: 'sf pro display',
                      fontSize: 16.0,
                      letterSpacing: 0.0,
                    ),
                  ),
                ),
              ),
              if (isSelected)
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 8.0, 0.0),
                  child: Container(
                    key: const ValueKey<String>(
                        'country_card_selected_indicator'),
                    width: selectionIndicatorSize,
                    height: selectionIndicatorSize,
                    decoration: BoxDecoration(
                      color: theme.success,
                      shape: BoxShape.circle,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional(0.0, 0.0),
                      child: Icon(
                        FFIcons.kcheck,
                        color: Colors.black,
                        size: 14.0,
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
}
