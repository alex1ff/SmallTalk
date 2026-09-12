import '/flutter_flow/internationalization.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

class StudentStartSearchButton extends StatelessWidget {
  const StudentStartSearchButton({
    super.key,
    required this.onTap,
    this.isActive = false,
  });

  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final label = FFLocalizations.of(context).getVariableText(
      ruText: isActive ? 'Остановить поиск' : 'Начать поиск',
      enText: isActive ? 'Stop search' : 'Start search',
    );
    final icon = isActive ? Icons.stop_rounded : Icons.auto_awesome_rounded;
    final shadowColor =
        isActive ? const Color(0x26FF383C) : const Color(0x267430E8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(ExpatlioDesign.buttonRadius),
        onTap: onTap,
        child: Container(
          width: 240.0,
          height: 60.0,
          decoration: BoxDecoration(
            color: isActive ? ExpatlioDesign.danger : null,
            gradient: isActive ? null : ExpatlioDesign.primaryGradient,
            borderRadius: BorderRadius.circular(ExpatlioDesign.buttonRadius),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 22.0,
                offset: Offset(0.0, 10.0),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 22.0,
              ),
              const SizedBox(width: ExpatlioDesign.itemSpacing),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
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
