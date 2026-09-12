import '/shared_pages/design/expatlio_design.dart';
import '/flutter_flow/internationalization.dart';
import 'package:flutter/material.dart';

class StudentPayIntro extends StatelessWidget {
  const StudentPayIntro({super.key});

  @override
  Widget build(BuildContext context) {
    final localization = FFLocalizations.of(context);
    String localized(String ru, String en) =>
        localization.getVariableText(ruText: ru, enText: en);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          localized(
            'Говорите больше. Учитесь быстрее.',
            'Speak more. Learn faster.',
          ),
          textAlign: TextAlign.center,
          style: ExpatlioDesign.textStyle(
            context,
            size: 28.0,
            weight: FontWeight.w800,
            height: 1.12,
          ),
        ),
        const SizedBox(height: ExpatlioDesign.space8),
        Text(
          localized(
            'Звонки, перевод, словарь и AI-разбор — в одной подписке.',
            'Calls, translation, vocabulary and AI feedback in one plan.',
          ),
          textAlign: TextAlign.center,
          style: ExpatlioDesign.textStyle(
            context,
            color: ExpatlioDesign.muted,
            size: 15.0,
            height: 1.25,
          ),
        ),
        const SizedBox(height: ExpatlioDesign.space20),
        _PaywallBenefit(
          icon: Icons.forum_outlined,
          text: localized(
            'Разговорная практика с собеседниками',
            'Conversation practice with real people',
          ),
        ),
        const SizedBox(height: ExpatlioDesign.space12),
        _PaywallBenefit(
          icon: Icons.translate_rounded,
          text: localized(
            'Перевод и субтитры во время звонка',
            'Live translation and captions during calls',
          ),
        ),
        const SizedBox(height: ExpatlioDesign.space12),
        _PaywallBenefit(
          icon: Icons.auto_awesome_outlined,
          text: localized(
            'AI-разбор разговоров и доступ к событиям',
            'AI conversation feedback and events',
          ),
        ),
      ],
    );
  }
}

class _PaywallBenefit extends StatelessWidget {
  const _PaywallBenefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34.0,
          height: 34.0,
          decoration: ExpatlioDesign.softPrimaryDecoration(
            radius: ExpatlioDesign.radiusCapsule,
          ),
          child: Icon(icon, color: ExpatlioDesign.primary, size: 18.0),
        ),
        const SizedBox(width: ExpatlioDesign.space12),
        Expanded(
          child: Text(
            text,
            style: ExpatlioDesign.textStyle(
              context,
              size: 15.0,
              weight: FontWeight.w500,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}
