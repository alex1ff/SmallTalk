import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

class StudentPayIntro extends StatelessWidget {
  const StudentPayIntro({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Выберите свой тариф',
          textAlign: TextAlign.center,
          style: ExpatlioDesign.textStyle(
            context,
            size: 26.0,
            weight: FontWeight.w700,
            height: 1.18,
          ),
        ),
        const SizedBox(height: 8.0),
        Text(
          'Отмените или измените подписку в любой момент',
          textAlign: TextAlign.center,
          style: ExpatlioDesign.textStyle(
            context,
            color: ExpatlioDesign.muted,
            size: 15.0,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}
