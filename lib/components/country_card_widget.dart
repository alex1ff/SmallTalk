import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
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
                          color: ExpatlioDesign.primary,
                          size: 24.0,
                        ),
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
                    localization.getVariableText(
                      ruText: lang?.nameRu,
                      enText: lang?.nameEn,
                    ),
                    style: theme.bodyMedium.override(
                      fontFamily: 'sf pro display',
                      color: ExpatlioDesign.text,
                      fontSize: 16.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (isSelected)
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                      ExpatlioDesign.space0,
                      ExpatlioDesign.space0,
                      ExpatlioDesign.space8,
                      ExpatlioDesign.space0),
                  child: Container(
                    key: const ValueKey<String>(
                        'country_card_selected_indicator'),
                    width: selectionIndicatorSize,
                    height: selectionIndicatorSize,
                    decoration: BoxDecoration(
                      color: ExpatlioDesign.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional(0.0, 0.0),
                      child: Icon(
                        FFIcons.kcheck,
                        color: Colors.white,
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
