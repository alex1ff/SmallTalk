import '/flutter_flow/internationalization.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

class StudentStartSearchButton extends StatelessWidget {
  const StudentStartSearchButton({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ExpatlioDesign.buttonRadius),
        onTap: onTap,
        child: Container(
          width: 240.0,
          height: 60.0,
          decoration: BoxDecoration(
            gradient: ExpatlioDesign.primaryGradient,
            borderRadius: BorderRadius.circular(ExpatlioDesign.buttonRadius),
            boxShadow: const [
              BoxShadow(
                color: Color(0x267430E8),
                blurRadius: 22.0,
                offset: Offset(0.0, 10.0),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 22.0,
              ),
              const SizedBox(width: ExpatlioDesign.itemSpacing),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    FFLocalizations.of(context).getVariableText(
                      ruText: 'Начать поиск',
                      enText: 'Start search',
                    ),
                    maxLines: 1,
                    style: ExpatlioDesign.textStyle(
                      context,
                      color: Colors.white,
                      size: 18.0,
                      weight: FontWeight.w700,
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
