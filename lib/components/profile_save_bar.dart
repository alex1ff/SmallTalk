import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

class ProfileSaveBar extends StatelessWidget {
  const ProfileSaveBar({
    super.key,
    required this.onSave,
  });

  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFFBFBFB),
        border: Border(
          top: BorderSide(color: Color(0xFFEDEDED), width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(24.0, 12.0, 24.0, 12.0),
        child: FFButtonWidget(
          onPressed: onSave,
          text: FFLocalizations.of(context).getVariableText(
            ruText: 'Сохранить',
            enText: 'Save',
          ),
          options: FFButtonOptions(
            width: double.infinity,
            height: ExpatlioDesign.buttonHeight,
            color: ExpatlioDesign.primary,
            elevation: 0.0,
            borderRadius: BorderRadius.circular(10.0),
            textStyle: ExpatlioDesign.textStyle(
              context,
              color: Colors.white,
              size: 17.0,
              weight: FontWeight.w700,
            ),
          ),
          showLoadingIndicator: false,
        ),
      ),
    );
  }
}
